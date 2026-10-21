#import "ITChatClient.h"
#import "ITSession.h"
#import "ITUtil.h"
#import <CFNetwork/CFNetwork.h>
#import <math.h>

// El chat vive en su propio hilo con su propio run loop. Si los flujos se
// programan en el run loop principal (como se hacía antes), cualquier espera
// del socket (handshake TLS, buffer lleno) congela la interfaz: en iOS el
// watchdog acaba matando la app con 0x8badf00d.
@interface ITChatClient () <NSStreamDelegate>
- (void)procesarDatos;
- (void)procesarBuffer;
@end

@implementation ITChatClient {
    NSInputStream *_entrada;
    NSOutputStream *_salida;
    NSMutableString *_buffer;
    NSMutableData *_datosPendientes;
    NSString *_canal;
    NSString *_nick;
    BOOL _abierto;
    BOOL _conectado;
    NSUInteger _intentos;
    NSTimer *_reconexion;
    NSThread *_hilo;
    NSRunLoop *_runLoopHilo;
    BOOL _hiloListo;
    BOOL _terminar;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _buffer = [NSMutableString string];
        _datosPendientes = [NSMutableData data];
    }
    return self;
}

- (void)dealloc {
    // Mientras el hilo vive conserva self, así que aquí ya no queda nadie
    // usando los flujos; se cierran por si acaso.
    [_reconexion invalidate];
    [_entrada close];
    [_salida close];
}

- (BOOL)conectado { return _conectado; }

#pragma mark - Hilo propio

- (void)asegurarHilo {
    if (_hilo && !_hilo.finished) return;
    _terminar = NO;
    _hiloListo = NO;
    _hilo = [[NSThread alloc] initWithTarget:self selector:@selector(bucleDelHilo) object:nil];
    _hilo.name = @"itwitch-chat";
    [_hilo start];

    // Se espera a que el run loop exista antes de encolar trabajo. Son
    // milisegundos y solo ocurre al abrir el chat.
    NSDate *limite = [NSDate dateWithTimeIntervalSinceNow:1.0];
    while (!_hiloListo && [limite timeIntervalSinceNow] > 0.0) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
}

