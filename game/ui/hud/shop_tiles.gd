extends RefCounted
## The shop tiles, pills, stat bars, prices and shared styles and fonts that fill a card. A part of the HUD (hud.gd).

## The things to buy on a card are shop tiles (the user: "It should be like a whole shop store"), a row
## {"kind": "item", "icon", "title", "text", "stats": [[name, 0..1], ...], "badge", "cost", "label", "enabled", "action"}
## (G3: an optional "picture", a res:// image path shown instead of the icon when the file exists: the bows' pictures).
## Consecutive item rows make one grid: 2 tiles a row on a phone, 3 once the dialog holds 3 of about TILE_MIN_W; a lone
## last tile sits on the left. Every tile of a grid has the same size and layout, top to bottom: the icon in a soft
## rounded square (the badge a pill in the tile's top corner), the name on one line (smaller, then "...", when long),
## one or two short lines, labelled stat bars, then the price (an icon and a number for each currency, red when there is
## not enough) and one button. An empty cost with a label is a free action; an empty label shows no button. A disabled
## or unaffordable tile's button is grey and does nothing. A stat may carry a third item, a short value shown after its
## bar ("6/10"). The tiles are made when a card opens or refreshes (after a purchase), never per frame, and share
## their styles. A row {"kind": "section", "text"} is a small shelf heading over them.
const GRID_GAP := 12.0                  # between two tiles, both ways
const TILE_MIN_W := 200.0               # 3 tiles a row once the dialog holds 3 this wide, else 2
const TILE_PAD := 10.0                  # inside a tile
const PIC := 64.0                       # the soft rounded square behind a tile's icon
const PIC_ICON := 52.0                  # the icon in it
const TITLE_FS := 24                    # a tile's name (bold), down to TITLE_MIN when it is long
const TITLE_MIN := 17
const TEXT_FS := 19                     # its short line (two lines at most)
const STAT_H := 22.0                    # one labelled stat bar
const STAT_LABEL_W := 96.0
const MAX_STATS := 4
const PRICE_H := 30.0
const TILE_BTN_H := 52.0                # the one button: a thumb tall (touch targets 44 px and more)
const PILL := {"wood": Color(0.56, 0.35, 0.17), "green": Color(0.33, 0.6, 0.2), "blue": Color(0.24, 0.5, 0.72),
	"orange": Color(0.92, 0.45, 0.2), "gold": Color(0.84, 0.6, 0.1), "red": Color(0.78, 0.22, 0.17)}
const BTN := {"green": Color(0.36, 0.66, 0.24), "blue": Color(0.31, 0.55, 0.83), "orange": Color(0.9, 0.55, 0.2),
	"off": Color(0.72, 0.69, 0.64)}

var hud                                 # the HUD node (untyped on purpose: hud._stage_l and the rest are read at run time)
var _ui_styles := {}                    # the tiles' styles, made once and shared by every tile
var _bold_font: FontVariation
var _caps_font: FontVariation


func _init(h) -> void:
	hud = h


## How wide the dialog's scrolling list is, in HUD pixels: the dialog less its frame and the body's margins, and room
## for a scroll bar.
func _list_w() -> float:
	return hud.get_viewport().get_visible_rect().size.x * hud.DIALOG_W - 12.0 - 32.0 - 14.0


## Tiles a row: 3 once the list holds 3 of about TILE_MIN_W, else 2 (a phone in portrait).
func _grid_cols() -> int:
	return 3 if _list_w() >= 3.0 * TILE_MIN_W + 2.0 * GRID_GAP else 2


## About how wide a tile's insides are (its price line and badge are fitted to it).
func _tile_inner_w() -> float:
	var n := _grid_cols()
	return (_list_w() - GRID_GAP * float(n - 1)) / float(n) - TILE_PAD * 2.0 - 4.0


