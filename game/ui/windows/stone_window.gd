extends "res://ui/windows/building_window.gd"
## H4: the Guardian Stone's window (building and marker "stone": the Moss Warden's stone, found in the first Burrow,
## never bought). Moved from stations.gd (_card_stone, _post_note and the stone's part of the upgrade line) in H4 Stage 1.
##   no Warden yet        "The stone is quiet"
##   asleep               "The Moss Warden is asleep" and Wake (stations._wake_warden)
##   awake                its numbers, how it fights, its post (Change: stations._next_post), its looks and Upgrade
## Stage 2 (P2c) pins Upgrade in the footer. Never ruined or worn. H8 gives it tabs.
## Used by: ui/windows/window_list.gd (hud.windows["stone"]), stations.gd (the marker's builder), the tests.
## Uses: Data (the guardian's numbers), main.guardian, the rules in stations.gd (_wake_warden, _next_post, _post_lanes),
##       the base's tiles and looks rows.


func _init(owner_hud) -> void:
	super(owner_hud, "stone", "stone")


func spec() -> Dictionary:
	return _card_stone()


## What stone level `level` gives: the Warden's health and blows at that level (at today's Hearthtree level).
func gives(level: int) -> Array:
	var pw := Data.guardian_power()                 # the next stone level at today's Hearthtree level
	return ["%s: %s health, fists %d, slam %d" % [Data.guardian_name(), _thousands(int(round(Data.pick("guardian", "hp_by_level", level) * pw))),
		int(round(Data.pick("guardian", "fist_damage_by_level", level) * pw)), int(round(Data.pick("guardian", "slam_damage_by_level", level) * pw))]]


func _card_stone() -> Dictionary:
	var anchor := _anchor("stone", 2.0)
	var lv := int(Save.stations.get("stone", 0))
	var sub := "Level %d · the Warden grows with %s too (x%.2f)" % [lv, Data.camp_name(), Data.guardian_power()]
	var g = main.guardian
	if g == null:
		return {"title": "Guardian Stone", "sub": sub, "rows": [{"text": "The stone is quiet", "note": "", "cost": {}, "label": "", "enabled": false, "action": Callable()}], "anchor": anchor}
	if not Save.flag("warden_awake"):
		return {"title": "Guardian Stone", "sub": sub, "rows": [
			{"text": "The %s is asleep" % Data.guardian_name(), "note": "An old guardian of mossy stone. Wake it and it guards your camp",
				"cost": {}, "label": "Wake", "enabled": true, "pulse": true, "action": st._wake_warden}], "anchor": anchor}
	var rows: Array = []
	rows.append({"text": "%s · level %d" % [Data.guardian_name(), lv], "note": "%s health · fists %d · ground slam %d" % [
		_thousands(int(round(Data.guardian_max_hp()))), int(round(Data.guardian_fist())), int(round(Data.guardian_slam()))],
		"cost": {}, "label": "", "enabled": false, "action": Callable()})
	rows.append({"text": "How it fights", "note": "Goes for whatever attacks your buildings, barricades or campfire · too slow for fliers and thieves · stand by it to help it up",
		"cost": {}, "label": "", "enabled": false, "action": Callable()})
	rows.append({"text": "Post: %s" % g.post_text(Save.guardian_post), "note": _post_note(), "cost": {}, "label": "Change", "enabled": true, "action": st._next_post})
	var looks: Array = []
	if (Data.b["looks"]["guardian"] as Array).size() > 1:
		looks = _look_tiles("guardian", "guardian", "Your guardian now", "Same strength, a new look")
	looks.append(_skin_row("guardian"))
	_add_section(rows, "Looks", looks)
	return {"title": "Guardian Stone", "sub": sub, "rows": rows, "anchor": anchor, "footer": upgrade_footer()}


func _post_note() -> String:
	var lanes: Array = st._post_lanes()
	var names: Array = lanes.map(func(ln): return String(Data.patch(int(ln))["name"]))
	var p := Save.guardian_post
	var note := "Goes where the fight is, all round the camp" if p < 0 else "Stays at that trail's mouth; the rest of the camp is yours"
	note += " · next raid: %s" % ", ".join(names)
	if p >= 0 and not lanes.has(p):
		note += " (not that trail: it guards the camp then)"
	return note
