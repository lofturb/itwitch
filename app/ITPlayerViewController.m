#import "ITPlayerViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <math.h>
#import "ITTheme.h"
#import "ITUtil.h"
#import "ITPlayback.h"
#import "ITImageCache.h"
#import "ITSettingsViewController.h"
#import "ITChatViewController.h"
#import "ITMiniPlayer.h"

@interface ITPlayerViewController () <UIGestureRecognizerDelegate>
@end

@implementation ITPlayerViewController {
    ITStream *_stream;
    ITVideo *_video;
    ITClip *_clip;
    BOOL _esDirecto;
    BOOL _esClip;
    BOOL _pantallaCompleta;
    BOOL _chatActivo;
    BOOL _controlesVisibles;
    BOOL _arrastrando;
    BOOL _bucle;
    BOOL _iniciado;
    BOOL _reanudado;
    BOOL _cedidoAMini;
    NSTimeInterval _ultimoGuardado;

    UIView *_vistaVideo;
    AVPlayer *_player;
    AVPlayerItem *_item;
    AVPlayerLayer *_capa;
    id _observadorTiempo;
    id _observadorEstado;
    NSTimeInterval _ultimoToque;

    UIView *_controles;
    UIView *_barraSuperior;
    UIView *_barraInferior;
    UIButton *_btnAtras;
    UIButton *_btnPlay;
    UIButton *_btnAtras10;
    UIButton *_btnAdelante10;
    UIButton *_btnCompartir;
    UIButton *_btnMas;
    UIButton *_btnCalidad;
    UIButton *_btnVelocidad;
    UIButton *_btnChat;
    UIButton *_btnPantalla;
    UIButton *_btnBucle;
    UIButton *_btnIrDirecto;
    UIButton *_btnReintentar;
    UISlider *_slider;
    UILabel *_lblTiempo;
    UILabel *_lblDuracion;
    UILabel *_lblTitulo;
    UILabel *_lblDirecto;
    UILabel *_lblError;
    UIActivityIndicatorView *_rueda;
    NSTimer *_timerOcultar;

    NSArray *_variantes;
    NSDictionary *_varianteActual;
    NSString *_urlMaster;
    double _duracion;
    double _tiempoAntesDeArrastrar;
    MPVolumeView *_volumen;
    MPVolumeView *_ruta;

    ITChatViewController *_chat;
    UIView *_cajaChat;
    BOOL _chatCargado;
}

#pragma mark - Init

- (instancetype)initWithStream:(ITStream *)stream {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _stream = stream;
        _esDirecto = YES;
    }
    return self;
}

- (instancetype)initWithVideo:(ITVideo *)video {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _video = video;
    }
    return self;
}

- (instancetype)initWithClip:(ITClip *)clip {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _clip = clip;
        _esClip = YES;
    }
    return self;
}

#pragma mark - Ciclo

