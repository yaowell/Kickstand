#import <Foundation/Foundation.h>

static void KSLog(NSString *message) {
    NSString *path = @"/var/mobile/Documents/Kickstand.log";
    NSString *line = [NSString stringWithFormat:@"%@ %@\n", [NSDate date], message];
    NSFileHandle *file = [NSFileHandle fileHandleForWritingAtPath:path];
    if (!file) {
        [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
        file = [NSFileHandle fileHandleForWritingAtPath:path];
    }
    if (file) {
        [file seekToEndOfFile];
        [file writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
        [file closeFile];
    }
}

%hook SBCoverSheetSlidingViewController

- (void)_transitionToViewControllerAppearState:(int)arg1 ifNeeded:(BOOL)arg2 forUserGesture:(BOOL)arg3 {
    KSLog([NSString stringWithFormat:@"transition state=%d ifNeeded=%d userGesture=%d", arg1, arg2, arg3]);
    %orig;
}

- (void)_commitTransitionToAppeared:(BOOL)arg1 animated:(BOOL)arg2 {
    KSLog([NSString stringWithFormat:@"commit appeared=%d animated=%d", arg1, arg2]);
    %orig;
}

- (void)_finishTransitionToPresented:(BOOL)arg1 animated:(BOOL)arg2 withCompletion:(id)arg3 {
    KSLog([NSString stringWithFormat:@"finish presented=%d animated=%d", arg1, arg2]);
    %orig;
}

%end