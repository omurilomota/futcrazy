class_name TurboSpeedEvent
extends GameEvent

## Velocidade absurda: todo mundo acelera demais e o controle fica uma loteria.


func _init(g: Node = null) -> void:
	super(g)
	id = "turbo_speed"
	title = "VELOCIDADE ABSURDA"
	color = Color("#facc15")
	duration = 10.0


func apply() -> void:
	super()
	for p in game.players:
		p.add_modifier(id, {
			"speed": 2.05,
			"steer": 0.55,
			"kick_power": 1.35,
			"wobble": 1.6,
		})


func clear() -> void:
	for p in game.players:
		p.remove_modifier(id)
