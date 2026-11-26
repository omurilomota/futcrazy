class_name MenuScreen
extends CanvasLayer

## Todas as telas de interface do jogo, com a identidade visual do FutCrazy:
## menu principal, selecao de modo, opcoes, controles, creditos, pausa e resultado.
##
## Construido por codigo com componentes reutilizaveis (FcButton, FcPoster, FcLogo)
## e uma paleta/tipografia unica (UiTheme). Navegacao completa por mouse e teclado:
## setas/TAB movem o foco, ENTER confirma, ESC volta.

signal mode_selected(mode: int)
signal resume_requested
signal restart_requested
signal menu_requested
signal quit_requested

const MODES := [
	{
		"id": 1,
		"num": "01",
		"name": "UM JOGADOR",
		"line": "Você contra um bot atrapalhado.",
		"feat": "CÂMERA FIXA · PARTIDA CURTA",
		"meta": "1 x BOT",
		"dots": 1,
		"accent": UiTheme.BLUE,
	},
	{
		"id": 2,
		"num": "02",
		"name": "DOIS JOGADORES",
		"line": "Mesmo teclado, um de cada lado.",
		"feat": "TECLADO COMPARTILHADO",
		"meta": "2 P LOCAL",
		"dots": 1,
		"accent": UiTheme.RED,
	},
	{
		"id": 3,
		"num": "03",
		"name": "CAMPO TODO",
		"line": "5 x 5 com goleiros e formação.",
		"feat": "GOLEIROS · FORMAÇÃO · TROCA",
		"meta": "5 x 5",
		"dots": 5,
		"accent": UiTheme.YELLOW,
	},
]

const OPTION_SECTIONS := ["ÁUDIO", "VÍDEO", "ACESSIBILIDADE", "PARTIDA"]
const MATCH_TIME_INDEX := 1

var sfx: Sfx

var _root: Control
var _screens: Dictionary = {}
var _first_focus: Dictionary = {}
var _screen := ""
var _return_to := "main"
var _visible := false

# opcoes
var _option_section := 0
var _option_body: VBoxContainer
var _option_sections: Array[VBoxContainer] = []
var _option_tabs: Array[FcButton] = []
var _refreshers: Array[Callable] = []

# controles
var _binding_buttons: Dictionary = {}
var _listen_action := ""
var _listen_button: FcButton
var _bind_warning: Label

# confirmacao
var _confirm_layer: Control
var _confirm_title: Label
var _confirm_text: Label
var _confirm_yes: FcButton
var _confirm_action := Callable()

# pausa / resultado
var _pause_score: Label
var _pause_clock: Label
var _result_mode: Label
var _result_score: Label
var _result_names: Label
var _result_stats: VBoxContainer
var _result_headline: Label


func _ready() -> void:
	layer = 20
	visible = false

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	_build_main()
	_build_modes()
	_build_options()
	_build_controls()
	_build_credits()
	_build_pause()
	_build_results()
	_build_confirm()


# ===================================================================== API

func show_main() -> void:
	_open("main")


func show_modes() -> void:
	_open("modes")


func show_options(from_screen := "main") -> void:
	_return_to = from_screen
	_open("options")


func show_controls(from_screen := "main") -> void:
	_return_to = from_screen
	_open("controls")


func show_credits() -> void:
	_return_to = "main"
	_open("credits")


func show_pause(score_text: String, clock_text: String) -> void:
	if _pause_score != null:
		_pause_score.text = score_text
	if _pause_clock != null:
		_pause_clock.text = clock_text
	_return_to = "pause"
	_open("pause")


func show_results(data: Dictionary) -> void:
	_return_to = "results"
	_result_mode.text = String(data.get("mode", ""))
	_result_headline.text = String(data.get("headline", "FIM DE JOGO"))
	_result_score.text = "%d  x  %d" % [int(data.get("a", 0)), int(data.get("b", 0))]
	_result_names.text = "%s  ·  %s" % [
		String(data.get("name_a", Cfg.TEAM_A_NAME)),
		String(data.get("name_b", Cfg.TEAM_B_NAME)),
	]
	for child in _result_stats.get_children():
		child.queue_free()
	var stats: Dictionary = data.get("stats", {})
	for row in [
		["GOLS", int(stats.get("goals", 0))],
		["CHUTES", int(stats.get("kicks", 0))],
		["CARRINHOS", int(stats.get("tackles", 0))],
		["PANCADAS", int(stats.get("hits", 0))],
	]:
		_result_stats.add_child(_stat_row(String(row[0]), int(row[1])))
	_open("results")


func hide_all() -> void:
	_visible = false
	visible = false
	_cancel_listen()
	_hide_confirm()


func is_open() -> bool:
	return _visible


func current_screen() -> String:
	return _screen


