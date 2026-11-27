extends RefCounted
## H5 (Stage 2, 27 Nov 2026): the Market's window checks of `--campg` (scripts/autotest_g2_camp.gd runs them after it has
## built the Market at Hearthtree 2; split out so neither file grows past about 800 lines). Each check logs "EXPECT PASS
## <what>" or "EXPECT FAIL <what>" through autotest.gd's _expect. The windows are reached through main.hud.windows only.
##   tabs     four icon tabs at the bottom (a real tap on each shows it), named from balance.json windows, no Upgrade,
##            no level; Buys' payouts are neutral lines
##   trades   Sells and Buys as grids (one bundle's price or payout, no name, no button) and the trade popup: "+" and
##            the one action, two bundles, one gain for two bundles, exact and too few leaves, a full and a nearly full
##            Bag, too little stock, stock changing while it is open, the amber gate and its two payouts, the Golden
##            Carp, and no shard trade at all
##   mounts   Ride, Bramblewool chosen and its colours, a Gloomlit row, the detail view, and the Thunder Shoes (bought,
##            taken off, worn again) once the Gloomwood is open
##   pets     Sprig bought once (Lumi refused before, the "!" only when it can be paid), the pet goal's Go opening Pets,
##            training to 2 and 3 (the Hearthtree cap, a stale button), Lumi bought and chosen with the same sparks,
##            colours, the detail view, and the pet staying when the Market is ruined
## Screenshots: campg_market_sells / _buys / _mounts / _pets, campg_market_popup, campg_market_pets_owned,
## campg_market_pet_detail.
## Uses: autotest.gd (t: _wait, _shot, _expect, _until, _at_ring, _tap_at), the Market's window (main.hud.windows["stall"]:
##       select, tab, tab_ids, spec, tab_spec, entries, inspect, back, tab_lights, pulse, trade, companions), the
##       Hearthtree's window (its goal rows), scripts/market_trade.gd, commands/buy.gd, scripts/companion_shop.gd.

const MarketTrade := preload("res://scripts/market_trade.gd")
const Buy := preload("res://commands/buy.gd")
const CompanionShop := preload("res://scripts/companion_shop.gd")
const TABS := ["sells", "buys", "mounts", "pets"]

var t                     # autotest.gd (its helpers: _wait, _shot, _expect, _until, _at_ring, _tap_at)
var main


## The four groups of checks, in order (the Market is built and its card may be open).
func run() -> bool:
	await _market_tabs()
	await _trades()
	await _mounts()
	await _pets()
	return true


func _x(what: String, ok: bool, extra := {}) -> bool:
	return t._expect(what, ok, extra)


func _st():
	return main.stations


func _mw():
	return main.hud.windows["stall"]


func _w(key: String) -> String:
	return String(Data.word(key))


func _titles(rows: Array) -> Array:
	return rows.map(func(r): return "%s:%s" % [String(r.get("kind", "")), String(r.get("title", r.get("text", "")))])


## The row whose id (list_row's row_id) is rid, {} when there is none.
func _row_id(rows: Array, rid: String) -> Dictionary:
	for r in rows:
		if r is Dictionary and String((r as Dictionary).get("id", "")) == rid:
			return r
	return {}


## The cell with this id in a list of cells, {} when there is none.
func _cell(cells: Array, cid: String) -> Dictionary:
	for c in cells:
		if String(c.get("id", "")) == cid:
			return c
	return {}


## A visible button of the open card (not the X) with the meta `meta`, null when there is none.
func _card_button(meta: String) -> Button:
	if main.hud._card == null:
		return null
	for b in main.hud._card.find_children("*", "Button", true, false):
		if (b as Button).has_meta(meta) and (b as Button).is_visible_in_tree():
			return b
	return null


