extends RefCounted
## H4: the parts the window kit added to the card's frame (the window kit; the frame itself is ui/hud/card.gd): a tab's
## icon, the small "!" dot on a tab, and the pinned footer with its words, price and buttons. The card keeps the
## footer's box (card.gd `foot`), clears the old footer and calls these when it fills a card; they only draw.
##   tab_icon(hud, button, icon, text)   the icon left of a tab's words (or alone, in the middle, when it has none)
##   tab_dot() -> Control                the "!" in a tab button's top right corner
##   footer(hud, f, rule) -> Control     the footer's contents, or null when f has nothing to show (see card.gd's top)
## Called by: card.gd (_fill_card_tabs, _fill_footer). Uses: the HUD's tile styles, fonts and price line (shop_tiles.gd)
## and its icons. `hud` is untyped, as in list_row.gd (its parts are read at run time). No class_name: preload it.

const ShopTiles := preload("res://ui/hud/shop_tiles.gd")   # the type of the HUD's tiles (hud.p_tiles)
const FOOT_BTN := Vector2(150, 64)      # a footer button's least size (a thumb wide and tall)
const TAB_ICON := 40.0                  # a tab's icon
const TAB_DOT := 24.0                   # the "!" dot on a tab


## A tab's icon, drawn left of its words (or alone, in the middle, when it has none): the button's own text gives way
## to a centred icon and label, and the button keeps room for both.
static func tab_icon(hud, button: Button, icon: Variant, text: String) -> void:
	button.text = ""
	var box := HBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 8)
	button.add_child(box)
	var pic := TextureRect.new()
	pic.texture = hud.icon(icon)
	pic.custom_minimum_size = Vector2(TAB_ICON, TAB_ICON)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(pic)
	var w := TAB_ICON + 28.0
	if text != "":
		var l := Label.new()
		l.text = text
		l.add_theme_font_size_override("font_size", 26)
		l.add_theme_color_override("font_color", Color(1, 1, 1))
		l.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.05, 0.8))
		l.add_theme_constant_override("outline_size", 6)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(l)
		w += 8.0 + ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	button.custom_minimum_size.x = w


## The owner's yes, 26 Nov 2026: the small "!" on a tab that has something you can buy, in the top right corner of its
## button; it looks like the marker's "!" dot (a coral disc with a cream rim and a white "!"). The tests find it by its
## meta "tab_dot".
static func tab_dot() -> Control:
	var d := Control.new()
	d.set_meta("tab_dot", true)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d.anchor_left = 1.0
	d.anchor_right = 1.0
	d.offset_left = -TAB_DOT - 6.0
	d.offset_right = -6.0
	d.offset_top = 6.0
	d.offset_bottom = 6.0 + TAB_DOT
	d.draw.connect(func() -> void:
		var c := d.size * 0.5
		var r := minf(d.size.x, d.size.y) * 0.5
		d.draw_circle(c, r, Color(1.0, 0.97, 0.89))
		d.draw_circle(c, r - 3.0, Color(0.96, 0.38, 0.24))
		d.draw_line(c + Vector2(0, -r * 0.52), c + Vector2(0, r * 0.12), Color(1, 1, 1), 4.0, true)
		d.draw_circle(c + Vector2(0, r * 0.46), 2.4, Color(1, 1, 1)))
	return d


## The pinned footer's contents: a thin line over it when `rule` (rows show above it), then its bold line, its note
## (up to 2 lines) and its price on the left, and its 0-2 buttons on the right (the last is the main one). Null when f
## has no words, no price and no buttons (the card then hides the footer).
static func footer(hud, f: Dictionary, rule: bool) -> Control:
	var tiles: ShopTiles = hud.p_tiles
	var text := String(f.get("text", ""))
	var note := String(f.get("note", ""))
	var cost := _dict(f.get("cost", {}))
	var bv: Variant = f.get("buttons", [])
	var buttons: Array = bv if bv is Array else []
	var priced: bool = tiles._price_kinds(cost) > 0
	if text == "" and note == "" and not priced and buttons.is_empty():
		return null
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if rule:
		var line := ColorRect.new()
		line.color = Color(0.56, 0.35, 0.17, 0.3)
		line.custom_minimum_size = Vector2(0, 2)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(line)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(h)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	words.add_theme_constant_override("separation", 2)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(words)
	if text != "":
		var t := Label.new()
		t.text = text
		t.add_theme_font_override("font", tiles._bold())
		t.add_theme_font_size_override("font_size", 24)
		t.add_theme_color_override("font_color", hud.TILE_INK)
		t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		t.clip_text = true
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		words.add_child(t)
	if note != "":
		var n := Label.new()
		n.text = note
		n.add_theme_font_size_override("font_size", 19)
		n.add_theme_color_override("font_color", Color(0.45, 0.36, 0.26))
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		n.max_lines_visible = 2
		n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		words.add_child(n)
	if priced:
		var room: float = tiles._list_w() - float(buttons.size()) * (FOOT_BTN.x + 12.0)
		var price: HBoxContainer = tiles._price_line(cost, maxf(room, 120.0))
		price.alignment = BoxContainer.ALIGNMENT_BEGIN
		words.add_child(price)
	for b: Variant in buttons:
		h.add_child(foot_button(hud, _dict(b)))
	return col


## One footer button: at least FOOT_BTN, in its tone (a name of shop_tiles.BTN; grey and off while disabled). The kit
## does not check the price (the window decides `enabled`); a press runs its action, then the card refreshes.
static func foot_button(hud, b: Dictionary) -> Button:
	var tiles: ShopTiles = hud.p_tiles
	var label := String(b.get("label", ""))
	var tone := String(b.get("tone", "green"))
	var on := bool(b.get("enabled", false))
	var act: Variant = b.get("action", Callable())
	var action: Callable = act if act is Callable else Callable()
	var btn := Button.new()
	btn.text = label
	btn.focus_mode = Control.FOCUS_NONE
	btn.disabled = not on
	btn.custom_minimum_size = FOOT_BTN
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.set_meta("label", label)
	btn.set_meta("footer", true)
	btn.add_theme_font_override("font", tiles._bold())
	btn.add_theme_font_size_override("font_size", 26)
	for st: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		btn.add_theme_color_override(st, Color(1, 1, 1))
	btn.add_theme_color_override("font_disabled_color", Color(0.98, 0.96, 0.92))
	btn.add_theme_color_override("font_outline_color", Color(0.1, 0.12, 0.05, 0.55))
	btn.add_theme_constant_override("outline_size", 5)
	for st: String in ["normal", "hover", "focus"]:
		btn.add_theme_stylebox_override(st, tiles._ui_style("btn_" + tone))
	btn.add_theme_stylebox_override("pressed", tiles._ui_style("btn_%s_down" % tone))
	btn.add_theme_stylebox_override("hover_pressed", tiles._ui_style("btn_%s_down" % tone))
	btn.add_theme_stylebox_override("disabled", tiles._ui_style("btn_off"))
	if on and action.is_valid():
		btn.pressed.connect(func() -> void:
			action.call()
			hud.refresh_card())
	return btn


static func _dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}
