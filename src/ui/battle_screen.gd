extends Control
## The battle screen.
##
## The battlefield is the game — two hosts drawn as formations of men, facing
## each other across three wings, that march, clash and break where you can
## watch it. The interface is deliberately pushed to the edges: a thin header,
## an order strip along the bottom, and a running chronicle in the corner.
##
## The loop is: walk your companies with the stick, set each one's order, commit
## the whole line at once, then watch the round play out. Nothing resolves until
## you commit, so a round is one decision about the whole line rather than five
## small ones — and because both sides commit blind, you are guessing at the
## other captain rather than reacting to him.

const FIELD_TOP := 74.0
const TICKER_LINES := 4

var _battle: Battle
var _scenario: Scenario
var _orders: Dictionary = {}
var _roster: Array[Unit] = []
var _selected := 0
var _resolving := false

var _field: Battlefield
var _orders_box: HBoxContainer
var _ticker_box: VBoxContainer
var _header_label: Label
var _ability_label: Label
var _player_bar: ProgressBar
var _enemy_bar: ProgressBar
var _commit_label: Label


func _ready() -> void:
	ChronicleUI.page(self)
	# A player staring at the field deciding their orders is not idle.
	Attract.suspend()

	_scenario = GameState.pending_scenario
	if _scenario == null:
		GameState.goto("campaign")
		return

	_battle = Battle.new(_scenario)
	_build_field()
	_build_chrome()
	_prepare_round()


func _exit_tree() -> void:
	Attract.resume()


# ------------------------------------------------------------------ layout ---

func _build_field() -> void:
	_field = Battlefield.new()
	_field.name = "Campo"
	_field.position = Vector2(0, FIELD_TOP)
	add_child(_field)
	_field.setup(_battle, _scenario)


func _build_chrome() -> void:
	_build_header()
	_build_footer()


func _build_header() -> void:
	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 34
	top.offset_right = -34
	top.offset_top = 12
	top.add_theme_constant_override("separation", 3)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)

	var row := ChronicleUI.hbox(20)
	top.add_child(row)

	var left := ChronicleUI.vbox(0)
	row.add_child(left)
	left.add_child(ChronicleUI.label("%s · %d" % [_scenario.title, _scenario.year], 21,
		Palette.TINTA))
	_header_label = ChronicleUI.label("", 13, Palette.TINTA_SUAVE)
	left.add_child(_header_label)

	var objective := ChronicleUI.label(tr(_scenario.goal_key()), 14, Palette.RUBRICA,
		HORIZONTAL_ALIGNMENT_CENTER)
	objective.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(objective)

	_ability_label = ChronicleUI.label("", 14, Palette.ORO, HORIZONTAL_ALIGNMENT_RIGHT)
	_ability_label.custom_minimum_size = Vector2(300, 0)
	row.add_child(_ability_label)

	# Army nerve, one bar per side, reading outward from the middle.
	var bars := ChronicleUI.hbox(16)
	top.add_child(bars)
	var mine := ChronicleUI.vbox(1)
	bars.add_child(mine)
	mine.add_child(ChronicleUI.label(_scenario.player_faction.get("nombre", ""), 12,
		Palette.LAPIS))
	_player_bar = ChronicleUI.bar(100.0, 100.0, Palette.LAPIS, 500)
	mine.add_child(_player_bar)

	var theirs := ChronicleUI.vbox(1)
	bars.add_child(theirs)
	theirs.add_child(ChronicleUI.label(_scenario.enemy_faction.get("nombre", ""), 12,
		Palette.RUBRICA, HORIZONTAL_ALIGNMENT_RIGHT))
	_enemy_bar = ChronicleUI.bar(100.0, 100.0, Palette.RUBRICA, 500)
	theirs.add_child(_enemy_bar)


func _build_footer() -> void:
	var bottom := VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 34
	bottom.offset_right = -34
	bottom.offset_top = -186
	bottom.offset_bottom = -14
	bottom.add_theme_constant_override("separation", 6)
	add_child(bottom)

	# Chronicle ticker, low and out of the way.
	_ticker_box = ChronicleUI.vbox(1)
	_ticker_box.custom_minimum_size = Vector2(0, 62)
	bottom.add_child(_ticker_box)

	bottom.add_child(ChronicleUI.rule(Color(Palette.ORO, 0.55)))

	_orders_box = ChronicleUI.hbox(8)
	bottom.add_child(_orders_box)

	var hints := ChronicleUI.hbox(24)
	bottom.add_child(hints)
	_commit_label = ChronicleUI.label(tr("HINT_COMMIT"), 14, Palette.RUBRICA)
	hints.add_child(_commit_label)
	hints.add_child(ChronicleUI.label(tr("HINT_MOVE"), 13,
		Color(Palette.TINTA_SUAVE, 0.85)))
	hints.add_child(ChronicleUI.label(tr("HINT_ABILITY"), 13,
		Color(Palette.TINTA_SUAVE, 0.85)))
	hints.add_child(ChronicleUI.label(tr("HINT_BACK"), 13,
		Color(Palette.TINTA_SUAVE, 0.85)))


# ------------------------------------------------------------------- round ---

## Rebuild the roster of companies that can still be given orders, keeping
## whatever the player chose last round where it is still legal.
func _prepare_round() -> void:
	_roster = _battle.active_units(Battle.SIDE_PLAYER)
	var carried := {}
	for u in _roster:
		var previous: Orders.Order = _orders.get(u.id, Orders.Order.MANTENER)
		carried[u.id] = previous if previous in Orders.available_for(u.kind) \
			else Orders.Order.MANTENER
	_orders = carried
	_selected = clampi(_selected, 0, maxi(0, _roster.size() - 1))
	_refresh()


