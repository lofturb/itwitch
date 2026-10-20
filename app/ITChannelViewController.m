#import "ITChannelViewController.h"
#import "ITTheme.h"
#import "ITUtil.h"
#import "ITCells.h"
#import "ITApi.h"
#import "ITImageCache.h"
#import "ITPlayerViewController.h"
#import "ITCollectionViewController.h"

@implementation ITChannelViewController {
    NSString *_login;
    ITChannel *_canal;
    UIView *_cabecera;
    UIImageView *_banner;
    UIImageView *_avatar;
    UILabel *_nombre;
    UILabel *_meta;
    UILabel *_estado;
    UIButton *_botonDirecto;
    UIButton *_botonSeguir;
    UISegmentedControl *_pestanas;
    UISegmentedControl *_filtro;

    NSInteger _pestana;
    NSArray *_videosDestacados;
    NSArray *_videosRecientes;
    NSArray *_clips;
    NSArray *_colecciones;
    NSArray *_videosFiltrados;
    NSString *_tipoVideo;
    NSString *_ordenVideo;
    NSString *_periodoClips;
    BOOL _cargando;
    NSUInteger _generacion;
}

- (instancetype)initWithLogin:(NSString *)login {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        _login = [login copy];
        self.title = login;
        _pestana = 0;
        _tipoVideo = @"ARCHIVE";
        _ordenVideo = @"TIME";
        _periodoClips = @"ALL_TIME";
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.backgroundColor = [ITTheme fondo];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.navigationItem.title = _login;
    [self montarCabecera];
    [self cargarCanal];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat ancho = self.tableView.bounds.size.width;
    if (_cabecera) {
        CGRect marco = _cabecera.frame;
        marco.size.width = ancho;
        _cabecera.frame = marco;
        [self colocarCabecera];
        self.tableView.tableHeaderView = _cabecera;
    }
}

#pragma mark - Cabecera

- (void)montarCabecera {
    _cabecera = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.tableView.bounds.size.width, 214)];
    _cabecera.backgroundColor = [ITTheme fondo];

    _banner = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, _cabecera.bounds.size.width, 96)];
    _banner.contentMode = UIViewContentModeScaleAspectFill;
    _banner.clipsToBounds = YES;
    _banner.backgroundColor = [ITTheme superficie];
    [_cabecera addSubview:_banner];

    _avatar = [[UIImageView alloc] initWithFrame:CGRectMake(14, 66, 68, 68)];
    _avatar.contentMode = UIViewContentModeScaleAspectFill;
    _avatar.clipsToBounds = YES;
    _avatar.layer.cornerRadius = 34.0;
    _avatar.layer.borderWidth = 3.0;
    _avatar.layer.borderColor = [ITTheme fondo].CGColor;
    _avatar.backgroundColor = [ITTheme superficie];
    [_cabecera addSubview:_avatar];

    _nombre = ITLabel(_login, [UIFont systemFontOfSize:19.0 weight:UIFontWeightBold],
                      [ITTheme textoPrimario]);
    [_cabecera addSubview:_nombre];

    _meta = ITLabel(@"", [ITTheme fuenteMenuda], [ITTheme textoSecundario]);
    [_cabecera addSubview:_meta];

    _estado = ITLabel(@"", [ITTheme fuenteCuerpo], [ITTheme textoSecundario]);
    [_cabecera addSubview:_estado];

    _botonDirecto = [UIButton buttonWithType:UIButtonTypeSystem];
    [_botonDirecto setTitle:@"Ver directo" forState:UIControlStateNormal];
    [_botonDirecto setTitleColor:[ITTheme textoSobreAcento] forState:UIControlStateNormal];
    _botonDirecto.backgroundColor = [ITTheme acento];
    _botonDirecto.titleLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    ITRedondear(_botonDirecto, 15.0);
    [_botonDirecto addTarget:self action:@selector(verDirecto) forControlEvents:UIControlEventTouchUpInside];
    [_cabecera addSubview:_botonDirecto];

    _botonSeguir = [UIButton buttonWithType:UIButtonTypeSystem];
    [_botonSeguir setTitle:@"Seguir web" forState:UIControlStateNormal];
    [_botonSeguir setTitleColor:[ITTheme textoPrimario] forState:UIControlStateNormal];
    _botonSeguir.backgroundColor = [ITTheme superficieAlta];
    _botonSeguir.titleLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    ITRedondear(_botonSeguir, 15.0);
    [_botonSeguir addTarget:self action:@selector(seguir) forControlEvents:UIControlEventTouchUpInside];
    [_cabecera addSubview:_botonSeguir];

    UIButton *compartir = ITBotonIcono(@"compartir", 18, [ITTheme textoPrimario]);
    [compartir addTarget:self action:@selector(compartir) forControlEvents:UIControlEventTouchUpInside];
    [_cabecera addSubview:compartir];
    compartir.tag = 700;

    _pestanas = [[UISegmentedControl alloc] initWithItems:
                 @[@"Inicio", @"Vídeos", @"Clips", @"Colecciones", @"Acerca"]];
    _pestanas.selectedSegmentIndex = 0;
    _pestanas.tintColor = [ITTheme acento];
    _pestanas.apportionsSegmentWidthsByContent = YES;
    [_pestanas addTarget:self action:@selector(cambiarPestana) forControlEvents:UIControlEventValueChanged];
    [_cabecera addSubview:_pestanas];

    _filtro = [[UISegmentedControl alloc] initWithItems:@[@"Recientes", @"Más vistos", @"Destacados"]];
    _filtro.selectedSegmentIndex = 0;
    _filtro.tintColor = [ITTheme acento];
    _filtro.hidden = YES;
    [_filtro addTarget:self action:@selector(cambiarFiltro) forControlEvents:UIControlEventValueChanged];
    [_cabecera addSubview:_filtro];

    self.tableView.tableHeaderView = _cabecera;
    [self colocarCabecera];
}

