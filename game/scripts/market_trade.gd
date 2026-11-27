extends RefCounted
## Bramble's trades at the Market (H5, 27 Nov 2026; docs/ARCHITECTURE.md part 4, Command; the H5 map part 3.3): what he
## sells and buys, what an amount of it costs or pays, and selling to him. Static functions only; it keeps no state.
## Buying from him is the Buy command (commands/buy.gd, kind "market_goods"): it reads the same quote and runs the same
## exchange (trade). The Market window (ui/windows/market_window.gd, H5 Stage 2) reads offers and quote, never does sums.
## No class_name: preload it, const MarketTrade := preload("res://scripts/market_trade.gd").
## Words used below:
##   side    "sells" (Bramble sells, the player buys) or "buys" (Bramble buys, the player sells): Bramble's side
##   bundle  one lot of an offer: 5 timber, 2 Sunberries, 1 amber. An amount is always whole bundles, from 1
##   price   what leaves the player: on "sells" the currencies paid; on "buys" the goods handed over ({id: units})
##   payout  what the player gets: on "sells" the goods ({id: units}); on "buys" every currency Bramble pays (amber:
##           1,000 leaves and one purple shard each)
## Where the offers come from: timber's two from balance.json trade (buy: timber for leaves; sell: timber back for fewer
## leaves), then balance.json market (sells, buys; after_missions: only once every Raid Mission is won). An offer is
## found by its side and its id, never by a place in a filtered list.
## Rules:
##   - Bramble never buys Gloom shards (H5: the old shard trade, gloom_raids.shard_trade, is not read here): goods are
##     timber or a thing the Bag holds (Bag.kind_of), so a "shards" offer is never shown or traded.
##   - His prices are leaves and timber: a "sells" price that names the paid currency (shards buy only looks, CLAUDE.md)
##     or amber (it is sold, never paid with), or a malformed amount, leaves that offer out (fails closed).
##   - A trade needs the Market built and standing (a ruined Market trades nothing) and the offer's mission gate open.
##   - Buying is bounded by both the money and the Bag's room (timber needs no room); selling by the stock held. Zero,
##     negative and too-big amounts are refused before anything changes, and a refused trade changes nothing.
##   - trade() marks the save dirty and never saves or calls the HUD: the caller saves, refreshes and shows the receipt
##     (or the refusal from quote). Bag.add / Bag.take / Save.add_mat send the Bag's own events; leaves, timber and
##     shards send currency_changed through their Save setters. Nothing else is announced, so one purchase is one gain.
## Used by: commands/buy.gd, scripts/companion_shop.gd (the shared words and checks below), the Market window and the
##          tests (H5 Stage 2). Uses: Data (balance.json trade, market, windows; the money), Bag, Save.

const SELLS := "sells"                  # Bramble sells: the player buys (the Buy command's "market_goods")
const BUYS := "buys"                    # Bramble buys: the player sells (sell below)
const MARKET := "stall"                 # the Market's building id (the save's): Bramble trades only while it stands
const TIMBER := "timber"                # the goods of balance.json trade (a currency, so it needs no Bag room)
## The paid currency (CLAUDE.md, the owner 25 Nov 2026: purple shards buy only looks). A price for power or goods that
## names it is never paid; Bramble may still pay it out (one for each amber).
const PAID_CURRENCY := "shards"


