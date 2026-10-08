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

static void KSDumpView(UIView *view, NSInteger depth) {
    if (!view || depth > 8) return;

    NSString *indent = @"";
    for (NSInteger i = 0; i < depth; i++) {
        indent = [indent stringByAppendingString:@"  "];
    }

    NSString *name = NSStringFromClass(view.class);

    if ([view isKindOfClass:[UIScrollView class]]) {
        UIScrollView *scroll = (UIScrollView *)view;

        KSLog([NSString stringWithFormat:
               @"%@SCROLL %@ frame=(%.0f,%.0f,%.0f,%.0f) offset=(%.1f,%.1f)",
               indent,
               name,
               view.frame.origin.x,
               view.frame.origin.y,
               view.frame.size.width,
               view.frame.size.height,
               scroll.contentOffset.x,
               scroll.contentOffset.y]);
    } else {
        KSLog([NSString stringWithFormat:
               @"%@VIEW %@ frame=(%.0f,%.0f,%.0f,%.0f)",
               indent,
               name,
               view.frame.origin.x,
               view.frame.origin.y,
               view.frame.size.width,
               view.frame.size.height]);
    }

    for (UIGestureRecognizer *gesture in view.gestureRecognizers) {
        KSLog([NSString stringWithFormat:
               @"%@  GESTURE %@ state=%ld",
               indent,
               NSStringFromClass(gesture.class),
               (long)gesture.state]);
    }

    for (UIView *subview in view.subviews) {
        KSDumpView(subview, depth + 1);
    }
}

static void KSDumpWindows(void) {
    KSLog(@"========================================");
    KSLog(@"KICKSTAND NOTIFICATION VIEW PROBE");
    KSLog(@"========================================");

    NSArray *windows = [UIApplication sharedApplication].windows;

    for (UIWindow *window in windows) {
        if (window.hidden || window.alpha <= 0.01) continue;

        KSLog([NSString stringWithFormat:
               @"WINDOW %@ level=%.1f frame=(%.0f,%.0f,%.0f,%.0f)",
               NSStringFromClass(window.class),
               window.windowLevel,
               window.frame.origin.x,
               window.frame.origin.y,
               window.frame.size.width,
               window.frame.size.height]);

        KSDumpView(window, 0);
    }

    KSLog(@"========================================");
}

%hook SBCoverSheetPrimarySlidingViewController

- (void)_handleDismissGesture:(id)gesture {
    static BOOL dumped = NO;

    if (!dumped) {
        dumped = YES;
        KSDumpWindows();
    }

    %orig;
}

%end