extends Node
## Build menu checks for autotest.gd (`-- --autotest --fresh --buildmenu`; ui/windows/build_menu_window.gd, ui/kit/icon_grid.gd,
## H4 Stage 2, 26 Nov 2026). It also checks P2e's pieces: the build icon's tap and its dot, the camera shot (main.show_spot,
## main._show_t) and the building's rise. Each check logs "EXPECT PASS <what>" or "EXPECT FAIL <what>" through
## autotest.gd's _expect. The window is reached through main.hud.windows["build"] only, and its cells through what they
## draw (meta "cell", "locked", "detail", button meta "label"), never through the stations forwarders.
## Checks:
##   (a) entries() at a fresh save (empty), after wave 1 of mission 1 (the Target "open"), after the first win (Target and Bow
##       Shop "open"; Well, Market, Saddlery, Tailor "locked" with today's needs words), at Hearthtree 2 (the Market
##       open)
##   (b) a real tap on the build icon opens the window, a second tap closes it; it fits at 480x1040 and 540x960; the empty
##       menu says W.build_empty; the cells fade in one after another and reach alpha 1; a locked cell has no Build button
##   (c) a real tap on a cell opens its detail (name, desc with the names filled in, price, Build, Back); Back returns;
##       open_at(id) on the open menu shows that detail, open_at on a closed one opens it; a locked detail has no Build
##   (d) Build (a cell's own button, then the detail's): pays exactly the price, sets level 1, sends building_upgraded(id, 1),
##       closes the window; the camera shot starts (main._show_t) and ends within 4 s, at once when a wave starts; the
##       building rises from the ground and ends at its base scale; a built building leaves the grid
##   (e) the build icon's dot follows pulse() (an open building you can pay for); a wave blanks the menu; the Hearthtree in
##       ruins shows W.build_ruined, nothing builds and pulse() is false
## Screenshots: buildmenu_grid, buildmenu_detail, buildmenu_rise.

var t                     # autotest.gd (its helpers: _wait, _shot, _expect, _until, _tap_at, _tap_close)
var main
var _lay                  # autotest_layout.gd, for its _card_fits (the dialog fits the phone and its safe area)
var _built: Array = []    # building_upgraded(id, level) events seen
var _snap := {}


func _x(what: String, ok: bool, extra := {}) -> bool:
	return t._expect(what, ok, extra)


func _on_upgraded(id: String, level: int) -> void:
	_built.append([id, level])


func run() -> bool:
	main.player.invincible = true
	_lay = load("res://scripts/autotest_layout.gd").new()
	_lay.t = t
	_lay.main = main
	add_child(_lay)
	get_window().size = Vector2i(480, 1040)
	await t._wait(0.5)
	_take_snapshot()
	Events.building_upgraded.connect(_on_upgraded)
	var ok := true
	ok = await _check_entries() and ok
	ok = await _check_window() and ok
	ok = await _check_detail() and ok
	ok = await _check_build() and ok
	ok = await _check_dot_wave_ruin() and ok
	Events.building_upgraded.disconnect(_on_upgraded)
	_restore()
	await t._wait(0.3)
	return ok


# ---------------------------------------------------------------- the save state this test needs
func _take_snapshot() -> void:
	_snap = {"won": Save.missions_done.duplicate(), "camp": Save.camp_level, "stations": Save.stations.duplicate(),
		"flags": Save.flags.duplicate(), "leaves": Save.leaves, "timber": Save.timber, "ruined": Save.ruined.duplicate(),
		"active": main.fight.active, "in_wave": main.fight.in_wave}


func _restore() -> void:
	main.hud.hide_card()
	Save.missions_done = (_snap["won"] as Array).duplicate()
	Save.camp_level = int(_snap["camp"])
	Save.stations = (_snap["stations"] as Dictionary).duplicate()
	Save.flags = (_snap["flags"] as Dictionary).duplicate()
	Save.leaves = int(_snap["leaves"])
	Save.timber = int(_snap["timber"])
	Save.ruined = (_snap["ruined"] as Array).duplicate()
	main.fight.active = bool(_snap["active"])
	main.fight.in_wave = bool(_snap["in_wave"])
	main.stations.refresh()
	main.hud.refresh()
	get_window().size = Vector2i(480, 1040)


