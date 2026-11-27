extends RefCounted
## H5 (Stage 2, 27 Nov 2026; the H5 map part 3.4, the owner's Q3): the Saddlery's Skills tab, inside the Saddlery's
## window (saddlery_window.gd draws the frame, the bottom tabs and the pinned Upgrade). Two views:
##   overview  the mount's three skill circles joined in a triangle (ui/kit/skill_triangle.gd), how to use them, then
##             the round icons of the four skills (SkillTriangle.skill_grid: at least three across), each with its name
##             and "Level 2/5" (or "New"). A learned skill is dragged into a circle to use it (a filled circle takes the
##             new one; a skill already in another circle moves); a tap on a filled circle empties it; a tap on an empty
##             one says how to fill it. Every mount shares the circles, and the mount fights only with the skills in
##             them (Data.active_skill_level): 0 to 3, never 4. A tap on a skill's icon opens its detail.
##   detail    a skill's picture, name, line, what it does at its level (stations._saddle_note), its level and the next
##             level's line, whether it is in a circle, its price, why it can't go further (red), then Back and its one
##             button: Learn (not learned yet), Upgrade (while the Saddlery's level and the Burrows allow), else a grey
##             Upgrade or Max level. A skill learned here goes into the grid, not a circle: the player drags it in.
## The circles' change runs scripts/companion_shop.gd assign_skill (it checks the Saddlery stands and no wave is on, and
## saves quietly), then the circles show it in place and the grid's green rims follow once the drop is over, so a drag
## is never cut short by a redraw. The triangle itself is kept across the card's rebuilds (moved into each new content).
## It is a window row of the card ({"kind": "window"}; card.gd): content() on every rebuild, tick(d) every frame,
## opened() and closed() once per visit of this row.
## Used by: ui/windows/saddlery_window.gd (its Skills tab's window row), the tests.
## Uses: the Saddlery's window (shown_id, part_of, entries, entry, state_line, inspect, act, back), ui/kit/skill_triangle.gd,
##       ui/kit/card_parts.gd (the buttons), scripts/companion_shop.gd (assign_skill), the HUD's tiles, icons and toast,
##       Data (skill_slots, saddle_info, saddlery_level, mount_name, word), Save, stations.gd (_saddle_note, _locked).

const SkillTriangle := preload("res://ui/kit/skill_triangle.gd")
const CardParts := preload("res://ui/kit/card_parts.gd")
const CompanionShop := preload("res://scripts/companion_shop.gd")
const ShopTiles := preload("res://ui/hud/shop_tiles.gd")   # the type of the HUD's tiles (hud.p_tiles)
const DETAIL_PIC := 200.0               # the detail's picture (as the build menu's detail)
const DETAIL_PAD := 8.0
const BTN := Vector2(220, 64)           # Back and the action
const MUTED := Color(0.45, 0.36, 0.26)
const WARN := Color(0.7, 0.28, 0.2)
const IN_USE := Color(0.3, 0.45, 0.16)
## H5 words: not in balance.json "windows" yet. Data.word(key) is used when it has the key; this is only the fallback.
const H5_WORDS := {
	"skill_in_use": "In a circle: %s uses it in fights",
}

var hud                                 # the HUD node (untyped on purpose, as in the HUD's parts)
var main
var _win: WeakRef                       # the Saddlery's window (weak: it holds this tab)
var _tri: SkillTriangle                 # the circles, kept across the card's rebuilds; null when none
var _grid: Control                      # the skill icons under them (rebuilt in place after a change)


func _init(window) -> void:
	_win = weakref(window)
	hud = window.hud
	main = window.main


