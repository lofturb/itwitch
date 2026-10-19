#import "ITProfileViewController.h"
#import "ITTheme.h"
#import "ITUtil.h"
#import "ITApi.h"
#import "ITSession.h"
#import "ITLoginViewController.h"
#import "ITSettingsViewController.h"
#import "ITImageCache.h"

@implementation ITProfileViewController {
    ITChannel *_usuario;
    UIView *_cabecera;
    UIImageView *_avatar;
    UILabel *_nombre;
    UILabel *_login;
    UILabel *_seguidores;
    UIButton *_entrar;
}

- (instancetype)init {
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        self.title = @"Perfil";
        self.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Perfil"
                                                        image:[ITTheme icono:@"ajustes" lado:26]
                                                          tag:4];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.backgroundColor = [ITTheme fondo];
    self.tableView.separatorColor = [ITTheme borde];
    self.navigationItem.title = @"Perfil";
    [self montarCabecera];
}

- (void)montarCabecera {
    _cabecera = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 154)];
    _cabecera.backgroundColor = [ITTheme fondo];

    _avatar = [[UIImageView alloc] init];
    _avatar.frame = CGRectMake(16, 14, 64, 64);
    _avatar.contentMode = UIViewContentModeScaleAspectFill;
    _avatar.clipsToBounds = YES;
    _avatar.layer.cornerRadius = 32.0;
    _avatar.backgroundColor = [ITTheme superficie];
    [_cabecera addSubview:_avatar];

    _nombre = ITLabel(@"Sin sesión", [UIFont systemFontOfSize:19.0 weight:UIFontWeightBold],
                      [ITTheme textoPrimario]);
    _nombre.frame = CGRectMake(94, 20, _cabecera.bounds.size.width - 106, 24);
    [_cabecera addSubview:_nombre];

    _login = ITLabel(@"Entra para seguir canales y chatear", [ITTheme fuenteCuerpo],
                     [ITTheme textoSecundario]);
    _login.frame = CGRectMake(94, 45, _cabecera.bounds.size.width - 106, 18);
    [_cabecera addSubview:_login];

    _seguidores = ITLabel(@"", [ITTheme fuenteMenuda], [ITTheme textoSecundario]);
    _seguidores.frame = CGRectMake(94, 65, _cabecera.bounds.size.width - 106, 16);
    [_cabecera addSubview:_seguidores];

    _entrar = [UIButton buttonWithType:UIButtonTypeSystem];
    [_entrar setTitle:@"Entrar" forState:UIControlStateNormal];
    [_entrar setTitleColor:[ITTheme textoSobreAcento] forState:UIControlStateNormal];
    _entrar.backgroundColor = [ITTheme acento];
    _entrar.titleLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
    ITRedondear(_entrar, 15.0);
    _entrar.frame = CGRectMake(16, 106, 104, 30);
    [_entrar addTarget:self action:@selector(entrar) forControlEvents:UIControlEventTouchUpInside];
    [_cabecera addSubview:_entrar];

    self.tableView.tableHeaderView = _cabecera;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self actualizar];
}

- (void)actualizar {
    if (![[ITSession compartida] haySesion]) {
        _usuario = nil;
        [self pintar];
        return;
    }
    __weak typeof(self) debil = self;
    [[ITApi compartida] usuarioActual:^(id objeto, NSError *error) {
        if ([objeto isKindOfClass:[ITChannel class]]) debil->_usuario = objeto;
        [debil pintar];
    }];
}

- (void)pintar {
    if (_usuario) {
        _nombre.text = _usuario.nombre;
        _login.text = [NSString stringWithFormat:@"@%@", _usuario.login];
        _seguidores.text = [NSString stringWithFormat:@"%@ seguidores",
                            ITMillones(_usuario.seguidores)];
        _avatar.image = nil;
        [ITImageCache cargarURL:ITImagen(_usuario.avatar, 128, 128) en:_avatar];
        [_entrar setTitle:@"Cerrar sesión" forState:UIControlStateNormal];
        _entrar.backgroundColor = [ITTheme superficieAlta];
        [_entrar setTitleColor:[ITTheme textoPrimario] forState:UIControlStateNormal];
    } else {
        _nombre.text = @"Sin sesión";
        _login.text = @"Entra para seguir canales y chatear";
        _seguidores.text = @"";
        _avatar.image = [ITTheme icono:@"canal" lado:32];
        [_entrar setTitle:@"Entrar" forState:UIControlStateNormal];
        _entrar.backgroundColor = [ITTheme acento];
        [_entrar setTitleColor:[ITTheme textoSobreAcento] forState:UIControlStateNormal];
    }
    [self.tableView reloadData];
}

- (void)entrar {
    if ([[ITSession compartida] haySesion]) {
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Cerrar sesión"
            message:@"Se borrará el token de este dispositivo." preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel handler:nil]];
        [a addAction:[UIAlertAction actionWithTitle:@"Cerrar sesión" style:UIAlertActionStyleDestructive
            handler:^(UIAlertAction *accion) {
            [[ITSession compartida] cerrarSesion];
            [self actualizar];
        }]];
        [self presentViewController:a animated:YES completion:nil];
        return;
    }
    ITLoginViewController *login = [[ITLoginViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:login];
    [self presentViewController:nav animated:YES completion:nil];
}

#pragma mark - Tabla

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 2; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? 2 : 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == 0 ? @"Ajustes" : @"Información";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *simple = @"simple";
    UITableViewCell *c = [tableView dequeueReusableCellWithIdentifier:simple];
    if (!c) {
        c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:simple];
        c.backgroundColor = [ITTheme superficie];
        c.textLabel.textColor = [ITTheme textoPrimario];
        c.textLabel.font = [ITTheme fuenteTituloLista];
        c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            c.textLabel.text = @"Ajustes";
            c.imageView.image = [ITTheme icono:@"ajustes" lado:20];
        } else {
            c.textLabel.text = @"Seguidos";
            c.imageView.image = [ITTheme icono:@"canal" lado:20];
        }
    } else {
        c.textLabel.text = @"Acerca de iTwitch";
        c.imageView.image = [ITTheme icono:@"marca" lado:20];
    }
    c.imageView.tintColor = [ITTheme acento];
    return c;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 0 && indexPath.row == 0) {
        ITSettingsViewController *vc = [[ITSettingsViewController alloc] init];
        [self.navigationController pushViewController:vc animated:YES];
    } else if (indexPath.section == 0 && indexPath.row == 1) {
        [self.tabBarController setSelectedIndex:3];
    } else {
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"iTwitch 1.0.0"
            message:@"Cliente no oficial de Twitch para iOS 9.3.5 (armv7).\n\nNo está afiliado a Twitch Interactive, Inc."
            preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"Cerrar" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:a animated:YES completion:nil];
    }
}

@end
