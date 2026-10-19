#import "ITMiniPlayer.h"
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <math.h>
#import "ITTheme.h"
#import "ITUtil.h"
#import "ITPlayback.h"
#import "ITPlayerViewController.h"

static ITMiniPlayer *gMini = nil;

@interface ITMiniPlayer () <UIGestureRecognizerDelegate>
@end

@implementation ITMiniPlayer {
    UIView *_caja;
    AVPlayer *_player;
    AVPlayerItem *_item;
    AVPlayerLayer *_capa;
    id _observadorEstado;
    UIActivityIndicatorView *_rueda;
    UILabel *_titulo;
    UIButton *_cerrar;
    BOOL _arrastrado;
    BOOL _abriendo;
    BOOL _observaRotacion;

    ITStream *_stream;
    ITVideo *_video;
    ITClip *_clip;
    double _posicion;
}

+ (instancetype)compartida {
    static dispatch_once_t una;
    dispatch_once(&una, ^{ gMini = [[ITMiniPlayer alloc] init]; });
    return gMini;
}

- (BOOL)visible {
    return _caja && _caja.superview && !_caja.hidden;
}

#pragma mark - API

- (void)mostrarStream:(ITStream *)stream {
    if (!stream.login.length) return;
    [self prepararCajaConTitulo:stream.nombre ?: stream.login];
    _stream = stream;
    _video = nil;
    _clip = nil;
    _posicion = 0;
    [self cargarStream];
}

- (void)mostrarVideo:(ITVideo *)video posicion:(double)posicion {
    if (!video.identificador.length) return;
    [self prepararCajaConTitulo:video.titulo ?: @"Vídeo"];
    _stream = nil;
    _video = video;
    _clip = nil;
    _posicion = posicion;
    [self cargarVideo];
}

- (void)mostrarClip:(ITClip *)clip {
    if (!clip) return;
    [self prepararCajaConTitulo:clip.titulo ?: @"Clip"];
    _stream = nil;
    _video = nil;
    _clip = clip;
    _posicion = 0;
    [self cargarClip];
}

- (void)adoptarPlayer:(AVPlayer *)player
               stream:(ITStream *)stream
                video:(ITVideo *)video
                 clip:(ITClip *)clip
             posicion:(double)posicion {
    if (!player) return;
    NSString *titulo = stream.nombre ?: stream.login;
    if (video) titulo = video.titulo ?: @"Vídeo";
    if (clip) titulo = clip.titulo ?: @"Clip";
    [self prepararCajaConTitulo:titulo ?: @"iTwitch"];

    if (_player && _player != player) [_player pause];
    [self quitarObservador];
    _stream = stream;
    _video = video;
    _clip = clip;
    _posicion = posicion;
    _player = player;
    _item = player.currentItem;
    _capa.player = player;
    _rueda.hidden = YES;
    [_rueda stopAnimating];
    [self prepararMandos];
    [self actualizarAhoraSuena];
    [_player play];
}

- (void)cerrar {
    [self parar];
    [_caja removeFromSuperview];
    _caja.hidden = YES;
}

#pragma mark - Carga

- (void)cargarStream {
    __typeof(self) debil = self;
    [ITPlayback urlDirecto:_stream.login completion:^(NSString *url, NSError *error) {
        if (error || url.length == 0) { [debil fallo]; return; }
        [ITPlayback variantesDeMaster:url completion:^(NSArray *variantes, NSError *error2) {
            NSString *destino = url;
            NSDictionary *baja = [debil varianteBajaDe:variantes];
            if (baja[@"url"]) destino = [baja[@"url"] absoluteString];
            [debil reproducirURL:destino];
        }];
    }];
}

- (void)cargarVideo {
    __typeof(self) debil = self;
    [ITPlayback urlVod:_video.identificador completion:^(NSString *url, NSError *error) {
        if (error || url.length == 0) { [debil fallo]; return; }
        [ITPlayback variantesDeMaster:url completion:^(NSArray *variantes, NSError *error2) {
            NSString *destino = url;
            NSDictionary *baja = [debil varianteBajaDe:variantes];
            if (baja[@"url"]) destino = [baja[@"url"] absoluteString];
            [debil reproducirURL:destino];
        }];
    }];
}

- (void)cargarClip {
    if (_clip.calidades.count == 0) { [self fallo]; return; }
    NSDictionary *elegida = nil;
    for (NSDictionary *c in _clip.calidades) {
        NSInteger alto = [c[@"alto"] integerValue];
        if (alto > 0 && alto <= 480 && (!elegida || alto > [elegida[@"alto"] integerValue])) elegida = c;
    }
    if (!elegida) elegida = _clip.calidades.firstObject;
    [self reproducirURL:elegida[@"url"]];
}

