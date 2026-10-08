#import <UIKit/UIKit.h>

@interface SBCoverSheetSlidingViewController : NSObject
- (BOOL)_shouldEndPresentedForEndingGestureRecognizer:(id)gesture;
@end

%hook SBCoverSheetSlidingViewController

- (BOOL)_shouldEndPresentedForEndingGestureRecognizer:(id)gesture {
    if ([gesture isKindOfClass:NSClassFromString(@"SBCoverSheetScreenEdgePanGestureRecognizer")]) {
        UIPanGestureRecognizer *pan = (UIPanGestureRecognizer *)gesture;
        CGPoint velocity = [pan velocityInView:pan.view];

        if (velocity.y > 0) {
            return NO;
        }
    }

    return %orig;
}

%end