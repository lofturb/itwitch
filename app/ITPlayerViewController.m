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
#import "ITDownloadManager.h"
#import "ITDownloadsViewController.h"

// Boton del reproductor con icono (o texto) y una etiqueta debajo. En un A5
// los botones pelados se perdian entre el video; con el pie se entiende que
// hace cada uno.
@interface ITBotonControl : UIButton
@property (nonatomic, strong) UIImageView *icono;
@property (nonatomic, strong) UILabel *titulo;
@property (nonatomic, strong) UILabel *pie;
- (void)usarIcono:(NSString *)forma;
- (void)usarTexto:(NSString *)texto;
- (void)ponerPie:(NSString *)texto;
- (void)destacar:(BOOL)destacar;
@end

@implementation ITBotonControl

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _icono = [[UIImageView alloc] init];
        _icono.contentMode = UIViewContentModeScaleAspectFit;
        _icono.tintColor = [UIColor whiteColor];
        _icono.userInteractionEnabled = NO;
        [self addSubview:_icono];

        _titulo = [[UILabel alloc] init];
        _titulo.font = [UIFont systemFontOfSize:10.0 weight:UIFontWeightSemibold];
        _titulo.textColor = [UIColor whiteColor];
        _titulo.textAlignment = NSTextAlignmentCenter;
        _titulo.userInteractionEnabled = NO;
        [self addSubview:_titulo];

        _pie = [[UILabel alloc] init];
        _pie.font = [UIFont systemFontOfSize:8.5 weight:UIFontWeightMedium];
        _pie.textColor = [UIColor colorWithWhite:1.0 alpha:0.62];
        _pie.textAlignment = NSTextAlignmentCenter;
        _pie.userInteractionEnabled = NO;
        [self addSubview:_pie];
    }
    return self;
}

- (void)usarIcono:(NSString *)forma {
    UIImage *imagen = [ITTheme icono:forma lado:19];
    self.icono.image = [imagen imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    self.icono.hidden = NO;
    self.titulo.text = @"";
    self.titulo.hidden = YES;
    [self setNeedsLayout];
}

- (void)usarTexto:(NSString *)texto {
    self.icono.image = nil;
    self.icono.hidden = YES;
    self.titulo.text = texto;
    self.titulo.hidden = NO;
    [self setNeedsLayout];
}

- (void)ponerPie:(NSString *)texto {
    self.pie.text = texto;
}

- (void)destacar:(BOOL)destacar {
    UIColor *color = destacar ? [ITTheme acento] : [UIColor whiteColor];
    self.icono.tintColor = color;
    self.titulo.textColor = color;
    self.pie.textColor = destacar ? [ITTheme acento]
                                  : [UIColor colorWithWhite:1.0 alpha:0.62];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat ancho = self.bounds.size.width;
    CGFloat alto = self.bounds.size.height;
    BOOL conIcono = !self.icono.hidden;

    if (conIcono) {
        CGFloat lado = 20.0;
        self.icono.frame = CGRectMake((ancho - lado) / 2.0, 5.0, lado, lado);
        self.titulo.frame = CGRectMake(0, 26.0, ancho, 12.0);
        self.pie.frame = CGRectMake(0, 37.0, ancho, 10.0);
    } else {
        self.titulo.frame = CGRectMake(0, 9.0, ancho, 16.0);
        self.pie.frame = CGRectMake(0, 25.0, ancho, 10.0);
    }
    (void)alto;
}

@end

// Contenedor de los controles: deja pasar los toques del fondo al video para
// que los gestos (toque para mostrar, arrastre para buscar) sigan funcionando
// aunque la capa de controles este visible.
@interface ITControlesView : UIView
@end

@implementation ITControlesView
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *vista = [super hitTest:point withEvent:event];
    return (vista == self) ? nil : vista;
}
@end

@interface ITPlayerViewController () <UIGestureRecognizerDelegate>
- (float)velocidadElegida;
- (void)avisar:(NSString *)texto;
- (void)crearAviso;
- (void)descargarVideo;
- (void)abrirDescargas;
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
    BOOL _reproducirAlCargar;
    NSTimeInterval _ultimoGuardado;

    UIView *_vistaVideo;
    AVPlayer *_player;
    AVPlayerItem *_item;
    AVPlayerLayer *_capa;
    id _observadorTiempo;
    id _observadorEstado;
    NSTimer *_temporizadorCarga;
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
    ITBotonControl *_btnCalidad;
    ITBotonControl *_btnVelocidad;
    ITBotonControl *_btnChat;
    ITBotonControl *_btnPantalla;
    ITBotonControl *_btnBucle;
    ITBotonControl *_btnDescargar;
    UIButton *_btnIrDirecto;
    UIButton *_btnReintentar;
    UISlider *_slider;
    UILabel *_lblTiempo;
    UILabel *_lblDuracion;
    UILabel *_lblTitulo;
    UILabel *_lblDirecto;
    UILabel *_lblError;
    UILabel *_lblAviso;
    UIActivityIndicatorView *_rueda;
    NSTimer *_timerOcultar;
    NSTimer *_temporizadorSueno;
    NSTimer *_temporizadorAviso;

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
    NSString *_rutaLocal;
    NSString *_tituloLocal;
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

