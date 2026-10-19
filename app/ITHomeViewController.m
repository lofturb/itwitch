#import "ITHomeViewController.h"
#import "ITTheme.h"
#import "ITUtil.h"
#import "ITCells.h"
#import "ITApi.h"
#import "ITCategoryViewController.h"
#import "ITPlayerViewController.h"
#import "ITLoginViewController.h"
#import "ITSession.h"
#import "ITNotifications.h"

@implementation ITHomeViewController {
    NSArray *_juegos;
    NSArray *_directos;
    BOOL _cargando;
    UILabel *_vacio;
}

- (instancetype)init {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        self.title = @"Inicio";
        self.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Inicio"
                                                        image:[ITTheme icono:@"inicio" lado:26]
                                                          tag:0];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.backgroundColor = [ITTheme fondo];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.rowHeight = 72;
    self.tableView.contentInset = UIEdgeInsetsMake(4, 0, 12, 0);
    self.navigationItem.title = @"iTwitch";
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithImage:[ITTheme icono:@"campana" lado:22]
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(abrirNotificaciones)];

    UIRefreshControl *refresco = [[UIRefreshControl alloc] init];
    [refresco addTarget:self action:@selector(recargar) forControlEvents:UIControlEventValueChanged];
    self.refreshControl = refresco;

    _vacio = ITLabel(@"Cargando Twitch…", [ITTheme fuenteCuerpo], [ITTheme textoSecundario]);
    _vacio.textAlignment = NSTextAlignmentCenter;
    _vacio.frame = CGRectMake(0, 0, 320, 40);
    self.tableView.tableFooterView = _vacio;

    [self recargar];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
    NSUInteger nuevos = [[ITNotifications compartida] nuevos].count;
    self.tabBarItem.badgeValue = nuevos ? [NSString stringWithFormat:@"%lu", (unsigned long)nuevos] : nil;
}

- (void)recargar {
    if (_cargando) return;
    _cargando = YES;
    _vacio.text = @"Cargando Twitch…";

    __typeof(self) debil = self;
    [[ITApi compartida] categorias:18 completion:^(NSArray *elementos, NSError *error) {
        if (elementos) debil->_juegos = elementos;
        [debil terminarCarga];
    }];
    [[ITApi compartida] directos:20 completion:^(NSArray *elementos, NSError *error) {
        if (elementos) debil->_directos = elementos;
        if (error) debil->_vacio.text = error.localizedDescription;
        [debil terminarCarga];
    }];
}

- (void)terminarCarga {
    _cargando = NO;
    [self.refreshControl endRefreshing];
    [self.tableView reloadData];
    if (_juegos.count + _directos.count == 0) {
        _vacio.text = @"No hay datos. Desliza para recargar.";
    } else {
        _vacio.text = @"";
    }
}

- (void)abrirNotificaciones {
    if (![[ITSession compartida] haySesion]) {
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Notificaciones"
            message:@"Inicia sesión para ver los directos de tus canales seguidos."
            preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"Entrar" style:UIAlertActionStyleDefault
            handler:^(UIAlertAction *accion) {
            ITLoginViewController *vc = [[ITLoginViewController alloc] init];
            UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
            [self presentViewController:nav animated:YES completion:nil];
        }]];
        [a addAction:[UIAlertAction actionWithTitle:@"Cerrar" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:a animated:YES completion:nil];
        return;
    }

    NSArray *nuevos = [[ITNotifications compartida] nuevos];
    UIAlertController *a;
    if (nuevos.count == 0) {
        a = [UIAlertController alertControllerWithTitle:@"Notificaciones"
            message:[ITNotifications avisosActivos]
                ? @"No hay nuevos directos de tus canales seguidos."
                : @"Los avisos están desactivados. Actívalos en Ajustes para que iTwitch te avise de los nuevos directos."
            preferredStyle:UIAlertControllerStyleAlert];
    } else {
        NSMutableString *texto = [NSMutableString stringWithString:
                                  @"Estos canales seguidos se han puesto en directo:\n\n"];
        NSUInteger limite = MIN(nuevos.count, (NSUInteger)8);
        for (NSUInteger i = 0; i < limite; i++) {
            ITChannel *c = nuevos[i];
            [texto appendFormat:@"• %@", c.nombre.length ? c.nombre : c.login];
            if (c.directoTitulo.length) [texto appendFormat:@" — %@", c.directoTitulo];
            [texto appendString:@"\n"];
        }
        if (nuevos.count > limite) {
            [texto appendFormat:@"\nY %lu más.", (unsigned long)(nuevos.count - limite)];
        }
        a = [UIAlertController alertControllerWithTitle:@"Nuevos directos"
                                                message:texto
                                         preferredStyle:UIAlertControllerStyleAlert];
    }

    [a addAction:[UIAlertAction actionWithTitle:@"Ver Siguiendo" style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *accion) {
        [[ITNotifications compartida] limpiarNuevos];
        self.tabBarItem.badgeValue = nil;
        self.tabBarController.selectedIndex = 3;
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Cerrar" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

#pragma mark - Tabla

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 2; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? _juegos.count : _directos.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) return 72.0;
    CGFloat ancho = tableView.bounds.size.width;
    return MIN(ancho * 9.0 / 16.0, 240.0) + 70.0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return _juegos.count ? @"Categorías" : nil;
    return _directos.count ? @"Directos para ti" : nil;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    NSString *titulo = [self tableView:tableView titleForHeaderInSection:section];
    if (!titulo) return nil;
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, 34)];
    v.backgroundColor = [ITTheme fondo];
    UILabel *l = ITLabel(titulo, [ITTheme fuenteTituloFila], [ITTheme textoPrimario]);
    l.frame = CGRectMake(14, 10, v.bounds.size.width - 28, 22);
    [v addSubview:l];
    return v;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return [self tableView:tableView titleForHeaderInSection:section] ? 34.0 : 0.0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        ITGameCell *c = [tableView dequeueReusableCellWithIdentifier:@"juego"];
        if (!c) c = [[ITGameCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"juego"];
        [c configurarConJuego:_juegos[indexPath.row]];
        return c;
    }
    ITStreamCell *c = [tableView dequeueReusableCellWithIdentifier:@"directo"];
    if (!c) c = [[ITStreamCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"directo"];
    [c configurarConStream:_directos[indexPath.row]];
    return c;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 0) {
        ITCategoryViewController *vc = [[ITCategoryViewController alloc] initWithJuego:_juegos[indexPath.row]];
        [self.navigationController pushViewController:vc animated:YES];
    } else {
        ITStream *s = _directos[indexPath.row];
        ITPlayerViewController *p = [[ITPlayerViewController alloc] initWithStream:s];
        [self.navigationController pushViewController:p animated:YES];
    }
}

@end
