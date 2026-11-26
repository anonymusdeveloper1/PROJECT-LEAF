extends "res://ui/windows/building_window.gd"
## H4: the Bow Shop's window (building and marker "bench": the Bow Bench before G3, the same save keys). Moved from
## stations.gd (_card_bench, _bow_tile, _bow_note and their helpers, and the shop's part of the upgrade line) in H4
## Stage 1, looking exactly as before. G3: one tile per bow, in the bows' content order (Twig, Sunwood, Ember, Frost;
## since 22 Nov 2026 Thorn Volley and Foxfire are "hidden": no tile unless the save owns one, then it shows Owned /
## Equipped as below so it can still be used), each with one button:
##   the bow in the cat's paw   "Upgrade" (its level, mastery past 10 once the Burrows are open; never above the
##                              shop's cap, Data.bow_cap(): at the cap the button is off and the note says to upgrade
##                              the Bow Shop); badge "Equipped"
##   owned, not in the paw      "Equip" (free); off while a mission or raid wave is on, the note then "Between waves";
##                              badge "Owned"
##   not owned                  "Buy" (its price, Data.craft_cost); off below the shop level it needs ("Needs Bow Shop
##                              level N", badge "Locked"), else badge "New". A bow bought between waves goes in the
##                              paw; one bought mid-wave waits on the shelf (equip it after the wave)
## The Foxfire Bow is left out until the Burrows open (unless the save owns it). Each bow keeps its own level. A tile
## shows res://assets/ui/bows/bow_<id>.png (row key "picture", hud.gd) when that picture exists, else the "bow" icon.
## Then the shop's own "Upgrade" tile. Knocked down: only the ruin card. Stage 2 (P2b) makes the bows list rows, adds
## the bow's inspect view and pins the Upgrade at the bottom.
## Used by: ui/windows/window_list.gd (hud.windows["bench"]), stations.gd (the marker's builder; _card_bench for the
##          tests in Stage 1).
## Uses: Data (bow_ids, bow_info, bow_shop_level, bow_waits, bow_hidden, bow_cap, bow_top, bow_cost, craft_cost,
##       bow_level_mult, bow_burn, bow_frost, bow_draw_mult), Save.bows / Save.bow, the rules in stations.gd
##       (_upgrade_bow, _craft, _equip, _locked).


func _init(owner_hud) -> void:
	super(owner_hud, "bench", "bench")


func spec() -> Dictionary:
	return _card_bench()


## What Bow Shop level `level` gives: the bow level cap it allows, and the bows it starts selling (never a hidden one,
## nor one that waits for the Gloomwood): "Bows up to level 6, sells the Sunwood Longbow".
func gives(level: int) -> Array:
	var caps: Array = Data.b["bow_cap_by_bench_level"]
	var out: Array = ["Bows up to level %d" % int(caps[clampi(level, 0, caps.size() - 1)])]
	var sells: Array = []
	for bid in Data.bow_ids():
		var bi := Data.bow_info(String(bid))
		if Data.bow_shop_level(String(bid)) == level and not Data.bow_hidden(String(bid)) and not Data.bow_waits(String(bid)):
			sells.append("the " + String(bi["name"]))
	if not sells.is_empty():
		out.append("sells %s" % " and ".join(sells))
	return out


func _card_bench() -> Dictionary:
	if Save.ruined.has("bench"):
		return _ruin_card("bench", st._name("bench"), _anchor("bench", 1.6))
	var rows: Array = _wear_row("bench")
	var bows: Array = []
	for bid in Data.bow_ids():
		var t := _bow_tile(String(bid))
		if not t.is_empty():
			bows.append(t)
	_add_section(rows, "Bows", bows)
	_add_section(rows, "Upgrade", [upgrade_tile()])
	return {"title": st._name("bench"), "sub": "Level %d · buy, upgrade and equip bows" % Save.stations["bench"], "rows": rows,
		"anchor": _anchor("bench", 1.6)}


## The path of a bow's shop picture (G3: rendered from its model); the tile uses it only when the file exists.
static func bow_picture_path(bid: String) -> String:
	return "res://assets/ui/bows/bow_%s.png" % bid


