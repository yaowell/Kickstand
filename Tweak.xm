#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

static void LSRLog(NSString *msg) {
    NSString *path = @"/var/mobile/Documents/LockScreenDebug.log";
    NSString *line = [NSString stringWithFormat:@"[LSR] %@ %@\n",
        [NSDate date], msg];
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:path];
    if (!fh) {
        [line writeToFile:path atomically:YES
                 encoding:NSUTF8StringEncoding error:nil];
        return;
    }
    [fh seekToEndOfFile];
    [fh writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
    [fh closeFile];
}

%group iOS16NotificationBehavior

%hook NCNotificationMasterList

- (void)setCurrentListDisplayStyleSetting:(NSUInteger)setting {
    LSRLog([NSString stringWithFormat:
        @"setCurrentListDisplayStyleSetting incoming=%lu",
        (unsigned long)setting]);
    %orig(0);
}

- (NSUInteger)currentListDisplayStyleSetting {
    NSUInteger original = %orig;
    LSRLog([NSString stringWithFormat:
        @"currentListDisplayStyleSetting original=%lu forced=0",
        (unsigned long)original]);
    return 0;
}

%end
%end

%ctor {
    if ([[[NSProcessInfo processInfo] processName]
         isEqualToString:@"SpringBoard"]) {
        %init(iOS16NotificationBehavior);
        LSRLog(@"Tweak loaded");
    }
}