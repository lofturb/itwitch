// ITDownloadManager.m -- descarga de VODs HLS de Twitch.
//
// Twitch sirve los VOD como MPEG-TS troceado (segmentos de ~10 s) dentro de
// una playlist .m3u8. La descarga consiste en bajar todos los segmentos, unirlos
// en un solo .ts y, si el dispositivo puede, remuxearlo a .mp4 con
// AVAssetExportSession (sin recodificar, asi que es rapido incluso en un A5).
#import "ITDownloadManager.h"
#import "ITPlayback.h"
#import "ITUtil.h"
#import <AVFoundation/AVFoundation.h>

NSString * const ITDescargasCambiaron = @"ITDescargasCambiaron";

static NSString * const kITCarpetaDescargas = @"itwitch_carpeta_descargas";
static NSString * const kITListaDescargas = @"itwitch_descargas.plist";
static NSString * const kITCarpetaPredeterminada = @"/var/mobile/Media/iTwitch";

#pragma mark - Modelo

@interface ITDescarga ()
- (NSDictionary *)diccionario;
+ (instancetype)conDiccionario:(NSDictionary *)d;
@end

@implementation ITDescarga

- (double)progreso {
    if (self.estado == ITDescargaCompletada) return 1.0;
    if (self.segmentosTotales > 0) {
        return MIN(1.0, (double)self.segmentosHechos / (double)self.segmentosTotales);
    }
    if (self.bytesTotales > 0) {
        return MIN(1.0, (double)self.bytesHechos / (double)self.bytesTotales);
    }
    return 0.0;
}

- (NSString *)estadoTexto {
    switch (self.estado) {
        case ITDescargaEnEspera:
            return @"En espera";
        case ITDescargaActiva:
            if (self.segmentosTotales > 0) {
                return [NSString stringWithFormat:@"Descargando %d%% (%lu/%lu)",
                        (int)(self.progreso * 100.0),
                        (unsigned long)self.segmentosHechos,
                        (unsigned long)self.segmentosTotales];
            }
            return self.mensaje.length ? self.mensaje : @"Descargando…";
        case ITDescargaCompletada:
            return self.mensaje.length ? self.mensaje : @"Completada";
        case ITDescargaFallida:
            return self.mensaje.length ? self.mensaje : @"Error";
        case ITDescargaCancelada:
            return @"Cancelada";
    }
    return @"";
}

- (NSDictionary *)diccionario {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    d[@"identificador"] = self.identificador ?: @"";
    d[@"titulo"] = self.titulo ?: @"";
    d[@"login"] = self.login ?: @"";
    d[@"miniatura"] = self.miniatura ?: @"";
    d[@"calidad"] = self.calidad ?: @"Auto";
    d[@"carpeta"] = self.carpeta ?: @"";
    d[@"archivo"] = self.archivo ?: @"";
    d[@"duracion"] = @(self.duracion);
    d[@"segmentosTotales"] = @(self.segmentosTotales);
    d[@"segmentosHechos"] = @(self.segmentosHechos);
    d[@"bytesHechos"] = @(self.bytesHechos);
    d[@"bytesTotales"] = @(self.bytesTotales);
    d[@"estado"] = @(self.estado);
    d[@"mensaje"] = self.mensaje ?: @"";
    return d;
}

+ (instancetype)conDiccionario:(NSDictionary *)d {
    if (![d isKindOfClass:[NSDictionary class]]) return nil;
    ITDescarga *x = [[ITDescarga alloc] init];
    x.identificador = ITStr(d[@"identificador"]);
    x.titulo = ITStr(d[@"titulo"]);
    x.login = ITStr(d[@"login"]);
    x.miniatura = ITStr(d[@"miniatura"]);
    x.calidad = ITStr(d[@"calidad"]);
    x.carpeta = ITStr(d[@"carpeta"]);
    x.archivo = ITStr(d[@"archivo"]);
    x.duracion = ITNum(d[@"duracion"]);
    x.segmentosTotales = (NSUInteger)ITInt(d[@"segmentosTotales"]);
    x.segmentosHechos = (NSUInteger)ITInt(d[@"segmentosHechos"]);
    x.bytesHechos = ITLargo(d[@"bytesHechos"]);
    x.bytesTotales = ITLargo(d[@"bytesTotales"]);
    x.estado = (ITDescargaEstado)ITInt(d[@"estado"]);
    x.mensaje = ITStr(d[@"mensaje"]);
    if (x.identificador.length == 0) return nil;
    return x;
}

