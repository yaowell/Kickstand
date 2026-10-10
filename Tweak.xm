#import <UIKit/UIKit.h>

@interface NCNotificationListView : UIScrollView
@property (nonatomic) CGFloat revealPercentage;
- (BOOL)isRevealed;
@end

%group OldPluginAnimationCore

%hook NCNotificationListView

// 1. 核心的下拉展开/收起百分比驱动动画
- (void)setRevealPercentage:(CGFloat)percentage {
    %orig;
    // 旧插件里，通知面板的渐变、展开动画都是靠这个百分比实时驱动的
}

// 2. 状态机切换
- (void)setRevealed:(BOOL)revealed {
    %orig;
}

// 3. 滚动视图的偏移控制（这才是产生下拉滑动动画的根本）
- (void)setContentOffset:(CGPoint)contentOffset animated:(BOOL)animated {
    %orig;
}

%end

%end // OldPluginAnimationCore

%ctor {
    if ([[[NSProcessInfo processInfo] processName] isEqualToString:@"SpringBoard"]) {
        %init(OldPluginAnimationCore);
    }
}
