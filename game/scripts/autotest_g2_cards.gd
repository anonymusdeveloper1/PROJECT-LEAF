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
##       Hearthtree, the Training Target, the Bow Shop, the Market and the Wishing Well; each fits the phone. H4 (26 Nov
##       2026, the windows' new shape): H5 (27 Nov): the Market shows its wares as a grid of picture cells (the same size, 2 a row, no button), Buys pays a neutral amount, four round icon tabs sit at its bottom and it has no footer; the old tiles remain in the synthetic card; their
##       buttons a thumb wide; the Hearthtree's tab shows no tiles, its Cat and Defences tabs, the Target and the Bow
##       Shop show list rows, as wide as the list, their buttons a thumb wide; the Well is only its footer (no rows);
##       each footer's Upgrade sits inside the dialog and the screen, out of the list that scrolls. Then the confirm
##       window (from the Well's Upgrade) and the build menu (a real tap on the build icon) fit the phone too
##   (d) every icon id gives a picture (made once; every SVG loaded), an unknown id a plain round one, a texture is used
##       as it is; a sheet of them all (cards_icons.png)
##   (e) H4, the window kit (run after (b)): in its own file, autotest_g2_cards_kit.gd, which calls the helpers here
##       (_x, _grids, _texts, _list_rows, _on_card_and_screen and FakeRing). Moved out on 26 Nov 2026 (house rule 1: one
##       job a file, under about 800 lines); its checks did not change. Screenshots: cards_kit_*.png.

var t                     # autotest.gd (its helpers: _wait, _shot, _expect, _until, _veteran, _at_ring, _press, _tap_close...)
var main
var _lay                  # autotest_layout.gd, for its _card_fits (the dialog fits the phone and its safe area)
var _hits := {}           # which test tile's action ran, how often
var _ring                 # the test card's stand-in marker (kept while its card is open)

const UiIcons := preload("res://scripts/ui_icons.gd")
const ICON_IDS := ["bow", "target", "damage", "draw", "range", "heart", "speed", "magnet", "timber", "leaves", "berries",
	"herbs", "honey", "fish", "goldfish", "shard", "amber", "tower", "barricade", "spikes", "well",
	"home", "pet", "mount", "garden", "pot", "fishing", "grow", "repair", "settings",
	# H3 (the owner's Q6 a): the stand-ins for the new ingredients and the recipes (a bottle per potion in its colour)
	"peppers", "roots", "health_potion", "mount_potion", "cooked_fish", "damage_potion", "speed_potion"]


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
	var kit = load("res://scripts/autotest_g2_cards_kit.gd").new()   # (e): the H4 window kit's checks
	kit.t = t
	kit.main = main
	kit.g = self
	kit._lay = _lay
	add_child(kit)
	await kit.run()
	kit.queue_free()
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


# ---------------------------------------------------------------- H4: list rows and the footer (the kit file and (c) use these)
func _list_rows() -> Array:
	var out: Array = []
	var list = main.hud._card_list
	if main.hud._card == null or list == null or not is_instance_valid(list):
		return out
	for c in list.get_children():
		if c.has_meta("list_row") and not c.is_queued_for_deletion():
			out.append(c)
	return out


## A control shows inside the dialog and inside the screen between the phone's bars.
func _on_card_and_screen(c: Control) -> bool:
	var hud = main.hud
	var v := _view()
	var r := c.get_global_rect()
	var top: float = hud._safe.x
	var bottom: float = v.y - hud._safe.y
	var screen := Rect2(0.0, top, v.x, bottom - top)
	return c.is_visible_in_tree() and hud._card.get_global_rect().grow(0.5).encloses(r) and screen.grow(0.5).encloses(r)


