extends "res://ui/windows/building_window.gd"
## H4: the Training Target's window (building and marker "target"). Moved from stations.gd (_card_target and the
## Target's part of the upgrade line) in H4 Stage 1, looking exactly as before: Patch it up (when raids wore it), the
## "Train" shelf (Damage, Draw speed, Range: stat_list.gd) and its own "Upgrade" tile. Knocked down: only the ruin card.
## Stage 2 (P2b) makes the stats list rows and pins the Upgrade at the bottom.
## Used by: ui/windows/window_list.gd (hud.windows["target"]), stations.gd (the marker's builder; _card_target and
##          _station_upgrade_row("target") for the tests in Stage 1).
## Uses: stat_list.gd, the base's tiles, Data (stat_cap_by_station_level).

const StatList := preload("res://ui/windows/stat_list.gd")


func _init(owner_hud) -> void:
	super(owner_hud, "target", "target")


func spec() -> Dictionary:
	return _card_target()


## What Target level `level` gives: the stat cap it allows, and Range at level 2 (today's words, "Stats up to level 6,
## unlocks Range").
func gives(level: int) -> Array:
	var caps: Array = Data.b["stat_cap_by_station_level"]
	var out: Array = ["Stats up to level %d" % int(caps[clampi(level, 0, caps.size() - 1)])]
	if level == 2:
		out.append("unlocks Range")
	return out


func _card_target() -> Dictionary:
	if Save.ruined.has("target"):
		return _ruin_card("target", "Training Target", _anchor("target", 1.5))
	var rows := _wear_row("target")
	_add_section(rows, "Train", StatList.rows(self, ["damage", "draw", "range"]))
	_add_section(rows, "Upgrade", [upgrade_tile()])
	return {"title": "Training Target", "sub": "Level %d · the cat practises while you stand here" % Save.stations["target"], "rows": rows, "anchor": _anchor("target", 1.5)}