## A run of item rows as one grid of tiles. The slots any of its tiles uses (stat bars, a price line, a button) are kept
## in all of them, so every tile of the grid has the same size.
func _item_grid(items: Array) -> GridContainer:
	var g := GridContainer.new()
	g.columns = _grid_cols()
	g.set_meta("grid", true)
	g.add_theme_constant_override("h_separation", int(GRID_GAP))
	g.add_theme_constant_override("v_separation", int(GRID_GAP))
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var n_stats := 0
	var priced := false
	var buttons := false
	for it in items:
		var d := _as_dict(it)
		var st = d.get("stats", [])
		if st is Array:
			n_stats = maxi(n_stats, mini((st as Array).size(), MAX_STATS))
		if _price_kinds(_as_dict(d.get("cost", {}))) > 0:
			priced = true
		if str(d.get("label", "")) != "":
			buttons = true
	var inner := _tile_inner_w()
	for it in items:
		g.add_child(_item_tile(_as_dict(it), n_stats, priced, buttons, inner))
	g.sort_children.connect(_even_tiles.bind(g), CONNECT_ONE_SHOT)   # once laid out: every tile as tall as the tallest
	return g


## Every tile of a grid gets the tallest tile's height (a shrunk title or price line can leave one a pixel or two short).
func _even_tiles(g: GridContainer) -> void:
	if not is_instance_valid(g):
		return
	var h := 0.0
	for c in g.get_children():
		h = maxf(h, (c as Control).get_combined_minimum_size().y)
	for c in g.get_children():
		(c as Control).custom_minimum_size.y = h


## One shop tile (see above). n_stats, priced, buttons: the grid's slots, kept even when this tile leaves them empty.
func _item_tile(it: Dictionary, n_stats: int, priced: bool, buttons: bool, inner_w: float) -> PanelContainer:
	var title := str(it.get("title", ""))
	var cost := _as_dict(it.get("cost", {}))
	var tile := PanelContainer.new()
	tile.set_meta("tile", true)
	tile.set_meta("title", title)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.mouse_filter = Control.MOUSE_FILTER_PASS        # a drag on a tile still scrolls the dialog
	tile.add_theme_stylebox_override("panel", _ui_style("tile"))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_PASS
	tile.add_child(v)
	# the picture: the icon in a soft rounded square in the middle, the badge a pill in the tile's top corner
	var top := Control.new()
	top.custom_minimum_size = Vector2(0, PIC)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	var sq := Panel.new()
	sq.add_theme_stylebox_override("panel", _ui_style("pic"))
	sq.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sq.anchor_left = 0.5
	sq.anchor_right = 0.5
	sq.offset_left = -PIC * 0.5
	sq.offset_right = PIC * 0.5
	sq.offset_top = 0.0
	sq.offset_bottom = PIC
	top.add_child(sq)
	var raw = it.get("icon", "")
	var own_pic: Texture2D = hud.p_icons._picture(str(it.get("picture", "")))   # G3: a tile's own picture (a bow's), over its icon
	if own_pic != null:
		raw = own_pic
	var pic := TextureRect.new()
	pic.texture = hud.icon(raw)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inset := (PIC - PIC_ICON) * 0.5
	pic.anchor_right = 1.0
	pic.anchor_bottom = 1.0
	pic.offset_left = inset
	pic.offset_top = inset
	pic.offset_right = -inset
	pic.offset_bottom = -inset
	sq.add_child(pic)
	if not hud._icon_known(raw):
		sq.add_child(_letter(title))                 # an unknown id: the plain disc with the name's first letter
	var badge := str(it.get("badge", ""))
	if badge != "":
		top.add_child(_pill(badge, inner_w))
	# the name, on one line
	var tl := Label.new()
	tl.text = title
	tl.add_theme_font_override("font", _bold())
	tl.add_theme_font_size_override("font_size", TITLE_FS)
	tl.add_theme_color_override("font_color", hud.TILE_INK)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tl.clip_text = true
	tl.custom_minimum_size = Vector2(0, ceilf(_bold().get_height(TITLE_FS)))
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tl.resized.connect(_fit_title.bind(tl))
	v.add_child(tl)
	# one short line (two at most), in a slot two lines tall
	var tx := Label.new()
	tx.text = str(it.get("text", ""))
	tx.add_theme_font_size_override("font_size", TEXT_FS)
	tx.add_theme_color_override("font_color", Color(0.45, 0.36, 0.26))
	tx.add_theme_constant_override("line_spacing", 0)
	tx.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tx.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	tx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tx.max_lines_visible = 2
	tx.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tx.custom_minimum_size = Vector2(0, ceilf(ThemeDB.fallback_font.get_height(TEXT_FS) * 2.0) + 10.0)   # roomy: one or two lines, every tile the same height
	tx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(tx)
	# the stat bars
	if n_stats > 0:
		var sv := VBoxContainer.new()
		sv.add_theme_constant_override("separation", 2)
		sv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(sv)
		var stats = it.get("stats", [])
		for k in n_stats:
			sv.add_child(_stat_bar(stats[k] if stats is Array and k < (stats as Array).size() else null))
	var fill := Control.new()                        # keeps the price and the button at the tile's bottom
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(fill)
	if priced:
		v.add_child(_price_line(cost, inner_w))
	if buttons:
		if str(it.get("label", "")) != "":
			v.add_child(_tile_button(it, cost))
		else:
			var gap := Control.new()                     # an info tile among buttons: the button's room, empty
			gap.custom_minimum_size = Vector2(0, TILE_BTN_H)
			gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			v.add_child(gap)
	return tile


