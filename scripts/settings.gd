class_name GameSettings
extends Node

## Gerenciador central de configuracoes do FutCrazy.
##
## - Fonte unica de verdade para audio, video, acessibilidade, gameplay e controles.
## - Persiste em `user://futcrazy.cfg` (ConfigFile) e sobrevive ao fechar o jogo.
## - Aplica cada valor de verdade: volumes de bus, modo da janela, VSync, escala da
##   interface, tremor de camera, flashes, particulas, duracao da partida, ritmo dos
##   eventos, dificuldade dos bots e teclas dos dois jogadores (InputMap).
##
## Registrado como autoload `Settings` em project.godot. Como tambem tem `class_name`,
## qualquer script pode usar `Settings.x()` ou `GameSettings.x()`.

signal changed(key: String, value: Variant)
signal bindings_changed

const CONFIG_PATH := "user://futcrazy.cfg"
const GAME_VERSION := "0.4.0"
const CONFIG_VERSION := 2

const BUS_SFX := "SFX"
const BUS_AMBIENCE := "Ambience"

## Acoes de jogo remapeaveis. Pausa e reinicio ficam fixos (ESC / R) e aparecem
## na tela de controles como referencia.
const ACTIONS := [
	"p1_left", "p1_right", "p1_jump", "p1_kick", "p1_tackle",
	"p2_left", "p2_right", "p2_jump", "p2_kick", "p2_tackle",
]

const DEFAULT_BINDINGS := {
	"p1_left": KEY_A,
	"p1_right": KEY_D,
	"p1_jump": KEY_W,
	"p1_kick": KEY_SPACE,
	"p1_tackle": KEY_SHIFT,
	"p2_left": KEY_LEFT,
	"p2_right": KEY_RIGHT,
	"p2_jump": KEY_UP,
	"p2_kick": KEY_ENTER,
	"p2_tackle": KEY_CTRL,
}

const ACTION_LABELS := {
	"left": "MOVER ESQUERDA",
	"right": "MOVER DIREITA",
	"jump": "PULAR",
	"kick": "CHUTAR",
	"tackle": "CARRINHO",
}

## Teclas que nunca podem ser atribuidas a uma acao de jogador: sao reservadas
## para navegar no jogo (pausa, reinicio, confirmar, voltar).
const RESERVED_KEYS := {
	KEY_ESCAPE: "PAUSA",
	KEY_R: "REINICIAR",
	KEY_F11: "TELA CHEIA",
}

const DEFAULTS := {
	"audio/master": 0.9,
	"audio/sfx": 0.9,
	"audio/ambience": 0.5,
	"video/fullscreen": false,
	"video/vsync": true,
	"video/ui_scale": 1.0,
	"a11y/shake": 1.0,
	"a11y/flash": 1.0,
	"a11y/effects": true,
	"game/match_time": 120.0,
	"game/event_rate": 1,
	"game/bot_difficulty": 1,
}

## Multiplicador de intervalo entre eventos por indice de ritmo (0 raro, 1 normal, 2 caos).
const EVENT_RATE_SCALE := [1.7, 1.0, 0.55]
const EVENT_RATE_COMBO := [0.15, 0.35, 0.6]
const MATCH_TIME_CHOICES := [60.0, 120.0, 180.0]
const BOT_DIFFICULTY_NAMES := ["TRANQUILO", "NORMAL", "MALVADO"]

var bindings: Dictionary = {}

var _data: Dictionary = {}
var _loaded := false


func _ready() -> void:
	_ensure_buses()
	load_settings()
	apply_all()


# ---------------------------------------------------------------- ciclo de vida

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_settings()


func _ensure_buses() -> void:
	# Buses criados em tempo de execucao: nao dependem de um default_bus_layout.tres
	# e funcionam igual em headless, no editor e no jogo exportado.
	for bus_name in [BUS_SFX, BUS_AMBIENCE]:
		if AudioServer.get_bus_index(bus_name) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")


# ---------------------------------------------------------------- get / set

func get_value(key: String) -> Variant:
	if _data.has(key):
		return _data[key]
	return DEFAULTS.get(key)


