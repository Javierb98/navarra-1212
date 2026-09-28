class_name Figures
extends RefCounted
## Soldiers, drawn rather than illustrated.
##
## Every figure on the battlefield is built here out of polygons and lines. No
## sprite files, no spritesheets, nothing to draw by hand — which is the whole
## reason an army can exist on screen at all at this stage of the project.
##
## They are silhouettes with two or three flat colours, which is both the
## cheapest thing to draw and exactly right for the illuminated-chronicle look:
## manuscript figures are flat, stiff and unshaded too.
##
## Local coordinates put the origin at the figure's feet, facing right; the
## caller passes facing = -1 to mirror.

## Grid spacing a company should use for this troop type.
static func footprint(kind: UnitKind.Kind) -> Vector2:
	match kind:
		UnitKind.Kind.CABALLERIA: return Vector2(26.0, 22.0)
		UnitKind.Kind.JINETES: return Vector2(24.0, 21.0)
		_: return Vector2(14.0, 17.0)


## How many figures represent this many men. Deliberately coarse: the block
## should read as "a lot" or "not many any more" at a glance, not be counted.
static func figure_count(strength: int) -> int:
	if strength <= 0:
		return 0
	return clampi(int(round(strength / 26.0)), 1, 22)


static func is_mounted(kind: UnitKind.Kind) -> bool:
	return kind == UnitKind.Kind.CABALLERIA or kind == UnitKind.Kind.JINETES


## Draw one man.
##
##   phase       — his personal place in the animation cycle, in turns (0..1
##                 repeating). Every figure gets a different one so a company
##                 never marches in lockstep.
##   gait        — 0 standing, 1 moving. Drives the walk and the gallop.
##   fight       — 0 not in contact, 1 fighting. Drives the thrust.
##   aggression  — posture: negative is backing away, 1 is a full charge.
static func draw_figure(c: CanvasItem, kind: UnitKind.Kind, pos: Vector2, facing: int,
		body: Color, metal: Color, phase: float, gait: float, fight: float,
		aggression: float) -> void:
	if is_mounted(kind):
		_draw_horseman(c, kind, pos, facing, body, metal, phase, gait, fight, aggression)
	else:
		_draw_footman(c, kind, pos, facing, body, metal, phase, gait, fight, aggression)


# ------------------------------------------------------------------- foot ---

