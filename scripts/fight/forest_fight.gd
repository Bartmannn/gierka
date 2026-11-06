class_name ForestFight
extends RefCounted
## Walka w lesie, bez obrazu i dźwięku: przyjaciel kontra bestia.
##
## Każdy krok idzie w tej samej kolejności: ruch przyjaciela → ruch bestii → trafienia →
## przytomność → wynik. Obraz i dźwięk (forest_lake.gd i węzły postaci) tylko reagują na
## zwracane zdarzenia. Dzięki temu całą walkę da się sprawdzić w testach.
##
## Przytomność bohatera (0..1) zastępuje pasek zdrowia, jak w prototypie rytmu: trafienie
## przyjaciela ją obniża, cięcia w bestię i czas bez obrażeń powoli ją przywracają.
## Hitstop: po trafieniu walka staje na ułamek sekundy, żeby cios było czuć.

enum Outcome { FIGHTING, WON, FAINTED }

# --- parametry (ustawia je forest_lake.gd z wartości w Inspektorze) ---
var hit_damage := 0.25          ## o ile spada przytomność po trafieniu przyjaciela
var heal_per_hit := 0.03        ## o ile rośnie po trafieniu bestii
var regen_per_second := 0.02    ## powolny powrót przytomności...
var regen_delay := 3.0          ## ...po tylu sekundach bez obrażeń
var beast_hitstop := 0.05       ## s zatrzymania po trafieniu bestii
var friend_hitstop := 0.12      ## s zatrzymania po trafieniu przyjaciela

var friend := FriendMotor.new()
var beast := BeastBrain.new()
var consciousness := 1.0
var outcome := Outcome.FIGHTING
## Ile sekund jeszcze trwa zatrzymanie po trafieniu (w tym czasie nic się nie rusza).
var hitstop_left := 0.0

var _since_hurt := 99.0
var _landed_swing := -1
var _pending_attack := false
var _pending_roll := false


## Jeden krok walki. Zwraca listę zdarzeń: słowniki z polem "type" (i ewentualnie "at", "who").
## Typy: friend_* i beast_* (zdarzenia postaci, np. friend_swing, beast_telegraph),
## beast_hit (at: miejsce trafienia), friend_hit, won, fainted.
func step(delta: float, axis: float, up_held: bool, attack_pressed: bool, roll_pressed: bool) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	# wciśnięcia w trakcie zatrzymania nie przepadają
	_pending_attack = _pending_attack or attack_pressed
	_pending_roll = _pending_roll or roll_pressed
	if hitstop_left > 0.0:
		hitstop_left -= delta
		return events

	if outcome != Outcome.FAINTED:
		for e in friend.update(delta, axis, up_held, _pending_attack, _pending_roll):
			events.append({"type": StringName("friend_" + e)})
	_pending_attack = false
	_pending_roll = false
	for e in beast.update(delta, friend.x):
		events.append({"type": StringName("beast_" + e)})

	if outcome == Outcome.FIGHTING:
		_resolve_hits(events)
		_since_hurt += delta
		if _since_hurt > regen_delay:
			consciousness = minf(1.0, consciousness + regen_per_second * delta)
		if consciousness <= 0.0:
			outcome = Outcome.FAINTED
			events.append({"type": &"fainted"})
		elif beast.state == BeastBrain.State.DEAD:
			outcome = Outcome.WON
			events.append({"type": &"won"})
	return events


## Ciało przyjaciela na scenie.
func friend_body() -> Rect2:
	return HitboxMath.to_world(friend.body_box(), friend_feet(), friend.facing)


## Zasięg cięcia przyjaciela na scenie (Rect2(), gdy cięcie nie rani).
func friend_slash() -> Rect2:
	return HitboxMath.to_world(friend.slash_box(), friend_feet(), friend.facing)


func friend_feet() -> Vector2:
	return Vector2(friend.x, ForestTerrain.ground_y(friend.x))


func _resolve_hits(events: Array[Dictionary]) -> void:
	# cięcie trafia bestię (raz na zamach)
	var slash := friend_slash()
	var target := beast.hurtbox()
	if friend.swing_id != _landed_swing and HitboxMath.hits(slash, target):
		_landed_swing = friend.swing_id
		beast.take_hit()
		friend.on_hit_landed()
		consciousness = minf(1.0, consciousness + heal_per_hit)
		hitstop_left = beast_hitstop
		events.append({"type": &"beast_hit", "at": HitboxMath.contact_point(slash, target)})
		if not beast.is_alive():
			events.append({"type": &"beast_dying"})
	# atak bestii trafia przyjaciela (chyba że jest nietykalny)
	if friend.is_invulnerable():
		return
	var body := friend_body()
	for box in beast.attack_boxes():
		if HitboxMath.hits(box, body):
			friend.take_hit(box.get_center().x)
			consciousness = maxf(0.0, consciousness - hit_damage)
			_since_hurt = 0.0
			hitstop_left = friend_hitstop
			events.append({"type": &"friend_hit", "at": HitboxMath.contact_point(box, body)})
			return
