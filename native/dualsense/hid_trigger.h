#import <Foundation/Foundation.h>
#import <IOKit/hid/IOHIDManager.h>
#include "trigger_report.h"

@interface AHTriggerHID : NSObject {
    IOHIDManagerRef _manager;
    IOHIDDeviceRef _device;
    uint8_t _input[1024];
    uint8_t _sequence;
    BOOL _bluetooth;
}
@property BOOL ready;
@property NSInteger generation;
@property NSInteger reportedMode;
@property IOReturn lastResult;
- (NSInteger)refresh;
- (IOReturn)send:(float)strength kick:(BOOL)kick;
- (void)read:(const uint8_t *)report length:(CFIndex)length;
@end

static void trigger_input(void *context, IOReturn result, void *sender, IOHIDReportType type, uint32_t reportID, uint8_t *report, CFIndex length) {
    (void)sender; (void)type; (void)reportID;
    if (result == kIOReturnSuccess) [(__bridge AHTriggerHID *)context read:report length:length];
}

@implementation AHTriggerHID
- (instancetype)init {
    if ((self = [super init])) {
        _reportedMode = -1;
        _manager = IOHIDManagerCreate(kCFAllocatorDefault, 0);
        NSArray *matches = @[
            @{@kIOHIDVendorIDKey:@0x054c, @kIOHIDProductIDKey:@0x0ce6},
            @{@kIOHIDVendorIDKey:@0x054c, @kIOHIDProductIDKey:@0x0df2}
        ];
        IOHIDManagerSetDeviceMatchingMultiple(_manager, (__bridge CFArrayRef)matches);
        IOHIDManagerScheduleWithRunLoop(_manager, CFRunLoopGetMain(), kCFRunLoopCommonModes);
        _lastResult = IOHIDManagerOpen(_manager, kIOHIDOptionsTypeNone);
    }
    return self;
}
- (void)closeDevice {
    if (!_device) return;
    [self send:0 kick:NO];
    IOHIDDeviceRegisterInputReportCallback(_device, _input, sizeof(_input), NULL, NULL);
    IOHIDDeviceUnscheduleFromRunLoop(_device, CFRunLoopGetMain(), kCFRunLoopCommonModes);
    IOHIDDeviceClose(_device, 0);
    CFRelease(_device);
    _device = NULL;
    _ready = NO;
}
- (NSInteger)refresh {
    NSSet *devices = CFBridgingRelease(IOHIDManagerCopyDevices(_manager));
    IOHIDDeviceRef next = devices.count == 1 ? (__bridge IOHIDDeviceRef)devices.anyObject : NULL;
    if (next != _device) {
        [self closeDevice];
        _generation++;
        _reportedMode = -1;
        if (next) {
            _device = (IOHIDDeviceRef)CFRetain(next);
            _lastResult = IOHIDDeviceOpen(_device, kIOHIDOptionsTypeNone);
            _ready = _lastResult == kIOReturnSuccess;
            NSString *transport = (__bridge NSString *)IOHIDDeviceGetProperty(_device, CFSTR(kIOHIDTransportKey));
            _bluetooth = [transport isEqualToString:@"Bluetooth"];
            _sequence = 0;
            if (_ready) {
                IOHIDDeviceRegisterInputReportCallback(_device, _input, sizeof(_input), trigger_input, (__bridge void *)self);
                IOHIDDeviceScheduleWithRunLoop(_device, CFRunLoopGetMain(), kCFRunLoopCommonModes);
                [self send:0 kick:NO];
            }
        }
    }
    return (NSInteger)devices.count;
}
- (IOReturn)send:(float)strength kick:(BOOL)kick {
    if (!_device || !_ready) return _lastResult = kIOReturnNotOpen;
    uint8_t report[78];
    size_t length = trigger_report(report, _bluetooth, _sequence++, strength, kick);
    _lastResult = IOHIDDeviceSetReport(_device, kIOHIDReportTypeOutput, report[0], report, length);
    return _lastResult;
}
- (void)read:(const uint8_t *)report length:(CFIndex)length {
    if (length <= 0) return;
    int offset = report[0] == 0x31 ? 2 : 1;
    if ((report[0] == 0x31 || report[0] == 0x01) && length > offset + 47)
        _reportedMode = report[offset + 47] & 15;
}
- (void)dealloc {
    [self closeDevice];
    IOHIDManagerUnscheduleFromRunLoop(_manager, CFRunLoopGetMain(), kCFRunLoopCommonModes);
    IOHIDManagerClose(_manager, 0);
    CFRelease(_manager);
}
@end
