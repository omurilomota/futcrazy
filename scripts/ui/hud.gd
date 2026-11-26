class_name Hud
extends CanvasLayer

## HUD de partida no estilo de transmissao esportiva de varzea:
## placar em bloco (time / numero / time) com aba de cronometro, tarja de modo,
## banner de evento com barra de tempo, fichas de eventos ativos e mensagens grandes.
## Todo o desenho e chapado, com a paleta do jogo (UiTheme).

var root: Control
var mode_label: Label
var hint: Label
var message: Label
var banner_title: Label
var banner_sub: Label

var _plate: Control
var _team_a: Label
var _team_b: Label
var _score: Label
var _clock: Label
var _banner: Control
var _chips: VBoxContainer
var _flash: ColorRect

var _banner_time := 0.0
var _message_time := 0.0
var _message_dur := 1.0
var _flash_time := 0.0
var _flash_dur := 0.5
var _flash_strength := 0.0
var _chips_sig := ""
var _chip_rows: Array = []


func _ready() -> void:
	layer = 10

	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_build_scoreboard()
	_build_banner()
	_build_message()
	_build_mode_chip()
	_build_chips()
	_build_hint()

	_flash = ColorRect.new()
	_flash.color = Color(1.0, 1.0, 1.0, 0.0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_flash)

	set_score(0, 0)
	set_clock(Cfg.MATCH_TIME)


# ---------------------------------------------------------------- construcao

func _build_scoreboard() -> void:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_CENTER_TOP)
	holder.offset_left = -280.0
	holder.offset_right = 280.0
	holder.offset_top = 14.0
	holder.offset_bottom = 118.0
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(holder)

	_plate = Plate.new()
	_plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_plate)

	_team_a = _text(holder, 20, UiTheme.CREAM, 2.0, 0.7)
	_team_a.position = Vector2(10.0, 14.0)
	_team_a.size = Vector2(180.0, 42.0)
	_team_a.text = Cfg.TEAM_A_NAME

	_team_b = _text(holder, 20, UiTheme.CREAM, 2.0, 0.7)
	_team_b.position = Vector2(370.0, 14.0)
	_team_b.size = Vector2(180.0, 42.0)
	_team_b.text = Cfg.TEAM_B_NAME

	_score = _text(holder, 40, UiTheme.WHITE, 2.0, 1.1)
	_score.position = Vector2(190.0, 4.0)
	_score.size = Vector2(180.0, 56.0)
	_score.text = "0  x  0"

	_clock = _text(holder, 19, UiTheme.INK, 1.5, 0.8)
	_clock.position = Vector2(220.0, 78.0)
	_clock.size = Vector2(120.0, 24.0)
	_clock.text = "02:00"


func _text(parent: Control, size: int, color: Color, tracking: float, embolden: float) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_override("font", UiTheme.display_font(tracking, embolden))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _build_banner() -> void:
	_banner = Control.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_left = -360.0
	_banner.offset_right = 360.0
	_banner.offset_top = 132.0
	_banner.offset_bottom = 206.0
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.draw.connect(_draw_banner)
	root.add_child(_banner)

	banner_title = _text(_banner, 26, UiTheme.YELLOW, 2.5, 0.9)
	banner_title.position = Vector2(24.0, 6.0)
	banner_title.size = Vector2(672.0, 38.0)

	banner_sub = _text(_banner, 14, UiTheme.CREAM_DIM, 2.0, 0.3)
	banner_sub.position = Vector2(24.0, 44.0)
	banner_sub.size = Vector2(672.0, 22.0)


func _draw_banner() -> void:
	if banner_title.text == "":
		return
	var w := _banner.size.x
	var h := _banner.size.y
	_banner.draw_rect(Rect2(0.0, 0.0, w, h), Color(UiTheme.INK.r, UiTheme.INK.g, UiTheme.INK.b, 0.86))
	_banner.draw_rect(Rect2(0.0, 0.0, 6.0, h), banner_title.get_theme_color("font_color"))
	_banner.draw_line(Vector2(0.0, 0.0), Vector2(w, 0.0), Color(UiTheme.CREAM.r, UiTheme.CREAM.g, UiTheme.CREAM.b, 0.22), 1.0)
	_banner.draw_line(Vector2(0.0, h - 1.0), Vector2(w, h - 1.0), Color(UiTheme.CREAM.r, UiTheme.CREAM.g, UiTheme.CREAM.b, 0.22), 1.0)


func _build_message() -> void:
	# acima dos jogadores e so sobre o painel decorativo do estadio: o contorno
	# grosso do banner_text garante leitura sem precisar de uma caixa na tela
	message = UiTheme.banner_text(96)
	message.set_anchors_preset(Control.PRESET_CENTER)
	message.offset_left = -520.0
	message.offset_right = 520.0
	message.offset_top = -130.0
	message.offset_bottom = 50.0
	root.add_child(message)


