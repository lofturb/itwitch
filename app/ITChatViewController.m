#import "ITChatViewController.h"
#import "ITTheme.h"
#import "ITUtil.h"
#import "ITModels.h"
#import "ITChatClient.h"
#import "ITApi.h"
#import "ITSession.h"

#pragma mark - Celda de chat

@interface ITChatCell : UITableViewCell
@property (nonatomic, strong) UILabel *texto;
+ (CGFloat)alturaParaMensaje:(ITChatMessage *)m ancho:(CGFloat)ancho;
- (void)configurarConMensaje:(ITChatMessage *)m;
@end

@implementation ITChatCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = [ITTheme fondo];
        self.contentView.backgroundColor = [ITTheme fondo];
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        _texto = [[UILabel alloc] init];
        _texto.numberOfLines = 0;
        [self.contentView addSubview:_texto];
    }
    return self;
}

+ (NSAttributedString *)atribuidoDeMensaje:(ITChatMessage *)m {
    UIColor *color = ITColorDeChat(m.color, m.nombre);
    NSMutableAttributedString *a = [[NSMutableAttributedString alloc] init];

    NSString *etiqueta = @"";
    if ([m.logins rangeOfString:@"mod"].location != NSNotFound) etiqueta = @"[MOD] ";
    else if ([m.logins rangeOfString:@"subscriber"].location != NSNotFound) etiqueta = @"[SUB] ";

    if (etiqueta.length) {
        [a appendAttributedString:[[NSAttributedString alloc] initWithString:etiqueta attributes:@{
            NSFontAttributeName : [UIFont systemFontOfSize:10.0 weight:UIFontWeightBold],
            NSForegroundColorAttributeName : [ITTheme textoSecundario]
        }]];
    }
    [a appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@: ", m.nombre]
        attributes:@{
            NSFontAttributeName : [UIFont systemFontOfSize:12.5 weight:UIFontWeightSemibold],
            NSForegroundColorAttributeName : color
        }]];
    [a appendAttributedString:[[NSAttributedString alloc] initWithString:m.texto ?: @"" attributes:@{
        NSFontAttributeName : [UIFont systemFontOfSize:12.5],
        NSForegroundColorAttributeName : m.esAccion ? color : [ITTheme textoPrimario]
    }]];
    return a;
}

+ (CGFloat)alturaParaMensaje:(ITChatMessage *)m ancho:(CGFloat)ancho {
    NSAttributedString *a = [self atribuidoDeMensaje:m];
    CGRect r = [a boundingRectWithSize:CGSizeMake(MAX(40.0, ancho - 20.0), CGFLOAT_MAX)
                              options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                              context:nil];
    return MAX(30.0, ceil(r.size.height) + 8.0);
}

- (void)configurarConMensaje:(ITChatMessage *)m {
    _texto.attributedText = [[self class] atribuidoDeMensaje:m];
    [self setNeedsLayout];
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat ancho = self.contentView.bounds.size.width;
    CGSize tam = [_texto sizeThatFits:CGSizeMake(ancho - 20, 999)];
    _texto.frame = CGRectMake(10, 4, ancho - 20, tam.height);
}
@end

#pragma mark - Controlador

@interface ITChatViewController () <UITableViewDataSource, UITableViewDelegate,
                                   UITextFieldDelegate, ITChatClientDelegado>
@end

@implementation ITChatViewController {
    UITableView *_tabla;
    UITextField *_campo;
    UIButton *_enviar;
    UIView *_barra;

    ITChatClient *_cliente;
    NSMutableArray *_mensajes;
    NSString *_canal;

    BOOL _esReplay;
    NSString *_videoID;
    double _duracion;
    NSArray *_replayTodos;
    NSUInteger _replayIndice;
    double _ultimoTiempo;
    UILabel *_aviso;
    BOOL _recargaPendiente;
    BOOL _recortePendiente;
    NSUInteger _filasTabla;
    NSUInteger _nuevosPendientes;
}

- (instancetype)initWithCanal:(NSString *)canal {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _mensajes = [NSMutableArray array];
        _cliente = [[ITChatClient alloc] init];
        _cliente.delegado = self;
        self.title = canal;
        _canal = [canal copy];
    }
    return self;
}

