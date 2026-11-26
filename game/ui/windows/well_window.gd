extends "res://ui/windows/building_window.gd"
## H4: the Wishing Well's window (building and marker "well"). Moved from stations.gd (_card_well, _well_line and the
## Well's part of the upgrade line) in H4 Stage 1, looking exactly as before: its level and mending rates in the header
## line, and its only row is its upgrade (the Well is never tapped: it mends the camp by itself, stations.well_tick).
## Knocked down: only the ruin card. Stage 2 (P2c) moves the Upgrade into the pinned footer.
## Used by: ui/windows/window_list.gd (hud.windows["well"]), stations.gd (the marker's builder; _card_well and _pct for
##          the tests in Stage 1).
## Uses: the mending rates in stations.gd (well_between, well_regen: balance.json well.passive), the base's tiles.


func _init(owner_hud) -> void:
	super(owner_hud, "well", "well")


func spec() -> Dictionary:
	return _card_well()


## What Well level `level` gives: its mending rates.
func gives(level: int) -> Array:
	return [_well_line(level)]


## The standing Well's only row is its upgrade.
func _card_well() -> Dictionary:
	if Save.ruined.has("well"):
		return _ruin_card("well", "Wishing Well", _anchor("well", 1.9))
	var lv := int(Save.stations["well"])
	return {"title": "Wishing Well", "sub": "Level %d · %s" % [lv, _well_line(lv)],
		"rows": [upgrade_tile()], "anchor": _anchor("well", 1.9)}


## The Well's mending rates at level lv.
func _well_line(lv: int) -> String:
	return "Mends to full · %s/s between waves, %s/s in waves" % [_pct(st.well_between(lv)), _pct(st.well_regen(lv))]