@end

#pragma mark - Gestor

@interface ITDownloadManager ()
- (void)cargarLista;
- (void)guardarLista;
- (void)avisar;
- (void)procesarCola;
- (void)iniciar:(ITDescarga *)descarga;
- (NSDictionary *)elegirVariante:(NSArray *)variantes calidad:(NSString *)calidad;
- (NSArray *)segmentosDe:(NSString *)texto base:(NSURL *)base;
- (NSString *)rutaParcialPara:(ITDescarga *)descarga;
- (void)prepararArchivoPara:(ITDescarga *)descarga;
- (void)descargarSegmentos:(NSArray *)urls indice:(NSUInteger)indice descarga:(ITDescarga *)descarga;
- (void)escribir:(NSData *)datos;
- (void)falloSegmento:(NSArray *)urls indice:(NSUInteger)indice descarga:(ITDescarga *)descarga
                error:(NSError *)error;
- (void)abortar:(ITDescarga *)descarga;
- (void)finalizar:(ITDescarga *)descarga;
- (void)terminar:(ITDescarga *)descarga conError:(NSString *)texto;
- (void)convertir:(NSString *)ts destino:(NSString *)mp4 completion:(void (^)(NSString *ruta))completion;
- (NSString *)nombreBasePara:(ITDescarga *)descarga;
- (NSString *)rutaLibre:(NSString *)ruta;
- (void)pedirTexto:(NSString *)url completion:(void (^)(NSString *texto, NSError *error))completion;
- (NSString *)carpetaValida:(NSString *)carpeta;
@end

@implementation ITDownloadManager {
    NSMutableArray *_lista;
    NSURLSession *_sesion;
    BOOL _procesando;
    NSFileHandle *_archivo;
    NSString *_rutaParte;
    NSUInteger _ultimoIndiceFallido;
    NSUInteger _intentos;
}

+ (instancetype)compartida {
    static ITDownloadManager *gestor = nil;
    static dispatch_once_t unaVez;
    dispatch_once(&unaVez, ^{
        gestor = [[ITDownloadManager alloc] init];
    });
    return gestor;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _lista = [NSMutableArray array];
        NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration defaultSessionConfiguration];
        cfg.timeoutIntervalForRequest = 30.0;
        cfg.timeoutIntervalForResource = 60.0 * 60.0 * 8.0;
        cfg.HTTPMaximumConnectionsPerHost = 1;
        _sesion = [NSURLSession sessionWithConfiguration:cfg];
        [self cargarLista];
    }
    return self;
}

#pragma mark - Carpetas

+ (NSString *)carpetaDeDescargas {
    NSString *ruta = [[NSUserDefaults standardUserDefaults] stringForKey:kITCarpetaDescargas];
    if (ruta.length == 0) ruta = kITCarpetaPredeterminada;
    return ruta;
}

+ (void)guardarCarpetaDeDescargas:(NSString *)ruta {
    NSString *limpia = [ruta stringByTrimmingCharactersInSet:
                        [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSUserDefaults *ajustes = [NSUserDefaults standardUserDefaults];
    if (limpia.length == 0) [ajustes removeObjectForKey:kITCarpetaDescargas];
    else [ajustes setObject:limpia forKey:kITCarpetaDescargas];
    [ajustes synchronize];
}

+ (NSString *)carpetaDeRespaldo {
    NSString *docs = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                          NSUserDomainMask, YES) firstObject];
    return [docs stringByAppendingPathComponent:@"Descargas"];
}

