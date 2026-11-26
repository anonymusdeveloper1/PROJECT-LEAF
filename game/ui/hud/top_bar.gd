extends RefCounted
## The top bar: the leaves, timber and shards counters (counting up), the satchel below ground, and the second line (the endgame label, the dish). A part of the HUD (hud.gd).

const HudStyle := preload("res://ui/hud/hud_style.gd")
const STRIP := Color(0.06, 0.045, 0.03, 0.46)

var hud                                 # the HUD node (untyped on purpose: hud._stage_l and the rest are read at run time)


func _init(h) -> void:
	hud = h


func build() -> void:
	# the top bar's strip
	hud._top = Panel.new()
	hud._top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ts := StyleBoxFlat.new()
	ts.bg_color = STRIP
	ts.corner_radius_bottom_left = 18
	ts.corner_radius_bottom_right = 18
	hud._top.add_theme_stylebox_override("panel", ts)
	hud.add_child(hud._top)
	# leaves, timber, shards (and below ground the satchel)
	hud._res = HBoxContainer.new()
	hud._res.add_theme_constant_override("separation", 16)
	hud._res.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	hud._satchel_box.add_theme_constant_override("separation", 5)
	hud._satchel_box.visible = false
	hud._res.add_child(hud._satchel_box)
	hud._line2 = HBoxContainer.new()
	hud._line2.add_theme_constant_override("separation", 12)
	hud._line2.mouse_filter = Control.MOUSE_FILTER_IGNORE
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


func refresh(below: bool) -> void:
	hud._timber_box.visible = (Save.timber > 0 or Save.camp_level > 1 or Save.claimed.size() > 0) and not below
	hud._timber_l.text = str(Save.timber)
	hud._shard_box.visible = (Save.shards > 0 or Data.raids_open() or hud._shown_shards > 0) and not below
	var chip: String = hud.main.cooking.chip_text() if hud.main.cooking else ""
	hud._meal_l.text = chip
	hud._meal_l.visible = chip != ""


func tick(delta: float) -> void:
	# count leaves up, so a pickup feels like something
	if hud._shown_leaves != Save.leaves:
		var diff: int = Save.leaves - hud._shown_leaves
		hud._shown_leaves += signi(diff) * maxi(1, absi(diff) / 6)
		hud._leaves_l.text = str(hud._shown_leaves)
	else:
		hud._leaves_l.text = str(Save.leaves)
	# shards count up as the shower lands (shards_held are banked but still on their way)
	if hud.shards_held > 0:
		hud._held_t += delta
		if hud._held_t > 3.0:
			hud.shards_held = 0
	var want: int = Save.shards - hud.shards_held
	if hud._shown_shards != want:
		var sd: int = want - hud._shown_shards
		hud._shown_shards += signi(sd) * maxi(1, absi(sd) / 6)
		hud._shard_l.text = str(hud._shown_shards)
		hud._shard_box.visible = hud.main.get("area") == null
	elif hud._shard_l.text != str(want):
		hud._shard_l.text = str(want)


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
	var l: Label = HudStyle.label("0", 28)
	box.add_child(l)
	return [box, l]


## Below ground: the materials in the satchel (icons and counts, only those above 0), in the top bar after the leaves.
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
		ic.custom_minimum_size = Vector2(28, 28)
		hud._satchel_box.add_child(ic)
		hud._satchel_box.add_child(HudStyle.label(str(n), 24))
