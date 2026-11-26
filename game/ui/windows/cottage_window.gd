extends "res://ui/windows/building_window.gd"
## H4: the Mushroom Cottage's window (building and marker "cottage": Sprig's home). Moved from stations.gd
## (_card_cottage and the Cottage's part of the upgrade line) in H4 Stage 1, looking exactly as before: Patch it up
## (when raids wore it), the pet's line, the Nest (its looks, colours, Gloomlit colours, attachments) and its own
## "Upgrade" tile. Knocked down: only the ruin card. H5 removes the Cottage (its pet upgrades move to the Market).
## Used by: ui/windows/window_list.gd (hud.windows["cottage"]), stations.gd (the marker's builder; _card_cottage in
##          Stage 1).
## Uses: Data (the pet), the base's tiles and looks rows.


func _init(owner_hud) -> void:
	super(owner_hud, "cottage", "cottage")


func spec() -> Dictionary:
	return _card_cottage()


## What Cottage level `level` gives: the pet's sparks at that level.
func gives(level: int) -> Array:
	return ["%s: %d damage every %.1fs" % [Data.pet_name(), int(Data.pick("pet", "damage_by_level", level)), Data.pick("pet", "every_by_level", level)]]


func _card_cottage() -> Dictionary:
	if Save.ruined.has("cottage"):
		return _ruin_card("cottage", "Mushroom Cottage", _anchor("cottage", 2.6))
	var lv := int(Save.stations["cottage"])
	var rows: Array = _wear_row("cottage")
	rows.append({"text": "%s · level %d" % [Data.pet_name(), lv], "note": "Flicks sparks: %d damage every %.1fs" % [int(Data.pick("pet", "damage_by_level", lv)), Data.pick("pet", "every_by_level", lv)],
		"cost": {}, "label": "", "enabled": false, "action": Callable()})
	# the Nest: every look fights exactly the same
	var nest := _look_tiles("pet", "pet", "Your pet now", "Same damage and speed, a different friend")
	nest.append(_skin_row("pet"))
	nest.append_array(_gloomlit_row("pet"))
	nest.append_array(_attach_rows("pet"))
	_add_section(rows, "The Nest", nest)
	_add_section(rows, "Upgrade", [upgrade_tile()])
	return {"title": "Mushroom Cottage", "sub": "Level %d · %s lives here" % [lv, String(Data.look("pet", Save.pet_look)["name"])], "rows": rows, "anchor": _anchor("cottage", 2.6)}
