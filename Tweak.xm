#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

static void KSLog(NSString *s) {
    NSString *p = @"/var/mobile/Documents/Kickstand.log";
    NSFileHandle *f = [NSFileHandle fileHandleForWritingAtPath:p];

    if (!f) {
        [s writeToFile:p atomically:YES encoding:NSUTF8StringEncoding error:nil];
        return;
    }

    [f seekToEndOfFile];
    NSString *line = [s stringByAppendingString:@"\n"];
    [f writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
    [f closeFile];
}

static BOOL KSIsCSScrollView(UIScrollView *view) {
    if (!view) return NO;

    Class cls = NSClassFromString(@"CSScrollView");
    if (!cls) return NO;

    return [view isKindOfClass:cls];
}

static void KSLogPan(UIPanGestureRecognizer *pan, NSString *tag) {
    CGPoint t = [pan translationInView:pan.view];
    CGPoint v = [pan velocityInView:pan.view];

    KSLog([NSString stringWithFormat:
           @"%@ state=%ld translation=(%.1f,%.1f) velocity=(%.1f,%.1f)",
           tag,
           (long)pan.state,
           t.x,
           t.y,
           v.x,
           v.y]);
}

%hook UIScrollViewPanGestureRecognizer

- (void)setState:(UIGestureRecognizerState)state {
    UIScrollView *view = (UIScrollView *)self.view;

    if (KSIsCSScrollView(view)) {
        if (state == UIGestureRecognizerStateBegan ||
            state == UIGestureRecognizerStateEnded ||
            state == UIGestureRecognizerStateCancelled ||
            state == UIGestureRecognizerStateFailed) {

            KSLogPan(self, @"CSScrollView PAN");
        }
    }

    %orig;
}

%end

%hook SBCoverSheetScreenEdgePanGestureRecognizer

- (void)setState:(UIGestureRecognizerState)state {
    if (state == UIGestureRecognizerStateBegan ||
        state == UIGestureRecognizerStateEnded ||
        state == UIGestureRecognizerStateCancelled ||
        state == UIGestureRecognizerStateFailed) {

        KSLogPan(self, @"COVER SHEET PAN");
    }

    %orig;
}

%end

%hook CSScrollView

- (void)setContentOffset:(CGPoint)offset {
    static CGPoint lastOffset = { -99999, -99999 };

    if (fabs(offset.y - lastOffset.y) > 20.0 ||
        fabs(offset.x - lastOffset.x) > 20.0) {

        KSLog([NSString stringWithFormat:
               @"CSScrollView OFFSET=(%.1f,%.1f)",
               offset.x,
               offset.y]);

        lastOffset = offset;
    }

    %orig;
}

%end