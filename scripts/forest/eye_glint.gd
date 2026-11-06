class_name EyeGlint
extends Node2D
## Oko bestii. Zwykle to jeden jasny piksel i drugi, ciemniejszy obok (jak na szkicu).
## Przed atakiem błyska według wzoru danego ataku (BeastBrain.eye_glint):
##   -1 zgaszone, 0 zwykłe, 1 mały krzyżyk, 2 większy, 3 największy z promieniami w ditheringu.
## Rysuje tylko piksele z palety; węzeł stoi dokładnie w miejscu oka.

## Poziom błysku (-1..3).
var level := 0:
	set(value):
		if value != level:
			level = value
			queue_redraw()
## 1 = bestia patrzy w prawo, -1 = w lewo (ciemniejszy piksel oka jest od strony ucha).
var facing := 1:
	set(value):
		if value != facing:
			facing = value
			queue_redraw()


func _draw() -> void:
	match level:
		-1:
			return
		0:
			_dot(0, 0, Palette.MOON)
			_dot(-facing, 0, Palette.MOON_GLOW)
		1:
			_cross(1, Palette.MOON_GLOW)
			_dot(0, 0, Palette.MOON)
		2:
			_cross(2, Palette.MOON_GLOW)
			_cross(1, Palette.MOON)
		_:
			for d in range(4, 9, 2):  # promienie: przerywana linia na boki
				_dot(d, 0, Palette.MIST)
				_dot(-d, 0, Palette.MIST)
			for corner: Vector2i in [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
				_dot(corner.x, corner.y, Palette.MOON_GLOW)
			_cross(3, Palette.MOON_GLOW)
			_cross(2, Palette.MOON)


func _cross(arm: int, color: Color) -> void:
	for i in range(-arm, arm + 1):
		_dot(i, 0, color)
		_dot(0, i, color)


func _dot(x: int, y: int, color: Color) -> void:
	draw_rect(Rect2(x, y, 1, 1), color)
