class_name BrawlEvent
extends GameEvent

## Briga generalizada: em vez de futebol, pancadaria. A bola continua no campo.


func _init(g: Node = null) -> void:
	super(g)
	id = "brawl"
	title = "BRIGA GENERALIZADA"
	color = Color("#ef4444")
	duration = 10.0


func apply() -> void:
	super()
	game.brawl = true
	for p in game.players:
		p.add_modifier(id, {"speed": 1.1, "wobble": 1.2})
	game.hud.set_hint("SHIFT agora é SOCO   •   A/D mover   •   W pular   •   ESPAÇO chutar   •   R reiniciar")


func clear() -> void:
	game.brawl = false
	for p in game.players:
		p.remove_modifier(id)
	game.hud.set_hint("A/D mover   •   W pular   •   ESPAÇO chutar   •   SHIFT carrinho/pancada   •   R reiniciar")
