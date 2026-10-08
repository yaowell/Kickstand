#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static NSMutableString *gLog;
static NSMutableSet *gSeen;

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

static NSString *KSClass(id obj) {
    if (!obj) return @"<nil>";
    return NSStringFromClass([obj class]);
}

static BOOL KSInterestingClass(Class cls) {
    if (!cls) return NO;

    NSString *name = NSStringFromClass(cls);

    NSArray *keys = @[
        @"Notification",
        @"CoverSheet",
        @"SBCover",
        @"NC",
        @"Lock",
        @"Bulletin"
    ];

    for (NSString *key in keys) {
        if ([name rangeOfString:key
                        options:NSCaseInsensitiveSearch].location != NSNotFound) {
            return YES;
        }
    }

    return NO;
}

static void KSDescribeGesture(UIGestureRecognizer *gr,
                              NSString *event) {
    if (!gr) return;

    Class cls = [gr class];

    if (!KSInterestingClass(cls)) return;

    NSString *className = NSStringFromClass(cls);

    if (!gSeen) {
        gSeen = [NSMutableSet set];
    }

    NSString *key = [NSString stringWithFormat:@"%@:%@",
                     className,
                     event];

    if ([gSeen containsObject:key]) {
        return;
    }

    [gSeen addObject:key];

    UIView *view = gr.view;

    KSLog(@"");
    KSLog(@"[GESTURE]");
    KSLog(@"event=%@", event);
    KSLog(@"class=%@", className);
    KSLog(@"state=%ld", (long)gr.state);
    KSLog(@"view=%@", KSClass(view));

    if (view) {
        KSLog(@"viewFrame=%@", NSStringFromCGRect(view.frame));
    }

    UIView *superview = view.superview;

    int level = 0;

    while (superview && level < 5) {
        KSLog(@"super[%d]=%@ frame=%@",
              level,
              KSClass(superview),
              NSStringFromCGRect(superview.frame));

        superview = superview.superview;
        level++;
    }
}

%hook UIGestureRecognizer

- (void)setState:(UIGestureRecognizerState)state {
    if (KSInterestingClass([self class])) {
        UIGestureRecognizerState oldState = self.state;

        if (oldState != state) {
            NSString *event = nil;

            switch (state) {
                case UIGestureRecognizerStatePossible:
                    event = @"POSSIBLE";
                    break;

                case UIGestureRecognizerStateBegan:
                    event = @"BEGAN";
                    break;

                case UIGestureRecognizerStateChanged:
                    event = @"CHANGED";
                    break;

                case UIGestureRecognizerStateEnded:
                    event = @"ENDED";
                    break;

                case UIGestureRecognizerStateCancelled:
                    event = @"CANCELLED";
                    break;

                case UIGestureRecognizerStateFailed:
                    event = @"FAILED";
                    break;
            }

            if (event) {
                KSDescribeGesture(self, event);

                if (state == UIGestureRecognizerStateEnded ||
                    state == UIGestureRecognizerStateCancelled ||
                    state == UIGestureRecognizerStateFailed) {
                    KSSaveLog();
                }
            }
        }
    }

    %orig;
}

%end

%ctor {
    gLog = [NSMutableString string];
    gSeen = [NSMutableSet set];

    KSLog(@"");
    KSLog(@"========================================");
    KSLog(@"Kickstand LIGHT PROBE LOADED");
    KSLog(@"========================================");

    KSSaveLog();
}