## (c) The list rows of the open card: [as wide as the list, inside the dialog sideways, buttons a thumb wide (44 px, as
## the tiles' check)] -> the problems.
func _list_problems() -> Array:
	var bad: Array = []
	var hud = main.hud
	if hud._card == null or hud._card_list == null:
		return ["no card is open"]
	var cr: Rect2 = hud._card.get_global_rect()
	var lw: float = hud._card_list.size.x
	for r in _list_rows():
		var rc := r as Control
		var nm := String(r.get_meta("title", "?"))
		if absf(rc.size.x - lw) > 1.0:
			bad.append("%s is %.0f wide, the list %.0f" % [nm, rc.size.x, lw])
		var gr := rc.get_global_rect()
		if gr.position.x < cr.position.x - 0.5 or gr.end.x > cr.end.x + 0.5:
			bad.append("%s sticks out of the dialog" % nm)
		for b in _buttons_in(r):
			if (b as Control).size.y < 44.0 or (b as Control).size.x < 44.0:
				bad.append("%s's button is small %s" % [nm, (b as Control).size])
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
## H4: each real card's marker, its name in the checks and its shape: "grid" (H5: the Market's picture cells, bottom icon
## tabs and no footer), "plain" (the
## Hearthtree's own tab: its goals and the Graphics row, no tiles; its Cat and Defences tabs are "list"), "list" (list
## rows: the Training Target, the Bow Shop) or "footer" (the Wishing Well: no rows, only its pinned Upgrade).
const REAL := [["shop", "hearthtree", "plain"], ["target", "target", "list"], ["bench", "bench", "list"],
	["stall", "market", "grid"], ["well", "well", "footer"]]


func _real_cards() -> void:
	var hud = main.hud
	hud.hide_card()
	t._veteran(6)
	for id in ["target", "bench", "well", "stall", "garden"]:
		Save.stations[id] = maxi(int(Save.stations.get(id, 0)), 1)
	Save.leaves = 3000
	Save.timber = 60
	main.on_camp_grown()
	main.stations.refresh("all")
	await t._wait(1.2)
	var st = main.stations
	for pair in REAL:
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
		_card_shape(pair[1], pair[2])
		if pair[2] == "grid":
			await _market_grid(pair[1])                  # H5: Sells, the Buys tab's neutral payout, the bottom icon tabs, no footer
		else:
			_footer_inside(pair[1])
		var sc: ScrollContainer = hud._card_scroll
		if sc != null and hud._card_list != null and hud._card_list.size.y > sc.size.y + 40.0:
			sc.scroll_vertical = int(sc.size.y * 0.85)    # a long card: one more shot further down
			await t._wait(0.3)
			await t._shot("cards_%s_more" % pair[1])
			if hud._card_list.size.y > sc.size.y * 1.85 + 40.0:
				sc.scroll_vertical = int(sc.size.y * 1.7)
				await t._wait(0.3)
				await t._shot("cards_%s_more2" % pair[1])
		if pair[1] == "hearthtree":
			await _hearthtree_tabs()
		elif pair[1] == "well":
			await _confirm_from("well")
		await t._tap_close()                             # the confirm's X closes everything too (Q3 (a))
		await t._wait(0.2)
	await _build_menu()


## The open card's shape (see REAL). Each check fails on the old shape: tiles where a list should be, rows on the Well.
func _card_shape(what: String, shape: String) -> void:
	var hud = main.hud
	var tiles := 0
	for g in _grids():
		tiles += _tiles(g).size()
	var rows := _list_rows()
	match shape:
		"tiles":
			_x("the %s card shows its wares as tiles" % what, tiles > 0, {"title": hud.card_title(), "tiles": tiles})
			var probs := _tile_problems()
			_x("the %s card's tiles: the same size, 2 a row, buttons a thumb wide" % what, probs.is_empty(), {"bad": probs.slice(0, 5)})
		"grid":
			var cells := _cells()
			_x("the %s card shows its wares as picture cells (a grid)" % what, cells.size() > 0, {"title": hud.card_title(), "cells": cells.size()})
			var cp := _cell_problems()
			_x("the %s card's cells: the same size, inside the dialog, no buttons" % what, cp.is_empty(), {"bad": cp.slice(0, 5)})
		"plain":
			_x("the %s card shows its rows and no tiles" % what, tiles == 0 and hud._card_list.get_child_count() > 0,
				{"tiles": tiles, "children": hud._card_list.get_child_count()})
		"list":
			_x("the %s card shows list rows and no tiles" % what, rows.size() > 0 and tiles == 0,
				{"rows": rows.size(), "tiles": tiles})
		"footer":
			_x("the %s card is only its footer: no rows, no tiles" % what, rows.is_empty() and tiles == 0
				and not hud._card_body.visible, {"rows": rows.size(), "tiles": tiles, "body": hud._card_body.visible})
	if not rows.is_empty():
		var lp := _list_problems()
		_x("the %s card's list rows: as wide as the list, buttons a thumb wide" % what, lp.is_empty(),
			{"rows": rows.size(), "bad": lp.slice(0, 5)})


