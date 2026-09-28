class_name CompanyBlock
extends Node2D
## One company standing on the field, drawn as a formation of individual men.
##
## The block is the thing the player actually reads during a battle: how many
## figures are left, how far forward it has pushed, whether its banner is still
## up. Numbers are secondary. When a company loses men the figures go, and the
## bodies stay on the ground where they fell.

## Cycles per second for the animation. Standing men breathe slowly; marching
## men take roughly two strides a second.
const IDLE_CYCLE := 0.55
const MARCH_CYCLE := 2.0

## Company labels sit on a fixed line below the lane centre.
const NAME_BASELINE := 54.0

var unit: Unit
var facing := 1                       ## +1 for the player's side, -1 for the enemy's
var body_color := Color("2f3d5c")
var metal_color := Color("b8b09a")
var banner_color := Color("9c2b1b")
var selected := false
var name_row := 0                     ## staggers the label so ranks do not collide

var _cols := 5
var _spacing := Vector2(14, 17)
var _slots: PackedVector2Array = PackedVector2Array()
var _shown := 0                       ## figures currently standing
var _fallen: Array[Vector2] = []      ## slots vacated by casualties
var _aggression := 0.0                ## 0 holding, 1 charging — drives posture
var _time := 0.0                      ## wall time, for the banner
var _cycle := 0.0                     ## animation phase in turns; runs faster when moving
var _gait := 0.0                      ## 0 standing, 1 marching. Eased, never snapped.
var _gait_target := 0.0
var _fight := 0.0                     ## 0 apart, 1 in contact
var _fight_target := 0.0
var _shake := Vector2.ZERO
var _flash := 0.0
var _routing := false
var _banner_drop := 0.0


func setup(u: Unit, side_color: Color, block_facing: int) -> void:
	unit = u
	facing = block_facing
	body_color = side_color
	banner_color = side_color.lightened(0.08)
	metal_color = Color("cbc3ad") if side_color.get_luminance() < 0.4 else Color("6b6152")
	_cols = 4 if Figures.is_mounted(u.kind) else 5
	_spacing = Figures.footprint(u.kind)
	_rebuild_slots()
	_shown = Figures.figure_count(u.strength)
	set_process(true)


func _rebuild_slots() -> void:
	_slots = PackedVector2Array()
	var total := Figures.figure_count(unit.initial_strength)
	var rows := int(ceil(float(total) / float(_cols)))
	for k in total:
		var col := k % _cols
		@warning_ignore("integer_division")
		var row := k / _cols
		# A deterministic wobble per slot, so a formation looks like men rather
		# than a spreadsheet — but never shimmers between frames.
		var jitter := Vector2(_hash(k, 1) * 2.6 - 1.3, _hash(k, 2) * 2.2 - 1.1)
		_slots.append(Vector2(
			(float(col) - (_cols - 1) * 0.5) * _spacing.x,
			(float(row) - (rows - 1) * 0.5) * _spacing.y) + jitter)


static func _hash(a: int, b: int) -> float:
	var h := (a * 73856093) ^ (b * 19349663)
	return float(absi(h) % 1000) / 1000.0


# -------------------------------------------------------------- commands ---

func snap_to(pos: Vector2) -> void:
	position = pos


func move_to(pos: Vector2, duration: float) -> void:
	if _routing:
		return
	if position.distance_to(pos) < 1.0:
		return
	# Break into a march for the length of the move, then settle.
	_gait_target = 1.0
	var t := create_tween()
	t.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(self, "position", pos, duration)
	t.tween_callback(func(): _gait_target = 0.0)


## In contact with the enemy: the men start working their weapons.
func set_fighting(value: bool) -> void:
	_fight_target = 1.0 if value else 0.0


## Posture for the coming round, taken from the order the company was given.
func set_posture(order: Orders.Order) -> void:
	match order:
		Orders.Order.CARGAR: _aggression = 1.0
		Orders.Order.AVANZAR: _aggression = 0.45
		Orders.Order.HOSTIGAR: _aggression = 0.15
		Orders.Order.REPLEGAR: _aggression = -0.35
		_: _aggression = 0.0
	queue_redraw()


## Struck. Jolt away from the blow and flash.
func play_impact(from_direction: Vector2, force := 1.0) -> void:
	_shake = from_direction.normalized() * (5.0 + 5.0 * force)
	_flash = 1.0


## Losses land as figures disappearing and bodies appearing where they stood.
func apply_losses(new_strength: int) -> void:
	var target := Figures.figure_count(new_strength)
	while _shown > target and _shown > 0:
		_shown -= 1
		if _shown < _slots.size():
			_fallen.append(_slots[_shown])
	queue_redraw()


func play_rout(away: Vector2) -> void:
	if _routing:
		return
	_routing = true
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "position", position + away.normalized() * 420.0, 1.1) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(self, "modulate:a", 0.0, 1.1)
	t.tween_property(self, "_banner_drop", 1.0, 0.5)
	t.tween_property(self, "rotation", 0.12 * facing, 1.1)