- (void)bucleDelHilo {
    @autoreleasepool {
        _runLoopHilo = [NSRunLoop currentRunLoop];
        [_runLoopHilo addPort:[NSMachPort port] forMode:NSDefaultRunLoopMode];
        _hiloListo = YES;

        while (!_terminar) {
            @autoreleasepool {
                [_runLoopHilo runMode:NSDefaultRunLoopMode
                           beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
            }
        }

        [self cerrarEnHilo];
        _runLoopHilo = nil;
        _hiloListo = NO;
    }
}

- (void)ejecutar:(SEL)selector objeto:(id)objeto {
    if (!_hilo) return;
    if ([NSThread currentThread] == _hilo) {
        [self performSelector:selector withObject:objeto];
    } else {
        [self performSelector:selector onThread:_hilo withObject:objeto waitUntilDone:NO];
    }
}

#pragma mark - API publica

- (void)conectarCanal:(NSString *)canal {
    if (canal.length == 0) return;
    [self asegurarHilo];
    [self ejecutar:@selector(conectarEnHilo:) objeto:[canal lowercaseString]];
}

- (void)desconectar {
    [self ejecutar:@selector(cerrarEnHilo) objeto:nil];
}

- (void)cerrar {
    [self ejecutar:@selector(pararEnHilo) objeto:nil];
}

- (void)enviarMensaje:(NSString *)texto {
    if (texto.length == 0) return;
    [self ejecutar:@selector(enviarMensajeEnHilo:) objeto:[texto copy]];
}

#pragma mark - Conexion (siempre en el hilo del chat)

- (void)conectarEnHilo:(NSString *)canal {
    _canal = [canal copy];
    _intentos = 0;
    [self cerrarEnHilo];
    [self abrirEnHilo];
}

- (void)pararEnHilo {
    [self cerrarEnHilo];
    _terminar = YES;
    CFRunLoopStop(CFRunLoopGetCurrent());
}

- (void)abrirEnHilo {
    [_reconexion invalidate];
    _reconexion = nil;
    _buffer = [NSMutableString string];
    _datosPendientes = [NSMutableData data];
    _abierto = NO;
    _conectado = NO;

    NSString *token = [ITSession compartida].token;
    if (token.length > 0) {
        _nick = [ITSession compartida].usuario[@"login"];
        if (_nick.length == 0) _nick = @"itwitch";
    } else {
        _nick = [NSString stringWithFormat:@"justinfan%u", (unsigned int)(arc4random() % 99999) + 10000];
    }

    CFReadStreamRef lectura = NULL;
    CFWriteStreamRef escritura = NULL;
    CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault,
                                       CFSTR("irc.chat.twitch.tv"), 6697,
                                       &lectura, &escritura);
    if (!lectura || !escritura) {
        [self fallo:[NSError errorWithDomain:@"iTwitch" code:20
            userInfo:@{ NSLocalizedDescriptionKey : @"No se pudo abrir el socket de chat." }]];
        return;
    }

    NSDictionary *tls = @{
        (__bridge id)kCFStreamSSLLevel : (__bridge id)kCFStreamSocketSecurityLevelNegotiatedSSL,
        (__bridge id)kCFStreamSSLPeerName : @"irc.chat.twitch.tv",
        (__bridge id)kCFStreamSSLValidatesCertificateChain : @YES
    };
    CFReadStreamSetProperty(lectura, kCFStreamPropertySSLSettings, (__bridge CFDictionaryRef)tls);
    CFWriteStreamSetProperty(escritura, kCFStreamPropertySSLSettings, (__bridge CFDictionaryRef)tls);

    _entrada = (__bridge_transfer NSInputStream *)lectura;
    _salida = (__bridge_transfer NSOutputStream *)escritura;
    _entrada.delegate = self;
    _salida.delegate = self;

    NSRunLoop *runLoop = _runLoopHilo ?: [NSRunLoop currentRunLoop];
    [_entrada scheduleInRunLoop:runLoop forMode:NSDefaultRunLoopMode];
    [_salida scheduleInRunLoop:runLoop forMode:NSDefaultRunLoopMode];
    [_entrada open];
    [_salida open];
}

- (void)cerrarEnHilo {
    [_reconexion invalidate];
    _reconexion = nil;
    NSRunLoop *runLoop = _runLoopHilo ?: [NSRunLoop currentRunLoop];
    if (_entrada) {
        _entrada.delegate = nil;
        [_entrada close];
        [_entrada removeFromRunLoop:runLoop forMode:NSDefaultRunLoopMode];
        _entrada = nil;
    }
    if (_salida) {
        _salida.delegate = nil;
        [_salida close];
        [_salida removeFromRunLoop:runLoop forMode:NSDefaultRunLoopMode];
        _salida = nil;
    }
    _abierto = NO;
    _conectado = NO;
    [_datosPendientes setLength:0];
}

- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)evento {
    switch (evento) {
        case NSStreamEventOpenCompleted: {
            if (stream == _salida) {
                _abierto = YES;
                [self enviarLinea:[NSString stringWithFormat:
                    @"CAP REQ :twitch.tv/tags twitch.tv/commands"]];
                NSString *token = [ITSession compartida].token;
                if (token.length > 0) {
                    [self enviarLinea:[NSString stringWithFormat:@"PASS oauth:%@", token]];
                }
                [self enviarLinea:[NSString stringWithFormat:@"NICK %@", _nick]];
                [self enviarLinea:[NSString stringWithFormat:@"JOIN #%@", _canal]];
                _conectado = YES;
                _intentos = 0;
                dispatch_async(dispatch_get_main_queue(), ^{
                    if ([self.delegado respondsToSelector:@selector(chatConectado)]) {
                        [self.delegado chatConectado];
                    }
                });
            }
            break;
        }
        case NSStreamEventHasBytesAvailable: {
            uint8_t buf[4096];
            NSInteger leidos = [_entrada read:buf maxLength:sizeof(buf)];
            if (leidos > 0) {
                // Se acumulan bytes: un carácter UTF-8 puede quedar partido
                // entre dos lecturas del socket.
                [_datosPendientes appendBytes:buf length:(NSUInteger)leidos];
                [self procesarDatos];
            }
            break;
        }
        case NSStreamEventErrorOccurred: {
            [self fallo:stream.streamError];
            break;
        }
        case NSStreamEventEndEncountered: {
            [self cerrarYReconectar];
            break;
        }
        default:
            break;
    }
}