- (instancetype)initWithArchivo:(NSString *)ruta titulo:(NSString *)titulo {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _rutaLocal = [ruta copy];
        _tituloLocal = [titulo copy];
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

    [self montarControles];

    _rueda = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    [self.view addSubview:_rueda];

    _lblError = ITLabel(@"", [ITTheme fuenteCuerpo], [UIColor whiteColor]);
    _lblError.textAlignment = NSTextAlignmentCenter;
    _lblError.numberOfLines = 3;
    _lblError.hidden = YES;
    [self.view addSubview:_lblError];

    _btnReintentar = [UIButton buttonWithType:UIButtonTypeSystem];
    [_btnReintentar setTitle:@"Reintentar" forState:UIControlStateNormal];
    [_btnReintentar setTitleColor:[ITTheme textoSobreAcento] forState:UIControlStateNormal];
    _btnReintentar.backgroundColor = [ITTheme acento];
    _btnReintentar.titleLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    ITRedondear(_btnReintentar, 14.0);
    _btnReintentar.hidden = YES;
    [_btnReintentar addTarget:self action:@selector(reintentar) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_btnReintentar];

    [self prepararGestos];
    [self prepararAudio];

    _chatActivo = [ITSettingsViewController chatActivo] && !_esClip && _rutaLocal.length == 0;
    if (_chatActivo) [self crearChat];
    _reproducirAlCargar = YES;
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

    // El video ocupa toda la pantalla. Si el chat esta visible, se le reserva
    // un panel a la derecha (iPad horizontal) o abajo (vertical).
    BOOL chatVisible = (_chat != nil && _chatActivo);
    BOOL chatLateral = chatVisible && horizontal && ancho >= 640.0;
    CGFloat anchoChat = chatLateral ? MIN(320.0, MAX(250.0, ancho * 0.34)) : 0.0;
    CGFloat altoChat = (chatVisible && !chatLateral) ? MIN(alto * 0.42, 380.0) : 0.0;
    CGFloat anchoVideo = ancho - anchoChat;
    CGFloat altoVideo = alto - altoChat;

    _vistaVideo.frame = CGRectMake(0, 0, anchoVideo, altoVideo);
    _capa.frame = _vistaVideo.bounds;

    _controles.frame = self.view.bounds;
    _barraSuperior.frame = CGRectMake(0, 0, anchoVideo, 44);
    _barraInferior.frame = CGRectMake(0, altoVideo - 100, anchoVideo, 100);

    _btnAtras.frame = CGRectMake(2, 2, 42, 40);
    _btnMas.frame = CGRectMake(anchoVideo - 44, 2, 40, 40);
    _btnCompartir.frame = CGRectMake(anchoVideo - 84, 2, 40, 40);
    _ruta.frame = CGRectMake(anchoVideo - 128, 2, 42, 40);
    _lblTitulo.frame = CGRectMake(48, 2, MAX(40, anchoVideo - 180), 40);

    _slider.frame = CGRectMake(14, 8, anchoVideo - 28, 22);
    _lblTiempo.frame = CGRectMake(14, 32, 70, 14);
    _lblDuracion.frame = CGRectMake(anchoVideo - 84, 32, 70, 14);
    _lblDirecto.frame = CGRectMake(14, 34, 120, 14);
    _btnIrDirecto.frame = CGRectMake(anchoVideo - 118, 30, 104, 22);

    BOOL compacto = anchoVideo < 500.0;

    // Visibilidad segun el tipo de contenido y el ancho. En un iPhone los
    // botones secundarios viven en el menu ⋯ para que no se solapen.
    _btnAtras10.hidden = _esDirecto;
    _btnAdelante10.hidden = _esDirecto;
    _slider.hidden = _esDirecto;
    _lblTiempo.hidden = _esDirecto;
    _lblDuracion.hidden = _esDirecto;
    _lblDirecto.hidden = !_esDirecto;
    _btnIrDirecto.hidden = !_esDirecto;
    _btnChat.hidden = (_esClip || _rutaLocal.length > 0);
    if (compacto) {
        _btnDescargar.hidden = YES;
        _btnVelocidad.hidden = YES;
        _btnBucle.hidden = YES;
    } else {
        _btnDescargar.hidden = (_esDirecto || _esClip || _rutaLocal.length > 0);
        _btnVelocidad.hidden = (_esDirecto || _esClip);
        _btnBucle.hidden = !_esClip;
    }

    CGFloat y = 50.0;
    _btnAtras10.frame = CGRectMake(8, y, 44, 46);
    _btnPlay.frame = CGRectMake(54, y - 4, 52, 54);
    _btnAdelante10.frame = CGRectMake(108, y, 44, 46);

    CGFloat anchoBoton = compacto ? 44.0 : 62.0;
    CGFloat x = anchoVideo - 8.0;
    NSArray *derecha = @[ _btnPantalla, _btnChat, _btnDescargar, _btnVelocidad,
                          _btnCalidad, _btnBucle ];
    for (UIView *boton in derecha) {
        if (boton.hidden) continue;
        x -= anchoBoton;
        boton.frame = CGRectMake(x, y, anchoBoton, 46);
    }

    _rueda.center = CGPointMake(anchoVideo / 2, altoVideo / 2);
    _lblError.frame = CGRectMake(20, altoVideo / 2 - 20, anchoVideo - 40, 60);
    _btnReintentar.frame = CGRectMake((anchoVideo - 120) / 2, altoVideo / 2 + 42, 120, 30);

    _lblAviso.frame = CGRectMake(MAX(14, (anchoVideo - 360) / 2), 54,
                                 MIN(360, anchoVideo - 28), 32);

    if (_chat) {
        _chat.view.hidden = !chatVisible;
        if (chatLateral) {
            _chat.view.frame = CGRectMake(anchoVideo, 0, anchoChat, alto);
        } else if (chatVisible) {
            _chat.view.frame = CGRectMake(0, altoVideo, ancho, altoChat);
        }
    }

    // El chat va por encima de los controles para poder escribir en el, pero
    // las barras no lo invaden porque su ancho es el del video.
    [self.view bringSubviewToFront:_controles];
    if (chatVisible) [self.view bringSubviewToFront:_chat.view];
    [self.view bringSubviewToFront:_lblAviso];
}

