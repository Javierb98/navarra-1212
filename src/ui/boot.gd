extends Node
## First scene. Exists so the autoloads have a frame to settle before anything
## draws, and so the cabinet has one obvious place to put start-up checks.

func _ready() -> void:
	var missing := _missing_battles()
	if not missing.is_empty():
		push_error("Faltan escenarios: %s" % ", ".join(missing))
	await get_tree().process_frame
	GameState.goto("attract")


## A cabinet that boots with a broken campaign should say so in the log rather
## than fail silently three menus later.
func _missing_battles() -> Array:
	var missing: Array = []
	for id in GameState.CAMPAIGN:
		if not FileAccess.file_exists(Scenario.path_for(id)):
			missing.append(id)
	return missing