## One bow's tile on the Bow Shop (see the top of this file); {} for a bow not shown: a hidden bow the save does not own
## (Thorn Volley and Foxfire, 22 Nov 2026), or one that waits for the Burrows.
func _bow_tile(bid: String) -> Dictionary:
	var bi := Data.bow_info(bid)
	var nm := String(bi["name"])
	var owned := Save.bows.has(bid)
	if not owned and Data.bow_hidden(bid):
		return {}                                           # kept out of the shop for now (owned ones still show)
	if not owned and Data.bow_waits(bid):
		return {}                                           # a bow that waits for the Burrows
	var says := _bow_note(bid)
	var cap := Data.bow_cap()
	var t: Dictionary
	if owned:
		var lv := int(Save.bows[bid])
		var top := Data.bow_top(bid)
		var shown_cap := maxi(mini(cap, top), lv)
		var bar := [["Level", float(lv) / float(maxi(shown_cap, 1)), "%d/%d" % [lv, shown_cap]]]
		if bid == Save.bow:
			var curve: Dictionary = Data.b["bow_upgrade_curve"]
			if lv + 1 >= int(curve["late_from_level"]) and lv + 1 <= int(curve["late_to_level"]) and lv < cap and lv < top:
				var gain := (Data.bow_level_mult(bid, lv + 1) / Data.bow_level_mult(bid, lv) - 1.0) * 100.0
				says = "Next: +%s%% damage\n%s" % [_short_num(gain), says]
			var costs: Array = bi["cost"]
			if lv >= top:
				t = _tile("bow", nm, "At max level · " + says, {}, "", false, Callable(), "Equipped", [["Level", 1.0, "Max"]])
			elif lv >= cap:
				t = _tile("bow", nm, "Upgrade the %s for more" % st._name("bench"), {}, "Upgrade", false, Callable(), "Equipped", bar)
			elif lv >= costs.size():
				var bc := Data.bow_cost(bid, lv)            # Phase E: bow mastery, past level 10
				t = _tile("bow", nm, "Mastery %d/%d%s" % [lv - costs.size() + 1, top - costs.size(), Data.mats_line(bc)], bc,
					"Upgrade", true, st._upgrade_bow, "Equipped", bar)
			else:
				t = _tile("bow", nm, says, Data.bow_cost(bid, lv), "Upgrade", true, st._upgrade_bow, "Equipped", bar)
		else:
			var mid: bool = st._locked()                    # a wave is on: bows are swapped between waves
			t = _tile("bow", nm, "Between waves" if mid else says, {}, "Equip", not mid, st._equip.bind(bid), "Owned", bar)
	else:
		var need: int = Data.bow_shop_level(bid)
		var ok := int(Save.stations["bench"]) >= need
		var cc := Data.craft_cost(bid)
		t = _tile("bow", nm, (says + Data.mats_line(cc)) if ok else "Needs %s level %d" % [st._name("bench"), need], cc, "Buy", ok,
			st._craft.bind(bid), "New" if ok else "Locked")
	var pic := bow_picture_path(bid)
	if ResourceLoader.exists(pic):
		t["picture"] = pic
	return t


## What a bow does, in plain words, from its numbers: "A normal bow", "Goes through the first enemy, +1.5 m range",
## "Fire arrows: the hit enemy burns for 3 s", "Ice arrows: slow, and the 3rd hit freezes", "3 arrows in a fan",
## "Goes through two enemies, +1 m range".
func _bow_note(bid: String) -> String:
	var bi := Data.bow_info(bid)
	var bits: Array = []
	var n := int(bi["arrows"])
	if n > 1:
		bits.append("%d arrows in a fan" % n)
	var p := int(bi["pierce"])
	if p == 1:
		bits.append("goes through the first enemy")
	elif p > 1:
		bits.append("goes through %s enemies" % _count_word(p))
	var fire := Data.bow_burn(bid)
	if not fire.is_empty():
		bits.append("fire arrows: the hit enemy burns for %s s" % _short_num(float(fire.get("seconds", 0.0))))
	var ice := Data.bow_frost(bid)
	if not ice.is_empty():
		bits.append("ice arrows: slow, and the %s hit freezes" % _ordinal(int(ice.get("hits_to_freeze", 3))))
	var rb := float(bi["range_bonus"])
	if rb > 0.0:
		bits.append("+%s m range" % _short_num(rb))
	var dm := Data.bow_draw_mult(bid)
	var cons: Array = []                                 # the bow's downsides, after a "·"
	if rb < 0.0:
		cons.append("%s m shorter range" % _short_num(-rb))
	if dm > 1.0:
		var pct := roundi((dm - 1.0) * 100.0)
		cons.append("draws %d%% slower" % pct if pct < 20 else "slowest draw")   # a big slowdown reads as "slowest draw"
	if bits.is_empty() and cons.is_empty():
		return "Fastest draw" if dm <= 1.0 else "A normal bow"
	var s := ", ".join(bits)
	if s != "":
		s = s.substr(0, 1).to_upper() + s.substr(1)
	if not cons.is_empty():
		s = (s + " · " if s != "" else "") + " · ".join(cons)
	return s


const _COUNT_WORDS := ["no", "one", "two", "three", "four", "five"]


## "two", "three" (a number as a word in a line; the figure itself past five).
func _count_word(n: int) -> String:
	return String(_COUNT_WORDS[n]) if n >= 0 and n < _COUNT_WORDS.size() else str(n)


## 1 -> "1st", 2 -> "2nd", 3 -> "3rd", 4 -> "4th", 11 -> "11th", 22 -> "22nd".
func _ordinal(n: int) -> String:
	var suf := "th"
	if n % 100 < 11 or n % 100 > 13:
		match n % 10:
			1: suf = "st"
			2: suf = "nd"
			3: suf = "rd"
	return "%d%s" % [n, suf]
