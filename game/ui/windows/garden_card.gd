extends "res://ui/windows/building_window.gd"
## H4: the garden's card (building and marker "garden", mission 1's gift). Moved from stations.gd (_card_garden and the
## garden's part of the upgrade line) in H4 Stage 1. H3: the card holds the garden's window (ui/windows/garden_window.gd,
## hud.garden_window: the plots as on the bed, the seeds, Water). Stage 2 (P2c) pins Upgrade in the footer.
## Neither holds rules: planting, watering and picking are garden.gd's, and the crops grow in real time (Timers). The
## stable view_id keeps a leaf pickup or a save from rebuilding the window under a drag; the marker's "!" comes through
## the window row's "pulse" (garden.wants_pulse) or the footer. A wave blanks it, as every station card (card.gd _spec).
## Used by: ui/windows/window_list.gd (hud.windows["garden"]), stations.gd (the marker's builder; _card_garden for the
##          tests in Stage 1).
## Uses: hud.garden_window, main.garden (wants_pulse), Data (garden_level, garden_plots, the garden table).


func _init(owner_hud) -> void:
	super(owner_hud, "garden", "garden")


func spec() -> Dictionary:
	return _card_garden()


## What garden level `level` gives: its plots, how long watering lasts and the extra on every harvest (H3: watering is
## timed, balance.json garden.water_s_by_level, seconds).
func gives(level: int) -> Array:
	var out: Array = ["%d plots" % int(Data.pick("garden", "plots_by_level", level)),
		"water lasts %s min" % _short_num(Data.pick("garden", "water_s_by_level", level) / 60.0)]
	if int(Data.pick("garden", "extra_by_level", level)) > 0:
		out.append("+%d on every harvest" % int(Data.pick("garden", "extra_by_level", level)))
	return out


func _card_garden() -> Dictionary:
	var anchor := _anchor("garden", 1.2)
	var lv := Data.garden_level()
	var sub := "Level %d · %d plots" % [lv, Data.garden_plots()]
	var g = main.garden
	if g == null or main.hud == null or main.hud.garden_window == null:
		return {"title": "Garden", "sub": sub, "rows": [], "anchor": anchor, "footer": upgrade_footer()}
	var wants: bool = bool(g.wants_pulse())
	var rows: Array = [{"kind": "window", "window": main.hud.garden_window, "enabled": true, "pulse": wants}]
	return {"title": "Garden", "sub": sub, "rows": rows, "anchor": anchor, "view_id": "garden", "footer": upgrade_footer()}
