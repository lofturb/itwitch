#import <UIKit/UIKit.h>
#import "ITModels.h"

@interface ITPlayerViewController : UIViewController
@property (nonatomic) double posicionInicial;   // segundos; 0 = usar el progreso guardado
@property (nonatomic, strong) NSArray *listaVideos; // VODs de una coleccion, para reproducir en cadena
@property (nonatomic) NSUInteger indiceVideo;
- (instancetype)initWithStream:(ITStream *)stream;
- (instancetype)initWithVideo:(ITVideo *)video;
- (instancetype)initWithClip:(ITClip *)clip;
// Reproduce un archivo ya descargado (mp4, mov o ts) de la carpeta local.
- (instancetype)initWithArchivo:(NSString *)ruta titulo:(NSString *)titulo;
@end
