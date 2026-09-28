extends Control
## Title and attract loop — what the cabinet shows to an empty room.

const DWELL := 4.0

var _vignettes: Array = []
var _index := 0
var _timer := 0.0
var _vignette_label: Label


func _ready() -> void:
	ChronicleUI.page(self)
	Attract.resume()
	_gather_vignettes()
	_build()


func _gather_vignettes() -> void:
	for id in GameState.CAMPAIGN:
		var s := Scenario.load_scenario(id)
		if s != null:
			_vignettes.append("%d · %s — %s" % [s.year, s.title, s.place])


func _build() -> void:
	var m := ChronicleUI.margins(90, 70)
	add_child(m)

	var v := ChronicleUI.vbox(6)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	m.add_child(v)

	v.add_child(ChronicleUI.label("1212", 110, Palette.ORO, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(ChronicleUI.label(tr("TITLE"), 42, Palette.TINTA, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(ChronicleUI.spacer(6))
	v.add_child(ChronicleUI.rule())
	v.add_child(ChronicleUI.spacer(6))
	v.add_child(ChronicleUI.label(tr("SUBTITLE"), 20, Palette.TINTA_SUAVE,
		HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(ChronicleUI.spacer(28))

	_vignette_label = ChronicleUI.label(_vignettes[0] if not _vignettes.is_empty() else "",
		24, Palette.RUBRICA, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(_vignette_label)
	v.add_child(ChronicleUI.spacer(40))

	var prompt := ChronicleUI.label(tr("PRESS_START"), 26, Palette.TINTA,
		HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(prompt)
	# Slow pulse rather than a hard blink — easier on the eyes for a cabinet
	# that may sit on this screen for hours.
	var t := create_tween().set_loops()
	t.tween_property(prompt, "modulate:a", 0.25, 1.1).set_trans(Tween.TRANS_SINE)
	t.tween_property(prompt, "modulate:a", 1.0, 1.1).set_trans(Tween.TRANS_SINE)


func _process(delta: float) -> void:
	if _vignettes.size() < 2 or _vignette_label == null:
		return
	_timer += delta
	if _timer < DWELL:
		return
	_timer = 0.0
	_index = (_index + 1) % _vignettes.size()
	_vignette_label.text = _vignettes[_index]
	var t := create_tween()
	_vignette_label.modulate.a = 0.0
	t.tween_property(_vignette_label, "modulate:a", 1.0, 0.4)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("confirm") or event.is_action_pressed("start") \
			or event.is_action_pressed("coin"):
		GameState.goto("campaign")
