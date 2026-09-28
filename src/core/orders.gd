class_name Orders
extends RefCounted
## The five orders a captain can give a company each round.
##
## This is the whole player-facing decision space, and it is deliberately tiny
## — an arcade player has to read it from two metres away with a joystick in
## their hand. Depth comes from the interaction with unit type, fatigue and the
## enemy's simultaneous choice, not from menu breadth.

enum Order { MANTENER, AVANZAR, CARGAR, HOSTIGAR, REPLEGAR }

## atk/def are damage multipliers. fatigue is the per-round delta.
## morale is the per-round recovery (negative values would drain).
const PROFILE := {
	# Holding recovers only a little nerve. It used to recover a lot, which made
	# standing still the answer to every question — see docs/DISENO.md on why
	# recovery belongs to REPLEGAR instead.
	Order.MANTENER: {
		"key": "ORDER_MANTENER", "desc": "ORDER_MANTENER_DESC",
		"atk": 0.60, "def": 1.40, "fatigue": -8.0, "morale": 2.5,
	},
	Order.AVANZAR: {
		"key": "ORDER_AVANZAR", "desc": "ORDER_AVANZAR_DESC",
		"atk": 1.00, "def": 1.00, "fatigue": 6.0, "morale": 0.0,
	},
	Order.CARGAR: {
		"key": "ORDER_CARGAR", "desc": "ORDER_CARGAR_DESC",
		"atk": 1.70, "def": 0.70, "fatigue": 18.0, "morale": 2.0,
	},
	Order.HOSTIGAR: {
		"key": "ORDER_HOSTIGAR", "desc": "ORDER_HOSTIGAR_DESC",
		"atk": 0.90, "def": 1.20, "fatigue": 4.0, "morale": 0.0,
	},
	Order.REPLEGAR: {
		"key": "ORDER_REPLEGAR", "desc": "ORDER_REPLEGAR_DESC",
		"atk": 0.00, "def": 0.80, "fatigue": -14.0, "morale": 10.0,
	},
}

## Spear infantry bracing for a charge is the single most important
## interaction in the game, so it gets an explicit rule rather than falling out
## of the multipliers: MANTENER against an incoming CARGAR doubles the
## defender's advantage.
const BRACE_BONUS := 2.0


static func all() -> Array:
	return [Order.MANTENER, Order.AVANZAR, Order.CARGAR, Order.HOSTIGAR, Order.REPLEGAR]


## Orders this troop type is allowed to receive. Only missile troops skirmish.
static func available_for(kind: UnitKind.Kind) -> Array:
	var out := []
	for o in all():
		if o == Order.HOSTIGAR and not UnitKind.is_ranged(kind):
			continue
		out.append(o)
	return out


static func name_key(o: Order) -> String:
	return PROFILE[o]["key"]


static func desc_key(o: Order) -> String:
	return PROFILE[o]["desc"]


static func atk(o: Order) -> float:
	return PROFILE[o]["atk"]


static func def(o: Order) -> float:
	return PROFILE[o]["def"]


static func fatigue_delta(o: Order) -> float:
	return PROFILE[o]["fatigue"]


static func morale_delta(o: Order) -> float:
	return PROFILE[o]["morale"]


## Does this order close with the enemy in melee?
static func is_aggressive(o: Order) -> bool:
	return o == Order.AVANZAR or o == Order.CARGAR


## Does this order give ground?
static func cedes_ground(o: Order) -> bool:
	return o == Order.REPLEGAR
