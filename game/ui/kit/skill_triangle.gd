extends Control
## H5 (the window kit; the H5 map part 3.4, the owner's Q3 of 26 Nov 2026): the mount's skill circles on the Saddlery's
## Skills tab. Three circles (saddlery.skill_slot_count) joined by lines in a triangle, one at the top and two below;
## every mount shares them. Under them the Saddlery window puts the grid of round skill icons (skill_grid() below). A
## learned skill's icon is dragged into a circle to use it there; the mount fights only with the skills in the circles
## (Data.active_skill_level), and a learned skill outside them keeps its level in the grid.
## It holds no rules: the owner hands it what each circle shows and two callables, and does the change itself
## (scripts/companion_shop.gd assign_skill), then redraws it (set_slots, or the card's next rebuild).
##   SkillTriangle.new(hud), then setup(slots, on_drop, on_clear, check)
##     slots      the skill id in each circle, in order ("" = empty): Data.skill_slots()
##     on_drop    Callable(index: int, id: String): a learned skill was dropped on circle index (it replaces what was
##                there; the rule moves it out of its old circle when it was in one)
##     on_clear   Callable(index: int): a filled circle was tapped (it empties; the skill stays learned)
##     check      optional Callable(index: int, id: String) -> bool: the owner's own say on a drop (the Saddlery stands,
##                no wave is on); without it only the kit's checks below hold
##   set_slots(slots)   shows new contents in place (the circles are kept, so nothing jumps and no drag is cut short)
##   slot_ids()         what the circles show; slot_node(i) circle i (a DropSlot; the tests drop on it)
##   can_take(i, payload)   whether a drop of payload on circle i would be taken (the circles ask it; the tests too)
##   signal empty_tapped(index)   an empty circle was tapped (the owner can show how to fill it)
## A drop is taken only when every check holds: the payload is {"kind": PAYLOAD_KIND, "id": a String}; the circle is
## one of them; the skill is a known one (Data.saddle_info) and learned (Data.skill_level >= 1); it is not already in
## that circle; and the owner's check says yes. Anything else is refused before on_drop is called, so a refused drop
## leaves the three circles and every learned level as they were.
## Touch: the circles and the grid's icons stop their touches (the drag kit's rule, drag_source.gd and drop_slot.gd);
## everything around them (the space round the triangle, the gaps and the side gutters of the grid) passes the touch on,
## so the player still scrolls the dialog from there and a drag is never lost to the scroll.
## Used by: ui/windows/saddlery_window.gd (H5 Stage 2), the tests. Uses: ui/kit/drop_slot.gd, drag_source.gd,
## icon_grid.gd (the grey look), the HUD's icons, fonts and ink, Data (the skills' icons, learned levels, circles).
## No class_name: preload it.

signal empty_tapped(index: int)

const DropSlot := preload("res://ui/kit/drop_slot.gd")
const DragSource := preload("res://ui/kit/drag_source.gd")
const IconGrid := preload("res://ui/kit/icon_grid.gd")

const PAYLOAD_KIND := "mount_skill"     # what a skill icon carries: {"kind": "mount_skill", "id": <skill id>}
const CIRCLE := 116.0                   # a circle's width
const SIDE := 236.0                     # from one circle's middle to the next one's
const RING := 5.0                       # a circle's rim
const ICON_INSET := 18.0                # the skill's picture inside a circle, this far from its edge
const LINE_W := 6.0                     # the lines joining the circles
const EDGE := 6.0                       # room round the circles' rims
const WOOD := Color(0.56, 0.35, 0.17)
const LINE_INK := Color(0.56, 0.35, 0.17, 0.45)
const FILL := Color(1.0, 0.985, 0.94)   # a filled circle (the tiles' parchment)
const FILL_EMPTY := Color(0.96, 0.88, 0.7, 0.55)   # an empty one (the pictures' soft square, faded)
const RIM_EMPTY := Color(0.56, 0.35, 0.17, 0.4)
# the skill grid under the triangle
const MIN_ACROSS := 3                   # at least this many icons a row, at both phone sizes (the map's rule)
const GUTTER := 32.0                    # free space at each side of the grid: a drag there scrolls the dialog
const GAP := 12.0                       # between two icons, both ways
const CELL_W := 118.0                   # an icon's cell at most (narrower when MIN_ACROSS would not fit)
const DISC := 88.0                      # the round icon in it
const DISC_RING := 4.0
const NAME_FS := 18
const NOTE_FS := 16
const NOTE_INK := Color(0.45, 0.36, 0.26)
const SLOTTED_RIM := Color(0.33, 0.6, 0.2)   # a skill in a circle: a green rim round its icon in the grid

