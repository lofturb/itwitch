#import "ITSearchViewController.h"
#import "ITTheme.h"
#import "ITUtil.h"
#import "ITCells.h"
#import "ITApi.h"
#import "ITChannelViewController.h"
#import "ITCategoryViewController.h"

static NSString * const kITRecientes = @"itwitch_busquedas_recientes";

@interface ITSearchViewController () <UISearchBarDelegate>
@end

@implementation ITSearchViewController {
    UISearchBar *_buscador;
    UISegmentedControl *_segmento;
    NSArray *_sugerencias;
    NSArray *_canales;
    NSArray *_categorias;
    NSArray *_recientes;
    BOOL _modoResultados;
    NSTimer *_rebote;
    NSString *_ultimaConsulta;
}

- (instancetype)init {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        self.title = @"Buscar";
        self.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Buscar"
                                                        image:[ITTheme icono:@"buscar" lado:26]
                                                          tag:2];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.backgroundColor = [ITTheme fondo];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.rowHeight = 68;
    self.navigationItem.title = @"Buscar";

    _buscador = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
    _buscador.placeholder = @"Buscar canales o categorías";
    _buscador.delegate = self;
    _buscador.searchBarStyle = UISearchBarStyleMinimal;
    _buscador.tintColor = [ITTheme acento];
    _buscador.barTintColor = [ITTheme fondo];
    self.navigationItem.titleView = _buscador;

    _segmento = [[UISegmentedControl alloc] initWithItems:@[@"Canales", @"Categorías"]];
    _segmento.selectedSegmentIndex = 0;
    _segmento.tintColor = [ITTheme acento];
    [_segmento addTarget:self action:@selector(cambiarSegmento) forControlEvents:UIControlEventValueChanged];

    _recientes = [[NSUserDefaults standardUserDefaults] arrayForKey:kITRecientes] ?: @[];
    _sugerencias = @[];
    _canales = @[];
    _categorias = @[];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

- (void)cambiarSegmento {
    [self.tableView reloadData];
}

#pragma mark - Busqueda

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    [_rebote invalidate];
    _modoResultados = NO;

    if (searchText.length == 0) {
        _sugerencias = @[];
        _recientes = [[NSUserDefaults standardUserDefaults] arrayForKey:kITRecientes] ?: @[];
        [self.tableView reloadData];
        return;
    }
    if (searchText.length < 2) {
        _sugerencias = @[];
        [self.tableView reloadData];
        return;
    }

    _rebote = [NSTimer scheduledTimerWithTimeInterval:0.32 target:self
                                            selector:@selector(pedirSugerencias)
                                            userInfo:nil repeats:NO];
}

- (void)pedirSugerencias {
    NSString *texto = _buscador.text;
    if (texto.length < 2) return;
    __weak typeof(self) debil = self;
    [[ITApi compartida] sugerencias:texto completion:^(NSArray *elementos, NSError *error) {
        if (![debil->_buscador.text isEqualToString:texto]) return;
        if (elementos) debil->_sugerencias = elementos;
        [debil.tableView reloadData];
    }];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
    [self buscar:searchBar.text];
}

