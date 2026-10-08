#import <UIKit/UIKit.h>

static BOOL KickstandHandling = NO;

%hook UIPanGestureRecognizer

- (void)setState:(UIGestureRecognizerState)state {
    UIView *view = self.view;

    if (!KickstandHandling &&
        state == UIGestureRecognizerStateEnded &&
        [view isKindOfClass:NSClassFromString(@"NCNotificationListView")]) {

        CGPoint velocity = [self velocityInView:view];

        if (velocity.y > 0) {
            KickstandHandling = YES;

            self.enabled = NO;

            dispatch_async(dispatch_get_main_queue(), ^{
                self.enabled = YES;
                KickstandHandling = NO;
            });

            return;
        }
    }

    %orig;
}

%end