#import <UIKit/UIKit.h>

@interface SBCoverSheetSlidingViewController : NSObject
- (void)_commitTransitionToAppeared:(BOOL)arg1 animated:(BOOL)arg2;
@end

%hook SBCoverSheetSlidingViewController

- (void)_presentOrDismissGestureEndedWithGestureRecognizer:(UIGestureRecognizer *)gesture {
    CGPoint velocity = [gesture velocityInView:gesture.view];

    if (velocity.y > 0 &&
        [gesture isKindOfClass:NSClassFromString(@"SBCoverSheetScreenEdgePanGestureRecognizer")]) {

        %orig;

        dispatch_async(dispatch_get_main_queue(), ^{
            [self _commitTransitionToAppeared:YES animated:YES];
        });

        return;
    }

    %orig;
}

%end