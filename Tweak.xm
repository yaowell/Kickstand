#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static void KSLog(NSString *text) {
    NSString *path = @"/var/mobile/Documents/Kickstand.log";
    NSString *old = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    if (!old) old = @"";
    NSString *out = [old stringByAppendingFormat:@"%@\n", text];
    [out writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

static void DumpMethod(Class cls, NSString *name) {
    SEL sel = NSSelectorFromString(name);
    Method m = class_getInstanceMethod(cls, sel);

    if (!m) {
        KSLog([NSString stringWithFormat:@"MISSING %@ %@", NSStringFromClass(cls), name]);
        return;
    }

    const char *types = method_getTypeEncoding(m);

    KSLog([NSString stringWithFormat:
           @"METHOD %@ %@ -> %s",
           NSStringFromClass(cls),
           name,
           types ? types : "(null)"]);
}

%hook SBCoverSheetPrimarySlidingViewController

- (void)_handleDismissGesture:(id)gesture {
    static BOOL dumped = NO;

    if (!dumped) {
        dumped = YES;

        KSLog(@"========================================");
        KSLog(@"KICKSTAND METHOD ENCODING PROBE");
        KSLog(@"========================================");

        Class cls = NSClassFromString(@"SBCoverSheetPrimarySlidingViewController");
        Class superCls = NSClassFromString(@"SBCoverSheetSlidingViewController");

        DumpMethod(cls, @"_handleDismissGesture:");
        DumpMethod(cls, @"_dismissGestureChangedWithGestureRecognizer:");
        DumpMethod(cls, @"_presentOrDismissGestureEndedWithGestureRecognizer:");
        DumpMethod(cls, @"_cancelTransitionForGesture:");
        DumpMethod(cls, @"_commitTransitionToAppeared:animated:");
        DumpMethod(cls, @"_endTransitionToAppeared");
        DumpMethod(cls, @"_finishTransitionToPresented:animated:withCompletion:");
        DumpMethod(cls, @"_finalLocationForTransitionToPresented:");
        DumpMethod(cls, @"_velocityForGesture:");
        DumpMethod(cls, @"_shouldRubberBandForGestureRecognizer:");
        DumpMethod(cls, @"_shouldEndPresentedForEndingGestureRecognizer:");

        if (superCls) {
            DumpMethod(superCls, @"_handleDismissGesture:");
            DumpMethod(superCls, @"_dismissGestureChangedWithGestureRecognizer:");
            DumpMethod(superCls, @"_presentOrDismissGestureEndedWithGestureRecognizer:");
            DumpMethod(superCls, @"_cancelTransitionForGesture:");
            DumpMethod(superCls, @"_commitTransitionToAppeared:animated:");
            DumpMethod(superCls, @"_endTransitionToAppeared");
            DumpMethod(superCls, @"_finishTransitionToPresented:animated:withCompletion:");
            DumpMethod(superCls, @"_finalLocationForTransitionToPresented:");
            DumpMethod(superCls, @"_velocityForGesture:");
            DumpMethod(superCls, @"_shouldRubberBandForGestureRecognizer:");
            DumpMethod(superCls, @"_shouldEndPresentedForEndingGestureRecognizer:");
        }

        KSLog(@"========================================");
    }

    %orig;
}

%end