## H5 Stage 1 foundation checks for autotest.gd (`-- --autotest --h5found`; the H5 build map parts 3 and 5, the owner's
## answers Q1-Q6), by the contract names, before any window uses them: the four new content kinds and their old readers
## (H4's ids, names, prices and models), hidden and unknown ids, the shared pet level, the mount tiers and the skill
## circles, the frozen to_v5 block and SaveUpgradeV5.upgrade() on v4 dictionaries built here (run twice it grants
## nothing twice), Bramble's trades (scripts/market_trade.gd) and the Buy command (commands/buy.gd).
## Stage 1 keeps the H4 game (the save is still v4): what needs the v5 save is checked to refuse until Buy.v5_ready(),
## and checked for real once it is live (Stage 2). Save is changed in memory only, with the automatic flush held, and
## every field is put back at the end; an entry hidden for a check is shown again at once. Only
## CompanionShop.assign_skill saves (Stage 2 only), into the test slot.
extends Node

const AutotestScript := preload("res://scripts/autotest.gd")
const MainScript := preload("res://scripts/main.gd")
const SaveUpgradeV5 := preload("res://core/save_upgrade_v5.gd")
const MarketTrade := preload("res://scripts/market_trade.gd")
const Buy := preload("res://commands/buy.gd")
const CompanionShop := preload("res://scripts/companion_shop.gd")

const INDEX_PATH := "res://content/index.json"
## The four H5 kinds in index order (content/index.json).
const KINDS := {"mounts": ["thistle", "bramblewool"], "pets": ["sprig", "lumi"],
	"outfits": ["original", "dusk_ranger", "nightfall_ranger"],
	"attachments": ["fire_spitter", "saddle", "saddlebags", "mount_shoes", "pet_lantern", "pet_charm", "pet_bell"]}
## What the H4 game sold (f72b03f), frozen here. Mounts: [name, short]; free with the Market.
const MOUNTS := {"thistle": ["Thistle the hare", "Thistle"], "bramblewool": ["Bramblewool the ram", "Bramblewool"]}
## Pets: [name, short, price, looks_only] (the owner's Q1 B: Sprig the old Cottage's price, Lumi a looks-only 400).
const PETS := {"sprig": ["Sprig the leaf dragon", "Sprig", {"leaves": 160}, false],
	"lumi": ["Lumi the fox kit", "Lumi", {"leaves": 400}, true]}
## Outfits: [name, price, model].
const OUTFITS := {"original": ["Original Ranger", {}, ""],
	"dusk_ranger": ["Dusk Ranger", {"leaves": 3000}, "res://assets/cat/skins/dusk_ranger.glb"],
	"nightfall_ranger": ["Ember Ranger", {"leaves": 6000}, "res://assets/cat/skins/nightfall_ranger.glb"]}
## The Saddlery's attachments: [name, the five level prices]; levels from BURROWS_FROM wait for the Burrows.
const SADDLE_GEAR := {
	"fire_spitter": ["Fire-spitter", [{"leaves": 1200, "timber": 45}, {"leaves": 1800, "timber": 55},
		{"leaves": 2700, "timber": 75}, {"leaves": 5320, "timber": 95}, {"leaves": 8240, "timber": 125}]],
	"saddle": ["Mossweave Saddle", [{"leaves": 900, "timber": 35}, {"leaves": 1300, "timber": 45},
		{"leaves": 2100, "timber": 60}, {"leaves": 3940, "timber": 80}, {"leaves": 6560, "timber": 110}]],
	"saddlebags": ["Saddlebags", [{"leaves": 1000, "timber": 40}, {"leaves": 1500, "timber": 50},
		{"leaves": 2300, "timber": 65}, {"leaves": 4480, "timber": 85}, {"leaves": 7200, "timber": 115}]]}
const BURROWS_FROM := 4
## Expedition gear: [slot, name, price, mods].
const TRIP_GEAR := {"mount_shoes": ["mount", "Thunder Shoes", {"leaves": 3520}, {"thump_mult": 0.6}],
	"pet_lantern": ["pet", "Glowworm Lantern", {"leaves": 2120}, {"trap_warn": 0.3}],
	"pet_charm": ["pet", "Ember Charm", {"leaves": 3400}, {"pet_dmg": 0.6}],
	"pet_bell": ["pet", "Dew Bell", {"leaves": 2100}, {"hp": 2}]}
## The shop pictures P1e renders: res://content/<kind>/<id>/icon.png, in each entry's "picture".
const PICTURES := {"mounts": ["thistle", "bramblewool"], "pets": ["sprig", "lumi"],
	"attachments": ["fire_spitter", "saddle", "saddlebags"]}
## The pet's training prices by level (the old Mushroom Cottage's; level 1 is buying Sprig).
const PET_LEVEL_PRICES := [{}, {"leaves": 350}, {"leaves": 900, "timber": 30}]
## Mount tiers 1-5: walking speed and base health (H4's 1-3; the owner's Q6 A for 4 and 5).
const MOUNT_SPEED := [1.275, 1.4025, 1.53, 1.6575, 1.785]
const MOUNT_HP := [6, 9, 13, 18, 24]
const SKILLS := ["stomp", "ram", "pounce", "bellow"]
## balance.json save_upgrades.to_v5 exactly (the parts' agreement, 26 Nov 2026).
const TO_V5 := {"old_level_cap": 3, "old_market_hp": [0, 200, 340, 500], "mount_looks": ["thistle", "bramblewool"],
	"pet_looks": ["sprig", "lumi"], "original_outfit": "original", "skill_order": ["stomp", "ram", "pounce", "bellow"],
	"skill_slots": 3, "g4_mission": "spitters", "g4_free_skill": "stomp",
	"g4_gear": {"mount_saddle": {"id": "saddle", "level": 3}, "mount_bags": {"id": "saddlebags", "level": 5}},
	"worn_tie_order": ["saddlebags", "saddle", "fire_spitter"]}
## A v4 save as the H4 game wrote it: the fields the 4 -> 5 step reads (_v4 puts a case's fields on top).
const V4_BASE := {"save_v": 4, "leaves": 500, "timber": 20, "shards": 0, "camp_level": 2,
	"stations": {"target": 1, "bench": 1, "well": 1, "cottage": 0, "stall": 0, "stone": 0, "garden": 1, "fishing": 0,
		"saddlery": 0, "tailor": 0},
	"ruined": [], "wear": {}, "flags": {}, "missions_done": [], "unlocks": [], "mount_look": "thistle", "pet_look": "sprig",
	"mount_skin": "natural", "pet_skin": "natural", "attach": {"owned": [], "mount": "", "pet": ""},
	"saddlery": {"skills": {}, "attach": {}, "worn": ""}, "cat_skin": "original", "cat_skins_owned": ["original"]}
## The words Buy and the trades refuse with: all in balance.json windows, none written in code.
const WORDS := ["coming_later", "already_owned", "amount", "needs", "build_ruined", "after_missions", "bag_full",
	"have_only", "max", "max_for_now", "needs_home", "needs_missions", "opens_after_missions", "receipt_wear_here",
	"pet_first"]
## The Save fields these checks change (kept and put back), the v5 ones only when Save has them.
const SAVE_FIELDS := ["leaves", "timber", "shards", "camp_level", "stations", "ruined", "missions_done", "flags",
	"saddlery", "attach", "unlocks", "mount_look", "pet_look", "mount_skin", "pet_skin", "cat_skin", "cat_skins_owned",
	"bag", "items", "mats", "bows", "bow", "owned", "pet_level", "market_hp_floor"]
## The fields a refused purchase or trade must leave as they were.
const STATE_FIELDS := ["leaves", "timber", "shards", "stations", "ruined", "saddlery", "attach", "unlocks", "bag", "items",
	"mats", "bows", "bow", "cat_skin", "mount_look", "pet_look", "mount_skin", "pet_skin", "owned", "pet_level"]

var t: AutotestScript
var main: MainScript
var _kept: Dictionary = {}


