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

static BOOL KSIsDismissGesture(id gesture) {
    Class cls = NSClassFromString(@"SBCoverSheetScreenEdgePanGestureRecognizer");

    return gesture &&
           [gesture isKindOfClass:[UIPanGestureRecognizer class]] &&
           cls &&
           [gesture isKindOfClass:cls];
}

%hook SBCoverSheetSlidingViewController

- (void)_dismissGestureChangedWithGestureRecognizer:(id)gesture {
    if (KSIsDismissGesture(gesture)) {
        UIPanGestureRecognizer *pan = (UIPanGestureRecognizer *)gesture;

        CGPoint t = [pan translationInView:pan.view];
        CGPoint v = [pan velocityInView:pan.view];

        KSLog([NSString stringWithFormat:
               @"CHANGED t=(%.1f,%.1f) v=(%.1f,%.1f)",
               t.x, t.y, v.x, v.y]);
    }

    %orig;
}

- (void)_presentOrDismissGestureEndedWithGestureRecognizer:(id)gesture {
    if (KSIsDismissGesture(gesture)) {
        UIPanGestureRecognizer *pan = (UIPanGestureRecognizer *)gesture;

        CGPoint t = [pan translationInView:pan.view];
        CGPoint v = [pan velocityInView:pan.view];

        KSLog([NSString stringWithFormat:
               @"ENDED t=(%.1f,%.1f) v=(%.1f,%.1f)",
               t.x, t.y, v.x, v.y]);
    }

    %orig;
}

- (void)_commitTransitionToAppeared:(BOOL)animated {
    KSLog([NSString stringWithFormat:
           @"CALL _commitTransitionToAppeared animated=%d",
           animated]);

    %orig;
}

- (void)_transitionToViewControllerAppearState:(int)state
                                    ifNeeded:(BOOL)ifNeeded
                              forUserGesture:(BOOL)forUserGesture {
    KSLog([NSString stringWithFormat:
           @"CALL _transitionToViewControllerAppearState:ifNeeded:forUserGesture: state=%d ifNeeded=%d userGesture=%d",
           state,
           ifNeeded,
           forUserGesture]);

    %orig;
}

- (void)_transitionToViewControllerAppearState:(int)state
                                forUserGesture:(BOOL)forUserGesture {
    KSLog([NSString stringWithFormat:
           @"CALL _transitionToViewControllerAppearState:forUserGesture: state=%d userGesture=%d",
           state,
           forUserGesture]);

    %orig;
}

%end