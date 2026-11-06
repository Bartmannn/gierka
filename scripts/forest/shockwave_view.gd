class_name ShockwaveView
extends Node2D
## Fala tupnięcia biegnąca po ziemi: jasne czoło z pikseli palety i krótki, rzednący ślad
## za nim, plus pył spod czoła. Położenie fal bierze z logiki bestii (BeastBrain.waves),
## więc fala, którą widać, to dokładnie ta, która rani.

const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

## Logika bestii (ustawia ją forest_lake.gd).
var brain: BeastBrain
## Pył spod czoła fali (opcjonalnie).
var dust: DustPuff

var _dust_wait := 0.0
var _had_waves := false


func _process(delta: float) -> void:
	if brain == null:
		return
	var has_waves := not brain.waves.is_empty()
	if has_waves or _had_waves:
		queue_redraw()
	_had_waves = has_waves
	_dust_wait -= delta
	if has_waves and dust and _dust_wait <= 0.0:
		_dust_wait = 0.05
		for w in brain.waves:
			dust.puff(Vector2(roundf(w.x), ForestTerrain.ground_y(w.x)), -w.y, 1)


func _draw() -> void:
	if brain == null:
		return
	for w in brain.waves:
		var x0 := roundi(w.x)
		var dir := int(w.y)
		var height := 10 - int(minf(w.z, 1.5) * 3.0)  # z czasem fala niższa
		for k in 14:
			var x := x0 - dir * k
			var ground := ForestTerrain.ground_y(x)
			var h := maxi(1, height - k * 2 / 3)
			for i in h:
				var y := ground - 1 - i
				if k <= 1:
					# czoło fali: biały czubek, pod nim poświata
					var color := Palette.MOON if i >= h - 2 else (Palette.MOON_GLOW if i >= h - 5 else Palette.MIST)
					_dot(x, y, color)
				elif _bayer(x, y) < 1.0 - float(k) / 14.0:
					_dot(x, y, Palette.MOON_GLOW if i == h - 1 else Palette.MIST)


func _bayer(x: int, y: int) -> float:
	return (BAYER[(y & 3) * 4 + (x & 3)] + 0.5) / 16.0


func _dot(x: int, y: int, color: Color) -> void:
	draw_rect(Rect2(x, y, 1, 1), color)
