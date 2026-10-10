#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <execinfo.h>
#import <stdlib.h>

@interface SBCoverSheetSlidingViewController : NSObject
- (BOOL)_shouldEndPresentedForEndingGestureRecognizer:(id)gesture;
- (void)_presentOrDismissGestureEndedWithGestureRecognizer:(id)gesture;
- (void)_presentOrDismissGestureChangedWithGestureRecognizer:(id)gesture;
- (void)_dismissGestureChangedWithGestureRecognizer:(id)gesture;
- (void)_cancelTransitionForGesture:(id)gesture;
- (void)_commitTransitionToAppeared:(BOOL)appeared animated:(BOOL)animated;
- (void)_finishTransitionToPresented:(BOOL)presented animated:(BOOL)animated withCompletion:(id)completion;
@end

static void KSLog(NSString *s) {
    NSString *p = @"/var/mobile/Documents/Kickstand.log";
    NSString *line = [NSString stringWithFormat:@"%@ %@\n", [NSDate date], s];
    NSFileHandle *f = [NSFileHandle fileHandleForWritingAtPath:p];

    if (!f) {
        [line writeToFile:p atomically:YES encoding:NSUTF8StringEncoding error:nil];
    } else {
        [f seekToEndOfFile];
        [f writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
        [f closeFile];
    }
}

%hook SBCoverSheetSlidingViewController

- (BOOL)_shouldEndPresentedForEndingGestureRecognizer:(id)gesture {
    BOOL result = %orig;
    NSString *cls = gesture ? NSStringFromClass([gesture class]) : @"nil";

    if ([gesture isKindOfClass:[UIPanGestureRecognizer class]]) {
        UIPanGestureRecognizer *pan = (UIPanGestureRecognizer *)gesture;
        CGPoint v = [pan velocityInView:pan.view];
        KSLog([NSString stringWithFormat:
            @"SHOULD_END class=%@ state=%ld velocity=(%.1f,%.1f) orig=%d",
            cls, (long)pan.state, v.x, v.y, result]);
    } else {
        KSLog([NSString stringWithFormat:@"SHOULD_END class=%@ orig=%d", cls, result]);
    }

    return result;
}

- (void)_presentOrDismissGestureEndedWithGestureRecognizer:(id)gesture {
    NSString *cls = gesture ? NSStringFromClass([gesture class]) : @"nil";
    KSLog([NSString stringWithFormat:@"GESTURE_ENDED class=%@", cls]);
    %orig;
}

- (void)_presentOrDismissGestureChangedWithGestureRecognizer:(id)gesture {
    NSString *cls = gesture ? NSStringFromClass([gesture class]) : @"nil";
    KSLog([NSString stringWithFormat:@"PRESENT_DISMISS_CHANGED class=%@", cls]);
    %orig;
}

- (void)_dismissGestureChangedWithGestureRecognizer:(id)gesture {
    NSString *cls = gesture ? NSStringFromClass([gesture class]) : @"nil";
    KSLog([NSString stringWithFormat:@"DISMISS_CHANGED class=%@", cls]);
    %orig;
}

- (void)_cancelTransitionForGesture:(id)gesture {
    NSString *cls = gesture ? NSStringFromClass([gesture class]) : @"nil";
    KSLog([NSString stringWithFormat:@"CANCEL_TRANSITION class=%@", cls]);
    %orig;
}

- (void)_finishTransitionToPresented:(BOOL)presented animated:(BOOL)animated withCompletion:(id)completion {
    KSLog([NSString stringWithFormat:@"FINISH presented=%d animated=%d", presented, animated]);

    if (!presented) {
        void *frames[24];
        int count = backtrace(frames, 24);
        char **symbols = backtrace_symbols(frames, count);

        if (symbols) {
            for (int i = 0; i < count; i++) {
                KSLog([NSString stringWithFormat:@"STACK %s", symbols[i]]);
            }
            free(symbols);
        }
    }

    %orig;
}

- (void)_commitTransitionToAppeared:(BOOL)appeared animated:(BOOL)animated {
    KSLog([NSString stringWithFormat:@"COMMIT_ENTER appeared=%d animated=%d", appeared, animated]);
    %orig;
    KSLog([NSString stringWithFormat:@"COMMIT_EXIT appeared=%d animated=%d", appeared, animated]);
}

%end