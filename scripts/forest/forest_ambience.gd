class_name ForestAmbience
extends Node2D
## Dźwięki nocnego lasu. Pętle (wiatr, woda, świerszcze) grają cały czas i na starcie
## powoli się pojawiają. Sowa i plusk ryby odzywają się co jakiś czas, z różnych miejsc.
## Dźwięki z miejscem w scenie (AudioStreamPlayer2D) słychać z lewej albo z prawej strony.
## Pliki leżą w sounds/otoczenie/ (wylicza je tools/make_sounds.gd); można je podmienić na nagrania.

## Ile sekund trwa pojawianie się dźwięków na starcie sceny.
@export var fade_in := 4.0
## Co ile sekund (od-do) odzywa się sowa.
@export var owl_every := Vector2(18.0, 40.0)
## Miejsca w koronach drzew, z których może odezwać się sowa.
@export var owl_spots: Array[Vector2] = [Vector2(40, 40), Vector2(440, 55), Vector2(330, 70)]
## Co ile sekund (od-do) w jeziorku pluska ryba.
@export var splash_every := Vector2(25.0, 55.0)
## Obszar jeziorka, w którym może plusnąć ryba.
@export var splash_area := Rect2(220, 145, 210, 30)

var _owl_wait := 0.0
var _splash_wait := 0.0

@onready var _owl: AudioStreamPlayer2D = $Owl
@onready var _splash: AudioStreamPlayer2D = $Splash


func _ready() -> void:
	_owl_wait = randf_range(6.0, 12.0)  # pierwsza sowa niedługo po wejściu
	_splash_wait = randf_range(10.0, 20.0)
	for child in get_children():
		if child.get_meta("loop", false):
			_fade_in_loop(child)


func _process(delta: float) -> void:
	_owl_wait -= delta
	if _owl_wait <= 0.0:
		_owl.position = owl_spots.pick_random()
		_owl.pitch_scale = randf_range(0.96, 1.04)
		_owl.play()
		_owl_wait = randf_range(owl_every.x, owl_every.y)
	_splash_wait -= delta
	if _splash_wait <= 0.0:
		_splash.position = splash_area.position + Vector2(randf(), randf()) * splash_area.size
		_splash.pitch_scale = randf_range(0.9, 1.1)
		_splash.play()
		_splash_wait = randf_range(splash_every.x, splash_every.y)


## Las cichnie: wszystkie dźwięki powoli gasną, sowa i ryba już się nie odzywają.
func fade_out(seconds: float) -> void:
	_owl_wait = INF
	_splash_wait = INF
	for child in get_children():
		if child is AudioStreamPlayer or child is AudioStreamPlayer2D:
			var tween := create_tween()
			tween.tween_property(child, "volume_db", -60.0, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			tween.tween_callback(child.stop)


## Pętla zaczyna od losowego miejsca (żeby nie było słychać zawsze tego samego początku)
## i płynnie nabiera głośności ustawionej w scenie.
func _fade_in_loop(player: Node) -> void:
	var target: float = player.volume_db
	player.volume_db = -50.0
	var stream: AudioStream = player.stream
	player.play(randf() * stream.get_length())
	create_tween().tween_property(player, "volume_db", target, fade_in) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
