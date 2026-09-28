class_name Palette
extends RefCounted
## The illuminated-chronicle palette.
##
## Pulled from what a 13th-century Iberian scriptorium actually had on the
## bench: vellum, iron-gall ink, vermilion for the rubrics, lapis for the
## expensive blue, gold leaf for anything royal. Sticking to these six keeps
## screens looking like one object even as art gets swapped in.

const PERGAMINO := Color("e8dcc0")
const PERGAMINO_OSCURO := Color("d4c39c")
const HUESO := Color("f4ecd8")
const TINTA := Color("2b2118")
const TINTA_SUAVE := Color("5f4c39")
const ORO := Color("b8860b")
const RUBRICA := Color("9c2b1b")
const LAPIS := Color("26456e")
const VERDE := Color("4a6b45")

## Morale reads red as it falls — the one place colour carries a number.
static func morale_color(pct: float) -> Color:
	if pct >= 60.0:
		return VERDE
	if pct >= 35.0:
		return ORO
	return RUBRICA


static func side_color(side: int) -> Color:
	return LAPIS if side == 0 else RUBRICA


static func panel_style(fill: Color, border: Color, width: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


## Flat bar with an inked outline, used for morale and fatigue.
static func bar_styles(fill: Color) -> Array[StyleBoxFlat]:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(TINTA, 0.12)
	bg.border_color = Color(TINTA, 0.45)
	bg.set_border_width_all(1)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	return [bg, fg]
