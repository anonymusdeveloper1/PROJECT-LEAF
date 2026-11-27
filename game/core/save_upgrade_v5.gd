extends RefCounted
## The save's 4 -> 5 step (H5, 26 Nov 2026; the owner's answers Q1-Q5; docs/ARCHITECTURE.md part 10). The Mushroom
## Cottage leaves the camp and everything the shops sell gets one form, owned[kind][id] = {"level": n}. An old save
## keeps everything it paid for:
##   1. the old Cottage, Market and Saddlery levels are read one by one (missing or odd = 0). The Cottage and Market are
##      cut down to the old top level (old_level_cap): the H4 game never gave more than that, whatever the file said.
##      They are never cut down to the Hearthtree's level: an old mission gift can stand in a Hearthtree 1 camp
##   2. any Cottage becomes the pet's level (pet_level, the same tier) and owns both old pet looks (pet_looks: Sprig and
##      Lumi, free, the owner's Q1). Any Market owns both old mount looks (mount_looks: Thistle and Bramblewool). A
##      partial file without those levels still owns a slot's looks when it shows it used them: a chosen look other than
##      the first (the first is the default even in an empty camp) or a bought colour of one ("skin:<slot>:<look>:<id>"
##      in unlocks). Then the pet is at least level 1. The selected looks, colours and colour unlocks stay as they are
##   3. the Market becomes built (stations.stall = 1) and its old level is the mount's carried tier
##      (saddlery.mount_credit, the owner's Q2). The Saddlery keeps its real level, or stays unbuilt
##   4. the old Market's building health is kept (market_hp_floor = old_market_hp[level], the owner's Q5). The Cottage
##      goes from stations, wear, ruined, the legacy crusted list and the legacy spots. Other buildings' damage, the
##      Market's ruin, the placed pieces, missions and raids stay as they are
##   5. the outfits bought (cat_skins_owned) go into owned.outfits, always with the original (original_outfit). The
##      Saddlery's attachments (saddlery.attach, by level) and the expedition gear bought (attach.owned, level 1) go into
##      owned.attachments. On an overlap the higher level stays. A record's other fields and unknown ids stay. The old
##      receipt ids stay too (as level-1 records): the camp still names them once (stations._tell_saddlery_moves). The
##      worn ids stay apart: saddlery.worn for the Saddlery's one, attach.mount and attach.pet for expedition gear
##   6. a file from before G4 (no saddlery dictionary) is brought over once, as Save.migrate_saddlery did: a win of
##      g4_mission gives g4_free_skill at level 1 (flag g4_free_stomp), and each old Burrows item of g4_gear it bought
##      becomes that Saddlery attachment at that level (flag g4_old_attach). An old item worn in the expedition mount
##      slot comes off; the pet slot stays. A file that already has a saddlery dictionary gets neither again. Then the
##      mount wears one Saddlery attachment: the one marked worn when it owns it, else its highest, the first in
##      worn_tie_order on a tie, else none
##   7. every learned skill keeps its level, unknown ones too. The first learned ones in skill_order fill the
##      skill_slots circles (the owner's Q3: Stomp, Ram, Pounce; Bellow stays learned, never a fourth). Circles left
##      over are "" (empty)
## It reads only balance.json save_upgrades.to_v5 (frozen: what the H4 game gave), never a shop list or price of today.
## A key missing or odd there counts as none (no looks, no health floor, no free gifts, no circles; a missing
## old_level_cap cuts no level). It erases each field it converts, since Save.save_game() carries every top-level field
## it does not write itself.
## No class_name: core/save_upgrades.gd preloads it. Uses: Data.b (balance.json).

const TO_VERSION := 5                 # the format this step writes: a dictionary already at it is left as it is
const OWNED := 1                      # the level that only says "owned" (a look, an outfit, expedition gear, a first skill level)
const BUILT := 1                      # stations.stall in v5: 1 built, 0 not
const COTTAGE := "cottage"            # the old building's id, gone from the camp in v5
const MARKET := "stall"               # the Market's building id
const UNLOCK_SKIN := "skin"           # first part of a colour unlock, "skin:<slot>:<look>:<colour>"
const FLAG_FREE_SKILL := "g4_free_stomp"   # the camp says once that the old Thump is a Saddlery skill now
const FLAG_OLD_GEAR := "g4_old_attach"     # the camp says once that the old Burrows gear is Saddlery gear now


