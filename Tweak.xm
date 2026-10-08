#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static BOOL gDumped = NO;

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

static void KSDumpMethods(id obj) {
    Class cls = object_getClass(obj);

    while (cls) {
        unsigned int count = 0;
        Method *methods = class_copyMethodList(cls, &count);

        KSLog([NSString stringWithFormat:@"--- CLASS %@ ---",
               NSStringFromClass(cls)]);

        for (unsigned int i = 0; i < count; i++) {
            SEL sel = method_getName(methods[i]);
            NSString *name = NSStringFromSelector(sel);

            if ([name rangeOfString:@"dismiss"
                            options:NSCaseInsensitiveSearch].location != NSNotFound ||
                [name rangeOfString:@"gesture"
                            options:NSCaseInsensitiveSearch].location != NSNotFound ||
                [name rangeOfString:@"transition"
                            options:NSCaseInsensitiveSearch].location != NSNotFound ||
                [name rangeOfString:@"present"
                            options:NSCaseInsensitiveSearch].location != NSNotFound ||
                [name rangeOfString:@"slide"
                            options:NSCaseInsensitiveSearch].location != NSNotFound ||
                [name rangeOfString:@"animate"
                            options:NSCaseInsensitiveSearch].location != NSNotFound ||
                [name rangeOfString:@"cancel"
                            options:NSCaseInsensitiveSearch].location != NSNotFound ||
                [name rangeOfString:@"finish"
                            options:NSCaseInsensitiveSearch].location != NSNotFound ||
                [name rangeOfString:@"complete"
                            options:NSCaseInsensitiveSearch].location != NSNotFound) {

                KSLog([NSString stringWithFormat:@"%@", name]);
            }
        }

        free(methods);
        cls = class_getSuperclass(cls);
    }
}

%hook SBCoverSheetPrimarySlidingViewController

- (void)_handleDismissGesture:(id)gesture {

    if (!gDumped) {
        gDumped = YES;

        KSLog(@"========================================");
        KSLog(@"Kickstand METHOD PROBE");
        KSLog(@"========================================");

        KSDumpMethods(self);

        KSLog(@"========================================");
    }

    %orig;
}

%end