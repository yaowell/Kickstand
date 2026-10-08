#import <UIKit/UIKit.h>

static BOOL KSIsDismissGesture(id gesture) {
    Class cls = NSClassFromString(@"SBCoverSheetScreenEdgePanGestureRecognizer");
    return cls && [gesture isKindOfClass:cls];
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

%end

%hook SBCoverSheetPrimarySlidingViewController

- (void)_handleDismissGesture:(id)gesture {
    if (KSIsDismissGesture(gesture)) {
        UIPanGestureRecognizer *pan = (UIPanGestureRecognizer *)gesture;

        if (pan.state == UIGestureRecognizerStateEnded) {
            CGPoint velocity = [pan velocityInView:pan.view];

            if (velocity.y < 0) {
                return;
            }
        }
    }

    %orig;
}

%end