+ (BOOL)carpetaEscribible:(NSString *)ruta {
    if (ruta.length == 0) return NO;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error = nil;
    if (![fm fileExistsAtPath:ruta]) {
        if (![fm createDirectoryAtPath:ruta withIntermediateDirectories:YES
                            attributes:nil error:&error]) {
            NSLog(@"[iTwitch] no se pudo crear %@: %@", ruta, error);
            return NO;
        }
    }
    NSString *prueba = [ruta stringByAppendingPathComponent:@".itwitch-prueba"];
    BOOL ok = [fm createFileAtPath:prueba contents:[NSData data] attributes:nil];
    if (ok) [fm removeItemAtPath:prueba error:nil];
    return ok;
}

- (NSString *)carpetaValida:(NSString *)carpeta {
    NSString *destino = carpeta.length ? carpeta : [[self class] carpetaDeDescargas];
    if ([[self class] carpetaEscribible:destino]) return destino;

    NSString *respaldo = [[self class] carpetaDeRespaldo];
    NSLog(@"[iTwitch] sin permiso en %@; se usara %@", destino, respaldo);
    if ([[self class] carpetaEscribible:respaldo]) return respaldo;
    return nil;
}

#pragma mark - Lista

- (NSString *)rutaLista {
    NSString *docs = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                          NSUserDomainMask, YES) firstObject];
    return [docs stringByAppendingPathComponent:kITListaDescargas];
}

- (void)cargarLista {
    NSArray *guardadas = [NSArray arrayWithContentsOfFile:[self rutaLista]];
    for (NSDictionary *d in guardadas) {
        ITDescarga *desc = [ITDescarga conDiccionario:d];
        if (!desc) continue;
        if (desc.estado == ITDescargaActiva) desc.estado = ITDescargaEnEspera;
        if (desc.estado == ITDescargaCompletada && desc.archivo.length > 0) {
            if (![[NSFileManager defaultManager] fileExistsAtPath:desc.archivo]) {
                desc.estado = ITDescargaFallida;
                desc.mensaje = @"El archivo ya no está en la carpeta.";
            }
        }
        [_lista addObject:desc];
    }
    if (_lista.count) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self procesarCola]; });
    }
}

- (void)guardarLista {
    @synchronized (self) {
        NSMutableArray *arr = [NSMutableArray array];
        for (ITDescarga *d in _lista) [arr addObject:[d diccionario]];
        [arr writeToFile:[self rutaLista] atomically:YES];
    }
}

- (NSArray *)descargas {
    @synchronized (self) {
        return [_lista copy];
    }
}

- (void)avisar {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:ITDescargasCambiaron
                                                            object:self];
    });
}

#pragma mark - API publica

- (ITDescarga *)descargarVideo:(ITVideo *)video calidad:(NSString *)calidad carpeta:(NSString *)carpeta {
    if (video.identificador.length == 0) return nil;
    ITDescarga *d = [[ITDescarga alloc] init];
    d.identificador = video.identificador;
    d.titulo = video.titulo.length ? video.titulo : @"Vídeo de Twitch";
    d.login = video.login ?: @"";
    d.miniatura = video.miniatura ?: @"";
    d.duracion = video.duracion;
    d.calidad = calidad.length ? calidad : @"Auto";
    d.carpeta = carpeta.length ? carpeta : [[self class] carpetaDeDescargas];
    d.estado = ITDescargaEnEspera;
    d.mensaje = @"En cola";
    @synchronized (self) {
        [_lista insertObject:d atIndex:0];
    }
    [self guardarLista];
    [self avisar];
    [self procesarCola];
    return d;
}

