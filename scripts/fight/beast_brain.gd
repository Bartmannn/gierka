class_name BeastBrain
extends RefCounted
## Logika bestii (dzika ze szkicu grafiki), bez obrazu i dźwięku.
##
## Bestia podchodzi do przyjaciela, trzyma dystans i co chwilę wyprowadza jeden z trzech ataków.
## Każdy atak ma zapowiedź (TELEGRAPH) z własnym wzorem błysku oczu (`eye_glint`), potem sam
## atak (ATTACK) i odpoczynek (RECOVER) - wtedy najłatwiej ją ciąć.
##   CHARGE  szarża: długi, narastający błysk; pędzi przed siebie, groźne są łeb i pierś
##   TUSK    cios kłami: dwa szybkie mrugnięcia; podrzut łba tuż przed sobą
##   STOMP   tupnięcie: oczy gasną, potem rozbłysk; uderza racicami, fala biegnie po ziemi
## Atak wybiera prosta sztuczna inteligencja (`_choose_attack`), ale można go też wywołać
## z zewnątrz przez `start_attack` - np. później nutą z MIDI.
## Prostokąty są opisane względem stóp bestii zwróconej w prawo (zob. HitboxMath).

enum State { IDLE, WALK, TELEGRAPH, ATTACK, RECOVER, DYING, DEAD }
enum Attack { NONE, CHARGE, TUSK, STOMP }

## Ciało, w które trafia ostrze: tułów i łeb, bez nóg.
const HURTBOX := Rect2(-66, -76, 158, 58)
## Szarża: łeb, kły i pierś aż do ziemi. Tylny tułów nie rani - pod nim można się przetoczyć.
const CHARGE_BOX := Rect2(40, -60, 52, 60)
## Cios kłami: strefa tuż przed łbem.
const TUSK_BOX := Rect2(60, -64, 44, 64)
## Uderzenie racicami przy tupnięciu.
const STOMP_BOX := Rect2(30, -22, 70, 22)
## Fala tupnięcia (prostokąt wokół jej czoła).
const WAVE_BOX := Rect2(-4, -10, 8, 10)
## Jak daleko od środka bestii sięga czubek łba (do mierzenia odległości).
const HEAD_REACH := 90.0
## Połowa rozstawu nóg - na zboczu bestia stoi na niżej położonej parze.
const HALF_STANCE := 50.0
## Kiedy w ataku działają uderzenia (sekundy od początku ataku).
const TUSK_ACTIVE := Vector2(0.04, 0.16)
const STOMP_ACTIVE := Vector2(0.10, 0.18)
const STOMP_IMPACT := 0.10

# --- parametry (ustawia je beast.gd z wartości w Inspektorze) ---
var walk_speed := 38.0          ## px/s
var charge_speed := 230.0       ## px/s
var charge_distance := 280.0    ## px, najdłuższa szarża
var wave_speed := 170.0         ## px/s, fala tupnięcia
var max_health := 16            ## ile cięć wytrzymuje
var counter_delay := 0.25       ## s - tak szybko odpowiada atakiem, gdy ktoś ją tnie, a ona akurat nie atakuje
var first_attack_delay := 2.0   ## s od początku walki do pierwszego ataku
var rest_time := Vector2(0.5, 1.1)  ## s przerwy między atakami (od-do)
var telegraph_time := {Attack.CHARGE: 0.75, Attack.TUSK: 0.45, Attack.STOMP: 0.6}
var attack_time := {Attack.CHARGE: 2.0, Attack.TUSK: 0.24, Attack.STOMP: 0.3}
var recover_time := {Attack.CHARGE: 0.9, Attack.TUSK: 0.55, Attack.STOMP: 0.8}
var dying_time := 1.4
## Bestia tylko chodzi i oddycha, nie atakuje (do pokazu ruchu).
var passive := false
var min_x := ForestTerrain.WALK_MIN_X + 75.0
var max_x := ForestTerrain.WALK_MAX_X - 75.0

# --- stan ---
var state := State.IDLE
var attack := Attack.NONE
var x := 380.0
var facing := -1
var state_time := 0.0
var health := 16
## Droga przebyta krokami (do klatek chodu i szarży).
var travel := 0.0
## Fale tupnięcia: Vector3(x czoła, kierunek, wiek w s).
var waves: Array[Vector3] = []
var rng := RandomNumberGenerator.new()