- (void)colocarCabecera {
    CGFloat ancho = _cabecera.bounds.size.width;
    CGFloat alto = _filtro.hidden ? 236.0 : 272.0;
    _cabecera.frame = CGRectMake(0, 0, ancho, alto);
    _banner.frame = CGRectMake(0, 0, ancho, 96);
    _avatar.frame = CGRectMake(14, 66, 68, 68);
    _nombre.frame = CGRectMake(94, 74, ancho - 110, 24);
    _meta.frame = CGRectMake(94, 98, ancho - 110, 16);
    _estado.frame = CGRectMake(14, 138, ancho - 28, 18);
    _botonDirecto.frame = CGRectMake(14, 164, 112, 30);
    _botonSeguir.frame = CGRectMake(134, 164, 92, 30);
    UIView *compartir = [_cabecera viewWithTag:700];
    compartir.frame = CGRectMake(ancho - 44, 164, 32, 30);
    _pestanas.frame = CGRectMake(14, 200, ancho - 28, 30);
    _filtro.frame = CGRectMake(14, 236, ancho - 28, 30);
}

- (void)pintarCabecera {
    _nombre.text = _canal.nombre.length ? _canal.nombre : _login;
    _meta.text = [NSString stringWithFormat:@"%@ seguidores%@", ITMillones(_canal.seguidores),
                  _canal.partner ? @" · Partner" : (_canal.afiliado ? @" · Afiliado" : @"")];
    if (_canal.enDirecto) {
        _estado.text = [NSString stringWithFormat:@"EN DIRECTO · %@ · %@ espectadores",
                        _canal.directoJuego ?: @"", ITNumeroCorto(_canal.directoViewers)];
        _estado.textColor = [ITTheme acento];
        [_botonDirecto setTitle:@"Ver directo" forState:UIControlStateNormal];
        _botonDirecto.backgroundColor = [ITTheme acento];
        [_botonDirecto setTitleColor:[ITTheme textoSobreAcento] forState:UIControlStateNormal];
    } else {
        _estado.text = @"Desconectado";
        _estado.textColor = [ITTheme textoSecundario];
        [_botonDirecto setTitle:@"Último vídeo" forState:UIControlStateNormal];
        _botonDirecto.backgroundColor = [ITTheme superficieAlta];
        [_botonDirecto setTitleColor:[ITTheme textoPrimario] forState:UIControlStateNormal];
    }
    [ITImageCache cargarURL:ITImagen(_canal.banner, 800, 200) en:_banner];
    [ITImageCache cargarURL:ITImagen(_canal.avatar, 160, 160) en:_avatar];
    [self.tableView reloadData];
}

