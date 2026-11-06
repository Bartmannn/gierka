class_name Judge
extends RefCounted
## Ocenia, czy naciśnięcie przycisku trafiło w nutę gracza.
##
## Zasady:
##   - trafienie w oknie "perfect" lub "good" wokół nuty wybija ją,
##   - cios zbyt wczesny (tuż przed oknem) zużywa nutę jako chybioną - to chroni przed klepaniem,
##   - cios daleko od nut to "pusty zamach" bez kary,
##   - nuta, której nikt nie odbił w porę, przepada (chybienie).
## Klasa nie wie nic o dźwięku ani obrazie, więc łatwo ją testować.

enum Kind {
	PERFECT,  ## idealnie w rytm
	GOOD,     ## trochę obok, ale zaliczone
	MISS,     ## nuta stracona
	EMPTY,    ## zamach w powietrze, żadna nuta nie była blisko
}

class Result:
	var kind: Kind
	var cue: Cue          ## null przy pustym zamachu
	var offset: float     ## różnica czasu (s): ujemna = za wcześnie, dodatnia = za późno

	func _init(p_kind: Kind, p_cue: Cue = null, p_offset: float = 0.0) -> void:
		kind = p_kind
		cue = p_cue
		offset = p_offset


var perfect_window := 0.05     ## s, w obie strony
var good_window := 0.10        ## s, w obie strony
var early_miss_window := 0.25  ## s przed nutą: cios w tym czasie (ale poza oknem good) psuje nutę

var _cues: Array[Cue] = []
var _next: int = 0                   # pierwsza nieoceniona nuta
var _late_misses: Array[Cue] = []    # nuty przegapione, czekające na odebranie


func _init(cues: Array[Cue]) -> void:
	_cues = cues


## Gracz nacisnął przycisk w chwili `time` (czas utworu, s).
func strike(time: float) -> Result:
	_skip_late_cues(time)
	if _next >= _cues.size():
		return Result.new(Kind.EMPTY)
	var cue := _cues[_next]
	var offset := time - cue.time
	if absf(offset) <= good_window:
		_next += 1
		return Result.new(Kind.PERFECT if absf(offset) <= perfect_window else Kind.GOOD, cue, offset)
	if offset < 0.0 and -offset <= early_miss_window:
		_next += 1
		return Result.new(Kind.MISS, cue, offset)
	return Result.new(Kind.EMPTY)


## Zwraca nuty, które minęły bez odpowiedzi (każdą tylko raz).
func collect_missed(time: float) -> Array[Cue]:
	_skip_late_cues(time)
	var missed := _late_misses
	_late_misses = []
	return missed


## Kolejne nuty oczekujące na cios (do pokazywania zapowiedzi).
func upcoming(time: float, horizon: float) -> Array[Cue]:
	var result: Array[Cue] = []
	for i in range(_next, _cues.size()):
		if _cues[i].time - time > horizon:
			break
		result.append(_cues[i])
	return result


func is_finished() -> bool:
	return _next >= _cues.size()


func reset() -> void:
	_next = 0
	_late_misses.clear()


func _skip_late_cues(time: float) -> void:
	while _next < _cues.size() and time - _cues[_next].time > good_window:
		_late_misses.append(_cues[_next])
		_next += 1
