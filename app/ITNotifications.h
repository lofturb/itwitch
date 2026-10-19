#import <UIKit/UIKit.h>
#import "ITModels.h"

// Avisos locales de directos de canales seguidos.
//
// No hay push real: iOS 9 no permite recibir notificaciones de Twitch sin un
// servidor APNs propio.  Esta clase consulta la lista de seguidos mientras la
// app esta viva (o reproduce audio en segundo plano) y programa avisos locales
// cuando detecta un canal que antes estaba desconectado.
@interface ITNotifications : NSObject

+ (instancetype)compartida;

+ (BOOL)avisosActivos;
+ (void)establecerAvisosActivos:(BOOL)activos;

- (void)comenzar;
- (void)detener;
- (void)comprobar;

// Canales que se han puesto en directo desde la ultima comprobacion.
- (NSArray *)nuevos;
- (void)limpiarNuevos;

// Llamado desde AppDelegate cuando iOS responde al permiso.
- (void)permisoCambiado:(UIUserNotificationSettings *)ajustes;

@end
