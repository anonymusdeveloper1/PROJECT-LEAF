extends Node
## Phase G2: the shop-style cards (`-- --autotest --fresh --cards`), run from autotest.gd. Best run at 480x1040 with
## --safe-top=73 --safe-bottom=42 (the S24's shape and bars); the test also sets the window to 480x1040 itself and
## tries 540x960 once. Each check logs "EXPECT PASS <what>" or "EXPECT FAIL <what>" through autotest.gd's _expect.
## Screenshots: cards_*.png.
##   (a) a test card built here (a goal line, a shelf heading, 5 item tiles: affordable, unaffordable, disabled, with a
##       badge, free; and a plain row under them): 2 tiles a row, every tile the same size, the lone last tile on the
##       left, the heading and the plain rows still there, the dialog fits the phone, its X closes it; the same at
##       540x960 (a tap outside closes it) and Android's back button closes it
##   (b) the tiles' buttons: an affordable one runs its action and the card refreshes; an unaffordable or a disabled one
##       is grey and does nothing; a free one runs; the plain row's button still works
##   (c) the real cards opened by a tap, one by one, with screenshots (a veteran save with them all built): the
##       Hearthtree, the Training Target, the Bow Bench, the Market and the Wishing Well: each fits the phone, shows
##       tiles, its tiles the same size and 2 a row, their buttons a thumb wide
##   (d) every icon id gives a picture (made once; every SVG loaded), an unknown id a plain round one, a texture is used
##       as it is; a sheet of them all (cards_icons.png)

var t                     # autotest.gd (its helpers: _wait, _shot, _expect, _until, _veteran, _at_ring, _press, _tap_close...)
var main
var _lay                  # autotest_layout.gd, for its _card_fits (the dialog fits the phone and its safe area)
var _hits := {}           # which test tile's action ran, how often
var _ring                 # the test card's stand-in marker (kept while its card is open)

const UiIcons := preload("res://scripts/ui_icons.gd")
const ICON_IDS := ["bow", "target", "damage", "draw", "range", "heart", "speed", "magnet", "timber", "leaves", "berries",
	"herbs", "honey", "fish", "goldfish", "shard", "amber", "glowstone", "heartwood", "tower", "barricade", "spikes", "well",
	"home", "pet", "mount", "garden", "pot", "fishing", "grow", "repair", "settings"]


## A stand-in for a marker: all the dialog needs from one is its card builder.
class FakeRing extends RefCounted:
	var builder: Callable


func run() -> bool:
	main.player.invincible = true
	_lay = load("res://scripts/autotest_layout.gd").new()
	_lay.t = t
	_lay.main = main
	add_child(_lay)
	get_window().size = Vector2i(480, 1040)
	await t._wait(0.6)
	await _test_card()
	await _buttons()
	await _real_cards()
	await _icons()
	return true


func _x(what: String, ok: bool, extra := {}) -> bool:
	return t._expect(what, ok, extra)


func _view() -> Vector2:
	return main.hud.get_viewport().get_visible_rect().size


