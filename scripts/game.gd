@tool
extends Node3D

## Orquestrador do jogo: estádio, jogadores, bola, câmera, HUD, áudio, efeitos e menu.
##
## A cena main.tscn é de propósito quase vazia: tudo é montado por código em _ready().
## Por isso existe o bloco @tool abaixo — no editor ele monta estádio, bola e
## jogadores para você poder inspecionar/depurar. A partida só roda ao dar play.
##
## Estados: menu -> countdown -> play -> goal/end, com pausa a qualquer momento.
##
## Modos de teste:
##   godot --headless --path . -- --smoke        (arcade bot x bot, 7 eventos)
##   godot --headless --path . -- --smoke-campo  (5x5 com goleiros)
##   godot --path . -- --shot / --shot-menu / --shot-campo

const CAM_POS := Vector3(0.0, 7.6, 26.0)
const CAM_TARGET := Vector3(0.0, 3.3, 0.0)

const MODE_ARCADE := 1
const MODE_LOCAL := 2
const MODE_FIELD := 3

const HINT_1P := "A/D mover  •  W pular  •  ESPAÇO chutar  •  SHIFT carrinho  •  ESC pausa  •  R reiniciar"
const HINT_2P := "AZUL  A/D • W • ESPAÇO • SHIFT        VERMELHO  ←/→ • ↑ • ENTER • CTRL        ESC pausa"
const HINT_FIELD := "VOCÊ CONTROLA O JOGADOR MAIS PERTO DA BOLA   •   A/D  W  ESPAÇO  SHIFT   •   ESC pausa"

const KEYS_SOLO := {
	"left": [KEY_A, KEY_LEFT],
	"right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_W, KEY_UP],
	"kick": [KEY_SPACE],
	"tackle": [KEY_SHIFT, KEY_J],
}
const KEYS_P1 := {
	"left": [KEY_A],
	"right": [KEY_D],
	"jump": [KEY_W],
	"kick": [KEY_SPACE],
	"tackle": [KEY_SHIFT],
}
const KEYS_P2 := {
	"left": [KEY_LEFT],
	"right": [KEY_RIGHT],
	"jump": [KEY_UP],
	"kick": [KEY_ENTER, KEY_KP_ENTER],
	"tackle": [KEY_CTRL, KEY_KP_0],
}

var stadium: Stadium
var ball: Ball
var players: Array[Player] = []
var controlled: Player
var cam: Camera3D
var hud: Hud
var events: EventManager
var sfx: Sfx
var menu: MenuScreen

var match_state := "menu"
var prev_state := "play"
var mode := MODE_ARCADE
var state_timer := Cfg.START_COUNTDOWN
var score := [0, 0]
var clock := Cfg.MATCH_TIME
var trampoline := false
var brawl := false

var stats := {"kicks": 0, "tackles": 0, "hits": 0, "goals": 0}

var shake := 0.0
var smoke := false
var smoke_campo := false
var _shot := false
var _shot_done := false
var _shot_menu := false
var _shot_mode := MODE_ARCADE
var _shot_at := 5000
var _excite := 0.3

var _cam_pos := CAM_POS
var _last_count := -1
var _start_ms := 0
var _key_latch: Dictionary = {}
var _pause_ball_frozen := true
var _layout_mode := 0
var _human_teams: Array = [0]
var _switch_cd := 0.0
var _stuck_t := 0.0

var _smoke_t := 0.0
var _smoke_stage := 0
var _smoke_ok := true
var _smoke_goal_at := 6.0
var _smoke_check_at := 7.5
var _smoke_end := 34.0
var _sample_t := 0.0
var _upright_samples := 0
var _upright_ok := 0


