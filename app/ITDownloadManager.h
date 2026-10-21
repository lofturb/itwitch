// ITDownloadManager.h -- descarga de VODs de Twitch a una carpeta del dispositivo.
#import <Foundation/Foundation.h>
#import "ITModels.h"

// Se lanza en el hilo principal cada vez que cambia la lista o el progreso.
extern NSString * const ITDescargasCambiaron;

typedef NS_ENUM(NSInteger, ITDescargaEstado) {
    ITDescargaEnEspera = 0,
    ITDescargaActiva,
    ITDescargaCompletada,
    ITDescargaFallida,
    ITDescargaCancelada
};

@interface ITDescarga : NSObject
@property (nonatomic, copy) NSString *identificador;
@property (nonatomic, copy) NSString *titulo;
@property (nonatomic, copy) NSString *login;
@property (nonatomic, copy) NSString *miniatura;
@property (nonatomic, copy) NSString *calidad;
@property (nonatomic, copy) NSString *carpeta;
@property (nonatomic, copy) NSString *archivo;      // ruta final cuando termina
@property (nonatomic, assign) double duracion;
@property (nonatomic, assign) NSUInteger segmentosTotales;
@property (nonatomic, assign) NSUInteger segmentosHechos;
@property (nonatomic, assign) long long bytesHechos;
@property (nonatomic, assign) long long bytesTotales;
@property (nonatomic, assign) ITDescargaEstado estado;
@property (nonatomic, copy) NSString *mensaje;
@property (nonatomic, readonly) double progreso;    // 0.0 .. 1.0
@property (nonatomic, readonly) NSString *estadoTexto;
@end

@interface ITDownloadManager : NSObject

+ (instancetype)compartida;

@property (nonatomic, readonly) NSArray *descargas;   // ITDescarga, mas recientes primero

// Carpeta de destino elegida por el usuario. Por defecto /var/mobile/Media/iTwitch.
+ (NSString *)carpetaDeDescargas;
+ (void)guardarCarpetaDeDescargas:(NSString *)ruta;
+ (BOOL)carpetaEscribible:(NSString *)ruta;
+ (NSString *)carpetaDeRespaldo;    // Documents/Descargas de la app

// Encola una descarga. Devuelve el objeto para poder seguirlo.
- (ITDescarga *)descargarVideo:(ITVideo *)video
                       calidad:(NSString *)calidad
                       carpeta:(NSString *)carpeta;

- (void)cancelar:(ITDescarga *)descarga;
- (void)reintentar:(ITDescarga *)descarga;
- (void)eliminar:(ITDescarga *)descarga;   // borra el archivo y la entrada

@end
