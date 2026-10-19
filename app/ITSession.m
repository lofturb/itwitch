#import "ITSession.h"
#import <Security/Security.h>

static NSString * const kServicio = @"com.lofturb.itwitch";
static NSString * const kCuentaToken = @"auth-token";

@implementation ITSession

+ (instancetype)compartida {
    static ITSession *s = nil;
    static dispatch_once_t una;
    dispatch_once(&una, ^{ s = [[ITSession alloc] init]; });
    return s;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _token = [self leerToken];
    }
    return self;
}

- (BOOL)haySesion {
    return self.token.length > 0;
}

#pragma mark - Keychain

- (NSMutableDictionary *)consultaBase {
    return [@{
        (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService : kServicio,
        (__bridge id)kSecAttrAccount : kCuentaToken
    } mutableCopy];
}

- (NSString *)leerToken {
    NSMutableDictionary *consulta = [self consultaBase];
    consulta[(__bridge id)kSecReturnData] = @YES;
    consulta[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;

    CFTypeRef salida = NULL;
    OSStatus estado = SecItemCopyMatching((__bridge CFDictionaryRef)consulta, &salida);
    if (estado != errSecSuccess || !salida) return nil;

    NSData *datos = (__bridge_transfer NSData *)salida;
    NSString *valor = [[NSString alloc] initWithData:datos encoding:NSUTF8StringEncoding];
    return valor.length > 0 ? valor : nil;
}

- (void)guardarToken:(NSString *)token {
    if (token.length == 0) {
        [self cerrarSesion];
        return;
    }
    [self borrarToken];
    NSData *datos = [token dataUsingEncoding:NSUTF8StringEncoding];

    NSMutableDictionary *alta = [self consultaBase];
    alta[(__bridge id)kSecValueData] = datos;
    alta[(__bridge id)kSecAttrAccessible] =
        (__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly;

    OSStatus estado = SecItemAdd((__bridge CFDictionaryRef)alta, NULL);
    if (estado != errSecSuccess) {
        // Si el llavero falla (raro), al menos que no perdamos la sesion viva.
        NSLog(@"[iTwitch] No se pudo guardar el token: %d", (int)estado);
    }
    _token = [token copy];
}

- (void)borrarToken {
    SecItemDelete((__bridge CFDictionaryRef)[self consultaBase]);
}

- (void)cerrarSesion {
    [self borrarToken];
    _token = nil;
    _usuario = nil;

    // Tambien se limpian las cookies de Twitch: si no, UIWebView seguiria
    // mandando la sesion vieja en el siguiente login.
    NSHTTPCookieStorage *almacen = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie *cookie in [almacen cookies]) {
        if ([cookie.domain rangeOfString:@"twitch.tv"].location != NSNotFound) {
            [almacen deleteCookie:cookie];
        }
    }
}

@end