#pragma mark - Carga

- (void)cargarCanal {
    __typeof(self) debil = self;
    [[ITApi compartida] canal:_login completion:^(id objeto, NSError *error) {
        if ([objeto isKindOfClass:[ITChannel class]]) {
            debil->_canal = objeto;
            [debil pintarCabecera];
            [debil cargarPestana];
        } else {
            debil->_estado.text = error.localizedDescription ?: @"No se pudo cargar el canal.";
        }
    }];
}

- (void)configurarFiltro {
    [_filtro removeAllSegments];
    if (_pestana == 1) {
        [_filtro insertSegmentWithTitle:@"Recientes" atIndex:0 animated:NO];
        [_filtro insertSegmentWithTitle:@"Más vistos" atIndex:1 animated:NO];
        [_filtro insertSegmentWithTitle:@"Destacados" atIndex:2 animated:NO];
    } else if (_pestana == 2) {
        [_filtro insertSegmentWithTitle:@"Todo" atIndex:0 animated:NO];
        [_filtro insertSegmentWithTitle:@"Mes" atIndex:1 animated:NO];
        [_filtro insertSegmentWithTitle:@"Semana" atIndex:2 animated:NO];
        [_filtro insertSegmentWithTitle:@"Día" atIndex:3 animated:NO];
    }
    _filtro.selectedSegmentIndex = 0;
}

- (void)cambiarPestana {
    _pestana = _pestanas.selectedSegmentIndex;
    _filtro.hidden = !(_pestana == 1 || _pestana == 2);
    [self configurarFiltro];
    [self colocarCabecera];
    self.tableView.tableHeaderView = _cabecera;
    if (_pestana == 1) {
        _tipoVideo = @"ARCHIVE";
        _ordenVideo = @"TIME";
    } else if (_pestana == 2) {
        _periodoClips = @"ALL_TIME";
    }
    [self cargarPestana];
}

- (void)cambiarFiltro {
    if (_pestana == 1) {
        if (_filtro.selectedSegmentIndex == 0) { _tipoVideo = @"ARCHIVE"; _ordenVideo = @"TIME"; }
        else if (_filtro.selectedSegmentIndex == 1) { _tipoVideo = @"ARCHIVE"; _ordenVideo = @"VIEWS"; }
        else { _tipoVideo = @"HIGHLIGHT"; _ordenVideo = @"TIME"; }
    } else if (_pestana == 2) {
        NSArray *periodos = @[ @"ALL_TIME", @"LAST_MONTH", @"LAST_WEEK", @"LAST_DAY" ];
        if (_filtro.selectedSegmentIndex < (NSInteger)periodos.count) {
            _periodoClips = periodos[_filtro.selectedSegmentIndex];
        }
    }
    [self cargarPestana];
}

