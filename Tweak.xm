#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <execinfo.h>
#import <stdlib.h>

static BOOL gNotificationShown = NO;
static BOOL gTrackingNextPull = NO;
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

%hook SBCoverSheetPrimarySlidingViewController

- (void)_endTransitionToAppeared:(BOOL)arg1 {
    %orig;
    gNotificationShown = arg1;
    if (arg1) {
        gTrackingNextPull = NO;
        gCaptured = NO;
    }
}

- (void)grabberTongueBeganPulling:(id)arg1 withDistance:(double)arg2 andVelocity:(double)arg3 andGesture:(id)arg4 {
    if (gNotificationShown && !gCaptured) {
        gTrackingNextPull = YES;
        KSLog(@"===== NEXT PULL BEGIN =====");
        KSLog([NSString stringWithFormat:@"BEGIN distance=%.1f velocity=%.1f", arg2, arg3]);
    }
    %orig;
}

- (void)grabberTongueUpdatedPulling:(id)arg1 withDistance:(double)arg2 andVelocity:(double)arg3 andGesture:(id)arg4 {
    if (gTrackingNextPull && !gCaptured) {
        KSLog([NSString stringWithFormat:@"UPDATE distance=%.1f velocity=%.1f", arg2, arg3]);
    }
    %orig;
}

- (void)grabberTongueEndedPulling:(id)arg1 withDistance:(double)arg2 andVelocity:(double)arg3 andGesture:(id)arg4 {
    if (gTrackingNextPull && !gCaptured) {
        KSLog([NSString stringWithFormat:@"END distance=%.1f velocity=%.1f", arg2, arg3]);
        gTrackingNextPull = NO;
    }
    %orig;
}

- (void)grabberTongueCanceledPulling:(id)arg1 withDistance:(double)arg2 andVelocity:(double)arg3 andGesture:(id)arg4 {
    if (gTrackingNextPull && !gCaptured) {
        KSLog(@"GESTURE CANCELED");
        gTrackingNextPull = NO;
    }
    %orig;
}

- (void)_commitTransitionToAppeared:(BOOL)arg1 animated:(BOOL)arg2 {
    if (gTrackingNextPull && !gCaptured && !arg1) {
        gCaptured = YES;
        gTrackingNextPull = NO;
        KSLog([NSString stringWithFormat:@"HIDE COMMIT animated=%d", arg2]);

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
    %orig;
}

%end