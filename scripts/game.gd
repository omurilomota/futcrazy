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

## As teclas vivem no gerenciador central (Settings/InputMap); o HUD monta a dica
## a partir do que estiver configurado, então remapear não deixa a ajuda mentindo.

## Sistemas fixos vêm da cena (main.tscn) com nomes explícitos: abra a cena no
## editor e você vê Camera, Stadium, Ball, Sfx, Events, Hud e Menu na árvore.
## Só os jogadores são criados em tempo de execução, porque a quantidade depende
## do modo (2 ou 10).
@onready var stadium: Stadium = $Stadium
@onready var ball: Ball = $Ball
@onready var cam: Camera3D = $Camera
@onready var hud: Hud = $Hud
@onready var events: EventManager = $Events
@onready var sfx: Sfx = $Sfx
@onready var menu: MenuScreen = $Menu

var players: Array[Player] = []
var controlled: Player

## 0 = menu. 1/2/3 = entra direto no modo (útil em cenas de desenvolvimento).
@export_enum("Menu", "1 jogador", "2 jogadores", "Campo todo") var autostart_mode := 0

var match_state := "menu"
var prev_state := "play"
var mode := MODE_ARCADE
var state_timer := Cfg.START_COUNTDOWN
var score := [0, 0]
var clock := Cfg.MATCH_TIME
var trampoline := false
var brawl := false
var slope := 0.0

var stats := {"kicks": 0, "tackles": 0, "hits": 0, "goals": 0}

var shake := 0.0
var smoke := false
var smoke_campo := false
var smoke_ui := false
var _shot := false
var _shot_done := false
var _shot_menu := false
var _shot_mode := MODE_ARCADE
var _shot_screen := ""
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
var events_override := false   ## testes fixam o ritmo dos eventos e ignoram as opções

var _finishing := false

var _smoke_t := 0.0
var _smoke_stage := 0
var _smoke_ok := true
var _smoke_goal_at := 6.0
var _smoke_check_at := 7.5
var _smoke_end := 55.0
var _sample_t := 0.0
var _upright_samples := 0
var _upright_ok := 0


func _ready() -> void:
	# ------------------------------------------------ preview dentro do editor
	if Engine.is_editor_hint():
		_setup_camera()
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
	smoke_ui = "--smoke-ui" in args
	_shot_menu = "--shot-menu" in args
	var shot_campo := "--shot-campo" in args
	_shot_mode = MODE_FIELD if shot_campo else MODE_ARCADE
	for screen in ["modes", "options", "controls", "credits", "pause", "result"]:
		if ("--shot-%s" % screen) in args:
			_shot_screen = screen
	_shot = "--shot" in args or _shot_menu or shot_campo or _shot_screen != ""

	if smoke or smoke_campo:
		Engine.time_scale = 2.0

	if smoke_campo:
		_smoke_goal_at = 4.0
		_smoke_check_at = 5.5
		_smoke_end = 16.0

	_setup_camera()
	ball.setup(self)
	ball.global_position = Vector3(0.0, 1.4, 0.0)
	events.setup(self)

	menu.sfx = sfx
	menu.mode_selected.connect(start_match)
	menu.resume_requested.connect(_resume)
	menu.restart_requested.connect(restart)
	menu.menu_requested.connect(_open_menu)
	menu.quit_requested.connect(_quit_game)

	_human_teams = [0]
	_apply_layout(MODE_ARCADE)

	if smoke_ui:
		_run_ui_smoke()
		return

	if smoke:
		# bot x bot, tudo acelerado e na ordem do pool para exercitar os 7 eventos
		events_override = true
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
		events_override = true
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
		# telas de menu sao capturadas a partir do proprio menu (fluxo real)
		# e apenas pausa/resultado precisam de uma partida montada
		_shot_at = 1400
		if _shot_menu or _shot_screen in ["modes", "options", "controls", "credits"]:
			_open_menu()
			match _shot_screen:
				"modes":
					menu.show_modes()
				"options":
					menu.show_options("main")
				"controls":
					menu.show_controls("main")
				"credits":
					menu.show_credits()
		else:
			start_match(_shot_mode)
			Engine.time_scale = 0.35
			_shot_at = 3400 if _shot_mode == MODE_FIELD else 2200
			if _shot_screen == "pause":
				_pause()
			elif _shot_screen == "result":
				score[0] = 3
				score[1] = 2
				stats["goals"] = 5
				stats["kicks"] = 41
				stats["tackles"] = 12
				stats["hits"] = 9
				_end_match()
	elif autostart_mode > 0:
		start_match(autostart_mode)
	else:
		_open_menu()


