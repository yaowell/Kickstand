#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static void KSLog(NSString *s) {
    NSString *p = @"/var/mobile/Documents/Kickstand.log";
    NSString *old = [NSString stringWithContentsOfFile:p
                                              encoding:NSUTF8StringEncoding
                                                 error:nil];
    if (!old) old = @"";
    [[old stringByAppendingFormat:@"%@\n", s]
        writeToFile:p
        atomically:YES
        encoding:NSUTF8StringEncoding
        error:nil];
}

static BOOL KSDismissGesture(id gesture) {
    Class cls = NSClassFromString(@"SBCoverSheetScreenEdgePanGestureRecognizer");
    return cls && [gesture isKindOfClass:cls];
}

%hook SBCoverSheetPrimarySlidingViewController

- (void)_handleDismissGesture:(id)gesture {

    if (KSDismissGesture(gesture)) {
        UIPanGestureRecognizer *pan = (UIPanGestureRecognizer *)gesture;

        if (pan.state == UIGestureRecognizerStateEnded) {
            CGPoint t = [pan translationInView:pan.view];
            CGPoint v = [pan velocityInView:pan.view];

            KSLog(@"========================================");
            KSLog(@"KICKSTAND DISMISS END TRACE");
            KSLog([NSString stringWithFormat:
                   @"translation=(%.1f,%.1f) velocity=(%.1f,%.1f)",
                   t.x, t.y, v.x, v.y]);

            KSLog(@"Calling original _handleDismissGesture...");
        }
    }

    %orig;

    if (KSDismissGesture(gesture)) {
        UIPanGestureRecognizer *pan = (UIPanGestureRecognizer *)gesture;

        if (pan.state == UIGestureRecognizerStateEnded) {
            KSLog(@"Original _handleDismissGesture returned");
            KSLog(@"========================================");
        }
    }
}

%end

%hook SBCoverSheetSlidingViewController

- (void)_dismissGestureChangedWithGestureRecognizer:(id)gesture {
    if (KSDismissGesture(gesture)) {
        UIPanGestureRecognizer *pan = (UIPanGestureRecognizer *)gesture;

        if (pan.state == UIGestureRecognizerStateEnded) {
            KSLog(@"DISMISS_CHANGED ENDED");
        }
    }

    %orig;
}

- (void)_presentOrDismissGestureEndedWithGestureRecognizer:(id)gesture {
    if (KSDismissGesture(gesture)) {
        KSLog(@"PRESENT_DISMISS_ENDED BEGIN");
    }

    %orig;

    if (KSDismissGesture(gesture)) {
        KSLog(@"PRESENT_DISMISS_ENDED AFTER");
    }
}

%end