class_name Hud
extends CanvasLayer

## HUD montado por código: placar, cronômetro, banner de evento e mensagens grandes.

var score_label: Label
var clock_label: Label
var banner_title: Label
var banner_sub: Label
var message: Label
var hint: Label

var root: Control
var flash_rect: ColorRect

var _banner_time := 0.0
var _message_time := 0.0
var _message_dur := 1.0
var _flash_time := 0.0
var _flash_dur := 1.0
var _flash_strength := 0.0


func _ready() -> void:
	layer = 10

	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	score_label = _make(root, 44, 10.0, 54.0, Color("#f8fafc"))
	clock_label = _make(root, 24, 62.0, 30.0, Color("#dbeafe"))
	banner_title = _make(root, 44, 104.0, 56.0, Color("#fde68a"))
	banner_sub = _make(root, 24, 158.0, 30.0, Color("#fef3c7"))
	message = _make(root, 112, 250.0, 150.0, Color("#fde68a"))

	# flash de tela (gol): desenhado acima do texto, abaixo do menu
	flash_rect = ColorRect.new()
	flash_rect.color = Color(1.0, 1.0, 1.0, 0.0)
	flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flash_rect)

	hint = Label.new()
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", Color("#f1f5f9"))
	hint.add_theme_constant_override("outline_size", 6)
	hint.add_theme_color_override("font_outline_color", Color(0.03, 0.05, 0.08, 0.95))
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -52.0
	hint.offset_bottom = -10.0
	hint.text = ""
	root.add_child(hint)

	set_score(0, 0)
	set_clock(Cfg.MATCH_TIME)


func _make(parent: Control, size: int, y: float, height: float, color: Color) -> Label:
	var l := Label.new()
	l.text = ""
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", maxi(4, size / 9))
	l.add_theme_color_override("font_outline_color", Color(0.03, 0.05, 0.08, 0.95))
	l.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	l.offset_top = y
	l.offset_bottom = y + height
	parent.add_child(l)
	return l


func set_score(a: int, b: int) -> void:
	score_label.text = "%s  %d  x  %d  %s" % [Cfg.TEAM_A_NAME, a, b, Cfg.TEAM_B_NAME]


func set_clock(t: float) -> void:
	var tt := maxf(t, 0.0)
	clock_label.text = "%02d:%02d" % [int(tt) / 60, int(tt) % 60]


func show_banner(title: String, sub: String, color: Color, seconds: float) -> void:
	banner_title.text = title
	banner_title.add_theme_color_override("font_color", color)
	banner_sub.text = sub
	banner_sub.add_theme_color_override("font_color", color.lightened(0.35))
	banner_title.modulate.a = 1.0
	banner_sub.modulate.a = 1.0
	_banner_time = seconds


func clear_banner() -> void:
	banner_title.text = ""
	banner_sub.text = ""
	_banner_time = 0.0


func flash(text: String, color: Color, seconds := 1.6) -> void:
	message.text = text
	message.add_theme_color_override("font_color", color)
	_message_time = seconds
	_message_dur = maxf(seconds, 0.01)
	message.modulate.a = 1.0


func set_hint(text: String) -> void:
	hint.text = text


## Esconde todo o HUD de partida (usado no menu inicial).
func set_ui_visible(v: bool) -> void:
	root.visible = v


func clear_message() -> void:
	message.text = ""
	_message_time = 0.0


## Pisca a tela inteira na cor do time (usado no gol).
func flash_screen(color: Color, strength := 0.4) -> void:
	_flash_strength = clampf(strength, 0.0, 1.0)
	_flash_dur = 0.5
	_flash_time = _flash_dur
	flash_rect.color = Color(color.r, color.g, color.b, _flash_strength)


func _process(delta: float) -> void:
	if _banner_time > 0.0:
		_banner_time -= delta
		if _banner_time <= 0.0:
			clear_banner()

	if _message_time > 0.0:
		_message_time -= delta
		message.modulate.a = clampf(_message_time / maxf(_message_dur * 0.5, 0.01), 0.0, 1.0)
		if _message_time <= 0.0:
			message.text = ""

	if _flash_time > 0.0:
		_flash_time = maxf(0.0, _flash_time - delta)
		flash_rect.color.a = _flash_strength * (_flash_time / _flash_dur)
