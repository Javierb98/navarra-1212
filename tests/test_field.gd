extends SceneTree
## Integration test for the battlefield animation.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --headless \
##       --path . --script tests/test_field.gd
##
## Plays a real battle through the real field node, in real time, and asserts
## the things the player is supposed to see: companies move when ordered
## forward, casualties remove figures and leave bodies, and broken companies
## leave the field. Construction tests cannot catch any of that.
##
## Takes about half a minute — it waits out the actual animations.

const MAX_ROUNDS := 6

var _passed := 0
var _failed := 0


func _initialize() -> void:
	print("— Prueba del campo de batalla —")
	await process_frame

	var scenario := Scenario.load_scenario("roncesvalles_778")
	if scenario == null:
		print("  FALLO no carga el escenario")
		quit(1)
		return

	var battle := Battle.new(scenario, 4242)
	var host := Node2D.new()
	root.add_child(host)

	var field := Battlefield.new()
	host.add_child(field)
	field.setup(battle, scenario)
	await process_frame

	check("hay un bloque por compañía", field.block_for("vas_alto") != null
		and field.block_for("fra_escolta") != null)

	var tracked := field.block_for("vas_alto")
	var start_x: float = tracked.position.x
	var start_figures := tracked.figures_standing()
	check("un bloque empieza con figuras en pie", start_figures > 0,
		"tenía %d" % start_figures)

	var moved := false
	var any_losses := false
	var any_bodies := false
	var any_rout := false

	for round_index in MAX_ROUNDS:
		if battle.finished:
			break
		var orders := {}
		for u in battle.active_units(Battle.SIDE_PLAYER):
			orders[u.id] = Orders.Order.CARGAR if u.kind != UnitKind.Kind.BALLESTEROS \
				else Orders.Order.HOSTIGAR
		var events := battle.resolve_round(orders)
		await field.play_round(events)

		if absf(tracked.position.x - start_x) > 20.0:
			moved = true
		for u in battle.units:
			var block: CompanyBlock = field.block_for(u.id)
			if block == null:
				continue
			if block.figures_standing() < Figures.figure_count(u.initial_strength):
				any_losses = true
			if block.fallen_count() > 0:
				any_bodies = true
			if block.is_routing():
				any_rout = true

		print("  ronda %d: %s" % [round_index + 1,
			"terminada" if battle.finished else "en curso"])

	check("las compañías avanzan cuando se les ordena cargar", moved,
		"x pasó de %.0f a %.0f" % [start_x, tracked.position.x])
	check("las bajas retiran figuras del bloque", any_losses)
	check("los caídos se quedan en el campo", any_bodies)
	check("alguna compañía se rompe y huye", any_rout)

	print("\n%d correctas, %d fallidas" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		_passed += 1
		print("  ok   %s" % label)
	else:
		_failed += 1
		print("  FALLO %s %s" % [label, detail])
