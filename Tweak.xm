#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

static NSMutableString *gLog;

static NSString *KSPath(void) {
    return @"/var/mobile/Documents/Kickstand.log";
}

static void KSLog(NSString *format, ...) {
    if (!gLog) {
        gLog = [NSMutableString string];
    }

    va_list args;
    va_start(args, format);
    NSString *s = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    [gLog appendFormat:@"%@\n", s];

    if (gLog.length > 200000) {
        [gLog deleteCharactersInRange:NSMakeRange(0, gLog.length - 150000)];
    }
}

static void KSSaveLog(void) {
    if (!gLog || gLog.length == 0) return;

    [gLog writeToFile:KSPath()
           atomically:YES
             encoding:NSUTF8StringEncoding
                error:nil];
}

@interface SBCoverSheetPrimarySlidingViewController : NSObject
@end

@interface SBGrabberTongue : NSObject
@end

%hook SBCoverSheetPrimarySlidingViewController

- (void)_handleDismissGesture:(id)gesture {
    KSLog(@"");
    KSLog(@"========================================");
    KSLog(@"HANDLE DISMISS GESTURE");
    KSLog(@"========================================");

    KSLog(@"gesture=%@",
          gesture ? NSStringFromClass([gesture class]) : @"<nil>");

    if ([gesture isKindOfClass:[UIPanGestureRecognizer class]]) {
        UIPanGestureRecognizer *pan =
            (UIPanGestureRecognizer *)gesture;

        UIView *view = pan.view;

        CGPoint translation = [pan translationInView:view];
        CGPoint velocity = [pan velocityInView:view];
        CGPoint location = [pan locationInView:view];

        KSLog(@"state=%ld",
              (long)pan.state);

        KSLog(@"translation=(%.1f, %.1f)",
              translation.x,
              translation.y);

        KSLog(@"velocity=(%.1f, %.1f)",
              velocity.x,
              velocity.y);

        KSLog(@"location=(%.1f, %.1f)",
              location.x,
              location.y);
    }

    %orig;

    KSLog(@"HANDLE DISMISS GESTURE AFTER");
    KSSaveLog();
}

%end

%hook SBGrabberTongue

- (void)_handlePullGesture:(id)gesture {
    if (gesture &&
        [gesture isKindOfClass:[UIGestureRecognizer class]]) {

        NSString *name = NSStringFromClass([gesture class]);

        if ([name isEqualToString:@"SBCoverSheetPresentationGestureRecognizer"]) {
            KSLog(@"");
            KSLog(@"========================================");
            KSLog(@"HANDLE PRESENTATION PULL GESTURE");
            KSLog(@"========================================");

            KSLog(@"gesture=%@",
                  name);

            if ([gesture isKindOfClass:[UIPanGestureRecognizer class]]) {
                UIPanGestureRecognizer *pan =
                    (UIPanGestureRecognizer *)gesture;

                UIView *view = pan.view;

                CGPoint translation = [pan translationInView:view];
                CGPoint velocity = [pan velocityInView:view];

                KSLog(@"state=%ld",
                      (long)pan.state);

                KSLog(@"translation=(%.1f, %.1f)",
                      translation.x,
                      translation.y);

                KSLog(@"velocity=(%.1f, %.1f)",
                      velocity.x,
                      velocity.y);
            }

            KSSaveLog();
        }
    }

    %orig;
}

%end

%ctor {
    gLog = [NSMutableString string];

    KSLog(@"");
    KSLog(@"========================================");
    KSLog(@"Kickstand DISMISS PROBE LOADED");
    KSLog(@"========================================");

    KSSaveLog();
}