extends CanvasLayer
## Everything drawn on top of the game. There are no menus. The screen (18 Nov 2026, the user's call; see
## docs/PHASE_A_PROGRESS.md, "Camp layout and HUD"):
##   the top      one slim bar on a soft dark strip: leaves, timber, shards (the satchel below ground), the dish of the
##                chapter and the endgame-save label on the left; the fight's bar (the campfire, the raid meter and its
##                countdown, the Burrow's fight pips) and the status line on the right. Under it the boss bar, then the
##                banners (a compact strip), the toast and the status or hiding line.
##   the bottom   the buttons (Ride / Feed / Snack, the defences to place), the tip and the hint just above them.
##   the middle   nothing but the health bars over the cat (lifebar.gd) and the pointer arrow: the cat stands there.
##   a card       (19 Nov 2026, the user's call) the card of a thing the player tapped (marker.gd, interact.gd) opens as
##                a dialog in the middle of the screen over a soft dim of the game: a header with its name and a round
##                close button, its rows below (scrolling inside when long). The X, a tap on the dim, Android's back
##                button or Escape close it. Inside (20 Nov 2026, the user: "like a whole shop store"; Phase G2) the
##                things to buy are shop tiles in a grid (rows {"kind": "item"}, 2 a row on a phone) under small shelf
##                headings ({"kind": "section"}); the plain rows ({text, note, cost, label, ...}) draw as before.
## The phone's safe area (status bar, camera hole, gesture bar) is kept clear (--safe-top= / --safe-bottom= try it on a
## PC, in HUD pixels).

const LifebarScript := preload("res://scripts/lifebar.gd")
const ArrowsScript := preload("res://scripts/threat_arrows.gd")
const UiIcons := preload("res://scripts/ui_icons.gd")           # Phase G2: the shop tiles' pictures
const ROW_H := 48.0                     # the top bar's first line: riches on the left, the fight's bar on the right
const LINE2_H := 24.0                   # its second line, when there is something on it: the dish, the status line
const GATE_W := 236.0
const EDGE := 14.0                      # side margins
const STRIP := Color(0.06, 0.045, 0.03, 0.46)

var main
var boss = null
var _leaf_tex: ImageTexture
var _log_tex: ImageTexture
var _leaves_l: Label
var _timber_l: Label
var _timber_box: HBoxContainer
var _shard_tex: ImageTexture            # Phase D: Gloom shards
var _shard_l: Label
var _shard_box: HBoxContainer
var _shown_shards := 0
var shards_held := 0                    # shards banked but still flying to the cat (the shower): not counted up yet
var _held_t := 0.0
var _meal_l: Label                     # the dish eaten this chapter, or waiting in the pot (Phase C)
var _eg_l: Label                       # "Endgame test save" (the debug endgame start)
var _res: HBoxContainer                # the top bar's left: leaves, timber, shards, the satchel below ground
var _line2: HBoxContainer              # ... its second line: the endgame label, the dish
var _top: Panel                        # the soft dark strip behind the top bar
var _lifebar: Control                  # the health bars over the cat (and its mount)
var _stage_l: Label
var _gate_bar: Control
var _boss_bar: Control
var _banner: PanelContainer
var _banner_t: Label
var _banner_s: Label
var _banner_tw: Tween
var _toast: Label
var _toast_tw: Tween
var _tip: Label
var _hint: Label
var _overlay: Control
var _card: PanelContainer              # the open dialog (null when none)
var _card_key := ""
var _card_anchor := Vector3.ZERO
var _card_ring = null
var _card_in := 0.0                    # the dialog popping in: 0 = small and clear, 1 = open
var _dim: ColorRect                    # the soft dark see-through cover over the game behind a dialog
var _dim_down := false                 # a touch went down on the dim (a tap on it closes the dialog)
var _dim_from := Vector2.ZERO
var _card_head: Control                # the dialog's header strip (its name, its line, the X)
var _card_scroll: ScrollContainer      # the dialog's rows, scrolling inside when long
var _card_list: VBoxContainer
var _card_title: Label
var _card_sub: Label
var _card_body: Control
var _close_btn: Button                 # the round X
var _quit_back := true                 # what Android's back button did before the dialog took it
var _tip_ring = null
var _tip_time := 0.0
var _shown_leaves := 0
var _gate_flash := 0.0
var _build_bar: HBoxContainer
var _hide_l: Label
var _place_bar: HBoxContainer
var status := ""                        # a line under the top bar (rebuilding the campfire...)
var _point_pos := Vector3.ZERO          # point_at: an arrow to a spot in the world (a raid's trail), for _point_t s
var _point_t := 0.0
var _bar_key := ""                      # what the raid bar last drew (it redraws only when this changes)
var _feed_ok := false                   # the Feed button was built enabled
var _fade: ColorRect                    # Phase E: the full-screen fade between the camp and the Burrows (its own layer)
var _satchel_box: HBoxContainer         # Phase E: the satchel below ground, in the top bar after the leaves
var _safe := Vector2.ZERO               # the phone's safe insets in HUD pixels: top, bottom
var _top_h := ROW_H                     # how tall the top bar is now (with its second line or without)
var _zone_end := 0.0                    # the bottom of everything at the top (the bar, the boss bar, a banner, ...)