func _ready() -> void:
	# ------------------------------------------------ preview dentro do editor
	if Engine.is_editor_hint():
		_build_environment()
		_build_camera()
		ball = Ball.new()
		ball.name = "Ball"
		add_child(ball)
		ball.setup(self)
		_human_teams = [0]
		_apply_layout(MODE_ARCADE)
		ball.global_position = Vector3(0.0, 1.2, 0.0)
		_reset_positions()
		ball.freeze = true
		for p in players:
			p.global_position.y = 0.95
			p.freeze = true
		return

	randomize()
	_start_ms = Time.get_ticks_msec()

	var args := OS.get_cmdline_user_args()
	smoke = "--smoke" in args
	smoke_campo = "--smoke-campo" in args
	_shot_menu = "--shot-menu" in args
	var shot_campo := "--shot-campo" in args
	_shot_mode = MODE_FIELD if shot_campo else MODE_ARCADE
	_shot = "--shot" in args or _shot_menu or shot_campo

	if smoke or smoke_campo:
		Engine.time_scale = 2.0

	if smoke_campo:
		_smoke_goal_at = 4.0
		_smoke_check_at = 5.5
		_smoke_end = 16.0

	_build_environment()
	_build_camera()

	ball = Ball.new()
	ball.name = "Ball"
	add_child(ball)
	ball.setup(self)
	ball.global_position = Vector3(0.0, 1.4, 0.0)

	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)

	sfx = Sfx.new()
	sfx.name = "Sfx"
	add_child(sfx)

	events = EventManager.new()
	events.name = "Events"
	add_child(events)
	events.setup(self)

	menu = MenuScreen.new()
	menu.name = "Menu"
	add_child(menu)

	_human_teams = [0]
	_apply_layout(MODE_ARCADE)

	if smoke:
		# bot x bot, tudo acelerado e na ordem do pool para exercitar os 7 eventos
		events.use_sequence = true
		events.min_gap = 0.4
		events.max_gap = 1.0
		events.warn_time = 0.4
		events.combo_chance = 0.0
		events.duration_override = 2.0
		start_match(MODE_ARCADE)
		# confere a configuração do modo 2 jogadores sem precisar de teclado
		start_match(MODE_LOCAL)
		if _human_count() != 2 or players.size() != 2:
			_smoke_ok = false
			printerr("[SMOKE] FALHA: modo 2 jogadores mal configurado")
		else:
			print("[SMOKE] modo 2 jogadores OK")
		start_match(MODE_ARCADE)
		for p in players:
			p.is_human = false
			p.brain = BotBrain.new("field", p.home_x)
	elif smoke_campo:
		events.min_gap = 2.0
		events.max_gap = 3.0
		events.warn_time = 0.5
		events.combo_chance = 0.0
		events.duration_override = 2.0
		start_match(MODE_FIELD)
		for p in players:
			p.is_human = false
			p.brain = BotBrain.new(p.role, p.home_x)
	elif _shot:
		if _shot_menu:
			_open_menu()
			_shot_at = 1400
		else:
			start_match(_shot_mode)
			Engine.time_scale = 0.35
			if _shot_mode == MODE_FIELD:
				_shot_at = 3400
	else:
		_open_menu()


# ---------------------------------------------------------------- montagem

func _build_environment() -> void:
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#79c6f2")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#cfe8ff")
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	add_child(we)


func _build_camera() -> void:
	cam = Camera3D.new()
	cam.name = "Camera"
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 11.5
	cam.near = 0.05
	cam.far = 120.0
	cam.position = CAM_POS
	add_child(cam)
	cam.look_at(CAM_TARGET, Vector3.UP)
	cam.current = true
	_cam_pos = cam.global_position


func _build_stadium() -> void:
	if stadium != null:
		remove_child(stadium)
		stadium.queue_free()
	stadium = Stadium.new()
	stadium.name = "Stadium"
	add_child(stadium)
	stadium.build(self)


## Troca o tamanho do campo, o zoom da câmera e a quantidade de jogadores.
func _apply_layout(m: int) -> void:
	var changed := m != _layout_mode
	_layout_mode = m
	Cfg.field_half = Cfg.HALF_FIELD if m == MODE_FIELD else Cfg.HALF_ARCADE
	if stadium == null or changed:
		_build_stadium()
	cam.size = 15.6 if m == MODE_FIELD else 11.5
	_spawn_players(_team_size_for(m))


func _team_size_for(m: int) -> int:
	return 5 if m == MODE_FIELD else 1