func run() -> bool:
	_kept = _keep()
	var held: bool = Save.hold_flush
	Save.hold_flush = true                              # nothing below reaches a file by the flush timer
	var ok := _check_catalogues()
	ok = _check_gear() and ok
	ok = _check_hidden() and ok
	ok = _check_pet_mount_slots() and ok
	ok = _check_frozen() and ok
	ok = _check_upgrade() and ok
	ok = _check_market() and ok
	ok = _check_buy() and ok
	_restore(_kept)
	Save.hold_flush = held
	return ok


# ---------------------------------------------------------------- the catalogues and their old readers
func _check_catalogues() -> bool:
	_fixture()
	var index: Variant = JSON.parse_string(FileAccess.get_file_as_string(INDEX_PATH))
	var kinds: Dictionary = _dict(_dict(index).get("kinds"))
	var wrong: Array = []
	for kind: String in KINDS:
		if not _same(kinds.get(kind), KINDS[kind]) or not _same(_ids(Data.catalog(kind)), KINDS[kind]) \
				or not _same(_ids(Data.shop_entries(kind)), KINDS[kind]):
			wrong.append(kind)
	var ok := t._expect("the four H5 kinds are indexed and read in index order, none hidden (index.json, Data.catalog, Data.shop_entries)",
		wrong.is_empty(), {"wrong": wrong})
	var off: Array = []
	for id: String in MOUNTS:
		var e: Dictionary = Data.item("mounts", id)
		if String(e.get("name", "")) != MOUNTS[id][0] or String(e.get("short", "")) != MOUNTS[id][1] or not _same(e.get("price"), {}) \
				or not _same(e.get("unlock"), {"building": ["stall", 1]}) or Data.companion_model("mount", id) == "":
			off.append(id)
	for id: String in PETS:
		var e: Dictionary = Data.item("pets", id)
		if String(e.get("name", "")) != PETS[id][0] or String(e.get("short", "")) != PETS[id][1] \
				or not _same(Data.entry_price("pets", id), PETS[id][2]) or _true(e.get("looks_only")) != PETS[id][3] \
				or not Data.entry_price_ok("pets", id) or Data.companion_model("pet", id) == "":
			off.append(id)
	ok = t._expect("mounts and pets: H4's names and models, Thistle and Bramblewool free with the Market, Sprig 160 leaves, Lumi 400 leaves looks-only",
		off.is_empty(), {"off": off}) and ok
	var cottage_price: Dictionary = Data.build_price("cottage") if not Data.building("cottage").is_empty() else PETS["sprig"][2]
	ok = t._expect("Sprig costs what the Mushroom Cottage cost", _same(Data.entry_price("pets", "sprig"), cottage_price),
		{"sprig": Data.entry_price("pets", "sprig"), "cottage": cottage_price}) and ok
	ok = _check_old_looks() and ok
	var unbuilt: Array = [Data.owned_level("mounts", "thistle"), Data.owned_level("mounts", "bramblewool"), Data.owned_level("pets", "sprig")]
	Save.stations["stall"] = 1
	var built: Array = [Data.owned_level("mounts", "thistle"), Data.owned_level("mounts", "bramblewool"), Data.owned_level("pets", "sprig"),
		Data.owned_level("pets", "lumi"), Data.owned_level("mounts", "no_such_mount")]
	ok = t._expect("Thistle and Bramblewool come with a built Market (Data.owned_level); a pet is never owned by itself",
		_same(unbuilt, [0, 0, 0]) and _same(built, [1, 1, 0, 0, 0]), {"unbuilt": unbuilt, "built": built}) and ok
	ok = _check_outfits() and ok
	ok = _check_pictures() and ok
	return ok


## Data.look reads the content entries (the same dictionaries), keeps its display fallback, and agrees with the old
## balance.json looks while that block is still there.
func _check_old_looks() -> bool:
	var same_entry := true
	for id: String in MOUNTS:
		same_entry = same_entry and is_same(Data.look("mount", id), Data.item("mounts", id))
	for id: String in PETS:
		same_entry = same_entry and is_same(Data.look("pet", id), Data.item("pets", id))
	var ok := t._expect("Data.look gives the content entries; an unknown look still shows the first (a name only), never a shop entry",
		same_entry and is_same(Data.look("pet", "no_such_pet"), Data.item("pets", "sprig")) and Data.shop_entry("pets", "no_such_pet").is_empty()
		and Data.shop_entry("mounts", "").is_empty() and Data.companion_model("pet", "no_such_pet") == "")
	var looks: Dictionary = _dict(Data.b.get("looks"))
	var differ: Array = []
	for pair: Array in [["mount", "mounts"], ["pet", "pets"]]:
		var old: Variant = looks.get(pair[0])
		if not old is Array:
			continue                                        # the old block is gone (H5 Stage 3): the frozen names above stand
		var old_ids: Array = []
		for l: Variant in old:
			var o: Dictionary = _dict(l)
			old_ids.append(String(o.get("id", "")))
			var e: Dictionary = Data.item(String(pair[1]), String(o.get("id", "")))
			for k: String in ["name", "short", "fur", "skins", "flies", "spark"]:
				if o.has(k) and not _same(o[k], e.get(k)):
					differ.append("%s/%s %s" % [pair[1], o.get("id", ""), k])
		if not _same(old_ids, KINDS[pair[1]]):
			differ.append(String(pair[1]) + " order")
	return t._expect("the mount and pet entries match balance.json looks (names, fur, colours, flight, sparks)", differ.is_empty(),
		{"differ": differ}) and ok


func _check_outfits() -> bool:
	var off: Array = []
	var old: Dictionary = _dict(Data.b.get("cat_skins"))
	for id: String in OUTFITS:
		var w: Array = OUTFITS[id]
		var cost: Dictionary = w[1]
		var e: Dictionary = Data.item("outfits", id)
		var view: Dictionary = Data.cat_skin(id)
		if String(e.get("name", "")) != w[0] or not _same(e.get("price"), cost) or String(e.get("model", "")) != w[2] \
				or String(view.get("name", "")) != w[0] or not _same(Data.cat_skin_cost(id), cost) \
				or _int(view.get("price")) != _int(cost.get("leaves")) or String(view.get("currency", "")) != "leaves":
			off.append(id)
		var o: Dictionary = _dict(old.get(id))
		if not o.is_empty() and (String(o.get("name", "")) != String(e.get("name", "")) or String(o.get("short", "")) != String(e.get("desc", ""))
				or _int(o.get("price")) != _int(cost.get(String(o.get("currency", "leaves")))) or String(o.get("model", "")) != String(e.get("model", ""))):
			off.append(id + " (balance.json cat_skins)")
	var ok := t._expect("outfits: H4's ids (Ember Ranger keeps nightfall_ranger), names, prices and models; Data.cat_skin* agree",
		off.is_empty() and _same(Data.cat_skin_ids(), KINDS["outfits"]), {"off": off, "ids": Data.cat_skin_ids()})
	return t._expect("the original outfit is free and always owned; the other two have models and can be sold",
		Data.owned_level("outfits", "original") == 1 and Data.entry_price_ok("outfits", "original") and Data.cat_skin_buyable("dusk_ranger")
		and Data.cat_skin_buyable("nightfall_ranger") and Data.cat_skin_model("nightfall_ranger") != "") and ok


## Each picture is the entry's "picture"; Data.shop_picture gives it once its file is imported, "" before (the window
## then shows the entry's icon), "" for a missing file or an unknown id. Every icon is one the HUD draws.
func _check_pictures() -> bool:
	var bad: Array = []
	var waiting: Array = []
	for kind: String in PICTURES:
		for id: String in PICTURES[kind]:
			var path := "res://content/%s/%s/icon.png" % [kind, id]
			var there := ResourceLoader.exists(path)
			if String(Data.item(kind, id).get("picture", "")) != path or Data.shop_picture(kind, id) != (path if there else ""):
				bad.append("%s/%s" % [kind, id])
			if not there:
				waiting.append("%s/%s" % [kind, id])
	if not waiting.is_empty():
		print("NOTE shop pictures not imported yet (their icon stands in): %s" % ", ".join(waiting))
	var e: Dictionary = Data.item("mounts", "thistle")
	var kept: Variant = e.get("picture")
	e["picture"] = "res://content/mounts/thistle/no_such_picture.png"
	var missing := Data.shop_picture("mounts", "thistle")
	e["picture"] = kept
	var ok := t._expect("the seven shop pictures are named in their entries; Data.shop_picture gives \"\" for a missing file or id",
		bad.is_empty() and missing == "" and Data.shop_picture("pets", "no_such_pet") == "", {"bad": bad})
	var hud: Variant = main.hud
	var unknown: Array = []
	for kind: String in KINDS:
		for entry: Variant in Data.catalog(kind):
			var icon := String(_dict(entry).get("icon", ""))
			if not hud._icon_known(icon):
				unknown.append("%s: %s" % [kind, icon])
	return t._expect("every mount, pet, outfit and attachment icon is a HUD icon (the picture's stand-in)", unknown.is_empty(),
		{"unknown": unknown}) and ok


