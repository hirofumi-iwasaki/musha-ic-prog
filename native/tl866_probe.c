/* SPDX-License-Identifier: GPL-3.0-or-later */
/*
 * Read-only TL866CS enumerator. It deliberately never calls libusb_open(),
 * libusb_claim_interface(), or any transfer API, so it cannot address ZIF
 * pins, change programmer state, or read/write an IC.
 */

#include <libusb.h>
#include <stdio.h>

#define TL866_VENDOR_ID 0x04d8
#define TL866_PRODUCT_ID 0xe11c

int main(void) {
  libusb_context *context = NULL;
  libusb_device **devices = NULL;
  int result = libusb_init(&context);
  if (result != LIBUSB_SUCCESS) {
    fprintf(stderr, "libusb_init failed: %s\n", libusb_error_name(result));
    return 2;
  }

  const ssize_t count = libusb_get_device_list(context, &devices);
  if (count < 0) {
    fprintf(stderr, "libusb_get_device_list failed: %s\n",
            libusb_error_name((int)count));
    libusb_exit(context);
    return 2;
  }

  unsigned matches = 0;
  fputs("{\"count\":", stdout);
  for (ssize_t index = 0; index < count; index++) {
    struct libusb_device_descriptor descriptor;
    if (libusb_get_device_descriptor(devices[index], &descriptor) !=
        LIBUSB_SUCCESS) {
      continue;
    }
    if (descriptor.idVendor != TL866_VENDOR_ID ||
        descriptor.idProduct != TL866_PRODUCT_ID) {
      continue;
    }
    matches++;
  }
  printf("%u,\"devices\":[", matches);

  unsigned emitted = 0;
  for (ssize_t index = 0; index < count; index++) {
    struct libusb_device_descriptor descriptor;
    if (libusb_get_device_descriptor(devices[index], &descriptor) !=
            LIBUSB_SUCCESS ||
        descriptor.idVendor != TL866_VENDOR_ID ||
        descriptor.idProduct != TL866_PRODUCT_ID) {
      continue;
    }
    if (emitted++ != 0) {
      fputc(',', stdout);
    }
    printf("{\"vendorId\":\"04d8\",\"productId\":\"e11c\","
           "\"bus\":%u,\"address\":%u}",
           libusb_get_bus_number(devices[index]),
           libusb_get_device_address(devices[index]));
  }
  fputs("]}\n", stdout);
  libusb_free_device_list(devices, 1);
  libusb_exit(context);
  return 0;
}
