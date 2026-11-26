class_name TiltedFieldEvent
extends GameEvent

## Campo inclinado: o gramado "entorta" e tudo é puxado para um dos lados.
## O game aplica a força no jogador e na bola; aqui só ligamos/desligamos.


var sign_x := 1.0


func _init(g: Node = null) -> void:
	super(g)
	id = "tilted_field"
	title = "CAMPO INCLINADO"
	subtitle = "SEGURA!"
	color = Color("#fbbf24")
	duration = 9.0


func apply() -> void:
	super()
	sign_x = 1.0 if randf() < 0.5 else -1.0
	game.slope = 3.8 * sign_x
	subtitle = "TUDO ROLA PARA A %s" % ("DIREITA" if sign_x > 0.0 else "ESQUERDA")
	if game.has_method("sfx_play"):
		game.sfx_play("rumble", -6.0)
	if game.has_method("excite"):
		game.excite(0.55)


func clear() -> void:
	game.slope = 0.0
