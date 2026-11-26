extends RefCounted
## H4: the build menu (the build icon next to the Bag; in hud.windows under "build", not a marker). It opens through
## the card like the Settings window: it has a `key` and a `builder`, and its one row is a {"kind": "window"} row (this
## object), so the card draws content() and calls tick, opened and closed. A wave blanks it, as every station card.
## What it shows: every building you can build now, as a big picture with its price and its own Build button (one tap),
## and, once the first Raid Mission is won, the ones that are not open yet, greyed out with what they need (no button).
## A tap on a picture opens that building's detail view (a bigger picture, what it does, the price, Build and Back).
## A built building leaves the menu (the owner, 26 Nov 2026). While the Hearthtree is in ruins nothing can be built and
## the menu says so. Building pays and builds through stations.gd (_build_station), closes the menu and sends the camera
## to the new building (main.show_spot); stations.refresh then lets it rise out of the ground.
## The pictures fade and grow in one after another, about 0.03 s apart (the card's own reveal helper), and the detail
## view fades in the same way; only this window does that.
## Used by: ui/windows/window_list.gd (made with the building windows), the build icon (ui/hud/action_buttons.gd: toggle,
##          pulse), the Hearthtree's goals (open_at), the tests.
## Uses: Data (the menu buildings, their unlock rules, pictures, descriptions, prices and the words, Data.word), Save,
##       ui/kit/icon_grid.gd, ui/kit/card_parts.gd (the footer's button), the HUD (card, icons, tiles), stations.gd
##       (_build_station), main.gd (show_spot).

const IconGrid := preload("res://ui/kit/icon_grid.gd")
const CardParts := preload("res://ui/kit/card_parts.gd")
const ShopTiles := preload("res://ui/hud/shop_tiles.gd")   # the type of the HUD's tiles (hud.p_tiles)

const REVEAL_STEP := 0.03               # the pictures appear this far apart (an animation timing, in code)
const REVEAL_MAX := 0.3                 # the last one starts by now
const DETAIL_PIC := 200.0               # the detail view's picture
const DETAIL_PAD := 8.0                 # the soft square behind it is this much bigger on each side
const BTN := Vector2(220, 64)           # the detail view's Build and Back

var hud                                 # the HUD node (untyped on purpose, as in the HUD's parts)
var main
var key := "build"                      # not exempt from the wave blank: a wave blanks it, as every station card
var builder: Callable = spec            # a ring in the card system has a builder (this has no marker)
var _detail := ""                       # the building whose detail view shows ("" = the grid)
var _reveal := false                    # the next content() fades its pictures in (a new visit or a new view)
var _reveal_frame := -1                 # the frame that last faded in: a rebuild in that same frame fades in too


func _init(owner_hud) -> void:
	hud = owner_hud
	main = hud.main if hud != null else null


## The card: the menu's title and its one window row; while the Hearthtree is in ruins only "Repair the Hearthtree
## first" (nothing can be built then, as today).
func spec() -> Dictionary:
	if _ruined():
		return {"title": String(Data.word("build_title")), "sub": "", "anchor": Vector3.ZERO,
			"rows": [{"text": String(Data.word("build_ruined")) % Data.camp_name()}]}
	return {"title": String(Data.word("build_title")), "sub": "", "anchor": Vector3.ZERO,
		"rows": [{"kind": "window", "window": self, "enabled": true}]}


func open() -> void:
	if hud != null:
		hud.show_card(self)


## The build icon's tap: close the menu when it is open, else open it.
func toggle() -> void:
	if hud == null:
		return
	if hud.card_ring() == self:
		hud.hide_card()
	else:
		open()


## Opens the menu at building `id`'s detail view (a goal's Show). The card does not reopen the card already open
## (card.gd show_card), so an open menu only redraws.
func open_at(id: String) -> void:
	_detail = id
	_reveal = true
	if hud != null and hud.card_ring() == self:
		hud.refresh_card()
	else:
		open()