# ---------------------------------------------------------------- attachments
func _check_gear() -> bool:
	_fixture()
	var off: Array = []
	for id: String in SADDLE_GEAR:
		var prices: Array = SADDLE_GEAR[id][1]
		var e: Dictionary = Data.item("attachments", id)
		var why: Array = []
		if String(e.get("name", "")) != SADDLE_GEAR[id][0] or String(e.get("shop", "")) != "saddlery" or String(e.get("slot", "")) != "mount" \
				or String(e.get("scope", "")) != "all" or Data.saddle_info("attach", id).is_empty() or Data.saddle_top("attach", id) != prices.size():
			why.append("fields")
		for lv: int in prices.size():
			if not _same(Data.saddle_price("attach", id, lv + 1), prices[lv]) \
					or Data.saddle_needs_burrows("attach", id, lv + 1) != (lv + 1 >= BURROWS_FROM):
				why.append("level %d" % (lv + 1))
		for look: String in KINDS["mounts"]:
			if Data.gear_model(id, look) == "":
				why.append("model on " + look)
		if not why.is_empty():
			off.append({id: why})
	for id: String in TRIP_GEAR:
		var w: Array = TRIP_GEAR[id]
		var e: Dictionary = Data.item("attachments", id)
		if String(e.get("slot", "")) != w[0] or String(e.get("name", "")) != w[1] or not _same(Data.entry_price("attachments", id), w[2]) \
				or not _same(e.get("mods"), w[3]) or String(e.get("shop", "")) != "stall" or String(e.get("scope", "")) != "expedition" \
				or e.has("upgrades"):
			off.append(id)
	var ok := t._expect("attachments: the Saddlery's three keep H4's names, five level prices (4-5 after the Burrows) and fitted models; the expedition gear its slot, price and mods",
		off.is_empty(), {"off": off})
	ok = t._expect("attachments match balance.json mount_attachments and attachments while those blocks are there", _old_gear_same(),
		{}) and ok
	ok = t._expect("Data.attachment_entries lists each shop's gear by slot in index order; Data.saddle_items the Saddlery's",
		_same(_ids(Data.attachment_entries("saddlery", "mount")), ["fire_spitter", "saddle", "saddlebags"])
		and Data.attachment_entries("saddlery", "pet").is_empty()
		and _same(_ids(Data.attachment_entries("stall", "mount")), ["mount_shoes"])
		and _same(_ids(Data.attachment_entries("stall", "pet")), ["pet_lantern", "pet_charm", "pet_bell"])
		and _same(_ids(Data.attachment_entries("stall", "")), ["mount_shoes", "pet_lantern", "pet_charm", "pet_bell"])
		and _same(Data.saddle_items("attach").keys(), ["fire_spitter", "saddle", "saddlebags"])) and ok
	# the expedition gear worn reads the entries (both ownership forms are written, so this holds before and after the switch)
	Save.attach = {"owned": ["pet_bell"], "mount": "", "pet": "pet_bell"}
	if _has("owned"):
		Save.set("owned", {"attachments": {"pet_bell": {"level": 1}}})
	var on: Array = Data.attachments_on()
	ok = t._expect("Data.attachments_on gives the worn expedition gear's entry with its mods",
		on.size() == 1 and _same(_dict(on[0]).get("mods"), {"hp": 2}), {"on": _ids(on)}) and ok
	# H5's power prices never ask for purple shards (only looks may)
	var paid: Array = []
	for e: Variant in Data.catalog("attachments"):
		var gear_id := String(_dict(e).get("id", ""))
		for lv: int in range(1, 2 + _array(_dict(e).get("upgrades")).size()):
			if Data.entry_price("attachments", gear_id, lv).has("shards"):
				paid.append("%s %d" % [gear_id, lv])
	for id: String in SKILLS:
		for lv: int in range(1, Data.saddle_top("skills", id) + 1):
			if Data.saddle_price("skills", id, lv).has("shards"):
				paid.append("%s %d" % [id, lv])
	for lv: int in range(2, Data.pet_top() + 1):
		if Data.pet_level_price(lv).has("shards"):
			paid.append("pet level %d" % lv)
	if Data.entry_price("pets", "sprig").has("shards"):
		paid.append("sprig")
	return t._expect("no gear, skill, pet or pet-training price asks for purple shards", paid.is_empty(), {"paid": paid}) and ok


## The content attachments say what balance.json said (skipped for a block that is gone).
func _old_gear_same() -> bool:
	var saddle_old: Dictionary = _dict(_dict(Data.b.get("mount_attachments")).get("items"))
	for id: Variant in saddle_old:
		var o: Dictionary = _dict(saddle_old[id])
		var e: Dictionary = Data.item("attachments", str(id))
		var levels: Array = [e.get("price")]
		levels.append_array(_array(e.get("upgrades")))
		if not _same(o.get("price"), levels) or String(o.get("text", "")) != String(e.get("desc", "")):
			return false
		for k: Variant in o:
			if String(k) != "price" and String(k) != "text" and not String(k).begins_with("_") and not _same(o[k], e.get(k)):
				return false
	var trip_old: Dictionary = _dict(_dict(Data.b.get("attachments")).get("items"))
	for id: Variant in trip_old:
		var o: Dictionary = _dict(trip_old[id])
		var e: Dictionary = Data.item("attachments", str(id))
		if String(o.get("slot", "")) != String(e.get("slot", "")) or String(o.get("name", "")) != String(e.get("name", "")) \
				or String(o.get("note", "")) != String(e.get("desc", "")) or not _same(o.get("cost"), e.get("price")) \
				or not _same(o.get("mods"), e.get("mods")):
			return false
	return true


# ---------------------------------------------------------------- hidden and unknown entries
func _check_hidden() -> bool:
	_fixture()
	Save.stations["stall"] = 1
	Save.stations["tailor"] = 1
	Save.stations["saddlery"] = 1
	Save.stations["bench"] = 3
	Save.leaves = 100000
	Save.timber = 10000
	Save.shards = 1000
	var shown: Array = []
	for pair: Array in [["mounts", "bramblewool"], ["pets", "lumi"], ["outfits", "dusk_ranger"], ["attachments", "saddle"]]:
		var kind: String = pair[0]
		var id: String = pair[1]
		var e: Dictionary = Data.item(kind, id)
		e["hidden"] = true
		if _ids(Data.shop_entries(kind)).has(id) or not Data.shop_entry(kind, id).is_empty() or Data.entry_price_ok(kind, id) \
				or Buy.new(kind, id, 1, 1).can_run(main) == "" or Data.cat_skin_ids().has(id) \
				or _ids(Data.attachment_entries("saddlery", "")).has(id) or Data.saddle_items("attach").has(id):
			shown.append("%s/%s" % [kind, id])
		e.erase("hidden")
	var back := true
	for kind: String in KINDS:
		back = back and _same(_ids(Data.shop_entries(kind)), KINDS[kind])
	var ok := t._expect("a hidden entry is not listed, not a shop entry, has no price for sale and Buy refuses it; shown again it is back in order",
		shown.is_empty() and back, {"shown": shown})
	# a hidden bow, where Buy runs today: the same purchase goes through once it is shown again
	var bow: Dictionary = Data.item("bows", "sunwood")
	var shown_why := Buy.new("bows", "sunwood").can_run(main)
	bow["hidden"] = true
	var hidden_why := Buy.new("bows", "sunwood").can_run(main)
	var hidden_ran := Buy.new("bows", "sunwood").run(main)
	bow.erase("hidden")
	ok = t._expect("Buy never sells a hidden bow, and sells it once it is shown",
		shown_why == "" and hidden_why != "" and not hidden_ran and not Save.bows.has("sunwood") and Buy.new("bows", "sunwood").can_run(main) == "",
		{"shown": shown_why, "hidden": hidden_why}) and ok
	# an unknown id (or kind) is never bought, whatever the kind, and changes nothing
	var before := _state()
	var took: Array = []
	for kind: String in ["mounts", "pets", "outfits", "attachments", "skills", "colour_unlock", "bows", "defences", "market_goods",
			"no_such_kind"]:
		var b := Buy.new(kind, "no_such_thing", 1, -1, "thistle")
		if b.can_run(main) == "" or b.run(main):
			took.append(kind)
	if Buy.new("colour_unlock", "gloomlit", 1, -1, "no_such_look").run(main):
		took.append("colour of an unknown look")
	return t._expect("an unknown id, kind or look is never bought and nothing changes", took.is_empty() and _same(_state(), before),
		{"took": took}) and ok