## The tab's content now: a skill's detail when one is looked at, else the circles and the grid.
func content() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.mouse_filter = Control.MOUSE_FILTER_PASS        # the space round the circles and icons scrolls the dialog
	var w = _win.get_ref()
	if w == null:
		return box
	var sid := String(w.shown_id)
	if sid != "" and String(w.part_of(sid)) == "skills":
		_grid = null
		_detail(box, w, w.entry("skills", sid))
		return box
	box.set_meta("saddlery_skills", true)
	box.add_child(_triangle())
	box.add_child(_label(_w("skill_slot_hint") + "\n" + _w("skill_slot_clear"), 19, MUTED, false, "hint"))
	_grid = _make_grid(w)
	box.add_child(_grid)
	return box


func tick(_delta: float) -> void:
	pass


func opened() -> void:
	pass


## This row's visit ends (another tab, an attachment's detail, the card closing): the circles go with the old content.
func closed() -> void:
	_tri = null
	_grid = null


## The circles now (the tests drop on them): the triangle of the overview showing, else null.
func triangle() -> SkillTriangle:
	return _tri if _tri != null and is_instance_valid(_tri) and _tri.is_inside_tree() else null


# ---------------------------------------------------------------- the circles and the grid
## The triangle: the one made before (moved out of the old content, which the card is freeing), showing the circles as
## they are now, or a new one.
func _triangle() -> SkillTriangle:
	var slots: Array = Data.skill_slots()
	if _tri != null and is_instance_valid(_tri) and not _tri.is_queued_for_deletion():
		var p := _tri.get_parent()
		if p != null:
			p.remove_child(_tri)
		_tri.set_slots(slots)
		return _tri
	_tri = SkillTriangle.new(hud)
	_tri.setup(slots, _on_drop, _on_clear, _may_drop)
	_tri.empty_tapped.connect(_on_empty)
	return _tri


## The four skills as round icons (learned ones drag; a tap opens the detail), in balance.json mount_skills' order.
func _make_grid(w) -> Control:
	var cells: Array = []
	for e: Dictionary in w.entries("skills"):
		cells.append({"id": String(e["id"]), "title": String(e["name"]), "note": String(w.state_line(e)),
			"icon": String(e["icon"]), "learned": int(e["level"]) >= 1, "slotted": String(e["state"]) == "slotted"})
	return SkillTriangle.skill_grid(hud, cells, w.inspect)


## The owner's say on a drop (the kit checks the payload, the circle and that the skill is learned): the Saddlery
## stands and no wave is on, as companion_shop.assign_skill will check again.
func _may_drop(_i: int, _sid: String) -> bool:
	return Data.saddlery_level() > 0 and not Save.ruined.has("saddlery") and not main.stations._locked()


## A learned skill dropped on circle i: it goes in (the rule moves it out of another circle, or replaces what was there).
func _on_drop(i: int, sid: String) -> void:
	if CompanionShop.assign_skill(main, i, sid):
		_changed()


## A tap on a filled circle: it empties (the skill stays learned in the grid).
func _on_clear(i: int) -> void:
	if CompanionShop.assign_skill(main, i, ""):
		_changed()


## A tap on an empty circle: how to fill it.
func _on_empty(_i: int) -> void:
	hud.toast(_w("skill_slot_hint"))


## The circles changed: they show it at once; the grid's rims follow after the drop (never while a drag is on).
func _changed() -> void:
	if _tri != null and is_instance_valid(_tri):
		_tri.set_slots(Data.skill_slots())
	_regrid.call_deferred()


## The grid made again in its place (its green rims show which skills are in the circles).
func _regrid() -> void:
	var w = _win.get_ref()
	if w == null or _grid == null or not is_instance_valid(_grid) or not _grid.is_inside_tree():
		return
	if hud.get_viewport().gui_is_dragging():
		_regrid.call_deferred()                         # another drag already started: wait for it
		return
	var p := _grid.get_parent()
	var at := _grid.get_index()
	var g := _make_grid(w)
	p.add_child(g)
	p.move_child(g, at)
	_grid.queue_free()
	_grid = g


