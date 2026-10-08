#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

static void KSLog(NSString *s) {
    NSString *p = @"/var/mobile/Documents/Kickstand.log";
    NSString *old = [NSString stringWithContentsOfFile:p encoding:NSUTF8StringEncoding error:nil];
    if (!old) old = @"";
    [[old stringByAppendingFormat:@"%@\n", s]
        writeToFile:p atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

%hook SBCoverSheetSlidingViewController

- (void)_presentOrDismissGestureEndedWithGestureRecognizer:(id)gesture {
    Class cls = NSClassFromString(@"SBCoverSheetScreenEdgePanGestureRecognizer");

    if (cls && [gesture isKindOfClass:cls]) {
        KSLog(@"========== DISMISS END BEGIN ==========");
    }

    %orig;

    if (cls && [gesture isKindOfClass:cls]) {
        KSLog(@"========== DISMISS END AFTER ==========");
    }
}

- (void)_dismissGestureChangedWithGestureRecognizer:(id)gesture {
    Class cls = NSClassFromString(@"SBCoverSheetScreenEdgePanGestureRecognizer");

    if (cls && [gesture isKindOfClass:cls]) {
        UIPanGestureRecognizer *pan = (UIPanGestureRecognizer *)gesture;

        if (pan.state == UIGestureRecognizerStateChanged) {
            CGPoint t = [pan translationInView:pan.view];
            CGPoint v = [pan velocityInView:pan.view];

            KSLog([NSString stringWithFormat:
                   @"DISMISS CHANGED t=(%.1f,%.1f) v=(%.1f,%.1f)",
                   t.x, t.y, v.x, v.y]);
        }
    }

    %orig;
}

%end