class_name MidiTrack
extends RefCounted
## Jedna ścieżka z pliku MIDI: nazwa nadana w LMMS i nuty posortowane po czasie.

var name: String = ""
var notes: Array[MidiNote] = []
