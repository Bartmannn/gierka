class_name InputSetup
extends RefCounted
## Akcje sterowania. Trzymamy je w kodzie, żeby łatwo było je czytać i zmieniać.
## Klawisze są "fizyczne" - działają tak samo przy każdym układzie klawiatury.

const ACTIONS := {
	"strike": {  # cios / odpowiedź na pytanie bossa
		"keys": [KEY_SPACE, KEY_J, KEY_ENTER],
		"pad": [JOY_BUTTON_A, JOY_BUTTON_X],
		"mouse": [MOUSE_BUTTON_LEFT],
	},
	"restart": {"keys": [KEY_R], "pad": [JOY_BUTTON_START], "mouse": []},
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
		for button: MouseButton in ACTIONS[action]["mouse"]:
			var event := InputEventMouseButton.new()
			event.button_index = button
			InputMap.action_add_event(action, event)