## Nothing built that the menu sells, `won` missions won, the Hearthtree at `camp`, these flags, rich (or `leaves`).
func _state(won: int, camp: int, flags: Array, leaves := 5000) -> void:
	main.hud.hide_card()
	Save.missions_done = []
	for i in won:
		Save.missions_done.append(String(Data.mission(i)["id"]))
	Save.camp_level = camp
	for e: Dictionary in Data.menu_buildings():
		Save.stations[String(e["id"])] = 0
	for k in ["shop_open", "shop_target", "shop_bench"]:
		Save.flags.erase(k)
	for k: String in flags:
		Save.set_flag(k)
	Save.ruined = []
	Save.leaves = leaves
	Save.timber = 500
	main.fight.active = false
	main.fight.in_wave = false
	main.stations.refresh()
	main.hud.refresh()


func _w():
	return main.hud.windows["build"]


func _ids(es: Array) -> Array:
	var out: Array = []
	for e: Dictionary in es:
		out.append(String(e["id"]))
	return out


func _entry(id: String) -> Dictionary:
	for e: Dictionary in _w().entries():
		if String(e["id"]) == id:
			return e
	return {}


func _needs_home(n: int) -> String:
	return String(Data.word("needs_home")) % [Data.camp_name(), n]


func _needs_missions(n: int) -> String:
	return String(Data.word("needs_missions")) % n


## The cell of building `id` in the open card (null when none).
func _cell(id: String) -> Control:
	var hud = main.hud
	if hud._card == null:
		return null
	for c: Node in hud._card.find_children("*", "PanelContainer", true, false):
		if c.has_meta("cell") and String(c.get_meta("cell")) == id and not _going(c):
			return c as Control
	return null


func _cells() -> Array:
	var out: Array = []
	var hud = main.hud
	if hud._card == null:
		return out
	for c: Node in hud._card.find_children("*", "PanelContainer", true, false):
		if c.has_meta("cell") and not _going(c):
			out.append(c)
	return out


func _detail_box() -> Control:
	var hud = main.hud
	if hud._card == null:
		return null
	for c: Node in hud._card.find_children("*", "VBoxContainer", true, false):
		if c.has_meta("detail") and not _going(c):
			return c as Control
	return null


func _buttons_in(n: Node) -> Array:
	var out: Array = []
	for b: Node in n.find_children("*", "Button", true, false):
		if not _going(b):
			out.append(b)
	return out


## A node or one of its parents is being freed (a card's rebuild frees the old rows; their insides are not marked).
func _going(n: Node) -> bool:
	var q: Node = n
	while q != null:
		if q.is_queued_for_deletion():
			return true
		q = q.get_parent()
	return false


func _button_in(n: Node, label: String) -> Button:
	for b: Button in _buttons_in(n):
		if String(b.get_meta("label", "")) == label:
			return b
	return null


func _texts() -> Array:
	var out: Array = []
	var hud = main.hud
	if hud._card == null:
		return out
	for l: Node in hud._card.find_children("*", "Label", true, false):
		if not _going(l):
			out.append((l as Label).text)
	return out


func _dot() -> Control:
	var icon: Control = main.hud._build_icon
	if icon == null:
		return null
	for c: Node in icon.get_children():
		if c is Control and (String(c.name).to_lower().contains("dot") or c.has_meta("dot")):
			return c as Control
	return null


func _dot_shown() -> bool:
	var d := _dot()
	return d != null and d.is_visible_in_tree() and d.modulate.a > 0.5


func _open_menu() -> void:
	_w().open()
	await t._wait(0.4)


