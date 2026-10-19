#import "ITApi.h"
#import "ITSession.h"
#import "ITUtil.h"

static NSString * const kITGQL = @"https://gql.twitch.tv/gql";
static NSString * const kITClientID = @"kimne78kx3ncx6brgo4mv6wki5h1ko";

static NSError *ITError(NSString *mensaje) {
    return [NSError errorWithDomain:@"iTwitch" code:1
                           userInfo:@{ NSLocalizedDescriptionKey : mensaje ?: @"Error de Twitch" }];
}

static NSString *ITEscapar(NSString *texto) {
    if (![texto isKindOfClass:[NSString class]]) return @"";
    NSMutableString *s = [texto mutableCopy];
    [s replaceOccurrencesOfString:@"\\" withString:@"\\\\" options:0 range:NSMakeRange(0, s.length)];
    [s replaceOccurrencesOfString:@"\"" withString:@"\\\"" options:0 range:NSMakeRange(0, s.length)];
    [s replaceOccurrencesOfString:@"\n" withString:@"\\n" options:0 range:NSMakeRange(0, s.length)];
    return s;
}

static void ITEnMain(dispatch_block_t bloque) {
    if ([NSThread isMainThread]) bloque();
    else dispatch_async(dispatch_get_main_queue(), bloque);
}

// Un comentario de VOD: texto con emotes y desplazamiento dentro del video.
static ITChatMessage *ITMensajeReplay(NSDictionary *nodo) {
    NSDictionary *mensaje = ITDic(nodo[@"message"]);
    NSMutableString *texto = [NSMutableString string];
    NSMutableArray *emotes = [NSMutableArray array];
    for (id f in ITArr(mensaje[@"fragments"])) {
        NSDictionary *fragmento = ITDic(f);
        NSString *t = ITStr(fragmento[@"text"]);
        if (!t) continue;
        [texto appendString:t];

        // El id del emote en VOD llega como "id;inicio;fin".
        NSString *emoteID = ITStr(ITDic(fragmento[@"emote"])[@"id"]);
        NSArray *partes = [emoteID componentsSeparatedByString:@";"];
        if (partes.count >= 3) {
            NSInteger inicio = [partes[1] integerValue];
            NSInteger fin = [partes[2] integerValue];
            if (inicio >= 0 && fin >= inicio && (NSUInteger)fin < texto.length) {
                [emotes addObject:@{ @"id" : partes[0],
                                     @"inicio" : @(inicio),
                                     @"fin" : @(fin) }];
            }
        }
    }
    if (texto.length == 0) return nil;
    if (emotes.count > 1) {
        [emotes sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
            return [a[@"inicio"] compare:b[@"inicio"]];
        }];
    }
    ITChatMessage *m = [[ITChatMessage alloc] init];
    m.identificador = ITStr(nodo[@"id"]) ?: @"";
    m.offset = ITNum(nodo[@"contentOffsetSeconds"]);
    m.nombre = ITStr(ITDic(nodo[@"commenter"])[@"displayName"]) ?: @"";
    m.color = ITStr(mensaje[@"userColor"]) ?: @"";
    m.texto = texto;
    m.emotes = emotes;
    m.esReplay = YES;
    return m;
}

@interface ITApi ()
- (void)comentariosVod:(NSString *)videoID
                 desde:(NSInteger)desde
                vistos:(NSMutableSet *)vistos
            acumulados:(NSMutableArray *)salida
              paginas:(NSInteger)paginas
            completion:(ITListaBloque)completion;
@end

@implementation ITApi

+ (instancetype)compartida {
    static ITApi *api = nil;
    static dispatch_once_t una;
    dispatch_once(&una, ^{ api = [[ITApi alloc] init]; });
    return api;
}

#pragma mark - Transporte

