extends RefCounted
## H3: the cooking pot's window, shown inside the pot's card as a row {"kind": "window", "window": hud.cooking_window}
## (stations._card_pot; card.gd draws it and calls the visit hooks; hud.gd ticks it while it shows).
## It holds no game rules: every rule is in cooking.gd (main.cooking). It shows
##   - the pot's slots (cooking.pot_slots, 3): drag an ingredient in, or TAP an ingredient to fill the next empty slot
##     (Q15); a tap on a filled slot empties it. The slots are not saved: they empty when the visit ends (closed()).
##   - the matched recipe (name and desc) and Cook, lit when the pieces make a recipe and cooking.can_cook says yes;
##   - while it cooks: the recipe's icon, a bar and "Ready in 0:32"; when done: Collect;
##   - the ingredients the known recipes need, with what is left in the Bag after the pieces in the slots;
##   - a small read-only list of the known recipes and what each needs (Q15).
## Nothing leaves the Bag until Cook (Q14).
##
## The window API (the same for every window in a card):
##   content()  builds the whole window from Save, Timers and the slots; it runs on every rebuild of the card, so it
##              must be safe to call again at any time
##   tick(d)    every frame while the window shows
##   opened()   once per visit, just before that visit's first content()
##   closed()   once, when the card closes or another card replaces it (never on a rebuild or a wave blank): the slots
##              empty here

const DragSource := preload("res://ui/kit/drag_source.gd")
const DropSlot := preload("res://ui/kit/drop_slot.gd")

const INK := Color(0.25, 0.16, 0.08)            # the card's dark brown text
const INK_SOFT := Color(0.45, 0.36, 0.26)
const TILE_BG := Color(0.93, 0.85, 0.66)
const TILE_EDGE := Color(0.7, 0.55, 0.3)
const SLOT_SIZE := 118.0
const TICK_S := 0.5

var hud                                 # the HUD node (untyped on purpose, as in the HUD's parts)
var main

var _slots: Array[String] = []          # the ingredient id in each pot slot, "" when empty
var _root: VBoxContainer                # what content() last returned; the window redraws inside it
var _bar: ProgressBar
var _time_l: Label
var _sig := ""                          # what the drawn window was built from; a change means a redraw
var _acc := 0.0
var _dirty := false                     # a redraw waits for the drag to end


func _init(owner_hud) -> void:
	hud = owner_hud
	main = hud.main


func content() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root = box
	_fill()
	return box


func tick(delta: float) -> void:
	_acc += delta
	if _acc < TICK_S:
		return
	_acc = 0.0
	if _root == null or not is_instance_valid(_root) or _cooking() == null:
		return
	if _sig_now() != _sig or _dirty:
		_request_redraw()
		return
	_update_bar()


## A new visit: the slots start empty.
func opened() -> void:
	_slots.clear()
	_sig = ""


func closed() -> void:
	_slots.clear()
	_sig = ""


# ---------------------------------------------------------------------------------------------------- state

func _cooking():
	return main.cooking if main != null else null


func _slot_count() -> int:
	return maxi(1, int(Data.b.get("cooking", {}).get("pot_slots", 3)))


func _ensure_slots() -> void:
	var n := _slot_count()
	while _slots.size() < n:
		_slots.append("")
	while _slots.size() > n:
		_slots.remove_at(_slots.size() - 1)


## "idle" (empty pot), "cooking" or "ready" (the result waits for Collect).
func _mode() -> String:
	var c = _cooking()
	if c == null or String(c.cooking_id()) == "":
		return "idle"
	return "ready" if bool(c.is_ready()) else "cooking"


func _pieces() -> Array[String]:
	var out: Array[String] = []
	for s in _slots:
		if s != "":
			out.append(s)
	return out


## How many of an ingredient are still in the Bag after the pieces in the slots.
func _left(id: String) -> int:
	var used := 0
	for s in _slots:
		if s == id:
			used += 1
	return maxi(0, Bag.count(id) - used)


func _first_empty() -> int:
	for i in _slots.size():
		if _slots[i] == "":
			return i
	return -1


func _match() -> Dictionary:
	var c = _cooking()
	if c == null:
		return {}
	return c.match_recipe(_pieces())


func _sig_now() -> String:
	var c = _cooking()
	var bits: Array[String] = [_mode(), ",".join(_slots)]
	if c != null:
		for id in c.needed_ingredients():
			bits.append("%s=%d" % [id, Bag.count(String(id))])
		var m := _match()
		bits.append(String(c.can_cook(m)) if not m.is_empty() else "-")
		bits.append(str(c.known().size()))
	return "|".join(bits)


# ---------------------------------------------------------------------------------------------------- building

func _request_redraw() -> void:
	_dirty = true
	_redraw.call_deferred()


func _redraw() -> void:
	if _root == null or not is_instance_valid(_root):
		return
	if _root.get_viewport() != null and _root.get_viewport().gui_is_dragging():
		return                                  # never redraw under a finger that drags; the tick tries again
	_dirty = false
	for ch in _root.get_children():
		_root.remove_child(ch)
		ch.queue_free()
	_fill()


