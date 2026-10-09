#import <Foundation/Foundation.h>
#include "hid_trigger.h"
#include <math.h>
#include "gdextension_interface.h"

static GDExtensionClassLibraryPtr library;
static GDExtensionInterfaceStringNameNewWithUtf8Chars make_name;
static GDExtensionInterfaceClassdbConstructObject2 construct;
static GDExtensionInterfaceObjectSetInstance set_instance;
static GDExtensionInterfaceClassdbRegisterExtensionClass4 register_class;
static GDExtensionInterfaceClassdbRegisterExtensionClassMethod register_method;
static GDExtensionInterfaceClassdbUnregisterExtensionClass unregister_class;
static GDExtensionVariantFromTypeConstructorFunc from_int;
static GDExtensionTypeFromVariantConstructorFunc to_float;
static GDExtensionPtrDestructor destroy_name;
static void *class_name, *parent_name;

@interface AHTrigger : NSObject
@property AHTriggerHID *hid;
@property NSInteger generation;
@property float strength;
@property BOOL kicking;
@property double deadline;
@property NSTimer *watchdog;
- (NSInteger)refresh;
- (void)bow:(float)strength;
- (void)kick:(float)strength;
@end

@implementation AHTrigger
- (instancetype)init {
    if ((self = [super init])) {
        _hid = [AHTriggerHID new];
        __weak AHTrigger *weak = self;
        _watchdog = [NSTimer scheduledTimerWithTimeInterval:.02 repeats:YES block:^(NSTimer *timer) {
            (void)timer;
            AHTrigger *state = weak;
            double now = NSProcessInfo.processInfo.systemUptime;
            if (now >= state.deadline) [state bow:0];

        }];
    }
    return self;
}
- (NSInteger)refresh {
    NSInteger count = [_hid refresh];
    if (_generation != _hid.generation) {
        _generation = _hid.generation;
        _strength = 0;
        _kicking = NO;
    }
    return count;
}
- (void)bow:(float)value {
    [self refresh];
    float strength = isfinite(value) ? fminf(1, fmaxf(0, value)) : 0;
    _deadline = NSProcessInfo.processInfo.systemUptime + 1;
    if (_strength == strength && !_kicking) return;
    _strength = strength;
    _kicking = NO;
    [_hid send:strength kick:NO];
}
- (void)kick:(float)value {
    [self refresh];
    float strength = isfinite(value) ? fminf(1, fmaxf(0, value)) : 0;
    if (strength == 0) { [self bow:0]; return; }
    if (_kicking && _strength == strength) return;
    _strength = strength;
    _kicking = YES;
    _deadline = NSProcessInfo.processInfo.systemUptime + .260;
    [_hid send:strength kick:YES];
}
- (void)dealloc {
    [_watchdog invalidate];
    [_hid send:0 kick:NO];
}
@end