## Brings one save dictionary from version 4 to 5 and returns it (SaveUpgrades stamps save_v afterwards).
static func upgrade(d: Dictionary) -> Dictionary:
	# A v5 file is never converted again: an empty triangle the player chose stays empty.
	if _count(d.get("save_v")) >= TO_VERSION:
		return d
	var to: Dictionary = _dict(_dict(Data.b.get("save_upgrades")).get("to_v5"))
	# Before anything below makes one: a file with no saddlery dictionary is from before G4 (part 6).
	var before_g4: bool = not (d.get("saddlery") is Dictionary)
	var saddlery: Dictionary = _section(d, "saddlery")
	var owned: Dictionary = _section(d, "owned")
	var market: int = _companions(d, to, owned, saddlery)
	_market_health(d, to, market)
	_drop_cottage(d)
	_outfits(d, to, owned)
	var gear: Dictionary = _attachments(d, to, owned, saddlery, before_g4)
	var skills: Dictionary = _section(saddlery, "skills")
	if before_g4:
		_free_skill(d, to, skills)
	saddlery["worn"] = _settle_worn(gear, _id(saddlery.get("worn")), _ids(to.get("worn_tie_order")))
	saddlery["skill_slots"] = _fill_slots(skills, _ids(to.get("skill_order")), _count(to.get("skill_slots")))
	return d


# ---------------------------------------------------------------- 1-3: the pet, the mounts, the Market
## Parts 1-3. Returns the old Market level (0 when there was none), which part 4 needs for the building's health.
static func _companions(d: Dictionary, to: Dictionary, owned: Dictionary, saddlery: Dictionary) -> int:
	var stations: Dictionary = _section(d, "stations")
	var cap: int = _count(to.get("old_level_cap"))
	var market: int = _old_level(stations.get(MARKET), cap)
	var cottage: int = _old_level(stations.get(COTTAGE), cap)
	var mount_looks: Array[String] = _ids(to.get("mount_looks"))
	var pet_looks: Array[String] = _ids(to.get("pet_looks"))
	var mounts: Dictionary = _section(owned, "mounts")
	var pets: Dictionary = _section(owned, "pets")
	if market > 0 or _used_looks(d, "mount", mount_looks):
		for id: String in mount_looks:
			_grant(mounts, id, OWNED)
	if cottage > 0 or _used_looks(d, "pet", pet_looks):
		for id: String in pet_looks:
			_grant(pets, id, OWNED)
		cottage = maxi(cottage, OWNED)                  # an owned pet is never below level 1
	d["pet_level"] = maxi(_count(d.get("pet_level")), cottage)
	saddlery["mount_credit"] = maxi(_count(saddlery.get("mount_credit")), market)
	stations[MARKET] = BUILT if market > 0 else 0
	return market


## An old Cottage or Market level: a whole number of 0 or more (odd = 0), at most cap (no cap when cap is 0).
static func _old_level(v: Variant, cap: int) -> int:
	var lv: int = _count(v)
	return mini(lv, cap) if cap > 0 else lv


## True when a partial file shows it had a slot's looks: it chose a look other than the first one (Save's default, even
## in a camp that never had the companion), or it bought a colour of one ("skin:<slot>:<look>:<colour>" in unlocks).
static func _used_looks(d: Dictionary, slot: String, looks: Array[String]) -> bool:
	if looks.is_empty():
		return false
	var picked: String = _id(d.get(slot + "_look"))
	if picked != looks[0] and looks.has(picked):
		return true
	for u: Variant in _array(d.get("unlocks")):
		if not u is String:
			continue
		var parts: PackedStringArray = (u as String).split(":")
		if parts.size() == 4 and parts[0] == UNLOCK_SKIN and parts[1] == slot and looks.has(parts[2]) and parts[3] != "":
			return true
	return false


# ---------------------------------------------------------------- 4: the Market's health and the Cottage's traces
## Part 4: the health the old Market had earned at its level (old_market_hp, the last entry past its end), 0 for none.
static func _market_health(d: Dictionary, to: Dictionary, market: int) -> void:
	var hp: Array = _array(to.get("old_market_hp"))
	var earned: int = 0
	if market > 0 and not hp.is_empty():
		earned = _count(hp[mini(market, hp.size() - 1)])
	d["market_hp_floor"] = maxi(_count(d.get("market_hp_floor")), earned)


## Part 4: the Cottage leaves every list and table that names a building. A field that is missing or not a list or
## table is left as it is.
static func _drop_cottage(d: Dictionary) -> void:
	for key: String in ["stations", "wear", "spots"]:
		var table: Variant = d.get(key)
		if table is Dictionary:
			(table as Dictionary).erase(COTTAGE)
	for key: String in ["ruined", "crusted"]:
		var list: Variant = d.get(key)
		if list is Array:
			while (list as Array).has(COTTAGE):
				(list as Array).erase(COTTAGE)


# ---------------------------------------------------------------- 5-6: outfits and attachments
## Part 5: the outfits bought, always with the original.
static func _outfits(d: Dictionary, to: Dictionary, owned: Dictionary) -> void:
	var outfits: Dictionary = _section(owned, "outfits")
	_grant(outfits, _id(to.get("original_outfit")), OWNED)
	for id: String in _ids(d.get("cat_skins_owned")):
		_grant(outfits, id, OWNED)
	d.erase("cat_skins_owned")


