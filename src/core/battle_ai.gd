class_name BattleAI
extends RefCounted
## The opposing captain.
##
## Deliberately not optimal. It scores each legal order with a handful of
## readable heuristics and then picks with some noise, so the player can learn
## its habits over a few plays without it ever feeling scripted. Two dials in
## the scenario JSON shape it:
##
##   agresividad — how much it likes closing and charging (0..1)
##   astucia     — how well it reads matchups and its own condition (0..1).
##                 At 0 it more or less flails; at 1 it braces spears against
##                 horse and pulls broken companies out of the line.
##
## It uses the battle's own RNG so a seeded battle replays identically.

var aggression: float = 0.5
var cunning: float = 0.5


func _init(profile: Dictionary = {}) -> void:
	aggression = clampf(float(profile.get("agresividad", 0.5)), 0.0, 1.0)
	cunning = clampf(float(profile.get("astucia", 0.5)), 0.0, 1.0)


func choose_order(battle: Battle, unit: Unit) -> Orders.Order:
	var info := battle.nearest_enemy(unit.side, unit.lane)
	var foe: Unit = info["unidad"]
	var legal := Orders.available_for(unit.kind)

	# Nothing left to fight: close ranks and get your breath back.
	if foe == null:
		return Orders.Order.MANTENER if unit.fatigue < 50.0 else Orders.Order.REPLEGAR

	var scores := {}
	for o in legal:
		scores[o] = _score(unit, foe, o)
	return _pick(battle, scores)


func _score(unit: Unit, foe: Unit, order: Orders.Order) -> float:
	var mine := UnitKind.counter(unit.kind, foe.kind)     # >1 means I beat them
	var theirs := UnitKind.counter(foe.kind, unit.kind)   # >1 means they beat me
	var edge := mine - theirs
	var score := 1.0

	match order:
		Orders.Order.CARGAR:
			score = 1.0 + aggression * 1.5
			score += edge * 2.0 * cunning
			# Charging fresh is fine; charging exhausted is how armies die.
			score -= maxf(0.0, unit.fatigue - 50.0) / 25.0 * cunning
			score -= maxf(0.0, 60.0 - unit.morale) / 20.0 * cunning
			# Never charge braced spears if you know better.
			if foe.kind == UnitKind.Kind.PEONES and foe.order == Orders.Order.MANTENER:
				score -= 2.0 * cunning

		Orders.Order.AVANZAR:
			score = 1.2 + aggression * 0.6
			score += edge * cunning

		Orders.Order.MANTENER:
			score = 1.0 + (1.0 - aggression) * 0.8
			score -= edge * cunning            # Holding is for when you're outmatched.
			score += unit.fatigue / 40.0 * cunning
			# Spearmen expecting horse should plant themselves.
			if unit.kind == UnitKind.Kind.PEONES and foe.kind == UnitKind.Kind.CABALLERIA:
				score += 2.0 * cunning

		Orders.Order.HOSTIGAR:
			score = 1.4
			score += mine * cunning            # Shoot the target you're good against.
			score -= aggression * 0.4
			# Missile troops with cavalry on top of them must not stand and shoot.
			if foe.kind == UnitKind.Kind.CABALLERIA:
				score -= 2.0 * cunning

		Orders.Order.REPLEGAR:
			score = 0.4
			score += maxf(0.0, 45.0 - unit.morale) / 12.0 * cunning
			score += maxf(0.0, unit.fatigue - 70.0) / 15.0 * cunning
			score -= aggression * 0.8
			# Light horse fight by pulling away and coming back.
			if unit.kind == UnitKind.Kind.JINETES and unit.fatigue > 40.0:
				score += 1.0 * cunning

	return maxf(0.05, score)


## Weighted pick. The floor of 0.05 above means even a bad order occasionally
## happens, which is what keeps the AI from being solvable.
func _pick(battle: Battle, scores: Dictionary) -> Orders.Order:
	var total := 0.0
	for o in scores:
		total += scores[o]
	var roll := battle.rng.randf() * total
	for o in scores:
		roll -= scores[o]
		if roll <= 0.0:
			return o
	return Orders.Order.MANTENER