## The trade popup's "+" (dir 1) or "-" (dir -1) on the open card (meta "step"), null when there is none.
func _step_button(dir: int) -> Button:
	if main.hud._card == null:
		return null
	for b in main.hud._card.find_children("*", "Button", true, false):
		if (b as Button).has_meta("step") and int(b.get_meta("step")) == dir and (b as Button).is_visible_in_tree():
			return b
	return null


## The open card's tab button `tid` (meta "tab_id"), null when there is none.
func _tab_button(tid: String) -> Button:
	if main.hud._card == null or main.hud._card_tabs == null or not is_instance_valid(main.hud._card_tabs):
		return null
	for c in main.hud._card_tabs.get_children():
		if c is Button and not c.is_queued_for_deletion() and (c as Button).visible and String(c.get_meta("tab_id", "")) == tid:
			return c
	return null


## Calls a row's or a cell's action (its button's press), as a tap on it would, then the card refreshes.
func _act(r: Dictionary) -> void:
	var a: Variant = r.get("action", Callable())
	if a is Callable and (a as Callable).is_valid():
		(a as Callable).call()
	main.hud.refresh_card()


# ---------------------------------------------------------------- (c) the Market's window: four icon tabs
func _market_tabs() -> void:
	var mw = _mw()
	Save.leaves = 1000
	await t._at_ring(mw.ring())
	await t._wait(0.5)
	var spec: Dictionary = mw.spec()
	var tabs: Array = spec.get("tabs", [])
	_x("the Market opens on Sells: four icon tabs at the bottom (Sells, Buys, Mounts, Pets), each named, and no Upgrade",
		main.hud.card_title() == String(Data.building("stall")["name"]) and mw.tab == "sells" and String(spec.get("tabs_at", "")) == "bottom"
		and tabs.map(func(x): return String(x["id"])) == TABS and tabs.all(func(x): return String(x["text"]) == "" and String(x["name"]) != "")
		and not spec.has("footer") and main.hud.p_card.footer_button(_w("upgrade")) == null and (mw.tab_ids() as Array) == TABS,
		{"title": main.hud.card_title(), "tabs": tabs.map(func(x): return [x["id"], x["name"]])})
	_x("no level anywhere on the Market (one level, Q5 A)", not String(spec["sub"]).to_lower().contains("level"), {"sub": spec["sub"]})
	await t._shot("campg_market_sells")
	var seen: Array = []
	var ok := true
	var neutral := false
	for tid: String in ["buys", "mounts", "pets", "sells"]:
		var b: Button = _tab_button(tid)
		var found := b != null                         # read before the tap: the card's redraw frees the old button
		if found:
			await t._tap_at(b.get_global_rect().get_center())
		await t._wait(0.35)
		seen.append([tid, mw.tab, found])
		ok = ok and found and mw.tab == tid and main.hud.card_ring() == mw.ring()
		if tid == "buys":
			var lines: Array = main.hud._card_list.find_children("*", "HBoxContainer", true, false).filter(
				func(n): return (n as Node).has_meta("amount_line") and (n as Control).is_visible_in_tree())
			neutral = not lines.is_empty() and lines.all(func(n): return bool((n as Node).get_meta("neutral")))
		if tid != "sells":
			await t._shot("campg_market_" + tid)
	_x("a real tap on each icon tab shows that tab", ok, {"seen": seen})
	_x("Buys shows what Bramble pays as neutral lines (never red)", neutral)