- (void)buscar:(NSString *)texto {
    if (texto.length == 0) return;
    _modoResultados = YES;
    _ultimaConsulta = [texto copy];
    _sugerencias = @[];
    _canales = @[];
    _categorias = @[];

    NSMutableArray *rec = [NSMutableArray arrayWithObject:texto];
    for (NSString *r in _recientes) {
        if (![r isEqualToString:texto] && rec.count < 10) [rec addObject:r];
    }
    _recientes = rec;
    [[NSUserDefaults standardUserDefaults] setObject:rec forKey:kITRecientes];
    [self.tableView reloadData];

    __weak typeof(self) debil = self;
    [[ITApi compartida] buscarCanales:texto completion:^(NSArray *elementos, NSError *error) {
        if (![debil->_ultimaConsulta isEqualToString:texto]) return;
        if (elementos) debil->_canales = elementos;
        [debil.tableView reloadData];
    }];
    [[ITApi compartida] buscarCategorias:texto completion:^(NSArray *elementos, NSError *error) {
        if (![debil->_ultimaConsulta isEqualToString:texto]) return;
        if (elementos) debil->_categorias = elementos;
        [debil.tableView reloadData];
    }];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (!_modoResultados) {
        NSString *texto = nil;
        if (_buscador.text.length == 0 && indexPath.section == 0) {
            texto = _recientes[indexPath.row];
        } else {
            texto = _sugerencias[indexPath.row];
        }
        _buscador.text = texto;
        [self buscar:texto];
        return;
    }

    if (_segmento.selectedSegmentIndex == 0) {
        ITChannel *c = _canales[indexPath.row];
        ITChannelViewController *vc = [[ITChannelViewController alloc] initWithLogin:c.login];
        [self.navigationController pushViewController:vc animated:YES];
    } else {
        ITGame *g = _categorias[indexPath.row];
        ITCategoryViewController *vc = [[ITCategoryViewController alloc] initWithJuego:g];
        [self.navigationController pushViewController:vc animated:YES];
    }
}

#pragma mark - Tabla

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (_modoResultados) return 1;
    if (_buscador.text.length == 0) return _recientes.count > 0 ? 1 : 0;
    return _sugerencias.count > 0 ? 1 : 0;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (_modoResultados) {
        return _segmento.selectedSegmentIndex == 0 ? _canales.count : _categorias.count;
    }
    if (_buscador.text.length == 0) return _recientes.count;
    return _sugerencias.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (_modoResultados) {
        if (_canales.count + _categorias.count == 0) return @"Sin resultados";
        return nil;
    }
    if (_buscador.text.length == 0 && _recientes.count) return @"Búsquedas recientes";
    return @"Sugerencias";
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (_modoResultados) return 44.0;
    return 32.0;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (_modoResultados) {
        UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, 44)];
        v.backgroundColor = [ITTheme fondo];
        _segmento.frame = CGRectMake(14, 7, v.bounds.size.width - 28, 30);
        [v addSubview:_segmento];
        return v;
    }
    NSString *titulo = [self tableView:tableView titleForHeaderInSection:section];
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, 32)];
    v.backgroundColor = [ITTheme fondo];
    UILabel *l = ITLabel(titulo, [ITTheme fuenteMenuda], [ITTheme textoSecundario]);
    l.frame = CGRectMake(14, 10, v.bounds.size.width - 28, 18);
    [v addSubview:l];
    return v;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_modoResultados) {
        if (_segmento.selectedSegmentIndex == 0) {
            ITChannelCell *c = [tableView dequeueReusableCellWithIdentifier:@"canal"];
            if (!c) c = [[ITChannelCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"canal"];
            [c configurarConCanal:_canales[indexPath.row]];
            return c;
        }
        ITGameCell *c = [tableView dequeueReusableCellWithIdentifier:@"juego"];
        if (!c) c = [[ITGameCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"juego"];
        [c configurarConJuego:_categorias[indexPath.row]];
        return c;
    }

    static NSString *simple = @"simple";
    UITableViewCell *c = [tableView dequeueReusableCellWithIdentifier:simple];
    if (!c) {
        c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:simple];
        c.backgroundColor = [ITTheme fondo];
        c.textLabel.textColor = [ITTheme textoPrimario];
        c.textLabel.font = [ITTheme fuenteTituloLista];
        c.imageView.tintColor = [ITTheme textoSecundario];
        UIView *sel = [[UIView alloc] init];
        sel.backgroundColor = [ITTheme superficieAlta];
        c.selectedBackgroundView = sel;
    }
    NSString *texto = (_buscador.text.length == 0) ? _recientes[indexPath.row] : _sugerencias[indexPath.row];
    c.textLabel.text = texto;
    c.imageView.image = [ITTheme icono:(_buscador.text.length == 0 ? @"reloj" : @"buscar") lado:18];
    return c;
}

@end
