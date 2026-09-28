extends Node
## Attract mode: if nobody touches the panel for a while, drift back to the
## title loop so the cabinet is never sitting on a half-finished menu.
##
## Scenes opt out with `Attract.suspend()` — the battle screen does this, since
## a player staring at the board deciding their orders is not idle.

var _idle: float = 0.0
var _suspended: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func suspend() -> void:
	_suspended = true
	_idle = 0.0


func resume() -> void:
	_suspended = false
	_idle = 0.0


func _input(_event: InputEvent) -> void:
	_idle = 0.0


func _process(delta: float) -> void:
	if _suspended or Cfg.attract_delay <= 0.0:
		return
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return
	if tree.current_scene.scene_file_path == GameState.SCENES["attract"]:
		return

	_idle += delta
	if _idle >= Cfg.attract_delay:
		_idle = 0.0
		GameState.goto("attract")
