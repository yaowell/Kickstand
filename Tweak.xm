#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

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

%hook UIPanGestureRecognizer

- (void)setState:(UIGestureRecognizerState)state {
    UIView *view = [(UIGestureRecognizer *)self view];

    if (view &&
        [NSStringFromClass([view class]) isEqualToString:@"NCNotificationListView"] &&
        (state == UIGestureRecognizerStateBegan ||
         state == UIGestureRecognizerStateChanged ||
         state == UIGestureRecognizerStateEnded ||
         state == UIGestureRecognizerStateCancelled ||
         state == UIGestureRecognizerStateFailed)) {

        CGPoint t = [self translationInView:view];
        CGPoint v = [self velocityInView:view];

        KSLog(@"state=%ld class=%@ translation=(%.1f,%.1f) velocity=(%.1f,%.1f)",
              (long)state,
              NSStringFromClass([self class]),
              t.x, t.y,
              v.x, v.y);
    }

    %orig;
}

%end