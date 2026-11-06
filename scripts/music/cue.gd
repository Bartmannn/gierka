class_name Cue
extends RefCounted
## Jeden moment, w którym gracz ma uderzyć. Nuty zagrane razem (akord) tworzą jeden Cue,
## więc jedno naciśnięcie wybija cały akord.

var time: float = 0.0
var notes: Array[MidiNote] = []


## Najwyższa nuta akordu - od niej zależy np. miejsce błysku na ekranie.
func top_pitch() -> int:
	var top := 0
	for note in notes:
		top = maxi(top, note.pitch)
	return top