## ESC / botao voltar. Devolve true se a tela tratou o voltar.
func back() -> bool:
	if _confirm_layer != null and _confirm_layer.visible:
		_hide_confirm()
		return true
	if _listen_action != "":
		_cancel_listen()
		_refresh_bindings()
		return true
	match _screen:
		"main":
			return false
		"modes", "credits":
			_open("main")
			return true
		"options", "controls":
			_open(_return_to if _return_to != "" else "main")
			return true
		"pause":
			resume_requested.emit()
			return true
		"results":
			menu_requested.emit()
			return true
	return false


# ================================================================== helpers

func _screen_node(name: String) -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.visible = false
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(c)
	_screens[name] = c
	return c


func _dim(parent: Control, alpha := 0.9) -> void:
	var d := ColorRect.new()
	d.color = Color(UiTheme.INK.r, UiTheme.INK.g, UiTheme.INK.b, alpha)
	d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(d)


func _margin(parent: Control, left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_theme_constant_override("margin_left", left)
	m.add_theme_constant_override("margin_top", top)
	m.add_theme_constant_override("margin_right", right)
	m.add_theme_constant_override("margin_bottom", bottom)
	parent.add_child(m)
	return m


func _vbox(sep := 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


func _hbox(sep := 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return h


func _btn(text: String, kind := FcButton.Kind.GHOST, accent := UiTheme.YELLOW, cb := Callable()) -> FcButton:
	var b := FcButton.new()
	b.text = text
	b.kind = kind
	b.accent = accent
	b.custom_minimum_size = Vector2(0, 52)
	if cb.is_valid():
		b.pressed.connect(cb)
	_wire(b)
	return b


func _wire(b: Control) -> void:
	if b is BaseButton:
		var bb := b as BaseButton
		bb.pressed.connect(_click_sfx)
		bb.focus_entered.connect(_hover_sfx)
		bb.mouse_entered.connect(func() -> void:
			if bb.focus_mode != Control.FOCUS_NONE:
				bb.grab_focus()
		)


func _click_sfx() -> void:
	if sfx != null:
		sfx.play("ui", -14.0, 0.9)


func _hover_sfx() -> void:
	if sfx != null:
		sfx.play("ui", -24.0, 1.45)


func _header(parent: Control, kicker: String, title: String, sub := "") -> void:
	var v := _vbox(6)
	parent.add_child(v)
	v.add_child(UiTheme.caption(kicker, 14, UiTheme.CREAM_DIM))
	v.add_child(UiTheme.title(title, 44))
	if sub != "":
		v.add_child(UiTheme.label(sub, 17, UiTheme.CREAM_DIM))


func _mini_pitch(dots: int, accent: Color) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, 62)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void:
		var w := c.size.x
		var h := c.size.y
		if w < 8.0:
			return
		var line := Color(UiTheme.CREAM.r, UiTheme.CREAM.g, UiTheme.CREAM.b, 0.22)
		c.draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)), Color(0.35, 0.55, 0.35, 0.10))
		c.draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)), line, false, 1.5)
		c.draw_line(Vector2(w * 0.5, 0.0), Vector2(w * 0.5, h), line, 1.5)
		c.draw_arc(Vector2(w * 0.5, h * 0.5), h * 0.17, 0.0, TAU, 24, line, 1.5)
		for side in 2:
			for i in dots:
				var t := 0.0 if dots <= 1 else float(i) / float(dots - 1)
				var x := w * (0.10 + 0.34 * t) if side == 0 else w * (0.90 - 0.34 * t)
				var y := h * (0.5 + (0.18 if i % 2 == 1 else -0.18) * (1.0 if dots > 1 else 0.0))
				c.draw_circle(Vector2(x, y), 4.5, accent)
	)
	return c


# ==================================================================== menu

