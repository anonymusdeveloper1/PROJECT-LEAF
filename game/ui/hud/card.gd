extends RefCounted
## The card: the dialog a tapped marker opens (frame, header with the X, scrolling rows, plain rows, the dim). A part of the HUD (hud.gd).
## A card opens as a dialog (19 Nov 2026, the user: "it should open like a whole UI, but not full screen. It should
## have a close button... you can still see the background of the game. You can click the close button or click away
## to close it"): DIALOG_W of the screen's width, at most DIALOG_H of the height between the phone's bars, in the
## middle, over a soft see-through dim of the game. The game runs on underneath; the dim takes every touch, so a drag
## there never moves the cat. The banner and the toast stay on top (what a button did shows there).

const HudStyle := preload("res://ui/hud/hud_style.gd")
const DIALOG_H := 0.8
const DIM_A := 0.42
const CLOSE := 68.0                     # the round X, HUD pixels (about 7 mm on the phone)
const PARCHMENT := Color(0.99, 0.95, 0.84)
const WOOD := Color(0.56, 0.35, 0.17)

var hud                                 # the HUD node (untyped on purpose: hud._stage_l and the rest are read at run time)


func _init(h) -> void:
	hud = h


func show_card(ring) -> void:
	if hud._card != null and hud._card_ring == ring:
		return
	var was_open: bool = hud._card != null
	hide_card()
	hud._card_ring = ring
	hud._dim = ColorRect.new()
	hud._dim.color = Color(0.03, 0.025, 0.02, DIM_A if was_open else 0.0)
	hud._dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud._dim.mouse_filter = Control.MOUSE_FILTER_STOP
	hud._dim.add_to_group("ui_block")
	hud._dim.gui_input.connect(_on_dim_input)
	hud._dim_down = false
	hud.add_child(hud._dim)
	hud._card = PanelContainer.new()
	hud._card.add_to_group("ui_block")
	hud._card.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = PARCHMENT
	sb.border_color = WOOD
	sb.set_border_width_all(6)
	sb.set_corner_radius_all(26)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 18
	sb.shadow_offset = Vector2(0, 6)
	sb.set_content_margin_all(6)
	hud._card.add_theme_stylebox_override("panel", sb)
	hud.add_child(hud._card)
	hud.move_child(hud._banner, -1)                          # what a button did shows over the dialog
	hud.move_child(hud._toast, -1)
	_fill_card(_spec(ring))
	hud._card_in = 0.0
	hud._card.modulate.a = 0.0
	var tw: Tween = hud._card.create_tween().set_parallel()
	tw.tween_property(hud, "_card_in", 1.0, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(hud._card, "modulate:a", 1.0, 0.12)
	tw.tween_property(hud._dim, "color:a", DIM_A, 0.15)
	hud._quit_back = hud.get_tree().quit_on_go_back           # Android's back button closes the dialog, not the game
	hud.get_tree().quit_on_go_back = false
	_place_card()


func hide_card() -> void:
	if hud._card != null:
		var c: PanelContainer = hud._card
		hud._card = null
		c.remove_from_group("ui_block")
		for b in c.find_children("*", "BaseButton", true, false):
			(b as BaseButton).disabled = true          # nothing on a closing dialog takes a tap
		var tw := c.create_tween().set_parallel()
		tw.tween_property(c, "modulate:a", 0.0, 0.12)
		tw.tween_property(c, "scale", Vector2.ONE * 0.95, 0.12)
		tw.chain().tween_callback(c.queue_free)
		hud.get_tree().quit_on_go_back = hud._quit_back
	if hud._dim != null:
		var dm: ColorRect = hud._dim
		hud._dim = null
		dm.remove_from_group("ui_block")
		dm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tw2 := dm.create_tween()
		tw2.tween_property(dm, "color:a", 0.0, 0.12)
		tw2.tween_callback(dm.queue_free)
	hud._card_ring = null
	hud._close_btn = null
	hud._card_head = null
	hud._card_scroll = null
	hud._card_list = null
	hud._card_title = null
	hud._card_sub = null
	hud._card_body = null
	hud._card_tabs = null
	hud._card_nav = null
	hud._card_view_id = ""
	hud._card_render_signature = ""


## A tap on the dim (outside the dialog) closes it; a drag there does nothing.
func _on_dim_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or (event as InputEventMouseButton).button_index != MOUSE_BUTTON_LEFT:
		return
	var mb := event as InputEventMouseButton
	if mb.pressed:
		hud._dim_down = true
		hud._dim_from = mb.position
	elif hud._dim_down:
		hud._dim_down = false
		if mb.position.distance_to(hud._dim_from) < 40.0:
			hide_card()
	hud.get_viewport().set_input_as_handled()


## A dialog is open (the Burrows' camera then keeps the camp's focus).
func card_open() -> bool:
	return hud._card != null


## The marker whose dialog is open (null when none).
func card_ring():
	return hud._card_ring if hud._card != null else null


func refresh_card() -> void:
	if hud._card != null and hud._card_ring != null:
		_fill_card(_spec(hud._card_ring))


## The open dialog's name ("" when none is open; the tests read it).
func card_title() -> String:
	return hud._card_title.text if hud._card != null and hud._card_title != null else ""


## Phase F: scrolls the open dialog to the first row or shop tile (not a goal line) whose words hold `needle`, and
## makes it glow a moment: a goal on the home's card that is sold further down the same card. Waits for the rows to be
## laid out.
func scroll_card_to(needle: String) -> void:
	if needle == "":
		return
	await hud.get_tree().process_frame
	await hud.get_tree().process_frame
	if hud._card == null or hud._card_list == null or not is_instance_valid(hud._card_list) or hud._card_scroll == null:
		return
	for h in hud._card_list.get_children():
		if not (h as Control).visible or h.has_meta("goal") or h.has_meta("section"):
			continue
		if h.has_meta("grid"):                          # Phase G2: a grid of tiles, the tile itself
			for tile in (h as Node).get_children():
				if _holds_text(tile, needle):
					_glow_at(tile as Control, (h as Control).position.y + (tile as Control).position.y)
					return
			continue
		if h is HBoxContainer and _holds_text(h, needle):
			_glow_at(h as Control, (h as Control).position.y)
			return


## A label under n holds `needle`.
func _holds_text(n: Node, needle: String) -> bool:
	for l in n.find_children("*", "Label", true, false):
		if String((l as Label).text).contains(needle):
			return true
	return false


## The dialog scrolled to y (in its list), and the row or tile there glows a moment.
func _glow_at(row: Control, y: float) -> void:
	hud._card_scroll.scroll_vertical = int(y)
	row.modulate = Color(1.35, 1.25, 0.85)
	row.create_tween().tween_property(row, "modulate", Color(1, 1, 1), 0.9)


## A marker's card. While a wave is on only the signpost and the barricade rows' markers (repair) work: the shops and stations open between waves.
func _spec(ring) -> Dictionary:
	if ring == hud.inventory:
		return hud.inventory.spec()
	var spec: Dictionary = ring.builder.call()
	var f = hud.main.fight
	if f.active and f.in_wave and ring != hud.main.stations.rings.get("sign") and not String(ring.key).begins_with("road_"):
		return {"title": spec.get("title", ""), "sub": "A wave is on! This opens again between waves.", "rows": [],
			"anchor": spec.get("anchor", Vector3.ZERO)}
	return spec


func card_buttons() -> Array:
	# for the automated test: the rows' buttons (not the X)
	var out: Array = []
	if hud._card == null:
		return out
	_collect_buttons(hud._card, out)
	out.erase(hud._close_btn)
	return out


## The dialog's X (the tests tap it).
func close_button() -> Button:
	return hud._close_btn


func _collect_buttons(n: Node, out: Array) -> void:
	if n is Button:
		out.append(n)
	for c in n.get_children():
		_collect_buttons(c, out)


## The dialog's frame, made once when it opens: the header strip (the name, its line, the X) and the body that scrolls.
func _card_frame() -> void:
	for c in hud._card.get_children():
		c.queue_free()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	hud._card.add_child(v)
	var head := PanelContainer.new()
	var hs := StyleBoxFlat.new()
	hs.bg_color = WOOD
	hs.corner_radius_top_left = 20
	hs.corner_radius_top_right = 20
	hs.border_color = Color(0.86, 0.66, 0.24)
	hs.border_width_bottom = 4
	hs.content_margin_left = 12
	hs.content_margin_right = 10
	hs.content_margin_top = 10
	hs.content_margin_bottom = 12
	head.add_theme_stylebox_override("panel", hs)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(head)
	hud._card_head = head
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(hb)
	var balance := Control.new()                    # as wide as the X, so the name sits in the middle
	balance.custom_minimum_size = Vector2(CLOSE, 0)
	balance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(balance)
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tv.add_theme_constant_override("separation", 0)
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(tv)
	var title: Label = HudStyle.label("", 36)
	title.add_theme_color_override("font_color", Color(1.0, 0.95, 0.82))
	title.add_theme_color_override("font_outline_color", Color(0.25, 0.13, 0.05, 0.9))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tv.add_child(title)
	hud._card_title = title
	var sub: Label = HudStyle.label("", 20)
	sub.add_theme_color_override("font_color", Color(1.0, 0.86, 0.62))
	sub.add_theme_color_override("font_outline_color", Color(0.25, 0.13, 0.05, 0.8))
	sub.add_theme_constant_override("outline_size", 5)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tv.add_child(sub)
	hud._card_sub = sub
	hud._close_btn = _make_close()
	hb.add_child(hud._close_btn)
	hud._card_tabs = HBoxContainer.new()
	hud._card_tabs.add_theme_constant_override("separation", 8)
	hud._card_nav = MarginContainer.new()
	v.add_child(hud._card_nav)
	hud._card_nav.add_child(hud._card_tabs)
	hud._card_nav.visible = false
	hud._card_tabs.visible = false
	var body := MarginContainer.new()
	body.add_theme_constant_override("margin_left", 16)
	body.add_theme_constant_override("margin_right", 16)
	body.add_theme_constant_override("margin_top", 4)
	body.add_theme_constant_override("margin_bottom", 12)
	v.add_child(body)
	hud._card_body = body
	hud._card_scroll = ScrollContainer.new()
	hud._card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(hud._card_scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud._card_scroll.add_child(list)
	hud._card_list = list


## The dialog's contents: its name and line in the header, then the rows, in the body that scrolls inside the dialog
## when they are taller than it may be. Phase G2: a row {"kind": "section"} is a shelf heading; a run of rows
## {"kind": "item"} is one grid of shop tiles (_item_grid); any other row is a plain row, drawn as before (_plain_row).
func _fill_card(spec: Dictionary) -> void:
	var scroll: int = hud._card_scroll.scroll_vertical if hud._card_scroll != null else 0
	hud._card_anchor = spec.get("anchor", Vector3.ZERO)
	var rows: Array = spec.get("rows", [])
	var view_id := String(spec.get("view_id", ""))
	var signature: String = hud.p_sign._signpost_signature(spec) if view_id != "" else ""
	if view_id != "" and view_id == hud._card_view_id and signature == hud._card_render_signature and is_instance_valid(hud._card_list):
		return                                      # live HUD refreshes keep the list and its animations steady
	var reveal: bool = view_id != "" and view_id != hud._card_view_id
	hud._card_view_id = view_id
	hud._card_render_signature = signature
	if hud._card_list == null or not is_instance_valid(hud._card_list):
		_card_frame()
	var spacious := bool(spec.get("spacious", false))
	hud._card_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER if spacious else ScrollContainer.SCROLL_MODE_AUTO
	hud._card_list.add_theme_constant_override("separation", 16 if spacious else 6)
	for side in ["left", "right"]:
		hud._card_body.add_theme_constant_override("margin_" + side, 18 if spacious else 16)
		hud._card_nav.add_theme_constant_override("margin_" + side, 18 if spacious else 0)
	hud._card_body.add_theme_constant_override("margin_top", 0 if spacious else 4)
	hud._card_body.add_theme_constant_override("margin_bottom", 18 if spacious else 12)
	hud._card_nav.add_theme_constant_override("margin_top", 18 if spacious else 0)
	hud._card_nav.add_theme_constant_override("margin_bottom", 18 if spacious else 0)
	hud._card_tabs.add_theme_constant_override("separation", 14 if spacious else 8)
	# a refresh (leaves spent, a wave starting) keeps the frame, the X and the scroll; only the words and rows change
	hud._card_title.text = String(spec.get("title", ""))
	hud._card_sub.text = String(spec.get("sub", ""))
	hud._card_sub.visible = hud._card_sub.text != ""
	_fill_card_tabs(spec.get("tabs", []))
	hud._card_body.visible = not rows.is_empty()
	for c in hud._card_list.get_children():
		(c as Control).visible = false              # gone from the layout now (a pressed button finishes its press first)
		c.queue_free()
	var list: VBoxContainer = hud._card_list
	var prev := ""                                  # what came last: "" (nothing yet), "row", "small", "section", "grid"
	var i := 0
	while i < rows.size():
		var row: Dictionary = rows[i]
		var kind := String(row.get("kind", ""))
		if kind == "inventory":
			list.add_child(hud.inventory.content())
			i += 1
			continue
		if kind == "pantry":
			list.add_child(pantry_strip())
			i += 1
			continue
		if kind == "item":
			var items: Array = []                       # consecutive tiles make one grid
			while i < rows.size() and String((rows[i] as Dictionary).get("kind", "")) == "item":
				items.append(rows[i])
				i += 1
			list.add_child(hud.p_tiles._item_grid(items))
			prev = "grid"
			continue
		i += 1
		if kind == "section":
			list.add_child(hud.p_tiles._section_row(String(row.get("text", "")), prev != ""))
			prev = "section"
			continue
		if kind == "mission":
			list.add_child(hud.p_sign._mission_row(row))
			prev = "mission"
			continue
		if spacious:
			var panel: PanelContainer = hud.p_sign._signpost_panel()
			list.add_child(panel)
			var inner := VBoxContainer.new()
			panel.add_child(inner)
			_plain_row(inner, row, false)
			for button in panel.find_children("*", "Button", true, false):
				hud.p_sign._signpost_button_motion(button as Button)
			prev = "row"
			continue
		# Phase F: a "small" row is one compact line (the home's goals): no rule between two of them, a smaller font and
		# button. A rule between two plain rows, as before (a tile or a heading next to it needs none).
		var small := bool(row.get("small", false))
		if (prev == "row" or prev == "small") and not (small and prev == "small"):
			var sep := HSeparator.new()
			sep.add_theme_constant_override("separation", 6)
			list.add_child(sep)
		prev = "small" if small else "row"
		_plain_row(list, row, small)
	hud._card_scroll.set_deferred("scroll_vertical", scroll)
	if reveal:
		var index := 0
		for child in list.get_children():
			if (child as Control).visible:
				hud.p_sign._reveal_signpost_control(child as Control, minf(index * 0.025, 0.15))
				index += 1
		for button in hud._card_tabs.get_children():
			hud.p_sign._reveal_signpost_control(button as Control, 0.0)


func _fill_card_tabs(tabs: Array) -> void:
	for child in hud._card_tabs.get_children():
		child.hide()
		child.queue_free()
	hud._card_tabs.visible = not tabs.is_empty()
	hud._card_nav.visible = hud._card_tabs.visible
	for tab in tabs:
		var selected := bool(tab.get("selected", false))
		var enabled := bool(tab.get("enabled", true))
		var color := Color(0.72, 0.43, 0.17) if selected else Color(0.29, 0.48, 0.58)
		if not enabled and not selected:
			color = Color(0.5, 0.49, 0.45)
		var button: Button = hud.p_actions._big_button(String(tab["text"]), color, tab.get("action", Callable()), enabled)
		button.custom_minimum_size = Vector2(0, 64)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 26)
		button.set_meta("card_tab", true)
		hud._card_tabs.add_child(button)
		hud.p_sign._signpost_button_motion(button)


func pantry_strip() -> Control:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 12)
	flow.add_theme_constant_override("v_separation", 6)
	for id in Data.b["ingredients"]:
		if not Data.food_known(String(id)):
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 5)
		flow.add_child(row)
		var picture: TextureRect = _btn_icon(hud.icon(id))
		picture.custom_minimum_size = Vector2(28, 28)
		row.add_child(picture)
		var label := Label.new()
		label.text = "%s %d/%d" % [Data.item_name(String(id), 2).capitalize(), int(Save.pantry.get(id, 0)), int(Data.b["cooking"]["pantry_cap"])]
		label.add_theme_font_size_override("font_size", 19)
		label.add_theme_color_override("font_color", hud.TILE_INK)
		row.add_child(label)
	return flow


