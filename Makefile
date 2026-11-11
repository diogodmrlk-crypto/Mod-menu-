TARGET = iphone:clang:latest:14.0
ARCHS = arm64
INSTALL_TARGET_PROCESSES = SpringBoard

TWEAK_NAME = PurpouMenu
PurpouMenu_FILES = Tweak.xm Menu.mm Hooks.mm
PurpouMenu_CFLAGS = -fobjc-arc -std=c++17 -Wno-error -Wno-unused-function -Wno-unused-variable
PurpouMenu_LDFLAGS = -undefined dynamic_lookup -lsubstrate
PurpouMenu_FRAMEWORKS = UIKit Foundation QuartzCore

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk
