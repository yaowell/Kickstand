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

- (BOOL)_shouldEndPresentedForEndingGestureRecognizer:(id)gesture {
    BOOL result = %orig;

    KSLog([NSString stringWithFormat:
           @"SHOULD_END result=%d gesture=%@",
           result,
           gesture ? NSStringFromClass([gesture class]) : @"(nil)"]);

    return result;
}

- (void)_presentOrDismissGestureEndedWithGestureRecognizer:(id)gesture {
    KSLog([NSString stringWithFormat:
           @"ENDED gesture=%@",
           gesture ? NSStringFromClass([gesture class]) : @"(nil)"]);

    %orig;
}

- (void)_cancelTransitionForGesture:(id)gesture {
    KSLog([NSString stringWithFormat:
           @"CANCEL gesture=%@",
           gesture ? NSStringFromClass([gesture class]) : @"(nil)"]);

    %orig;
}

- (void)_commitTransitionToAppeared:(BOOL)animated {
    KSLog([NSString stringWithFormat:
           @"COMMIT_APPEARED animated=%d",
           animated]);

    %orig(animated);
}

- (void)_endTransitionToAppeared {
    KSLog(@"END_APPEARED");
    %orig;
}

%end

%hook SBCoverSheetPrimarySlidingViewController

- (void)_handleDismissGesture:(id)gesture {
    KSLog(@"DISMISS_GESTURE");
    %orig;
}

%end