# ---------------------------------------------------------------- the offers
## Every offer of one side that can be traded at all, in order (timber first): {"id", "side", "units" (in one bundle),
## "price", "payout" (for one bundle, see the words above), "after_missions" (it waits for the Raid Missions), "open"
## (its mission gate is open now)}. Malformed offers and a second offer with the same id are left out.
static func offers(side: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen: Array[String] = []
	for raw: Dictionary in _raw_offers(side):
		var o: Dictionary = _offer_from(side, raw)
		if o.is_empty() or seen.has(String(o["id"])):
			continue
		seen.append(String(o["id"]))
		out.append(o)
	return out


## One offer by its side and exact id (as offers gives it), {} when there is none.
static func offer(side: String, item_id: String) -> Dictionary:
	for o: Dictionary in offers(side):
		if String(o["id"]) == item_id:
			return o
	return {}


## What `bundles` bundles of offer item_id would be now: {"id", "side", "bundles", "units" (all of them), "price",
## "payout" (for all of them), "max_bundles" (the most that can be traded now: money and room, or stock; 0 when none),
## "reason" ("" when this many can be traded now, else why not, in the player's words)}. The window asks again when
## the stock or the money changes.
static func quote(side: String, item_id: String, bundles: int) -> Dictionary:
	var q: Dictionary = {"id": item_id, "side": side, "bundles": bundles, "units": 0, "price": {}, "payout": {},
		"max_bundles": 0, "reason": ""}
	var o: Dictionary = offer(side, item_id)
	if o.is_empty():
		q["reason"] = say("coming_later")
		return q
	var n: int = maxi(bundles, 0)
	q["units"] = int(o["units"]) * n
	q["price"] = _times(o["price"], n)
	q["payout"] = _times(o["payout"], n)
	q["max_bundles"] = _max_bundles(o)
	q["reason"] = _reason(o, bundles, int(q["units"]), q["price"])
	return q


## The player sells `bundles` bundles of item_id to Bramble: the goods go, his payout comes. false (and nothing changed)
## when quote gives a reason. (The scene is not needed: the argument keeps the shops' one shape, like Buy.run(main).)
static func sell(_main: Node3D, item_id: String, bundles: int) -> bool:
	return trade(BUYS, item_id, bundles)


## One whole exchange of `bundles` bundles on one side, or nothing: checked again first (quote), then the player's part
## is taken, then theirs is given. Buy (market_goods) and sell are its two callers.
static func trade(side: String, item_id: String, bundles: int) -> bool:
	var q: Dictionary = quote(side, item_id, bundles)
	if String(q["reason"]) != "":
		return false
	var units: int = int(q["units"])
	if side == SELLS:
		if not Data.pay(q["price"]):
			return false
		_give_goods(item_id, units)
	else:
		if not _take_goods(item_id, units):
			return false
		var payout: Dictionary = q["payout"]
		for k: Variant in payout:
			Data.give(str(k), int(payout[k]))
	Save.mark_dirty()
	return true


# ---------------------------------------------------------------- words and checks the shops share
## A window word from balance.json windows (Data.word), filled in with args when it has places for them. A missing
## word shows as its key and never breaks (the same as Data.word).
static func say(key: String, args: Array = []) -> String:
	var w: String = Data.word(key)
	if args.is_empty() or not w.contains("%"):
		return w
	return w % args


## Why building id cannot sell anything now: "Needs Market" when it is not built, "Repair Market first" in ruins; ""
## when it stands, and for "" (a thing no building sells).
static func building_reason(building_id: String) -> String:
	if building_id == "":
		return ""
	var nm: String = String(Data.building(building_id).get("name", building_id))
	if Data.station_level(building_id) < 1:
		return say("needs", [nm])
	if Save.ruined.has(building_id):
		return say("build_ruined", [nm])
	return ""


## "Needs 900 leaves, 30 timber": the refusal for a price the player cannot pay yet (the currency ids are their words,
## as in the receipts).
static func short_of(cost: Dictionary) -> String:
	var bits: PackedStringArray = []
	for k: Variant in cost:
		bits.append("%d %s" % [int(cost[k]), str(k)])
	return say("needs", [", ".join(bits)])


## A price can be paid by a shop: every money amount in it is a whole number of at least 1 in a currency the game
## takes, never amber, and never the paid currency unless it buys a look (looks = true). Keys that are not money (a
## note "_...", a gate such as needs_burrows: true) are skipped. {} is well formed (free); anything not a dictionary
## is not (fails closed).
static func price_ok(price: Variant, looks: bool) -> bool:
	if not price is Dictionary:
		return false
	var d: Dictionary = price
	for k: Variant in d:
		var key: String = str(k)
		var v: Variant = d[k]
		var number: bool = v is int or v is float
		if key.begins_with("_") or (not number and not Data.CURRENCIES.has(key)):
			continue                                        # a note or a gate, not money
		if not number or not Data.CURRENCIES.has(key) or Data.MATS.has(key):
			return false
		if key == PAID_CURRENCY and not looks:
			return false
		if float(v) < 1.0 or float(v) != floorf(float(v)):
			return false
	return true


# ---------------------------------------------------------------- inside
## The raw offers of one side, in order: timber's from balance.json trade, then balance.json market[side]. Each is a
## dictionary like a market entry: {"id", "amount", <currency>: <amount>, "after_missions"}.
static func _raw_offers(side: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if side != SELLS and side != BUYS:
		return out
	var trade_block: Dictionary = _dict(Data.b.get("trade"))
	var timber: Dictionary = _dict(trade_block.get("buy" if side == SELLS else "sell"))
	if not timber.is_empty():
		var raw: Dictionary = timber.duplicate()
		raw.erase(TIMBER)
		raw["id"] = TIMBER
		raw["amount"] = timber.get(TIMBER)
		out.append(raw)
	var market: Dictionary = _dict(Data.b.get("market"))
	var list: Variant = market.get(side)
	if list is Array:
		for e: Variant in list:
			if e is Dictionary:
				out.append(e)
	return out


## One offer from a raw entry (see offers), {} when it is malformed: no id, goods Bramble cannot trade, a bundle under 1,
## a money amount that is not a whole number of 0 or more, no money at all, or a "sells" price no shop may ask.
static func _offer_from(side: String, raw: Dictionary) -> Dictionary:
	var item_id: String = raw.get("id") if raw.get("id") is String else ""
	var units: int = _amount(raw.get("amount"))
	if item_id == "" or units < 1 or not _goods_ok(item_id):
		return {}
	var money: Dictionary = {}
	for k: String in Data.CURRENCIES:
		if k == item_id or not raw.has(k):
			continue
		var n: int = _amount(raw[k])
		if n < 0:
			return {}
		if n > 0:
			money[k] = n
	if money.is_empty() or (side == SELLS and not price_ok(money, false)):
		return {}
	var goods: Dictionary = {item_id: units}
	var gated: bool = raw.get("after_missions", false) == true
	return {"id": item_id, "side": side, "units": units, "price": money if side == SELLS else goods,
		"payout": goods if side == SELLS else money, "after_missions": gated, "open": not gated or Data.raids_open()}


## Goods Bramble can trade: timber, or anything the Bag holds (food, fish, potions, amber, pieces). Never shards, never
## leaves.
static func _goods_ok(item_id: String) -> bool:
	return item_id == TIMBER or Bag.kind_of(item_id) != ""


## Why `bundles` bundles of offer o cannot be traded now ("" when they can), given their units and price.
static func _reason(o: Dictionary, bundles: int, units: int, price: Dictionary) -> String:
	var why: String = building_reason(MARKET)
	if why != "":
		return why
	if not bool(o["open"]):
		return say("after_missions")
	if bundles < 1:
		return say("amount", [bundles])
	var item_id: String = String(o["id"])
	if String(o["side"]) == SELLS:
		var room: int = _room(item_id)
		if room >= 0 and units > room:
			return say("bag_full")
		if not Data.can_afford(price):
			return short_of(price)
		return ""
	var stock: int = _stock(item_id)
	if stock < units:
		return say("have_only", [stock])
	return ""


## The most bundles of offer o that can be traded now: buying, what the money and the Bag's room allow; selling, what
## the stock allows. 0 while the Market cannot trade or the offer's gate is shut.
static func _max_bundles(o: Dictionary) -> int:
	if building_reason(MARKET) != "" or not bool(o["open"]):
		return 0
	var item_id: String = String(o["id"])
	var per: int = maxi(1, int(o["units"]))
	if String(o["side"]) == BUYS:
		return _stock(item_id) / per
	var most: int = -1                                      # -1: nothing has bounded it yet
	var price: Dictionary = o["price"]
	for k: Variant in price:
		var each: int = maxi(1, int(price[k]))
		var can: int = maxi(0, Data.have(str(k))) / each
		most = can if most < 0 else mini(most, can)
	var room: int = _room(item_id)
	if room >= 0:
		most = room / per if most < 0 else mini(most, room / per)
	return maxi(0, most)


## How many of item_id the player holds: timber from the purse, the rest from the Bag (amber too).
static func _stock(item_id: String) -> int:
	return Data.have(TIMBER) if item_id == TIMBER else Bag.count(item_id)


## How many more of item_id fit now: -1 for timber (a currency: no limit), else the Bag's room.
static func _room(item_id: String) -> int:
	return -1 if item_id == TIMBER else Bag.room_for(item_id)


## Puts bought goods in: timber into the purse, the rest into the Bag. Forced: the room was checked and they are paid
## for, so all of them always go in.
static func _give_goods(item_id: String, units: int) -> void:
	if item_id == TIMBER:
		Data.give(TIMBER, units)
	else:
		Bag.add(item_id, units, true)


## Takes sold goods out, all or nothing.
static func _take_goods(item_id: String, units: int) -> bool:
	if item_id == TIMBER:
		if Data.have(TIMBER) < units:
			return false
		Data.take(TIMBER, units)
		return true
	return Bag.take(item_id, units)


## Every amount of d times n.
static func _times(d: Variant, n: int) -> Dictionary:
	var out: Dictionary = {}
	if d is Dictionary:
		for k: Variant in d:
			out[k] = int((d as Dictionary)[k]) * n
	return out


## A JSON amount as a whole number of 0 or more; -1 when it is not one (a fraction, below 0, text, missing).
static func _amount(v: Variant) -> int:
	if v is int:
		return v if (v as int) >= 0 else -1
	if v is float and is_finite(v as float) and (v as float) >= 0.0 and (v as float) == floorf(v as float):
		return int(v as float)
	return -1


static func _dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}
