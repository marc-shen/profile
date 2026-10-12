#import <Cocoa/Cocoa.h>

// This process owns the Dock tile; Emacs itself remains a separate daemon.
@interface EmacsClientDelegate : NSObject <NSApplicationDelegate>
@property(nonatomic, strong) NSOperationQueue *requests;
@end

@implementation EmacsClientDelegate
- (instancetype)init {
    self = [super init];
    if (self) {
        _requests = [[NSOperationQueue alloc] init];
        _requests.maxConcurrentOperationCount = 1;
    }
    return self;
}

- (void)activateEmacsWithArguments:(NSArray<NSString *> *)arguments {
    // emacsclient can wait while Emacs is busy. Keep the AppKit event loop live.
    [self.requests addOperationWithBlock:^{
        NSTask *task = [[NSTask alloc] init];
        task.executableURL = [NSURL fileURLWithPath:@"/bin/bash"];
        NSString *helper = [[NSBundle mainBundle] pathForResource:@"activate-emacs"
                                                         ofType:nil];
        task.arguments = [@[helper] arrayByAddingObjectsFromArray:arguments];
        task.standardOutput = [NSFileHandle fileHandleWithNullDevice];
        NSError *error = nil;
        BOOL started = [task launchAndReturnError:&error];
        if (started) [task waitUntilExit];
        if (!started || task.terminationStatus != 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSAlert *alert = [[NSAlert alloc] init];
                alert.messageText = @"Unable to open Emacs";
                alert.informativeText = error.localizedDescription ?: 
                    @"Check that /Applications/Emacs.app is installed and the org.gnu.emacs.daemon launch agent is running.";
                [alert runModal];
            });
        }
    }];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    NSMenu *menu = [[NSMenu alloc] init];
    NSMenuItem *appItem = [[NSMenuItem alloc] init];
    [menu addItem:appItem];
    NSMenu *appMenu = [[NSMenu alloc] initWithTitle:@"Emacs Client"];
    [appMenu addItemWithTitle:@"Quit Emacs Client" action:@selector(terminate:)
               keyEquivalent:@"q"];
    appItem.submenu = appMenu;
    NSApp.mainMenu = menu;

    NSMutableArray *arguments = [NSMutableArray array];
    for (NSString *argument in [[NSProcessInfo processInfo].arguments subarrayWithRange:
         NSMakeRange(1, [NSProcessInfo processInfo].arguments.count - 1)]) {
        if (![argument hasPrefix:@"-psn_"]) [arguments addObject:argument];
    }
    [self activateEmacsWithArguments:arguments];
}

- (void)newWindow:(id)sender {
    [self activateEmacsWithArguments:@[@"--new-window"]];
}

- (NSMenu *)applicationDockMenu:(NSApplication *)sender {
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Emacs Client"];
    NSMenuItem *item = [menu addItemWithTitle:@"新建窗口"
                                     action:@selector(newWindow:)
                              keyEquivalent:@""];
    item.target = self;
    return menu;
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender
                   hasVisibleWindows:(BOOL)flag {
    [self activateEmacsWithArguments:@[]];
    return YES;
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return NO;
}
@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        EmacsClientDelegate *delegate = [[EmacsClientDelegate alloc] init];
        app.delegate = delegate;
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        [app run];
    }
    return 0;
}
