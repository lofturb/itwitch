#import "ITUtil.h"
#import "ITTheme.h"

NSString *ITStr(id valor) {
    if ([valor isKindOfClass:[NSString class]]) return valor;
    if ([valor isKindOfClass:[NSNumber class]]) return [valor stringValue];
    return nil;
}

double ITNum(id valor) {
    if ([valor isKindOfClass:[NSNumber class]]) return [valor doubleValue];
    if ([valor isKindOfClass:[NSString class]]) return [valor doubleValue];
    return 0.0;
}

NSInteger ITInt(id valor) {
    return (NSInteger)ITNum(valor);
}

long long ITLargo(id valor) {
    if ([valor isKindOfClass:[NSNumber class]]) return [valor longLongValue];
    if ([valor isKindOfClass:[NSString class]]) return [valor longLongValue];
    return 0;
}

BOOL ITBool(id valor) {
    if ([valor isKindOfClass:[NSNumber class]]) return [valor boolValue];
    if ([valor isKindOfClass:[NSString class]]) return [valor boolValue];
    return NO;
}

NSArray *ITArr(id valor) {
    if ([valor isKindOfClass:[NSArray class]]) return valor;
    return @[];
}

NSDictionary *ITDic(id valor) {
    if ([valor isKindOfClass:[NSDictionary class]]) return valor;
    return @{};
}

static NSDateFormatter *ITFormatoISO(void) {
    static NSDateFormatter *f = nil;
    static dispatch_once_t una;
    dispatch_once(&una, ^{
        f = [[NSDateFormatter alloc] init];
        f.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        f.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss'Z'";
        f.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
    });
    return f;
}

static NSDate *ITFechaISO(NSString *iso) {
    if (![iso isKindOfClass:[NSString class]] || iso.length == 0) return nil;
    NSDate *fecha = [ITFormatoISO() dateFromString:iso];
    if (fecha) return fecha;
    NSMutableString *limpia = [iso mutableCopy];
    NSRange punto = [limpia rangeOfString:@"."];
    NSRange zeta = [limpia rangeOfString:@"Z" options:NSBackwardsSearch];
    if (punto.location != NSNotFound && zeta.location != NSNotFound && zeta.location > punto.location) {
        [limpia deleteCharactersInRange:NSMakeRange(punto.location, zeta.location - punto.location)];
    }
    return [ITFormatoISO() dateFromString:limpia];
}

NSString *ITFechaCorta(NSString *iso) {
    if (![iso isKindOfClass:[NSString class]] || iso.length == 0) return @"";
    NSDate *fecha = ITFechaISO(iso);
    if (!fecha) return @"";

    static NSDateFormatter *salida = nil;
    static dispatch_once_t una;
    dispatch_once(&una, ^{
        salida = [[NSDateFormatter alloc] init];
        salida.locale = [NSLocale localeWithLocaleIdentifier:@"es_ES"];
        salida.dateFormat = @"d MMM yyyy";
    });
    return [salida stringFromDate:fecha];
}

NSString *ITHace(NSString *iso) {
    if (![iso isKindOfClass:[NSString class]] || iso.length == 0) return @"";
    NSDate *fecha = ITFechaISO(iso);
    if (!fecha) return ITFechaCorta(iso);
    NSTimeInterval segundos = -[fecha timeIntervalSinceNow];
    if (segundos < 60) return @"Ahora";
    if (segundos < 3600) {
        return [NSString stringWithFormat:@"Hace %d min", (int)(segundos / 60)];
    }
    if (segundos < 86400) {
        return [NSString stringWithFormat:@"Hace %d h", (int)(segundos / 3600)];
    }
    if (segundos < 2592000) {
        return [NSString stringWithFormat:@"Hace %d d", (int)(segundos / 86400)];
    }
    return ITFechaCorta(iso);
}

NSString *ITDuracion(double segundos) {
    if (segundos < 0 || !isfinite(segundos)) segundos = 0;
    NSInteger s = (NSInteger)segundos;
    NSInteger h = s / 3600;
    NSInteger m = (s % 3600) / 60;
    NSInteger seg = s % 60;
    if (h > 0) {
        return [NSString stringWithFormat:@"%d:%02d:%02d", (int)h, (int)m, (int)seg];
    }
    return [NSString stringWithFormat:@"%d:%02d", (int)m, (int)seg];
}

