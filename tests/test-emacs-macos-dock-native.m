// clang -fobjc-arc -framework Cocoa -I <Emacs.app>/Contents/Resources/include
// No NSApplication is created: exercise policy interception without touching UI.
#include <assert.h>
#import "../emacs.d/Emacs Client.app/Contents/Resources/dock-policy.m"

@interface FakeDockApp : NSObject
@property NSApplicationActivationPolicy activationPolicy;
@property NSUInteger calls;
@end
@implementation FakeDockApp
@end

static BOOL fakeSetter(id receiver, SEL selector, NSApplicationActivationPolicy policy) {
    FakeDockApp *app = receiver;
    app.calls++;
    app.activationPolicy = policy;
    return YES;
}

int main(void) {
    @autoreleasepool {
        FakeDockApp *app = [FakeDockApp new];
        app.activationPolicy = NSApplicationActivationPolicyAccessory;
        originalSetter = fakeSetter;
        enabled = YES;
        SEL selector = @selector(setActivationPolicy:);
        for (NSUInteger i = 0; i < 5; ++i)
            assert(setDaemonPolicy((NSApplication *)app, selector,
                                   NSApplicationActivationPolicyRegular));
        assert(app.calls == 0 && policyChanges == 0 && blockedPromotions == 5);
        assert(app.activationPolicy == NSApplicationActivationPolicyAccessory);
        // Closing the last display must still be able to disable AppKit.
        assert(setDaemonPolicy((NSApplication *)app, selector,
                               NSApplicationActivationPolicyProhibited));
        assert(app.activationPolicy == NSApplicationActivationPolicyProhibited);
        // Reopening goes directly from prohibited to accessory, never regular.
        assert(setDaemonPolicy((NSApplication *)app, selector,
                               NSApplicationActivationPolicyRegular));
        assert(app.activationPolicy == NSApplicationActivationPolicyAccessory);
        assert(app.calls == 2 && policyChanges == 2);
        enabled = NO;
        assert(setDaemonPolicy((NSApplication *)app, selector,
                               NSApplicationActivationPolicyRegular));
        assert(app.activationPolicy == NSApplicationActivationPolicyRegular);
        assert(app.calls == 3 && policyChanges == 3);
        puts("Dock policy interception: all checks passed");
    }
}