var hud                                 # the HUD node (untyped on purpose, as in the kit's other parts)
var _ids: Array[String] = []            # what each circle shows
var _on_drop: Callable
var _on_clear: Callable
var _check: Callable                    # the owner's own say on a drop (optional)
var _points: Array[Vector2] = []        # each circle's middle, round the triangle's own middle
var _box := Rect2()                     # the circles' whole room round that middle
var _circles: Array[Control] = []       # the DropSlots, one per circle
var _pics: Array[TextureRect] = []      # the skill picture in each


func _init(owner_hud = null) -> void:
	hud = owner_hud
	mouse_filter = Control.MOUSE_FILTER_PASS            # a drag on the space round the circles scrolls the dialog
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	set_meta("skill_triangle", true)
	resized.connect(_place)


## Makes the circles (again, if it had some): see the top for the arguments.
func setup(slots: Array, on_drop: Callable, on_clear: Callable, check: Callable = Callable()) -> void:
	_on_drop = on_drop
	_on_clear = on_clear
	_check = check
	for c: Control in _circles:
		remove_child(c)
		c.queue_free()
	_circles.clear()
	_pics.clear()
	_ids = _as_ids(slots)
	_points = _corners(_ids.size())
	_box = _room(_points)
	custom_minimum_size = _box.size
	for i in _ids.size():
		_circles.append(_circle(i))
		add_child(_circles[i])
	set_slots(_ids)
	_place()


## Shows new contents in the circles in place (a different number of circles makes them again).
func set_slots(slots: Array) -> void:
	var ids := _as_ids(slots)
	if ids.size() != _circles.size():
		setup(ids, _on_drop, _on_clear, _check)
		return
	_ids = ids
	for i in _ids.size():
		var c: Control = _circles[i]
		c.set_meta("skill", _ids[i])
		_pics[i].texture = _skill_icon(_ids[i]) if _ids[i] != "" else null
		c.queue_redraw()


func slot_ids() -> Array[String]:
	var out: Array[String] = []
	out.assign(_ids)
	return out


## Circle i (a DropSlot), or null.
func slot_node(i: int) -> Control:
	return _circles[i] if i >= 0 and i < _circles.size() else null


## The kit's checks and the owner's say on dropping payload p on circle i (see the top).
func can_take(i: int, p: Dictionary) -> bool:
	if i < 0 or i >= _ids.size() or String(p.get("kind", "")) != PAYLOAD_KIND or not (p.get("id") is String):
		return false
	var id := String(p["id"])
	if id == "" or Data.saddle_info("skills", id).is_empty() or Data.skill_level(id) < 1 or _ids[i] == id:
		return false
	return not _check.is_valid() or bool(_check.call(i, id))


# ---------------------------------------------------------------- the circles
func _circle(i: int) -> Control:
	var slot := DropSlot.new()
	slot.set_meta("skill_slot", i)
	slot.size = Vector2(CIRCLE, CIRCLE)
	slot.custom_minimum_size = Vector2(CIRCLE, CIRCLE)
	slot.accepts = func(p: Dictionary) -> bool: return can_take(i, p)
	slot.dropped = _dropped.bind(i)
	slot.tapped.connect(_tapped.bind(i))
	slot.draw.connect(_draw_circle.bind(slot, i))
	var pic := TextureRect.new()
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.set_anchors_preset(Control.PRESET_FULL_RECT)
	pic.offset_left = ICON_INSET
	pic.offset_top = ICON_INSET
	pic.offset_right = -ICON_INSET
	pic.offset_bottom = -ICON_INSET
	slot.add_child(pic)
	_pics.append(pic)
	return slot


## A circle: a parchment disc with a wood rim when it holds a skill, a faded one when it is empty.
func _draw_circle(slot: Control, i: int) -> void:
	var filled := i < _ids.size() and _ids[i] != ""
	var c := slot.size * 0.5
	var r := minf(slot.size.x, slot.size.y) * 0.5
	slot.draw_circle(c, r, WOOD if filled else RIM_EMPTY)
	slot.draw_circle(c, r - RING, FILL if filled else FILL_EMPTY)


## A drop the checks took (Godot asks accepts first; asked again here, so a refused one never reaches the owner).
func _dropped(p: Dictionary, i: int) -> void:
	if can_take(i, p) and _on_drop.is_valid():
		_on_drop.call(i, String(p["id"]))


