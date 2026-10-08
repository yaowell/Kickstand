#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

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

static void KSLogGesture(UIGestureRecognizer *gr,
                         UIGestureRecognizerState state) {
    if (!KSTargetGesture(gr)) return;

    UIView *view = gr.view;

    CGPoint translation = [gr translationInView:view];
    CGPoint velocity = [gr velocityInView:view];
    CGPoint location = [gr locationInView:view];

    NSString *name = NSStringFromClass([gr class]);

    KSLog(@"");
    KSLog(@"========== %@ ==========", name);
    KSLog(@"state=%@", KSState(state));
    KSLog(@"translation=(%.1f, %.1f)",
          translation.x,
          translation.y);
    KSLog(@"velocity=(%.1f, %.1f)",
          velocity.x,
          velocity.y);
    KSLog(@"location=(%.1f, %.1f)",
          location.x,
          location.y);
    KSLog(@"view=%@",
          view ? NSStringFromClass([view class]) : @"<nil>");
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
    gSeen = [NSMutableSet set];

    KSLog(@"");
    KSLog(@"========================================");
    KSLog(@"Kickstand DIRECTION PROBE LOADED");
    KSLog(@"========================================");

    KSSaveLog();
}