func _build_main() -> void:
	var s := _screen_node("main")

	var poster := FcPoster.new()
	poster.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	poster.anchor_right = 0.46
	poster.offset_right = 0.0
	poster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.add_child(poster)

	var m := _margin(s, 58, 40, 0, 34)
	m.anchor_right = 0.46
	m.offset_right = -30.0
	var col := _vbox(0)
	m.add_child(col)

	col.add_child(UiTheme.caption("campeonato de várzea · edição 2026", 13, UiTheme.YELLOW.darkened(0.1)))
	col.add_child(UiTheme.spacer(10))

	var logo := FcLogo.new()
	logo.custom_minimum_size = Vector2(400, 92)
	logo.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(logo)

	col.add_child(UiTheme.spacer(6))
	var tag1 := UiTheme.label("não é um simulador de futebol.", 19, UiTheme.CREAM, 0.0, 0.25)
	col.add_child(tag1)
	var tag2 := UiTheme.label("é comédia física com cenário de futebol.", 19, UiTheme.CREAM_DIM, 0.0, 0.0)
	col.add_child(tag2)

	col.add_child(UiTheme.spacer(26))
	col.add_child(UiTheme.rule(UiTheme.CREAM_DIM.darkened(0.4), 2))
	col.add_child(UiTheme.spacer(22))

	var buttons := _vbox(10)
	buttons.custom_minimum_size = Vector2(340, 0)
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(buttons)

	var b_play := _btn("JOGAR", FcButton.Kind.PRIMARY, UiTheme.YELLOW, show_modes)
	b_play.custom_minimum_size = Vector2(340, 60)
	buttons.add_child(b_play)
	buttons.add_child(_btn("OPÇÕES", FcButton.Kind.GHOST, UiTheme.YELLOW, show_options.bind("main")))
	buttons.add_child(_btn("CONTROLES", FcButton.Kind.GHOST, UiTheme.CREAM_DIM, show_controls.bind("main")))
	buttons.add_child(_btn("CRÉDITOS", FcButton.Kind.GHOST, UiTheme.CREAM_DIM, show_credits))
	buttons.add_child(_btn("SAIR", FcButton.Kind.DANGER, UiTheme.RED, func() -> void: quit_requested.emit()))

	col.add_child(UiTheme.spacer(0))
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(filler)

	col.add_child(UiTheme.rule(UiTheme.CREAM_DIM.darkened(0.5), 1))
	col.add_child(UiTheme.spacer(8))
	var foot := _hbox(14)
	col.add_child(foot)
	foot.add_child(UiTheme.caption("v%s" % Settings.GAME_VERSION, 12, UiTheme.CREAM_DIM))
	foot.add_child(UiTheme.caption("godot %s" % _engine_version(), 12, UiTheme.CREAM_DIM.darkened(0.2)))

	# carimbo inclinado no canto direito: assinatura de cartaz
	var stamp := UiTheme.label("EDIÇÃO DE VÁRZEA", 20, UiTheme.YELLOW, 5.0, 0.8)
	stamp.add_theme_constant_override("outline_size", 8)
	stamp.add_theme_color_override("font_outline_color", UiTheme.INK)
	stamp.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	stamp.offset_left = -300.0
	stamp.offset_right = -54.0
	stamp.offset_top = 54.0
	stamp.offset_bottom = 92.0
	stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stamp.rotation_degrees = -6.0
	s.add_child(stamp)

	var hint := UiTheme.caption("setas navegam · enter confirma · esc volta", 12, UiTheme.CREAM_DIM)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.offset_left = -420.0
	hint.offset_right = -54.0
	hint.offset_top = -56.0
	hint.offset_bottom = -30.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	s.add_child(hint)

	_first_focus["main"] = b_play


func _engine_version() -> String:
	var info := Engine.get_version_info()
	return "%d.%d.%d" % [int(info.get("major", 4)), int(info.get("minor", 0)), int(info.get("patch", 0))]


# ================================================================== modos

func _build_modes() -> void:
	var s := _screen_node("modes")
	_dim(s, 0.93)

	var m := _margin(s, 64, 48, 64, 40)
	var col := _vbox(0)
	m.add_child(col)

	_header(col, "escolha a sua partida", "MODO DE JOGO", "Três jeitos de perder a compostura no mesmo campo.")
	col.add_child(UiTheme.spacer(16))
	col.add_child(UiTheme.rule(UiTheme.CREAM_DIM.darkened(0.5), 2))
	col.add_child(UiTheme.spacer(24))

	var cards := _hbox(18)
	col.add_child(cards)

	var first: FcButton = null
	for info in MODES:
		var card := FcButton.new()
		card.text = ""
		card.kind = FcButton.Kind.CARD
		card.accent = info["accent"]
		card.show_chevron = false
		card.custom_minimum_size = Vector2(0, 350)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.pressed.connect(_on_mode_pressed.bind(int(info["id"])))
		_wire(card)
		cards.add_child(card)

		var pad := _margin(card, 22, 20, 22, 20)
		pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var body := _vbox(0)
		pad.add_child(body)

		var top := _hbox(10)
		body.add_child(top)
		var num := UiTheme.label(String(info["num"]), 15, info["accent"], 3.0, 0.9)
		top.add_child(num)
		top.add_child(UiTheme.caption(String(info["meta"]), 12, UiTheme.CREAM_DIM))

		body.add_child(UiTheme.spacer(10))
		var name_label := UiTheme.label(String(info["name"]), 25, UiTheme.CREAM, 1.5, 0.9)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(name_label)

		body.add_child(UiTheme.spacer(6))
		var line_label := UiTheme.label(String(info["line"]), 15, UiTheme.CREAM_DIM)
		line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(line_label)

		body.add_child(UiTheme.spacer(10))
		body.add_child(UiTheme.caption(String(info["feat"]), 10, info["accent"]))

		var filler := Control.new()
		filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
		filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(filler)

		body.add_child(_mini_pitch(int(info["dots"]), info["accent"]))
		body.add_child(UiTheme.spacer(8))
		body.add_child(UiTheme.caption("ENTER para começar", 11, UiTheme.CREAM_DIM.darkened(0.25)))

		if first == null:
			first = card

	col.add_child(UiTheme.spacer(0))
	var filler2 := Control.new()
	filler2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	filler2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(filler2)

	var foot := _hbox(12)
	col.add_child(foot)
	var back_btn := _btn("VOLTAR", FcButton.Kind.GHOST, UiTheme.CREAM_DIM, func() -> void: _open("main"))
	back_btn.custom_minimum_size = Vector2(180, 48)
	foot.add_child(back_btn)

	_first_focus["modes"] = first


