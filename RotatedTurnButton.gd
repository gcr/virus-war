@tool
extends Button

@export var flipped: bool = false
enum Glyph {X, O}
@export var glyph: Glyph = Glyph.X
@export var glyph_offset: float = 0.0
@export var label_offset: float = 0.0

func _draw() -> void:
	var turn_string = "Swap Turn"
	var sz = get_theme_default_font_size()
	var h = get_rect().size.y
	var w = get_rect().size.x
	var c = get_theme_color("font_pressed_color" if button_pressed else "font_color")
	var f = get_theme_font("font")
	var xw = h/6
	var sign = 1.0
	if flipped:
		draw_set_transform(Vector2(w, h), PI, Vector2.ONE)
		sign = -1.0
	draw_string(
		f,
		Vector2(label_offset, h/2 + f.get_height()), # + f.get_height()/2),
		turn_string,
		HORIZONTAL_ALIGNMENT_CENTER,
		get_rect().size.x-label_offset,
		sz,
		c)

	var glyph_center = Vector2(w/2 - f.get_string_size(turn_string, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x/2- glyph_offset, h/2)
	if glyph == Glyph.X:
		draw_line(glyph_center + Vector2(xw,xw), glyph_center + Vector2(-xw, -xw), c, 1, true)
		draw_line(glyph_center + Vector2(-xw,xw), glyph_center + Vector2(xw, -xw), c, 1, true)
	else:
		draw_arc(glyph_center, xw, 0, TAU, 64, c, 1, true)
