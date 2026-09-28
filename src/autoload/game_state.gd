extends Node
## Campaign progress and scene routing.
##
## An arcade session ("partida") is short: pick a battle, fight it, see the
## chronicle page, back to the map. Progress across sessions — which battles
## have been cleared and the best result on each — persists on the cabinet.

signal progress_changed

const SAVE_PATH := "user://progreso.cfg"

const SCENES := {
	"attract": "res://scenes/attract.tscn",
	"campaign": "res://scenes/campaign.tscn",
	"briefing": "res://scenes/briefing.tscn",
	"battle": "res://scenes/battle.tscn",
	"aftermath": "res://scenes/aftermath.tscn",
}

## Campaign order. Each id maps to data/battles/<id>.json.
const CAMPAIGN := [
	"roncesvalles_778",
	"roncesvalles_824",
	"valdejunquera_920",
	"najera_923",
	"atapuerca_1054",
	"tudela_1119",
	"navas_de_tolosa_1212",
]

## id -> {"cleared": bool, "best_score": int, "best_survivors": int}
var records: Dictionary = {}

## Set by the briefing screen, consumed by the battle screen.
var pending_scenario: Scenario = null
## Set by the battle screen, consumed by the aftermath screen.
var last_result: Dictionary = {}

func _ready() -> void:
	load_progress()


func is_unlocked(id: String) -> bool:
	var i := CAMPAIGN.find(id)
	if i <= 0:
		return true  # The first battle is always available.
	return record_for(CAMPAIGN[i - 1]).get("cleared", false)


func record_for(id: String) -> Dictionary:
	return records.get(id, {"cleared": false, "best_score": 0, "best_survivors": 0})


func submit_result(id: String, result: Dictionary) -> void:
	var rec := record_for(id)
	if result.get("victory", false):
		rec["cleared"] = true
	rec["best_score"] = maxi(rec.get("best_score", 0), int(result.get("score", 0)))
	rec["best_survivors"] = maxi(rec.get("best_survivors", 0), int(result.get("survivors", 0)))
	records[id] = rec
	save_progress()
	progress_changed.emit()


func goto(scene_key: String) -> void:
	assert(SCENES.has(scene_key), "escena desconocida: %s" % scene_key)
	get_tree().change_scene_to_file(SCENES[scene_key])


func load_progress() -> void:
	var f := ConfigFile.new()
	if f.load(SAVE_PATH) != OK:
		return
	for id in f.get_section_keys("records") if f.has_section("records") else []:
		records[id] = f.get_value("records", id, {})


func save_progress() -> void:
	var f := ConfigFile.new()
	for id in records:
		f.set_value("records", id, records[id])
	f.save(SAVE_PATH)


## Wipes progress — exposed for the cabinet's service menu.
func reset_progress() -> void:
	records.clear()
	save_progress()
	progress_changed.emit()
