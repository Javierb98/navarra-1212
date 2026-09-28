class_name Battlefield
extends Node2D
## The field itself: two armies facing each other, and the animation of a round.
##
## Layout is the same abstraction the engine uses, made literal. The player's
## host stands on the left, the enemy's on the right, three wings stacked as
## bands, and companies behind the front rank wait further back in their lane.
## Orders push blocks toward the contact line in the middle; that is where they
## meet and where the fighting is drawn.
##
## `play_round()` walks the engine's event list and stages it — volleys first,
## then the clashes, then anything that broke — so the player watches the round
## they just ordered actually happen.

const FIELD_SIZE := Vector2(1280.0, 444.0)
const LANE_Y := [78.0, 220.0, 362.0]
const PLAYER_HOME_X := 274.0
const ENEMY_HOME_X := 1006.0
const CONTACT_X := 640.0
## Half the space left between the two front ranks when the lines close. Must
## clear the widest block or the two hosts draw through each other.
const CONTACT_GAP := 74.0
const RANK_DEPTH := 116.0
## Scenery lives out at the edges, behind both hosts. Drawing it any closer in
## puts tents and battlements on top of the men, which reads as noise.
const SCENERY_MARGIN := 84.0

const MOVE_TIME := 0.55
const VOLLEY_TIME := 0.5
const CLASH_TIME := 0.34

var battle: Battle
var scenario: Scenario

var _stage: Node2D                    ## everything that shakes
var _blocks: Dictionary = {}          ## unit id -> CompanyBlock
var _engagement: Dictionary = {}      ## unit id -> 0..1 push toward contact
var _displayed: Dictionary = {}       ## unit id -> strength currently drawn
var _shake := Vector2.ZERO
var _scenery := "campo"


func setup(b: Battle, s: Scenario) -> void:
	battle = b
	scenario = s
	_scenery = s.terrain.get("escenografia", "campo")

	_stage = Node2D.new()
	_stage.name = "Stage"
	add_child(_stage)

	for u in battle.units:
		var block := CompanyBlock.new()
		var faction: Dictionary = s.player_faction if u.side == Battle.SIDE_PLAYER \
			else s.enemy_faction
		block.setup(u, _faction_color(faction, u.side), 1 if u.side == Battle.SIDE_PLAYER else -1)
		_stage.add_child(block)
		_blocks[u.id] = block
		_engagement[u.id] = 0.0
		_displayed[u.id] = u.strength

	_reflow(0.0)
	set_process(true)
	queue_redraw()


func _faction_color(faction: Dictionary, side: int) -> Color:
	var raw: String = faction.get("color", "")
	if raw.is_valid_html_color():
		# Darken toward ink so figures read as silhouettes against parchment.
		return Color(raw).lerp(Palette.TINTA, 0.32)
	return Palette.LAPIS if side == Battle.SIDE_PLAYER else Palette.RUBRICA


func block_for(unit_id: String) -> CompanyBlock:
	return _blocks.get(unit_id)


func highlight(unit_id: String) -> void:
	for id in _blocks:
		_blocks[id].set_selected(id == unit_id)


# ------------------------------------------------------------------ layout ---

func _active_in_lane(side: int, lane: int) -> Array:
	var out := []
	for u in battle.units:
		if u.side == side and u.lane == lane and u.is_active():
			out.append(u)
	return out


func _slot_position(side: int, lane: int, rank: int, engagement: float) -> Vector2:
	var back := RANK_DEPTH * float(rank)
	var home: float
	var front: float
	if side == Battle.SIDE_PLAYER:
		home = PLAYER_HOME_X - back
		front = CONTACT_X - CONTACT_GAP - back
	else:
		home = ENEMY_HOME_X + back
		front = CONTACT_X + CONTACT_GAP + back
	return Vector2(lerpf(home, front, clampf(engagement, 0.0, 1.0)), LANE_Y[lane])


func _reflow(duration: float) -> void:
	for lane in 3:
		for side in [Battle.SIDE_PLAYER, Battle.SIDE_ENEMY]:
			var ranked := _active_in_lane(side, lane)
			for rank in ranked.size():
				var u: Unit = ranked[rank]
				var block: CompanyBlock = _blocks[u.id]
				if block == null or block.is_routing():
					continue
				# Stagger name labels by rank so companies stacked in the same
				# lane do not write over each other.
				block.name_row = rank % 2
				var target := _slot_position(side, lane, rank, _engagement[u.id])
				if duration <= 0.0:
					block.snap_to(target)
				else:
					block.move_to(target, duration)
	_update_contact()


## Front companies whose lines have closed start working their weapons. Anyone
## still crossing open ground just marches.
func _update_contact() -> void:
	for id in _blocks:
		_blocks[id].set_fighting(false)
	for lane in 3:
		var mine := _active_in_lane(Battle.SIDE_PLAYER, lane)
		var theirs := _active_in_lane(Battle.SIDE_ENEMY, lane)
		if mine.is_empty() or theirs.is_empty():
			continue
		var a: Unit = mine[0]
		var b: Unit = theirs[0]
		if float(_engagement[a.id]) + float(_engagement[b.id]) >= 1.0:
			_blocks[a.id].set_fighting(true)
			_blocks[b.id].set_fighting(true)


## Orders decide how far each company pushes toward the contact line.
func _apply_postures() -> void:
	for u in battle.units:
		var block: CompanyBlock = _blocks.get(u.id)
		if block == null or not u.is_active():
			continue
		block.set_posture(u.order)
		var delta := 0.0
		match u.order:
			Orders.Order.CARGAR: delta = 0.55
			Orders.Order.AVANZAR: delta = 0.38
			Orders.Order.HOSTIGAR: delta = -0.06
			Orders.Order.REPLEGAR: delta = -0.32
			_: delta = 0.0
		_engagement[u.id] = clampf(_engagement[u.id] + delta, 0.0, 1.0)


# --------------------------------------------------------------- playback ---

## Stage one round. Awaits until the field has settled.
func play_round(events: Array) -> void:
	_apply_postures()
	# Anything the engine says came to blows this round must actually be in
	# contact on screen. Without this the chronicle reports a clash while the
	# two blocks are still a third of the field apart, and the picture stops
	# meaning anything.
	for e in events:
		var key: String = e.get("clave", "")
		if key == "EV_CHOQUE" or key == "EV_FLANQUEO":
			for role in ["origen", "destino"]:
				var id: String = e.get(role, "")
				if _engagement.has(id):
					_engagement[id] = 1.0

	_reflow(MOVE_TIME)
	await _wait(MOVE_TIME + 0.1)

	for e in events:
		match e.get("clave", ""):
			"EV_DISPARO":
				await _play_volley(e)
			"EV_CHOQUE", "EV_FLANQUEO":
				await _play_clash(e)
			"EV_ROTA":
				await _play_break(e)

	_reflow(0.4)
	await _wait(0.45)


func _play_volley(e: Dictionary) -> void:
	var src: CompanyBlock = _blocks.get(e.get("origen", ""))
	var dst: CompanyBlock = _blocks.get(e.get("destino", ""))
	if src == null or dst == null:
		return

	var volley := Volley.new()
	_stage.add_child(volley)
	@warning_ignore("integer_division")
	var shafts := 6 + int(e.get("bajas", 0)) / 6
	volley.fire(src.position, dst.position, shafts, Palette.TINTA, VOLLEY_TIME)

	await _wait(VOLLEY_TIME * 0.72)
	_land(e, dst, (dst.position - src.position), 0.45)
	await _wait(0.16)


func _play_clash(e: Dictionary) -> void:
	var src: CompanyBlock = _blocks.get(e.get("origen", ""))
	var dst: CompanyBlock = _blocks.get(e.get("destino", ""))
	if src == null or dst == null:
		return

	# The attacker lunges in and recovers; the defender takes it.
	var direction := (dst.position - src.position).normalized()
	if not src.is_routing():
		var lunge := create_tween()
		lunge.tween_property(src, "position", src.position + direction * 16.0, 0.09)
		lunge.tween_property(src, "position", src.position, 0.16)

	await _wait(0.09)
	_land(e, dst, direction, 1.0)
	_shake_field(minf(9.0, float(e.get("bajas", 0)) * 0.16))
	await _wait(CLASH_TIME)


func _play_break(e: Dictionary) -> void:
	var block: CompanyBlock = _blocks.get(e.get("destino", ""))
	if block == null:
		return
	# Broken men run for the rear, whichever way that is for their side.
	var away := Vector2(-1.0, 0.25) if block.facing > 0 else Vector2(1.0, 0.25)
	block.play_rout(away)
	_shake_field(4.0)
	await _wait(0.4)


## Apply an event's casualties to the block that took them.
func _land(e: Dictionary, dst: CompanyBlock, direction: Vector2, force: float) -> void:
	var id: String = e.get("destino", "")
	var losses := int(e.get("bajas", 0))
	_displayed[id] = maxi(0, int(_displayed.get(id, 0)) - losses)
	dst.apply_losses(_displayed[id])
	dst.play_impact(direction, force)


func _shake_field(amount: float) -> void:
	_shake = Vector2(randf_range(-amount, amount), randf_range(-amount, amount))


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _process(delta: float) -> void:
	if _shake.length() > 0.05:
		_shake = _shake.lerp(Vector2.ZERO, delta * 11.0)
		_stage.position = _shake
	elif _stage.position != Vector2.ZERO:
		_stage.position = Vector2.ZERO


