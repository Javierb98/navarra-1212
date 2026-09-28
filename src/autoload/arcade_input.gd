extends Node
## Builds the InputMap in code instead of storing it in project.godot.
##
## Two reasons. First, the cabinet's control panel is not built yet, and
## hand-editing serialised InputEvent objects inside project.godot is miserable.
## Second, most USB arcade encoders (Zero Delay, IPAC and friends) show up as
## *either* a gamepad or a keyboard sending MAME's default keys — so every
## action is bound to all three at once and the panel works whichever way you
## wire it.
##
## Panel layout assumed (one player, six buttons + start + coin):
##   B1 confirm   B2 cancel    B3 commit round
##   B4 ability   B5 prev unit B6 next unit

## action -> { keys: [Key], mame: [Key], pad: [JoyButton] }
const DEFAULTS := {
	"nav_up":     {"keys": [KEY_W], "mame": [KEY_UP],    "pad": [JOY_BUTTON_DPAD_UP]},
	"nav_down":   {"keys": [KEY_S], "mame": [KEY_DOWN],  "pad": [JOY_BUTTON_DPAD_DOWN]},
	"nav_left":   {"keys": [KEY_A], "mame": [KEY_LEFT],  "pad": [JOY_BUTTON_DPAD_LEFT]},
	"nav_right":  {"keys": [KEY_D], "mame": [KEY_RIGHT], "pad": [JOY_BUTTON_DPAD_RIGHT]},
	"confirm":    {"keys": [KEY_ENTER, KEY_Z], "mame": [KEY_CTRL],  "pad": [JOY_BUTTON_A]},
	"cancel":     {"keys": [KEY_ESCAPE, KEY_X], "mame": [KEY_ALT],  "pad": [JOY_BUTTON_B]},
	"commit":     {"keys": [KEY_SPACE], "mame": [KEY_SPACE], "pad": [JOY_BUTTON_X]},
	"ability":    {"keys": [KEY_E], "mame": [KEY_SHIFT], "pad": [JOY_BUTTON_Y]},
	"prev_unit":  {"keys": [KEY_Q], "mame": [KEY_Z], "pad": [JOY_BUTTON_LEFT_SHOULDER]},
	"next_unit":  {"keys": [KEY_TAB], "mame": [KEY_X], "pad": [JOY_BUTTON_RIGHT_SHOULDER]},
	"start":      {"keys": [KEY_1], "mame": [KEY_1], "pad": [JOY_BUTTON_START]},
	"coin":       {"keys": [KEY_5], "mame": [KEY_5], "pad": [JOY_BUTTON_BACK]},
}

## Analog sticks double as the joystick, in case the panel uses one.
const STICK_AXES := {
	"nav_left":  [JOY_AXIS_LEFT_X, -1.0],
	"nav_right": [JOY_AXIS_LEFT_X, 1.0],
	"nav_up":    [JOY_AXIS_LEFT_Y, -1.0],
	"nav_down":  [JOY_AXIS_LEFT_Y, 1.0],
}

func _ready() -> void:
	rebuild()


func rebuild() -> void:
	for action in DEFAULTS.keys():
		if InputMap.has_action(action):
			InputMap.erase_action(action)
		InputMap.add_action(action, 0.35)

		if Cfg.input_overrides.has(action):
			for ev in _deserialise(Cfg.input_overrides[action]):
				InputMap.action_add_event(action, ev)
			continue

		var binding: Dictionary = DEFAULTS[action]
		for k in (binding["keys"] as Array) + (binding["mame"] as Array):
			var key := InputEventKey.new()
			key.physical_keycode = k
			InputMap.action_add_event(action, key)
		for b in binding["pad"] as Array:
			var btn := InputEventJoypadButton.new()
			btn.button_index = b
			InputMap.action_add_event(action, btn)
		if STICK_AXES.has(action):
			var spec: Array = STICK_AXES[action]
			var axis := InputEventJoypadMotion.new()
			axis.axis = spec[0]
			axis.axis_value = spec[1]
			InputMap.action_add_event(action, axis)


## Rebind one action to a single captured event, and persist it.
func rebind(action: String, event: InputEvent) -> void:
	Cfg.input_overrides[action] = _serialise([event])
	Cfg.save_cfg()
	rebuild()


func reset_bindings() -> void:
	Cfg.input_overrides.clear()
	Cfg.save_cfg()
	rebuild()


func _serialise(events: Array) -> Array:
	var out: Array = []
	for ev in events:
		if ev is InputEventKey:
			out.append({"t": "key", "c": ev.physical_keycode})
		elif ev is InputEventJoypadButton:
			out.append({"t": "pad", "c": ev.button_index})
		elif ev is InputEventJoypadMotion:
			out.append({"t": "axis", "c": ev.axis, "v": ev.axis_value})
	return out


func _deserialise(data: Array) -> Array:
	var out: Array = []
	for d in data:
		match d.get("t", ""):
			"key":
				var k := InputEventKey.new()
				k.physical_keycode = d["c"]
				out.append(k)
			"pad":
				var b := InputEventJoypadButton.new()
				b.button_index = d["c"]
				out.append(b)
			"axis":
				var a := InputEventJoypadMotion.new()
				a.axis = d["c"]
				a.axis_value = d["v"]
				out.append(a)
	return out