# ---------------------------------------------------------------- the test card
func _test_spec() -> Dictionary:
	var hit := func(k: String) -> void:
		_hits[k] = int(_hits.get(k, 0)) + 1
	return {"title": "Test shop", "sub": "Phase G2 · tiles and plain rows", "anchor": Vector3.ZERO, "rows": [
		{"text": "A goal, met", "note": "", "small": true, "done": true, "cost": {}, "label": "", "enabled": false, "action": Callable()},
		{"kind": "section", "text": "Upgrades"},
		{"kind": "item", "icon": "damage", "title": "Sharp arrows", "text": "Hits harder, every shot",
			"stats": [["Damage", 0.4], ["Speed", 0.7]], "cost": {"leaves": 40}, "label": "Upgrade", "enabled": true,
			"action": hit.bind("afford")},
		{"kind": "item", "icon": main.hud.icon("bow"), "title": "A very long bow name that cannot fit on one line",
			"text": "More than you have, and a line long enough to need two lines or even more than two of them",
			"stats": [["Damage", 0.9]], "cost": {"leaves": 5000, "timber": 5}, "label": "Buy", "enabled": true,
			"action": hit.bind("dear")},
		{"kind": "item", "icon": "lantern", "title": "Lantern", "text": "Not yet", "cost": {"leaves": 10}, "label": "Build",
			"enabled": false, "action": hit.bind("off")},
		{"kind": "item", "icon": "target", "title": "Training", "text": "Level up the target", "badge": "Level 3/5",
			"stats": [["Range", 0.6, "6/10"]], "cost": {"leaves": 20, "timber": 2}, "label": "Upgrade", "enabled": true,
			"action": hit.bind("badge")},
		{"kind": "item", "icon": "mount", "title": "Ride Thistle", "text": "Free to ride", "cost": {}, "label": "Ride",
			"enabled": true, "action": hit.bind("free")},
		{"text": "A plain row", "note": "Drawn as before, under the grid", "cost": {"leaves": 5}, "label": "Old buy",
			"enabled": true, "action": hit.bind("plain")},
	]}


## Opens the test card (as a tap on a marker would) and lets it pop in and lay out.
func _open_test() -> void:
	main.hud.hide_card()
	await t._wait(0.3)
	Save.leaves = 500
	Save.timber = 50
	var r := FakeRing.new()
	r.builder = _test_spec
	_ring = r
	main.hud.show_card(r)
	await t._wait(0.6)


func _grids() -> Array:
	var out: Array = []
	var list = main.hud._card_list
	if main.hud._card == null or list == null or not is_instance_valid(list):
		return out
	for c in list.get_children():
		if c is GridContainer and c.has_meta("grid") and not c.is_queued_for_deletion():
			out.append(c)
	return out


func _tiles(g: Node) -> Array:
	return g.get_children().filter(func(c): return c.has_meta("tile"))


func _labels(n: Node) -> Array:
	return n.find_children("*", "Label", true, false)


func _texts(n: Node) -> Array:
	return _labels(n).map(func(l): return String(l.text))


func _buttons_in(n: Node) -> Array:
	return n.find_children("*", "Button", true, false)


func _button(label: String) -> Button:
	for b in main.hud.card_buttons():
		if String(b.get_meta("label", "")) == label:
			return b
	return null


## The tiles of the open card: [all the same size, 2 a row, buttons a thumb wide, inside the dialog] -> the problems.
func _tile_problems() -> Array:
	var bad: Array = []
	var cr: Rect2 = main.hud._card.get_global_rect() if main.hud._card != null else Rect2()
	for g in _grids():
		var tl := _tiles(g)
		if tl.is_empty():
			continue
		var want: int = 2 if _view().x < 800.0 else int(main.hud._grid_cols())
		if (g as GridContainer).columns != want:
			bad.append("%d a row (want %d)" % [(g as GridContainer).columns, want])
		for x in tl:
			if ((x as Control).size - (tl[0] as Control).size).length() > 0.5:
				bad.append("%s is %s, not %s" % [x.get_meta("title", "?"), (x as Control).size, (tl[0] as Control).size])
			var r: Rect2 = (x as Control).get_global_rect()
			if r.position.x < cr.position.x - 0.5 or r.end.x > cr.end.x + 0.5:
				bad.append("%s sticks out of the dialog" % x.get_meta("title", "?"))
			for b in _buttons_in(x):
				if (b as Control).size.y < 44.0 or (b as Control).size.x < 44.0:
					bad.append("%s's button is small %s" % [x.get_meta("title", "?"), (b as Control).size])
		if tl.size() >= 2 and int(g.columns) >= 2 and absf((tl[0] as Control).position.y - (tl[1] as Control).position.y) > 0.5:
			bad.append("the first two tiles are not side by side")
	return bad


