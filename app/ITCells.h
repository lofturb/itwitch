// ITCells.h -- celdas reutilizables. Todas se colocan a mano (mas rapido en A5).
#import <UIKit/UIKit.h>
#import "ITModels.h"

@interface ITStreamCell : UITableViewCell
- (void)configurarConStream:(ITStream *)stream;
@end

@interface ITStreamRowCell : UITableViewCell
- (void)configurarConStream:(ITStream *)stream;
@end

@interface ITGameCell : UITableViewCell
- (void)configurarConJuego:(ITGame *)juego;
@end

@interface ITVideoCell : UITableViewCell
- (void)configurarConVideo:(ITVideo *)video;
@end

@interface ITClipCell : UITableViewCell
- (void)configurarConClip:(ITClip *)clip;
@end

@interface ITCollectionCell : UITableViewCell
- (void)configurarConColeccion:(ITCollection *)coleccion;
@end

@interface ITChannelCell : UITableViewCell
- (void)configurarConCanal:(ITChannel *)canal;
@end

@interface ITTextCell : UITableViewCell
- (void)configurarTitulo:(NSString *)titulo detalle:(NSString *)detalle;
@end
