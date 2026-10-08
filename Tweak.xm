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
    BOOL r = %orig;
    KSLog([NSString stringWithFormat:@"SHOULD_END=%d", r]);
    return r;
}

- (CGFloat)_finalLocationForTransitionToPresented:(id)gesture {
    CGFloat r = %orig(gesture);
    KSLog([NSString stringWithFormat:@"FINAL_LOCATION=%f", r]);
    return r;
}

- (CGFloat)_velocityForGesture:(id)gesture {
    CGFloat r = %orig(gesture);
    KSLog([NSString stringWithFormat:@"VELOCITY=%f", r]);
    return r;
}

- (BOOL)_shouldRubberBandForGestureRecognizer:(id)gesture {
    BOOL r = %orig(gesture);
    KSLog([NSString stringWithFormat:@"RUBBER_BAND=%d", r]);
    return r;
}

- (void)_presentOrDismissGestureEndedWithGestureRecognizer:(id)gesture {
    KSLog(@"ENDED");
    %orig;
}

- (void)_dismissGestureChangedWithGestureRecognizer:(id)gesture {
    KSLog(@"CHANGED");
    %orig;
}

%end