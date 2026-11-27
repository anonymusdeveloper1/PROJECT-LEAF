extends "res://ui/windows/building_window.gd"
## H4: the Wishing Well's window (building and marker "well"). Moved from stations.gd (_card_well, _well_line and the
## Well's part of the upgrade line) in H4 Stage 1. The header shows its level and mending rates. The Well mends the
## camp by itself (stations.well_tick). Stage 2 (P2c) pins Upgrade in the footer. Knocked down: only the ruin card.
## Used by: ui/windows/window_list.gd (hud.windows["well"]), stations.gd (the marker's builder), the tests (spec, _pct).
## Uses: the mending rates in stations.gd (well_between, well_regen: balance.json well.passive), the base's Upgrade footer.


func _init(owner_hud) -> void:
	super(owner_hud, "well", "well")


func spec() -> Dictionary:
	return _card_well()


## What Well level `level` gives: its mending rates.
func gives(level: int) -> Array:
	return [_well_line(level)]


## The standing Well shows its level, mending rates and pinned Upgrade.
func _card_well() -> Dictionary:
	if Save.ruined.has("well"):
		return _ruin_card("well", "Wishing Well", _anchor("well", 1.9))
	var lv := int(Save.stations["well"])
	return {"title": "Wishing Well", "sub": "Level %d · %s" % [lv, _well_line(lv)],
		"rows": [], "anchor": _anchor("well", 1.9), "footer": upgrade_footer()}


## The Well's mending rates at level lv.
func _well_line(lv: int) -> String:
	return "Mends to full · %s/s between waves, %s/s in waves" % [_pct(st.well_between(lv)), _pct(st.well_regen(lv))]
