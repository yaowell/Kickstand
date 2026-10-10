#import <UIKit/UIKit.h>

// Debug 日志，用于精准捕捉下拉松手时的动画轨迹
#ifdef DEBUG
static void LSRDebugLog(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);
static void LSRDebugLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *line = [NSString stringWithFormat:@"%.2f %@\n", CACurrentMediaTime(), [[NSString alloc] initWithFormat:format arguments:args]];
    va_end(args);
    NSString *path = @"/var/mobile/Documents/LockScreenRestoreDebug.log";
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:path];
    if (!fh) {
        [line writeToFile:path atomically:NO encoding:NSUTF8StringEncoding error:nil];
        return;
    }
    [fh seekToEndOfFile];
    [fh writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
    [fh closeFile];
}
#else
#define LSRDebugLog(...) do {} while (0)
#endif

@interface NCNotificationListView : UIScrollView
@property (nonatomic) CGFloat revealPercentage;
- (BOOL)isRevealed;
@end

%group LSPureAnimationCore

%hook NCNotificationListView

// 1. 监控下拉过程中的显示比例动画（实时百分比）
- (void)setRevealPercentage:(CGFloat)percentage {
    LSRDebugLog(@"[Animation Core] setRevealPercentage: %.2f", percentage);
    %orig;
}

// 2. 监控系统触发的展开/收起状态切换
- (void)setRevealed:(BOOL)revealed {
    LSRDebugLog(@"[Animation Core] setRevealed: %d", revealed);
    
    // =========================================================================
    // 咱们的最终拦截逻辑将在这里编写：
    // 当旧通知松手试图触发 revealed = NO（自动收回）时，在这里进行精准判断和拦截，
    // 从而实现“下拉能动，但松手后绝不自动收回”的效果。
    // =========================================================================
    
    %orig;
}

%end

%end // LSPureAnimationCore

%ctor {
    if ([[[NSProcessInfo processInfo] processName] isEqualToString:@"SpringBoard"]) {
        %init(LSPureAnimationCore);
    }
}