- (void)cargarPestana {
    if (!_canal) return;
    _generacion++;
    NSUInteger gen = _generacion;
    __typeof(self) debil = self;

    if (_pestana == 1) {
        _cargando = YES;
        [[ITApi compartida] videosDe:_login tipo:_tipoVideo orden:_ordenVideo
                          completion:^(NSArray *elementos, NSError *error) {
            if (gen != debil->_generacion) return;
            debil->_videosFiltrados = elementos ?: @[];
            debil->_cargando = NO;
            [debil.tableView reloadData];
        }];
        return;
    }
    if (_pestana == 2) {
        _cargando = YES;
        [[ITApi compartida] clipsDe:_login periodo:_periodoClips
                         completion:^(NSArray *elementos, NSError *error) {
            if (gen != debil->_generacion) return;
            debil->_clips = elementos ?: @[];
            debil->_cargando = NO;
            [debil.tableView reloadData];
        }];
        return;
    }
    if (_pestana == 3) {
        _cargando = YES;
        [[ITApi compartida] coleccionesDe:_login completion:^(NSArray *elementos, NSError *error) {
            if (gen != debil->_generacion) return;
            debil->_colecciones = elementos ?: @[];
            debil->_cargando = NO;
            [debil.tableView reloadData];
        }];
        return;
    }
    if (_pestana == 4) {
        [self.tableView reloadData];
        return;
    }

    // Inicio: todo en paralelo.
    _cargando = YES;
    __block NSInteger pendientes = 4;
    void (^listo)(void) = ^{
        pendientes--;
        if (pendientes <= 0 && gen == debil->_generacion) {
            debil->_cargando = NO;
            [debil.tableView reloadData];
        }
    };
    [[ITApi compartida] videosDe:_login tipo:@"ARCHIVE" orden:@"VIEWS"
                      completion:^(NSArray *elementos, NSError *error) {
        if (gen != debil->_generacion) return;
        debil->_videosDestacados = elementos ?: @[];
        listo();
    }];
    [[ITApi compartida] videosDe:_login tipo:@"ARCHIVE" orden:@"TIME"
                      completion:^(NSArray *elementos, NSError *error) {
        if (gen != debil->_generacion) return;
        debil->_videosRecientes = elementos ?: @[];
        listo();
    }];
    [[ITApi compartida] clipsDe:_login periodo:@"ALL_TIME"
                     completion:^(NSArray *elementos, NSError *error) {
        if (gen != debil->_generacion) return;
        debil->_clips = elementos ?: @[];
        listo();
    }];
    [[ITApi compartida] coleccionesDe:_login completion:^(NSArray *elementos, NSError *error) {
        if (gen != debil->_generacion) return;
        debil->_colecciones = elementos ?: @[];
        listo();
    }];
}

#pragma mark - Acciones

- (void)verDirecto {
    if (_canal.enDirecto) {
        ITStream *s = [[ITStream alloc] init];
        s.login = _canal.login;
        s.nombre = _canal.nombre;
        s.avatar = _canal.avatar;
        s.titulo = _canal.directoTitulo;
        s.juego = _canal.directoJuego;
        s.viewers = _canal.directoViewers;
        s.miniatura = _canal.apagado;
        s.enDirecto = YES;
        ITPlayerViewController *p = [[ITPlayerViewController alloc] initWithStream:s];
        [self.navigationController pushViewController:p animated:YES];
    } else if (_videosRecientes.count) {
        ITPlayerViewController *p = [[ITPlayerViewController alloc] initWithVideo:_videosRecientes.firstObject];
        [self.navigationController pushViewController:p animated:YES];
    }
}

- (void)seguir {
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://www.twitch.tv/%@", _login]];
    [[UIApplication sharedApplication] openURL:url];
}

- (void)compartir {
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://www.twitch.tv/%@", _login]];
    UIActivityViewController *a = [[UIActivityViewController alloc] initWithActivityItems:@[url]
                                                                  applicationActivities:nil];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        a.popoverPresentationController.sourceView = self.view;
        a.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width / 2,
                                                                self.view.bounds.size.height / 2, 1, 1);
    }
    [self presentViewController:a animated:YES completion:nil];
}

