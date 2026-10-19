#import "ITSettingsViewController.h"
#import "ITTheme.h"
#import "ITUtil.h"
#import "ITSession.h"
#import "ITApi.h"
#import "ITLoginViewController.h"
#import "ITDiagnosticsViewController.h"
#import "ITNotifications.h"

static NSString * const kITCalidad = @"itwitch_calidad";
static NSString * const kITChat = @"itwitch_chat";
static NSString * const kITReanudar = @"itwitch_reanudar";

@implementation ITSettingsViewController

+ (NSString *)calidadMaxima {
    NSString *v = [[NSUserDefaults standardUserDefaults] stringForKey:kITCalidad];
    return v.length ? v : @"auto";
}

+ (BOOL)chatActivo {
    id v = [[NSUserDefaults standardUserDefaults] objectForKey:kITChat];
    return v == nil ? YES : [v boolValue];
}

+ (BOOL)reanudarVod {
    id v = [[NSUserDefaults standardUserDefaults] objectForKey:kITReanudar];
    return v == nil ? YES : [v boolValue];
}

- (instancetype)init {
    return [super initWithStyle:UITableViewStyleGrouped];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Ajustes";
    self.tableView.backgroundColor = [ITTheme fondo];
    self.tableView.separatorColor = [ITTheme borde];
}

#pragma mark - Tabla

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 6; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0: return 2;
        case 1: return 2;
        case 2: return 3;
        case 3: return 1;
        case 4: return 1;
        default: return 1;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case 0: return @"Cuenta";
        case 1: return @"Apariencia";
        case 2: return @"Reproductor";
        case 3: return @"Avisos";
        case 4: return @"Ayuda";
        default: return @"iTwitch";
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *simple = @"simple";
    UITableViewCell *c = [tableView dequeueReusableCellWithIdentifier:simple];
    if (!c) {
        c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:simple];
        c.backgroundColor = [ITTheme superficie];
        c.textLabel.textColor = [ITTheme textoPrimario];
        c.detailTextLabel.textColor = [ITTheme textoSecundario];
        c.textLabel.font = [ITTheme fuenteTituloLista];
        c.detailTextLabel.font = [ITTheme fuenteCuerpo];
    }
    c.accessoryView = nil;
    c.accessoryType = UITableViewCellAccessoryNone;

    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            c.textLabel.text = [[ITSession compartida] haySesion] ? @"Cerrar sesión" : @"Entrar en Twitch";
            c.textLabel.textColor = [ITTheme acento];
        } else {
            c.textLabel.text = @"Pegar auth-token";
            c.textLabel.textColor = [ITTheme textoPrimario];
            c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
    } else if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            c.textLabel.text = @"Fondo";
            c.detailTextLabel.text = [ITTheme tituloDeFondo:[ITTheme fondoClave]];
        } else {
            c.textLabel.text = @"Acento";
            c.detailTextLabel.text = [ITTheme tituloDeAcento:[ITTheme acentoClave]];
        }
        c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else if (indexPath.section == 2) {
        if (indexPath.row == 0) {
            c.textLabel.text = @"Calidad máxima";
            NSString *q = [ITSettingsViewController calidadMaxima];
            c.detailTextLabel.text = [q isEqualToString:@"auto"] ? @"Auto" : [NSString stringWithFormat:@"%@p", q];
            c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        } else if (indexPath.row == 1) {
            c.textLabel.text = @"Chat activado";
            UISwitch *s = [[UISwitch alloc] init];
            s.onTintColor = [ITTheme acento];
            s.on = [ITSettingsViewController chatActivo];
            [s addTarget:self action:@selector(cambiarChat:) forControlEvents:UIControlEventValueChanged];
            c.accessoryView = s;
        } else {
            c.textLabel.text = @"Reanudar VODs";
            UISwitch *s = [[UISwitch alloc] init];
            s.onTintColor = [ITTheme acento];
            s.on = [ITSettingsViewController reanudarVod];
            [s addTarget:self action:@selector(cambiarReanudar:) forControlEvents:UIControlEventValueChanged];
            c.accessoryView = s;
        }
    } else if (indexPath.section == 3) {
        c.textLabel.text = @"Avisos de directos";
        UISwitch *s = [[UISwitch alloc] init];
        s.onTintColor = [ITTheme acento];
        s.on = [ITNotifications avisosActivos];
        [s addTarget:self action:@selector(cambiarAvisos:) forControlEvents:UIControlEventValueChanged];
        c.accessoryView = s;
    } else if (indexPath.section == 4) {
        c.textLabel.text = @"Diagnóstico de conexión";
        c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else {
        c.textLabel.text = @"Versión";
        c.detailTextLabel.text = @"1.0.0 (armv7)";
    }
    return c;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == 0 && indexPath.row == 0) {
        if ([[ITSession compartida] haySesion]) {
            [[ITSession compartida] cerrarSesion];
            [self.tableView reloadData];
        } else {
            ITLoginViewController *vc = [[ITLoginViewController alloc] init];
            UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
            [self presentViewController:nav animated:YES completion:nil];
        }
        return;
    }
    if (indexPath.section == 0 && indexPath.row == 1) {
        [self pedirToken];
        return;
    }
    if (indexPath.section == 1) {
        if (indexPath.row == 0) [self elegirFondo];
        else [self elegirAcento];
        return;
    }
    if (indexPath.section == 2 && indexPath.row == 0) {
        [self elegirCalidad];
        return;
    }
    if (indexPath.section == 4) {
        ITDiagnosticsViewController *vc = [[ITDiagnosticsViewController alloc] init];
        [self.navigationController pushViewController:vc animated:YES];
    }
}

