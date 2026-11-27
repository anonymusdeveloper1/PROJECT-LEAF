extends Node
## H4 (Stage 1): the --cards window kit checks (e), run from autotest_g2_cards.gd after its (b) (that file keeps the
## checks (a) to (d) and the helpers both halves use: _x, _grids, _texts, _list_rows, _on_card_and_screen and the
## stand-in marker FakeRing). Each check logs "EXPECT PASS <what>" or "EXPECT FAIL <what>" through autotest.gd's
## _expect.
##   (e) H4, the window kit (run after (b), with stand-in cards built here):
##       - a card with 12 list rows, top tabs (one with the "!" dot) and a footer, at 480x1040 and 540x960: it fits, the
##         rows are as wide as the list and 8 apart with no rule, the footer's Upgrade is not in the scrolling list and
##         stays inside the dialog and the screen with the list scrolled to its end and back ("Upgrade never scrolls
##         away"); the same with the tabs at the bottom and an icon-only tab: the tabs sit under the footer, inside
##       - a list row: its button runs its action; a tap on its picture runs on_picture; a drag that starts on the
##         picture scrolls the list and is no tap
##       - the confirm window (hud.confirm): ask() opens it, it fits and lists its lines (capitalised); Cancel is the
##         live grey and goes back without running the rule; Confirm runs the rule, then goes back; a short price or a
##         reason turns Confirm off and a short price shows red; Confirm's own check runs nothing while the price is
##         short or there is a reason, also when the leaves go after it was drawn; a wave blanks it (no footer); the X
##         closes it
##       - the visit hooks: card_opened once per open, card_closed once per close or replace; the Bag (no builder) and
##         the Settings window open and close with them in place
##       - the signature: a card with a view_id keeps its rows when nothing changed and redraws when only its footer's
##         note, a tile's badge or whether its footer's price can be paid changes
##       Screenshots: cards_kit_*.png.
## Moved out of autotest_g2_cards.gd on 26 Nov 2026 (house rule 1: one job a file, under about 800 lines); the checks
## (e) did not change and run in the same order, with the same words.

var t                     # autotest.gd (its helpers: _wait, _shot, _expect, _until, _press, _tap_at, _tap_close...)
var main
var g                     # autotest_g2_cards.gd: the helpers both halves use (_x, _grids, _texts, _list_rows and the rest)
var _lay                  # autotest_layout.gd, for its _card_fits (the dialog fits the phone and its safe area)
var _hits := {}           # which stand-in row's, tab's or footer's action ran, how often
var _ring                 # the stand-in card's marker (kept while its card is open)
var _calls: Array = []    # (e) what the confirm's rule and its back ran, in order
var _reason_now := ""     # (e) the confirm's reason ("" = it may run)
var _back_ring            # (e) the window the confirm goes back to
var _sig_note := ""       # (e) the signature card's footer note and tile badge
var _sig_badge := ""
var _sig_cost := {}       # (e) the signature card's footer price

const Cards := preload("res://scripts/autotest_g2_cards.gd")   # its FakeRing (the stand-in marker both halves use)
const ConfirmScript := preload("res://ui/kit/confirm_window.gd")
const ShopTilesScript := preload("res://ui/hud/shop_tiles.gd")   # (e) its BTN colours, for the Cancel check


## (e) A stand-in window for the visit hooks: its builder is its own spec, so the card finds it behind the Callable and
## tells it when its visit starts and ends.
class FakeWindow extends RefCounted:
	var key := "fake_window"
	var builder: Callable = spec
	var opened := 0
	var closed := 0

	func spec() -> Dictionary:
		return {"title": "Fake window", "sub": "", "rows": [{"text": "A window that hears its visits"}]}

	func card_opened() -> void:
		opened += 1

	func card_closed() -> void:
		closed += 1


