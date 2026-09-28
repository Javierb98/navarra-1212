class_name ChronicleUI
extends RefCounted
## Builders for the manuscript look.
##
## Every screen is assembled from these rather than laid out in the editor, so
## the styling lives in exactly one place while the art direction is still
## moving. If you later want to build screens visually in the editor, keep
## calling `page()` for the ground and the rest will still match.

const PARCHMENT_SHADER := "res://shaders/parchment.gdshader"


## Full-bleed parchment ground. Call once per screen, first thing.
static func page(root: Control) -> void:
	var bg := ColorRect.new()
	bg.name = "Pergamino"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Palette.PERGAMINO
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shader := load(PARCHMENT_SHADER)
	if shader != null:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("base_color", Palette.PERGAMINO)
		mat.set_shader_parameter("stain_color", Palette.PERGAMINO_OSCURO)
		bg.material = mat

	root.add_child(bg)
	root.move_child(bg, 0)


## Screen margins, so nothing sits in the bleed on a CRT or an overscanned TV.
static func margins(left := 48, top := 32) -> MarginContainer:
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left", left)
	m.add_theme_constant_override("margin_right", left)
	m.add_theme_constant_override("margin_top", top)
	m.add_theme_constant_override("margin_bottom", top)
	return m


static func label(text: String, size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	return l


static func heading(text: String, size := 40) -> Label:
	return label(text, size, Palette.TINTA)


## Rubricated line — in a real manuscript the red ink marked the headings.
static func rubric(text: String, size := 22) -> Label:
	return label(text, size, Palette.RUBRICA)


static func body(text: String, size := 17, color := Palette.TINTA_SUAVE) -> Label:
	var l := label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func rule(color := Palette.ORO, thickness := 2) -> Control:
	var r := ColorRect.new()
	r.color = color
	r.custom_minimum_size = Vector2(0, thickness)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return r


static func spacer(height: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c


static func panel(fill := Palette.HUESO, border := Palette.ORO) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Palette.panel_style(Color(fill, 0.55), border))
	return p


static func bar(value: float, maximum: float, fill: Color, width := 150) -> ProgressBar:
	var b := ProgressBar.new()
	b.max_value = maxf(1.0, maximum)
	b.value = value
	b.show_percentage = false
	b.custom_minimum_size = Vector2(width, 10)
	var styles := Palette.bar_styles(fill)
	b.add_theme_stylebox_override("background", styles[0])
	b.add_theme_stylebox_override("fill", styles[1])
	return b


## The control-panel legend that sits along the bottom of every screen.
static func hints(entries: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	for e in entries:
		row.add_child(label(str(e), 14, Color(Palette.TINTA_SUAVE, 0.85)))
	return row


static func vbox(separation := 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", separation)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return v


static func hbox(separation := 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", separation)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return h