# ---------------------------------------------------------------- the pet, the mount and the skill circles (Data)
func _check_pet_mount_slots() -> bool:
	_fixture()
	var prices_ok := Data.pet_top() == PET_LEVEL_PRICES.size() and Data.pet_level_price(1).is_empty() \
		and Data.pet_level_price(Data.pet_top() + 1).is_empty()
	for lv: int in range(2, PET_LEVEL_PRICES.size() + 1):
		prices_ok = prices_ok and _same(Data.pet_level_price(lv), PET_LEVEL_PRICES[lv - 1])
		if not Data.building("cottage").is_empty():
			prices_ok = prices_ok and _same(Data.pet_level_price(lv), Data.level_price("cottage", lv))
	Save.camp_level = 2
	var cap_2 := Data.pet_level_cap()
	Save.camp_level = 5
	var cap_5 := Data.pet_level_cap()
	var ok := t._expect("the pet: training to levels 2 and 3 costs the old Cottage's prices, never past the Hearthtree's level",
		prices_ok and cap_2 == 2 and cap_5 == 3, {"cap at Hearthtree 2": cap_2, "cap at 5": cap_5})
	var tiers: Array = []
	for lv: int in range(1, MOUNT_SPEED.size() + 1):
		tiers.append([Data.mount_speed_at(lv), Data.mount_base_hp_at(lv)])
	var tiers_ok := true
	for i: int in MOUNT_SPEED.size():
		tiers_ok = tiers_ok and is_equal_approx(float(tiers[i][0]), float(MOUNT_SPEED[i])) and int(tiers[i][1]) == int(MOUNT_HP[i])
	ok = t._expect("mount tiers 1-5: H4's speed and health for 1-3, the owner's Q6 A for 4 (1.6575x, 18) and 5 (1.785x, 24)",
		tiers_ok, {"tiers": tiers}) and ok
	Save.saddlery["mount_credit"] = 3
	var no_mount := Data.mount_level_at_saddlery(4)
	Save.stations["stall"] = 1
	var carried: Array = [Data.mount_level_at_saddlery(0), Data.mount_level_at_saddlery(1), Data.mount_level_at_saddlery(3),
		Data.mount_level_at_saddlery(4), Data.mount_level_at_saddlery(5)]
	Save.saddlery["mount_credit"] = 0
	var plain: Array = [Data.mount_level_at_saddlery(0), Data.mount_level_at_saddlery(2)]
	ok = t._expect("the mount's level (the owner's Q2 A): 0 without a mount, else the highest of 1, the Saddlery's level and the carried tier",
		no_mount == 0 and _same(carried, [3, 3, 3, 4, 5]) and _same(plain, [1, 2]), {"carried 3": carried, "none carried": plain}) and ok
	# the circles: three, shared; a repeat or an unknown id is an empty circle; a skill outside keeps its learned level
	Save.saddlery = {"skills": {"stomp": 2, "ram": 1, "bellow": 4}, "attach": {}, "worn": "", "skill_slots": ["ram", "ram", "future_skill"]}
	var cleaned := Data.skill_slots()
	var cleaned_ok := _same(cleaned, ["ram", "", ""]) and Data.skill_is_slotted("ram") and not Data.skill_is_slotted("stomp") \
		and not Data.skill_is_slotted("") and Data.active_skill_level("ram") == 1 and Data.active_skill_level("stomp") == 0 \
		and Data.skill_level("stomp") == 2
	Save.saddlery["skill_slots"] = ["stomp", "ram", "pounce", "bellow"]
	var four := Data.skill_slots()
	var four_ok := _same(four, ["stomp", "ram", "pounce"]) and Data.active_skill_level("bellow") == 0 and Data.skill_level("bellow") == 4 \
		and Data.active_skill_level("stomp") == 2 and Data.active_skill_level("pounce") == 0
	Save.saddlery.erase("skill_slots")
	var none_ok := _same(Data.skill_slots(), ["", "", ""]) and Data.active_skill_level("stomp") == 0
	return t._expect("three skill circles (the owner's Q3): never a fourth, a repeat or an unknown id; outside them a skill keeps its level and fights at 0",
		cleaned_ok and four_ok and none_ok and Data.skill_slots().size() == _int(Data.saddlery_cfg().get("skill_slot_count")),
		{"repeat and unknown": cleaned, "four": four}) and ok


# ---------------------------------------------------------------- the frozen to_v5 block
func _check_frozen() -> bool:
	var su: Dictionary = _dict(Data.b.get("save_upgrades"))
	if not t._expect("balance.json save_upgrades has a to_v5 block and its _note_v5", su.get("to_v5") is Dictionary and su.get("_note_v5") is String):
		return false
	var to: Dictionary = su["to_v5"]
	var keys: Array = to.keys()
	keys.sort()
	var want: Array = TO_V5.keys()
	want.sort()
	var ok := t._expect("to_v5 has exactly the agreed keys and values (frozen: what the H4 game gave)", _same(keys, want) and _same(to, TO_V5),
		{"keys": keys})
	# against today's code: Save.migrate_saddlery's mission, skill and old gear, settle_worn's tie order, the old shop order
	var sad: Dictionary = Data.saddlery_cfg()
	var fs: Dictionary = _dict(sad.get("free_stomp"))
	var mission_i := _int(fs.get("mission")) - 1
	var mission_same: bool = fs.is_empty() or (mission_i >= 0 and mission_i < Data.mission_count()
		and String(Data.mission(mission_i)["id"]) == String(to.get("g4_mission")) and String(fs.get("skill", "")) == String(to.get("g4_free_skill")))
	var old_gear: Dictionary = _dict(sad.get("old_attachments"))
	var new_gear: Dictionary = _dict(to.get("g4_gear"))
	var gear_same: bool = old_gear.is_empty() or old_gear.size() == new_gear.size()
	for k: Variant in old_gear:
		var pair: Array = _array(old_gear[k])
		var g: Dictionary = _dict(new_gear.get(k))
		gear_same = gear_same and pair.size() == 2 and String(g.get("id", "")) == String(pair[0]) and _int(g.get("level")) == _int(pair[1])
	var ties_same: bool = not sad.has("worn_tie_order") or _same(sad["worn_tie_order"], to.get("worn_tie_order"))
	var order_same: bool = _same(Data.saddle_items("skills").keys(), to.get("skill_order")) \
		and _int(sad.get("skill_slot_count")) == _int(to.get("skill_slots"))
	var looks: Dictionary = _dict(Data.b.get("looks"))
	var looks_same := true
	for slot: String in ["mount", "pet"]:
		if looks.get(slot) is Array:
			looks_same = looks_same and _same(_ids(looks[slot]), to.get(slot + "_looks"))
	return t._expect("to_v5 agrees with today's code: mission 8 (spitters) and Stomp, the old saddle and bags, the worn tie order, the skills' shop order, 3 circles, the old looks",
		mission_same and gear_same and ties_same and order_same and looks_same,
		{"mission": mission_same, "gear": gear_same, "ties": ties_same, "order": order_same, "looks": looks_same}) and ok


