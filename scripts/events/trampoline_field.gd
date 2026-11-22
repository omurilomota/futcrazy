class_name TrampolineFieldEvent
extends GameEvent

## Campo de trampolim: o chão fica elástico para bola e jogadores.


func _init(g: Node = null) -> void:
	super(g)
	id = "trampoline"
	title = "CAMPO DE TRAMPOLIM"
	color = Color("#22d3ee")
	duration = 9.0


func apply() -> void:
	super()
	game.trampoline = true
	game.stadium.ground_mat.bounce = 0.8


func clear() -> void:
	game.trampoline = false
	game.stadium.ground_mat.bounce = 0.3
