#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

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

%hook SBCoverSheetSlidingViewController

- (BOOL)_shouldEndPresentedForEndingGestureRecognizer:(id)gesture {
    BOOL result = %orig;

    KSLog([NSString stringWithFormat:
           @"_shouldEndPresentedForEndingGestureRecognizer: result=%d gesture=%@",
           result,
           gesture ? NSStringFromClass([gesture class]) : @"(nil)"]);

    return result;
}

%end

%hook SBCoverSheetPrimarySlidingViewController

- (void)_handleDismissGesture:(id)gesture {
    KSLog(@"_handleDismissGesture called");
    %orig;
}

%end