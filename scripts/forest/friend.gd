class_name Friend
extends Node2D
## Przyjaciel bohatera: postać, którą steruje gracz. Biega, robi przewroty i tnie
## przed siebie albo w górę (jak w Hollow Knight). Zasady ruchu są w `FriendMotor`;
## ten skrypt dobiera do nich klatki, białą smugę cięcia, dźwięki i pył spod stóp.
##
## Klatki: grafika/postacie/przyjaciel_ruch.png, smuga: grafika/efekty/ciecie.png
## (rysuje je tools/make_friend_sprites.gd). Węzeł stoi w miejscu stóp:
## x to środek między stopami, y to pierwszy wiersz ziemi.

const FRAME_SIZE := Vector2i(80, 72)
const COLUMNS := 8
const ROW_IDLE := 0
const ROW_RUN := 1
const ROW_ROLL := 2
const ROW_ATTACK_SIDE := 3
const ROW_ATTACK_UP := 4
const IDLE_FRAMES := 4
const RUN_FRAMES := 8
const ROLL_FRAMES := 8
const ATTACK_FRAMES := 5
## Cykl biegu ma 48 px drogi na 8 klatek, więc stopy nie ślizgają się po ziemi.
const RUN_STEP_PIXELS := 6.0
## Klatki biegu, w których stopa dotyka ziemi (wtedy słychać krok).
const RUN_CONTACT_FRAMES: Array[int] = [0, 4]
## Gdzie (jaka część czasu cięcia) kończy się każda klatka: zamach i cios są błyskawiczne,
## powrót do postawy trochę dłuższy.
const ATTACK_FRAME_ENDS: Array[float] = [0.12, 0.24, 0.42, 0.65, 1.0]
## Smuga pojawia się zaraz po zamachu i ma 5 klatek po 0,03 s (3 narastania, 2 zanikania).
const SLASH_START := 0.03
const SLASH_FRAME_TIME := 0.03
const SLASH_FRAMES := 5

@export_group("Bieg")
## Prędkość biegu w pikselach na sekundę (scena ma 480 px szerokości).
@export var run_speed := 96.0
## Jak szybko postać się rozpędza (px/s na sekundę). Duża liczba = rusza od razu.
@export var acceleration := 1400.0
## Jak szybko staje po puszczeniu klawisza (px/s na sekundę).
@export var deceleration := 1700.0
## Tempo oddechu w bezruchu (klatki na sekundę).
@export var idle_fps := 4.0
@export_group("Przewrót")
## Ile pikseli pokonuje jeden przewrót.
@export var roll_distance := 60.0
## Ile sekund trwa przewrót.
@export var roll_time := 0.38
## Przerwa po przewrocie, zanim można zrobić następny (s).
@export var roll_cooldown := 0.18
@export_group("Cięcie")
## Ile sekund trwa poza cięcia (zamach, cios, powrót).
@export var attack_time := 0.26
## Najkrótszy odstęp między cięciami (s).
@export var attack_cooldown := 0.32
## Jak długo zapamiętane jest wciśnięcie przed końcem poprzedniej akcji (s).
@export var buffer_time := 0.12
@export_group("Dźwięki i efekty")
## Dźwięki kroków; przy każdym kroku losowany jest jeden, z lekko zmienioną wysokością.
@export var step_sounds: Array[AudioStream] = []
## Świsty ostrza; przy każdym cięciu losowany jest jeden.
@export var swing_sounds: Array[AudioStream] = []
## Węzeł z pyłem spod stóp.
@export var dust: DustPuff

var motor := FriendMotor.new()
var _idle_time := 0.0
var _run_frame := -1
var _slash_time := -1.0  # czas od początku cięcia; mniej niż 0 = smugi nie ma
var _slash_row := 0

@onready var _sprite: Sprite2D = $Sprite
@onready var _slash: Sprite2D = $Slash
@onready var _steps: AudioStreamPlayer2D = $Steps
@onready var _swing: AudioStreamPlayer2D = $Swing
@onready var _roll: AudioStreamPlayer2D = $Roll
@onready var _land: AudioStreamPlayer2D = $Land


