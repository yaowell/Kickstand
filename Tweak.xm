#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static NSString *KSPath(void) {
    return @"/var/mobile/Documents/Kickstand.log";
}

static void KSLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *s = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    NSString *old = [NSString stringWithContentsOfFile:KSPath()
                                               encoding:NSUTF8StringEncoding
                                                  error:nil];

    if (!old) old = @"";

    NSString *out = [old stringByAppendingFormat:@"%@\n", s];

    if (out.length > 500000) {
        out = [out substringFromIndex:out.length - 400000];
    }

    [out writeToFile:KSPath()
          atomically:YES
            encoding:NSUTF8StringEncoding
               error:nil];
}

static NSString *KSClass(id obj) {
    if (!obj) return @"<nil>";
    return NSStringFromClass([obj class]);
}

static BOOL KSInterestingClass(Class cls) {
    if (!cls) return NO;

    NSString *n = NSStringFromClass(cls);

    NSArray *keys = @[
        @"Notification",
        @"CoverSheet",
        @"SBCover",
        @"SB",
        @"NC",
        @"Lock",
        @"Bulletin"
    ];

    for (NSString *key in keys) {
        if ([n rangeOfString:key options:NSCaseInsensitiveSearch].location != NSNotFound) {
            return YES;
        }
    }

    return NO;
}

static void KSLogRecognizer(UIGestureRecognizer *gr, NSString *reason) {
    if (!KSInterestingClass([gr class])) return;

    UIView *view = gr.view;

    KSLog(@"[GR] %@ | class=%@ state=%ld view=%@",
          reason,
          KSClass(gr),
          (long)gr.state,
          KSClass(view));

    UIView *v = view;
    int level = 0;

    while (v && level < 8) {
        KSLog(@"    view[%d] = %@ frame=%@",
              level,
              KSClass(v),
              NSStringFromCGRect(v.frame));

        v = v.superview;
        level++;
    }
}

%hook UIGestureRecognizer

- (void)setState:(UIGestureRecognizerState)state {
    BOOL interesting = KSInterestingClass([self class]);

    if (interesting) {
        KSLogRecognizer(self,
                        [NSString stringWithFormat:@"BEFORE state=%ld -> %ld",
                         (long)self.state,
                         (long)state]);
    }

    %orig;

    if (interesting) {
        KSLogRecognizer(self,
                        [NSString stringWithFormat:@"AFTER state=%ld",
                         (long)self.state]);
    }
}

%end

static BOOL gTouchActive = NO;

%hook UIApplication

- (void)sendEvent:(UIEvent *)event {
    NSSet *touches = event.allTouches;

    for (UITouch *touch in touches) {
        if (touch.phase == UITouchPhaseBegan) {
            gTouchActive = YES;

            UIWindow *window = touch.window;

            KSLog(@"");
            KSLog(@"========== TOUCH BEGAN ==========");
            KSLog(@"window=%@ key=%d hidden=%d",
                  KSClass(window),
                  window.isKeyWindow,
                  window.hidden);

            UIView *v = touch.view;
            int level = 0;

            while (v && level < 10) {
                KSLog(@"view[%d]=%@ frame=%@",
                      level,
                      KSClass(v),
                      NSStringFromCGRect(v.frame));

                for (UIGestureRecognizer *gr in v.gestureRecognizers) {
                    KSLogRecognizer(gr, @"ATTACHED");
                }

                v = v.superview;
                level++;
            }
        }

        if (gTouchActive &&
            (touch.phase == UITouchPhaseEnded ||
             touch.phase == UITouchPhaseCancelled)) {

            KSLog(@"========== TOUCH %@ ==========",
                  touch.phase == UITouchPhaseEnded ? @"ENDED" : @"CANCELLED");

            gTouchActive = NO;
        }
    }

    %orig;
}

%end

%ctor {
    KSLog(@"");
    KSLog(@"========================================");
    KSLog(@"Kickstand PROBE LOADED");
    KSLog(@"========================================");
}