# ---------------------------------------------------------------- (a) the test card at 480x1040 and 540x960
func _test_card() -> void:
	var hud = main.hud
	_hits.clear()
	await _open_test()
	var v := _view()
	_x("the test card opens as a dialog", hud.card_title() == "Test shop", {"title": hud.card_title(), "view": v})
	var grids := _grids()
	_x("the 5 item rows make one grid", grids.size() == 1 and _tiles(grids[0]).size() == 5, {"grids": grids.size()})
	if grids.size() != 1 or _tiles(grids[0]).size() != 5:
		return
	var g: GridContainer = grids[0]
	var tl := _tiles(g)
	var p0: Vector2 = tl[0].position
	_x("2 tiles a row at %dx%d" % [int(v.x), int(v.y)], g.columns == 2 and absf(tl[1].position.y - p0.y) < 0.5 and tl[1].position.x > p0.x + 10.0
		and tl[2].position.y > p0.y + 10.0 and absf(tl[2].position.x - p0.x) < 0.5, {"columns": g.columns, "pos": tl.map(func(c): return c.position)})
	var same := true
	for x in tl:
		if ((x as Control).size - (tl[0] as Control).size).length() > 0.5:
			same = false
	_x("every tile the same size", same, {"sizes": tl.map(func(c): return c.size)})
	_x("the lone last tile sits on the left, as big as the others", absf(tl[4].position.x - p0.x) < 0.5 and tl[4].position.y > tl[2].position.y + 10.0
		and absf(tl[4].size.x - tl[0].size.x) < 0.5)
	_x("two tiles fill the dialog's width", tl[1].get_global_rect().end.x > hud._card.get_global_rect().end.x - 60.0
		and tl[0].get_global_rect().position.x < hud._card.get_global_rect().position.x + 60.0)
	# the heading and the plain rows, in their places
	var kids: Array = hud._card_list.get_children()
	var i_goal := -1
	var i_sec := -1
	var i_grid := kids.find(g)
	var i_plain := -1
	for i in kids.size():
		var c = kids[i]
		if c is HBoxContainer and _texts(c).has("A goal, met"):
			i_goal = i
		elif c.has_meta("section"):
			i_sec = i
		elif c is HBoxContainer and _texts(c).has("A plain row"):
			i_plain = i
	_x("a shelf heading over the grid", i_sec >= 0 and i_sec < i_grid and _texts(kids[i_sec]).has("UPGRADES"))
	_x("the plain rows are still there, above and below the grid", i_goal >= 0 and i_goal < i_sec and i_plain > i_grid
		and _button("Old buy") != null and _texts(kids[i_plain]).has("Drawn as before, under the grid"),
		{"goal": i_goal, "section": i_sec, "grid": i_grid, "plain": i_plain})
	# what each tile shows
	var t0: Node = tl[0]
	_x("a tile: its icon, name, line, stat bars, price and one button", _texts(t0).has("Sharp arrows") and _texts(t0).has("Hits harder, every shot")
		and _texts(t0).has("Damage") and _texts(t0).has("Speed") and t0.find_children("*", "ProgressBar", true, false).size() == 2
		and _texts(t0).has("40") and _buttons_in(t0).size() == 1 and t0.find_children("*", "TextureRect", true, false).size() >= 2,
		{"texts": _texts(t0)})
	var t1: Node = tl[1]
	var pics: Array = t1.find_children("*", "TextureRect", true, false)
	_x("a picture given as a texture is used as it is", pics.size() > 0 and (pics[0] as TextureRect).texture == hud.icon("bow"))
	var names: Array = _labels(t1).filter(func(l): return String(l.text).begins_with("A very long"))
	_x("a long name shrinks to fit one line (then ...)", names.size() == 1 and (names[0] as Label).get_theme_font_size("font_size") < 24
		and (names[0] as Label).size.y < 40.0, {"size": (names[0] as Label).get_theme_font_size("font_size") if names.size() == 1 else -1})
	var short: Array = _labels(t1).filter(func(l): return l.has_meta("afford") and not bool(l.get_meta("afford")))
	var enough: Array = _labels(t1).filter(func(l): return l.has_meta("afford") and bool(l.get_meta("afford")))
	_x("the price the cat can't pay is red, the one it can is not", short.size() == 1 and String(short[0].text) == "5000" and enough.size() == 1
		and (short[0] as Label).get_theme_color("font_color").r > 0.7 and (short[0] as Label).get_theme_color("font_color").g < 0.4)
	_x("an unknown icon id: a round icon with the name's first letter", _texts(tl[2]).has("L"))
	_x("the badge shows as a pill in the tile's top corner", _texts(tl[3]).has("Level 3/5") and _texts(tl[3]).has("6/10"))
	var badges: Array = _labels(tl[3]).filter(func(l): return String(l.text) == "Level 3/5")
	var br: Rect2 = (badges[0] as Label).get_global_rect() if badges.size() == 1 else Rect2()
	var tr3: Rect2 = (tl[3] as Control).get_global_rect()
	_x("... in the top right corner", badges.size() == 1 and br.end.x > tr3.end.x - 30.0 and br.position.y < tr3.position.y + 30.0,
		{"badge": br, "tile": tr3})
	_x("a free tile: its button and no price", _buttons_in(tl[4]).size() == 1 and not _labels(tl[4]).any(func(l): return l.has_meta("afford")))
	var probs := _tile_problems()
	_x("the test card's tiles: the same size, 2 a row, buttons a thumb wide, inside the dialog", probs.is_empty(), {"bad": probs.slice(0, 5)})
	_lay._card_fits("test card")
	await t._shot("cards_test")
	await t._tap_close()
	_x("its X closes it", hud._card == null)
	# the same at 540x960
	get_window().size = Vector2i(540, 960)
	await t._wait(0.6)
	await _open_test()
	var probs2 := _tile_problems()
	_x("at %dx%d: 2 tiles a row, the same size" % [int(_view().x), int(_view().y)], _grids().size() == 1 and probs2.is_empty(), {"bad": probs2.slice(0, 5)})
	_lay._card_fits("test card 540x960")
	await t._shot("cards_test_540")
	await t._tap_outside()
	_x("a tap outside closes it", hud._card == null)
	get_window().size = Vector2i(480, 1040)
	await t._wait(0.6)
	await _open_test()
	get_tree().root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await t._wait(0.2)
	_x("Android's back button closes it", hud._card == null)