# ---------------------------------------------------------------- the 4 -> 5 save step (dictionaries built here)
func _check_upgrade() -> bool:
	var outs: Array[Dictionary] = []
	var cottage := _up(_v4({"cottage": 2}, {"ruined": ["cottage", "well"], "wear": {"cottage": 0.3, "well": 0.25},
		"spots": {"cottage": [1, 2]}, "crusted": ["cottage"]}))
	outs.append(cottage)
	var ok := t._expect("v4 -> v5, the Cottage only (level 2): the pet keeps level 2 and owns Sprig and Lumi; no mount, Market or Market health",
		_same(_core(cottage), [2, 1, 1, 0, 0, 0, 0, 0]), {"pet, sprig, lumi, thistle, bramblewool, stall, credit, hp": _core(cottage)})
	ok = t._expect("v4 -> v5: the Cottage leaves stations, wear, ruined, crusted and spots; the Well keeps its damage",
		not _dict(cottage.get("stations")).has("cottage") and _same(cottage.get("ruined"), ["well"])
		and _same(cottage.get("wear"), {"well": 0.25}) and _same(cottage.get("crusted"), []) and _same(cottage.get("spots"), {}),
		{"ruined": cottage.get("ruined"), "wear": cottage.get("wear")}) and ok
	var gift := _up(_v4({"cottage": 1}, {"camp_level": 1}))
	outs.append(gift)
	ok = t._expect("v4 -> v5: a Cottage at Hearthtree 1 (an old gift) still gives the pet at level 1 and both looks",
		_same(_core(gift), [1, 1, 1, 0, 0, 0, 0, 0]), {"got": _core(gift)}) and ok
	var market := _up(_v4({"stall": 3}, {"mount_look": "bramblewool", "mount_skin": "snow", "cat_skin": "dusk_ranger",
		"cat_skins_owned": ["original", "dusk_ranger", "future_outfit"]}))
	outs.append(market)
	ok = t._expect("v4 -> v5, the Market only (level 3): built, both mount looks, tier 3 carried, its 500 health kept, Saddlery unbuilt; no pet",
		_same(_core(market), [0, 0, 0, 1, 1, 1, 3, 500]) and _int(_at(market, ["stations", "saddlery"])) == 0, {"got": _core(market)}) and ok
	ok = t._expect("v4 -> v5: the chosen look, colour and outfit stay; the outfits bought (an unknown one too) are owned, the original always; cat_skins_owned goes",
		_text(market.get("mount_look")) == "bramblewool" and _text(market.get("mount_skin")) == "snow" and _text(market.get("cat_skin")) == "dusk_ranger"
		and _lvl(market, "outfits", "original") == 1 and _lvl(market, "outfits", "dusk_ranger") == 1
		and _lvl(market, "outfits", "future_outfit") == 1 and not market.has("cat_skins_owned"), {"owned": market.get("owned")}) and ok
	var both := _up(_v4({"cottage": 1, "stall": 2, "saddlery": 4}, {"pet_look": "lumi", "pet_skin": "gloomlit",
		"unlocks": ["skin:pet:lumi:gloomlit"], "saddlery": {"skills": {}, "attach": {"fire_spitter": 2, "saddle": 1}, "worn": "fire_spitter"},
		"attach": {"owned": ["pet_charm", "mount_shoes"], "mount": "mount_shoes", "pet": "pet_charm"}}))
	outs.append(both)
	ok = t._expect("v4 -> v5, Cottage 1 and Market 2 with Saddlery 4: pet 1, all four looks, tier 2 carried, 340 health, the Saddlery stays 4; looks and colours kept",
		_same(_core(both), [1, 1, 1, 1, 1, 1, 2, 340]) and _int(_at(both, ["stations", "saddlery"])) == 4 and _text(both.get("pet_look")) == "lumi"
		and _text(both.get("pet_skin")) == "gloomlit" and _same(both.get("unlocks"), ["skin:pet:lumi:gloomlit"]), {"got": _core(both)}) and ok
	ok = t._expect("v4 -> v5: Saddlery gear at its levels and expedition gear at 1 go into owned.attachments; the worn ones stay apart; the old lists go",
		_lvl(both, "attachments", "fire_spitter") == 2 and _lvl(both, "attachments", "saddle") == 1 and _lvl(both, "attachments", "pet_charm") == 1
		and _lvl(both, "attachments", "mount_shoes") == 1 and _text(_at(both, ["saddlery", "worn"])) == "fire_spitter"
		and _text(_at(both, ["attach", "mount"])) == "mount_shoes" and _text(_at(both, ["attach", "pet"])) == "pet_charm"
		and not _dict(both.get("saddlery")).has("attach") and not _dict(both.get("attach")).has("owned"), {"owned": both.get("owned")}) and ok
	var fresh := _up(_v4({}))
	outs.append(fresh)
	ok = t._expect("v4 -> v5, nothing built and the default looks chosen (a fresh camp): no pet, no mount looks, no Market, only the original outfit",
		_same(_core(fresh), [0, 0, 0, 0, 0, 0, 0, 0]) and _dict(_at(fresh, ["owned", "pets"])).is_empty()
		and _dict(_at(fresh, ["owned", "mounts"])).is_empty() and _same(_at(fresh, ["owned", "outfits"]), {"original": {"level": 1}}),
		{"owned": fresh.get("owned")}) and ok
	var used := _up(_v4({}, {"pet_look": "lumi", "unlocks": ["skin:mount:thistle:gloomlit"]}))
	outs.append(used)
	ok = t._expect("v4 -> v5, a partial file that chose Lumi and bought a Thistle colour owns both pet looks (pet level 1) and both mount looks",
		_same(_core(used), [1, 1, 1, 1, 1, 0, 0, 0]), {"got": _core(used)}) and ok
	ok = _check_upgrade_skills(outs) and ok
	ok = _check_upgrade_g4(outs) and ok
	var odd := _up(_file({"save_v": 4, "stations": "odd", "saddlery": [], "attach": 5, "cat_skins_owned": "x", "unlocks": {}, "owned": "x"}))
	var odd_levels := _up(_file({"save_v": 4, "stations": {"cottage": 7, "stall": "x"}, "pet_look": 5}))
	outs.append(odd)
	outs.append(odd_levels)
	ok = t._expect("v4 -> v5, odd fields count as none; a Cottage level past the old top is cut to 3",
		_same(_core(odd), [0, 0, 0, 0, 0, 0, 0, 0]) and _lvl(odd, "outfits", "original") == 1 and _same(_at(odd, ["saddlery", "skill_slots"]), ["", "", ""])
		and _same(_core(odd_levels), [3, 1, 1, 0, 0, 0, 0, 0]), {"odd": _core(odd), "levels": _core(odd_levels)}) and ok
	var changed: Array = []
	for i: int in outs.size():
		var o: Dictionary = outs[i]
		if not _same(_up(o.duplicate(true)), o):
			changed.append(i)
		var v5: Dictionary = o.duplicate(true)
		v5["save_v"] = 5
		var sad: Dictionary = _dict(v5.get("saddlery"))
		sad["skill_slots"] = ["", "", ""]
		if not _same(_up(v5.duplicate(true)), v5):
			changed.append("v5 %d" % i)
	return t._expect("v4 -> v5 run again on its own output grants nothing twice; a v5 file (an empty triangle too) is left as it is",
		changed.is_empty(), {"changed": changed}) and ok


