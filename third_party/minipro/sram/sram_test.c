/*
 * SRAM destructive test engine for a local minipro fork.
 *
 * Copyright (C) 2026 Hirofumi Iwasaki
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Local change, 2026-09-16.
 */

#include "sram_test.h"

#include <string.h>

static void set_report(struct mp_sram_report *report, enum mp_sram_result result,
    enum mp_sram_pattern pattern, uint64_t address, uint8_t expected,
    uint8_t actual)
{
    if (report == NULL)
        return;
    report->result = result;
    report->pattern = pattern;
    report->address = address;
    report->expected = expected;
    report->actual = actual;
}

static uint8_t expected_byte(enum mp_sram_pattern pattern, uint64_t address)
{
    switch (pattern) {
    case MP_SRAM_PATTERN_00: return 0x00;
    case MP_SRAM_PATTERN_FF: return 0xff;
    case MP_SRAM_PATTERN_55: return 0x55;
    case MP_SRAM_PATTERN_AA: return 0xaa;
    case MP_SRAM_PATTERN_ADDRESS_LOW: return (uint8_t)address;
    case MP_SRAM_PATTERN_ADDRESS_MID: return (uint8_t)(address >> 8);
    case MP_SRAM_PATTERN_ADDRESS_HIGH: return (uint8_t)(address >> 16);
    case MP_SRAM_PATTERN_ADDRESS_24: return (uint8_t)(address >> 24);
    case MP_SRAM_PATTERN_ADDRESS_32: return (uint8_t)(address >> 32);
    case MP_SRAM_PATTERN_ADDRESS_40: return (uint8_t)(address >> 40);
    case MP_SRAM_PATTERN_ADDRESS_48: return (uint8_t)(address >> 48);
    case MP_SRAM_PATTERN_ADDRESS_56: return (uint8_t)(address >> 56);
    case MP_SRAM_PATTERN_ADDRESS_XOR:
        return (uint8_t)(address ^ (address >> 8) ^ (address >> 16) ^
            (address >> 24) ^ (address >> 32) ^ (address >> 40) ^
            (address >> 48) ^ (address >> 56));
    }
    return 0;
}

static enum mp_sram_result status_result(enum mp_sram_status status)
{
    if (status == MP_SRAM_STATUS_CANCELLED)
        return MP_SRAM_RESULT_CANCELLED;
    if (status == MP_SRAM_STATUS_UNKNOWN)
        return MP_SRAM_RESULT_UNKNOWN_STATUS;
    return MP_SRAM_RESULT_IO_ERROR;
}

static bool is_cancelled(const struct mp_sram_callbacks *callbacks, void *context)
{
    return callbacks->cancelled != NULL && callbacks->cancelled(context);
}

static enum mp_sram_result fill_and_write(const struct mp_sram_callbacks *callbacks,
    void *context, enum mp_sram_pattern pattern, uint64_t size, uint8_t *buffer,
    size_t buffer_length, struct mp_sram_report *report)
{
    uint64_t address;
    size_t count;
    struct mp_sram_transfer transfer;

    for (address = 0; address < size; address += count) {
        if (is_cancelled(callbacks, context))
            return MP_SRAM_RESULT_CANCELLED;
        count = buffer_length;
        if (size - address < count)
            count = (size_t)(size - address);
        for (size_t index = 0; index < count; ++index)
            buffer[index] = expected_byte(pattern, address + index);
        transfer = callbacks->write(context, address, buffer, count);
        report->transfer_status = transfer.status;
        if (transfer.status != MP_SRAM_STATUS_OK)
            return status_result(transfer.status);
        if (transfer.length != count)
            return MP_SRAM_RESULT_IO_ERROR;
    }
    return MP_SRAM_RESULT_PASSED;
}