func _refresh() -> void:
	_header_label.text = Loc.f("BATTLE_ROUND", [_battle.round_number, _scenario.max_rounds])
	_player_bar.value = _battle.army_morale(Battle.SIDE_PLAYER)
	_enemy_bar.value = _battle.army_morale(Battle.SIDE_ENEMY)

	if _battle.ability_used:
		_ability_label.text = tr("BATTLE_ABILITY_SPENT")
		_ability_label.add_theme_color_override("font_color", Color(Palette.TINTA_SUAVE, 0.6))
	else:
		_ability_label.text = Loc.f("BATTLE_ABILITY_READY",
			[_scenario.commander.get("habilidad", "")])

	if not _roster.is_empty() and _field != null:
		_field.highlight(_roster[_selected].id)
		# Show the posture on the field as the order is chosen, so the player
		# sees the company brace or level its spears before committing.
		for u in _roster:
			var block := _field.block_for(u.id)
			if block != null:
				block.set_posture(_orders.get(u.id, Orders.Order.MANTENER))

	_rebuild_orders()


func _rebuild_orders() -> void:
	for c in _orders_box.get_children():
		c.queue_free()
	if _roster.is_empty():
		return

	var unit := _roster[_selected]
	var current: Orders.Order = _orders.get(unit.id, Orders.Order.MANTENER)

	var who := ChronicleUI.vbox(0)
	who.custom_minimum_size = Vector2(236, 0)
	_orders_box.add_child(who)
	who.add_child(ChronicleUI.label(unit.name_text, 16, Palette.LAPIS))
	who.add_child(ChronicleUI.label("%s · %d %s" % [tr(UnitKind.name_key(unit.kind)),
		unit.strength, tr("BATTLE_STRENGTH").to_lower()], 12, Palette.TINTA_SUAVE))
	who.add_child(ChronicleUI.label("%s %d · %s %d" % [tr("BATTLE_MORALE"),
		int(unit.morale), tr("BATTLE_FATIGUE"), int(unit.fatigue)], 12,
		Palette.morale_color(unit.morale)))

	for o in Orders.available_for(unit.kind):
		var chosen: bool = o == current
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", Palette.panel_style(
			Color(Palette.HUESO, 0.92 if chosen else 0.32),
			Palette.RUBRICA if chosen else Color(Palette.ORO, 0.35),
			3 if chosen else 1))
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_orders_box.add_child(chip)
		var cv := ChronicleUI.vbox(1)
		chip.add_child(cv)
		cv.add_child(ChronicleUI.label(tr(Orders.name_key(o)), 15,
			Palette.TINTA if chosen else Palette.TINTA_SUAVE))
		if chosen:
			cv.add_child(ChronicleUI.body(tr(Orders.desc_key(o)), 11))


func _append_events(events: Array) -> void:
	for e in events:
		var key: String = e.get("clave", "")
		var color := Palette.TINTA_SUAVE
		if key == "EV_RONDA":
			color = Palette.ORO
		elif key == "EV_ROTA" or key.begins_with("END_"):
			color = Palette.RUBRICA
		elif key == "EV_HABILIDAD":
			color = Palette.LAPIS
		_ticker_box.add_child(ChronicleUI.label(
			Loc.f(key, e.get("args", [])), 13, color))

	# Keep only the last few lines; the full record is in battle.chronicle.
	while _ticker_box.get_child_count() > TICKER_LINES:
		var oldest := _ticker_box.get_child(0)
		_ticker_box.remove_child(oldest)
		oldest.queue_free()


# ------------------------------------------------------------------ input ---

func _unhandled_input(event: InputEvent) -> void:
	if _resolving or _battle == null or _battle.finished:
		return

	if event.is_action_pressed("nav_down") or event.is_action_pressed("next_unit"):
		_cycle_unit(1)
	elif event.is_action_pressed("nav_up") or event.is_action_pressed("prev_unit"):
		_cycle_unit(-1)
	elif event.is_action_pressed("nav_right"):
		_cycle_order(1)
	elif event.is_action_pressed("nav_left"):
		_cycle_order(-1)
	elif event.is_action_pressed("confirm"):
		_cycle_unit(1)   # Confirming a company steps on to the next one.
	elif event.is_action_pressed("ability"):
		if _battle.activate_ability():
			_refresh()
	elif event.is_action_pressed("commit"):
		_commit()
	elif event.is_action_pressed("cancel"):
		GameState.goto("campaign")


func _cycle_unit(step: int) -> void:
	if _roster.is_empty():
		return
	_selected = (_selected + step + _roster.size()) % _roster.size()
	_refresh()


func _cycle_order(step: int) -> void:
	if _roster.is_empty():
		return
	var unit := _roster[_selected]
	var options := Orders.available_for(unit.kind)
	var i := options.find(_orders.get(unit.id, Orders.Order.MANTENER))
	if i < 0:
		i = 0
	_orders[unit.id] = options[(i + step + options.size()) % options.size()]
	_refresh()


func _commit() -> void:
	_resolving = true
	_commit_label.text = "…"

	var events := _battle.resolve_round(_orders)
	_append_events(events)
	# Watch the round happen before being asked for the next one.
	await _field.play_round(events)

	_resolving = false
	_commit_label.text = tr("HINT_COMMIT")

	if _battle.finished:
		_finish()
	else:
		_prepare_round()


func _finish() -> void:
	GameState.last_result = _battle.result
	GameState.last_result["chronicle"] = _battle.chronicle
	GameState.submit_result(_scenario.id, _battle.result)
	await get_tree().create_timer(1.1).timeout   # let the last rout finish
	GameState.goto("aftermath")