static func _draw_footman(c: CanvasItem, kind: UnitKind.Kind, pos: Vector2, facing: int,
		body: Color, metal: Color, phase: float, gait: float, fight: float,
		aggression: float) -> void:
	var cycle := phase * TAU
	var swing := sin(cycle)
	var breath := sin(cycle * 0.45) * 0.5          # idle: the men are never quite still

	# The body rises on each stride and settles between them.
	var bob := -absf(swing) * 1.5 * gait - breath * (1.0 - gait) * 0.6
	var lean := aggression * 2.2 + swing * 0.5 * gait
	var top := Vector2(lean, bob)

	# Legs stride out of phase with each other; planted feet when standing.
	var stride := 3.4 * gait
	var hip := Vector2(0.0, -5.5 + bob * 0.5)
	_leg(c, pos, facing, body, hip + Vector2(-1.4, 0), swing * stride,
		maxf(0.0, swing) * 2.2 * gait)
	_leg(c, pos, facing, body, hip + Vector2(1.4, 0), -swing * stride,
		maxf(0.0, -swing) * 2.2 * gait)

	# Torso
	c.draw_colored_polygon(_poly([
		Vector2(-2.7, -13.0) + top, Vector2(2.7, -13.0) + top,
		Vector2(2.2, -5.0) + Vector2(0, bob * 0.5), Vector2(-2.2, -5.0) + Vector2(0, bob * 0.5),
	], pos, facing), body)

	# Head, with a hint of a helmet
	var head := Vector2(0.2, -15.4) + top
	c.draw_circle(_p(head, pos, facing), 2.5, body)
	c.draw_circle(_p(head + Vector2(0, -0.7), pos, facing), 2.2, metal)

	# Weapons thrust on the fight cycle, which runs at double the walk.
	var thrust := maxf(0.0, sin(cycle * 2.0)) * fight

	match kind:
		UnitKind.Kind.BALLESTEROS:
			# Crossbow across the chest. It kicks back as it looses.
			var recoil := -thrust * 2.4
			var chest := Vector2(0.5 + recoil, -9.5) + top
			c.draw_line(_p(chest, pos, facing), _p(chest + Vector2(6.5, -0.6), pos, facing),
				metal, 1.5)
			c.draw_line(_p(chest + Vector2(4.6, -3.0), pos, facing),
				_p(chest + Vector2(4.6, 2.0), pos, facing), metal, 1.3)
		UnitKind.Kind.ALMOGAVARES:
			# Javelin, cocked back and thrown.
			var hand := Vector2(2.0 + thrust * 5.0, -12.0) + top
			c.draw_line(_p(hand + Vector2(-4.0, -4.0 + thrust * 3.0), pos, facing),
				_p(hand + Vector2(7.0, 1.5 - thrust * 2.0), pos, facing), metal, 1.4)
		_:
			# Spear and shield. The spear levels as the charge builds and jabs
			# forward when the lines are in contact.
			var reach := aggression * 5.0 + thrust * 6.0
			var butt := Vector2(3.4 - thrust * 3.0, 2.0 + bob * 0.5)
			var tip := Vector2(3.4 + reach, -19.0 - aggression * 1.5 + thrust * 7.0) + top
			c.draw_line(_p(butt, pos, facing), _p(tip, pos, facing), metal, 1.3)
			c.draw_colored_polygon(_poly([
				Vector2(-2.4, -12.5) + top, Vector2(-5.6, -11.0) + top,
				Vector2(-5.6, -6.5) + Vector2(0, bob * 0.5),
				Vector2(-2.4, -5.5) + Vector2(0, bob * 0.5),
			], pos, facing), metal)


static func _leg(c: CanvasItem, pos: Vector2, facing: int, body: Color,
		hip: Vector2, reach: float, lift: float) -> void:
	c.draw_line(_p(hip, pos, facing), _p(Vector2(hip.x + reach, -lift), pos, facing),
		body, 1.9)


# ------------------------------------------------------------------ horse ---