# ---------------------------------------------------------------- (a) entries()
func _check_entries() -> bool:
	_state(0, 1, [])
	var ok := _x("a fresh save: the menu has nothing to build", _w().entries().is_empty(), {"ids": _ids(_w().entries())})
	await _open_menu()
	ok = _x("the empty menu says W.build_empty and has no cell", _texts().has(String(Data.word("build_empty"))) and _cells().is_empty(),
		{"texts": _texts()}) and ok
	main.hud.hide_card()
	_state(0, 1, ["shop_target"])
	ok = _x("after wave 1 of mission 1 the Target is open", _ids(_w().entries()) == ["target"]
		and String(_entry("target")["state"]) == "open" and (_entry("target")["price"] as Dictionary) == Data.build_price("target"),
		{"entries": _w().entries()}) and ok
	_state(1, 1, ["shop_open", "shop_target", "shop_bench"])
	var ids := _ids(_w().entries())
	ok = _x("after the first win: Target and Bow Shop open, Well, Market, Saddlery, Tailor and the Defence Workshop locked (H5: no Cottage; H6: the Workshop is last)",
		ids == ["target", "bench", "well", "stall", "saddlery", "tailor", "workshop"]
		and String(_entry("target")["state"]) == "open" and String(_entry("bench")["state"]) == "open"
		and ["well", "stall", "saddlery", "tailor", "workshop"].all(func(i): return String(_entry(i)["state"]) == "locked"),
		{"ids": ids}) and ok
	ok = _x("the locked ones say what they need, in today's words", String(_entry("well")["needs"]) == _needs_home(3)
		and not ids.has("cottage") and String(_entry("stall")["needs"]) == _needs_home(2)
		and String(_entry("tailor")["needs"]) == _needs_home(3)
		and String(_entry("saddlery")["needs"]) == _needs_home(2) + " · " + _needs_missions(8)
		and String(_entry("workshop")["needs"]) == _needs_missions(2)
		and String(_entry("target")["needs"]) == "",
		{"well": _entry("well").get("needs"), "saddlery": _entry("saddlery").get("needs")}) and ok
	_state(2, 1, ["shop_open", "shop_target", "shop_bench"])
	var w2 := _entry("workshop")
	ok = _x("after Mission 2 the Defence Workshop is open with its price (250 leaves, 10 timber) and its picture",
		String(w2.get("state", "")) == "open" and (w2["price"] as Dictionary) == Data.build_price("workshop")
		and int(Data.build_price("workshop").get("leaves", 0)) == 250 and int(Data.build_price("workshop").get("timber", 0)) == 10
		and String(w2.get("picture", "")) != "" and load(String(w2["picture"])) is Texture2D, {"entry": w2}) and ok
	_state(1, 1, ["shop_open", "shop_target", "shop_bench"])
	Save.camp_level = 2
	ok = _x("at Hearthtree 2 the Market is open (the Well and the Tailor not yet)",
		String(_entry("stall")["state"]) == "open"
		and String(_entry("well")["state"]) == "locked" and String(_entry("saddlery")["needs"]) == _needs_missions(8)) and ok
	Save.camp_level = 1
	_state(0, 1, ["shop_open"])
	ok = _x("a locked building shows only after the first Raid Mission is won", _w().entries().is_empty(), {"ids": _ids(_w().entries())}) and ok
	return ok