# ---------------------------------------------------------------- (c) Sells and Buys: the grid and the popup
func _trades() -> void:
	var mw = _mw()
	var tr = mw.trade
	var tb: Dictionary = Data.b["trade"]["buy"]
	var ts: Dictionary = Data.b["trade"]["sell"]
	Save.leaves = 1000
	Save.timber = 0
	for id in ["berries", "goldfish"]:
		Bag.take(id, Bag.count(id))
	mw.select("sells")
	var sells: Array = mw.entries("sells")
	_x("Sells: timber first, then Bramble's food, each a picture with one bundle's price and no name or button",
		sells.size() >= 2 and String(sells[0]["id"]) == "timber" and not _cell(sells, "berries").is_empty()
		and sells.all(func(c): return not bool(c["show_title"]) and not (c.get("cost", {}) as Dictionary).is_empty() and String(c.get("label", "")) == "")
		and int(sells[0]["cost"]["leaves"]) == int(tb["leaves"]) and int(sells[0]["units"]) == int(tb["timber"]),
		{"cells": sells.map(func(c): return [c["id"], c.get("cost", {})])})
	# two bundles of timber through the popup's own buttons
	mw.inspect("timber")
	var plus: Button = _step_button(1)
	if plus != null:
		plus.pressed.emit()
	var act: Button = _card_button("action")
	_x("the timber popup: '+' makes 2 bundles, 2 x %d timber for 2 x %d leaves" % [int(tb["timber"]), int(tb["leaves"])],
		tr.is_open() and tr.popup.item_id() == "timber" and tr.popup.amount() == 2 and act != null and not act.disabled)
	if act != null:
		act.pressed.emit()
	_x("buying 2 bundles of timber", Save.timber == 2 * int(tb["timber"]) and Save.leaves == 1000 - 2 * int(tb["leaves"]),
		{"timber": Save.timber, "leaves": Save.leaves})
	mw.back()
	# two bundles of Sunberries: 4 for 60 leaves, one gain of 4
	var be: Dictionary = MarketTrade.offer("sells", "berries")
	var gains: Array = []
	var on_gain := func(k: String, id: String, n: int) -> void: gains.append([k, id, n])
	Events.item_gained.connect(on_gain)
	var l0 := Save.leaves
	mw.inspect("berries")
	tr.popup.set_amount(2)
	await t._wait(0.3)
	await t._shot("campg_market_popup")
	act = _card_button("action")
	if act != null:
		act.pressed.emit()
	Events.item_gained.disconnect(on_gain)
	_x("2 bundles of Sunberries: %d for %d leaves, in the Bag, one gain" % [2 * int(be["units"]), 2 * int(be["price"]["leaves"])],
		Bag.count("berries") == 2 * int(be["units"]) and Save.leaves == l0 - 2 * int(be["price"]["leaves"])
		and gains.filter(func(g): return String(g[1]) == "berries").size() == 1 and int(gains[0][2]) == 2 * int(be["units"]),
		{"berries": Bag.count("berries"), "leaves": Save.leaves, "gains": gains})
	# exact and too few leaves
	var each := int(be["price"]["leaves"])
	Save.leaves = each
	var q2: Dictionary = MarketTrade.quote("sells", "berries", 2)
	var held := Bag.count("berries")
	_x("exact leaves for one bundle: 2 are refused with the price, nothing changes", int(MarketTrade.quote("sells", "berries", 1)["max_bundles"]) == 1
		and String(q2["reason"]) == MarketTrade.short_of(q2["price"]) and not tr.trade("sells", "berries", 2)
		and Save.leaves == each and Bag.count("berries") == held, {"reason": q2["reason"]})
	_x("... and one bundle goes through", tr.trade("sells", "berries", 1) and Save.leaves == 0 and Bag.count("berries") == held + int(be["units"]))
	# a full Bag, then a nearly full one (room for less than two bundles)
	Save.leaves = 1000
	Bag.add("berries", Bag.room_for("berries"))
	held = Bag.count("berries")
	var cell: Dictionary = _cell(mw.entries("sells"), "berries")
	_x("a full Bag: the berries cell is grey, the popup says Bag full and nothing is bought", Bag.room_for("berries") == 0
		and bool(cell.get("grey", false)) and String(MarketTrade.quote("sells", "berries", 1)["reason"]) == _w("bag_full")
		and not tr.trade("sells", "berries", 1) and Bag.count("berries") == held and Save.leaves == 1000)
	Bag.take("berries", int(be["units"]) + 1)
	var room := Bag.room_for("berries")
	_x("room for %d berries: one bundle fits, two are refused (Bag full)" % room, room > int(be["units"]) and room < 2 * int(be["units"])
		and int(MarketTrade.quote("sells", "berries", 2)["max_bundles"]) == 1 and String(MarketTrade.quote("sells", "berries", 2)["reason"]) == _w("bag_full")
		and not tr.trade("sells", "berries", 2) and Save.leaves == 1000, {"room": room})
	Bag.take("berries", Bag.count("berries"))
	# Buys: timber back, too little stock, the Golden Carp, stock changing while the popup is open
	mw.select("buys")
	var buys: Array = mw.entries("buys")
	_x("Buys: timber first and the Golden Carp, each with what Bramble pays and no price; no amber before the missions, no shards",
		String(buys[0]["id"]) == "timber" and int(buys[0]["payout"]["leaves"]) == int(ts["leaves"]) and int(_cell(buys, "goldfish").get("payout", {}).get("leaves", 0)) == 300
		and buys.all(func(c): return not c.has("cost") and c.has("payout")) and _cell(buys, "amber").is_empty() and _cell(buys, "shards").is_empty(),
		{"cells": buys.map(func(c): return [c["id"], c.get("payout", {})])})
	Save.timber = int(ts["timber"])
	l0 = Save.leaves
	_x("selling one bundle of timber: Bramble pays %d leaves" % int(ts["leaves"]), tr.trade("buys", "timber", 1) and Save.timber == 0
		and Save.leaves == l0 + int(ts["leaves"]))
	Save.timber = int(ts["timber"]) - 1
	_x("too little timber: refused ('You have %d'), nothing changes" % Save.timber, String(MarketTrade.quote("buys", "timber", 1)["reason"])
		== String(Data.word("have_only")) % Save.timber and not tr.trade("buys", "timber", 1) and Save.timber == int(ts["timber"]) - 1 and Save.leaves == l0 + int(ts["leaves"]))
	Bag.add("goldfish", 2, true)
	mw.inspect("goldfish")
	tr.popup.set_amount(2)
	Bag.take("goldfish", 1)
	tr.popup.tick(1.0)
	act = _card_button("action")
	l0 = Save.leaves
	_x("the stock changes while the popup is open: 2 carp are refused now ('You have 1') and Sell is off",
		String(MarketTrade.quote("buys", "goldfish", 2)["reason"]) == String(Data.word("have_only")) % 1 and act != null and act.disabled
		and not tr.trade("buys", "goldfish", 2) and Bag.count("goldfish") == 1 and Save.leaves == l0)
	_x("one Golden Carp sells for 300 leaves", tr.trade("buys", "goldfish", 1) and Bag.count("goldfish") == 0 and Save.leaves == l0 + 300)
	mw.back()
	# amber: after the Raid Missions only, 1,000 leaves and a shard each
	Save.mats["amber"] = 0
	Data.give("amber", 2)
	l0 = Save.leaves
	var sh0 := Save.shards
	_x("before the missions are won Bramble does not buy amber", not MarketTrade.sell(main, "amber", 1) and Bag.count("amber") == 2 and Save.leaves == l0)
	var keep: Array = Save.missions_done.duplicate()
	Save.missions_done = []
	for i in Data.mission_count():
		Save.missions_done.append(String(Data.mission(i)["id"]))
	var amber: Dictionary = _cell(mw.entries("buys"), "amber")
	_x("after the missions: the amber cell pays 1,000 leaves and a Gloom shard", int(amber.get("payout", {}).get("leaves", 0)) == 1000
		and int(amber.get("payout", {}).get("shards", 0)) == 1, {"cell": amber})
	_x("selling 2 amber: 2,000 leaves and 2 shards", tr.trade("buys", "amber", 2) and Bag.count("amber") == 0 and Save.leaves == l0 + 2000
		and Save.shards == sh0 + 2, {"leaves": Save.leaves, "shards": Save.shards})
	Save.missions_done = keep
	# no shard trade at all (H5): never offered, a forged sale refused, the old rule and number gone
	Save.shards = 10
	_x("H5: Bramble never buys Gloom shards: no offer, a forged sale is refused, and the old shard trade is gone",
		not MarketTrade.sell(main, "shards", 1) and Save.shards == 10 and MarketTrade.offer("buys", "shards").is_empty()
		and not Data.gr().has("shard_trade") and not main.raids.has_method("trade_shards"))
	Save.shards = 0