- (BOOL)prefersStatusBarHidden { return YES; }
- (UIStatusBarStyle)preferredStatusBarStyle { return UIStatusBarStyleLightContent; }

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];

    _vistaVideo = [[UIView alloc] init];
    _vistaVideo.backgroundColor = [UIColor blackColor];
    [self.view addSubview:_vistaVideo];

    _capa = [AVPlayerLayer playerLayerWithPlayer:nil];
    _capa.videoGravity = AVLayerVideoGravityResizeAspect;
    [_vistaVideo.layer addSublayer:_capa];

    _rueda = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    [_vistaVideo addSubview:_rueda];

    _lblError = ITLabel(@"", [ITTheme fuenteCuerpo], [UIColor whiteColor]);
    _lblError.textAlignment = NSTextAlignmentCenter;
    _lblError.numberOfLines = 3;
    _lblError.hidden = YES;
    [_vistaVideo addSubview:_lblError];

    _btnReintentar = [UIButton buttonWithType:UIButtonTypeSystem];
    [_btnReintentar setTitle:@"Reintentar" forState:UIControlStateNormal];
    [_btnReintentar setTitleColor:[ITTheme textoSobreAcento] forState:UIControlStateNormal];
    _btnReintentar.backgroundColor = [ITTheme acento];
    _btnReintentar.titleLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    ITRedondear(_btnReintentar, 14.0);
    _btnReintentar.hidden = YES;
    [_btnReintentar addTarget:self action:@selector(reintentar) forControlEvents:UIControlEventTouchUpInside];
    [_vistaVideo addSubview:_btnReintentar];

    [self montarControles];
    [self prepararGestos];
    [self prepararAudio];

    _chatActivo = [ITSettingsViewController chatActivo] && !_esClip;
    if (_chatActivo) [self crearChat];
    [self cargar];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[ITMiniPlayer compartida] cerrar];
    self.navigationController.navigationBarHidden = YES;
    [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationFade];
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    self.navigationController.navigationBarHidden = NO;
    [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
    [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
    if (self.isMovingFromParentViewController || self.isBeingDismissed) {
        if (!_esDirecto && !_esClip) {
            [self guardarProgresoEn:CMTimeGetSeconds(_player.currentTime)];
        }
        [self minimizarSiProcede];
        [self parar];
    }
}

- (void)minimizarSiProcede {
    if (!_iniciado || _player.rate <= 0) return;
    ITMiniPlayer *mini = [ITMiniPlayer compartida];
    if (_stream) {
        [mini adoptarPlayer:_player stream:_stream video:nil clip:nil posicion:0];
    } else if (_video) {
        double posicion = CMTimeGetSeconds(_player.currentTime);
        [mini adoptarPlayer:_player stream:nil video:_video clip:nil
                   posicion:(isfinite(posicion) ? posicion : 0)];
    } else if (_clip) {
        [mini adoptarPlayer:_player stream:nil video:nil clip:_clip posicion:0];
    } else {
        return;
    }
    _cedidoAMini = YES;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat ancho = self.view.bounds.size.width;
    CGFloat alto = self.view.bounds.size.height;
    BOOL horizontal = ancho > alto;

    CGFloat altoVideo = (horizontal || _pantallaCompleta) ? alto : MIN(ancho * 9.0 / 16.0, alto * 0.64);
    _vistaVideo.frame = CGRectMake(0, 0, ancho, altoVideo);
    _capa.frame = _vistaVideo.bounds;

    _controles.frame = _vistaVideo.bounds;
    _barraSuperior.frame = CGRectMake(0, 0, ancho, 44);
    _barraInferior.frame = CGRectMake(0, altoVideo - 78, ancho, 78);

    _btnAtras.frame = CGRectMake(2, 2, 40, 40);
    _lblTitulo.frame = CGRectMake(46, 2, ancho - 178, 40);
    _ruta.frame = CGRectMake(ancho - 128, 2, 40, 40);
    _btnMas.frame = CGRectMake(ancho - 88, 2, 40, 40);
    _btnCompartir.frame = CGRectMake(ancho - 46, 2, 40, 40);

    _btnPlay.frame = CGRectMake((ancho - 56) / 2, (altoVideo - 56) / 2, 56, 56);
    _btnAtras10.frame = CGRectMake((ancho - 56) / 2 - 76, (altoVideo - 42) / 2, 50, 42);
    _btnAdelante10.frame = CGRectMake((ancho - 56) / 2 + 82, (altoVideo - 42) / 2, 50, 42);

    _slider.frame = CGRectMake(14, altoVideo - 56, ancho - 28, 22);
    _lblTiempo.frame = CGRectMake(14, altoVideo - 32, 60, 16);
    _lblDuracion.frame = CGRectMake(ancho - 74, altoVideo - 32, 60, 16);
    _lblDirecto.frame = CGRectMake(14, altoVideo - 32, 100, 16);
    _btnIrDirecto.frame = CGRectMake(ancho - 110, altoVideo - 34, 96, 20);

    _btnCalidad.frame = CGRectMake(76, altoVideo - 24, 46, 20);
    _btnVelocidad.frame = CGRectMake(124, altoVideo - 24, 36, 20);
    _btnBucle.frame = CGRectMake(162, altoVideo - 24, 30, 20);
    _btnChat.frame = CGRectMake(ancho - 96, altoVideo - 24, 30, 20);
    _btnPantalla.frame = CGRectMake(ancho - 42, altoVideo - 24, 34, 20);

    _rueda.center = CGPointMake(ancho / 2, altoVideo / 2);
    _lblError.frame = CGRectMake(20, altoVideo / 2 - 20, ancho - 40, 60);
    _btnReintentar.frame = CGRectMake((ancho - 120) / 2, altoVideo / 2 + 42, 120, 30);

    if (_chat) {
        BOOL visible = _chatActivo && !horizontal && !_pantallaCompleta;
        _chat.view.hidden = !visible;
        if (visible) {
            _chat.view.frame = CGRectMake(0, altoVideo, ancho, alto - altoVideo);
        }
    }
}

- (void)dealloc {
    if (_observadorTiempo) [_player removeTimeObserver:_observadorTiempo];
    if (_observadorEstado) [_item removeObserver:self forKeyPath:@"status"];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_timerOcultar invalidate];
}

#pragma mark - Carga

- (void)cargar {
    [self mostrarCargando:YES];
    _lblError.hidden = YES;
    _btnReintentar.hidden = YES;

    __typeof(self) debil = self;
    if (_esClip) {
        [self cargarClip];
        return;
    }
    if (_esDirecto) {
        [ITPlayback urlDirecto:_stream.login completion:^(NSString *url, NSError *error) {
            if (error || url.length == 0) {
                [debil mostrarError:error.localizedDescription ?: @"No se pudo abrir el directo."];
                return;
            }
            debil->_urlMaster = url;
            [debil cargarVariantesYReproducir:url];
        }];
    } else {
        [ITPlayback urlVod:_video.identificador completion:^(NSString *url, NSError *error) {
            if (error || url.length == 0) {
                [debil mostrarError:error.localizedDescription ?: @"No se pudo abrir el vídeo."];
                return;
            }
            debil->_urlMaster = url;
            [debil cargarVariantesYReproducir:url];
        }];
    }
}

- (void)cargarClip {
    if (_clip.calidades.count == 0) {
        [self mostrarError:@"Este clip no tiene una calidad reproducible."];
        return;
    }
    NSDictionary *elegida = [self mejorCalidadDe:_clip.calidades];
    NSString *url = elegida[@"url"] ?: [_clip.calidades.firstObject objectForKey:@"url"];
    [self prepararURL:url];
}

