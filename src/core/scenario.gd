class_name Scenario
extends RefCounted
## A battle, loaded from data/battles/<id>.json.
##
## Scenarios are plain JSON on purpose: the history is the content of this
## game, and it should be editable by someone with a book open and no interest
## in GDScript. See docs/HISTORIA.md for the sourcing rules, including how we
## mark the difference between what the chronicles record and what they only
## claim.

const DIR := "res://data/battles"

enum Goal { ROMPER, SOBREVIVIR, OBJETIVO_UNIDAD }

var id: String = ""
var year: int = 0
var title: String = ""
var place: String = ""
var date_text: String = ""
var summary: String = ""
var historical_note: String = ""
var caveat: String = ""          ## Legend-vs-record warning; may be empty.
var sources: Array = []

var player_faction: Dictionary = {}
var enemy_faction: Dictionary = {}
var commander: Dictionary = {}
var terrain: Dictionary = {}
var ai_profile: Dictionary = {}

var max_rounds: int = 10
var goal: Goal = Goal.ROMPER
var goal_value: int = 0
var goal_unit_id: String = ""
var break_threshold: float = 30.0
## Armies do not all break at the same point. A king's household stands when a
## coalition of unwilling levies would already be running, and at Las Navas the
## huge Almohad host came apart faster than the small Navarrese one. Leave
## unset to use the same figure for both sides.
var enemy_break_threshold: float = -1.0

var player_units: Array = []     ## Raw dictionaries; Unit.make() turns them into units.
var enemy_units: Array = []


static func path_for(scenario_id: String) -> String:
	return "%s/%s.json" % [DIR, scenario_id]


static func load_scenario(scenario_id: String) -> Scenario:
	var path := path_for(scenario_id)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Scenario: no se puede abrir %s" % path)
		return null
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Scenario: JSON inválido en %s" % path)
		return null
	return from_dict(parsed)


static func from_dict(d: Dictionary) -> Scenario:
	var s := Scenario.new()
	s.id = d.get("id", "")
	s.year = int(d.get("anio", 0))
	s.title = d.get("titulo", "")
	s.place = d.get("lugar", "")
	s.date_text = d.get("fecha", "")
	s.summary = d.get("resumen", "")
	s.historical_note = d.get("nota_historica", "")
	s.caveat = d.get("advertencia", "")
	s.sources = d.get("fuentes", [])

	s.player_faction = d.get("bando_jugador", {})
	s.enemy_faction = d.get("bando_enemigo", {})
	s.commander = d.get("comandante", {})
	s.terrain = d.get("terreno", {})
	s.ai_profile = d.get("ia", {"agresividad": 0.5, "astucia": 0.5})

	s.max_rounds = int(d.get("rondas_max", 10))
	s.break_threshold = float(d.get("umbral_ruptura", 30.0))
	s.enemy_break_threshold = float(d.get("umbral_ruptura_enemigo", -1.0))

	var obj: Dictionary = d.get("objetivo", {})
	match obj.get("tipo", "romper"):
		"sobrevivir": s.goal = Goal.SOBREVIVIR
		"objetivo_unidad": s.goal = Goal.OBJETIVO_UNIDAD
		_: s.goal = Goal.ROMPER
	s.goal_value = int(obj.get("valor", 0))
	s.goal_unit_id = obj.get("unidad", "")

	s.player_units = d.get("unidades_jugador", [])
	s.enemy_units = d.get("unidades_enemigo", [])
	return s


## Attack multiplier this battlefield grants a troop type — the pass at
## Roncesvalles is death to horsemen, the plain at Valdejunquera is a gift.
func terrain_mod_for(kind: UnitKind.Kind) -> float:
	var mods: Dictionary = terrain.get("mods", {})
	return float(mods.get(UnitKind.to_string_id(kind), 1.0))


## Per-wing multiplier: [left, centre, right].
func terrain_mod_for_lane(lane: int) -> float:
	var lanes: Array = terrain.get("alas", [1.0, 1.0, 1.0])
	if lane < 0 or lane >= lanes.size():
		return 1.0
	return float(lanes[lane])


## Army morale below which this side quits the field.
func break_threshold_for(side: int) -> float:
	if side == 1 and enemy_break_threshold >= 0.0:
		return enemy_break_threshold
	return break_threshold


func goal_key() -> String:
	match goal:
		Goal.SOBREVIVIR: return "GOAL_SOBREVIVIR"
		Goal.OBJETIVO_UNIDAD: return "GOAL_OBJETIVO_UNIDAD"
		_: return "GOAL_ROMPER"
