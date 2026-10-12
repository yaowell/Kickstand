#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <substrate.h>

static void CVLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    NSString *path = @"/var/mobile/Documents/CopyVaultProbe.log";
    NSString *line = [NSString stringWithFormat:@"%@ %@\n",
                      [NSDate date], message];
    NSFileHandle *file = [NSFileHandle fileHandleForWritingAtPath:path];

    if (!file) {
        [line writeToFile:path atomically:YES
                 encoding:NSUTF8StringEncoding error:nil];
    } else {
        [file seekToEndOfFile];
        [file writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
        [file closeFile];
    }
}

static BOOL CVClassOwnsMethod(Class cls, SEL selector) {
    unsigned int count = 0;
    Method *methods = class_copyMethodList(cls, &count);
    BOOL found = NO;

    for (unsigned int i = 0; i < count; i++) {
        if (method_getName(methods[i]) == selector) {
            found = YES;
            break;
        }
    }

    free(methods);
    return found;
}

static void CVHookInsertText(Class cls) {
    SEL sel = @selector(insertText:);
    if (!CVClassOwnsMethod(cls, sel)) return;

    Method method = class_getInstanceMethod(cls, sel);
    if (!method) return;

    IMP original = method_getImplementation(method);
    IMP replacement = imp_implementationWithBlock(
        ^(id self, NSString *text) {
            CVLog(@"insertText: process=%@ class=%@ text=%@",
                  [[NSProcessInfo processInfo] processName],
                  NSStringFromClass([self class]),
                  text);
            ((void (*)(id, SEL, id))original)(self, sel, text);
        }
    );

    method_setImplementation(method, replacement);
}

static void CVHookPaste(Class cls) {
    SEL sel = @selector(paste:);
    if (!CVClassOwnsMethod(cls, sel)) return;

    Method method = class_getInstanceMethod(cls, sel);
    if (!method) return;

    IMP original = method_getImplementation(method);
    IMP replacement = imp_implementationWithBlock(
        ^(id self, id event) {
            CVLog(@"paste: process=%@ class=%@ event=%@",
                  [[NSProcessInfo processInfo] processName],
                  NSStringFromClass([self class]),
                  event);
            ((void (*)(id, SEL, id))original)(self, sel, event);
        }
    );

    method_setImplementation(method, replacement);
}

static void CVHookBecomeFirstResponder(Class cls) {
    SEL sel = @selector(becomeFirstResponder);
    if (!CVClassOwnsMethod(cls, sel)) return;

    Method method = class_getInstanceMethod(cls, sel);
    if (!method) return;

    IMP original = method_getImplementation(method);
    IMP replacement = imp_implementationWithBlock(
        ^BOOL(id self) {
            BOOL result = ((BOOL (*)(id, SEL))original)(self, sel);
            CVLog(@"becomeFirstResponder process=%@ class=%@ result=%d",
                  [[NSProcessInfo processInfo] processName],
                  NSStringFromClass([self class]),
                  result);
            return result;
        }
    );

    method_setImplementation(method, replacement);
}

static void CVHookResignFirstResponder(Class cls) {
    SEL sel = @selector(resignFirstResponder);
    if (!CVClassOwnsMethod(cls, sel)) return;

    Method method = class_getInstanceMethod(cls, sel);
    if (!method) return;

    IMP original = method_getImplementation(method);
    IMP replacement = imp_implementationWithBlock(
        ^BOOL(id self) {
            BOOL result = ((BOOL (*)(id, SEL))original)(self, sel);
            CVLog(@"resignFirstResponder process=%@ class=%@ result=%d",
                  [[NSProcessInfo processInfo] processName],
                  NSStringFromClass([self class]),
                  result);
            return result;
        }
    );

    method_setImplementation(method, replacement);
}

%ctor {
    @autoreleasepool {
        NSString *process = [[NSProcessInfo processInfo] processName];
        NSString *bundle = [[NSBundle mainBundle] bundleIdentifier];

        CVLog(@"========== PROBE LOADED ==========");
        CVLog(@"process=%@ bundle=%@ version=%@",
              process,
              bundle,
              [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]);

        CVHookInsertText([UITextField class]);
        CVHookInsertText([UITextView class]);

        CVHookPaste([UITextField class]);
        CVHookPaste([UITextView class]);

        CVHookBecomeFirstResponder([UITextField class]);
        CVHookBecomeFirstResponder([UITextView class]);

        CVHookResignFirstResponder([UITextField class]);
        CVHookResignFirstResponder([UITextView class]);

        Class announcer = objc_getClass("DRPasteAnnouncer");
        if (announcer) {
            CVLog(@"DRPasteAnnouncer found: %@", announcer);
            unsigned int count = 0;
            Method *methods = class_copyMethodList(object_getClass(announcer), &count);

            for (unsigned int i = 0; i < count; i++) {
                CVLog(@"DRPasteAnnouncer class method: %@",
                      NSStringFromSelector(method_getName(methods[i])));
            }

            free(methods);
        } else {
            CVLog(@"DRPasteAnnouncer not found in this process");
        }
    }
}