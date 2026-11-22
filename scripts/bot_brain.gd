class_name BotBrain
extends RefCounted

## Cérebro do bot. Simples de propósito: empurra a bola para o gol adversário.
## Escreve direto no Player (input_move / want_jump / want_kick / want_tackle).

var attack_bias := 1.0
var _jitter := 0.0
var _jitter_t := 0.0
var _panic_t := 0.0


func think(p: Player, ball: Ball, delta: float) -> void:
	p.input_move = 0.0
	p.want_jump = false
	p.want_kick = false
	p.want_tackle = false
	if ball == null or p.game == null:
		return
	if p.game.match_state != "play":
		return

	_jitter_t -= delta
	if _jitter_t <= 0.0:
		_jitter_t = randf_range(0.5, 1.4)
		_jitter = randf_range(-1.0, 1.0)
	_panic_t = maxf(0.0, _panic_t - delta)

	var attack: float = p.goal_dir
	var bx := ball.global_position.x
	var px := p.global_position.x

	# posição ideal: um pouco atrás da bola, do lado do próprio gol
	var stand_off := 0.55 + p.body_radius() * 0.45
	var stand_x := bx - attack * stand_off
	var dx := stand_x - px
	var drift: float = clampf(dx * 2.0 + _jitter * 0.3, -1.0, 1.0)

	# às vezes o bot se atrapalha e trava por um instante (comédia + jogabilidade)
	if _panic_t > 0.0:
		drift *= 0.2

	p.input_move = drift
	if absf(drift) > 0.08:
		p.facing = signf(drift)

	var d := Vector2(bx - px, ball.global_position.y - p.global_position.y).length()
	var reach: float = 1.55 * p.get_stat("kick_range") + p.body_radius()
	if d < reach * 0.95:
		p.want_kick = true

	# bola alta: tenta cabecear
	if ball.global_position.y > p.global_position.y + 1.25 and d < 3.6 and p.is_grounded():
		p.want_jump = true

	# carrinho ocasional, mais frequente na briga generalizada
	var tackle_chance := 0.02 if p.game.brawl else 0.004
	if randf() < tackle_chance:
		p.want_tackle = true

	if randf() < 0.0007:
		_panic_t = randf_range(0.25, 0.6)
