class_name UiTheme
extends RefCounted

## Identidade visual do FutCrazy.
##
## Direcao de arte: futebol de varzea + transmissao esportiva + cartaz de campeonato
## local. Verde escuro de gramado, creme envelhecido de papel, amarelo de arbitragem
## e as cores dos dois times. Tudo desenhado por codigo (nenhum asset externo), com
## tipografia pesada de cartaz (embolden + tracking) e formas angulares.
##
## Nada de glassmorphism, gradiente em tudo ou cartao arredondado generico: os
## paineis sao chapados, com borda grossa e canto vivo.

# ------------------------------------------------------------------- paleta

const INK := Color("#0a0f0c")          ## preto esverdeado (fundo do cartaz)
const PITCH_DEEP := Color("#112619")   ## verde de campo na sombra
const CREAM := Color("#f4e9cf")        ## papel envelhecido (texto principal)
const CREAM_DIM := Color("#b3a583")    ## texto secundario
const YELLOW := Color("#f5c542")       ## amarelo de arbitragem (destaque)
const RED := Color("#c93a2e")          ## time vermelho / perigo
const BLUE := Color("#3a7bd5")         ## time azul
const WHITE := Color("#fdf8ec")

# ------------------------------------------------------------------ fontes

static var _font_cache: Dictionary = {}


## Fonte de cartaz: mesma fonte da engine, mas engrossada e com espacamento entre
## letras. `slant` inclina levemente para dar movimento de letreiro esportivo.
static func display_font(tracking := 2.0, embolden := 0.9, slant := 0.0) -> FontVariation:
	var key := "%0.2f|%0.2f|%0.2f" % [tracking, embolden, slant]
	if _font_cache.has(key):
		return _font_cache[key]
	var fv := FontVariation.new()
	fv.base_font = ThemeDB.fallback_font
	fv.variation_embolden = embolden
	fv.spacing_glyph = int(tracking)
	if absf(slant) > 0.001:
		fv.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(slant, 1.0), Vector2.ZERO)
	_font_cache[key] = fv
	return fv


# ------------------------------------------------------------------ caixas

static func box(bg: Color, border: Color = Color.TRANSPARENT, border_w := 0, pad := 16) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = 0
	sb.corner_radius_top_right = 0
	sb.corner_radius_bottom_left = 0
	sb.corner_radius_bottom_right = 0
	if border_w > 0:
		sb.border_width_left = border_w
		sb.border_width_top = border_w
		sb.border_width_right = border_w
		sb.border_width_bottom = border_w
		sb.border_color = border
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad * 0.6
	sb.content_margin_bottom = pad * 0.6
	return sb


static func panel_box(pad := 24) -> StyleBoxFlat:
	return box(Color(0.043, 0.086, 0.06, 0.94), CREAM_DIM.darkened(0.35), 2, pad)


# ------------------------------------------------------------------ widgets

static func label(text: String, size := 18, color := CREAM, tracking := 0.0, embolden := 0.0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if tracking != 0.0 or embolden != 0.0:
		l.add_theme_font_override("font", display_font(tracking, embolden))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Titulo de secao: caixa alta, tracking largo, amarelo de arbitragem.
static func title(text: String, size := 34, color := YELLOW) -> Label:
	var l := label(text.to_upper(), size, color, 4.0, 1.1)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", INK)
	return l


static func caption(text: String, size := 14, color := CREAM_DIM) -> Label:
	return label(text.to_upper(), size, color, 2.0, 0.35)


static func rule(color := CREAM_DIM, height := 2) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.custom_minimum_size = Vector2(0, height)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func spacer(height := 12) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Texto grande com contorno pesado, usado em mensagens de tela cheia.
static func banner_text(size := 112) -> Label:
	var l := label("", size, YELLOW, 3.0, 1.2)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_constant_override("outline_size", maxi(8, size / 8))
	l.add_theme_color_override("font_outline_color", INK)
	return l