# ---------------------------------------------------------------- (b) the icon, the window, the cells
func _check_window() -> bool:
	var hud = main.hud
	_state(1, 1, ["shop_open", "shop_target", "shop_bench"])
	await t._wait(0.3)
	var icon: Button = hud._build_icon
	var ok := _x("the build icon shows", icon != null and icon.is_visible_in_tree())
	if icon == null:
		return false
	await t._tap_at(icon.get_global_rect().get_center())
	await t._until(func(): return hud.card_ring() == _w(), 1.5)
	ok = _x("a real tap on the build icon opens the build menu", hud.card_ring() == _w() and hud.card_title() == String(Data.word("build_title"))) and ok
	if hud.card_ring() != _w():
		_w().open()                                  # go on with the other checks
	# the reveal: right after opening the later cells are still fading in, and in the end every cell is whole
	_w().toggle()
	await t._wait(0.2)
	_w().open()
	await get_tree().process_frame
	await get_tree().process_frame
	var cells := _cells()
	ok = _x("the grid holds a cell per entry, each with its picture", cells.size() == _w().entries().size() and cells.size() == 7
		and cells.all(func(c): return (c as Control).find_children("*", "Panel", true, false).any(func(p): return p.has_meta("cell_pic"))),
		{"cells": cells.size()}) and ok
	var last: Control = cells.back() if not cells.is_empty() else null
	ok = _x("the pictures fade in one after another (the last is still faint right after opening)", last != null and last.modulate.a < 0.9,
		{"alpha": last.modulate.a if last != null else -1.0}) and ok
	await t._wait(1.0)
	ok = _x("a second later every cell is whole (alpha 1)", _cells().all(func(c): return absf((c as Control).modulate.a - 1.0) < 0.02)) and ok
	var locked_ok := true
	var open_ok := true
	for c: Control in _cells():
		var id := String(c.get_meta("cell"))
		var locked := String(_entry(id)["state"]) == "locked"
		locked_ok = locked_ok and (not locked or (bool(c.get_meta("locked")) and _buttons_in(c).is_empty()))
		open_ok = open_ok and (locked or (not bool(c.get_meta("locked")) and _button_in(c, String(Data.word("build"))) != null))
	ok = _x("a locked cell is greyed and has no Build button, an open one has its own Build button", locked_ok and open_ok) and ok
	await t._shot("buildmenu_grid")
	_lay._card_fits("build menu, 480x1040")
	get_window().size = Vector2i(540, 960)
	await t._wait(0.6)
	hud.hide_card()
	_w().open()
	await t._wait(1.0)
	_lay._card_fits("build menu, 540x960")
	get_window().size = Vector2i(480, 1040)
	await t._wait(0.6)
	hud.hide_card()
	_w().open()
	await t._wait(0.6)
	await t._tap_at(icon.get_global_rect().get_center())    # the second tap (on the dim, or the icon): the window closes
	await t._wait(0.4)
	ok = _x("a second tap on the build icon closes the menu", hud.card_ring() != _w()) and ok
	# the tap above lands on the dim (it covers the icon while a dialog is open), so the icon's own toggle() is checked
	# by itself too: it opens a closed menu and closes an open one
	_w().toggle()
	await t._wait(0.4)
	var opened: bool = hud.card_ring() == _w()
	_w().toggle()
	await t._wait(0.4)
	ok = _x("toggle() opens the closed menu and closes the open one", opened and hud.card_ring() != _w()) and ok
	return ok


