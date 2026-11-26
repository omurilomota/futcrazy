extends Node3D

## Galeria de UI: abre todas as telas sem rodar uma partida.
##
## Uso: abra `scenes/dev/ui_gallery.tscn` no editor e aperte F6.
## `0` mostra só o HUD, `1`..`7` mostram cada tela do menu, `ESC` volta ao menu.
## HUD e menu nunca aparecem juntos — é assim que o jogo se comporta.
## O estádio aparece ao fundo para dar o contraste real do campo.
##
## É uma cena de desenvolvimento: o jogo não a carrega.

@onready var hud: Hud = $Hud
@onready var menu: MenuScreen = $Menu
@onready var stadium: Stadium = $Stadium


func _ready() -> void:
	stadium.build(null)
	_build_help()
	_fill_hud()

	# sem uma partida, os sinais do menu só precisam não deixar a tela travada
	menu.mode_selected.connect(func(mode_id: int) -> void: print("[GALERIA] modo escolhido: %d" % mode_id))
	menu.resume_requested.connect(show_screen.bind(1))
	menu.restart_requested.connect(show_screen.bind(1))
	menu.menu_requested.connect(show_screen.bind(1))
	menu.quit_requested.connect(func() -> void: get_tree().quit())

	show_screen(1)


func _fill_hud() -> void:
	hud.set_score(2, 1)
	hud.set_clock(73.0)
	hud.set_mode_label("GALERIA DE UI")
	hud.set_hint("0 volta para o HUD  ·  1..7 trocam a tela  ·  ESC volta ao menu")
	hud.show_banner("PERNAS GIGANTES", "PREPARE-SE  2.4s", Color("#a3e635"), 0.0)
	hud.set_active_events([
		{"title": "PERNAS GIGANTES", "color": Color("#a3e635"), "time_left": 7.5, "duration": 11.0},
		{"title": "GRAVIDADE LUNAR", "color": Color("#a5b4fc"), "time_left": 4.0, "duration": 10.0},
	])


## n = 0 mostra o HUD; 1..7 mostram as telas do menu.
func show_screen(n: int) -> void:
	if n == 0:
		menu.hide_all()
		hud.set_ui_visible(true)
		return
	hud.set_ui_visible(false)
	match n:
		1:
			menu.show_main()
		2:
			menu.show_modes()
		3:
			menu.show_options("main")
		4:
			menu.show_controls("main")
		5:
			menu.show_credits()
		6:
			menu.show_pause("AZUL   2  x  1   VERMELHO", "01:13  ·  CAMPO TODO • 5x5")
		7:
			menu.show_results({
				"mode": "CAMPO TODO • 5x5",
				"headline": "AZUL VENCE",
				"a": 3,
				"b": 2,
				"name_a": Cfg.TEAM_A_NAME,
				"name_b": Cfg.TEAM_B_NAME,
				"stats": {"goals": 5, "kicks": 41, "tackles": 12, "hits": 9},
			})
		_:
			menu.show_main()


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var code := key.physical_keycode
	if code >= KEY_0 and code <= KEY_7:
		show_screen(0 if code == KEY_0 else code - KEY_0)
	elif code == KEY_ESCAPE:
		show_screen(1)


## Legenda fixa, acima de tudo, para não depender de qual tela está aberta.
func _build_help() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)

	var bar := ColorRect.new()
	bar.color = Color(0.04, 0.06, 0.05, 0.85)
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -26.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(bar)

	var text := Label.new()
	text.text = "GALERIA DE UI    0 HUD  ·  1 menu  ·  2 modos  ·  3 opções  ·  4 controles  ·  5 créditos  ·  6 pausa  ·  7 resultado"
	text.add_theme_font_size_override("font_size", 13)
	text.add_theme_color_override("font_color", Color("#f5c542"))
	text.add_theme_constant_override("outline_size", 4)
	text.add_theme_color_override("font_outline_color", Color("#0a0f0c"))
	text.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	text.offset_left = 14.0
	text.offset_top = -26.0
	text.offset_bottom = 0.0
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(text)
