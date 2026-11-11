TARGET = iphone:clang:latest:14.0
ARCHS = arm64
INSTALL_TARGET_PROCESSES = SpringBoard

TWEAK_NAME = PurpouMenu

# Arquivos do projeto
PurpouMenu_FILES = Tweak.xm Menu.mm Hooks.mm

# Flags: ARC, C++17, e silenciar warnings
PurpouMenu_CFLAGS = -fobjc-arc -std=c++17 -Wno-error -Wno-unused-function -Wno-unused-variable

# Linkagem: REMOVIDO o Substrate, ADICIONADO o Dobby
PurpouMenu_LDFLAGS = -undefined dynamic_lookup -L$(THEOS_PROJECT_DIR)/lib -lDobby
PurpouMenu_FRAMEWORKS = UIKit Foundation QuartzCore Security

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk
