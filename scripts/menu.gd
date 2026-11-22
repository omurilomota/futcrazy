class_name MenuScreen
extends CanvasLayer

## Sobreposições de menu/pausa, montadas por código (mesmo estilo do HUD).

var _title: Label
var _sub: Label
var _body: Label
var _foot: Label


func _ready() -> void:
	layer = 20
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.08, 0.84)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_title = _label(96, Color("#fde68a"), 128.0, 130.0)
	_sub = _label(22, Color("#dbeafe"), 258.0, 60.0)
	_body = _label(30, Color("#f8fafc"), 330.0, 170.0)
	_foot = _label(20, Color("#a9b8ca"), 556.0, 90.0)


func _label(size: int, color: Color, top: float, height: float) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", maxi(4, size / 8))
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.06, 0.95))
	l.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	l.offset_top = top
	l.offset_bottom = top + height
	add_child(l)
	return l


func show_main() -> void:
	visible = true
	_title.text = "FUTCRAZY"
	_title.add_theme_color_override("font_color", Color("#fde68a"))
	_sub.text = "não é um simulador de futebol.\né comédia física com cenário de futebol."
	_body.text = "[ 1 ]   UM JOGADOR  x  BOT\n\n[ 2 ]   DOIS JOGADORES  (mesmo teclado)"
	_foot.text = "A/D mover • W pular • ESPAÇO chutar • SHIFT carrinho\nESC pausa   •   R reinicia a partida"


func show_pause() -> void:
	visible = true
	_title.text = "PAUSADO"
	_title.add_theme_color_override("font_color", Color("#f8fafc"))
	_sub.text = ""
	_body.text = "ESC  ou  P   continuar\n\nENTER   sair para o menu"
	_foot.text = "a partida continua de onde parou"


func hide_all() -> void:
	visible = false