- (void)cancelar:(ITDescarga *)descarga {
    if (!descarga) return;
    descarga.estado = ITDescargaCancelada;
    descarga.mensaje = @"Cancelada";
    NSString *parte = [self rutaParcialPara:descarga];
    [[NSFileManager defaultManager] removeItemAtPath:parte error:nil];
    if (_rutaParte && [_rutaParte isEqualToString:parte]) {
        @synchronized (_archivo) {
            [_archivo closeFile];
            _archivo = nil;
        }
        _rutaParte = nil;
    }
    [self guardarLista];
    [self avisar];
}

- (void)reintentar:(ITDescarga *)descarga {
    if (!descarga) return;
    descarga.estado = ITDescargaEnEspera;
    descarga.mensaje = @"En cola";
    descarga.segmentosHechos = 0;
    descarga.bytesHechos = 0;
    NSString *parte = [self rutaParcialPara:descarga];
    [[NSFileManager defaultManager] removeItemAtPath:parte error:nil];
    [self guardarLista];
    [self avisar];
    [self procesarCola];
}

- (void)eliminar:(ITDescarga *)descarga {
    if (!descarga) return;
    if (descarga.estado == ITDescargaActiva) [self cancelar:descarga];
    if (descarga.archivo.length) {
        [[NSFileManager defaultManager] removeItemAtPath:descarga.archivo error:nil];
    }
    [[NSFileManager defaultManager] removeItemAtPath:[self rutaParcialPara:descarga] error:nil];
    @synchronized (self) {
        [_lista removeObject:descarga];
    }
    [self guardarLista];
    [self avisar];
}

#pragma mark - Cola

- (void)procesarCola {
    if (_procesando) return;
    ITDescarga *siguiente = nil;
    @synchronized (self) {
        for (ITDescarga *d in _lista) {
            if (d.estado == ITDescargaEnEspera) { siguiente = d; break; }
        }
    }
    if (!siguiente) return;
    _procesando = YES;
    siguiente.estado = ITDescargaActiva;
    siguiente.mensaje = @"Conectando con Twitch…";
    [self avisar];
    [self iniciar:siguiente];
}

- (void)iniciar:(ITDescarga *)d {
    __weak typeof(self) debil = self;
    [ITPlayback urlVod:d.identificador completion:^(NSString *url, NSError *error) {
        __typeof(self) fuerte = debil;
        if (!fuerte) return;
        if (url.length == 0) {
            [fuerte terminar:d conError:error.localizedDescription ?: @"No se pudo abrir el vídeo."];
            return;
        }
        NSLog(@"[iTwitch] descarga: master %@", url);
        [fuerte pedirTexto:url completion:^(NSString *texto, NSError *e) {
            if (texto.length == 0) {
                [fuerte terminar:d conError:e.localizedDescription ?: @"No se pudo leer la lista."];
                return;
            }
            NSURL *base = [NSURL URLWithString:url];
            NSArray *variantes = [ITPlayback variantesDeTexto:texto base:base];
            NSDictionary *elegida = [fuerte elegirVariante:variantes calidad:d.calidad];
            if (!elegida) {
                [fuerte terminar:d conError:@"Ese vídeo no ofrece calidades descargables."];
                return;
            }
            d.calidad = elegida[@"nombre"] ?: d.calidad;
            NSString *urlVariante = [elegida[@"url"] absoluteString];
            NSLog(@"[iTwitch] descarga: variante %@", urlVariante);
            [fuerte pedirTexto:urlVariante completion:^(NSString *lista, NSError *e2) {
                if (lista.length == 0) {
                    [fuerte terminar:d conError:e2.localizedDescription ?: @"No se pudo leer la variante."];
                    return;
                }
                NSArray *segmentos = [fuerte segmentosDe:lista base:elegida[@"url"]];
                if (segmentos.count == 0) {
                    [fuerte terminar:d conError:@"La lista de segmentos está vacía."];
                    return;
                }
                d.segmentosTotales = segmentos.count;
                [fuerte prepararArchivoPara:d];
                NSUInteger inicio = MIN(d.segmentosHechos, segmentos.count);
                d.mensaje = @"Descargando…";
                [fuerte guardarLista];
                [fuerte avisar];
                [fuerte descargarSegmentos:segmentos indice:inicio descarga:d];
            }];
        }];
    }];
}