# ---------------------------------------------------------------- a skill's detail
func _detail(box: VBoxContainer, w, e: Dictionary) -> void:
	var sid := String(e["id"])
	box.set_meta("skill_detail", sid)
	box.add_theme_constant_override("separation", 10)
	box.add_child(_picture(String(e["icon"]), String(e["name"])))
	box.add_child(_label(String(e["name"]), 32, hud.TILE_INK, true))
	var info := Data.saddle_info("skills", sid)
	var line := String(info.get("text", ""))
	if line != "":
		box.add_child(_label(line, 20, MUTED, false, "desc"))
	var lv := int(e["level"])
	var st = main.stations
	box.add_child(_label(String(st._saddle_note("skills", sid, maxi(lv, 1))), 24, hud.TILE_INK, false, "effect"))
	if lv >= 1:
		box.add_child(_label(_w("level_of") % [lv, int(e["top"])], 21, MUTED, false, "level"))
		if lv < int(e["top"]):
			box.add_child(_label(_w("next_level") % String(st._saddle_note("skills", sid, lv + 1)), 20, MUTED, false, "next"))
		if String(e["state"]) == "slotted":
			box.add_child(_label(_word("skill_in_use") % Data.mount_name(), 20, IN_USE, false, "slot"))
		else:
			box.add_child(_label(_w("skill_slot_hint"), 20, MUTED, false, "slot"))
	var tiles: ShopTiles = hud.p_tiles
	var price: Dictionary = e["price"]
	if tiles._price_kinds(price) > 0:
		var pl: HBoxContainer = tiles._price_line(price, tiles._list_w())
		pl.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_child(pl)
	if String(e["why"]) != "":
		box.add_child(_label(String(e["why"]), 21, WARN, false, "why"))
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	buttons.mouse_filter = Control.MOUSE_FILTER_PASS
	buttons.add_child(_button(_w("back"), "grey", true, w.back))
	var act := String(e["action"])
	buttons.add_child(_button(String(e["label"]), "green", act != "" and bool(e["can"]), w.act.bind("skills", sid, int(e["next"]))))
	box.add_child(buttons)


## The skill's picture big in the tiles' soft square (its icon, the one the circles and the grid show).
func _picture(icon: String, title: String) -> Control:
	var tiles: ShopTiles = hud.p_tiles
	var sq := Panel.new()
	sq.set_meta("detail_pic", true)
	var side := DETAIL_PIC + DETAIL_PAD * 2.0
	sq.custom_minimum_size = Vector2(side, side)
	sq.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sq.add_theme_stylebox_override("panel", tiles._ui_style("pic"))
	sq.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pic := TextureRect.new()
	pic.texture = hud.icon(icon)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.set_anchors_preset(Control.PRESET_FULL_RECT)
	pic.offset_left = DETAIL_PAD
	pic.offset_top = DETAIL_PAD
	pic.offset_right = -DETAIL_PAD
	pic.offset_bottom = -DETAIL_PAD
	sq.add_child(pic)
	if not hud._icon_known(icon):
		sq.add_child(tiles._letter(title))
	return sq


## A centred line: bold for the name; `tag` is its meta (the tests find "hint", "desc", "effect", "level", "next",
## "slot", "why").
func _label(text: String, size: int, ink: Color, bold: bool, tag := "") -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", ink)
	if bold:
		l.add_theme_font_override("font", hud.p_tiles._bold())
	if tag != "":
		l.set_meta(tag, true)
	return l


## One of the detail's buttons: the footer's button (the card kit draws it), but not the card's footer.
func _button(label: String, tone: String, on: bool, action: Callable) -> Button:
	var b: Button = CardParts.foot_button(hud, {"label": label, "tone": tone if on else "grey", "enabled": on, "action": action})
	b.remove_meta("footer")
	b.custom_minimum_size = BTN
	return b


static func _w(key: String) -> String:
	return String(Data.word(key))


## A window word: balance.json "windows" when it has it, else this file's H5_WORDS.
static func _word(key: String) -> String:
	var w := Data.word(key)
	return String(H5_WORDS.get(key, key)) if w == key else w