func build(m) -> void:
	main = m
	_leaf_tex = _make_leaf()
	_log_tex = _make_log()
	_shard_tex = _make_shard()
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	# the top bar's strip
	_top = Panel.new()
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ts := StyleBoxFlat.new()
	ts.bg_color = STRIP
	ts.corner_radius_bottom_left = 18
	ts.corner_radius_bottom_right = 18
	_top.add_theme_stylebox_override("panel", ts)
	add_child(_top)
	# leaves, timber, shards (and below ground the satchel)
	_res = HBoxContainer.new()
	_res.add_theme_constant_override("separation", 16)
	_res.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_res)
	var lb := _icon_row(_leaf_tex)
	_leaves_l = lb[1]
	_res.add_child(lb[0])
	var tb := _icon_row(_log_tex)
	_timber_box = tb[0]
	_timber_l = tb[1]
	_res.add_child(_timber_box)
	var sb := _icon_row(_shard_tex)
	_shard_box = sb[0]
	_shard_l = sb[1]
	_res.add_child(_shard_box)
	_satchel_box = HBoxContainer.new()
	_satchel_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_satchel_box.add_theme_constant_override("separation", 5)
	_satchel_box.visible = false
	_res.add_child(_satchel_box)
	_line2 = HBoxContainer.new()
	_line2.add_theme_constant_override("separation", 12)
	_line2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_line2)
	_eg_l = _label("Endgame test save", 16)
	_eg_l.add_theme_color_override("font_color", Color(1.0, 0.75, 0.5))
	_eg_l.visible = Save.endgame_slot                  # the debug endgame start: never mistaken for the real save
	_line2.add_child(_eg_l)
	_meal_l = _label("", 17)
	_meal_l.visible = false
	_meal_l.add_theme_color_override("font_color", Color(1.0, 0.93, 0.75))
	_meal_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_line2.add_child(_meal_l)
	_lifebar = Control.new()
	_lifebar.set_script(LifebarScript)
	_lifebar.main = main
	add_child(_lifebar)
	move_child(_lifebar, 0)                         # under the cards and banners
	var arrows := Control.new()                     # where an attack comes from: arrows at the screen's edge
	arrows.set_script(ArrowsScript)
	arrows.main = main
	add_child(arrows)
	# the fight: the status line and the bar on the right of the top bar, the boss bar under it
	_stage_l = _label("", 18)
	_stage_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stage_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_stage_l.clip_text = true
	add_child(_stage_l)
	_gate_bar = Control.new()
	_gate_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gate_bar.draw.connect(_draw_gate)
	add_child(_gate_bar)
	_boss_bar = Control.new()
	_boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_bar.draw.connect(_draw_boss)
	add_child(_boss_bar)
	# the banner: a compact strip under the top bar
	_banner = PanelContainer.new()
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.06, 0.045, 0.03, 0.55)
	bs.set_corner_radius_all(16)
	bs.content_margin_left = 16
	bs.content_margin_right = 16
	bs.content_margin_top = 6
	bs.content_margin_bottom = 8
	_banner.add_theme_stylebox_override("panel", bs)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 0)
	bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_child(bv)
	_banner_t = _label("", 30)
	_banner_t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner_s = _label("", 19)
	_banner_s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bv.add_child(_banner_t)
	bv.add_child(_banner_s)
	_banner.modulate.a = 0.0
	add_child(_banner)
	_toast = _label("", 22)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.modulate.a = 0.0
	add_child(_toast)
	_hide_l = _label("", 21)
	_hide_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_hide_l)
	# the tip and the hint: small lines just above the buttons at the bottom
	_tip = _label("", 21)
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.max_lines_visible = 2
	_tip.modulate.a = 0.0
	add_child(_tip)
	_hint = _label("Drag anywhere to move · tap things to use them", 22)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_hint)
	# building: a button per kind of piece the cat has bought; while placing, Place and Done
	_build_bar = HBoxContainer.new()
	_build_bar.add_theme_constant_override("separation", 10)
	_build_bar.alignment = BoxContainer.ALIGNMENT_END
	add_child(_build_bar)
	_place_bar = HBoxContainer.new()
	_place_bar.add_theme_constant_override("separation", 14)
	_place_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_place_bar)
	var fl := CanvasLayer.new()
	fl.layer = 20
	add_child(fl)
	_fade = ColorRect.new()
	_fade.color = Color(0.043, 0.059, 0.039, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.visible = false
	fl.add_child(_fade)
	get_viewport().size_changed.connect(_layout)
	Save.changed.connect(_on_save_changed)
	_shown_leaves = Save.leaves
	_shown_shards = Save.shards
	_layout()
	refresh()


func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(1, 1, 1))
	l.add_theme_color_override("font_outline_color", Color(0.12, 0.08, 0.05, 0.85))
	l.add_theme_constant_override("outline_size", maxi(6, size / 3))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _icon_row(tex: Texture2D) -> Array:
	var box := HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 5)
	var icon := TextureRect.new()
	icon.texture = tex
	icon.custom_minimum_size = Vector2(32, 32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)
	var l := _label("0", 28)
	box.add_child(l)
	return [box, l]


## The phone's safe insets (status bar and camera hole on top, the gesture bar at the bottom), in HUD pixels.
func _insets() -> Vector2:
	var out := Vector2.ZERO
	for a in Data.args():
		if a.begins_with("--safe-top="):
			out.x = float(a.substr(11))
		elif a.begins_with("--safe-bottom="):
			out.y = float(a.substr(14))
	if OS.has_feature("mobile"):
		var win := DisplayServer.window_get_size()
		var at := DisplayServer.window_get_position()
		var safe := DisplayServer.get_display_safe_area()
		var vis := get_viewport().get_visible_rect().size
		if win.y > 0 and safe.size.y > 0:
			var k := vis.y / float(win.y)
			out.x = maxf(out.x, float(safe.position.y - at.y) * k)
			out.y = maxf(out.y, float(at.y + win.y - safe.end.y) * k)
	return Vector2(clampf(out.x, 0.0, 160.0), clampf(out.y, 0.0, 120.0))


func _layout() -> void:
	_safe = _insets()
	_place_all()
	if _card != null and _card_list != null and is_instance_valid(_card_list):
		var n := _grid_cols()                         # the screen turned or changed size: the open dialog's grids follow
		for g in _card_list.get_children():
			if g is GridContainer and (g as GridContainer).columns != n:
				(g as GridContainer).columns = n


## Where everything goes this frame: the top bar grows a second line when there is something on it, and what sits
## under it stacks down (boss bar, banner, toast, status line); at the bottom the buttons, with the tip and the hint
## just above them. A dialog takes none of this room: it sits over the dim (_place_card).
func _place_all() -> void:
	var size := get_viewport().get_visible_rect().size
	var t := _safe.x
	var two: bool = _stage_l.visible or _meal_l.visible or _eg_l.visible
	_top_h = ROW_H + (LINE2_H if two else 0.0) + 4.0
	_top.position = Vector2(0, 0)
	_top.size = Vector2(size.x, t + _top_h)
	_res.position = Vector2(EDGE, t + 8)
	_res.size = Vector2(size.x * 0.6, 34)
	_gate_bar.position = Vector2(size.x - EDGE - GATE_W, t + 10)
	_gate_bar.size = Vector2(GATE_W, 30)
	_line2.position = Vector2(EDGE, t + ROW_H)
	_line2.size = Vector2(0, LINE2_H)
	var used := 0.0
	if _eg_l.visible:
		used += _text_w(_eg_l)
	if _meal_l.visible:
		var mw := minf(_text_w(_meal_l), size.x * 0.4)
		_meal_l.custom_minimum_size = Vector2(mw, 0)
		used += mw + (12.0 if _eg_l.visible else 0.0)
	var gap := 16.0 if used > 0.0 else 0.0
	_stage_l.position = Vector2(EDGE + used + gap, t + ROW_H - 2)
	_stage_l.size = Vector2(size.x - EDGE * 2.0 - used - gap, LINE2_H)
	var y := t + _top_h + 6.0
	_boss_bar.position = Vector2(EDGE + 4, y)
	_boss_bar.size = Vector2(size.x - EDGE * 2.0 - 8.0, 30)
	if _boss_bar.visible:
		y += 36.0
	_banner.position = Vector2(26, y)
	_banner.size = Vector2(size.x - 52, 0)
	_banner.custom_minimum_size = Vector2(size.x - 52, 0)
	if _banner.modulate.a > 0.01:
		y += _banner.get_combined_minimum_size().y + 6.0
	_toast.position = Vector2(30, y)
	_toast.size = Vector2(size.x - 60, 30)
	if _toast.modulate.a > 0.01:
		y += _toast.get_combined_minimum_size().y + 2.0
	_hide_l.position = Vector2(0, y)
	_hide_l.size = Vector2(size.x, 28)
	if _hide_l.visible:
		y += 30.0
	_zone_end = y
	# the bottom: the buttons above the gesture bar
	var bottom := size.y - _safe.y
	var bar_y := bottom - 16.0 - 84.0
	var buttons := true
	_build_bar.position = Vector2(20, bar_y)
	_build_bar.size = Vector2(size.x - 40, 84)
	_place_bar.position = Vector2(20, bar_y - 6.0)
	_place_bar.size = Vector2(size.x - 40, 96)
	_build_bar.modulate.a = 1.0 if buttons else 0.0
	_place_bar.modulate.a = 1.0 if buttons else 0.0
	_build_bar.mouse_filter = Control.MOUSE_FILTER_PASS if buttons else Control.MOUSE_FILTER_IGNORE
	for c in _build_bar.get_children() + _place_bar.get_children():
		(c as Control).visible = buttons
	var line_bottom := (bar_y if _build_bar.get_child_count() > 0 or _place_bar.visible else bottom - 10.0) - 6.0
	_hint.position = Vector2(0, line_bottom - 30.0)
	_hint.size = Vector2(size.x, 30)
	var tip_bottom := (line_bottom - 32.0) if _hint.modulate.a > 0.01 else line_bottom
	_tip.size = Vector2(size.x - 60, 0)
	var th := _tip.get_combined_minimum_size().y
	_tip.position = Vector2(30, tip_bottom - th)
	_tip.size = Vector2(size.x - 60, th)
	# the tip and the hint never land mid-screen. While fishing, its words ("Tap!") take the hint's line.
	var low := _tip.position.y > size.y * 0.66
	_tip.visible = low
	_hint.visible = _hint.position.y > size.y * 0.66 and not (main.fishing != null and main.fishing.busy())