- (NSDictionary *)elegirVariante:(NSArray *)variantes calidad:(NSString *)calidad {
    if (variantes.count == 0) return nil;
    NSString *buscada = calidad.length ? calidad : @"Auto";

    for (NSDictionary *v in variantes) {
        if ([v[@"nombre"] caseInsensitiveCompare:buscada] == NSOrderedSame) return v;
    }
    if ([buscada hasSuffix:@"p"]) {
        NSInteger alto = [buscada integerValue];
        for (NSDictionary *v in variantes) {
            if ([v[@"alto"] integerValue] == alto) return v;
        }
    }
    if ([buscada isEqualToString:@"Audio"]) {
        for (NSDictionary *v in variantes) {
            if ([v[@"nombre"] isEqualToString:@"Audio"]) return v;
        }
    }

    // Auto: la mejor que no pase de 720p (el A5 no mueve mas con soltura).
    NSDictionary *mejor = nil;
    for (NSDictionary *v in variantes) {
        NSInteger alto = [v[@"alto"] integerValue];
        if (alto <= 0 || alto > 720) continue;
        if (!mejor || alto > [mejor[@"alto"] integerValue]) mejor = v;
    }
    if (mejor) return mejor;
    for (NSDictionary *v in variantes) {
        NSInteger alto = [v[@"alto"] integerValue];
        if (!mejor || alto > [mejor[@"alto"] integerValue]) mejor = v;
    }
    return mejor ?: variantes.firstObject;
}

