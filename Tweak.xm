#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static void KSLog(NSString *text) {
    NSString *path = @"/var/mobile/Documents/Kickstand.log";
    NSString *old = [NSString stringWithContentsOfFile:path
                                              encoding:NSUTF8StringEncoding
                                                 error:nil];
    if (!old) old = @"";

    NSString *out = [old stringByAppendingFormat:@"%@\n", text];
    [out writeToFile:path
          atomically:YES
            encoding:NSUTF8StringEncoding
               error:nil];
}

static void KSDumpMethodTypes(Class cls, NSString *className) {
    NSArray *names = @[
        @"_presentOrDismissGestureEndedWithGestureRecognizer:",
        @"_dismissGestureChangedWithGestureRecognizer:",
        @"_cancelTransitionForGesture:",
        @"_commitTransitionToAppeared:animated:",
        @"_endTransitionToAppeared",
        @"_finishTransitionToPresented:animated:withCompletion:",
        @"_shouldEndPresentedForEndingGestureRecognizer:",
        @"_finalLocationForTransitionToPresented:",
        @"_velocityForGesture:",
        @"_shouldRubberBandForGestureRecognizer:",
        @"_transitionToViewControllerAppearState:ifNeeded:forUserGesture:",
        @"_transitionToViewControllerAppearState:forUserGesture:",
        @"_animationTickedWithProgress:velocity:forPresentationValue:",
        @"_positionSubviewsForContentFrame:forPresentationValue:",
        @"_updatePositionViewForProgress:forPresentationValue:",
        @"_averageVelocityForGesture:"
    ];

    for (NSString *name in names) {
        SEL sel = NSSelectorFromString(name);
        Method method = class_getInstanceMethod(cls, sel);

        if (method) {
            const char *types = method_getTypeEncoding(method);
            KSLog([NSString stringWithFormat:
                   @"METHOD %@ [%@] type=%s",
                   name,
                   className,
                   types]);
        } else {
            KSLog([NSString stringWithFormat:
                   @"METHOD %@ [%@] NOT FOUND",
                   name,
                   className]);
        }
    }
}

static BOOL gDumped = NO;

%hook SBCoverSheetPrimarySlidingViewController

- (void)_handleDismissGesture:(id)gesture {
    if (!gDumped) {
        gDumped = YES;

        KSLog(@"========================================");
        KSLog(@"KICKSTAND METHOD TYPE PROBE");
        KSLog(@"========================================");

        Class cls = object_getClass(self);
        Class current = cls;

        while (current) {
            NSString *name = NSStringFromClass(current);

            if ([name containsString:@"SBCoverSheet"]) {
                KSLog([NSString stringWithFormat:
                       @"CLASS %@", name]);

                KSDumpMethodTypes(current, name);
            }

            current = class_getSuperclass(current);
        }

        KSLog(@"========================================");
    }

    %orig;
}

%end