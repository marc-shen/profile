// Prevent Emacs NS frame creation from promoting a daemon into a Dock app.
// Loaded only by the macOS daemon configuration; never activates any window.
#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>
#include <emacs-module.h>

int plugin_is_GPL_compatible;

typedef BOOL (*PolicySetter)(id, SEL, NSApplicationActivationPolicy);
static PolicySetter originalSetter;
static BOOL enabled;
static NSUInteger blockedPromotions;
static NSUInteger policyChanges;

static BOOL setDaemonPolicy(NSApplication *app, SEL selector,
                            NSApplicationActivationPolicy policy) {
    if (enabled && policy == NSApplicationActivationPolicyRegular) {
        ++blockedPromotions;
        policy = NSApplicationActivationPolicyAccessory;
    }
    // Even assigning the same policy can have AppKit side effects.
    if (policy == app.activationPolicy) return YES;
    ++policyChanges;
    return originalSetter(app, selector, policy);
}

static emacs_value signalError(emacs_env *env, const char *message) {
    emacs_value text = env->make_string(env, message, strlen(message));
    emacs_value data = env->funcall(env, env->intern(env, "list"), 1, &text);
    env->non_local_exit_signal(env, env->intern(env, "error"), data);
    return env->intern(env, "nil");
}

static emacs_value setEnabled(emacs_env *env, ptrdiff_t nargs,
                              emacs_value *args, void *data) {
    @autoreleasepool {
        if (![NSThread isMainThread])
            return signalError(env, "Dock policy guard requires the application main thread");
        if (env->is_not_nil(env, args[0]) && !originalSetter) {
            // Add an override to EmacsApp, not to AppKit's NSApplication class.
            // A fresh daemon has no NSApp yet. The linked EmacsApp class is
            // available before its first instance, so protect the first frame too.
            Class cls = NSApp ? object_getClass(NSApp) : NSClassFromString(@"EmacsApp");
            if (!cls || cls == [NSApplication class])
                return signalError(env, "Expected an Emacs NSApplication subclass");
            SEL selector = @selector(setActivationPolicy:);
            Method method = class_getInstanceMethod(cls, selector);
            if (!method)
                return signalError(env, "NSApplication has no activation policy setter");
            originalSetter = (PolicySetter)method_getImplementation(method);
            if (!class_addMethod(cls, selector, (IMP)setDaemonPolicy,
                                 method_getTypeEncoding(method)))
                class_replaceMethod(cls, selector, (IMP)setDaemonPolicy,
                                    method_getTypeEncoding(method));
        }
        enabled = env->is_not_nil(env, args[0]);
        if (enabled && NSApp)
            [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
        return env->intern(env, enabled ? "t" : "nil");
    }
}

static emacs_value status(emacs_env *env, ptrdiff_t nargs,
                          emacs_value *args, void *data) {
    emacs_value values[] = {
        env->intern(env, ":enabled"), env->intern(env, enabled ? "t" : "nil"),
        env->intern(env, ":policy"), env->make_integer(env, NSApp ? NSApp.activationPolicy : -1),
        env->intern(env, ":blocked-promotions"), env->make_integer(env, blockedPromotions),
        env->intern(env, ":policy-changes"), env->make_integer(env, policyChanges)
    };
    return env->funcall(env, env->intern(env, "list"), 8, values);
}

int emacs_module_init(struct emacs_runtime *runtime) {
    if (runtime->size < (ptrdiff_t)sizeof(*runtime)) return 1;
    emacs_env *env = runtime->get_environment(runtime);
    if (env->size < (ptrdiff_t)sizeof(*env)) return 2;
    emacs_value binding[] = {
        env->intern(env, "profile-macos-dock-guard"),
        env->make_function(env, 1, 1, setEnabled,
            "Enable the daemon's stable accessory policy with non-nil ENABLE.\n"
            "Nil allows later policy requests through; it does not activate Emacs.", NULL)
    };
    env->funcall(env, env->intern(env, "fset"), 2, binding);
    binding[0] = env->intern(env, "profile-macos-dock-guard-status");
    binding[1] = env->make_function(env, 0, 0, status,
        "Return guard state and native policy counters for regression checks.", NULL);
    env->funcall(env, env->intern(env, "fset"), 2, binding);
    return env->non_local_exit_check(env) == emacs_funcall_exit_return ? 0 : 3;
}
