extends RefCounted
## H4: the Hearthtree's Defences tab: mending what a raid or a camp fall left broken, then for each kind (barricade,
## tower, spikes) its pieces to buy into the Bag (towers and spikes: barricade rows are built at the road spots,
## defences.gd) and its next level (the barricade level raises every row's health). The whole of the old Defences shelf
## (the owner keeps everything: until H6's Defence Workshop this is the only place that sells towers and spikes), as
## list rows (ui/kit/list_row.gd) with the shelf's words, prices and buttons: Mend, Buy and Upgrade stay one tap (no
## confirm, the owner's answer of 26 Nov 2026). Static functions only; the window is passed in (`w`, the Hearthtree's
## window: ui/windows/hearthtree_window.gd), because a row is made by its list_row (its `enabled` includes the price)
## and needs the defences (w.main.defences) and the rules (w.st._mend_raid, _buy_piece, _def_cost, _upgrade_defence).
## Moved from stations.gd (_defence_tiles and its helpers) in H4 Stage 1; list rows and its own tab in Stage 2. H6 lifts
## it into the Defence Workshop's window.
## Used by: ui/windows/hearthtree_window.gd (the tab, whether it shows, its goals' row titles, the confirm's defences
##          line), stations._defence_tiles (the old name the tests call until H4 Stage 3).
## Uses: Data (defence_info, def_kind_name, raids_open, burrows_open, camp_name, mats_line), Save.camp_level, Bag.

## The kinds the tab sells and levels, in its order (the old shelf's list; the fence is not sold here).
const KINDS := ["barricade", "tower", "spikes"]


## The tab shows once it has something: a kind is open (its unlock_missions are won) or a piece is broken.
static func shown(w) -> bool:
	if int(w.main.defences.wrecked_count()) > 0:
		return true
	for type: String in KINDS:
		if bool(w.main.defences.unlocked(type)):
			return true
	return false


## The Defences tab's rows (see the top of this file). Row ids: "mend", the kind (its Buy row), "<kind>_level".
static func rows(w) -> Array:
	var out: Array = []
	var lv := Save.camp_level
	# defences kept damaged after a Gloom Raid or a camp fall
	var wrecked: int = w.main.defences.wrecked_count()
	if wrecked > 0:
		out.append(w.list_row("repair", "Mend the defences", "%d defence piece%s broken or damaged" % [wrecked, "s" if wrecked > 1 else ""],
			{"leaves": w.main.defences.repair_cost()}, "Mend", true, w.st._mend_raid, "", "mend"))
	for type: String in KINDS:
		var di := Data.defence_info(type)
		if not w.main.defences.unlocked(type):
			continue
		if type != "barricade":
			var have := Bag.count(type)
			var note := "%d in the Bag · place it from the Bag" % have if have > 0 else _def_note(type)
			var room: bool = w.main.defences.room_for(type)
			var bag_room := Bag.room_for(type) > 0              # H3: a piece bought goes into the Bag (refused when full)
			if not room:
				note = w.main.defences.room_note(type)
			elif not bag_room:
				note = "Bag full"
			out.append(w.list_row(type, String(di["name"]), note, {"leaves": int(di["piece"])}, "Buy", room and bag_room,
				w.st._buy_piece.bind(type), ("%d to place" % have) if have > 0 else "", type))
		var dl: int = w.main.defences.level(type)
		var dlevels: Array = di["levels"]
		var shown_top := _def_shown_top(type)
		# level 4 (Shardstone) once raids are open; level 5 (Phase E: Heartwood, Amber) once the Burrows are open
		if dl < shown_top:
			var ok := dl + 1 <= lv
			var lnote := _def_level_note(type, dl + 1) if ok else "Needs %s at level %d" % [Data.camp_name(), dl + 1]
			var dcost: Dictionary = w.st._def_cost(type, dl + 1)
			if ok and dl + 1 == 4:
				lnote += " · set with Gloom shards"
			elif ok and dl + 1 >= 5:
				lnote += Data.mats_line(dcost)
			out.append(w.list_row(type, _def_level_title(type, dl + 1), lnote, dcost, "Upgrade", ok, w.st._upgrade_defence.bind(type),
				"Level %d/%d" % [dl, dlevels.size()], type + "_level"))
	return out


## The highest defence level on offer now: 3, then 4 (Shardstone) once raids are open, 5 once the Burrows are open.
static func _def_shown_top(type: String) -> int:
	var n := (Data.defence_info(type)["levels"] as Array).size()
	if not Data.raids_open():
		n = mini(n, 3)
	elif not Data.burrows_open():
		n = mini(n, 4)
	return n


## The highest level any kind of the tab is offered at now (the Hearthtree's confirm says "Defences up to level N" only
## up to it).
static func top_shown() -> int:
	var top := 0
	for type: String in KINDS:
		top = maxi(top, _def_shown_top(type))
	return top


## "Barricades level 2", "Towers level 3", "Thorn Spikes: Shardstone" (levels 4 and 5 have names).
static func _def_level_title(type: String, lv: int) -> String:
	var dlevels: Array = Data.defence_info(type)["levels"]
	var kind := Data.def_kind_name(type)
	if lv >= 4 and lv <= dlevels.size() and dlevels[lv - 1].has("name"):
		return "%s: %s" % [kind, String(dlevels[lv - 1]["name"])]
	return "%s level %d" % [kind, lv]


static func _def_note(type: String) -> String:
	match type:
		"barricade": return "Blocks a road at one of its glowing spots: enemies must break it"
		"tower": return "Shoots acorns at enemies near it"
		"spikes": return "Hurts and slows enemies that walk over it"
	return ""


static func _def_level_note(type: String, lv: int) -> String:
	var l: Dictionary = Data.defence_info(type)["levels"][lv - 1]
	match type:
		"barricade": return "%d health each" % int(l["hp"])
		"tower": return "360° · %d damage · %.1fm\nEvery %.2fs · %d health" % [int(l["damage"]), float(l["range"]), float(l["every"]), int(l.get("hp", 0))]
		"spikes": return "%d damage a second, slows more" % int(l["dps"])
	return ""