func _on_mode_pressed(mode: int) -> void:
	mode_selected.emit(mode)


# ================================================================= opcoes

func _build_options() -> void:
	var s := _screen_node("options")
	_dim(s, 0.94)

	var m := _margin(s, 64, 44, 64, 36)
	var col := _vbox(0)
	m.add_child(col)

	_header(col, "ajuste a bagunça", "OPÇÕES", "Tudo aqui vale de verdade e fica salvo ao fechar o jogo.")
	col.add_child(UiTheme.spacer(14))
	col.add_child(UiTheme.rule(UiTheme.CREAM_DIM.darkened(0.5), 2))
	col.add_child(UiTheme.spacer(18))

	var row := _hbox(24)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(row)

	var tabs := _vbox(8)
	tabs.custom_minimum_size = Vector2(230, 0)
	row.add_child(tabs)
	for i in OPTION_SECTIONS.size():
		var tab := _btn(String(OPTION_SECTIONS[i]), FcButton.Kind.CHIP, UiTheme.YELLOW, _select_section.bind(i))
		tab.custom_minimum_size = Vector2(230, 46)
		tab.alignment = HORIZONTAL_ALIGNMENT_LEFT
		tab.add_theme_font_size_override("font_size", 17)
		tabs.add_child(tab)
		_option_tabs.append(tab)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_box(26))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(panel)

	_option_body = _vbox(0)
	panel.add_child(_option_body)

	for i in OPTION_SECTIONS.size():
		var sec := _vbox(14)
		sec.visible = i == 0
		_option_body.add_child(sec)
		_option_sections.append(sec)

	_build_audio_section(_option_sections[0])
	_build_video_section(_option_sections[1])
	_build_a11y_section(_option_sections[2])
	_build_game_section(_option_sections[3])

	var body_grow := Control.new()
	body_grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_grow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_option_body.add_child(body_grow)
	_option_body.add_child(UiTheme.rule(UiTheme.CREAM_DIM.darkened(0.55), 1))
	_option_body.add_child(UiTheme.label(
		"futcrazy v%s  ·  preferências em user://futcrazy.cfg" % Settings.GAME_VERSION,
		12, UiTheme.CREAM_DIM.darkened(0.1)))

	col.add_child(UiTheme.spacer(16))
	var foot := _hbox(12)
	col.add_child(foot)
	var reset := _btn("RESTAURAR PADRÕES", FcButton.Kind.DANGER, UiTheme.RED, _ask_reset_defaults)
	reset.custom_minimum_size = Vector2(250, 46)
	reset.add_theme_font_size_override("font_size", 17)
	foot.add_child(reset)

	var grow := Control.new()
	grow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.add_child(grow)

	var back_btn := _btn("VOLTAR", FcButton.Kind.GHOST, UiTheme.CREAM_DIM, _options_back)
	back_btn.custom_minimum_size = Vector2(180, 46)
	foot.add_child(back_btn)

	_first_focus["options"] = _option_tabs[0]


func _options_back() -> void:
	_open(_return_to if _return_to != "" else "main")


func _select_section(i: int) -> void:
	_option_section = i
	for j in _option_sections.size():
		_option_sections[j].visible = j == i
	for j in _option_tabs.size():
		var on := j == i
		_option_tabs[j].kind = FcButton.Kind.PRIMARY if on else FcButton.Kind.CHIP
		_option_tabs[j].add_theme_color_override("font_color", UiTheme.INK if on else UiTheme.CREAM)


func _build_audio_section(sec: VBoxContainer) -> void:
	sec.add_child(UiTheme.caption("volume", 13, UiTheme.YELLOW))
	_add_slider(sec, "VOLUME GERAL", "audio/master", 0.0, 1.0, 0.05, "pct")
	_add_slider(sec, "EFEITOS SONOROS", "audio/sfx", 0.0, 1.0, 0.05, "pct")
	_add_slider(sec, "TORCIDA / AMBIENTE", "audio/ambience", 0.0, 1.0, 0.05, "pct")
	sec.add_child(UiTheme.spacer(6))
	sec.add_child(UiTheme.label(
		"Não existe música no jogo, então não existe controle de música.",
		14, UiTheme.CREAM_DIM))


func _build_video_section(sec: VBoxContainer) -> void:
	sec.add_child(UiTheme.caption("tela", 13, UiTheme.YELLOW))
	_add_toggle(sec, "TELA CHEIA", "video/fullscreen")
	_add_toggle(sec, "VSYNC", "video/vsync")
	_add_slider(sec, "ESCALA DA INTERFACE", "video/ui_scale", 0.8, 1.3, 0.05, "pct_scale")
	sec.add_child(UiTheme.spacer(6))
	sec.add_child(UiTheme.label(
		"A resolução acompanha a janela; o jogo usa escala por canvas e continua legível em outras proporções.",
		14, UiTheme.CREAM_DIM))


