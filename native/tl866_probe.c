/* SPDX-License-Identifier: GPL-3.0-or-later */
/*
 * Read-only MiniPro-programmer enumerator. It deliberately never calls libusb_open(),
 * libusb_claim_interface(), or any transfer API, so it cannot address ZIF
 * pins, change programmer state, or read/write an IC.
 */

#include <libusb.h>
#include <stdio.h>

typedef struct {
  unsigned short vendor_id;
  unsigned short product_id;
} minipro_usb_id;

static const minipro_usb_id minipro_usb_ids[] = {
    {0x04d8, 0xe11c}, /* TL866A/CS */
    {0xa466, 0x0a53}, /* TL866II+, T48, T56 */
    {0xa466, 0x1a86}, /* T76 */
};

static int is_minipro_device(const struct libusb_device_descriptor *descriptor) {
  for (unsigned index = 0;
       index < sizeof(minipro_usb_ids) / sizeof(minipro_usb_ids[0]); ++index) {
    if (descriptor->idVendor == minipro_usb_ids[index].vendor_id &&
        descriptor->idProduct == minipro_usb_ids[index].product_id) return 1;
  }
  return 0;
}

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
    if (!is_minipro_device(&descriptor)) {
      continue;
    }
    matches++;
  }
  printf("%u,\"devices\":[", matches);

  unsigned emitted = 0;
  for (ssize_t index = 0; index < count; index++) {
    struct libusb_device_descriptor descriptor;
    if (libusb_get_device_descriptor(devices[index], &descriptor) !=
        LIBUSB_SUCCESS || !is_minipro_device(&descriptor)) {
      continue;
    }
    if (emitted++ != 0) {
      fputc(',', stdout);
    }
    printf("{\"vendorId\":\"%04x\",\"productId\":\"%04x\","
           "\"bus\":%u,\"address\":%u,\"identity\":\"usb:%u:%u\"}",
           descriptor.idVendor, descriptor.idProduct,
           libusb_get_bus_number(devices[index]),
           libusb_get_device_address(devices[index]),
           libusb_get_bus_number(devices[index]),
           libusb_get_device_address(devices[index]));
  }
  fputs("]}\n", stdout);
  libusb_free_device_list(devices, 1);
  libusb_exit(context);
  return 0;
}
