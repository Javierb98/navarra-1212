extends SceneTree
## Construction smoke test for every screen.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --headless \
##       --path . --script tests/test_screens.gd
##
## Screens are assembled in code, which means a typo in a layout call is a
## runtime error rather than a parse error — exactly the kind of thing that
## would otherwise be found by a person standing in front of the cabinet. This
## builds each one, lets it live a few frames, and tears it down.

const SCREENS := [
	"res://scenes/attract.tscn",
	"res://scenes/campaign.tscn",
	"res://scenes/briefing.tscn",
	"res://scenes/battle.tscn",
	"res://scenes/aftermath.tscn",
]

var _failed := 0


func _initialize() -> void:
	print("— Pruebas de pantallas —")

	# Autoloads are not compile-time identifiers for a script launched with
	# --script, so we wait for them to exist and fetch them by path. The screens
	# themselves are loaded later, once the singletons are up, and can use the
	# ordinary global names.
	await process_frame
	var game_state := root.get_node_or_null("GameState")
	if game_state == null:
		print("  FALLO no hay autoload GameState")
		quit(1)
		return

	# Both the briefing and the battle screen expect a scenario waiting for
	# them, and the aftermath expects a finished result.
	game_state.pending_scenario = Scenario.load_scenario("navas_de_tolosa_1212")
	game_state.last_result = {
		"victoria": true, "victory": true, "motivo": "END_OBJETIVO", "rondas": 6,
		"survivors": 900, "supervivientes": 900, "bajas_propias": 400,
		"bajas_enemigas": 1200, "score": 3200, "moral_final": 61.0,
		"escenario": "navas_de_tolosa_1212",
	}

	for path in SCREENS:
		await _try_screen(path)

	print("\n%s" % ("todas las pantallas se construyen" if _failed == 0
		else "%d pantallas con fallo" % _failed))
	quit(1 if _failed > 0 else 0)


func _try_screen(path: String) -> void:
	var packed: PackedScene = load(path)
	if packed == null:
		_failed += 1
		print("  FALLO no carga %s" % path)
		return

	var instance := packed.instantiate()
	if instance == null:
		_failed += 1
		print("  FALLO no instancia %s" % path)
		return

	root.add_child(instance)
	for i in 3:
		await process_frame

	var children := instance.get_child_count()
	if children == 0:
		_failed += 1
		print("  FALLO %s no construyó nada" % path)
	else:
		print("  ok   %s (%d nodos raíz)" % [path.get_file(), children])

	instance.queue_free()
	await process_frame
