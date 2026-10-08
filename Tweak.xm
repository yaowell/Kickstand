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

static BOOL KSIsDismissPan(id gesture) {
    return [gesture isKindOfClass:[UIPanGestureRecognizer class]] &&
           [gesture isKindOfClass:NSClassFromString(@"SBCoverSheetScreenEdgePanGestureRecognizer")];
}

%hook SBCoverSheetPrimarySlidingViewController

- (void)_handleDismissGesture:(id)gesture {
    if (KSIsDismissPan(gesture)) {
        UIPanGestureRecognizer *pan = (UIPanGestureRecognizer *)gesture;

        if (pan.state == UIGestureRecognizerStateEnded) {
            CGPoint translation = [pan translationInView:pan.view];
            CGPoint velocity = [pan velocityInView:pan.view];

            KSLog([NSString stringWithFormat:
                   @"DISMISS ENDED translation=(%.1f,%.1f) velocity=(%.1f,%.1f)",
                   translation.x,
                   translation.y,
                   velocity.x,
                   velocity.y]);

            if (velocity.y < 0) {
                KSLog(@"TRY BLOCK DISMISS");
            }
        }
    }

    %orig;
}

%end