extends "res://ui/windows/building_window.gd"
## H4: the Training Target's window (building and marker "target"). The plan: "the Training Target is a short list:
## Damage, Draw speed and Range, each row with its picture, its level, what the next level gives and one button.
## Upgrade is at the bottom."
##   rows     "Patch it up" (only when raids wore it: the base's _wear_row, as a list row), then one list row per stat
##            the Target trains (stat_list.gd: "Next: +12% · now +36%", Buy); Range shows Locked until Target level 2
##   footer   the pinned Upgrade (the base's upgrade_footer: "Level 1 of 5" and the next level's price; it asks first in
##            the confirm window, which lists gives())
## Knocked down: only the ruin card (Repair). The owner's answer (26 Nov 2026, Q9): Patch it up and the ruin view stay.
## Moved from stations.gd (_card_target and the Target's part of the upgrade line) in H4 Stage 1; list rows and the
## pinned Upgrade since Stage 2 (P2b).
## Used by: ui/windows/window_list.gd (hud.windows["target"]), stations.gd (the marker's builder and its "!"; the old
##          tests' _card_target and _station_upgrade_row("target") until Stage 3), the tests.
## Uses: stat_list.gd, the base (as_list, _wear_row, _ruin_card, upgrade_footer, upgrade_tile), Data
##       (stat_cap_by_station_level, balance.json stats, station_level).

const StatList := preload("res://ui/windows/stat_list.gd")


func _init(owner_hud) -> void:
	super(owner_hud, "target", "target")


func spec() -> Dictionary:
	var anchor := _anchor(id, 1.5)
	if Save.ruined.has(id):
		return _ruin_card(id, "Training Target", anchor)
	var rows: Array = as_list(_wear_row(id))
	rows.append_array(StatList.rows(self, StatList.ids_at(id)))
	return {"title": "Training Target", "sub": "Level %d · the cat practises while you stand here" % Data.station_level(id),
		"rows": rows, "footer": upgrade_footer(), "anchor": anchor}


## What Target level `level` gives: the stat cap it allows, and each stat it unlocks at that level (a stat trained here
## whose own needs_station_level is `level`; today Range at level 2), in today's words: "Stats up to level 6",
## "unlocks Range". (A stat without needs_station_level is open from the Target's first level: nothing to unlock.)
func gives(level: int) -> Array:
	var caps: Array = Data.b["stat_cap_by_station_level"]
	var out: Array = ["Stats up to level %d" % int(caps[clampi(level, 0, caps.size() - 1)])]
	var all: Dictionary = Data.b["stats"]
	for sid in all:
		var info: Dictionary = all[sid]
		if String(info.get("station", "")) == id and info.has("needs_station_level") and int(info["needs_station_level"]) == level:
			out.append("unlocks %s" % String(info["name"]))
	return out
