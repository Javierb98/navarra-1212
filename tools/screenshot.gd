extends SceneTree
## Capture stills of the battle screen, for checking the look without a person
## sitting in front of it and for illustrating the docs.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --path . \
##       --script tools/screenshot.gd -- <output-dir> [scenario_id]
##
## Must run with a real renderer — not `--headless`, which draws nothing.

const DEFAULT_SCENARIO := "navas_de_tolosa_1212"

var _out_dir := "."
var _shot := 0


func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	if argv.size() >= 1:
		_out_dir = argv[0]
	var scenario_id: String = argv[1] if argv.size() >= 2 else DEFAULT_SCENARIO

	await process_frame
	var game_state := root.get_node_or_null("GameState")
	var scenario := Scenario.load_scenario(scenario_id)
	if game_state == null or scenario == null:
		push_error("No hay GameState o no carga el escenario '%s'" % scenario_id)
		quit(1)
		return
	game_state.pending_scenario = scenario

	var screen: Control = load("res://scenes/battle.tscn").instantiate()
	root.add_child(screen)
	await _settle(40)
	_capture_now("despliegue")

	# Order everyone forward so there is something to look at, then catch the
	# round mid-flight and again once it has resolved.
	for round_index in 3:
		if screen._battle.finished:
			break
		for u in screen._battle.active_units(Battle.SIDE_PLAYER):
			screen._orders[u.id] = Orders.Order.HOSTIGAR \
				if UnitKind.is_ranged(u.kind) else Orders.Order.CARGAR
		screen._refresh()
		await _settle(3)

		# Godot will not let an async call go un-awaited, so the mid-round shot
		# is taken by a timer that fires while _commit() is still running.
		_capture_after(1.0, "ronda%d_avance" % (round_index + 1))
		_capture_after(2.1, "ronda%d_choque" % (round_index + 1))
		await screen._commit()
		await _settle(6)
		_capture_now("ronda%d_final" % (round_index + 1))

	print("Capturas guardadas en %s" % _out_dir)
	quit(0)


func _settle(frames: int) -> void:
	for i in frames:
		await process_frame


func _capture_now(label: String) -> void:
	var image := root.get_texture().get_image()
	_shot += 1
	var path := "%s/%02d_%s.png" % [_out_dir, _shot, label]
	image.save_png(path)
	print("  %s" % path)


## Fire a capture from a timer, so stills can be taken while the main routine
## is parked on an await.
func _capture_after(seconds: float, label: String) -> void:
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = seconds
	root.add_child(timer)
	timer.timeout.connect(func() -> void:
		_capture_now(label)
		timer.queue_free())
	timer.start()