## A plain row (the card rows from before Phase G2): its words and note, and a button with its price. "done" (with
## "small") puts a tick (true) or an open ring (false) before its words.
func _plain_row(list: VBoxContainer, row: Dictionary, small: bool) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10 if small else 12)
	if small:
		h.set_meta("goal", true)
	list.add_child(h)
	if small and row.has("done"):
		var mark: TextureRect = _btn_icon(hud.icon("tick" if bool(row["done"]) else "todo"))
		mark.custom_minimum_size = Vector2(28, 28)
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(mark)
	var txt := VBoxContainer.new()
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	txt.size_flags_vertical = Control.SIZE_SHRINK_CENTER if small else Control.SIZE_FILL
	txt.add_theme_constant_override("separation", 0)
	h.add_child(txt)
	var a := Label.new()
	a.text = String(row.get("text", ""))
	a.add_theme_font_size_override("font_size", 23 if small else 26)
	var done_row := small and bool(row.get("done", false))
	a.add_theme_color_override("font_color", Color(0.3, 0.45, 0.16) if done_row else Color(0.25, 0.16, 0.08))
	a.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	txt.add_child(a)
	var note := String(row.get("note", ""))
	if note != "":
		var b := Label.new()
		b.text = note
		b.add_theme_font_size_override("font_size", 19)
		b.add_theme_color_override("font_color", Color(0.45, 0.36, 0.26))
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		txt.add_child(b)
	var label := String(row.get("label", ""))
	if label != "":
		h.add_child(_cost_button(row))