func _ready() -> void:
	motor.run_speed = run_speed
	motor.acceleration = acceleration
	motor.deceleration = deceleration
	motor.roll_distance = roll_distance
	motor.roll_time = roll_time
	motor.roll_cooldown = roll_cooldown
	motor.attack_time = attack_time
	motor.attack_cooldown = attack_cooldown
	motor.buffer_time = buffer_time
	motor.x = position.x
	_steps.stream = _shuffle(step_sounds, 1.12, 2.5)
	_swing.stream = _shuffle(swing_sounds, 1.08, 1.5)
	_slash.visible = false
	_place()
	_show(ROW_IDLE, 0)


func _process(delta: float) -> void:
	var events := motor.update(delta,
			Input.get_axis("move_left", "move_right"),
			Input.is_action_pressed("aim_up"),
			Input.is_action_just_pressed("attack"),
			Input.is_action_just_pressed("roll"))
	for event in events:
		_on_motor_event(event)
	_animate(delta)
	_place()


func _on_motor_event(event: StringName) -> void:
	match event:
		&"swing":
			_swing.play()  # od razu, w tej samej klatce co wciśnięcie
			_slash_time = 0.0
			_slash_row = 1 if motor.state == FriendMotor.State.ATTACK_UP else 0
		&"roll_start":
			_roll.play()
			_slash_time = -1.0
			_dust(-motor.facing, 6)
		&"roll_land":
			_land.play()
			_dust(0.0, 5)
		&"run_start":
			_dust(-motor.facing, 3)
		&"turn":
			_dust(-motor.facing, 4)


func _animate(delta: float) -> void:
	match motor.state:
		FriendMotor.State.RUN:
			var frame := int(motor.run_distance / RUN_STEP_PIXELS) % RUN_FRAMES
			if frame != _run_frame and _run_frame != -1 and frame in RUN_CONTACT_FRAMES:
				_steps.play()
			_run_frame = frame
			_show(ROW_RUN, frame)
		FriendMotor.State.ROLL:
			_run_frame = -1
			_show(ROW_ROLL, mini(int(motor.action_progress() * ROLL_FRAMES), ROLL_FRAMES - 1))
		FriendMotor.State.ATTACK_SIDE, FriendMotor.State.ATTACK_UP:
			_run_frame = -1
			var progress := motor.action_progress()
			var frame := 0
			while frame < ATTACK_FRAMES - 1 and progress >= ATTACK_FRAME_ENDS[frame]:
				frame += 1
			var row := ROW_ATTACK_UP if motor.state == FriendMotor.State.ATTACK_UP else ROW_ATTACK_SIDE
			_show(row, frame)
		_:
			_run_frame = -1
			_idle_time += delta
			_show(ROW_IDLE, int(_idle_time * idle_fps) % IDLE_FRAMES)
	_animate_slash(delta)


## Biała smuga: krótka, kilka klatek, potem znika. Przesuwa się razem z postacią.
func _animate_slash(delta: float) -> void:
	if _slash_time < 0.0:
		return
	_slash_time += delta
	var k := int((_slash_time - SLASH_START) / SLASH_FRAME_TIME)
	if _slash_time < SLASH_START:
		_slash.visible = false
	elif k < SLASH_FRAMES:
		_slash.visible = true
		_slash.frame = _slash_row * SLASH_FRAMES + k
	else:
		_slash.visible = false
		_slash_time = -1.0


func _show(row: int, column: int) -> void:
	_sprite.frame = row * COLUMNS + column
	var flipped := motor.facing < 0
	if _sprite.flip_h != flipped:
		_sprite.flip_h = flipped
		_slash.flip_h = flipped
		(_sprite.material as ShaderMaterial).set_shader_parameter("flip", -1.0 if flipped else 1.0)


## Ustawia postać na całym pikselu, stopami na ziemi.
func _place() -> void:
	var px := roundf(motor.x)
	position = Vector2(px, ForestTerrain.ground_y(px))


func _dust(direction: float, count: int) -> void:
	if dust:
		dust.puff(position, direction, count)


static func _shuffle(sounds: Array[AudioStream], pitch: float, volume_db: float) -> AudioStreamRandomizer:
	var shuffle := AudioStreamRandomizer.new()
	shuffle.random_pitch = pitch
	shuffle.random_volume_offset_db = volume_db
	for sound in sounds:
		shuffle.add_stream(-1, sound)
	return shuffle
