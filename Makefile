TARGET = iphone:clang:latest:14.0
ARCHS = arm64
INSTALL_TARGET_PROCESSES = SpringBoard

TWEAK_NAME = PurpouMenu

# Arquivos do projeto (incluindo o Gesture.mm que você criou)
PurpouMenu_FILES = Tweak.xm Menu.mm Hooks.mm Gesture.mm

# Flags: ARC, C++17 (necessário pro Hooks.mm) e silenciar warnings
PurpouMenu_CFLAGS = -fobjc-arc -std=c++17 -Wno-error -Wno-unused-function -Wno-unused-variable

# Linka o Dobby da pasta lib (se você for usar o Dobby no futuro)
PurpouMenu_LDFLAGS = -undefined dynamic_lookup -L$(THEOS_PROJECT_DIR)/lib -lDobby

# Frameworks necessários
PurpouMenu_FRAMEWORKS = UIKit Foundation QuartzCore Security

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk
