#import "ITCells.h"
#import "ITTheme.h"
#import "ITUtil.h"
#import "ITImageCache.h"

#pragma mark - ITStreamCell (tarjeta grande)

@implementation ITStreamCell {
    UIImageView *_foto;
    UILabel *_directo;
    UILabel *_espectadores;
    UILabel *_titulo;
    UILabel *_canal;
    UILabel *_juego;
    UIView *_vivo;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = [ITTheme fondo];
        self.contentView.backgroundColor = [ITTheme fondo];
        self.selectionStyle = UITableViewCellSelectionStyleNone;

        _foto = [[UIImageView alloc] init];
        _foto.contentMode = UIViewContentModeScaleAspectFill;
        _foto.clipsToBounds = YES;
        _foto.backgroundColor = [ITTheme superficie];
        _foto.layer.cornerRadius = 8.0;
        [self.contentView addSubview:_foto];

        _vivo = [[UIView alloc] init];
        _vivo.backgroundColor = [UIColor colorWithRed:0.85 green:0.12 blue:0.16 alpha:1.0];
        _vivo.layer.cornerRadius = 4.0;
        [_foto addSubview:_vivo];

        _directo = ITLabel(@"EN DIRECTO", [UIFont systemFontOfSize:9.0 weight:UIFontWeightBold],
                           [UIColor whiteColor]);
        [_vivo addSubview:_directo];

        _espectadores = ITLabel(@"", [UIFont systemFontOfSize:9.0 weight:UIFontWeightSemibold],
                                [UIColor whiteColor]);
        _espectadores.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.72];
        _espectadores.textAlignment = NSTextAlignmentCenter;
        _espectadores.layer.cornerRadius = 4.0;
        _espectadores.clipsToBounds = YES;
        [_foto addSubview:_espectadores];

        _titulo = ITLabel(@"", [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold],
                          [ITTheme textoPrimario]);
        _titulo.numberOfLines = 2;
        [self.contentView addSubview:_titulo];

        _canal = ITLabel(@"", [ITTheme fuenteCuerpo], [ITTheme textoSecundario]);
        [self.contentView addSubview:_canal];

        _juego = ITLabel(@"", [ITTheme fuenteMenuda], [ITTheme textoSecundario]);
        _juego.textAlignment = NSTextAlignmentRight;
        [self.contentView addSubview:_juego];
    }
    return self;
}

- (void)configurarConStream:(ITStream *)s {
    _titulo.text = s.titulo;
    _canal.text = s.nombre;
    _juego.text = s.juego;
    _espectadores.text = [NSString stringWithFormat:@" %@ ", ITNumeroCorto(s.viewers)];
    _vivo.hidden = !s.enDirecto;
    _directo.hidden = !s.enDirecto;
    [ITImageCache cargarURL:ITImagen(s.miniatura, 640, 360) en:_foto];
    [self setNeedsLayout];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    [ITImageCache cancelarPara:_foto];
    _foto.image = nil;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat ancho = self.contentView.bounds.size.width;
    CGFloat altoFoto = MIN(ancho * 9.0 / 16.0, 240.0);
    _foto.frame = CGRectMake(0, 0, ancho, altoFoto);

    CGSize tam = [_directo sizeThatFits:CGSizeMake(200, 20)];
    _vivo.frame = CGRectMake(8, 8, tam.width + 14, 18);
    _directo.frame = CGRectMake(7, 2, tam.width, 14);

    CGSize esp = [_espectadores sizeThatFits:CGSizeMake(200, 20)];
    _espectadores.frame = CGRectMake(ancho - esp.width - 8, 8, esp.width, 18);

    _titulo.frame = CGRectMake(0, altoFoto + 8, ancho, 36);
    _canal.frame = CGRectMake(0, altoFoto + 46, ancho * 0.56, 18);
    _juego.frame = CGRectMake(ancho * 0.56, altoFoto + 46, ancho * 0.44 - 2, 18);
}

@end

#pragma mark - ITStreamRowCell (fila compacta)

