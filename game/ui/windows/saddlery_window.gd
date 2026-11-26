extends "res://ui/windows/building_window.gd"
## H4: the Saddlery's window (building and marker "saddlery": the mount's skills and attachments, G4). Moved from
## stations.gd (_card_saddlery, _saddle_tile and the Saddlery's part of the upgrade line) in H4 Stage 1, looking exactly
## as before (H5 rebuilds it): two shelves of tiles, "Skills" (Stomp, Ram, Pounce, Bellow: balance.json mount_skills)
## and "Attachments" (Fire-spitter, Mossweave Saddle, Saddlebags: mount_attachments), in balance.json's order, then its
## own upgrade ("Upgrade"). Each tile has one button:
##   not learned yet     "Buy" (its level-1 price, leaves and timber); badge "New"
##   learned             "Upgrade" (the next level's price; levels 4-5 only once the Burrows are open); off at the Saddlery's
##                       level (the line "Upgrade the Saddlery for more") or while the next level needs the Burrows
##                       ("Level 4 opens after the Raid Missions"); badge "Level 2/5" and a level bar
##   at its top          no button; badge "Max"
## Its line says what it does at its level (level 1 before it is learned): stations._saddle_note (it stays there: the
## rule _saddle_buy uses it for its banner). Learning and upgrading work any time (mid-wave too, like the bows' levels).
## 22 Nov 2026 (the owner's rule): the mount wears ONE attachment at a time (Save.saddlery.worn), and only that one acts
## and shows. The Attachments tiles work like the Bow Shop's, one button each:
##   the worn one        "Upgrade" as above (or no button at its top); badge "Worn"
##   owned, not worn     "Wear" (free); off while a mission or raid wave is on, the line then "Between waves"; badge
##                       "Owned"
##   not owned           "Buy"; badge "New". Bought when nothing is worn, it is worn at once.
## Knocked down: only the ruin card.
## Used by: ui/windows/window_list.gd (hud.windows["saddlery"]), stations.gd (the marker's builder; _card_saddlery for
##          the tests in Stage 1).
## Uses: Data (saddle_items, saddle_info, saddle_level, saddle_top, saddle_block, saddle_price, worn_attach), the rules
##       in stations.gd (_saddle_buy, _saddle_wear, _saddle_note, _locked), the base's tiles.


func _init(owner_hud) -> void:
	super(owner_hud, "saddlery", "saddlery")


func spec() -> Dictionary:
	return _card_saddlery()


## What Saddlery level `level` gives: how far its skills and attachments can go.
func gives(level: int) -> Array:
	return ["Skills and attachments up to level %d" % level]


func _card_saddlery() -> Dictionary:
	var title: String = st._name("saddlery")
	if Save.ruined.has("saddlery"):
		return _ruin_card("saddlery", title, _anchor("saddlery", 1.6))
	var rows: Array = _wear_row("saddlery")
	var skills: Array = []
	for sk in Data.saddle_items("skills"):
		skills.append(_saddle_tile("skills", String(sk)))
	var gear: Array = []
	for sk in Data.saddle_items("attach"):
		gear.append(_saddle_tile("attach", String(sk)))
	_add_section(rows, "Skills", skills)
	_add_section(rows, "Attachments", gear)
	_add_section(rows, "Upgrade", [upgrade_tile()])
	return {"title": title, "sub": "Level %d · %s uses its skills and wears one attachment while you ride" % [Data.saddlery_level(), Data.mount_name()],
		"rows": rows, "anchor": _anchor("saddlery", 1.6)}


## One skill's or attachment's tile on the Saddlery (part "skills" or "attach"; see the top of this file).
func _saddle_tile(part: String, sk: String) -> Dictionary:
	var info := Data.saddle_info(part, sk)
	var nm := String(info.get("name", sk))
	var icon := String(info.get("icon", "saddlery"))
	var lv := Data.saddle_level(part, sk)
	var top := Data.saddle_top(part, sk)
	var says: String = st._saddle_note(part, sk, maxi(lv, 1))
	var block := Data.saddle_block(part, sk)
	if lv <= 0:
		var c := Data.saddle_price(part, sk, 1)
		return _tile(icon, nm, says, c, "Buy", block == "", st._saddle_buy.bind(part, sk), "New")
	var badge := "Level %d/%d" % [lv, top]
	var bar := [["Level", float(lv) / float(maxi(top, 1)), "%d/%d" % [lv, top]]]
	if part == "attach":
		if Data.worn_attach() != sk:                    # owned, not worn: Wear it (free, between waves)
			var mid: bool = st._locked()
			return _tile(icon, nm, "Between waves" if mid else says, {}, "Wear", not mid, st._saddle_wear.bind(sk), "Owned", bar)
		badge = "Worn"
	match block:
		"max":
			return _tile(icon, nm, says, {}, "", false, Callable(), "Worn" if part == "attach" else "Max", [["Level", 1.0, "Max"]])
		"cap":
			return _tile(icon, nm, "Upgrade the %s for more" % st._name("saddlery"), {}, "Upgrade", false, Callable(), badge, bar)
		"burrows":
			return _tile(icon, nm, "Level %d opens after the Raid Missions" % (lv + 1), {}, "Upgrade", false, Callable(), badge, bar)
	var nc := Data.saddle_price(part, sk, lv + 1)
	return _tile(icon, nm, says + Data.mats_line(nc), nc, "Upgrade", block == "", st._saddle_buy.bind(part, sk), badge, bar)