## What the grid shows now, in the buildings' order: [{"id", "name", "state": "open" | "locked", "needs", "price",
## "icon", "picture"}]. A building already built is left out. One whose flag is not set yet (the first mission's shop
## flags, the shop's opening) is left out as well. The rest are "open" when nothing is missing, else "locked", once
## balance.json build_menu.locked_from_missions Raid Missions are won. `needs` is what a locked one waits for, in the
## words "Needs the Hearthtree at level 2 · Finish 8 Raid Missions first" ("" when open).
func entries() -> Array:
	var out: Array = []
	var from_won := int((Data.b.get("build_menu", {}) as Dictionary).get("locked_from_missions", 1))
	for e: Dictionary in Data.menu_buildings():
		var id := String(e.get("id", ""))
		if Data.station_level(id) > 0:
			continue
		var home_bits: Array = []
		var mission_bits: Array = []
		var flag_missing := false
		for part: Dictionary in Data.unlock_missing(e.get("unlock", {}) as Dictionary):
			match String(part.get("type", "")):
				"flag":
					flag_missing = true
				"building":
					home_bits.append(String(Data.word("needs_home")) % [Data.camp_name(), int(part.get("level", 1))])
				"missions_won":
					mission_bits.append(String(Data.word("needs_missions")) % int(part.get("n", 0)))
		if flag_missing:
			continue
		var missing := not home_bits.is_empty() or not mission_bits.is_empty()
		if missing and Data.progress() < from_won:
			continue
		out.append({"id": id, "name": String(e.get("name", id)), "state": "locked" if missing else "open",
			"needs": " · ".join(home_bits + mission_bits), "price": Data.build_price(id),
			"icon": String(e.get("icon", "")), "picture": Data.building_picture(id)})
	return out


## The build icon's "!" dot: an open entry whose price can be paid (never while the Hearthtree is in ruins).
func pulse() -> bool:
	if _ruined():
		return false
	for e: Dictionary in entries():
		if String(e["state"]) == "open" and Data.can_afford(e["price"] as Dictionary):
			return true
	return false


## The window row's contents (the card calls it on every rebuild): the grid of pictures, or the detail view of `_detail`
## (the grid when that building is not in the menu any more). When a reveal is due the pictures fade in one after
## another (the card's own helper), once.
func content() -> Control:
	var es := entries()
	var shown: Dictionary = {}
	for e: Dictionary in es:
		if String(e["id"]) == _detail:
			shown = e
	if _detail != "" and shown.is_empty():
		_detail = ""                                   # built meanwhile, or not on the menu: back to the grid
	# a goal's Show opens the menu and its button's own refresh rebuilds it in the same frame: that rebuild fades too
	var now := Engine.get_process_frames()
	var fade := _reveal or _reveal_frame == now
	if _reveal:
		_reveal_frame = now
	_reveal = false
	if not shown.is_empty():
		var box := _detail_view(shown)
		if fade:
			_fade_in(box, 0.0)
		return box
	if es.is_empty():
		var box := VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var l := Label.new()
		l.text = String(Data.word("build_empty"))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", 22)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(l)
		return box
	var grid := IconGrid.make(hud, _cells(es), _open_detail)
	if fade:
		var i := 0
		for cell: Node in grid.get_children():
			_fade_in(cell as Control, minf(float(i) * REVEAL_STEP, REVEAL_MAX))
			i += 1
	return grid


## The card's own reveal (card_signpost.gd _reveal_signpost_control: a quick fade and a small grow), started at the
## next deferred moment and only on a picture still showing. A rebuild in the same frame (a goal's Show, then its
## button's refresh) frees the first build's pictures, and a test's timer can run between the two; the card's helper
## would then hand a freed picture on.
func _fade_in(c: Control, delay: float) -> void:
	c.modulate.a = 0.0                                 # hidden until it starts (no flash of the full picture first)
	var wr: WeakRef = weakref(c)
	var start := func() -> void:
		var n: Control = wr.get_ref() as Control
		if n != null and n.is_inside_tree() and not n.is_queued_for_deletion():
			hud.p_sign._reveal_signpost_control(n, delay)
	start.call_deferred()


func tick(_delta: float) -> void:
	pass


## A visit starts (the card, just before its first content()): the pictures appear one after another.
func opened() -> void:
	_reveal = true


## The visit ends: the next visit starts on the grid.
func closed() -> void:
	_detail = ""