- (void)cargarVariantesYReproducir:(NSString *)url {
    __typeof(self) debil = self;
    [ITPlayback variantesDeMaster:url completion:^(NSArray *variantes, NSError *error) {
        debil->_variantes = variantes ?: @[];
        NSDictionary *elegida = [debil mejorCalidadDe:debil->_variantes];
        NSString *destino = url;
        if (elegida[@"url"]) destino = [elegida[@"url"] absoluteString];
        debil->_varianteActual = elegida;
        [debil prepararURL:destino];
    }];
}

- (NSDictionary *)mejorCalidadDe:(NSArray *)lista {
    if (lista.count == 0) return nil;
    NSString *tope = [ITSettingsViewController calidadMaxima];
    NSInteger limite = [tope isEqualToString:@"auto"] ? 720 : tope.integerValue;
    if ([tope isEqualToString:@"auto"]) limite = 720;

    NSDictionary *mejor = nil;
    for (NSDictionary *v in lista) {
        NSInteger alto = [v[@"alto"] integerValue];
        if (alto <= 0) continue;
        if (alto > limite) continue;
        if (!mejor || alto > [mejor[@"alto"] integerValue]) mejor = v;
    }
    if (!mejor) {
        for (NSDictionary *v in lista) {
            NSInteger alto = [v[@"alto"] integerValue];
            if (!mejor || alto > [mejor[@"alto"] integerValue]) mejor = v;
        }
    }
    return mejor;
}

- (void)prepararURL:(NSString *)urlString {
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        [self mostrarError:@"La URL del vídeo no es válida."];
        return;
    }
    if (_item && _observadorEstado) {
        [_item removeObserver:self forKeyPath:@"status"];
        _observadorEstado = nil;
    }

    _item = [AVPlayerItem playerItemWithURL:url];
    [_item addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
    _observadorEstado = @YES;

    if (!_player) {
        _player = [[AVPlayer alloc] initWithPlayerItem:_item];
        _capa.player = _player;
    } else {
        [_player replaceCurrentItemWithPlayerItem:_item];
    }

    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(finDeVideo:)
        name:AVPlayerItemDidPlayToEndTimeNotification object:_item];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemFailedToPlayToEndTimeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(falloDeVideo:)
        name:AVPlayerItemFailedToPlayToEndTimeNotification object:_item];

    if (_observadorTiempo) {
        [_player removeTimeObserver:_observadorTiempo];
        _observadorTiempo = nil;
    }
    __weak typeof(self) debil = self;
    _observadorTiempo = [_player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(0.5, 600)
        queue:dispatch_get_main_queue() usingBlock:^(CMTime tiempo) {
        __typeof(self) fuerte = debil;
        if (fuerte) [fuerte actualizarTiempo:tiempo];
    }];
}

- (void)mostrarCargando:(BOOL)cargando {
    if (cargando) {
        [_vistaVideo bringSubviewToFront:_rueda];
        [_rueda startAnimating];
    } else {
        [_rueda stopAnimating];
    }
}

- (void)mostrarError:(NSString *)texto {
    [self mostrarCargando:NO];
    _lblError.text = texto ?: @"Error de reproducción.";
    _lblError.hidden = NO;
    _btnReintentar.hidden = NO;
    [_vistaVideo bringSubviewToFront:_lblError];
    [_vistaVideo bringSubviewToFront:_btnReintentar];
    [_player pause];
}

- (void)reintentar {
    _lblError.hidden = YES;
    _btnReintentar.hidden = YES;
    [_player pause];
    if (_observadorTiempo) {
        [_player removeTimeObserver:_observadorTiempo];
        _observadorTiempo = nil;
    }
    if (_item && _observadorEstado) {
        [_item removeObserver:self forKeyPath:@"status"];
        _observadorEstado = nil;
    }
    _player = nil;
    _capa.player = nil;
    _item = nil;
    [self cargar];
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                        change:(NSDictionary *)change context:(void *)context {
    if (![keyPath isEqualToString:@"status"]) return;
    if (object != _item) return;
    if (_item.status == AVPlayerItemStatusReadyToPlay) {
        [self mostrarCargando:NO];
        _lblError.hidden = YES;
        _btnReintentar.hidden = YES;
        CMTime d = _item.duration;
        if (CMTIME_IS_VALID(d) && !CMTIME_IS_INDEFINITE(d)) {
            _duracion = CMTimeGetSeconds(d);
            _slider.maximumValue = _duracion;
            _lblDuracion.text = ITDuracion(_duracion);
        }
        [self actualizarBotonPlay];
        [self reanudarSiProcede];
        [self reproducir];
        [self actualizarAhoraSuena];
    } else if (_item.status == AVPlayerItemStatusFailed) {
        [self mostrarError:_item.error.localizedDescription ?: @"No se pudo reproducir."];
    }
}

#pragma mark - Reproduccion

- (void)reproducir {
    [_player play];
    _iniciado = YES;
    [self actualizarBotonPlay];
    [self programarOcultar];
}

- (void)pausar {
    [_player pause];
    [self actualizarBotonPlay];
    [self mostrarControles:YES];
    [_timerOcultar invalidate];
}

- (void)alternarReproduccion {
    if (_player.rate > 0) [self pausar];
    else [self reproducir];
}

- (void)actualizarBotonPlay {
    BOOL pausado = _player.rate == 0;
    [_btnPlay setImage:[ITTheme icono:(pausado ? @"reproducir" : @"pausa") lado:34]
              forState:UIControlStateNormal];
}

- (void)saltar:(double)segundos {
    if (_esDirecto) return;
    double actual = CMTimeGetSeconds(_player.currentTime);
    double destino = MAX(0, MIN(_duracion, actual + segundos));
    [_player seekToTime:CMTimeMakeWithSeconds(destino, 600)
      toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
}

- (void)finDeVideo:(NSNotification *)n {
    if (_esClip && _bucle) {
        [_player seekToTime:kCMTimeZero];
        [_player play];
        return;
    }
    if (!_esDirecto && !_esClip) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:[self claveProgreso]];
        [[NSUserDefaults standardUserDefaults] synchronize];
        if (_listaVideos.count > _indiceVideo + 1) {
            [self cargarSiguienteVideo];
            return;
        }
    }
    [self actualizarBotonPlay];
    [self mostrarControles:YES];
    [_timerOcultar invalidate];
}

