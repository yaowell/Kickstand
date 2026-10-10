#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

static BOOL gKickstandProtect = NO;

%hook SBCoverSheetPresentationManager

- (void)_presentOrDismissGestureEndedWithGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer {
    BOOL edgePan = [NSStringFromClass([gestureRecognizer class]) isEqualToString:@"SBCoverSheetScreenEdgePanGestureRecognizer"];
    if (edgePan) gKickstandProtect = YES;
    %orig;
    if (edgePan) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            gKickstandProtect = NO;
        });
    }
}

- (void)_finishTransitionToPresented:(BOOL)presented animated:(BOOL)animated withCompletion:(id)completion {
    if (!presented && gKickstandProtect) {
        %orig(YES, animated, completion);
        gKickstandProtect = NO;
        return;
    }
    %orig;
}

%end