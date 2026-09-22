/* No-hardware fixture: includes the materialized MiniPro guard itself. */
#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif
#include <assert.h>
#include <string.h>

#define main minipro_unused_main_for_guard_fixture
#include "main.c"
#undef main

static cmdopts_t guarded(const char *model, const char *identity,
			 const char *firmware)
{
	cmdopts_t options;
	memset(&options, 0, sizeof(options));
	options.expected_model = (char *)model;
	options.expected_identity = (char *)identity;
	options.expected_firmware = (char *)firmware;
	return options;
}

static minipro_handle_t connected(uint8_t version, uint8_t status,
				  const char *firmware, const char *serial)
{
	minipro_handle_t handle;
	memset(&handle, 0, sizeof(handle));
	handle.version = version;
	handle.status = status;
	strncpy(handle.firmware_str, firmware, sizeof(handle.firmware_str) - 1);
	strncpy(handle.serial_number, serial, sizeof(handle.serial_number) - 1);
	return handle;
}

int main(void)
{
	cmdopts_t cs = guarded("tl866cs", "serial:CS-123", "03.2.86");
	minipro_handle_t handle = connected(MP_TL866CS, MP_STATUS_NORMAL,
		"03.2.86", "CS-123");
	assert(expected_programmer_matches(&handle, &cs));

	cmdopts_t a = guarded("tl866a", "serial:CS-123", "03.2.86");
	assert(!expected_programmer_matches(&handle, &a));
	handle.version = MP_TL866A;
	assert(expected_programmer_matches(&handle, &a));
	assert(!expected_programmer_matches(&handle, &cs));

	cmdopts_t ii = guarded("tl866ii", "serial:II-456", "04.1.01");
	handle = connected(MP_TL866IIPLUS, MP_STATUS_NORMAL, "04.1.01", "II-456");
	assert(expected_programmer_matches(&handle, &ii));

	cs = guarded("t48", "serial:II-456", "04.1.01");
	assert(!expected_programmer_matches(&handle, &cs));
	cs = guarded("tl866ii", "serial:other", "04.1.01");
	assert(!expected_programmer_matches(&handle, &cs));
	cs = guarded("tl866ii", "serial:II-456", "04.1.02");
	assert(!expected_programmer_matches(&handle, &cs));
	cs = guarded("tl866ii", NULL, "04.1.01");
	assert(!expected_programmer_matches(&handle, &cs));
	handle.status = MP_STATUS_BOOTLOADER;
	assert(!expected_programmer_matches(&handle, &ii));
	handle.status = MP_STATUS_NORMAL;
	handle.serial_number[0] = '\0';
	assert(!expected_programmer_matches(&handle, &ii));
	return 0;
}
