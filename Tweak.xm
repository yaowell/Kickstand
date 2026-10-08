#import <UIKit/UIKit.h>

@interface SBCoverSheetSlidingViewController : NSObject
- (void)_commitTransitionToAppeared:(BOOL)arg1 animated:(BOOL)arg2;
@end

%hook SBCoverSheetSlidingViewController

- (void)_presentOrDismissGestureEndedWithGestureRecognizer:(UIGestureRecognizer *)gesture {
    if ([gesture isKindOfClass:NSClassFromString(@"SBCoverSheetScreenEdgePanGestureRecognizer")]) {
        UIPanGestureRecognizer *pan = (UIPanGestureRecognizer *)gesture;
        CGPoint velocity = [pan velocityInView:pan.view];

        if (velocity.y > 0) {
            %orig;

            dispatch_async(dispatch_get_main_queue(), ^{
                [self _commitTransitionToAppeared:YES animated:YES];
            });

            return;
        }
    }

    %orig;
}

%end