func _build_a11y_section(sec: VBoxContainer) -> void:
	sec.add_child(UiTheme.caption("conforto visual", 13, UiTheme.YELLOW))
	_add_slider(sec, "INTENSIDADE DO TREMOR", "a11y/shake", 0.0, 1.0, 0.1, "pct")
	_add_slider(sec, "INTENSIDADE DOS FLASHES", "a11y/flash", 0.0, 1.0, 0.1, "pct")
	_add_toggle(sec, "EFEITOS DE PARTÍCULA", "a11y/effects")
	sec.add_child(UiTheme.spacer(6))
	sec.add_child(UiTheme.label(
		"Com os flashes em 0% a tela não pisca; o tremor em 0% deixa a câmera totalmente estável.",
		14, UiTheme.CREAM_DIM))


func _build_game_section(sec: VBoxContainer) -> void:
	sec.add_child(UiTheme.caption("regras da partida", 13, UiTheme.YELLOW))
	_add_choice(sec, "DURAÇÃO", "game/match_time", ["1 MIN", "2 MIN", "3 MIN"], MATCH_TIME_INDEX)
	_add_choice(sec, "RITMO DOS EVENTOS", "game/event_rate", ["RARO", "NORMAL", "CAOS"], null)
	_add_choice(sec, "DIFICULDADE DOS BOTS", "game/bot_difficulty", Settings.BOT_DIFFICULTY_NAMES, null)
	sec.add_child(UiTheme.spacer(6))
	sec.add_child(UiTheme.label(
		"Ritmo raro espaça os eventos; caos quase dobra a frequência e aumenta as combinações.",
		14, UiTheme.CREAM_DIM))


