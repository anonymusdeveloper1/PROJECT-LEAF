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
## Called by: ui/windows/build_menu_window.gd. Uses: the HUD's tile styles, fonts, price line and tile button
## (shop_tiles.gd), the HUD's icons and pictures (hud_icons.gd). No class_name: preload it.

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
	var panel := PanelContainer.new()
	panel.set_meta("cell", id)
	panel.set_meta("title", title)
	panel.set_meta("locked", locked)
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
	v.add_child(_picture(hud, c, title))
	var tl := Label.new()
	tl.text = title
	tl.add_theme_font_override("font", tiles._bold())
	tl.add_theme_font_size_override("font_size", NAME_FS)
	tl.add_theme_color_override("font_color", hud.TILE_INK)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # a long name ("Mushroom Cottage") takes a second line at 480 px
	tl.max_lines_visible = NAME_LINES
	tl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(tl)
	var note := String(c.get("note", ""))
	if not locked and tiles._price_kinds(cost) > 0:
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
## an unknown icon shows the name's first letter on a plain disc, as a tile does.
static func _picture(hud, c: Dictionary, title: String) -> Control:
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
	sq.add_child(pic)
	if not hud._icon_known(raw):
		sq.add_child(hud.p_tiles._letter(title))
	return sq


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
