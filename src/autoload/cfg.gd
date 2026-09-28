extends Node
## Persisted cabinet settings.
##
## Everything here survives a power cut, because an arcade machine gets
## switched off at the wall rather than quit politely. Writes are immediate.

const PATH := "user://cabinet.cfg"

var locale: String = "es"
var fullscreen: bool = false
var master_volume: float = 0.8
var attract_delay: float = 45.0  ## Seconds idle before the attract loop takes over.
var show_historical_notes: bool = true
var input_overrides: Dictionary = {}  ## action name -> array of serialised events

func _ready() -> void:
	load_cfg()
	# The cabinet always boots fullscreen; on a dev machine we stay windowed
	# unless the flag is passed explicitly.
	if fullscreen or "--fullscreen" in OS.get_cmdline_args():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func load_cfg() -> void:
	var f := ConfigFile.new()
	if f.load(PATH) != OK:
		return
	locale = f.get_value("cabinet", "locale", locale)
	fullscreen = f.get_value("cabinet", "fullscreen", fullscreen)
	master_volume = f.get_value("cabinet", "master_volume", master_volume)
	attract_delay = f.get_value("cabinet", "attract_delay", attract_delay)
	show_historical_notes = f.get_value("cabinet", "show_historical_notes", show_historical_notes)
	input_overrides = f.get_value("input", "overrides", {})


func save_cfg() -> void:
	var f := ConfigFile.new()
	f.set_value("cabinet", "locale", locale)
	f.set_value("cabinet", "fullscreen", fullscreen)
	f.set_value("cabinet", "master_volume", master_volume)
	f.set_value("cabinet", "attract_delay", attract_delay)
	f.set_value("cabinet", "show_historical_notes", show_historical_notes)
	f.set_value("input", "overrides", input_overrides)
	f.save(PATH)