- (NSArray *)segmentosDe:(NSString *)texto base:(NSURL *)base {
    NSMutableArray *urls = [NSMutableArray array];
    NSArray *lineas = [texto componentsSeparatedByCharactersInSet:
                       [NSCharacterSet newlineCharacterSet]];
    for (NSString *cruda in lineas) {
        NSString *linea = [cruda stringByTrimmingCharactersInSet:
                           [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (linea.length == 0 || [linea hasPrefix:@"#"]) continue;
        NSURL *url = [NSURL URLWithString:linea relativeToURL:base];
        if (url) [urls addObject:url];
    }
    return urls;
}

#pragma mark - Archivo de trabajo

- (NSString *)rutaParcialPara:(ITDescarga *)d {
    NSString *tmp = NSTemporaryDirectory();
    NSString *carpeta = [tmp stringByAppendingPathComponent:@"itwitch-descargas"];
    [[NSFileManager defaultManager] createDirectoryAtPath:carpeta
                              withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *nombre = [NSString stringWithFormat:@"%@-%@.part",
                        d.identificador ?: @"video",
                        [d.calidad stringByReplacingOccurrencesOfString:@"/" withString:@"-"]];
    return [carpeta stringByAppendingPathComponent:nombre];
}

- (void)prepararArchivoPara:(ITDescarga *)d {
    NSString *ruta = [self rutaParcialPara:d];
    NSFileManager *fm = [NSFileManager defaultManager];
    long long tam = 0;
    if ([fm fileExistsAtPath:ruta]) {
        tam = [[fm attributesOfItemAtPath:ruta error:nil][NSFileSize] longLongValue];
    }

    BOOL reanudar = (d.bytesHechos > 0 && tam >= d.bytesHechos &&
                     d.segmentosHechos > 0 && d.segmentosHechos < d.segmentosTotales);
    if (reanudar) {
        _archivo = [NSFileHandle fileHandleForUpdatingAtPath:ruta];
        [_archivo truncateFileAtOffset:(unsigned long long)d.bytesHechos];
        [_archivo seekToEndOfFile];
        NSLog(@"[iTwitch] descarga reanudada en el segmento %lu",
              (unsigned long)d.segmentosHechos);
    } else {
        [fm removeItemAtPath:ruta error:nil];
        [fm createFileAtPath:ruta contents:nil attributes:nil];
        _archivo = [NSFileHandle fileHandleForWritingAtPath:ruta];
        d.segmentosHechos = 0;
        d.bytesHechos = 0;
    }
    _rutaParte = ruta;
    _ultimoIndiceFallido = NSNotFound;
    _intentos = 0;
}

#pragma mark - Segmentos

- (void)descargarSegmentos:(NSArray *)urls indice:(NSUInteger)indice descarga:(ITDescarga *)d {
    if (d.estado != ITDescargaActiva) {
        [self abortar:d];
        return;
    }
    if (indice >= urls.count) {
        [self finalizar:d];
        return;
    }

    NSURL *url = urls[indice];
    NSMutableURLRequest *peticion = [NSMutableURLRequest requestWithURL:url];
    peticion.timeoutInterval = 30.0;

    __weak typeof(self) debil = self;
    NSURLSessionDataTask *tarea = [_sesion dataTaskWithRequest:peticion
        completionHandler:^(NSData *datos, NSURLResponse *respuesta, NSError *error) {
        __typeof(self) fuerte = debil;
        if (!fuerte) return;
        NSInteger codigo = 200;
        if ([respuesta isKindOfClass:[NSHTTPURLResponse class]]) {
            codigo = [(NSHTTPURLResponse *)respuesta statusCode];
        }
        if (error || codigo >= 400 || datos.length == 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [fuerte falloSegmento:urls indice:indice descarga:d
                                error:error ?: [NSError errorWithDomain:@"iTwitch"
                                    code:codigo userInfo:@{
                                        NSLocalizedDescriptionKey :
                                        [NSString stringWithFormat:@"Segmento %lu: HTTP %ld",
                                         (unsigned long)indice, (long)codigo]}]];
            });
            return;
        }

        [fuerte escribir:datos];
        dispatch_async(dispatch_get_main_queue(), ^{
            d.segmentosHechos = indice + 1;
            d.bytesHechos += (long long)datos.length;
            if (indice % 8 == 0 || indice + 1 == urls.count) {
                [fuerte guardarLista];
                [fuerte avisar];
            }
            [fuerte descargarSegmentos:urls indice:indice + 1 descarga:d];
        });
    }];
    [tarea resume];
}

- (void)escribir:(NSData *)datos {
    @synchronized (_archivo) {
        if (!_archivo) return;
        @try {
            [_archivo writeData:datos];
        } @catch (NSException *excepcion) {
            NSLog(@"[iTwitch] error escribiendo segmento: %@", excepcion);
        }
    }
}

- (void)falloSegmento:(NSArray *)urls indice:(NSUInteger)indice descarga:(ITDescarga *)d
                error:(NSError *)error {
    NSLog(@"[iTwitch] fallo en segmento %lu: %@", (unsigned long)indice, error);
    if (_ultimoIndiceFallido == indice) _intentos++;
    else { _ultimoIndiceFallido = indice; _intentos = 1; }

    if (_intentos >= 4) {
        [self terminar:d conError:[NSString stringWithFormat:
            @"Se cortó la descarga en el segmento %lu. %@",
            (unsigned long)indice, error.localizedDescription ?: @""]];
        return;
    }
    d.mensaje = [NSString stringWithFormat:@"Reintentando (%lu)…", (unsigned long)_intentos];
    [self avisar];
    __weak typeof(self) debil = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [debil descargarSegmentos:urls indice:indice descarga:d];
    });
}

- (void)abortar:(ITDescarga *)d {
    @synchronized (_archivo) {
        [_archivo closeFile];
        _archivo = nil;
    }
    [[NSFileManager defaultManager] removeItemAtPath:_rutaParte error:nil];
    _rutaParte = nil;
    d.estado = ITDescargaCancelada;
    d.mensaje = @"Cancelada";
    [self guardarLista];
    [self avisar];
    _procesando = NO;
    [self procesarCola];
}

