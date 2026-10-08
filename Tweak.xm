#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

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

static BOOL KSTargetGesture(UIGestureRecognizer *gr) {
    NSString *name = NSStringFromClass([gr class]);

    return [name isEqualToString:@"SBCoverSheetPresentationGestureRecognizer"] ||
           [name isEqualToString:@"SBCoverSheetScreenEdgePanGestureRecognizer"];
}

static NSString *KSState(UIGestureRecognizerState state) {
    switch (state) {
        case UIGestureRecognizerStatePossible:
            return @"POSSIBLE";
        case UIGestureRecognizerStateBegan:
            return @"BEGAN";
        case UIGestureRecognizerStateChanged:
            return @"CHANGED";
        case UIGestureRecognizerStateEnded:
            return @"ENDED";
        case UIGestureRecognizerStateCancelled:
            return @"CANCELLED";
        case UIGestureRecognizerStateFailed:
            return @"FAILED";
    }

    return @"UNKNOWN";
}

static void KSLogTargets(UIGestureRecognizer *gr) {
    NSArray *targets = nil;

    @try {
        targets = [gr valueForKey:@"_targets"];
    } @catch (...) {
        targets = nil;
    }

    KSLog(@"targets=%@", targets);

    if (!targets) return;

    for (id targetInfo in targets) {
        id target = nil;
        id action = nil;

        @try {
            target = [targetInfo valueForKey:@"_target"];
        } @catch (...) {
        }

        @try {
            action = [targetInfo valueForKey:@"_action"];
        } @catch (...) {
        }

        KSLog(@"target=%@ class=%@",
              target,
              target ? NSStringFromClass([target class]) : @"<nil>");

        KSLog(@"action=%@",
              action);
    }
}

static void KSLogGesture(UIGestureRecognizer *gr,
                         UIGestureRecognizerState state) {
    if (!KSTargetGesture(gr)) return;

    KSLog(@"");
    KSLog(@"========================================");
    KSLog(@"GESTURE %@", NSStringFromClass([gr class]));
    KSLog(@"state=%@", KSState(state));
    KSLog(@"========================================");

    UIView *view = gr.view;

    KSLog(@"view=%@",
          view ? NSStringFromClass([view class]) : @"<nil>");

    if ([gr isKindOfClass:[UIPanGestureRecognizer class]]) {
        UIPanGestureRecognizer *pan =
            (UIPanGestureRecognizer *)gr;

        CGPoint translation = [pan translationInView:view];
        CGPoint velocity = [pan velocityInView:view];

        KSLog(@"translation=(%.1f, %.1f)",
              translation.x,
              translation.y);

        KSLog(@"velocity=(%.1f, %.1f)",
              velocity.x,
              velocity.y);

        KSLog(@"location=(%.1f, %.1f)",
              [pan locationInView:view].x,
              [pan locationInView:view].y);
    }

    KSLogTargets(gr);
}

%hook UIGestureRecognizer

- (void)setState:(UIGestureRecognizerState)state {
    if (KSTargetGesture(self) &&
        self.state != state) {

        KSLogGesture(self, state);

        if (state == UIGestureRecognizerStateEnded ||
            state == UIGestureRecognizerStateCancelled ||
            state == UIGestureRecognizerStateFailed) {
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
    KSLog(@"Kickstand TARGET PROBE LOADED");
    KSLog(@"========================================");

    KSSaveLog();
}