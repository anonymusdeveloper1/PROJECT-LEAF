extends RefCounted
## H5 (Stage 2): the Market's Sells and Buys tabs (ui/windows/market_window.gd; the owner's pictures 2 and 3, the H5
## map parts 1 and 3.4). It is the card's window row on those two tabs ({"kind": "window"}, card.gd), with the window
## API: content() on every rebuild, tick(d) every frame, opened() and closed() once per visit.
##   Sells   what Bramble sells: a grid of big pictures (ui/kit/icon_grid.gd), each with only its price for one bundle
##           under it (red where the cat has too few), no name and no button. Timber first, then the food.
##   Buys    what Bramble buys: the same grid, each with what he PAYS for one bundle (a neutral line, never red):
##           timber, the Golden Carp, and amber once every Raid Mission is won (until then amber is not shown, as before).
## A cell is grey when one bundle cannot be traded now for a reason other than money (the Bag is full, nothing to sell).
## A tap on a picture opens the trade popup (ui/kit/item_popup.gd) in this same window: the picture again, its name,
## what it is for, the amount with - and + (whole bundles), what you pay and what you get, why not when it can't, then
## Back and the one action (Buy or Sell, one tap). Bramble never buys Gloom shards (scripts/market_trade.gd).
## The trade itself is the rule stations.market_trade(side, id, bundles) (the Buy command "market_goods" for buying,
## MarketTrade.sell for selling, then the save, the sparkle at the Market, the camp's refresh and the receipt toast).
## It is bound by side and the offer's id, never by a place in the grid.
## Used by: ui/windows/market_window.gd (trade), the tests (entries, inspect, trade, popup).
## Uses: scripts/market_trade.gd (offers, offer, quote), stations.gd (market_trade), ui/kit/icon_grid.gd,
##       ui/kit/item_popup.gd, market_words.gd, Bag (names, pictures, what a thing is for), Data.

const ItemPopup := preload("res://ui/kit/item_popup.gd")
const IconGrid := preload("res://ui/kit/icon_grid.gd")
const MarketTrade := preload("res://scripts/market_trade.gd")
const Words := preload("res://ui/windows/market_words.gd")

var hud                                 # the HUD node (untyped on purpose, as in the HUD's parts)
var main
var st                                  # main.stations: the trade's rule lives there
var _market: WeakRef                    # the Market's window (weak: it holds this tab)
var popup: ItemPopup                    # the trade popup; open while a trade is looked at


func _init(market) -> void:
	_market = weakref(market)
	hud = market.hud
	main = market.main
	st = market.st
	popup = ItemPopup.new(hud)


## The side the Market's window shows now: "sells" or "buys" (Bramble's side; MarketTrade.SELLS / BUYS).
func side() -> String:
	var m = _market.get_ref()
	var t := String(m.tab) if m != null else ""
	return t if t == MarketTrade.BUYS else MarketTrade.SELLS


## The grid's cells of one side, in the offers' order (timber first): {"id", "side", "title" (not drawn: the cell's
## accessible name), "icon", "units" (in one bundle), "show_title": false, "cost" (Sells: the price of one bundle) or
## "payout" (Buys: what one bundle pays), "grey", "reason" (why one bundle can't be traded now, "" when it can)}.
## An offer whose mission gate is shut (amber before the Raid Missions are won) is left out.
func entries(s: String) -> Array:
	var out: Array = []
	for o: Dictionary in MarketTrade.offers(s):
		if not bool(o["open"]):
			continue
		var item_id := String(o["id"])
		var one: Dictionary = MarketTrade.quote(s, item_id, 1)
		var why := String(one["reason"])
		var short := why != "" and s == MarketTrade.SELLS and not Data.can_afford(o["price"] as Dictionary)
		var cell := {"id": item_id, "side": s, "title": name_of(item_id, int(o["units"])), "icon": icon_of(item_id),
			"units": int(o["units"]), "show_title": false, "grey": why != "" and not short, "reason": why}
		if s == MarketTrade.SELLS:
			cell["cost"] = (o["price"] as Dictionary).duplicate()
		else:
			cell["payout"] = (o["payout"] as Dictionary).duplicate()
		out.append(cell)
	return out


## Opens the trade popup for offer item_id of side s (from 1 bundle). false when there is no such open offer.
func inspect(s: String, item_id: String) -> bool:
	var o: Dictionary = MarketTrade.offer(s, item_id)
	if o.is_empty() or not bool(o["open"]):
		return false
	var units := int(o["units"])
	var selling := s == MarketTrade.SELLS
	popup.open_item({"id": item_id, "title": Words.title_case(name_of(item_id, units)), "desc": desc_of(item_id),
		"icon": icon_of(item_id), "label": Words.say("buy" if selling else "sell"), "tone": "green",
		"quote": _quote_of.bind(s, item_id), "act": _trade_of.bind(s, item_id)})
	return true


## The popup's quote: bundles first (the popup's own argument), then the side and the id bound to it.
func _quote_of(bundles: int, s: String, item_id: String) -> Dictionary:
	return MarketTrade.quote(s, item_id, bundles)


## The popup's action, bound the same way.
func _trade_of(bundles: int, s: String, item_id: String) -> bool:
	return trade(s, item_id, bundles)


## Closes the popup (the grid shows again on the next rebuild).
func reset() -> void:
	popup.close()


func is_open() -> bool:
	return popup.is_open()


# ---------------------------------------------------------------- the window API (the card calls these)
## The popup while a trade is looked at, else the grid of the side the window shows.
func content() -> Control:
	if popup.is_open():
		return popup.content()
	var s := side()
	var cells := entries(s)
	if cells.is_empty():
		var l := Label.new()
		l.text = Words.say("market_empty")
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", 22)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return l
	var grid := IconGrid.make(hud, cells, _on_cell)
	grid.set_meta("trade_grid", s)
	return grid


func tick(delta: float) -> void:
	popup.tick(delta)                                   # the HUD ticks only the card's window: the popup's numbers


func opened() -> void:
	popup.opened()


## The visit ends (the X, a tap outside, another card, another tab's window): the popup closes.
func closed() -> void:
	popup.closed()


# ---------------------------------------------------------------- the trade itself
## A tap on a cell: its trade popup, from the top of the card.
func _on_cell(item_id: String) -> void:
	if inspect(side(), item_id):
		hud.refresh_card()


## Trades `bundles` bundles of item_id on side s through the rule (stations.market_trade: the whole exchange or nothing,
## then the save, the sparkle, the camp's refresh and the receipt toast). true when it went through; when it was
## refused nothing changed, and the popup's reason line (MarketTrade.quote) already says why.
func trade(s: String, item_id: String, bundles: int) -> bool:
	return bool(st.market_trade(s, item_id, bundles))


# ---------------------------------------------------------------- names and pictures
## What n of item_id is called: timber its word, the rest the Bag's name ("Sunberries", "Golden Carp", "amber").
static func name_of(item_id: String, n: int) -> String:
	return Words.say("timber_name") if item_id == MarketTrade.TIMBER else Bag.name_of(item_id, n)


## Its picture's id: timber's own, the rest the Bag's.
static func icon_of(item_id: String) -> String:
	return MarketTrade.TIMBER if item_id == MarketTrade.TIMBER else Bag.icon(item_id)


## What it is for (the popup's line): timber's word, the rest the Bag's ("For cooking at the pot.").
static func desc_of(item_id: String) -> String:
	return Words.say("timber_desc") if item_id == MarketTrade.TIMBER else Bag.desc(item_id)