## The checks, in the order they always ran; autotest_g2_cards.gd starts them after its (b) and frees this node after.
func run() -> void:
	var hud = main.hud
	hud.hide_card()
	await t._wait(0.3)
	for size in [Vector2i(480, 1040), Vector2i(540, 960)]:
		get_window().size = size
		await t._wait(0.6)
		await _kit_card("top")
		await _kit_card("bottom")
	get_window().size = Vector2i(480, 1040)
	await t._wait(0.6)
	await _kit_rows()
	await _kit_confirm()
	await _kit_hooks()
	await _kit_signature()
	hud.hide_card()
	_ring = null
	await t._wait(0.3)


# ---------------------------------------------------------------- helpers kept in autotest_g2_cards.gd (its (c) uses them too)
func _x(what: String, ok: bool, extra := {}) -> bool:
	return g._x(what, ok, extra)


func _grids() -> Array:
	return g._grids()


func _texts(n: Node) -> Array:
	return g._texts(n)


func _list_rows() -> Array:
	return g._list_rows()


func _on_card_and_screen(c: Control) -> bool:
	return g._on_card_and_screen(c)


# ---------------------------------------------------------------- (e) H4: the window kit's own checks and helpers
func _kit_hit(k: String) -> void:
	_hits[k] = int(_hits.get(k, 0)) + 1


## The kit's stand-in card: 12 list rows (one with a real bow picture), two tabs (the second with the "!" dot; with the
## tabs at the bottom a third that is only an icon) and a footer with one Upgrade.
func _kit_spec(at: String) -> Dictionary:
	var icons := ["damage", "draw", "range", "heart"]
	var rows: Array = []
	for i in 12:
		rows.append({"kind": "list", "id": "row%d" % i, "icon": icons[i % icons.size()],
			"picture": "res://assets/ui/bows/bow_sunwood.png" if i == 3 else "", "title": "Row %d" % (i + 1),
			"badge": "Level %d/5" % (i % 5), "text": "Its first line\nand its second line, long enough to wrap on a phone",
			"cost": {"leaves": 10 + i}, "label": "Buy", "enabled": true, "action": _kit_hit.bind("row%d" % i),
			"on_picture": _kit_hit.bind("pic%d" % i)})
	var tabs: Array = [{"id": "one", "text": "One", "selected": true, "action": _kit_hit.bind("tab_one")},
		{"id": "two", "text": "Two", "dot": true, "action": _kit_hit.bind("tab_two")}]
	if at == "bottom":
		tabs.append({"id": "three", "text": "", "icon": "bow", "action": _kit_hit.bind("tab_three")})
	return {"title": "Kit test", "sub": "H4 · list rows, tabs and a footer", "anchor": Vector3.ZERO, "tabs": tabs,
		"tabs_at": at, "rows": rows, "footer": {"text": "Level 2 of 5", "note": "Needs the Hearthtree at level 3",
		"cost": {"leaves": 90}, "buttons": [{"label": "Upgrade", "tone": "green", "enabled": true,
		"action": _kit_hit.bind("footer")}]}}


## Opens a stand-in card (as a tap on a marker would) with this builder and lets it pop in and lay out.
func _open_fake(builder: Callable) -> void:
	main.hud.hide_card()
	await t._wait(0.3)
	Save.leaves = 500
	Save.timber = 50
	var r := Cards.FakeRing.new()
	r.builder = builder
	_ring = r
	main.hud.show_card(r)
	await t._wait(0.6)


func _tab_buttons() -> Array:
	var tabs = main.hud._card_tabs
	if main.hud._card == null or tabs == null or not is_instance_valid(tabs):
		return []
	return tabs.get_children().filter(func(b): return b.has_meta("card_tab") and not b.is_queued_for_deletion())


## The "!" dot drawn on a tab button, or null.
func _dot_of(b: Node) -> Control:
	for c in b.get_children():
		if c.has_meta("tab_dot"):
			return c as Control
	return null