#pragma mark - Final

- (void)finalizar:(ITDescarga *)d {
    @synchronized (_archivo) {
        [_archivo closeFile];
        _archivo = nil;
    }
    NSString *parte = _rutaParte;
    _rutaParte = nil;

    NSString *carpeta = [self carpetaValida:d.carpeta];
    if (carpeta.length == 0) {
        [self terminar:d conError:@"No hay ninguna carpeta donde se pueda escribir."];
        return;
    }
    d.carpeta = carpeta;
    d.mensaje = @"Convirtiendo a MP4…";
    [self avisar];

    NSString *base = [self nombreBasePara:d];
    NSString *mp4 = [self rutaLibre:[carpeta stringByAppendingPathComponent:
                                     [base stringByAppendingPathExtension:@"mp4"]]];

    __weak typeof(self) debil = self;
    [self convertir:parte destino:mp4 completion:^(NSString *final) {
        __typeof(self) fuerte = debil;
        if (!fuerte) return;
        NSFileManager *fm = [NSFileManager defaultManager];
        if (final.length > 0) {
            d.archivo = final;
            d.estado = ITDescargaCompletada;
            d.mensaje = @"";
            [fm removeItemAtPath:parte error:nil];
        } else {
            // Sin MP4 nos quedamos con el .ts, que VLC y Filza reproducen.
            NSString *ts = [fuerte rutaLibre:[carpeta stringByAppendingPathComponent:
                                              [base stringByAppendingPathExtension:@"ts"]]];
            NSError *error = nil;
            if ([fm moveItemAtPath:parte toPath:ts error:&error]) {
                d.archivo = ts;
                d.estado = ITDescargaCompletada;
                d.mensaje = @"Guardado como .ts";
            } else {
                d.estado = ITDescargaFallida;
                d.mensaje = error.localizedDescription ?: @"No se pudo guardar el archivo.";
            }
        }
        NSLog(@"[iTwitch] descarga terminada: %@ (%@)", d.archivo, d.mensaje);
        [fuerte guardarLista];
        [fuerte avisar];
        fuerte->_procesando = NO;
        [fuerte procesarCola];
    }];
}

- (void)terminar:(ITDescarga *)d conError:(NSString *)texto {
    @synchronized (_archivo) {
        [_archivo closeFile];
        _archivo = nil;
    }
    d.estado = ITDescargaFallida;
    d.mensaje = texto.length ? texto : @"Error de descarga.";
    NSLog(@"[iTwitch] descarga fallida: %@", d.mensaje);
    [self guardarLista];
    [self avisar];
    _procesando = NO;
    [self procesarCola];
}

// Remuxea el .ts a .mp4 sin recodificar. Si el sistema no puede, devuelve nil y
// el .ts se conserva tal cual.
- (void)convertir:(NSString *)ts destino:(NSString *)mp4 completion:(void (^)(NSString *))completion {
    if (ts.length == 0) { completion(nil); return; }
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:ts] options:nil];
    if (asset.tracks.count == 0) {
        NSLog(@"[iTwitch] el .ts no se puede abrir con AVFoundation");
        completion(nil);
        return;
    }
    AVAssetExportSession *exportador = [AVAssetExportSession
        exportSessionWithAsset:asset presetName:AVAssetExportPresetPassthrough];
    if (!exportador) { completion(nil); return; }

    NSArray *tipos = exportador.supportedFileTypes;
    NSString *tipo = nil;
    NSString *destino = mp4;
    if ([tipos containsObject:AVFileTypeMPEG4]) {
        tipo = AVFileTypeMPEG4;
    } else if ([tipos containsObject:AVFileTypeQuickTimeMovie]) {
        tipo = AVFileTypeQuickTimeMovie;
        destino = [[mp4 stringByDeletingPathExtension] stringByAppendingPathExtension:@"mov"];
    }
    if (!tipo) { completion(nil); return; }

    [[NSFileManager defaultManager] removeItemAtPath:destino error:nil];
    exportador.outputURL = [NSURL fileURLWithPath:destino];
    exportador.outputFileType = tipo;
    exportador.shouldOptimizeForNetworkUse = YES;

    [exportador exportAsynchronouslyWithCompletionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            if (exportador.status == AVAssetExportSessionStatusCompleted) {
                completion(destino);
            } else {
                NSLog(@"[iTwitch] exportacion no disponible: %@", exportador.error);
                [[NSFileManager defaultManager] removeItemAtPath:destino error:nil];
                completion(nil);
            }
        });
    }];
}

