class_name FcLogo
extends Control

## Marca do FutCrazy: bola desenhada vetorialmente + wordmark pesado.
## A bola e um pentagono central com raios ate a borda, tudo em draw_* (sem asset).

var wordmark := "FUTCRAZY"
var word_size := 62.0

var _label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0.0, word_size * 1.35)
	_label = UiTheme.label(wordmark, int(word_size), UiTheme.CREAM, 3.0, 1.25)
	_label.add_theme_constant_override("outline_size", 12)
	_label.add_theme_color_override("font_outline_color", UiTheme.INK)
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(_label)
	resized.connect(_layout)
	_layout()


func set_word(text: String) -> void:
	wordmark = text
	if _label != null:
		_label.text = text


func _layout() -> void:
	if _label == null:
		return
	var r := minf(size.y * 0.46, 54.0)
	var left := r * 2.0 + 18.0
	_label.position = Vector2(left, 0.0)
	_label.size = Vector2(maxf(size.x - left, 10.0), size.y)
	_label.add_theme_font_size_override("font_size", int(maxf(18.0, minf(word_size, size.y * 0.72))))
	queue_redraw()


func _draw() -> void:
	var r := minf(size.y * 0.46, 54.0)
	var c := Vector2(r + 2.0, size.y * 0.5)
	var cream := UiTheme.CREAM

	# disco de fundo
	draw_circle(c, r, Color(0.04, 0.07, 0.05, 0.9))
	draw_arc(c, r, 0.0, TAU, 48, cream, 3.0, true)

	# pentagono central
	var pent := PackedVector2Array()
	var pr := r * 0.40
	for i in 5:
		var a := -PI * 0.5 + TAU * float(i) / 5.0
		pent.append(c + Vector2(cos(a), sin(a)) * pr)
	draw_colored_polygon(pent, cream)

	# raios do pentagono ate a borda
	for i in 5:
		var a := -PI * 0.5 + TAU * float(i) / 5.0
		var inner := c + Vector2(cos(a), sin(a)) * pr
		var outer := c + Vector2(cos(a), sin(a)) * (r * 0.97)
		draw_line(inner, outer, Color(cream.r, cream.g, cream.b, 0.85), 2.0)

	# gomos laterais (sugestao de costura)
	for i in 5:
		var a := -PI * 0.5 + TAU * (float(i) + 0.5) / 5.0
		var p1 := c + Vector2(cos(a - 0.34), sin(a - 0.34)) * (r * 0.97)
		var p2 := c + Vector2(cos(a + 0.34), sin(a + 0.34)) * (r * 0.97)
		draw_line(p1, p2, Color(cream.r, cream.g, cream.b, 0.55), 2.0)
