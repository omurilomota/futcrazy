class_name EventManager
extends Node

## Gerencia aviso -> ativação -> duração -> limpeza.
## Pode combinar dois eventos ao mesmo tempo (o caos combinado do conceito).

const POOL := [
	preload("res://scripts/events/giant_legs.gd"),
	preload("res://scripts/events/big_head.gd"),
	preload("res://scripts/events/rubber_ball.gd"),
	preload("res://scripts/events/trampoline_field.gd"),
	preload("res://scripts/events/turbo_speed.gd"),
	preload("res://scripts/events/brawl.gd"),
	preload("res://scripts/events/giant_invasion.gd"),
]

var game: Node
var pool: Array = []
var active: Array[GameEvent] = []
var pending: Array[GameEvent] = []
var fired_ids: Dictionary = {}

var enabled := true
var timer := 6.0
var warn_left := 0.0
var min_gap := 10.0
var max_gap := 16.0
var warn_time := 2.6
var combo_chance := 0.35
var duration_override := -1.0
var use_sequence := false

var _seq := 0


func setup(g: Node) -> void:
	game = g
	pool = POOL.duplicate()
	timer = randf_range(4.0, 6.0)


func tick(delta: float) -> void:
	if game == null or not enabled:
		return
	if game.match_state != "play":
		return

	for e in active.duplicate():
		e.time_left -= delta
		if e.time_left <= 0.0:
			_deactivate(e)

	if not pending.is_empty():
		warn_left -= delta
		_update_banner()
		if warn_left <= 0.0:
			_activate()
		return

	if not active.is_empty():
		_update_banner()
		return

	timer -= delta
	if timer <= 0.0:
		_queue_new()


func _physics_process(delta: float) -> void:
	tick(delta)


func _queue_new() -> void:
	pending.clear()
	var taken: Array = []

	var first: GameEvent = _make_one(taken)
	if first == null:
		return
	pending.append(first)
	taken.append(_script_of(first))

	if randf() < combo_chance:
		var second: GameEvent = _make_one(taken)
		if second != null:
			pending.append(second)

	warn_left = warn_time
	_update_banner()
	if game.has_method("sfx_play"):
		game.sfx_play("event", -14.0, 1.0)
	print("[EVENTO] aviso: ", _join(pending))


func _make_one(exclude: Array) -> GameEvent:
	var options: Array = []
	for s in pool:
		if s in exclude:
			continue
		options.append(s)
	if options.is_empty():
		return null
	var script: GDScript
	if use_sequence:
		script = pool[_seq % pool.size()]
		_seq += 1
	else:
		script = options.pick_random()
	return script.new(game)


func _script_of(ev: GameEvent) -> GDScript:
	for s in pool:
		if ev.get_script() == s:
			return s
	return null


func _activate() -> void:
	for e in pending:
		e.apply()
		if duration_override > 0.0:
			e.time_left = duration_override
		active.append(e)
		fired_ids[e.id] = true
		if game.has_method("sfx_play"):
			game.sfx_play("event", -4.0, 1.32)
		print("[EVENTO] ativo: ", e.id)
	pending.clear()
	_update_banner()


func _deactivate(e: GameEvent) -> void:
	e.clear()
	active.erase(e)
	if active.is_empty():
		timer = randf_range(min_gap, max_gap)
		game.hud.clear_banner()
	else:
		_update_banner()


func _update_banner() -> void:
	if game == null or game.hud == null:
		return
	if not pending.is_empty():
		game.hud.show_banner("⚠ " + _join(pending), "PREPARE-SE  %.1fs" % maxf(warn_left, 0.0), pending[0].color, 0.0)
		return
	if active.is_empty():
		return
	var t := 0.0
	for e in active:
		t = maxf(t, e.time_left)
	game.hud.show_banner(_join(active), "%.1fs" % maxf(t, 0.0), active[0].color, 0.0)


func _join(list: Array) -> String:
	var parts: Array[String] = []
	for e in list:
		parts.append(e.title)
	return " + ".join(parts)


func reset() -> void:
	for e in active.duplicate():
		e.clear()
	active.clear()
	pending.clear()
	warn_left = 0.0
	timer = randf_range(min_gap, max_gap)
	if game != null and game.hud != null:
		game.hud.clear_banner()


func all_ids() -> Array:
	var ids: Array = []
	for s in POOL:
		ids.append(s.new(game).id)
	return ids