#pragma mark - Nombres

- (NSString *)nombreBasePara:(ITDescarga *)d {
    NSString *titulo = d.titulo.length ? d.titulo : @"Video de Twitch";
    NSCharacterSet *prohibidos = [NSCharacterSet characterSetWithCharactersInString:
                                  @"/\\:*?\"<>|\n\r\t"];
    titulo = [[titulo componentsSeparatedByCharactersInSet:prohibidos]
              componentsJoinedByString:@"-"];
    titulo = [titulo stringByTrimmingCharactersInSet:
              [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (titulo.length > 90) titulo = [titulo substringToIndex:90];

    NSString *base = titulo;
    if (d.login.length) {
        base = [NSString stringWithFormat:@"%@ - %@", d.login, titulo];
    }
    if (base.length > 120) base = [base substringToIndex:120];
    return base.length ? base : [NSString stringWithFormat:@"iTwitch-%@", d.identificador];
}

- (NSString *)rutaLibre:(NSString *)ruta {
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:ruta]) return ruta;

    NSString *carpeta = [ruta stringByDeletingLastPathComponent];
    NSString *extension = [ruta pathExtension];
    NSString *base = [[ruta lastPathComponent] stringByDeletingPathExtension];
    for (int i = 2; i < 500; i++) {
        NSString *nombre = [NSString stringWithFormat:@"%@ (%d).%@", base, i, extension];
        NSString *candidata = [carpeta stringByAppendingPathComponent:nombre];
        if (![fm fileExistsAtPath:candidata]) return candidata;
    }
    return ruta;
}

#pragma mark - Red

- (void)pedirTexto:(NSString *)url completion:(void (^)(NSString *, NSError *))completion {
    NSURL *destino = [NSURL URLWithString:url];
    if (!destino) {
        completion(nil, [NSError errorWithDomain:@"iTwitch" code:1
            userInfo:@{ NSLocalizedDescriptionKey : @"URL no válida." }]);
        return;
    }
    NSMutableURLRequest *peticion = [NSMutableURLRequest requestWithURL:destino];
    peticion.timeoutInterval = 30.0;
    [peticion setValue:@"application/vnd.apple.mpegurl, application/x-mpegURL, */*"
    forHTTPHeaderField:@"Accept"];

    [[_sesion dataTaskWithRequest:peticion
        completionHandler:^(NSData *datos, NSURLResponse *respuesta, NSError *error) {
        NSInteger codigo = 200;
        if ([respuesta isKindOfClass:[NSHTTPURLResponse class]]) {
            codigo = [(NSHTTPURLResponse *)respuesta statusCode];
        }
        if (error || codigo >= 400 || datos.length == 0) {
            NSString *mensaje = error.localizedDescription ?:
                [NSString stringWithFormat:@"Twitch respondió %ld.", (long)codigo];
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, [NSError errorWithDomain:@"iTwitch" code:codigo
                    userInfo:@{ NSLocalizedDescriptionKey : mensaje }]);
            });
            return;
        }
        NSString *texto = [[NSString alloc] initWithData:datos encoding:NSUTF8StringEncoding];
        if (!texto) {
            texto = [[NSString alloc] initWithData:datos encoding:NSISOLatin1StringEncoding];
        }
        dispatch_async(dispatch_get_main_queue(), ^{ completion(texto, nil); });
    }] resume];
}

@end