## Posições de formação por time. Índice 0 é o goleiro quando o time tem 5.
func _slots(team: int, n: int) -> Array:
	var h: float = Cfg.field_half
	var base: Array = []
	if n <= 1:
		base = [-h + 5.0]
	else:
		base = [-h + 1.0, -h + 5.0, -h + 7.5, -h + 9.6, -h + 11.2]
	var out: Array = []
	for x in base:
		out.append(x if team == 0 else -x)
	return out


func _spawn_players(team_size: int) -> void:
	for p in players:
		p.freeze = true
		remove_child(p)
		p.queue_free()
	players.clear()
	controlled = null

	for team in 2:
		var slots := _slots(team, team_size)
		for i in slots.size():
			var role_name := "gk" if team_size > 1 and i == 0 else "field"
			var p := Player.new()
			p.name = "T%d_%s_%d" % [team, role_name, i]
			add_child(p)
			p.setup(self, team, false, role_name)
			p.home_x = float(slots[i])
			p.brain = BotBrain.new(role_name, p.home_x)
			players.append(p)

	controlled = _initial_controlled()


func _initial_controlled() -> Player:
	var best: Player = null
	for p in players:
		if p.team != 0 or p.is_gk():
			continue
		if best == null or p.home_x > best.home_x:
			best = p
	return best


func _human_count() -> int:
	var n := 0
	for p in players:
		if p.is_human:
			n += 1
	return n


# ---------------------------------------------------------------- partida

func start_match(new_mode := MODE_ARCADE) -> void:
	mode = new_mode
	_human_teams = [0, 1] if mode == MODE_LOCAL else [0]

	score[0] = 0
	score[1] = 0
	for k in stats:
		stats[k] = 0
	shake = 0.0
	_excite = 0.35
	trampoline = false
	brawl = false
	_stuck_t = 0.0
	clock = Cfg.MATCH_TIME
	menu.hide_all()

	events.enabled = true
	events.reset()
	_apply_layout(mode)
	controlled = _initial_controlled()
	_reassign_control()

	for p in players:
		if p.team == 1:
			p.keys = KEYS_P2
		else:
			p.keys = KEYS_P1 if mode == MODE_LOCAL else KEYS_SOLO

	hud.set_ui_visible(true)
	hud.set_mode_label(_mode_label())
	hud.set_hint(_hint_for_mode())
	hud.clear_message()
	_reset_positions()
	_start_countdown()

	sfx.set_intensity(0.35)
	sfx.play("whistle", -9.0)
	print("[PARTIDA] modo: %s (%d jogadores)" % [_mode_label(), players.size()])


func _open_menu() -> void:
	match_state = "menu"
	prev_state = "play"
	menu.show_main()
	hud.set_ui_visible(false)
	hud.set_mode_label("")
	hud.set_hint("")
	hud.clear_banner()
	hud.clear_message()
	ball.freeze = true
	for p in players:
		p.freeze = true
	events.enabled = false
	events.reset()
	sfx.set_intensity(0.18)


func _mode_label() -> String:
	match mode:
		MODE_LOCAL:
			return "2 JOGADORES • ARCADE"
		MODE_FIELD:
			return "CAMPO TODO • 5 x 5 COM GOLEIROS"
		_:
			return "1 x BOT • ARCADE"


func _hint_for_mode() -> String:
	if mode == MODE_LOCAL:
		return HINT_2P
	if mode == MODE_FIELD:
		return HINT_FIELD
	return HINT_1P


func restore_hint() -> void:
	if hud != null:
		hud.set_hint(_hint_for_mode())


## Mantém o controle no jogador de linha do time azul mais perto da bola.
func _reassign_control() -> void:
	for p in players:
		var human := false
		if p.team in _human_teams:
			if mode == MODE_LOCAL:
				human = p.role == "field"
			else:
				human = p == controlled
		if human:
			p.is_human = true
			p.brain = null
		else:
			p.is_human = false
			p.brain = BotBrain.new(p.role, p.home_x)
		p.set_marked(mode == MODE_FIELD and p == controlled)


