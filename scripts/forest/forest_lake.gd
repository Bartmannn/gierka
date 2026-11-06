extends Node2D
## Scena „las nad jeziorkiem” nocą: przyjaciel walczy z bestią. Bez żadnego interfejsu.
##
## Ten skrypt prowadzi walkę (ForestFight): co klatkę czyta sterowanie, robi krok logiki
## i rozdaje zdarzenia węzłom postaci (Friend, Beast) oraz efektom: iskry, pył, fala tupnięcia,
## wstrząs obrazu, przytomność bohatera (powieki, ciemnienie, głuchy świat, serce).
## Po wygranej las cichnie; po omdleniu walka zaczyna się od nowa. R = od nowa w każdej chwili.
##
## Warstwy grafiki (grafika/sceny/las_jeziorko/warstwy) leżą jedna na drugiej w kolejności
## numerów; postacie stoją między ziemią (8) a pierwszym planem (10). Warstwa 9 (szkic postaci
## i bestii) nie jest używana. Ruch nieba, wody, snopów światła i mgły robią shadery w `shaders/`.
##
## Opcje z wiersza poleceń (po `--`):
##   --demo-walk       postać sama biega, robi przewroty i tnie; bestia nie atakuje
##   --demo-fight      prosty automat gra za gracza (do nagrywania i sprawdzania walki)
##   --exit-when-done  z --demo-fight: koniec po walce, kod 0 = bestia pokonana, 1 = omdlenie
##   --show-hitboxes   od razu pokazuje ramki hitboxów (jak klawisz F1)

## Ile sekund trwa jeden „oddech” księżyca: poświata na niebie i snopy światła zmieniają się razem.
@export var moon_breath_period := 7.0
@export_group("Przytomność bohatera")
## O ile spada przytomność po trafieniu przyjaciela (1 = cała).
@export_range(0.0, 1.0) var hit_damage := 0.25
## O ile rośnie po trafieniu bestii.
@export_range(0.0, 1.0) var heal_per_hit := 0.03
## Powolny powrót przytomności na sekundę, po `regen_delay` s bez obrażeń.
@export var regen_per_second := 0.02
@export var regen_delay := 3.0
## Po ilu sekundach od omdlenia walka zaczyna się od nowa.
@export var restart_after_faint := 2.6
@export_group("Odczucie ciosów")
## Zatrzymanie walki po trafieniu bestii i po trafieniu przyjaciela (s).
@export var beast_hitstop := 0.05
@export var friend_hitstop := 0.12
## Ziarno losowania ataków bestii (0 = za każdym razem inna walka).
@export var fight_seed := 0

## Pokaz (--demo-walk), pętla co DEMO_LOOP s: kiedy trzymać kierunki i kiedy wcisnąć przyciski.
const DEMO_LOOP := 10.0
const DEMO_HOLDS := {
	"move_right": [Vector2(0.0, 1.6), Vector2(8.4, 9.0)],
	"move_left": [Vector2(4.0, 5.6)],
	"aim_up": [Vector2(2.95, 3.3), Vector2(7.45, 7.8)],
}
const DEMO_TAPS := {
	"attack": [0.5, 2.2, 2.55, 3.1, 4.3, 7.0, 7.6],
	"roll": [1.0, 4.8, 6.2],
}
const SHAKE_FRIEND_HIT := Vector2(2.0, 0.2)   # (piksele, sekundy)
const SHAKE_STOMP := Vector2(2.0, 0.25)
const SHAKE_BEAST_HIT := Vector2(1.0, 0.06)

var fight := ForestFight.new()

var _demo_walk := false
var _demo_fight := false
var _exit_when_done := false
var _demo_time := 0.0
var _demo_release: Array[String] = []
var _bot_attack_wait := 0.0
var _felt := 1.0
var _end_time := 0.0
var _shake := Vector2.ZERO  # (siła, czas)
var _world_lowpass: AudioEffectLowPassFilter
var _fight_time := 0.0
var _friend_hits := 0

@onready var _friend: Friend = $Friend
@onready var _beast: Beast = $Beast
@onready var _sparks: DustPuff = $Sparks
@onready var _dust: DustPuff = $Dust
@onready var _shockwave: ShockwaveView = $Shockwave
@onready var _camera: Camera2D = $Camera
@onready var _senses: ColorRect = $Senses/Consciousness
@onready var _heart: AudioStreamPlayer = $Heart
@onready var _ambience: ForestAmbience = $Ambience
@onready var _hitboxes: HitboxDebug = $Hitboxes


