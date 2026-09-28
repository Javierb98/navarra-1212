class_name Battle
extends RefCounted
## The battle resolution engine.
##
## Both sides commit orders for the round, then everything resolves at once —
## no initiative, no turn order. You are guessing what the enemy captain will
## do, which is the interesting decision, and it means the AI never gets to
## react to your choice after seeing it.
##
## The engine is deterministic given a seed and touches no scene tree, so it
## runs headless. tests/test_battle.gd exercises it that way.

signal round_resolved(events: Array)
signal battle_ended(result: Dictionary)

## How hard casualties bite into morale. Raise it and battles get shorter and
## more brittle; lower it and they grind. 1.35 puts a typical clash at five to
## seven rounds, which is about right for a coin-op sitting.
const SHOCK := 1.35

## The day wearing on. Without this, two armies that both play carefully settle
## into a plateau where regeneration cancels casualties and the battle simply
## runs out of rounds — which is neither good history nor a good arcade game.
## From the fourth round on, standing in the line costs everyone nerve, and the
## cost grows. It forces a decision and it rewards winning quickly.
const WEARINESS_FROM_ROUND := 3
const WEARINESS_PER_ROUND := 0.9

const FLANK_BONUS := 1.25
const ROUT_SHOCK_SAME_LANE := 12.0
const ROUT_SHOCK_ADJACENT := 8.0
const ROUT_SHOCK_ARMY := 4.0

const SIDE_PLAYER := 0
const SIDE_ENEMY := 1

var scenario: Scenario
var units: Array[Unit] = []
var round_number: int = 1
var chronicle: Array = []
var finished: bool = false
var result: Dictionary = {}

var ability_used: bool = false
var ability_active: bool = false

## Events raised between rounds (the commander's ability), flushed into the
## next round's log so the chronicle panel shows them in order.
var _pending_events: Array = []

var rng := RandomNumberGenerator.new()
var _ai: BattleAI


func _init(s: Scenario, seed_value: int = 0) -> void:
	scenario = s
	rng.seed = seed_value if seed_value != 0 else randi()
	_ai = BattleAI.new(s.ai_profile)
	for d in s.player_units:
		units.append(Unit.make(d, SIDE_PLAYER))
	for d in s.enemy_units:
		units.append(Unit.make(d, SIDE_ENEMY))


# ---------------------------------------------------------------- queries ---

func units_of(side: int) -> Array[Unit]:
	var out: Array[Unit] = []
	for u in units:
		if u.side == side:
			out.append(u)
	return out


func active_units(side: int) -> Array[Unit]:
	var out: Array[Unit] = []
	for u in units:
		if u.side == side and u.is_active():
			out.append(u)
	return out


func find_unit(unit_id: String) -> Unit:
	for u in units:
		if u.id == unit_id:
			return u
	return null


## The company currently holding a wing — the first one still standing.
func front_unit(side: int, lane: int) -> Unit:
	for u in units:
		if u.side == side and u.lane == lane and u.is_active():
			return u
	return null


## Nearest wing that still has somebody in it, for units whose own wing has
## nothing left to fight. Attacking out of your lane is how flanking happens.
func nearest_enemy(side: int, lane: int) -> Dictionary:
	var enemy_side := 1 - side
	var direct := front_unit(enemy_side, lane)
	if direct != null:
		return {"unidad": direct, "flanqueo": false}
	for dist in [1, 2]:
		for l in [lane - dist, lane + dist]:
			if l < 0 or l > 2:
				continue
			var u := front_unit(enemy_side, l)
			if u != null:
				return {"unidad": u, "flanqueo": true}
	return {"unidad": null, "flanqueo": false}


func army_morale(side: int) -> float:
	var total := 0.0
	var weight := 0.0
	for u in units_of(side):
		weight += float(u.initial_strength)
		if u.is_active():
			total += u.morale * float(u.initial_strength)
	return total / maxf(1.0, weight)


func army_strength(side: int) -> int:
	var n := 0
	for u in units_of(side):
		if u.is_active():
			n += u.strength
	return n


func is_broken(side: int) -> bool:
	return active_units(side).is_empty() \
		or army_morale(side) < scenario.break_threshold_for(side)


# --------------------------------------------------------------- commands ---

## One-shot commander ability. Effects last for the round it is spent on;
## "moral" is the exception and lands immediately, because a rally the player
## cannot see is a rally they will not believe in.
func activate_ability() -> bool:
	if ability_used or finished:
		return false
	ability_used = true
	var effect: String = scenario.commander.get("efecto", "moral")
	if effect == "moral":
		for u in active_units(SIDE_PLAYER):
			u.change_morale(30.0)
	else:
		ability_active = true
	_pending_events.append({
		"clave": "EV_HABILIDAD",
		"args": [scenario.commander.get("nombre", ""), scenario.commander.get("habilidad", "")],
		"ronda": round_number,
	})
	return true


func _ability_effect() -> String:
	return scenario.commander.get("efecto", "moral") if ability_active else ""


