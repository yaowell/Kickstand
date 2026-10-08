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

- (CGPoint)_velocityForGesture:(id)gesture {
    CGPoint r = %orig;

    Class cls = NSClassFromString(@"SBCoverSheetScreenEdgePanGestureRecognizer");
    if (cls && [gesture isKindOfClass:cls]) {
        KSLog([NSString stringWithFormat:
               @"VELOCITY gesture=%@ -> (%.1f,%.1f)",
               NSStringFromClass([gesture class]), r.x, r.y]);
    }

    return r;
}

- (CGPoint)_finalLocationForTransitionToPresented:(id)gesture {
    CGPoint r = %orig;

    Class cls = NSClassFromString(@"SBCoverSheetScreenEdgePanGestureRecognizer");
    if (cls && [gesture isKindOfClass:cls]) {
        KSLog([NSString stringWithFormat:
               @"FINAL LOCATION gesture=%@ -> (%.1f,%.1f)",
               NSStringFromClass([gesture class]), r.x, r.y]);
    }

    return r;
}

%end