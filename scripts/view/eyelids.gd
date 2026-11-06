class_name Eyelids
extends Node2D
## Powieki rannego bohatera - zamiast paska zdrowia.
## Im mniej przytomności, tym niżej opadają i tym ciemniej robi się w oczach.
## Krawędź powiek jest ditherowana (szachownica Bayera), żeby pasowała do pixel artu.

const SCREEN := Vector2i(320, 180)
const CURVE := 28.0       ## jak bardzo powieki są wygięte (kształt oka)
const DITHER_ROWS := 4    ## szerokość miękkiej krawędzi w pikselach
const BAYER_4X4 := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

var openness := 1.0  ## 1 = oczy otwarte, 0 = zamknięte
var darkness := 0.0  ## 0..1, ogólne przyciemnienie obrazu


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if darkness > 0.003:
		draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(Palette.BLACK, darkness))
	var closed := 1.0 - clampf(openness, 0.0, 1.0)
	if closed <= 0.002:
		return
	var half_height := SCREEN.y * 0.5
	for x in SCREEN.x:
		var u := (x - SCREEN.x * 0.5) / (SCREEN.x * 0.5)
		var lid := roundf(closed * (half_height + CURVE * u * u))
		if lid > 0.0:
			draw_rect(Rect2(x, 0, 1, lid), Palette.BLACK)
			draw_rect(Rect2(x, SCREEN.y - lid, 1, lid), Palette.BLACK)
		for row in DITHER_ROWS:
			var density := float(DITHER_ROWS - row) / (DITHER_ROWS + 1)
			var top_y := int(lid) + row
			var bottom_y := SCREEN.y - 1 - int(lid) - row
			if _bayer(x, top_y) < density:
				draw_rect(Rect2(x, top_y, 1, 1), Palette.BLACK)
			if _bayer(x, bottom_y) < density:
				draw_rect(Rect2(x, bottom_y, 1, 1), Palette.BLACK)


func _bayer(x: int, y: int) -> float:
	return BAYER_4X4[(y & 3) * 4 + (x & 3)] / 16.0
