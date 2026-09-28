extends Control
## Pre-battle page: the situation, the ground, the objective, and both hosts.
##
## This is where the history actually lands — a player who reads nothing else
## still gets the year, the place and what was at stake before the first order.

func _ready() -> void:
	ChronicleUI.page(self)
	Attract.resume()
	if GameState.pending_scenario == null:
		GameState.goto("campaign")
		return
	_build(GameState.pending_scenario)


func _build(s: Scenario) -> void:
	var m := ChronicleUI.margins(60, 34)
	add_child(m)
	var v := ChronicleUI.vbox(8)
	m.add_child(v)

	# Heading
	var head := ChronicleUI.hbox(16)
	v.add_child(head)
	head.add_child(ChronicleUI.label(str(s.year), 46, Palette.ORO))
	var titles := ChronicleUI.vbox(0)
	head.add_child(titles)
	titles.add_child(ChronicleUI.label(s.title, 34, Palette.TINTA))
	titles.add_child(ChronicleUI.label("%s · %s" % [s.place, s.date_text], 15,
		Palette.TINTA_SUAVE))
	v.add_child(ChronicleUI.rule())

	# The situation
	v.add_child(ChronicleUI.body(s.summary, 17))
	v.add_child(ChronicleUI.spacer(4))

	# Ground / objective / commander, three across
	var cols := ChronicleUI.hbox(14)
	v.add_child(cols)
	cols.add_child(_card(tr("BRIEF_TERRAIN"),
		"%s\n%s" % [s.terrain.get("nombre", ""), s.terrain.get("desc", "")]))
	cols.add_child(_card(tr("BRIEF_OBJECTIVE"),
		"%s\n%s" % [tr(s.goal_key()), Loc.f("BRIEF_ROUNDS", [s.max_rounds])]))
	cols.add_child(_card(tr("BRIEF_COMMANDER"),
		"%s\n%s: %s" % [s.commander.get("nombre", ""), s.commander.get("habilidad", ""),
			s.commander.get("habilidad_desc", "")]))

	v.add_child(ChronicleUI.spacer(4))

	# The two hosts
	var hosts := ChronicleUI.hbox(20)
	v.add_child(hosts)
	hosts.add_child(_host_column(tr("BRIEF_YOUR_HOST"), s.player_faction,
		s.player_units, Palette.LAPIS))
	hosts.add_child(_host_column(tr("BRIEF_ENEMY_HOST"), s.enemy_faction,
		s.enemy_units, Palette.RUBRICA))

	v.add_child(ChronicleUI.spacer(6))
	v.add_child(ChronicleUI.hints([tr("HINT_MOVE"), "B1: %s" % tr("BRIEF_BEGIN"),
		tr("HINT_BACK")]))


func _card(title: String, text: String) -> PanelContainer:
	var p := ChronicleUI.panel()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := ChronicleUI.vbox(4)
	p.add_child(v)
	v.add_child(ChronicleUI.rubric(title, 16))
	v.add_child(ChronicleUI.body(text, 14))
	return p


func _host_column(heading: String, faction: Dictionary, units: Array,
		accent: Color) -> PanelContainer:
	var p := ChronicleUI.panel()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := ChronicleUI.vbox(3)
	p.add_child(v)

	var banner := ChronicleUI.hbox(10)
	v.add_child(banner)
	var shield := _shield(faction.get("heraldica", ""))
	if shield != null:
		banner.add_child(shield)
	var names := ChronicleUI.vbox(0)
	banner.add_child(names)
	names.add_child(ChronicleUI.label(heading, 13, Color(Palette.TINTA_SUAVE, 0.9)))
	names.add_child(ChronicleUI.label(faction.get("nombre", ""), 18, accent))
	v.add_child(ChronicleUI.rule(Color(accent, 0.4), 1))

	var total := 0
	for u in units:
		total += int(u.get("fuerza", 0))
		var row := ChronicleUI.hbox(8)
		v.add_child(row)
		var kind := UnitKind.from_string(u.get("tipo", "peones"))
		var name_label := ChronicleUI.label(u.get("nombre", ""), 14, Palette.TINTA)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		row.add_child(ChronicleUI.label(tr(UnitKind.name_key(kind)), 13, Palette.TINTA_SUAVE))
		var men := ChronicleUI.label(str(int(u.get("fuerza", 0))), 14, Palette.TINTA_SUAVE,
			HORIZONTAL_ALIGNMENT_RIGHT)
		men.custom_minimum_size = Vector2(56, 0)
		row.add_child(men)

	v.add_child(ChronicleUI.rule(Color(accent, 0.25), 1))
	v.add_child(ChronicleUI.label("%s: %d" % [tr("BATTLE_STRENGTH"), total], 15, accent,
		HORIZONTAL_ALIGNMENT_RIGHT))
	return p


## Faction shield. Missing art is not fatal — a scenario should still be
## playable while its heraldry is being drawn.
func _shield(path: String) -> TextureRect:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var tex := load(path)
	if tex == null:
		return null
	var r := TextureRect.new()
	r.texture = tex
	r.custom_minimum_size = Vector2(44, 53)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return r


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("confirm") or event.is_action_pressed("start"):
		GameState.goto("battle")
	elif event.is_action_pressed("cancel"):
		GameState.goto("campaign")