#pragma mark - Acciones

- (void)cambiarChat:(UISwitch *)s {
    [[NSUserDefaults standardUserDefaults] setBool:s.on forKey:kITChat];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)cambiarReanudar:(UISwitch *)s {
    [[NSUserDefaults standardUserDefaults] setBool:s.on forKey:kITReanudar];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)cambiarAvisos:(UISwitch *)s {
    [ITNotifications establecerAvisosActivos:s.on];
}

- (void)elegirFondo {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Fondo"
        message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    NSArray *fondos = [ITTheme fondosDisponibles];
    for (NSDictionary *f in fondos) {
        [a addAction:[UIAlertAction actionWithTitle:f[@"titulo"] style:UIAlertActionStyleDefault
            handler:^(UIAlertAction *accion) {
            [ITTheme guardarFondo:f[@"clave"] acento:[ITTheme acentoClave]];
            [self.tableView reloadData];
        }]];
    }
    [a addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel handler:nil]];
    [self presentarAccion:a];
}

- (void)elegirAcento {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Acento"
        message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSDictionary *c in [ITTheme acentosDisponibles]) {
        [a addAction:[UIAlertAction actionWithTitle:c[@"titulo"] style:UIAlertActionStyleDefault
            handler:^(UIAlertAction *accion) {
            [ITTheme guardarFondo:[ITTheme fondoClave] acento:c[@"clave"]];
            [self.tableView reloadData];
        }]];
    }
    [a addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel handler:nil]];
    [self presentarAccion:a];
}

- (void)elegirCalidad {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Calidad máxima"
        message:@"El reproductor elegirá la mejor calidad permitida." preferredStyle:UIAlertControllerStyleActionSheet];
    NSArray *opciones = @[ @"auto", @"1080", @"720", @"480", @"360" ];
    for (NSString *q in opciones) {
        NSString *titulo = [q isEqualToString:@"auto"] ? @"Auto" : [NSString stringWithFormat:@"%@p", q];
        [a addAction:[UIAlertAction actionWithTitle:titulo style:UIAlertActionStyleDefault
            handler:^(UIAlertAction *accion) {
            [[NSUserDefaults standardUserDefaults] setObject:q forKey:kITCalidad];
            [[NSUserDefaults standardUserDefaults] synchronize];
            [self.tableView reloadData];
        }]];
    }
    [a addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel handler:nil]];
    [self presentarAccion:a];
}

- (void)presentarAccion:(UIAlertController *)a {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        a.popoverPresentationController.sourceView = self.view;
        a.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width / 2,
                                                                self.view.bounds.size.height / 2, 1, 1);
    }
    [self presentViewController:a animated:YES completion:nil];
}

- (void)pedirToken {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Pegar auth-token"
        message:@"Copia el valor de la cookie auth-token de Twitch y pégalo aquí. Se guarda en el llavero del dispositivo."
        preferredStyle:UIAlertControllerStyleAlert];
    [a addTextFieldWithConfigurationHandler:^(UITextField *campo) {
        campo.placeholder = @"auth-token";
        campo.autocapitalizationType = UITextAutocapitalizationTypeNone;
        campo.autocorrectionType = UITextAutocorrectionTypeNo;
    }];
    [a addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"Guardar" style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *accion) {
        NSString *texto = a.textFields.firstObject.text;
        [self validarToken:texto];
    }]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)validarToken:(NSString *)texto {
    NSString *limpio = [texto stringByTrimmingCharactersInSet:
                        [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (limpio.length == 0) return;
    if ([limpio hasPrefix:@"auth-token="]) limpio = [limpio substringFromIndex:11];
    NSRange punto = [limpio rangeOfString:@";"];
    if (punto.location != NSNotFound) limpio = [limpio substringToIndex:punto.location];

    ITSession *sesion = [ITSession compartida];
    NSString *anterior = sesion.token;
    sesion.token = limpio;
    [[ITApi compartida] usuarioActual:^(id objeto, NSError *error) {
        if (objeto && !error) {
            if ([objeto isKindOfClass:[ITChannel class]]) {
                ITChannel *c = objeto;
                sesion.usuario = @{ @"login" : c.login ?: @"",
                                    @"id" : c.identificador ?: @"" };
            }
            [sesion guardarToken:limpio];
            [[ITNotifications compartida] comenzar];
            [self.tableView reloadData];
            UIAlertController *ok = [UIAlertController alertControllerWithTitle:@"Sesión iniciada"
                message:@"El token es válido." preferredStyle:UIAlertControllerStyleAlert];
            [ok addAction:[UIAlertAction actionWithTitle:@"Vale" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:ok animated:YES completion:nil];
        } else {
            sesion.token = anterior;
            UIAlertController *mal = [UIAlertController alertControllerWithTitle:@"Token no válido"
                message:error.localizedDescription ?: @"Twitch no ha aceptado ese token."
                preferredStyle:UIAlertControllerStyleAlert];
            [mal addAction:[UIAlertAction actionWithTitle:@"Cerrar" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:mal animated:YES completion:nil];
        }
    }];
}

@end
