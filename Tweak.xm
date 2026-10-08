#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static NSMutableString *gLog;
static BOOL gDumped = NO;

static NSString *KSPath(void) {
    return @"/var/mobile/Documents/Kickstand.log";
}

static void KSLog(NSString *format, ...) {
    if (!gLog) {
        gLog = [NSMutableString string];
    }

    va_list args;
    va_start(args, format);
    NSString *s = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    [gLog appendFormat:@"%@\n", s];
}

static void KSSave(void) {
    if (!gLog) return;

    [gLog writeToFile:KSPath()
           atomically:YES
             encoding:NSUTF8StringEncoding
                error:nil];
}

static void KSDumpMethods(id obj) {
    if (gDumped || !obj) return;

    gDumped = YES;

    Class cls = object_getClass(obj);

    KSLog(@"");
    KSLog(@"========================================");
    KSLog(@"METHOD DUMP");
    KSLog(@"class=%@", NSStringFromClass(cls));
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
            [lower containsString:@"cancel"] ||
            [lower containsString:@"finish"] ||
            [lower containsString:@"complete"]) {

            KSLog(@"METHOD: %@", name);
        }
    }

    free(methods);

    KSLog(@"========================================");
    KSLog(@"END METHOD DUMP");
    KSLog(@"========================================");

    KSSave();
}

%hook SBCoverSheetPrimarySlidingViewController

- (void)_handleDismissGesture:(id)gesture {
    if (!gDumped) {
        KSLog(@"");
        KSLog(@"========================================");
        KSLog(@"HANDLE DISMISS GESTURE FOUND");
        KSLog(@"class=%@",
              NSStringFromClass([self class]));
        KSLog(@"========================================");

        KSDumpMethods(self);
    }

    %orig;
}

%end

%ctor {
    gLog = [NSMutableString string];

    KSLog(@"");
    KSLog(@"========================================");
    KSLog(@"Kickstand METHOD PROBE LOADED");
    KSLog(@"========================================");

    KSSave();
}