func _cost_button(row: Dictionary) -> Button:
	var cost: Dictionary = row.get("cost", {})
	var enabled: bool = row.get("enabled", false)
	var small := bool(row.get("small", false)) and cost.is_empty()
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(112, 50) if small else Vector2(150, 64)
	btn.focus_mode = Control.FOCUS_NONE
	btn.disabled = not enabled
	btn.set_meta("label", String(row.get("label", "")))
	var green := StyleBoxFlat.new()
	green.bg_color = Color(0.36, 0.66, 0.24) if enabled else Color(0.62, 0.6, 0.55)
	green.set_corner_radius_all(18)
	green.border_color = Color(0.2, 0.42, 0.12) if enabled else Color(0.45, 0.43, 0.4)
	green.border_width_bottom = 5
	var pressed := green.duplicate() as StyleBoxFlat
	pressed.bg_color = green.bg_color.darkened(0.15)
	pressed.border_width_bottom = 2
	for st in ["normal", "hover", "focus"]:
		btn.add_theme_stylebox_override(st, green)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", green)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 4)
	btn.add_child(h)
	if cost.is_empty():
		h.add_child(_btn_label(String(row.get("label", "")), 24 if small else 28))
	else:
		# every currency the cost asks for (Data.CURRENCIES; other keys such as needs_* are not money)
		var n_cur := 0
		for k in Data.CURRENCIES:
			if int(cost.get(k, 0)) > 0:
				n_cur += 1
		var fs := 22 if n_cur >= 3 else 26
		btn.custom_minimum_size = Vector2(maxf(150.0, 24.0 + 78.0 * n_cur) if n_cur > 1 else 150.0, 64)
		for k in Data.CURRENCIES:
			var n := int(cost.get(k, 0))
			if n > 0:
				h.add_child(_btn_icon(hud.icon(k)))
				h.add_child(_btn_label(str(n), fs, Data.have(k) >= n))
	var action: Callable = row.get("action", Callable())
	if enabled and action.is_valid():
		btn.pressed.connect(func():
			action.call()
			refresh_card())
	return btn