func _ready() -> void:
	InputSetup.ensure_actions()
	var args := OS.get_cmdline_user_args()
	_demo_walk = "--demo-walk" in args
	_demo_fight = "--demo-fight" in args
	_exit_when_done = "--exit-when-done" in args
	for node: CanvasItem in [$Sky, $Shafts]:
		(node.material as ShaderMaterial).set_shader_parameter("glow_period", moon_breath_period)
	var slope := ForestTerrain.slope_vector()
	for sprite: Sprite2D in [$Friend/Sprite, $Beast/Sprite]:
		(sprite.material as ShaderMaterial).set_shader_parameter("slope", slope)

	fight.beast = BeastBrain.new(fight_seed if fight_seed != 0 else randi())
	if _demo_fight:
		fight.beast.rng.seed = 12345  # pokaz zawsze z tą samą walką
	fight.hit_damage = hit_damage
	fight.heal_per_hit = heal_per_hit
	fight.regen_per_second = regen_per_second
	fight.regen_delay = regen_delay
	fight.beast_hitstop = beast_hitstop
	fight.friend_hitstop = friend_hitstop
	_friend.configure(fight.friend)
	_beast.configure(fight.beast)
	fight.beast.passive = _demo_walk
	_shockwave.brain = fight.beast
	_shockwave.dust = _dust
	_hitboxes.fight = fight
	if "--show-hitboxes" in args:
		_hitboxes.shown = true
		_hitboxes.visible = true

	_world_lowpass = AudioBuses.ensure_world_bus()
	for player in find_children("*", "AudioStreamPlayer2D") + find_children("*", "AudioStreamPlayer"):
		if player != _heart:
			player.bus = AudioBuses.WORLD
	_heart.stream = _heartbeat_loop()
	_heart.play()


func _process(delta: float) -> void:
	var input := _read_input(delta)
	var events := fight.step(delta, input.axis, input.up, input.attack, input.roll)
	var logic_delta := 0.0 if fight.hitstop_left > 0.0 else delta
	_friend.present(logic_delta, events)
	_beast.present(logic_delta, events)
	for e in events:
		if _demo_fight and e.type in [&"beast_telegraph", &"beast_attack", &"beast_hit", &"friend_hit", &"friend_roll_start"]:
			var what: String = e.type
			if e.type == &"beast_telegraph":
				what += " " + BeastBrain.Attack.keys()[fight.beast.attack]
			print("[pokaz] %5.2f s  %s" % [_fight_time, what])
		match e.type:
			&"beast_hit":
				_sparks.puff(e.at, fight.friend.facing, 7)
				_start_shake(SHAKE_BEAST_HIT)
			&"friend_hit":
				_start_shake(SHAKE_FRIEND_HIT)
				_friend_hits += 1
			&"beast_stomp":
				_start_shake(SHAKE_STOMP)
				_dust.puff(fight.beast.feet() + Vector2(fight.beast.facing * 55.0, 0.0), 0.0, 10)
			&"won":
				_ambience.fade_out(6.0)
				print("[walka] bestia pokonana po %.1f s, przyjaciel trafiony %d razy, przytomność %.2f"
						% [_fight_time, _friend_hits, fight.consciousness])
			&"fainted":
				print("[walka] omdlenie po %.1f s, bestii zostało %d cięć" % [_fight_time, fight.beast.health])
	_update_senses(delta)
	_update_shake(delta)
	_update_ending(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quit"):
		get_tree().quit()
	elif event.is_action_pressed("restart"):
		get_tree().reload_current_scene()


# ---------------------------------------------------------------- sterowanie

func _read_input(delta: float) -> Dictionary:
	if _demo_fight:
		return _bot_input(delta)
	if _demo_walk:
		_demo_time += delta
		_demo_step()
	return {
		"axis": Input.get_axis("move_left", "move_right"),
		"up": Input.is_action_pressed("aim_up"),
		"attack": Input.is_action_just_pressed("attack"),
		"roll": Input.is_action_just_pressed("roll"),
	}


## Prosty automat gracza do pokazu walki: przetacza się pod szarżą i przez fale,
## cofa się przed kłami i tupnięciem, a gdy bestia dyszy - podchodzi i tnie.
func _bot_input(delta: float) -> Dictionary:
	var out := {"axis": 0.0, "up": false, "attack": false, "roll": false}
	_bot_attack_wait -= delta
	var f := fight.friend
	var b := fight.beast
	if not b.is_alive() or fight.outcome != ForestFight.Outcome.FIGHTING:
		return out
	var dir := 1.0 if b.x > f.x else -1.0
	var body := fight.friend_body()
	# coś groźnego nadlatuje: przewrót w jego stronę (pod nim / przez nie)
	var threats := b.attack_boxes()
	for i in threats.size():
		var box := threats[i]
		var from_right := box.get_center().x > f.x
		var gap := box.position.x - body.end.x if from_right else body.position.x - box.end.x
		var coming := b.state == BeastBrain.State.ATTACK and b.attack == BeastBrain.Attack.CHARGE \
				and (b.facing < 0) == from_right
		if i >= threats.size() - b.waves.size():
			var wave: Vector3 = b.waves[i - (threats.size() - b.waves.size())]
			coming = (wave.y < 0.0) == from_right
		if coming and gap > 4.0 and gap < 28.0:
			out.axis = 1.0 if from_right else -1.0
			out.roll = true
			return out
	var head_gap := absf(b.x - f.x) - BeastBrain.HEAD_REACH
	if b.state == BeastBrain.State.TELEGRAPH:
		if head_gap < 70.0:
			out.axis = -dir  # przed zapowiedzianym atakiem odsuwa się od łba
		return out
	if b.state == BeastBrain.State.ATTACK:
		return out
	# bestia dyszy albo czeka: podejść i ciąć
	var target := b.hurtbox()
	var edge_gap := target.position.x - f.x if dir > 0.0 else f.x - target.end.x
	if edge_gap > 18.0:
		out.axis = dir
	elif _bot_attack_wait <= 0.0:
		out.axis = dir * 0.01  # zwrot w stronę bestii
		out.attack = true
		_bot_attack_wait = 0.34
	return out


## Pokaz ruchu: bieg w prawo z cięciem i przewrotem, cięcia w miejscu (także w górę),
## bieg w lewo, przewrót z miejsca, kolejne cięcia - i od nowa.
func _demo_step() -> void:
	for action in _demo_release:
		Input.action_release(action)
	_demo_release.clear()
	var t := fmod(_demo_time, DEMO_LOOP)
	var previous := t - get_process_delta_time()
	for action: String in DEMO_HOLDS:
		var held := false
		for span: Vector2 in DEMO_HOLDS[action]:
			held = held or (t >= span.x and t < span.y)
		_set_action(action, held)
	for action: String in DEMO_TAPS:
		for at: float in DEMO_TAPS[action]:
			if previous < at and t >= at:
				Input.action_press(action)
				_demo_release.append(action)


func _set_action(action: String, pressed: bool) -> void:
	if pressed and not Input.is_action_pressed(action):
		Input.action_press(action)
	elif not pressed and Input.is_action_pressed(action):
		Input.action_release(action)


# ---------------------------------------------------------------- odczucia

## Słabnąca przytomność: obraz ciemnieje, powieki opadają, świat głuchnie, serce słychać mocniej
## (tak samo jak w prototypie rytmu).
func _update_senses(delta: float) -> void:
	_felt = lerpf(_felt, fight.consciousness, 1.0 - exp(-delta * 4.0))
	var c := _felt
	var droop := (1.0 - c) * (1.0 - c) * 0.25 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 600.0))
	var openness := 0.55 + 0.45 * c - droop
	if fight.outcome == ForestFight.Outcome.FAINTED:
		openness = lerpf(openness, 0.0, minf(_end_time / 1.2, 1.0))
	var material := _senses.material as ShaderMaterial
	material.set_shader_parameter("openness", openness if c < 0.995 else 1.0)
	material.set_shader_parameter("darkness", (1.0 - c) * 0.45)
	_world_lowpass.cutoff_hz = AudioBuses.muffle_cutoff(c)
	_heart.volume_db = lerpf(-4.0, -42.0, c)
	_heart.pitch_scale = 1.0 + (1.0 - c) * 0.35