## The picture of the list row with this id, or null.
func _row_picture(id: String) -> Control:
	for r in _list_rows():
		if String(r.get_meta("id", "")) == id:
			for c in (r as Node).find_children("*", "", true, false):
				if c.has_meta("list_pic"):
					return c as Control
	return null


## A finger swipe through Input, with the viewport's transform (as autotest_missions.gd's).
func _swipe(from: Vector2, to: Vector2) -> void:
	var xf: Transform2D = get_viewport().get_final_transform()
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.position = xf * from
	down.pressed = true
	Input.parse_input_event(down)
	for i in 8:
		await t._wait(0.03)
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = xf * from.lerp(to, float(i + 1) / 8.0)
		drag.relative = xf.basis_xform((to - from) / 8.0)
		Input.parse_input_event(drag)
	await t._wait(0.15)                               # settle before lifting, so the check starts without inertia
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.position = xf * to
	Input.parse_input_event(up)
	await t._wait(0.06)


## The kit card at the window's size now, with the tabs on top or at the bottom.
func _kit_card(at: String) -> void:
	var hud = main.hud
	await _open_fake(_kit_spec.bind(at))
	var ws: Vector2i = get_window().size
	var where := "%s tabs, %dx%d" % [at, ws.x, ws.y]
	if not _x("the kit card opens (%s)" % where, hud.card_title() == "Kit test", {"title": hud.card_title()}):
		return
	_lay._card_fits("kit card, " + where)
	var rows := _list_rows()
	var lw: float = hud._card_list.size.x
	var wide := rows.all(func(r): return absf((r as Control).size.x - lw) < 1.0)
	_x("12 list rows, as wide as the list, 8 apart, no rule between them (%s)" % where, rows.size() == 12 and wide
		and hud._card_list.get_theme_constant("separation") == 8
		and hud._card_list.find_children("*", "HSeparator", false, false).is_empty(),
		{"rows": rows.size(), "list_w": lw, "row_w": rows.map(func(r): return (r as Control).size.x).slice(0, 3)})
	var fb: Button = hud.p_card.footer_button("Upgrade")
	if not _x("the footer holds its Upgrade, a thumb wide (%s)" % where, fb != null and bool(fb.get_meta("footer", false))
			and fb.size.x >= 149.5 and fb.size.y >= 63.5, {"size": fb.size if fb != null else Vector2.ZERO}):
		hud.hide_card()
		await t._wait(0.3)
		return
	var sc: ScrollContainer = hud._card_scroll
	_x("the footer is not in the scrolling list (%s)" % where, not sc.is_ancestor_of(fb))
	_x("the 12 rows scroll inside the dialog (%s)" % where, hud._card_list.size.y > sc.size.y + 1.0,
		{"list": hud._card_list.size.y, "scroll": sc.size.y})
	sc.scroll_vertical = int(sc.get_v_scroll_bar().max_value)
	await t._wait(0.3)
	var end_y: int = sc.scroll_vertical
	var at_end := _on_card_and_screen(fb)
	sc.scroll_vertical = 0
	await t._wait(0.3)
	var at_top := _on_card_and_screen(fb)
	_x("Upgrade never scrolls away: inside the dialog and the screen at the list's end and at its top (%s)" % where,
		end_y > 0 and at_end and at_top, {"end": end_y, "at_end": at_end, "at_top": at_top, "button": fb.get_global_rect()})
	var tabs := _tab_buttons()
	var nav: Control = hud._card_nav
	var cr: Rect2 = hud._card.get_global_rect().grow(0.5)
	if at == "top":
		_x("the tabs sit on top, over the list (%s)" % where, tabs.size() == 2 and cr.encloses(nav.get_global_rect())
			and nav.get_global_rect().end.y <= sc.get_global_rect().position.y + 0.5,
			{"nav": nav.get_global_rect(), "scroll": sc.get_global_rect()})
		var dotted := tabs.filter(func(b): return String(b.get_meta("tab_id", "")) == "two")
		var plain := tabs.filter(func(b): return String(b.get_meta("tab_id", "")) == "one")
		var dot: Control = _dot_of(dotted[0]) if dotted.size() == 1 else null
		_x("the tab with a dot shows the \"!\" on its button; the other tab none (%s)" % where, dot != null
			and plain.size() == 1 and _dot_of(plain[0]) == null
			and (dotted[0] as Control).get_global_rect().grow(0.5).encloses(dot.get_global_rect()))
	else:
		var ft: Control = hud.p_card.foot
		_x("bottom tabs sit under the footer, inside the dialog (%s)" % where, tabs.size() == 3
			and cr.encloses(nav.get_global_rect()) and nav.get_global_rect().position.y >= ft.get_global_rect().end.y - 0.5,
			{"nav": nav.get_global_rect(), "foot": ft.get_global_rect()})
		var icon_tab := tabs.filter(func(b): return String(b.get_meta("tab_id", "")) == "three")
		_x("an icon-only tab shows its icon and no words, inside the dialog (%s)" % where, icon_tab.size() == 1
			and (icon_tab[0] as Node).find_children("*", "TextureRect", true, false).size() == 1
			and (icon_tab[0] as Button).text == "" and cr.encloses((icon_tab[0] as Control).get_global_rect()))
	await t._shot("cards_kit_%s_%d" % [at, ws.x])
	hud.hide_card()
	await t._wait(0.3)


