#import "ITBrowseViewController.h"
#import "ITTheme.h"
#import "ITUtil.h"
#import "ITCells.h"
#import "ITApi.h"
#import "ITCategoryViewController.h"

@interface ITBrowseViewController () <UISearchBarDelegate>
@end

@implementation ITBrowseViewController {
    NSArray *_juegos;
    NSArray *_filtrados;
    UISearchBar *_buscador;
    BOOL _cargando;
}

- (instancetype)init {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        self.title = @"Explorar";
        self.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Explorar"
                                                        image:[ITTheme icono:@"tendencias" lado:26]
                                                          tag:1];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.backgroundColor = [ITTheme fondo];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.rowHeight = 72;
    self.navigationItem.title = @"Explorar";

    _buscador = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
    _buscador.placeholder = @"Buscar categorías";
    _buscador.delegate = self;
    _buscador.barTintColor = [ITTheme superficie];
    _buscador.tintColor = [ITTheme acento];
    _buscador.searchBarStyle = UISearchBarStyleMinimal;
    self.tableView.tableHeaderView = _buscador;

    UIRefreshControl *refresco = [[UIRefreshControl alloc] init];
    [refresco addTarget:self action:@selector(recargar) forControlEvents:UIControlEventValueChanged];
    self.refreshControl = refresco;

    [self recargar];
}

- (void)recargar {
    if (_cargando) return;
    _cargando = YES;
    __typeof(self) debil = self;
    [[ITApi compartida] categorias:30 completion:^(NSArray *elementos, NSError *error) {
        debil->_cargando = NO;
        if (elementos) {
            debil->_juegos = elementos;
            debil->_filtrados = elementos;
        }
        [debil.refreshControl endRefreshing];
        [debil.tableView reloadData];
    }];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if (searchText.length == 0) {
        _filtrados = _juegos;
    } else {
        NSMutableArray *salida = [NSMutableArray array];
        for (ITGame *g in _juegos) {
            NSString *n = g.mostrado ?: @"";
            if ([n rangeOfString:searchText options:NSCaseInsensitiveSearch].location != NSNotFound) {
                [salida addObject:g];
            }
        }
        _filtrados = salida;
    }
    [self.tableView reloadData];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _filtrados.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ITGameCell *c = [tableView dequeueReusableCellWithIdentifier:@"juego"];
    if (!c) c = [[ITGameCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"juego"];
    [c configurarConJuego:_filtrados[indexPath.row]];
    return c;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    ITCategoryViewController *vc = [[ITCategoryViewController alloc] initWithJuego:_filtrados[indexPath.row]];
    [self.navigationController pushViewController:vc animated:YES];
}

@end