- (void)dealloc {
    [self parar];
    [_temporizadorCarga invalidate];
    if (_observadorTiempo) [_player removeTimeObserver:_observadorTiempo];
    if (_observadorEstado) [_item removeObserver:self forKeyPath:@"status"];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_timerOcultar invalidate];
    [_temporizadorSueno invalidate];
    [_temporizadorAviso invalidate];
}

#pragma mark - Carga

- (void)cargar {
    [self mostrarCargando:YES];
    [self programarLimiteDeCarga];
    _lblError.hidden = YES;
    _btnReintentar.hidden = YES;

    __typeof(self) debil = self;
    if (_rutaLocal.length) {
        NSLog(@"[iTwitch] abriendo archivo local %@", _rutaLocal);
        [self prepararURL:[[NSURL fileURLWithPath:_rutaLocal] absoluteString]];
        return;
    }
    if (_esClip) {
        [self cargarClip];
        return;
    }
    if (_esDirecto) {
        NSLog(@"[iTwitch] abriendo directo %@", _stream.login);
        [ITPlayback urlDirecto:_stream.login completion:^(NSString *url, NSError *error) {
            if (error || url.length == 0) {
                NSLog(@"[iTwitch] token de directo fallo: %@", error);
                [debil mostrarError:error.localizedDescription ?: @"No se pudo abrir el directo."];
                return;
            }
            NSLog(@"[iTwitch] master: %@", url);
            debil->_urlMaster = url;
            [debil cargarVariantesYReproducir:url];
        }];
    } else {
        NSLog(@"[iTwitch] abriendo video %@", _video.identificador);
        [ITPlayback urlVod:_video.identificador completion:^(NSString *url, NSError *error) {
            if (error || url.length == 0) {
                NSLog(@"[iTwitch] token de video fallo: %@", error);
                [debil mostrarError:error.localizedDescription ?: @"No se pudo abrir el vídeo."];
                return;
            }
            NSLog(@"[iTwitch] master vod: %@", url);
            debil->_urlMaster = url;
            [debil cargarVariantesYReproducir:url];
        }];
    }
}

// En un A5 una carga que no termina deja la rueda girando para siempre.
// Este límite convierte el cuelgue en un error con botón de reintentar.
- (void)programarLimiteDeCarga {
    [_temporizadorCarga invalidate];
    _temporizadorCarga = [NSTimer scheduledTimerWithTimeInterval:25.0
                                                          target:self
                                                        selector:@selector(cargaAgotada:)
                                                        userInfo:nil
                                                         repeats:NO];
}

- (void)cargaAgotada:(NSTimer *)temporizador {
    _temporizadorCarga = nil;
    if (_item.status == AVPlayerItemStatusReadyToPlay) return;
    NSLog(@"[iTwitch] la carga se agoto (estado %ld, error %@)",
          (long)_item.status, _item.error);
    [self mostrarError:@"El vídeo tarda demasiado en cargar. Revisa la conexión y el perfil de certificados."];
}

