extends Node3D

## Orquestrador do MVP: monta estádio, jogadores, bola, câmera e HUD,
## controla o relógio da partida, gols, kickoff e reinício.
##
## Modo de teste automatizado:
##   godot --headless --path . -- --smoke
## Roda bot x bot acelerado, força todos os eventos e valida a detecção de gol.

const CAM_POS := Vector3(0.0, 7.6, 26.0)
const CAM_TARGET := Vector3(0.0, 3.3, 0.0)
const HINT_DEFAULT := "A/D mover   •   W pular   •   ESPAÇO chutar   •   SHIFT carrinho/pancada   •   R reiniciar"

var stadium: Stadium
var ball: Ball
var players: Array[Player] = []
var cam: Camera3D
var hud: Hud
var events: EventManager

var match_state := "countdown"
var state_timer := Cfg.START_COUNTDOWN
var score := [0, 0]
var clock := Cfg.MATCH_TIME
var trampoline := false
var brawl := false

var stats := {"kicks": 0, "tackles": 0, "hits": 0, "goals": 0}

var shake := 0.0
var smoke := false
var _shot := false
var _shot_done := false

var _cam_pos := CAM_POS
var _last_count := -1
var _start_ms := 0
var _r_latch := false
var _smoke_t := 0.0
var _smoke_stage := 0
var _smoke_ok := true
var _sample_t := 0.0
var _upright_samples := 0
var _upright_ok := 0


func _ready() -> void:
	randomize()
	_start_ms = Time.get_ticks_msec()
	smoke = "--smoke" in OS.get_cmdline_user_args()
	_shot = "--shot" in OS.get_cmdline_user_args()
	if smoke:
		Engine.time_scale = 2.0

	_build_environment()
	_build_camera()

	stadium = Stadium.new()
	stadium.name = "Stadium"
	add_child(stadium)
	stadium.build(self)

	ball = Ball.new()
	ball.name = "Ball"
	add_child(ball)
	ball.setup(self)
	ball.global_position = Vector3(0.0, 1.4, 0.0)

	_build_players()

	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)

	events = EventManager.new()
	events.name = "Events"
	add_child(events)
	events.setup(self)

	if smoke:
		# bot x bot, tudo acelerado e na ordem do pool para exercitar os 7 eventos
		events.use_sequence = true
		events.min_gap = 0.4
		events.max_gap = 1.0
		events.warn_time = 0.4
		events.combo_chance = 0.0
		events.duration_override = 2.0
		for p in players:
			p.is_human = false
			p.brain = BotBrain.new()

	if _shot:
		# câmera lenta para inspecionar a formação inicial
		Engine.time_scale = 0.35

	_reset_positions()
	_start_countdown()


# ---------------------------------------------------------------- montagem

func _build_environment() -> void:
	var we := WorldEnvironment.new()
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


func _build_players() -> void:
	var blue := Player.new()
	blue.name = "BlueHuman"
	add_child(blue)
	blue.setup(self, 0, true)
	players.append(blue)

	var red := Player.new()
	red.name = "RedBot"
	add_child(red)
	red.setup(self, 1, false)
	players.append(red)


# ---------------------------------------------------------------- partida

func _physics_process(delta: float) -> void:
	_handle_restart()

	match match_state:
		"countdown":
			state_timer -= delta
			var n := int(ceil(maxf(state_timer, 0.0)))
			if n != _last_count:
				_last_count = n
				if n > 0:
					hud.flash(str(n), Color("#fde68a"), 0.85)
				else:
					hud.flash("JÁ!", Color("#a7f3d0"), 0.8)
			if state_timer <= 0.0:
				match_state = "play"
				ball.freeze = false

		"play":
			clock = maxf(0.0, clock - delta)
			hud.set_clock(clock)
			_check_goal()
			if match_state == "play":
				_check_ball_out()
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

		"end":
			pass


func _handle_restart() -> void:
	var pressed := Input.is_physical_key_pressed(KEY_R)
	if pressed and not _r_latch and Time.get_ticks_msec() - _start_ms > 900:
		restart()
	_r_latch = pressed


func _check_goal() -> void:
	var bp := ball.global_position
	if bp.y > Cfg.GOAL_H + 0.15 or bp.y < -0.5:
		return
	if bp.x > Cfg.FIELD_HALF:
		_on_goal(0)
	elif bp.x < -Cfg.FIELD_HALF:
		_on_goal(1)


func _check_ball_out() -> void:
	var bp := ball.global_position
	var out := false
	if bp.y > 15.0:
		out = true
	elif bp.y < -3.0:
		out = true
	elif absf(bp.x) > Cfg.FIELD_HALF + 2.8:
		out = true
	elif absf(bp.x) > Cfg.FIELD_HALF + 0.45 and bp.y > Cfg.GOAL_H:
		out = true
	if out:
		_throw_in()


