#import "ITModels.h"
#import "ITUtil.h"

#pragma mark - ITStream

@implementation ITStream
+ (instancetype)conDiccionario:(NSDictionary *)d {
    if (![d isKindOfClass:[NSDictionary class]]) return nil;
    ITStream *s = [[ITStream alloc] init];
    s.identificador = ITStr(d[@"id"]) ?: @"";
    s.titulo = ITStr(d[@"title"]) ?: @"";
    s.viewers = ITLargo(d[@"viewersCount"]);
    s.miniatura = ITStr(d[@"previewImageURL"]) ?: @"";
    s.iniciadoEn = ITStr(d[@"createdAt"]) ?: @"";
    s.enDirecto = YES;

    NSDictionary *juego = ITDic(d[@"game"]);
    s.juego = ITStr(juego[@"displayName"]) ?: ITStr(juego[@"name"]) ?: @"";

    NSDictionary *canal = ITDic(d[@"broadcaster"]);
    if (canal.count == 0) canal = ITDic(d[@"channel"]);
    s.login = ITStr(canal[@"login"]) ?: @"";
    s.nombre = ITStr(canal[@"displayName"]) ?: s.login;
    s.avatar = ITStr(canal[@"profileImageURL"]) ?: @"";
    return s;
}
@end

#pragma mark - ITGame

@implementation ITGame
+ (instancetype)conDiccionario:(NSDictionary *)d {
    if (![d isKindOfClass:[NSDictionary class]]) return nil;
    ITGame *g = [[ITGame alloc] init];
    g.identificador = ITStr(d[@"id"]) ?: @"";
    g.nombre = ITStr(d[@"name"]) ?: @"";
    g.mostrado = ITStr(d[@"displayName"]) ?: g.nombre;
    g.viewers = ITLargo(d[@"viewersCount"]);
    g.portada = ITStr(d[@"boxArtURL"]) ?: @"";
    return g;
}
@end

#pragma mark - ITVideo

@implementation ITVideo
+ (instancetype)conDiccionario:(NSDictionary *)d {
    if (![d isKindOfClass:[NSDictionary class]]) return nil;
    ITVideo *v = [[ITVideo alloc] init];
    v.identificador = ITStr(d[@"id"]) ?: @"";
    v.titulo = ITStr(d[@"title"]) ?: @"";
    v.duracion = ITNum(d[@"lengthSeconds"]);
    v.vistas = ITLargo(d[@"viewCount"]);
    v.creado = ITStr(d[@"createdAt"]) ?: @"";
    v.miniatura = ITStr(d[@"previewThumbnailURL"]) ?: @"";
    v.tipo = ITStr(d[@"broadcastType"]) ?: @"";
    v.login = ITStr(ITDic(d[@"owner"])[@"login"]) ?: @"";
    v.curador = ITStr(d[@"description"]) ?: @"";
    return v;
}
@end

#pragma mark - ITClip

@implementation ITClip
+ (instancetype)conDiccionario:(NSDictionary *)d {
    if (![d isKindOfClass:[NSDictionary class]]) return nil;
    ITClip *c = [[ITClip alloc] init];
    c.identificador = ITStr(d[@"id"]) ?: @"";
    c.slug = ITStr(d[@"slug"]) ?: @"";
    c.titulo = ITStr(d[@"title"]) ?: @"";
    c.duracion = ITNum(d[@"durationSeconds"]);
    c.vistas = ITLargo(d[@"viewCount"]);
    c.creado = ITStr(d[@"createdAt"]) ?: @"";
    c.miniatura = ITStr(d[@"thumbnailURL"]) ?: @"";
    c.curador = ITStr(ITDic(d[@"curator"])[@"displayName"]) ?: @"";

    NSMutableArray *calidades = [NSMutableArray array];
    for (id bruto in ITArr(d[@"videoQualities"])) {
        NSDictionary *q = ITDic(bruto);
        NSString *url = ITStr(q[@"sourceURL"]);
        if (url.length == 0) continue;
        NSString *calidad = ITStr(q[@"quality"]) ?: @"";
        NSInteger alto = 0;
        NSRange p = [calidad rangeOfString:@"p"];
        if (p.location != NSNotFound) {
            alto = [[calidad substringToIndex:p.location] integerValue];
        }
        [calidades addObject:@{ @"url" : url,
                                @"calidad" : calidad,
                                @"alto" : @(alto) }];
    }
    c.calidades = calidades;
    return c;
}
@end

#pragma mark - ITSegmento

@implementation ITSegmento
+ (instancetype)conDiccionario:(NSDictionary *)d {
    if (![d isKindOfClass:[NSDictionary class]]) return nil;
    ITSegmento *s = [[ITSegmento alloc] init];
    s.identificador = ITStr(d[@"id"]) ?: @"";
    s.inicio = ITStr(d[@"startAt"]) ?: @"";
    s.fin = ITStr(d[@"endAt"]) ?: @"";
    s.titulo = ITStr(d[@"title"]) ?: @"";
    NSMutableArray *cats = [NSMutableArray array];
    for (id c in ITArr(d[@"categories"])) {
        NSString *nombre = ITStr(ITDic(c)[@"name"]);
        if (nombre) [cats addObject:nombre];
    }
    s.categorias = cats;
    return s;
}
@end

