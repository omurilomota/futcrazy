class_name GameEvent
extends RefCounted

## Base de todo evento de partida.
## Contrato: apply() liga o efeito, clear() desliga SÓ o que ele ligou.
## Cada evento é independente — adicionar um novo não mexe nos outros.

var id := ""
var title := ""
var subtitle := ""
var color := Color.WHITE
var duration := 10.0
var time_left := 0.0
var game: Node


func _init(g: Node = null) -> void:
	game = g


func apply() -> void:
	time_left = duration


func clear() -> void:
	pass


func label() -> String:
	return title if subtitle == "" else "%s — %s" % [title, subtitle]
