class_name MidiNote
extends RefCounted
## Jedna nuta z pliku MIDI. Czasy są już przeliczone na sekundy od początku utworu.

var time: float = 0.0      ## początek nuty (s)
var duration: float = 0.0  ## długość nuty (s)
var pitch: int = 60        ## wysokość, 60 = C4
var velocity: int = 100    ## głośność 1-127
var channel: int = 0       ## kanał MIDI 0-15


func _init(p_time: float = 0.0, p_duration: float = 0.0, p_pitch: int = 60,
		p_velocity: int = 100, p_channel: int = 0) -> void:
	time = p_time
	duration = p_duration
	pitch = p_pitch
	velocity = p_velocity
	channel = p_channel


func end_time() -> float:
	return time + duration


func _to_string() -> String:
	return "MidiNote(t=%.3f, dur=%.3f, pitch=%d, vel=%d)" % [time, duration, pitch, velocity]