NSString *ITNumeroCorto(long long numero) {
    if (numero < 1000) return [NSString stringWithFormat:@"%lld", numero];
    if (numero < 1000000) {
        double k = numero / 1000.0;
        return [NSString stringWithFormat:@"%.1f mil", k];
    }
    double m = numero / 1000000.0;
    return [NSString stringWithFormat:@"%.1f M", m];
}

NSString *ITMillones(long long numero) {
    if (numero < 1000) return [NSString stringWithFormat:@"%lld", numero];
    if (numero < 1000000) {
        return [NSString stringWithFormat:@"%.1f mil", numero / 1000.0];
    }
    return [NSString stringWithFormat:@"%.1f M", numero / 1000000.0];
}

NSString *ITImagen(NSString *url, int ancho, int alto) {
    if (![url isKindOfClass:[NSString class]] || url.length == 0) return nil;
    NSString *limpia = url;
    NSRange signo = [limpia rangeOfString:@"?"];
    if (signo.location != NSNotFound) limpia = [limpia substringToIndex:signo.location];
    if (ancho <= 0 || alto <= 0) return limpia;
    return [NSString stringWithFormat:@"%@?w=%d&h=%d&fit=crop", limpia, ancho, alto];
}

static NSUInteger ITHashColor(NSString *texto) {
    NSUInteger h = 5381;
    for (NSUInteger i = 0; i < texto.length; i++) {
        h = ((h << 5) + h) + [texto characterAtIndex:i];
    }
    return h;
}

UIColor *ITColorDeChat(NSString *hex, NSString *nombre) {
    if ([hex isKindOfClass:[NSString class]] && hex.length >= 6) {
        NSString *s = [hex hasPrefix:@"#"] ? [hex substringFromIndex:1] : hex;
        unsigned int valor = 0;
        if ([[NSScanner scannerWithString:s] scanHexInt:&valor]) {
            return [UIColor colorWithRed:((valor >> 16) & 0xFF) / 255.0
                                   green:((valor >> 8) & 0xFF) / 255.0
                                    blue:(valor & 0xFF) / 255.0
                                   alpha:1.0];
        }
    }
    static NSArray *colores = nil;
    static dispatch_once_t una;
    dispatch_once(&una, ^{
        colores = @[
            [UIColor colorWithRed:0.95 green:0.27 blue:0.35 alpha:1.0],
            [UIColor colorWithRed:0.36 green:0.61 blue:0.96 alpha:1.0],
            [UIColor colorWithRed:0.20 green:0.78 blue:0.55 alpha:1.0],
            [UIColor colorWithRed:0.98 green:0.66 blue:0.19 alpha:1.0],
            [UIColor colorWithRed:0.74 green:0.44 blue:0.96 alpha:1.0],
            [UIColor colorWithRed:0.96 green:0.47 blue:0.74 alpha:1.0],
            [UIColor colorWithRed:0.20 green:0.75 blue:0.85 alpha:1.0]
        ];
    });
    NSUInteger indice = ITHashColor(nombre ?: @"") % colores.count;
    return colores[indice];
}

#pragma mark - UI

UILabel *ITLabel(NSString *texto, UIFont *fuente, UIColor *color) {
    UILabel *l = [[UILabel alloc] init];
    l.text = texto;
    l.font = fuente;
    l.textColor = color;
    l.numberOfLines = 1;
    return l;
}

UIButton *ITBotonIcono(NSString *forma, CGFloat lado, UIColor *color) {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    [b setImage:[ITTheme icono:forma lado:lado] forState:UIControlStateNormal];
    b.tintColor = color;
    b.contentEdgeInsets = UIEdgeInsetsMake(8, 8, 8, 8);
    return b;
}

UIView *ITCaja(CGFloat alto) {
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 1, alto)];
    v.backgroundColor = [UIColor clearColor];
    return v;
}

void ITRedondear(UIView *vista, CGFloat radio) {
    vista.layer.cornerRadius = radio;
    vista.layer.masksToBounds = YES;
}

@implementation ITUtil
@end
