extends RefCounted
## H4: big picture cells in a grid (the window kit; the build menu uses it, and H5's Market grids will). Each cell is a
## soft parchment tile: the picture (120 px), the name (bold 22), then the price line or a short note, and, when the cell
## says so, its own one-tap button. A locked cell is drawn at 55% (its words and picture; the tile stays whole) and has
## no button. Columns: 3 once the dialog's list holds 3 cells of about 170 px, else 2 (a phone in portrait holds 3).
## A tap on a cell (a press and release less than TAP_PX apart, the H3 drag_source.gd rule) calls on_tap(id); a drag that
## starts on it still scrolls the dialog (the cell and its words pass the touch on and never accept it). The cell's own
## button stops its touch, as every tile button does.
##   cells: [{"id", "picture" (a res:// image, used when the file exists), "icon" (an icon id, else), "title", "cost",
##            "note", "locked", and for a button: "label", "enabled" (it already holds the price), "action"}]
##   make() -> the GridContainer (meta "grid" = true); each cell is a PanelContainer with meta "cell" = its id, "title",
##   "locked"; its picture panel has meta "cell_pic".
## H5 (the Market's and the Tailor's grids): three optional cell keys. A cell without them is drawn exactly as in H4, so
## the build menu does not change.
##   "show_title": false   no name under the picture (a Market trade is its picture and its price); the cell keeps its
##                         meta "title", and its accessible name where the engine has one
##   "payout": {id: n}     what the player GETS (Bramble's Buys: 1,000 leaves and a shard for an amber), drawn in the
##                         price line's place as a neutral line: always in ink, never red, because having few leaves
##                         never makes a payout short (the cell's "cost", if any, is still what its button checks)
##   "grey": true          the picture and the name in grey (an outfit not owned yet), but unlike "locked" it keeps its
##                         price line, note, button and taps, so it can still be looked at and tried on (meta "grey")
## amount_line() draws a line of currencies and goods (a price that turns red when short, or a neutral payout); the
## Market's trade popup (item_popup.gd) uses it too.
## Called by: ui/windows/build_menu_window.gd, ui/kit/item_popup.gd. Uses: the HUD's tile styles, fonts, price line and
## tile button (shop_tiles.gd), the HUD's icons and pictures (hud_icons.gd), Data (the currencies, what the cat has),
## Bag (goods: their count and picture). No class_name: preload it.

const ShopTiles := preload("res://ui/hud/shop_tiles.gd")   # the type of the HUD's tiles (hud.p_tiles)
const CELL_MIN_W := 170.0               # a cell is at least this wide (3 of them make a row on a phone)
const GAP := 12.0                       # between two cells, both ways
const PIC := 120.0                      # the picture
const PIC_PAD := 6.0                    # the soft square behind it is this much bigger on each side
const NAME_FS := 22                     # the name (bold, up to NAME_LINES lines, then "...")
const NAME_LINES := 2
const NOTE_FS := 19                     # the note under it (what a locked building needs)
const BTN_H := 56.0                     # a cell's own button: a thumb tall
const LOCKED_ALPHA := 0.55              # a locked cell's words and picture
const TAP_PX := 12.0                    # a press and release closer than this is a tap, not a drag
const PAD := 10.0                       # inside a cell (the tile style's own padding)
const GREY_SHARE := 0.85                # H5: how far a grey cell's picture goes to grey (0 = its colours, 1 = all grey)
const GREY_ALPHA := 0.8                 # H5: and fades this much, so it reads as "not yours yet"
const GREY_INK := Color(0.5, 0.48, 0.45)   # H5: a grey cell's name
const LINE_H := 30.0                    # H5: an amount line's height (shop_tiles' PRICE_H)
const LINE_FS := 22                     # H5: its numbers, down to LINE_FS_MIN when many would not fit
const LINE_FS_MIN := 15
const SHORT_INK := Color(0.8, 0.22, 0.16)  # H5: a price's number the cat has too few of (shop_tiles' red)

## H5: the grey look, one shader shared by every grey picture (made once, the first time a grey cell is drawn).
static var _grey_mat: ShaderMaterial


## How many columns `n` cells make: 3 when the list holds 3 cells of CELL_MIN_W (and there are 3 or more), else 2.
static func columns(hud, n: int) -> int:
	var room: float = hud.p_tiles._list_w()
	return 3 if n >= 3 and room >= 3.0 * CELL_MIN_W + 2.0 * GAP else 2


static func make(hud, cells: Array, on_tap: Callable) -> GridContainer:
	var g := GridContainer.new()
	g.set_meta("grid", true)
	g.columns = columns(hud, cells.size())
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.add_theme_constant_override("h_separation", int(GAP))
	g.add_theme_constant_override("v_separation", int(GAP))
	g.mouse_filter = Control.MOUSE_FILTER_PASS
	var room: float = hud.p_tiles._list_w()
	var inner: float = (room - GAP * float(g.columns - 1)) / float(g.columns) - PAD * 2.0 - 4.0   # a cell's insides
	for c: Variant in cells:
		if c is Dictionary:
			g.add_child(_cell(hud, c as Dictionary, on_tap, inner))
	return g


