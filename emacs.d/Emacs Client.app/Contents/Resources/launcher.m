#import <Cocoa/Cocoa.h>

// This process owns the Dock tile; Emacs itself remains a separate daemon.
@interface EmacsClientDelegate : NSObject <NSApplicationDelegate>
@property(nonatomic, strong) NSOperationQueue *requests;
@property(atomic, strong) NSTask *activeTask;
@property(atomic) NSUInteger generation;
@property(atomic) BOOL restarting;
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
    if (self.restarting) return;
    NSUInteger generation = self.generation;
    // emacsclient can wait while Emacs is busy. Keep the AppKit event loop live.
    [self.requests addOperationWithBlock:^{
        NSTask *task = [[NSTask alloc] init];
        task.executableURL = [NSURL fileURLWithPath:@"/bin/bash"];
        NSString *helper = [[NSBundle mainBundle] pathForResource:@"activate-emacs"
                                                         ofType:nil];
        task.arguments = [@[helper] arrayByAddingObjectsFromArray:arguments];
        task.standardOutput = [NSFileHandle fileHandleWithNullDevice];
        NSError *error = nil;
        BOOL started;
        @synchronized (self) {
            if (generation != self.generation) return;
            self.activeTask = task;
            started = [task launchAndReturnError:&error];
        }
        if (started) [task waitUntilExit];
        @synchronized (self) {
            if (self.activeTask == task) self.activeTask = nil;
        }
        if (!started || task.terminationStatus != 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (generation != self.generation) return;
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

- (void)forceRestartEmacs:(id)sender {
    if (self.restarting) return;
    NSAlert *confirmation = [[NSAlert alloc] init];
    confirmation.alertStyle = NSAlertStyleCritical;
    confirmation.messageText = @"强制重启 Emacs 后台？";
    confirmation.informativeText = @"此后台中的所有 Emacs 窗口会关闭，未保存的修改将丢失。随后会启动新的后台并打开一个窗口。磁盘上的文件和配置不会删除。";
    [confirmation addButtonWithTitle:@"取消"];
    [confirmation addButtonWithTitle:@"强制重启"];
    if ([confirmation runModal] != NSAlertSecondButtonReturn) return;

    @synchronized (self) {
        self.restarting = YES;
        self.generation += 1;
        [self.requests cancelAllOperations];
        // Stop the opening helper, not the Dock app. Its pending errors are stale.
        if (self.activeTask.running) [self.activeTask terminate];
    }
    // Recovery must not wait behind an emacsclient blocked in the normal queue.
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSTask *task = [[NSTask alloc] init];
        task.executableURL = [NSURL fileURLWithPath:@"/bin/bash"];
        task.arguments = @[[[NSBundle mainBundle] pathForResource:@"restart-emacs"
                                                         ofType:nil]];
        NSError *error = nil;
        BOOL started = [task launchAndReturnError:&error];
        if (started) [task waitUntilExit];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.restarting = NO;
            if (!started || task.terminationStatus != 0) {
                NSAlert *alert = [[NSAlert alloc] init];
                alert.messageText = @"无法重启 Emacs 后台";
                alert.informativeText = error.localizedDescription ?: @"请检查 org.gnu.emacs.daemon 服务及 ~/Library/LaunchAgents/org.gnu.emacs.daemon.plist。";
                [alert runModal];
            }
        });
    });
}

- (BOOL)validateMenuItem:(NSMenuItem *)item {
    if (item.action == @selector(forceRestartEmacs:) ||
        item.action == @selector(newWindow:)) return !self.restarting;
    return YES;
}

- (NSMenu *)applicationDockMenu:(NSApplication *)sender {
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Emacs Client"];
    NSMenuItem *item = [menu addItemWithTitle:@"新建窗口"
                                     action:@selector(newWindow:)
                              keyEquivalent:@""];
    item.target = self;
    [menu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *restart = [menu addItemWithTitle:@"强制重启 Emacs 后台…"
                                         action:@selector(forceRestartEmacs:)
                                  keyEquivalent:@""];
    restart.target = self;
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