# ---------------------------------------------------------------- (c2) Mounts
func _mounts() -> void:
	var st = _st()
	var mw = _mw()
	mw.select("mounts")
	var rows: Array = mw.tab_spec("mounts")["rows"]
	var ride: Dictionary = _row_id(rows, "ride")
	_x("Mounts: the Ride row is on (Thistle came with the Market)", String(ride.get("label", "")) == _w("ride") and bool(ride.get("enabled", false)),
		{"rows": _titles(rows)})
	var cells: Array = mw.entries("mounts")
	var th: Dictionary = _cell(cells, "thistle")
	var bw: Dictionary = _cell(cells, "bramblewool")
	_x("Mounts: Thistle (out, Equipped) and Bramblewool (Included, Use), both owned with the Market",
		cells.map(func(c): return String(c["id"])) == ["thistle", "bramblewool"] and bool(th.get("out", false)) and not bool(th.get("grey", true))
		and String(bw.get("label", "")) == _w("use") and String(bw.get("note", "")) == _w("included") and not bool(bw.get("grey", true)),
		{"cells": cells.map(func(c): return [c["id"], c["note"], c["label"]])})
	_act(ride)
	_x("Ride: the cat rides, and the row says Walk", main.player.riding and String(_row_id(mw.tab_spec("mounts")["rows"], "ride").get("label", "")) == _w("walk"))
	main.set_riding(false, false)
	_act(bw)
	await t._wait(0.2)
	_x("Use on Bramblewool: it comes out (the save's mount look), Thistle shows Use", Save.mount_look == "bramblewool"
		and bool(_cell(mw.entries("mounts"), "bramblewool").get("out", false)) and String(_cell(mw.entries("mounts"), "thistle").get("label", "")) == _w("use"))
	var col: Dictionary = _row_id(mw.tab_spec("mounts")["rows"], "colours")
	var skin0 := Save.mount_skin
	_act(col)
	_x("Next goes round Bramblewool's colours", String(col.get("label", "")) == _w("next") and Save.mount_skin != skin0, {"skin": Save.mount_skin})
	_x("a Gloomlit row for the mount (60 shards, off with none)", not _row_id(mw.tab_spec("mounts")["rows"], "gloomlit").is_empty())
	_x("the detail view: Bramblewool's whole picture, its speed and health", mw.inspect("bramblewool")
		and (mw.tab_spec("mounts")["rows"] as Array).size() == 1 and String(mw.companions.detail_lines("mount")[0]).contains(Data.mount_name()))
	mw.back()
	_act(_cell(mw.entries("mounts"), "thistle"))
	Save.mount_skin = "natural"
	if main.mount != null:
		main.mount.set_look()
	# the Thunder Shoes, once the Gloomwood is open
	Save.set_flag("hollow_open")
	Save.leaves = 5000
	var shoes: Dictionary = _row_id(mw.tab_spec("mounts")["rows"], "mount_shoes")
	_x("the Gloomwood open: the Thunder Shoes are for sale on Mounts", String(shoes.get("label", "")) == _w("buy") and bool(shoes.get("enabled", false)),
		{"row": shoes.get("text", "")})
	_act(shoes)
	_x("bought: owned and worn at once", Data.owned_level("attachments", "mount_shoes") == 1 and String(Save.attach["mount"]) == "mount_shoes")
	_act(_row_id(mw.tab_spec("mounts")["rows"], "mount_shoes"))
	_x("Take off", String(Save.attach["mount"]) == "")
	_act(_row_id(mw.tab_spec("mounts")["rows"], "mount_shoes"))
	_x("Wear again", String(Save.attach["mount"]) == "mount_shoes")
	Save.attach["mount"] = ""
	Save.flags.erase("hollow_open")
	st.refresh()


