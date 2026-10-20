#import "ITNotifications.h"
#import "ITApi.h"
#import "ITSession.h"
#import "ITUtil.h"

static NSString * const kITAvisosActivos = @"itwitch_avisos_activos";
static NSString * const kITVivosConocidos = @"itwitch_avisos_vivos";
NSString * const ITNotificationsCambio = @"ITNotificationsCambio";

@implementation ITNotifications {
    NSTimer *_temporizador;
    BOOL _comprobando;
    NSArray *_nuevos;
}

+ (instancetype)compartida {
    static ITNotifications *una = nil;
    static dispatch_once_t vez;
    dispatch_once(&vez, ^{ una = [[ITNotifications alloc] init]; });
    return una;
}

+ (BOOL)avisosActivos {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kITAvisosActivos];
}

+ (void)establecerAvisosActivos:(BOOL)activos {
    NSUserDefaults *ajustes = [NSUserDefaults standardUserDefaults];
    [ajustes setBool:activos forKey:kITAvisosActivos];
    [ajustes synchronize];

    ITNotifications *n = [ITNotifications compartida];
    if (activos) {
        UIUserNotificationType tipos = UIUserNotificationTypeAlert |
                                       UIUserNotificationTypeSound |
                                       UIUserNotificationTypeBadge;
        UIUserNotificationSettings *permiso =
            [UIUserNotificationSettings settingsForTypes:tipos categories:nil];
        [[UIApplication sharedApplication] registerUserNotificationSettings:permiso];
        [n comenzar];
    } else {
        [n detener];
        [[UIApplication sharedApplication] cancelAllLocalNotifications];
        [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
    }
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _nuevos = @[];
    }
    return self;
}

- (void)comenzar {
    if (![ITNotifications avisosActivos]) return;
    if (_temporizador) return;

    _temporizador = [NSTimer scheduledTimerWithTimeInterval:120.0
                                                     target:self
                                                   selector:@selector(comprobar)
                                                   userInfo:nil
                                                    repeats:YES];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(comprobar)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    [self comprobar];
}

- (void)detener {
    [_temporizador invalidate];
    _temporizador = nil;
    _comprobando = NO;
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidBecomeActiveNotification
                                                  object:nil];
}

- (NSArray *)nuevos {
    return _nuevos ?: @[];
}

- (void)limpiarNuevos {
    _nuevos = @[];
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
}

- (void)permisoCambiado:(UIUserNotificationSettings *)ajustes {
    if ((ajustes.types & (UIUserNotificationTypeAlert | UIUserNotificationTypeSound)) == 0) {
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kITAvisosActivos];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [self detener];
    } else {
        [self comenzar];
    }
}

#pragma mark - Comprobacion

- (void)comprobar {
    if (_comprobando) return;
    if (![ITNotifications avisosActivos]) return;
    if ([ITSession compartida].token.length == 0) return;

    _comprobando = YES;
    __typeof(self) debil = self;
    [[ITApi compartida] seguidos:^(NSArray *canales, NSError *error) {
        debil->_comprobando = NO;
        if (error || !canales) return;
        [debil procesarSeguidos:canales];
    }];
}

- (void)procesarSeguidos:(NSArray *)canales {
    if (![ITNotifications avisosActivos]) return;
    NSUserDefaults *ajustes = [NSUserDefaults standardUserDefaults];
    NSArray *previos = [ajustes arrayForKey:kITVivosConocidos];
    BOOL primeraVez = (previos == nil);
    if (!previos) previos = @[];

    NSMutableArray *vivos = [NSMutableArray array];
    NSMutableArray *nuevos = [NSMutableArray array];
    for (ITChannel *c in canales) {
        if (![c isKindOfClass:[ITChannel class]] || !c.enDirecto) continue;
        NSString *login = [c.login lowercaseString];
        if (login.length == 0) continue;
        [vivos addObject:login];
        if (!primeraVez && ![previos containsObject:login]) {
            [nuevos addObject:c];
        }
    }

    [ajustes setObject:vivos forKey:kITVivosConocidos];
    [ajustes synchronize];

    if (primeraVez) {
        _nuevos = @[];
        return;
    }

    if (nuevos.count == 0) return;

    // Se conservan los avisos no leidos de sondeos anteriores.
    NSMutableArray *acumulados = [NSMutableArray arrayWithArray:_nuevos ?: @[]];
    for (ITChannel *c in nuevos) {
        BOOL repetido = NO;
        for (ITChannel *viejo in acumulados) {
            if ([viejo.login caseInsensitiveCompare:c.login] == NSOrderedSame) {
                repetido = YES;
                break;
            }
        }
        if (!repetido) [acumulados addObject:c];
    }
    while (acumulados.count > 30) [acumulados removeObjectAtIndex:0];
    _nuevos = acumulados;
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:(NSInteger)_nuevos.count];

    NSUInteger limite = MIN(nuevos.count, (NSUInteger)5);
    for (NSUInteger i = 0; i < limite; i++) {
        ITChannel *c = nuevos[i];
        UILocalNotification *aviso = [[UILocalNotification alloc] init];
        aviso.fireDate = [NSDate dateWithTimeIntervalSinceNow:1.0];
        aviso.alertBody = [NSString stringWithFormat:@"%@ está en directo: %@",
                           c.nombre.length ? c.nombre : c.login,
                           c.directoTitulo.length ? c.directoTitulo : @"Twitch"];
        aviso.soundName = UILocalNotificationDefaultSoundName;
        aviso.userInfo = @{ @"login" : c.login ?: @"" };
        [[UIApplication sharedApplication] scheduleLocalNotification:aviso];
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:ITNotificationsCambio object:nil];
}

@end
