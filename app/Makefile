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
	ITUtil.m \
	ITModels.m \
	ITSession.m \
	ITImageCache.m \
	ITApi.m \
	ITPlayback.m \
	ITCells.m \
	ITHomeViewController.m \
	ITBrowseViewController.m \
	ITSearchViewController.m \
	ITFollowingViewController.m \
	ITProfileViewController.m \
	ITSettingsViewController.m \
	ITLoginViewController.m \
	ITChannelViewController.m \
	ITCategoryViewController.m \
	ITCollectionViewController.m \
	ITDiagnosticsViewController.m \
	ITChatClient.m \
	ITChatViewController.m \
	ITMiniPlayer.m \
	ITPlayerViewController.m

iTwitch_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore AVFoundation MediaPlayer Security CFNetwork
iTwitch_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-parameter
iTwitch_RESOURCE_DIRS = Resources
iTwitch_LDFLAGS = -Wl,-dead_strip

include $(THEOS_MAKE_PATH)/application.mk
