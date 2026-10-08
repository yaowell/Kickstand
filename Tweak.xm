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

static void KSFindTargetAction(UIGestureRecognizer *gesture) {
    if (KSLogged)
        return;

    UIView *view = [(UIGestureRecognizer *)gesture view];

    if (!view ||
        ![NSStringFromClass([view class]) isEqualToString:@"NCNotificationListView"])
        return;

    KSLogged = YES;

    KSLog(@"GESTURE class=%@", NSStringFromClass([gesture class]));

    Ivar targetsIvar = class_getInstanceVariable([UIGestureRecognizer class], "_targets");

    if (!targetsIvar) {
        KSLog(@"_targets NOT FOUND");
        return;
    }

    id targets = object_getIvar(gesture, targetsIvar);

    if (![targets isKindOfClass:[NSArray class]]) {
        KSLog(@"_targets invalid");
        return;
    }

    for (id item in (NSArray *)targets) {
        Ivar targetIvar = class_getInstanceVariable([item class], "_target");
        Ivar actionIvar = class_getInstanceVariable([item class], "_action");

        id target = nil;
        SEL action = NULL;

        if (targetIvar)
            target = object_getIvar(item, targetIvar);

        if (actionIvar) {
            ptrdiff_t offset = ivar_getOffset(actionIvar);
            action = *(SEL *)((uint8_t *)(__bridge void *)item + offset);
        }

        KSLog(@"TARGETCLASS=%@ ACTION=%@",
              target ? NSStringFromClass([target class]) : @"(null)",
              action ? NSStringFromSelector(action) : @"(null)");
    }
}

%hook UIPanGestureRecognizer

- (void)setState:(UIGestureRecognizerState)state {
    if (state == UIGestureRecognizerStateBegan)
        KSFindTargetAction((UIGestureRecognizer *)self);

    %orig;
}

%end