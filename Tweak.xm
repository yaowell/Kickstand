#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

static void KSLog(NSString *text) {
    NSString *path = @"/var/mobile/Documents/Kickstand.log";
    NSString *old = [NSString stringWithContentsOfFile:path
                                              encoding:NSUTF8StringEncoding
                                                 error:nil];
    if (!old) old = @"";
    NSString *out = [old stringByAppendingFormat:@"%@\n", text];
    [out writeToFile:path
          atomically:YES
            encoding:NSUTF8StringEncoding
               error:nil];
}

%hook SBCoverSheetSlidingViewController

- (void)_dismissGestureChangedWithGestureRecognizer:(id)gesture {
    KSLog(@"DISMISS_CHANGED");
    %orig;
}

- (void)_presentOrDismissGestureEndedWithGestureRecognizer:(id)gesture {
    KSLog(@"PRESENT_DISMISS_ENDED");
    %orig;
}

- (void)_cancelTransitionForGesture:(id)gesture {
    KSLog(@"CANCEL_TRANSITION");
    %orig;
}

- (void)_commitTransitionToAppeared:(BOOL)animated {
    KSLog([NSString stringWithFormat:@"COMMIT_APPEARED %d", animated]);
    %orig(animated);
}

- (void)_finishTransitionToPresented:(BOOL)animated
                      withCompletion:(id)completion {
    KSLog([NSString stringWithFormat:@"FINISH_PRESENTED %d", animated]);
    %orig(animated, completion);
}

%end

%hook SBCoverSheetPrimarySlidingViewController

- (void)_handleDismissGesture:(id)gesture {
    %orig;
}

%end