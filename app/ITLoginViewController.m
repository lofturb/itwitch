#import "ITLoginViewController.h"
#import "ITTheme.h"
#import "ITUtil.h"
#import "ITSession.h"
#import "ITApi.h"
#import "ITNotifications.h"

@interface ITLoginViewController () <UIWebViewDelegate>
@end

@implementation ITLoginViewController {
    UIWebView *_web;
    UIActivityIndicatorView *_rueda;
    UILabel *_aviso;
    NSTimer *_sondeo;
    BOOL _validando;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Entrar en Twitch";
    self.view.backgroundColor = [UIColor whiteColor];

    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"Cancelar" style:UIBarButtonItemStylePlain
                                        target:self action:@selector(cancelar)];
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"Pegar token" style:UIBarButtonItemStylePlain
                                        target:self action:@selector(pegarToken)];

    _web = [[UIWebView alloc] initWithFrame:self.view.bounds];
    _web.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _web.delegate = self;
    _web.scalesPageToFit = YES;
    _web.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:_web];

    _rueda = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    _rueda.center = CGPointMake(self.view.bounds.size.width / 2, 100);
    _rueda.hidesWhenStopped = YES;
    [self.view addSubview:_rueda];
    [_rueda startAnimating];

    _aviso = ITLabel(@"Si Google o Apple rechazan el acceso dentro de la app, usa «Pegar token».",
                     [ITTheme fuenteMenuda], [ITTheme textoSecundario]);
    _aviso.textAlignment = NSTextAlignmentCenter;
    _aviso.numberOfLines = 2;
    _aviso.frame = CGRectMake(16, self.view.bounds.size.height - 54,
                              self.view.bounds.size.width - 32, 40);
    _aviso.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:_aviso];

    [_web loadRequest:[NSURLRequest requestWithURL:
        [NSURL URLWithString:@"https://www.twitch.tv/login"]]];

    // La pagina de Twitch puede actualizar la cookie sin recargar del todo.
    // Sondeamos el almacen de cookies para no depender de webViewDidFinishLoad.
    _sondeo = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self
                                             selector:@selector(buscarCookie)
                                             userInfo:nil repeats:YES];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [_sondeo invalidate];
    _sondeo = nil;
}

- (void)dealloc {
    [_sondeo invalidate];
}

- (void)cancelar {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Web

- (void)webViewDidStartLoad:(UIWebView *)webView {
    [_rueda startAnimating];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    [_rueda stopAnimating];
    [self buscarCookie];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    [_rueda stopAnimating];
}

- (void)buscarCookie {
    if (_validando) return;
    NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies];
    NSString *token = nil;
    for (NSHTTPCookie *cookie in cookies) {
        if ([cookie.name isEqualToString:@"auth-token"] &&
            [cookie.domain rangeOfString:@"twitch.tv"].location != NSNotFound) {
            token = cookie.value;
            break;
        }
    }
    if (token.length > 0) [self validar:token];
}

- (void)validar:(NSString *)token {
    if (_validando) return;
    _validando = YES;
    __typeof(self) debil = self;
    [[ITSession compartida] guardarToken:token];
    [[ITApi compartida] usuarioActual:^(id objeto, NSError *error) {
        debil->_validando = NO;
        if (objeto && !error) {
            if ([objeto isKindOfClass:[ITChannel class]]) {
                ITChannel *c = objeto;
                [ITSession compartida].usuario = @{ @"login" : c.login ?: @"",
                                                    @"id" : c.identificador ?: @"" };
            }
            [[ITNotifications compartida] comenzar];
            [debil dismissViewControllerAnimated:YES completion:nil];
        } else {
            [[ITSession compartida] cerrarSesion];
            debil->_aviso.text = @"Twitch no ha aceptado la sesión. Prueba a pegar el token a mano.";
        }
    }];
}

#pragma mark - Token manual

- (void)pegarToken {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Pegar auth-token"
        message:@"Copia el valor de la cookie auth-token de Twitch."
        preferredStyle:UIAlertControllerStyleAlert];
    [a addTextFieldWithConfigurationHandler:^(UITextField *campo) {
        campo.placeholder = @"auth-token";
        campo.autocapitalizationType = UITextAutocapitalizationTypeNone;
        campo.autocorrectionType = UITextAutocorrectionTypeNo;
    }];
    [a addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"Entrar" style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *accion) {
        NSString *texto = a.textFields.firstObject.text;
        NSString *limpio = [texto stringByTrimmingCharactersInSet:
                            [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([limpio hasPrefix:@"auth-token="]) limpio = [limpio substringFromIndex:11];
        NSRange punto = [limpio rangeOfString:@";"];
        if (punto.location != NSNotFound) limpio = [limpio substringToIndex:punto.location];
        if (limpio.length > 0) [self validar:limpio];
    }]];
    [self presentViewController:a animated:YES completion:nil];
}

@end