#pragma mark - Tabla

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (_pestana == 0) {
        return 1 + (_videosDestacados.count > 0) + (_videosRecientes.count > 0) +
               (_clips.count > 0) + (_colecciones.count > 0);
    }
    if (_pestana == 4) return 5;
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (_pestana == 0) {
        if (section == 0) return _canal ? 1 : 0;
        NSInteger i = 1;
        if (_videosDestacados.count > 0) { if (section == i) return MIN(_videosDestacados.count, 5); i++; }
        if (_videosRecientes.count > 0) { if (section == i) return MIN(_videosRecientes.count, 5); i++; }
        if (_clips.count > 0) { if (section == i) return MIN(_clips.count, 6); i++; }
        if (_colecciones.count > 0) { if (section == i) return _colecciones.count; }
        return 0;
    }
    if (_pestana == 1) return _videosFiltrados.count;
    if (_pestana == 2) return _clips.count;
    if (_pestana == 3) return _colecciones.count;
    if (_pestana == 4) {
        if (section == 0) return 1;
        if (section == 1) return 2;
        if (section == 2) return _canal.paneles.count;
        if (section == 3) return _canal.sociales.count;
        if (section == 4) return _canal.segmentos.count;
        return 0;
    }
    return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (_pestana == 0) {
        if (section == 0) return nil;
        NSInteger i = 1;
        if (_videosDestacados.count > 0) { if (section == i) return @"Destacados"; i++; }
        if (_videosRecientes.count > 0) { if (section == i) return @"Transmisiones recientes"; i++; }
        if (_clips.count > 0) { if (section == i) return @"Clips"; i++; }
        if (_colecciones.count > 0) { if (section == i) return @"Colecciones"; }
        return nil;
    }
    if (_pestana == 4) {
        if (section == 0) return @"Acerca de";
        if (section == 1) return @"Información";
        if (section == 2) return _canal.paneles.count ? @"Paneles" : nil;
        if (section == 3) return _canal.sociales.count ? @"Redes sociales" : nil;
        if (section == 4) return _canal.segmentos.count ? @"Horario" : nil;
    }
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return [self tableView:tableView titleForHeaderInSection:section] ? 32.0 : 0.0;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    NSString *titulo = [self tableView:tableView titleForHeaderInSection:section];
    if (!titulo) return nil;
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, 32)];
    v.backgroundColor = [ITTheme fondo];
    UILabel *l = ITLabel(titulo, [ITTheme fuenteTituloFila], [ITTheme textoPrimario]);
    l.frame = CGRectMake(14, 8, v.bounds.size.width - 28, 22);
    [v addSubview:l];
    return v;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_pestana == 0) return indexPath.section == 0 ? 52.0 : 88.0;
    if (_pestana == 1 || _pestana == 2) return 88.0;
    if (_pestana == 3) return 72.0;
    if (_pestana == 4) return indexPath.section == 0 ? 92.0 : 66.0;
    return 60.0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_pestana == 0) {
        if (indexPath.section == 0) {
            static NSString *simple = @"inicio";
            UITableViewCell *c = [tableView dequeueReusableCellWithIdentifier:simple];
            if (!c) {
                c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:simple];
                c.backgroundColor = [ITTheme superficie];
                c.textLabel.textColor = [ITTheme textoPrimario];
                c.detailTextLabel.textColor = [ITTheme textoSecundario];
                c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            }
            c.textLabel.text = _canal.enDirecto ? @"EN DIRECTO" : @"Desconectado";
            c.textLabel.textColor = _canal.enDirecto ? [ITTheme acento] : [ITTheme textoPrimario];
            c.detailTextLabel.text = _canal.enDirecto ? _canal.directoTitulo : @"No hay directo ahora mismo";
            return c;
        }
        NSInteger i = 1;
        if (_videosDestacados.count > 0) {
            if (indexPath.section == i) {
                ITVideoCell *c = [tableView dequeueReusableCellWithIdentifier:@"video"];
                if (!c) c = [[ITVideoCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"video"];
                [c configurarConVideo:_videosDestacados[indexPath.row]];
                return c;
            }
            i++;
        }
        if (_videosRecientes.count > 0) {
            if (indexPath.section == i) {
                ITVideoCell *c = [tableView dequeueReusableCellWithIdentifier:@"video"];
                if (!c) c = [[ITVideoCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"video"];
                [c configurarConVideo:_videosRecientes[indexPath.row]];
                return c;
            }
            i++;
        }
        if (_clips.count > 0) {
            if (indexPath.section == i) {
                ITClipCell *c = [tableView dequeueReusableCellWithIdentifier:@"clip"];
                if (!c) c = [[ITClipCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"clip"];
                [c configurarConClip:_clips[indexPath.row]];
                return c;
            }
            i++;
        }
        if (_colecciones.count > 0) {
            ITCollectionCell *c = [tableView dequeueReusableCellWithIdentifier:@"coleccion"];
            if (!c) c = [[ITCollectionCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"coleccion"];
            [c configurarConColeccion:_colecciones[indexPath.row]];
            return c;
        }
    }

    if (_pestana == 1) {
        ITVideoCell *c = [tableView dequeueReusableCellWithIdentifier:@"video"];
        if (!c) c = [[ITVideoCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"video"];
        [c configurarConVideo:_videosFiltrados[indexPath.row]];
        return c;
    }
    if (_pestana == 2) {
        ITClipCell *c = [tableView dequeueReusableCellWithIdentifier:@"clip"];
        if (!c) c = [[ITClipCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"clip"];
        [c configurarConClip:_clips[indexPath.row]];
        return c;
    }
    if (_pestana == 3) {
        ITCollectionCell *c = [tableView dequeueReusableCellWithIdentifier:@"coleccion"];
        if (!c) c = [[ITCollectionCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"coleccion"];
        [c configurarConColeccion:_colecciones[indexPath.row]];
        return c;
    }

    // Acerca de
    ITTextCell *c = [tableView dequeueReusableCellWithIdentifier:@"texto"];
    if (!c) c = [[ITTextCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"texto"];
    if (indexPath.section == 0) {
        [c configurarTitulo:_canal.descripcion.length ? _canal.descripcion : @"Sin descripción."
                    detalle:nil];
    } else if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            [c configurarTitulo:@"Seguidores" detalle:ITMillones(_canal.seguidores)];
        } else {
            [c configurarTitulo:@"Creado" detalle:ITFechaCorta(_canal.creado)];
        }
    } else if (indexPath.section == 2) {
        ITPanel *p = _canal.paneles[indexPath.row];
        [c configurarTitulo:p.titulo.length ? p.titulo : (p.descripcion ?: @"Panel")
                    detalle:p.descripcion.length ? p.descripcion : p.enlace];
    } else if (indexPath.section == 3) {
        NSDictionary *s = _canal.sociales[indexPath.row];
        [c configurarTitulo:s[@"nombre"] detalle:s[@"url"]];
    } else {
        ITSegmento *s = _canal.segmentos[indexPath.row];
        [c configurarTitulo:s.titulo detalle:[NSString stringWithFormat:@"%@ · %@",
                                              ITFechaCorta(s.inicio), ITFechaCorta(s.fin)]];
    }
    return c;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (_pestana == 0) {
        if (indexPath.section == 0) { [self verDirecto]; return; }
        NSInteger i = 1;
        if (_videosDestacados.count > 0) {
            if (indexPath.section == i) { [self abrirVideo:_videosDestacados[indexPath.row]]; return; }
            i++;
        }
        if (_videosRecientes.count > 0) {
            if (indexPath.section == i) { [self abrirVideo:_videosRecientes[indexPath.row]]; return; }
            i++;
        }
        if (_clips.count > 0) {
            if (indexPath.section == i) { [self abrirClip:_clips[indexPath.row]]; return; }
            i++;
        }
        if (_colecciones.count > 0) { [self abrirColeccion:_colecciones[indexPath.row]]; }
        return;
    }
    if (_pestana == 1) { [self abrirVideo:_videosFiltrados[indexPath.row]]; return; }
    if (_pestana == 2) { [self abrirClip:_clips[indexPath.row]]; return; }
    if (_pestana == 3) { [self abrirColeccion:_colecciones[indexPath.row]]; return; }

    if (_pestana == 4) {
        if (indexPath.section == 2) {
            ITPanel *p = _canal.paneles[indexPath.row];
            if (p.enlace.length) [[UIApplication sharedApplication] openURL:[NSURL URLWithString:p.enlace]];
        } else if (indexPath.section == 3) {
            NSDictionary *s = _canal.sociales[indexPath.row];
            if (s[@"url"]) [[UIApplication sharedApplication] openURL:[NSURL URLWithString:s[@"url"]]];
        }
    }
}

- (void)abrirVideo:(ITVideo *)v {
    ITPlayerViewController *p = [[ITPlayerViewController alloc] initWithVideo:v];
    [self.navigationController pushViewController:p animated:YES];
}

- (void)abrirClip:(ITClip *)c {
    [[ITApi compartida] clip:c.slug completion:^(id objeto, NSError *error) {
        if ([objeto isKindOfClass:[ITClip class]]) {
            ITPlayerViewController *p = [[ITPlayerViewController alloc] initWithClip:objeto];
            [self.navigationController pushViewController:p animated:YES];
        }
    }];
}

- (void)abrirColeccion:(ITCollection *)c {
    ITCollectionViewController *vc = [[ITCollectionViewController alloc] initWithColeccion:c];
    [self.navigationController pushViewController:vc animated:YES];
}

@end