# ---------------------------------------------------------------- montagem

## A câmera vem posicionada da cena para enquadrar o editor; aqui só garantimos
## que ela olhe para o alvo e que o tremor tenha um ponto de referência.
func _setup_camera() -> void:
	cam.current = true
	cam.look_at(CAM_TARGET, Vector3.UP)
	_cam_pos = cam.global_position


## Troca o tamanho do campo, o zoom da câmera e a quantidade de jogadores.
func _apply_layout(m: int) -> void:
	var changed := m != _layout_mode
	_layout_mode = m
	Cfg.field_half = Cfg.HALF_FIELD if m == MODE_FIELD else Cfg.HALF_ARCADE
	if changed or stadium.get_child_count() == 0:
		stadium.clear()
		stadium.build(self)
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
			p.action_prefix = "p2" if team == 1 else "p1"
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
	slope = 0.0
	_stuck_t = 0.0
	clock = Settings.match_time()
	menu.hide_all()

	events.enabled = true
	events.reset()
	_apply_event_settings()
	_apply_layout(mode)
	controlled = _initial_controlled()
	_reassign_control()

	# no modo 2P o P2 usa as setas; no 1P as setas também ajudam o P1
	Settings.apply_input_map(mode == MODE_LOCAL)

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
	hud.set_active_events([])
	ball.freeze = true
	for p in players:
		p.freeze = true
	events.enabled = false
	events.reset()
	sfx.set_intensity(0.18)


func _apply_event_settings() -> void:
	if events_override:
		return
	var gap := Settings.event_gap_scale()
	events.min_gap = 10.0 * gap
	events.max_gap = 16.0 * gap
	events.combo_chance = Settings.event_combo_chance()


func _mode_label() -> String:
	match mode:
		MODE_LOCAL:
			return "2 JOGADORES • ARCADE"
		MODE_FIELD:
			return "CAMPO TODO • 5x5"
		_:
			return "1 x BOT • ARCADE"


func _hint_for_mode() -> String:
	if mode == MODE_LOCAL:
		return "%s        %s        ESC pausa" % [_keys_hint("p1"), _keys_hint("p2")]
	if mode == MODE_FIELD:
		return "VOCÊ CONTROLA O JOGADOR MAIS PERTO DA BOLA   •   %s   •   ESC pausa" % _keys_hint("p1")
	return "%s   •   ESC pausa   •   R reiniciar" % _keys_hint("p1")