- (void)cerrarYReconectar {
    if (self.delegado && [self.delegado respondsToSelector:@selector(chatAviso:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegado chatAviso:@"Chat desconectado. Reconectando…"];
        });
    }
    [self cerrarEnHilo];
    _intentos++;
    NSTimeInterval espera = MIN(30.0, pow(2.0, (double)MIN(_intentos, 5)));
    _reconexion = [NSTimer scheduledTimerWithTimeInterval:espera target:self
                                                 selector:@selector(abrirEnHilo)
                                                 userInfo:nil repeats:NO];
}

- (void)fallo:(NSError *)error {
    if (self.delegado && [self.delegado respondsToSelector:@selector(chatFallo:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegado chatFallo:error];
        });
    }
    [self cerrarYReconectar];
}

#pragma mark - Envio

- (void)enviarLinea:(NSString *)linea {
    if (!_salida || !_abierto) return;
    NSString *completa = [linea stringByAppendingString:@"\r\n"];
    NSData *datos = [completa dataUsingEncoding:NSUTF8StringEncoding];
    [_salida write:datos.bytes maxLength:datos.length];
}

- (void)enviarMensajeEnHilo:(NSString *)texto {
    if (texto.length == 0 || !_conectado) return;
    if (![[ITSession compartida] haySesion]) return;
    [self enviarLinea:[NSString stringWithFormat:@"PRIVMSG #%@ :%@", _canal, texto]];
}

#pragma mark - Parseo

- (void)procesarDatos {
    if (_datosPendientes.length == 0) return;

    // Solo se decodifican líneas completas. Así no se pierde un mensaje
    // cuando el último carácter multibyte llega en la siguiente lectura.
    const uint8_t *bytes = _datosPendientes.bytes;
    NSInteger ultimo = -1;
    for (NSInteger i = (NSInteger)_datosPendientes.length - 1; i >= 0; i--) {
        if (bytes[i] == '\n') { ultimo = i; break; }
    }
    if (ultimo < 0) return;

    NSUInteger corte = (NSUInteger)ultimo + 1;
    NSData *completos = [_datosPendientes subdataWithRange:NSMakeRange(0, corte)];
    [_datosPendientes replaceBytesInRange:NSMakeRange(0, corte)
                                withBytes:NULL length:0];

    NSString *texto = [[NSString alloc] initWithData:completos encoding:NSUTF8StringEncoding];
    if (!texto) texto = [[NSString alloc] initWithData:completos encoding:NSISOLatin1StringEncoding];
    if (texto) {
        [_buffer appendString:texto];
        [self procesarBuffer];
    }
}

- (void)procesarBuffer {
    while (YES) {
        NSRange salto = [_buffer rangeOfString:@"\r\n"];
        if (salto.location == NSNotFound) break;
        NSString *linea = [_buffer substringToIndex:salto.location];
        [_buffer deleteCharactersInRange:NSMakeRange(0, salto.location + 2)];
        if (linea.length > 0) [self procesarLinea:linea];
    }
}