func _fill() -> void:
	_bar = null
	_time_l = null
	var c = _cooking()
	if c == null:
		_root.add_child(_label("The pot is not here.", 22, INK_SOFT))
		_sig = ""
		return
	_ensure_slots()
	var mode := _mode()
	if mode == "idle":
		_build_slots(c)
	else:
		_build_pot_busy(c, mode)
	_build_ingredients(c, mode)
	_build_recipes(c)
	_sig = _sig_now()


## The empty pot: the slots, the matched recipe's words and Cook.
func _build_slots(c) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	_root.add_child(row)
	for i in _slots.size():
		row.add_child(_make_slot(i))

	var m := _match()
	var why := ""
	var title := "Put ingredients in the pot"
	var desc := "Tap an ingredient, or drag it into a slot."
	if not m.is_empty():
		title = String(m.get("name", ""))
		desc = String(m.get("desc", ""))
		why = String(c.can_cook(m))
	var t := _label(title, 27, INK)
	_root.add_child(t)
	var d := _label(desc, 20, INK_SOFT)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size.y = 52                 # two lines, so the card does not jump when a recipe matches
	_root.add_child(d)
	if why != "":
		_root.add_child(_label(why, 22, Color(0.72, 0.25, 0.18)))

	var lit := not m.is_empty() and why == ""
	var cook_b := _button("Cook", lit, Color(0.36, 0.66, 0.24))
	cook_b.pressed.connect(_on_cook)
	_center(cook_b)


## While it cooks, or when it is done: the recipe's icon, the bar and the time, or Collect.
func _build_pot_busy(c, mode: String) -> void:
	var id := String(c.cooking_id())
	var r := Data.recipe(id)
	var rname := String(r.get("name", id))
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(TILE_BG, TILE_EDGE, 20, 3))
	_root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(v)
	var ic := _icon(String(r.get("icon", id)), 96)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var col := Color.html(String(r.get("color", "#ffffff")))
	var name_l := _label(rname if mode == "cooking" else "%s is ready!" % rname, 27, INK)
	name_l.add_theme_color_override("font_outline_color", col.darkened(0.2))
	v.add_child(name_l)
	if mode == "cooking":
		_bar = ProgressBar.new()
		_bar.show_percentage = false
		_bar.custom_minimum_size = Vector2(0, 26)
		_bar.max_value = 1.0
		_bar.add_theme_stylebox_override("background", _box(Color(0.78, 0.68, 0.5), TILE_EDGE, 13, 2))
		_bar.add_theme_stylebox_override("fill", _box(col.darkened(0.1), col.darkened(0.4), 13, 2))
		v.add_child(_bar)
		_time_l = _label("", 22, INK_SOFT)
		v.add_child(_time_l)
		_update_bar()
	else:
		var collect_b := _button("Collect", true, Color(0.36, 0.66, 0.24))
		collect_b.pressed.connect(_on_collect)
		var holder := CenterContainer.new()
		holder.add_child(collect_b)
		v.add_child(holder)


func _make_slot(i: int) -> Control:
	var slot := DropSlot.new()
	slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	slot.accepts = Callable(self, "_accepts")
	slot.dropped = Callable(self, "_on_drop").bind(i)
	slot.tapped.connect(_on_slot_tapped.bind(i))
	var id := _slots[i]
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := TILE_BG if id != "" else Color(0.82, 0.72, 0.52, 0.55)
	panel.add_theme_stylebox_override("panel", _box(bg, TILE_EDGE, 20, 3))
	slot.add_child(panel)
	if id != "":
		var ic := _icon(id, 84)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		panel.add_child(ic)
	return slot


