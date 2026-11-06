class_name FriendMotor
extends RefCounted
## Logika ruchu przyjaciela, bez obrazu i dźwięku: bieg, przewrót, cięcia przed siebie i w górę.
## Obraz i dźwięk dobiera do niej `friend.gd`. Wszystko da się sprawdzić w testach.
##
## Zasady (wzorowane na Hollow Knight):
## - bieg rusza i staje prawie od razu,
## - cięcie można zrobić w biegu; w trakcie zamachu postać się nie odwraca,
## - przewrót przerywa cięcie, pokonuje zawsze ten sam dystans i przez chwilę chroni przed ciosem,
## - wciśnięcie trochę przed końcem poprzedniej akcji jest zapamiętane (bufor).

enum State { IDLE, RUN, ROLL, ATTACK_SIDE, ATTACK_UP }

# --- parametry (ustawia je friend.gd z wartości w Inspektorze) ---
var run_speed := 96.0         ## px/s
var acceleration := 1400.0    ## px/s²
var deceleration := 1700.0    ## px/s²
var roll_distance := 60.0     ## px
var roll_time := 0.38         ## s
var roll_cooldown := 0.18     ## s od końca przewrotu do następnego
var attack_time := 0.26       ## s, tyle trwa poza cięcia
var attack_cooldown := 0.32   ## s od początku cięcia do następnego
var buffer_time := 0.12       ## s, tyle wciśnięcie czeka na swoją kolej
var min_x := ForestTerrain.WALK_MIN_X
var max_x := ForestTerrain.WALK_MAX_X

# --- stan ---
var state := State.IDLE
var x := 0.0
var velocity := 0.0
var facing := 1
## Ile sekund trwa bieżąca akcja (przewrót albo cięcie).
var state_time := 0.0
## Droga przebyta w bieżącym biegu - według niej zmieniają się klatki biegu.
var run_distance := 0.0

var _attack_wait := 0.0
var _roll_wait := 0.0
var _attack_buffer := 0.0
var _roll_buffer := 0.0
var _buffered_up := false
var _roll_from := 0.0
var _events: Array[StringName] = []


## Jeden krok logiki. axis: -1..1 (lewo/prawo), up_held: trzymany kierunek w górę,
## attack_pressed / roll_pressed: przycisk wciśnięty w tej klatce.
## Zwraca zdarzenia: &"swing" (początek cięcia), &"roll_start", &"roll_land", &"run_start", &"turn".
func update(delta: float, axis: float, up_held: bool, attack_pressed: bool,
		roll_pressed: bool) -> Array[StringName]:
	_events.clear()
	if attack_pressed:
		_attack_buffer = buffer_time
		_buffered_up = up_held
	if roll_pressed:
		_roll_buffer = buffer_time
	_attack_wait = maxf(0.0, _attack_wait - delta)
	_roll_wait = maxf(0.0, _roll_wait - delta)
	state_time += delta

	if state == State.ROLL and state_time >= roll_time:
		_finish_roll(axis)
	elif is_attacking() and state_time >= attack_time:
		state = State.RUN if absf(velocity) > 1.0 else State.IDLE

	if _roll_buffer > 0.0 and state != State.ROLL and _roll_wait <= 0.0:
		_start_roll(axis)
	elif _attack_buffer > 0.0 and state != State.ROLL and _attack_wait <= 0.0:
		_start_attack(axis, _buffered_up)

	if state == State.ROLL:
		_move_roll()
	else:
		_move_run(delta, axis)

	_attack_buffer -= delta
	_roll_buffer -= delta
	return _events


func is_attacking() -> bool:
	return state == State.ATTACK_SIDE or state == State.ATTACK_UP


## W środku przewrotu postać nie obrywa (początek i koniec przewrotu już tak).
func is_invulnerable() -> bool:
	return state == State.ROLL and state_time > 0.04 and state_time < roll_time - 0.06


## Postęp bieżącej akcji 0..1 (do wyboru klatki).
func action_progress() -> float:
	var total := roll_time if state == State.ROLL else attack_time
	return clampf(state_time / total, 0.0, 1.0)


func _start_attack(axis: float, up: bool) -> void:
	if axis != 0.0:
		facing = 1 if axis > 0.0 else -1  # cięcie w stronę wciśniętego kierunku
	state = State.ATTACK_UP if up else State.ATTACK_SIDE
	state_time = 0.0
	_attack_wait = attack_cooldown
	_attack_buffer = 0.0
	_events.append(&"swing")


func _start_roll(axis: float) -> void:
	if axis != 0.0:
		facing = 1 if axis > 0.0 else -1
	state = State.ROLL
	state_time = 0.0
	_roll_from = x
	_roll_buffer = 0.0
	velocity = 0.0
	_events.append(&"roll_start")


func _finish_roll(axis: float) -> void:
	_move_roll_to(1.0)
	state = State.IDLE
	_roll_wait = roll_cooldown
	# gdy gracz trzyma kierunek przewrotu, postać biegnie dalej z rozpędu
	velocity = facing * run_speed * 0.5 if axis * facing > 0.0 else 0.0
	_events.append(&"roll_land")


## Przewrót: szybko na początku, wolniej na końcu. Pozycja wynika z czasu, więc dystans
## nie zależy od liczby klatek na sekundę.
func _move_roll() -> void:
	_move_roll_to(clampf(state_time / roll_time, 0.0, 1.0))


func _move_roll_to(t: float) -> void:
	var eased := 1.0 - (1.0 - t) * (1.0 - t)
	x = clampf(_roll_from + facing * roll_distance * eased, min_x, max_x)


func _move_run(delta: float, axis: float) -> void:
	var target := axis * run_speed
	var rate := deceleration
	if axis != 0.0 and (velocity == 0.0 or signf(axis) == signf(velocity)):
		rate = acceleration
	velocity = move_toward(velocity, target, rate * delta)
	var new_x := clampf(x + velocity * delta, min_x, max_x)
	if new_x == x and velocity != 0.0:
		velocity = 0.0  # krawędź sceny
	run_distance += absf(new_x - x)
	x = new_x

	if is_attacking():
		return  # w trakcie cięcia kierunek i poza się nie zmieniają
	var old_facing := facing
	if absf(velocity) > 0.5:
		facing = 1 if velocity > 0.0 else -1
	elif axis != 0.0:
		facing = 1 if axis > 0.0 else -1
	var moving := absf(velocity) > 1.0
	if moving and state != State.RUN:
		state = State.RUN
		run_distance = 0.0
		_events.append(&"run_start")
	elif not moving and state == State.RUN:
		state = State.IDLE
	if facing != old_facing and moving:
		_events.append(&"turn")