@implementation ITStreamRowCell {
    UIImageView *_foto;
    UILabel *_titulo;
    UILabel *_canal;
    UILabel *_meta;
    UILabel *_vivo;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = [ITTheme fondo];
        self.contentView.backgroundColor = [ITTheme fondo];
        self.selectionStyle = UITableViewCellSelectionStyleDefault;
        UIView *sel = [[UIView alloc] init];
        sel.backgroundColor = [ITTheme superficieAlta];
        self.selectedBackgroundView = sel;

        _foto = [[UIImageView alloc] init];
        _foto.contentMode = UIViewContentModeScaleAspectFill;
        _foto.clipsToBounds = YES;
        _foto.backgroundColor = [ITTheme superficie];
        _foto.layer.cornerRadius = 6.0;
        [self.contentView addSubview:_foto];

        _vivo = ITLabel(@"EN DIRECTO", [UIFont systemFontOfSize:8.0 weight:UIFontWeightBold],
                        [UIColor whiteColor]);
        _vivo.backgroundColor = [UIColor colorWithRed:0.85 green:0.12 blue:0.16 alpha:1.0];
        _vivo.textAlignment = NSTextAlignmentCenter;
        _vivo.layer.cornerRadius = 3.0;
        _vivo.clipsToBounds = YES;
        [_foto addSubview:_vivo];

        _titulo = ITLabel(@"", [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold],
                          [ITTheme textoPrimario]);
        _titulo.numberOfLines = 2;
        [self.contentView addSubview:_titulo];

        _canal = ITLabel(@"", [ITTheme fuenteCuerpo], [ITTheme textoSecundario]);
        [self.contentView addSubview:_canal];

        _meta = ITLabel(@"", [ITTheme fuenteMenuda], [ITTheme textoSecundario]);
        [self.contentView addSubview:_meta];
    }
    return self;
}

- (void)configurarConStream:(ITStream *)s {
    _titulo.text = s.titulo;
    _canal.text = s.nombre;
    _meta.text = [NSString stringWithFormat:@"%@ · %@ espectadores", s.juego ?: @"", ITNumeroCorto(s.viewers)];
    _vivo.hidden = !s.enDirecto;
    [ITImageCache cargarURL:ITImagen(s.miniatura, 320, 180) en:_foto];
    [self setNeedsLayout];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    [ITImageCache cancelarPara:_foto];
    _foto.image = nil;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat ancho = self.contentView.bounds.size.width;
    _foto.frame = CGRectMake(12, 8, 112, 63);
    _vivo.frame = CGRectMake(4, 4, 62, 14);
    _titulo.frame = CGRectMake(132, 8, ancho - 144, 36);
    _canal.frame = CGRectMake(132, 45, ancho - 144, 16);
    _meta.frame = CGRectMake(132, 61, ancho - 144, 14);
}

@end

#pragma mark - ITGameCell

@implementation ITGameCell {
    UIImageView *_foto;
    UILabel *_nombre;
    UILabel *_meta;
    UILabel *_chevron;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = [ITTheme fondo];
        self.contentView.backgroundColor = [ITTheme fondo];
        UIView *sel = [[UIView alloc] init];
        sel.backgroundColor = [ITTheme superficieAlta];
        self.selectedBackgroundView = sel;

        _foto = [[UIImageView alloc] init];
        _foto.contentMode = UIViewContentModeScaleAspectFill;
        _foto.clipsToBounds = YES;
        _foto.backgroundColor = [ITTheme superficie];
        _foto.layer.cornerRadius = 4.0;
        [self.contentView addSubview:_foto];

        _nombre = ITLabel(@"", [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold],
                          [ITTheme textoPrimario]);
        _nombre.numberOfLines = 1;
        [self.contentView addSubview:_nombre];

        _meta = ITLabel(@"", [ITTheme fuenteCuerpo], [ITTheme textoSecundario]);
        [self.contentView addSubview:_meta];

        _chevron = ITLabel(@">", [UIFont systemFontOfSize:18.0 weight:UIFontWeightMedium],
                           [ITTheme textoSecundario]);
        _chevron.textAlignment = NSTextAlignmentRight;
        [self.contentView addSubview:_chevron];
    }
    return self;
}