func _check_upgrade_skills(outs: Array[Dictionary]) -> bool:
	var learned := {"stomp": 2, "ram": 1, "pounce": 1, "bellow": 3, "future_skill": 2}
	var four := _up(_v4({"stall": 1, "saddlery": 2}, {"saddlery": {"skills": learned,
		"attach": {"saddle": 2, "saddlebags": 2}, "worn": "fire_spitter"}}))
	outs.append(four)
	var ok := t._expect("v4 -> v5, all four skills learned: Stomp, Ram and Pounce fill the circles (the owner's Q3), Bellow stays learned; every level kept, an unknown one too",
		_same(_at(four, ["saddlery", "skill_slots"]), ["stomp", "ram", "pounce"]) and _same(_at(four, ["saddlery", "skills"]), learned),
		{"slots": _at(four, ["saddlery", "skill_slots"])})
	ok = t._expect("v4 -> v5: a worn id that is not owned gives way to the highest owned gear, the first in worn_tie_order on a tie",
		_text(_at(four, ["saddlery", "worn"])) == "saddlebags", {"worn": _at(four, ["saddlery", "worn"])}) and ok
	var two := _up(_v4({"stall": 1}, {"saddlery": {"skills": {"bellow": 1, "ram": 2, "stomp": 0}, "attach": {}, "worn": ""}}))
	outs.append(two)
	return t._expect("v4 -> v5, two skills learned (one at level 0): two circles in the old shop order, the third empty; no gear worn",
		_same(_at(two, ["saddlery", "skill_slots"]), ["ram", "bellow", ""]) and _text(_at(two, ["saddlery", "worn"])) == "",
		{"slots": _at(two, ["saddlery", "skill_slots"])}) and ok


## The G4 conversion, once: a save from before G4 (no saddlery key) with and without the mission-8 win, and one that
## already ran it.
func _check_upgrade_g4(outs: Array[Dictionary]) -> bool:
	var won: Array = _missions(8)
	var seven: Array = _missions(7)
	var pre := _v4({"stall": 2}, {"missions_done": won, "attach": {"owned": ["mount_saddle", "mount_bags", "pet_bell"],
		"mount": "mount_saddle", "pet": "pet_bell"}})
	pre.erase("saddlery")
	var g4 := _up(pre)
	outs.append(g4)
	var ok := t._expect("v4 -> v5, from before G4 with spitters won: Stomp 1, the old saddle at 3 and bags at 5, both notices; the old saddle off the expedition slot, the pet's stays",
		won.has(TO_V5["g4_mission"]) and _int(_at(g4, ["saddlery", "skills", "stomp"])) == 1 and _true(_at(g4, ["flags", "g4_free_stomp"]))
		and _true(_at(g4, ["flags", "g4_old_attach"])) and _lvl(g4, "attachments", "saddle") == 3 and _lvl(g4, "attachments", "saddlebags") == 5
		and _lvl(g4, "attachments", "pet_bell") == 1 and _lvl(g4, "attachments", "mount_saddle") >= 1 and _lvl(g4, "attachments", "mount_bags") >= 1
		and _text(_at(g4, ["attach", "mount"])) == "" and _text(_at(g4, ["attach", "pet"])) == "pet_bell" and _text(_at(g4, ["saddlery", "worn"])) == "saddlebags"
		and _same(_at(g4, ["saddlery", "skill_slots"]), ["stomp", "", ""]), {"saddlery": g4.get("saddlery"), "owned": g4.get("owned")})
	var pre_seven := _v4({"stall": 1}, {"missions_done": seven, "attach": {"owned": ["mount_saddle"], "mount": "", "pet": ""}})
	pre_seven.erase("saddlery")
	var no_win := _up(pre_seven)
	outs.append(no_win)
	ok = t._expect("v4 -> v5, from before G4 without spitters: no Stomp and no Stomp notice; the old saddle still becomes the saddle at 3, worn",
		not seven.has(TO_V5["g4_mission"]) and _int(_at(no_win, ["saddlery", "skills", "stomp"])) == 0 and not _true(_at(no_win, ["flags", "g4_free_stomp"]))
		and _lvl(no_win, "attachments", "saddle") == 3 and _text(_at(no_win, ["saddlery", "worn"])) == "saddle"
		and _same(_at(no_win, ["saddlery", "skill_slots"]), ["", "", ""]), {"saddlery": no_win.get("saddlery")}) and ok
	var ran := _up(_v4({"stall": 1}, {"missions_done": won, "attach": {"owned": ["mount_saddle"], "mount": "", "pet": ""},
		"saddlery": {"skills": {}, "attach": {"saddle": 1}, "worn": "saddle"}}))
	outs.append(ran)
	return t._expect("v4 -> v5, a save that already ran G4 gets neither gift again (no Stomp, the saddle stays 1, no notices)",
		_int(_at(ran, ["saddlery", "skills", "stomp"])) == 0 and _lvl(ran, "attachments", "saddle") == 1 and not _true(_at(ran, ["flags", "g4_free_stomp"]))
		and not _true(_at(ran, ["flags", "g4_old_attach"])) and _text(_at(ran, ["saddlery", "worn"])) == "saddle", {"saddlery": ran.get("saddlery")}) and ok


# ---------------------------------------------------------------- Bramble's trades (scripts/market_trade.gd)
func _check_market() -> bool:
	_fixture()
	Save.stations["stall"] = 1
	Save.leaves = 1000
	var sell_ids: Array = _ids(MarketTrade.offers("sells"))
	var buy_ids: Array = _ids(MarketTrade.offers("buys"))
	var timber_in := MarketTrade.quote("sells", "timber", 2)
	var timber_out := MarketTrade.quote("buys", "timber", 1)
	var ok := t._expect("Bramble's offers by side, timber first from balance.json trade: 2 bundles = 10 timber for 100 leaves; he pays 30 leaves for 5",
		_same(sell_ids, ["timber", "berries", "herbs", "honey", "fish"]) and _same(buy_ids, ["timber", "amber", "goldfish"])
		and _int(timber_in["units"]) == 10 and _same(timber_in["price"], {"leaves": 100}) and _same(timber_out["price"], {"timber": 5})
		and _same(timber_out["payout"], {"leaves": 30}), {"sells": sell_ids, "buys": buy_ids})
	var q := MarketTrade.quote("sells", "berries", 2)
	var most := mini(floori(1000.0 / 30.0), floori(float(Bag.room_for("berries")) / 2.0))
	ok = t._expect("two bundles of Sunberries: 4 berries for 60 leaves; the most is what both the money and the Bag allow",
		_int(q["units"]) == 4 and _same(q["price"], {"leaves": 60}) and _same(q["payout"], {"berries": 4}) and String(q["reason"]) == ""
		and _int(q["max_bundles"]) == most, {"quote": q}) and ok
	var gains: Array = []
	var on_gain := func(kind: String, item_id: String, n: int) -> void: gains.append([kind, item_id, n])
	Events.item_gained.connect(on_gain)
	var bought := Buy.new("market_goods", "berries", 2).run(main)
	Events.item_gained.disconnect(on_gain)
	ok = t._expect("Buy market_goods: two bundles put 4 berries in the Bag for 60 leaves and send one item_gained of 4",
		bought and Bag.count("berries") == 4 and Save.leaves == 940 and _same(gains, [["food", "berries", 4]]), {"gains": gains}) and ok
	var before := _state()
	var top := _int(MarketTrade.quote("sells", "berries", 1)["max_bundles"])
	var refused: bool = String(MarketTrade.quote("sells", "berries", 0)["reason"]) != "" \
		and String(MarketTrade.quote("sells", "berries", -1)["reason"]) != "" \
		and String(MarketTrade.quote("sells", "berries", top + 1)["reason"]) != "" \
		and not Buy.new("market_goods", "berries", 0).run(main) and not Buy.new("market_goods", "berries", -2).run(main) \
		and not Buy.new("market_goods", "berries", top + 1).run(main) and not MarketTrade.sell(main, "berries", 1) \
		and not MarketTrade.sell(main, "timber", 0)
	ok = t._expect("zero, negative and too-big amounts (and an offer Bramble does not make) are refused and change nothing",
		refused and _same(_state(), before), {"most": top}) and ok
	Save.bag = {}
	Save.leaves = 59
	var poor := MarketTrade.quote("sells", "berries", 2)
	ok = t._expect("a buy is bounded by the money: 59 leaves buy 1 bundle, not 2",
		String(poor["reason"]) != "" and _int(poor["max_bundles"]) == 1 and String(MarketTrade.quote("sells", "berries", 1)["reason"]) == ""
		and not Buy.new("market_goods", "berries", 2).run(main) and Save.leaves == 59 and Bag.count("berries") == 0, {"quote": poor}) and ok
	Save.leaves = 1000
	Bag.add("herbs", (Bag.slots() - 1) * Bag.stack_size("herbs"))
	Bag.add("berries", Bag.stack_size("berries") - 3)
	var room := Bag.room_for("berries")
	var full := MarketTrade.quote("sells", "berries", 2)
	ok = t._expect("a buy is bounded by the Bag's room: room for 3 berries takes 1 bundle, not 2 (Bag full)",
		room == 3 and String(full["reason"]) == Data.word("bag_full") and _int(full["max_bundles"]) == 1
		and String(MarketTrade.quote("sells", "berries", 1)["reason"]) == "" and not Buy.new("market_goods", "berries", 2).run(main)
		and Save.leaves == 1000, {"room": room, "quote": full}) and ok
	Save.bag = {}
	ok = _check_market_buys() and ok
	Save.timber = 10
	Save.stations["stall"] = 0
	var unbuilt := MarketTrade.quote("sells", "berries", 1)
	Save.stations["stall"] = 1
	Save.ruined = ["stall"]
	var ruined := MarketTrade.quote("sells", "berries", 1)
	var ruin_why := MarketTrade.building_reason("stall")
	var ruin_sold := MarketTrade.sell(main, "timber", 1)
	var ruin_bought := Buy.new("market_goods", "berries", 1).run(main)
	Save.ruined = []
	return t._expect("Bramble trades only while the Market stands: unbuilt or in ruins every quote says why, the most is 0 and nothing is traded",
		String(unbuilt["reason"]) != "" and _int(unbuilt["max_bundles"]) == 0 and ruin_why != "" and String(ruined["reason"]) == ruin_why
		and _int(ruined["max_bundles"]) == 0 and not ruin_sold and not ruin_bought and Save.timber == 10 and Bag.count("berries") == 0,
		{"unbuilt": unbuilt["reason"], "ruined": ruined["reason"]}) and ok