- (void)peticion:(NSString *)query variables:(NSDictionary *)variables
      completion:(void (^)(NSDictionary *datos, NSError *error))completion {
    NSMutableURLRequest *peticion = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:kITGQL]];
    peticion.HTTPMethod = @"POST";
    peticion.timeoutInterval = 20.0;
    [peticion setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [peticion setValue:kITClientID forHTTPHeaderField:@"Client-ID"];
    [peticion setValue:@"iTwitch/1.0 (iOS 9; armv7)" forHTTPHeaderField:@"User-Agent"];

    NSString *token = [ITSession compartida].token;
    if (token.length > 0) {
        [peticion setValue:[NSString stringWithFormat:@"OAuth %@", token]
        forHTTPHeaderField:@"Authorization"];
    }

    NSMutableDictionary *cuerpo = [NSMutableDictionary dictionary];
    cuerpo[@"query"] = query ?: @"";
    if (variables) cuerpo[@"variables"] = variables;

    NSError *jsonError = nil;
    peticion.HTTPBody = [NSJSONSerialization dataWithJSONObject:cuerpo
                                                       options:0
                                                         error:&jsonError];
    if (jsonError) {
        ITEnMain(^{ if (completion) completion(nil, jsonError); });
        return;
    }

    NSURLSessionDataTask *tarea =
        [[NSURLSession sharedSession] dataTaskWithRequest:peticion
                                       completionHandler:^(NSData *datos,
                                                           NSURLResponse *respuesta,
                                                           NSError *error) {
        if (error) {
            ITEnMain(^{ if (completion) completion(nil, error); });
            return;
        }

        NSInteger codigo = 0;
        if ([respuesta isKindOfClass:[NSHTTPURLResponse class]]) {
            codigo = [(NSHTTPURLResponse *)respuesta statusCode];
        }
        if (codigo == 401 || codigo == 403) {
            ITEnMain(^{ if (completion) completion(nil, ITError(@"Twitch ha rechazado la sesión.")); });
            return;
        }
        if (!datos) {
            ITEnMain(^{ if (completion) completion(nil, ITError(@"Twitch no devolvió datos.")); });
            return;
        }

        NSError *parseError = nil;
        id bruto = [NSJSONSerialization JSONObjectWithData:datos options:0 error:&parseError];
        if (![bruto isKindOfClass:[NSDictionary class]]) {
            ITEnMain(^{ if (completion) completion(nil, parseError ?: ITError(@"Respuesta no válida.")); });
            return;
        }

        NSDictionary *raiz = bruto;
        NSDictionary *data = ITDic(raiz[@"data"]);
        NSArray *errores = ITArr(raiz[@"errors"]);
        if (data.count == 0 && errores.count > 0) {
            NSString *mensaje = ITStr(ITDic(errores.firstObject)[@"message"]);
            ITEnMain(^{ if (completion) completion(nil, ITError(mensaje)); });
            return;
        }
        ITEnMain(^{ if (completion) completion(data, nil); });
    }];
    [tarea resume];
}

#pragma mark - Inicio / explorar

- (void)directos:(NSInteger)cantidad completion:(ITListaBloque)completion {
    if (cantidad < 1) cantidad = 1;
    if (cantidad > 30) cantidad = 30;
    NSString *q = @"query($n:Int!){ streams(first:$n){ edges{ node{"
                  @" id title viewersCount createdAt previewImageURL(width:440)"
                  @" game{ id displayName }"
                  @" broadcaster{ id login displayName profileImageURL(width:70) }"
                  @" } } } }";
    [self peticion:q variables:@{ @"n" : @(cantidad) } completion:^(NSDictionary *datos, NSError *error) {
        if (error) { if (completion) completion(nil, error); return; }
        NSMutableArray *salida = [NSMutableArray array];
        for (id e in ITArr(ITDic(datos[@"streams"])[@"edges"])) {
            ITStream *s = [ITStream conDiccionario:ITDic(ITDic(e)[@"node"])];
            if (s) [salida addObject:s];
        }
        if (completion) completion(salida, nil);
    }];
}

- (void)categorias:(NSInteger)cantidad completion:(ITListaBloque)completion {
    if (cantidad < 1) cantidad = 1;
    if (cantidad > 30) cantidad = 30;
    NSString *q = @"query($n:Int!){ games(first:$n){ edges{ node{"
                  @" id name displayName viewersCount boxArtURL(width:285,height:380)"
                  @" } } } }";
    [self peticion:q variables:@{ @"n" : @(cantidad) } completion:^(NSDictionary *datos, NSError *error) {
        if (error) { if (completion) completion(nil, error); return; }
        NSMutableArray *salida = [NSMutableArray array];
        for (id e in ITArr(ITDic(datos[@"games"])[@"edges"])) {
            ITGame *g = [ITGame conDiccionario:ITDic(ITDic(e)[@"node"])];
            if (g) [salida addObject:g];
        }
        if (completion) completion(salida, nil);
    }];
}