func _build_mode_chip() -> void:
	var chip := Control.new()
	chip.set_anchors_preset(Control.PRESET_TOP_LEFT)
	chip.offset_left = 18.0
	chip.offset_top = 18.0
	chip.offset_right = 258.0
	chip.offset_bottom = 52.0
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.draw.connect(func() -> void:
		var w := chip.size.x
		var h := chip.size.y
		chip.draw_rect(Rect2(0.0, 0.0, w, h), Color(UiTheme.INK.r, UiTheme.INK.g, UiTheme.INK.b, 0.8))
		chip.draw_rect(Rect2(0.0, 0.0, 4.0, h), UiTheme.YELLOW)
	)
	root.add_child(chip)

	mode_label = Label.new()
	mode_label.position = Vector2(12.0, 0.0)
	mode_label.size = Vector2(230.0, 34.0)
	mode_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mode_label.add_theme_font_size_override("font_size", 13)
	mode_label.add_theme_color_override("font_color", UiTheme.CREAM)
	mode_label.add_theme_font_override("font", UiTheme.display_font(1.6, 0.5))
	mode_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(mode_label)


func _build_chips() -> void:
	_chips = VBoxContainer.new()
	_chips.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_chips.offset_left = -292.0
	_chips.offset_right = -18.0
	_chips.offset_top = 18.0
	_chips.offset_bottom = 130.0
	_chips.alignment = BoxContainer.ALIGNMENT_BEGIN
	_chips.add_theme_constant_override("separation", 6)
	_chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_chips)


func _build_hint() -> void:
	var bar := Control.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -46.0
	bar.offset_bottom = 0.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(func() -> void:
		bar.draw_rect(Rect2(Vector2.ZERO, bar.size), Color(UiTheme.INK.r, UiTheme.INK.g, UiTheme.INK.b, 0.82))
		bar.draw_line(Vector2(0.0, 0.0), Vector2(bar.size.x, 0.0), Color(UiTheme.CREAM.r, UiTheme.CREAM.g, UiTheme.CREAM.b, 0.18), 1.0)
	)
	root.add_child(bar)

	hint = Label.new()
	hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", UiTheme.CREAM_DIM)
	hint.add_theme_font_override("font", UiTheme.display_font(1.2, 0.3))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(hint)


# -------------------------------------------------------------------- API

func set_score(a: int, b: int) -> void:
	if _score != null:
		_score.text = "%d  x  %d" % [a, b]


func set_clock(t: float) -> void:
	if _clock == null:
		return
	var tt := maxf(t, 0.0)
	_clock.text = "%02d:%02d" % [int(tt) / 60, int(tt) % 60]


func set_mode_label(text: String) -> void:
	if mode_label != null:
		mode_label.text = text


func set_hint(text: String) -> void:
	if hint != null:
		hint.text = text