func _row_shell(parent: VBoxContainer, name: String) -> HBoxContainer:
	var row := _hbox(16)
	row.custom_minimum_size = Vector2(0, 40)
	parent.add_child(row)
	var l := UiTheme.label(name, 16, UiTheme.CREAM, 1.5, 0.3)
	l.custom_minimum_size = Vector2(250, 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	return row


func _add_slider(parent: VBoxContainer, name: String, key: String, minv: float, maxv: float, step: float, fmt: String) -> void:
	var row := _row_shell(parent, name)
	var slider := HSlider.new()
	slider.min_value = minv
	slider.max_value = maxv
	slider.step = step
	slider.value = float(Settings.get_value(key))
	slider.custom_minimum_size = Vector2(220, 26)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_ALL
	_style_slider(slider)
	row.add_child(slider)

	var val := UiTheme.label(_format(fmt, slider.value), 16, UiTheme.YELLOW, 1.0, 0.5)
	val.custom_minimum_size = Vector2(74, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(val)

	slider.value_changed.connect(func(v: float) -> void:
		Settings.set_value(key, v)
		val.text = _format(fmt, v)
	)
	_refreshers.append(func() -> void:
		slider.set_value_no_signal(float(Settings.get_value(key)))
		val.text = _format(fmt, slider.value)
	)


func _style_slider(slider: HSlider) -> void:
	var track := UiTheme.box(Color(0.02, 0.05, 0.03, 0.9), UiTheme.CREAM_DIM.darkened(0.45), 1, 0)
	track.content_margin_top = 5
	track.content_margin_bottom = 5
	var fill := UiTheme.box(UiTheme.YELLOW.darkened(0.15), UiTheme.YELLOW, 1, 0)
	fill.content_margin_top = 5
	fill.content_margin_bottom = 5
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)


func _format(fmt: String, v: float) -> String:
	match fmt:
		"pct":
			return "%d%%" % int(round(v * 100.0))
		"pct_scale":
			return "%d%%" % int(round(v * 100.0))
		_:
			return str(v)


func _add_toggle(parent: VBoxContainer, name: String, key: String) -> void:
	var row := _row_shell(parent, name)
	var grow := Control.new()
	grow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(grow)

	var b := FcButton.new()
	b.kind = FcButton.Kind.CHIP
	b.show_chevron = false
	b.custom_minimum_size = Vector2(150, 38)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_font_size_override("font_size", 15)
	b.pressed.connect(func() -> void:
		Settings.set_value(key, not bool(Settings.get_value(key)))
		_refresh_options()
	)
	_wire(b)
	row.add_child(b)
	_refreshers.append(func() -> void:
		var on := bool(Settings.get_value(key))
		b.text = "LIGADO" if on else "DESLIGADO"
		b.accent = UiTheme.YELLOW if on else UiTheme.CREAM_DIM.darkened(0.3)
	)


func _add_choice(parent: VBoxContainer, name: String, key: String, labels: Array, forced_index) -> void:
	var row := _row_shell(parent, name)
	var grow := Control.new()
	grow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(grow)

	var b := FcButton.new()
	b.kind = FcButton.Kind.CHIP
	b.show_chevron = false
	b.custom_minimum_size = Vector2(180, 38)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_font_size_override("font_size", 15)
	b.pressed.connect(func() -> void:
		var idx := _choice_index(key, labels, forced_index)
		idx = (idx + 1) % labels.size()
		Settings.set_value(key, _choice_value(key, idx))
		_refresh_options()
	)
	_wire(b)
	row.add_child(b)
	_refreshers.append(func() -> void:
		var idx := _choice_index(key, labels, forced_index)
		b.text = String(labels[idx])
	)


## Converte valor salvo -> indice do rotulo.
func _choice_index(key: String, labels: Array, forced_index) -> int:
	if forced_index != null:
		var v := float(Settings.get_value(key))
		var best := 0
		var best_d := INF
		for i in Settings.MATCH_TIME_CHOICES.size():
			var d: float = absf(float(Settings.MATCH_TIME_CHOICES[i]) - v)
			if d < best_d:
				best_d = d
				best = i
		return best
	return clampi(int(Settings.get_value(key)), 0, labels.size() - 1)


func _choice_value(key: String, idx: int) -> Variant:
	if key == "game/match_time":
		return float(Settings.MATCH_TIME_CHOICES[clampi(idx, 0, 2)])
	return idx


func _refresh_options() -> void:
	for r in _refreshers:
		r.call()
	_select_section(_option_section)


func _ask_reset_defaults() -> void:
	_confirm(
		"RESTAURAR PADRÕES",
		"Isso apaga suas preferências de áudio, vídeo, acessibilidade, partida e controles. Não dá para desfazer.",
		"RESTAURAR",
		func() -> void:
			Settings.reset_to_defaults()
			_refresh_options()
			_refresh_bindings()
	)


# =============================================================== controles

func _build_controls() -> void:
	var s := _screen_node("controls")
	_dim(s, 0.94)

	var m := _margin(s, 64, 44, 64, 34)
	var col := _vbox(0)
	m.add_child(col)

	_header(col, "quem aperta o quê", "CONTROLES", "Clique na tecla para remapear. O jogo recusa teclas repetidas.")
	col.add_child(UiTheme.spacer(14))
	col.add_child(UiTheme.rule(UiTheme.CREAM_DIM.darkened(0.5), 2))
	col.add_child(UiTheme.spacer(18))

	var cols := _hbox(20)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(cols)

	_build_bind_column(cols, "JOGADOR 1", UiTheme.BLUE, "p1")
	_build_bind_column(cols, "JOGADOR 2", UiTheme.RED, "p2")

	col.add_child(UiTheme.spacer(14))
	_bind_warning = UiTheme.label("", 15, UiTheme.YELLOW)
	col.add_child(_bind_warning)

	var foot := _hbox(12)
	col.add_child(foot)
	var reset := _btn("RESTAURAR CONTROLES", FcButton.Kind.DANGER, UiTheme.RED, func() -> void:
		Settings.reset_bindings()
		_bind_warning.text = "Controles restaurados para o padrão."
		_refresh_bindings()
	)
	reset.custom_minimum_size = Vector2(260, 46)
	reset.add_theme_font_size_override("font_size", 17)
	foot.add_child(reset)

	foot.add_child(UiTheme.caption("pausa: ESC   ·   reiniciar: R   ·   tela cheia: F11", 13, UiTheme.CREAM_DIM))

	var grow := Control.new()
	grow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.add_child(grow)

	var back_btn := _btn("VOLTAR", FcButton.Kind.GHOST, UiTheme.CREAM_DIM, func() -> void: _open(_return_to))
	back_btn.custom_minimum_size = Vector2(180, 46)
	foot.add_child(back_btn)


func _build_bind_column(parent: HBoxContainer, title_text: String, accent: Color, prefix: String) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_box(20))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)

	var v := _vbox(10)
	panel.add_child(v)

	var head := _hbox(10)
	v.add_child(head)
	var tag := ColorRect.new()
	tag.color = accent
	tag.custom_minimum_size = Vector2(6, 24)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(tag)
	head.add_child(UiTheme.title(title_text, 24, UiTheme.CREAM))
	v.add_child(UiTheme.rule(UiTheme.CREAM_DIM.darkened(0.55), 1))

	for action in ["left", "right", "jump", "kick", "tackle"]:
		var full := "%s_%s" % [prefix, action]
		var row := _hbox(12)
		v.add_child(row)
		var l := UiTheme.label(String(Settings.ACTION_LABELS[action]), 14, UiTheme.CREAM_DIM, 1.2, 0.3)
		l.custom_minimum_size = Vector2(0, 40)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(l)

		var b := FcButton.new()
		b.kind = FcButton.Kind.CHIP
		b.show_chevron = false
		b.accent = accent
		b.custom_minimum_size = Vector2(160, 40)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_font_size_override("font_size", 16)
		b.pressed.connect(_start_listen.bind(full))
		_wire(b)
		row.add_child(b)
		_binding_buttons[full] = b


func _refresh_bindings() -> void:
	for action in _binding_buttons.keys():
		var b: FcButton = _binding_buttons[action]
		if action == _listen_action:
			b.text = "PRESSIONE…"
		else:
			b.text = Settings.key_label(Settings.key_for(action))


