extends RefCounted
## Cards for a placed tower, patch or row. The defence rules own all changes to those targets.

const Marker := preload("res://scripts/marker.gd")
const NO_SLOT := Vector2i(-1, -1)
const ROW_KIND := "barricade"
const STATS := ["hp", "damage", "every", "range", "dps", "slow"]

var hud: CanvasLayer
var main: Node3D
var d: Node3D


func _init(owner_hud: CanvasLayer) -> void:
	hud = owner_hud
	main = hud.main
	d = main.defences


func spec_for_piece(id: int) -> Dictionary:
	var piece: Dictionary = d.piece_at(id)
	if piece.is_empty():
		return _gone()
	var kind := String(piece["type"])
	var lv: int = d.piece_level(piece)
	var rows: Array = []
	if kind != "spikes":
		rows.append({"text": _health(piece), "small": true})
	elif float(piece["hp"]) < float(piece["max_hp"]):
		var share := float(piece["hp"]) / float(piece["max_hp"])
		rows.append({"text": Data.word("defence_wear") % roundi((1.0 - share) * 100.0), "small": true})
	return _spec(kind, id, NO_SLOT, lv, piece["pos"], rows)


func spec_for_row(lane: int, pad: int) -> Dictionary:
	var row: Dictionary = d.row_at(lane, pad)
	if row.is_empty():
		return _gone()
	var rows: Array = []
	var pieces: Array = row["pieces"]
	for i: int in range(pieces.size()):
		var piece: Dictionary = pieces[i]
		var health := _health(piece)
		var stage: String = d.piece_stage(piece)
		if stage == "cracked" or stage == "broken":
			health += " · " + Data.word("defence_" + stage)
		rows.append({"text": Data.word("defence_section_health") % [i + 1, health], "small": true})
	var root: Node3D = row["root"]
	return _spec(ROW_KIND, -1, Vector2i(lane, pad), int(d.row_level(row)), root.global_position, rows)


func _gone() -> Dictionary:
	return {"title": Data.word("upgrade_gone"), "sub": "", "anchor": Vector3.ZERO, "rows": []}


func _health(piece: Dictionary) -> String:
	return Data.word("defence_health") % [ceili(float(piece["hp"])), roundi(float(piece["max_hp"]))]


func _spec(kind: String, id: int, slot: Vector2i, lv: int, anchor: Vector3, rows: Array) -> Dictionary:
	var entry := Data.defence_info(kind)
	var levels: Array = entry["levels"]
	var title := String(entry["name"])
	var repair: Dictionary = d.repair_quote(kind, id, slot)
	if bool(repair["show"]):
		var repair_cost: Dictionary = repair["price"]
		var repair_reason := String(repair["reason"])
		var label := Data.word("repair")
		rows.append({"kind": "list", "id": "repair", "icon": "repair", "title": label, "label": label,
			"text": Data.word("defence_refill") if repair_reason == "" else repair_reason, "cost": repair_cost,
			"enabled": repair_reason == "" and Data.can_afford(repair_cost), "action": d.repair_placed.bind(kind, id, slot)})
	var spec := {"title": title, "sub": Data.word("level_of") % [lv, levels.size()], "anchor": anchor, "rows": rows}
	var q: Dictionary = d.upgrade_quote(kind, id, slot, lv)
	var next := int(q["next_level"])
	if next <= 0:
		return spec
	rows.append({"kind": "section", "text": Data.word("defence_next_level") % next})
	for line: String in _gains(kind, lv, next):
		rows.append({"text": line, "small": true})
	var why := String(q["reason"])
	spec["footer"] = {"note": why, "cost": q["price"],
		"buttons": [{"label": Data.word("upgrade"), "tone": "green", "enabled": why == "",
			"action": _ask_upgrade.bind(kind, id, slot, lv)}]}
	return spec


func _gains(kind: String, lv: int, next: int) -> Array[String]:
	var now: Dictionary = d.level_stats(kind, lv)
	var later: Dictionary = d.level_stats(kind, next)
	var lines: Array[String] = []
	for stat: String in STATS:
		var before := float(now.get(stat, 0))
		var after := float(later.get(stat, 0))
		if not is_equal_approx(before, after):
			var scale := 100.0 if stat == "slow" else 1.0
			var key := "defence_stat_section_hp" if stat == "hp" and kind == ROW_KIND else "defence_stat_" + stat
			lines.append(Data.word(key) % [String.num(before * scale, 2), String.num(after * scale, 2)])
	return lines


func _ask_upgrade(kind: String, id: int, slot: Vector2i, lv: int) -> void:
	var q: Dictionary = d.upgrade_quote(kind, id, slot, lv)
	var next := int(q["next_level"])
	if next <= 0 or String(q["reason"]) != "":
		return
	var title := Data.word("upgrade_title") % [String(Data.defence_info(kind)["name"]), next]
	var lines := _gains(kind, lv, next)
	lines.append(Data.word("defence_refill"))
	var reason := func() -> String:
		return String(d.upgrade_quote(kind, id, slot, lv)["reason"])
	hud.confirm.ask({"title": title, "lines": lines, "cost": q["price"],
		"on_confirm": d.upgrade_placed.bind(kind, id, slot, lv), "reason": reason, "back": _reopen.bind(kind, id, slot)})


func _reopen(kind: String, id: int, slot: Vector2i) -> void:
	var marker := d.piece_marker(kind, id, slot) as Marker
	if not is_instance_valid(marker):
		hud.hide_card()
	elif marker.is_visible_in_tree() and main.player != null and marker.in_reach(main.player.global_position):
		main.open_ring(marker)
	else:
		hud.show_card(marker)