func show_banner(title: String, sub: String, color: Color, seconds: float) -> void:
	if banner_title == null:
		return
	var changed := banner_title.text != title
	banner_title.text = title
	banner_title.add_theme_color_override("font_color", color)
	banner_sub.text = sub
	banner_sub.add_theme_color_override("font_color", UiTheme.CREAM_DIM)
	_banner_time = seconds
	_banner.queue_redraw()
	if changed:
		_banner.pivot_offset = Vector2(_banner.size.x * 0.5, 0.0)
		_banner.scale = Vector2(1.0, 0.82)
		var tw := create_tween()
		tw.tween_property(_banner, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func clear_banner() -> void:
	if banner_title == null:
		return
	banner_title.text = ""
	banner_sub.text = ""
	banner_title.scale = Vector2.ONE
	_banner_time = 0.0
	_banner.queue_redraw()


func flash(text: String, color: Color, seconds := 1.6) -> void:
	if message == null:
		return
	message.text = text
	message.add_theme_color_override("font_color", color)
	message.pivot_offset = message.size * 0.5
	message.scale = Vector2(1.25, 1.25)
	var tw := create_tween()
	tw.tween_property(message, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_message_time = seconds
	_message_dur = maxf(seconds, 0.01)
	message.modulate.a = 1.0


func clear_message() -> void:
	if message != null:
		message.text = ""
	_message_time = 0.0


func set_ui_visible(v: bool) -> void:
	if root != null:
		root.visible = v


func flash_screen(color: Color, strength := 0.4) -> void:
	var scale := Settings.flash_scale() if Settings != null else 1.0
	_flash_strength = clampf(strength * scale, 0.0, 1.0)
	_flash_dur = 0.45
	_flash_time = _flash_dur
	if _flash != null:
		_flash.color = Color(color.r, color.g, color.b, _flash_strength)


## Fichas no canto superior direito: cada evento ativo com cor e tempo restante.
## `entries` = Array de {title, color, time_left, duration}
func set_active_events(entries: Array) -> void:
	if _chips == null:
		return
	var sig := ""
	for e in entries:
		sig += String(e.get("title", "")) + "|"
	if sig != _chips_sig:
		_chips_sig = sig
		for row in _chip_rows:
			row.queue_free()
		_chip_rows.clear()
		for e in entries:
			var row := _make_chip(String(e.get("title", "")), e.get("color", UiTheme.YELLOW))
			_chips.add_child(row)
			_chip_rows.append(row)
	for i in mini(_chip_rows.size(), entries.size()):
		var row: Control = _chip_rows[i]
		var left := float(entries[i].get("time_left", 0.0))
		var dur := maxf(float(entries[i].get("duration", 1.0)), 0.01)
		row.set_meta("fill", clampf(left / dur, 0.0, 1.0))
		var lbl: Label = row.get_meta("label", null)
		if lbl != null:
			lbl.text = "%s  %.1fs" % [String(entries[i].get("title", "")), maxf(left, 0.0)]
		row.queue_redraw()


func _make_chip(title: String, color: Color) -> Control:
	var row := Control.new()
	row.custom_minimum_size = Vector2(0.0, 30.0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_meta("fill", 1.0)
	row.draw.connect(func() -> void:
		var w := row.size.x
		var h := row.size.y
		row.draw_rect(Rect2(0.0, 0.0, w, h), Color(UiTheme.INK.r, UiTheme.INK.g, UiTheme.INK.b, 0.82))
		row.draw_rect(Rect2(0.0, 0.0, 4.0, h), color)
		var fill: float = row.get_meta("fill", 1.0)
		row.draw_rect(Rect2(0.0, h - 3.0, w * fill, 3.0), color)
		row.draw_rect(Rect2(0.0, 0.0, w, h), Color(color.r, color.g, color.b, 0.22), false, 1.0)
	)
	var l := Label.new()
	l.position = Vector2(12.0, 0.0)
	l.size = Vector2(260.0, 30.0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", UiTheme.CREAM)
	l.add_theme_font_override("font", UiTheme.display_font(1.2, 0.4))
	l.text = title
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(l)
	row.set_meta("label", l)
	return row


# ---------------------------------------------------------------- processo

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
		if _flash != null:
			_flash.color.a = _flash_strength * (_flash_time / _flash_dur)


## Placar em blocos: time A | numero | time B, com aba de cronometro embaixo.
class Plate extends Control:
	func _draw() -> void:
		var w := size.x
		var bar_h := 74.0
		var cut := 12.0
		var ink := Color(UiTheme.INK.r, UiTheme.INK.g, UiTheme.INK.b, 0.94)
		var a := Cfg.TEAM_A_COLOR.darkened(0.45)
		var b := Cfg.TEAM_B_COLOR.darkened(0.45)

		# aba do cronometro (desenhada primeiro, atras da barra)
		var tab := PackedVector2Array([
			Vector2(w * 0.5 - 62.0, bar_h - 2.0),
			Vector2(w * 0.5 + 62.0, bar_h - 2.0),
			Vector2(w * 0.5 + 62.0, bar_h + 22.0),
			Vector2(w * 0.5 + 54.0, bar_h + 30.0),
			Vector2(w * 0.5 - 54.0, bar_h + 30.0),
			Vector2(w * 0.5 - 62.0, bar_h + 22.0),
		])
		draw_colored_polygon(tab, UiTheme.YELLOW)

		# barra principal com cantos chanfrados
		var bar := PackedVector2Array([
			Vector2(cut, 0.0),
			Vector2(w - cut, 0.0),
			Vector2(w, cut),
			Vector2(w, bar_h - cut),
			Vector2(w - cut, bar_h),
			Vector2(cut, bar_h),
			Vector2(0.0, bar_h - cut),
			Vector2(0.0, cut),
		])
		draw_colored_polygon(bar, ink)
		draw_rect(Rect2(0.0, 0.0, 190.0, bar_h), a)
		draw_rect(Rect2(370.0, 0.0, w - 370.0, bar_h), b)

		# faixa superior amarela: assinatura de transmissao
		draw_rect(Rect2(0.0, 0.0, w, 3.0), UiTheme.YELLOW)
		# borda creme
		var outline := bar.duplicate()
		outline.append(bar[0])
		draw_polyline(outline, UiTheme.CREAM, 2.0)
		# separadores
		draw_line(Vector2(190.0, 4.0), Vector2(190.0, bar_h), Color(UiTheme.CREAM.r, UiTheme.CREAM.g, UiTheme.CREAM.b, 0.35), 1.5)
		draw_line(Vector2(370.0, 4.0), Vector2(370.0, bar_h), Color(UiTheme.CREAM.r, UiTheme.CREAM.g, UiTheme.CREAM.b, 0.35), 1.5)
		# faixas de cor dos times nas pontas
		draw_rect(Rect2(0.0, bar_h - 4.0, 190.0, 4.0), Cfg.TEAM_A_COLOR)
		draw_rect(Rect2(370.0, bar_h - 4.0, w - 370.0, 4.0), Cfg.TEAM_B_COLOR)
