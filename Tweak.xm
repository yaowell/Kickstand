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

%hook SBCoverSheetSlidingViewController

- (void)_presentOrDismissGestureEndedWithGestureRecognizer:(id)gesture {
    KSLog(@"CALL END BEGIN");

    %orig;

    KSLog(@"CALL END AFTER");
}

- (void)_cancelTransitionForGesture:(id)gesture {
    KSLog(@"CALL CANCEL");

    %orig;
}

- (void)_commitTransitionToAppeared:(BOOL)animated {
    KSLog([NSString stringWithFormat:
           @"CALL COMMIT_APPEARED animated=%d", animated]);

    %orig;
}

- (void)_finishTransitionToPresented:(BOOL)animated
                    withCompletion:(id)completion {
    KSLog([NSString stringWithFormat:
           @"CALL FINISH_PRESENTED animated=%d", animated]);

    %orig;
}

%end