func _update_control(delta: float) -> void:
	if mode != MODE_FIELD or controlled == null:
		return
	_switch_cd = maxf(0.0, _switch_cd - delta)
	if _switch_cd > 0.0:
		return

	var best: Player = null
	var best_d := INF
	for p in players:
		if p.team != 0 or p.is_gk() or p == controlled:
			continue
		var d := p.global_position.distance_to(ball.global_position)
		if d < best_d:
			best_d = d
			best = p
	if best == null:
		return

	var cur_d := controlled.global_position.distance_to(ball.global_position)
	if best_d + 1.4 < cur_d:
		controlled = best
		_reassign_control()
		_switch_cd = 0.6
		sfx.play("ui", -18.0, 1.5)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	_handle_keys()

	match match_state:
		"countdown":
			state_timer -= delta
			var n := int(ceil(maxf(state_timer, 0.0)))
			if n != _last_count:
				_last_count = n
				if n > 0:
					hud.flash(str(n), Color("#fde68a"), 0.85)
					sfx.play("beep", -4.0, 1.0 + float(3 - n) * 0.07)
				else:
					hud.flash("JÁ!", Color("#a7f3d0"), 0.8)
					sfx.play("whistle", -12.0, 1.06)
			if state_timer <= 0.0:
				match_state = "play"
				ball.freeze = false

		"play":
			clock = maxf(0.0, clock - delta)
			hud.set_clock(clock)
			_update_control(delta)
			_check_goal()
			if match_state == "play":
				_check_ball_out()
				_check_ball_stuck(delta)
			if clock <= 0.0 and match_state == "play":
				_end_match()

		"goal":
			state_timer -= delta
			if state_timer <= 0.0:
				if clock <= 0.0:
					_end_match()
				else:
					_reset_positions()
					match_state = "play"
					ball.freeze = false
					hud.flash("JÁ!", Color("#a7f3d0"), 0.7)
					sfx.play("whistle", -12.0, 1.06)

		_:
			pass


# ---------------------------------------------------------------- entrada

func _just(key: int) -> bool:
	var down := Input.is_physical_key_pressed(key)
	var was: bool = _key_latch.get(key, false)
	_key_latch[key] = down
	return down and not was


func _handle_keys() -> void:
	if smoke or smoke_campo:
		return

	if match_state == "menu":
		if _just(KEY_1) or _just(KEY_KP_1) or _just(KEY_ENTER):
			start_match(MODE_ARCADE)
		elif _just(KEY_2) or _just(KEY_KP_2):
			start_match(MODE_LOCAL)
		elif _just(KEY_3) or _just(KEY_KP_3):
			start_match(MODE_FIELD)
		return

	if match_state == "paused":
		if _just(KEY_ESCAPE) or _just(KEY_P):
			_resume()
		elif _just(KEY_ENTER) or _just(KEY_KP_ENTER):
			_open_menu()
		return

	if _just(KEY_ESCAPE):
		if match_state == "end":
			_open_menu()
		else:
			_pause()
		return

	if _just(KEY_R) and Time.get_ticks_msec() - _start_ms > 900:
		if match_state == "play" or match_state == "goal" or match_state == "countdown" or match_state == "end":
			restart()


func _pause() -> void:
	if match_state != "play" and match_state != "countdown" and match_state != "goal":
		return
	prev_state = match_state
	match_state = "paused"
	_pause_ball_frozen = ball.freeze
	ball.freeze = true
	for p in players:
		p.freeze = true
	menu.show_pause()
	sfx.play("ui", -10.0, 0.8)


func _resume() -> void:
	if match_state != "paused":
		return
	match_state = prev_state
	ball.freeze = _pause_ball_frozen
	for p in players:
		p.freeze = false
	menu.hide_all()
	sfx.play("ui", -10.0, 1.2)


# ---------------------------------------------------------------- gols

func _check_goal() -> void:
	var bp := ball.global_position
	if bp.y > Cfg.GOAL_H + 0.15 or bp.y < -0.5:
		return
	if bp.x > Cfg.field_half:
		_on_goal(0)
	elif bp.x < -Cfg.field_half:
		_on_goal(1)


func _check_ball_out() -> void:
	var bp := ball.global_position
	var out := false
	if bp.y > 15.0:
		out = true
	elif bp.y < -3.0:
		out = true
	elif absf(bp.x) > Cfg.field_half + 2.8:
		out = true
	elif absf(bp.x) > Cfg.field_half + 0.45 and bp.y > Cfg.GOAL_H:
		out = true
	if out:
		_throw_in()


