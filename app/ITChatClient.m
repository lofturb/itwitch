#import "ITChatClient.h"
#import "ITSession.h"
#import "ITUtil.h"
#import <CFNetwork/CFNetwork.h>
#import <math.h>

@interface ITChatClient () <NSStreamDelegate>
@end

@implementation ITChatClient {
    NSInputStream *_entrada;
    NSOutputStream *_salida;
    NSMutableString *_buffer;
    NSString *_canal;
    NSString *_nick;
    BOOL _abierto;
    BOOL _conectado;
    NSUInteger _intentos;
    NSTimer *_reconexion;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _buffer = [NSMutableString string];
    }
    return self;
}

- (void)dealloc {
    [self desconectar];
}

- (BOOL)conectado { return _conectado; }

#pragma mark - Conexion

- (void)conectarCanal:(NSString *)canal {
    if (canal.length == 0) return;
    [self desconectar];
    _canal = [canal lowercaseString];
    _intentos = 0;
    [self abrir];
}

- (void)abrir {
    [_reconexion invalidate];
    _reconexion = nil;
    _buffer = [NSMutableString string];
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

    [_entrada scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    [_salida scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    [_entrada open];
    [_salida open];
}

- (void)desconectar {
    [_reconexion invalidate];
    _reconexion = nil;
    if (_entrada) {
        _entrada.delegate = nil;
        [_entrada close];
        [_entrada removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
        _entrada = nil;
    }
    if (_salida) {
        _salida.delegate = nil;
        [_salida close];
        [_salida removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
        _salida = nil;
    }
    _abierto = NO;
    _conectado = NO;
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
                NSString *texto = [[NSString alloc] initWithBytes:buf length:leidos encoding:NSUTF8StringEncoding];
                if (texto) {
                    [_buffer appendString:texto];
                    [self procesarBuffer];
                }
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
    [self desconectar];
    _intentos++;
    NSTimeInterval espera = MIN(30.0, pow(2.0, (double)MIN(_intentos, 5)));
    _reconexion = [NSTimer scheduledTimerWithTimeInterval:espera target:self
                                                 selector:@selector(abrir)
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

- (void)enviarMensaje:(NSString *)texto {
    if (texto.length == 0 || !_conectado) return;
    if (![[ITSession compartida] haySesion]) return;
    [self enviarLinea:[NSString stringWithFormat:@"PRIVMSG #%@ :%@", _canal, texto]];
}

#pragma mark - Parseo

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
