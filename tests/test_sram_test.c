/* Mock coverage for the local GPL-3.0-or-later minipro SRAM engine. */
#include "../third_party/minipro/sram/sram_test.h"

#include <assert.h>
#include <stdio.h>
#include <string.h>

enum { RAM_SIZE = 131072 };

struct mock_ram {
    uint8_t bytes[RAM_SIZE];
    unsigned begin_count;
    unsigned end_count;
    bool active;
    bool cancel;
    uint64_t cancel_after;
    uint64_t operations;
    uint64_t alias_mask;
    uint8_t stuck_low_mask;
    int fail_read;
    int fail_write;
    bool short_read;
    bool unknown_write;
    enum mp_sram_status begin_status;
    enum mp_sram_status end_status;
};

static enum mp_sram_status mock_begin(void *opaque)
{
    struct mock_ram *ram = opaque;
    ++ram->begin_count;
    if (ram->begin_status == MP_SRAM_STATUS_OK)
        ram->active = true;
    return ram->begin_status;
}

static struct mp_sram_transfer mock_write(void *opaque, uint64_t address,
    const uint8_t *bytes, size_t length)
{
    struct mock_ram *ram = opaque;
    if (!ram->active || ram->fail_write)
        return (struct mp_sram_transfer){ MP_SRAM_STATUS_IO_ERROR, 0 };
    if (ram->unknown_write)
        return (struct mp_sram_transfer){ MP_SRAM_STATUS_UNKNOWN, 0 };
    for (size_t i = 0; i < length; ++i)
        ram->bytes[(address + i) & ram->alias_mask] = bytes[i];
    ram->operations += length;
    if (ram->short_read)
        return (struct mp_sram_transfer){ MP_SRAM_STATUS_OK, length - 1 };
    return (struct mp_sram_transfer){ MP_SRAM_STATUS_OK, length };
}

static struct mp_sram_transfer mock_read(void *opaque, uint64_t address,
    uint8_t *bytes, size_t length)
{
    struct mock_ram *ram = opaque;
    if (!ram->active || ram->fail_read)
        return (struct mp_sram_transfer){ MP_SRAM_STATUS_IO_ERROR, 0 };
    for (size_t i = 0; i < length; ++i)
        bytes[i] = (uint8_t)(ram->bytes[(address + i) & ram->alias_mask] &
            (uint8_t)~ram->stuck_low_mask);
    ram->operations += length;
    return (struct mp_sram_transfer){ MP_SRAM_STATUS_OK, length };
}

static enum mp_sram_status mock_end(void *opaque)
{
    struct mock_ram *ram = opaque;
    ++ram->end_count;
    ram->active = false;
    return ram->end_status;
}

static bool mock_cancelled(void *opaque)
{
    struct mock_ram *ram = opaque;
    return ram->cancel || (ram->cancel_after != 0 && ram->operations >= ram->cancel_after);
}

static const struct mp_sram_callbacks callbacks = {
    .begin = mock_begin, .write = mock_write, .read = mock_read,
    .end = mock_end, .cancelled = mock_cancelled,
};

static struct mock_ram fresh_ram(void)
{
    return (struct mock_ram){ .alias_mask = RAM_SIZE - 1,
        .begin_status = MP_SRAM_STATUS_OK, .end_status = MP_SRAM_STATUS_OK };
}

static void test_passes_and_holds_one_session(void)
{
    struct mock_ram ram = fresh_ram();
    struct mp_sram_report report;
    uint8_t scratch[257];
    assert(mp_sram_test(&callbacks, &ram, RAM_SIZE, scratch, sizeof(scratch), &report)
        == MP_SRAM_RESULT_PASSED);
    assert(ram.begin_count == 1 && ram.end_count == 1 && !ram.active);
    assert(report.end_status == MP_SRAM_STATUS_OK);
}

static void test_stuck_data_fault_reports_value(void)
{
    struct mock_ram ram = fresh_ram();
    struct mp_sram_report report;
    uint8_t scratch[64];
    ram.stuck_low_mask = 0x01;
    assert(mp_sram_test(&callbacks, &ram, RAM_SIZE, scratch, sizeof(scratch), &report)
        == MP_SRAM_RESULT_MISMATCH);
    assert(report.expected == 0xff && report.actual == 0xfe);
    assert(ram.end_count == 1);
}

