#ifndef ARROWHEAD_TRIGGER_REPORT_H
#define ARROWHEAD_TRIGGER_REPORT_H
#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include <string.h>
#include <math.h>

// Output framing: libsdl-org/SDL's PS5 HID driver. Trigger 0x06 parameters:
// daidr/dualsense-tester, TriggerEffect.vue (frequency, force, start position).
static size_t trigger_report(uint8_t report[78], bool bluetooth, uint8_t sequence, float value, bool kick) {
    float strength = isfinite(value) ? fminf(1, fmaxf(0, value)) : 0;
    memset(report, 0, 78);
    const size_t offset = bluetooth ? 3 : 1;
    report[0] = bluetooth ? 0x31 : 0x02;
    if (bluetooth) { report[1] = (sequence & 15) << 4; report[2] = 0x10; }
    report[offset] = 0x0c;
    uint8_t *right = report + offset + 10, *left = right + 11;
    right[0] = left[0] = 0x05;
    if (strength > 0 && kick) {
        uint8_t force = (uint8_t)roundf(strength * 255);
        if (force) {
            right[0] = 0x06; right[1] = 10; right[2] = force; right[3] = 20;
            memcpy(left, right, 11);
        }
    } else if (strength > 0) {
        const float curve[10] = {0, .375, .5, .625, .75, .875, 1, 1, 1, 1};
        uint16_t mask = 0;
        uint32_t forces = 0;
        for (int i = 0; i < 10; ++i) {
            uint8_t force = (uint8_t)roundf(curve[i] * strength * 8);
            if (force) { mask |= 1 << i; forces |= (uint32_t)(force - 1) << (i * 3); }
        }
        if (mask) {
            right[0] = 0x21;
            right[1] = mask & 255; right[2] = mask >> 8;
            for (int i = 0; i < 4; ++i) right[3 + i] = (forces >> (i * 8)) & 255;
        }
    }
    if (bluetooth) {
        uint32_t crc = 0xffffffff;
        for (int i = -1; i < 74; ++i) {
            crc ^= i < 0 ? 0xa2 : report[i];
            for (int bit = 0; bit < 8; ++bit) crc = (crc >> 1) ^ ((crc & 1) ? 0xedb88320 : 0);
        }
        crc = ~crc;
        for (int i = 0; i < 4; ++i) report[74 + i] = (crc >> (8 * i)) & 255;
    }
    return bluetooth ? 78 : 48;
}
#endif
