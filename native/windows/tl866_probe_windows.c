/* SPDX-License-Identifier: GPL-3.0-or-later */
/* Read-only SetupAPI probe for MiniPro's TL866A/CS interface. */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <setupapi.h>
#include <stdio.h>
#include <wchar.h>

#define TL866_GUID {0x85980D83,0x32B9,0x4BA1,{0x8F,0xDF,0x12,0xA7,0x11,0xB9,0x9C,0xA2}}

typedef struct { wchar_t *identity; wchar_t *service; int interface_ready; } tl866_device;

static void json_string(const wchar_t *value) {
  if (!value) { fputs("\"\"", stdout); return; }
  int bytes = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, value, -1, NULL, 0, NULL, NULL);
  if (!bytes) { fputs("\"\"", stdout); return; }
  char *utf8 = HeapAlloc(GetProcessHeap(), 0, (SIZE_T)bytes);
  if (!utf8) { fputs("\"\"", stdout); return; }
  WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, value, -1, utf8, bytes, NULL, NULL);
  putchar('"');
  for (const char *p = utf8; *p; ++p) { if (*p == '"' || *p == '\\') putchar('\\'); if ((unsigned char)*p >= 0x20) putchar(*p); }
  putchar('"'); HeapFree(GetProcessHeap(), 0, utf8);
}

static int is_tl866(const wchar_t *ids, DWORD bytes) {
  const wchar_t *limit = (const wchar_t *)((const BYTE *)ids + bytes);
  for (const wchar_t *id = ids; id < limit && *id; id += wcslen(id) + 1) {
    if (wcsstr(id, L"VID_04D8&PID_E11C")) return 1;
  }
  return 0;
}

static wchar_t *instance_id(HDEVINFO set, SP_DEVINFO_DATA *device) {
  DWORD length = 0;
  if (SetupDiGetDeviceInstanceIdW(set, device, NULL, 0, &length) || GetLastError() != ERROR_INSUFFICIENT_BUFFER || !length) return NULL;
  wchar_t *value = HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, (SIZE_T)length * sizeof(*value));
  if (!value || !SetupDiGetDeviceInstanceIdW(set, device, value, length, NULL)) { HeapFree(GetProcessHeap(), 0, value); return NULL; }
  return value;
}

/* An absent service is reported as empty; a present service must be readable. */
static wchar_t *driver_service(HDEVINFO set, SP_DEVINFO_DATA *device) {
  DWORD bytes = 0;
  if (!SetupDiGetDeviceRegistryPropertyW(set, device, SPDRP_SERVICE, NULL, NULL, 0, &bytes)) {
    if (GetLastError() != ERROR_INSUFFICIENT_BUFFER || !bytes)
      return HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, sizeof(wchar_t));
  }
  wchar_t *value = HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, bytes ? bytes : sizeof(wchar_t));
  if (!value || (bytes && !SetupDiGetDeviceRegistryPropertyW(set, device, SPDRP_SERVICE, NULL, (PBYTE)value, bytes, NULL))) { HeapFree(GetProcessHeap(), 0, value); return NULL; }
  return value;
}

static int contains_instance(wchar_t **items, size_t count, const wchar_t *identity) {
  for (size_t index = 0; index < count; ++index) if (_wcsicmp(items[index], identity) == 0) return 1;
  return 0;
}

static int append_instance(wchar_t ***items, size_t *count, size_t *capacity, wchar_t *identity) {
  if (*count == *capacity) {
    size_t next = *capacity ? *capacity * 2 : 4;
    wchar_t **expanded = *items
      ? HeapReAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, *items, next * sizeof(*expanded))
      : HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, next * sizeof(*expanded));
    if (!expanded) return 0;
    *items = expanded; *capacity = next;
  }
  (*items)[(*count)++] = identity; return 1;
}

static int append_device(tl866_device **items, size_t *count, size_t *capacity, wchar_t *identity, wchar_t *service, int ready) {
  if (*count == *capacity) {
    size_t next = *capacity ? *capacity * 2 : 4;
    tl866_device *expanded = *items
      ? HeapReAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, *items, next * sizeof(*expanded))
      : HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, next * sizeof(*expanded));
    if (!expanded) return 0;
    *items = expanded; *capacity = next;
  }
  (*items)[*count] = (tl866_device){ identity, service, ready }; ++*count; return 1;
}

static void free_instances(wchar_t **items, size_t count) {
  for (size_t index = 0; index < count; ++index) HeapFree(GetProcessHeap(), 0, items[index]);
  HeapFree(GetProcessHeap(), 0, items);
}