## A list row's button, a tap on its picture and a drag that starts on its picture.
func _kit_rows() -> void:
	var hud = main.hud
	_hits.clear()
	await _open_fake(_kit_spec.bind("top"))
	var ok: bool = t._press("Buy")
	await t._wait(0.3)
	_x("a list row's button runs its action, and the card refreshes", ok and int(_hits.get("row0", 0)) == 1
		and hud.card_title() == "Kit test" and _list_rows().size() == 12, {"hits": _hits})
	var pic := _row_picture("row1")
	if not _x("a list row shows its picture", pic != null):
		hud.hide_card()
		await t._wait(0.3)
		return
	await t._tap_at(pic.get_global_rect().get_center())
	await t._wait(0.3)
	_x("a tap on a row's picture runs its on_picture (not its button)", int(_hits.get("pic1", 0)) == 1
		and not _hits.has("row1") and hud.card_title() == "Kit test", {"hits": _hits})
	var sc: ScrollContainer = hud._card_scroll
	sc.scroll_vertical = 0
	await t._wait(0.3)
	var pic2 := _row_picture("row2")
	var before: int = sc.scroll_vertical
	if pic2 != null:
		var from := pic2.get_global_rect().get_center()
		await _swipe(from, from - Vector2(0, 210))
	_x("a drag that starts on a picture scrolls the list and is no tap", pic2 != null and sc.scroll_vertical > before + 40
		and not _hits.has("pic2"), {"before": before, "after": sc.scroll_vertical, "hits": _hits})
	await t._shot("cards_kit_rows")
	hud.hide_card()
	await t._wait(0.3)


func _kit_note(k: String) -> void:
	_calls.append(k)


func _kit_reason() -> String:
	return _reason_now


## The confirm's back: the window it came from (a stand-in card here).
func _kit_back() -> void:
	_calls.append("back")
	main.hud.show_card(_back_ring)


func _back_spec() -> Dictionary:
	return {"title": "Back window", "sub": "", "rows": [{"text": "The window the confirm came from"}]}


func _kit_ask(cw, leaves: int) -> void:
	cw.ask({"title": "Test level 2", "lines": ["stats up to level 6", "unlocks Range"], "cost": {"leaves": leaves},
		"on_confirm": _kit_note.bind("confirm"), "back": _kit_back, "reason": _kit_reason})


