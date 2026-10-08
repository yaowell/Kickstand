#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

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

%hook CCUIDismissalGestureRecognizer

- (void)setState:(UIGestureRecognizerState)state {
    if (state == UIGestureRecognizerStateBegan ||
        state == UIGestureRecognizerStateChanged ||
        state == UIGestureRecognizerStateEnded ||
        state == UIGestureRecognizerStateCancelled ||
        state == UIGestureRecognizerStateFailed) {

        UIPanGestureRecognizer *pan = (UIPanGestureRecognizer *)self;

        KSLog(@"CCUIDismissal state=%ld translation=(%.1f,%.1f) velocity=(%.1f,%.1f)",
              (long)state,
              [pan translationInView:self.view].x,
              [pan translationInView:self.view].y,
              [pan velocityInView:self.view].x,
              [pan velocityInView:self.view].y);
    }

    %orig;
}

%end