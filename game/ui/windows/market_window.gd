extends "res://ui/windows/building_window.gd"
## H5 (Stage 2, 27 Nov 2026): the Market's window (building and marker "stall": the old Market Stall's ids). The owner's
## words (Phase H plan, the H5 map part 1, pictures 2 and 3): four picture buttons along the bottom, in the order Sells,
## Buys, Mounts, Pets (icons only; each keeps its word from balance.json windows as its name), no Upgrade and no levels
## (the owner's Q5 A: a one-level building). A visit always opens on Sells, unless a Hearthtree goal's Go asked for
## another tab (open_on). Knocked down: only the ruin card (Repair), as every building.
##   Sells     what Bramble sells (market_trade_tab.gd): big pictures with their price; a tap opens the trade popup
##             (name, what it is for, the amount, what you pay and get, Buy). "Patch it up" sits over the grid when raids
##             wore the Market.
##   Buys      what Bramble buys (market_trade_tab.gd): big pictures with what he pays (never red); a tap opens the popup
##             with Sell. He buys timber, the Golden Carp and, after the Raid Missions, amber (1,000 leaves and a shard),
##             never Gloom shards.
##   Mounts    (market_companions.gd) Ride/Walk, the mounts' whole pictures (Thistle and Bramblewool come with the
##             Market), their colours, Gloomlit colours and the mount's expedition gear.
##   Pets      (market_companions.gd) the pet's training (the one shared pet level: the old Mushroom Cottage's prices and
##             its Hearthtree cap), the pets' whole pictures (Sprig 160 leaves brings the pet; Lumi, looks only, 400
##             leaves once the pet is owned), their colours, Gloomlit colours and the pet's expedition gear.
## A tab shows the small "!" dot while something on it can be bought now (Sells: Patch it up; Mounts and Pets: a Buy,
## Train, a Gloomlit colour or gear they can pay for); everyday trades, Use, Ride and Next are quiet. The marker's "!"
## is any tab's dot.
## The window only builds rows. Every action is a rule in stations.gd, called as st.<name> (market_trade, _use_look,
## _buy_companion, _train_pet, _next_skin, _unlock_skin, _buy_attach, _wear), which runs the Buy command
## (commands/buy.gd), MarketTrade or CompanionShop and then saves, gives the receipt and refreshes the camp. The window
## asks the Buy command's can_run and MarketTrade.quote only to draw a button on or off and to say why not.
## Used by: ui/windows/window_list.gd (hud.windows["stall"]), stations.gd (the marker's builder and its "!"), the
##          Hearthtree's goals (open_on("pets") before a Go), the tests (select, tab_ids, tab_spec, entries, inspect,
##          back, open_on, pulse, trade, companions).
## Uses: market_trade_tab.gd, market_companions.gd, market_words.gd, the base's rows (list_row, as_list, _wear_row,
##       _ruin_card, _lights), Data, Save, the card (hud: card_ring, refresh_card, the card's scroll).

const MarketTradeTab := preload("res://ui/windows/market_trade_tab.gd")
const MarketCompanions := preload("res://ui/windows/market_companions.gd")
const Words := preload("res://ui/windows/market_words.gd")

const TABS := ["sells", "buys", "mounts", "pets"]      # the bottom tabs, in their order (the H5 map part 3.4)
## Each tab's picture: an icon id (ui_icons.gd, hud_icons.gd), or for Mounts and Pets the first look's whole picture
## when it is there (TAB_PICTURE: its content kind).
const TAB_ICONS := {"sells": "market", "buys": "leaves", "mounts": "mount", "pets": "pet"}
const TAB_PICTURE := {"mounts": "mounts", "pets": "pets"}
const OPEN_ON_S := 30.0                 # a Go's tab request waits this long for the visit it was made for
const ANCHOR_H := 2.4                   # the card's anchor over the Market (as before)

var tab := "sells"                      # the tab showing: "sells", "buys", "mounts" or "pets"
var trade: MarketTradeTab               # the Sells and Buys tabs (their grid and the trade popup)
var companions: MarketCompanions        # the Mounts and Pets tabs (their rows, grid and detail view)
var _want_tab := ""                     # open_on's request for the next visit ("" = none)
var _want_until := 0                    # ... until this time (Time.get_ticks_msec)


func _init(owner_hud) -> void:
	super(owner_hud, "stall", "stall")
	trade = MarketTradeTab.new(self)
	companions = MarketCompanions.new(self)


func spec() -> Dictionary:
	return tab_spec(tab)


## The card as if tab `t` were selected (nothing changes): the ruin card while the Market is in ruins; else its name and
## line, the tab's rows and the four bottom tabs (with their "!" dots). No footer: the Market has no Upgrade.
func tab_spec(t: String) -> Dictionary:
	var title: String = st._name(id)
	var anchor := _anchor(id, ANCHOR_H)
	if Save.ruined.has(id):
		return _ruin_card(id, title, anchor)
	var showing := t if TABS.has(t) else "sells"
	var tabs: Array = []
	for tid: String in TABS:
		tabs.append({"id": tid, "text": "", "name": _w("tab_" + tid), "icon": _tab_icon(tid), "selected": tid == showing,
			"enabled": true, "action": select.bind(tid), "dot": tab_lights(tid)})
	return {"title": title, "sub": Words.say("market_sub") % Data.mount_name(), "rows": _tab_rows(showing), "tabs": tabs,
		"tabs_at": "bottom", "anchor": anchor}


