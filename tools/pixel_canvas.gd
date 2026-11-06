extends RefCounted
## Siatka pikseli jednej klatki dla narzędzi rysujących postacie (make_friend_sprites.gd,
## make_beast_sprites.gd). Rysuje proste kształty bez wygładzania: piksel jest zapalony,
## gdy jego środek leży w kształcie. Współrzędne są w pikselach względem „stóp” klatki
## (punktu na ziemi pod postacią); y rośnie w dół. Wiersz stóp i niżej to ziemia - tam nic nie rysujemy.
## Wartości w siatce to numery „kolorów” narzędzia (0 = pusto).

const EMPTY := 0

var size: Vector2i
var feet: Vector2
var mask := PackedByteArray()


func _init(frame_size: Vector2i, feet_point: Vector2) -> void:
	size = frame_size
	feet = feet_point
	clear()


func clear() -> void:
	mask = PackedByteArray()
	mask.resize(size.x * size.y)


func to_pixel(local: Vector2) -> Vector2i:
	return Vector2i(floori(local.x + feet.x), floori(local.y + feet.y))


func center(px: int, py: int) -> Vector2:
	return Vector2(px + 0.5 - feet.x, py + 0.5 - feet.y)


func get_px(p: Vector2i) -> int:
	if p.x < 0 or p.y < 0 or p.x >= size.x or p.y >= int(feet.y):
		return EMPTY
	return mask[p.y * size.x + p.x]


func put(p: Vector2i, value: int) -> void:
	if p.x < 0 or p.y < 0 or p.x >= size.x or p.y >= int(feet.y):
		return
	mask[p.y * size.x + p.x] = value


func bounds(points: Array, pad: float) -> Rect2i:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p: Vector2 in points:
		lo = lo.min(p)
		hi = hi.max(p)
	var a := to_pixel(lo - Vector2(pad, pad))
	var b := to_pixel(hi + Vector2(pad, pad))
	return Rect2i(a, b - a + Vector2i.ONE)


func line(a: Vector2, b: Vector2, width: float, value: int) -> void:
	var r := bounds([a, b], width)
	var half := width * 0.5
	for py in range(r.position.y, r.end.y):
		for px in range(r.position.x, r.end.x):
			var c := center(px, py)
			if c.distance_to(Geometry2D.get_closest_point_to_segment(c, a, b)) <= half:
				put(Vector2i(px, py), value)


func polyline(points: Array[Vector2], width: float, value: int) -> void:
	for i in points.size() - 1:
		line(points[i], points[i + 1], width, value)


func poly(points: Array[Vector2], value: int) -> void:
	var packed := PackedVector2Array(points)
	var r := bounds(points, 1.0)
	for py in range(r.position.y, r.end.y):
		for px in range(r.position.x, r.end.x):
			if Geometry2D.is_point_in_polygon(center(px, py), packed):
				put(Vector2i(px, py), value)


func ellipse(c: Vector2, radii: Vector2, value: int) -> void:
	var r := bounds([c - radii, c + radii], 1.0)
	for py in range(r.position.y, r.end.y):
		for px in range(r.position.x, r.end.x):
			var d := (center(px, py) - c) / radii
			if d.length_squared() <= 1.0:
				put(Vector2i(px, py), value)


## Odcinek grubości 1 piksela, krok po kroku (do włosów, ogona, ostrza).
func thin_line(a: Vector2, b: Vector2, value: int) -> void:
	var steps := maxi(1, ceili(maxf(absf(b.x - a.x), absf(b.y - a.y))))
	for i in steps + 1:
		put(to_pixel(a.lerp(b, float(i) / steps)), value)


## Przenosi klatkę na arkusz w miejscu (kolumna, rząd), zamieniając numery na kolory.
func blit(sheet: Image, column: int, row: int, colors: Dictionary) -> void:
	var at := Vector2i(column * size.x, row * size.y)
	for py in size.y:
		for px in size.x:
			var v := mask[py * size.x + px]
			if v != EMPTY:
				sheet.set_pixel(at.x + px, at.y + py, colors[v])
