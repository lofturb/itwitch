#import "AppDelegate.h"
#import "ITTheme.h"
#import "ITHomeViewController.h"
#import "ITBrowseViewController.h"
#import "ITSearchViewController.h"
#import "ITFollowingViewController.h"
#import "ITProfileViewController.h"
#import "ITNotifications.h"

@implementation AppDelegate {
    UITabBarController *_tabs;
}

- (BOOL)application:(UIApplication *)application
        didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [ITTheme prepararAparienciaGlobal];

    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    [self montarTabs];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(cambiarTema)
                                                 name:ITThemeCambio
                                               object:nil];

    self.window.rootViewController = _tabs;
    self.window.tintColor = [ITTheme acento];
    [self.window makeKeyAndVisible];

    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
    [[ITNotifications compartida] comenzar];
    return YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
    [[ITNotifications compartida] comenzar];
}

- (void)application:(UIApplication *)application
        didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings {
    [[ITNotifications compartida] permisoCambiado:notificationSettings];
}

- (void)application:(UIApplication *)application
        didReceiveLocalNotification:(UILocalNotification *)notification {
    application.applicationIconBadgeNumber = 0;
    [[ITNotifications compartida] limpiarNuevos];
    if (_tabs) _tabs.selectedIndex = 3;
}

- (void)montarTabs {
    NSUInteger seleccionado = _tabs.selectedIndex;

    _tabs = [[UITabBarController alloc] init];
    _tabs.viewControllers = @[
        [self envolver:[[ITHomeViewController alloc] init]],
        [self envolver:[[ITBrowseViewController alloc] init]],
        [self envolver:[[ITSearchViewController alloc] init]],
        [self envolver:[[ITFollowingViewController alloc] init]],
        [self envolver:[[ITProfileViewController alloc] init]]
    ];
    if (seleccionado < _tabs.viewControllers.count) _tabs.selectedIndex = seleccionado;
    [ITTheme aplicarEstiloTabBar:_tabs.tabBar];
}

- (UINavigationController *)envolver:(UIViewController *)vc {
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    [ITTheme aplicarEstiloNavegacion:nav.navigationBar];
    return nav;
}

- (void)cambiarTema {
    [ITTheme prepararAparienciaGlobal];
    [self montarTabs];
    self.window.rootViewController = _tabs;
    self.window.tintColor = [ITTheme acento];
    [self.window makeKeyAndVisible];
}

@end