# ---------------------------------------------------------------- (c3) Pets
func _pets() -> void:
	var mw = _mw()
	var w = main.hud.windows["shop"]
	mw.select("pets")
	var price := Data.entry_price("pets", "sprig", 1)
	var cells: Array = mw.entries("pets")
	var sprig: Dictionary = _cell(cells, "sprig")
	var lumi: Dictionary = _cell(cells, "lumi")
	_x("Pets before the pet: Sprig for %d leaves (Buy), Lumi grey with 'Buy Sprig first', no training row" % int(price.get("leaves", 0)),
		int(price.get("leaves", 0)) == 160 and String(sprig.get("label", "")) == _w("buy") and bool(sprig.get("grey", false))
		and String(lumi.get("label", "")) == "" and String(lumi.get("note", "")) == String(Data.word("pet_first")) % "Sprig"
		and _row_id(mw.tab_spec("pets")["rows"], "pet_training").is_empty(), {"cells": cells.map(func(c): return [c["id"], c["note"], c["label"]])})
	Save.leaves = 1000
	_x("Lumi cannot be bought before the pet", not CompanionShop.buy(main, "pet", "lumi", 1) and Save.leaves == 1000 and Data.owned_level("pets", "lumi") == 0)
	Save.leaves = 159
	_x("159 leaves: Sprig's Buy is off and nothing lights", not bool(_cell(mw.entries("pets"), "sprig").get("enabled", true)) and not mw.tab_lights("pets") and not mw.pulse())
	Save.leaves = 1000
	_x("1,000 leaves: the Pets tab's dot and the Market's '!' light for Sprig", mw.tab_lights("pets") and mw.pulse())
	_act(_cell(mw.entries("pets"), "sprig"))
	await t._wait(0.4)
	_x("buying Sprig: 160 leaves, the pet comes at level 1 and joins the cat", Save.leaves == 840 and Data.pet_level() == 1
		and Data.owned_level("pets", "sprig") == 1 and main.pet != null and Save.pet_look == "sprig", {"leaves": Save.leaves, "pet": Data.pet_level()})
	_x("Sprig is not sold twice", Buy.new("pets", "sprig", 1, 1).can_run(main) != "" and not CompanionShop.buy(main, "pet", "sprig", 1) and Save.leaves == 840)
	# the pet goal's Go: the cat goes to the Market and it opens on Pets
	main.hud.hide_card()
	main.player.global_position = mw.ring().global_position
	main.snap_camera()
	await t._wait(0.1)
	var go: Array = (w._grow_rows() as Array).filter(func(r): return r.has("goal") and String(r["goal"].get("type", "")) == "pet_level")
	_x("after the Market is built the pet goal has Go", go.size() == 1 and String(go[0]["label"]) == "Go", {"rows": go.map(func(r): return r["label"])})
	if not go.is_empty():
		(go[0]["action"] as Callable).call()
	await t._until(func(): return main.hud.card_ring() == mw.ring(), 3.0)
	await t._wait(0.3)
	_x("Go opens the Market on its Pets tab", main.hud.card_ring() == mw.ring() and mw.tab == "pets", {"tab": mw.tab})
	# training: one tap, the Cottage's prices, never above the Hearthtree
	Save.camp_level = 2
	Save.leaves = 2000
	Save.timber = 100
	var row: Dictionary = _row_id(mw.tab_spec("pets")["rows"], "pet_training")
	_x("training to level 2 costs the old Cottage's level-2 price", (row.get("cost", {}) as Dictionary) == Data.pet_level_price(2)
		and int(Data.pet_level_price(2).get("leaves", 0)) == 350 and bool(row.get("enabled", false)) and String(row["label"]) == _w("train"), {"row": row.get("cost", {})})
	_act(row)
	_x("Train: the pet is level 2 for 350 leaves", Data.pet_level() == 2 and Save.leaves == 1650)
	_act(row)
	_x("the same (stale) Train again trains nothing", Data.pet_level() == 2 and Save.leaves == 1650)
	var r3: Dictionary = _row_id(mw.tab_spec("pets")["rows"], "pet_training")
	_x("level 3 waits for Hearthtree 3", not bool(r3.get("enabled", true)) and String(r3.get("text", "")).contains(str(3))
		and Buy.new("pet_training", "", 1, 3).can_run(main) != "", {"text": r3.get("text", "")})
	Save.camp_level = 3
	_act(_row_id(mw.tab_spec("pets")["rows"], "pet_training"))
	var p3 := Data.pet_level_price(3)
	_x("at Hearthtree 3: level 3 for the Cottage's level-3 price", Data.pet_level() == 3 and Save.leaves == 1650 - int(p3.get("leaves", 0))
		and Save.timber == 100 - int(p3.get("timber", 0)), {"leaves": Save.leaves, "timber": Save.timber})
	_x("at the top: Max level, no Train", String(_row_id(mw.tab_spec("pets")["rows"], "pet_training").get("label", "x")) == "")
	# Lumi: looks only, 400 leaves, the same sparks
	var sparks: String = mw.companions.sparks(Data.pet_level())
	Save.leaves = 400
	_act(_cell(mw.entries("pets"), "lumi"))
	_x("Lumi bought for 400 leaves; Sprig stays out until Use", Data.owned_level("pets", "lumi") == 1 and Save.leaves == 0 and Save.pet_look == "sprig")
	_act(_cell(mw.entries("pets"), "lumi"))
	await t._wait(0.2)
	_x("Use on Lumi: she comes out with the same level and the same sparks", Save.pet_look == "lumi" and Data.pet_level() == 3
		and main.pet != null and String(_row_id(mw.tab_spec("pets")["rows"], "pet_training").get("text", "")).begins_with(sparks), {"sparks": sparks})
	var col: Dictionary = _row_id(mw.tab_spec("pets")["rows"], "colours")
	var skin0 := Save.pet_skin
	_act(col)
	_x("the pet's colours go round (Next) and a Gloomlit row is there", Save.pet_skin != skin0
		and not _row_id(mw.tab_spec("pets")["rows"], "gloomlit").is_empty())
	Save.pet_skin = "natural"
	main.pet.set_look()
	mw.select("pets")
	await t._wait(0.3)
	await t._shot("campg_market_pets_owned")
	_x("the detail view of Lumi: her sparks at the pet's level", mw.inspect("lumi") and String(mw.companions.detail_lines("pet")[0]) == sparks)
	await t._wait(0.3)
	await t._shot("campg_market_pet_detail")
	mw.back()
	_act(_cell(mw.entries("pets"), "sprig"))
	# a ruined Market: no shopping or training, the pet stays with the cat
	Save.ruined.append("stall")
	main.pet._process(0.1)
	var ruin: Dictionary = mw.spec()
	var why: String = MarketTrade.building_reason("stall")
	_x("a ruined Market: only its ruin card (no tabs), no training or Use, and the pet stays beside the cat", main.pet.visible
		and not ruin.has("tabs") and why != "" and not CompanionShop.choose(main, "pet", "lumi") and Save.pet_look == "sprig"
		and Buy.new("pet_training", "", 1, -1).can_run(main) == why and Data.pet_level() == 3, {"sub": ruin.get("sub", ""), "why": why})
	Save.ruined.erase("stall")
	main.hud.hide_card()
	await t._wait(0.2)