## The open footer's price numbers (each a Label with the meta "afford" that shop_tiles._price_line sets: false when
## that currency is short, so it is drawn red); an old footer that is going is skipped.
func _foot_prices() -> Array:
	var out: Array = []
	var f: MarginContainer = main.hud.p_card.foot
	if main.hud._card == null or f == null or not is_instance_valid(f):
		return out
	for c in f.get_children():
		if c.is_queued_for_deletion():
			continue
		for l in c.find_children("*", "Label", true, false):
			if l.has_meta("afford"):
				out.append(l)
	return out


## The confirm window: what it shows, Cancel, Confirm, a short price, a reason, a wave, the X.
func _kit_confirm() -> void:
	var hud = main.hud
	hud.hide_card()
	await t._wait(0.3)
	var cw = hud.get("confirm")
	_x("the HUD has its confirm window (hud.confirm)", cw != null)
	if cw == null:
		cw = ConfirmScript.new(hud)                     # one of its own, so the kit's own checks still run
	_calls.clear()
	_reason_now = ""
	Save.leaves = 500
	var back := Cards.FakeRing.new()
	back.builder = _back_spec
	_back_ring = back
	var cancel_w := Data.word("cancel")
	var ok_w := Data.word("confirm")
	_kit_ask(cw, 50)
	await t._wait(0.6)
	if not _x("ask() opens the confirm window", hud.card_ring() == cw and hud.card_title() == "Test level 2",
			{"title": hud.card_title()}):
		hud.hide_card()
		await t._wait(0.3)
		return
	_lay._card_fits("confirm")
	var texts := _texts(hud._card_list)
	_x("it lists what the level gives, one line each, starting with a capital", texts.has("Stats up to level 6")
		and texts.has("Unlocks Range"), {"texts": texts})
	var cancel: Button = hud.p_card.footer_button(cancel_w)
	var ok_b: Button = hud.p_card.footer_button(ok_w)
	_x("its footer: Cancel, then Confirm on the right, both on", cancel != null and ok_b != null and not cancel.disabled
		and not ok_b.disabled and ok_b.get_global_rect().position.x > cancel.get_global_rect().position.x)
	var prices := _foot_prices()
	_x("its footer shows the price, in ink when it can be paid", prices.size() == 1 and (prices[0] as Label).text == "50"
		and bool(prices[0].get_meta("afford")), {"prices": prices.map(func(l: Label) -> String: return l.text)})
	# the colour too: an unknown tone would make its own "btn_grey" style, drawn green (shop_tiles._ui_style)
	var cancel_style: StyleBoxFlat = (cancel.get_theme_stylebox("normal") as StyleBoxFlat) if cancel != null else null
	var grey: Variant = ShopTilesScript.BTN.get("grey")
	_x("Cancel is drawn in the live grey (btn_grey), not green", cancel_style != null
		and cancel_style == hud.p_tiles._ui_style("btn_grey") and grey is Color and cancel_style.bg_color == grey
		and cancel_style.bg_color != ShopTilesScript.BTN["green"], {"colour": cancel_style.bg_color if cancel_style != null else null})
	await t._shot("cards_kit_confirm")
	t._press(cancel_w)
	await t._wait(0.4)
	_x("Cancel goes back and runs nothing", _calls == ["back"] and hud.card_ring() == _back_ring, {"calls": _calls})
	_calls.clear()
	_kit_ask(cw, 50)
	await t._wait(0.5)
	t._press(ok_w)
	await t._wait(0.4)
	_x("Confirm runs the rule, then goes back", _calls == ["confirm", "back"] and hud.card_ring() == _back_ring,
		{"calls": _calls})
	_calls.clear()
	_kit_ask(cw, 99999)
	await t._wait(0.5)
	ok_b = hud.p_card.footer_button(ok_w)
	_x("with the price short Confirm is grey and off", hud.card_ring() == cw and ok_b != null and ok_b.disabled
		and ok_b.get_theme_stylebox("disabled") == hud.p_tiles._ui_style("btn_off"))
	prices = _foot_prices()
	_x("... and the price shows in red (Q2 a)", prices.size() == 1 and (prices[0] as Label).text == "99999"
		and not bool(prices[0].get_meta("afford")), {"prices": prices.map(func(l: Label) -> String: return l.text)})
	cw._confirm()                                       # its own check of the price, not the button's
	await t._wait(0.2)
	_x("... and Confirm's own check runs nothing while the price is short", _calls.is_empty() and hud.card_ring() == cw,
		{"calls": _calls})
	_reason_now = "Needs the Hearthtree at level 3"
	_kit_ask(cw, 50)                                    # it already shows: ask() redraws it
	await t._wait(0.3)
	ok_b = hud.p_card.footer_button(ok_w)
	_x("with a reason Confirm is off and the reason shows", ok_b != null and ok_b.disabled
		and _texts(hud._card_list).has(_reason_now), {"texts": _texts(hud._card_list)})
	if ok_b != null:
		ok_b.pressed.emit()                             # nothing is connected to an off button
	await t._wait(0.2)
	_x("... and a press on it anyway runs nothing", _calls.is_empty(), {"calls": _calls})
	cw._confirm()                                       # its own check of the reason
	await t._wait(0.2)
	_x("... and Confirm's own check runs nothing while there is a reason", _calls.is_empty() and hud.card_ring() == cw,
		{"calls": _calls})
	_reason_now = ""
	# drawn payable, then the leaves go before the press: the live button reaches Confirm's own check of the price
	_kit_ask(cw, 50)
	await t._wait(0.3)
	ok_b = hud.p_card.footer_button(ok_w)
	var live: bool = ok_b != null and not ok_b.disabled
	Save.leaves = 0
	if ok_b != null and is_instance_valid(ok_b):
		ok_b.pressed.emit()                             # same frame: the button that was drawn on, still connected
	await t._wait(0.2)
	_x("a price that stopped being paid since it was drawn: Confirm runs nothing and the window stays",
		live and _calls.is_empty() and hud.card_ring() == cw, {"live": live, "calls": _calls})
	Save.leaves = 500
	# a wave blanks it, as every station card
	_kit_ask(cw, 50)
	await t._wait(0.3)
	main.fight.set_physics_process(false)               # a wave "on" for the check, with nothing running it
	main.fight.active = true
	main.fight.in_wave = true
	hud.refresh_card()
	await get_tree().process_frame
	await get_tree().process_frame
	_x("a wave blanks the confirm: no footer, no button", hud.card_ring() == cw and not hud.p_card.foot.visible
		and hud.p_card.footer_button(ok_w) == null and hud.card_buttons().size() == 0,
		{"buttons": hud.card_buttons().size()})
	main.fight.active = false
	main.fight.in_wave = false
	main.fight.set_physics_process(true)
	hud.refresh_card()
	await t._wait(0.3)
	_x("after the wave its Confirm is back", hud.p_card.footer_button(ok_w) != null)
	await t._tap_close()
	_x("its X closes everything and runs nothing", hud._card == null and _calls.is_empty(), {"calls": _calls})


