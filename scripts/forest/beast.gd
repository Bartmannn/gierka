class_name Beast
extends Node2D
## Bestia: wygląd i dźwięk dobrane do logiki (BeastBrain). Sama niczego nie liczy -
## co klatkę dostaje od sceny zdarzenia walki i ustawia klatkę, oko, obrys i dźwięki.
##
## Klatki: grafika/postacie/bestia_ruch.png (rysuje je tools/make_beast_sprites.gd),
## położenie oka w każdej klatce: BeastFrameData. Węzeł stoi w miejscu stóp bestii.

@export_group("Ruch")
## Prędkość chodu (px/s).
@export var walk_speed := 38.0
## Prędkość szarży (px/s) i najdłuższa szarża (px).
@export var charge_speed := 230.0
@export var charge_distance := 280.0
## Prędkość fali tupnięcia (px/s).
@export var wave_speed := 170.0
@export_group("Ataki")
## Ile sekund trwa zapowiedź (błysk oczu) przed szarżą, ciosem kłami i tupnięciem.
@export var charge_warning := 0.75
@export var tusk_warning := 0.45
@export var stomp_warning := 0.6
## Ile sekund bestia dyszy po szarży, ciosie kłami i tupnięciu (wtedy najłatwiej ją ciąć).
@export var charge_rest := 0.9
@export var tusk_rest := 0.55
@export var stomp_rest := 0.8
## Przerwa między atakami (od-do, s) i czas do pierwszego ataku.
@export var rest_between := Vector2(0.5, 1.1)
@export var first_attack_delay := 2.0
@export_group("Życie")
## Ile cięć wytrzymuje bestia.
@export var max_health := 16
## Jak szybko (s) bestia odpowiada atakiem, gdy ktoś ją tnie, a ona akurat nie atakuje.
@export var counter_delay := 0.25
@export_group("Dźwięki")
@export var charge_sound: AudioStream
@export var tusk_sound: AudioStream
@export var stomp_sound: AudioStream
@export var step_sounds: Array[AudioStream] = []
@export var hit_sounds: Array[AudioStream] = []

var brain: BeastBrain
var _time := 0.0
var _flinch_left := 0.0
var _flash_left := 0.0

@onready var _sprite: Sprite2D = $Sprite
@onready var _eye: EyeGlint = $Eye
@onready var _voice: AudioStreamPlayer2D = $Voice
@onready var _steps: AudioStreamPlayer2D = $Steps
@onready var _impact: AudioStreamPlayer2D = $Impact
@onready var _hit: AudioStreamPlayer2D = $Hit
@onready var _roar: AudioStreamPlayer2D = $Roar


## Przekazuje logice ustawienia z Inspektora i podłącza ją do tego węzła.
func configure(b: BeastBrain) -> void:
	brain = b
	b.walk_speed = walk_speed
	b.charge_speed = charge_speed
	b.charge_distance = charge_distance
	b.wave_speed = wave_speed
	b.telegraph_time = {BeastBrain.Attack.CHARGE: charge_warning, BeastBrain.Attack.TUSK: tusk_warning,
			BeastBrain.Attack.STOMP: stomp_warning}
	b.recover_time = {BeastBrain.Attack.CHARGE: charge_rest, BeastBrain.Attack.TUSK: tusk_rest,
			BeastBrain.Attack.STOMP: stomp_rest}
	b.rest_time = rest_between
	b.max_health = max_health
	b.counter_delay = counter_delay
	b.health = max_health
	b.x = position.x
	b.facing = -1
	b.state_time = 0.0
	b.wait_before_attack(first_attack_delay)
	_steps.stream = Friend.shuffle(step_sounds, 1.1, 2.0)
	_hit.stream = Friend.shuffle(hit_sounds, 1.1, 1.5)