var _rest_left := 0.0
var _charge_from := 0.0
var _history: Array[Attack] = []
var _events: Array[StringName] = []


func _init(seed_value: int = 1) -> void:
	rng.seed = seed_value
	health = max_health
	_rest_left = first_attack_delay


## Jeden krok logiki. friend_x: gdzie stoi przyjaciel.
## Zwraca zdarzenia: &"telegraph", &"attack", &"stomp", &"charge_end", &"step", &"dying", &"dead".
func update(delta: float, friend_x: float) -> Array[StringName]:
	_events.clear()
	state_time += delta
	_update_waves(delta)
	match state:
		State.IDLE, State.WALK:
			_think(delta, friend_x)
		State.TELEGRAPH:
			if state_time >= telegraph_time[attack]:
				_set_state(State.ATTACK)
				_charge_from = x
				_events.append(&"attack")
		State.ATTACK:
			_update_attack(delta)
		State.RECOVER:
			if state_time >= recover_time[attack]:
				attack = Attack.NONE
				_rest_left = rng.randf_range(rest_time.x, rest_time.y)
				_set_state(State.IDLE)
		State.DYING:
			if state_time >= dying_time:
				_set_state(State.DEAD)
				_events.append(&"dead")
	return _events


## Ile sekund bestia czeka przed kolejnym (np. pierwszym) atakiem.
func wait_before_attack(seconds: float) -> void:
	_rest_left = seconds


## Rozpoczyna zapowiedź ataku (gdy bestia nie jest zajęta innym atakiem).
func start_attack(kind: Attack) -> bool:
	if not is_alive() or state in [State.TELEGRAPH, State.ATTACK, State.RECOVER] or kind == Attack.NONE:
		return false
	attack = kind
	_history.append(kind)
	_set_state(State.TELEGRAPH)
	_events.append(&"telegraph")
	return true


## Trafienie ostrzem. Zwraca true, jeśli cios coś zrobił.
func take_hit() -> bool:
	if not is_alive():
		return false
	health -= 1
	if state == State.IDLE or state == State.WALK:
		_rest_left = minf(_rest_left, counter_delay)  # nie da się jej ciąć bezkarnie: kontratak
	if health <= 0:
		attack = Attack.NONE
		waves.clear()
		_set_state(State.DYING)
		_events.append(&"dying")
	return true


func is_alive() -> bool:
	return state != State.DYING and state != State.DEAD


## Stopy bestii na scenie. Na zboczu stoi na niższej parze nóg; wyższe nogi chowają się w trawie.
func feet() -> Vector2:
	var ground := maxi(ForestTerrain.ground_y(x - HALF_STANCE), ForestTerrain.ground_y(x + HALF_STANCE))
	return Vector2(x, ground)


func hurtbox() -> Rect2:
	return HitboxMath.to_world(HURTBOX, feet(), facing) if is_alive() else Rect2()


## Wszystkie prostokąty, które w tej chwili ranią przyjaciela (na scenie).
func attack_boxes() -> Array[Rect2]:
	var boxes: Array[Rect2] = []
	if state == State.ATTACK:
		match attack:
			Attack.CHARGE:
				boxes.append(HitboxMath.to_world(CHARGE_BOX, feet(), facing))
			Attack.TUSK:
				if state_time >= TUSK_ACTIVE.x and state_time < TUSK_ACTIVE.y:
					boxes.append(HitboxMath.to_world(TUSK_BOX, feet(), facing))
			Attack.STOMP:
				if state_time >= STOMP_ACTIVE.x and state_time < STOMP_ACTIVE.y:
					boxes.append(HitboxMath.to_world(STOMP_BOX, feet(), facing))
	for w in waves:
		boxes.append(Rect2(WAVE_BOX.position + Vector2(w.x, ForestTerrain.ground_y(w.x)), WAVE_BOX.size))
	return boxes