func set_selected(value: bool) -> void:
	if selected != value:
		selected = value
		queue_redraw()


func is_routing() -> bool:
	return _routing


## Figures currently standing. Exposed for tests — this is the number the
## player actually reads off the field, so it is worth asserting on.
func figures_standing() -> int:
	return _shown


func fallen_count() -> int:
	return _fallen.size()


# ---------------------------------------------------------------- drawing ---

func _process(delta: float) -> void:
	_time += delta

	# Ease between standing and marching so companies lean into a move instead
	# of snapping into a walk cycle.
	_gait = move_toward(_gait, _gait_target, delta * 3.4)
	_fight = move_toward(_fight, _fight_target, delta * 2.6)
	_cycle += delta * lerpf(IDLE_CYCLE, MARCH_CYCLE, _gait)

	_shake = _shake.lerp(Vector2.ZERO, delta * 9.0)
	_flash = maxf(0.0, _flash - delta * 2.6)

	# Every frame. The men are always moving, and anything less than full rate
	# reads as a slideshow. If a Raspberry Pi cannot hold 60 here, reduce the
	# figure count in Figures.figure_count() before throttling this.
	queue_redraw()


func _draw() -> void:
	if unit == null:
		return

	var tint := body_color
	if _flash > 0.01:
		tint = body_color.lerp(Color("f4ecd8"), _flash * 0.75)
	if unit.state == Unit.State.VACILANTE:
		tint = tint.lerp(Color("6b5f4a"), 0.35)

	# The dead first, so the living stand over them.
	for slot in _fallen:
		Figures.draw_fallen(self, slot + _shake * 0.25 + Vector2(0, 2), facing,
			Color(tint, 0.45))

	for i in mini(_shown, _slots.size()):
		var slot := _slots[i] + _shake
		# Each man carries his own offset into the cycle, so the company moves
		# as a crowd rather than a chorus line.
		var phase := _cycle + _hash(i, 7)
		Figures.draw_figure(self, unit.kind, slot, facing, tint, metal_color,
			phase, _gait, _fight, maxf(0.0, _aggression))

	_draw_banner()
	_draw_morale()
	_draw_name()
	if selected:
		_draw_selection()


## The company's name under its feet, so the order strip and the field refer to
## visibly the same thing.
func _draw_name() -> void:
	if not unit.is_active():
		return
	var font := ThemeDB.fallback_font
	var size := 11
	var width := font.get_string_size(unit.name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	# Fixed baseline rather than one derived from the block's height: companies
	# of different sizes in the same wing must not write on the same line. The
	# label also sits toward its own side of the field, so that when the two
	# lines close the opposing names do not land on top of each other.
	var at := Vector2(-width * 0.5 - float(facing) * 34.0,
		NAME_BASELINE + float(name_row) * 13.0)
	draw_string(font, at, unit.name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
		Color(Palette.TINTA, 0.9 if selected else 0.62))


func _draw_banner() -> void:
	if _shown <= 0:
		return
	var extent := _block_extent()
	var anchor := Vector2(extent.x * 0.5 * facing + 10.0 * facing, extent.y * -0.5 + 6.0)
	if _banner_drop > 0.0:
		anchor += Vector2(0, _banner_drop * 26.0)
	var wave := sin(_time * 2.4) * 1.6
	Figures.draw_banner(self, anchor, facing, 34.0 - _banner_drop * 20.0,
		Color(banner_color, 1.0 - _banner_drop), metal_color, wave)


func _draw_morale() -> void:
	if not unit.is_active():
		return
	var extent := _block_extent()
	var width := maxf(46.0, extent.x)
	var origin := Vector2(-width * 0.5, -extent.y * 0.5 - 20.0)
	draw_rect(Rect2(origin, Vector2(width, 4.0)), Color(0.17, 0.13, 0.09, 0.35))
	var pct := clampf(unit.morale / 100.0, 0.0, 1.0)
	draw_rect(Rect2(origin, Vector2(width * pct, 4.0)), Palette.morale_color(unit.morale))


func _draw_selection() -> void:
	var extent := _block_extent()
	var half := Vector2(extent.x * 0.5 + 9.0, extent.y * 0.5 + 9.0)
	var corner := 9.0
	# Corner brackets rather than a full box — less visual noise over the men.
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var c := Vector2(half.x * sx, half.y * sy)
			draw_line(c, c - Vector2(corner * sx, 0.0), Palette.ORO, 2.0)
			draw_line(c, c - Vector2(0.0, corner * sy), Palette.ORO, 2.0)


func _block_extent() -> Vector2:
	var total := maxi(1, Figures.figure_count(unit.initial_strength))
	var rows := int(ceil(float(total) / float(_cols)))
	return Vector2(_cols * _spacing.x, rows * _spacing.y)