func _ability_atk_mod(u: Unit) -> float:
	if u.side != SIDE_PLAYER:
		return 1.0
	match _ability_effect():
		"carga":
			return 1.6 if u.order == Orders.Order.CARGAR else 1.0
		"emboscada":
			return 2.0
	return 1.0


func _ability_def_mod(u: Unit) -> float:
	if u.side != SIDE_PLAYER:
		return 1.0
	return 1.8 if _ability_effect() == "muro" else 1.0


# --------------------------------------------------------------- the round ---

## player_orders maps unit id -> Orders.Order. Units left out keep MANTENER.
func resolve_round(player_orders: Dictionary) -> Array:
	if finished:
		return []

	var events: Array = _pending_events.duplicate()
	_pending_events.clear()
	for u in active_units(SIDE_PLAYER):
		u.order = player_orders.get(u.id, Orders.Order.MANTENER)
	for u in active_units(SIDE_ENEMY):
		u.order = _ai.choose_order(self, u)

	_log_to("EV_RONDA", [round_number], events)
	_missile_phase(events)
	_melee_phase(events)
	_upkeep(events)
	_rout_checks(events)
	_check_end(events)

	ability_active = false
	round_number += 1
	chronicle.append_array(events)
	round_resolved.emit(events)
	if finished:
		battle_ended.emit(result)
	return events


## Crossbows and javelins strike before anyone closes, and take nothing back.
func _missile_phase(events: Array) -> void:
	for u in active_units(SIDE_PLAYER) + active_units(SIDE_ENEMY):
		if u.order != Orders.Order.HOSTIGAR or not UnitKind.is_ranged(u.kind):
			continue
		var target_info := nearest_enemy(u.side, u.lane)
		var target: Unit = target_info["unidad"]
		if target == null:
			continue
		var dmg := _compute_damage(u, target, target_info["flanqueo"], true)
		_apply_damage(target, dmg, events, "EV_DISPARO", u)


## Wings clash one against one. Whoever is behind the front rank waits their
## turn — companies feed into the line as the ones ahead of them break.
func _melee_phase(events: Array) -> void:
	for lane in 3:
		var p := front_unit(SIDE_PLAYER, lane)
		var e := front_unit(SIDE_ENEMY, lane)
		if p != null and e != null:
			_engage(p, e, false, events)
			continue
		# An unopposed wing wheels into whatever it can reach.
		for u in [p, e]:
			if u == null or not Orders.is_aggressive(u.order):
				continue
			var info := nearest_enemy(u.side, u.lane)
			var target: Unit = info["unidad"]
			if target != null:
				_engage(u, target, true, events)


## Simultaneous exchange: both damages come from the pre-strike state, so
## neither side benefits from being resolved first.
func _engage(a: Unit, b: Unit, flanking: bool, events: Array) -> void:
	var a_fights := Orders.is_aggressive(a.order) or Orders.is_aggressive(b.order)
	var b_fights := a_fights
	if Orders.cedes_ground(a.order):
		a_fights = false
	if Orders.cedes_ground(b.order):
		b_fights = false
	if not a_fights and not b_fights:
		return  # Two lines watching each other across the field.

	var dmg_to_b := _compute_damage(a, b, flanking) if a_fights else {"bajas": 0, "choque": 0.0}
	var dmg_to_a := _compute_damage(b, a, false) if b_fights else {"bajas": 0, "choque": 0.0}

	# Pursuing a company that is pulling out only catches its stragglers.
	if Orders.cedes_ground(b.order):
		dmg_to_b["bajas"] = int(dmg_to_b["bajas"] * 0.5)
		dmg_to_b["choque"] *= 0.5
	if Orders.cedes_ground(a.order):
		dmg_to_a["bajas"] = int(dmg_to_a["bajas"] * 0.5)
		dmg_to_a["choque"] *= 0.5

	var key := "EV_FLANQUEO" if flanking else "EV_CHOQUE"
	if dmg_to_b["bajas"] > 0 or dmg_to_b["choque"] > 0.0:
		_apply_damage(b, dmg_to_b, events, key, a)
	if dmg_to_a["bajas"] > 0 or dmg_to_a["choque"] > 0.0:
		_apply_damage(a, dmg_to_a, events, key, b)


func _compute_damage(a: Unit, d: Unit, flanking: bool, missile: bool = false) -> Dictionary:
	var eff := a.effective_strength()
	if eff <= 0.0:
		return {"bajas": 0, "choque": 0.0}

	var raw := eff / 100.0 * float(UnitKind.stat(a.kind, "power")) * a.power_mod
	raw *= Orders.atk(a.order)
	# A company that spent the round shooting is in no shape to brawl when
	# somebody reaches it — otherwise HOSTIGAR would pay twice in one round.
	if not missile and a.order == Orders.Order.HOSTIGAR:
		raw *= 0.35
	raw *= UnitKind.counter(a.kind, d.kind)
	raw *= scenario.terrain_mod_for(a.kind) * scenario.terrain_mod_for_lane(a.lane)
	raw *= _ability_atk_mod(a)
	if flanking:
		raw *= FLANK_BONUS

	var defense := float(UnitKind.stat(d.kind, "toughness")) * Orders.def(d.order) * _ability_def_mod(d)
	# Braced spears against a charge: the rule the whole triangle rests on.
	if d.order == Orders.Order.MANTENER and a.order == Orders.Order.CARGAR \
			and d.kind == UnitKind.Kind.PEONES:
		defense *= Orders.BRACE_BONUS

	var losses := int(round(raw / maxf(0.2, defense) * rng.randf_range(0.85, 1.15)))
	losses = mini(losses, d.strength)
	var shock := float(losses) / maxf(1.0, float(d.initial_strength)) * 100.0 \
			* SHOCK / float(UnitKind.stat(d.kind, "discipline"))
	return {"bajas": losses, "choque": shock}