func set_value(key: String, value: Variant) -> void:
	if not DEFAULTS.has(key):
		push_warning("Settings: chave desconhecida '%s'" % key)
		return
	var old: Variant = get_value(key)
	_data[key] = value
	if _same(old, value):
		return
	_apply_key(key)
	save_settings()
	changed.emit(key, value)


func reset_to_defaults() -> void:
	_data = DEFAULTS.duplicate(true)
	bindings = DEFAULT_BINDINGS.duplicate(true)
	apply_all()
	save_settings()
	changed.emit("*", null)
	bindings_changed.emit()


func _same(a: Variant, b: Variant) -> bool:
	if typeof(a) == TYPE_FLOAT or typeof(b) == TYPE_FLOAT:
		return absf(float(a) - float(b)) < 0.0001
	return a == b


# ---------------------------------------------------------------- tipados

func master_volume() -> float:
	return float(get_value("audio/master"))


func sfx_volume() -> float:
	return float(get_value("audio/sfx"))


func ambience_volume() -> float:
	return float(get_value("audio/ambience"))


func fullscreen() -> bool:
	return bool(get_value("video/fullscreen"))


func vsync() -> bool:
	return bool(get_value("video/vsync"))


func ui_scale() -> float:
	return float(get_value("video/ui_scale"))


func shake_scale() -> float:
	return clampf(float(get_value("a11y/shake")), 0.0, 1.5)


func flash_scale() -> float:
	return clampf(float(get_value("a11y/flash")), 0.0, 1.5)


func effects_enabled() -> bool:
	return bool(get_value("a11y/effects"))


func match_time() -> float:
	var t := float(get_value("game/match_time"))
	return t if t > 10.0 else 120.0


func event_rate() -> int:
	return clampi(int(get_value("game/event_rate")), 0, 2)


func event_gap_scale() -> float:
	return float(EVENT_RATE_SCALE[event_rate()])


func event_combo_chance() -> float:
	return float(EVENT_RATE_COMBO[event_rate()])


func bot_difficulty() -> int:
	return clampi(int(get_value("game/bot_difficulty")), 0, 2)


# ---------------------------------------------------------------- persistencia

func load_settings() -> void:
	_data = DEFAULTS.duplicate(true)
	bindings = DEFAULT_BINDINGS.duplicate(true)
	_loaded = true

	var cf := ConfigFile.new()
	var err := cf.load(CONFIG_PATH)
	if err != OK:
		return

	for key in DEFAULTS.keys():
		var v: Variant = cf.get_value("settings", key, DEFAULTS[key])
		if typeof(v) == typeof(DEFAULTS[key]) or _numeric_pair(v, DEFAULTS[key]):
			_data[key] = v

	for action in ACTIONS:
		var k: int = int(cf.get_value("keys", action, DEFAULT_BINDINGS[action]))
		bindings[action] = k if k != KEY_NONE else DEFAULT_BINDINGS[action]


func _numeric_pair(a: Variant, b: Variant) -> bool:
	var ta := typeof(a)
	var tb := typeof(b)
	var numeric := [TYPE_INT, TYPE_FLOAT]
	return ta in numeric and tb in numeric


func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("meta", "version", CONFIG_VERSION)
	cf.set_value("meta", "game_version", GAME_VERSION)
	for key in DEFAULTS.keys():
		cf.set_value("settings", key, get_value(key))
	for action in ACTIONS:
		cf.set_value("keys", action, int(bindings.get(action, DEFAULT_BINDINGS[action])))
	cf.save(CONFIG_PATH)


# ---------------------------------------------------------------- aplicacao

func apply_all() -> void:
	apply_audio()
	apply_video()
	apply_input_map(false)


func _apply_key(key: String) -> void:
	if key.begins_with("audio/"):
		apply_audio()
	elif key.begins_with("video/"):
		apply_video()
	# a11y/* e game/* sao lidos sob demanda pelos sistemas que os usam


func _db(linear: float) -> float:
	if linear <= 0.001:
		return -80.0
	return linear_to_db(clampf(linear, 0.0, 1.0))


func apply_audio() -> void:
	_ensure_buses()
	_set_bus_volume("Master", master_volume())
	_set_bus_volume(BUS_SFX, sfx_volume())
	_set_bus_volume(BUS_AMBIENCE, ambience_volume())


func _set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, linear <= 0.001)
	AudioServer.set_bus_volume_db(idx, _db(linear))