static func _draw_horseman(c: CanvasItem, kind: UnitKind.Kind, pos: Vector2, facing: int,
		body: Color, metal: Color, phase: float, gait: float, fight: float,
		aggression: float) -> void:
	var cycle := phase * TAU
	# A gallop is a bounding gait: the whole animal leaves the ground once per
	# stride rather than swinging legs like a walker.
	var bound := sin(cycle)
	var lift := -(absf(bound) * 2.6 * gait) - aggression * 1.2
	var reach := bound * gait

	# Fore and hind pairs move together and out of phase with each other.
	var fore := bound * 4.6 * gait
	var hind := -bound * 4.6 * gait
	for spec in [[-6.0, hind], [-4.2, hind * 0.8], [4.2, fore * 0.8], [6.0, fore]]:
		var hip := Vector2(spec[0], -7.5 + lift)
		var hoof := Vector2(spec[0] + spec[1], -maxf(0.0, spec[1]) * 0.35)
		c.draw_line(_p(hip, pos, facing), _p(hoof, pos, facing), body, 1.8)

	# Barrel, neck and head. The neck reaches forward as the horse extends.
	c.draw_colored_polygon(_poly([
		Vector2(-8.5, -12.5 + lift), Vector2(6.0, -12.5 + lift), Vector2(8.5, -10.0 + lift),
		Vector2(8.0, -6.5 + lift), Vector2(-7.5, -6.5 + lift), Vector2(-9.5, -9.0 + lift),
	], pos, facing), body)
	var neck := reach * 0.8 + aggression * 1.4
	c.draw_colored_polygon(_poly([
		Vector2(5.5, -12.0 + lift), Vector2(10.0 + neck, -18.0 + lift + neck * 0.3),
		Vector2(13.0 + neck, -17.0 + lift + neck * 0.3), Vector2(12.0 + neck, -14.0 + lift),
		Vector2(8.5, -9.5 + lift),
	], pos, facing), body)
	# Tail streams out behind.
	c.draw_line(_p(Vector2(-8.5, -11.5 + lift), pos, facing),
		_p(Vector2(-12.5 - gait * 2.0, -5.0 + lift - reach), pos, facing), body, 1.6)

	# Rider, riding the bounce a beat behind the horse.
	var seat := Vector2(-1.0, -13.0 + lift + bound * 0.6 * gait)
	c.draw_colored_polygon(_poly([
		seat + Vector2(-2.4, -6.5), seat + Vector2(2.6, -6.5),
		seat + Vector2(2.2, 0.5), seat + Vector2(-2.2, 0.5),
	], pos, facing), body)
	c.draw_circle(_p(seat + Vector2(0.4, -8.8), pos, facing), 2.4, metal)

	var thrust := maxf(0.0, sin(cycle * 2.0)) * fight
	if kind == UnitKind.Kind.JINETES:
		# Javelin, held overarm and thrown.
		c.draw_line(_p(seat + Vector2(-4.0 + thrust * 4.0, -9.0), pos, facing),
			_p(seat + Vector2(8.0 + thrust * 5.0, -5.0 - thrust * 2.0), pos, facing),
			metal, 1.4)
	else:
		# Couched lance. Levels off as the charge goes in.
		var drop := 4.0 - aggression * 3.0
		c.draw_line(_p(seat + Vector2(-7.0 + thrust * 3.0, -7.0 + drop), pos, facing),
			_p(seat + Vector2(17.0 + thrust * 4.0, -3.0), pos, facing), metal, 1.6)


# ------------------------------------------------------------------ dead ---

## The fallen stay on the field. A block that has been fought to pieces should
## have the evidence lying around it.
static func draw_fallen(c: CanvasItem, pos: Vector2, facing: int, body: Color) -> void:
	c.draw_colored_polygon(_poly([
		Vector2(-5.0, -1.2), Vector2(4.0, -2.6), Vector2(5.0, -0.4), Vector2(-4.5, 0.8),
	], pos, facing), body)
	c.draw_circle(_p(Vector2(5.4, -2.2), pos, facing), 1.9, body)


# ---------------------------------------------------------------- banners ---

## Company banner. The pole is the anchor point the player's eye tracks, so it
## leans with the block and drops when the company breaks.
static func draw_banner(c: CanvasItem, pos: Vector2, facing: int, height: float,
		cloth: Color, pole: Color, wave: float) -> void:
	var top := Vector2(0, -height)
	c.draw_line(_p(Vector2(0, 0), pos, facing), _p(top, pos, facing), pole, 1.8)
	c.draw_colored_polygon(_poly([
		top + Vector2(0, 1.0),
		top + Vector2(13.0, 3.0 + wave),
		top + Vector2(13.0, 11.0 + wave),
		top + Vector2(0, 12.0),
	], pos, facing), cloth)


# ----------------------------------------------------------------- helpers ---

static func _p(local: Vector2, origin: Vector2, facing: int) -> Vector2:
	return origin + Vector2(local.x * facing, local.y)


static func _poly(points: Array, origin: Vector2, facing: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	# Mirroring reverses winding; push points in reverse so the polygon stays
	# convex-ordered for the triangulator.
	if facing < 0:
		for i in range(points.size() - 1, -1, -1):
			out.append(_p(points[i], origin, facing))
	else:
		for pt in points:
			out.append(_p(pt, origin, facing))
	return out
