class_name DustPuff
extends Node2D
## Drobny pył spod stóp: kilka pikseli, które rozlatują się, opadają i znikają.
## Każdy piksel ma pełny kolor z palety i po prostu znika - bez półprzezroczystości.
## Węzeł stoi w (0, 0) sceny, więc pył zostaje w miejscu, gdy postać biegnie dalej.

const COLORS: Array[Color] = [Palette.MIST, Palette.WATER_EDGE, Palette.WATER_EDGE]

## Jak długo (od-do, w sekundach) żyje jeden pyłek.
@export var lifetime := Vector2(0.18, 0.42)

var _bits: Array = []  # słowniki: pos, vel, life, color


func _ready() -> void:
	set_process(false)


## Wyrzuca `count` pyłków z punktu `at`. direction: -1 w lewo, 1 w prawo, 0 na obie strony.
func puff(at: Vector2, direction: float, count: int) -> void:
	for i in count:
		var side := direction if direction != 0.0 else (-1.0 if i % 2 == 0 else 1.0)
		_bits.append({
			"pos": at + Vector2(randf_range(-4.0, 4.0), -1.0),
			"vel": Vector2(side * randf_range(15.0, 45.0) + randf_range(-10.0, 10.0), randf_range(-24.0, -6.0)),
			"life": randf_range(lifetime.x, lifetime.y),
			"color": COLORS.pick_random(),
		})
	set_process(true)


func _process(delta: float) -> void:
	var drag := pow(0.03, delta)
	for b: Dictionary in _bits:
		b.life -= delta
		b.vel *= drag
		b.vel.y += 50.0 * delta
		b.pos += b.vel * delta
	_bits = _bits.filter(func(b: Dictionary) -> bool: return b.life > 0.0)
	if _bits.is_empty():
		set_process(false)
	queue_redraw()


func _draw() -> void:
	for b: Dictionary in _bits:
		draw_rect(Rect2((b.pos as Vector2).round(), Vector2.ONE), b.color)