## How wide a one-line label's text is.
func _text_w(l: Label) -> float:
	var f := l.get_theme_font("font")
	return f.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x + 4.0


## The y of the line just above the bottom buttons (fishing's "Tap!" and the like).
func line_y() -> float:
	return _hint.position.y + 26.0


## The bottom of the clear part of the screen (above the phone's gesture bar): a dialog takes no room there.
func _card_top() -> float:
	var size := get_viewport().get_visible_rect().size
	return size.y - _safe.y


func refresh() -> void:
	var below: bool = main.get("area") != null
	_timber_box.visible = (Save.timber > 0 or Save.camp_level > 1 or Save.claimed.size() > 0) and not below
	_timber_l.text = str(Save.timber)
	_shard_box.visible = (Save.shards > 0 or Data.raids_open() or _shown_shards > 0) and not below
	var chip: String = main.cooking.chip_text() if main.cooking else ""
	_meal_l.text = chip
	_meal_l.visible = chip != ""
	refresh_hp()
	var f = main.fight
	var shown: bool = below or f.active or (main.raids != null and main.raids.meter_shown())
	_stage_l.visible = shown
	_gate_bar.visible = shown
	if below:
		_stage_l.text = main.area.status_text()
	elif f.active:
		_stage_l.text = f.status_text()
	elif shown:
		_stage_l.text = main.raids.hud_text()
	_refresh_satchel(below)
	_bar_key = ""
	_gate_bar.queue_redraw()


## Below ground: the materials in the satchel (icons and counts, only those above 0), in the top bar after the leaves.
func _refresh_satchel(below: bool) -> void:
	for c in _satchel_box.get_children():
		c.queue_free()
	_satchel_box.visible = below
	if not below:
		return
	var sat: Dictionary = main.area.satchel()
	for k in Data.MATS:
		var n := int(sat.get(k, 0))
		if n <= 0:
			continue
		var ic := _btn_icon(icon(k))
		ic.custom_minimum_size = Vector2(28, 28)
		_satchel_box.add_child(ic)
		_satchel_box.add_child(_label(str(n), 24))


## The bars over the cat follow its health by themselves (lifebar.gd); kept for the callers.
func refresh_hp() -> void:
	if _lifebar:
		_lifebar.queue_redraw()


func _on_save_changed() -> void:
	refresh()
	if main.mount != null and main.mount.resting > 0.0 and main.can_feed() != _feed_ok:
		refresh_build()                              # the Feed button lights up (or greys out) with the pantry
	if _card != null and _card_ring != null:
		_fill_card(_spec(_card_ring))              # through _spec: a card stays blank while a wave is on


func _process(delta: float) -> void:
	# count leaves up, so a pickup feels like something
	if _shown_leaves != Save.leaves:
		var diff := Save.leaves - _shown_leaves
		_shown_leaves += signi(diff) * maxi(1, absi(diff) / 6)
		_leaves_l.text = str(_shown_leaves)
	else:
		_leaves_l.text = str(Save.leaves)
	# shards count up as the shower lands (shards_held are banked but still on their way)
	if shards_held > 0:
		_held_t += delta
		if _held_t > 3.0:
			shards_held = 0
	var want := Save.shards - shards_held
	if _shown_shards != want:
		var sd := want - _shown_shards
		_shown_shards += signi(sd) * maxi(1, absi(sd) / 6)
		_shard_l.text = str(_shown_shards)
		_shard_box.visible = main.get("area") == null
	elif _shard_l.text != str(want):
		_shard_l.text = str(want)
	_gate_flash = maxf(0.0, _gate_flash - delta)
	_point_t = maxf(0.0, _point_t - delta)
	var rd = main.raids
	var meter_on: bool = rd != null and rd.meter_shown()
	if main.get("area") != null:
		_stage_l.visible = true
		_gate_bar.visible = true
		_stage_l.text = main.area.status_text()
		meter_on = false
	elif main.fight.active:
		_stage_l.text = main.fight.status_text()
	elif meter_on:
		_stage_l.visible = true
		_gate_bar.visible = true
		_stage_l.text = rd.hud_text()
		_stage_l.modulate.a = 0.6 if rd.hud_state() == "idle" else 1.0
	elif _stage_l.visible:
		_stage_l.visible = false
		_gate_bar.visible = false
	if main.fight.active or not meter_on:
		_stage_l.modulate.a = 1.0
	if status != "":
		_hide_l.text = status
		_hide_l.add_theme_color_override("font_color", Color(1.0, 0.8, 0.5))
		_hide_l.visible = true
	elif main.hidden:
		_hide_l.text = "Hidden  ·  Ambush ready!" if main.ambush_ready else "Hidden in the grass"
		_hide_l.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4) if main.ambush_ready else Color(0.75, 1.0, 0.65))
		_hide_l.visible = true
	else:
		_hide_l.visible = false
	if _gate_bar.visible:
		if main.get("area") != null:
			_gate_bar.queue_redraw()
		elif main.fight.active and not (main.fight.mode == "raid" and main.fight.warning):
			_gate_bar.queue_redraw()
		else:
			# the raid bar: only when what it shows changes (half a meter point, a second), or every frame while it pulses
			var key: String = rd.bar_key() if rd != null else ""
			if key != _bar_key or key.begins_with("pulse"):
				_bar_key = key
				_gate_bar.queue_redraw()
	_boss_bar.visible = boss != null and is_instance_valid(boss) and not boss.dead
	if _boss_bar.visible:
		_boss_bar.queue_redraw()
	if _tip_time > 0.0:
		_tip_time -= delta
		if _tip_time <= 0.0 or (_tip_ring != null and _tip_ring == _card_ring and _card != null):
			_tip_time = 0.0
			_tip_ring = null
			create_tween().tween_property(_tip, "modulate:a", 0.0, 0.4)
	elif not _tip_queue.is_empty():
		var nxt: Array = _tip_queue.pop_front()
		tip(String(nxt[0]), nxt[1] if nxt[1] != null and is_instance_valid(nxt[1]) else null)
	_place_all()
	if _card != null:
		_place_card()
	_overlay.queue_redraw()


func hide_hint() -> void:
	if _hint.modulate.a > 0.0:
		create_tween().tween_property(_hint, "modulate:a", 0.0, 0.6)


