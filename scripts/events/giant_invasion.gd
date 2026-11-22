class_name GiantInvasionEvent
extends GameEvent

## Invasão dos gigantes: um jogador aleatório (seu ou do bot) cresce absurdamente.


var target: Player


func _init(g: Node = null) -> void:
	super(g)
	id = "giant_invasion"
	title = "INVASÃO DOS GIGANTES"
	color = Color("#c084fc")
	duration = 11.0
	if g != null and g.players.size() > 0:
		target = g.players.pick_random()
		if target.is_human:
			subtitle = "VOCÊ VIROU GIGANTE"
		else:
			subtitle = "O ADVERSÁRIO VIROU GIGANTE"


func apply() -> void:
	super()
	if target != null:
		target.add_modifier(id, {
			"size": 1.95,
			"kick_power": 1.5,
			"wobble": 1.4,
			"speed": 1.15,
		})


func clear() -> void:
	if target != null:
		target.remove_modifier(id)
