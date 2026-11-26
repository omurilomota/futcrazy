class_name FcPoster
extends Control

## Fundo de cartaz do menu: chapa de verde de campo com borda inclinada,
## faixas de grama cortada, circulo central apagado e marcas de campo.
## Desenhado por codigo para a interface ter identidade propria sem asset externo.

var slant := 34.0
var show_pitch := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 1.0 or h <= 1.0:
		return

	var poly := PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(w, 0.0),
		Vector2(w - slant, h),
		Vector2(0.0, h),
	])
	draw_colored_polygon(poly, UiTheme.PITCH_DEEP)

	# faixas de grama cortada: variacao sutil, sem virar degrade
	var band := 54.0
	var y := 0.0
	var i := 0
	while y < h:
		if i % 2 == 0:
			var inset := slant * clampf(y / h, 0.0, 1.0)
			draw_rect(Rect2(0.0, y, w - inset, minf(band, h - y)), Color(1.0, 1.0, 1.0, 0.014))
		y += band
		i += 1

	if show_pitch:
		var ink := Color(UiTheme.CREAM.r, UiTheme.CREAM.g, UiTheme.CREAM.b, 0.055)
		var cx := w * 0.46
		var cy := h * 0.80
		var r := minf(w, h) * 0.40
		draw_arc(Vector2(cx, cy), r, 0.0, TAU, 72, ink, 2.0)
		draw_line(Vector2(0.0, cy), Vector2(w, cy), ink, 2.0)
		# pequena area de gol no canto inferior
		draw_rect(Rect2(0.0, cy - r * 0.45, r * 0.55, r * 0.9), ink, false, 2.0)

	# borda inclinada: linha de giz
	draw_line(Vector2(w, 0.0), Vector2(w - slant, h), Color(UiTheme.CREAM.r, UiTheme.CREAM.g, UiTheme.CREAM.b, 0.30), 2.0)

	# hachura de cartaz no topo
	var hatch := Color(UiTheme.YELLOW.r, UiTheme.YELLOW.g, UiTheme.YELLOW.b, 0.20)
	var hx := 0.0
	while hx < 180.0 and hx < w:
		draw_line(Vector2(hx, 0.0), Vector2(hx + 40.0, 40.0), hatch, 2.0)
		hx += 16.0
	draw_line(Vector2(0.0, 40.0), Vector2(minf(180.0, w), 40.0), hatch, 2.0)