## The visit hooks: card_opened and card_closed on the object behind a card's builder; the Bag and Settings unharmed.
func _kit_hooks() -> void:
	var hud = main.hud
	hud.hide_card()
	await t._wait(0.3)
	var a := FakeWindow.new()
	var b := FakeWindow.new()
	hud.show_card(a)
	await t._wait(0.3)
	var first: bool = a.opened == 1 and a.closed == 0
	hud.refresh_card()
	hud.show_card(a)                                    # it already shows: nothing happens
	await t._wait(0.2)
	_x("card_opened runs once when a card opens (not on a refresh, not again while it shows)", first and a.opened == 1
		and a.closed == 0, {"opened": a.opened, "closed": a.closed})
	hud.hide_card()
	await t._wait(0.2)
	_x("card_closed runs once when it closes", a.opened == 1 and a.closed == 1, {"opened": a.opened, "closed": a.closed})
	hud.show_card(a)
	await t._wait(0.2)
	hud.show_card(b)                                    # another card replaces it
	await t._wait(0.3)
	_x("a card that replaces it: the old window hears card_closed, the new one card_opened", a.opened == 2
		and a.closed == 2 and b.opened == 1 and b.closed == 0, {"a": [a.opened, a.closed], "b": [b.opened, b.closed]})
	await t._tap_close()
	_x("the X ends the visit too", hud._card == null and b.closed == 1, {"b": [b.opened, b.closed]})
	_x("the Bag has no builder, so no hooks for it", hud.p_card._builder_object(hud.inventory) == null)
	_x("the Settings window is its own builder's object", hud.p_card._builder_object(hud.settings) == hud.settings)
	hud.open_inventory()
	await t._wait(0.6)
	var bag_open: bool = hud.card_ring() == hud.inventory
	hud.hide_card()
	await t._wait(0.3)
	var bag_shut: bool = hud._card == null
	hud.open_settings()
	await t._wait(0.4)
	var set_open: bool = hud.card_ring() == hud.settings
	hud.hide_card()
	await t._wait(0.3)
	_x("the Bag and the Settings window open and close with the hooks in place", bag_open and bag_shut and set_open
		and hud._card == null, {"bag": bag_open, "settings": set_open})