- (void)cargarSiguienteVideo {
    ITVideo *siguiente = _listaVideos[_indiceVideo + 1];
    if (!siguiente) return;

    if (_chat) {
        [_chat detener];
        [_chat willMoveToParentViewController:nil];
        [_chat.view removeFromSuperview];
        [_chat removeFromParentViewController];
        _chat = nil;
    }
    _chatCargado = NO;
    _video = siguiente;
    _indiceVideo++;
    _reanudado = NO;
    _posicionInicial = 0;
    _urlMaster = nil;
    _variantes = @[];
    _varianteActual = nil;
    _duracion = 0;
    _slider.maximumValue = 1;
    _slider.value = 0;
    _lblTiempo.text = @"0:00";
    _lblDuracion.text = @"0:00";
    _lblTitulo.text = [self titulo];
    _lblError.hidden = YES;
    _btnReintentar.hidden = YES;
    [self cargar];
    if (_chatActivo) [self crearChat];
    [self.view setNeedsLayout];
}

- (void)falloDeVideo:(NSNotification *)n {
    NSError *e = n.userInfo[AVPlayerItemFailedToPlayToEndTimeErrorKey];
    [self mostrarError:e.localizedDescription ?: @"La reproducción se ha cortado."];
}

#pragma mark - Tiempo

- (void)actualizarTiempo:(CMTime)tiempo {
    double segundos = CMTimeGetSeconds(tiempo);
    if (!isfinite(segundos)) return;
    if (!_arrastrando && !_esDirecto) {
        _slider.value = MIN(_duracion, MAX(0, segundos));
    }
    _lblTiempo.text = ITDuracion(segundos);

    if (!_esDirecto && !_esClip && [ITSettingsViewController reanudarVod]) {
        NSTimeInterval ahora = [NSDate timeIntervalSinceReferenceDate];
        if (ahora - _ultimoGuardado > 5.0) {
            _ultimoGuardado = ahora;
            [self guardarProgresoEn:segundos];
        }
    }

    if (_chat && _chatCargado && !_esDirecto) {
        [_chat actualizarTiempo:segundos];
    }
    if (_esDirecto) {
        _lblDirecto.hidden = NO;
    }

    if (_player.rate > 0 && _controlesVisibles &&
        [NSDate timeIntervalSinceReferenceDate] - _ultimoToque > 3.5) {
        [self mostrarControles:NO];
    }
}

- (void)deslizadorTocando {
    _arrastrando = YES;
    _tiempoAntesDeArrastrar = CMTimeGetSeconds(_player.currentTime);
    [_timerOcultar invalidate];
}

- (void)deslizadorCambio {
    double destino = _slider.value;
    _lblTiempo.text = ITDuracion(destino);
}

