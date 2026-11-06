class_name InputSetup
extends RefCounted
## Akcje sterowania. Trzymamy je w kodzie, żeby łatwo było je czytać i zmieniać.
## Klawisze są "fizyczne" - działają tak samo przy każdym układzie klawiatury.

const ACTIONS := {
	"move_left": {  # ruch w lewo; "axes": gałka pada (oś, kierunek)
		"keys": [KEY_A, KEY_LEFT],
		"pad": [JOY_BUTTON_DPAD_LEFT],
		"axes": [[JOY_AXIS_LEFT_X, -1.0]],
		"mouse": [],
	},
	"move_right": {
		"keys": [KEY_D, KEY_RIGHT],
		"pad": [JOY_BUTTON_DPAD_RIGHT],
		"axes": [[JOY_AXIS_LEFT_X, 1.0]],
		"mouse": [],
	},
	"aim_up": {  # trzymane razem z atakiem: cięcie w górę
		"keys": [KEY_W, KEY_UP],
		"pad": [JOY_BUTTON_DPAD_UP],
		"axes": [[JOY_AXIS_LEFT_Y, -1.0]],
		"mouse": [],
	},
	"attack": {  # cięcie w scenie lasu
		"keys": [KEY_J],
		"pad": [JOY_BUTTON_X],
		"mouse": [MOUSE_BUTTON_LEFT],
	},
	"roll": {  # przewrót (unik)
		"keys": [KEY_K, KEY_SHIFT],
		"pad": [JOY_BUTTON_B, JOY_BUTTON_RIGHT_SHOULDER],
		"mouse": [MOUSE_BUTTON_RIGHT],
	},
	"strike": {  # cios / odpowiedź na pytanie bossa
		"keys": [KEY_SPACE, KEY_J, KEY_ENTER],
		"pad": [JOY_BUTTON_A, JOY_BUTTON_X],
		"mouse": [MOUSE_BUTTON_LEFT],
	},
	"restart": {"keys": [KEY_R], "pad": [JOY_BUTTON_START], "mouse": []},
	"debug_hitboxes": {"keys": [KEY_F1], "pad": [], "mouse": []},  # podgląd hitboxów (tylko wersja robocza)
	"quit": {"keys": [KEY_ESCAPE], "pad": [JOY_BUTTON_BACK], "mouse": []},
}


static func ensure_actions() -> void:
	for action: String in ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key: Key in ACTIONS[action]["keys"]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
		for button: JoyButton in ACTIONS[action]["pad"]:
			var event := InputEventJoypadButton.new()
			event.button_index = button
			InputMap.action_add_event(action, event)
		for axis: Array in ACTIONS[action].get("axes", []):
			var event := InputEventJoypadMotion.new()
			event.axis = axis[0]
			event.axis_value = axis[1]
			InputMap.action_add_event(action, event)
		for button: MouseButton in ACTIONS[action]["mouse"]:
			var event := InputEventMouseButton.new()
			event.button_index = button
			InputMap.action_add_event(action, event)