func _sig_spec() -> Dictionary:
	return {"title": "Signature", "sub": "", "view_id": "kit_signature", "rows": [
		{"kind": "item", "icon": "target", "title": "A tile", "text": "Its badge changes", "badge": _sig_badge,
			"cost": {}, "label": "", "enabled": false, "action": Callable()}],
		"footer": {"text": "Level 1 of 5", "note": _sig_note, "cost": _sig_cost, "buttons": [{"label": "Upgrade",
			"tone": "green", "enabled": true, "action": _kit_note.bind("sig")}]}}


## The signature of a card with a view_id: no rebuild when nothing changed; a rebuild when only the footer's note or a
## tile's badge changes.
func _kit_signature() -> void:
	var hud = main.hud
	_sig_note = "Note one"
	_sig_badge = "Level 1/5"
	await _open_fake(_sig_spec)
	var grids := _grids()
	var grid0: Node = grids[0] if grids.size() == 1 else null
	hud.refresh_card()
	await get_tree().process_frame
	_x("a view_id card keeps its rows when nothing changed", grid0 != null and is_instance_valid(grid0)
		and not grid0.is_queued_for_deletion() and _grids().size() == 1 and _grids()[0] == grid0)
	_sig_note = "Note two"
	hud.refresh_card()
	await t._wait(0.2)
	var ft: Array = _texts(hud.p_card.foot) if hud.p_card.foot != null else []
	_x("... and redraws when only its footer's note changes", ft.has("Note two") and not ft.has("Note one"), {"footer": ft})
	_sig_badge = "Level 2/5"
	hud.refresh_card()
	await t._wait(0.2)
	_x("... or only a tile's badge", _grids().size() == 1 and _texts(_grids()[0]).has("Level 2/5"),
		{"grids": _grids().size()})
	# the footer's Upgrade stays on while its price is short (Q2 a): the price's red or ink must follow the leaves
	var leaves_before := Save.leaves
	Save.leaves = 50
	_sig_cost = {"leaves": 100}
	hud.refresh_card()
	await t._wait(0.2)
	var short_p: Array = _foot_prices().map(func(l: Label) -> bool: return bool(l.get_meta("afford")))   # read now:
	Save.leaves = 150                                   # the redraw frees these labels
	hud.refresh_card()
	await t._wait(0.2)
	var paid_p: Array = _foot_prices().map(func(l: Label) -> bool: return bool(l.get_meta("afford")))
	_x("... or only whether its footer's price can be paid (red, then ink)", short_p == [false] and paid_p == [true],
		{"short": short_p, "paid": paid_p})
	_sig_cost = {}
	Save.leaves = leaves_before
	hud.hide_card()
	await t._wait(0.3)
