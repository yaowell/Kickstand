#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static NSString *KPPath(void) {
    return @"/var/mobile/Documents/KeepNotificationProbe.log";
}

static void KPLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *s = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    NSString *old = [NSString stringWithContentsOfFile:KPPath()
                                               encoding:NSUTF8StringEncoding
                                                  error:nil];

    if (!old) old = @"";

    NSString *out = [old stringByAppendingFormat:@"%@\n", s];

    if (out.length > 500000) {
        out = [out substringFromIndex:out.length - 400000];
    }

    [out writeToFile:KPPath()
          atomically:YES
            encoding:NSUTF8StringEncoding
               error:nil];
}

static NSString *KPClass(id obj) {
    if (!obj) return @"<nil>";
    return NSStringFromClass([obj class]);
}

static BOOL KPInterestingClass(Class cls) {
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

static void KPLogRecognizer(UIGestureRecognizer *gr, NSString *reason) {
    if (!KPInterestingClass([gr class])) return;

    UIView *view = gr.view;

    KPLog(@"[GR] %@ | class=%@ state=%ld view=%@",
          reason,
          KPClass(gr),
          (long)gr.state,
          KPClass(view));

    UIView *v = view;
    int level = 0;

    while (v && level < 8) {
        KPLog(@"    view[%d] = %@ frame=%@",
              level,
              KPClass(v),
              NSStringFromCGRect(v.frame));

        v = v.superview;
        level++;
    }
}

%hook UIGestureRecognizer

- (void)setState:(UIGestureRecognizerState)state {
    BOOL interesting = KPInterestingClass([self class]);

    if (interesting) {
        KPLogRecognizer(self,
                        [NSString stringWithFormat:@"BEFORE state=%ld -> %ld",
                         (long)self.state,
                         (long)state]);
    }

    %orig;

    if (interesting) {
        KPLogRecognizer(self,
                        [NSString stringWithFormat:@"AFTER state=%ld",
                         (long)self.state]);
    }
}

%end

static BOOL gTouchActive = NO;
static BOOL gTouchLogged = NO;

%hook UIApplication

- (void)sendEvent:(UIEvent *)event {
    NSSet *touches = [event touchesForWindow:nil];

    for (UITouch *touch in touches) {
        if (touch.phase == UITouchPhaseBegan) {
            gTouchActive = YES;
            gTouchLogged = NO;

            UIWindow *window = touch.window;

            KPLog(@"");
            KPLog(@"========== TOUCH BEGAN ==========");
            KPLog(@"window=%@ key=%d hidden=%d",
                  KPClass(window),
                  window.isKeyWindow,
                  window.hidden);

            UIView *v = touch.view;
            int level = 0;

            while (v && level < 10) {
                KPLog(@"view[%d]=%@ frame=%@",
                      level,
                      KPClass(v),
                      NSStringFromCGRect(v.frame));

                for (UIGestureRecognizer *gr in v.gestureRecognizers) {
                    KPLogRecognizer(gr, @"ATTACHED");
                }

                v = v.superview;
                level++;
            }

            gTouchLogged = YES;
        }

        if (gTouchActive &&
            (touch.phase == UITouchPhaseEnded ||
             touch.phase == UITouchPhaseCancelled)) {

            KPLog(@"========== TOUCH %@ ==========",
                  touch.phase == UITouchPhaseEnded ? @"ENDED" : @"CANCELLED");

            gTouchActive = NO;
        }
    }

    %orig;
}

%end

%ctor {
    KPLog(@"");
    KPLog(@"========================================");
    KPLog(@"KeepNotificationProbe LOADED");
    KPLog(@"========================================");
}