# ---------------------------------------------------------------- (c) the detail view
func _check_detail() -> bool:
	var hud = main.hud
	_state(1, 2, ["shop_open", "shop_target", "shop_bench"])
	await _open_menu()
	var first := _cell("target")
	if not _x("the Target's cell is there", first != null):
		return false
	var pic: Control = null
	for p: Node in first.find_children("*", "Panel", true, false):
		if p.has_meta("cell_pic"):
			pic = p as Control
	await t._tap_at((pic if pic != null else first).get_global_rect().get_center())
	await t._wait(0.5)
	var box := _detail_box()
	var ok := _x("a real tap on a cell opens that building's detail view", box != null and String(box.get_meta("detail", "")) == "target")
	if box == null:
		_w()._open_detail("target")                  # go on with the rest
		await t._wait(0.5)
		box = _detail_box()
	var e := _entry("target")
	var texts := _texts()
	ok = _x("the detail shows the name, the desc and the price", texts.has(String(e["name"])) and texts.has(Data.building_desc("target"))
		and box != null and box.get_children().any(func(c): return c is HBoxContainer and _buttons_in(c).is_empty()),
		{"texts": texts}) and ok
	ok = _x("the detail has Back and Build, Build on (rich)", box != null and _button_in(box, String(Data.word("back"))) != null
		and _button_in(box, String(Data.word("build"))) != null and not _button_in(box, String(Data.word("build"))).disabled) and ok
	await t._shot("buildmenu_detail")
	_button_in(box, String(Data.word("back"))).pressed.emit()
	await t._wait(0.5)
	ok = _x("Back returns to the grid", _detail_box() == null and not _cells().is_empty()) and ok
	_w().open_at("bench")
	await t._wait(0.5)
	ok = _x("open_at(id) on the open menu shows that detail", _detail_box() != null and String(_detail_box().get_meta("detail")) == "bench") and ok
	_w().open_at("stall")
	await t._wait(0.5)
	var cd := _detail_box()
	var desc_ok := cd != null and _texts().has(Data.building_desc("stall")) and not Data.building_desc("stall").contains("{")
	ok = _x("the Market's desc has the mount look's name filled in", desc_ok, {"desc": Data.building_desc("stall")}) and ok
	_w().open_at("well")
	await t._wait(0.5)
	cd = _detail_box()
	ok = _x("a locked building's detail names what it needs and has no Build", cd != null and String(cd.get_meta("detail")) == "well"
		and _texts().has(_needs_home(3)) and _button_in(cd, String(Data.word("build"))) == null
		and _button_in(cd, String(Data.word("back"))) != null) and ok
	hud.hide_card()
	await t._wait(0.3)
	_w().open_at("well")                              # a closed menu opens at the detail (a goal's Show)
	await t._wait(0.5)
	ok = _x("open_at(id) on a closed menu opens it at that detail", hud.card_ring() == _w() and _detail_box() != null
		and String(_detail_box().get_meta("detail")) == "well") and ok
	hud.hide_card()
	await t._wait(0.2)
	await _open_menu()
	ok = _x("a new visit starts on the grid", _detail_box() == null and not _cells().is_empty()) and ok
	hud.hide_card()
	return ok


# ---------------------------------------------------------------- (d) building
func _paid(before: Dictionary, price: Dictionary) -> bool:
	for k in Data.CURRENCIES:
		if int(before.get(k, 0)) - Data.have(k) != int(price.get(k, 0)):
			return false
	return true


func _have_all() -> Dictionary:
	var out := {}
	for k in Data.CURRENCIES:
		out[k] = Data.have(k)
	return out


func _check_build() -> bool:
	var hud = main.hud
	_state(1, 1, ["shop_open", "shop_target", "shop_bench"])
	_built.clear()
	await _open_menu()
	var price: Dictionary = Data.build_price("target")
	var before := _have_all()
	var cell := _cell("target")
	var btn: Button = _button_in(cell, String(Data.word("build"))) if cell != null else null
	var ok := _x("the Target's cell has its own Build button", btn != null and not btn.disabled)
	if btn == null:
		return false
	btn.pressed.emit()
	await get_tree().process_frame
	ok = _x("Build pays exactly the price, sets level 1 and sends building_upgraded(target, 1)", _paid(before, price)
		and Data.station_level("target") == 1 and _built == [["target", 1]], {"built": _built}) and ok
	ok = _x("the window closes", hud.card_ring() != _w()) and ok
	ok = _x("the camera shot starts at the new building", main._show_t > 0.0
		and (main._show_at as Vector3).distance_to(main.world.station_pos("target")) < 0.1, {"t": main._show_t}) and ok
	await t._wait(0.15)
	var node: Node3D = main.stations.nodes.get("target")
	ok = _x("the Target rises out of the ground (still low a moment later)", node != null and node.scale.y < 0.5,
		{"scale": node.scale if node != null else Vector3.ZERO}) and ok
	await t._wait(0.45)
	await t._shot("buildmenu_rise")
	await t._until(func(): return main._show_t <= 0.0, 4.0)
	ok = _x("the camera shot ends within 4 s", main._show_t <= 0.0, {"t": main._show_t}) and ok
	await t._wait(1.0)
	node = main.stations.nodes.get("target")
	ok = _x("the Target's scale ends at its base", node != null and (node.scale - Vector3.ONE).length() < 0.03,
		{"scale": node.scale if node != null else Vector3.ZERO}) and ok
	ok = _x("a built building leaves the grid", not _ids(_w().entries()).has("target") and _ids(_w().entries()).has("bench")) and ok
	await _open_menu()
	ok = _x("and its cell is gone from the open menu", _cell("target") == null and _cell("bench") != null) and ok
	hud.hide_card()
	# the second build: from the detail view, and a wave that starts at once ends the camera shot at once
	_built.clear()
	price = Data.build_price("bench")
	before = _have_all()
	_w().open_at("bench")
	await t._wait(0.5)
	var b2: Button = _button_in(_detail_box(), String(Data.word("build"))) if _detail_box() != null else null
	ok = _x("the detail's Build is on", b2 != null and not b2.disabled) and ok
	if b2 != null:
		b2.pressed.emit()
		await get_tree().process_frame
		ok = _x("the detail's Build pays exactly the price and builds the Bow Shop", _paid(before, price)
			and Data.station_level("bench") == 1 and _built == [["bench", 1]] and hud.card_ring() != _w() and main._show_t > 0.0,
			{"built": _built}) and ok
		main.fight.active = true
		main.fight.in_wave = true
		await t._wait(0.2)
		ok = _x("a wave ends the camera shot at once", main._show_t <= 0.0, {"t": main._show_t}) and ok
		main.fight.active = false
		main.fight.in_wave = false
	await t._wait(0.5)
	return ok


