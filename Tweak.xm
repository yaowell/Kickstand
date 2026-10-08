#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static BOOL KSLogged = NO;

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

static void KSLogTargets(UIGestureRecognizer *gesture) {
    if (KSLogged)
        return;

    UIView *view = [(UIGestureRecognizer *)gesture view];
    if (!view)
        return;

    if (![NSStringFromClass([view class]) isEqualToString:@"NCNotificationListView"])
        return;

    KSLogged = YES;

    KSLog(@"TARGET ACTION class=%@", NSStringFromClass([gesture class]));

    Ivar targetsIvar = class_getInstanceVariable(object_getClass(gesture), "_targets");
    if (!targetsIvar)
        targetsIvar = class_getInstanceVariable([gesture class], "_targets");

    if (!targetsIvar) {
        KSLog(@"_targets IVAR NOT FOUND");
        return;
    }

    id targets = object_getIvar(gesture, targetsIvar);

    if (![targets isKindOfClass:[NSArray class]]) {
        KSLog(@"_targets is not NSArray: %@", NSStringFromClass([targets class]));
        return;
    }

    for (id item in (NSArray *)targets) {
        Ivar targetIvar = class_getInstanceVariable([item class], "_target");
        Ivar actionIvar = class_getInstanceVariable([item class], "_action");

        id target = targetIvar ? object_getIvar(item, targetIvar) : nil;
        id action = actionIvar ? object_getIvar(item, actionIvar) : nil;

        KSLog(@"TARGET=%@ ACTION=%@ TARGETCLASS=%@",
              target,
              action,
              target ? NSStringFromClass([target class]) : @"(null)");
    }
}

%hook UIPanGestureRecognizer

- (void)setState:(UIGestureRecognizerState)state {
    if (state == UIGestureRecognizerStateBegan) {
        KSLogTargets((UIGestureRecognizer *)self);
    }

    %orig;
}

%end