- (void)cargarClip {
    if (_clip.calidades.count == 0) {
        [self mostrarError:@"Este clip no tiene una calidad reproducible."];
        return;
    }

    // Las URLs de los clips necesitan la firma; se preparan para el menu.
    NSMutableArray *variantes = [NSMutableArray array];
    for (NSDictionary *q in _clip.calidades) {
        NSString *base = q[@"url"];
        if (base.length == 0) continue;
        NSString *firmada = [ITPlayback urlClip:base firma:_clip.firma token:_clip.token];
        NSURL *destino = [NSURL URLWithString:firmada];
        if (!destino) continue;
        NSInteger alto = [q[@"alto"] integerValue];
        NSString *nombre = alto > 0 ? [NSString stringWithFormat:@"%dp", (int)alto]
                                    : (q[@"calidad"] ?: @"Auto");
        [variantes addObject:@{ @"nombre" : nombre,
                                @"url" : destino,
                                @"alto" : @(alto),
                                @"banda" : @0 }];
    }
    _variantes = variantes;
    _varianteActual = nil;
    [_btnCalidad usarTexto:@"Auto"];

    NSDictionary *elegida = [self mejorCalidadDe:variantes];
    if (!elegida) {
        [self mostrarError:@"Este clip no tiene una calidad reproducible."];
        return;
    }
    [self prepararURL:[elegida[@"url"] absoluteString]];
}

- (void)cargarVariantesYReproducir:(NSString *)url {
    __typeof(self) debil = self;
    [ITPlayback variantesDeMaster:url completion:^(NSArray *variantes, NSError *error) {
        if (error && variantes.count == 0) {
            NSLog(@"[iTwitch] no se pudo leer el master: %@", error);
            [debil mostrarError:error.localizedDescription ?: @"No se pudo leer la lista de calidades."];
            return;
        }
        NSLog(@"[iTwitch] variantes: %lu", (unsigned long)variantes.count);
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
    NSLog(@"[iTwitch] preparando: %@", urlString);
    [self mostrarCargando:YES];
    [self programarLimiteDeCarga];
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
        [self.view bringSubviewToFront:_rueda];
        [_rueda startAnimating];
    } else {
        [_rueda stopAnimating];
        [_temporizadorCarga invalidate];
        _temporizadorCarga = nil;
    }
}

- (void)mostrarError:(NSString *)texto {
    [self mostrarCargando:NO];
    _lblError.text = texto ?: @"Error de reproducción.";
    _lblError.hidden = NO;
    _btnReintentar.hidden = NO;
    [self.view bringSubviewToFront:_lblError];
    [self.view bringSubviewToFront:_btnReintentar];
    [_player pause];
}

- (void)reintentar {
    _lblError.hidden = YES;
    _btnReintentar.hidden = YES;
    double actual = CMTimeGetSeconds(_player.currentTime);
    if (isfinite(actual) && actual > 0) _posicionInicial = actual;
    _reanudado = NO;
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
    _reproducirAlCargar = YES;
    [self cargar];
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                        change:(NSDictionary *)change context:(void *)context {
    if (![keyPath isEqualToString:@"status"]) return;
    if (object != _item) return;
    if (_item.status == AVPlayerItemStatusReadyToPlay) {
        NSLog(@"[iTwitch] listo para reproducir");
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
        if (_reproducirAlCargar) [self reproducir];
        else [self actualizarBotonPlay];
        [self actualizarAhoraSuena];
    } else if (_item.status == AVPlayerItemStatusFailed) {
        NSLog(@"[iTwitch] fallo del item: %@", _item.error);
        [self mostrarError:_item.error.localizedDescription ?: @"No se pudo reproducir."];
    }
}

#pragma mark - Reproduccion

- (void)reproducir {
    [_player play];
    if (!_esDirecto) {
        float velocidad = [self velocidadElegida];
        if (velocidad != 1.0f) _player.rate = velocidad;
        [_btnVelocidad usarTexto:[NSString stringWithFormat:@"%.2g×", velocidad]];
    }
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
    _reproducirAlCargar = YES;
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
        [NSDate timeIntervalSinceReferenceDate] - _ultimoToque > 5.0) {
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
    _controles = [[ITControlesView alloc] init];
    _controles.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_controles];

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
    [_btnPlay setImage:[ITTheme icono:@"reproducir" lado:32] forState:UIControlStateNormal];
    [_btnPlay addTarget:self action:@selector(alternarReproduccion) forControlEvents:UIControlEventTouchUpInside];
    [_barraInferior addSubview:_btnPlay];

    _btnAtras10 = ITBotonIcono(@"atras10", 28, [UIColor whiteColor]);
    [_btnAtras10 addTarget:self action:@selector(atrasDiez) forControlEvents:UIControlEventTouchUpInside];
    [_barraInferior addSubview:_btnAtras10];

    _btnAdelante10 = ITBotonIcono(@"adelante10", 28, [UIColor whiteColor]);
    [_btnAdelante10 addTarget:self action:@selector(adelanteDiez) forControlEvents:UIControlEventTouchUpInside];
    [_barraInferior addSubview:_btnAdelante10];

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

    _btnCalidad = [[ITBotonControl alloc] initWithFrame:CGRectZero];
    [_btnCalidad usarTexto:@"Auto"];
    [_btnCalidad ponerPie:@"Calidad"];
    [_btnCalidad addTarget:self action:@selector(elegirCalidad) forControlEvents:UIControlEventTouchUpInside];
    [_barraInferior addSubview:_btnCalidad];

    _btnVelocidad = [[ITBotonControl alloc] initWithFrame:CGRectZero];
    [_btnVelocidad usarTexto:@"1×"];
    [_btnVelocidad ponerPie:@"Velocidad"];
    [_btnVelocidad addTarget:self action:@selector(elegirVelocidad) forControlEvents:UIControlEventTouchUpInside];
    [_barraInferior addSubview:_btnVelocidad];

    _btnBucle = [[ITBotonControl alloc] initWithFrame:CGRectZero];
    [_btnBucle usarIcono:@"bucle"];
    [_btnBucle ponerPie:@"Bucle"];
    [_btnBucle addTarget:self action:@selector(alternarBucle) forControlEvents:UIControlEventTouchUpInside];
    [_barraInferior addSubview:_btnBucle];

    _btnChat = [[ITBotonControl alloc] initWithFrame:CGRectZero];
    [_btnChat usarIcono:@"chat"];
    [_btnChat ponerPie:@"Chat"];
    [_btnChat addTarget:self action:@selector(alternarChat) forControlEvents:UIControlEventTouchUpInside];
    [_barraInferior addSubview:_btnChat];

    _btnDescargar = [[ITBotonControl alloc] initWithFrame:CGRectZero];
    [_btnDescargar usarIcono:@"descargar"];
    [_btnDescargar ponerPie:@"Bajar"];
    [_btnDescargar addTarget:self action:@selector(descargarVideo) forControlEvents:UIControlEventTouchUpInside];
    [_barraInferior addSubview:_btnDescargar];

    _btnPantalla = [[ITBotonControl alloc] initWithFrame:CGRectZero];
    [_btnPantalla usarIcono:@"pantalla"];
    [_btnPantalla ponerPie:@"Pantalla"];
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
        _btnDescargar.hidden = YES;
        _lblDirecto.hidden = NO;
        _btnIrDirecto.hidden = NO;
    } else {
        _lblDirecto.hidden = YES;
        _btnIrDirecto.hidden = YES;
        _btnBucle.hidden = !_esClip;
        if (_esClip) {
            _btnChat.hidden = YES;
            _btnVelocidad.hidden = YES;
            _btnDescargar.hidden = YES;
        }
        if (_rutaLocal.length) {
            _btnChat.hidden = YES;
            _btnDescargar.hidden = YES;
        }
    }
    [_btnChat destacar:_chatActivo];
    [_btnBucle destacar:NO];

    [self crearAviso];
    [self mostrarControles:YES];
}

