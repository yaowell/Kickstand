#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@interface SBCoverSheetSlidingViewController : NSObject
- (void)_cancelTransitionForGesture:(id)gesture;
@end

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
            [self _cancelTransitionForGesture:gesture];
            return;
        }
    }

    %orig;
}

%end