- (NSDictionary *)varianteBajaDe:(NSArray *)variantes {
    NSDictionary *mejor = nil;
    for (NSDictionary *v in variantes) {
        NSInteger alto = [v[@"alto"] integerValue];
        if (alto <= 0 || alto > 480) continue;
        if (!mejor || alto > [mejor[@"alto"] integerValue]) mejor = v;
    }
    if (!mejor) {
        for (NSDictionary *v in variantes) {
            NSInteger alto = [v[@"alto"] integerValue];
            if (!mejor || alto < [mejor[@"alto"] integerValue]) mejor = v;
        }
    }
    return mejor;
}

- (void)reproducirURL:(NSString *)urlString {
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) { [self fallo]; return; }

    [self quitarObservador];
    _item = [AVPlayerItem playerItemWithURL:url];
    [_item addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
    _observadorEstado = @YES;

    if (!_player) {
        _player = [[AVPlayer alloc] initWithPlayerItem:_item];
        _capa.player = _player;
    } else {
        [_player replaceCurrentItemWithPlayerItem:_item];
    }
    [self prepararMandos];
    [self actualizarAhoraSuena];
    [_rueda startAnimating];
    _rueda.hidden = NO;
}

- (void)fallo {
    [_rueda stopAnimating];
    _titulo.text = @"No se puede reproducir";
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                        change:(NSDictionary *)change context:(void *)context {
    if (![keyPath isEqualToString:@"status"] || object != _item) return;
    if (_item.status == AVPlayerItemStatusReadyToPlay) {
        [_rueda stopAnimating];
        _rueda.hidden = YES;
        if (_video && _posicion > 0) {
            [_player seekToTime:CMTimeMakeWithSeconds(_posicion, 600)
              toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
        }
        [_player play];
    } else if (_item.status == AVPlayerItemStatusFailed) {
        [self fallo];
    }
}

- (void)quitarObservador {
    if (_observadorEstado && _item) {
        [_item removeObserver:self forKeyPath:@"status"];
    }
    _observadorEstado = nil;
}

- (void)parar {
    [_player pause];
    [self quitarObservador];
    [self quitarMandos];
    [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
}

#pragma mark - Mandos y ahora suena

- (void)prepararMandos {
    MPRemoteCommandCenter *centro = [MPRemoteCommandCenter sharedCommandCenter];
    [centro.playCommand removeTarget:self];
    [centro.pauseCommand removeTarget:self];
    [centro.togglePlayPauseCommand removeTarget:self];
    [centro.playCommand addTarget:self action:@selector(mandoPlay:)];
    [centro.pauseCommand addTarget:self action:@selector(mandoPausa:)];
    [centro.togglePlayPauseCommand addTarget:self action:@selector(mandoAlternar:)];
}

- (void)quitarMandos {
    MPRemoteCommandCenter *centro = [MPRemoteCommandCenter sharedCommandCenter];
    [centro.playCommand removeTarget:self];
    [centro.pauseCommand removeTarget:self];
    [centro.togglePlayPauseCommand removeTarget:self];
}

- (MPRemoteCommandHandlerStatus)mandoPlay:(MPRemoteCommandEvent *)evento {
    dispatch_async(dispatch_get_main_queue(), ^{ [self->_player play]; });
    return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus)mandoPausa:(MPRemoteCommandEvent *)evento {
    dispatch_async(dispatch_get_main_queue(), ^{ [self->_player pause]; });
    return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus)mandoAlternar:(MPRemoteCommandEvent *)evento {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self->_player.rate > 0) [self->_player pause];
        else [self->_player play];
    });
    return MPRemoteCommandHandlerStatusSuccess;
}

- (void)actualizarAhoraSuena {
    NSString *titulo = _titulo.text ?: @"iTwitch";
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    info[MPMediaItemPropertyTitle] = titulo;
    info[MPMediaItemPropertyArtist] = _stream.nombre ?: (_video.login ?: @"Twitch");
    info[MPNowPlayingInfoPropertyPlaybackRate] = @(_player.rate);
    [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = info;
}

#pragma mark - Interfaz

- (void)prepararCajaConTitulo:(NSString *)texto {
    UIWindow *ventana = [UIApplication sharedApplication].keyWindow;
    if (!ventana) return;

    if (!_observaRotacion) {
        _observaRotacion = YES;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(rotacion)
                                                     name:UIApplicationDidChangeStatusBarOrientationNotification
                                                   object:nil];
    }

    if (!_caja) {
        _caja = [[UIView alloc] init];
        _caja.backgroundColor = [UIColor blackColor];
        _caja.clipsToBounds = YES;
        _caja.layer.cornerRadius = 7.0;
        _caja.layer.borderWidth = 1.0;
        _caja.layer.borderColor = [ITTheme borde].CGColor;

        _capa = [AVPlayerLayer playerLayerWithPlayer:nil];
        _capa.videoGravity = AVLayerVideoGravityResizeAspect;
        [_caja.layer addSublayer:_capa];

        _rueda = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        [_caja addSubview:_rueda];

        _titulo = ITLabel(@"", [UIFont systemFontOfSize:10.0 weight:UIFontWeightSemibold],
                          [UIColor whiteColor]);
        _titulo.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.58];
        _titulo.textAlignment = NSTextAlignmentLeft;
        [_caja addSubview:_titulo];

        _cerrar = ITBotonIcono(@"cerrar", 11, [UIColor whiteColor]);
        _cerrar.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.58];
        _cerrar.layer.cornerRadius = 11.0;
        [_cerrar addTarget:self action:@selector(cerrar) forControlEvents:UIControlEventTouchUpInside];
        [_caja addSubview:_cerrar];

        UITapGestureRecognizer *toque = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(abrirCompleto)];
        toque.delegate = self;
        [_caja addGestureRecognizer:toque];

        UIPanGestureRecognizer *arrastre = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(mover:)];
        arrastre.delegate = self;
        [_caja addGestureRecognizer:arrastre];
    }

    _titulo.text = texto;
    _caja.hidden = NO;
    if (_caja.superview != ventana) [ventana addSubview:_caja];
    [ventana bringSubviewToFront:_caja];
    if (!_arrastrado) [self colocarAbajoDerecha];
    [self colocarPiezas];
}

