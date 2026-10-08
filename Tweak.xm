#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

static BOOL KSIsDismissGesture(id gesture) {
    Class cls = NSClassFromString(@"SBCoverSheetScreenEdgePanGestureRecognizer");

    return gesture &&
           [gesture isKindOfClass:[UIPanGestureRecognizer class]] &&
           cls &&
           [gesture isKindOfClass:cls];
}

%hook SBCoverSheetSlidingViewController

- (void)_presentOrDismissGestureEndedWithGestureRecognizer:(id)gesture {
    if (KSIsDismissGesture(gesture)) {
        UIPanGestureRecognizer *pan = (UIPanGestureRecognizer *)gesture;
        CGPoint velocity = [pan velocityInView:pan.view];

        if (velocity.y < 0) {
            return;
        }
    }

    %orig;
}

- (void)_transitionToViewControllerAppearState:(int)state
                                    ifNeeded:(BOOL)ifNeeded
                              forUserGesture:(BOOL)forUserGesture {

    if (state == 0 && !forUserGesture) {
        %orig(3, ifNeeded, forUserGesture);
        return;
    }

    %orig;
}

%end