# ---------------------------------------------------------------- messages
## A banner: a compact strip just under the top bar for about two seconds. `big` (a mission or a raid won or lost) is
## a little larger and stays a little longer, still at the top.
func banner(title: String, color := Color(1, 1, 1), sub := "", big := false) -> void:
	_banner_t.text = title
	_banner_t.add_theme_color_override("font_color", color)
	_banner_t.add_theme_font_size_override("font_size", 40 if big else 30)
	_banner_s.text = sub
	_banner_s.visible = sub != ""
	_banner_s.add_theme_font_size_override("font_size", 22 if big else 19)
	if _banner_tw != null and _banner_tw.is_valid():
		_banner_tw.kill()
	_banner.pivot_offset = Vector2(_banner.size.x * 0.5, 0)
	_banner.scale = Vector2(0.92, 0.92)
	var tw := create_tween()
	_banner_tw = tw
	tw.set_parallel()
	tw.tween_property(_banner, "modulate:a", 1.0, 0.15)
	tw.tween_property(_banner, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval((3.0 if big else 1.6) + (0.5 if sub.length() > 40 else 0.0))
	tw.chain().tween_property(_banner, "modulate:a", 0.0, 0.35)


## Fades the whole screen to `alpha` over `secs` (Phase E: into and out of the Burrows). While it covers
## the screen, touches are for nothing (the joystick ignores them). Await it.
func fade(alpha: float, secs: float) -> void:
	_fade.visible = true
	if not _fade.is_in_group("ui_block"):
		_fade.add_to_group("ui_block")
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := _fade.create_tween()
	tw.tween_property(_fade, "color:a", alpha, maxf(secs, 0.01))
	await tw.finished
	if alpha <= 0.01:
		_fade.visible = false
		_fade.remove_from_group("ui_block")
		_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE


## True while a banner is on screen (the Old Hollow's reveal waits for it).
func banner_busy() -> bool:
	return _banner.modulate.a > 0.02


## The same banner a moment later (a gift after the "mission won" banner, so both can be read).
func banner_later(delay: float, title: String, color := Color(1, 1, 1), sub := "", big := false) -> void:
	get_tree().create_timer(delay).timeout.connect(banner.bind(title, color, sub, big))


## A short message under the top bar (under the banner when one shows).
func toast(text: String) -> void:
	_toast.text = text
	if _toast_tw != null and _toast_tw.is_valid():
		_toast_tw.kill()
	var tw := create_tween()
	_toast_tw = tw
	tw.tween_property(_toast, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.7)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.35)


## A tip that waits for the one on screen to go first (gifts, which come with the "mission won" tips).
var _tip_queue: Array = []


## tip_after, a few seconds from now (after a banner).
func tip_after_delay(delay: float, text: String, ring) -> void:
	get_tree().create_timer(delay).timeout.connect(func():
		tip_after(text, ring if ring != null and is_instance_valid(ring) else null))


func tip_after(text: String, ring) -> void:
	if _tip_time <= 0.0:
		tip(text, ring)
	else:
		_tip_queue.append([text, ring])


## A tip: a small line just above the buttons at the bottom, with an arrow to the marker it is about (it goes when
## that marker's card opens).
func tip(text: String, ring) -> void:
	_tip.text = text
	_tip_ring = ring
	_tip_time = 14.0
	create_tween().tween_property(_tip, "modulate:a", 1.0, 0.3)


func gate_hit() -> void:
	_gate_flash = 0.25


## Points the tip arrow at a spot in the world (a raid's trail) for `secs`: bobbing over it when it is on screen, at the
## screen's edge when it is not.
func point_at(world_pos: Vector3, secs: float) -> void:
	_point_pos = world_pos
	_point_t = secs


func _draw_gate() -> void:
	var f = main.fight
	if main.get("area") != null:
		_draw_pips()
		return
	if not f.active or (f.mode == "raid" and f.warning):
		_draw_raid_bar()
		return
	var w := _gate_bar.size.x
	var frac := clampf(f.gate_hp / maxf(f.gate_max, 1.0), 0.0, 1.0)
	_gate_bar.draw_rect(Rect2(0, 0, w, 30), Color(0, 0, 0, 0.45))
	var c := Color(0.95, 0.75, 0.3).lerp(Color(1, 0.3, 0.25), 1.0 - frac)
	if _gate_flash > 0.0:
		c = Color(1, 1, 1)
	_gate_bar.draw_rect(Rect2(3, 3, (w - 6) * frac, 24), c)
	if f.last_stand:
		var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.008)
		_gate_bar.draw_rect(Rect2(3, 3, w - 6, 24), Color(0.55, 0.1, 0.1, pulse))
		_gate_bar.draw_string(ThemeDB.fallback_font, Vector2(8, 24), "LAST STAND", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 0.92, 0.85))
		_gate_bar.queue_redraw()
		return
	_gate_bar.draw_string(ThemeDB.fallback_font, Vector2(8, 24), "Campfire %d" % int(ceil(f.gate_hp)), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.15, 0.08, 0.05))


## In a Burrow: one circle per fight on the way, and one for the end (filled = won, a ring = on now, hollow = ahead,
## a crown on the boss).
func _draw_pips() -> void:
	var pips: Array = main.area.fight_pips()
	var w := _gate_bar.size.x
	var gap := 12.0
	var r := 11.0
	var need := pips.size() * 2.0 * r + (pips.size() - 1) * gap
	if need > w - 8.0:
		var k := (w - 8.0) / need
		r *= k
		gap *= k
	var x := w - r - 4.0 - (pips.size() - 1) * (2.0 * r + gap)
	for p in pips:
		var c := Vector2(x, 15)
		var col := Color(1.0, 0.86, 0.45)
		_gate_bar.draw_circle(c, r + 2.5, Color(0.1, 0.07, 0.04, 0.55))
		match int(p[0]):
			2: _gate_bar.draw_circle(c, r, col)
			1:
				_gate_bar.draw_arc(c, r - 1.5, 0, TAU, 24, col, 3.5, true)
				_gate_bar.draw_circle(c, 4.0, col)
			_: _gate_bar.draw_arc(c, r - 1.5, 0, TAU, 24, Color(1, 1, 1, 0.55), 2.0, true)
		if bool(p[1]):
			var t := c + Vector2(0, -r - 4)
			_gate_bar.draw_colored_polygon(PackedVector2Array([t + Vector2(-8, 0), t + Vector2(-8, -7), t + Vector2(-4, -3), t + Vector2(0, -9),
				t + Vector2(4, -3), t + Vector2(8, -7), t + Vector2(8, 0)]), Color(1.0, 0.5, 0.45))
		x += 2.0 * r + gap


## The Gloom meter (violet, "Raid at 100%"), or a raid's warning counting down (gold to red, "0:38").
func _draw_raid_bar() -> void:
	var rd = main.raids
	if rd == null:
		return
	var w := _gate_bar.size.x
	var st: String = rd.hud_state()
	var frac: float = rd.hud_frac()
	_gate_bar.draw_rect(Rect2(0, 0, w, 30), Color(0.08, 0.05, 0.14, 0.6))
	if st == "warning":
		var c := Color(0.95, 0.75, 0.3).lerp(Color(1, 0.3, 0.25), 1.0 - frac)
		_gate_bar.draw_rect(Rect2(3, 3, (w - 6) * frac, 24), c)
		var txt: String = "waiting for you" if rd.holding() else main.fight.mmss(main.fight.breather_left())
		_gate_bar.draw_string(ThemeDB.fallback_font, Vector2(8, 24), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.15, 0.08, 0.05))
		return
	var col := Color(0.62, 0.4, 0.95)
	if st == "idle":
		col.a = 0.6
	_gate_bar.draw_rect(Rect2(3, 3, (w - 6) * frac, 24), col)
	var label := "Raid at 100%"
	if st == "blocked":
		var pulse := 0.35 + 0.35 * sin(Time.get_ticks_msec() * 0.008)
		_gate_bar.draw_rect(Rect2(3, 3, w - 6, 24), Color(0.95, 0.8, 1.0, pulse))
		label = "Raid waiting"
	_gate_bar.draw_string(ThemeDB.fallback_font, Vector2(8, 24), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 0.95, 1.0, 0.95 if st != "idle" else 0.6))


