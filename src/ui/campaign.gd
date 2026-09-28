extends Control
## The chronicle: pick which battle to fight.
##
## Laid out as a column of entries in date order, so the campaign reads as what
## it is — four and a half centuries of one kingdom's frontier, from an ambush
## in a mountain pass to the field that put the chains on its shield.

var _entries: Array = []      ## [{ "scenario": Scenario, "row": PanelContainer }]
var _selected := 0
var _rows_box: VBoxContainer


func _ready() -> void:
	ChronicleUI.page(self)
	Attract.resume()
	_build()
	_refresh_selection()


func _build() -> void:
	var m := ChronicleUI.margins(70, 40)
	add_child(m)
	var v := ChronicleUI.vbox(10)
	m.add_child(v)

	v.add_child(ChronicleUI.heading(tr("MENU_CAMPAIGN"), 38))
	v.add_child(ChronicleUI.rule())
	v.add_child(ChronicleUI.spacer(8))

	_rows_box = ChronicleUI.vbox(6)
	_rows_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_rows_box)

	for id in GameState.CAMPAIGN:
		var s := Scenario.load_scenario(id)
		if s == null:
			continue
		var row := _build_row(s)
		_rows_box.add_child(row)
		_entries.append({"scenario": s, "row": row})

	v.add_child(ChronicleUI.spacer(6))
	v.add_child(ChronicleUI.hints([tr("HINT_MOVE"), tr("HINT_BACK")]))


func _build_row(s: Scenario) -> PanelContainer:
	var unlocked := GameState.is_unlocked(s.id)
	var rec := GameState.record_for(s.id)

	var p := ChronicleUI.panel()
	var h := ChronicleUI.hbox(18)
	p.add_child(h)

	var year := ChronicleUI.label(str(s.year), 30,
		Palette.ORO if unlocked else Color(Palette.TINTA_SUAVE, 0.45))
	year.custom_minimum_size = Vector2(90, 0)
	h.add_child(year)

	var text := ChronicleUI.vbox(2)
	h.add_child(text)
	var title_color := Palette.TINTA if unlocked else Color(Palette.TINTA_SUAVE, 0.45)
	text.add_child(ChronicleUI.label(s.title, 24, title_color))
	text.add_child(ChronicleUI.label(s.place, 15, Color(Palette.TINTA_SUAVE, 0.9)))

	var status_text := ""
	if not unlocked:
		status_text = tr("MENU_LOCKED")
	elif rec.get("cleared", false):
		status_text = "%s · %s" % [tr("MENU_CLEARED"),
			Loc.f("MENU_BEST", [rec.get("best_score", 0)])]
	var status := ChronicleUI.label(status_text, 15,
		Palette.VERDE if rec.get("cleared", false) else Palette.RUBRICA,
		HORIZONTAL_ALIGNMENT_RIGHT)
	status.custom_minimum_size = Vector2(220, 0)
	h.add_child(status)

	return p


func _refresh_selection() -> void:
	for i in _entries.size():
		var row: PanelContainer = _entries[i]["row"]
		var chosen := i == _selected
		var border := Palette.RUBRICA if chosen else Color(Palette.ORO, 0.35)
		var fill := Color(Palette.HUESO, 0.85 if chosen else 0.4)
		row.add_theme_stylebox_override("panel",
			Palette.panel_style(fill, border, 3 if chosen else 1))


func _unhandled_input(event: InputEvent) -> void:
	if _entries.is_empty():
		return
	if event.is_action_pressed("nav_down"):
		_selected = (_selected + 1) % _entries.size()
		_refresh_selection()
	elif event.is_action_pressed("nav_up"):
		_selected = (_selected - 1 + _entries.size()) % _entries.size()
		_refresh_selection()
	elif event.is_action_pressed("confirm"):
		var s: Scenario = _entries[_selected]["scenario"]
		if GameState.is_unlocked(s.id):
			GameState.pending_scenario = s
			GameState.goto("briefing")
	elif event.is_action_pressed("cancel"):
		GameState.goto("attract")