- (void)crearAviso {
    _lblAviso = ITLabel(@"", [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold],
                        [UIColor whiteColor]);
    _lblAviso.textAlignment = NSTextAlignmentCenter;
    _lblAviso.numberOfLines = 2;
    _lblAviso.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.78];
    _lblAviso.hidden = YES;
    _lblAviso.userInteractionEnabled = NO;
    ITRedondear(_lblAviso, 8.0);
    [self.view addSubview:_lblAviso];
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
    _timerOcultar = [NSTimer scheduledTimerWithTimeInterval:5.0 target:debil
                                                   selector:@selector(ocultarPorTimer)
                                                   userInfo:nil repeats:NO];
}

- (void)ocultarPorTimer {
    if (_player.rate > 0) [self mostrarControles:NO];
}

- (void)atrasDiez { [self saltar:-10]; }
- (void)adelanteDiez { [self saltar:10]; }

- (void)irAlDirecto {
    if (_esDirecto) {
        [_player seekToTime:kCMTimePositiveInfinity];
        return;
    }
    if (_duracion > 0) {
        [_player seekToTime:CMTimeMakeWithSeconds(MAX(0, _duracion - 3), 600)];
    }
}

- (void)alternarBucle {
    _bucle = !_bucle;
    [_btnBucle destacar:_bucle];
    [self avisar:_bucle ? @"Bucle activado" : @"Bucle desactivado"];
}

- (void)alternarPantalla {
    _pantallaCompleta = !_pantallaCompleta;
    [_btnPantalla usarIcono:(_pantallaCompleta ? @"encoger" : @"pantalla")];
    [_btnPantalla ponerPie:(_pantallaCompleta ? @"Normal" : @"Pantalla")];
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
    if (_rutaLocal.length) return [NSURL fileURLWithPath:_rutaLocal];
    if (_stream) return [NSURL URLWithString:[NSString stringWithFormat:@"https://www.twitch.tv/%@", _stream.login]];
    if (_video) return [NSURL URLWithString:[NSString stringWithFormat:@"https://www.twitch.tv/videos/%@", _video.identificador]];
    if (_clip) return [NSURL URLWithString:[NSString stringWithFormat:@"https://clips.twitch.tv/%@", _clip.slug]];
    return nil;
}