func _btn_label(t: String, size: int, ok := true) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(1, 1, 1) if ok else Color(1.0, 0.75, 0.7))
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.25, 0.05, 0.8))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _btn_icon(tex: Texture2D) -> TextureRect:
	var i := TextureRect.new()
	i.texture = tex
	i.custom_minimum_size = Vector2(30, 30)
	i.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	i.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return i


## The round X in the dialog's header: big enough for a thumb, terracotta on the wood.
func _make_close() -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(CLOSE, CLOSE)
	b.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	b.focus_mode = Control.FOCUS_NONE
	b.set_meta("label", "Close")
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.86, 0.38, 0.24)
	sb.set_corner_radius_all(int(CLOSE * 0.5))
	sb.border_color = Color(1.0, 0.93, 0.8)
	sb.set_border_width_all(4)
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 2)
	for st in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	var pr := sb.duplicate() as StyleBoxFlat
	pr.bg_color = sb.bg_color.darkened(0.2)
	b.add_theme_stylebox_override("pressed", pr)
	b.add_theme_stylebox_override("disabled", sb)
	var x := Control.new()
	x.set_anchors_preset(Control.PRESET_FULL_RECT)
	x.mouse_filter = Control.MOUSE_FILTER_IGNORE
	x.draw.connect(func():
		var c := x.size * 0.5
		var col := Color(1.0, 0.97, 0.9)
		for d in [Vector2(1, 1), Vector2(1, -1)]:
			x.draw_line(c - d * 13.0, c + d * 13.0, col, 7.0, true)
			x.draw_circle(c - d * 13.0, 3.5, col)
			x.draw_circle(c + d * 13.0, 3.5, col))
	b.add_child(x)
	b.pressed.connect(hide_card)
	return b


