// SPDX-License-Identifier: GPL-3.0-or-later
#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#include <unistd.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif
#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  FlMethodChannel* files_channel;
  GtkWindow* window;
  FlView* view;
  gboolean close_authorized;
};
G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

namespace {
constexpr char kFilesChannel[] = "mushagaeshi/programmer_files";

void respond_not_implemented(FlMethodChannel*, FlMethodCall* call, gpointer) {
  fl_method_call_respond_not_implemented(call, nullptr);
}

void close_result_cb(GObject* source, GAsyncResult* result, gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  g_autoptr(GError) error = nullptr;
  g_autoptr(FlMethodResponse) response =
      fl_method_channel_invoke_method_finish(FL_METHOD_CHANNEL(source), result, &error);
  gboolean allow = false;
  if (error == nullptr && response != nullptr &&
      FL_IS_METHOD_SUCCESS_RESPONSE(response)) {
    FlValue* value = fl_method_success_response_get_result(
        FL_METHOD_SUCCESS_RESPONSE(response));
    allow = value != nullptr && fl_value_get_type(value) == FL_VALUE_TYPE_BOOL &&
        fl_value_get_bool(value);
  }
  if (allow && self->window != nullptr) {
    self->close_authorized = TRUE;
    gtk_window_close(self->window);
  }
}

gboolean delete_event_cb(GtkWidget*, GdkEvent*, gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  if (self->close_authorized) return FALSE;
  // The Dart coordinator returns true only when there is neither an active
  // hardware command nor a programming-confirmation dialog. Keep the window
  // alive until that asynchronous reply arrives.
  fl_method_channel_invoke_method(self->files_channel, "closeRequested", nullptr,
                                  nullptr, close_result_cb, self);
  return TRUE;
}

void send_drop_error(MyApplication* self, const gchar* message) {
  FlValue* arguments = fl_value_new_map();
  fl_value_set_string_take(arguments, "message", fl_value_new_string(message));
  fl_method_channel_invoke_method(self->files_channel, "fileDropError", arguments,
                                  nullptr, nullptr, nullptr);
}

void drag_data_received_cb(GtkWidget* widget, GdkDragContext* context, gint x, gint y,
                           GtkSelectionData* selection_data, guint, guint time,
                           gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  gchar** uris = gtk_selection_data_get_uris(selection_data);
  if (uris == nullptr || uris[0] == nullptr || uris[1] != nullptr) {
    send_drop_error(self, "Drop exactly one file at a time.");
    if (uris != nullptr) g_strfreev(uris);
    gtk_drag_finish(context, FALSE, FALSE, time);
    return;
  }
  g_autoptr(GFile) file = g_file_new_for_uri(uris[0]);
  g_autofree gchar* path = g_file_get_path(file);
  if (path == nullptr || !g_file_test(path, G_FILE_TEST_IS_REGULAR)) {
    send_drop_error(self, "The dropped item is not a readable file.");
    g_strfreev(uris);
    gtk_drag_finish(context, FALSE, FALSE, time);
    return;
  }
  gint view_x = x;
  gint view_y = y;
  gtk_widget_translate_coordinates(widget, GTK_WIDGET(self->view), x, y,
                                   &view_x, &view_y);
  FlValue* arguments = fl_value_new_map();
  fl_value_set_string_take(arguments, "path", fl_value_new_string(path));
  // GTK reports logical widget coordinates. Flutter's Linux embedding applies
  // the monitor scale before it reaches the engine, so passing them through
  // preserves the Dart layout coordinate system at 100%, 150%, and 200%.
  fl_value_set_string_take(arguments, "x", fl_value_new_float(view_x));
  fl_value_set_string_take(arguments, "y", fl_value_new_float(view_y));
  fl_method_channel_invoke_method(self->files_channel, "fileDropped", arguments,
                                  nullptr, nullptr, nullptr);
  g_strfreev(uris);
  gtk_drag_finish(context, TRUE, FALSE, time);
}

void first_frame_cb(MyApplication*, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

void set_window_icon_from_bundle(GtkWindow* window) {
  gchar executable[4096];
  const ssize_t length = readlink("/proc/self/exe", executable, sizeof(executable) - 1);
  if (length < 0) return;
  executable[length] = '\0';
  g_autofree gchar* directory = g_path_get_dirname(executable);
  g_autofree gchar* icon = g_build_filename(directory, "data", "app_icon.png", nullptr);
  gtk_window_set_icon_from_file(window, icon, nullptr);
}
}  // namespace

static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  self->window = GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));
  gtk_window_set_title(self->window, "Mushagaeshi IC Programmer");
  gtk_window_set_default_size(self->window, 1180, 780);
  set_window_icon_from_bundle(self->window);
  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(project, self->dart_entrypoint_arguments);
  self->view = fl_view_new(project);
  GdkRGBA background;
  gdk_rgba_parse(&background, "#000000");
  fl_view_set_background_color(self->view, &background);
  gtk_widget_show(GTK_WIDGET(self->view));
  gtk_container_add(GTK_CONTAINER(self->window), GTK_WIDGET(self->view));
  g_signal_connect_swapped(self->view, "first-frame", G_CALLBACK(first_frame_cb), self);
  gtk_widget_realize(GTK_WIDGET(self->view));
  fl_register_plugins(FL_PLUGIN_REGISTRY(self->view));
  self->files_channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(self->view)), kFilesChannel,
      FL_METHOD_CODEC(fl_standard_method_codec_new()));
  fl_method_channel_set_method_call_handler(self->files_channel,
      respond_not_implemented, self, nullptr);
  GtkTargetEntry targets[] = {{const_cast<gchar*>("text/uri-list"), 0, 0}};
  gtk_drag_dest_set(GTK_WIDGET(self->view), GTK_DEST_DEFAULT_ALL, targets, 1,
                    GDK_ACTION_COPY);
  g_signal_connect(self->view, "drag-data-received", G_CALLBACK(drag_data_received_cb), self);
  g_signal_connect(self->window, "delete-event", G_CALLBACK(delete_event_cb), self);
  gtk_widget_grab_focus(GTK_WIDGET(self->view));
}

static gboolean my_application_local_command_line(GApplication* application,
                                                   gchar*** arguments, int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);
  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) { *exit_status = 1; return TRUE; }
  g_application_activate(application);
  *exit_status = 0;
  return TRUE;
}
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_object(&self->files_channel);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}
static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line = my_application_local_command_line;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}
static void my_application_init(MyApplication*) {}
MyApplication* my_application_new() {
  g_set_prgname(APPLICATION_ID);
  return MY_APPLICATION(g_object_new(my_application_get_type(), "application-id", APPLICATION_ID,
                                     "flags", G_APPLICATION_NON_UNIQUE, nullptr));
}