## Dica de controles montada a partir das teclas configuradas de verdade.
func _keys_hint(prefix: String) -> String:
	var who := ""
	if mode == MODE_LOCAL:
		who = "AZUL  " if prefix == "p1" else "VERMELHO  "
	return "%s%s/%s mover • %s pular • %s chutar • %s carrinho" % [
		who,
		Settings.key_label(Settings.key_for(prefix + "_left")),
		Settings.key_label(Settings.key_for(prefix + "_right")),
		Settings.key_label(Settings.key_for(prefix + "_jump")),
		Settings.key_label(Settings.key_for(prefix + "_kick")),
		Settings.key_label(Settings.key_for(prefix + "_tackle")),
	]


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
			_apply_slope()
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
	if smoke or smoke_campo or smoke_ui:
		return

	if _just(KEY_F11):
		Settings.toggle_fullscreen()

	if match_state == "menu":
		if _just(KEY_ESCAPE):
			menu.back()
		return

	if match_state == "paused":
		# ESC volta um nivel: fecha confirmacao, sai de opcoes/controles ou retoma
		if _just(KEY_ESCAPE) or _just(KEY_P):
			menu.back()
		return

	if match_state == "end":
		if _just(KEY_ESCAPE):
			_open_menu()
			return
	elif _just(KEY_ESCAPE):
		_pause()
		return

	if _just(KEY_R) and Time.get_ticks_msec() - _start_ms > 900:
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
	menu.show_pause(
		"%s   %d  x  %d   %s" % [Cfg.TEAM_A_NAME, score[0], score[1], Cfg.TEAM_B_NAME],
		"%02d:%02d  ·  %s" % [int(clock) / 60, int(clock) % 60, _mode_label()]
	)
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

## Campo inclinado: força lateral constante no chão (jogadores + bola).
func _apply_slope() -> void:
	if absf(slope) < 0.01:
		if cam != null and absf(cam.rotation.z) > 0.0005:
			cam.rotation.z = 0.0
		return
	for p in players:
		p.apply_central_force(Vector3(slope * p.mass, 0.0, 0.0))
	ball.apply_central_force(Vector3(slope * ball.mass * 2.4, 0.0, 0.0))
	if cam != null:
		cam.rotation.z = clampf(-slope * 0.004, -0.02, 0.02)


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
	# comemoração do time que marcou
	for p in players:
		if p.team == team_id and not p.is_gk():
			p.celebrate(1.7)
	# eventos NÃO são cancelados no gol: no modo campo todo eles sobrevivem ao kickoff
	match_state = "goal"
	# nos testes, pausa curta: senão os gols comem o tempo da sequência de eventos
	state_timer = 0.4 if (smoke or smoke_campo) else Cfg.GOAL_PAUSE
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
	clock = Settings.match_time()
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
	hud.set_active_events([])
	hud.clear_banner()
	hud.clear_message()
	hud.set_ui_visible(false)
	sfx.set_intensity(0.5)
	sfx.play("whistle", -4.0, 0.92)

	var headline := "EMPATE!"
	if score[0] > score[1]:
		headline = "%s VENCE" % Cfg.TEAM_A_NAME
	elif score[1] > score[0]:
		headline = "%s VENCE" % Cfg.TEAM_B_NAME

	menu.show_results({
		"mode": _mode_label(),
		"headline": headline,
		"a": score[0],
		"b": score[1],
		"name_a": Cfg.TEAM_A_NAME,
		"name_b": Cfg.TEAM_B_NAME,
		"stats": stats.duplicate(),
	})
	sfx.play("event", -12.0, 0.8)
	print("[FIM] %d x %d" % [score[0], score[1]])


func restart() -> void:
	start_match(mode)
	hud.flash("DE NOVO!", Color("#fde68a"), 0.8)


# ---------------------------------------------------------------- reações

func excite(v: float) -> void:
	_excite = maxf(_excite, v)


## Chamado pelo EventManager quando um evento (ou combo) começa.
func on_event_started(e: GameEvent) -> void:
	hud.flash_screen(e.color, 0.16)
	excite(0.75)


func spawn_dust(pos: Vector3, color := Color("#d6c9a8"), amount := 10.0, power := 1.0) -> void:
	if not Settings.effects_enabled():
		return
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
		var amp: float = shake * 0.32 * Settings.shake_scale()
		cam.global_position = _cam_pos + Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * amp
	else:
		shake = 0.0
		cam.global_position = _cam_pos

	_excite = move_toward(_excite, 0.3, delta * 0.45)
	sfx.set_intensity(_excite)
	stadium.set_scoreboard_visible(match_state != "menu")

	if (smoke or smoke_campo) and not _finishing:
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
	_finish_and_quit(0)


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
	_finish_and_quit(0 if _smoke_ok else 1)


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
	_finish_and_quit(0 if _smoke_ok else 1)