func _draw_boss() -> void:
	if boss == null or not is_instance_valid(boss):
		return
	var w := _boss_bar.size.x
	var frac := clampf(boss.hp / maxf(boss.max_hp, 1.0), 0.0, 1.0)
	_boss_bar.draw_rect(Rect2(0, 0, w, 30), Color(0, 0, 0, 0.5))
	_boss_bar.draw_rect(Rect2(3, 3, (w - 6) * frac, 24), Color(0.7, 0.35, 0.95))
	var bt := String(boss.get("title")) if boss.get("title") != null and String(boss.get("title")) != "" else String(boss.info["name"])
	_boss_bar.draw_string(ThemeDB.fallback_font, Vector2(10, 22), bt, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(1, 1, 1))


func _draw_overlay() -> void:
	if main.cam == null:
		return
	var world_p: Vector3
	if _tip_ring != null and _tip_time > 0.0 and is_instance_valid(_tip_ring):
		world_p = _tip_ring.tip_point()
	elif _point_t > 0.0:
		world_p = _point_pos + Vector3(0, 0.3, 0)
	else:
		return
	var size := _overlay.size
	var behind: bool = main.cam.is_position_behind(world_p)
	var sp: Vector2 = main.cam.unproject_position(world_p)
	var t := Time.get_ticks_msec() * 0.001
	var gold := Color(1.0, 0.85, 0.3)
	var clear_top: float = _safe.x + _top_h + 40.0
	if not behind and Rect2(Vector2(30, clear_top), Vector2(size.x - 60, _card_top() - clear_top - 30.0)).has_point(sp):
		var bob := sin(t * 6.0) * 10.0
		var tip_p := sp + Vector2(0, -50 + bob)
		_overlay.draw_colored_polygon(PackedVector2Array([tip_p, tip_p + Vector2(-26, -34), tip_p + Vector2(26, -34)]), gold)
		_overlay.draw_polyline(PackedVector2Array([tip_p, tip_p + Vector2(-26, -34), tip_p + Vector2(26, -34), tip_p]), Color(0.3, 0.18, 0.05), 3.0)
	else:
		var c := size * 0.5
		var dir := (sp - c).normalized() if not behind else (c - sp).normalized()
		var edge := c + dir * minf(size.x, size.y) * 0.42
		var a := dir.angle()
		var pts := PackedVector2Array([edge + Vector2(34, 0).rotated(a), edge + Vector2(-16, -22).rotated(a), edge + Vector2(-16, 22).rotated(a)])
		_overlay.draw_colored_polygon(pts, gold)


# ---------------------------------------------------------------- building
func refresh_build() -> void:
	for c in _build_bar.get_children():
		c.queue_free()
	for c in _place_bar.get_children():
		c.queue_free()
	var d = main.defences
	if d == null:
		return
	if d.placing != "":
		_place_bar.add_child(_big_button("Place", Color(0.36, 0.66, 0.24), d.place_here))
		_place_bar.add_child(_big_button("Done", Color(0.55, 0.5, 0.45), d.stop_placing))
		_place_bar.visible = true
		_build_bar.visible = false
		return
	_place_bar.visible = false
	_build_bar.visible = true
	_feed_ok = main.can_feed()
	if main.get("area") != null:
		_area_buttons()                              # below ground: the mount's Ride / Feed, and a snack; no building
		return
	if main.mount != null and main.mount.resting > 0.0:
		# knocked out: the Ride button becomes Feed (food from the pantry brings it back), greyed when there is none
		var ok: bool = _feed_ok
		var txt := ("Feed %s\n%s" % [Data.mount_name(), main.feed_text()]) if ok else ("No food\n%s" % main.feed_text())
		_build_bar.add_child(_big_button(txt, Color(0.9, 0.5, 0.55) if ok else Color(0.62, 0.6, 0.55), main.feed_mount, ok))
	elif main.mount != null and not Save.ruined.has("stall"):
		var on: bool = main.player.riding
		_build_bar.add_child(_big_button("Walk" if on else "Ride", Color(0.42, 0.6, 0.86) if not on else Color(0.55, 0.5, 0.45), main.toggle_ride))
	for type in ["barricade", "tower", "spikes"]:
		var n := int(Save.items.get(type, 0))
		if n <= 0:
			continue
		var names := {"barricade": "Barricade", "tower": "Tower", "spikes": "Spikes"}
		_build_bar.add_child(_big_button("%s ×%d" % [names[type], n], Color(0.85, 0.62, 0.22), d.start_placing.bind(type)))


## The buttons below ground: Ride / Walk or Feed the mount (as in missions), and a snack from the pantry that heals.
func _area_buttons() -> void:
	if main.mount != null and main.mount.resting > 0.0:
		var ok: bool = _feed_ok
		var txt := ("Feed %s
%s" % [Data.mount_name(), main.feed_text()]) if ok else ("No food
%s" % main.feed_text())
		_build_bar.add_child(_big_button(txt, Color(0.9, 0.5, 0.55) if ok else Color(0.62, 0.6, 0.55), main.feed_mount, ok))
	elif main.mount != null and not Save.ruined.has("stall"):
		var on: bool = main.player.riding
		_build_bar.add_child(_big_button("Walk" if on else "Ride", Color(0.42, 0.6, 0.86) if not on else Color(0.55, 0.5, 0.45), main.toggle_ride))
	var sn: Dictionary = main.snack_pick() if main.has_method("snack_pick") else {}
	if not sn.is_empty():
		var hurt: bool = main.player.hp < Data.cat_max_hp()
		_build_bar.add_child(_big_button("Snack
%s +%d" % [Data.item_name(String(sn["item"]), 1), int(sn["heal"])],
			Color(0.55, 0.75, 0.35) if hurt else Color(0.62, 0.6, 0.55), main.eat_snack))


func _big_button(text: String, col: Color, action: Callable, enabled := true) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.custom_minimum_size = Vector2(170, 84)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 30)
	b.add_theme_color_override("font_color", Color(1, 1, 1))
	b.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.05, 0.8))
	b.add_theme_constant_override("outline_size", 6)
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(22)
	sb.border_color = col.darkened(0.35)
	sb.border_width_bottom = 6
	for st in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	var pr := sb.duplicate() as StyleBoxFlat
	pr.bg_color = col.darkened(0.15)
	pr.border_width_bottom = 2
	b.add_theme_stylebox_override("pressed", pr)
	b.add_theme_stylebox_override("disabled", sb)
	b.add_theme_color_override("font_disabled_color", Color(0.95, 0.93, 0.9))
	b.add_to_group("ui_block")
	b.set_meta("label", text)
	b.pressed.connect(func(): action.call())
	return b


func build_buttons() -> Array:
	# for the automated test
	var out: Array = []
	_collect_buttons(_build_bar, out)
	_collect_buttons(_place_bar, out)
	return out


