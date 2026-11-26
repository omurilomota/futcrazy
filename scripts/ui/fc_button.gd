class_name FcButton
extends Button

## Botao com a identidade do FutCrazy: chapa de cor, borda grossa, canto vivo,
## barra de destaque a esquerda e chevron a direita.
##
## Estados visuais completos (normal / hover / pressionado / foco / desabilitado),
## navegacao por teclado e feedback sonoro ficam a cargo do dono do botao.

enum Kind { PRIMARY, GHOST, DANGER, CARD, CHIP }

var kind := Kind.GHOST:
	set(v):
		kind = v
		_restyle()

var accent := UiTheme.YELLOW:
	set(v):
		accent = v
		_restyle()

var show_chevron := true:
	set(v):
		show_chevron = v
		queue_redraw()

var _hovered := false


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	clip_text = false
	add_theme_font_override("font", UiTheme.display_font(2.0, 0.7))
	add_theme_font_size_override("font_size", 22)
	add_theme_constant_override("outline_size", 0)
	_restyle()

	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	focus_entered.connect(_on_hover.bind(true))
	focus_exited.connect(_on_hover.bind(false))


func _on_hover(v: bool) -> void:
	if _hovered == v:
		return
	_hovered = v
	queue_redraw()


func _restyle() -> void:
	var base := UiTheme.box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 18)
	var border := Color.TRANSPARENT
	var fg := UiTheme.CREAM
	var bg := Color(0, 0, 0, 0)

	match kind:
		Kind.PRIMARY:
			bg = UiTheme.CREAM
			fg = UiTheme.INK
			border = UiTheme.CREAM
		Kind.GHOST:
			bg = Color(0.055, 0.11, 0.075, 0.55)
			fg = UiTheme.CREAM
			border = UiTheme.CREAM_DIM.darkened(0.3)
		Kind.DANGER:
			bg = Color(0.28, 0.07, 0.055, 0.7)
			fg = UiTheme.CREAM
			border = UiTheme.RED
		Kind.CARD:
			bg = Color(0.055, 0.11, 0.075, 0.72)
			fg = UiTheme.CREAM
			border = UiTheme.CREAM_DIM.darkened(0.45)
		Kind.CHIP:
			bg = Color(0.055, 0.11, 0.075, 0.5)
			fg = UiTheme.CREAM
			border = UiTheme.CREAM_DIM.darkened(0.4)

	var normal := base.duplicate() as StyleBoxFlat
	normal.bg_color = bg
	normal.border_color = border
	if kind != Kind.CHIP:
		normal.border_width_left = 2
		normal.border_width_top = 2
		normal.border_width_right = 2
		normal.border_width_bottom = 2

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = _lift(bg)
	hover.border_color = accent

	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = _sink(bg)

	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(bg.r, bg.g, bg.b, bg.a * 0.4)
	disabled.border_color = Color(border.r, border.g, border.b, 0.3)

	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = accent
	focus.border_width_left = 2
	focus.border_width_top = 2
	focus.border_width_right = 2
	focus.border_width_bottom = 2
	focus.set_expand_margin_all(3.0)

	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", pressed)
	add_theme_stylebox_override("disabled", disabled)
	add_theme_stylebox_override("focus", focus)
	add_theme_stylebox_override("hover_pressed", pressed)

	add_theme_color_override("font_color", fg)
	add_theme_color_override("font_hover_color", UiTheme.WHITE if kind != Kind.PRIMARY else UiTheme.INK)
	add_theme_color_override("font_pressed_color", fg)
	add_theme_color_override("font_focus_color", fg)
	add_theme_color_override("font_disabled_color", Color(fg.r, fg.g, fg.b, 0.35))

	queue_redraw()


func _lift(c: Color) -> Color:
	if c.a < 0.01:
		return Color(0.09, 0.17, 0.115, 0.85)
	return c.lightened(0.10)


func _sink(c: Color) -> Color:
	if c.a < 0.01:
		return Color(0.03, 0.06, 0.04, 0.9)
	return c.darkened(0.12)


func _draw() -> void:
	# barra de destaque a esquerda: assinatura visual dos botoes
	var bar_w := 5.0 if kind != Kind.CHIP else 3.0
	var bar_h := size.y - 16.0
	if kind == Kind.CARD:
		bar_h = minf(size.y - 24.0, 64.0)
	var col := accent
	if disabled:
		col = Color(accent.r, accent.g, accent.b, 0.25)
	elif not (_hovered or has_focus()):
		col = Color(accent.r, accent.g, accent.b, 0.75)
	draw_rect(Rect2(0, (size.y - bar_h) * 0.5, bar_w, bar_h), col)

	if show_chevron and kind != Kind.CARD:
		var cx := size.x - 26.0
		var cy := size.y * 0.5
		var a := 1.0 if (_hovered or has_focus()) else 0.45
		var chev := PackedVector2Array([
			Vector2(cx - 5.0, cy - 7.0),
			Vector2(cx + 2.0, cy),
			Vector2(cx - 5.0, cy + 7.0),
			Vector2(cx - 8.0, cy + 7.0),
			Vector2(cx - 1.0, cy),
			Vector2(cx - 8.0, cy - 7.0),
		])
		draw_colored_polygon(chev, Color(col.r, col.g, col.b, a))
