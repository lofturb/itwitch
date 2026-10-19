#import "ITDiagnosticsViewController.h"
#import "ITTheme.h"
#import "ITUtil.h"
#import "ITApi.h"
#import "ITSession.h"
#import "ITPlayback.h"

@implementation ITDiagnosticsViewController {
    NSArray *_pasos;
    NSMutableArray *_estados;
    NSMutableArray *_detalles;
    BOOL _ejecutado;
}

- (instancetype)init {
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        _pasos = @[
            @"GraphQL de Twitch",
            @"Lista de directos",
            @"Categorías",
            @"Sugerencias de búsqueda",
            @"Token de reproducción",
            @"Master HLS de un directo",
            @"Sesión de usuario"
        ];
        _estados = [NSMutableArray array];
        _detalles = [NSMutableArray array];
        for (NSUInteger i = 0; i < _pasos.count; i++) {
            [_estados addObject:@"—"];
            [_detalles addObject:@""];
        }
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Diagnóstico";
    self.tableView.backgroundColor = [ITTheme fondo];
    self.tableView.separatorColor = [ITTheme borde];
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"Compartir" style:UIBarButtonItemStylePlain
                                        target:self action:@selector(compartir)];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (_ejecutado) return;
    _ejecutado = YES;
    [self ejecutar];
}

- (void)marcar:(NSUInteger)indice estado:(NSString *)estado detalle:(NSString *)detalle {
    if (indice >= _estados.count) return;
    _estados[indice] = estado;
    _detalles[indice] = detalle ?: @"";
    [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:indice inSection:0]]
                          withRowAnimation:UITableViewRowAnimationNone];
}

- (void)ejecutar {
    __typeof(self) debil = self;

    [[ITApi compartida] directos:1 completion:^(NSArray *elementos, NSError *error) {
        if (error) {
            [debil marcar:0 estado:@"FALLO" detalle:error.localizedDescription];
            [debil marcar:1 estado:@"FALLO" detalle:error.localizedDescription];
        } else {
            [debil marcar:0 estado:@"OK" detalle:[NSString stringWithFormat:@"%lu directos", (unsigned long)elementos.count]];
            [debil marcar:1 estado:@"OK" detalle:elementos.count ? @"Datos recibidos" : @"Lista vacía"];
        }
    }];

    [[ITApi compartida] categorias:5 completion:^(NSArray *elementos, NSError *error) {
        [debil marcar:2 estado:(error ? @"FALLO" : @"OK")
            detalle:(error ? error.localizedDescription : [NSString stringWithFormat:@"%lu categorías", (unsigned long)elementos.count])];
    }];

    [[ITApi compartida] sugerencias:@"xqc" completion:^(NSArray *elementos, NSError *error) {
        [debil marcar:3 estado:(error ? @"FALLO" : @"OK")
            detalle:(error ? error.localizedDescription : [NSString stringWithFormat:@"%lu sugerencias", (unsigned long)elementos.count])];
    }];

    [[ITApi compartida] tokenDirecto:@"xqc" completion:^(NSString *valor, NSString *firma, NSError *error) {
        [debil marcar:4 estado:(error ? @"FALLO" : @"OK")
            detalle:(error ? error.localizedDescription : @"Token recibido")];
        if (!error) {
            [ITPlayback urlDirecto:@"xqc" completion:^(NSString *url, NSError *error2) {
                if (error2) {
                    [debil marcar:5 estado:@"FALLO" detalle:error2.localizedDescription];
                    return;
                }
                [ITPlayback variantesDeMaster:url completion:^(NSArray *variantes, NSError *error3) {
                    if (error3) {
                        [debil marcar:5 estado:@"FALLO" detalle:error3.localizedDescription];
                    } else {
                        [debil marcar:5 estado:(variantes.count ? @"OK" : @"FALLO")
                            detalle:[NSString stringWithFormat:@"%lu calidades", (unsigned long)variantes.count]];
                    }
                }];
            }];
        }
    }];

    if ([[ITSession compartida] haySesion]) {
        [[ITApi compartida] usuarioActual:^(id objeto, NSError *error) {
            ITChannel *c = [objeto isKindOfClass:[ITChannel class]] ? objeto : nil;
            [debil marcar:6 estado:(c ? @"OK" : @"FALLO")
                detalle:(c ? [NSString stringWithFormat:@"@%@", c.login] : (error.localizedDescription ?: @"Sin sesión"))];
        }];
    } else {
        [self marcar:6 estado:@"—" detalle:@"Sin sesión (no es un fallo)"];
    }
}

- (void)compartir {
    NSMutableString *texto = [NSMutableString stringWithFormat:@"iTwitch 1.0.0\n\n"];
    for (NSUInteger i = 0; i < _pasos.count; i++) {
        [texto appendFormat:@"%@: %@ %@\n", _pasos[i], _estados[i], _detalles[i]];
    }
    UIActivityViewController *a = [[UIActivityViewController alloc] initWithActivityItems:@[texto]
                                                                  applicationActivities:nil];
    [self presentViewController:a animated:YES completion:nil];
}

#pragma mark - Tabla

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 1; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _pasos.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return @"Comprobaciones de red";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return @"Si todo está en OK y el vídeo no se reproduce, instala el perfil de certificados del repositorio y reinicia el dispositivo.";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *simple = @"diag";
    UITableViewCell *c = [tableView dequeueReusableCellWithIdentifier:simple];
    if (!c) {
        c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:simple];
        c.backgroundColor = [ITTheme superficie];
        c.textLabel.textColor = [ITTheme textoPrimario];
        c.detailTextLabel.textColor = [ITTheme textoSecundario];
        c.detailTextLabel.numberOfLines = 2;
        c.textLabel.font = [ITTheme fuenteTituloLista];
        c.detailTextLabel.font = [ITTheme fuenteMenuda];
    }
    c.textLabel.text = _pasos[indexPath.row];
    NSString *estado = _estados[indexPath.row];
    NSString *detalle = _detalles[indexPath.row];
    c.detailTextLabel.text = detalle.length ? detalle : @"Pendiente";
    c.detailTextLabel.textColor = [estado isEqualToString:@"FALLO"] ? [UIColor redColor] :
        ([estado isEqualToString:@"OK"] ? [ITTheme acento] : [ITTheme textoSecundario]);
    return c;
}

@end