static void free_devices(tl866_device *items, size_t count) {
  for (size_t index = 0; index < count; ++index) { HeapFree(GetProcessHeap(), 0, items[index].identity); HeapFree(GetProcessHeap(), 0, items[index].service); }
  HeapFree(GetProcessHeap(), 0, items);
}

int main(void) {
  const GUID guid = TL866_GUID;
  HDEVINFO usb = INVALID_HANDLE_VALUE, interfaces = INVALID_HANDLE_VALUE;
  wchar_t **ready = NULL; size_t ready_count = 0, ready_capacity = 0;
  tl866_device *matches = NULL; size_t match_count = 0, match_capacity = 0;
  int result = 2;

  /* Device nodes include TL866 hardware even when it lacks MiniPro's driver. */
  usb = SetupDiGetClassDevsW(NULL, L"USB", NULL, DIGCF_PRESENT | DIGCF_ALLCLASSES);
  if (usb == INVALID_HANDLE_VALUE) goto cleanup;
  /* The separate interface set identifies bindings acceptable to pinned MiniPro. */
  interfaces = SetupDiGetClassDevsW(&guid, NULL, NULL, DIGCF_PRESENT | DIGCF_DEVICEINTERFACE);
  if (interfaces == INVALID_HANDLE_VALUE) goto cleanup;

  for (DWORD index = 0;; ++index) {
    SP_DEVICE_INTERFACE_DATA iface = { .cbSize = sizeof(iface) };
    SP_DEVINFO_DATA device = { .cbSize = sizeof(device) };
    if (!SetupDiEnumDeviceInterfaces(interfaces, NULL, &guid, index, &iface)) { if (GetLastError() == ERROR_NO_MORE_ITEMS) break; goto cleanup; }
    DWORD required = 0;
    if (SetupDiGetDeviceInterfaceDetailW(interfaces, &iface, NULL, 0, &required, &device) || GetLastError() != ERROR_INSUFFICIENT_BUFFER) goto cleanup;
    wchar_t *identity = instance_id(interfaces, &device);
    if (!identity || !append_instance(&ready, &ready_count, &ready_capacity, identity)) { HeapFree(GetProcessHeap(), 0, identity); goto cleanup; }
  }

  for (DWORD index = 0;; ++index) {
    SP_DEVINFO_DATA device = { .cbSize = sizeof(device) };
    if (!SetupDiEnumDeviceInfo(usb, index, &device)) { if (GetLastError() == ERROR_NO_MORE_ITEMS) break; goto cleanup; }
    DWORD bytes = 0;
    if (!SetupDiGetDeviceRegistryPropertyW(usb, &device, SPDRP_HARDWAREID, NULL, NULL, 0, &bytes)) {
      if (GetLastError() == ERROR_INVALID_DATA) continue;
      if (GetLastError() != ERROR_INSUFFICIENT_BUFFER || !bytes) goto cleanup;
    }
    wchar_t *ids = HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, bytes);
    if (!ids || !SetupDiGetDeviceRegistryPropertyW(usb, &device, SPDRP_HARDWAREID, NULL, (PBYTE)ids, bytes, NULL)) { HeapFree(GetProcessHeap(), 0, ids); goto cleanup; }
    int tl866 = is_tl866(ids, bytes); HeapFree(GetProcessHeap(), 0, ids);
    if (!tl866) continue;
    wchar_t *identity = instance_id(usb, &device);
    wchar_t *service = driver_service(usb, &device);
    if (!identity || !service || !append_device(&matches, &match_count, &match_capacity, identity, service, contains_instance(ready, ready_count, identity))) {
      HeapFree(GetProcessHeap(), 0, identity); HeapFree(GetProcessHeap(), 0, service); goto cleanup;
    }
  }

  printf("{\"count\":%u,\"devices\":[", (unsigned)match_count);
  for (size_t index = 0; index < match_count; ++index) {
    if (index) fputc(',', stdout);
    fputs("{\"vendorId\":\"04d8\",\"productId\":\"e11c\",\"identity\":", stdout); json_string(matches[index].identity);
    fputs(",\"interfaceReady\":", stdout); fputs(matches[index].interface_ready ? "true" : "false", stdout);
    fputs(",\"driverService\":", stdout); json_string(matches[index].service); fputc('}', stdout);
  }
  fputs("]}\n", stdout); result = 0;

cleanup:
  if (interfaces != INVALID_HANDLE_VALUE) SetupDiDestroyDeviceInfoList(interfaces);
  if (usb != INVALID_HANDLE_VALUE) SetupDiDestroyDeviceInfoList(usb);
  free_instances(ready, ready_count); free_devices(matches, match_count);
  if (result) fputs("{\"error\":\"SetupAPI probe failed\"}\n", stdout);
  return result;
}
