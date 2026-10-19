#import <UIKit/UIKit.h>

@interface ITChatViewController : UIViewController

// Chat en directo por IRC. Si no hay sesion, entra como anonimo.
- (instancetype)initWithCanal:(NSString *)canal;

// Chat replay de un VOD. Los mensajes se insertan al llamar a actualizarTiempo:.
- (instancetype)initWithVideo:(NSString *)videoID duracion:(double)duracion;

- (void)actualizarTiempo:(double)segundos;
- (void)detener;

@end
