extends RefCounted
## The card on an empty road pad previews the row the defence rules will build there.

const ROW_KIND := "barricade"

var main: Node3D
var d: Node3D


func _init(owner_hud: CanvasLayer) -> void:
	main = owner_hud.main
	d = main.defences


func spec_for_pad(lane: int, pad: int) -> Dictionary:
	var entry := Data.defence_info(ROW_KIND)
	var levels: Array = entry["levels"]
	var lv := clampi(int(d.new_row_level()), 1, levels.size())
	var stats: Dictionary = d.level_stats(ROW_KIND, lv)
	var why: String = d.pad_reason(lane, pad)
	var cost: Dictionary = d.row_cost()
	var s: Array = main.world.barricade_slot(lane, pad)
	var anchor: Vector3 = s[0] if not s.is_empty() else Vector3.ZERO
	var note := Data.word("defence_pad_preview") % [int(d.pieces_per_row()), roundi(float(stats["hp"]))]
	if why != "":
		note += "\n" + why
	var row := {"kind": "list", "id": ROW_KIND, "icon": String(entry["icon"]), "title": String(entry["name"]),
		"text": note, "cost": cost, "label": Data.word("build"),
		"enabled": why == "" and Data.can_afford(cost), "action": d.build_row.bind(lane, pad)}
	return {"title": Data.word("defence_pad_title"), "sub": Data.word("level_of") % [lv, levels.size()],
		"anchor": anchor, "rows": [row]}
