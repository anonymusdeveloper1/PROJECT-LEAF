extends RefCounted
## H3: the garden's window, shown inside the garden's card as a row {"kind": "window", "window": hud.garden_window}
## (ui/windows/garden_card.gd; card.gd draws it and calls the visit hooks; hud.gd ticks it while it shows).
## It looks like the garden: the 6 plots as on the bed in the camp (plot 3 2 1 over 6 5 4; the camera looks north), the
## seeds in a row below to drag onto an empty plot (ui/kit/drag_source.gd, drop_slot.gd), and Water. A tap on a ripe
## plant puts it in the Bag. It holds no game rules: every rule is in garden.gd (main.garden); this file only draws
## what garden.gd says and sends the player's taps and drops to it. It fits without scrolling (drag and scroll do not
## mix) and never redraws while a drag is on.
##
## The window API (the same for every window in a card):
##   content()  builds the whole window from Save and Timers; it runs on every rebuild of the card, so it is safe to
##              call again at any time
##   tick(d)    every frame while the window shows
##   opened()   once per visit, just before that visit's first content()
##   closed()   once, when the card closes or another card replaces it (never on a rebuild or a wave blank)

const DragSource := preload("res://ui/kit/drag_source.gd")
const DropSlot := preload("res://ui/kit/drop_slot.gd")

const ROWS := [[2, 1, 0], [5, 4, 3]]    # plot indexes as the bed shows them on screen (top row, bottom row)
const PLOT_MAX := 150.0                 # a plot square's side, HUD pixels, at most
const GAP := 10
const SEED_W := 108.0                   # five seeds and their gaps (572) fit the card's list width (590)
const SEED_H := 118.0
const TICK_S := 0.5

var hud                                 # the HUD node (untyped on purpose, as in the HUD's parts)
var main

var _root: VBoxContainer
var _plot_box: VBoxContainer            # the 2 rows of plots (rebuilt when a plot's look changes)
var _seed_box: HFlowContainer
var _water_box: VBoxContainer
var _water_btn: Button
var _times := {}                        # plot index -> Label (time left)
var _bars := {}                         # plot index -> ColorRect (the growth bar's fill)
var _bar_w := {}                        # plot index -> the bar's full width
var _plot_sig := ""
var _seed_sig := ""
var _water_sig := ""
var _t := 0.0


func _init(owner_hud) -> void:
	hud = owner_hud
	main = hud.main


func content() -> Control:
	_root = VBoxContainer.new()
	_root.add_theme_constant_override("separation", 10)
	_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_plot_box = VBoxContainer.new()
	_plot_box.add_theme_constant_override("separation", GAP)
	_plot_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_root.add_child(_plot_box)
	_seed_box = HFlowContainer.new()
	_seed_box.add_theme_constant_override("h_separation", 8)
	_seed_box.add_theme_constant_override("v_separation", 8)
	_seed_box.alignment = FlowContainer.ALIGNMENT_CENTER
	_root.add_child(_seed_box)
	_water_box = VBoxContainer.new()
	_water_box.add_theme_constant_override("separation", 4)
	_root.add_child(_water_box)
	_plot_sig = ""
	_seed_sig = ""
	_water_sig = ""
	_t = 0.0
	_refresh()
	return _root


func tick(delta: float) -> void:
	if _root == null or not is_instance_valid(_root) or not _root.is_inside_tree():
		return
	if hud.get_viewport().gui_is_dragging():
		return                                  # a redraw would drop the dragged seed's source
	_t += delta
	if _t < TICK_S:
		return
	_t = 0.0
	_refresh()


## A new visit to the garden: garden.gd counts the Gloom bump once per visit that picks something (map 3.7).
func opened() -> void:
	if main != null and main.garden != null:
		main.garden.window_opened()


func closed() -> void:
	_root = null
	_plot_box = null
	_seed_box = null
	_water_box = null
	_water_btn = null
	_times.clear()
	_bars.clear()
	_bar_w.clear()


# ---- redraw: only the parts whose look changed, then the times -----------------------------------------------------

func _garden():
	return main.garden if main != null else null


func _refresh() -> void:
	var g = _garden()
	if g == null or _root == null or not is_instance_valid(_root):
		return
	var sig := _plots_sig(g)
	if sig != _plot_sig:
		_plot_sig = sig
		_build_plots(g)
	var ssig := _seeds_sig(g)
	if ssig != _seed_sig:
		_seed_sig = ssig
		_build_seeds(g)
	var wsig := "%s|%s" % [g.can_water(), Data.garden_level()]
	if wsig != _water_sig:
		_water_sig = wsig
		_build_water(g)
	_update_times(g)


func _plots_sig(g) -> String:
	var s := "%d:" % Data.garden_level()
	for i in 6:
		s += "%s,%s,%s;" % [g.stage(i), String(g.plot(i).get("crop", "")), g.is_wet(i)]
	return s