# ---------------------------------------------------------------- encerramento

func _quit_game() -> void:
	_shutdown_audio()
	get_tree().quit(0)


## Solta os streams antes de sair: sem isso o AudioServer mantem
## AudioStreamWAV/AudioStreamPlaybackWAV vivos e o Godot reporta vazamento.
func _shutdown_audio() -> void:
	if sfx != null:
		sfx.shutdown()


## Encerra o audio, deixa o AudioServer reciclar os playbacks e só então sai.
## Sem essa pequena espera o Godot reporta AudioStreamPlaybackWAV vivos ao fechar.
func _finish_and_quit(code: int) -> void:
	if _finishing:
		return
	_finishing = true
	_shutdown_audio()
	await get_tree().create_timer(0.25, true, false, true).timeout
	_shutdown_audio()
	get_tree().quit(code)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_shutdown_audio()
		get_tree().quit(0)


# ---------------------------------------------------------------- smoke de UI

func _ui_check(cond: bool, label: String) -> bool:
	if cond:
		print("[SMOKE-UI] ok: %s" % label)
	else:
		printerr("[SMOKE-UI] FALHA: %s" % label)
	return cond


## Percorre os fluxos reais de interface e estado da partida, sem depender de teclado
## ou de resultados aleatórios da física.
func _run_ui_smoke() -> void:
	var ok := true

	_open_menu()
	await get_tree().process_frame
	await get_tree().process_frame
	ok = _ui_check(menu.is_open() and menu.current_screen() == "main", "menu principal abre") and ok
	ok = _ui_check(menu.get_viewport().gui_get_focus_owner() != null, "menu principal dá foco ao primeiro botão") and ok

	menu.show_modes()
	await get_tree().process_frame
	ok = _ui_check(menu.current_screen() == "modes", "tela de modos abre") and ok
	menu.back()
	await get_tree().process_frame
	ok = _ui_check(menu.current_screen() == "main", "voltar de modos para o menu") and ok

	for m in [MODE_ARCADE, MODE_LOCAL, MODE_FIELD]:
		start_match(m)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var expected := 10 if m == MODE_FIELD else 2
		ok = _ui_check(players.size() == expected, "modo %d monta %d jogadores" % [m, expected]) and ok
		ok = _ui_check(not menu.is_open(), "modo %d esconde o menu" % m) and ok
		ok = _ui_check(match_state == "countdown" or match_state == "play", "modo %d entra em contagem" % m) and ok
		ok = _ui_check(hud.root.visible, "modo %d mostra o HUD" % m) and ok

	start_match(MODE_LOCAL)
	await get_tree().physics_frame
	var prefixes := {}
	for p in players:
		prefixes[p.action_prefix] = true
	ok = _ui_check(prefixes.size() == 2, "modo 2P tem dois esquemas de tecla") and ok

	start_match(MODE_ARCADE)
	await get_tree().physics_frame
	_pause()
	ok = _ui_check(match_state == "paused", "pausa congela o estado") and ok
	ok = _ui_check(menu.current_screen() == "pause", "menu de pausa abre") and ok
	var clock_paused := clock
	await get_tree().physics_frame
	await get_tree().physics_frame
	ok = _ui_check(absf(clock - clock_paused) < 0.001, "relogio para durante a pausa") and ok
	_resume()
	ok = _ui_check(match_state != "paused", "retomada sai da pausa") and ok
	ok = _ui_check(not menu.is_open(), "retomada fecha o menu") and ok

	score[0] = 2
	score[1] = 1
	stats["goals"] = 3
	_end_match()
	await get_tree().process_frame
	ok = _ui_check(match_state == "end", "fim de partida") and ok
	ok = _ui_check(menu.current_screen() == "results", "tela de resultado abre") and ok
	ok = _ui_check(not hud.root.visible, "HUD some no resultado") and ok

	restart()
	await get_tree().physics_frame
	ok = _ui_check(score[0] == 0 and score[1] == 0, "revanche zera o placar") and ok
	ok = _ui_check(hud.root.visible, "revanche devolve o HUD") and ok

	_open_menu()
	await get_tree().process_frame
	ok = _ui_check(menu.current_screen() == "main", "volta ao menu principal") and ok

	menu.show_options("main")
	await get_tree().process_frame
	ok = _ui_check(menu.current_screen() == "options", "tela de opcoes abre") and ok
	menu.back()
	await get_tree().process_frame
	ok = _ui_check(menu.current_screen() == "main", "voltar de opcoes") and ok
	menu.show_controls("main")
	await get_tree().process_frame
	ok = _ui_check(menu.current_screen() == "controls", "tela de controles abre") and ok
	menu.back()
	await get_tree().process_frame

	# persistencia real em disco, devolvendo os valores originais no fim
	var snapshot := {}
	for key in GameSettings.DEFAULTS.keys():
		snapshot[key] = Settings.get_value(key)
	Settings.set_value("audio/master", 0.42)
	Settings.save_settings()
	Settings.load_settings()
	ok = _ui_check(absf(Settings.master_volume() - 0.42) < 0.001, "configuracao persiste no disco") and ok
	for key in snapshot.keys():
		Settings.set_value(key, snapshot[key])
	Settings.save_settings()

	var old_key := Settings.key_for("p1_kick")
	Settings.set_binding("p1_kick", KEY_K)
	ok = _ui_check(Settings.key_for("p1_kick") == KEY_K, "remapear grava a tecla") and ok
	ok = _ui_check(Settings.conflict_for("p1_jump", KEY_K) == "p1_kick", "conflito de tecla e detectado") and ok
	ok = _ui_check(Settings.conflict_for("p1_jump", KEY_ESCAPE) == "PAUSA", "tecla reservada e recusada") and ok
	Settings.set_binding("p1_kick", old_key)

	# as opções precisam mudar o jogo, não só ficar salvas
	Settings.set_value("video/ui_scale", 1.15)
	ok = _ui_check(absf(get_window().content_scale_factor - 1.15) < 0.01, "escala da interface é aplicada") and ok
	Settings.set_value("video/ui_scale", 1.0)

	Settings.set_value("audio/sfx", 0.0)
	var sfx_bus := AudioServer.get_bus_index(GameSettings.BUS_SFX)
	ok = _ui_check(AudioServer.is_bus_mute(sfx_bus), "volume zero silencia o bus de efeitos") and ok
	Settings.set_value("audio/sfx", 0.9)

	Settings.set_value("a11y/shake", 0.0)
	ok = _ui_check(absf(Settings.shake_scale()) < 0.001, "tremor pode ser desligado") and ok
	Settings.set_value("a11y/shake", 1.0)

	Settings.set_value("game/match_time", 60.0)
	start_match(MODE_ARCADE)
	await get_tree().physics_frame
	ok = _ui_check(absf(clock - 60.0) < 0.5, "duração da partida vem das opções") and ok
	Settings.set_value("game/match_time", 120.0)

	start_match(MODE_ARCADE)
	await get_tree().physics_frame
	var residual := 0
	for script in events.POOL:
		var ev: GameEvent = script.new(self)
		ev.apply()
		ev.clear()
		for p in players:
			if p.has_modifier(ev.id):
				residual += 1
	ok = _ui_check(residual == 0, "eventos limpam seus modificadores") and ok
	ok = _ui_check(_world_is_clean(), "eventos nao deixam estado global residual") and ok

	_shutdown_audio()
	ok = _ui_check(sfx.streams.is_empty(), "audio e liberado no encerramento") and ok

	print("[SMOKE-UI] RESULTADO: %s" % ("OK" if ok else "FALHOU"))
	_finish_and_quit(0 if ok else 1)


func _world_is_clean() -> bool:
	return absf(slope) < 0.001 and not trampoline and not brawl