func _start_listen(action: String) -> void:
	_listen_action = action
	_listen_button = _binding_buttons.get(action)
	_bind_warning.text = "Aperte a tecla para %s  ·  ESC cancela" % Settings.action_label(action)
	_refresh_bindings()


func _cancel_listen() -> void:
	_listen_action = ""
	_listen_button = null


func _input(event: InputEvent) -> void:
	if not _visible or _listen_action == "":
		return
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	get_viewport().set_input_as_handled()

	var key := key_event.physical_keycode
	if key == KEY_ESCAPE:
		_cancel_listen()
		_refresh_bindings()
		_bind_warning.text = ""
		return

	var conflict := Settings.conflict_for(_listen_action, key)
	if conflict != "":
		var who := conflict
		if conflict.begins_with("p"):
			who = Settings.action_label(conflict)
		_bind_warning.text = "%s já usa essa tecla. Escolha outra." % who
		_cancel_listen()
		_refresh_bindings()
		return

	Settings.set_binding(_listen_action, key)
	_bind_warning.text = "%s agora é %s." % [Settings.action_label(_listen_action), Settings.key_label(key)]
	_cancel_listen()
	_refresh_bindings()


# ================================================================ creditos

func _build_credits() -> void:
	var s := _screen_node("credits")
	_dim(s, 0.94)

	var m := _margin(s, 64, 44, 64, 36)
	var col := _vbox(0)
	m.add_child(col)

	_header(col, "quem fez essa bagunça", "CRÉDITOS", "")
	col.add_child(UiTheme.spacer(14))
	col.add_child(UiTheme.rule(UiTheme.CREAM_DIM.darkened(0.5), 2))
	col.add_child(UiTheme.spacer(20))

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_box(28))
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(panel)

	var v := _vbox(10)
	panel.add_child(v)

	for row in [
		["CONCEITO E CÓDIGO", "projeto FutCrazy"],
		["ENGINE", "Godot %s (MIT)" % _engine_version()],
		["ÁUDIO", "síntese própria em Python (tools/gen_audio.py)"],
		["MODELOS 3D", "gerados no Blender pelo próprio projeto (tools/blender/)"],
		["VISUAL", "tudo procedural: nenhum asset externo"],
		["INSPIRAÇÃO", "futebol de várzea, transmissão de TV e física desajeitada"],
	]:
		var line := _hbox(16)
		v.add_child(line)
		var k := UiTheme.caption(String(row[0]), 12, UiTheme.YELLOW.darkened(0.05))
		k.custom_minimum_size = Vector2(220, 0)
		line.add_child(k)
		line.add_child(UiTheme.label(String(row[1]), 16, UiTheme.CREAM))

	v.add_child(UiTheme.spacer(10))
	var about := UiTheme.label(
		"FutCrazy não é um simulador de futebol. É comédia física com cenário de futebol: "
		+ "a partida começa normal e vai perdendo a seriedade. Nenhum jogador foi machucado de verdade.",
		15, UiTheme.CREAM_DIM)
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(about)

	var grow := Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(grow)

	var foot := _hbox(12)
	col.add_child(UiTheme.spacer(14))
	col.add_child(foot)
	var back_btn := _btn("VOLTAR", FcButton.Kind.GHOST, UiTheme.CREAM_DIM, func() -> void: _open("main"))
	back_btn.custom_minimum_size = Vector2(180, 46)
	foot.add_child(back_btn)

	_first_focus["credits"] = back_btn


# =================================================================== pausa

func _build_pause() -> void:
	var s := _screen_node("pause")
	_dim(s, 0.72)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_box(30))
	panel.custom_minimum_size = Vector2(520, 0)
	center.add_child(panel)

	var v := _vbox(0)
	panel.add_child(v)

	v.add_child(UiTheme.caption("a partida está congelada", 12, UiTheme.YELLOW))
	v.add_child(UiTheme.title("PAUSADO", 40))
	v.add_child(UiTheme.spacer(12))
	v.add_child(UiTheme.rule(UiTheme.CREAM_DIM.darkened(0.5), 1))
	v.add_child(UiTheme.spacer(12))

	_pause_score = UiTheme.label("", 22, UiTheme.CREAM, 1.5, 0.6)
	v.add_child(_pause_score)
	_pause_clock = UiTheme.caption("", 13, UiTheme.CREAM_DIM)
	v.add_child(_pause_clock)

	v.add_child(UiTheme.spacer(20))

	var b_continue := _btn("CONTINUAR", FcButton.Kind.PRIMARY, UiTheme.YELLOW, func() -> void: resume_requested.emit())
	b_continue.custom_minimum_size = Vector2(0, 56)
	v.add_child(b_continue)
	v.add_child(_btn("REINICIAR PARTIDA", FcButton.Kind.GHOST, UiTheme.CREAM_DIM, func() -> void:
		_confirm("REINICIAR PARTIDA", "O placar e o tempo voltam do zero.", "REINICIAR", func() -> void:
			restart_requested.emit()
		)
	))
	v.add_child(_btn("CONTROLES", FcButton.Kind.GHOST, UiTheme.CREAM_DIM, func() -> void: show_controls("pause")))
	v.add_child(_btn("OPÇÕES", FcButton.Kind.GHOST, UiTheme.CREAM_DIM, func() -> void: show_options("pause")))
	v.add_child(_btn("VOLTAR AO MENU", FcButton.Kind.DANGER, UiTheme.RED, func() -> void:
		_confirm("VOLTAR AO MENU", "A partida atual será encerrada e o placar perdido.", "SAIR PARA O MENU", func() -> void:
			menu_requested.emit()
		)
	))

	_first_focus["pause"] = b_continue


