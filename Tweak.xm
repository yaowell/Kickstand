#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <substrate.h>
#import <stdarg.h>

static NSString * const CVLogPath = @"/var/mobile/Documents/CopyVaultProbe.log";

static void CVLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    NSString *line = [NSString stringWithFormat:@"%@ %@\n", [NSDate date], message];

    @synchronized ([NSObject class]) {
        NSFileHandle *file = [NSFileHandle fileHandleForWritingAtPath:CVLogPath];
        if (file) {
            [file seekToEndOfFile];
            [file writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
            [file closeFile];
        } else {
            [line writeToFile:CVLogPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
        }
    }
}

static NSString *CVProcessInfo(void) {
    NSString *process = [[NSProcessInfo processInfo] processName];
    NSString *bundle = [[NSBundle mainBundle] bundleIdentifier];
    return [NSString stringWithFormat:@"process=%@ bundle=%@",
            process ?: @"?", bundle ?: @"?"];
}

static BOOL CVClassOwnsMethod(Class cls, SEL sel) {
    unsigned int count = 0;
    Method *methods = class_copyMethodList(cls, &count);
    BOOL found = NO;

    for (unsigned int i = 0; i < count; i++) {
        if (method_getName(methods[i]) == sel) {
            found = YES;
            break;
        }
    }

    free(methods);
    return found;
}

static void CVHookSendAction(void) {
    Class cls = objc_getClass("UIApplication");
    SEL sel = @selector(sendAction:to:from:forEvent:);

    if (!cls || !CVClassOwnsMethod(cls, sel)) {
        CVLog(@"sendAction hook skipped");
        return;
    }

    Method method = class_getInstanceMethod(cls, sel);
    IMP original = method_getImplementation(method);

    IMP replacement = imp_implementationWithBlock(
        ^BOOL(id self, SEL action, id target, id sender, id event) {
            NSString *actionName = NSStringFromSelector(action);

            CVLog(@"sendAction ENTER %@ action=%@ target=%@ sender=%@",
                  CVProcessInfo(),
                  actionName ?: @"?",
                  target ? NSStringFromClass([target class]) : @"nil",
                  sender ? NSStringFromClass([sender class]) : @"nil");

            BOOL result = ((BOOL (*)(id, SEL, SEL, id, id, id))
                           original)(self, sel, action, target, sender, event);

            CVLog(@"sendAction EXIT action=%@ result=%d",
                  actionName ?: @"?", result);
            return result;
        });

    method_setImplementation(method, replacement);
    CVLog(@"hooked UIApplication sendAction");
}

static void CVHookPasteOnClass(Class cls) {
    SEL sel = @selector(paste:);
    if (!cls || !CVClassOwnsMethod(cls, sel)) return;

    Method method = class_getInstanceMethod(cls, sel);
    if (!method) return;

    IMP original = method_getImplementation(method);

    IMP replacement = imp_implementationWithBlock(
        ^(id self, id sender) {
            CVLog(@"paste ENTER %@ class=%@ sender=%@",
                  CVProcessInfo(),
                  NSStringFromClass([self class]),
                  sender ? NSStringFromClass([sender class]) : @"nil");

            ((void (*)(id, SEL, id))original)(self, sel, sender);

            CVLog(@"paste EXIT %@ class=%@",
                  CVProcessInfo(), NSStringFromClass([self class]));
        });

    method_setImplementation(method, replacement);
    CVLog(@"hooked paste: owner=%@", NSStringFromClass(cls));
}

static void CVHookInsertTextOnClass(Class cls) {
    SEL sel = @selector(insertText:);
    if (!cls || !CVClassOwnsMethod(cls, sel)) return;

    Method method = class_getInstanceMethod(cls, sel);
    if (!method) return;

    IMP original = method_getImplementation(method);

    IMP replacement = imp_implementationWithBlock(
        ^(id self, NSString *text) {
            CVLog(@"insertText %@ class=%@ length=%lu text=%@",
                  CVProcessInfo(),
                  NSStringFromClass([self class]),
                  (unsigned long)[text length],
                  text ?: @"(nil)");

            ((void (*)(id, SEL, id))original)(self, sel, text);
        });

    method_setImplementation(method, replacement);
    CVLog(@"hooked insertText: owner=%@", NSStringFromClass(cls));
}

static void CVHookResponderMethod(Class cls, SEL sel) {
    if (!cls || !CVClassOwnsMethod(cls, sel)) return;

    Method method = class_getInstanceMethod(cls, sel);
    if (!method) return;

    IMP original = method_getImplementation(method);

    IMP replacement = imp_implementationWithBlock(
        ^BOOL(id self) {
            BOOL result = ((BOOL (*)(id, SEL))original)(self, sel);

            CVLog(@"%@ %@ class=%@ result=%d",
                  NSStringFromSelector(sel),
                  CVProcessInfo(),
                  NSStringFromClass([self class]),
                  result);
            return result;
        });

    method_setImplementation(method, replacement);
    CVLog(@"hooked %@ owner=%@",
          NSStringFromSelector(sel), NSStringFromClass(cls));
}

%ctor {
    @autoreleasepool {
        CVLog(@"========== PROBE LOADED ==========");
        CVLog(@"%@", CVProcessInfo());
        CVLog(@"bundleVersion=%@",
              [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]);

        CVHookSendAction();

        Class responder = objc_getClass("UIResponder");
        Class application = objc_getClass("UIApplication");
        Class view = objc_getClass("UIView");
        Class control = objc_getClass("UIControl");
        Class textField = objc_getClass("UITextField");
        Class textView = objc_getClass("UITextView");

        CVHookPasteOnClass(responder);
        CVHookPasteOnClass(view);
        CVHookPasteOnClass(control);
        CVHookPasteOnClass(textField);
        CVHookPasteOnClass(textView);

        CVHookInsertTextOnClass(textField);
        CVHookInsertTextOnClass(textView);

        CVHookResponderMethod(responder, @selector(becomeFirstResponder));
        CVHookResponderMethod(responder, @selector(resignFirstResponder));
        CVHookResponderMethod(view, @selector(becomeFirstResponder));
        CVHookResponderMethod(view, @selector(resignFirstResponder));
        CVHookResponderMethod(textField, @selector(becomeFirstResponder));
        CVHookResponderMethod(textField, @selector(resignFirstResponder));
        CVHookResponderMethod(textView, @selector(becomeFirstResponder));
        CVHookResponderMethod(textView, @selector(resignFirstResponder));

        CVLog(@"========== HOOK SETUP FINISHED ==========");
    }
}