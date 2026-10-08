#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

static BOOL KSActive = NO;
static int KSLastState = -1;

static void KSLog(NSString *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    NSString *s = [[NSString alloc] initWithFormat:fmt arguments:args];
    va_end(args);

    NSString *line = [NSString stringWithFormat:@"[Kickstand] %@\n", s];
    NSString *path = @"/var/mobile/Documents/Kickstand.log";

    NSFileHandle *f = [NSFileHandle fileHandleForWritingAtPath:path];
    if (!f) {
        [line writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    } else {
        [f seekToEndOfFile];
        [f writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
        [f closeFile];
    }
}

static void KSRecord(NSString *name, UIGestureRecognizer *g, UIGestureRecognizerState state) {
    if (!g.view || ![NSStringFromClass(g.view.class) isEqualToString:@"NCNotificationListView"])
        return;

    UIPanGestureRecognizer *pan = nil;
    if ([g isKindOfClass:[UIPanGestureRecognizer class]])
        pan = (UIPanGestureRecognizer *)g;

    CGPoint t = CGPointZero;
    CGPoint v = CGPointZero;

    if (pan) {
        t = [pan translationInView:g.view];
        v = [pan velocityInView:g.view];
    }

    KSLog(@"%@ state=%ld class=%@ translation=(%.1f,%.1f) velocity=(%.1f,%.1f)",
          name,
          (long)state,
          NSStringFromClass(g.class),
          t.x, t.y,
          v.x, v.y);
}

%hook UIScrollViewPanGestureRecognizer

- (void)setState:(UIGestureRecognizerState)state {
    if (self.view &&
        [NSStringFromClass(self.view.class) isEqualToString:@"NCNotificationListView"]) {

        if (state == UIGestureRecognizerStateBegan ||
            state == UIGestureRecognizerStateEnded ||
            state == UIGestureRecognizerStateCancelled ||
            state == UIGestureRecognizerStateFailed) {

            KSRecord(@"SCROLL", self, state);
        }
    }

    %orig;
}

%end

%hook UIPanGestureRecognizer

- (void)setState:(UIGestureRecognizerState)state {
    if (self.view &&
        [NSStringFromClass(self.view.class) isEqualToString:@"NCNotificationListView"] &&
        ![self isKindOfClass:[UIScrollViewPanGestureRecognizer class]]) {

        if (state == UIGestureRecognizerStateBegan ||
            state == UIGestureRecognizerStateEnded ||
            state == UIGestureRecognizerStateCancelled ||
            state == UIGestureRecognizerStateFailed) {

            KSRecord(@"PAN", self, state);
        }
    }

    %orig;
}

%end