static enum mp_sram_result read_and_compare(const struct mp_sram_callbacks *callbacks,
    void *context, enum mp_sram_pattern pattern, uint64_t size, uint8_t *buffer,
    size_t buffer_length, struct mp_sram_report *report)
{
    uint64_t address;
    size_t count;
    struct mp_sram_transfer transfer;

    for (address = 0; address < size; address += count) {
        if (is_cancelled(callbacks, context))
            return MP_SRAM_RESULT_CANCELLED;
        count = buffer_length;
        if (size - address < count)
            count = (size_t)(size - address);
        transfer = callbacks->read(context, address, buffer, count);
        report->transfer_status = transfer.status;
        if (transfer.status != MP_SRAM_STATUS_OK)
            return status_result(transfer.status);
        if (transfer.length != count)
            return MP_SRAM_RESULT_IO_ERROR;
        for (size_t index = 0; index < count; ++index) {
            uint8_t expected = expected_byte(pattern, address + index);
            if (buffer[index] != expected) {
                set_report(report, MP_SRAM_RESULT_MISMATCH, pattern, address + index,
                    expected, buffer[index]);
                return MP_SRAM_RESULT_MISMATCH;
            }
        }
    }
    return MP_SRAM_RESULT_PASSED;
}

enum mp_sram_result mp_sram_test(const struct mp_sram_callbacks *callbacks,
    void *context, uint64_t size, uint8_t *buffer, size_t buffer_length,
    struct mp_sram_report *report)
{
    enum mp_sram_result result = MP_SRAM_RESULT_PASSED;
    enum mp_sram_status begin_status;
    enum mp_sram_status end_status;
    struct mp_sram_report local_report;

    if (report == NULL)
        report = &local_report;
    memset(report, 0, sizeof(*report));
    if (callbacks == NULL || callbacks->begin == NULL || callbacks->write == NULL ||
        callbacks->read == NULL || callbacks->end == NULL || buffer == NULL ||
        buffer_length == 0 || size == 0) {
        set_report(report, MP_SRAM_RESULT_INVALID_ARGUMENT, MP_SRAM_PATTERN_00, 0, 0, 0);
        return MP_SRAM_RESULT_INVALID_ARGUMENT;
    }

    begin_status = callbacks->begin(context);
    report->begin_status = begin_status;
    if (begin_status != MP_SRAM_STATUS_OK) {
        end_status = callbacks->end(context);
        report->end_status = end_status;
        result = MP_SRAM_RESULT_BEGIN_FAILED;
        set_report(report, result, MP_SRAM_PATTERN_00, 0, 0, 0);
        return result;
    }

    for (enum mp_sram_pattern pattern = MP_SRAM_PATTERN_00;
         pattern <= MP_SRAM_PATTERN_ADDRESS_XOR; ++pattern) {
        report->pattern = pattern;
        result = fill_and_write(callbacks, context, pattern, size, buffer, buffer_length,
            report);
        if (result != MP_SRAM_RESULT_PASSED)
            break;
        result = read_and_compare(callbacks, context, pattern, size, buffer, buffer_length,
            report);
        if (result != MP_SRAM_RESULT_PASSED)
            break;
    }

    end_status = callbacks->end(context);
    report->end_status = end_status;
    if (result == MP_SRAM_RESULT_PASSED && end_status != MP_SRAM_STATUS_OK)
        result = MP_SRAM_RESULT_END_FAILED;
    set_report(report, result, report->pattern, report->address, report->expected,
        report->actual);
    return result;
}

const char *mp_sram_result_string(enum mp_sram_result result)
{
    static const char *const names[] = { "passed", "cancelled", "invalid argument",
        "begin failed", "I/O error", "unknown status", "mismatch", "end failed" };
    return result >= MP_SRAM_RESULT_PASSED && result <= MP_SRAM_RESULT_END_FAILED
        ? names[result] : "unknown result";
}

const char *mp_sram_pattern_string(enum mp_sram_pattern pattern)
{
    static const char *const names[] = { "00", "ff", "55", "aa", "address-low",
        "address-mid", "address-high", "address-24", "address-32", "address-40",
        "address-48", "address-56", "address-xor" };
    return pattern >= MP_SRAM_PATTERN_00 && pattern <= MP_SRAM_PATTERN_ADDRESS_XOR
        ? names[pattern] : "unknown pattern";
}
