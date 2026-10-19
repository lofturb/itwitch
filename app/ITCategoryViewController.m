#import "ITCategoryViewController.h"
#import "ITTheme.h"
#import "ITUtil.h"
#import "ITCells.h"
#import "ITApi.h"
#import "ITPlayerViewController.h"

@implementation ITCategoryViewController {
    ITGame *_juego;
    NSArray *_directos;
    BOOL _cargando;
}

- (instancetype)initWithJuego:(ITGame *)juego {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        _juego = juego;
        self.title = juego.mostrado ?: @"Categoría";
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.backgroundColor = [ITTheme fondo];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.rowHeight = 80;
    self.navigationItem.title = _juego.mostrado ?: @"Categoría";

    UIRefreshControl *refresco = [[UIRefreshControl alloc] init];
    [refresco addTarget:self action:@selector(recargar) forControlEvents:UIControlEventValueChanged];
    self.refreshControl = refresco;

    UILabel *cabecera = ITLabel([NSString stringWithFormat:@"%@ · %@ espectadores",
                                 _juego.mostrado ?: @"", ITNumeroCorto(_juego.viewers)],
                                [ITTheme fuenteCuerpo], [ITTheme textoSecundario]);
    cabecera.textAlignment = NSTextAlignmentCenter;
    cabecera.frame = CGRectMake(0, 0, 320, 36);
    self.tableView.tableHeaderView = cabecera;

    [self recargar];
}

- (void)recargar {
    if (_cargando) return;
    _cargando = YES;
    __weak typeof(self) debil = self;
    [[ITApi compartida] directosDelJuego:_juego.mostrado ?: _juego.nombre
                              completion:^(NSArray *elementos, NSError *error) {
        debil->_cargando = NO;
        if (elementos) debil->_directos = elementos;
        [debil.refreshControl endRefreshing];
        [debil.tableView reloadData];
    }];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _directos.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ITStreamRowCell *c = [tableView dequeueReusableCellWithIdentifier:@"fila"];
    if (!c) c = [[ITStreamRowCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"fila"];
    [c configurarConStream:_directos[indexPath.row]];
    return c;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    ITPlayerViewController *p = [[ITPlayerViewController alloc] initWithStream:_directos[indexPath.row]];
    [self.navigationController pushViewController:p animated:YES];
}

@end