# ---------------------------------------------------------------- the grid and the detail view
## The grid's cells: an open building shows its price and its own Build button (one tap), a locked one what it needs
## and no button at all (the whole cell greyed; a tap still opens its detail view).
func _cells(es: Array) -> Array:
	var out: Array = []
	for e: Dictionary in es:
		var id := String(e["id"])
		var open := String(e["state"]) == "open"
		var price: Dictionary = e["price"]
		out.append({"id": id, "title": String(e["name"]), "picture": String(e["picture"]), "icon": String(e["icon"]),
			"cost": price if open else {}, "note": "" if open else String(e["needs"]), "locked": not open,
			"label": String(Data.word("build")) if open else "", "enabled": open and Data.can_afford(price),
			"action": _build.bind(id)})
	return out


## A tap on a cell: its detail view.
func _open_detail(id: String) -> void:
	_detail = id
	_reveal = true
	hud.refresh_card()


func _back() -> void:
	_detail = ""


## The detail view: the picture at 200 px, the name (bold 32), what the building does (its entry's desc, the pet's and
## the mount's names filled in), the price, then Back and Build (or what it still needs, with no Build).
func _detail_view(e: Dictionary) -> Control:
	var tiles: ShopTiles = hud.p_tiles
	var id := String(e["id"])
	var open := String(e["state"]) == "open"
	var price: Dictionary = e["price"]
	var box := VBoxContainer.new()
	box.set_meta("detail", id)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	var sq := Panel.new()
	sq.set_meta("detail_pic", true)
	var side := DETAIL_PIC + DETAIL_PAD * 2.0
	sq.custom_minimum_size = Vector2(side, side)
	sq.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sq.add_theme_stylebox_override("panel", tiles._ui_style("pic"))
	sq.mouse_filter = Control.MOUSE_FILTER_PASS
	var raw: Variant = String(e["icon"])
	var own: Texture2D = hud.p_icons._picture(String(e["picture"]))
	if own != null:
		raw = own
	var pic := TextureRect.new()
	pic.texture = hud.icon(raw)
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
	if not hud._icon_known(raw):
		sq.add_child(tiles._letter(String(e["name"])))
	box.add_child(sq)
	var name_l := Label.new()
	name_l.text = String(e["name"])
	name_l.add_theme_font_override("font", tiles._bold())
	name_l.add_theme_font_size_override("font_size", 32)
	name_l.add_theme_color_override("font_color", hud.TILE_INK)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_l)
	var desc := Label.new()
	desc.set_meta("desc", true)
	desc.text = Data.building_desc(id)
	desc.add_theme_font_size_override("font_size", 22)
	desc.add_theme_color_override("font_color", Color(0.45, 0.36, 0.26))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(desc)
	if tiles._price_kinds(price) > 0:
		var line: HBoxContainer = tiles._price_line(price, tiles._list_w())
		line.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_child(line)
	if not open:
		var needs := Label.new()
		needs.set_meta("needs", true)
		needs.text = String(e["needs"])
		needs.add_theme_font_size_override("font_size", 21)
		needs.add_theme_color_override("font_color", Color(0.7, 0.28, 0.2))
		needs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		needs.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		needs.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(needs)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	buttons.mouse_filter = Control.MOUSE_FILTER_PASS
	buttons.add_child(_button(String(Data.word("back")), "grey", true, _back))
	if open:
		buttons.add_child(_button(String(Data.word("build")), "green", Data.can_afford(price), _build.bind(id)))
	box.add_child(buttons)
	return box


## One of the detail view's buttons: the footer's button (the card kit draws it), but it is not the card's footer.
func _button(label: String, tone: String, on: bool, action: Callable) -> Button:
	var b: Button = CardParts.foot_button(hud, {"label": label, "tone": tone, "enabled": on, "action": action})
	b.remove_meta("footer")
	b.custom_minimum_size = BTN
	return b


# ---------------------------------------------------------------- building
## Builds `id` (stations.gd pays, sets level 1, tells the world and the banner). When it stands afterwards: the menu
## closes and the camera shows the new building (main.show_spot; stations.refresh makes it rise). Nothing is built while
## the Hearthtree is in ruins (the menu does not even show cells then).
func _build(id: String) -> void:
	if main == null or _ruined():
		return
	main.stations._build_station(id)
	if Data.station_level(id) > 0:
		_detail = ""
		hud.hide_card()
		main.show_spot(main.world.station_pos(id))


func _ruined() -> bool:
	return Save.ruined.has("home")