- (void)mostrarMas {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:nil
        message:nil preferredStyle:UIAlertControllerStyleActionSheet];

    if (!_esDirecto && !_esClip) {
        [a addAction:[UIAlertAction actionWithTitle:@"Descargar vídeo" style:UIAlertActionStyleDefault
            handler:^(UIAlertAction *accion) { [self descargarVideo]; }]];
    }
    if (!_esDirecto) {
        [a addAction:[UIAlertAction actionWithTitle:@"Velocidad" style:UIAlertActionStyleDefault
            handler:^(UIAlertAction *accion) { [self elegirVelocidad]; }]];
    }
    [a addAction:[UIAlertAction actionWithTitle:@"Calidad" style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *accion) { [self elegirCalidad]; }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Temporizador" style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *accion) { [self elegirTemporizador]; }]];
    if (!_esDirecto && !_esClip) {
        [a addAction:[UIAlertAction actionWithTitle:@"Copiar enlace en este minuto"
            style:UIAlertActionStyleDefault
            handler:^(UIAlertAction *accion) { [self copiarEnlaceEnMinuto]; }]];
    }
    [a addAction:[UIAlertAction actionWithTitle:@"Compartir" style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *accion) { [self compartir]; }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Copiar enlace" style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *accion) {
        NSURL *url = [self enlaceActual];
        if (url) [UIPasteboard generalPasteboard].string = url.absoluteString;
        [self avisar:@"Enlace copiado"];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Ver descargas" style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *accion) { [self abrirDescargas]; }]];
    if (!_esDirecto) {
        [a addAction:[UIAlertAction actionWithTitle:@"Abrir en Twitch" style:UIAlertActionStyleDefault
            handler:^(UIAlertAction *accion) {
            NSURL *url = [self enlaceActual];
            if (url) [[UIApplication sharedApplication] openURL:url];
        }]];
    }
    [a addAction:[UIAlertAction actionWithTitle:@"Reportar un problema" style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *accion) {
        NSURL *url = [NSURL URLWithString:@"https://github.com/lofturb/itwitch/issues"];
        if (url) [[UIApplication sharedApplication] openURL:url];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel handler:nil]];
    [self presentarAccion:a];
}

- (void)abrirDescargas {
    ITDownloadsViewController *vc = [[ITDownloadsViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)copiarEnlaceEnMinuto {
    NSURL *url = [self enlaceActual];
    if (!url) return;
    int total = (int)MAX(0, CMTimeGetSeconds(_player.currentTime));
    NSString *marca = [NSString stringWithFormat:@"%dh%dm%ds",
                       total / 3600, (total % 3600) / 60, total % 60];
    NSString *texto = [NSString stringWithFormat:@"%@?t=%@", url.absoluteString, marca];
    [UIPasteboard generalPasteboard].string = texto;
    [self avisar:@"Enlace copiado en este minuto"];
}

#pragma mark - Temporizador

- (void)elegirTemporizador {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Temporizador"
        message:@"La reproducción se pausará al terminar el tiempo."
        preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSNumber *minutos in @[@15, @30, @60, @90]) {
        NSString *titulo = [NSString stringWithFormat:@"%@ minutos", minutos];
        [a addAction:[UIAlertAction actionWithTitle:titulo style:UIAlertActionStyleDefault
            handler:^(UIAlertAction *accion) {
            [self programarSueno:minutos.doubleValue * 60.0];
        }]];
    }
    [a addAction:[UIAlertAction actionWithTitle:@"Desactivar" style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *accion) {
        [self->_temporizadorSueno invalidate];
        self->_temporizadorSueno = nil;
        [self avisar:@"Temporizador desactivado"];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel handler:nil]];
    [self presentarAccion:a];
}

- (void)programarSueno:(NSTimeInterval)segundos {
    [_temporizadorSueno invalidate];
    _temporizadorSueno = [NSTimer scheduledTimerWithTimeInterval:segundos
                                                          target:self
                                                        selector:@selector(sonarSueno:)
                                                        userInfo:nil
                                                         repeats:NO];
    [self avisar:[NSString stringWithFormat:@"Se pausará en %d min", (int)(segundos / 60.0)]];
}

- (void)sonarSueno:(NSTimer *)temporizador {
    _temporizadorSueno = nil;
    [self pausar];
    [self avisar:@"Temporizador: reproducción pausada"];
}

#pragma mark - Avisos

- (void)avisar:(NSString *)texto {
    if (!_lblAviso) return;
    _lblAviso.text = texto;
    _lblAviso.hidden = NO;
    _lblAviso.alpha = 1.0;
    [self.view bringSubviewToFront:_lblAviso];
    [_temporizadorAviso invalidate];
    _temporizadorAviso = [NSTimer scheduledTimerWithTimeInterval:2.4
                                                          target:self
                                                        selector:@selector(ocultarAviso:)
                                                        userInfo:nil
                                                         repeats:NO];
}

- (void)ocultarAviso:(NSTimer *)temporizador {
    _temporizadorAviso = nil;
    [UIView animateWithDuration:0.25 animations:^{
        self->_lblAviso.alpha = 0.0;
    } completion:^(BOOL terminado) {
        self->_lblAviso.hidden = YES;
    }];
}

#pragma mark - Descargas

- (void)descargarVideo {
    if (_esDirecto || _esClip || _rutaLocal.length) {
        [self avisar:@"Solo se pueden descargar VODs"];
        return;
    }
    NSMutableArray *nombres = [NSMutableArray array];
    for (NSDictionary *v in _variantes) {
        NSString *nombre = v[@"nombre"];
        if (nombre.length && ![nombres containsObject:nombre]) [nombres addObject:nombre];
    }

    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Descargar vídeo"
        message:@"Elige la calidad. La descarga sigue aunque cierres el reproductor."
        preferredStyle:UIAlertControllerStyleActionSheet];
    [a addAction:[UIAlertAction actionWithTitle:@"Auto (mejor hasta 720p)"
        style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *accion) { [self pedirCarpetaParaCalidad:@"Auto"]; }]];
    for (NSString *nombre in nombres) {
        [a addAction:[UIAlertAction actionWithTitle:nombre style:UIAlertActionStyleDefault
            handler:^(UIAlertAction *accion) { [self pedirCarpetaParaCalidad:nombre]; }]];
    }
    [a addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel handler:nil]];
    [self presentarAccion:a];
}

