// ITSession.h -- guarda el auth-token en el llavero (Keychain).
#import <Foundation/Foundation.h>

@interface ITSession : NSObject

+ (instancetype)compartida;

@property (nonatomic, copy) NSString *token;      // nil si no hay sesion
@property (nonatomic, copy) NSDictionary *usuario;

- (BOOL)haySesion;
- (void)guardarToken:(NSString *)token;
- (void)cerrarSesion;

@end
