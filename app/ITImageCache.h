// ITImageCache.h -- carga de miniaturas con cache en memoria y disco.
#import <UIKit/UIKit.h>

@interface ITImageCache : NSObject

// Carga la URL en la vista. Si la celda se reutiliza, la carga anterior se
// cancela sola (se guarda la URL actual en la propia vista).
+ (void)cargarURL:(NSString *)url en:(UIImageView *)vista;
+ (void)cargarURL:(NSString *)url completion:(void (^)(UIImage *imagen))completion;
// Solo memoria: para calcular alturas sin tocar el disco ni la red.
+ (UIImage *)imagenEnMemoria:(NSString *)url;
+ (void)cancelarPara:(UIImageView *)vista;
+ (void)limpiarMemoria;

@end