#pragma mark - ITPanel

@implementation ITPanel
+ (instancetype)conDiccionario:(NSDictionary *)d {
    if (![d isKindOfClass:[NSDictionary class]]) return nil;
    ITPanel *p = [[ITPanel alloc] init];
    p.identificador = ITStr(d[@"id"]) ?: @"";
    p.titulo = ITStr(d[@"title"]) ?: @"";
    p.descripcion = ITStr(d[@"description"]) ?: @"";
    p.imagen = ITStr(d[@"imageURL"]) ?: @"";
    p.enlace = ITStr(d[@"linkURL"]) ?: @"";
    p.esExtension = [ITStr(d[@"__typename"]) isEqualToString:@"ExtensionPanel"];
    return p;
}
@end

#pragma mark - ITCollection

@implementation ITCollection
+ (instancetype)conDiccionario:(NSDictionary *)d {
    if (![d isKindOfClass:[NSDictionary class]]) return nil;
    ITCollection *c = [[ITCollection alloc] init];
    c.identificador = ITStr(d[@"id"]) ?: @"";
    c.titulo = ITStr(d[@"title"]) ?: @"";
    c.descripcion = ITStr(d[@"description"]) ?: @"";
    c.actualizada = ITStr(d[@"updatedAt"]) ?: @"";

    NSMutableArray *videos = [NSMutableArray array];
    NSArray *items = ITArr(ITDic(d[@"items"])[@"edges"]);
    for (id e in items) {
        NSDictionary *nodo = ITDic(ITDic(e)[@"node"]);
        ITVideo *v = [ITVideo conDiccionario:nodo];
        if (v) [videos addObject:v];
    }
    c.videos = videos;
    return c;
}
@end

#pragma mark - ITChannel

@implementation ITChannel
+ (instancetype)conDiccionario:(NSDictionary *)d {
    if (![d isKindOfClass:[NSDictionary class]]) return nil;
    ITChannel *c = [[ITChannel alloc] init];
    c.identificador = ITStr(d[@"id"]) ?: @"";
    c.login = ITStr(d[@"login"]) ?: @"";
    c.nombre = ITStr(d[@"displayName"]) ?: c.login;
    c.descripcion = ITStr(d[@"description"]) ?: @"";
    c.creado = ITStr(d[@"createdAt"]) ?: @"";
    c.avatar = ITStr(d[@"profileImageURL"]) ?: @"";
    c.banner = ITStr(d[@"bannerImageURL"]) ?: @"";
    c.apagado = ITStr(d[@"offlineImageURL"]) ?: @"";
    c.seguidores = ITLargo(ITDic(d[@"followers"])[@"totalCount"]);

    NSDictionary *roles = ITDic(d[@"roles"]);
    c.partner = ITBool(roles[@"isPartner"]);
    c.afiliado = ITBool(roles[@"isAffiliate"]);

    NSDictionary *directo = ITDic(d[@"stream"]);
    if (directo.count > 0 && ITStr(directo[@"id"])) {
        c.enDirecto = YES;
        c.directoTitulo = ITStr(directo[@"title"]) ?: @"";
        c.directoJuego = ITStr(ITDic(directo[@"game"])[@"displayName"]) ?: @"";
        c.directoViewers = ITLargo(directo[@"viewersCount"]);
    }

    NSDictionary *canal = ITDic(d[@"channel"]);
    NSMutableArray *sociales = [NSMutableArray array];
    for (id s in ITArr(canal[@"socialMedias"])) {
        NSDictionary *sm = ITDic(s);
        NSString *nombre = ITStr(sm[@"name"]);
        NSString *url = ITStr(sm[@"url"]);
        if (nombre && url) [sociales addObject:@{ @"nombre" : nombre, @"url" : url }];
    }
    c.sociales = sociales;

    NSMutableArray *segmentos = [NSMutableArray array];
    NSDictionary *horario = ITDic(canal[@"schedule"]);
    for (id s in ITArr(horario[@"segments"])) {
        ITSegmento *seg = [ITSegmento conDiccionario:ITDic(s)];
        if (seg) [segmentos addObject:seg];
    }
    c.segmentos = segmentos;

    NSMutableArray *paneles = [NSMutableArray array];
    for (id p in ITArr(d[@"panels"])) {
        ITPanel *panel = [ITPanel conDiccionario:ITDic(p)];
        if (panel && panel.titulo.length + panel.descripcion.length + panel.imagen.length > 0) {
            [paneles addObject:panel];
        }
    }
    c.paneles = paneles;
    return c;
}
@end

#pragma mark - ITChatMessage

@implementation ITChatMessage
@end