static func _cell(hud, c: Dictionary, on_tap: Callable, inner: float) -> Control:
	var tiles: ShopTiles = hud.p_tiles
	var id := String(c.get("id", ""))
	var title := String(c.get("title", ""))
	var locked := bool(c.get("locked", false))
	var cost := _dict(c.get("cost", {}))
	var show_title := bool(c.get("show_title", true))   # H5: false for a Market trade (its picture and price only)
	var grey := bool(c.get("grey", false))              # H5: an outfit not owned yet (still looked at, still priced)
	var payout := _dict(c.get("payout", {}))            # H5: what the player gets (Bramble's Buys), never red
	var panel := PanelContainer.new()
	panel.set_meta("cell", id)
	panel.set_meta("title", title)
	panel.set_meta("locked", locked)
	if grey:
		panel.set_meta("grey", true)
	if not show_title and "accessibility_name" in panel:
		panel.set("accessibility_name", title)          # the name a screen reader says, though none is drawn
	panel.custom_minimum_size = Vector2(CELL_MIN_W, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_theme_stylebox_override("panel", tiles._ui_style("tile"))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_PASS
	if locked:
		v.modulate.a = LOCKED_ALPHA                 # the cell's own reveal fades panel.modulate, so this stays apart
	panel.add_child(v)
	v.add_child(_picture(hud, c, title, grey))
	if show_title:
		var tl := Label.new()
		tl.text = title
		tl.add_theme_font_override("font", tiles._bold())
		tl.add_theme_font_size_override("font_size", NAME_FS)
		tl.add_theme_color_override("font_color", GREY_INK if grey else hud.TILE_INK)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # a long name ("Mushroom Cottage") takes a second line at 480 px
		tl.max_lines_visible = NAME_LINES
		tl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(tl)
	var note := String(c.get("note", ""))
	if not locked and amount_kinds(payout) > 0:
		var pay_line: HBoxContainer = amount_line(hud, payout, maxf(inner, 120.0), false)   # H5: neutral, never red
		pay_line.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_child(pay_line)
	elif not locked and tiles._price_kinds(cost) > 0:
		var line: HBoxContainer = tiles._price_line(cost, maxf(inner, 120.0))
		line.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_child(line)
	elif note != "":
		var nl := Label.new()
		nl.text = note
		nl.add_theme_font_size_override("font_size", NOTE_FS)
		nl.add_theme_color_override("font_color", Color(0.45, 0.36, 0.26))
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(nl)
	if not locked and String(c.get("label", "")) != "":
		var b: Button = tiles._tile_button(c, cost)       # on only when enabled and the price can be paid
		b.custom_minimum_size = Vector2(0, BTN_H)
		v.add_child(b)
	if on_tap.is_valid():
		var state := {"down": false, "at": Vector2.ZERO, "global": Vector2.ZERO}   # this press (shared by the calls)
		panel.gui_input.connect(func(event: InputEvent) -> void:
			_cell_input(hud, panel, id, on_tap, state, event))
	return panel


## The picture: the cell's own picture (a building's) when its file is there, else its icon, in the tiles' soft square;
## an unknown icon shows the name's first letter on a plain disc, as a tile does. H5: grey = drawn in grey and faded.
static func _picture(hud, c: Dictionary, title: String, grey: bool = false) -> Control:
	var sq := Panel.new()
	sq.set_meta("cell_pic", true)
	var side := PIC + PIC_PAD * 2.0
	sq.custom_minimum_size = Vector2(side, side)
	sq.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sq.add_theme_stylebox_override("panel", hud.p_tiles._ui_style("pic"))
	sq.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var raw: Variant = c.get("icon", "")                    # an icon id or a texture
	var own: Texture2D = hud.p_icons._picture(String(c.get("picture", "")))
	if own != null:
		raw = own
	var pic := TextureRect.new()
	pic.texture = hud.icon(raw)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.anchor_right = 1.0
	pic.anchor_bottom = 1.0
	pic.offset_left = PIC_PAD
	pic.offset_top = PIC_PAD
	pic.offset_right = -PIC_PAD
	pic.offset_bottom = -PIC_PAD
	if grey:
		pic.material = grey_material()
		pic.modulate.a = GREY_ALPHA
	sq.add_child(pic)
	if not hud._icon_known(raw):
		var letter: Label = hud.p_tiles._letter(title)
		if grey:
			letter.modulate.a = GREY_ALPHA
		sq.add_child(letter)
	return sq


## H5: the shared grey look (a picture mixed GREY_SHARE of the way to grey), made once. The skill grid's unlearned
## skills use it too.
static func grey_material() -> ShaderMaterial:
	if _grey_mat == null:
		var sh := Shader.new()
		sh.code = """shader_type canvas_item;
uniform float grey = 0.85;
void fragment() {
	float g = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
	COLOR.rgb = mix(COLOR.rgb, vec3(g), grey);
}
"""
		_grey_mat = ShaderMaterial.new()
		_grey_mat.shader = sh
		_grey_mat.set_shader_parameter("grey", GREY_SHARE)
	return _grey_mat


## H5: a line of amounts, {id: n}: an icon and a number for each, centred, the currencies first (in Data.CURRENCIES
## order), then goods (anything the Bag holds: Sunberries, Golden Carp) in the order given; anything else, and amounts
## of 0 or less, are left out. The font gets smaller (down to LINE_FS_MIN) when it would not fit inner_w.
##   check = true    a price: a number the cat has too few of is red, its icon dimmed (as shop_tiles' price line)
##   check = false   a payout: always in ink (what you get is never short)
## Meta: the line "amount_line" = true and "neutral" = not check; each number "afford" (always true when neutral).
## An empty line keeps its height (LINE_H).
static func amount_line(hud, amounts: Dictionary, inner_w: float, check: bool) -> HBoxContainer:
	var tiles: ShopTiles = hud.p_tiles
	var h := HBoxContainer.new()
	h.set_meta("amount_line", true)
	h.set_meta("neutral", not check)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.custom_minimum_size = Vector2(0, LINE_H)
	h.add_theme_constant_override("separation", 12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var parts: Array[Array] = _amount_parts(amounts)
	if parts.is_empty():
		return h
	var f: Font = tiles._bold()
	var fs := LINE_FS
	while fs > LINE_FS_MIN:
		var w := 12.0 * float(parts.size() - 1)
		for p: Array in parts:
			w += float(fs + 2) + 3.0 + f.get_string_size(str(p[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if w <= inner_w:
			break
		fs -= 1
	for p: Array in parts:
		var id := String(p[0])
		var n := int(p[1])
		var ok: bool = not check or held(id) >= n
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 3)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ic: TextureRect = hud._btn_icon(hud.icon(id if Data.CURRENCIES.has(id) else Bag.icon(id)))
		ic.custom_minimum_size = Vector2(fs + 2, fs + 2)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if not ok:
			ic.modulate = Color(1, 1, 1, 0.55)
		box.add_child(ic)
		var l := Label.new()
		l.text = str(n)
		l.add_theme_font_override("font", f)
		l.add_theme_font_size_override("font_size", fs)
		l.add_theme_color_override("font_color", hud.TILE_INK if ok else SHORT_INK)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.set_meta("afford", ok)
		box.add_child(l)
		h.add_child(box)
	return h


## H5: how many things amount_line would draw for `amounts` (0: it draws an empty line).
static func amount_kinds(amounts: Dictionary) -> int:
	return _amount_parts(amounts).size()


## [[id, n], ...] in amount_line's order: the currencies first, then goods the Bag knows; nothing else, nothing <= 0.
static func _amount_parts(amounts: Dictionary) -> Array[Array]:
	var out: Array[Array] = []
	for k: Variant in Data.CURRENCIES:
		var cur := String(k)
		if amounts.has(cur) and _count(amounts[cur]) > 0:
			out.append([cur, _count(amounts[cur])])
	for k: Variant in amounts:
		var id := String(k)
		if Data.CURRENCIES.has(id) or Bag.kind_of(id) == "":
			continue
		if _count(amounts[k]) > 0:
			out.append([id, _count(amounts[k])])
	return out


## A whole number from an amount (JSON numbers come as floats); 0 for anything that is not a number.
static func _count(v: Variant) -> int:
	if v is int or v is float:
		return int(v)
	return 0


## H5: how many of id the cat has: a currency (amber too) from Data, goods from the Bag (the item popup reads it too).
static func held(id: String) -> int:
	return Data.have(id) if Data.CURRENCIES.has(id) else Bag.count(id)


## A press on the cell and its release less than TAP_PX apart is a tap: on_tap(id) runs. Moving further (a drag that
## scrolls the dialog) is no tap. Both the cell's own and the screen's positions are checked, because the cell moves
## with the finger while the dialog scrolls. It never accepts the event, so the scroll sees every touch too.
static func _cell_input(hud, cell: Control, id: String, act: Callable, state: Dictionary, event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			state["down"] = true
			state["at"] = mb.position
			state["global"] = mb.global_position
		elif bool(state["down"]):
			state["down"] = false
			var still: bool = mb.position.distance_to(state["at"]) < TAP_PX and mb.global_position.distance_to(state["global"]) < TAP_PX
			if still and act.is_valid() and hud._card != null and (hud._card as Node).is_ancestor_of(cell):   # not on a closing dialog
				act.call(id)
	elif event is InputEventMouseMotion and bool(state["down"]):
		var mm := event as InputEventMouseMotion
		if mm.position.distance_to(state["at"]) >= TAP_PX or mm.global_position.distance_to(state["global"]) >= TAP_PX:
			state["down"] = false                           # moved too far: no tap on release


static func _dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}