func apply_video() -> void:
	var win := get_window()
	if win != null:
		var want_fullscreen := fullscreen()
		var is_fullscreen := win.mode == Window.MODE_FULLSCREEN or win.mode == Window.MODE_EXCLUSIVE_FULLSCREEN
		if want_fullscreen != is_fullscreen:
			win.mode = Window.MODE_EXCLUSIVE_FULLSCREEN if want_fullscreen else Window.MODE_WINDOWED
		win.content_scale_factor = ui_scale()

	if DisplayServer.get_name() != "headless":
		var mode := DisplayServer.VSYNC_ENABLED if vsync() else DisplayServer.VSYNC_DISABLED
		DisplayServer.window_set_vsync_mode(mode)


func toggle_fullscreen() -> void:
	set_value("video/fullscreen", not fullscreen())


# ---------------------------------------------------------------- controles

func _ensure_action(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)


## Reconstroi o InputMap a partir das teclas salvas.
## No modo de 1 jogador as setas tambem controlam o P1 (conforto, como antes).
func apply_input_map(two_player: bool) -> void:
	for action in ACTIONS:
		_ensure_action(action)
		InputMap.action_erase_events(action)
		var key: int = int(bindings.get(action, DEFAULT_BINDINGS[action]))
		if key != KEY_NONE:
			_add_key_event(action, key)

	if not two_player:
		var aliases := [
			["p1_left", KEY_LEFT],
			["p1_right", KEY_RIGHT],
			["p1_jump", KEY_UP],
			["p1_kick", KEY_KP_ENTER],
		]
		for pair in aliases:
			var alias_key: int = int(pair[1])
			if int(bindings.get(pair[0], KEY_NONE)) != alias_key:
				_add_key_event(pair[0], alias_key)


func _add_key_event(action: String, key: int) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)


func key_for(action: String) -> int:
	return int(bindings.get(action, DEFAULT_BINDINGS[action]))


## Nome curto e legivel de uma tecla, para a tela de controles.
static func key_label(key: int) -> String:
	match key:
		KEY_SPACE:
			return "ESPAÇO"
		KEY_SHIFT:
			return "SHIFT"
		KEY_CTRL:
			return "CTRL"
		KEY_ENTER, KEY_KP_ENTER:
			return "ENTER"
		KEY_UP:
			return "↑"
		KEY_DOWN:
			return "↓"
		KEY_LEFT:
			return "←"
		KEY_RIGHT:
			return "→"
		KEY_ESCAPE:
			return "ESC"
		KEY_TAB:
			return "TAB"
		KEY_BACKSPACE:
			return "BACKSPACE"
		KEY_KP_0:
			return "NUM 0"
	if key >= KEY_A and key <= KEY_Z:
		return char(key)
	if key >= KEY_0 and key <= KEY_9:
		return char(key)
	if key >= KEY_F1 and key <= KEY_F12:
		return "F%d" % (key - KEY_F1 + 1)
	return OS.get_keycode_string(key)


## Devolve o nome da acao que ja usa essa tecla (string vazia se estiver livre).
func conflict_for(action: String, key: int) -> String:
	if RESERVED_KEYS.has(key):
		return String(RESERVED_KEYS[key])
	for other in ACTIONS:
		if other == action:
			continue
		if int(bindings.get(other, KEY_NONE)) == key:
			return other
	return ""


func set_binding(action: String, key: int) -> bool:
	if not DEFAULT_BINDINGS.has(action) or key == KEY_NONE:
		return false
	bindings[action] = key
	apply_input_map(false)
	save_settings()
	bindings_changed.emit()
	return true


func reset_bindings() -> void:
	bindings = DEFAULT_BINDINGS.duplicate(true)
	apply_input_map(false)
	save_settings()
	bindings_changed.emit()


## Nome amigavel de uma acao ("p2_kick" -> "JOGADOR 2 · CHUTAR").
static func action_label(action: String) -> String:
	var parts := action.split("_", true, 1)
	if parts.size() != 2:
		return action.to_upper()
	var who := "JOGADOR 1" if parts[0] == "p1" else "JOGADOR 2"
	return "%s · %s" % [who, str(ACTION_LABELS.get(parts[1], parts[1])).to_upper()]