## Selling to Bramble: amber (gated, two currencies), the Golden Carp, and never Gloom shards.
func _check_market_buys() -> bool:
	Save.mats["amber"] = 3
	Save.missions_done = []
	var shut := MarketTrade.quote("buys", "amber", 1)
	var shut_ok: bool = String(shut["reason"]) == Data.word("after_missions") and _int(shut["max_bundles"]) == 0 \
		and not MarketTrade.sell(main, "amber", 1) and Bag.count("amber") == 3
	Save.missions_done = _missions(Data.mission_count())
	var one := MarketTrade.quote("buys", "amber", 1)
	var two := MarketTrade.quote("buys", "amber", 2)
	var leaves_before := Save.leaves
	var shards_before := Save.shards
	var sold := MarketTrade.sell(main, "amber", 2)
	var open_ok: bool = _same(one["payout"], {"leaves": 1000, "shards": 1}) and _same(two["price"], {"amber": 2}) \
		and _same(two["payout"], {"leaves": 2000, "shards": 2}) and String(two["reason"]) == "" and sold and Bag.count("amber") == 1 \
		and Save.leaves == leaves_before + 2000 and Save.shards == shards_before + 2
	var over := MarketTrade.quote("buys", "amber", 2)
	var over_ok: bool = String(over["reason"]) != "" and _int(over["max_bundles"]) == 1 and not MarketTrade.sell(main, "amber", 2) \
		and Bag.count("amber") == 1 and Save.leaves == leaves_before + 2000
	var ok := t._expect("amber: shut until every Raid Mission is won; then each pays 1,000 leaves and 1 purple shard (two: 2,000 and 2), never more than held",
		shut_ok and open_ok and over_ok, {"shut": shut, "two": two, "over": over})
	Save.missions_done = []
	var carp := MarketTrade.quote("buys", "goldfish", 1)
	Save.shards = 10
	var forged := not MarketTrade.sell(main, "shards", 1) and not MarketTrade.sell(main, "shards", 5) and MarketTrade.offer("buys", "shards").is_empty() \
		and String(MarketTrade.quote("buys", "shards", 1)["reason"]) != "" and Save.shards == 10
	return t._expect("a Golden Carp pays 300 leaves at any time; Bramble never buys purple shards (no offer, a forged sale refused)",
		_same(carp["payout"], {"leaves": 300}) and _same(carp["price"], {"goldfish": 1}) and forged, {"carp": carp}) and ok


# ---------------------------------------------------------------- the Buy command (commands/buy.gd)
func _check_buy() -> bool:
	_fixture()
	var missing: Array = WORDS.filter(func(k: String) -> bool: return not _dict(Data.b.get("windows")).has(k))
	var ok := t._expect("every refusal Buy and the trades give is a word in balance.json windows", missing.is_empty(), {"missing": missing})
	ok = t._expect("MarketTrade.price_ok: shards only for looks, never amber, a zero, a fraction or a non-price; a gate is not money",
		MarketTrade.price_ok({"shards": 60}, true) and not MarketTrade.price_ok({"shards": 60}, false) and not MarketTrade.price_ok({"amber": 1}, true)
		and not MarketTrade.price_ok({"leaves": 0}, false) and not MarketTrade.price_ok({"leaves": 1.5}, false) and not MarketTrade.price_ok(160, false)
		and MarketTrade.price_ok({}, false) and MarketTrade.price_ok({"leaves": 10, "needs_burrows": true}, false)) and ok
	Save.stations["saddlery"] = 2                       # level 2 open, so a stale Learn meets only its staleness
	Save.leaves = 100000
	Save.timber = 10000
	var price: Dictionary = Data.saddle_price("skills", "stomp", 1)
	var gains: Array = []
	var on_gain := func(kind: String, item_id: String, n: int) -> void: gains.append([kind, item_id, n])
	Events.item_gained.connect(on_gain)
	var learn := Buy.new("skills", "stomp", 1, 1)
	var learn_why := learn.can_run(main)
	var learned := learn.run(main)
	var leaves_after := Save.leaves
	var stale := Buy.new("skills", "stomp", 1, 1)
	var stale_why := stale.can_run(main)
	var stale_ran := stale.run(main)
	var ahead_why := Buy.new("skills", "ram", 1, 2).can_run(main)  # a button drawn for a level not reached yet
	Save.stations["saddlery"] = 1
	var cap_why := Buy.new("skills", "stomp", 1, 2).can_run(main)
	Events.item_gained.disconnect(on_gain)
	ok = t._expect("Buy skills: Learn Stomp (expected level 1) pays its price once and sends one item_gained",
		learn_why == "" and learned and Data.skill_level("stomp") == 1 and leaves_after == 100000 - _int(price.get("leaves"))
		and Save.timber == 10000 - _int(price.get("timber")) and _same(gains, [["skills", "stomp", 1]]), {"why": learn_why, "gains": gains}) and ok
	ok = t._expect("Buy refuses a stale expected_level (the same Learn again buys nothing) and a level the button has not reached; the Saddlery's level caps the next",
		stale_why == Data.word("already_owned") and not stale_ran and Data.skill_level("stomp") == 1 and Save.leaves == leaves_after
		and ahead_why != "" and Data.skill_level("ram") == 0 and cap_why == Data.word("max_for_now"),
		{"stale": stale_why, "ahead": ahead_why, "cap": cap_why}) and ok
	return _check_buy_v5() and ok


