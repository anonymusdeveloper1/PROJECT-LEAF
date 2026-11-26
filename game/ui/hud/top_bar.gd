extends RefCounted
## The top of the screen's sides (H2, the owner's sketch): top-left the three currencies, small and always all three
## (leaves, timber, shards, counting up; below ground the satchel after them) with no dark strip behind them, and under
## them one small line (the endgame label; the dish line, hidden since H3); top-right the Settings gear. A part of the
## HUD (hud.gd).

const HudStyle := preload("res://ui/hud/hud_style.gd")
const ICON := 28.0                      # the currencies' icons, HUD pixels
const FONT := 24                        # ... and their counts
const GEAR := 64.0                      # the round Settings gear

var hud                                 # the HUD node (untyped on purpose: hud._stage_l and the rest are read at run time)
var _leaves_target := 0
var _shards_target := 0


func _init(h) -> void:
	hud = h


func build() -> void:
	hud._top = null                                         # H2: no dark strip behind the top bar (the name stays declared)
	# leaves, timber, shards (and below ground the satchel)
	hud._res = HBoxContainer.new()
	hud._res.add_theme_constant_override("separation", 10)
	hud._res.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud._res.add_to_group("hud_edge")
	hud.add_child(hud._res)
	var lb: Array = _icon_row(hud._leaf_tex)
	hud._leaves_l = lb[1]
	hud._res.add_child(lb[0])
	var tb: Array = _icon_row(hud._log_tex)
	hud._timber_box = tb[0]
	hud._timber_l = tb[1]
	hud._res.add_child(hud._timber_box)
	var sb: Array = _icon_row(hud._shard_tex)
	hud._shard_box = sb[0]
	hud._shard_l = sb[1]
	hud._res.add_child(hud._shard_box)
	hud._satchel_box = HBoxContainer.new()
	hud._satchel_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud._satchel_box.add_theme_constant_override("separation", 4)
	hud._satchel_box.visible = false
	hud._res.add_child(hud._satchel_box)
	hud._line2 = HBoxContainer.new()
	hud._line2.add_theme_constant_override("separation", 12)
	hud._line2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud._line2.add_to_group("hud_edge")
	hud.add_child(hud._line2)
	hud._eg_l = HudStyle.label("Endgame test save", 16)
	hud._eg_l.add_theme_color_override("font_color", Color(1.0, 0.75, 0.5))
	hud._eg_l.visible = Save.endgame_slot                  # the debug endgame start: never mistaken for the real save
	hud._line2.add_child(hud._eg_l)
	hud._meal_l = HudStyle.label("", 17)
	hud._meal_l.visible = false
	hud._meal_l.add_theme_color_override("font_color", Color(1.0, 0.93, 0.75))
	hud._meal_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hud._line2.add_child(hud._meal_l)
	_build_gear()
	_leaves_target = Save.leaves
	_shards_target = Save.shards
	hud._shown_leaves = _leaves_target
	hud._shown_shards = _shards_target
	hud._leaves_l.text = str(_leaves_target)
	hud._shard_l.text = str(_shards_target)


## The Settings gear: a round button, always shown; a tap opens (or closes) the Settings window (hud.open_settings).
func _build_gear() -> void:
	var g := Button.new()
	g.custom_minimum_size = Vector2(GEAR, GEAR)
	g.focus_mode = Control.FOCUS_NONE
	g.set_meta("label", "Settings")
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.06, 0.045, 0.03, 0.55)
	st.set_corner_radius_all(int(GEAR * 0.5))
	st.border_color = Color(1.0, 0.93, 0.8, 0.85)
	st.set_border_width_all(3)
	for s in ["normal", "hover", "focus", "disabled"]:
		g.add_theme_stylebox_override(s, st)
	var pr := st.duplicate() as StyleBoxFlat
	pr.bg_color = Color(0.25, 0.16, 0.08, 0.75)
	g.add_theme_stylebox_override("pressed", pr)
	var pic := TextureRect.new()
	pic.texture = hud.p_icons._make_gear()
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.set_anchors_preset(Control.PRESET_FULL_RECT)
	pic.offset_left = 9
	pic.offset_top = 9
	pic.offset_right = -9
	pic.offset_bottom = -9
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.add_child(pic)
	g.add_to_group("ui_block")                             # the joystick leaves a touch on it alone
	g.add_to_group("hud_edge")
	g.pressed.connect(func(): hud.open_settings())
	hud._gear = g
	hud.add_child(g)


func refresh(_below: bool) -> void:
	_refresh_timber(Save.timber)
	hud._shard_box.visible = true                          # H2: all three always (also below ground)
	# H3: no dishes any more, so the dish line (hud._meal_l) stays hidden; it is kept for a later use (Q22)


func _on_currency_changed(id: String, total: int) -> void:
	match id:
		"leaves":
			_leaves_target = total
		"timber":
			_refresh_timber(total)
		"shards":
			_shards_target = total


func _refresh_timber(total: int) -> void:
	hud._timber_l.text = str(total)
	hud._timber_box.visible = true                         # H2: all three always


func tick(delta: float) -> void:
	# count leaves up, so a pickup feels like something
	if hud._shown_leaves != _leaves_target:
		var diff: int = _leaves_target - hud._shown_leaves
		hud._shown_leaves += signi(diff) * maxi(1, absi(diff) / 6)
		hud._leaves_l.text = str(hud._shown_leaves)
	# shards count up as the shower lands (shards_held are banked but still on their way)
	if hud.shards_held > 0:
		hud._held_t += delta
		if hud._held_t > 3.0:
			hud.shards_held = 0
	var want: int = _shards_target - hud.shards_held
	if hud._shown_shards != want:
		var sd: int = want - hud._shown_shards
		hud._shown_shards += signi(sd) * maxi(1, absi(sd) / 6)
		hud._shard_l.text = str(hud._shown_shards)


func _icon_row(tex: Texture2D) -> Array:
	var box := HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)
	var icon := TextureRect.new()
	icon.texture = tex
	icon.custom_minimum_size = Vector2(ICON, ICON)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)
	var l: Label = HudStyle.label("0", FONT)
	box.add_child(l)
	return [box, l]


## Below ground: the materials in the satchel (icons and counts, only those above 0), in the top bar after the shards.
func _refresh_satchel(below: bool) -> void:
	for c in hud._satchel_box.get_children():
		c.queue_free()
	hud._satchel_box.visible = below
	if not below:
		return
	var sat: Dictionary = hud.main.area.satchel()
	for k in Data.MATS:
		var n := int(sat.get(k, 0))
		if n <= 0:
			continue
		var ic: TextureRect = hud._btn_icon(hud.icon(k))
		ic.custom_minimum_size = Vector2(ICON - 2.0, ICON - 2.0)
		hud._satchel_box.add_child(ic)
		hud._satchel_box.add_child(HudStyle.label(str(n), FONT - 2))
