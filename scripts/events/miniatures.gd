class_name MiniaturesEvent
extends GameEvent

## Miniaturas: todo mundo encolhe e vira um bando de formigas correndo atrás
## de uma bola que agora parece gigante.


func _init(g: Node = null) -> void:
	super(g)
	id = "miniatures"
	title = "MINIATURAS"
	subtitle = "CABE TODO MUNDO NA BOLA"
	color = Color("#f472b6")
	duration = 10.0


func apply() -> void:
	super()
	if game.has_method("sfx_play"):
		game.sfx_play("squeak", -6.0, 1.1)
	for p in game.players:
		p.add_modifier(id, {
			"size": 0.55,
			"speed": 1.35,
			"jump": 1.12,
			"wobble": 1.2,
		})


func clear() -> void:
	for p in game.players:
		p.remove_modifier(id)
