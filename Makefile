TARGET := iphone:clang:16.5:16.0
ARCHS := arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := KeepNotificationProbe

KeepNotificationProbe_FILES := Tweak.xm
KeepNotificationProbe_CFLAGS := -fobjc-arc
KeepNotificationProbe_FRAMEWORKS := UIKit Foundation

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"