## Jedno uderzenie serca (podwójne „lub-dub”) z syntezatora prototypu, zapętlone.
func _heartbeat_loop() -> AudioStreamWAV:
	var beat := Synth.render_note(MidiNote.new(0.0, 0.2, 36, 110), Synth.Instrument.HEART)
	var buffer := PackedFloat32Array()
	buffer.resize(int(0.86 * Synth.SAMPLE_RATE))
	var second := int(0.28 * Synth.SAMPLE_RATE)
	for i in mini(beat.size(), buffer.size()):
		buffer[i] += beat[i]
		if second + i < buffer.size():
			buffer[second + i] += beat[i] * 0.6
	var stream := Synth.to_stream(buffer)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = buffer.size()
	return stream


func _start_shake(shake: Vector2) -> void:
	if shake.x >= _shake.x or _shake.y <= 0.0:
		_shake = shake


## Wstrząs obrazu o całe piksele.
func _update_shake(delta: float) -> void:
	_shake.y -= delta
	if _shake.y > 0.0:
		var a := int(_shake.x)
		_camera.offset = Vector2(randi_range(-a, a), randi_range(-a, a))
	else:
		_camera.offset = Vector2.ZERO


func _update_ending(delta: float) -> void:
	if fight.outcome == ForestFight.Outcome.FIGHTING:
		_fight_time += delta
		if _demo_fight and _exit_when_done and _fight_time > 120.0:
			get_tree().quit(2)  # walka się nie skończyła
		return
	_end_time += delta
	if fight.outcome == ForestFight.Outcome.FAINTED and _end_time > restart_after_faint:
		if _exit_when_done:
			get_tree().quit(1)
		else:
			get_tree().reload_current_scene()
	elif fight.outcome == ForestFight.Outcome.WON and _exit_when_done and _end_time > 2.0:
		get_tree().quit(0)