## The ingredients the known recipes need, as big tiles: the icon, the count left, the name.
func _build_ingredients(c, mode: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_root.add_child(row)
	var all: Array = c.needed_ingredients()
	var room := (float(hud._list_w()) - 8.0 * float(maxi(all.size() - 1, 0))) / float(maxi(all.size(), 1)) - 10.0
	for raw in all:
		var id := String(raw)
		var left := _left(id)
		var src := DragSource.new()
		src.custom_minimum_size = Vector2(92, 118)
		src.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		src.payload = {"kind": "food", "id": id}
		src.can_drag = left > 0 and mode == "idle"
		src.icon = hud.icon(id)
		src.tapped.connect(_on_ingredient_tapped.bind(id))
		var panel := PanelContainer.new()
		panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tile_sb := _box(TILE_BG if left > 0 else Color(0.8, 0.78, 0.72), TILE_EDGE, 16, 2)
		tile_sb.content_margin_left = 4                  # narrow sides: six tiles in a row still show whole names
		tile_sb.content_margin_right = 4
		panel.add_theme_stylebox_override("panel", tile_sb)
		src.add_child(panel)
		var v := VBoxContainer.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", 0)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		panel.add_child(v)
		var ic := _icon(id, 56)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		if left <= 0:
			ic.modulate = Color(0.55, 0.55, 0.55, 0.8)     # greyed: none left, it does not drag
		v.add_child(ic)
		var cnt := _label("×%d" % left, 26, INK if left > 0 else INK_SOFT)
		v.add_child(cnt)
		var nm_text := Data.item_name(id, 2).capitalize()
		var nm := _label(nm_text, _fit_size(nm_text, 16, 12, room), INK_SOFT)   # "Emberpeppers" stays whole
		nm.clip_text = true
		v.add_child(nm)
		row.add_child(src)


## The read-only recipe list: each known recipe and what it needs.
func _build_recipes(c) -> void:
	var head := _label("Recipes", 20, INK_SOFT)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_root.add_child(head)
	for r in c.known():
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		_root.add_child(line)
		var ic := _icon(String(r.get("icon", r.get("id", ""))), 30)
		line.add_child(ic)
		var l := _label("%s: %s" % [String(r.get("name", "")), _needs_text(r)], 19, INK)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.clip_text = true
		line.add_child(l)


func _needs_text(r: Dictionary) -> String:
	var bits: Array[String] = []
	var needs: Dictionary = r.get("needs", {})
	for k in needs:
		var n := int(needs[k])
		bits.append("%d %s" % [n, Data.item_name(String(k), n).capitalize()])   # as the tiles above write them
	return " + ".join(bits)


func _update_bar() -> void:
	var c = _cooking()
	if c == null or _bar == null or not is_instance_valid(_bar):
		return
	var r := Data.recipe(String(c.cooking_id()))
	var total := maxf(1.0, float(r.get("cook_s", 1.0)))
	var left := maxf(0.0, float(c.left_s()))
	_bar.value = clampf(1.0 - left / total, 0.0, 1.0)
	if _time_l != null and is_instance_valid(_time_l):
		var s := ceili(left)
		_time_l.text = "Ready in %d:%02d" % [s / 60, s % 60]


# ---------------------------------------------------------------------------------------------------- actions

func _accepts(payload: Dictionary) -> bool:
	if _mode() != "idle" or String(payload.get("kind", "")) != "food":
		return false
	return _left(String(payload.get("id", ""))) > 0


func _on_drop(payload: Dictionary, index: int) -> void:
	var id := String(payload.get("id", ""))
	if index < 0 or index >= _slots.size() or id == "":
		return
	if _slots[index] != id and _left(id) <= 0:
		return
	_slots[index] = id
	_request_redraw()


func _on_slot_tapped(index: int) -> void:
	if index < 0 or index >= _slots.size() or _slots[index] == "":
		return
	_slots[index] = ""
	_request_redraw()


## A tap on an ingredient fills the next empty slot (Q15).
func _on_ingredient_tapped(id: String) -> void:
	match _mode():
		"cooking":
			hud.toast("Cooking already")
			return
		"ready":
			hud.toast("Collect first")
			return
	if _left(id) <= 0:
		return
	var i := _first_empty()
	if i < 0:
		hud.toast("The pot is full: tap a slot to empty it")
		return
	_slots[i] = id
	_request_redraw()


func _on_cook() -> void:
	var c = _cooking()
	if c == null:
		return
	var m := _match()
	if m.is_empty():
		hud.toast("Put ingredients in the pot")
		return
	var why := String(c.can_cook(m))
	if why == "":
		why = String(c.cook(String(m.get("id", ""))))
	if why != "":
		hud.toast(why)
		_request_redraw()
		return
	_slots.clear()
	_ensure_slots()
	_request_redraw()


func _on_collect() -> void:
	var c = _cooking()
	if c == null:
		return
	var why := String(c.collect())
	if why != "":
		hud.toast(why)
	_request_redraw()


# ---------------------------------------------------------------------------------------------------- small helpers

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## The biggest font size from fs down to min_fs at which text fits in room pixels (the HUD's font).
func _fit_size(text: String, fs: int, min_fs: int, room: float) -> int:
	var f: Font = ThemeDB.fallback_font
	while fs > min_fs and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room:
		fs -= 1
	return fs


func _icon(id: String, px: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = hud.icon(id)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(px, px)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func _box(fill: Color, edge: Color, radius: int, border: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = edge
	sb.set_border_width_all(border)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


## A big button as the card's own: green when lit, grey when not (a press then says why in a toast).
func _button(text: String, lit: bool, green: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(190, 64)
	b.add_theme_font_size_override("font_size", 28)
	b.add_theme_color_override("font_color", Color(1, 1, 1))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	var col := green if lit else Color(0.62, 0.6, 0.55)
	var sb := _box(col, col.darkened(0.35), 22, 0)
	sb.border_width_bottom = 6
	for st in ["normal", "hover", "focus", "pressed"]:
		b.add_theme_stylebox_override(st, sb)
	return b


func _center(ctrl: Control) -> void:
	var holder := CenterContainer.new()
	holder.add_child(ctrl)
	_root.add_child(holder)