- (void)directosDelJuego:(NSString *)juego completion:(ITListaBloque)completion {
    NSString *q = @"query($juego:String!){ game(name:$juego){"
                  @" streams(first:30){ edges{ node{"
                  @" id title viewersCount createdAt previewImageURL(width:440)"
                  @" game{ id displayName }"
                  @" broadcaster{ id login displayName profileImageURL(width:70) }"
                  @" } } } } }";
    [self peticion:q variables:@{ @"juego" : juego ?: @"" } completion:^(NSDictionary *datos, NSError *error) {
        if (error) { if (completion) completion(nil, error); return; }
        NSMutableArray *salida = [NSMutableArray array];
        NSDictionary *game = ITDic(datos[@"game"]);
        for (id e in ITArr(ITDic(game[@"streams"])[@"edges"])) {
            ITStream *s = [ITStream conDiccionario:ITDic(ITDic(e)[@"node"])];
            if (s) [salida addObject:s];
        }
        if (completion) completion(salida, nil);
    }];
}

#pragma mark - Buscar

- (void)sugerencias:(NSString *)texto completion:(ITListaBloque)completion {
    NSString *q = @"query($q:String!){ searchSuggestions(queryFragment:$q){"
                  @" edges{ node{ id text } } } }";
    [self peticion:q variables:@{ @"q" : texto ?: @"" } completion:^(NSDictionary *datos, NSError *error) {
        if (error) { if (completion) completion(nil, error); return; }
        NSMutableArray *salida = [NSMutableArray array];
        for (id e in ITArr(ITDic(datos[@"searchSuggestions"])[@"edges"])) {
            NSString *t = ITStr(ITDic(ITDic(e)[@"node"])[@"text"]);
            if (t.length > 0 && ![salida containsObject:t]) [salida addObject:t];
        }
        if (completion) completion(salida, nil);
    }];
}

- (void)buscarCanales:(NSString *)texto completion:(ITListaBloque)completion {
    NSString *q = @"query($q:String!){ searchUsers(userQuery:$q,first:30){"
                  @" edges{ node{"
                  @" id login displayName profileImageURL(width:70)"
                  @" followers{ totalCount }"
                  @" stream{ id title viewersCount game{ displayName } }"
                  @" } } } }";
    [self peticion:q variables:@{ @"q" : texto ?: @"" } completion:^(NSDictionary *datos, NSError *error) {
        if (error) { if (completion) completion(nil, error); return; }
        NSMutableArray *salida = [NSMutableArray array];
        for (id e in ITArr(ITDic(datos[@"searchUsers"])[@"edges"])) {
            ITChannel *c = [ITChannel conDiccionario:ITDic(ITDic(e)[@"node"])];
            if (c) [salida addObject:c];
        }
        if (completion) completion(salida, nil);
    }];
}

- (void)buscarCategorias:(NSString *)texto completion:(ITListaBloque)completion {
    NSString *q = @"query($q:String!){ searchCategories(query:$q,first:20){"
                  @" edges{ node{ id name displayName viewersCount boxArtURL(width:285,height:380) } } } }";
    [self peticion:q variables:@{ @"q" : texto ?: @"" } completion:^(NSDictionary *datos, NSError *error) {
        if (error) { if (completion) completion(nil, error); return; }
        NSMutableArray *salida = [NSMutableArray array];
        for (id e in ITArr(ITDic(datos[@"searchCategories"])[@"edges"])) {
            ITGame *g = [ITGame conDiccionario:ITDic(ITDic(e)[@"node"])];
            if (g) [salida addObject:g];
        }
        if (completion) completion(salida, nil);
    }];
}

#pragma mark - Canal

- (void)canal:(NSString *)login completion:(ITObjetoBloque)completion {
    NSString *q = @"query($login:String!){ user(login:$login){"
                  @" id login displayName description createdAt"
                  @" profileImageURL(width:300) bannerImageURL offlineImageURL"
                  @" followers{ totalCount } roles{ isPartner isAffiliate }"
                  @" channel{ socialMedias{ name url }"
                  @"   schedule{ segments{ id startAt endAt title categories{ id name } } } }"
                  @" panels{ __typename ... on DefaultPanel { id title description imageURL linkURL } }"
                  @" stream{ id title viewersCount game{ displayName } }"
                  @" } }";
    [self peticion:q variables:@{ @"login" : login ?: @"" } completion:^(NSDictionary *datos, NSError *error) {
        if (error) { if (completion) completion(nil, error); return; }
        ITChannel *c = [ITChannel conDiccionario:ITDic(datos[@"user"])];
        if (completion) completion(c, c ? nil : ITError(@"Canal no encontrado."));
    }];
}

