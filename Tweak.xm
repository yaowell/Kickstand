%group LSRNotifications

%hook NCNotificationListView
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

- (void)setRevealPercentage:(CGFloat)percentage {
    %orig;
    LSRApplyHistoryHeaderReveal(self);
}

- (void)setRevealed:(BOOL)revealed {
    %orig;
    LSRApplyHistoryHeaderReveal(self);
}
%end
