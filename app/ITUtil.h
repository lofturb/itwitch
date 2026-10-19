// ITUtil.h -- funciones sueltas que se usan en toda la app.
#import <UIKit/UIKit.h>

#pragma mark - Lectura segura de JSON

NSString *ITStr(id valor);
double ITNum(id valor);
NSInteger ITInt(id valor);
long long ITLargo(id valor);
BOOL ITBool(id valor);
NSArray *ITArr(id valor);
NSDictionary *ITDic(id valor);

#pragma mark - Formato

// "2026-10-17T17:00:00Z" -> "17 oct 2026"
NSString *ITFechaCorta(NSString *iso);
// "Hace 2 h", "Hace 3 d", "Ahora"
NSString *ITHace(NSString *iso);
// 3725 -> "1:02:05"
NSString *ITDuracion(double segundos);
// 25921 -> "25,9 mil"
NSString *ITNumeroCorto(long long numero);
// 12642377 -> "12,6 M"
NSString *ITMillones(long long numero);

#pragma mark - Twitch

// Reajusta una URL de imagen de Twitch al tamano pedido.
NSString *ITImagen(NSString *url, int ancho, int alto);
// "#9146FF" -> UIColor; si no hay color, uno estable a partir del nombre.
UIColor *ITColorDeChat(NSString *hex, NSString *nombre);

#pragma mark - UI

UILabel *ITLabel(NSString *texto, UIFont *fuente, UIColor *color);
UIButton *ITBotonIcono(NSString *forma, CGFloat lado, UIColor *color);
UIView *ITCaja(CGFloat alto);
void ITRedondear(UIView *vista, CGFloat radio);

@interface ITUtil : NSObject
@end
