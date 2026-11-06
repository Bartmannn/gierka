class_name FriendMotor
extends RefCounted
## Logika ruchu przyjaciela, bez obrazu i dźwięku: bieg, przewrót, cięcia przed siebie i w górę.
## Obraz i dźwięk dobiera do niej `friend.gd`. Wszystko da się sprawdzić w testach.
##
## Zasady (wzorowane na Hollow Knight):
## - bieg rusza i staje prawie od razu,
## - cięcie można zrobić w biegu; w trakcie zamachu postać się nie odwraca,
## - przewrót przerywa cięcie, pokonuje zawsze ten sam dystans i przez chwilę chroni przed ciosem,
## - wciśnięcie trochę przed końcem poprzedniej akcji jest zapamiętane (bufor),
## - trafiony przyjaciel odlatuje do tyłu, przez chwilę nie słucha sterowania i miga (nietykalny).
##
## Prostokąty ciała i cięć (hitboxy) są opisane względem stóp postaci zwróconej w prawo
## (zob. HitboxMath); świat ich używa w ForestFight.

enum State { IDLE, RUN, ROLL, ATTACK_SIDE, ATTACK_UP, HURT }

## Ciało stojącej postaci, przykucniętej (początek i koniec przewrotu) i zwiniętej w kłębek.
## Kłębek jest niższy niż brzuch bestii, więc można się pod nią przetoczyć.
const BODY_STAND := Rect2(-6, -46, 12, 46)
const BODY_CROUCH := Rect2(-7, -30, 14, 30)
const BODY_BALL := Rect2(-7, -16, 14, 16)
## Zasięg cięć (tam, gdzie widać białą smugę).
const SLASH_SIDE := Rect2(4, -58, 32, 54)
const SLASH_UP := Rect2(-24, -62, 50, 32)
## Kiedy cięcie rani (s od początku zamachu) - tyle, ile narasta smuga.
const SLASH_ACTIVE := Vector2(0.03, 0.12)
## Część przewrotu, w której postać jest zwinięta w kłębek.
const BALL_PART := Vector2(0.12, 0.75)

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
var hurt_time := 0.25         ## s odrzutu po trafieniu (bez sterowania)
var hurt_knockback := 150.0   ## px/s, prędkość odrzutu
var hurt_invulnerable := 1.0  ## s nietykalności po trafieniu
var recoil_speed := 90.0      ## px/s, odbicie do tyłu po trafieniu bestii cięciem
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
## Numer zamachu - jedno cięcie może trafić tylko raz.
var swing_id := 0
## Ile jeszcze sekund trwa nietykalność po trafieniu.
var invulnerable_left := 0.0

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
	invulnerable_left = maxf(0.0, invulnerable_left - delta)
	state_time += delta

	if state == State.HURT:
		_update_hurt(delta)
		_attack_buffer -= delta
		_roll_buffer -= delta
		return _events

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


## W środku przewrotu i chwilę po trafieniu postać nie obrywa.
func is_invulnerable() -> bool:
	return is_rolling_safe() or invulnerable_left > 0.0 or state == State.HURT


## Środek przewrotu (początek i koniec przewrotu nie chronią).
func is_rolling_safe() -> bool:
	return state == State.ROLL and state_time > 0.04 and state_time < roll_time - 0.06


## Ciało postaci (względem stóp, zwróconej w prawo).
func body_box() -> Rect2:
	if state == State.ROLL:
		var t := action_progress()
		return BODY_BALL if t >= BALL_PART.x and t < BALL_PART.y else BODY_CROUCH
	return BODY_STAND


## Zasięg cięcia, gdy właśnie rani; w przeciwnym razie Rect2() (brak).
func slash_box() -> Rect2:
	if not is_attacking() or state_time < SLASH_ACTIVE.x or state_time >= SLASH_ACTIVE.y:
		return Rect2()
	return SLASH_UP if state == State.ATTACK_UP else SLASH_SIDE


## Bestia (albo jej atak) trafiła przyjaciela; from_x: skąd przyszedł cios.
func take_hit(from_x: float) -> void:
	state = State.HURT
	state_time = 0.0
	var away := 1.0 if x >= from_x else -1.0
	velocity = away * hurt_knockback
	facing = -int(away)  # trafiony patrzy na to, co go uderzyło
	invulnerable_left = hurt_invulnerable
	_attack_buffer = 0.0
	_roll_buffer = 0.0
	_events.append(&"hurt")


## Cięcie trafiło bestię: lekkie odbicie do tyłu (jak w Hollow Knight, tylko przy cięciu przed siebie).
func on_hit_landed() -> void:
	if state == State.ATTACK_SIDE:
		velocity -= facing * recoil_speed


func _update_hurt(delta: float) -> void:
	velocity = move_toward(velocity, 0.0, hurt_knockback / hurt_time * delta)
	x = clampf(x + velocity * delta, min_x, max_x)
	if state_time >= hurt_time:
		state = State.IDLE
		velocity = 0.0


## Postęp bieżącej akcji 0..1 (do wyboru klatki).
func action_progress() -> float:
	var total := roll_time if state == State.ROLL else attack_time
	return clampf(state_time / total, 0.0, 1.0)


func _start_attack(axis: float, up: bool) -> void:
	if axis != 0.0:
		facing = 1 if axis > 0.0 else -1  # cięcie w stronę wciśniętego kierunku
	state = State.ATTACK_UP if up else State.ATTACK_SIDE
	state_time = 0.0
	swing_id += 1
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