- (void)videosDe:(NSString *)login tipo:(NSString *)tipo orden:(NSString *)orden
      completion:(ITListaBloque)completion {
    NSString *t = tipo ?: @"ARCHIVE";
    NSString *o = orden ?: @"TIME";
    NSArray *tipos = @[ @"ARCHIVE", @"HIGHLIGHT", @"UPLOAD", @"ALL" ];
    NSArray *ordenes = @[ @"TIME", @"VIEWS" ];
    if (![tipos containsObject:t]) t = @"ARCHIVE";
    if (![ordenes containsObject:o]) o = @"TIME";

    NSString *filtro = [t isEqualToString:@"ALL"] ? @"" :
        [NSString stringWithFormat:@",type:%@", t];
    NSString *q = [NSString stringWithFormat:
        @"query($login:String!){ user(login:$login){ videos(first:30%@,sort:%@){"
         @" edges{ node{ id title lengthSeconds viewCount createdAt"
         @" previewThumbnailURL broadcastType owner{ login } } } } } }", filtro, o];

    [self peticion:q variables:@{ @"login" : login ?: @"" } completion:^(NSDictionary *datos, NSError *error) {
        if (error) { if (completion) completion(nil, error); return; }
        NSMutableArray *salida = [NSMutableArray array];
        for (id e in ITArr(ITDic(ITDic(datos[@"user"])[@"videos"])[@"edges"])) {
            ITVideo *v = [ITVideo conDiccionario:ITDic(ITDic(e)[@"node"])];
            if (v) [salida addObject:v];
        }
        if (completion) completion(salida, nil);
    }];
}

- (void)clipsDe:(NSString *)login periodo:(NSString *)periodo
     completion:(ITListaBloque)completion {
    NSString *p = periodo ?: @"ALL_TIME";
    NSArray *periodos = @[ @"LAST_DAY", @"LAST_WEEK", @"LAST_MONTH", @"ALL_TIME" ];
    if (![periodos containsObject:p]) p = @"ALL_TIME";

    NSString *q = [NSString stringWithFormat:
        @"query($login:String!){ user(login:$login){ clips(first:30,criteria:{period:%@}){"
         @" edges{ node{ id slug title durationSeconds viewCount createdAt"
         @" thumbnailURL curator{ displayName } } } } } }", p];

    [self peticion:q variables:@{ @"login" : login ?: @"" } completion:^(NSDictionary *datos, NSError *error) {
        if (error) { if (completion) completion(nil, error); return; }
        NSMutableArray *salida = [NSMutableArray array];
        for (id e in ITArr(ITDic(ITDic(datos[@"user"])[@"clips"])[@"edges"])) {
            ITClip *c = [ITClip conDiccionario:ITDic(ITDic(e)[@"node"])];
            if (c) [salida addObject:c];
        }
        if (completion) completion(salida, nil);
    }];
}

- (void)coleccionesDe:(NSString *)login completion:(ITListaBloque)completion {
    NSString *q = @"query($login:String!){ user(login:$login){ collections(first:20){"
                  @" edges{ node{ id title description updatedAt"
                  @" items(first:100){ edges{ node{ ... on Video {"
                  @" id title lengthSeconds viewCount createdAt previewThumbnailURL owner{ login }"
                  @" } } } } } } } } }";
    [self peticion:q variables:@{ @"login" : login ?: @"" } completion:^(NSDictionary *datos, NSError *error) {
        if (error) { if (completion) completion(nil, error); return; }
        NSMutableArray *salida = [NSMutableArray array];
        for (id e in ITArr(ITDic(ITDic(datos[@"user"])[@"collections"])[@"edges"])) {
            ITCollection *c = [ITCollection conDiccionario:ITDic(ITDic(e)[@"node"])];
            if (c) [salida addObject:c];
        }
        if (completion) completion(salida, nil);
    }];
}

#pragma mark - Reproduccion