## A tab's rows (no tab bar). Sells and Buys: Patch it up (Sells only, when worn) over the trade grid, or the trade
## popup alone; Mounts and Pets: the companions' rows (market_companions.gd).
func _tab_rows(t: String) -> Array:
	match t:
		"mounts":
			return companions.rows("mount")
		"pets":
			return companions.rows("pet")
	var me := {"kind": "window", "window": trade, "enabled": true}
	if trade.is_open():
		return [me]
	var rows: Array = as_list(_wear_row(id)) if t == "sells" else []
	rows.append(me)
	return rows


## A tab has something that can be bought now: its "!" dot.
func tab_lights(t: String) -> bool:
	match t:
		"sells":
			for r: Variant in as_list(_wear_row(id)):
				if _lights(r):
					return true
			return false
		"mounts":
			return companions.lights("mount")
		"pets":
			return companions.lights("pet")
	return false                                         # Buys: everyday trades are quiet


## The marker's "!": any tab's dot. In ruins: the ruin card's Repair, as on every building.
func pulse() -> bool:
	if Save.ruined.has(id):
		return super.pulse()
	for tid: String in TABS:
		if tab_lights(tid):
			return true
	return false


## The Market has one level (the owner's Q5 A): nothing to give.
func gives(_level: int) -> Array:
	return []


# ---------------------------------------------------------------- tabs, visits and looking at one thing
## The tabs, in their order (all four always show).
func tab_ids() -> Array:
	return TABS.duplicate()


## A tap on a tab: that tab shows, from its top, on its grid (a popup or a detail view closes).
func select(t: String) -> void:
	if not TABS.has(t):
		return
	tab = t
	trade.reset()
	companions.reset()
	_redraw(true)


## The Hearthtree's Go (a pet goal: the Pets tab): the next visit opens on tab `t` instead of Sells; when the Market's
## card is open already it switches now. It opens no card and walks nowhere: call it just before the walk to the
## marker (main.interact.use, main.open_ring). A request older than OPEN_ON_S is forgotten.
func open_on(t: String) -> void:
	if not TABS.has(t):
		return
	if hud != null and ring() != null and hud.card_ring() == ring():
		select(t)
		return
	_want_tab = t
	_want_until = Time.get_ticks_msec() + int(OPEN_ON_S * 1000.0)


## A visit starts: on Sells (or the tab open_on asked for), on its grid.
func card_opened() -> void:
	tab = "sells"
	if _want_tab != "" and Time.get_ticks_msec() <= _want_until:
		tab = _want_tab
	_want_tab = ""
	trade.reset()
	companions.reset()


## The visit ends: the popup and the detail view close (their windows hear closed() too).
func card_closed() -> void:
	trade.reset()
	companions.reset()


## What a tab shows (the tests read it): Sells and Buys their trade cells (market_trade_tab.gd entries), Mounts and
## Pets their look cells (market_companions.gd entries).
func entries(t: String) -> Array:
	match t:
		"sells", "buys":
			return trade.entries(t)
		"mounts":
			return companions.entries("mount")
		"pets":
			return companions.entries("pet")
	return []


## Looks at one thing of the tab showing: on Sells or Buys its trade popup, on Mounts or Pets its detail view. false
## when the tab has no such thing.
func inspect(item_id: String) -> bool:
	var ok := false
	match tab:
		"sells", "buys":
			ok = trade.inspect(tab, item_id)
		"mounts":
			ok = companions.inspect("mount", item_id)
		"pets":
			ok = companions.inspect("pet", item_id)
	if ok:
		_redraw(true)
	return ok


## Back from the popup or the detail view to the tab's grid.
func back() -> void:
	trade.reset()
	companions.reset()
	_redraw(false)


## Redraws the Market's card when it is the one open (from its top when asked).
func _redraw(to_top: bool) -> void:
	if hud == null or ring() == null or hud.card_ring() != ring():
		return
	if to_top and hud._card_scroll != null and is_instance_valid(hud._card_scroll):
		hud._card_scroll.scroll_vertical = 0
	hud.refresh_card()


## A tab's picture: Mounts and Pets show their first look's whole picture when it is there, else the icon.
func _tab_icon(t: String) -> Variant:
	var kind := String(TAB_PICTURE.get(t, ""))
	if kind != "":
		var looks: Array[Dictionary] = Data.shop_entries(kind)
		if not looks.is_empty():
			var tex: Texture2D = hud.p_icons._picture(Data.shop_picture(kind, String(looks[0]["id"]))) if hud != null else null
			if tex != null:
				return tex
	return String(TAB_ICONS.get(t, t))
