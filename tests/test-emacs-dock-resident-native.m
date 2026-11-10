#include <assert.h>
#import "../emacs.d/Emacs Client.app/Contents/Resources/dock-resident.m"

@interface FakeResidentApp : NSObject
@property NSApplicationActivationPolicy activationPolicy;
@property NSUInteger calls;
@end
@implementation FakeResidentApp
@end
static BOOL fakeSetter(id receiver, SEL selector, NSApplicationActivationPolicy policy) {
    FakeResidentApp *app = receiver;
    app.calls++;
    app.activationPolicy = policy;
    return YES;
}
int main(void) {
    @autoreleasepool {
        FakeResidentApp *app = [FakeResidentApp new];
        app.activationPolicy = NSApplicationActivationPolicyProhibited;
        originalResidentSetter = fakeSetter;
        residentEnabled = YES;
        SEL setter = @selector(setActivationPolicy:);
        assert(setResidentPolicy((NSApplication *)app, setter, NSApplicationActivationPolicyRegular));
        assert(app.activationPolicy == NSApplicationActivationPolicyRegular && app.calls == 1);
        // Last-window close, old hiding hooks, and repeated child frame creation
        // must all leave the app Regular without invoking AppKit again.
        for (NSInteger policy = 0; policy <= 2; policy++)
            assert(setResidentPolicy((NSApplication *)app, setter, policy));
        assert(app.activationPolicy == NSApplicationActivationPolicyRegular && app.calls == 1);
        residentEnabled = NO;
        assert(setResidentPolicy((NSApplication *)app, setter, NSApplicationActivationPolicyProhibited));
        assert(app.activationPolicy == NSApplicationActivationPolicyProhibited && app.calls == 2);
        puts("Resident Dock policy: all checks passed");
    }
}
