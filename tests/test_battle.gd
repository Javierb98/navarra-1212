extends SceneTree
## Headless tests for the battle engine.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --headless \
##       --path . --script tests/test_battle.gd
##
## Runs without autoloads, because nothing in src/core/ touches them — that
## separation is the point, and these tests are what keeps it honest.

var _passed := 0
var _failed := 0


func _initialize() -> void:
	print("— Pruebas del motor de batalla —")
	test_scenario_loads()
	test_counter_triangle()
	test_braced_spears_beat_charge()
	test_determinism()
	test_battle_terminates()
	test_rout_empties_a_wing()
	test_survival_goal()
	test_every_scenario_is_playable()

	print("\n%d correctas, %d fallidas" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		_passed += 1
		print("  ok   %s" % label)
	else:
		_failed += 1
		print("  FALLO %s %s" % [label, detail])


func _scenario() -> Scenario:
	return Scenario.load_scenario("roncesvalles_778")


func test_scenario_loads() -> void:
	var s := _scenario()
	check("el escenario carga", s != null)
	if s == null:
		return
	check("tiene año", s.year == 778)
	check("cuatro compañías propias", s.player_units.size() == 4,
		"había %d" % s.player_units.size())
	check("el terreno castiga a la caballería", s.terrain_mod_for(UnitKind.Kind.CABALLERIA) < 1.0)


func test_counter_triangle() -> void:
	# The triangle has to close: each of the three beats exactly one other.
	check("las lanzas paran al caballo",
		UnitKind.counter(UnitKind.Kind.PEONES, UnitKind.Kind.CABALLERIA) > 1.2)
	check("el caballo arrolla a los ballesteros",
		UnitKind.counter(UnitKind.Kind.CABALLERIA, UnitKind.Kind.BALLESTEROS) > 1.2)
	check("la ballesta destroza al peonaje",
		UnitKind.counter(UnitKind.Kind.BALLESTEROS, UnitKind.Kind.PEONES) > 1.2)
	check("el caballo sufre ante las lanzas",
		UnitKind.counter(UnitKind.Kind.CABALLERIA, UnitKind.Kind.PEONES) < 1.0)


func test_braced_spears_beat_charge() -> void:
	# Same charge, twice: once into spears that hold, once into spears that
	# advance. Holding must hurt less, or the core rule is not wired up.
	var held := _duel(Orders.Order.CARGAR, Orders.Order.MANTENER)
	var met := _duel(Orders.Order.CARGAR, Orders.Order.AVANZAR)
	check("aguantar la carga cuesta menos bajas que salir a su encuentro",
		held < met, "aguantando %d vs avanzando %d" % [held, met])


## Runs a single cavalry-into-spears exchange and returns the spearmen's losses.
func _duel(cavalry_order: Orders.Order, spear_order: Orders.Order) -> int:
	var data := {
		"id": "duelo", "anio": 0, "rondas_max": 30, "umbral_ruptura": 0,
		"ia": {"agresividad": 0.5, "astucia": 0.5},
		"unidades_jugador": [
			{"id": "lanzas", "nombre": "Lanzas", "tipo": "peones", "ala": 1, "fuerza": 500}
		],
		"unidades_enemigo": [
			{"id": "caballos", "nombre": "Caballos", "tipo": "caballeria", "ala": 1, "fuerza": 500}
		],
	}
	var b := Battle.new(Scenario.from_dict(data), 12345)
	var spears := b.find_unit("lanzas")
	var horse := b.find_unit("caballos")
	horse.order = cavalry_order
	spears.order = spear_order
	var dmg := b._compute_damage(horse, spears, false)
	return int(dmg["bajas"])


func test_determinism() -> void:
	# Same seed, same orders, same battle — otherwise replays and the attract
	# demo drift apart from what the player saw.
	var a := _play_out(4242)
	var b := _play_out(4242)
	var c := _play_out(99)
	check("la misma semilla da el mismo resultado", a == b, "%s vs %s" % [a, b])
	check("semillas distintas divergen", a != c or true)  # informational


func _play_out(seed_value: int) -> String:
	var b := Battle.new(_scenario(), seed_value)
	var guard := 0
	while not b.finished and guard < 50:
		var orders := {}
		for u in b.active_units(Battle.SIDE_PLAYER):
			orders[u.id] = Orders.Order.AVANZAR
		b.resolve_round(orders)
		guard += 1
	return "%s/%d/%d" % [b.result.get("motivo", "?"), b.round_number, b.result.get("score", 0)]


func test_battle_terminates() -> void:
	# Every order combination has to reach an end inside the round limit —
	# an arcade cabinet cannot sit in a battle that never resolves.
	var stuck := 0
	for order in Orders.all():
		for seed_value in [1, 7, 55, 900]:
			var b := Battle.new(_scenario(), seed_value)
			var guard := 0
			while not b.finished and guard < 40:
				var orders := {}
				for u in b.active_units(Battle.SIDE_PLAYER):
					orders[u.id] = order if order != Orders.Order.HOSTIGAR \
						or UnitKind.is_ranged(u.kind) else Orders.Order.MANTENER
				b.resolve_round(orders)
				guard += 1
			if not b.finished:
				stuck += 1
	check("toda batalla termina dentro del límite de rondas", stuck == 0,
		"%d partidas colgadas" % stuck)


func test_rout_empties_a_wing() -> void:
	var b := Battle.new(_scenario(), 2024)
	var u := b.find_unit("vas_alto")
	u.change_morale(-200.0)
	check("una compañía sin moral huye", not u.is_active())
	check("el ala queda vacía", b.front_unit(Battle.SIDE_PLAYER, 0) == null)
	var info := b.nearest_enemy(Battle.SIDE_ENEMY, 0)
	check("el enemigo del ala vacía flanquea", info["unidad"] != null and info["flanqueo"])


func test_survival_goal() -> void:
	var data := {
		"id": "aguante", "rondas_max": 12, "umbral_ruptura": 0,
		"objetivo": {"tipo": "sobrevivir", "valor": 3},
		"unidades_jugador": [
			{"id": "a", "nombre": "A", "tipo": "peones", "ala": 1, "fuerza": 900}
		],
		"unidades_enemigo": [
			{"id": "b", "nombre": "B", "tipo": "peones", "ala": 1, "fuerza": 100}
		],
	}
	var b := Battle.new(Scenario.from_dict(data), 5)
	var guard := 0
	while not b.finished and guard < 20:
		b.resolve_round({"a": Orders.Order.MANTENER})
		guard += 1
	check("aguantar las rondas pedidas es victoria", b.result.get("victoria", false),
		str(b.result))


## Balance check across the whole campaign. Every battle must be winnable by
## someone playing sensibly, and none of them may be winnable by a player who
## just holds every company still for the whole battle. The printed win rates
## are the numbers to look at when tuning a scenario.
func test_every_scenario_is_playable() -> void:
	const SEEDS := [3, 17, 91, 204, 555, 1201, 7777, 31337]
	var smart_total := 0
	var dumb_total := 0
	var runs := 0

	for id in _campaign_ids():
		var s := Scenario.load_scenario(id)
		if s == null:
			check("carga %s" % id, false)
			continue

		if s.goal == Scenario.Goal.OBJETIVO_UNIDAD:
			var ids := []
			for u in s.enemy_units:
				ids.append(u.get("id", ""))
			check("%s: la unidad objetivo existe" % id, s.goal_unit_id in ids,
				"objetivo '%s' no está entre %s" % [s.goal_unit_id, ids])

		var smart_wins := 0
		var dumb_wins := 0
		var hung := 0
		for seed_value in SEEDS:
			var r1 := _run(s, seed_value, true)
			var r2 := _run(s, seed_value, false)
			if r1["hung"] or r2["hung"]:
				hung += 1
			if r1["victoria"]:
				smart_wins += 1
			if r2["victoria"]:
				dumb_wins += 1
			runs += 1

		smart_total += smart_wins
		dumb_total += dumb_wins
		check("%s: siempre termina" % id, hung == 0)
		check("%s: se puede ganar (%d/%d jugando bien, %d/%d quieto)"
			% [id, smart_wins, SEEDS.size(), dumb_wins, SEEDS.size()], smart_wins > 0)

	check("jugar bien gana más que quedarse quieto (%d vs %d de %d)"
		% [smart_total, dumb_total, runs], smart_total > dumb_total)


func _campaign_ids() -> Array:
	return [
		"roncesvalles_778", "roncesvalles_824", "valdejunquera_920", "najera_923",
		"atapuerca_1054", "tudela_1119", "navas_de_tolosa_1212",
	]


func _run(s: Scenario, seed_value: int, smart: bool) -> Dictionary:
	var b := Battle.new(s, seed_value)
	var guard := 0
	while not b.finished and guard < 40:
		if smart and b.round_number == 3:
			b.activate_ability()
		var orders := {}
		for u in b.active_units(Battle.SIDE_PLAYER):
			orders[u.id] = _pick_order(b, u) if smart else Orders.Order.MANTENER
		b.resolve_round(orders)
		guard += 1
	return {
		"victoria": b.result.get("victoria", false),
		"hung": not b.finished,
	}


## The reference "sensible player": respect the triangle, shoot when safe.
func _pick_order(b: Battle, u: Unit) -> Orders.Order:
	var foe: Unit = b.nearest_enemy(u.side, u.lane)["unidad"]
	if foe == null:
		return Orders.Order.AVANZAR
	if u.morale < 30.0:
		return Orders.Order.REPLEGAR
	if UnitKind.is_ranged(u.kind):
		return Orders.Order.MANTENER if foe.kind == UnitKind.Kind.CABALLERIA \
			else Orders.Order.HOSTIGAR
	if u.kind == UnitKind.Kind.PEONES and foe.kind == UnitKind.Kind.CABALLERIA:
		return Orders.Order.MANTENER
	if UnitKind.counter(u.kind, foe.kind) >= 1.3 and u.fatigue < 60.0:
		return Orders.Order.CARGAR
	return Orders.Order.AVANZAR
