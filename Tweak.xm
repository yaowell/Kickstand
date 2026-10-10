#import <UIKit/UIKit.h>

@interface NCNotificationListView : UIScrollView
@property (nonatomic) CGFloat revealPercentage;
- (BOOL)isRevealed;
@end

%group StickyNotificationsAll

// 1. 管控新通知：强制使用标准列表样式，防止新通知自动回弹
%hook NCNotificationMasterList
- (void)setCurrentListDisplayStyleSetting:(NSUInteger)setting {
    %orig(0);
}

- (NSUInteger)currentListDisplayStyleSetting {
    return 0;
}
%end

// 2. 管控旧通知：拦截列表的收回指令，让旧通知下拉松手后也永远保持展开状态
%hook NCNotificationListView

- (void)setRevealed:(BOOL)revealed {
    // 如果系统试图触发收回（revealed 为 NO），在这里强制将其变更为 YES（或直接阻止）
    // 这样旧通知在下拉松手后就会稳稳停住，不会自动收回
    %orig(YES); 
}

- (void)setRevealPercentage:(CGFloat)percentage {
    %orig;
}

%end

%end // StickyNotificationsAll

%ctor {
    if ([[[NSProcessInfo processInfo] processName] isEqualToString:@"SpringBoard"]) {
        %init(StickyNotificationsAll);
    }
}