static GDExtensionObjectPtr create(void *userdata, GDExtensionBool notify) {
    (void)userdata; (void)notify;
    GDExtensionObjectPtr owner = construct(&parent_name);
    AHTrigger *state = [AHTrigger new];
    set_instance(owner, &class_name, (__bridge_retained void *)state);
    return owner;
}
static void release_instance(void *userdata, GDExtensionClassInstancePtr instance) {
    (void)userdata;
    AHTrigger *state = CFBridgingRelease(instance);
    [state bow:0];
}
static int64_t invoke(intptr_t method, AHTrigger *state, double value) {
    switch (method) {
        case 0: return [state refresh];
        case 1: [state bow:(float)value]; return state.hid.lastResult;
        case 2: return state.hid.reportedMode;
        case 3: [state kick:(float)value]; return state.hid.lastResult;
        case 4: return state.hid.ready && state.hid.lastResult == kIOReturnSuccess;
        default: return -1;
    }
}
static void call(void *method, GDExtensionClassInstancePtr instance, const GDExtensionConstVariantPtr *args, GDExtensionInt count, GDExtensionVariantPtr result, GDExtensionCallError *error) {
    double value = 0;
    if (((intptr_t)method == 1 || (intptr_t)method == 3) && count == 1) to_float(&value, (GDExtensionVariantPtr)args[0]);
    int64_t answer = invoke((intptr_t)method, (__bridge AHTrigger *)instance, value);
    from_int(result, &answer);
    error->error = GDEXTENSION_CALL_OK;
}
static void ptrcall(void *method, GDExtensionClassInstancePtr instance, const GDExtensionConstTypePtr *args, GDExtensionTypePtr result) {
    *(int64_t *)result = invoke((intptr_t)method, (__bridge AHTrigger *)instance, ((intptr_t)method == 1 || (intptr_t)method == 3) ? *(const double *)args[0] : 0);
}
static void initialize(void *userdata, GDExtensionInitializationLevel level) {
    (void)userdata;
    if (level != GDEXTENSION_INITIALIZATION_SCENE) return;
    make_name(&class_name, "DualSenseBridge");
    make_name(&parent_name, "RefCounted");
    GDExtensionClassCreationInfo4 info = {0};
    info.is_exposed = 1;
    info.is_runtime = 1;
    info.create_instance_func = create;
    info.free_instance_func = release_instance;
    register_class(library, &class_name, &parent_name, &info);
    const char *names[] = {"controller_count", "bow", "reported_mode", "kick", "output_ready"};
    for (intptr_t i = 0; i < 5; ++i) {
        void *name = NULL, *empty = NULL, *hint = NULL, *argument_name = NULL;
        make_name(&name, names[i]);
        make_name(&empty, "");
        make_name(&argument_name, "strength");
        GDExtensionPropertyInfo result = {.type = GDEXTENSION_VARIANT_TYPE_INT, .name = &empty, .class_name = &empty, .hint_string = &hint};
        GDExtensionPropertyInfo argument = {.type = GDEXTENSION_VARIANT_TYPE_FLOAT, .name = &argument_name, .class_name = &empty, .hint_string = &hint};
        GDExtensionClassMethodArgumentMetadata metadata = GDEXTENSION_METHOD_ARGUMENT_METADATA_REAL_IS_DOUBLE;
        GDExtensionClassMethodInfo method = {0};
        method.name = &name;
        method.method_userdata = (void *)i;
        method.call_func = call;
        method.ptrcall_func = ptrcall;
        method.method_flags = GDEXTENSION_METHOD_FLAG_NORMAL;
        method.has_return_value = 1;
        method.return_value_info = &result;
        method.return_value_metadata = GDEXTENSION_METHOD_ARGUMENT_METADATA_INT_IS_INT64;
        method.argument_count = (i == 1 || i == 3) ? 1 : 0;
        method.arguments_info = &argument;
        method.arguments_metadata = &metadata;
        register_method(library, &class_name, &method);
        destroy_name(&name);
        destroy_name(&empty);
        destroy_name(&argument_name);
    }
}
static void deinitialize(void *userdata, GDExtensionInitializationLevel level) {
    (void)userdata;
    if (level != GDEXTENSION_INITIALIZATION_SCENE) return;
    unregister_class(library, &class_name);
    destroy_name(&class_name);
    destroy_name(&parent_name);
}
GDExtensionBool arrowhead_dualsense_init(GDExtensionInterfaceGetProcAddress get, GDExtensionClassLibraryPtr handle, GDExtensionInitialization *init) {
    library = handle;
    make_name = (GDExtensionInterfaceStringNameNewWithUtf8Chars)(void *)get("string_name_new_with_utf8_chars");
    construct = (GDExtensionInterfaceClassdbConstructObject2)(void *)get("classdb_construct_object2");
    set_instance = (GDExtensionInterfaceObjectSetInstance)(void *)get("object_set_instance");
    register_class = (GDExtensionInterfaceClassdbRegisterExtensionClass4)(void *)get("classdb_register_extension_class4");
    register_method = (GDExtensionInterfaceClassdbRegisterExtensionClassMethod)(void *)get("classdb_register_extension_class_method");
    unregister_class = (GDExtensionInterfaceClassdbUnregisterExtensionClass)(void *)get("classdb_unregister_extension_class");
    from_int = ((GDExtensionInterfaceGetVariantFromTypeConstructor)(void *)get("get_variant_from_type_constructor"))(GDEXTENSION_VARIANT_TYPE_INT);
    to_float = ((GDExtensionInterfaceGetVariantToTypeConstructor)(void *)get("get_variant_to_type_constructor"))(GDEXTENSION_VARIANT_TYPE_FLOAT);
    destroy_name = ((GDExtensionInterfaceVariantGetPtrDestructor)(void *)get("variant_get_ptr_destructor"))(GDEXTENSION_VARIANT_TYPE_STRING_NAME);
    init->minimum_initialization_level = GDEXTENSION_INITIALIZATION_SCENE;
    init->initialize = initialize;
    init->deinitialize = deinitialize;
    return 1;
}
