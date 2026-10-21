#import "ITDownloadsViewController.h"
#import "ITDownloadManager.h"
#import "ITTheme.h"
#import "ITUtil.h"
#import "ITPlayerViewController.h"
#import <AVFoundation/AVFoundation.h>

static NSString *ITBytes(long long bytes) {
    if (bytes < 1024) return [NSString stringWithFormat:@"%lld B", bytes];
    if (bytes < 1024 * 1024) return [NSString stringWithFormat:@"%.0f KB", bytes / 1024.0];
    if (bytes < 1024LL * 1024 * 1024) {
        return [NSString stringWithFormat:@"%.1f MB", bytes / (1024.0 * 1024.0)];
    }
    return [NSString stringWithFormat:@"%.2f GB", bytes / (1024.0 * 1024.0 * 1024.0)];
}

#pragma mark - Celda

@interface ITDescargaCelda : UITableViewCell
@property (nonatomic, strong) UILabel *titulo;
@property (nonatomic, strong) UILabel *detalle;
@property (nonatomic, strong) UIProgressView *barra;
- (void)mostrarDescarga:(ITDescarga *)descarga;
@end

@implementation ITDescargaCelda

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = [ITTheme superficie];
        self.selectionStyle = UITableViewCellSelectionStyleDefault;

        _titulo = ITLabel(@"", [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold],
                          [ITTheme textoPrimario]);
        _titulo.numberOfLines = 2;
        [self.contentView addSubview:_titulo];

        _detalle = ITLabel(@"", [UIFont systemFontOfSize:11.0], [ITTheme textoSecundario]);
        _detalle.numberOfLines = 1;
        [self.contentView addSubview:_detalle];

        _barra = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
        _barra.progressTintColor = [ITTheme acento];
        _barra.trackTintColor = [ITTheme borde];
        [self.contentView addSubview:_barra];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat ancho = self.contentView.bounds.size.width;
    _titulo.frame = CGRectMake(15, 7, ancho - 30, 32);
    _detalle.frame = CGRectMake(15, 40, ancho - 30, 14);
    _barra.frame = CGRectMake(15, 58, ancho - 30, 2);
}

- (void)mostrarDescarga:(ITDescarga *)d {
    self.titulo.text = d.titulo;
    self.barra.hidden = NO;

    if (d.estado == ITDescargaCompletada) {
        self.detalle.text = [NSString stringWithFormat:@"%@ · %@ · toca para opciones",
                             d.calidad ?: @"Auto", ITBytes(d.bytesHechos)];
        self.barra.progress = 1.0;
        self.detalle.textColor = [ITTheme textoSecundario];
    } else if (d.estado == ITDescargaFallida) {
        self.detalle.text = d.estadoTexto;
        self.detalle.textColor = [UIColor colorWithRed:1.0 green:0.35 blue:0.35 alpha:1.0];
        self.barra.progress = (float)d.progreso;
    } else if (d.estado == ITDescargaCancelada) {
        self.detalle.text = @"Cancelada";
        self.detalle.textColor = [ITTheme textoSecundario];
        self.barra.progress = (float)d.progreso;
    } else {
        NSString *texto = d.estadoTexto;
        if (d.bytesHechos > 0) {
            texto = [NSString stringWithFormat:@"%@ · %@", texto, ITBytes(d.bytesHechos)];
        }
        self.detalle.text = texto;
        self.detalle.textColor = [ITTheme textoSecundario];
        self.barra.progress = (float)d.progreso;
    }
}

@end

#pragma mark - Controlador

@implementation ITDownloadsViewController

- (instancetype)init {
    return [super initWithStyle:UITableViewStyleGrouped];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Descargas";
    self.tableView.backgroundColor = [ITTheme fondo];
    self.tableView.separatorColor = [ITTheme borde];
    self.tableView.rowHeight = 72;

    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"Carpeta"
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(cambiarCarpeta)];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(recargar)
                                                 name:ITDescargasCambiaron
                                               object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)recargar {
    [self.tableView reloadData];
}

