#import "ITFollowingViewController.h"
#import "ITTheme.h"
#import "ITUtil.h"
#import "ITCells.h"
#import "ITApi.h"
#import "ITSession.h"
#import "ITLoginViewController.h"
#import "ITChannelViewController.h"

@implementation ITFollowingViewController {
    NSArray *_vivos;
    NSArray *_apagados;
    UIView *_vacio;
    BOOL _cargando;
    NSTimer *_refresco;
}

- (instancetype)init {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        self.title = @"Siguiendo";
        self.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Siguiendo"
                                                        image:[ITTheme icono:@"canal" lado:26]
                                                          tag:3];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.backgroundColor = [ITTheme fondo];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.rowHeight = 68;

    UIRefreshControl *refresco = [[UIRefreshControl alloc] init];
    [refresco addTarget:self action:@selector(recargar) forControlEvents:UIControlEventValueChanged];
    self.refreshControl = refresco;

    [self prepararVacio];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self recargar];
    [_refresco invalidate];
    _refresco = [NSTimer scheduledTimerWithTimeInterval:60.0 target:self
                                               selector:@selector(recargar)
                                               userInfo:nil repeats:YES];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [_refresco invalidate];
    _refresco = nil;
}

- (void)prepararVacio {
    _vacio = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 260)];
    _vacio.backgroundColor = [ITTheme fondo];

    UILabel *emoji = ITLabel(@"♥", [UIFont systemFontOfSize:52.0 weight:UIFontWeightLight],
                              [ITTheme acento]);
    emoji.textAlignment = NSTextAlignmentCenter;
    emoji.frame = CGRectMake(0, 34, _vacio.bounds.size.width, 62);
    [_vacio addSubview:emoji];

    UILabel *titulo = ITLabel(@"Sigue a tus canales", [UIFont systemFontOfSize:19.0 weight:UIFontWeightBold],
                              [ITTheme textoPrimario]);
    titulo.textAlignment = NSTextAlignmentCenter;
    titulo.frame = CGRectMake(20, 104, _vacio.bounds.size.width - 40, 26);
    [_vacio addSubview:titulo];

    UILabel *detalle = ITLabel(@"Entra en Twitch para ver aquí los canales que sigues.",
                               [ITTheme fuenteCuerpo], [ITTheme textoSecundario]);
    detalle.textAlignment = NSTextAlignmentCenter;
    detalle.numberOfLines = 2;
    detalle.frame = CGRectMake(34, 134, _vacio.bounds.size.width - 68, 40);
    [_vacio addSubview:detalle];

    UIButton *entrar = [UIButton buttonWithType:UIButtonTypeSystem];
    [entrar setTitle:@"Entrar en Twitch" forState:UIControlStateNormal];
    [entrar setTitleColor:[ITTheme textoSobreAcento] forState:UIControlStateNormal];
    entrar.backgroundColor = [ITTheme acento];
    entrar.titleLabel.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
    ITRedondear(entrar, 18.0);
    entrar.frame = CGRectMake((_vacio.bounds.size.width - 190) / 2, 188, 190, 36);
    [entrar addTarget:self action:@selector(entrar) forControlEvents:UIControlEventTouchUpInside];
    [_vacio addSubview:entrar];
}

- (void)recargar {
    if (![[ITSession compartida] haySesion]) {
        _vivos = @[];
        _apagados = @[];
        self.tableView.tableHeaderView = _vacio;
        [self.tableView reloadData];
        return;
    }
    if (_cargando) return;
    _cargando = YES;
    self.tableView.tableHeaderView = nil;

    __typeof(self) debil = self;
    [[ITApi compartida] seguidos:^(NSArray *elementos, NSError *error) {
        debil->_cargando = NO;
        [debil.refreshControl endRefreshing];
        if (!elementos) {
            [debil.tableView reloadData];
            return;
        }
        NSMutableArray *vivos = [NSMutableArray array];
        NSMutableArray *apagados = [NSMutableArray array];
        for (ITChannel *c in elementos) {
            if (c.enDirecto) [vivos addObject:c];
            else [apagados addObject:c];
        }
        debil->_vivos = vivos;
        debil->_apagados = apagados;
        [debil.tableView reloadData];
    }];
}

- (void)entrar {
    ITLoginViewController *login = [[ITLoginViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:login];
    [self presentViewController:nav animated:YES completion:nil];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return (_vivos.count > 0) + (_apagados.count > 0);
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (_vivos.count == 0) return _apagados.count;
    return section == 0 ? _vivos.count : _apagados.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (_vivos.count == 0) return _apagados.count ? @"DESCONECTADOS" : nil;
    return section == 0 ? @"EN DIRECTO" : @"DESCONECTADOS";
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return [self tableView:tableView titleForHeaderInSection:section] ? 32.0 : 0.0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ITChannelCell *c = [tableView dequeueReusableCellWithIdentifier:@"canal"];
    if (!c) c = [[ITChannelCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"canal"];
    ITChannel *canal = nil;
    if (_vivos.count > 0) {
        canal = indexPath.section == 0 ? _vivos[indexPath.row] : _apagados[indexPath.row];
    } else {
        canal = _apagados[indexPath.row];
    }
    [c configurarConCanal:canal];
    return c;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    ITChannel *canal = nil;
    if (_vivos.count > 0) {
        canal = indexPath.section == 0 ? _vivos[indexPath.row] : _apagados[indexPath.row];
    } else {
        canal = _apagados[indexPath.row];
    }
    ITChannelViewController *vc = [[ITChannelViewController alloc] initWithLogin:canal.login];
    [self.navigationController pushViewController:vc animated:YES];
}

@end
