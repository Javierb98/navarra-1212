class_name UnitKind
extends RefCounted
## The troop types and how they beat each other.
##
## The spine is a rock-paper-scissors triangle, exactly as in 1066:
##
##     peones (spears)  stop  caballería (heavy horse)
##     caballería       ride down  ballesteros (crossbows)
##     ballesteros      shred  peones
##
## Two extra types sit off the triangle to give the later scenarios their own
## texture: almogávares (light mountain infantry, murder on broken ground) and
## jinetes (Andalusi light horse, who fight by withdrawing). Both are
## deliberately weaker head-on than the core three — they are situational, not
## upgrades. See docs/DISENO.md.

enum Kind { PEONES, BALLESTEROS, CABALLERIA, ALMOGAVARES, JINETES }

## Display key (translated) and raw combat profile.
##   power      — casualties inflicted per 100 effective men
##   toughness  — incoming damage divisor
##   discipline — morale-shock divisor; high means they take a beating quietly
##   ranged     — may use the HOSTIGAR (skirmish) order
const STATS := {
	Kind.PEONES: {
		"key": "UNIT_PEONES", "power": 10.0, "toughness": 1.00,
		"discipline": 0.90, "ranged": false,
	},
	Kind.BALLESTEROS: {
		"key": "UNIT_BALLESTEROS", "power": 12.0, "toughness": 0.75,
		"discipline": 0.80, "ranged": true,
	},
	Kind.CABALLERIA: {
		"key": "UNIT_CABALLERIA", "power": 16.0, "toughness": 1.25,
		"discipline": 1.10, "ranged": false,
	},
	Kind.ALMOGAVARES: {
		"key": "UNIT_ALMOGAVARES", "power": 13.0, "toughness": 0.85,
		"discipline": 1.00, "ranged": false,
	},
	Kind.JINETES: {
		"key": "UNIT_JINETES", "power": 11.0, "toughness": 0.90,
		"discipline": 0.85, "ranged": true,
	},
}

## COUNTER[attacker][defender] — a straight damage multiplier.
const COUNTER := {
	Kind.PEONES: {
		Kind.PEONES: 1.00, Kind.BALLESTEROS: 1.15, Kind.CABALLERIA: 1.50,
		Kind.ALMOGAVARES: 1.10, Kind.JINETES: 1.20,
	},
	Kind.BALLESTEROS: {
		Kind.PEONES: 1.45, Kind.BALLESTEROS: 1.00, Kind.CABALLERIA: 0.75,
		Kind.ALMOGAVARES: 1.20, Kind.JINETES: 1.05,
	},
	Kind.CABALLERIA: {
		Kind.PEONES: 0.70, Kind.BALLESTEROS: 1.60, Kind.CABALLERIA: 1.00,
		Kind.ALMOGAVARES: 0.80, Kind.JINETES: 1.35,
	},
	Kind.ALMOGAVARES: {
		Kind.PEONES: 0.85, Kind.BALLESTEROS: 1.20, Kind.CABALLERIA: 1.30,
		Kind.ALMOGAVARES: 1.00, Kind.JINETES: 1.15,
	},
	Kind.JINETES: {
		Kind.PEONES: 0.80, Kind.BALLESTEROS: 1.30, Kind.CABALLERIA: 0.70,
		Kind.ALMOGAVARES: 0.90, Kind.JINETES: 1.00,
	},
}

const _BY_NAME := {
	"peones": Kind.PEONES,
	"ballesteros": Kind.BALLESTEROS,
	"caballeria": Kind.CABALLERIA,
	"almogavares": Kind.ALMOGAVARES,
	"jinetes": Kind.JINETES,
}


static func from_string(s: String) -> Kind:
	var key := s.to_lower().strip_edges()
	assert(_BY_NAME.has(key), "tipo de unidad desconocido: %s" % s)
	return _BY_NAME.get(key, Kind.PEONES)


static func to_string_id(k: Kind) -> String:
	for name in _BY_NAME:
		if _BY_NAME[name] == k:
			return name
	return "peones"


static func stat(k: Kind, field: String) -> Variant:
	return STATS[k][field]


static func name_key(k: Kind) -> String:
	return STATS[k]["key"]


static func is_ranged(k: Kind) -> bool:
	return STATS[k]["ranged"]


static func counter(attacker: Kind, defender: Kind) -> float:
	return COUNTER[attacker][defender]