- (void)procesarLinea:(NSString *)linea {
    NSString *resto = linea;
    NSMutableDictionary *tags = [NSMutableDictionary dictionary];

    if ([resto hasPrefix:@"@"]) {
        NSRange espacio = [resto rangeOfString:@" "];
        if (espacio.location == NSNotFound) return;
        NSString *bloque = [resto substringWithRange:NSMakeRange(1, espacio.location - 1)];
        resto = [resto substringFromIndex:espacio.location + 1];
        for (NSString *parte in [bloque componentsSeparatedByString:@";"]) {
            NSRange igual = [parte rangeOfString:@"="];
            if (igual.location == NSNotFound) {
                tags[parte] = @"";
            } else {
                NSString *clave = [parte substringToIndex:igual.location];
                NSString *valor = [parte substringFromIndex:igual.location + 1];
                valor = [valor stringByReplacingOccurrencesOfString:@"\\s" withString:@" "];
                valor = [valor stringByReplacingOccurrencesOfString:@"\\:" withString:@":"];
                valor = [valor stringByReplacingOccurrencesOfString:@"\\\\" withString:@"\\"];
                tags[clave] = valor;
            }
        }
    }

    if ([resto hasPrefix:@"PING"]) {
        [self enviarLinea:@"PONG :tmi.twitch.tv"];
        return;
    }
    if ([resto hasPrefix:@"RECONNECT"]) {
        [self cerrarYReconectar];
        return;
    }
    if ([resto hasPrefix:@"NOTICE"]) {
        NSRange dosPuntos = [resto rangeOfString:@" :"];
        if (dosPuntos.location != NSNotFound) {
            NSString *aviso = [resto substringFromIndex:dosPuntos.location + 2];
            if (self.delegado && [self.delegado respondsToSelector:@selector(chatAviso:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegado chatAviso:aviso];
                });
            }
        }
        return;
    }

    NSRange dosPuntos = [resto rangeOfString:@" :"];
    if (dosPuntos.location == NSNotFound) return;
    NSString *cabecera = [resto substringToIndex:dosPuntos.location];
    NSString *texto = [resto substringFromIndex:dosPuntos.location + 2];

    NSArray *partes = [cabecera componentsSeparatedByString:@" "];
    if (partes.count < 2) return;
    NSString *comando = partes[1];
    if (![comando isEqualToString:@"PRIVMSG"]) return;
    if (partes.count < 3) return;
    NSString *destino = partes[2];

    NSString *nombre = tags[@"display-name"];
    if (nombre.length == 0) nombre = _nick;
    BOOL accion = NO;
    if ([texto hasPrefix:@"\001ACTION "] && [texto hasSuffix:@"\001"]) {
        texto = [texto substringWithRange:NSMakeRange(8, texto.length - 9)];
        accion = YES;
    }

    ITChatMessage *m = [[ITChatMessage alloc] init];
    m.identificador = tags[@"id"] ?: [NSString stringWithFormat:@"%f", [NSDate timeIntervalSinceReferenceDate]];
    m.nombre = nombre;
    m.color = tags[@"color"] ?: @"";
    m.texto = texto;
    m.logins = tags[@"badges"] ?: @"";
    m.esAccion = accion;

    NSMutableArray *emotes = [NSMutableArray array];
    for (NSString *bloque in [(tags[@"emotes"] ?: @"") componentsSeparatedByString:@"/"]) {
        NSRange dosPuntos = [bloque rangeOfString:@":"];
        if (dosPuntos.location == NSNotFound) continue;
        NSString *identificador = [bloque substringToIndex:dosPuntos.location];
        NSString *rangos = [bloque substringFromIndex:dosPuntos.location + 1];
        for (NSString *rango in [rangos componentsSeparatedByString:@","]) {
            NSRange guion = [rango rangeOfString:@"-"];
            if (guion.location == NSNotFound) continue;
            NSInteger inicio = [[rango substringToIndex:guion.location] integerValue];
            NSInteger fin = [[rango substringFromIndex:guion.location + 1] integerValue];
            if (identificador.length == 0 || inicio < 0 || fin < inicio ||
                (NSUInteger)fin >= texto.length) continue;
            [emotes addObject:@{ @"id" : identificador,
                                 @"inicio" : @(inicio),
                                 @"fin" : @(fin) }];
        }
    }
    if (emotes.count > 1) {
        [emotes sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
            return [a[@"inicio"] compare:b[@"inicio"]];
        }];
    }
    m.emotes = emotes;

    if ([tags[@"mod"] isEqualToString:@"1"]) m.logins = [m.logins stringByAppendingString:@",mod"];
    if ([tags[@"subscriber"] isEqualToString:@"1"]) m.logins = [m.logins stringByAppendingString:@",subscriber"];
    (void)destino;

    if (self.delegado && [self.delegado respondsToSelector:@selector(chatRecibioMensaje:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegado chatRecibioMensaje:m];
        });
    }
}

@end
