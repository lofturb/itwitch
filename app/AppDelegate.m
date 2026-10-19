#import "AppDelegate.h"
#import "ITTheme.h"
#import "ITPlaceholderViewController.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
        didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [ITTheme prepararAparienciaGlobal];

    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];

    UITabBarController *tabs = [[UITabBarController alloc] init];
    tabs.viewControllers = @[
        [[ITPlaceholderViewController alloc] initWithTitle:@"Inicio" icono:@"inicio"],
        [[ITPlaceholderViewController alloc] initWithTitle:@"Explorar" icono:@"tendencias"],
        [[ITPlaceholderViewController alloc] initWithTitle:@"Buscar" icono:@"buscar"],
        [[ITPlaceholderViewController alloc] initWithTitle:@"Siguiendo" icono:@"canal"],
        [[ITPlaceholderViewController alloc] initWithTitle:@"Perfil" icono:@"ajustes"]
    ];
    [ITTheme aplicarEstiloTabBar:tabs.tabBar];

    self.window.rootViewController = tabs;
    self.window.tintColor = [ITTheme acento];
    [self.window makeKeyAndVisible];
    return YES;
}

@end