## Se a bola ficar parada e ninguém chegar nela, devolve ao centro (evita travar a partida).
func _check_ball_stuck(delta: float) -> void:
	if ball.freeze or ball.linear_velocity.length() > 0.8:
		_stuck_t = 0.0
		return
	for p in players:
		if p.global_position.distance_to(ball.global_position) < 2.2:
			_stuck_t = 0.0
			return
	_stuck_t += delta
	if _stuck_t < 6.0:
		return
	_stuck_t = 0.0
	ball.global_position = Vector3(0.0, 3.0, 0.0)
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	hud.flash("BOLA NO CENTRO", Color("#e2e8f0"), 0.7)
	sfx.play("bounce", -12.0, 1.1)


## Lateral: a bola volta para dentro perto de onde saiu, em vez de teleportar ao centro.
func _throw_in() -> void:
	var h: float = Cfg.field_half
	var bp := ball.global_position
	var x := clampf(bp.x, -h + 1.2, h - 1.2)
	ball.global_position = Vector3(x, 2.6, 0.0)
	ball.linear_velocity = Vector3(-signf(x) * 1.6, 0.0, 0.0)
	ball.angular_velocity = Vector3.ZERO
	ball.global_rotation = Vector3.ZERO
	hud.flash("LATERAL!", Color("#e2e8f0"), 0.6)
	sfx.play("bounce", -12.0, 1.3)


func _on_goal(team_id: int) -> void:
	score[team_id] += 1
	stats["goals"] += 1
	hud.set_score(score[0], score[1])
	var col: Color = Cfg.TEAM_A_COLOR.lightened(0.25) if team_id == 0 else Cfg.TEAM_B_COLOR.lightened(0.25)
	hud.flash("GOL!", col, 1.7)
	hud.clear_banner()
	hud.flash_screen(col, 0.42)
	shake = 1.5
	excite(1.0)
	sfx.play("goal", -2.0)
	spawn_dust(ball.global_position, col, 16.0, 1.5)
	ball.freeze = true
	ball.linear_velocity = Vector3.ZERO
	# eventos NÃO são cancelados no gol: no modo campo todo eles sobrevivem ao kickoff
	match_state = "goal"
	state_timer = Cfg.GOAL_PAUSE
	print("[GOL] time %d | placar %d x %d" % [team_id, score[0], score[1]])


func _reset_positions() -> void:
	for p in players:
		p.freeze = false
		p.global_position = Vector3(p.home_x, 2.2, 0.0)
		p.global_rotation = Vector3.ZERO
		p.linear_velocity = Vector3.ZERO
		p.angular_velocity = Vector3.ZERO
		p.facing = -signf(p.home_x) if absf(p.home_x) > 0.05 else p.goal_dir
		p.stun_left = 0.0
		p.kick_cd_left = 0.0
		p.tackle_cd_left = 0.0

	ball.freeze = false
	ball.global_position = Vector3(0.0, 1.6, 0.0)
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	ball.global_rotation = Vector3.ZERO


func _start_countdown() -> void:
	match_state = "countdown"
	state_timer = 0.2 if _shot else (0.4 if (smoke or smoke_campo) else Cfg.START_COUNTDOWN)
	_last_count = -1
	clock = Cfg.MATCH_TIME
	hud.set_score(score[0], score[1])
	hud.set_clock(clock)
	hud.clear_banner()
	ball.freeze = true


func _end_match() -> void:
	match_state = "end"
	state_timer = 0.0
	ball.freeze = true
	for p in players:
		p.input_move = 0.0
		p.want_kick = false
		p.want_tackle = false
	events.reset()
	sfx.set_intensity(0.5)
	sfx.play("whistle", -4.0, 0.92)

	var res := "EMPATE!"
	if score[0] > score[1]:
		res = "%s VENCE!" % Cfg.TEAM_A_NAME
	elif score[1] > score[0]:
		res = "%s VENCE!" % Cfg.TEAM_B_NAME
	hud.flash(res, Color("#fde68a"), 6.0)
	hud.show_banner(
		"FIM DE JOGO",
		"%d x %d  •  chutes %d  •  carrinhos %d\nR jogar de novo   •   ESC menu" % [score[0], score[1], stats["kicks"], stats["tackles"]],
		Color("#f8fafc"),
		0.0
	)
	print("[FIM] %d x %d" % [score[0], score[1]])


