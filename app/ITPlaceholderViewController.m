#import "ITPlaceholderViewController.h"
#import "ITTheme.h"

@implementation ITPlaceholderViewController {
    NSString *_titulo;
    NSString *_icono;
}

- (instancetype)initWithTitle:(NSString *)titulo icono:(NSString *)icono {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _titulo = [titulo copy];
        _icono = [icono copy];
        self.title = titulo;
        self.tabBarItem = [[UITabBarItem alloc] initWithTitle:titulo
                                                        image:[ITTheme icono:icono lado:26]
                                                          tag:0];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [ITTheme fondo];

    UIImageView *marca = [[UIImageView alloc] initWithImage:[ITTheme icono:_icono lado:64 trazo:3.0]];
    marca.tintColor = [ITTheme acento];
    marca.contentMode = UIViewContentModeScaleAspectFit;
    marca.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:marca];

    UILabel *titulo = [[UILabel alloc] init];
    titulo.text = _titulo;
    titulo.font = [UIFont systemFontOfSize:24.0 weight:UIFontWeightBold];
    titulo.textColor = [ITTheme textoPrimario];
    titulo.textAlignment = NSTextAlignmentCenter;
    titulo.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:titulo];

    UILabel *detalle = [[UILabel alloc] init];
    detalle.text = @"Pantalla en construccion";
    detalle.font = [ITTheme fuenteCuerpo];
    detalle.textColor = [ITTheme textoSecundario];
    detalle.textAlignment = NSTextAlignmentCenter;
    detalle.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:detalle];

    [NSLayoutConstraint activateConstraints:@[
        [marca.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [marca.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-52],
        [marca.widthAnchor constraintEqualToConstant:64],
        [marca.heightAnchor constraintEqualToConstant:64],
        [titulo.topAnchor constraintEqualToAnchor:marca.bottomAnchor constant:16],
        [titulo.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [titulo.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [detalle.topAnchor constraintEqualToAnchor:titulo.bottomAnchor constant:6],
        [detalle.leadingAnchor constraintEqualToAnchor:titulo.leadingAnchor],
        [detalle.trailingAnchor constraintEqualToAnchor:titulo.trailingAnchor]
    ]];
}

@end
