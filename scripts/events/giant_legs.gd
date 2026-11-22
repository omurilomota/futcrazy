class_name GiantLegsEvent
extends GameEvent

## Pernas gigantes: alcance e potência de chute absurdos, corpo mais cambaleante.


func _init(g: Node = null) -> void:
	super(g)
	id = "giant_legs"
	title = "PERNAS GIGANTES"
	color = Color("#a3e635")
	duration = 11.0


func apply() -> void:
	super()
	for p in game.players:
		p.add_modifier(id, {
			"leg_len": 3.2,
			"kick_range": 2.4,
			"kick_power": 1.5,
			"wobble": 1.35,
			"speed": 1.05,
		})


func clear() -> void:
	for p in game.players:
		p.remove_modifier(id)
