class_name HitboxMath
extends RefCounted
## Prostokąty ciał i ciosów (hitboxy). Każdy jest opisany względem stóp postaci zwróconej
## w prawo: x rośnie do przodu, y w górę jest ujemne (jak na ekranie). Te funkcje przenoszą
## go na scenę i sprawdzają trafienia. Brak prostokąta = Rect2() (zero pola).


## Prostokąt z opisu postaci na współrzędne sceny. facing: 1 w prawo, -1 w lewo (odbicie).
static func to_world(local: Rect2, feet: Vector2, facing: int) -> Rect2:
	if not local.has_area():
		return Rect2()
	var r := local
	if facing < 0:
		r.position.x = -local.end.x
	r.position += feet
	return r


## Czy dwa prostokąty na siebie zachodzą (same krawędzie się nie liczą).
static func hits(a: Rect2, b: Rect2) -> bool:
	return a.has_area() and b.has_area() and a.intersects(b)


## Środek wspólnej części - tam pokazujemy iskry trafienia.
static func contact_point(a: Rect2, b: Rect2) -> Vector2:
	return a.intersection(b).get_center()
