/*
 * SRAM destructive test engine for a local minipro fork.
 *
 * Copyright (C) 2026 Hirofumi Iwasaki
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Local change, 2026-09-16.  This is not a TL866CS hardware adapter.
 */

#ifndef MUSHA_MINIPRO_SRAM_TEST_H
#define MUSHA_MINIPRO_SRAM_TEST_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

enum mp_sram_status {
    MP_SRAM_STATUS_OK = 0,
    MP_SRAM_STATUS_CANCELLED,
    MP_SRAM_STATUS_IO_ERROR,
    MP_SRAM_STATUS_UNKNOWN,
};

enum mp_sram_result {
    MP_SRAM_RESULT_PASSED = 0,
    MP_SRAM_RESULT_CANCELLED,
    MP_SRAM_RESULT_INVALID_ARGUMENT,
    MP_SRAM_RESULT_BEGIN_FAILED,
    MP_SRAM_RESULT_IO_ERROR,
    MP_SRAM_RESULT_UNKNOWN_STATUS,
    MP_SRAM_RESULT_MISMATCH,
    MP_SRAM_RESULT_END_FAILED,
};

enum mp_sram_pattern {
    MP_SRAM_PATTERN_00 = 0,
    MP_SRAM_PATTERN_FF,
    MP_SRAM_PATTERN_55,
    MP_SRAM_PATTERN_AA,
    MP_SRAM_PATTERN_ADDRESS_LOW,
    MP_SRAM_PATTERN_ADDRESS_MID,
    MP_SRAM_PATTERN_ADDRESS_HIGH,
    MP_SRAM_PATTERN_ADDRESS_24,
    MP_SRAM_PATTERN_ADDRESS_32,
    MP_SRAM_PATTERN_ADDRESS_40,
    MP_SRAM_PATTERN_ADDRESS_48,
    MP_SRAM_PATTERN_ADDRESS_56,
    MP_SRAM_PATTERN_ADDRESS_XOR,
};

struct mp_sram_transfer {
    enum mp_sram_status status;
    size_t length;
};

struct mp_sram_callbacks {
    enum mp_sram_status (*begin)(void *context);
    struct mp_sram_transfer (*write)(void *context, uint64_t address,
        const uint8_t *bytes, size_t length);
    struct mp_sram_transfer (*read)(void *context, uint64_t address,
        uint8_t *bytes, size_t length);
    enum mp_sram_status (*end)(void *context);
    bool (*cancelled)(void *context);
};

struct mp_sram_report {
    enum mp_sram_result result;
    enum mp_sram_pattern pattern;
    uint64_t address;
    uint8_t expected;
    uint8_t actual;
    enum mp_sram_status begin_status;
    enum mp_sram_status transfer_status;
    enum mp_sram_status end_status;
};

/*
 * Destructively tests bytes [0, size).  Every pattern writes the complete
 * region before any comparison reads it.  `buffer` is caller-owned bounded
 * scratch space and must be non-null and non-zero length.  `report` may be
 * NULL.  Transfers must
 * return status OK and exactly the requested byte count.  Unknown statuses
 * and partial transfers are errors, never a pass.  `end` is called exactly
 * once after every attempted `begin`; adapters must make it safe after a
 * partial begin failure.
 */
enum mp_sram_result mp_sram_test(const struct mp_sram_callbacks *callbacks,
    void *context, uint64_t size, uint8_t *buffer, size_t buffer_length,
    struct mp_sram_report *report);

const char *mp_sram_result_string(enum mp_sram_result result);
const char *mp_sram_pattern_string(enum mp_sram_pattern pattern);

#endif
