class_name MoonGravityEvent
extends GameEvent

## Gravidade lunar: todo mundo flutua, pulos duram uma eternidade e a bola
## demora a cair. Combina muito bem com pernas gigantes e trampolim.


func _init(g: Node = null) -> void:
	super(g)
	id = "moon_gravity"
	title = "GRAVIDADE LUNAR"
	subtitle = "TODO MUNDO FLUTUA"
	color = Color("#a5b4fc")
	duration = 10.0


func apply() -> void:
	super()
	if game.has_method("sfx_play"):
		game.sfx_play("moon", -8.0)
	for p in game.players:
		p.add_modifier(id, {
			"gravity": 0.28,
			"jump": 1.35,
			"wobble": 0.8,
		})
	game.ball.add_modifier(id, {
		"gravity": 0.35,
		"tint": Color("#e0e7ff"),
	})


func clear() -> void:
	for p in game.players:
		p.remove_modifier(id)
	game.ball.remove_modifier(id)
