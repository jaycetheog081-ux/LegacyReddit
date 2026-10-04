ARCHS = arm64
TARGET = iphone:clang:latest:11.0

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = LegacyReddit

LegacyReddit_FILES = \
    main.mm \
    LegacyRedditApp.mm

LegacyReddit_FRAMEWORKS = \
    UIKit \
    Foundation \
    SafariServices

LegacyReddit_CFLAGS = \
    -fobjc-arc \
    -Wno-deprecated-declarations

LegacyReddit_INFO_PLIST = Info.plist

include $(THEOS_MAKE_PATH)/application.mk
