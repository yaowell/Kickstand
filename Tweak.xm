#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <execinfo.h>
#import <stdlib.h>

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

- (void)_beginTransitionFromAppeared:(BOOL)arg1 {
    KSLog([NSString stringWithFormat:@"BEGIN transition appeared=%d", arg1]);
    %orig;
}

- (void)_endTransitionToAppeared:(BOOL)arg1 {
    KSLog([NSString stringWithFormat:@"END transition appeared=%d", arg1]);
    %orig;
}

- (void)_commitTransitionToAppeared:(BOOL)arg1 animated:(BOOL)arg2 {
    KSLog([NSString stringWithFormat:@"COMMIT appeared=%d animated=%d", arg1, arg2]);

    if (!arg1) {
        void *frames[32];
        int count = backtrace(frames, 32);
        char **symbols = backtrace_symbols(frames, count);

        KSLog(@"===== HIDE CALL STACK BEGIN =====");
        for (int i = 0; symbols && i < count; i++) {
            KSLog([NSString stringWithUTF8String:symbols[i]]);
        }
        KSLog(@"===== HIDE CALL STACK END =====");

        if (symbols) {
            free(symbols);
        }
    }

    %orig;
}

- (void)grabberTongueBeganPulling:(id)arg1 withDistance:(double)arg2 andVelocity:(double)arg3 andGesture:(id)arg4 {
    KSLog([NSString stringWithFormat:@"GRABBER began distance=%.1f velocity=%.1f gesture=%@", arg2, arg3, arg4]);
    %orig;
}

- (void)grabberTongueUpdatedPulling:(id)arg1 withDistance:(double)arg2 andVelocity:(double)arg3 andGesture:(id)arg4 {
    KSLog([NSString stringWithFormat:@"GRABBER updated distance=%.1f velocity=%.1f", arg2, arg3]);
    %orig;
}

- (void)grabberTongueEndedPulling:(id)arg1 withDistance:(double)arg2 andVelocity:(double)arg3 andGesture:(id)arg4 {
    KSLog([NSString stringWithFormat:@"GRABBER ended distance=%.1f velocity=%.1f gesture=%@", arg2, arg3, arg4]);
    %orig;
}

- (void)grabberTongueCanceledPulling:(id)arg1 withDistance:(double)arg2 andVelocity:(double)arg3 andGesture:(id)arg4 {
    KSLog([NSString stringWithFormat:@"GRABBER canceled distance=%.1f velocity=%.1f", arg2, arg3]);
    %orig;
}

%end