# ---------------------------------------------------------------- (b) the tiles' buttons
func _buttons() -> void:
	var hud = main.hud
	await _open_test()
	_hits.clear()
	var ok: bool = t._press("Upgrade")                 # the first one: the affordable tile
	await t._wait(0.3)
	_x("an affordable tile's button runs its action", ok and int(_hits.get("afford", 0)) == 1 and not _hits.has("badge"), {"hits": _hits})
	_x("the card refreshes after it (still open, its tiles made again)", hud.card_title() == "Test shop" and _grids().size() == 1
		and _tiles(_grids()[0]).size() == 5)
	var dear := _button("Buy")
	_x("an unaffordable tile's button is grey and off", dear != null and dear.disabled)
	if dear != null:
		dear.pressed.emit()
	var off := _button("Build")
	_x("a disabled tile's button is grey and off", off != null and off.disabled)
	if off != null:
		off.pressed.emit()
	await t._wait(0.2)
	_x("... and neither does anything", not _hits.has("dear") and not _hits.has("off"), {"hits": _hits})
	var free_ok: bool = t._press("Ride")
	await t._wait(0.2)
	_x("a free tile's button works", free_ok and int(_hits.get("free", 0)) == 1, {"hits": _hits})
	var plain_ok: bool = t._press("Old buy")
	await t._wait(0.2)
	_x("the plain row's button still works", plain_ok and int(_hits.get("plain", 0)) == 1, {"hits": _hits})
	_x("the second Upgrade (the badge tile) works too", t._press("Upgrade", 1) and int(_hits.get("badge", 0)) == 1, {"hits": _hits})
	await t._wait(0.2)
	await t._tap_close()
	_ring = null


