TARGET := iphone:clang:latest:12.0
ARCHS := arm64

DEBUG = 0
FINALPACKAGE = 1

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME := LegacyReddit

LegacyReddit_FILES := main.m
LegacyReddit_FRAMEWORKS := UIKit Foundation
LegacyReddit_CFLAGS := -fobjc-arc
LegacyReddit_INSTALL_PATH := /Applications
LegacyReddit_CODESIGN_FLAGS := -Sentitlements.plist

include $(THEOS_MAKE_PATH)/application.mk

after-install::
	install.exec "uicache -p /Applications/LegacyReddit.app || true"