# ---------------------------------------------------------------- the card: a dialog
## A card opens as a dialog (19 Nov 2026, the user: "it should open like a whole UI, but not full screen. It should
## have a close button... you can still see the background of the game. You can click the close button or click away
## to close it"): DIALOG_W of the screen's width, at most DIALOG_H of the height between the phone's bars, in the
## middle, over a soft see-through dim of the game. The game runs on underneath; the dim takes every touch, so a drag
## there never moves the cat. The banner and the toast stay on top (what a button did shows there).
const DIALOG_W := 0.9
const DIALOG_H := 0.8
const DIM_A := 0.42
const CLOSE := 68.0                     # the round X, HUD pixels (about 7 mm on the phone)
const PARCHMENT := Color(0.99, 0.95, 0.84)
const WOOD := Color(0.56, 0.35, 0.17)


func show_card(ring) -> void:
	if _card != null and _card_ring == ring:
		return
	var was_open := _card != null
	hide_card()
	_card_ring = ring
	_dim = ColorRect.new()
	_dim.color = Color(0.03, 0.025, 0.02, DIM_A if was_open else 0.0)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.add_to_group("ui_block")
	_dim.gui_input.connect(_on_dim_input)
	_dim_down = false
	add_child(_dim)
	_card = PanelContainer.new()
	_card.add_to_group("ui_block")
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = PARCHMENT
	sb.border_color = WOOD
	sb.set_border_width_all(6)
	sb.set_corner_radius_all(26)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 18
	sb.shadow_offset = Vector2(0, 6)
	sb.set_content_margin_all(6)
	_card.add_theme_stylebox_override("panel", sb)
	add_child(_card)
	move_child(_banner, -1)                          # what a button did shows over the dialog
	move_child(_toast, -1)
	_fill_card(_spec(ring))
	_card_in = 0.0
	_card.modulate.a = 0.0
	var tw := _card.create_tween().set_parallel()
	tw.tween_property(self, "_card_in", 1.0, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_card, "modulate:a", 1.0, 0.12)
	tw.tween_property(_dim, "color:a", DIM_A, 0.15)
	_quit_back = get_tree().quit_on_go_back           # Android's back button closes the dialog, not the game
	get_tree().quit_on_go_back = false
	_place_card()


func hide_card() -> void:
	if _card != null:
		var c := _card
		_card = null
		c.remove_from_group("ui_block")
		for b in c.find_children("*", "BaseButton", true, false):
			(b as BaseButton).disabled = true          # nothing on a closing dialog takes a tap
		var tw := c.create_tween().set_parallel()
		tw.tween_property(c, "modulate:a", 0.0, 0.12)
		tw.tween_property(c, "scale", Vector2.ONE * 0.95, 0.12)
		tw.chain().tween_callback(c.queue_free)
		get_tree().quit_on_go_back = _quit_back
	if _dim != null:
		var dm := _dim
		_dim = null
		dm.remove_from_group("ui_block")
		dm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tw2 := dm.create_tween()
		tw2.tween_property(dm, "color:a", 0.0, 0.12)
		tw2.tween_callback(dm.queue_free)
	_card_ring = null
	_close_btn = null
	_card_head = null
	_card_scroll = null
	_card_list = null
	_card_title = null
	_card_sub = null
	_card_body = null


## A tap on the dim (outside the dialog) closes it; a drag there does nothing.
func _on_dim_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or (event as InputEventMouseButton).button_index != MOUSE_BUTTON_LEFT:
		return
	var mb := event as InputEventMouseButton
	if mb.pressed:
		_dim_down = true
		_dim_from = mb.position
	elif _dim_down:
		_dim_down = false
		if mb.position.distance_to(_dim_from) < 40.0:
			hide_card()
	get_viewport().set_input_as_handled()


## Android's back button closes an open dialog (quit_on_go_back is off while one is open).
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and _card != null:
		hide_card()


## Escape (on a PC; or a back key sent as a key) closes an open dialog.
func _unhandled_key_input(event: InputEvent) -> void:
	if _card != null and event is InputEventKey and event.pressed and not event.echo \
			and ((event as InputEventKey).keycode == KEY_ESCAPE or (event as InputEventKey).keycode == KEY_BACK):
		hide_card()
		get_viewport().set_input_as_handled()


## The tip's arrow lets go of its marker (the cat went into a Burrow: a marker in the camp is 400 m away). The words stay.
func drop_tip_ring() -> void:
	_tip_ring = null


## A dialog is open (the Burrows' camera then keeps the camp's focus).
func card_open() -> bool:
	return _card != null


## The marker whose dialog is open (null when none).
func card_ring():
	return _card_ring if _card != null else null


## The marker a tip points at, while the tip shows (it shows full size; main.gd).
func tip_ring():
	return _tip_ring if _tip_time > 0.0 and _tip_ring != null and is_instance_valid(_tip_ring) else null


func refresh_card() -> void:
	if _card != null and _card_ring != null:
		_fill_card(_spec(_card_ring))


## The open dialog's name ("" when none is open; the tests read it).
func card_title() -> String:
	return _card_title.text if _card != null and _card_title != null else ""


## Phase F: scrolls the open dialog to the first row or shop tile (not a goal line) whose words hold `needle`, and
## makes it glow a moment: a goal on the home's card that is sold further down the same card. Waits for the rows to be
## laid out.
func scroll_card_to(needle: String) -> void:
	if needle == "":
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if _card == null or _card_list == null or not is_instance_valid(_card_list) or _card_scroll == null:
		return
	for h in _card_list.get_children():
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
	_card_scroll.scroll_vertical = int(y)
	row.modulate = Color(1.35, 1.25, 0.85)
	row.create_tween().tween_property(row, "modulate", Color(1, 1, 1), 0.9)


## A marker's card. While a wave is on only the signpost and the barricade rows' markers (repair) work: the shops and stations open between waves.
func _spec(ring) -> Dictionary:
	var spec: Dictionary = ring.builder.call()
	var f = main.fight
	if f.active and f.in_wave and ring != main.stations.rings.get("sign") and not String(ring.key).begins_with("road_"):
		return {"title": spec.get("title", ""), "sub": "A wave is on! This opens again between waves.", "rows": [],
			"anchor": spec.get("anchor", Vector3.ZERO)}
	return spec


func card_buttons() -> Array:
	# for the automated test: the rows' buttons (not the X)
	var out: Array = []
	if _card == null:
		return out
	_collect_buttons(_card, out)
	out.erase(_close_btn)
	return out


## The dialog's X (the tests tap it).
func close_button() -> Button:
	return _close_btn


func _collect_buttons(n: Node, out: Array) -> void:
	if n is Button:
		out.append(n)
	for c in n.get_children():
		_collect_buttons(c, out)