## The dialog in the middle of the clear part of the screen (between the phone's bars): DIALOG_W wide, as tall as its
## rows up to DIALOG_H (then they scroll inside); it pops in as it opens.
func _place_card() -> void:
	var size: Vector2 = hud.get_viewport().get_visible_rect().size
	var w: float = size.x * hud.DIALOG_W
	hud._card.custom_minimum_size.x = w
	var top: float = hud._safe.x + 8.0
	var bottom: float = size.y - hud._safe.y - 8.0
	var max_h := (bottom - top) * DIALOG_H
	if hud._card_scroll != null and hud._card_list != null and hud._card_head != null:
		var room: float = max_h - hud._card_head.get_combined_minimum_size().y - 12.0 - 16.0
		if hud._card_nav != null and hud._card_nav.visible:
			room -= hud._card_nav.get_combined_minimum_size().y
		room -= hud._card_body.get_theme_constant("margin_top") + hud._card_body.get_theme_constant("margin_bottom") - 16.0
		hud._card_scroll.custom_minimum_size.y = clampf(hud._card_list.get_combined_minimum_size().y, 0.0, maxf(room, 120.0))
	var cs: Vector2 = hud._card.get_combined_minimum_size()
	cs.x = w
	hud._card.size = cs
	hud._card.position = Vector2((size.x - cs.x) * 0.5, top + (bottom - top - cs.y) * 0.5)
	hud._card.pivot_offset = cs * 0.5
	hud._card.scale = Vector2.ONE * lerpf(0.88, 1.0, hud._card_in)
