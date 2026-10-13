# ============================================================================
#  Kickstand — Makefile
#  roothide(无根)环境:用 roothide 版 Theos,或普通 Theos 打开下面这行
# ============================================================================

# roothide 打包(用普通 Theos + roothide bootstrap 时也要打开)
THEOS_PACKAGE_SCHEME = roothide

TARGET = iphone:clang:latest:15.0
ARCHS  = arm64 arm64e

# 装完重启一下 SpringBoard(不重启也会被 ellekit 注入,但这行保险)
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Kickstand
Kickstand_FILES = Tweak.xm

# 需要 UIKit / Foundation / CoreFoundation。
# 用 %hook 拦 UIPasteboard 的话,这三个就够了,不用额外引私有框架。
Kickstand_FRAMEWORKS = UIKit Foundation CoreFoundation

# 补丁里用了 dispatch / notify / dyld / runtime,都在这几个系统库里,不用显式链接
Kickstand_CFLAGS = -fobjc-arc -O2 \
                   -Wno-deprecated-declarations \
                   -Wno-unused-function \
                   -Wno-unused-variable

include $(THEOS_MAKE_PATH)/tweak.mk