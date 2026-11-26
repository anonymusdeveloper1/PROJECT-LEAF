extends RefCounted
## H4: one row of a building window's list (the window kit). The card (ui/hud/card.gd) draws every {"kind": "list"} row
## with make(): a long parchment strip as wide as the dialog's list, with the thing's picture on the left, its name and
## badge, up to three short lines and its price in the middle, and one thumb-sized button on the right. Each row is its
## own child of the card's list, so the reveal staggers them; the rows sit 8 px apart with no rule between them.
## The keys are the shop tiles' (title, label, text, badge, enabled, cost), so a test that reads a tile reads a row too:
##   {"kind": "list", "id", "icon" (an icon id or a texture), "picture" (a res:// image, used when the file exists),
##    "title", "badge", "text" (up to 3 lines), "cost", "label" ("" = no button), "enabled", "action",
##    "on_picture" (optional: a tap on the picture), "pulse", "quiet"}
## The marker's "!" reads "enabled", so a window's "enabled" already includes the price (the base building_window.gd's
## list_row() does that); the drawn button is the tile button (shop_tiles.gd), which checks Data.can_afford again.
## A tap on the picture (a press and release less than TAP_PX apart, the H3 drag_source.gd rule) runs on_picture, then
## the card refreshes. The picture passes the touch on, so a drag that starts on it still scrolls the dialog.
## Called by: card.gd (_fill_card). Uses: the HUD's tile styles, fonts, pills, price line and tile button
## (shop_tiles.gd), the HUD's icons and pictures (hud_icons.gd). No class_name: preload it.

const ShopTiles := preload("res://ui/hud/shop_tiles.gd")   # the type of the HUD's tiles (hud.p_tiles)
const ROW_H := 88.0                    # the row's least height (it grows with its lines)
const PIC := 72.0                       # the soft rounded square behind the picture
const PIC_ICON := 58.0                  # the picture in it
const GAP := 12.0                       # between the picture, the words and the button
const TITLE_FS := 24                    # the name (bold, one line, then "...")
const TEXT_FS := 19                     # the short lines under it
const TEXT_LINES := 3                   # at most (the bow in the paw has a line of its own under its level line)
const BTN := Vector2(140, 60)           # the one button: a thumb wide and tall
const TAP_PX := 12.0                    # a press and release closer than this on the picture is a tap, not a drag


## One list row (see above), made when the card opens or refreshes, never per frame.
static func make(hud, row: Dictionary) -> Control:
	var tiles: ShopTiles = hud.p_tiles
	var title := String(row.get("title", ""))
	var cost := _dict(row.get("cost", {}))
	var panel := PanelContainer.new()
	panel.set_meta("list_row", true)
	panel.set_meta("title", title)
	panel.set_meta("id", String(row.get("id", "")))
	panel.custom_minimum_size = Vector2(0, ROW_H)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL   # as wide as the list (never wider: the scroll bar fits)
	panel.mouse_filter = Control.MOUSE_FILTER_PASS           # a drag on a row still scrolls the dialog
	panel.add_theme_stylebox_override("panel", tiles._ui_style("tile"))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(GAP))
	h.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(h)
	h.add_child(_picture(hud, row, title))
	h.add_child(_words(hud, row, title, cost))
	if String(row.get("label", "")) != "":
		var b: Button = tiles._tile_button(row, cost)          # on only when enabled and the price can be paid
		b.custom_minimum_size = BTN
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(b)
	return panel


## The picture: the row's own picture (a bow's) when its file is there, else its icon, in the tiles' soft square; an
## unknown icon shows the name's first letter on a plain disc, as a tile does. With on_picture it takes taps.
static func _picture(hud, row: Dictionary, title: String) -> Control:
	var sq := Panel.new()
	sq.set_meta("list_pic", true)
	sq.custom_minimum_size = Vector2(PIC, PIC)
	sq.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sq.add_theme_stylebox_override("panel", hud.p_tiles._ui_style("pic"))
	var raw: Variant = row.get("icon", "")                    # an icon id or a texture
	var own: Texture2D = hud.p_icons._picture(String(row.get("picture", "")))
	if own != null:
		raw = own
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
		sq.add_child(hud.p_tiles._letter(title))
	var tap: Variant = row.get("on_picture", Callable())
	if tap is Callable and (tap as Callable).is_valid():
		sq.mouse_filter = Control.MOUSE_FILTER_PASS          # the touch goes on to the dialog's scroll as well
		var act: Callable = tap
		var state := {"down": false, "at": Vector2.ZERO, "global": Vector2.ZERO}   # this press (shared by the calls)
		sq.gui_input.connect(func(event: InputEvent) -> void:
			_picture_input(hud, sq, act, state, event))
	else:
		sq.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return sq


## A press on the picture and its release less than TAP_PX apart is a tap: on_picture runs, then the card refreshes.
## Moving further (a drag that scrolls the dialog) is no tap. Both the picture's own and the screen's positions are
## checked, because the row moves with the finger while the dialog scrolls. It never accepts the event, so the scroll
## sees every touch too.
static func _picture_input(hud, sq: Control, act: Callable, state: Dictionary, event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			state["down"] = true
			state["at"] = mb.position
			state["global"] = mb.global_position
		elif bool(state["down"]):
			state["down"] = false
			var still: bool = mb.position.distance_to(state["at"]) < TAP_PX and mb.global_position.distance_to(state["global"]) < TAP_PX
			if still and act.is_valid() and hud._card != null and (hud._card as Node).is_ancestor_of(sq):   # not on a closing dialog
				act.call()
				hud.refresh_card()
	elif event is InputEventMouseMotion and bool(state["down"]):
		var mm := event as InputEventMouseMotion
		if mm.position.distance_to(state["at"]) >= TAP_PX or mm.global_position.distance_to(state["global"]) >= TAP_PX:
			state["down"] = false                           # moved too far: no tap on release


## The middle: the name and the badge on one line, the short lines, then the price when there is one.
static func _words(hud, row: Dictionary, title: String, cost: Dictionary) -> Control:
	var tiles: ShopTiles = hud.p_tiles
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	var tl := Label.new()
	tl.text = title
	tl.add_theme_font_override("font", tiles._bold())
	tl.add_theme_font_size_override("font_size", TITLE_FS)
	tl.add_theme_color_override("font_color", hud.TILE_INK)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tl.clip_text = true
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(tl)
	var badge := String(row.get("badge", ""))
	if badge != "":
		var pill: PanelContainer = tiles._pill(badge, tiles._list_w())   # the whole list's width: the badge keeps its font
		pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(pill)
	var text := String(row.get("text", ""))
	if text != "":
		var tx := Label.new()
		tx.text = text
		tx.add_theme_font_size_override("font_size", TEXT_FS)
		tx.add_theme_color_override("font_color", Color(0.45, 0.36, 0.26))
		tx.add_theme_constant_override("line_spacing", 0)
		tx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tx.max_lines_visible = TEXT_LINES
		tx.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		tx.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(tx)
	if tiles._price_kinds(cost) > 0:
		var room: float = tiles._list_w() - PIC - BTN.x - GAP * 2.0 - ShopTiles.TILE_PAD * 2.0
		var line: HBoxContainer = tiles._price_line(cost, maxf(room, 120.0))
		line.alignment = BoxContainer.ALIGNMENT_BEGIN
		v.add_child(line)
	return v


static func _dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}
