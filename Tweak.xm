#import <UIKit/UIKit.h>

%group iOS16NotificationBehavior

// 核心：强制更改通知列表展示样式，使其保持在不自动收回的交互状态下，
// 同时完全不干涉 iOS 16 原生的底部堆叠动画和外观。
%hook NCNotificationMasterList
- (void)setCurrentListDisplayStyleSetting:(NSUInteger)setting {
    %orig(0);
}

- (NSUInteger)currentListDisplayStyleSetting {
    return 0;
}
%end

%end // iOS16NotificationBehavior

%ctor {
    if ([[[NSProcessInfo processInfo] processName] isEqualToString:@"SpringBoard"]) {
        %init(iOS16NotificationBehavior);
    }
}
