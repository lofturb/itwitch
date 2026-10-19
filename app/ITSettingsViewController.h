#import <UIKit/UIKit.h>

@interface ITSettingsViewController : UITableViewController

+ (NSString *)calidadMaxima;       // @"auto", @"1080", @"720", @"480", @"360"
+ (BOOL)chatActivo;
+ (BOOL)reanudarVod;

@end
