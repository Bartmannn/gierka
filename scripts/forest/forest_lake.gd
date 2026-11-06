extends Node2D
## Scena „las nad jeziorkiem” nocą: przyjaciel chodzi po brzegu, księżyc świeci zza chmur,
## słychać las. Bez przeciwnika i bez żadnego interfejsu.
##
## Warstwy grafiki (grafika/sceny/las_jeziorko/warstwy) leżą jedna na drugiej w kolejności
## numerów; postać stoi między ziemią (8) a pierwszym planem (10). Warstwa 9 (szkic postaci
## i bestii) nie jest używana. Ruch nieba, wody, snopów światła i mgły robią shadery w `shaders/`.
##
## Opcje z wiersza poleceń (po `--`):
##   --demo-walk   postać sama biega, robi przewroty i tnie (do nagrywania klatek i testów)

## Ile sekund trwa jeden „oddech” księżyca: poświata na niebie i snopy światła zmieniają się razem.
@export var moon_breath_period := 7.0

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

var _demo_walk := false
var _demo_time := 0.0
var _demo_release: Array[String] = []


func _ready() -> void:
	InputSetup.ensure_actions()
	_demo_walk = "--demo-walk" in OS.get_cmdline_user_args()
	for node: CanvasItem in [$Sky, $Shafts]:
		(node.material as ShaderMaterial).set_shader_parameter("glow_period", moon_breath_period)


func _process(delta: float) -> void:
	if _demo_walk:
		_demo_time += delta
		_demo_step()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quit"):
		get_tree().quit()


## Pokaz: bieg w prawo z cięciem i przewrotem, cięcia w miejscu (także w górę),
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
