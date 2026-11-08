// Keep Squirrel selected and control its ASCII mode without activating an app.
#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>

static NSString *sourceID(TISInputSourceRef source) {
    return (__bridge NSString *)TISGetInputSourceProperty(source, kTISPropertyInputSourceID);
}

static BOOL isFrontmost(pid_t pid) {
    return NSWorkspace.sharedWorkspace.frontmostApplication.processIdentifier == pid;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        // PID status | PID rime SOURCE | PID rime-ascii
        if (argc != 3 && argc != 4) return 2;
        char *end = NULL;
        long value = strtol(argv[1], &end, 10);
        if (!end || *end || value <= 0 || value > INT_MAX) return 2;
        pid_t pid = (pid_t)value;
        if (!isFrontmost(pid)) return 3;

        TISInputSourceRef current = TISCopyCurrentKeyboardInputSource();
        if (!current) return 4;
        NSString *previous = [sourceID(current) copy];
        NSString *next = previous;
        BOOL isRime = [previous hasPrefix:@"im.rime.inputmethod.Squirrel."];
        int result = 4;
        if (argc == 3 && strcmp(argv[2], "status") == 0) {
            result = 0;
        } else if (argc == 3 && strcmp(argv[2], "rime-ascii") == 0) {
            // Same protocol as Squirrel --ascii. Never send this from a
            // background Emacs or while a different input source is selected.
            if (isRime && isFrontmost(pid)) {
                [[NSDistributedNotificationCenter defaultCenter]
                    postNotificationName:@"SquirrelToggleASCIIModeNotification"
                    object:@"ascii" userInfo:nil deliverImmediately:YES];
                result = 0;
            }
        } else if (argc == 4 && strcmp(argv[2], "rime") == 0 &&
                   [@(argv[3]) hasPrefix:@"im.rime.inputmethod.Squirrel."]) {
            if (isRime) {
                result = 0; // Preserve Hans/Hant and the existing Rime session.
            } else {
                NSDictionary *filter = @{
                    (__bridge NSString *)kTISPropertyInputSourceID: @(argv[3]),
                    (__bridge NSString *)kTISPropertyInputSourceIsEnabled: @YES,
                    (__bridge NSString *)kTISPropertyInputSourceIsSelectCapable: @YES
                };
                CFArrayRef sources = TISCreateInputSourceList((__bridge CFDictionaryRef)filter, false);
                if (sources && CFArrayGetCount(sources)) {
                    TISInputSourceRef target = (TISInputSourceRef)CFArrayGetValueAtIndex(sources, 0);
                    if (isFrontmost(pid) && TISSelectInputSource(target) == noErr) {
                        next = [sourceID(target) copy];
                        result = 0;
                    }
                }
                if (sources) CFRelease(sources);
            }
        }
        if (result == 0) printf("%s\n%s\n", previous.UTF8String, next.UTF8String);
        CFRelease(current);
        return result;
    }
}