- (void)colocarPiezas {
    CGRect b = _caja.bounds;
    _capa.frame = b;
    _rueda.center = CGPointMake(b.size.width / 2, b.size.height / 2);
    _titulo.frame = CGRectMake(0, b.size.height - 20, b.size.width, 20);
    _cerrar.frame = CGRectMake(b.size.width - 26, 4, 22, 22);
}

- (void)colocarAbajoDerecha {
    UIWindow *ventana = [UIApplication sharedApplication].keyWindow;
    if (!ventana) return;
    BOOL iPad = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad;
    CGFloat ancho = iPad ? 224.0 : 168.0;
    CGFloat alto = ancho * 9.0 / 16.0;
    CGFloat margen = 12.0;
    _caja.frame = CGRectMake(ventana.bounds.size.width - ancho - margen,
                             ventana.bounds.size.height - alto - margen - 49.0,
                             ancho, alto);
    [self colocarPiezas];
}

- (void)mover:(UIPanGestureRecognizer *)gesto {
    UIWindow *ventana = [UIApplication sharedApplication].keyWindow;
    if (!ventana) return;
    _arrastrado = YES;
    CGPoint p = [gesto locationInView:ventana];
    _caja.center = p;
    if (gesto.state == UIGestureRecognizerStateEnded ||
        gesto.state == UIGestureRecognizerStateCancelled) {
        CGRect b = ventana.bounds;
        CGRect f = _caja.frame;
        f.origin.x = MAX(8.0, MIN(b.size.width - f.size.width - 8.0, f.origin.x));
        f.origin.y = MAX(24.0, MIN(b.size.height - f.size.height - 8.0, f.origin.y));
        _caja.frame = f;
    }
}

- (void)abrirCompleto {
    if (_abriendo) return;
    _abriendo = YES;

    ITPlayerViewController *vc = nil;
    if (_stream) vc = [[ITPlayerViewController alloc] initWithStream:_stream];
    else if (_video) {
        vc = [[ITPlayerViewController alloc] initWithVideo:_video];
        double actual = CMTimeGetSeconds(_player.currentTime);
        vc.posicionInicial = (isfinite(actual) && actual > 0) ? actual : _posicion;
    } else if (_clip) vc = [[ITPlayerViewController alloc] initWithClip:_clip];
    if (!vc) { _abriendo = NO; return; }

    UIViewController *raiz = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (raiz.presentedViewController) raiz = raiz.presentedViewController;
    if ([raiz isKindOfClass:[UITabBarController class]]) {
        raiz = [(UITabBarController *)raiz selectedViewController];
    }
    UINavigationController *nav = raiz.navigationController;
    if (!nav && [raiz isKindOfClass:[UINavigationController class]]) nav = (UINavigationController *)raiz;

    [self pausarYocultar];
    if (nav) {
        [nav pushViewController:vc animated:YES];
    } else {
        UINavigationController *nuevo = [[UINavigationController alloc] initWithRootViewController:vc];
        [raiz presentViewController:nuevo animated:YES completion:nil];
    }
    _abriendo = NO;
}

- (void)pausarYocultar {
    [_player pause];
    _caja.hidden = YES;
}

- (void)rotacion {
    if (![self visible]) return;
    if (!_arrastrado) {
        [self colocarAbajoDerecha];
        return;
    }
    UIWindow *ventana = [UIApplication sharedApplication].keyWindow;
    if (!ventana) return;
    CGRect f = _caja.frame;
    f.origin.x = MAX(8.0, MIN(ventana.bounds.size.width - f.size.width - 8.0, f.origin.x));
    f.origin.y = MAX(24.0, MIN(ventana.bounds.size.height - f.size.height - 8.0, f.origin.y));
    _caja.frame = f;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesto shouldReceiveTouch:(UITouch *)toque {
    if (gesto.view == _caja && [toque.view isDescendantOfView:_cerrar]) return NO;
    return YES;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self parar];
}

@end
