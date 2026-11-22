class_name BigHeadEvent
extends GameEvent

## Cabeção: cabeça enorme (e com colisor de verdade), cabeçadas fortes,
## centro de massa alto = equilíbrio horrível.


func _init(g: Node = null) -> void:
	super(g)
	id = "big_head"
	title = "CABEÇÃO"
	color = Color("#fb923c")
	duration = 10.0


func apply() -> void:
	super()
	for p in game.players:
		p.add_modifier(id, {
			"head": 2.7,
			"wobble": 1.9,
			"jump": 1.15,
			"kick_power": 1.1,
		})


func clear() -> void:
	for p in game.players:
		p.remove_modifier(id)
