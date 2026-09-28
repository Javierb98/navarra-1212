extends Control
## The page after the battle.
##
## The scoreboard is the small half of this screen. The big half is what
## actually happened — including the times the real battle went the other way
## from the one just played, and the places where the popular story is legend
## rather than record. That contrast is the point of the whole game.

func _ready() -> void:
	ChronicleUI.page(self)
	Attract.resume()
	var s := GameState.pending_scenario
	if s == null:
		GameState.goto("campaign")
		return
	_build(s, GameState.last_result)


func _build(s: Scenario, result: Dictionary) -> void:
	var m := ChronicleUI.margins(60, 34)
	add_child(m)
	var v := ChronicleUI.vbox(8)
	m.add_child(v)

	var victory: bool = result.get("victoria", false)
	var head := ChronicleUI.hbox(16)
	v.add_child(head)
	head.add_child(ChronicleUI.label(tr("AFTER_VICTORY") if victory else tr("AFTER_DEFEAT"),
		44, Palette.VERDE if victory else Palette.RUBRICA))
	var sub := ChronicleUI.vbox(0)
	head.add_child(sub)
	sub.add_child(ChronicleUI.label("%s · %d" % [s.title, s.year], 24, Palette.TINTA))
	sub.add_child(ChronicleUI.label(tr(result.get("motivo", "")), 15, Palette.TINTA_SUAVE))
	v.add_child(ChronicleUI.rule())

	# Tally
	var tally := ChronicleUI.hbox(26)
	v.add_child(tally)
	for entry in [
		["AFTER_ROUNDS", result.get("rondas", 0)],
		["AFTER_OWN_LOSSES", result.get("bajas_propias", 0)],
		["AFTER_ENEMY_LOSSES", result.get("bajas_enemigas", 0)],
		["AFTER_SURVIVORS", result.get("supervivientes", 0)],
		["AFTER_SCORE", result.get("score", 0)],
	]:
		tally.add_child(ChronicleUI.label(Loc.f(entry[0], [entry[1]]), 16, Palette.TINTA))

	v.add_child(ChronicleUI.spacer(6))

	# What actually happened
	var note := ChronicleUI.panel()
	v.add_child(note)
	var nv := ChronicleUI.vbox(4)
	note.add_child(nv)
	nv.add_child(ChronicleUI.rubric(tr("AFTER_HISTORY"), 18))
	nv.add_child(ChronicleUI.body(s.historical_note, 15, Palette.TINTA))

	# Legend vs record, only where there is something to warn about
	if not s.caveat.is_empty():
		var caveat := ChronicleUI.panel(Palette.HUESO, Palette.RUBRICA)
		v.add_child(caveat)
		var cv := ChronicleUI.vbox(4)
		caveat.add_child(cv)
		cv.add_child(ChronicleUI.rubric(tr("AFTER_CAVEAT"), 16))
		cv.add_child(ChronicleUI.body(s.caveat, 14, Palette.TINTA))

	if not s.sources.is_empty():
		v.add_child(ChronicleUI.spacer(2))
		v.add_child(ChronicleUI.label(tr("AFTER_SOURCES"), 14, Palette.TINTA_SUAVE))
		for src in s.sources:
			v.add_child(ChronicleUI.label("· %s" % src, 12,
				Color(Palette.TINTA_SUAVE, 0.85)))

	v.add_child(ChronicleUI.spacer(6))
	v.add_child(ChronicleUI.hints(["B1: %s" % tr("AFTER_CONTINUE")]))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("confirm") or event.is_action_pressed("start") \
			or event.is_action_pressed("cancel"):
		GameState.goto("campaign")
