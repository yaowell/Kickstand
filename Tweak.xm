#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

@interface NCNotificationListSectionHeaderView : UIView
@property (nonatomic, weak) id delegate;
@end

@interface NCNotificationListView : UIScrollView
@property (nonatomic, strong) UIView *headerView;
@property (nonatomic) CGFloat revealPercentage;
- (BOOL)isRevealed;
@end

// 历史分组标题（Notification Centre）随 iOS 15 下拉动画同步渐变的逻辑
static BOOL LSRIsHistoryHeader(UIView *header) {
    if (![header isKindOfClass:NSClassFromString(@"NCNotificationListSectionHeaderView")]) return NO;
    id section = ((NCNotificationListSectionHeaderView *)header).delegate;
    return [section respondsToSelector:@selector(isHistorySection)]
        && ((BOOL (*)(id, SEL))objc_msgSend)(section, @selector(isHistorySection));
}

static CGFloat LSRHistoryHeaderMaxAlpha(UIView *header) {
    NCNotificationListView *list = (NCNotificationListView *)header.superview;
    if (![list isKindOfClass:NSClassFromString(@"NCNotificationListView")] || list.headerView != header
        || !LSRIsHistoryHeader(header)) return 1.0;
    return list.isRevealed ? 1.0 : MIN(MAX(list.revealPercentage, 0.0), 1.0);
}

static void LSRApplyHistoryHeaderReveal(NCNotificationListView *list) {
    UIView *header = list.headerView;
    if (!LSRIsHistoryHeader(header)) return;
    CGFloat alpha = LSRHistoryHeaderMaxAlpha(header);
    if (fabs(header.alpha - alpha) > 0.001) header.alpha = alpha;
}

%group LSI5NotificationAnimationCore

%hook NCNotificationListView

// 1. 核心：禁用 iOS 16 底端堆叠，恢复 iOS 15 的顶部向下延伸动画
- (BOOL)layoutFromBottom {
    return NO;
}

- (void)setLayoutFromBottom:(BOOL)layoutFromBottom {
    %orig(NO);
}

- (void)layoutSubviews {
    %orig;
    LSRApplyHistoryHeaderReveal(self);
}

// 2. iOS 15 下拉展开的实时百分比动画驱动
- (void)setRevealPercentage:(CGFloat)percentage {
    %orig;
    LSRApplyHistoryHeaderReveal(self);
}

// 3. iOS 15 状态机切换（唤出与收起）
- (void)setRevealed:(BOOL)revealed {
    // 咱们后续要做的“松手不自动收回”拦截，就可以在这里精准切入
    %orig;
    LSRApplyHistoryHeaderReveal(self);
}

%end

// 历史分组标题透明度同步（已修正为正确的 void 返回类型）
%hook NCNotificationListSectionHeaderView
- (void)setAlpha:(CGFloat)alpha {
    %orig(MIN(alpha, LSRHistoryHeaderMaxAlpha(self)));
}
%end

%end // LSI5NotificationAnimationCore

%ctor {
    if ([[[NSProcessInfo processInfo] processName] isEqualToString:@"SpringBoard"]) {
        %init(LSI5NotificationAnimationCore);
    }
}
