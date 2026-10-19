// ITApi.h -- todas las consultas a Twitch en un solo sitio.
#import <Foundation/Foundation.h>
#import "ITModels.h"

typedef void (^ITListaBloque)(NSArray *elementos, NSError *error);
typedef void (^ITObjetoBloque)(id objeto, NSError *error);
typedef void (^ITTokenBloque)(NSString *valor, NSString *firma, NSError *error);
typedef void (^ITTextoBloque)(NSString *texto, NSError *error);

@interface ITApi : NSObject

+ (instancetype)compartida;

// Inicio / explorar
- (void)directos:(NSInteger)cantidad completion:(ITListaBloque)completion;
- (void)categorias:(NSInteger)cantidad completion:(ITListaBloque)completion;
- (void)directosDelJuego:(NSString *)juego completion:(ITListaBloque)completion;

// Buscar
- (void)sugerencias:(NSString *)texto completion:(ITListaBloque)completion;
- (void)buscarCanales:(NSString *)texto completion:(ITListaBloque)completion;
- (void)buscarCategorias:(NSString *)texto completion:(ITListaBloque)completion;

// Canal
- (void)canal:(NSString *)login completion:(ITObjetoBloque)completion;
- (void)videosDe:(NSString *)login tipo:(NSString *)tipo orden:(NSString *)orden
      completion:(ITListaBloque)completion;
- (void)clipsDe:(NSString *)login periodo:(NSString *)periodo
     completion:(ITListaBloque)completion;
- (void)coleccionesDe:(NSString *)login completion:(ITListaBloque)completion;

// Reproduccion
- (void)tokenDirecto:(NSString *)login completion:(ITTokenBloque)completion;
- (void)tokenVod:(NSString *)videoID completion:(ITTokenBloque)completion;
- (void)clip:(NSString *)slug completion:(ITObjetoBloque)completion;
- (void)comentariosVod:(NSString *)videoID completion:(ITListaBloque)completion;

// Cuenta
- (void)usuarioActual:(ITObjetoBloque)completion;
- (void)seguidos:(ITListaBloque)completion;
- (void)estadosDeCanales:(NSArray *)logins completion:(ITListaBloque)completion;

@end
