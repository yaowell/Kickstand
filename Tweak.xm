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

static NSString *KSGestureInfo(id gesture) {
    if (![gesture isKindOfClass:[UIPanGestureRecognizer class]]) {
        return [NSString stringWithFormat:@"class=%@",
                gesture ? NSStringFromClass([gesture class]) : @"(nil)"];
    }

    UIPanGestureRecognizer *pan = (UIPanGestureRecognizer *)gesture;

    CGPoint translation = [pan translationInView:pan.view];
    CGPoint velocity = [pan velocityInView:pan.view];

    return [NSString stringWithFormat:
            @"class=%@ state=%ld translation=(%.1f,%.1f) velocity=(%.1f,%.1f)",
            NSStringFromClass([pan class]),
            (long)pan.state,
            translation.x,
            translation.y,
            velocity.x,
            velocity.y];
}

%hook SBCoverSheetSlidingViewController

- (void)_dismissGestureChangedWithGestureRecognizer:(id)gesture {
    KSLog([NSString stringWithFormat:
           @"CHANGED %@", KSGestureInfo(gesture)]);

    %orig;
}

- (void)_presentOrDismissGestureEndedWithGestureRecognizer:(id)gesture {
    KSLog([NSString stringWithFormat:
           @"ENDED %@", KSGestureInfo(gesture)]);

    %orig;
}

%end

%hook SBCoverSheetPrimarySlidingViewController

- (void)_handleDismissGesture:(id)gesture {
    KSLog([NSString stringWithFormat:
           @"DISMISS %@", KSGestureInfo(gesture)]);

    %orig;
}

%end