## A tap on a filled circle empties it; on an empty one, the owner hears empty_tapped.
func _tapped(i: int) -> void:
	if i < 0 or i >= _ids.size():
		return
	if _ids[i] == "":
		empty_tapped.emit(i)
	elif _on_clear.is_valid():
		_on_clear.call(i)


## The lines joining the circles, under them (a child draws over its parent).
func _draw() -> void:
	if _points.size() < 2:
		return
	var o := _origin()
	var loop := _points.size() >= 3
	for i in _points.size():
		if i == _points.size() - 1 and not loop:
			break
		draw_line(o + _points[i], o + _points[(i + 1) % _points.size()], LINE_INK, LINE_W, true)


## Puts the circles round the middle of the room it was given.
func _place() -> void:
	var o := _origin()
	for i in _circles.size():
		_circles[i].position = o + _points[i] - Vector2(CIRCLE, CIRCLE) * 0.5
		_circles[i].size = Vector2(CIRCLE, CIRCLE)
	queue_redraw()


## Where the triangle's own middle sits in this control (its room centred both ways).
func _origin() -> Vector2:
	return (size - _box.size) * 0.5 - _box.position


## Each circle's middle round (0, 0): one at the top, then on round the other way from a clock (the second at the
## bottom left, the third at the bottom right), SIDE apart. One circle sits in the middle; two side by side.
static func _corners(n: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if n == 1:
		out.append(Vector2.ZERO)
	elif n == 2:
		out.append(Vector2(-SIDE * 0.5, 0.0))
		out.append(Vector2(SIDE * 0.5, 0.0))
	elif n >= 3:
		var r := SIDE / (2.0 * sin(PI / float(n)))     # the circle through the corners of a shape with sides SIDE
		for i in n:
			var a := -PI * 0.5 - TAU * float(i) / float(n)
			out.append(Vector2(cos(a), sin(a)) * r)
	return out


## The room the circles take round (0, 0): every middle, a circle round it, and EDGE more.
static func _room(points: Array[Vector2]) -> Rect2:
	if points.is_empty():
		return Rect2()
	var half := Vector2(CIRCLE, CIRCLE) * 0.5 + Vector2(EDGE, EDGE)
	var box := Rect2(points[0] - half, half * 2.0)
	for p: Vector2 in points:
		box = box.merge(Rect2(p - half, half * 2.0))
	return box


## Only ids (a non-String entry becomes an empty circle).
static func _as_ids(slots: Array) -> Array[String]:
	var out: Array[String] = []
	for s: Variant in slots:
		out.append(String(s) if s is String else "")
	return out


## A skill's picture: its icon in balance.json mount_skills (the four shipped pictures), else its id's.
func _skill_icon(id: String) -> Texture2D:
	if hud == null:
		return null
	return hud.icon(String(Data.saddle_info("skills", id).get("icon", id)))


# ---------------------------------------------------------------- the grid of skill icons under the triangle
## The skills as round icons, MIN_ACROSS or more a row (all of them in one row when they fit), centred with GUTTER
## free at each side. cells: [{"id", "title" (the name under it), "note" (a short line: "Level 2"), "icon" (an icon id
## or a texture; default the skill's own), "learned" (default Data.skill_level(id) >= 1), "slotted" (default
## Data.skill_is_slotted(id))}]. Each icon is a DragSource carrying payload(id): a learned one drags, an unlearned one
## is grey and only taps. A tap on any of them calls on_tap(id) (the owner opens its detail: Learn or Upgrade).
## A skill in a circle has a green rim. Returns the holder (meta "skill_grid"); each icon has meta "skill_cell" = id,
## "learned", "slotted".
static func skill_grid(owner_hud, cells: Array, on_tap: Callable) -> Control:
	var holder := CenterContainer.new()
	holder.set_meta("skill_grid", true)
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.mouse_filter = Control.MOUSE_FILTER_PASS     # the gutters and gaps scroll the dialog
	var list: Array[Dictionary] = []
	for c: Variant in cells:
		if c is Dictionary and String((c as Dictionary).get("id", "")) != "":
			list.append(c as Dictionary)
	var cols := columns(owner_hud, list.size())
	var w := cell_width(owner_hud, cols)
	var g := GridContainer.new()
	g.columns = maxi(cols, 1)
	g.add_theme_constant_override("h_separation", int(GAP))
	g.add_theme_constant_override("v_separation", int(GAP))
	g.mouse_filter = Control.MOUSE_FILTER_PASS
	holder.add_child(g)
	for c: Dictionary in list:
		g.add_child(_skill_cell(owner_hud, c, w, on_tap))
	return holder


## How many icons a row: as many cells of CELL_W as fit between the gutters, at least MIN_ACROSS, never more than n.
static func columns(owner_hud, n: int) -> int:
	if n <= 0:
		return 1
	var room := _grid_room(owner_hud)
	var fit := int(floorf((room + GAP) / (CELL_W + GAP)))
	return mini(maxi(fit, MIN_ACROSS), n)


## A cell's width with cols a row: CELL_W, or less so that MIN_ACROSS fit between the gutters.
static func cell_width(owner_hud, cols: int) -> float:
	var n := maxi(cols, 1)
	return minf(CELL_W, floorf((_grid_room(owner_hud) - GAP * float(n - 1)) / float(n)))


## What one icon carries when it is dragged.
static func payload(id: String) -> Dictionary:
	return {"kind": PAYLOAD_KIND, "id": id}


## The list's width less the two gutters (the dialog's list: shop_tiles' _list_w); without a HUD, room for MIN_ACROSS.
static func _grid_room(owner_hud) -> float:
	var least := CELL_W * float(MIN_ACROSS) + GAP * float(MIN_ACROSS - 1)
	if owner_hud == null:
		return least
	var w: float = owner_hud.p_tiles._list_w()
	return maxf(w - GUTTER * 2.0, CELL_W)


## One round skill icon: the disc with the skill's picture, its name and its short line under it.
static func _skill_cell(owner_hud, c: Dictionary, w: float, on_tap: Callable) -> Control:
	var id := String(c["id"])
	var learned := bool(c.get("learned", Data.skill_level(id) >= 1))
	var slotted := bool(c.get("slotted", Data.skill_is_slotted(id)))
	var raw: Variant = c.get("icon", String(Data.saddle_info("skills", id).get("icon", id)))
	var tex: Texture2D = owner_hud.icon(raw)
	var disc := minf(DISC, w - 12.0)
	var src := DragSource.new()
	src.set_meta("skill_cell", id)
	src.set_meta("learned", learned)
	src.set_meta("slotted", slotted)
	src.payload = payload(id)
	src.can_drag = learned
	src.icon = tex
	src.tapped.connect(func() -> void:
		if on_tap.is_valid():
			on_tap.call(id))
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE            # the source takes the touch (it drags or taps)
	v.add_theme_constant_override("separation", 2)
	v.alignment = BoxContainer.ALIGNMENT_BEGIN
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	src.add_child(v)
	var ring := Control.new()
	ring.custom_minimum_size = Vector2(disc, disc)
	ring.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.draw.connect(func() -> void:
		var mid := ring.size * 0.5
		var r := minf(ring.size.x, ring.size.y) * 0.5
		ring.draw_circle(mid, r, SLOTTED_RIM if slotted else WOOD)
		ring.draw_circle(mid, r - DISC_RING, FILL))
	v.add_child(ring)
	var pic := TextureRect.new()
	pic.texture = tex
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.set_anchors_preset(Control.PRESET_FULL_RECT)
	var inset := disc * 0.16
	pic.offset_left = inset
	pic.offset_top = inset
	pic.offset_right = -inset
	pic.offset_bottom = -inset
	if not learned:
		pic.material = IconGrid.grey_material()           # not learned yet: grey, it only taps
		pic.modulate.a = IconGrid.GREY_ALPHA
	ring.add_child(pic)
	var h := disc + 4.0
	for line: Array in [[String(c.get("title", "")), NAME_FS, true], [String(c.get("note", "")), NOTE_FS, false]]:
		if String(line[0]) == "":
			continue
		var l := Label.new()
		l.text = String(line[0])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.clip_text = true
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.add_theme_font_size_override("font_size", int(line[1]))
		var ink: Color = owner_hud.TILE_INK if bool(line[2]) else NOTE_INK
		l.add_theme_color_override("font_color", ink if learned else IconGrid.GREY_INK)
		if bool(line[2]):
			l.add_theme_font_override("font", owner_hud.p_tiles._bold())
		v.add_child(l)
		h += ceilf(ThemeDB.fallback_font.get_height(int(line[1]))) + 2.0
	src.custom_minimum_size = Vector2(w, h)
	return src
