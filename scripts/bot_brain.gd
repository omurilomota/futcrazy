class_name BotBrain
extends RefCounted

## Cérebro do bot, agora com dois papéis:
## - field: o mais perto da bola persegue e chuta; os outros seguem a formação
##          deslocada pela posição da bola (dá sensação de time, não de enxame).
## - gk: fica na linha do gol, sai um pouco atrás da bola, pula e corta.

## Quanto maior, mais afiado o bot. Indice = Settings.bot_difficulty().
## TRANQUILO erra mais e hesita; MALVADO fecha o angulo e arrisca mais carrinho.
const SKILL := [0.62, 1.0, 1.22]

var role := "field"
var slot_x := 0.0

var _jitter := 0.0
var _jitter_t := 0.0
var _panic_t := 0.0


func _init(new_role := "field", new_slot := 0.0) -> void:
	role = new_role
	slot_x = new_slot


func think(p: Player, ball: Ball, delta: float) -> void:
	p.input_move = 0.0
	p.want_jump = false
	p.want_kick = false
	p.want_tackle = false
	if ball == null or p.game == null:
		return
	if p.game.match_state != "play":
		return

	if role == "gk":
		_think_gk(p, ball, delta)
	else:
		_think_field(p, ball, delta)


# ------------------------------------------------------------------ goleiro

func _think_gk(p: Player, ball: Ball, delta: float) -> void:
	var h: float = Cfg.field_half
	var own_x := -h * p.goal_dir
	var bx := ball.global_position.x
	var inward := signf(bx - own_x)
	if inward == 0.0:
		inward = p.goal_dir

	var skill: float = SKILL[Settings.bot_difficulty()]

	# fica perto da linha, mas sai um pouco na direção da bola
	var target_x := own_x + inward * clampf(absf(bx - own_x) * 0.2, 0.4, 1.3)
	var drift := clampf((target_x - p.global_position.x) * 2.6 * skill, -1.0, 1.0)
	p.input_move = drift

	var d := absf(bx - p.global_position.x)
	var to_goal := signf(own_x - bx)
	var coming := absf(ball.linear_velocity.x) > 9.0 and signf(ball.linear_velocity.x) == to_goal

	# corta a bola que chega perto
	var reach: float = 1.65 * p.get_stat("kick_range") + p.body_radius()
	if d < reach:
		p.want_kick = true
	if ball.global_position.y > p.global_position.y + 0.9 and d < 3.0 and p.is_grounded():
		p.want_jump = true
	if coming and d < 3.2 and p.is_grounded():
		p.facing = signf(bx - p.global_position.x)
		p.want_tackle = true


# ------------------------------------------------------------------- linha

func _think_field(p: Player, ball: Ball, delta: float) -> void:
	var h: float = Cfg.field_half
	var bx := ball.global_position.x
	var px := p.global_position.x

	_jitter_t -= delta
	if _jitter_t <= 0.0:
		_jitter_t = randf_range(0.6, 1.6)
		_jitter = randf_range(-1.0, 1.0)
	_panic_t = maxf(0.0, _panic_t - delta)

	var d := Vector2(bx - px, ball.global_position.y - p.global_position.y).length()
	var chase := _is_chaser(p, ball) or d < 2.4

	var target_x := slot_x
	if chase:
		# fica um pouco atrás da bola, do lado do próprio gol
		var stand_off := 0.55 + p.body_radius() * 0.45
		target_x = bx - p.goal_dir * stand_off
	else:
		# formação acompanha a bola (time inteiro sobe e desce junto)
		target_x = clampf(slot_x + bx * 0.5, -h + 1.4, h - 1.4)

	var skill: float = SKILL[Settings.bot_difficulty()]
	var drift := clampf((target_x - px) * (1.2 + 0.8 * skill) + _jitter * 0.3, -1.0, 1.0)
	# às vezes o bot se atrapalha e trava por um instante (comédia + jogabilidade)
	if _panic_t > 0.0:
		drift *= 0.2

	p.input_move = drift
	if absf(drift) > 0.08:
		p.facing = signf(drift)

	var reach: float = 1.55 * p.get_stat("kick_range") + p.body_radius()
	if d < reach * 0.95:
		p.want_kick = true

	if ball.global_position.y > p.global_position.y + 1.25 and d < 3.6 and p.is_grounded():
		p.want_jump = true

	var tackle_chance := 0.02 if (p.game.brawl or p.team == 0 and d < 1.6) else 0.004
	if randf() < tackle_chance * skill:
		p.want_tackle = true

	# bot atrapalhado de proposito: quanto menor a dificuldade, mais ele trava
	if randf() < 0.0007 * (2.0 - skill):
		_panic_t = randf_range(0.25, 0.6)


## Só o jogador de linha mais perto da bola do time persegue; os outros mantêm posição.
func _is_chaser(p: Player, ball: Ball) -> bool:
	var best: Player = null
	var best_d := INF
	for other in p.game.players:
		var mate: Player = other
		if mate.team != p.team or mate.is_gk():
			continue
		var dd := mate.global_position.distance_to(ball.global_position)
		if dd < best_d:
			best_d = dd
			best = mate
	return best == p
