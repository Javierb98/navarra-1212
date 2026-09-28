class_name Unit
extends RefCounted
## One company on the field.
##
## Men die, but companies are broken rather than annihilated — morale is the
## real health bar, and a unit that routs is out of the battle with most of its
## strength still walking. That is the 1066 lesson and it happens to be the
## historically honest one.

enum State { FIRME, VACILANTE, HUIDO }  ## steady / wavering / routed

var id: String = ""
var name_text: String = ""       ## Already-localised display name from the scenario.
var kind: UnitKind.Kind = UnitKind.Kind.PEONES
var lane: int = 1                ## 0 left, 1 centre, 2 right.
var side: int = 0                ## 0 player, 1 enemy.

var strength: int = 100          ## Men still in the ranks.
var initial_strength: int = 100
var morale: float = 100.0
var fatigue: float = 0.0
var state: State = State.FIRME
var order: Orders.Order = Orders.Order.MANTENER

## Scenario-granted tweaks, e.g. veterans or levies raised that morning.
var power_mod: float = 1.0
var morale_mod: float = 1.0


static func make(data: Dictionary, unit_side: int) -> Unit:
	var u := Unit.new()
	u.id = data.get("id", "u%d" % randi())
	u.name_text = data.get("nombre", "")
	u.kind = UnitKind.from_string(data.get("tipo", "peones"))
	u.lane = int(data.get("ala", 1))
	u.side = unit_side
	u.strength = int(data.get("fuerza", 100))
	u.initial_strength = u.strength
	u.morale = float(data.get("moral", 100.0))
	u.power_mod = float(data.get("mod_ataque", 1.0))
	u.morale_mod = float(data.get("mod_moral", 1.0))
	u.order = Orders.Order.MANTENER
	return u


func is_active() -> bool:
	return state != State.HUIDO and strength > 0


## Fraction of nominal fighting value still available, folding in losses,
## morale and tiredness. This is what actually multiplies into damage.
func effective_strength() -> float:
	if not is_active():
		return 0.0
	var morale_factor := clampf(morale / 100.0, 0.0, 1.0) * 0.6 + 0.4
	var fatigue_factor := 1.0 - clampf(fatigue / 100.0, 0.0, 1.0) * 0.4
	return float(strength) * morale_factor * fatigue_factor


func casualties() -> int:
	return initial_strength - strength


func strength_ratio() -> float:
	if initial_strength <= 0:
		return 0.0
	return float(strength) / float(initial_strength)


func take_casualties(n: int) -> void:
	strength = maxi(0, strength - n)
	if strength == 0:
		state = State.HUIDO
		morale = 0.0


func change_morale(delta: float) -> void:
	if not is_active():
		return
	if delta < 0.0:
		delta /= maxf(0.25, morale_mod)
	else:
		delta *= morale_mod
	morale = clampf(morale + delta, 0.0, 100.0)
	_reassess()


func change_fatigue(delta: float) -> void:
	fatigue = clampf(fatigue + delta, 0.0, 100.0)


## Morale thresholds. A wavering unit still fights; a routed one is gone for
## good — there is no rallying in this game, which keeps the stakes of a
## collapsing wing legible at arcade speed.
func _reassess() -> void:
	if state == State.HUIDO:
		return
	if morale <= 0.0:
		state = State.HUIDO
	elif morale < 35.0:
		state = State.VACILANTE
	else:
		state = State.FIRME


func state_key() -> String:
	match state:
		State.FIRME: return "STATE_FIRME"
		State.VACILANTE: return "STATE_VACILANTE"
		_: return "STATE_HUIDO"


func snapshot() -> Dictionary:
	return {
		"id": id, "nombre": name_text, "tipo": UnitKind.to_string_id(kind),
		"ala": lane, "bando": side, "fuerza": strength,
		"fuerza_inicial": initial_strength, "moral": morale,
		"fatiga": fatigue, "estado": state, "orden": order,
	}
