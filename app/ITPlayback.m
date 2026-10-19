#import "ITPlayback.h"
#import "ITApi.h"
#import "ITUtil.h"

@interface ITPlayback ()
+ (NSString *)consultaConValor:(NSString *)valor firma:(NSString *)firma;
+ (NSArray *)variantesDeTexto:(NSString *)texto base:(NSURL *)base;
@end

static NSString * const kCliente = @"kimne78kx3ncx6brgo4mv6wki5h1ko";

static NSString *ITCodificar(NSString *texto) {
    NSCharacterSet *permitidos = [NSCharacterSet characterSetWithCharactersInString:
        @"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"];
    return [texto stringByAddingPercentEncodingWithAllowedCharacters:permitidos] ?: @"";
}

@implementation ITPlayback

+ (NSString *)consultaConValor:(NSString *)valor firma:(NSString *)firma {
    unsigned int p = (unsigned int)(arc4random() % 999999) + 1;
    return [NSString stringWithFormat:
        @"client_id=%@&sig=%@&token=%@&allow_source=true&allow_audio_only=true"
         @"&fast_bread=true&p=%u",
        kCliente, ITCodificar(firma ?: @""), ITCodificar(valor ?: @""), p];
}

+ (void)urlDirecto:(NSString *)login completion:(void (^)(NSString *, NSError *))completion {
    [[ITApi compartida] tokenDirecto:login completion:^(NSString *valor, NSString *firma, NSError *error) {
        if (error || valor.length == 0) {
            if (completion) completion(nil, error ?: [NSError errorWithDomain:@"iTwitch" code:2
                userInfo:@{ NSLocalizedDescriptionKey : @"Token de directo vacío." }]);
            return;
        }
        NSString *url = [NSString stringWithFormat:
            @"https://usher.ttvnw.net/api/channel/hls/%@.m3u8?%@",
            ITCodificar(login ?: @""), [self consultaConValor:valor firma:firma]];
        if (completion) completion(url, nil);
    }];
}

+ (void)urlVod:(NSString *)videoID completion:(void (^)(NSString *, NSError *))completion {
    [[ITApi compartida] tokenVod:videoID completion:^(NSString *valor, NSString *firma, NSError *error) {
        if (error || valor.length == 0) {
            if (completion) completion(nil, error ?: [NSError errorWithDomain:@"iTwitch" code:3
                userInfo:@{ NSLocalizedDescriptionKey : @"Token de vídeo vacío." }]);
            return;
        }
        NSString *url = [NSString stringWithFormat:
            @"https://usher.ttvnw.net/vod/%@.m3u8?%@",
            ITCodificar(videoID ?: @""), [self consultaConValor:valor firma:firma]];
        if (completion) completion(url, nil);
    }];
}

+ (void)variantesDeMaster:(NSString *)url
               completion:(void (^)(NSArray *, NSError *))completion {
    NSURL *destino = [NSURL URLWithString:url];
    if (!destino) {
        if (completion) completion(nil, [NSError errorWithDomain:@"iTwitch" code:4
            userInfo:@{ NSLocalizedDescriptionKey : @"URL de vídeo no válida." }]);
        return;
    }

    NSMutableURLRequest *peticion = [NSMutableURLRequest requestWithURL:destino];
    peticion.timeoutInterval = 20.0;
    [peticion setValue:@"application/vnd.apple.mpegurl, application/x-mpegURL, */*"
    forHTTPHeaderField:@"Accept"];

    [[[NSURLSession sharedSession] dataTaskWithRequest:peticion
        completionHandler:^(NSData *datos, NSURLResponse *respuesta, NSError *error) {
        if (error || !datos) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, error);
            });
            return;
        }
        NSString *texto = [[NSString alloc] initWithData:datos encoding:NSUTF8StringEncoding];
        if (!texto) texto = [[NSString alloc] initWithData:datos encoding:NSISOLatin1StringEncoding];
        NSArray *variantes = [self variantesDeTexto:texto base:destino];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(variantes, nil);
        });
    }] resume];
}

+ (NSArray *)variantesDeTexto:(NSString *)texto base:(NSURL *)base {
    if (texto.length == 0) return @[];
    NSArray *lineas = [texto componentsSeparatedByCharactersInSet:
                       [NSCharacterSet newlineCharacterSet]];

    NSMutableArray *salida = [NSMutableArray array];
    NSDictionary *atributosPendientes = nil;

    for (NSString *lineaCruda in lineas) {
        NSString *linea = [lineaCruda stringByTrimmingCharactersInSet:
                           [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (linea.length == 0) continue;

        if ([linea hasPrefix:@"#EXT-X-STREAM-INF:"]) {
            NSString *resto = [linea substringFromIndex:@"#EXT-X-STREAM-INF:".length];
            NSMutableDictionary *attrs = [NSMutableDictionary dictionary];
            for (NSString *parte in [resto componentsSeparatedByString:@","]) {
                NSRange igual = [parte rangeOfString:@"="];
                if (igual.location == NSNotFound) continue;
                NSString *clave = [parte substringToIndex:igual.location];
                NSString *valor = [parte substringFromIndex:igual.location + 1];
                valor = [valor stringByTrimmingCharactersInSet:
                         [NSCharacterSet characterSetWithCharactersInString:@"\""]];
                attrs[clave] = valor;
            }
            atributosPendientes = attrs;
            continue;
        }

        if ([linea hasPrefix:@"#"] || !atributosPendientes) continue;

        NSURL *url = [NSURL URLWithString:linea relativeToURL:base];
        NSString *resolucion = atributosPendientes[@"RESOLUTION"];
        NSInteger ancho = 0, alto = 0;
        if ([resolucion isKindOfClass:[NSString class]]) {
            NSArray *partes = [resolucion componentsSeparatedByString:@"x"];
            if (partes.count == 2) {
                ancho = [partes[0] integerValue];
                alto = [partes[1] integerValue];
            }
        }
        NSString *nombre = alto > 0 ? [NSString stringWithFormat:@"%dp", (int)alto] : @"Auto";
        if ([linea rangeOfString:@"audio_only"].location != NSNotFound) nombre = @"Audio";
        if ([linea rangeOfString:@"720p60"].location != NSNotFound) nombre = @"720p60";

        [salida addObject:@{
            @"nombre" : nombre,
            @"url" : url,
            @"ancho" : @(ancho),
            @"alto" : @(alto),
            @"banda" : @([atributosPendientes[@"BANDWIDTH"] doubleValue])
        }];
        atributosPendientes = nil;
    }
    return salida;
}

@end
