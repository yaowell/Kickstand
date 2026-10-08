#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

static void KSLog(NSString *s) {
    NSString *p = @"/var/mobile/Documents/Kickstand.log";
    NSString *old = [NSString stringWithContentsOfFile:p
                                              encoding:NSUTF8StringEncoding
                                                 error:nil];
    if (!old) old = @"";
    [[old stringByAppendingFormat:@"%@\n", s]
        writeToFile:p
        atomically:YES
        encoding:NSUTF8StringEncoding
        error:nil];
}

static BOOL KSIsTarget(id gesture) {
    NSString *name = gesture ? NSStringFromClass([gesture class]) : @"";
    return [name isEqualToString:@"CSScrollViewPanGestureRecognizer"] ||
           [name isEqualToString:@"UIScrollViewPanGestureRecognizer"] ||
           [name isEqualToString:@"SBCoverSheetScreenEdgePanGestureRecognizer"];
}

%hook UIGestureRecognizer

- (void)requireGestureRecognizerToFail:(UIGestureRecognizer *)other {
    if (KSIsTarget(self) || KSIsTarget(other)) {
        KSLog([NSString stringWithFormat:
               @"REQUIRE %@ -> %@",
               NSStringFromClass([self class]),
               NSStringFromClass([other class])]);
    }

    %orig;
}

- (BOOL)canPreventGestureRecognizer:(UIGestureRecognizer *)other {
    BOOL r = %orig;

    if (KSIsTarget(self) || KSIsTarget(other)) {
        KSLog([NSString stringWithFormat:
               @"CANPREVENT %@ -> %@ = %d",
               NSStringFromClass([self class]),
               NSStringFromClass([other class]),
               r]);
    }

    return r;
}

- (BOOL)canBePreventedByGestureRecognizer:(UIGestureRecognizer *)other {
    BOOL r = %orig;

    if (KSIsTarget(self) || KSIsTarget(other)) {
        KSLog([NSString stringWithFormat:
               @"CANBEPREVENT %@ <- %@ = %d",
               NSStringFromClass([self class]),
               NSStringFromClass([other class]),
               r]);
    }

    return r;
}

%end

%hook UIScrollView

- (void)setContentOffset:(CGPoint)offset {
    Class cls = NSClassFromString(@"CSScrollView");

    if (cls && [self isKindOfClass:cls]) {
        static CGFloat lastY = -99999;

        if (fabs(offset.y - lastY) > 10.0) {
            KSLog([NSString stringWithFormat:
                   @"CS OFFSET y=%.1f", offset.y]);
            lastY = offset.y;
        }
    }

    %orig;
}

%end