- (void)deslizadorSoltado {
    _arrastrando = NO;
    double destino = _slider.value;
    [_player seekToTime:CMTimeMakeWithSeconds(destino, 600)
      toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
    [self programarOcultar];
}

#pragma mark - Controles

- (void)montarControles {
    _controles = [[UIView alloc] init];
    _controles.backgroundColor = [UIColor clearColor];
    [_vistaVideo addSubview:_controles];

    _barraSuperior = [[UIView alloc] init];
    _barraSuperior.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.55];
    [_controles addSubview:_barraSuperior];

    _barraInferior = [[UIView alloc] init];
    _barraInferior.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.62];
    [_controles addSubview:_barraInferior];

    _btnAtras = ITBotonIcono(@"chevron", 22, [UIColor whiteColor]);
    _btnAtras.transform = CGAffineTransformMakeScale(-1.0, 1.0);
    [_btnAtras addTarget:self action:@selector(cerrar) forControlEvents:UIControlEventTouchUpInside];
    [_barraSuperior addSubview:_btnAtras];

    _lblTitulo = ITLabel([self titulo], [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold],
                         [UIColor whiteColor]);
    _lblTitulo.numberOfLines = 1;
    [_barraSuperior addSubview:_lblTitulo];

    _btnCompartir = ITBotonIcono(@"compartir", 20, [UIColor whiteColor]);
    [_btnCompartir addTarget:self action:@selector(compartir) forControlEvents:UIControlEventTouchUpInside];
    [_barraSuperior addSubview:_btnCompartir];

    _btnMas = [UIButton buttonWithType:UIButtonTypeSystem];
    [_btnMas setTitle:@"⋯" forState:UIControlStateNormal];
    [_btnMas setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _btnMas.titleLabel.font = [UIFont systemFontOfSize:22.0 weight:UIFontWeightBold];
    [_btnMas addTarget:self action:@selector(mostrarMas) forControlEvents:UIControlEventTouchUpInside];
    [_barraSuperior addSubview:_btnMas];

    _ruta = [[MPVolumeView alloc] init];
    _ruta.showsVolumeSlider = NO;
    _ruta.showsRouteButton = YES;
    _ruta.tintColor = [UIColor whiteColor];
    [_barraSuperior addSubview:_ruta];

    _btnPlay = [UIButton buttonWithType:UIButtonTypeSystem];
    _btnPlay.tintColor = [UIColor whiteColor];
    [_btnPlay setImage:[ITTheme icono:@"reproducir" lado:34] forState:UIControlStateNormal];
    [_btnPlay addTarget:self action:@selector(alternarReproduccion) forControlEvents:UIControlEventTouchUpInside];
    [_controles addSubview:_btnPlay];

    _btnAtras10 = ITBotonIcono(@"atras10", 30, [UIColor whiteColor]);
    [_btnAtras10 addTarget:self action:@selector(atrasDiez) forControlEvents:UIControlEventTouchUpInside];
    [_controles addSubview:_btnAtras10];

    _btnAdelante10 = ITBotonIcono(@"adelante10", 30, [UIColor whiteColor]);
    [_btnAdelante10 addTarget:self action:@selector(adelanteDiez) forControlEvents:UIControlEventTouchUpInside];
    [_controles addSubview:_btnAdelante10];

    _slider = [[UISlider alloc] init];
    _slider.minimumTrackTintColor = [ITTheme acento];
    _slider.maximumTrackTintColor = [UIColor colorWithWhite:1.0 alpha:0.35];
    _slider.thumbTintColor = [ITTheme acento];
    [_slider addTarget:self action:@selector(deslizadorTocando) forControlEvents:UIControlEventTouchDown];
    [_slider addTarget:self action:@selector(deslizadorCambio) forControlEvents:UIControlEventValueChanged];
    [_slider addTarget:self action:@selector(deslizadorSoltado) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
    [_barraInferior addSubview:_slider];

    _lblTiempo = ITLabel(@"0:00", [UIFont systemFontOfSize:10.0], [UIColor whiteColor]);
    [_barraInferior addSubview:_lblTiempo];

    _lblDuracion = ITLabel(@"0:00", [UIFont systemFontOfSize:10.0], [UIColor whiteColor]);
    _lblDuracion.textAlignment = NSTextAlignmentRight;
    [_barraInferior addSubview:_lblDuracion];

    _lblDirecto = ITLabel(@"● EN DIRECTO", [UIFont systemFontOfSize:10.0 weight:UIFontWeightBold],
                          [UIColor colorWithRed:1.0 green:0.25 blue:0.30 alpha:1.0]);
    [_barraInferior addSubview:_lblDirecto];

    _btnIrDirecto = [UIButton buttonWithType:UIButtonTypeSystem];
    [_btnIrDirecto setTitle:@"Ir al directo" forState:UIControlStateNormal];
    [_btnIrDirecto setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _btnIrDirecto.titleLabel.font = [UIFont systemFontOfSize:10.0 weight:UIFontWeightSemibold];
    [_btnIrDirecto addTarget:self action:@selector(irAlDirecto) forControlEvents:UIControlEventTouchUpInside];
    [_barraInferior addSubview:_btnIrDirecto];

    _btnCalidad = [UIButton buttonWithType:UIButtonTypeSystem];
    [_btnCalidad setTitle:@"Auto" forState:UIControlStateNormal];
    [_btnCalidad setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _btnCalidad.titleLabel.font = [UIFont systemFontOfSize:10.0 weight:UIFontWeightSemibold];
    [_btnCalidad addTarget:self action:@selector(elegirCalidad) forControlEvents:UIControlEventTouchUpInside];
    [_barraInferior addSubview:_btnCalidad];

    _btnVelocidad = [UIButton buttonWithType:UIButtonTypeSystem];
    [_btnVelocidad setTitle:@"1×" forState:UIControlStateNormal];
    [_btnVelocidad setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _btnVelocidad.titleLabel.font = [UIFont systemFontOfSize:10.0 weight:UIFontWeightSemibold];
    [_btnVelocidad addTarget:self action:@selector(elegirVelocidad) forControlEvents:UIControlEventTouchUpInside];
    [_barraInferior addSubview:_btnVelocidad];

    _btnBucle = ITBotonIcono(@"bucle", 16, [UIColor whiteColor]);
    [_btnBucle addTarget:self action:@selector(alternarBucle) forControlEvents:UIControlEventTouchUpInside];
    [_barraInferior addSubview:_btnBucle];

    _btnChat = ITBotonIcono(@"chat", 18, [UIColor whiteColor]);
    [_btnChat addTarget:self action:@selector(alternarChat) forControlEvents:UIControlEventTouchUpInside];
    [_barraInferior addSubview:_btnChat];

    _btnPantalla = ITBotonIcono(@"pantalla", 18, [UIColor whiteColor]);
    [_btnPantalla addTarget:self action:@selector(alternarPantalla) forControlEvents:UIControlEventTouchUpInside];
    [_barraInferior addSubview:_btnPantalla];

    if (_esDirecto) {
        _slider.hidden = YES;
        _lblTiempo.hidden = YES;
        _lblDuracion.hidden = YES;
        _btnVelocidad.hidden = YES;
        _btnBucle.hidden = YES;
        _btnAtras10.hidden = YES;
        _btnAdelante10.hidden = YES;
        _lblDirecto.hidden = NO;
        _btnIrDirecto.hidden = NO;
    } else {
        _lblDirecto.hidden = YES;
        _btnIrDirecto.hidden = YES;
        if (_esClip) {
            _btnChat.hidden = YES;
            _btnVelocidad.hidden = YES;
        }
    }
    if (_esClip) {
        _btnCalidad.hidden = YES;
    } else {
        _btnBucle.hidden = YES;
    }

    [self mostrarControles:YES];
}

- (void)mostrarControles:(BOOL)mostrar {
    _controlesVisibles = mostrar;
    _ultimoToque = [NSDate timeIntervalSinceReferenceDate];
    _controles.userInteractionEnabled = mostrar;
    [UIView animateWithDuration:0.18 animations:^{
        _controles.alpha = mostrar ? 1.0 : 0.0;
    }];
    if (mostrar) [self programarOcultar];
    else [_timerOcultar invalidate];
}

- (void)programarOcultar {
    [_timerOcultar invalidate];
    if (_player.rate == 0) return;
    __typeof(self) debil = self;
    _timerOcultar = [NSTimer scheduledTimerWithTimeInterval:3.6 target:debil
                                                   selector:@selector(ocultarPorTimer)
                                                   userInfo:nil repeats:NO];
}

- (void)ocultarPorTimer {
    if (_player.rate > 0) [self mostrarControles:NO];
}

- (void)atrasDiez { [self saltar:-10]; }
- (void)adelanteDiez { [self saltar:10]; }

- (void)irAlDirecto {
    if (_duracion > 0) {
        [_player seekToTime:CMTimeMakeWithSeconds(MAX(0, _duracion - 3), 600)];
    }
}

- (void)alternarBucle {
    _bucle = !_bucle;
    _btnBucle.tintColor = _bucle ? [ITTheme acento] : [UIColor whiteColor];
}

- (void)alternarPantalla {
    _pantallaCompleta = !_pantallaCompleta;
    [_btnPantalla setImage:[ITTheme icono:(_pantallaCompleta ? @"encoger" : @"pantalla") lado:18]
                  forState:UIControlStateNormal];
    UIInterfaceOrientation orientacion = _pantallaCompleta
        ? UIInterfaceOrientationLandscapeRight : UIInterfaceOrientationPortrait;
    [[UIApplication sharedApplication] setStatusBarOrientation:orientacion animated:YES];
    [self setNeedsStatusBarAppearanceUpdate];
    [self.view setNeedsLayout];
    [UIViewController attemptRotationToDeviceOrientation];
}

- (void)cerrar {
    UINavigationController *nav = self.navigationController;
    if (nav && nav.viewControllers.count > 1) {
        [nav popViewControllerAnimated:YES];
    } else if (nav.presentingViewController) {
        [nav dismissViewControllerAnimated:YES completion:nil];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)compartir {
    NSURL *url = [self enlaceActual];
    if (!url) return;
    UIActivityViewController *a = [[UIActivityViewController alloc] initWithActivityItems:@[url]
                                                                  applicationActivities:nil];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        a.popoverPresentationController.sourceView = self.view;
        a.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width / 2,
                                                                self.view.bounds.size.height / 2, 1, 1);
    }
    [self presentViewController:a animated:YES completion:nil];
}

- (NSURL *)enlaceActual {
    if (_stream) return [NSURL URLWithString:[NSString stringWithFormat:@"https://www.twitch.tv/%@", _stream.login]];
    if (_video) return [NSURL URLWithString:[NSString stringWithFormat:@"https://www.twitch.tv/videos/%@", _video.identificador]];
    if (_clip) return [NSURL URLWithString:[NSString stringWithFormat:@"https://clips.twitch.tv/%@", _clip.slug]];
    return nil;
}

- (void)mostrarMas {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:nil
        message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [a addAction:[UIAlertAction actionWithTitle:@"Compartir" style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *accion) { [self compartir]; }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Copiar enlace" style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *accion) {
        NSURL *url = [self enlaceActual];
        if (url) [UIPasteboard generalPasteboard].string = url.absoluteString;
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Abrir en Twitch" style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *accion) {
        NSURL *url = [self enlaceActual];
        if (url) [[UIApplication sharedApplication] openURL:url];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Reportar un problema" style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *accion) {
        NSURL *url = [NSURL URLWithString:@"https://github.com/lofturb/itwitch/issues"];
        if (url) [[UIApplication sharedApplication] openURL:url];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel handler:nil]];
    [self presentarAccion:a];
}

#pragma mark - Calidad y velocidad

- (void)elegirCalidad {
    if (_variantes.count == 0) return;
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Calidad"
        message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [a addAction:[UIAlertAction actionWithTitle:@"Auto" style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *accion) {
        [self cambiarAURL:self->_urlMaster variante:nil];
    }]];
    for (NSDictionary *v in _variantes) {
        NSString *nombre = v[@"nombre"] ?: @"Auto";
        [a addAction:[UIAlertAction actionWithTitle:nombre style:UIAlertActionStyleDefault
            handler:^(UIAlertAction *accion) {
            [self cambiarAURL:[v[@"url"] absoluteString] variante:v];
        }]];
    }
    [a addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel handler:nil]];
    [self presentarAccion:a];
}

