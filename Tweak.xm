#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static BOOL gKickstandExpanded = NO;

%hook SBCoverSheetPresentationManager

- (void)_finishTransitionToPresented:(BOOL)presented animated:(BOOL)animated withCompletion:(id)completion {
    if (!presented && gKickstandExpanded) {
        %orig(YES, animated, completion);
        return;
    }
    %orig;
}

- (void)_presentOrDismissGestureEndedWithGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer {
    NSString *name = NSStringFromClass([gestureRecognizer class]);
    BOOL edgePan = [name isEqualToString:@"SBCoverSheetScreenEdgePanGestureRecognizer"];

    if (edgePan && gestureRecognizer.state == UIGestureRecognizerStateEnded) {
        CGPoint velocity = [gestureRecognizer velocityInView:gestureRecognizer.view];

        // 仅处理向下滑动
        if (velocity.y > 0) {
            gKickstandExpanded = YES;
        }
    }

    %orig;
}

%end