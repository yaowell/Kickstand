#import <Foundation/Foundation.h>
%hook SBCoverSheetSlidingViewController

- (void)_transitionToViewControllerAppearState:(int)arg1 ifNeeded:(BOOL)arg2 forUserGesture:(BOOL)arg3 {
    NSLog(@"[Kickstand] transition state=%d ifNeeded=%d userGesture=%d", arg1, arg2, arg3);
    %orig;
}

- (void)_commitTransitionToAppeared:(BOOL)arg1 animated:(BOOL)arg2 {
    NSLog(@"[Kickstand] commit appeared=%d animated=%d", arg1, arg2);
    %orig;
}

- (void)_finishTransitionToPresented:(BOOL)arg1 animated:(BOOL)arg2 withCompletion:(id)arg3 {
    NSLog(@"[Kickstand] finish presented=%d animated=%d", arg1, arg2);
    %orig;
}

%end