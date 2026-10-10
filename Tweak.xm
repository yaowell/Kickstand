#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <execinfo.h>
#import <stdlib.h>

static BOOL gNotificationShown = NO;
static BOOL gTracking = NO;
static BOOL gCaptured = NO;

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

static void KSLogCallStack(void) {
    void *frames[32];
    int count = backtrace(frames, 32);
    char **symbols = backtrace_symbols(frames, count);

    KSLog(@"===== HIDE CALL STACK BEGIN =====");
    for (int i = 0; symbols && i < count; i++) {
        KSLog([NSString stringWithUTF8String:symbols[i]]);
    }
    KSLog(@"===== HIDE CALL STACK END =====");

    if (symbols) free(symbols);
}

%hook SBCoverSheetPrimarySlidingViewController

- (void)_beginTransitionFromAppeared:(BOOL)arg1 {
    if (gTracking && !gCaptured) {
        KSLog([NSString stringWithFormat:@"BEGIN TRANSITION appeared=%d", arg1]);
    }
    %orig;
}

- (void)_endTransitionToAppeared:(BOOL)arg1 {
    %orig;

    gNotificationShown = arg1;

    if (gTracking && !gCaptured) {
        KSLog([NSString stringWithFormat:@"END TRANSITION appeared=%d", arg1]);

        if (!arg1) {
            gCaptured = YES;
            gTracking = NO;
            KSLogCallStack();
        }
    }

    if (arg1) {
        gCaptured = NO;
    }
}

- (void)_commitTransitionToAppeared:(BOOL)arg1 animated:(BOOL)arg2 {
    if (gTracking && !gCaptured) {
        KSLog([NSString stringWithFormat:@"COMMIT appeared=%d animated=%d", arg1, arg2]);

        if (!arg1) {
            gCaptured = YES;
            KSLogCallStack();
        }
    }

    %orig;
}

- (void)grabberTongueBeganPulling:(id)arg1 withDistance:(double)arg2 andVelocity:(double)arg3 andGesture:(id)arg4 {
    if (gNotificationShown && !gTracking) {
        gTracking = YES;
        gCaptured = NO;
        KSLog(@"===== PULL TRACKING BEGIN =====");
        KSLog([NSString stringWithFormat:@"GESTURE BEGIN distance=%.1f velocity=%.1f", arg2, arg3]);
    }
    %orig;
}

- (void)grabberTongueEndedPulling:(id)arg1 withDistance:(double)arg2 andVelocity:(double)arg3 andGesture:(id)arg4 {
    if (gTracking && !gCaptured) {
        KSLog([NSString stringWithFormat:@"GESTURE END distance=%.1f velocity=%.1f", arg2, arg3]);
    }
    %orig;
}

- (void)grabberTongueCanceledPulling:(id)arg1 withDistance:(double)arg2 andVelocity:(double)arg3 andGesture:(id)arg4 {
    if (gTracking && !gCaptured) {
        KSLog(@"GESTURE CANCELED");
    }
    %orig;
}

%end