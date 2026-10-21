// ITPlayback.h -- de un canal/VOD a una URL reproducible y sus calidades.
#import <Foundation/Foundation.h>

@interface ITPlayback : NSObject

// Devuelve la URL maestra de usher para un directo.
+ (void)urlDirecto:(NSString *)login completion:(void (^)(NSString *url, NSError *error))completion;
// Devuelve la URL maestra de usher para un VOD.
+ (void)urlVod:(NSString *)videoID completion:(void (^)(NSString *url, NSError *error))completion;
// Completa una URL de clip con la firma que exige CloudFront.
+ (NSString *)urlClip:(NSString *)base firma:(NSString *)firma token:(NSString *)token;

// Descarga el master y devuelve las variantes:
//   @[ @{@"nombre":@"720p", @"url":NSURL, @"ancho":@1280, @"alto":@720}, ... ]
+ (void)variantesDeMaster:(NSString *)url
               completion:(void (^)(NSArray *variantes, NSError *error))completion;

// La misma lectura pero sobre un texto ya descargado (lo usa el gestor de
// descargas para no pedir dos veces el master).
+ (NSArray *)variantesDeTexto:(NSString *)texto base:(NSURL *)base;

@end
