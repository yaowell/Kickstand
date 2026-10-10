
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

%hook SBCoverSheetPresentationManager

- (BOOL)_shouldEndPresentedForEndingGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer {
    NSString *name = NSStringFromClass([gestureRecognizer class]);

    if ([name isEqualToString:@"SBCoverSheetScreenEdgePanGestureRecognizer"]) {
        return YES;
    }

    return %orig;
}

%end