func _throw_in() -> void:
	ball.global_position = Vector3(0.0, 2.4, 0.0)
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	ball.global_rotation = Vector3.ZERO
	hud.flash("FORA!", Color("#e2e8f0"), 0.6)


func _on_goal(team_id: int) -> void:
	score[team_id] += 1
	stats["goals"] += 1
	hud.set_score(score[0], score[1])
	var col: Color = Cfg.TEAM_A_COLOR.lightened(0.25) if team_id == 0 else Cfg.TEAM_B_COLOR.lightened(0.25)
	hud.flash("GOL!", col, 1.7)
	hud.clear_banner()
	shake = 1.5
	ball.freeze = true
	ball.linear_velocity = Vector3.ZERO
	# no modo smoke não cancelamos eventos no gol: a sequência precisa cobrir os 7
	if not smoke:
		events.reset()
	match_state = "goal"
	state_timer = Cfg.GOAL_PAUSE
	print("[GOL] time %d | placar %d x %d" % [team_id, score[0], score[1]])


func _reset_positions() -> void:
	for p in players:
		var side := -1.0 if p.team == 0 else 1.0
		p.freeze = false
		p.global_position = Vector3(side * 3.0, 2.2, 0.0)
		p.global_rotation = Vector3.ZERO
		p.linear_velocity = Vector3.ZERO
		p.angular_velocity = Vector3.ZERO
		p.facing = -side
		p.stun_left = 0.0
		p.kick_cd_left = 0.0
		p.tackle_cd_left = 0.0

	ball.freeze = false
	ball.global_position = Vector3(0.0, 1.6, 0.0)
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	ball.global_rotation = Vector3.ZERO

	trampoline = false
	brawl = false
	stadium.ground_mat.bounce = 0.3
	hud.set_hint(HINT_DEFAULT)


func _start_countdown() -> void:
	match_state = "countdown"
	state_timer = 0.2 if _shot else (0.4 if smoke else Cfg.START_COUNTDOWN)
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

	var res := "EMPATE!"
	if score[0] > score[1]:
		res = "%s VENCE!" % Cfg.TEAM_A_NAME
	elif score[1] > score[0]:
		res = "%s VENCE!" % Cfg.TEAM_B_NAME
	hud.flash(res, Color("#fde68a"), 6.0)
	hud.show_banner("FIM DE JOGO", "%d x %d — R para jogar de novo" % [score[0], score[1]], Color("#f8fafc"), 0.0)
	print("[FIM] %d x %d" % [score[0], score[1]])


func restart() -> void:
	score[0] = 0
	score[1] = 0
	trampoline = false
	brawl = false
	shake = 0.0
	stats["kicks"] = 0
	stats["tackles"] = 0
	stats["hits"] = 0
	stats["goals"] = 0
	events.enabled = true
	events.reset()
	_reset_positions()
	_start_countdown()
	hud.flash("DE NOVO!", Color("#fde68a"), 0.8)


# ---------------------------------------------------------------- reações

func on_kick(_p: Player, power: float) -> void:
	stats["kicks"] += 1
	shake = maxf(shake, 0.1 + power * 0.008)


func on_whiff(_p: Player) -> void:
	shake = maxf(shake, 0.05)


func on_tackle(_p: Player) -> void:
	stats["tackles"] += 1


func on_hit(_attacker: Player, _target: Player, _power: float) -> void:
	stats["hits"] += 1
	shake = maxf(shake, 0.45)


# ---------------------------------------------------------------- frame

func _process(delta: float) -> void:
	if shake > 0.01:
		shake = move_toward(shake, 0.0, delta * 2.6)
		cam.global_position = _cam_pos + Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * shake * 0.32
	else:
		shake = 0.0
		cam.global_position = _cam_pos

	if smoke:
		_smoke_tick(delta)

	if _shot and not _shot_done and Time.get_ticks_msec() - _start_ms > 5000:
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
	print("[SHOT] salvo em .preview/preview.png")
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

	if _smoke_stage == 0 and _smoke_t > 6.0:
		_smoke_stage = 1
		ball.freeze = false
		ball.global_position = Vector3(-Cfg.FIELD_HALF + 1.0, 0.8, 0.0)
		ball.linear_velocity = Vector3(-16.0, 0.0, 0.0)
		print("[SMOKE] arremesso de teste no gol esquerdo")
	elif _smoke_stage == 1 and _smoke_t > 7.5:
		_smoke_stage = 2
		if score[1] < 1:
			_smoke_ok = false
			printerr("[SMOKE] FALHA: gol nao detectado")
		else:
			print("[SMOKE] deteccao de gol OK (placar %d x %d)" % [score[0], score[1]])
	elif _smoke_t > 34.0:
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