func _seeds_sig(g) -> String:
	var s := ""
	for e in g.seeds():
		s += "%s:%s;" % [String((e as Dictionary).get("id", "")), Data.can_afford((e as Dictionary).get("price", {}))]
	return s


func _update_times(g) -> void:
	for i in _times.keys():
		var lab := _times[i] as Label
		if lab == null or not is_instance_valid(lab):
			continue
		var st: String = g.stage(int(i))
		if st == "sprout" or st == "growing":
			lab.text = _clock(g.left_s(int(i)))
		var bar := _bars.get(i) as ColorRect
		if bar != null and is_instance_valid(bar):
			var c: Dictionary = g.crop_of(int(i))
			var total := float(c.get("grow_s", 0.0))
			var frac := 0.0
			if total > 0.0:
				frac = clampf(1.0 - float(g.left_s(int(i))) / total, 0.0, 1.0)
			bar.size.x = float(_bar_w.get(i, 0.0)) * frac


# ---- the plots -----------------------------------------------------------------------------------------------------

func _plot_side() -> float:
	var w: float = hud._list_w()
	return minf(PLOT_MAX, floorf((w - 2.0 * GAP) / 3.0))


func _build_plots(g) -> void:
	_free_children(_plot_box)
	_times.clear()
	_bars.clear()
	_bar_w.clear()
	var side := _plot_side()
	for row in ROWS:
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", GAP)
		hb.alignment = BoxContainer.ALIGNMENT_CENTER
		_plot_box.add_child(hb)
		for i in row:
			hb.add_child(_plot_square(g, int(i), side))


func _plot_square(g, i: int, side: float) -> Control:
	var st: String = g.stage(i)
	var slot := DropSlot.new()
	slot.custom_minimum_size = Vector2(side, side)
	slot.accepts = func(p: Dictionary) -> bool: return String(p.get("kind", "")) == "seed" and _garden() != null and _garden().stage(i) == "empty"
	slot.dropped = _on_drop.bind(i)
	slot.tapped.connect(_on_plot_tap.bind(i))

	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(16)
	sb.set_border_width_all(3)
	sb.border_width_bottom = 5
	match st:
		"locked":
			sb.bg_color = Color(0.55, 0.5, 0.42, 0.55)
			sb.border_color = Color(0.4, 0.36, 0.3, 0.6)
		"ripe":
			sb.bg_color = Color(0.45, 0.31, 0.18)
			sb.border_color = Color(1.0, 0.82, 0.25)
			sb.set_border_width_all(5)
		_:
			sb.bg_color = Color(0.45, 0.31, 0.18)
			sb.border_color = Color(0.3, 0.2, 0.11)
	if g.is_wet(i) and st != "locked":
		sb.bg_color = Color(0.27, 0.3, 0.36)            # wet soil: darker and bluer
		sb.border_color = Color(0.35, 0.62, 0.9) if st != "ripe" else sb.border_color
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(panel)

	match st:
		"locked":
			var l := _label("Garden %d" % _level_for(i), 21, Color(0.96, 0.92, 0.84))
			_fill(slot, l)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		"empty":
			var l := _label("Drop a seed", 18, Color(0.95, 0.88, 0.74, 0.8))
			_fill(slot, l)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_:
			var c: Dictionary = g.crop_of(i)
			var pic: TextureRect = hud._btn_icon(hud.icon(String(c.get("icon", ""))))
			var frac := {"sprout": 0.4, "growing": 0.6, "ripe": 0.8}.get(st, 0.6) as float
			var ps := side * frac
			pic.custom_minimum_size = Vector2(ps, ps)
			pic.size = Vector2(ps, ps)
			pic.position = Vector2((side - ps) * 0.5, side * 0.08 + (side * 0.62 - ps) * 0.5)
			if st != "ripe":
				pic.modulate = Color(1, 1, 1, 0.55 if st == "sprout" else 0.8)
			slot.add_child(pic)
			var t := _label("Ripe: tap" if st == "ripe" else _clock(g.left_s(i)), 20, Color(1.0, 0.95, 0.7) if st == "ripe" else Color(1, 1, 1))
			t.position = Vector2(0, side - 40.0)
			t.size = Vector2(side, 24)
			t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			slot.add_child(t)
			if st != "ripe":
				_times[i] = t
				var back := ColorRect.new()
				back.color = Color(0, 0, 0, 0.35)
				back.position = Vector2(12, side - 14.0)
				back.size = Vector2(side - 24.0, 7)
				back.mouse_filter = Control.MOUSE_FILTER_IGNORE
				slot.add_child(back)
				var fill := ColorRect.new()
				fill.color = Color(0.55, 0.85, 0.35)
				fill.position = back.position
				fill.size = Vector2(0, 7)
				fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
				slot.add_child(fill)
				_bars[i] = fill
				_bar_w[i] = side - 24.0
	return slot


