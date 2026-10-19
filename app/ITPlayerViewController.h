#import <UIKit/UIKit.h>
#import "ITModels.h"

@interface ITPlayerViewController : UIViewController
@property (nonatomic) double posicionInicial;   // segundos; 0 = usar el progreso guardado
- (instancetype)initWithStream:(ITStream *)stream;
- (instancetype)initWithVideo:(ITVideo *)video;
- (instancetype)initWithClip:(ITClip *)clip;
@end
