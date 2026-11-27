extends "res://ui/windows/building_window.gd"
## H4: the Fishing Spot's window (building and marker "fishing", mission 6's gift: a building with a save entry and a
## content folder, one level). Moved from stations.gd (_card_fishing) in H4 Stage 1, looking exactly as before: Cast a
## line (stations._cast, a rule: it stays there), the fish log and the lake treasures.
## Used by: ui/windows/window_list.gd (hud.windows["fishing"]), stations.gd (the marker's builder).
## Uses: main.fishing (can_fish, log_found), main.player (riding), Data (balance.json fishing, the mount's name), Bag,
##       Save (fish_log, flags).


func _init(owner_hud) -> void:
	super(owner_hud, "fishing", "fishing")


func spec() -> Dictionary:
	return _card_fishing()


func _card_fishing() -> Dictionary:
	var anchor := _anchor("fishing", 1.6)
	var fsh = main.fishing
	var sub := "Calm water · fish for the pot and the mount · %d fish in the Bag" % Bag.count("fish")
	if fsh == null:
		return {"title": "Fishing Spot", "sub": sub, "rows": [], "anchor": anchor}
	var rows: Array = []
	var riding: bool = main.player.riding
	rows.append({"text": "Cast a line", "note": ("Get off %s to fish" % Data.mount_name()) if riding else "Tap anywhere when the float dips · drag to stop",
		"cost": {}, "label": "Cast", "enabled": fsh.can_fish(), "action": st._cast})
	var cfg: Dictionary = Data.b["fishing"]
	var bits: Array = []
	for e in cfg["catches"]:
		var n := int(Save.fish_log.get(String(e["id"]), 0))
		bits.append("%s %d" % [String(e["name"]), n] if n > 0 else "?")
	rows.append({"text": "Fish log · %d of %d found" % [fsh.log_found(), (cfg["catches"] as Array).size()], "note": " · ".join(bits),
		"cost": {}, "label": "", "enabled": false, "action": Callable()})
	var found := 0
	var tb: Array = []
	for tr in cfg["treasures"]:
		if Save.flag(String(tr["id"])):
			found += 1
			tb.append("%s: %s" % [String(tr["name"]), String(tr["says"])])
		else:
			tb.append("?")
	rows.append({"text": "Lake treasures · %d of %d" % [found, (cfg["treasures"] as Array).size()], "note": " · ".join(tb),
		"cost": {}, "label": "", "enabled": false, "action": Callable()})
	return {"title": "Fishing Spot", "sub": sub, "rows": rows, "anchor": anchor}