- (void)configurarConJuego:(ITGame *)g {
    _nombre.text = g.mostrado;
    _meta.text = [NSString stringWithFormat:@"%@ espectadores", ITNumeroCorto(g.viewers)];
    [ITImageCache cargarURL:ITImagen(g.portada, 120, 160) en:_foto];
    [self setNeedsLayout];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    [ITImageCache cancelarPara:_foto];
    _foto.image = nil;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat ancho = self.contentView.bounds.size.width;
    _foto.frame = CGRectMake(12, 8, 42, 56);
    _nombre.frame = CGRectMake(66, 14, ancho - 104, 20);
    _meta.frame = CGRectMake(66, 36, ancho - 104, 16);
    _chevron.frame = CGRectMake(ancho - 30, 16, 20, 24);
}

@end

#pragma mark - ITVideoCell

@implementation ITVideoCell {
    UIImageView *_foto;
    UILabel *_duracion;
    UILabel *_titulo;
    UILabel *_meta;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = [ITTheme fondo];
        self.contentView.backgroundColor = [ITTheme fondo];
        UIView *sel = [[UIView alloc] init];
        sel.backgroundColor = [ITTheme superficieAlta];
        self.selectedBackgroundView = sel;

        _foto = [[UIImageView alloc] init];
        _foto.contentMode = UIViewContentModeScaleAspectFill;
        _foto.clipsToBounds = YES;
        _foto.backgroundColor = [ITTheme superficie];
        _foto.layer.cornerRadius = 5.0;
        [self.contentView addSubview:_foto];

        _duracion = ITLabel(@"", [UIFont systemFontOfSize:9.0 weight:UIFontWeightSemibold],
                            [UIColor whiteColor]);
        _duracion.textAlignment = NSTextAlignmentCenter;
        _duracion.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.75];
        _duracion.layer.cornerRadius = 3.0;
        _duracion.clipsToBounds = YES;
        [_foto addSubview:_duracion];

        _titulo = ITLabel(@"", [UIFont systemFontOfSize:13.5 weight:UIFontWeightSemibold],
                          [ITTheme textoPrimario]);
        _titulo.numberOfLines = 2;
        [self.contentView addSubview:_titulo];

        _meta = ITLabel(@"", [ITTheme fuenteMenuda], [ITTheme textoSecundario]);
        [self.contentView addSubview:_meta];
    }
    return self;
}

- (void)configurarConVideo:(ITVideo *)v {
    _titulo.text = v.titulo;
    _duracion.text = [NSString stringWithFormat:@" %@ ", ITDuracion(v.duracion)];
    _meta.text = [NSString stringWithFormat:@"%@ visitas · %@", ITNumeroCorto(v.vistas), ITHace(v.creado)];
    [ITImageCache cargarURL:ITImagen(v.miniatura, 320, 180) en:_foto];
    [self setNeedsLayout];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    [ITImageCache cancelarPara:_foto];
    _foto.image = nil;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat ancho = self.contentView.bounds.size.width;
    _foto.frame = CGRectMake(12, 10, 120, 68);
    CGSize d = [_duracion sizeThatFits:CGSizeMake(100, 20)];
    _duracion.frame = CGRectMake(120 - d.width - 4, 68 - 18, d.width, 14);
    _titulo.frame = CGRectMake(144, 10, ancho - 156, 36);
    _meta.frame = CGRectMake(144, 48, ancho - 156, 16);
}

@end

#pragma mark - ITClipCell

