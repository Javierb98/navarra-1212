extends Node
## Runtime string loader.
##
## Godot's normal path for translations is to import a CSV into binary
## .translation files. That works, but it means every text tweak is a two-step
## affair and the strings are invisible to `git diff`. Instead we parse
## i18n/strings.csv at boot and hand the result to the TranslationServer, so
## ordinary `tr("KEY")` works everywhere and the CSV is the single source of
## truth.
##
## CSV shape:  keys,es,en

const CSV_PATH := "res://i18n/strings.csv"

var _locales: PackedStringArray = []

func _ready() -> void:
	_load_csv()
	set_locale(Cfg.locale)


func available_locales() -> PackedStringArray:
	return _locales


func set_locale(code: String) -> void:
	if code in _locales:
		TranslationServer.set_locale(code)
		Cfg.locale = code


## Translate with positional substitution. The CSV uses {0}, {1}, … markers:
##   Loc.f("EV_CHOQUE", ["Mesnada del rey", "Guardia del califa", 42])
func f(key: String, args: Array) -> String:
	return tr(key).format(args)


func _load_csv() -> void:
	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	if file == null:
		push_error("Loc: no se encuentra %s" % CSV_PATH)
		return

	var header := file.get_csv_line()
	if header.size() < 2:
		push_error("Loc: cabecera CSV inválida")
		return

	# Column 0 is the key; every remaining column is a locale.
	var translations: Array[Translation] = []
	for i in range(1, header.size()):
		var t := Translation.new()
		t.locale = header[i].strip_edges()
		translations.append(t)
		_locales.append(t.locale)

	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() < 2 or row[0].strip_edges().is_empty():
			continue
		var key := row[0].strip_edges()
		for i in range(1, min(row.size(), header.size())):
			var value := row[i]
			if not value.is_empty():
				translations[i - 1].add_message(key, value)

	file.close()
	for t in translations:
		TranslationServer.add_translation(t)
