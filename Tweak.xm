#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static NSString *KSPath(void) {
    return @"/var/mobile/Documents/Kickstand.log";
}

static void KSLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *s = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    [s writeToFile:KSPath()
        atomically:YES
          encoding:NSUTF8StringEncoding
             error:nil];

    NSString *old = [NSString stringWithContentsOfFile:KSPath()
                                               encoding:NSUTF8StringEncoding
                                                  error:nil];

    if (old.length > 0) {
        NSString *out = [old stringByAppendingFormat:@"\n"];
        [out writeToFile:KSPath()
              atomically:YES
                encoding:NSUTF8StringEncoding
                   error:nil];
    }
}

%ctor {
    Class cls = objc_getClass("SBCoverSheetPrimarySlidingViewController");

    if (!cls) {
        KSLog(@"SBCoverSheetPrimarySlidingViewController NOT FOUND");
        return;
    }

    KSLog(@"");
    KSLog(@"========================================");
    KSLog(@"Kickstand METHOD PROBE");
    KSLog(@"========================================");

    unsigned int count = 0;
    Method *methods = class_copyMethodList(cls, &count);

    for (unsigned int i = 0; i < count; i++) {
        SEL sel = method_getName(methods[i]);
        NSString *name = NSStringFromSelector(sel);

        NSString *lower = [name lowercaseString];

        if ([lower containsString:@"dismiss"] ||
            [lower containsString:@"gesture"] ||
            [lower containsString:@"transition"] ||
            [lower containsString:@"present"] ||
            [lower containsString:@"slide"] ||
            [lower containsString:@"animate"] ||
            [lower containsString:@"cancel"]) {

            KSLog(@"METHOD: %@", name);
        }
    }

    free(methods);

    KSLog(@"");
    KSLog(@"========================================");
    KSLog(@"END METHOD PROBE");
    KSLog(@"========================================");
}