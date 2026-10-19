#import "ITImageCache.h"
#import <objc/runtime.h>

static const void *kITImagenURL = &kITImagenURL;
static const void *kITImagenTarea = &kITImagenTarea;

static NSCache *ITMemoria(void) {
    static NSCache *c = nil;
    static dispatch_once_t una;
    dispatch_once(&una, ^{
        c = [[NSCache alloc] init];
        c.countLimit = 160;
        c.totalCostLimit = 24 * 1024 * 1024;   // 24 MB: cabe en un A5
    });
    return c;
}

static NSString *ITRutaDisco(NSString *clave) {
    static NSString *carpeta = nil;
    static dispatch_once_t una;
    dispatch_once(&una, ^{
        NSArray *rutas = NSSearchPathForDirectoriesInDomains(NSCachesDirectory,
                                                             NSUserDomainMask, YES);
        carpeta = [rutas.firstObject stringByAppendingPathComponent:@"imagenes"];
        [[NSFileManager defaultManager] createDirectoryAtPath:carpeta
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:nil];
    });
    NSUInteger h = 5381;
    for (NSUInteger i = 0; i < clave.length; i++) {
        h = ((h << 5) + h) + [clave characterAtIndex:i];
    }
    return [carpeta stringByAppendingPathComponent:
            [NSString stringWithFormat:@"%08lx.img", (unsigned long)h]];
}

@implementation ITImageCache

+ (void)cargarURL:(NSString *)url en:(UIImageView *)vista {
    if (!vista) return;
    if (url.length == 0) {
        vista.image = nil;
        return;
    }

    objc_setAssociatedObject(vista, kITImagenURL, url, OBJC_ASSOCIATION_COPY_NONATOMIC);

    UIImage *memoria = [ITMemoria() objectForKey:url];
    if (memoria) {
        vista.image = memoria;
        return;
    }

    vista.image = nil;

    // Disco (rapido y sin red).
    UIImage *disco = [UIImage imageWithContentsOfFile:ITRutaDisco(url)];
    if (disco) {
        [ITMemoria() setObject:disco forKey:url cost:(NSUInteger)(disco.size.width * disco.size.height * 4)];
        vista.image = disco;
        return;
    }

    NSURL *destino = [NSURL URLWithString:url];
    if (!destino) return;

    NSMutableURLRequest *peticion = [NSMutableURLRequest requestWithURL:destino];
    peticion.timeoutInterval = 20.0;
    [peticion setValue:@"image/*" forHTTPHeaderField:@"Accept"];

    NSURLSessionDataTask *tarea =
        [[NSURLSession sharedSession] dataTaskWithRequest:peticion
                                       completionHandler:^(NSData *datos,
                                                           NSURLResponse *respuesta,
                                                           NSError *error) {
        if (!datos || error) return;
        UIImage *imagen = [UIImage imageWithData:datos];
        if (!imagen) return;
        [ITMemoria() setObject:imagen forKey:url
                          cost:(NSUInteger)(imagen.size.width * imagen.size.height * 4)];
        NSData *png = UIImagePNGRepresentation(imagen);
        if (png) [png writeToFile:ITRutaDisco(url) atomically:YES];

        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *actual = objc_getAssociatedObject(vista, kITImagenURL);
            if ([actual isEqualToString:url]) vista.image = imagen;
        });
    }];
    [tarea resume];

    NSURLSessionDataTask *vieja = objc_getAssociatedObject(vista, kITImagenTarea);
    if (vieja) [vieja cancel];
    objc_setAssociatedObject(vista, kITImagenTarea, tarea, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

+ (UIImage *)imagenEnMemoria:(NSString *)url {
    if (url.length == 0) return nil;
    return [ITMemoria() objectForKey:url];
}

+ (void)cargarURL:(NSString *)url completion:(void (^)(UIImage *))completion {
    if (url.length == 0) {
        if (completion) completion(nil);
        return;
    }
    UIImage *memoria = [ITMemoria() objectForKey:url];
    if (memoria) {
        if (completion) completion(memoria);
        return;
    }
    UIImage *disco = [UIImage imageWithContentsOfFile:ITRutaDisco(url)];
    if (disco) {
        [ITMemoria() setObject:disco forKey:url cost:(NSUInteger)(disco.size.width * disco.size.height * 4)];
        if (completion) completion(disco);
        return;
    }
    NSURL *destino = [NSURL URLWithString:url];
    if (!destino) {
        if (completion) completion(nil);
        return;
    }
    NSMutableURLRequest *peticion = [NSMutableURLRequest requestWithURL:destino];
    peticion.timeoutInterval = 20.0;
    NSURLSessionDataTask *tarea = [[NSURLSession sharedSession] dataTaskWithRequest:peticion
        completionHandler:^(NSData *datos, NSURLResponse *respuesta, NSError *error) {
        UIImage *imagen = datos ? [UIImage imageWithData:datos] : nil;
        if (imagen) {
            [ITMemoria() setObject:imagen forKey:url
                              cost:(NSUInteger)(imagen.size.width * imagen.size.height * 4)];
            NSData *png = UIImagePNGRepresentation(imagen);
            if (png) [png writeToFile:ITRutaDisco(url) atomically:YES];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(imagen);
        });
    }];
    [tarea resume];
}

+ (void)cancelarPara:(UIImageView *)vista {
    if (!vista) return;
    NSURLSessionDataTask *tarea = objc_getAssociatedObject(vista, kITImagenTarea);
    if (tarea) [tarea cancel];
    objc_setAssociatedObject(vista, kITImagenTarea, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(vista, kITImagenURL, nil, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

+ (void)limpiarMemoria {
    [ITMemoria() removeAllObjects];
}

@end