## The dialog's frame, made once when it opens: the header strip (the name, its line, the X) and the body that scrolls.
func _card_frame() -> void:
	for c in _card.get_children():
		c.queue_free()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	_card.add_child(v)
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
	_card_head = head
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
	var title := _label("", 36)
	title.add_theme_color_override("font_color", Color(1.0, 0.95, 0.82))
	title.add_theme_color_override("font_outline_color", Color(0.25, 0.13, 0.05, 0.9))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tv.add_child(title)
	_card_title = title
	var sub := _label("", 20)
	sub.add_theme_color_override("font_color", Color(1.0, 0.86, 0.62))
	sub.add_theme_color_override("font_outline_color", Color(0.25, 0.13, 0.05, 0.8))
	sub.add_theme_constant_override("outline_size", 5)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tv.add_child(sub)
	_card_sub = sub
	_close_btn = _make_close()
	hb.add_child(_close_btn)
	var body := MarginContainer.new()
	body.add_theme_constant_override("margin_left", 16)
	body.add_theme_constant_override("margin_right", 16)
	body.add_theme_constant_override("margin_top", 4)
	body.add_theme_constant_override("margin_bottom", 12)
	v.add_child(body)
	_card_body = body
	_card_scroll = ScrollContainer.new()
	_card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(_card_scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_scroll.add_child(list)
	_card_list = list


## The dialog's contents: its name and line in the header, then the rows, in the body that scrolls inside the dialog
## when they are taller than it may be. Phase G2: a row {"kind": "section"} is a shelf heading; a run of rows
## {"kind": "item"} is one grid of shop tiles (_item_grid); any other row is a plain row, drawn as before (_plain_row).
func _fill_card(spec: Dictionary) -> void:
	_card_anchor = spec.get("anchor", Vector3.ZERO)
	var rows: Array = spec.get("rows", [])
	if _card_list == null or not is_instance_valid(_card_list):
		_card_frame()
	# a refresh (leaves spent, a wave starting) keeps the frame, the X and the scroll; only the words and rows change
	_card_title.text = String(spec.get("title", ""))
	_card_sub.text = String(spec.get("sub", ""))
	_card_sub.visible = _card_sub.text != ""
	_card_body.visible = not rows.is_empty()
	for c in _card_list.get_children():
		(c as Control).visible = false              # gone from the layout now (a pressed button finishes its press first)
		c.queue_free()
	var list := _card_list
	var prev := ""                                  # what came last: "" (nothing yet), "row", "small", "section", "grid"
	var i := 0
	while i < rows.size():
		var row: Dictionary = rows[i]
		var kind := String(row.get("kind", ""))
		if kind == "item":
			var items: Array = []                       # consecutive tiles make one grid
			while i < rows.size() and String((rows[i] as Dictionary).get("kind", "")) == "item":
				items.append(rows[i])
				i += 1
			list.add_child(_item_grid(items))
			prev = "grid"
			continue
		i += 1
		if kind == "section":
			list.add_child(_section_row(String(row.get("text", "")), prev != ""))
			prev = "section"
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


## A plain row (the card rows from before Phase G2): its words and note, and a button with its price. "done" (with
## "small") puts a tick (true) or an open ring (false) before its words.
func _plain_row(list: VBoxContainer, row: Dictionary, small: bool) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10 if small else 12)
	if small:
		h.set_meta("goal", true)
	list.add_child(h)
	if small and row.has("done"):
		var mark := _btn_icon(icon("tick" if bool(row["done"]) else "todo"))
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
				h.add_child(_btn_icon(icon(k)))
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
	var size := get_viewport().get_visible_rect().size
	var w := size.x * DIALOG_W
	_card.custom_minimum_size.x = w
	var top := _safe.x + 8.0
	var bottom := size.y - _safe.y - 8.0
	var max_h := (bottom - top) * DIALOG_H
	if _card_scroll != null and _card_list != null and _card_head != null:
		var room := max_h - _card_head.get_combined_minimum_size().y - 12.0 - 16.0
		_card_scroll.custom_minimum_size.y = clampf(_card_list.get_combined_minimum_size().y, 0.0, maxf(room, 120.0))
	var cs := _card.get_combined_minimum_size()
	cs.x = w
	_card.size = cs
	_card.position = Vector2((size.x - cs.x) * 0.5, top + (bottom - top - cs.y) * 0.5)
	_card.pivot_offset = cs * 0.5
	_card.scale = Vector2.ONE * lerpf(0.88, 1.0, _card_in)


# ---------------------------------------------------------------- Phase G2: the shop tiles (20 Nov 2026)
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
const TILE_INK := Color(0.25, 0.16, 0.08)
const PILL := {"wood": Color(0.56, 0.35, 0.17), "green": Color(0.33, 0.6, 0.2), "blue": Color(0.24, 0.5, 0.72),
	"orange": Color(0.92, 0.45, 0.2), "gold": Color(0.84, 0.6, 0.1), "red": Color(0.78, 0.22, 0.17)}
const BTN := {"green": Color(0.36, 0.66, 0.24), "blue": Color(0.31, 0.55, 0.83), "orange": Color(0.9, 0.55, 0.2),
	"off": Color(0.72, 0.69, 0.64)}

var _ui_styles := {}                    # the tiles' styles, made once and shared by every tile
var _bold_font: FontVariation
var _caps_font: FontVariation


## How wide the dialog's scrolling list is, in HUD pixels: the dialog less its frame and the body's margins, and room
## for a scroll bar.
func _list_w() -> float:
	return get_viewport().get_visible_rect().size.x * DIALOG_W - 12.0 - 32.0 - 14.0


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
	var own_pic := _picture(str(it.get("picture", "")))   # G3: a tile's own picture (a bow's), over its icon
	if own_pic != null:
		raw = own_pic
	var pic := TextureRect.new()
	pic.texture = icon(raw)
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
	if not _icon_known(raw):
		sq.add_child(_letter(title))                 # an unknown id: the plain disc with the name's first letter
	var badge := str(it.get("badge", ""))
	if badge != "":
		top.add_child(_pill(badge, inner_w))
	# the name, on one line
	var tl := Label.new()
	tl.text = title
	tl.add_theme_font_override("font", _bold())
	tl.add_theme_font_size_override("font_size", TITLE_FS)
	tl.add_theme_color_override("font_color", TILE_INK)
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
		vl.add_theme_color_override("font_color", TILE_INK)
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
		var ic := _btn_icon(icon(String(p[0])))
		ic.custom_minimum_size = Vector2(fs + 2, fs + 2)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if not ok:
			ic.modulate = Color(1, 1, 1, 0.55)
		box.add_child(ic)
		var l := Label.new()
		l.text = str(p[1])
		l.add_theme_font_override("font", _bold())
		l.add_theme_font_size_override("font_size", fs)
		l.add_theme_color_override("font_color", TILE_INK if ok else Color(0.8, 0.22, 0.16))
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
			refresh_card())
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


# ---------------------------------------------------------------- icons drawn in code
var _icons := {}


## The ids icon() draws here; every other id is a shop tile's picture from ui_icons.gd.
const OWN_ICONS := ["leaves", "timber", "shards", "shard", "keys", "amber", "glowstone", "heartwood", "tick", "todo"]


## An icon, made once in code and kept: a currency (leaves, timber, shards, keys, amber, glowstone, heartwood), a goal's
## mark ("tick", "todo"), or a shop tile's picture (Phase G2, ui_icons.gd: "bow", "target", "heart", "tower", ...).
## A Texture2D is used as it is (the bows' pictures, G3). An unknown id gives a plain round disc (a tile writes its
## title's first letter on it).
func icon(k) -> Texture2D:
	if k is Texture2D:
		return k
	var id := str(k)
	match id:
		"leaves": return _leaf_tex
		"timber": return _log_tex
		"shards", "shard": return _shard_tex
	if not _icons.has(id):
		match id:
			"tick": _icons[id] = _make_tick(true)       # a goal met (the home's card)
			"todo": _icons[id] = _make_tick(false)      # a goal still to meet
			"keys": _icons[id] = _make_key()
			"amber": _icons[id] = _make_gem(Color(1.0, 0.78, 0.36), Color(0.95, 0.55, 0.15), Color(0.6, 0.3, 0.08), false)
			"glowstone": _icons[id] = _make_gem(Color(0.75, 1.0, 0.94), Color(0.3, 0.82, 0.72), Color(0.1, 0.42, 0.38), true)
			"heartwood": _icons[id] = _make_heart()
			_: _icons[id] = UiIcons.texture(id)
	return _icons[id]