#pragma mark - Tabla

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 2; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 1;
    NSArray *lista = [ITDownloadManager compartida].descargas;
    return lista.count ? lista.count : 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == 0 ? @"Destino" : @"Descargas";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section != 1) return nil;
    return @"Mantén iTwitch abierto mientras descarga. Los vídeos se guardan en MP4 "
           @"(o .ts si el sistema no puede convertirlos) y se pueden reproducir desde aquí.";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        static NSString *carpeta = @"carpeta";
        UITableViewCell *c = [tableView dequeueReusableCellWithIdentifier:carpeta];
        if (!c) {
            c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                       reuseIdentifier:carpeta];
            c.backgroundColor = [ITTheme superficie];
            c.textLabel.textColor = [ITTheme textoPrimario];
            c.detailTextLabel.textColor = [ITTheme textoSecundario];
            c.textLabel.font = [ITTheme fuenteTituloLista];
            c.detailTextLabel.font = [UIFont systemFontOfSize:11.0];
            c.detailTextLabel.numberOfLines = 2;
            c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
        c.textLabel.text = @"Carpeta de descargas";
        c.detailTextLabel.text = [ITDownloadManager carpetaDeDescargas];
        return c;
    }

    NSArray *lista = [ITDownloadManager compartida].descargas;
    if (lista.count == 0) {
        static NSString *vacia = @"vacia";
        UITableViewCell *c = [tableView dequeueReusableCellWithIdentifier:vacia];
        if (!c) {
            c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                       reuseIdentifier:vacia];
            c.backgroundColor = [ITTheme superficie];
            c.textLabel.textColor = [ITTheme textoSecundario];
            c.textLabel.font = [ITTheme fuenteCuerpo];
            c.textLabel.textAlignment = NSTextAlignmentCenter;
            c.selectionStyle = UITableViewCellSelectionStyleNone;
        }
        c.textLabel.text = @"No hay descargas todavía.\nAbre un VOD y pulsa «Bajar».";
        c.textLabel.numberOfLines = 2;
        return c;
    }

    static NSString *celda = @"descarga";
    ITDescargaCelda *c = [tableView dequeueReusableCellWithIdentifier:celda];
    if (!c) c = [[ITDescargaCelda alloc] initWithStyle:UITableViewCellStyleDefault
                                      reuseIdentifier:celda];
    ITDescarga *d = lista[indexPath.row];
    [c mostrarDescarga:d];
    return c;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 0) {
        [self cambiarCarpeta];
        return;
    }
    NSArray *lista = [ITDownloadManager compartida].descargas;
    if (indexPath.row >= lista.count) return;
    [self opcionesPara:lista[indexPath.row]];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
                                            forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle != UITableViewCellEditingStyleDelete) return;
    if (indexPath.section != 1) return;
    NSArray *lista = [ITDownloadManager compartida].descargas;
    if (indexPath.row >= lista.count) return;
    [[ITDownloadManager compartida] eliminar:lista[indexPath.row]];
    [tableView reloadData];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section != 1) return NO;
    return [ITDownloadManager compartida].descargas.count > 0;
}

#pragma mark - Acciones