## H5: the picture cells of the open card's grids (ui/kit/icon_grid.gd marks each with "cell").
func _cells() -> Array:
	var out: Array = []
	for g in _grids():
		out.append_array(g.get_children().filter(func(c): return c.has_meta("cell") and not c.is_queued_for_deletion()))
	return out


## H5: the cells of the open card: [all the same size, at most 3 a row, inside the dialog, a thumb big, no button in a cell]
## -> the problems. A cell is tapped as a whole (its popup or detail view).
func _cell_problems() -> Array:
	var bad: Array = []
	var cr: Rect2 = main.hud._card.get_global_rect() if main.hud._card != null else Rect2()
	for g in _grids():
		var cl: Array = g.get_children().filter(func(c): return c.has_meta("cell") and not c.is_queued_for_deletion())
		if cl.is_empty():
			continue
		if _view().x < 800.0 and (g as GridContainer).columns > 3:
			bad.append("%d a row" % (g as GridContainer).columns)
		for x in cl:
			if ((x as Control).size - (cl[0] as Control).size).length() > 1.5:   # a column is a whole pixel wider when the width does not divide
				bad.append("%s is %s, not %s" % [x.get_meta("title", "?"), (x as Control).size, (cl[0] as Control).size])
			var r: Rect2 = (x as Control).get_global_rect()
			if r.position.x < cr.position.x - 0.5 or r.end.x > cr.end.x + 0.5:
				bad.append("%s sticks out of the dialog" % x.get_meta("title", "?"))
			if r.size.x < 44.0 or r.size.y < 44.0:
				bad.append("%s is too small to tap %s" % [x.get_meta("title", "?"), r.size])
			if not _buttons_in(x).is_empty():
				bad.append("%s holds a button" % x.get_meta("title", "?"))
		if cl.size() >= 2 and int(g.columns) >= 2 and absf((cl[0] as Control).position.y - (cl[1] as Control).position.y) > 0.5:
			bad.append("the first two cells are not side by side")
	return bad


## H5: the Market's own shape. Sells' prices are checked amounts; Buys pays a neutral amount (never red, never a check);
## four round icon tabs sit under the grid, each with its word as its name and its tab id; and no footer.
func _market_grid(what: String) -> void:
	var hud = main.hud
	var win = hud.windows["stall"]
	var tabs: Array = _tab_buttons_of_card()
	var want: Array = win.tab_ids()
	var ids: Array = tabs.map(func(b): return String(b.get_meta("tab_id", "")))
	_x("the %s has four bottom tabs: Sells, Buys, Mounts, Pets" % what, tabs.size() == 4 and ids == want, {"tabs": ids, "want": want})
	var icon_only := not tabs.is_empty()
	var named := not tabs.is_empty()
	var thumb := not tabs.is_empty()
	for b in tabs:
		icon_only = icon_only and String((b as Button).text) == ""
		named = named and String(b.get_meta("tab_name", "")) != ""
		thumb = thumb and (b as Control).size.y >= 44.0 and (b as Control).size.x >= 44.0
	_x("the %s's tabs are icons only, each with its word as its name, a thumb big" % what, icon_only and named and thumb)
	var sc: ScrollContainer = hud._card_scroll
	var under: bool = hud._card_tabs != null and sc != null and hud._card_tabs.get_global_rect().position.y >= sc.get_global_rect().end.y - 1.0
	_x("the %s's tabs sit under the grid, inside the dialog and the screen" % what, under and _on_card_and_screen(hud._card_tabs), {"tabs": hud._card_tabs.get_global_rect()})
	var ft = hud.p_card.foot
	var has_foot: bool = ft != null and is_instance_valid(ft) and (ft as Control).visible
	_x("the %s has no footer and no Upgrade" % what, not has_foot and hud.p_card.footer_button(Data.word("upgrade")) == null and not win.spec().has("footer"),
		{"foot": has_foot})
	# Sells' cells carry the price as shop_tiles' checked price line (red when short, no amount_line meta); a neutral
	# amount_line is a payout and belongs to Buys only.
	var price_cells := 0
	var neutral_on_sells := false
	for cell in _cells():
		var has_price := false
		for l in (cell as Node).find_children("*", "HBoxContainer", true, false):
			if l.has_meta("amount_line"):
				if bool(l.get_meta("neutral", false)):
					neutral_on_sells = true
			elif not (l as Node).find_children("*", "Label", true, false).is_empty():
				has_price = true
		if has_price:
			price_cells += 1
	_x("Sells shows its prices as checked price lines, no neutral payout", price_cells > 0 and not neutral_on_sells, {"price cells": price_cells, "neutral": neutral_on_sells})
	win.select("buys")
	await t._wait(0.4)
	await t._shot("cards_market_buys")
	_lay._card_fits("market, Buys tab")
	var lines: Array = []
	var red := false
	for l in hud._card.find_children("*", "HBoxContainer", true, false):
		if l.has_meta("amount_line"):
			lines.append(l)
			for lb in (l as Node).find_children("*", "Label", true, false):
				if not bool(lb.get_meta("afford", true)):
					red = true
	var neutral: bool = not lines.is_empty() and lines.all(func(l): return bool(l.get_meta("neutral", false)))
	_x("Buys pays a neutral amount: no check, never red", neutral and not red, {"lines": lines.size(), "red": red})
	var cp := _cell_problems()
	_x("Buys' cells: the same size, inside the dialog, no buttons", _cells().size() > 0 and cp.is_empty(), {"cells": _cells().size(), "bad": cp.slice(0, 5)})
	win.select("sells")
	await t._wait(0.2)