# ---------------------------------------------------------------- scenery ---

func _draw() -> void:
	_draw_ground()
	match _scenery:
		"desfiladero": _draw_pass()
		"muralla": _draw_walls()
		"campamento": _draw_camp()
		_: _draw_hills()
	_draw_contact_line()


func _draw_ground() -> void:
	# Faint bands mark the three wings without boxing them in.
	for lane in 3:
		var y: float = LANE_Y[lane]
		draw_rect(Rect2(0.0, y - 52.0, FIELD_SIZE.x, 104.0),
			Color(Palette.TINTA, 0.03 if lane % 2 == 0 else 0.055))


func _draw_contact_line() -> void:
	# Where the two hosts meet. Dashed, so it reads as a notion rather than a wall.
	var y := 30.0
	while y < FIELD_SIZE.y - 20.0:
		draw_line(Vector2(CONTACT_X, y), Vector2(CONTACT_X, y + 9.0),
			Color(Palette.ORO, 0.30), 1.5)
		y += 19.0


func _draw_hills() -> void:
	var ridge := PackedVector2Array()
	ridge.append(Vector2(0.0, 34.0))
	for i in 15:
		var x := float(i) / 14.0 * FIELD_SIZE.x
		ridge.append(Vector2(x, 30.0 - sin(float(i) * 0.9) * 13.0 - cos(float(i) * 0.4) * 8.0))
	ridge.append(Vector2(FIELD_SIZE.x, 34.0))
	ridge.append(Vector2(FIELD_SIZE.x, 0.0))
	ridge.append(Vector2(0.0, 0.0))
	draw_colored_polygon(ridge, Color(Palette.VERDE, 0.20))


## Roncesvalles: rock walls closing in from both edges.
func _draw_pass() -> void:
	for side in [0, 1]:
		var rock := PackedVector2Array()
		var base := 0.0 if side == 0 else FIELD_SIZE.y
		var dir := 1.0 if side == 0 else -1.0
		rock.append(Vector2(0.0, base))
		for i in 17:
			var x := float(i) / 16.0 * FIELD_SIZE.x
			# Narrowest at the centre, which is where the trap closes.
			var pinch := 1.0 - absf(x - FIELD_SIZE.x * 0.5) / (FIELD_SIZE.x * 0.5)
			var depth := (16.0 + pinch * 30.0 + sin(float(i) * 1.7) * 9.0) * dir
			rock.append(Vector2(x, base + depth))
		rock.append(Vector2(FIELD_SIZE.x, base))
		draw_colored_polygon(rock, Color("4a3b2c", 0.42))


## Nájera and Tudela: the objective is a wall on the enemy's side.
func _draw_walls() -> void:
	var wall_x := FIELD_SIZE.x - SCENERY_MARGIN
	draw_rect(Rect2(wall_x, 18.0, FIELD_SIZE.x - wall_x, FIELD_SIZE.y - 36.0),
		Color("6b5b46", 0.40))
	# Crenellations along the near face.
	var y := 22.0
	while y < FIELD_SIZE.y - 30.0:
		draw_rect(Rect2(wall_x - 9.0, y, 9.0, 15.0), Color("6b5b46", 0.55))
		y += 30.0
	# Towers flanking the centre wing.
	for ty in [LANE_Y[0] - 62.0, LANE_Y[2] + 14.0]:
		draw_rect(Rect2(wall_x - 26.0, ty, 26.0, 52.0), Color("5c4d3c", 0.6))


## Las Navas: the caliph's camp behind its palisade.
func _draw_camp() -> void:
	var stake_x := FIELD_SIZE.x - SCENERY_MARGIN
	var y := 24.0
	while y < FIELD_SIZE.y - 24.0:
		draw_line(Vector2(stake_x, y), Vector2(stake_x - 4.0, y + 17.0),
			Color("4a3b2c", 0.65), 3.0)
		y += 13.0
	# Tents behind it, the red one in the middle being the point of the battle.
	# They run off the right edge on purpose — the camp is bigger than the view.
	for spec in [[LANE_Y[0], 32.0], [LANE_Y[1], 44.0], [LANE_Y[2], 32.0]]:
		var cy: float = spec[0]
		var size: float = spec[1]
		var cx := stake_x + 54.0
		var tent := PackedVector2Array([
			Vector2(cx - size, cy + size * 0.55),
			Vector2(cx, cy - size * 0.75),
			Vector2(cx + size, cy + size * 0.55),
		])
		var is_caliph := absf(cy - LANE_Y[1]) < 1.0
		draw_colored_polygon(tent, Color("7d1f1f", 0.55) if is_caliph
			else Color("8a7355", 0.45))