## Parts 5 and 6: both families of attachments into owned.attachments; the old Burrows gear once (before G4). Returns
## owned.attachments for settling the worn one.
static func _attachments(d: Dictionary, to: Dictionary, owned: Dictionary, saddlery: Dictionary, before_g4: bool) -> Dictionary:
	var gear: Dictionary = _section(owned, "attachments")
	var expedition: Dictionary = _section(d, "attach")
	var receipts: Array[String] = _ids(expedition.get("owned"))
	for id: String in receipts:
		_grant(gear, id, OWNED)
	expedition.erase("owned")
	for slot: String in ["mount", "pet"]:
		expedition[slot] = _id(expedition.get(slot))
	# The Saddlery's: H4 wrote a level for each known id and kept an unknown id's value as it was (a record keeps its fields).
	var bought: Dictionary = _dict(saddlery.get("attach"))
	for key: Variant in bought:
		var raw: Variant = bought[key]
		if raw is Dictionary:
			_grant(gear, _id(key), _count((raw as Dictionary).get("level")), raw as Dictionary)
		else:
			_grant(gear, _id(key), _count(raw))
	saddlery.erase("attach")
	var moved: Dictionary = _dict(to.get("g4_gear"))
	for key: Variant in moved:
		var old_id: String = _id(key)
		if old_id == "":
			continue
		var gift: Dictionary = _dict(moved[key])
		var new_id: String = _id(gift.get("id"))
		var level: int = _count(gift.get("level"))
		if before_g4 and receipts.has(old_id) and new_id != "" and level > 0:
			_grant(gear, new_id, level)
			var flags: Dictionary = _section(d, "flags")
			flags[FLAG_OLD_GEAR] = true
		# An old Burrows item is a Saddlery attachment now: it cannot be worn in the expedition mount slot.
		if String(expedition["mount"]) == old_id:
			expedition["mount"] = ""
	return gear


## Part 6, before G4 only: the mount's old built-in Thump becomes the free skill when the file had won its mission.
static func _free_skill(d: Dictionary, to: Dictionary, skills: Dictionary) -> void:
	var mission: String = _id(to.get("g4_mission"))
	var skill: String = _id(to.get("g4_free_skill"))
	if mission == "" or skill == "" or not _ids(d.get("missions_done")).has(mission):
		return
	skills[skill] = maxi(_count(skills.get(skill)), OWNED)
	var flags: Dictionary = _section(d, "flags")
	flags[FLAG_FREE_SKILL] = true


## Part 6: the Saddlery attachment the mount wears. The marked one when it is owned (even if another is higher), else
## the highest owned one, the first in order on a tie; "" when it owns none. Expedition gear never counts here.
static func _settle_worn(gear: Dictionary, worn: String, order: Array[String]) -> String:
	if order.has(worn) and _count(_dict(gear.get(worn)).get("level")) >= OWNED:
		return worn
	var best: String = ""
	var best_level: int = 0
	for id: String in order:
		var level: int = _count(_dict(gear.get(id)).get("level"))
		if level > best_level:
			best = id
			best_level = level
	return best


# ---------------------------------------------------------------- 7: the skill circles
## Part 7: count circles, filled with the learned skills (level 1 or more) in order; the rest "". Skills outside order
## (unknown ids) never fill a circle and keep their records.
static func _fill_slots(skills: Dictionary, order: Array[String], count: int) -> Array:
	var slots: Array = []
	for id: String in order:
		if slots.size() >= count:
			break
		if _count(skills.get(id)) >= OWNED:
			slots.append(id)
	while slots.size() < count:
		slots.append("")
	return slots


# ---------------------------------------------------------------- reading odd values safely
## Gives item id a record of at least level (and the given fields where it has none of its own). Nothing for an empty
## id, or for level 0 without fields (0 means not owned).
static func _grant(items: Dictionary, id: String, level: int, fields: Dictionary = {}) -> void:
	if id == "" or (level <= 0 and fields.is_empty()):
		return
	var record: Dictionary = _section(items, id)
	var best: int = maxi(_count(record.get("level")), level)
	record.merge(fields)                                # keeps the record's own fields on a clash
	record["level"] = best


## parent[key] as a Dictionary that writes go into; a missing or odd one is replaced by an empty one.
static func _section(parent: Dictionary, key: String) -> Dictionary:
	if not parent.get(key) is Dictionary:
		parent[key] = {}
	return parent[key]


static func _dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}


static func _array(v: Variant) -> Array:
	return v if v is Array else []


static func _id(v: Variant) -> String:
	return v if v is String else ""


## The text ids of a list, in order, each once (anything else in it is skipped).
static func _ids(v: Variant) -> Array[String]:
	var out: Array[String] = []
	for e: Variant in _array(v):
		var id: String = _id(e)
		if id != "" and not out.has(id):
			out.append(id)
	return out


## A JSON number as a whole number of 0 or more (Godot may read whole numbers as floats; a fraction is cut off, as the
## H4 loader's int() did); anything else is 0.
static func _count(v: Variant) -> int:
	if v is int:
		return maxi(v as int, 0)
	if v is float and is_finite(v as float):
		return maxi(int(v as float), 0)
	return 0