## The tab buttons of the open card (marked "card_tab").
func _tab_buttons_of_card() -> Array:
	var tabs = main.hud._card_tabs
	if main.hud._card == null or tabs == null or not is_instance_valid(tabs):
		return []
	return tabs.get_children().filter(func(b): return b.has_meta("card_tab") and not b.is_queued_for_deletion())


## The open card's pinned footer shows, out of the list that scrolls, with its Upgrade inside the dialog and the screen
## and a thumb wide (44 px, as the tiles').
func _footer_inside(what: String) -> void:
	var hud = main.hud
	var ft: Control = hud.p_card.foot
	var up: Button = hud.p_card.footer_button(Data.word("upgrade"))
	var shown: bool = ft != null and is_instance_valid(ft) and ft.visible and not hud._card_scroll.is_ancestor_of(ft)
	var inside: bool = up != null and _on_card_and_screen(up) and up.size.x >= 44.0 and up.size.y >= 44.0
	_x("the %s card's footer: its Upgrade inside the dialog and the screen, a thumb wide, out of the list that scrolls" % what,
		shown and inside, {"shown": shown, "button": up.get_global_rect() if up != null else Rect2()})


## The Hearthtree's other tabs (the Cat's stats, the Defences shelf): list rows, and the dialog still fits.
func _hearthtree_tabs() -> void:
	var win = main.hud.windows["shop"]
	var ids: Array = win.tab_ids()
	_x("the Hearthtree has its Cat tab (its stats are list rows)", ids.has("cat"), {"tabs": ids})
	for tid: String in ids:
		if tid == "hearthtree":
			continue
		win.select(tid)
		await t._wait(0.4)
		await t._shot("cards_hearthtree_" + tid)
		_lay._card_fits("hearthtree, %s tab" % tid)
		_card_shape("hearthtree's %s tab" % tid, "list")
	win.select("hearthtree")
	await t._wait(0.2)


## H4: the confirm window, from the open card's pinned Upgrade (the Well's: level 1 under a level 3 Hearthtree, so it
## is on): it opens and fits the phone as every dialog does.
func _confirm_from(what: String) -> void:
	var hud = main.hud
	var up: Button = hud.p_card.footer_button(Data.word("upgrade"))
	if not _x("the %s's Upgrade is on" % what, up != null and not up.disabled):
		return
	up.pressed.emit()
	await t._wait(0.6)
	if not _x("the %s's Upgrade opens the confirm window" % what, hud.card_ring() == hud.confirm, {"title": hud.card_title()}):
		return
	await t._shot("cards_confirm")
	_lay._card_fits("confirm, from the %s's Upgrade" % what)


## H4: the build menu, opened by a real tap on the build icon next to the Bag: it fits the phone.
func _build_menu() -> void:
	var hud = main.hud
	hud.hide_card()
	await t._wait(0.3)
	await t._tap_at(hud._build_icon.get_global_rect().get_center())
	await t._wait(0.8)                                # the pictures fade in one after another (0.3 s)
	if not _x("a real tap on the build icon opens the build menu", hud.card_ring() == hud.windows["build"], {"title": hud.card_title()}):
		return
	await t._shot("cards_build")
	_lay._card_fits("build menu")
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