# ---------------------------------------------------------------- (c) the real cards
func _real_cards() -> void:
	var hud = main.hud
	hud.hide_card()
	t._veteran(6)
	for id in ["target", "bench", "well", "stall", "cottage", "garden"]:
		Save.stations[id] = maxi(int(Save.stations.get(id, 0)), 1)
	Save.leaves = 3000
	Save.timber = 60
	main.on_camp_grown()
	main.stations.refresh("all")
	await t._wait(1.2)
	var st = main.stations
	for pair in [["shop", "hearthtree"], ["target", "target"], ["bench", "bench"], ["stall", "market"], ["well", "well"]]:
		var ring = st.rings.get(pair[0])
		if ring == null or not is_instance_valid(ring) or not ring.is_visible_in_tree():
			_x("the %s's marker is there" % pair[1], false)
			continue
		await t._at_ring(ring)
		await t._wait(0.6)
		if not _x("the %s card opens" % pair[1], hud.card_ring() == ring, {"title": hud.card_title()}):
			continue
		await t._shot("cards_" + pair[1])
		_lay._card_fits(pair[1])
		var n := 0
		for g in _grids():
			n += _tiles(g).size()
		_x("the %s card shows its wares as tiles" % pair[1], n > 0, {"title": hud.card_title(), "tiles": n})
		var probs := _tile_problems()
		_x("the %s card's tiles: the same size, 2 a row, buttons a thumb wide" % pair[1], probs.is_empty(), {"bad": probs.slice(0, 5)})
		var sc: ScrollContainer = hud._card_scroll
		if sc != null and hud._card_list != null and hud._card_list.size.y > sc.size.y + 40.0:
			sc.scroll_vertical = int(sc.size.y * 0.85)    # a long card: one more shot further down
			await t._wait(0.3)
			await t._shot("cards_%s_more" % pair[1])
			if hud._card_list.size.y > sc.size.y * 1.85 + 40.0:
				sc.scroll_vertical = int(sc.size.y * 1.7)
				await t._wait(0.3)
				await t._shot("cards_%s_more2" % pair[1])
		await t._tap_close()
		await t._wait(0.2)


# ---------------------------------------------------------------- (d) the icons
func _icons() -> void:
	var hud = main.hud
	hud.hide_card()
	var missing: Array = []
	for id in ICON_IDS:
		var tx = hud.icon(id)
		if not (tx is Texture2D) or (tx as Texture2D).get_width() < 32 or not hud._icon_known(id) or hud.icon(id) != tx:
			missing.append(id)
	_x("every icon id gives a picture, made once (%d ids)" % ICON_IDS.size(), missing.is_empty(), {"missing": missing})
	_x("every icon's SVG loaded", UiIcons.failed.is_empty(), {"failed": UiIcons.failed})
	var u = hud.icon("no_such_icon")
	_x("an unknown id gives a plain round icon", u is Texture2D and not hud._icon_known("no_such_icon") and u != hud.icon("bow"))
	_x("a texture given as an icon is used as it is", hud.icon(hud.icon("heart")) == hud.icon("heart"))
	# a sheet of them all, in the tiles' soft squares, for the eye
	var sheet := PanelContainer.new()
	sheet.add_theme_stylebox_override("panel", hud._ui_style("tile"))
	var g := GridContainer.new()
	g.columns = 6
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 4)
	sheet.add_child(g)
	for id in ICON_IDS + ["no_such_icon"]:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 0)
		var sq := PanelContainer.new()
		sq.add_theme_stylebox_override("panel", hud._ui_style("pic"))
		var pic := TextureRect.new()
		pic.texture = hud.icon(id)
		pic.custom_minimum_size = Vector2(88, 88)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sq.add_child(pic)
		cell.add_child(sq)
		var l := Label.new()
		l.text = id
		l.add_theme_font_size_override("font_size", 15)
		l.add_theme_color_override("font_color", Color(0.3, 0.2, 0.1))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(l)
		g.add_child(cell)
	hud.add_child(sheet)
	sheet.position = Vector2(20, hud._safe.x + 70.0)
	await t._wait(0.4)
	await t._shot("cards_icons")
	sheet.queue_free()
	await t._wait(0.1)
