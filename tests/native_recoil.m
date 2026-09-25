#include "../native/dualsense/bridge.m"
#include <assert.h>

@interface HIDRecorder : AHTriggerHID
@property NSData *lastReport;
@end
@implementation HIDRecorder
- (NSInteger)refresh { self.ready = YES; return 1; }
- (IOReturn)send:(float)strength kick:(BOOL)kick {
    uint8_t report[78];
    size_t length = trigger_report(report, false, 0, strength, kick);
    _lastReport = [NSData dataWithBytes:report length:length];
    return self.lastResult = kIOReturnSuccess;
}
@end

static void advance(double seconds) {
    [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:seconds]];
}
static void check_mode(HIDRecorder *hid, uint8_t right, uint8_t left) {
    const uint8_t *b = hid.lastReport.bytes;
    assert(b[11] == right && b[22] == left);
}
int main(void) {
    @autoreleasepool {
        AHTrigger *state = [AHTrigger new];
        HIDRecorder *hid = [HIDRecorder new];
        state.hid = hid;
        [state kick:1];
        double deadline = state.deadline;
        check_mode(hid, 0x06, 0x06);
        const uint8_t *b = hid.lastReport.bytes;
        assert(b[12] == 10 && b[13] == 255 && b[14] == 20);
        assert(memcmp(b + 11, b + 22, 11) == 0);
        advance(.1);
        [state kick:1];
        assert(state.deadline == deadline);
        check_mode(hid, 0x06, 0x06);
        advance(.2);
        check_mode(hid, 0x05, 0x05);
        [state kick:.5];
        b = hid.lastReport.bytes;
        assert(b[13] == 128 && b[24] == 128);
        [state bow:0];
        advance(.3);
        check_mode(hid, 0x05, 0x05);
        [state bow:1];
        check_mode(hid, 0x21, 0x05);
        advance(1.1);
        check_mode(hid, 0x05, 0x05);
        [state.watchdog invalidate];

        uint8_t report[78];
        assert(trigger_report(report, true, 2, 1, true) == 78);
        const uint8_t expected[] = {0x06, 10, 255, 20};
        assert(memcmp(report + 13, expected, 4) == 0);
        assert(memcmp(report + 24, expected, 4) == 0);
        // Same fixture as the WebHID test, computed independently with zlib.
        uint32_t crc = 0;
        for (int i = 0; i < 4; i++) crc |= (uint32_t)report[74+i] << (i*8);
        assert(crc == 0x9234cdb1);
        uint8_t input[78] = {0x31};
        input[49] = 0x11;
        [hid read:input length:78];
        assert(hid.reportedMode == 1);
        input[49] = 0;
        [hid read:input length:78];
        assert(hid.reportedMode == 0);
        puts("PASS: native direct vibration bytes, paired force, expiry, cancellation, heartbeat, CRC and input report parsing");
    }
    return 0;
}