- (void)tokenDirecto:(NSString *)login completion:(ITTokenBloque)completion {
    NSString *q = @"query($login:String!){ streamPlaybackAccessToken("
                  @" channelName:$login,"
                  @" params:{ platform:\"web\", playerBackend:\"mediaplayer\", playerType:\"site\" }"
                  @"){ value signature } }";
    [self peticion:q variables:@{ @"login" : login ?: @"" } completion:^(NSDictionary *datos, NSError *error) {
        if (error) { if (completion) completion(nil, nil, error); return; }
        NSDictionary *t = ITDic(datos[@"streamPlaybackAccessToken"]);
        NSString *valor = ITStr(t[@"value"]);
        NSString *firma = ITStr(t[@"signature"]);
        if (valor.length == 0) {
            if (completion) completion(nil, nil, ITError(@"No se pudo obtener el token del directo."));
        } else if (completion) {
            completion(valor, firma ?: @"", nil);
        }
    }];
}

- (void)tokenVod:(NSString *)videoID completion:(ITTokenBloque)completion {
    NSString *q = @"query($id:ID!){ videoPlaybackAccessToken("
                  @" id:$id,"
                  @" params:{ platform:\"web\", playerBackend:\"mediaplayer\", playerType:\"site\" }"
                  @"){ value signature } }";
    [self peticion:q variables:@{ @"id" : videoID ?: @"" } completion:^(NSDictionary *datos, NSError *error) {
        if (error) { if (completion) completion(nil, nil, error); return; }
        NSDictionary *t = ITDic(datos[@"videoPlaybackAccessToken"]);
        NSString *valor = ITStr(t[@"value"]);
        NSString *firma = ITStr(t[@"signature"]);
        if (valor.length == 0) {
            if (completion) completion(nil, nil, ITError(@"No se pudo obtener el token del vídeo."));
        } else if (completion) {
            completion(valor, firma ?: @"", nil);
        }
    }];
}

- (void)clip:(NSString *)slug completion:(ITObjetoBloque)completion {
    NSString *q = @"query($slug:ID!){ clip(slug:$slug){"
                  @" id title durationSeconds viewCount createdAt thumbnailURL"
                  @" curator{ displayName }"
                  @" playbackAccessToken(params:{ platform:\"web\", playerBackend:\"mediaplayer\", playerType:\"site\" }){ value signature }"
                  @" videoQualities{ sourceURL quality frameRate }"
                  @" } }";
    [self peticion:q variables:@{ @"slug" : slug ?: @"" } completion:^(NSDictionary *datos, NSError *error) {
        if (error) { if (completion) completion(nil, error); return; }
        ITClip *c = [ITClip conDiccionario:ITDic(datos[@"clip"])];
        if (completion) completion(c, c ? nil : ITError(@"Clip no encontrado."));
    }];
}

- (void)comentariosVod:(NSString *)videoID completion:(ITListaBloque)completion {
    [self comentariosVod:videoID
                   desde:0
                  vistos:[NSMutableSet set]
              acumulados:[NSMutableArray array]
                paginas:0
              completion:completion];
}

- (void)comentariosVod:(NSString *)videoID
                 desde:(NSInteger)desde
                vistos:(NSMutableSet *)vistos
            acumulados:(NSMutableArray *)salida
              paginas:(NSInteger)paginas
            completion:(ITListaBloque)completion {
    if (paginas >= 100 || salida.count >= 6000) {
        if (completion) {
            [salida sortUsingComparator:^NSComparisonResult(ITChatMessage *a, ITChatMessage *b) {
                if (a.offset < b.offset) return NSOrderedAscending;
                if (a.offset > b.offset) return NSOrderedDescending;
                return NSOrderedSame;
            }];
            completion([salida copy], nil);
        }
        return;
    }

    NSString *q = @"query($id:ID!,$off:Int!){ video(id:$id){ lengthSeconds"
                  @" comments(contentOffsetSeconds:$off){ edges{ node{ id contentOffsetSeconds"
                  @" commenter{ displayName } message{ userColor fragments{ text emote{ id } } }"
                  @" } } } } }";
    [self peticion:q variables:@{ @"id" : videoID ?: @"", @"off" : @(desde) }
        completion:^(NSDictionary *datos, NSError *error) {
        if (error) {
            // Si ya hay comentarios, se conserva la parte descargada.
            if (salida.count > 0) {
                if (completion) completion([salida copy], nil);
            } else if (completion) {
                completion(nil, error);
            }
            return;
        }

        NSDictionary *video = ITDic(datos[@"video"]);
        double duracion = ITNum(video[@"lengthSeconds"]);
        NSArray *edges = ITArr(ITDic(video[@"comments"])[@"edges"]);
        NSInteger maximo = desde;
        for (id e in edges) {
            NSDictionary *nodo = ITDic(ITDic(e)[@"node"]);
            ITChatMessage *m = ITMensajeReplay(nodo);
            if (!m) continue;
            NSString *clave = m.identificador.length ? m.identificador
                : [NSString stringWithFormat:@"%.0f:%@", m.offset, m.texto];
            if ([vistos containsObject:clave]) continue;
            [vistos addObject:clave];
            [salida addObject:m];
            if (m.offset > maximo) maximo = (NSInteger)m.offset;
        }

        NSInteger siguiente = maximo + 1;
        BOOL fin = (edges.count == 0 || siguiente <= desde);
        if (duracion > 0 && siguiente >= (NSInteger)duracion) fin = YES;
        if (salida.count >= 6000 || paginas + 1 >= 100) fin = YES;
        if (fin) {
            [salida sortUsingComparator:^NSComparisonResult(ITChatMessage *a, ITChatMessage *b) {
                if (a.offset < b.offset) return NSOrderedAscending;
                if (a.offset > b.offset) return NSOrderedDescending;
                return NSOrderedSame;
            }];
            if (completion) completion([salida copy], nil);
            return;
        }

        [self comentariosVod:videoID
                       desde:siguiente
                      vistos:vistos
                  acumulados:salida
                    paginas:paginas + 1
                  completion:completion];
    }];
}