- (instancetype)initWithVideo:(NSString *)videoID duracion:(double)duracion {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _mensajes = [NSMutableArray array];
        _esReplay = YES;
        _videoID = [videoID copy];
        _duracion = duracion;
        _replayTodos = @[];
        _replayIndice = 0;
        _ultimoTiempo = -1;
        self.title = @"Chat del vídeo";
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [ITTheme fondo];

    _tabla = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    _tabla.backgroundColor = [ITTheme fondo];
    _tabla.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tabla.dataSource = self;
    _tabla.delegate = self;
    _tabla.rowHeight = UITableViewAutomaticDimension;
    _tabla.estimatedRowHeight = 36;
    _tabla.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    [self.view addSubview:_tabla];

    _aviso = ITLabel(@"", [ITTheme fuenteMenuda], [ITTheme textoSecundario]);
    _aviso.textAlignment = NSTextAlignmentCenter;
    _aviso.numberOfLines = 2;
    _aviso.frame = CGRectMake(8, 8, self.view.bounds.size.width - 16, 34);
    [self.view addSubview:_aviso];

    if (!_esReplay) {
        _barra = [[UIView alloc] initWithFrame:CGRectMake(0, self.view.bounds.size.height - 44,
                                                          self.view.bounds.size.width, 44)];
        _barra.backgroundColor = [ITTheme superficie];
        [self.view addSubview:_barra];

        _campo = [[UITextField alloc] initWithFrame:CGRectMake(10, 6, _barra.bounds.size.width - 70, 32)];
        _campo.backgroundColor = [ITTheme superficieAlta];
        _campo.textColor = [ITTheme textoPrimario];
        _campo.font = [ITTheme fuenteCuerpo];
        _campo.placeholder = @"Escribe un mensaje";
        _campo.delegate = self;
        _campo.returnKeyType = UIReturnKeySend;
        _campo.layer.cornerRadius = 16.0;
        _campo.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 1)];
        _campo.leftViewMode = UITextFieldViewModeAlways;
        [_barra addSubview:_campo];

        _enviar = [UIButton buttonWithType:UIButtonTypeSystem];
        [_enviar setTitle:@"Enviar" forState:UIControlStateNormal];
        [_enviar setTitleColor:[ITTheme acento] forState:UIControlStateNormal];
        _enviar.titleLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
        _enviar.frame = CGRectMake(_barra.bounds.size.width - 62, 6, 54, 32);
        [_enviar addTarget:self action:@selector(enviarMensaje) forControlEvents:UIControlEventTouchUpInside];
        [_barra addSubview:_enviar];

        [_cliente conectarCanal:_canal];
        [self observarTeclado];
    } else {
        _aviso.text = @"Cargando chat…";
        [self cargarReplay];
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat alto = self.view.bounds.size.height;
    CGFloat ancho = self.view.bounds.size.width;
    if (_esReplay) {
        _tabla.frame = CGRectMake(0, 0, ancho, alto);
        _barra.hidden = YES;
    } else {
        _tabla.frame = CGRectMake(0, 0, ancho, alto - 44);
        _barra.frame = CGRectMake(0, alto - 44, ancho, 44);
        _campo.frame = CGRectMake(10, 6, ancho - 70, 32);
        _enviar.frame = CGRectMake(ancho - 62, 6, 54, 32);
    }
}

- (void)observarTeclado {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(teclado:)
        name:UIKeyboardWillChangeFrameNotification object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_cliente desconectar];
}

- (void)teclado:(NSNotification *)n {
    CGRect marco = [n.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect enVista = [self.view convertRect:marco fromView:nil];
    CGFloat altoTeclado = MAX(0, self.view.bounds.size.height - enVista.origin.y);
    [UIView animateWithDuration:0.2 animations:^{
        _tabla.frame = CGRectMake(0, 0, self.view.bounds.size.width,
                                  self.view.bounds.size.height - 44 - altoTeclado);
        _barra.frame = CGRectMake(0, self.view.bounds.size.height - 44 - altoTeclado,
                                  self.view.bounds.size.width, 44);
    }];
    [self bajar];
}

#pragma mark - Envio

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self enviarMensaje];
    return YES;
}

