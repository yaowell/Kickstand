#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@interface SBCoverSheetSlidingViewController : NSObject
- (BOOL)_shouldEndPresentedForEndingGestureRecognizer:(id)gesture;
@end

static void KSLog(NSString *s) {
    NSString *p = @"/var/mobile/Documents/Kickstand.log";
    NSString *line = [NSString stringWithFormat:@"%@ %@\n",
        [NSDate date], s];
    NSFileHandle *f = [NSFileHandle fileHandleForWritingAtPath:p];
    if (!f) {
        [line writeToFile:p atomically:YES
                 encoding:NSUTF8StringEncoding error:nil];
    } else {
        [f seekToEndOfFile];
        [f writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
        [f closeFile];
    }
}

%hook SBCoverSheetSlidingViewController

- (BOOL)_shouldEndPresentedForEndingGestureRecognizer:(id)gesture {
    BOOL result = %orig;
    NSString *cls = gesture ? NSStringFromClass([gesture class]) : @"nil";
    if ([gesture isKindOfClass:[UIPanGestureRecognizer class]]) {
        UIPanGestureRecognizer *pan = (UIPanGestureRecognizer *)gesture;
        CGPoint v = [pan velocityInView:pan.view];
        KSLog([NSString stringWithFormat:
            @"shouldEnd class=%@ state=%ld velocity=(%.1f, %.1f) orig=%d",
            cls, (long)pan.state, v.x, v.y, result]);
    } else {
        KSLog([NSString stringWithFormat:
            @"shouldEnd class=%@ orig=%d", cls, result]);
    }
    return result;
}

%end