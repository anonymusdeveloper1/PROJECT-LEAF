extends RefCounted
## Shared label and text-width helpers for the HUD parts (static). A part of the HUD (hud.gd).


static func label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(1, 1, 1))
	l.add_theme_color_override("font_outline_color", Color(0.12, 0.08, 0.05, 0.85))
	l.add_theme_constant_override("outline_size", maxi(6, size / 3))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## How wide a one-line label's text is.
static func text_w(l: Label) -> float:
	var f := l.get_theme_font("font")
	return f.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x + 4.0
