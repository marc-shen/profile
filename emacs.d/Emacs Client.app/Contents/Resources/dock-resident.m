// Keep the unified native daemon in the Dock after its last GUI frame closes.
#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>
#include <emacs-module.h>

int plugin_is_GPL_compatible;
typedef BOOL (*ResidentPolicySetter)(id, SEL, NSApplicationActivationPolicy);
static ResidentPolicySetter originalResidentSetter;
static BOOL residentEnabled;

static BOOL setResidentPolicy(NSApplication *app, SEL selector,
                              NSApplicationActivationPolicy policy) {
    if (residentEnabled) policy = NSApplicationActivationPolicyRegular;
    // Avoid repeating a policy assignment: AppKit can change focus even when
    // the requested policy is unchanged (e.g. completion child frames).
    if (policy == app.activationPolicy) return YES;
    return originalResidentSetter(app, selector, policy);
}

static emacs_value setResident(emacs_env *env, ptrdiff_t nargs,
                               emacs_value *args, void *data) {
    @autoreleasepool {
        BOOL enable = env->is_not_nil(env, args[0]);
        if (!enable) {
            residentEnabled = NO;
            return env->intern(env, "nil");
        }
        // Never instantiate NSApplication during early daemon initialization.
        if (!NSApp || ![NSThread isMainThread] ||
            ![[NSBundle mainBundle].bundleIdentifier isEqualToString:@"local.marcshen.emacs-client"])
            return env->intern(env, "nil");
        if (!originalResidentSetter) {
            Class cls = object_getClass(NSApp);
            if (cls == [NSApplication class]) return env->intern(env, "nil");
            SEL selector = @selector(setActivationPolicy:);
            Method method = class_getInstanceMethod(cls, selector);
            if (!method) return env->intern(env, "nil");
            originalResidentSetter = (ResidentPolicySetter)method_getImplementation(method);
            if (!class_addMethod(cls, selector, (IMP)setResidentPolicy,
                                 method_getTypeEncoding(method)))
                class_replaceMethod(cls, selector, (IMP)setResidentPolicy,
                                    method_getTypeEncoding(method));
        }
        residentEnabled = YES;
        // Covers loading this configuration into an already windowless daemon.
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
        return env->intern(env, "t");
    }
}

int emacs_module_init(struct emacs_runtime *runtime) {
    if (runtime->size < (ptrdiff_t)sizeof(*runtime)) return 1;
    emacs_env *env = runtime->get_environment(runtime);
    if (env->size < (ptrdiff_t)sizeof(*env)) return 2;
    emacs_value binding[] = {
        env->intern(env, "profile-macos-dock-resident"),
        env->make_function(env, 1, 1, setResident,
            "Keep the unified app in the Dock with non-nil ENABLE, including without windows.", NULL)
    };
    env->funcall(env, env->intern(env, "fset"), 2, binding);
    return env->non_local_exit_check(env) == emacs_funcall_exit_return ? 0 : 3;
}
