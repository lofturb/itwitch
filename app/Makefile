# ---------------------------------------------------------------------------
#  iTwitch -- cliente no oficial de Twitch para iOS 9.3.5 (32 bits, armv7)
#  Compilado con Theos + iPhoneOS9.3.sdk en Linux (GitHub Actions, gratis).
#  Ver README.md en la raiz del repositorio.
# ---------------------------------------------------------------------------

TARGET = iphone:clang:9.3:9.0
ARCHS = armv7
PACKAGE_FORMAT = ipa

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = iTwitch

iTwitch_FILES = \
	main.m \
	AppDelegate.m \
	ITTheme.m \
	ITPlaceholderViewController.m

iTwitch_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore AVFoundation MediaPlayer Security
iTwitch_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-parameter
iTwitch_RESOURCE_DIRS = Resources
iTwitch_LDFLAGS = -Wl,-dead_strip

include $(THEOS_MAKE_PATH)/application.mk