@implementation ITClipCell {
    UIImageView *_foto;
    UILabel *_duracion;
    UILabel *_titulo;
    UILabel *_meta;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = [ITTheme fondo];
        self.contentView.backgroundColor = [ITTheme fondo];
        UIView *sel = [[UIView alloc] init];
        sel.backgroundColor = [ITTheme superficieAlta];
        self.selectedBackgroundView = sel;

        _foto = [[UIImageView alloc] init];
        _foto.contentMode = UIViewContentModeScaleAspectFill;
        _foto.clipsToBounds = YES;
        _foto.backgroundColor = [ITTheme superficie];
        _foto.layer.cornerRadius = 5.0;
        [self.contentView addSubview:_foto];

        _duracion = ITLabel(@"", [UIFont systemFontOfSize:9.0 weight:UIFontWeightSemibold],
                            [UIColor whiteColor]);
        _duracion.textAlignment = NSTextAlignmentCenter;
        _duracion.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.75];
        _duracion.layer.cornerRadius = 3.0;
        _duracion.clipsToBounds = YES;
        [_foto addSubview:_duracion];

        _titulo = ITLabel(@"", [UIFont systemFontOfSize:13.5 weight:UIFontWeightSemibold],
                          [ITTheme textoPrimario]);
        _titulo.numberOfLines = 2;
        [self.contentView addSubview:_titulo];

        _meta = ITLabel(@"", [ITTheme fuenteMenuda], [ITTheme textoSecundario]);
        [self.contentView addSubview:_meta];
    }
    return self;
}

- (void)configurarConClip:(ITClip *)c {
    _titulo.text = c.titulo;
    _duracion.text = [NSString stringWithFormat:@" %@ ", ITDuracion(c.duracion)];
    _meta.text = [NSString stringWithFormat:@"%@ visitas · por %@", ITNumeroCorto(c.vistas), c.curador];
    [ITImageCache cargarURL:ITImagen(c.miniatura, 320, 180) en:_foto];
    [self setNeedsLayout];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    [ITImageCache cancelarPara:_foto];
    _foto.image = nil;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat ancho = self.contentView.bounds.size.width;
    _foto.frame = CGRectMake(12, 10, 120, 68);
    CGSize d = [_duracion sizeThatFits:CGSizeMake(100, 20)];
    _duracion.frame = CGRectMake(120 - d.width - 4, 68 - 18, d.width, 14);
    _titulo.frame = CGRectMake(144, 10, ancho - 156, 36);
    _meta.frame = CGRectMake(144, 48, ancho - 156, 16);
}

@end

#pragma mark - ITCollectionCell

@implementation ITCollectionCell {
    UIImageView *_icono;
    UILabel *_titulo;
    UILabel *_meta;
    UILabel *_chevron;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = [ITTheme fondo];
        self.contentView.backgroundColor = [ITTheme fondo];
        UIView *sel = [[UIView alloc] init];
        sel.backgroundColor = [ITTheme superficieAlta];
        self.selectedBackgroundView = sel;

        _icono = [[UIImageView alloc] initWithImage:[ITTheme icono:@"lista" lado:24]];
        _icono.tintColor = [ITTheme acento];
        [self.contentView addSubview:_icono];

        _titulo = ITLabel(@"", [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold],
                          [ITTheme textoPrimario]);
        [self.contentView addSubview:_titulo];

        _meta = ITLabel(@"", [ITTheme fuenteCuerpo], [ITTheme textoSecundario]);
        [self.contentView addSubview:_meta];

        _chevron = ITLabel(@">", [UIFont systemFontOfSize:18.0 weight:UIFontWeightMedium],
                           [ITTheme textoSecundario]);
        _chevron.textAlignment = NSTextAlignmentRight;
        [self.contentView addSubview:_chevron];
    }
    return self;
}

- (void)configurarConColeccion:(ITCollection *)c {
    _titulo.text = c.titulo;
    _meta.text = [NSString stringWithFormat:@"%lu vídeos", (unsigned long)c.videos.count];
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat ancho = self.contentView.bounds.size.width;
    _icono.frame = CGRectMake(16, 24, 24, 24);
    _titulo.frame = CGRectMake(52, 14, ancho - 90, 20);
    _meta.frame = CGRectMake(52, 36, ancho - 90, 16);
    _chevron.frame = CGRectMake(ancho - 30, 18, 20, 24);
}

@end

#pragma mark - ITChannelCell

