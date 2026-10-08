#import <UIKit/UIKit.h>

%hook SBCoverSheetSlidingViewController

- (BOOL)_shouldEndPresentedForEndingGestureRecognizer:(id)gesture {
    Class cls = NSClassFromString(@"SBCoverSheetScreenEdgePanGestureRecognizer");

    if (cls && [gesture isKindOfClass:cls]) {
        return NO;
    }

    return %orig;
}

%end