## Jedna klatka obrazu. delta = 0 w czasie zatrzymania po trafieniu (obraz stoi).
func present(delta: float, events: Array[Dictionary]) -> void:
	for e in events:
		match e.type:
			&"beast_telegraph":
				_voice.stream = {BeastBrain.Attack.CHARGE: charge_sound, BeastBrain.Attack.TUSK: tusk_sound,
						BeastBrain.Attack.STOMP: stomp_sound}.get(brain.attack)
				_voice.play()
			&"beast_step":
				_steps.play()
			&"beast_stomp":
				_impact.play()
			&"beast_hit":
				_hit.play()
				_flash_left = 0.07
				_flinch_left = 0.1
			&"beast_dying":
				_roar.play()
	_time += delta
	_flash_left -= delta
	_flinch_left -= delta
	position = brain.feet()
	var frame := _pick_frame()
	_sprite.frame = frame.x * BeastFrameData.COLUMNS + frame.y
	var flipped := brain.facing < 0
	_sprite.flip_h = flipped
	var material := _sprite.material as ShaderMaterial
	material.set_shader_parameter("flip", -1.0 if flipped else 1.0)
	material.set_shader_parameter("flash", 1.0 if _flash_left > 0.0 else 0.0)
	var eye: Vector2i = BeastFrameData.EYES[frame.x][frame.y]
	_eye.position = Vector2(eye.x if not flipped else -eye.x - 1, eye.y)
	_eye.facing = brain.facing
	_eye.level = brain.eye_glint()


## Klatka (rząd, kolumna) dla bieżącego stanu logiki.
func _pick_frame() -> Vector2i:
	var t := brain.state_time
	var attack := brain.attack
	match brain.state:
		BeastBrain.State.DEAD:
			return Vector2i(BeastFrameData.ROW_HURT, 7)
		BeastBrain.State.DYING:
			return Vector2i(BeastFrameData.ROW_HURT, 2 + mini(int(t / (brain.dying_time * 0.75) * 5.0), 5))
		BeastBrain.State.TELEGRAPH:
			var progress: float = t / brain.telegraph_time[attack]
			match attack:
				BeastBrain.Attack.CHARGE:
					return Vector2i(BeastFrameData.ROW_PAW, int(t * 8.0) % BeastFrameData.PAW_FRAMES)
				BeastBrain.Attack.TUSK:
					return Vector2i(BeastFrameData.ROW_TUSK, mini(int(progress * 3.0), 2))
				_:
					return Vector2i(BeastFrameData.ROW_STOMP, mini(int(progress * 4.0), 3))
		BeastBrain.State.ATTACK:
			match attack:
				BeastBrain.Attack.CHARGE:
					var k := int(brain.travel / BeastFrameData.GALLOP_STEP_PIXELS) % BeastFrameData.GALLOP_FRAMES
					return Vector2i(BeastFrameData.ROW_GALLOP, k)
				BeastBrain.Attack.TUSK:
					var progress: float = t / brain.attack_time[attack]
					return Vector2i(BeastFrameData.ROW_TUSK, 3 + mini(int(progress * 3.0), 2))
				_:
					var k := 1 if t < 0.06 else (4 if t < 0.16 else (5 if t < 0.24 else 6))
					return Vector2i(BeastFrameData.ROW_STOMP, k)
	if _flinch_left > 0.0:
		return Vector2i(BeastFrameData.ROW_HURT, 0 if _flinch_left > 0.05 else 1)
	match brain.state:
		BeastBrain.State.RECOVER:
			if attack == BeastBrain.Attack.CHARGE and t < 0.25:
				return Vector2i(BeastFrameData.ROW_PAW, 0)  # hamowanie po szarży
			return Vector2i(BeastFrameData.ROW_IDLE, int(_time * 6.0) % BeastFrameData.IDLE_FRAMES)  # dyszy
		BeastBrain.State.WALK:
			var k := int(brain.travel / BeastFrameData.WALK_STEP_PIXELS) % BeastFrameData.WALK_FRAMES
			return Vector2i(BeastFrameData.ROW_WALK, k)
	return Vector2i(BeastFrameData.ROW_IDLE, int(_time * 3.0) % BeastFrameData.IDLE_FRAMES)