- (void)enviarMensaje {
    NSString *texto = [_campo.text stringByTrimmingCharactersInSet:
                       [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (texto.length == 0) return;
    if (![[ITSession compartida] haySesion]) {
        [self sistema:@"Entra en Twitch para escribir en el chat."];
        return;
    }
    if (!_cliente.conectado) {
        [self sistema:@"El chat aún se está conectando. Espera un momento."];
        return;
    }
    [_cliente enviarMensaje:texto];
    _campo.text = @"";
}

#pragma mark - Replay

- (void)cargarReplay {
    __typeof(self) debil = self;
    [[ITApi compartida] comentariosVod:_videoID completion:^(NSArray *elementos, NSError *error) {
        if (error) {
            debil->_aviso.text = error.localizedDescription ?: @"No se pudo cargar el chat.";
            return;
        }
        debil->_replayTodos = elementos ?: @[];
        debil->_aviso.text = debil->_replayTodos.count ? @"" : @"Este vídeo no tiene chat.";
    }];
}

- (void)actualizarTiempo:(double)segundos {
    if (!_esReplay || _replayTodos.count == 0) return;
    if (segundos + 2.0 < _ultimoTiempo) {
        // El usuario ha retrocedido: se reconstruye desde el principio.
        [_mensajes removeAllObjects];
        _replayIndice = 0;
        _recargaPendiente = NO;
        _recortePendiente = NO;
        _nuevosPendientes = 0;
        _filasTabla = 0;
        [_tabla reloadData];
    }
    _ultimoTiempo = segundos;

    BOOL cambiado = NO;
    while (_replayIndice < _replayTodos.count) {
        ITChatMessage *m = _replayTodos[_replayIndice];
        if (m.offset > segundos) break;
        [_mensajes addObject:m];
        _replayIndice++;
        cambiado = YES;
    }
    if (cambiado) {
        if (_mensajes.count > 800) {
            [_mensajes removeObjectsInRange:NSMakeRange(0, _mensajes.count - 800)];
        }
        _recargaPendiente = NO;
        _recortePendiente = NO;
        _nuevosPendientes = 0;
        _filasTabla = _mensajes.count;
        [_tabla reloadData];
        [self bajar];
    }
}

- (void)detener {
    [_cliente desconectar];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Cliente

- (void)chatConectado {
    _aviso.text = @"";
}

- (void)chatRecibioMensaje:(ITChatMessage *)mensaje {
    [self agregar:mensaje];
}

- (void)chatAviso:(NSString *)texto {
    if (texto.length) [self sistema:texto];
}

- (void)chatFallo:(NSError *)error {
    if (error.localizedDescription.length) [self sistema:error.localizedDescription];
}

- (void)agregar:(ITChatMessage *)m {
    [_mensajes addObject:m];
    if (_mensajes.count > 800) {
        [_mensajes removeObjectAtIndex:0];
        _recortePendiente = YES;
    }
    _nuevosPendientes++;
    [self programarRecarga];
}

- (void)programarRecarga {
    if (_recargaPendiente) return;
    _recargaPendiente = YES;
    __typeof(self) debil = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        if (!debil) return;
        if (!debil->_recargaPendiente) return;
        debil->_recargaPendiente = NO;

        if (debil->_recortePendiente || debil->_filasTabla > debil->_mensajes.count) {
            debil->_recortePendiente = NO;
            debil->_nuevosPendientes = 0;
            [debil->_tabla reloadData];
            debil->_filasTabla = debil->_mensajes.count;
            [debil bajar];
            return;
        }

        NSUInteger nuevos = debil->_nuevosPendientes;
        debil->_nuevosPendientes = 0;
        if (nuevos == 0) return;

        NSUInteger primero = debil->_filasTabla;
        NSUInteger ultimo = debil->_mensajes.count;
        if (primero >= ultimo) {
            debil->_filasTabla = ultimo;
            return;
        }

        NSMutableArray *rutas = [NSMutableArray arrayWithCapacity:ultimo - primero];
        for (NSUInteger i = primero; i < ultimo; i++) {
            [rutas addObject:[NSIndexPath indexPathForRow:i inSection:0]];
        }
        [debil->_tabla beginUpdates];
        [debil->_tabla insertRowsAtIndexPaths:rutas withRowAnimation:UITableViewRowAnimationNone];
        [debil->_tabla endUpdates];
        debil->_filasTabla = ultimo;
        [debil bajar];
    });
}

- (void)sistema:(NSString *)texto {
    ITChatMessage *m = [[ITChatMessage alloc] init];
    m.nombre = @"iTwitch";
    m.texto = texto;
    m.color = @"#9146FF";
    [self agregar:m];
}

- (void)bajar {
    if (_mensajes.count == 0) return;
    NSIndexPath *ultimo = [NSIndexPath indexPathForRow:_mensajes.count - 1 inSection:0];
    [_tabla scrollToRowAtIndexPath:ultimo atScrollPosition:UITableViewScrollPositionBottom animated:NO];
}

#pragma mark - Tabla

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _mensajes.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    ITChatMessage *m = _mensajes[indexPath.row];
    return [ITChatCell alturaParaMensaje:m ancho:tableView.bounds.size.width];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ITChatCell *c = [tableView dequeueReusableCellWithIdentifier:@"chat"];
    if (!c) c = [[ITChatCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"chat"];
    [c configurarConMensaje:_mensajes[indexPath.row]];
    return c;
}

@end