func _apply_damage(target: Unit, dmg: Dictionary, events: Array, key: String, source: Unit) -> void:
	var was_active := target.is_active()
	var losses := int(dmg["bajas"])
	target.take_casualties(losses)
	target.change_morale(-float(dmg["choque"]))
	# Events carry ids as well as names: the chronicle panel wants the names,
	# but the battlefield needs to know which company on screen to animate.
	_log_to(key, [source.name_text, target.name_text, losses], events,
		{"origen": source.id, "destino": target.id, "bajas": losses})
	if was_active and not target.is_active():
		_log_to("EV_ROTA", [target.name_text], events, {"destino": target.id})


## Orders cost or restore stamina and nerve regardless of what happened.
func _upkeep(events: Array) -> void:
	var weariness := maxf(0.0, float(round_number - WEARINESS_FROM_ROUND)) * WEARINESS_PER_ROUND
	for u in units:
		if not u.is_active():
			continue
		u.change_fatigue(Orders.fatigue_delta(u.order))
		u.change_morale(Orders.morale_delta(u.order) - weariness)
		# Exhausted men lose heart on their own.
		if u.fatigue >= 90.0:
			u.change_morale(-4.0)
			_log_to("EV_AGOTAMIENTO", [u.name_text], events)


## A company breaking takes the nerve of everyone who watched it go.
func _rout_checks(events: Array) -> void:
	for u in units:
		if u.is_active() or u.get_meta("rout_counted", false):
			continue
		u.set_meta("rout_counted", true)
		for other in active_units(u.side):
			var shock := ROUT_SHOCK_ARMY
			if other.lane == u.lane:
				shock = ROUT_SHOCK_SAME_LANE
			elif absi(other.lane - u.lane) == 1:
				shock = ROUT_SHOCK_ADJACENT
			other.change_morale(-shock)


func _check_end(events: Array) -> void:
	var player_broken := is_broken(SIDE_PLAYER)
	var enemy_broken := is_broken(SIDE_ENEMY)
	var victory := false
	var reason := ""

	if enemy_broken:
		victory = true
		reason = "END_ENEMIGO_ROTO"
	elif scenario.goal == Scenario.Goal.OBJETIVO_UNIDAD:
		var target := find_unit(scenario.goal_unit_id)
		if target != null and not target.is_active():
			victory = true
			reason = "END_OBJETIVO"
	if not victory and player_broken:
		finished = true
		reason = "END_EJERCITO_ROTO"
	elif not victory and round_number >= scenario.max_rounds:
		finished = true
		if scenario.goal == Scenario.Goal.SOBREVIVIR and not player_broken:
			victory = true
			reason = "END_RESISTIDO"
		else:
			reason = "END_SIN_TIEMPO"
	elif scenario.goal == Scenario.Goal.SOBREVIVIR and round_number >= scenario.goal_value \
			and not player_broken:
		finished = true
		victory = true
		reason = "END_RESISTIDO"
	elif victory:
		finished = true

	if not finished:
		return

	result = _build_result(victory, reason)
	_log_to(reason, [], events)


func _build_result(victory: bool, reason: String) -> Dictionary:
	var survivors := army_strength(SIDE_PLAYER)
	var own_losses := 0
	var enemy_losses := 0
	for u in units_of(SIDE_PLAYER):
		own_losses += u.casualties()
	for u in units_of(SIDE_ENEMY):
		enemy_losses += u.casualties()

	var score := enemy_losses + survivors * 2
	score += maxi(0, scenario.max_rounds - round_number) * 50
	if victory:
		score += 1000

	return {
		"victoria": victory,
		"victory": victory,  # English alias; GameState.submit_result reads this.
		"motivo": reason,
		"rondas": round_number,
		"survivors": survivors,
		"supervivientes": survivors,
		"bajas_propias": own_losses,
		"bajas_enemigas": enemy_losses,
		"score": score,
		"moral_final": army_morale(SIDE_PLAYER),
		"escenario": scenario.id,
	}


# ------------------------------------------------------------------- log ---

func _log_to(key: String, args: Array, events: Array, extra: Dictionary = {}) -> void:
	var event := {"clave": key, "args": args, "ronda": round_number}
	event.merge(extra)
	events.append(event)