## Błysk oczu: -1 = oko zgaszone, 0 = zwykłe oko, 1-3 = coraz mocniejszy błysk (3 z promieniami).
## Każdy atak ma swój wzór, żeby gracz rozpoznał go po samych oczach.
func eye_glint() -> int:
	match state:
		State.DEAD:
			return -1
		State.DYING:
			return 0 if state_time < dying_time * 0.5 else -1
		State.TELEGRAPH:
			var t: float = state_time / telegraph_time[attack]
			match attack:
				Attack.CHARGE:
					return 1 + mini(int(t * 3.0), 2)  # narasta: 1, 2, 3
				Attack.TUSK:
					var s := state_time
					return 2 if (s < 0.08 or (s >= 0.17 and s < 0.25)) else 0  # dwa mrugnięcia
				Attack.STOMP:
					return -1 if t < 0.6 else 3  # oczy gasną, potem nagły rozbłysk
		State.ATTACK:
			if attack == Attack.CHARGE:
				return 2  # w szarży oczy płoną cały czas
			return 1 if state_time < 0.1 else 0
	return 0


## Sztuczna inteligencja: zwrot do przyjaciela, podchodzenie, wybór ataku.
func _think(delta: float, friend_x: float) -> void:
	var diff := friend_x - x
	if absf(diff) > 4.0:
		facing = 1 if diff > 0.0 else -1
	var gap := absf(diff) - HEAD_REACH  # odległość od czubka łba do przyjaciela
	_rest_left -= delta
	if _rest_left <= 0.0 and not passive:
		start_attack(_choose_attack(gap))
		return
	var move := 0.0
	if gap > 110.0:
		move = facing * walk_speed
	elif gap < 30.0:
		move = -facing * walk_speed * 0.6  # cofa się, gdy przyjaciel podejdzie za blisko
	_walk(move * delta)
	var new_state := State.WALK if move != 0.0 else State.IDLE
	if new_state != state:
		_set_state(new_state)


func _choose_attack(gap: float) -> Attack:
	var room := (max_x - x) if facing > 0 else (x - min_x)
	var weights := {}
	if gap < 40.0:
		weights = {Attack.TUSK: 0.45, Attack.STOMP: 0.3, Attack.CHARGE: 0.25}
	elif gap < 150.0:
		weights = {Attack.TUSK: 0.25, Attack.STOMP: 0.4, Attack.CHARGE: 0.35}
	else:
		weights = {Attack.CHARGE: 0.7, Attack.STOMP: 0.3}
	if room < 80.0:
		weights.erase(Attack.CHARGE)  # za mało miejsca na rozpęd
	# bez trzech takich samych ataków z rzędu
	var n := _history.size()
	if n >= 2 and _history[n - 1] == _history[n - 2] and weights.size() > 1:
		weights.erase(_history[n - 1])
	var total := 0.0
	for k in weights:
		total += weights[k]
	var pick := rng.randf() * total
	for k in weights:
		pick -= weights[k]
		if pick <= 0.0:
			return k
	return weights.keys().back()


func _update_attack(delta: float) -> void:
	match attack:
		Attack.CHARGE:
			var before := x
			_walk(facing * charge_speed * delta)
			var stuck := x == before
			if stuck or absf(x - _charge_from) >= charge_distance:
				_set_state(State.RECOVER)
				_events.append(&"charge_end")
		Attack.STOMP:
			if state_time >= STOMP_IMPACT and state_time - delta < STOMP_IMPACT:
				var front := x + facing * 55.0
				waves.append(Vector3(front, 1.0, 0.0))
				waves.append(Vector3(front, -1.0, 0.0))
				_events.append(&"stomp")
			if state_time >= attack_time[attack]:
				_set_state(State.RECOVER)
		_:
			if state_time >= attack_time[attack]:
				_set_state(State.RECOVER)


func _update_waves(delta: float) -> void:
	var alive: Array[Vector3] = []
	for w in waves:
		w.x += w.y * wave_speed * delta
		w.z += delta
		if w.x > ForestTerrain.WALK_MIN_X - 10.0 and w.x < ForestTerrain.WALK_MAX_X + 10.0:
			alive.append(w)
	waves = alive


func _walk(dx: float) -> void:
	var before := x
	x = clampf(x + dx, min_x, max_x)
	var moved := absf(x - before)
	var old_step := int(travel / 24.0)
	travel += moved
	if int(travel / 24.0) != old_step:
		_events.append(&"step")


func _set_state(s: State) -> void:
	state = s
	state_time = 0.0