#pragma mark - Cuenta

- (void)usuarioActual:(ITObjetoBloque)completion {
    NSString *q = @"query{ currentUser{ id login displayName profileImageURL(width:100)"
                  @" followers{ totalCount } } }";
    [self peticion:q variables:nil completion:^(NSDictionary *datos, NSError *error) {
        if (error) { if (completion) completion(nil, error); return; }
        ITChannel *c = [ITChannel conDiccionario:ITDic(datos[@"currentUser"])];
        if (completion) completion(c, c ? nil : ITError(@"Sesión no válida."));
    }];
}

- (void)seguidos:(ITListaBloque)completion {
    NSString *q = @"query{ currentUser{ follows(first:100){ edges{ node{"
                  @" id login displayName profileImageURL(width:70)"
                  @" followers{ totalCount }"
                  @" stream{ id title viewersCount game{ displayName } }"
                  @" } } } } }";
    [self peticion:q variables:nil completion:^(NSDictionary *datos, NSError *error) {
        if (error) { if (completion) completion(nil, error); return; }
        NSMutableArray *salida = [NSMutableArray array];
        NSDictionary *user = ITDic(datos[@"currentUser"]);
        for (id e in ITArr(ITDic(user[@"follows"])[@"edges"])) {
            ITChannel *c = [ITChannel conDiccionario:ITDic(ITDic(e)[@"node"])];
            if (c) [salida addObject:c];
        }
        if (completion) completion(salida, nil);
    }];
}

- (void)estadosDeCanales:(NSArray *)logins completion:(ITListaBloque)completion {
    NSArray *limpios = logins ?: @[];
    if (limpios.count == 0) {
        if (completion) completion(@[], nil);
        return;
    }

    NSMutableArray *partes = [NSMutableArray array];
    NSUInteger limite = MIN(limpios.count, 20);
    for (NSUInteger i = 0; i < limite; i++) {
        NSString *login = ITEscapar(ITStr(limpios[i]) ?: @"");
        [partes addObject:[NSString stringWithFormat:
            @"u%lu: user(login:\"%@\"){ id login displayName profileImageURL(width:70)"
             @" followers{ totalCount } stream{ id title viewersCount game{ displayName } } }",
            (unsigned long)i, login]];
    }
    NSString *q = [NSString stringWithFormat:@"query{ %@ }", [partes componentsJoinedByString:@" "]];

    [self peticion:q variables:nil completion:^(NSDictionary *datos, NSError *error) {
        if (error) { if (completion) completion(nil, error); return; }
        NSMutableArray *salida = [NSMutableArray array];
        for (NSUInteger i = 0; i < limite; i++) {
            NSString *clave = [NSString stringWithFormat:@"u%lu", (unsigned long)i];
            ITChannel *c = [ITChannel conDiccionario:ITDic(datos[clave])];
            if (c) [salida addObject:c];
        }
        if (completion) completion(salida, nil);
    }];
}

@end