@implementation ITChannelCell {
    UIImageView *_avatar;
    UILabel *_nombre;
    UILabel *_estado;
    UILabel *_punto;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = [ITTheme fondo];
        self.contentView.backgroundColor = [ITTheme fondo];
        UIView *sel = [[UIView alloc] init];
        sel.backgroundColor = [ITTheme superficieAlta];
        self.selectedBackgroundView = sel;

        _avatar = [[UIImageView alloc] init];
        _avatar.contentMode = UIViewContentModeScaleAspectFill;
        _avatar.clipsToBounds = YES;
        _avatar.backgroundColor = [ITTheme superficie];
        _avatar.layer.cornerRadius = 24.0;
        [self.contentView addSubview:_avatar];

        _punto = ITLabel(@"", [UIFont systemFontOfSize:9.0 weight:UIFontWeightBold],
                         [UIColor whiteColor]);
        _punto.backgroundColor = [UIColor colorWithRed:0.85 green:0.12 blue:0.16 alpha:1.0];
        _punto.textAlignment = NSTextAlignmentCenter;
        _punto.layer.cornerRadius = 3.0;
        _punto.clipsToBounds = YES;
        _punto.text = @"EN DIRECTO";
        [_avatar addSubview:_punto];

        _nombre = ITLabel(@"", [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold],
                          [ITTheme textoPrimario]);
        [self.contentView addSubview:_nombre];

        _estado = ITLabel(@"", [ITTheme fuenteCuerpo], [ITTheme textoSecundario]);
        [self.contentView addSubview:_estado];
    }
    return self;
}

- (void)configurarConCanal:(ITChannel *)c {
    _nombre.text = c.nombre;
    _punto.hidden = !c.enDirecto;
    if (c.enDirecto) {
        _estado.text = [NSString stringWithFormat:@"%@ · %@ espectadores",
                        c.directoJuego ?: @"", ITNumeroCorto(c.directoViewers)];
        _estado.textColor = [ITTheme acento];
    } else {
        _estado.text = [NSString stringWithFormat:@"%@ seguidores", ITMillones(c.seguidores)];
        _estado.textColor = [ITTheme textoSecundario];
    }
    [ITImageCache cargarURL:ITImagen(c.avatar, 100, 100) en:_avatar];
    [self setNeedsLayout];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    [ITImageCache cancelarPara:_avatar];
    _avatar.image = nil;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat ancho = self.contentView.bounds.size.width;
    _avatar.frame = CGRectMake(14, 10, 48, 48);
    CGSize p = [_punto sizeThatFits:CGSizeMake(100, 14)];
    _punto.frame = CGRectMake(48 - p.width - 2, 48 - 12, p.width, 11);
    _nombre.frame = CGRectMake(76, 13, ancho - 90, 20);
    _estado.frame = CGRectMake(76, 35, ancho - 90, 16);
}

@end

#pragma mark - ITTextCell

@implementation ITTextCell {
    UILabel *_titulo;
    UILabel *_detalle;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = [ITTheme superficie];
        self.contentView.backgroundColor = [ITTheme superficie];
        _titulo = ITLabel(@"", [UIFont systemFontOfSize:15.0 weight:UIFontWeightMedium],
                          [ITTheme textoPrimario]);
        _titulo.numberOfLines = 0;
        [self.contentView addSubview:_titulo];
        _detalle = ITLabel(@"", [ITTheme fuenteCuerpo], [ITTheme textoSecundario]);
        _detalle.numberOfLines = 0;
        [self.contentView addSubview:_detalle];
    }
    return self;
}

- (void)configurarTitulo:(NSString *)titulo detalle:(NSString *)detalle {
    _titulo.text = titulo;
    _detalle.text = detalle;
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat ancho = self.contentView.bounds.size.width;
    CGFloat y = 10;
    CGSize t = [_titulo sizeThatFits:CGSizeMake(ancho - 28, 999)];
    _titulo.frame = CGRectMake(14, y, ancho - 28, t.height);
    y += t.height + 3;
    CGSize d = [_detalle sizeThatFits:CGSizeMake(ancho - 28, 999)];
    _detalle.frame = CGRectMake(14, y, ancho - 28, d.height);
}

@end