## The garden level that opens plot i (from balance garden.plots_by_level), for a locked plot's label.
func _level_for(i: int) -> int:
	var arr: Array = Data.b["garden"]["plots_by_level"]
	for lv in arr.size():
		if int(arr[lv]) > i:
			return lv
	return arr.size() - 1


func _on_drop(payload: Dictionary, i: int) -> void:
	var g = _garden()
	if g == null:
		return
	var reason: String = g.plant(String(payload.get("id", "")), i)
	if reason != "":
		hud.toast(reason)
	_refresh()


func _on_plot_tap(i: int) -> void:
	var g = _garden()
	if g == null:
		return
	match String(g.stage(i)):
		"ripe":
			var reason: String = g.pick(i)
			if reason != "":
				hud.toast(reason)
			_refresh()
		"locked":
			hud.toast("Garden %d opens this plot" % _level_for(i))
		"empty":
			hud.toast("Drag a seed onto the plot")


# ---- the seeds -----------------------------------------------------------------------------------------------------

func _build_seeds(g) -> void:
	_free_children(_seed_box)
	for e in g.seeds():
		_seed_box.add_child(_seed_tile(e as Dictionary))


func _seed_tile(e: Dictionary) -> Control:
	var price: Dictionary = e.get("price", {})
	var ok := Data.can_afford(price)
	var src := DragSource.new()
	src.custom_minimum_size = Vector2(SEED_W, SEED_H)
	src.payload = {"kind": "seed", "id": String(e.get("id", ""))}
	src.can_drag = ok
	src.icon = hud.icon(String(e.get("icon", "")))
	var seed_name := String(e.get("name", ""))
	src.tapped.connect(func() -> void:
		hud.toast("%s: %s" % [seed_name, "drag it onto an empty plot" if ok else "not enough leaves"]))

	var sb: StyleBoxFlat = hud._ui_style("tile")
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	src.add_child(panel)
	var pic: TextureRect = hud._btn_icon(src.icon)
	pic.custom_minimum_size = Vector2(56, 56)
	pic.size = Vector2(56, 56)
	pic.position = Vector2((SEED_W - 56.0) * 0.5, 8)
	src.add_child(pic)
	var n := _label(seed_name, _fit_size(seed_name, 17, 13, SEED_W - 8.0), hud.TILE_INK)
	n.position = Vector2(2, 66)
	n.size = Vector2(SEED_W - 4.0, 22)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER     # a smaller (fitted) name stays on the others' line
	n.clip_text = true
	src.add_child(n)
	var p := _label(_price_text(price), 19, hud.TILE_INK if ok else Color(0.75, 0.25, 0.2))
	p.position = Vector2(2, 88)
	p.size = Vector2(SEED_W - 4.0, 24)
	p.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	src.add_child(p)
	if not ok:
		src.modulate = Color(1, 1, 1, 0.6)
	return src


func _price_text(price: Dictionary) -> String:
	var parts: Array[String] = []
	for k in price.keys():
		parts.append("%d %s" % [int(price[k]), String(k)])
	return ", ".join(parts)


# ---- Water ---------------------------------------------------------------------------------------------------------

func _build_water(g) -> void:
	_free_children(_water_box)
	var can: bool = g.can_water()
	_water_btn = hud._tile_button({"label": "Water", "enabled": can, "action": _on_water}, {})
	_water_btn.add_theme_font_size_override("font_size", 24)
	_water_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_water_btn.custom_minimum_size.y = 60
	_water_box.add_child(_water_btn)
	var note := _label(_water_text(), 18, hud.TILE_INK)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_water_box.add_child(note)


## "Watered plants grow twice as fast for 5 min": both numbers come from balance.json garden (never written here).
func _water_text() -> String:
	var speed := float(Data.b["garden"].get("water_speed", 2.0))
	var mins := Data.pick("garden", "water_s_by_level", Data.garden_level()) / 60.0
	var how := "twice as fast" if is_equal_approx(speed, 2.0) else "%s times as fast" % _num(speed)
	return "Watered plants grow %s for %s min" % [how, _num(mins)]


func _on_water() -> void:
	var g = _garden()
	if g != null:
		g.water()
	_refresh()


# ---- small helpers -------------------------------------------------------------------------------------------------

func _label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## The biggest font size from fs down to min_fs at which text fits in room pixels (the HUD's font), so a long seed
## name ("Emberpeppers") stays whole on its tile.
func _fit_size(text: String, fs: int, min_fs: int, room: float) -> int:
	var f: Font = ThemeDB.fallback_font
	while fs > min_fs and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room:
		fs -= 1
	return fs


func _fill(parent: Control, child: Control) -> void:
	child.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(child)


func _free_children(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


func _clock(s: float) -> String:
	var t := int(ceilf(maxf(s, 0.0)))
	return "%d:%02d" % [floori(t / 60.0), t % 60]


func _num(x: float) -> String:
	return str(int(x)) if is_equal_approx(x, roundf(x)) else "%.1f" % x