static void test_high_address_alias_is_detected(void)
{
    struct mock_ram ram = fresh_ram();
    struct mp_sram_report report;
    uint8_t scratch[513];
    /* A16 is shorted: this would evade a test that only varies the low byte. */
    ram.alias_mask = 0xffff;
    assert(mp_sram_test(&callbacks, &ram, RAM_SIZE, scratch, sizeof(scratch), &report)
        == MP_SRAM_RESULT_MISMATCH);
    assert(report.pattern == MP_SRAM_PATTERN_ADDRESS_HIGH);
    /* The collision becomes visible when the lower half is read back. */
    assert(report.address < 0x10000 && report.expected == 0 && report.actual == 1);
}

static void test_cancel_and_io_error_cleanup(void)
{
    struct mock_ram cancelled = fresh_ram();
    struct mock_ram io_error = fresh_ram();
    struct mp_sram_report report;
    uint8_t scratch[64];
    cancelled.cancel_after = 100;
    assert(mp_sram_test(&callbacks, &cancelled, RAM_SIZE, scratch, sizeof(scratch), &report)
        == MP_SRAM_RESULT_CANCELLED);
    assert(cancelled.begin_count == 1 && cancelled.end_count == 1);
    io_error.fail_read = 1;
    assert(mp_sram_test(&callbacks, &io_error, RAM_SIZE, scratch, sizeof(scratch), &report)
        == MP_SRAM_RESULT_IO_ERROR);
    assert(io_error.begin_count == 1 && io_error.end_count == 1);
}

static void test_begin_failure_never_ends_and_end_failure_is_reported(void)
{
    struct mock_ram begin_failed = fresh_ram();
    struct mock_ram end_failed = fresh_ram();
    struct mock_ram invalid = fresh_ram();
    struct mp_sram_report report;
    uint8_t scratch[64];
    begin_failed.begin_status = MP_SRAM_STATUS_UNKNOWN;
    assert(mp_sram_test(&callbacks, &begin_failed, 16, scratch, sizeof(scratch), &report)
        == MP_SRAM_RESULT_BEGIN_FAILED);
    assert(begin_failed.begin_count == 1 && begin_failed.end_count == 1);
    end_failed.end_status = MP_SRAM_STATUS_IO_ERROR;
    assert(mp_sram_test(&callbacks, &end_failed, 16, scratch, sizeof(scratch), &report)
        == MP_SRAM_RESULT_END_FAILED);
    assert(end_failed.end_count == 1);
    assert(mp_sram_test(&callbacks, &invalid, 0, scratch, sizeof(scratch), NULL)
        == MP_SRAM_RESULT_INVALID_ARGUMENT);
}

static void test_unknown_and_short_transfers_fail_closed(void)
{
    struct mock_ram unknown = fresh_ram();
    struct mock_ram short_read = fresh_ram();
    uint8_t scratch[64];
    unknown.unknown_write = true;
    assert(mp_sram_test(&callbacks, &unknown, 16, scratch, sizeof(scratch), NULL)
        == MP_SRAM_RESULT_UNKNOWN_STATUS);
    assert(unknown.end_count == 1);
    short_read.short_read = true;
    assert(mp_sram_test(&callbacks, &short_read, 16, scratch, sizeof(scratch), NULL)
        == MP_SRAM_RESULT_IO_ERROR);
    assert(short_read.end_count == 1);
}

static void test_invalid_enum_strings_are_safe(void)
{
    assert(strcmp(mp_sram_result_string((enum mp_sram_result)-1), "unknown result") == 0);
    assert(strcmp(mp_sram_pattern_string((enum mp_sram_pattern)-1), "unknown pattern") == 0);
}

int main(void)
{
    test_passes_and_holds_one_session();
    test_stuck_data_fault_reports_value();
    test_high_address_alias_is_detected();
    test_cancel_and_io_error_cleanup();
    test_begin_failure_never_ends_and_end_failure_is_reported();
    test_unknown_and_short_transfers_fail_closed();
    test_invalid_enum_strings_are_safe();
    puts("test_sram_test: all tests passed");
    return 0;
}