## The purchases that write the v5 save: refused while the H4 save is live (Stage 1), real once it is switched.
func _check_buy_v5() -> bool:
	_fixture()
	Save.stations["stall"] = 1
	Save.stations["tailor"] = 1
	Save.stations["saddlery"] = 1
	Save.saddlery["skills"] = {"stomp": 1, "ram": 1}
	Save.leaves = 1000
	Save.timber = 100
	var live := Buy.v5_ready()
	var ok := t._expect("the save switch is one step: the v5 reader (Buy.v5_ready) comes with SaveUpgrades.CURRENT_VERSION 5",
		live == (SaveUpgrades.CURRENT_VERSION >= SaveUpgradeV5.TO_VERSION), {"v5_ready": live, "current": SaveUpgrades.CURRENT_VERSION})
	if not live:
		var before := _state()
		var bought: Array = []
		for pair: Array in [["pets", "sprig"], ["pets", "lumi"], ["mounts", "bramblewool"], ["outfits", "dusk_ranger"],
				["attachments", "saddle"], ["attachments", "pet_bell"], ["pet_training", ""]]:
			if Buy.new(String(pair[0]), String(pair[1])).can_run(main) != Data.word("coming_later"):
				bought.append(pair)
		var chose := CompanionShop.choose(main, "mount", "bramblewool")
		var slotted := CompanionShop.assign_skill(main, 0, "stomp")
		print("NOTE the v5 purchase checks (Sprig, Lumi, the skill circles) run once the save is switched (H5 Stage 2)")
		return t._expect("Stage 1: until the v5 save is live, Buy says Coming later to what needs it and the companion choices change nothing",
			bought.is_empty() and not chose and not slotted and _same(_state(), before), {"not refused": bought}) and ok
	var gains: Array = []
	var on_gain := func(kind: String, item_id: String, n: int) -> void: gains.append([kind, item_id, n])
	Events.item_gained.connect(on_gain)
	var lumi_first := Buy.new("pets", "lumi", 1, 1).can_run(main)
	var sprig := Buy.new("pets", "sprig", 1, 1).run(main)
	var after_sprig := Save.leaves
	var again := Buy.new("pets", "sprig", 1, 1).run(main)
	var lumi := Buy.new("pets", "lumi", 1, 1).run(main)
	Events.item_gained.disconnect(on_gain)
	ok = t._expect("v5: Lumi waits for the pet; Sprig's 160 leaves give the pet at level 1 once (the stale Buy pays nothing); then Lumi 400 leaves, looks only",
		lumi_first != "" and sprig and after_sprig == 840 and not again and lumi and Save.leaves == 440 and Data.pet_level() == 1
		and Data.owned_level("pets", "sprig") == 1 and Data.owned_level("pets", "lumi") == 1
		and _same(gains, [["pets", "sprig", 1], ["pets", "lumi", 1]]), {"lumi first": lumi_first, "gains": gains}) and ok
	Save.saddlery["skill_slots"] = ["", "", ""]
	var put := CompanionShop.assign_skill(main, 0, "stomp")
	var moved := CompanionShop.assign_skill(main, 2, "stomp")
	var after_move := Data.skill_slots()
	var unlearned := CompanionShop.assign_skill(main, 1, "pounce")
	var bad_index := CompanionShop.assign_skill(main, 3, "ram")
	var replaced := CompanionShop.assign_skill(main, 2, "ram")
	var after_replace := Data.skill_slots()
	var cleared := CompanionShop.assign_skill(main, 2, "")
	return t._expect("v5 circles: a learned skill goes in, moves (its old circle empties) and is replaced; an unlearned skill or a bad circle is refused; a circle clears",
		put and moved and _same(after_move, ["", "", "stomp"]) and not unlearned and not bad_index and replaced
		and _same(after_replace, ["", "", "ram"]) and cleared and _same(Data.skill_slots(), ["", "", ""]) and Data.skill_level("stomp") == 1,
		{"after move": after_move, "after replace": after_replace}) and ok


# ---------------------------------------------------------------- the save fields: kept, a clean camp, put back
func _keep() -> Dictionary:
	var kept: Dictionary = {}
	for k: String in SAVE_FIELDS:
		if _has(k):
			kept[k] = _copy(Save.get(k))
	return kept


func _restore(kept: Dictionary) -> void:
	for k: Variant in kept:
		Save.set(String(k), _copy(kept[k]))


## A clean camp for one check: no money, nothing built, won, learned, owned or worn, an empty Bag; the rest as it was.
func _fixture() -> void:
	_restore(_kept)
	Save.leaves = 0
	Save.timber = 0
	Save.shards = 0
	Save.camp_level = 2
	var st: Dictionary = Save.stations.duplicate()
	for k: Variant in st:
		st[k] = 0
	Save.stations = st
	Save.ruined = []
	Save.missions_done = []
	Save.flags = {}
	Save.saddlery = {"skills": {}, "attach": {}, "worn": ""}
	Save.attach = {"owned": [], "mount": "", "pet": ""}
	Save.unlocks = []
	Save.bag = {}
	Save.items = {"tower": 0, "spikes": 0}
	Save.mats = {"amber": 0}
	Save.bows = {"twig": 1}
	Save.bow = "twig"
	if _has("owned"):
		Save.set("owned", {})
	if _has("pet_level"):
		Save.set("pet_level", 0)


## The fields a refused purchase or trade must not change, as one value to compare.
func _state() -> Dictionary:
	var s: Dictionary = {}
	for k: String in STATE_FIELDS:
		if _has(k):
			s[k] = _norm(Save.get(k))
	return s


## Save has field k (the v5 fields only once the save is switched).
static func _has(k: String) -> bool:
	return typeof(Save.get(k)) != TYPE_NIL


# ---------------------------------------------------------------- building v4 saves and reading the result
## A v4 save dictionary: V4_BASE, its stations set from levels and its other fields from over, read back the way a
## file is read (JSON numbers).
func _v4(levels: Dictionary, over: Dictionary = {}) -> Dictionary:
	var d: Dictionary = V4_BASE.duplicate(true)
	var stations: Dictionary = d["stations"]
	stations.merge(levels, true)
	d.merge(over, true)
	return _file(d)


static func _file(d: Dictionary) -> Dictionary:
	return _dict(JSON.parse_string(JSON.stringify(d)))


static func _up(d: Dictionary) -> Dictionary:
	return SaveUpgradeV5.upgrade(d)


## What a converted save says about the companions and the Market, in one row: [pet level, Sprig, Lumi, Thistle,
## Bramblewool, Market built, mount credit, Market health floor].
func _core(o: Dictionary) -> Array:
	return [_int(o.get("pet_level")), _lvl(o, "pets", "sprig"), _lvl(o, "pets", "lumi"), _lvl(o, "mounts", "thistle"),
		_lvl(o, "mounts", "bramblewool"), _int(_at(o, ["stations", "stall"])), _int(_at(o, ["saddlery", "mount_credit"])),
		_int(o.get("market_hp_floor"))]


## The owned level of kind/id in a converted save (owned[kind][id].level), 0 for none.
static func _lvl(o: Dictionary, kind: String, id: String) -> int:
	return _int(_at(o, ["owned", kind, id, "level"]))


## The ids of the first n missions, in order.
static func _missions(n: int) -> Array:
	var out: Array = []
	for i: int in mini(n, Data.mission_count()):
		out.append(String(Data.mission(i)["id"]))
	return out


# ---------------------------------------------------------------- helpers
## d[path[0]][path[1]]..., null when a step is missing.
static func _at(d: Variant, path: Array) -> Variant:
	var v: Variant = d
	for k: Variant in path:
		if not v is Dictionary or not (v as Dictionary).has(k):
			return null
		v = (v as Dictionary)[k]
	return v


## The ids of a list of entries or offers, in order.
static func _ids(list: Variant) -> Array:
	var out: Array = []
	for e: Variant in _array(list):
		out.append(String(_dict(e).get("id", "")))
	return out


## Every number as a float and every key as text, all the way down, so a value read from JSON and one written in code
## compare equal.
static func _norm(v: Variant) -> Variant:
	if v is int:
		return float(v)
	if v is Array:
		var list: Array = []
		for e: Variant in v:
			list.append(_norm(e))
		return list
	if v is Dictionary:
		var table: Dictionary = {}
		for k: Variant in v:
			table[str(k)] = _norm((v as Dictionary)[k])
		return table
	return v


static func _same(a: Variant, b: Variant) -> bool:
	return JSON.stringify(_norm(a)) == JSON.stringify(_norm(b))


static func _copy(v: Variant) -> Variant:
	if v is Dictionary:
		return (v as Dictionary).duplicate(true)
	if v is Array:
		return (v as Array).duplicate(true)
	return v


static func _dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}


static func _array(v: Variant) -> Array:
	return v if v is Array else []


static func _int(v: Variant) -> int:
	return int(v) if v is int or v is float else 0


## v as text, "" when it is not text (so a missing or odd field never breaks a comparison).
static func _text(v: Variant) -> String:
	return v if v is String else ""


## v is exactly true (a missing or odd field is not).
static func _true(v: Variant) -> bool:
	return v is bool and v