## icon(k) has a real picture for k (an unknown id gets the plain disc).
func _icon_known(k) -> bool:
	return k is Texture2D or OWN_ICONS.has(str(k)) or UiIcons.known(str(k))


var _pictures := {}                     # G3: res:// path -> its texture (null when the file is not there)


## G3: a shop tile's own picture, the row key "picture" (a res:// path, e.g. res://assets/ui/bows/bow_sunwood.png),
## loaded once and kept. null when the row has none or the file is not there: the tile then shows its "icon".
func _picture(path: String) -> Texture2D:
	if path == "":
		return null
	if not _pictures.has(path):
		_pictures[path] = (load(path) as Texture2D) if ResourceLoader.exists(path) else null
	return _pictures[path]


## A faceted gem: a diamond (amber) or a rounded pebble (glowstone), light left facet, dark outline (64 x 64).
func _make_gem(light: Color, mid: Color, dark: Color, round_: bool) -> ImageTexture:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := Vector2(32, 33)
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5) - c
			var d := p.length() / 26.0 if round_ else (absf(p.x) / 20.0 + absf(p.y) / 28.0)
			if d >= 1.0:
				continue
			var col := mid if p.x > 0.0 else light
			if d > 0.82:
				col = dark
			elif d < 0.35 and p.y < 0.0:
				col = light.lightened(0.3)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


## A goal's mark: a green disc with a white tick (met), or an open brown ring (not yet), 64 x 64.
func _make_tick(on: bool) -> ImageTexture:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := Vector2(32, 32)
	var a := Vector2(17, 33)
	var m := Vector2(28, 44)
	var e := Vector2(47, 22)
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5)
			var d := p.distance_to(c)
			var col := Color(0, 0, 0, 0)
			if on:
				if d < 29.0:
					col = Color(0.36, 0.66, 0.24) if d < 26.0 else Color(0.2, 0.42, 0.12)
					var t := minf(Geometry2D.get_closest_point_to_segment(p, a, m).distance_to(p), Geometry2D.get_closest_point_to_segment(p, m, e).distance_to(p))
					if t < 4.6:
						col = Color(1.0, 0.98, 0.9)
				col.a = clampf(29.0 - d, 0.0, 1.0) if d > 28.0 else col.a
			elif d < 25.0 and d > 19.0:
				col = Color(0.6, 0.45, 0.3, clampf(minf(25.0 - d, d - 19.0), 0.0, 1.0))
			if col.a > 0.0:
				img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


## Heartwood: a brown knot with an amber core.
func _make_heart() -> ImageTexture:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5) - Vector2(32, 32)
			var d := p.length() + 3.0 * sin(atan2(p.y, p.x) * 5.0)
			if d >= 27.0:
				continue
			var col := Color(0.58, 0.36, 0.18)
			if d > 23.0:
				col = Color(0.32, 0.18, 0.08)
			elif d < 11.0:
				col = Color(1.0, 0.72, 0.25) if d < 8.0 else Color(0.85, 0.5, 0.15)
			elif int(d) % 6 == 0:
				col = Color(0.45, 0.27, 0.13)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


## A Hollow key: a golden key with an acorn head.
func _make_key() -> ImageTexture:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var gold := Color(1.0, 0.82, 0.3)
	var dark := Color(0.55, 0.36, 0.08)
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5)
			var col := Color(0, 0, 0, 0)
			var head := p.distance_to(Vector2(20, 22))
			if head < 14.0:
				col = Color(0.62, 0.4, 0.18) if p.y < 16.0 else gold
				if head > 11.5:
					col = dark
				elif head < 4.5:
					col = Color(0, 0, 0, 0)
			elif p.x > 28 and p.x < 58 and absf(p.y - 22.0) < 4.0:
				col = gold if absf(p.y - 22.0) < 2.6 else dark
			elif (absf(p.x - 50.0) < 3.0 or absf(p.x - 42.0) < 3.0) and p.y > 22.0 and p.y < 34.0:
				col = gold if absf(p.x - 50.0) < 1.8 or absf(p.x - 42.0) < 1.8 else dark
			if col.a > 0.0:
				img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


func _make_leaf() -> ImageTexture:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var a := -0.7
	for y in n:
		for x in n:
			var p := (Vector2(x + 0.5, y + 0.5) / n) * 2.0 - Vector2.ONE
			var q := Vector2(p.x * cos(a) - p.y * sin(a), p.x * sin(a) + p.y * cos(a)) * 1.08
			var d1 := (q - Vector2(0.55, 0)).length()
			var d2 := (q + Vector2(0.55, 0)).length()
			var edge := maxf(d1, d2)
			if edge < 1.0:
				var c := Color(0.98, 0.78, 0.2)
				if edge > 0.86:
					c = Color(0.72, 0.45, 0.08)
				elif absf(q.x) < 0.045 or (absf(q.x) < 0.3 and absf(absf(q.x) * 1.4 - (q.y + 0.6) * 0.5 + 0.2) < 0.04):
					c = Color(1.0, 0.92, 0.55)
				c.a = clampf((1.0 - edge) * 30.0, 0.0, 1.0)
				img.set_pixel(x, y, c)
			elif absf(q.x) < 0.05 and q.y > 0.75 and q.y < 1.0:
				img.set_pixel(x, y, Color(0.72, 0.45, 0.08))
	return ImageTexture.create_from_image(img)


## A faceted violet Gloom shard: a tall crystal with a lighter left facet and a pale core (64 x 64).
func _make_shard() -> ImageTexture:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var top := Vector2(32, 4)
	var bottom := Vector2(32, 60)
	var left := Vector2(14, 26)
	var right := Vector2(50, 26)
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5)
			var inside := Geometry2D.is_point_in_polygon(p, PackedVector2Array([top, right, bottom, left]))
			if not inside:
				continue
			var c := Color(0.52, 0.3, 0.86)                         # the right facet
			if p.x < 32.0:
				c = Color(0.72, 0.52, 0.98)                         # the lighter left facet
			if p.y < 26.0 and Geometry2D.is_point_in_polygon(p, PackedVector2Array([top, Vector2(41, 26), Vector2(23, 26)])):
				c = c.lightened(0.15)
			if Geometry2D.is_point_in_polygon(p, PackedVector2Array([Vector2(32, 16), Vector2(39, 30), Vector2(32, 46), Vector2(25, 30)])):
				c = Color(0.93, 0.86, 1.0)                          # the pale core
			var edge := minf(minf(Geometry2D.get_closest_point_to_segment(p, top, right).distance_to(p),
				Geometry2D.get_closest_point_to_segment(p, right, bottom).distance_to(p)),
				minf(Geometry2D.get_closest_point_to_segment(p, bottom, left).distance_to(p),
				Geometry2D.get_closest_point_to_segment(p, left, top).distance_to(p)))
			if edge < 2.2:
				c = Color(0.3, 0.14, 0.52)                          # a dark outline
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


func _make_log() -> ImageTexture:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var centers := [Vector2(20, 42), Vector2(44, 42), Vector2(32, 21)]
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5)
			for c in centers:
				var d := p.distance_to(c)
				if d < 12.5:
					var col := Color(0.55, 0.33, 0.16)
					if d < 10.0:
						col = Color(0.88, 0.68, 0.42)
					if d < 6.5 and d > 4.5:
						col = Color(0.7, 0.5, 0.28)
					if d < 1.8:
						col = Color(0.6, 0.4, 0.2)
					img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)
