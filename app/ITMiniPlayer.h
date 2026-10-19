#import <UIKit/UIKit.h>
#import "ITModels.h"

// Reproductor flotante que sigue sonando mientras se navega por la app.
// Es un singleton porque solo puede haber un mini reproductor a la vez.
@interface ITMiniPlayer : NSObject

+ (instancetype)compartida;

- (void)mostrarStream:(ITStream *)stream;
- (void)mostrarVideo:(ITVideo *)video posicion:(double)posicion;
- (void)mostrarClip:(ITClip *)clip;
- (void)cerrar;

@property (nonatomic, readonly) BOOL visible;

@end