# ---------------------------------------------------------------- (e) the dot, a wave, the ruins
func _check_dot_wave_ruin() -> bool:
	var hud = main.hud
	_state(1, 1, ["shop_open", "shop_target", "shop_bench"], 0)
	hud.refresh_build()
	await t._wait(0.4)
	var ok := _x("with no leaves pulse() is false and the build icon has no dot", not _w().pulse() and not _dot_shown(),
		{"dot": _dot() != null})
	Save.leaves = 5000
	hud.refresh_build()
	await t._wait(0.4)
	ok = _x("with leaves for an open building pulse() is true", _w().pulse()) and ok
	ok = _x("and the build icon shows its dot", _dot() != null and _dot_shown(), {"dot": _dot() != null}) and ok
	await _open_menu()
	# the wave is faked with no frame passing while it is on (a faked wave with nothing in it is cleared on the next
	# physics frame, fight.gd _physics_process), so the blank is read straight after the redraw: the old cells are on
	# their way out (_going)
	main.fight.active = true
	main.fight.in_wave = true
	hud.refresh_card()
	var blank_sub := String(hud._card_sub.text) if hud._card_sub != null else ""
	ok = _x("a wave blanks the menu: no cell, no button", _cells().is_empty() and _buttons_in(hud._card).size() <= 1
		and hud.card_ring() == _w() and blank_sub.begins_with("A wave is on"), {"cells": _cells().size(),
		"buttons": _buttons_in(hud._card).map(func(b): return String(b.get_meta("label", b.name))), "sub": blank_sub}) and ok
	main.fight.active = false
	main.fight.in_wave = false
	hud.refresh_card()
	await t._wait(0.3)
	ok = _x("and the menu is back after it", not _cells().is_empty()) and ok
	hud.hide_card()
	Save.ruined = ["home"]
	var before := _have_all()
	_w()._build("target")
	ok = _x("in ruins nothing builds", _paid(before, {}) and Data.station_level("target") == 0) and ok
	ok = _x("in ruins pulse() is false", not _w().pulse()) and ok
	await _open_menu()
	ok = _x("the Hearthtree in ruins: the menu says W.build_ruined and shows no cell", _cells().is_empty()
		and _texts().has(String(Data.word("build_ruined")) % Data.camp_name()), {"texts": _texts()}) and ok
	await t._tap_close()
	await t._wait(0.2)
	Save.ruined = []
	return ok
