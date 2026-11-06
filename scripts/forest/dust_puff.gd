class_name DustPuff
extends Node2D
## Drobne piksele, które rozlatują się, opadają i znikają: pył spod stóp albo iskry trafienia.
## Każdy piksel ma pełny kolor z palety i po prostu znika - bez półprzezroczystości.
## Węzeł stoi w (0, 0) sceny, więc piksele zostają w miejscu, gdy postać biegnie dalej.

const DUST_COLORS: Array[Color] = [Palette.MIST, Palette.WATER_EDGE, Palette.WATER_EDGE]

## Jak długo (od-do, w sekundach) żyje jeden piksel.
@export var lifetime := Vector2(0.18, 0.42)
## Kolory pikseli (puste = pył).
@export var colors: Array[Color] = []
## Mnożnik prędkości rozrzutu (iskry lecą szybciej niż pył).
@export var speed := 1.0
## Jak mocno piksele opadają (px/s na sekundę).
@export var gravity := 50.0

var _bits: Array = []  # słowniki: pos, vel, life, color


func _ready() -> void:
	set_process(false)


## Wyrzuca `count` pikseli z punktu `at`. direction: -1 w lewo, 1 w prawo, 0 na obie strony.
func puff(at: Vector2, direction: float, count: int) -> void:
	var palette := colors if not colors.is_empty() else DUST_COLORS
	for i in count:
		var side := direction if direction != 0.0 else (-1.0 if i % 2 == 0 else 1.0)
		var vel := Vector2(side * randf_range(15.0, 45.0) + randf_range(-10.0, 10.0), randf_range(-24.0, -6.0))
		_bits.append({
			"pos": at + Vector2(randf_range(-4.0, 4.0), -1.0) / speed,
			"vel": vel * speed,
			"life": randf_range(lifetime.x, lifetime.y),
			"color": palette.pick_random(),
		})
	set_process(true)


func _process(delta: float) -> void:
	var drag := pow(0.03, delta)
	for b: Dictionary in _bits:
		b.life -= delta
		b.vel *= drag
		b.vel.y += gravity * delta
		b.pos += b.vel * delta
	_bits = _bits.filter(func(b: Dictionary) -> bool: return b.life > 0.0)
	if _bits.is_empty():
		set_process(false)
	queue_redraw()


func _draw() -> void:
	for b: Dictionary in _bits:
		draw_rect(Rect2((b.pos as Vector2).round(), Vector2.ONE), b.color)
