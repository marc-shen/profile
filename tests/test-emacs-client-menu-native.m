#include <assert.h>
#import "../emacs.d/Emacs Client.app/Contents/Resources/client-menu.m"

int main(void) {
    @autoreleasepool {
        NSMenu *menu = [NSMenu new];
        NSMenuItem *native = [menu addItemWithTitle:@"New Frame"
            action:NSSelectorFromString(@"newFrame:") keyEquivalent:@""];
        ProfileClientActions *actions = [ProfileClientActions new];
        configureClientMenu(menu, actions);
        configureClientMenu(menu, actions);
        assert(menu.numberOfItems == 1);
        assert([menu itemWithTag:19428] == native);
        assert(native.target == actions);
        assert(native.action == @selector(openClientFrame:));
        assert(native.enabled);
        NSMenu *empty = [NSMenu new];
        configureClientMenu(empty, actions);
        configureClientMenu(empty, actions);
        assert(empty.numberOfItems == 1);
        assert([empty itemWithTag:19428].action == @selector(openClientFrame:));
        puts("Dock New Frame routing: all checks passed");
    }
}
