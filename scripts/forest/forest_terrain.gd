class_name ForestTerrain
extends RefCounted
## Kształt sceny „las nad jeziorkiem”: gdzie jest ziemia, księżyc i dokąd można dojść.
## Wzory pochodzą z generatora grafiki (grafika/narzedzia/scena_las.py). Gdy grafika
## sceny się zmieni, trzeba poprawić też liczby tutaj, bo inaczej postać zawiśnie nad ziemią.

const SCREEN := Vector2i(480, 270)
## Środek księżyca na niebie (KS_X, KS_Y w generatorze).
const MOON := Vector2(238, 42)
## Linia dalekiego brzegu jeziorka (HORYZONT w generatorze).
const HORIZON := 131.0
## Najdalej na lewo i na prawo, dokąd może dojść postać (środek stóp).
const WALK_MIN_X := 18.0
const WALK_MAX_X := 462.0


## Pierwszy wiersz ziemi pod punktem x (funkcja ziemia_gry w generatorze): po lewej ziemia
## leży wyżej, w środku łagodnie opada i dalej, przy jeziorku, jest płaska.
static func ground_y(x: float) -> int:
	var height: float
	if x < 156.0:
		height = 188.0
	elif x > 246.0:
		height = 205.0
	else:
		var t := (x - 156.0) / 90.0
		height = 188.0 + 17.0 * t * t * (3.0 - 2.0 * t)
	return ceili(height)