- (void)cambiarAURL:(NSString *)url variante:(NSDictionary *)variante {
    if (url.length == 0) return;
    _varianteActual = variante;
    [_btnCalidad setTitle:variante[@"nombre"] ?: @"Auto" forState:UIControlStateNormal];
    double actual = CMTimeGetSeconds(_player.currentTime);
    BOOL estaba = _player.rate > 0;
    [self prepararURL:url];
    if (!_esDirecto && actual > 1) {
        [_player seekToTime:CMTimeMakeWithSeconds(actual, 600)];
    }
    if (estaba) [_player play];
}

- (void)elegirVelocidad {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Velocidad"
        message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    NSArray *velocidades = @[@0.5, @1.0, @1.25, @1.5, @2.0];
    for (NSNumber *n in velocidades) {
        NSString *titulo = [NSString stringWithFormat:@"%.2g×", n.doubleValue];
        [a addAction:[UIAlertAction actionWithTitle:titulo style:UIAlertActionStyleDefault
            handler:^(UIAlertAction *accion) {
            [self->_player setRate:n.floatValue];
            [self->_btnVelocidad setTitle:titulo forState:UIControlStateNormal];
        }]];
    }
    [a addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel handler:nil]];
    [self presentarAccion:a];
}

- (void)presentarAccion:(UIAlertController *)a {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        a.popoverPresentationController.sourceView = self.view;
        a.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width / 2,
                                                                self.view.bounds.size.height / 2, 1, 1);
    }
    [self presentViewController:a animated:YES completion:nil];
}

