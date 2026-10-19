// ITModels.h -- modelos de datos de Twitch, ya normalizados.
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@interface ITStream : NSObject
@property (nonatomic, copy) NSString *identificador;
@property (nonatomic, copy) NSString *titulo;
@property (nonatomic, assign) long long viewers;
@property (nonatomic, copy) NSString *login;
@property (nonatomic, copy) NSString *nombre;
@property (nonatomic, copy) NSString *avatar;
@property (nonatomic, copy) NSString *juego;
@property (nonatomic, copy) NSString *miniatura;
@property (nonatomic, copy) NSString *iniciadoEn;
@property (nonatomic, assign) BOOL enDirecto;
+ (instancetype)conDiccionario:(NSDictionary *)d;
@end

@interface ITGame : NSObject
@property (nonatomic, copy) NSString *identificador;
@property (nonatomic, copy) NSString *nombre;
@property (nonatomic, copy) NSString *mostrado;
@property (nonatomic, assign) long long viewers;
@property (nonatomic, copy) NSString *portada;
+ (instancetype)conDiccionario:(NSDictionary *)d;
@end

@interface ITVideo : NSObject
@property (nonatomic, copy) NSString *identificador;
@property (nonatomic, copy) NSString *titulo;
@property (nonatomic, assign) double duracion;
@property (nonatomic, assign) long long vistas;
@property (nonatomic, copy) NSString *creado;
@property (nonatomic, copy) NSString *miniatura;
@property (nonatomic, copy) NSString *login;
@property (nonatomic, copy) NSString *tipo;
@property (nonatomic, copy) NSString *curador;
+ (instancetype)conDiccionario:(NSDictionary *)d;
@end

@interface ITClip : NSObject
@property (nonatomic, copy) NSString *identificador;
@property (nonatomic, copy) NSString *slug;
@property (nonatomic, copy) NSString *titulo;
@property (nonatomic, assign) double duracion;
@property (nonatomic, assign) long long vistas;
@property (nonatomic, copy) NSString *creado;
@property (nonatomic, copy) NSString *miniatura;
@property (nonatomic, copy) NSString *curador;
@property (nonatomic, strong) NSArray *calidades;   // NSDictionary {url, calidad}
+ (instancetype)conDiccionario:(NSDictionary *)d;
@end

@interface ITSegmento : NSObject
@property (nonatomic, copy) NSString *identificador;
@property (nonatomic, copy) NSString *inicio;
@property (nonatomic, copy) NSString *fin;
@property (nonatomic, copy) NSString *titulo;
@property (nonatomic, strong) NSArray *categorias;
+ (instancetype)conDiccionario:(NSDictionary *)d;
@end

@interface ITPanel : NSObject
@property (nonatomic, copy) NSString *identificador;
@property (nonatomic, copy) NSString *titulo;
@property (nonatomic, copy) NSString *descripcion;
@property (nonatomic, copy) NSString *imagen;
@property (nonatomic, copy) NSString *enlace;
@property (nonatomic, assign) BOOL esExtension;
+ (instancetype)conDiccionario:(NSDictionary *)d;
@end

@interface ITCollection : NSObject
@property (nonatomic, copy) NSString *identificador;
@property (nonatomic, copy) NSString *titulo;
@property (nonatomic, copy) NSString *descripcion;
@property (nonatomic, copy) NSString *actualizada;
@property (nonatomic, strong) NSArray *videos;
+ (instancetype)conDiccionario:(NSDictionary *)d;
@end

@interface ITChannel : NSObject
@property (nonatomic, copy) NSString *identificador;
@property (nonatomic, copy) NSString *login;
@property (nonatomic, copy) NSString *nombre;
@property (nonatomic, copy) NSString *descripcion;
@property (nonatomic, copy) NSString *creado;
@property (nonatomic, copy) NSString *avatar;
@property (nonatomic, copy) NSString *banner;
@property (nonatomic, copy) NSString *apagado;
@property (nonatomic, assign) long long seguidores;
@property (nonatomic, assign) BOOL partner;
@property (nonatomic, assign) BOOL afiliado;
@property (nonatomic, assign) BOOL enDirecto;
@property (nonatomic, copy) NSString *directoTitulo;
@property (nonatomic, copy) NSString *directoJuego;
@property (nonatomic, assign) long long directoViewers;
@property (nonatomic, strong) NSArray *sociales;
@property (nonatomic, strong) NSArray *segmentos;
@property (nonatomic, strong) NSArray *paneles;
+ (instancetype)conDiccionario:(NSDictionary *)d;
@end

@interface ITChatMessage : NSObject
@property (nonatomic, copy) NSString *identificador;
@property (nonatomic, assign) double offset;
@property (nonatomic, copy) NSString *nombre;
@property (nonatomic, copy) NSString *color;
@property (nonatomic, copy) NSString *texto;
@property (nonatomic, copy) NSString *logins;      // "mod,subscriber"
@property (nonatomic, strong) NSArray *emotes;     // pares id/rangos
@property (nonatomic, assign) BOOL esAccion;
@property (nonatomic, assign) BOOL esReplay;
@end
