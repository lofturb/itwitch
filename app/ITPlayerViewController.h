#import <UIKit/UIKit.h>
#import "ITModels.h"

@interface ITPlayerViewController : UIViewController
- (instancetype)initWithStream:(ITStream *)stream;
- (instancetype)initWithVideo:(ITVideo *)video;
- (instancetype)initWithClip:(ITClip *)clip;
@end