#pragma mark - Chat

- (void)alternarChat {
    if (!_chatCargado) [self crearChat];
    _chatActivo = !_chatActivo;
    _chat.view.hidden = !_chatActivo;
    [self.view setNeedsLayout];
}

- (void)crearChat {
    if (_chatCargado) return;
    if (_esDirecto) {
        _chat = [[ITChatViewController alloc] initWithCanal:_stream.login];
    } else {
        _chat = [[ITChatViewController alloc] initWithVideo:_video.identificador
                                                   duracion:_video.duracion];
    }
    [self addChildViewController:_chat];
    [_chat didMoveToParentViewController:self];
    [self.view addSubview:_chat.view];
    _chatCargado = YES;
    if (!_esDirecto) [_chat actualizarTiempo:CMTimeGetSeconds(_player.currentTime)];
}

#pragma mark - Gestos

- (void)prepararGestos {
    UITapGestureRecognizer *simple = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                             action:@selector(tocarVideo)];
    [simple setNumberOfTapsRequired:1];
    [_vistaVideo addGestureRecognizer:simple];

    UITapGestureRecognizer *doble = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                            action:@selector(dobleToque:)];
    [doble setNumberOfTapsRequired:2];
    [simple requireGestureRecognizerToFail:doble];
    [_vistaVideo addGestureRecognizer:doble];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                                          action:@selector(pan:)];
    pan.delegate = self;
    [_vistaVideo addGestureRecognizer:pan];

    _volumen = [[MPVolumeView alloc] initWithFrame:CGRectMake(-1000, -1000, 40, 40)];
    [self.view addSubview:_volumen];
}

- (void)tocarVideo {
    [self mostrarControles:!_controlesVisibles];
}

- (void)dobleToque:(UITapGestureRecognizer *)g {
    if (_esDirecto) return;
    CGPoint p = [g locationInView:_vistaVideo];
    if (p.x < _vistaVideo.bounds.size.width / 2) [self saltar:-10];
    else [self saltar:10];
    [self mostrarControles:YES];
}

- (void)pan:(UIPanGestureRecognizer *)g {
    if (_esDirecto) return;
    CGPoint t = [g translationInView:_vistaVideo];
    if (g.state == UIGestureRecognizerStateBegan) {
        if (fabs(t.x) > fabs(t.y)) {
            _arrastrando = YES;
            _tiempoAntesDeArrastrar = CMTimeGetSeconds(_player.currentTime);
        }
    } else if (g.state == UIGestureRecognizerStateChanged) {
        if (_arrastrando) {
            double delta = (t.x / _vistaVideo.bounds.size.width) * _duracion;
            double destino = MAX(0, MIN(_duracion, _tiempoAntesDeArrastrar + delta));
            _slider.value = destino;
            _lblTiempo.text = ITDuracion(destino);
            [self mostrarControles:YES];
        } else {
            UISlider *s = [self deslizadorDeVolumen];
            if (s) {
                s.value = MAX(0, MIN(1, s.value - t.y / 400.0));
                [g setTranslation:CGPointZero inView:_vistaVideo];
            }
        }
    } else if (g.state == UIGestureRecognizerStateEnded ||
               g.state == UIGestureRecognizerStateCancelled) {
        if (_arrastrando) {
            _arrastrando = NO;
            [self deslizadorSoltado];
        }
    }
}

