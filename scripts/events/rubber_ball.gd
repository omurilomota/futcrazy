class_name RubberBallEvent
extends GameEvent

## Bola de borracha: bounce altíssimo e leve, um chute torto manda a bola longe.


func _init(g: Node = null) -> void:
	super(g)
	id = "rubber_ball"
	title = "BOLA DE BORRACHA"
	color = Color("#f472b6")
	duration = 12.0


func apply() -> void:
	super()
	game.ball.add_modifier(id, {
		"bounce": 0.96,
		"friction": 0.35,
		"mass": 0.7,
		"tint": Color("#fda4af"),
	})


func clear() -> void:
	game.ball.remove_modifier(id)