func restart() -> void:
	start_match(mode)
	hud.flash("DE NOVO!", Color("#fde68a"), 0.8)


# ---------------------------------------------------------------- reações

func excite(v: float) -> void:
	_excite = maxf(_excite, v)


func spawn_dust(pos: Vector3, color := Color("#d6c9a8"), amount := 10.0, power := 1.0) -> void:
	Fx.dust(self, pos, color, int(round(amount)), power)


func sfx_play(id: String, vol_db := 0.0, pitch := 1.0) -> void:
	if sfx != null:
		sfx.play(id, vol_db, pitch)


func on_kick(_p: Player, power: float) -> void:
	stats["kicks"] += 1
	shake = maxf(shake, 0.1 + power * 0.008)
	excite(0.55)
	sfx_play("kick", lerpf(-8.0, 0.0, clampf(power / 16.0, 0.0, 1.0)), 0.85 + power * 0.03)
	spawn_dust(ball.global_position, Color("#dbe7cf"), 6.0, 0.85)


func on_whiff(_p: Player) -> void:
	shake = maxf(shake, 0.05)
	sfx_play("whoosh", -14.0, 1.15)


func on_tackle(p: Player) -> void:
	stats["tackles"] += 1
	sfx_play("whoosh", -7.0, 0.85)
	spawn_dust(p.global_position + Vector3(0.0, -0.3, 0.0), Color("#dbe7cf"), 8.0, 1.0)


func on_hit(_attacker: Player, target: Player, _power: float) -> void:
	stats["hits"] += 1
	shake = maxf(shake, 0.45)
	excite(0.8)
	sfx_play("hit", -3.0, 0.9 + randf() * 0.25)
	spawn_dust(target.global_position, Color("#f2e6c9"), 12.0, 1.2)


# ---------------------------------------------------------------- frame

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if shake > 0.01:
		shake = move_toward(shake, 0.0, delta * 2.6)
		cam.global_position = _cam_pos + Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * shake * 0.32
	else:
		shake = 0.0
		cam.global_position = _cam_pos

	_excite = move_toward(_excite, 0.3, delta * 0.45)
	if sfx != null:
		sfx.set_intensity(_excite)

	if smoke or smoke_campo:
		_smoke_tick(delta)

	if _shot and not _shot_done and Time.get_ticks_msec() - _start_ms > _shot_at:
		_shot_done = true
		_save_shot()


func _save_shot() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var dir := ProjectSettings.globalize_path("res://.preview")
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(dir + "/preview.png")
	print("[SHOT] ball=%s p0=%s rot0=%s p1=%s rot1=%s" % [
		ball.global_position, players[0].global_position, players[0].global_rotation,
		players[1].global_position, players[1].global_rotation
	])
	print("[SHOT] salvo em .preview/preview.png (%d jogadores, campo %.0fm)" % [players.size(), Cfg.field_half * 2.0])
	get_tree().quit(0)


# ---------------------------------------------------------------- smoke test

func _smoke_tick(delta: float) -> void:
	_smoke_t += delta

	# o jogador precisa conseguir ficar de pé: mede a fração de tempo ereto
	_sample_t += delta
	if _sample_t > 0.25:
		_sample_t = 0.0
		var up: Vector3 = players[0].global_transform.basis.y
		var tilt := absf(atan2(up.x, up.y))
		_upright_samples += 1
		if tilt < 0.7:
			_upright_ok += 1

	if _smoke_stage == 0 and _smoke_t > _smoke_goal_at and match_state == "play":
		_smoke_stage = 1
		# bola nasce já dentro da boca do gol: teste determinístico, sem depender
		# de goleiro/defensor conseguindo interceptar o arremesso
		ball.freeze = false
		ball.global_position = Vector3(-Cfg.field_half - 0.12, 1.0, 0.0)
		ball.linear_velocity = Vector3.ZERO
		print("[SMOKE] arremesso de teste no gol esquerdo")
	elif _smoke_stage == 1 and _smoke_t > _smoke_check_at:
		_smoke_stage = 2
		if score[1] < 1:
			_smoke_ok = false
			printerr("[SMOKE] FALHA: gol nao detectado")
		else:
			print("[SMOKE] deteccao de gol OK (placar %d x %d)" % [score[0], score[1]])
	elif _smoke_t > _smoke_end:
		if smoke_campo:
			_smoke_finish_campo()
		else:
			_smoke_finish()


