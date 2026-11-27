extends RefCounted
## The Defence Workshop's rules (H6, moved here from stations.gd in Stage 3; no player-visible change). Static functions
## only; it keeps no state. No class_name: preload it, const WorkshopRules := preload("res://scripts/workshop_rules.gd").
## stations.gd keeps one-line entry points with the old names (workshop_reason, workshop_upgrade_reason,
## upgrade_workshop, buy_specialisation) and calls build / model / tint itself, so no caller changed. `st` below is
## the stations node (main.stations): the rules reach its _locked, _name, _upgrade_station, full_hp, refresh and hp.
## Used by: stations.gd (and through it the Workshop window, the Buy command, defence_levels.gd and the tests).
## Uses: Data, Save, Events, Props, commands/buy.gd, scripts/market_trade.gd.

const Buy := preload("res://commands/buy.gd")
const MarketTrade := preload("res://scripts/market_trade.gd")


## The Workshop's model: its entry's `model` (defence_workshop) once the file is in the game, else the stand-in of its
## layout (a warm-tinted Bow Bench, see tint). One model at every level.
static func model() -> String:
	var own := String(Data.building("workshop").get("model", "defence_workshop"))
	if own != "" and Props.has(own):
		return own
	return String((Data.building_layout("workshop").get("stand_in", {}) as Dictionary).get("model", "bow_bench_1"))


## The stand-in's tint (its layout.stand_in.tint); white (none) on the owner's own model.
static func tint() -> Color:
	var own := String(Data.building("workshop").get("model", "defence_workshop"))
	if own != "" and Props.has(own):
		return Color(1, 1, 1)
	return Color.html(String((Data.building_layout("workshop").get("stand_in", {}) as Dictionary).get("tint", "#C99A5B")))


## Builds the Defence Workshop. Checks first (unlocked, not built, above ground, no wave, the fire and the Hearthtree
## standing) and the money, then sends any held piece standing on its ground back to the Bag (defences.
## return_blocked_for_station; a safety net, the boot already moves them) before paying, so a refused build changes
## nothing. One notice tells how many went back.
static func build(st) -> void:
	var main = st.main
	if not Data.station_open("workshop") or int(Save.stations.get("workshop", 0)) > 0 or main.area != null or st._locked() \
			or Save.fire_ruined or Save.ruined.has("home"):
		return
	var price: Dictionary = Data.build_price("workshop")
	if not Data.can_afford(price):
		return
	var back: int = main.defences.return_blocked_for_station("workshop")
	Data.pay(price)                            # cannot fail now: the money was checked above
	Save.stations["workshop"] = 1
	if main.fight.active:
		st.hp["workshop"] = st.full_hp("workshop")
	Save.save_game()
	Events.building_upgraded.emit("workshop", 1)
	st.refresh("workshop", true)               # it rises out of the ground (the build menu's camera shows it)
	main.on_purchase()
	main.hud.banner("%s built!" % st._name("workshop"), Color(1.0, 0.85, 0.5), Data.word("workshop_built_sub"))
	if back > 0:
		main.hud.toast(Data.word("workshop_returned") % back)


## Why the Defence Workshop cannot sell or improve anything now: not built or in ruins (MarketTrade.building_reason),
## below ground, or a wave on. "" when it serves.
static func reason(st) -> String:
	var why: String = MarketTrade.building_reason("workshop")
	if why != "":
		return why
	if st.main.area != null:
		return Data.word("workshop_below")
	if st._locked():
		return Data.word("workshop_wave")
	return ""


## Why the Workshop's own Upgrade cannot happen now (expected_level is the level its window showed): "" when it can.
## Money is never a reason (the confirm shows the price in red).
static func upgrade_reason(st, expected_level: int) -> String:
	var why: String = reason(st)
	if why != "":
		return why
	var lv: int = Data.station_level("workshop")
	if expected_level != lv:
		return Data.word("upgrade_stale")
	var levels: Array = Data.building_levels("workshop")
	var next: int = lv + 1
	if next > levels.size():
		return Data.word("max")
	if next > Save.camp_level:
		return MarketTrade.say("needs_home", [Data.camp_name(), next])
	var entry: Dictionary = levels[lv]
	if bool(entry.get("needs_burrows", false)) and not Data.burrows_open():
		return Data.word("needs_burrows")
	if bool(entry.get("needs_raids", false)) and not Data.raids_open():
		return Data.word("needs_raids")
	return ""


## The Workshop's Upgrade (its window's confirm): rechecks the reason, then the usual building upgrade (_upgrade_station:
## the Hearthtree's cap, the price, the save, the event). True when its level moved.
static func upgrade(st, expected_level: int) -> bool:
	if upgrade_reason(st, expected_level) != "":
		return false
	var before: int = Data.station_level("workshop")
	st._upgrade_station("workshop")
	return Data.station_level("workshop") > before


## Learns or upgrades a specialisation at the Workshop (Buy kind "specialisations": exact id, shown level, price), then
## saves and refreshes the placed pieces it changes. True when it was bought.
static func buy_specialisation(st, id: String, expected_level: int) -> bool:
	var main = st.main
	if not Buy.new("specialisations", id, 1, expected_level).run(main):
		return false
	Save.save_game()
	main.defences.refresh_specialisation(id)
	main.on_purchase()
	return true
