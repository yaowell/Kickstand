#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>

static void KSLog(NSString *s) {
    NSString *p = @"/var/mobile/Documents/Kickstand.log";
    NSString *old = [NSString stringWithContentsOfFile:p
                                              encoding:NSUTF8StringEncoding
                                                 error:nil];
    if (!old) old = @"";
    [[old stringByAppendingFormat:@"%@\n", s]
        writeToFile:p
        atomically:YES
        encoding:NSUTF8StringEncoding
        error:nil];
}

static BOOL gTrace = NO;

%hook SBCoverSheetSlidingViewController

- (void)_presentOrDismissGestureEndedWithGestureRecognizer:(id)gesture {
    Class cls = NSClassFromString(@"SBCoverSheetScreenEdgePanGestureRecognizer");

    if (cls && [gesture isKindOfClass:cls]) {
        gTrace = YES;
        KSLog(@"========== TRACE BEGIN ==========");
    }

    %orig;

    if (cls && [gesture isKindOfClass:cls]) {
        KSLog(@"========== TRACE END ==========");
        gTrace = NO;
    }
}

- (void)_cancelTransitionForGesture:(id)gesture {
    if (gTrace) {
        KSLog(@"CALL _cancelTransitionForGesture:");
    }
    %orig;
}

- (void)_commitTransitionToAppeared:(BOOL)animated {
    if (gTrace) {
        KSLog([NSString stringWithFormat:
               @"CALL _commitTransitionToAppeared:animated: %d",
               animated]);
    }
    %orig;
}

- (void)_finishTransitionToPresented:(BOOL)animated
                    withCompletion:(id)completion {
    if (gTrace) {
        KSLog([NSString stringWithFormat:
               @"CALL _finishTransitionToPresented:animated: %d",
               animated]);
    }
    %orig;
}

- (void)_dismissGestureChangedWithGestureRecognizer:(id)gesture {
    if (gTrace) {
        KSLog(@"CALL _dismissGestureChangedWithGestureRecognizer:");
    }
    %orig;
}

- (BOOL)_shouldEndPresentedForEndingGestureRecognizer:(id)gesture {
    BOOL r = %orig;

    if (gTrace) {
        KSLog([NSString stringWithFormat:
               @"CALL _shouldEndPresentedForEndingGestureRecognizer: -> %d",
               r]);
    }

    return r;
}

- (BOOL)_shouldRubberBandForGestureRecognizer:(id)gesture {
    BOOL r = %orig;

    if (gTrace) {
        KSLog([NSString stringWithFormat:
               @"CALL _shouldRubberBandForGestureRecognizer: -> %d",
               r]);
    }

    return r;
}

%end