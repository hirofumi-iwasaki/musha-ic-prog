/* SPDX-License-Identifier: GPL-3.0-or-later */
/* Read-only TL866A/CS node and WinUSB binding probe. No device is opened. */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <setupapi.h>
#include <stdio.h>
#include <wchar.h>

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
  const wchar_t prefix[] = L"USB\\VID_04D8&PID_E11C";
  const size_t prefix_length = (sizeof(prefix) / sizeof(prefix[0])) - 1;
  const size_t count = bytes / sizeof(*ids);
  for (size_t offset = 0; offset < count && ids[offset];) {
    size_t length = 0;
    while (offset + length < count && ids[offset + length]) ++length;
    if (offset + length == count) return 0; /* Malformed MULTI_SZ. */
    if (length >= prefix_length &&
        _wcsnicmp(ids + offset, prefix, prefix_length) == 0 &&
        (length == prefix_length || ids[offset + prefix_length] == L'&')) return 1;
    offset += length + 1;
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

static void free_devices(tl866_device *items, size_t count) {
  for (size_t index = 0; index < count; ++index) { HeapFree(GetProcessHeap(), 0, items[index].identity); HeapFree(GetProcessHeap(), 0, items[index].service); }
  HeapFree(GetProcessHeap(), 0, items);
}

int main(void) {
  HDEVINFO usb = INVALID_HANDLE_VALUE;
  tl866_device *matches = NULL; size_t match_count = 0, match_capacity = 0;
  int result = 2;

  /* Device nodes include TL866 hardware even when it lacks MiniPro's driver. */
  usb = SetupDiGetClassDevsW(NULL, L"USB", NULL, DIGCF_PRESENT | DIGCF_ALLCLASSES);
  if (usb == INVALID_HANDLE_VALUE) goto cleanup;
  /* libusb discovers the interface GUID registered by the WinUSB installer.
   * It must not be constrained to the old vendor driver's interface GUID.
   * A WinUSB service is a prerequisite only; minipro performs the real open
   * and model check after this descriptor-only discovery step. */

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
    if (!identity || !service || !append_device(&matches, &match_count, &match_capacity, identity, service, _wcsicmp(service, L"WinUSB") == 0)) {
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
  if (usb != INVALID_HANDLE_VALUE) SetupDiDestroyDeviceInfoList(usb);
  free_devices(matches, match_count);
  if (result) fputs("{\"error\":\"SetupAPI probe failed\"}\n", stdout);
  return result;
}