## A tile's name on one line: a smaller font when it is long (down to TITLE_MIN), then "..." (once its width is known).
func _fit_title(l: Label) -> void:
	if not is_instance_valid(l) or l.size.x < 8.0:
		return
	var f := _bold()
	var fs := TITLE_FS
	while fs > TITLE_MIN and f.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > l.size.x - 2.0:
		fs -= 1
	if l.get_theme_font_size("font_size") != fs:
		l.add_theme_font_size_override("font_size", fs)


## The first letter of a tile's name, on the plain disc of an unknown icon.
func _letter(title: String) -> Label:
	var l := Label.new()
	var t := title.strip_edges()
	l.text = t.substr(0, 1).to_upper() if t != "" else "?"
	l.add_theme_font_override("font", _bold())
	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_color_override("font_color", Color(1.0, 0.97, 0.9))
	l.add_theme_color_override("font_outline_color", Color(0.36, 0.2, 0.09, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.anchor_right = 1.0
	l.anchor_bottom = 1.0
	return l


## A tile's badge: a small pill in its top right corner (green Equipped / Built / Worn, blue Owned, orange New, gold Max, red
## Broken, wood for the rest: Level 3/5 ...). A long one gets a smaller font so it keeps clear of the icon.
func _pill(text: String, inner_w: float) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _ui_style("pill_" + _pill_tone(text)))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.anchor_left = 1.0
	p.anchor_right = 1.0
	p.offset_left = 4.0
	p.offset_right = 4.0
	p.offset_top = -4.0
	p.offset_bottom = -4.0
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN     # it grows to the left, from the corner, as wide as its words
	var l := Label.new()
	l.text = text
	var room := (inner_w - PIC) * 0.5 - 20.0
	var fs := 15
	while fs > 12 and _bold().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room:
		fs -= 1
	l.add_theme_font_override("font", _bold())
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", Color(1.0, 0.98, 0.93))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	return p


func _pill_tone(text: String) -> String:
	var b := text.to_lower()
	if b.begins_with("equipped") or b.begins_with("built") or b.begins_with("in use") or b.begins_with("worn"):
		return "green"
	if b.begins_with("owned"):
		return "blue"
	if b.begins_with("new"):
		return "orange"
	if b.begins_with("max"):
		return "gold"
	if b.begins_with("broken") or b.begins_with("locked"):
		return "red"
	return "wood"


## One labelled stat bar [name, 0..1] (or [name, 0..1, "6/10"]); anything else is an empty slot of the same height.
func _stat_bar(s) -> Control:
	var h := HBoxContainer.new()
	h.custom_minimum_size = Vector2(0, STAT_H)
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not (s is Array) or (s as Array).size() < 2:
		return h
	var a := s as Array
	var nl := Label.new()
	nl.text = str(a[0])
	nl.custom_minimum_size = Vector2(STAT_LABEL_W, 0)
	nl.add_theme_font_size_override("font_size", 16)
	nl.add_theme_color_override("font_color", Color(0.42, 0.32, 0.22))
	nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nl.clip_text = true
	nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(nl)
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.step = 0.0
	bar.value = clampf(float(a[1]), 0.0, 1.0)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(40, 10)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_theme_stylebox_override("background", _ui_style("bar_bg"))
	bar.add_theme_stylebox_override("fill", _ui_style("bar_fill"))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(bar)
	if a.size() >= 3 and str(a[2]) != "":
		var vl := Label.new()
		vl.text = str(a[2])
		vl.add_theme_font_override("font", _bold())
		vl.add_theme_font_size_override("font_size", 16)
		vl.add_theme_color_override("font_color", hud.TILE_INK)
		vl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		vl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(vl)
	return h


## The price: an icon and a number for each currency it asks for (red, the icon dimmed, when there is not enough), on
## one line, the font smaller when many currencies would not fit the tile. An empty price: an empty line of the same
## height (a free tile among priced ones).
func _price_line(cost: Dictionary, inner_w: float) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.custom_minimum_size = Vector2(0, PRICE_H)
	h.add_theme_constant_override("separation", 12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var parts: Array = []
	for k in Data.CURRENCIES:                        # (other keys such as needs_* are not money)
		var n := int(cost.get(k, 0))
		if n > 0:
			parts.append([String(k), n])
	if parts.is_empty():
		return h
	var f := _bold()
	var fs := 22
	while fs > 15:
		var w := 12.0 * float(parts.size() - 1)
		for p in parts:
			w += float(fs + 2) + 3.0 + f.get_string_size(str(p[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if w <= inner_w:
			break
		fs -= 1
	for p in parts:
		var ok: bool = Data.have(String(p[0])) >= int(p[1])
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 3)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ic: TextureRect = hud._btn_icon(hud.icon(String(p[0])))
		ic.custom_minimum_size = Vector2(fs + 2, fs + 2)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if not ok:
			ic.modulate = Color(1, 1, 1, 0.55)
		box.add_child(ic)
		var l := Label.new()
		l.text = str(p[1])
		l.add_theme_font_override("font", _bold())
		l.add_theme_font_size_override("font_size", fs)
		l.add_theme_color_override("font_color", hud.TILE_INK if ok else Color(0.8, 0.22, 0.16))
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.set_meta("afford", ok)
		box.add_child(l)
		h.add_child(box)
	return h


## A tile's one button (as wide as the tile): green to buy, build or upgrade, blue to equip or use, orange to repair;
## grey and dead while it is disabled or the price is more than the cat has. Its action runs, then the card refreshes.
func _tile_button(it: Dictionary, cost: Dictionary) -> Button:
	var label := str(it.get("label", ""))
	var act = it.get("action", Callable())
	var action: Callable = act if act is Callable else Callable()
	var on: bool = bool(it.get("enabled", false)) and Data.can_afford(cost)
	var b := Button.new()
	b.text = label
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = not on
	b.custom_minimum_size = Vector2(0, TILE_BTN_H)
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.set_meta("label", label)
	b.add_theme_font_override("font", _bold())
	b.add_theme_font_size_override("font_size", 24)
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(st, Color(1, 1, 1))
	b.add_theme_color_override("font_disabled_color", Color(0.98, 0.96, 0.92))
	b.add_theme_color_override("font_outline_color", Color(0.1, 0.12, 0.05, 0.55))
	b.add_theme_constant_override("outline_size", 5)
	var tone := _btn_tone(label) if on else "off"
	for st in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(st, _ui_style("btn_" + tone))
	b.add_theme_stylebox_override("pressed", _ui_style("btn_%s_down" % tone))
	b.add_theme_stylebox_override("hover_pressed", _ui_style("btn_%s_down" % tone))
	b.add_theme_stylebox_override("disabled", _ui_style("btn_off"))
	if on and action.is_valid():
		b.pressed.connect(func():
			action.call()
			hud.refresh_card())
	return b


func _btn_tone(label: String) -> String:
	match label.to_lower():
		"equip", "use", "wear", "ride", "walk", "take off", "change", "go", "show":
			return "blue"
		"repair", "mend", "rebuild":
			return "orange"
	return "green"


## A shelf heading: small spaced-out capitals in wood brown, and a thin rule to the dialog's edge.
func _section_row(text: String, gap: bool) -> MarginContainer:
	var m := MarginContainer.new()
	m.set_meta("section", true)
	m.add_theme_constant_override("margin_top", 10 if gap else 0)
	m.add_theme_constant_override("margin_bottom", 2)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(h)
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_override("font", _caps())
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", Color(0.5, 0.31, 0.14))
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(minf(_caps().get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 4.0, _list_w() * 0.75), 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(l)
	var rule := ColorRect.new()
	rule.color = Color(0.56, 0.35, 0.17, 0.3)
	rule.custom_minimum_size = Vector2(12, 2)
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(rule)
	return m


## The game's font, bolder (a tile's name, its price and button, a badge).
func _bold() -> Font:
	if _bold_font == null:
		_bold_font = FontVariation.new()
		_bold_font.base_font = ThemeDB.fallback_font
		_bold_font.variation_embolden = 0.6
	return _bold_font


## The shelf headings' font: bold, the letters a little apart.
func _caps() -> Font:
	if _caps_font == null:
		_caps_font = FontVariation.new()
		_caps_font.base_font = ThemeDB.fallback_font
		_caps_font.variation_embolden = 0.45
		_caps_font.set("spacing_glyph", 2)
	return _caps_font


func _as_dict(v) -> Dictionary:
	return v if v is Dictionary else {}


## How many currencies a price asks for (Data.CURRENCIES above 0).
func _price_kinds(cost: Dictionary) -> int:
	var n := 0
	for k in Data.CURRENCIES:
		if int(cost.get(k, 0)) > 0:
			n += 1
	return n


## A tile's style, made once and shared: "tile", "pic" (the icon's square), "bar_bg" / "bar_fill", "pill_<tone>",
## "btn_<tone>" and "btn_<tone>_down" (pressed).
func _ui_style(k: String) -> StyleBoxFlat:
	if _ui_styles.has(k):
		return _ui_styles[k]
	var s := StyleBoxFlat.new()
	match k:
		"tile":
			s.bg_color = Color(1.0, 0.985, 0.94)
			s.border_color = Color(0.85, 0.72, 0.52)
			s.set_border_width_all(2)
			s.border_width_bottom = 4
			s.set_corner_radius_all(16)
			s.content_margin_left = TILE_PAD
			s.content_margin_right = TILE_PAD
			s.content_margin_top = TILE_PAD
			s.content_margin_bottom = TILE_PAD + 2.0
		"pic":
			s.bg_color = Color(0.96, 0.88, 0.7)
			s.border_color = Color(0.91, 0.8, 0.6)
			s.border_width_bottom = 3
			s.set_corner_radius_all(16)
		"bar_bg":
			s.bg_color = Color(0.88, 0.8, 0.66)
			s.set_corner_radius_all(5)
		"bar_fill":
			s.bg_color = Color(0.95, 0.64, 0.2)
			s.set_corner_radius_all(5)
		_:
			if k.begins_with("pill_"):
				s.bg_color = PILL.get(k.substr(5), PILL["wood"])
				s.set_corner_radius_all(11)
				s.content_margin_left = 8.0
				s.content_margin_right = 8.0
				s.content_margin_top = 1.0
				s.content_margin_bottom = 2.0
			elif k.begins_with("btn_"):
				var down := k.ends_with("_down")
				var col: Color = BTN.get(k.substr(4).trim_suffix("_down"), BTN["green"])
				s.bg_color = col.darkened(0.15) if down else col
				s.border_color = col.darkened(0.38)
				s.border_width_bottom = 2 if down else 5
				s.set_corner_radius_all(16)
				s.content_margin_left = 8.0
				s.content_margin_right = 8.0
	_ui_styles[k] = s
	return s
