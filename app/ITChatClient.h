// ITChatClient.h -- IRC de Twitch por TCP/TLS (iOS 9 no tiene WebSocket).
#import <Foundation/Foundation.h>
#import "ITModels.h"

@protocol ITChatClientDelegado <NSObject>
- (void)chatConectado;
- (void)chatRecibioMensaje:(ITChatMessage *)mensaje;
- (void)chatAviso:(NSString *)texto;
- (void)chatFallo:(NSError *)error;
@end

@interface ITChatClient : NSObject
@property (nonatomic, weak) id<ITChatClientDelegado> delegado;
@property (nonatomic, readonly) BOOL conectado;
- (void)conectarCanal:(NSString *)canal;
- (void)desconectar;
- (void)enviarMensaje:(NSString *)texto;
@end
