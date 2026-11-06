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


## Zbocze: od SLOPE_START do SLOPE_END ziemia łagodnie opada z HIGH_GROUND do LOW_GROUND.
## Ten sam kształt liczy shader obrysu (moonlit_silhouette), żeby przycinać nogi bestii do ziemi.
const SLOPE_START := 156.0
const SLOPE_END := 246.0
const HIGH_GROUND := 188.0
const LOW_GROUND := 205.0


## Pierwszy wiersz ziemi pod punktem x (funkcja ziemia_gry w generatorze): po lewej ziemia
## leży wyżej, w środku łagodnie opada i dalej, przy jeziorku, jest płaska.
static func ground_y(x: float) -> int:
	var height: float
	if x < SLOPE_START:
		height = HIGH_GROUND
	elif x > SLOPE_END:
		height = LOW_GROUND
	else:
		var t := (x - SLOPE_START) / (SLOPE_END - SLOPE_START)
		height = HIGH_GROUND + (LOW_GROUND - HIGH_GROUND) * t * t * (3.0 - 2.0 * t)
	return ceili(height)


## Parametry zbocza dla shadera: (początek, koniec, wysoko, nisko).
static func slope_vector() -> Vector4:
	return Vector4(SLOPE_START, SLOPE_END, HIGH_GROUND, LOW_GROUND)
