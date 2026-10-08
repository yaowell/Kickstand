#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

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

        KSLog([NSString stringWithFormat:
               @"KICKSTAND END velocity=(%.1f,%.1f)",
               velocity.x,
               velocity.y]);

        if (velocity.y < 0) {
            KSLog(@"KICKSTAND CANCEL DISMISS");

            [self _cancelTransitionForGesture:gesture];
            return;
        }
    }

    %orig;
}

%end