# ================================================================ resultado

func _build_results() -> void:
	var s := _screen_node("results")
	_dim(s, 0.86)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_box(32))
	panel.custom_minimum_size = Vector2(680, 0)
	center.add_child(panel)

	var v := _vbox(0)
	panel.add_child(v)

	_result_mode = UiTheme.caption("", 12, UiTheme.YELLOW)
	v.add_child(_result_mode)
	_result_headline = UiTheme.title("FIM DE JOGO", 40)
	v.add_child(_result_headline)
	v.add_child(UiTheme.spacer(10))
	v.add_child(UiTheme.rule(UiTheme.CREAM_DIM.darkened(0.5), 2))
	v.add_child(UiTheme.spacer(14))

	_result_score = UiTheme.label("0  x  0", 66, UiTheme.CREAM, 3.0, 1.2)
	_result_score.add_theme_constant_override("outline_size", 8)
	_result_score.add_theme_color_override("font_outline_color", UiTheme.INK)
	v.add_child(_result_score)
	_result_names = UiTheme.caption("", 14, UiTheme.CREAM_DIM)
	v.add_child(_result_names)

	v.add_child(UiTheme.spacer(18))
	_result_stats = _vbox(6)
	v.add_child(_result_stats)
	v.add_child(UiTheme.spacer(22))

	var b_rematch := _btn("REVANCHE", FcButton.Kind.PRIMARY, UiTheme.YELLOW, func() -> void: restart_requested.emit())
	b_rematch.custom_minimum_size = Vector2(0, 56)
	v.add_child(b_rematch)
	v.add_child(_btn("MENU PRINCIPAL", FcButton.Kind.GHOST, UiTheme.CREAM_DIM, func() -> void: menu_requested.emit()))

	_first_focus["results"] = b_rematch


func _stat_row(name: String, value: int) -> Control:
	var row := _hbox(12)
	var l := UiTheme.label(name, 15, UiTheme.CREAM_DIM, 1.5, 0.3)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	row.add_child(UiTheme.label(str(value), 18, UiTheme.CREAM, 1.0, 0.6))
	return row


# =============================================================== confirmacao

func _build_confirm() -> void:
	_confirm_layer = Control.new()
	_confirm_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm_layer.visible = false
	_confirm_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_confirm_layer)

	var dim := ColorRect.new()
	dim.color = Color(UiTheme.INK.r, UiTheme.INK.g, UiTheme.INK.b, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm_layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm_layer.add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_box(28))
	panel.custom_minimum_size = Vector2(520, 0)
	center.add_child(panel)

	var v := _vbox(0)
	panel.add_child(v)
	_confirm_title = UiTheme.title("", 28, UiTheme.CREAM)
	v.add_child(_confirm_title)
	v.add_child(UiTheme.spacer(10))
	_confirm_text = UiTheme.label("", 16, UiTheme.CREAM_DIM)
	_confirm_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_text.custom_minimum_size = Vector2(0, 60)
	v.add_child(_confirm_text)
	v.add_child(UiTheme.spacer(18))

	var row := _hbox(12)
	v.add_child(row)
	_confirm_yes = _btn("CONFIRMAR", FcButton.Kind.DANGER, UiTheme.RED, func() -> void:
		var act := _confirm_action
		_hide_confirm()
		if act.is_valid():
			act.call()
	)
	_confirm_yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_confirm_yes)
	var no := _btn("CANCELAR", FcButton.Kind.GHOST, UiTheme.CREAM_DIM, _hide_confirm)
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(no)


func _confirm(title_text: String, text: String, yes_label: String, action: Callable) -> void:
	_confirm_title.text = title_text
	_confirm_text.text = text
	_confirm_yes.text = yes_label
	_confirm_action = action
	_confirm_layer.visible = true
	_confirm_yes.grab_focus()


func _hide_confirm() -> void:
	if _confirm_layer != null:
		_confirm_layer.visible = false


# ================================================================== navegacao

func _open(name: String) -> void:
	_cancel_listen()
	_hide_confirm()
	_screen = name
	_visible = true
	visible = true
	for key in _screens.keys():
		var node: Control = _screens[key]
		node.visible = key == name

	if name == "options":
		_refresh_options()
	elif name == "controls":
		_bind_warning.text = ""
		_refresh_bindings()

	var first: Control = _first_focus.get(name)
	if first != null and first.is_inside_tree():
		first.call_deferred("grab_focus")