- (void)opcionesPara:(ITDescarga *)d {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:d.titulo
        message:d.estadoTexto preferredStyle:UIAlertControllerStyleActionSheet];

    if (d.estado == ITDescargaCompletada && d.archivo.length) {
        [a addAction:[UIAlertAction actionWithTitle:@"Reproducir" style:UIAlertActionStyleDefault
            handler:^(UIAlertAction *accion) {
            ITPlayerViewController *p = [[ITPlayerViewController alloc] initWithArchivo:d.archivo
                                                                                titulo:d.titulo];
            [self.navigationController pushViewController:p animated:YES];
        }]];
        [a addAction:[UIAlertAction actionWithTitle:@"Compartir archivo"
            style:UIAlertActionStyleDefault
            handler:^(UIAlertAction *accion) {
            UIActivityViewController *actividad = [[UIActivityViewController alloc]
                initWithActivityItems:@[[NSURL fileURLWithPath:d.archivo]]
                applicationActivities:nil];
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
                actividad.popoverPresentationController.sourceView = self.view;
                actividad.popoverPresentationController.sourceRect = CGRectMake(
                    self.view.bounds.size.width / 2, self.view.bounds.size.height / 2, 1, 1);
            }
            [self presentViewController:actividad animated:YES completion:nil];
        }]];
        [a addAction:[UIAlertAction actionWithTitle:@"Copiar ruta" style:UIAlertActionStyleDefault
            handler:^(UIAlertAction *accion) {
            [UIPasteboard generalPasteboard].string = d.archivo;
        }]];
    }

    if (d.estado == ITDescargaActiva || d.estado == ITDescargaEnEspera) {
        [a addAction:[UIAlertAction actionWithTitle:@"Cancelar descarga"
            style:UIAlertActionStyleDestructive
            handler:^(UIAlertAction *accion) {
            [[ITDownloadManager compartida] cancelar:d];
            [self.tableView reloadData];
        }]];
    }
    if (d.estado == ITDescargaFallida || d.estado == ITDescargaCancelada) {
        [a addAction:[UIAlertAction actionWithTitle:@"Reintentar" style:UIAlertActionStyleDefault
            handler:^(UIAlertAction *accion) {
            [[ITDownloadManager compartida] reintentar:d];
            [self.tableView reloadData];
        }]];
    }

    [a addAction:[UIAlertAction actionWithTitle:@"Borrar archivo y entrada"
        style:UIAlertActionStyleDestructive
        handler:^(UIAlertAction *accion) {
        [[ITDownloadManager compartida] eliminar:d];
        [self.tableView reloadData];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Cerrar" style:UIAlertActionStyleCancel handler:nil]];

    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        a.popoverPresentationController.sourceView = self.view;
        a.popoverPresentationController.sourceRect = CGRectMake(
            self.view.bounds.size.width / 2, self.view.bounds.size.height / 2, 1, 1);
    }
    [self presentViewController:a animated:YES completion:nil];
}

- (void)cambiarCarpeta {
    NSString *actual = [ITDownloadManager carpetaDeDescargas];
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Carpeta de descargas"
        message:@"Escribe una ruta del dispositivo. Por defecto: /var/mobile/Media/iTwitch"
        preferredStyle:UIAlertControllerStyleAlert];
    [a addTextFieldWithConfigurationHandler:^(UITextField *campo) {
        campo.text = actual;
        campo.autocapitalizationType = UITextAutocapitalizationTypeNone;
        campo.autocorrectionType = UITextAutocorrectionTypeNo;
        campo.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    [a addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"Media" style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *accion) { [self probarCarpeta:@"/var/mobile/Media"]; }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Privada" style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *accion) {
        [self probarCarpeta:[ITDownloadManager carpetaDeRespaldo]];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Guardar" style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *accion) {
        NSString *ruta = [a.textFields.firstObject.text stringByTrimmingCharactersInSet:
                          [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        [self probarCarpeta:ruta];
    }]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)probarCarpeta:(NSString *)ruta {
    if (ruta.length == 0) return;
    if ([ITDownloadManager carpetaEscribible:ruta]) {
        [ITDownloadManager guardarCarpetaDeDescargas:ruta];
        [self.tableView reloadData];
        return;
    }

    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Sin permiso de escritura"
        message:[NSString stringWithFormat:
                 @"iTwitch no puede escribir en %@.\n\nSe usará su carpeta privada "
                 @"(Documents/Descargas).", ruta]
        preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"Usar la privada" style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *accion) {
        [ITDownloadManager guardarCarpetaDeDescargas:[ITDownloadManager carpetaDeRespaldo]];
        [self.tableView reloadData];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

@end
