#import "ITCollectionViewController.h"
#import "ITTheme.h"
#import "ITUtil.h"
#import "ITCells.h"
#import "ITPlayerViewController.h"

@implementation ITCollectionViewController {
    ITCollection *_coleccion;
}

- (instancetype)initWithColeccion:(ITCollection *)coleccion {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        _coleccion = coleccion;
        self.title = coleccion.titulo;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.backgroundColor = [ITTheme fondo];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.rowHeight = 88;
    self.navigationItem.title = _coleccion.titulo;

    if (_coleccion.videos.count > 0) {
        self.navigationItem.rightBarButtonItem =
            [[UIBarButtonItem alloc] initWithTitle:@"Reproducir todo"
                                             style:UIBarButtonItemStylePlain
                                            target:self action:@selector(reproducirTodo)];
    }

    UIView *cabecera = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 72)];
    cabecera.backgroundColor = [ITTheme fondo];
    UILabel *detalle = ITLabel([NSString stringWithFormat:@"%lu vídeos · %@",
                                (unsigned long)_coleccion.videos.count,
                                ITFechaCorta(_coleccion.actualizada)],
                               [ITTheme fuenteCuerpo], [ITTheme textoSecundario]);
    detalle.frame = CGRectMake(14, 12, cabecera.bounds.size.width - 28, 20);
    [cabecera addSubview:detalle];

    UILabel *desc = ITLabel(_coleccion.descripcion ?: @"", [ITTheme fuenteMenuda],
                            [ITTheme textoSecundario]);
    desc.numberOfLines = 2;
    desc.frame = CGRectMake(14, 32, cabecera.bounds.size.width - 28, 32);
    [cabecera addSubview:desc];
    self.tableView.tableHeaderView = cabecera;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _coleccion.videos.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ITVideoCell *c = [tableView dequeueReusableCellWithIdentifier:@"video"];
    if (!c) c = [[ITVideoCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"video"];
    [c configurarConVideo:_coleccion.videos[indexPath.row]];
    return c;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    ITPlayerViewController *p = [[ITPlayerViewController alloc] initWithVideo:_coleccion.videos[indexPath.row]];
    p.listaVideos = _coleccion.videos;
    p.indiceVideo = indexPath.row;
    [self.navigationController pushViewController:p animated:YES];
}

- (void)reproducirTodo {
    if (_coleccion.videos.count == 0) return;
    ITPlayerViewController *p = [[ITPlayerViewController alloc] initWithVideo:_coleccion.videos.firstObject];
    p.listaVideos = _coleccion.videos;
    p.indiceVideo = 0;
    [self.navigationController pushViewController:p animated:YES];
}

@end