- (void)pedirCarpetaParaCalidad:(NSString *)calidad {
    NSString *carpeta = [ITDownloadManager carpetaDeDescargas];
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Carpeta de destino"
        message:@"Ruta donde se guardará el vídeo. Por defecto: /var/mobile/Media/iTwitch"
        preferredStyle:UIAlertControllerStyleAlert];
    [a addTextFieldWithConfigurationHandler:^(UITextField *campo) {
        campo.text = carpeta;
        campo.autocapitalizationType = UITextAutocapitalizationTypeNone;
        campo.autocorrectionType = UITextAutocorrectionTypeNo;
        campo.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    [a addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"Descargar" style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *accion) {
        NSString *ruta = [a.textFields.firstObject.text stringByTrimmingCharactersInSet:
                          [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (ruta.length == 0) ruta = [ITDownloadManager carpetaDeDescargas];
        [ITDownloadManager guardarCarpetaDeDescargas:ruta];
        ITDescarga *descarga = [[ITDownloadManager compartida] descargarVideo:self->_video
                                                                      calidad:calidad
                                                                      carpeta:ruta];
        [self avisar:(descarga ? @"Descarga añadida · Perfil → Descargas"
                               : @"No se pudo añadir la descarga")];
    }]];
    [self presentViewController:a animated:YES completion:nil];
}

#pragma mark - Calidad y velocidad

- (void)elegirCalidad {
    if (_variantes.count == 0) return;
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Calidad"
        message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [a addAction:[UIAlertAction actionWithTitle:@"Auto" style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *accion) {
        if (self->_esClip) {
            NSDictionary *mejor = [self mejorCalidadDe:self->_clip.calidades];
            NSString *url = [ITPlayback urlClip:mejor[@"url"]
                                          firma:self->_clip.firma
                                          token:self->_clip.token];
            [self cambiarAURL:url variante:nil];
        } else {
            [self cambiarAURL:self->_urlMaster variante:nil];
        }
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
    [_btnCalidad usarTexto:variante[@"nombre"] ?: @"Auto"];
    double actual = CMTimeGetSeconds(_player.currentTime);
    BOOL estaba = _player.rate > 0;
    _reproducirAlCargar = estaba;
    [self prepararURL:url];
    if (!_esDirecto && actual > 1) {
        [_player seekToTime:CMTimeMakeWithSeconds(actual, 600)];
    }
}

- (float)velocidadElegida {
    id valor = [[NSUserDefaults standardUserDefaults] objectForKey:@"itwitch_velocidad"];
    if (valor == nil) return 1.0f;
    float v = [valor floatValue];
    return (v >= 0.5f && v <= 2.0f) ? v : 1.0f;
}

- (void)elegirVelocidad {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Velocidad"
        message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    NSArray *velocidades = @[@0.5, @1.0, @1.25, @1.5, @2.0];
    for (NSNumber *n in velocidades) {
        NSString *titulo = [NSString stringWithFormat:@"%.2g×", n.doubleValue];
        [a addAction:[UIAlertAction actionWithTitle:titulo style:UIAlertActionStyleDefault
            handler:^(UIAlertAction *accion) {
            [self aplicarVelocidad:n.floatValue];
        }]];
    }
    [a addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel handler:nil]];
    [self presentarAccion:a];
}

- (void)aplicarVelocidad:(float)velocidad {
    [[NSUserDefaults standardUserDefaults] setFloat:velocidad forKey:@"itwitch_velocidad"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    if (_player.rate > 0) [_player setRate:velocidad];
    [_btnVelocidad usarTexto:[NSString stringWithFormat:@"%.2g×", velocidad]];
    [self avisar:[NSString stringWithFormat:@"Velocidad %.2g×", velocidad]];
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
    if (_esClip || _rutaLocal.length) {
        [self avisar:@"El chat no está disponible aquí"];
        return;
    }
    if (!_chatCargado) [self crearChat];
    _chatActivo = !_chatActivo;
    [ITSettingsViewController guardarChatActivo:_chatActivo];
    _chat.view.hidden = !_chatActivo;
    [_btnChat destacar:_chatActivo];
    [self.view setNeedsLayout];
    [self avisar:_chatActivo ? @"Chat visible" : @"Chat oculto"];
}

- (void)crearChat {
    if (_chatCargado) return;
    if (_esDirecto) {
        _chat = [[ITChatViewController alloc] initWithCanal:_stream.login];
    } else if (_video) {
        _chat = [[ITChatViewController alloc] initWithVideo:_video.identificador
                                                   duracion:_video.duracion];
    } else {
        return;
    }
    [self addChildViewController:_chat];
    [_chat didMoveToParentViewController:self];
    [self.view addSubview:_chat.view];
    _chatCargado = YES;
    [self.view bringSubviewToFront:_chat.view];
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

// Los toques sobre botones o sobre las propias barras no deben ocultar los
// controles; solo el fondo del video los alterna.
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesto shouldReceiveTouch:(UITouch *)toque {
    UIView *vista = toque.view;
    while (vista && vista != _controles) {
        if ([vista isKindOfClass:[UIControl class]]) return NO;
        if (vista == _barraInferior || vista == _barraSuperior) return NO;
        vista = vista.superview;
    }
    return YES;
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
    [centro.playCommand removeTarget:self];
    [centro.pauseCommand removeTarget:self];
    [centro.togglePlayPauseCommand removeTarget:self];
    [centro.skipForwardCommand removeTarget:self];
    [centro.skipBackwardCommand removeTarget:self];
    [centro.playCommand addTarget:self action:@selector(comandoPlay:)];
    [centro.pauseCommand addTarget:self action:@selector(comandoPausa:)];
    [centro.togglePlayPauseCommand addTarget:self action:@selector(comandoAlternar:)];
    [centro.skipForwardCommand addTarget:self action:@selector(comandoAdelante:)];
    [centro.skipBackwardCommand addTarget:self action:@selector(comandoAtras:)];
}

- (MPRemoteCommandHandlerStatus)comandoPlay:(MPRemoteCommandEvent *)evento {
    dispatch_async(dispatch_get_main_queue(), ^{ [self reproducir]; });
    return MPRemoteCommandHandlerStatusSuccess;
}
- (MPRemoteCommandHandlerStatus)comandoPausa:(MPRemoteCommandEvent *)evento {
    dispatch_async(dispatch_get_main_queue(), ^{ [self pausar]; });
    return MPRemoteCommandHandlerStatusSuccess;
}
- (MPRemoteCommandHandlerStatus)comandoAlternar:(MPRemoteCommandEvent *)evento {
    dispatch_async(dispatch_get_main_queue(), ^{ [self alternarReproduccion]; });
    return MPRemoteCommandHandlerStatusSuccess;
}
- (MPRemoteCommandHandlerStatus)comandoAdelante:(MPRemoteCommandEvent *)evento {
    dispatch_async(dispatch_get_main_queue(), ^{ [self saltar:10]; });
    return MPRemoteCommandHandlerStatusSuccess;
}
- (MPRemoteCommandHandlerStatus)comandoAtras:(MPRemoteCommandEvent *)evento {
    dispatch_async(dispatch_get_main_queue(), ^{ [self saltar:-10]; });
    return MPRemoteCommandHandlerStatusSuccess;
}

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
    if (_tituloLocal.length) return _tituloLocal;
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
    [_temporizadorSueno invalidate];
    _temporizadorSueno = nil;
    [_temporizadorAviso invalidate];
    _temporizadorAviso = nil;
    if (_observadorTiempo) {
        [_player removeTimeObserver:_observadorTiempo];
        _observadorTiempo = nil;
    }
    if (_item && _observadorEstado) {
        [_item removeObserver:self forKeyPath:@"status"];
        _observadorEstado = nil;
    }
    [_chat detener];
    MPRemoteCommandCenter *centro = [MPRemoteCommandCenter sharedCommandCenter];
    [centro.playCommand removeTarget:self];
    [centro.pauseCommand removeTarget:self];
    [centro.togglePlayPauseCommand removeTarget:self];
    [centro.skipForwardCommand removeTarget:self];
    [centro.skipBackwardCommand removeTarget:self];
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
    if (_esDirecto || _reanudado) return;
    if (_esClip) {
        _reanudado = YES;
        if (_posicionInicial > 1.0 && (_duracion <= 0 || _posicionInicial < _duracion - 1.0)) {
            [_player seekToTime:CMTimeMakeWithSeconds(_posicionInicial, 600)
              toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
        }
        return;
    }
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
