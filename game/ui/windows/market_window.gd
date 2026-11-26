extends "res://ui/windows/building_window.gd"
## H4: the Market's window (building and marker "stall": the old Market Stall's ids). Moved from stations.gd
## (_card_stall, _market_sells, _market_buys, _quiet and the Market's part of the upgrade line) in H4 Stage 1. H5
## rebuilds it. Phase G2: riding Thistle at the top, then Bramble's shop in tiles (what he sells, what he buys) and the
## Stable (mount looks, colours, attachments). Stage 2 (P2c) pins Upgrade in the footer. Knocked down: only the ruin
## card. The trades are rules and stay in stations.gd (_trade, _market_buy, _market_sell, with _market_open,
## _stock and _market_pay, which this window reads too).
## Used by: ui/windows/window_list.gd (hud.windows["stall"]), stations.gd (the marker's builder; _card_stall,
##          _market_sells and _market_buys for the tests in Stage 1).
## Uses: Data (trade, market, shard_trade, the mount), Bag, main.player and main.toggle_ride, main.raids.trade_shards,
##       the base's tiles and looks rows.


func _init(owner_hud) -> void:
	super(owner_hud, "stall", "stall")


func spec() -> Dictionary:
	return _card_stall()


## What Market level `level` gives: the mount's speed and health at that level.
func gives(level: int) -> Array:
	return ["%s runs faster and has %d health" % [Data.mount_name(), roundi(Data.pick("mount", "hp_by_level", level) * Data.mount_hp_mult())]]


## Phase G2: the Market (the old Market Stall's card): riding Thistle at the top, then Bramble's shop in tiles (what he
## sells, what he buys), the Stable (mount looks, colours, attachments) and the Market's own upgrade.
func _card_stall() -> Dictionary:
	var title: String = st._name("stall")
	if Save.ruined.has("stall"):
		return _ruin_card("stall", title, _anchor("stall", 2.4))
	var lv := int(Save.stations["stall"])
	var rows: Array = _wear_row("stall")
	var riding: bool = main.player.riding
	var mn := Data.mount_name()
	# G4: the mount has no move of its own: it carries the cat faster and takes the hits; it fights with the Saddlery's skills
	var learned := 0
	for sk in Data.saddle_items("skills"):
		if Data.skill_level(String(sk)) > 0:
			learned += 1
	var ride_note := "%s%% faster, takes the hits for you" % _short_num((Data.pick("mount", "speed_by_level", lv) - 1.0) * 100.0)
	if learned > 0:
		ride_note += " · %d skill%s" % [learned, "s" if learned > 1 else ""]
	rows.append({"text": ("Get off %s" if riding else "Ride %s") % mn, "note": "%s goes back to the %s" % [mn, title] if riding else ride_note,
		"cost": {}, "label": "Walk" if riding else "Ride", "enabled": main.mount != null, "action": main.toggle_ride})
	_add_section(rows, "Bramble sells", _market_sells())
	_add_section(rows, "Bramble buys", _market_buys())
	# the Stable: every look rides exactly the same, with the same Saddlery skills (G4: the saddle and the bags are
	# Saddlery attachments now; the Thunder Shoes stay here)
	var stable := _look_tiles("mount", "mount", "Your mount now", "")
	stable.append(_skin_row("mount"))
	stable.append_array(_gloomlit_row("mount"))
	stable.append_array(_attach_rows("mount"))
	_add_section(rows, "Stable", stable)
	return {"title": title, "sub": "Level %d · Bramble's trades, and %s" % [lv, mn],
		"rows": rows, "anchor": _anchor("stall", 2.4), "footer": upgrade_footer()}


## What Bramble sells: timber (balance.json trade.buy), then each market.sells entry (H3: food goes into the Bag, and
## the tile is off with "Bag full" when it would not fit; an expedition material, if one is ever listed, to the
## materials, which take Bag room too. H1: he sells no amber).
func _market_sells() -> Array:
	var out: Array = []
	var tb: Dictionary = Data.b["trade"].get("buy", {"timber": 5, "leaves": 50})
	out.append(_quiet(_tile("timber", "%d timber" % int(tb.get("timber", 5)), "For building and growing · you have %d" % Save.timber,
		{"leaves": int(tb.get("leaves", 50))}, "Buy", true, st._trade.bind(true))))
	var list: Array = Data.b.get("market", {}).get("sells", [])
	for i in list.size():
		var e: Dictionary = list[i]
		if not st._market_open(e):
			continue
		var iid := String(e["id"])
		var n := int(e.get("amount", 1))
		var mat := Data.MATS.has(iid)
		var title := "%d %s" % [n, Data.mat_name(iid) if mat else Data.item_name(iid, n)]
		var room := Bag.room_for(iid) >= n
		var text := ""
		if not room:
			text = "Bag full · you have %d" % st._stock(iid)
		elif mat:
			text = "An expedition material · you have %d" % Data.have(iid)
		else:
			text = "Food for cooking · you have %d" % st._stock(iid)
		out.append(_quiet(_tile(iid, title, text, {"leaves": int(e.get("leaves", 0))}, "Buy", room, st._market_buy.bind(i))))
	return out


## What Bramble buys: timber (trade.sell), Gloom shards once there are enough (as before), and each market.buys entry
## (H1: amber, once every mission is won; H3: the Golden Carp, from the Bag), for what the entry pays (_market_pay:
## leaves, and shards).
func _market_buys() -> Array:
	var out: Array = []
	var ts: Dictionary = Data.b["trade"].get("sell", {"timber": 5, "leaves": 30})
	out.append(_quiet(_tile("timber", "Sell %d timber" % int(ts.get("timber", 5)), "Bramble pays %d leaves" % int(ts.get("leaves", 30)),
		{"timber": int(ts.get("timber", 5))}, "Sell", true, st._trade.bind(false))))
	var sh: Dictionary = Data.gr()["shard_trade"]
	if Save.shards >= int(sh["shards"]):
		out.append(_tile("shard", "Sell %d Gloom shards" % int(sh["shards"]), "Bramble pays %d leaves" % int(sh["leaves"]),
			{"shards": int(sh["shards"])}, "Sell", true, main.raids.trade_shards))
	var list: Array = Data.b.get("market", {}).get("buys", [])
	for i in list.size():
		var e: Dictionary = list[i]
		if not st._market_open(e):
			continue
		var iid := String(e["id"])
		var n := int(e.get("amount", 1))
		var nm := Data.mat_name(iid) if Data.MATS.has(iid) else Data.item_name(iid, n)
		out.append(_quiet(_tile(iid, "Sell %d %s" % [n, nm], "Bramble pays %s · you have %d" % [_price_words(st._market_pay(e), true), st._stock(iid)],
			{iid: n} if Data.CURRENCIES.has(iid) else {}, "Sell", st._stock(iid) >= n, st._market_sell.bind(i))))
	return out


## An everyday trade: always there, so it never lights the Market's "!" (the shard trade still does, as before).
func _quiet(tile: Dictionary) -> Dictionary:
	tile["quiet"] = true
	return tile