func _smoke_finish() -> void:
	print("[SMOKE] eventos disparados: ", events.fired_ids.keys())

	for id in events.all_ids():
		if not events.fired_ids.has(id):
			_smoke_ok = false
			printerr("[SMOKE] FALHA: evento nao disparado: ", id)

	for p in players:
		var pos := p.global_position
		if absf(pos.x) > 30.0 or pos.y < -2.0 or pos.y > 25.0:
			_smoke_ok = false
			printerr("[SMOKE] FALHA: jogador fora dos limites: ", pos)
	if absf(ball.global_position.x) > 40.0 or ball.global_position.y < -2.0 or ball.global_position.y > 30.0:
		_smoke_ok = false
		printerr("[SMOKE] FALHA: bola fora dos limites: ", ball.global_position)
	if stats["kicks"] <= 0:
		_smoke_ok = false
		printerr("[SMOKE] FALHA: nenhum chute registrado")

	var ratio := 1.0
	if _upright_samples > 0:
		ratio = float(_upright_ok) / float(_upright_samples)
	if ratio < 0.55:
		_smoke_ok = false
		printerr("[SMOKE] FALHA: jogador deitado demais (ereto %.0f%%) " % (ratio * 100.0))
	print("[SMOKE] tempo ereto do jogador: %.0f%%" % (ratio * 100.0))

	print("[SMOKE] placar=%d x %d chutes=%d carrinhos=%d pancadas=%d gols=%d" % [
		score[0], score[1], stats["kicks"], stats["tackles"], stats["hits"], stats["goals"]
	])
	print("[SMOKE] RESULTADO: %s" % ("OK" if _smoke_ok else "FALHOU"))
	get_tree().quit(0 if _smoke_ok else 1)


func _smoke_finish_campo() -> void:
	var gks := 0
	var field_team := 0
	for p in players:
		if p.is_gk():
			gks += 1
		else:
			field_team += 1
		var pos := p.global_position
		if absf(pos.x) > Cfg.field_half + 4.0 or pos.y < -2.0 or pos.y > 25.0:
			_smoke_ok = false
			printerr("[SMOKE] FALHA: jogador fora dos limites: ", p.name, " ", pos)

	print("[SMOKE] jogadores: %d (goleiros: %d) | chutes=%d | gols=%d | eventos=%s" % [
		players.size(), gks, stats["kicks"], stats["goals"], events.fired_ids.keys()
	])
	if players.size() != 10 or gks != 2:
		_smoke_ok = false
		printerr("[SMOKE] FALHA: esperava 10 jogadores (2 goleiros)")
	if field_team != 8:
		_smoke_ok = false
		printerr("[SMOKE] FALHA: esperava 8 jogadores de linha")
	if stats["kicks"] <= 0:
		_smoke_ok = false
		printerr("[SMOKE] FALHA: nenhum chute registrado")
	if stats["goals"] <= 0:
		_smoke_ok = false
		printerr("[SMOKE] FALHA: nenhum gol no campo todo")
	if events.fired_ids.is_empty():
		_smoke_ok = false
		printerr("[SMOKE] FALHA: nenhum evento disparado com 10 jogadores")
	if absf(ball.global_position.x) > Cfg.field_half + 4.0:
		_smoke_ok = false
		printerr("[SMOKE] FALHA: bola fora dos limites: ", ball.global_position)

	print("[SMOKE] tempo ereto (amostra): %.0f%%" % (float(_upright_ok) / maxf(float(_upright_samples), 1.0) * 100.0))
	print("[SMOKE] placar=%d x %d" % [score[0], score[1]])
	print("[SMOKE] RESULTADO: %s" % ("OK" if _smoke_ok else "FALHOU"))
	get_tree().quit(0 if _smoke_ok else 1)
