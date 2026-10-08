#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

static int KSCount = 0;

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

%hook UIGestureRecognizer

- (void)setState:(UIGestureRecognizerState)state {
    if (state == UIGestureRecognizerStateBegan && KSCount < 3) {
        KSCount++;

        NSString *cls = NSStringFromClass([self class]);
        NSString *viewCls = self.view ? NSStringFromClass([self.view class]) : @"(null)";

        CGPoint t = CGPointZero;
        CGPoint v = CGPointZero;

        if ([self isKindOfClass:[UIPanGestureRecognizer class]]) {
            UIPanGestureRecognizer *pan = (UIPanGestureRecognizer *)self;
            UIView *view = self.view;
            t = [pan translationInView:view];
            v = [pan velocityInView:view];
        }

        KSLog(@"ACTION %d recognizer=%@ view=%@ translation=(%.1f,%.1f) velocity=(%.1f,%.1f)",
              KSCount,
              cls,
              viewCls,
              t.x, t.y,
              v.x, v.y);

        if (KSCount >= 3) {
            KSLog(@"=== THREE ACTIONS CAPTURED ===");
        }
    }

    %orig;
}

%end