- (UISlider *)deslizadorDeVolumen {
    for (UIView *v in _volumen.subviews) {
        if ([v isKindOfClass:[UISlider class]]) return (UISlider *)v;
    }
    return nil;
}

#pragma mark - Audio / bloqueo

- (void)prepararAudio {
    AVAudioSession *sesion = [AVAudioSession sharedInstance];
    [sesion setCategory:AVAudioSessionCategoryPlayback error:nil];
    [sesion setActive:YES error:nil];

    MPRemoteCommandCenter *centro = [MPRemoteCommandCenter sharedCommandCenter];
    [centro.playCommand addTarget:self action:@selector(comandoPlay)];
    [centro.pauseCommand addTarget:self action:@selector(comandoPausa)];
    [centro.togglePlayPauseCommand addTarget:self action:@selector(comandoAlternar)];
    [centro.skipForwardCommand addTarget:self action:@selector(comandoAdelante)];
    [centro.skipBackwardCommand addTarget:self action:@selector(comandoAtras)];
}

- (void)comandoPlay { dispatch_async(dispatch_get_main_queue(), ^{ [self reproducir]; }); }
- (void)comandoPausa { dispatch_async(dispatch_get_main_queue(), ^{ [self pausar]; }); }
- (void)comandoAlternar { dispatch_async(dispatch_get_main_queue(), ^{ [self alternarReproduccion]; }); }
- (void)comandoAdelante { dispatch_async(dispatch_get_main_queue(), ^{ [self saltar:10]; }); }
- (void)comandoAtras { dispatch_async(dispatch_get_main_queue(), ^{ [self saltar:-10]; }); }

- (void)actualizarAhoraSuena {
    NSString *titulo = [self titulo];
    NSString *artista = _stream.nombre ?: (_video ? _video.login : (_clip ? _clip.curador : @"iTwitch"));
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    info[MPMediaItemPropertyTitle] = titulo ?: @"iTwitch";
    info[MPMediaItemPropertyArtist] = artista ?: @"Twitch";
    info[MPNowPlayingInfoPropertyPlaybackRate] = @(_player.rate);
    if (_duracion > 0) info[MPMediaItemPropertyPlaybackDuration] = @(_duracion);
    [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = info;

    NSString *miniatura = _stream.miniatura ?: (_video.miniatura ?: _clip.miniatura);
    if (miniatura.length) {
        [ITImageCache cargarURL:ITImagen(miniatura, 400, 225) completion:^(UIImage *imagen) {
            if (!imagen) return;
            NSMutableDictionary *nuevo = [[MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo mutableCopy];
            if (!nuevo) nuevo = [NSMutableDictionary dictionary];
            nuevo[MPMediaItemPropertyArtwork] =
                [[MPMediaItemArtwork alloc] initWithImage:imagen];
            [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = nuevo;
        }];
    }
}

#pragma mark - Auxiliares

- (NSString *)titulo {
    if (_stream) {
        if (_stream.titulo.length) return [NSString stringWithFormat:@"%@ · %@", _stream.nombre, _stream.titulo];
        return _stream.nombre ?: _stream.login;
    }
    if (_video) return _video.titulo;
    if (_clip) return _clip.titulo;
    return @"iTwitch";
}

- (void)parar {
    if (!_cedidoAMini) [_player pause];
    [_timerOcultar invalidate];
    _timerOcultar = nil;
    if (_observadorTiempo) {
        [_player removeTimeObserver:_observadorTiempo];
        _observadorTiempo = nil;
    }
    if (_item && _observadorEstado) {
        [_item removeObserver:self forKeyPath:@"status"];
        _observadorEstado = nil;
    }
    [_chat detener];
    if (!_cedidoAMini) {
        [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:nil];
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Progreso de VOD

- (NSString *)claveProgreso {
    if (!_video.identificador.length) return nil;
    return [@"itwitch_pos_" stringByAppendingString:_video.identificador];
}

- (void)guardarProgresoEn:(double)segundos {
    NSString *clave = [self claveProgreso];
    if (!clave || !isfinite(segundos) || _duracion <= 0) return;
    NSUserDefaults *ajustes = [NSUserDefaults standardUserDefaults];
    if (segundos < 10.0 || segundos > _duracion - 15.0) {
        [ajustes removeObjectForKey:clave];
    } else {
        [ajustes setDouble:segundos forKey:clave];
    }
    [ajustes synchronize];
}

- (void)reanudarSiProcede {
    if (_esDirecto || _esClip || _reanudado) return;
    _reanudado = YES;
    if (![ITSettingsViewController reanudarVod] && _posicionInicial <= 0) return;
    NSString *clave = [self claveProgreso];
    if (!clave) return;
    double guardado = _posicionInicial > 0 ? _posicionInicial :
        [[NSUserDefaults standardUserDefaults] doubleForKey:clave];
    if (guardado < 10.0 || _duracion <= 0 || guardado > _duracion - 15.0) {
        if (guardado > 0) [[NSUserDefaults standardUserDefaults] removeObjectForKey:clave];
        return;
    }
    [_player seekToTime:CMTimeMakeWithSeconds(guardado, 600)
      toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
    _slider.value = guardado;
    _lblTiempo.text = ITDuracion(guardado);
}

@end
