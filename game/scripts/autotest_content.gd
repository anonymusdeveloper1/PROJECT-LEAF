## Content checks for autotest.gd (docs/ARCHITECTURE.md part 11).
## Checks the hand-written index, entry fields, asset paths, unlocks and the Bag's content.
## Restores the save fields used to test unlocks, repairs and the Bag.
extends Node

const AutotestScript := preload("res://scripts/autotest.gd")
const MainScript := preload("res://scripts/main.gd")
const PlayerScript := preload("res://scripts/player.gd")
const ArrowScript := preload("res://scripts/arrow.gd")

const INDEX_PATH := "res://content/index.json"
## Content in index order.
const CROPS := ["sunberry", "fernmint", "honeybell", "emberpepper", "swiftroot"]
const RECIPES := ["health_potion", "mount_potion", "cooked_fish", "damage_potion", "speed_potion"]
const BOWS := ["twig", "sunwood", "ember", "frost", "volley", "foxfire"]
const BUILDINGS := ["home", "target", "bench", "well", "cottage", "stall", "stone", "garden", "fishing", "saddlery", "tailor"]
## The buildings with a picture rendered from their model in H4 (art/scripts/buildings/pictures.py).
const PICTURED := ["target", "bench", "well", "cottage", "stall", "tailor"]
## The fields an effect may have (the effects list's shared fields, ARCHITECTURE part 5).
const EFFECT_FIELDS := ["type", "target", "share", "stat", "mult", "seconds"]
const TARGETS := ["cat", "mount"]
## Icons not drawn yet: printed as a note, never a failure. Empty since H3 Stage 2 (the owner's Q6 (a)), so a
## missing crop or recipe icon is now a real failure.
const ICONS_PENDING_Q6 := []    # H3 Stage 2: the owner chose (a), stand-ins drawn in ui_icons.gd, so none wait now

var t: AutotestScript
var main: MainScript


func run() -> bool:
	var ok := _check_index()
	ok = _check_crops() and ok
	ok = _check_recipes() and ok
	ok = _check_bows() and ok
	ok = _check_buildings() and ok
	ok = _check_unlocked() and ok
	ok = _check_icons() and ok
	ok = _check_bag_kinds() and ok
	ok = _check_bag_model() and ok
	return ok


# ---------------------------------------------------------------- the index
func _check_index() -> bool:
	var index: Variant = JSON.parse_string(FileAccess.get_file_as_string(INDEX_PATH))
	if not t._expect("content/index.json is readable", index is Dictionary and (index as Dictionary).get("kinds") is Dictionary):
		return false
	var kinds: Dictionary = (index as Dictionary)["kinds"]
	var ok := t._expect("the index lists the 5 crops in order", kinds.get("crops", []) == CROPS, {"crops": kinds.get("crops")})
	ok = t._expect("the index lists the 5 recipes in order", kinds.get("recipes", []) == RECIPES, {"recipes": kinds.get("recipes")}) and ok
	ok = t._expect("the index lists the bows and buildings in order",
		kinds.get("bows", []) == BOWS and kinds.get("buildings", []) == BUILDINGS,
		{"bows": kinds.get("bows"), "buildings": kinds.get("buildings")}) and ok
	ok = t._expect("bow and building entries live in content", not Data.b.has("bows") and not Data.b.has("stations")) and ok
	# written by hand until tools/build_content_index exists: every folder with an entry is listed, and nothing else
	var folders_kinds: Array = []
	for kind: String in DirAccess.get_directories_at("res://content"):
		folders_kinds.append(kind)
	var missing: Array = []
	var extra: Array = []
	for kind: String in folders_kinds:
		var listed: Array = kinds.get(kind, [])
		for id: String in DirAccess.get_directories_at("res://content/" + kind):
			if FileAccess.file_exists("res://content/%s/%s/entry.json" % [kind, id]) and not listed.has(id):
				missing.append("%s/%s" % [kind, id])
	for kind: Variant in kinds:
		for id: Variant in kinds[kind]:
			if not FileAccess.file_exists("res://content/%s/%s/entry.json" % [kind, id]):
				extra.append("%s/%s" % [kind, id])
	ok = t._expect("the index lists every entry folder and nothing else (written by hand until tools/build_content_index)",
		missing.is_empty() and extra.is_empty(), {"not listed": missing, "listed but no entry": extra}) and ok
	# Data reads it: one entry per id, in index order, each id the same as its folder
	var bad_ids: Array = []
	for kind: Variant in kinds:
		var cat := Data.catalog(String(kind))
		var want: Array = kinds[kind]
		if cat.size() != want.size():
			bad_ids.append("%s: %d entries read, %d listed" % [kind, cat.size(), want.size()])
			continue
		for i in want.size():
			if String((cat[i] as Dictionary).get("id", "")) != String(want[i]):
				bad_ids.append("%s/%s" % [kind, want[i]])
	ok = t._expect("Data reads every entry in index order, and each id equals its folder", bad_ids.is_empty(), {"bad": bad_ids}) and ok
	ok = t._expect("Data.crop and Data.recipe give the content entries ({} for an unknown id)",
		Data.crop("sunberry") == Data.item("crops", "sunberry") and Data.recipe("health_potion") == Data.item("recipes", "health_potion")
		and Data.crop("").is_empty() and Data.crop("no_such_crop").is_empty() and Data.recipe("berry_tart").is_empty()) and ok
	return ok


# ---------------------------------------------------------------- crops
func _check_crops() -> bool:
	var bad: Array = []
	var no_model: Array = []
	for id: String in CROPS:
		var c := Data.crop(id)
		var why := _shared_fields(c)
		if not (Data.b["ingredients"] as Dictionary).has(String(c.get("gives", ""))):
			why.append("gives is not an ingredient")
		if not _is_num(c.get("yield")) or int(c.get("yield", 0)) < 1:
			why.append("yield")
		if not _is_num(c.get("grow_s")) or float(c.get("grow_s", 0)) <= 0.0:
			why.append("grow_s")
		why.append_array(_price_problems(c.get("price")))
		if not why.is_empty():
			bad.append({id: why})
		var model := String(c.get("model", ""))
		for stage: String in ["_ripe", "_growing"]:
			if model == "" or not Props.has(model + stage):
				no_model.append(model + stage)
	var ok := t._expect("every crop has name, desc, icon, gives, yield, grow_s and a price in known currencies", bad.is_empty(), {"bad": bad})
	ok = t._expect("every crop's models are in assets/props (<model>_ripe, <model>_growing)", no_model.is_empty(), {"missing": no_model}) and ok
	# the owner's numbers (map part 3.3, Q9 with no answer: Swiftroot 18, Emberpepper 20, from garden level 1)
	var want := {"sunberry": ["berries", 3, 240, 10], "fernmint": ["herbs", 2, 300, 12], "honeybell": ["honey", 2, 360, 15],
		"emberpepper": ["peppers", 2, 480, 20], "swiftroot": ["roots", 2, 420, 18]}
	var off: Array = []
	for id: String in want:
		var c := Data.crop(id)
		var w: Array = want[id]
		if String(c.get("gives", "")) != w[0] or int(c.get("yield", 0)) != w[1] or int(c.get("grow_s", 0)) != w[2] \
				or int((c.get("price", {}) as Dictionary).get("leaves", 0)) != w[3] or c.get("unlock", null) != {}:
			off.append(id)
	ok = t._expect("the crops' numbers are the plan's (gives, yield, grow_s, seed price, open from garden 1)", off.is_empty(), {"off": off}) and ok
	return ok


# ---------------------------------------------------------------- recipes
func _check_recipes() -> bool:
	var bad: Array = []
	for id: String in RECIPES:
		var r := Data.recipe(id)
		var why := _shared_fields(r)
		var needs: Variant = r.get("needs")
		if not needs is Dictionary or (needs as Dictionary).is_empty():
			why.append("needs")
		else:
			for k: Variant in needs:
				if not (Data.b["ingredients"] as Dictionary).has(String(k)) or not _is_num(needs[k]) or int(needs[k]) < 1:
					why.append("needs %s" % k)
		if not _is_num(r.get("cook_s")) or float(r.get("cook_s", 0)) <= 0.0:
			why.append("cook_s")
		if not _is_num(r.get("limit")) or int(r.get("limit", 0)) < 1:
			why.append("limit")
		var fx: Variant = r.get("effects")
		if not fx is Array or (fx as Array).is_empty():
			why.append("effects")
		else:
			for e: Variant in fx:
				why.append_array(_effect_problems(e))
		if not why.is_empty():
			bad.append({id: why})
	var ok := t._expect("every recipe has name, desc, icon, needs (ingredients), cook_s, limit and effects with the shared fields",
		bad.is_empty(), {"bad": bad})
	var want := {"health_potion": [{"herbs": 2, "honey": 1}, 40, 3], "mount_potion": [{"berries": 2, "honey": 1}, 45, 3],
		"cooked_fish": [{"fish": 1}, 30, 10], "damage_potion": [{"peppers": 2, "honey": 1}, 60, 1], "speed_potion": [{"roots": 2, "honey": 1}, 50, 2]}
	var off: Array = []
	for id: String in want:
		var r := Data.recipe(id)
		var w: Array = want[id]
		var needs: Dictionary = r.get("needs", {})
		var same_needs := needs.size() == (w[0] as Dictionary).size()
		for k: String in w[0]:
			same_needs = same_needs and int(needs.get(k, 0)) == int(w[0][k])
		if not same_needs or int(r.get("cook_s", 0)) != w[1] or int(r.get("limit", 0)) != w[2]:
			off.append(id)
	ok = t._expect("the recipes' numbers are the plan's (needs, cook_s, limit)", off.is_empty(), {"off": off}) and ok
	var fish_rule: Dictionary = Data.recipe("cooked_fish").get("unlock", {})
	var others_open := true
	for id: String in RECIPES:
		if id != "cooked_fish":
			others_open = others_open and Data.recipe(id).get("unlock", {}) == {}
	ok = t._expect("Cooked Fish opens with the fishing spot; the other recipes are open from the start",
		_unlock_form_known(fish_rule) and not fish_rule.is_empty() and String(fish_rule["building"][0]) == "fishing"
		and int(fish_rule["building"][1]) == 1 and others_open, {"cooked_fish": fish_rule}) and ok
	return ok


# ---------------------------------------------------------------- bows and buildings
func _check_bows() -> bool:
	var bad: Dictionary = {}
	var ids: Array = []
	for bow: Dictionary in Data.bows():
		var id := String(bow.get("id", ""))
		ids.append(id)
		var why := _shared_fields(bow)
		why.append_array(_price_problems(bow.get("price"), id == "twig"))
		var cost: Variant = bow.get("cost")
		var mastery: Variant = bow.get("mastery")
		if not _is_num(bow.get("damage")) or float(bow["damage"]) <= 0.0:
			why.append("damage")
		if not _is_num(bow.get("arrows")) or int(bow["arrows"]) < 1:
			why.append("arrows")
		if not cost is Array or cost.size() != 10:
			why.append("cost")
		else:
			for amount: Variant in cost:
				if not _is_num(amount) or float(amount) < 0.0:
					why.append("upgrade price")
		if not mastery is Array or mastery.size() != 2:
			why.append("mastery")
		else:
			for price: Variant in mastery:
				why.append_array(_price_problems(price))
		if not ResourceLoader.exists(PlayerScript.bow_path(id)):
			why.append("bow model")
		if not ResourceLoader.exists(ArrowScript.arrow_path(id)):
			why.append("arrow model")
		if Data.bow_picture(id) == "" or not ResourceLoader.exists(Data.bow_picture(id)):
			why.append("picture")
		if not is_same(Data.bow_info(id), Data.item("bows", id)) or not is_same(bow, Data.bow_info(id)):
			why.append("shared entry")
		if not why.is_empty():
			bad[id] = why
	var ok := t._expect("bow entries share their data and have prices, shooting numbers and assets", bad.is_empty(), {"bad": bad})
	return t._expect("Data.bows and Data.bow_ids give the shop order", ids == BOWS and Data.bow_ids() == BOWS, {"ids": ids}) and ok


func _check_buildings() -> bool:
	var bad: Dictionary = {}
	var gifts: Array = []
	for mission: Dictionary in Data.b["missions"]:
		var gift := String(mission.get("gift", ""))
		if not gift.is_empty():
			gifts.append(gift)
	var gift_buildings: Array = []
	var ids: Array = []
	for entry: Dictionary in Data.buildings():
		var id := String(entry.get("id", ""))
		ids.append(id)
		var why := _shared_fields(entry)
		var arrives := String(entry.get("arrives", ""))
		if not arrives in ["menu", "gift", "found", "always"]:
			why.append("arrives")
		why.append_array(_price_problems(entry.get("price"), arrives != "menu"))
		if arrives == "gift":
			gift_buildings.append(id)
		var picture := Data.building_picture(id)
		if picture != "" and not (load(picture) is Texture2D):
			why.append("picture")
		if Data.building_levels(id).is_empty():
			why.append("levels")
		if not why.is_empty():
			bad[id] = why
	var ok := t._expect("Data.buildings gives the indexed entries with shared fields, prices, levels and optional pictures",
		ids == BUILDINGS and bad.is_empty(), {"ids": ids, "bad": bad})
	gifts.sort()
	gift_buildings.sort()
	ok = t._expect("every gift building comes from a mission and every mission gift is a gift building",
		gifts == gift_buildings, {"missions": gifts, "buildings": gift_buildings}) and ok
	# H4: the pictures rendered from the owner's models (assets/ui/buildings); the Saddlery has no model, so its icon shows
	var no_picture: Array = PICTURED.filter(func(id: String) -> bool: return Data.building_picture(id) == "")
	ok = t._expect("the buildings with a model have their picture, the Saddlery none (Data.building_picture)",
		no_picture.is_empty() and Data.building_picture("saddlery") == "", {"missing": no_picture}) and ok
	var levels := Data.building_levels("home")
	ok = t._expect("the Hearthtree has one name for every level", levels.size() == (Data.b["home_names"] as Array).size()) and ok
	return _check_building_refs(levels) and ok


func _check_building_refs(home_levels: Array) -> bool:
	var stats: Dictionary = Data.b["stats"]
	var defences: Dictionary = Data.b["defences"]
	var bad: Array = []
	for id: String in stats:
		if Data.building(String(Data.stat_info(id).get("station", ""))).is_empty():
			bad.append("stat: " + id)
	for level: Dictionary in home_levels:
		for goal: Dictionary in level.get("goals", []):
			var id := String(goal.get("id", ""))
			match String(goal.get("type", "")):
				"station":
					if Data.building(id).is_empty():
						bad.append(goal)
				"bow", "bow_owned":
					if not Data.has_bow(id):
						bad.append(goal)
				"stat":
					if not stats.has(id):
						bad.append(goal)
				"defence":
					if not defences.has(id):
						bad.append(goal)
				"towers":
					if not defences.has("tower"):
						bad.append(goal)
	return t._expect("stats and home goals refer to existing buildings, bows, stats and defences", bad.is_empty(), {"bad": bad})


# ---------------------------------------------------------------- unlock rules
func _check_unlocked() -> bool:
	var bad: Array = []
	for kind: String in ["crops", "recipes", "bows", "buildings"]:
		for e: Dictionary in Data.catalog(kind):
			var rule: Variant = e.get("unlock")
			if not rule is Dictionary or not _unlock_form_known(rule):
				bad.append("%s/%s" % [kind, e.get("id", "?")])
	var ok := t._expect("every unlock rule names known requirements and existing building levels", bad.is_empty(), {"bad": bad})
	var kept_stations := Save.stations
	var kept_flags := Save.flags
	var kept_missions := Save.missions_done
	var kept_home := Save.camp_level
	Save.stations = kept_stations.duplicate()
	Save.flags = kept_flags.duplicate()
	Save.missions_done = []
	Save.camp_level = 1
	Save.stations["fishing"] = 0
	var flag := "content_test_unlock"
	Save.flags.erase(flag)
	var fish_rule := {"building": ["fishing", 1]}
	var flag_rule := {"flag": flag}
	var both := {"building": ["fishing", 1], "flag": flag}
	var mission_rule := {"missions_won": 1}
	var starts_shut := not Data.unlocked(fish_rule) and not Data.unlocked(flag_rule) and not Data.unlocked(both)
	var missions_shut := not Data.unlocked(mission_rule)
	Save.stations["fishing"] = 1
	var fish_only := Data.unlocked(fish_rule) and not Data.unlocked(both) and not Data.unlocked({"building": ["fishing", 2]})
	var missing_flag := Data.unlock_missing(both) == [{"type": "flag", "id": flag}]
	Save.flags[flag] = true
	var both_open := Data.unlocked(flag_rule) and Data.unlocked(both)
	Save.stations["fishing"] = 0
	var flag_only := not Data.unlocked(both) and Data.unlock_missing(both) == [{"type": "building", "id": "fishing", "level": 1}]
	Save.missions_done.append(String(Data.mission(0)["id"]))
	var missions_open := Data.unlocked(mission_rule) and Data.unlock_missing({"missions_won": 2}) == [{"type": "missions_won", "n": 2}]
	ok = t._expect("unlock rules require their building, flag and mission conditions",
		Data.unlocked({}) and Data.unlocked({"building": ["home", 1]}) and starts_shut and fish_only
		and missing_flag and both_open and flag_only and missions_shut and missions_open) and ok
	ok = t._expect("an unknown key or a malformed requirement keeps an unlock rule closed",
		not Data.unlocked({"flag": flag, "unknown": true}) and not Data.unlocked({"building": "fishing"})) and ok

	Save.flags["shop_open"] = true
	var market_shut := not Data.station_open("stall")
	Save.camp_level = 2
	var market_open := Data.station_open("stall")
	Save.missions_done.clear()
	Save.stations["stall"] = 1
	var repair: Dictionary = main.stations.repair_cost("stall")
	Save.stations = kept_stations
	Save.flags = kept_flags
	Save.missions_done = kept_missions
	Save.camp_level = kept_home
	ok = t._expect("the Market opens at Hearthtree 2 and the Well needs Hearthtree 3",
		market_shut and market_open and Data.station_needs_home("well") == 3) and ok
	return t._expect("the Market's repair price includes timber before raids open",
		int(repair.get("timber", 0)) > 0, {"repair": repair}) and ok


func _unlock_form_known(rule: Dictionary) -> bool:
	for key: Variant in rule:
		var value: Variant = rule[key]
		match key:
			"building":
				if not value is Array or value.size() != 2 or not value[0] is String or not _is_num(value[1]):
					return false
				var id := String(value[0])
				var level := int(value[1])
				if Data.building(id).is_empty() or level < 1 or level > Data.building_levels(id).size() or level != value[1]:
					return false
			"flag":
				if not value is String or String(value).is_empty():
					return false
			"missions_won":
				if not _is_num(value) or float(value) < 0.0 or float(value) != floorf(float(value)):
					return false
			_:
				return false
	return true


# ---------------------------------------------------------------- icons
func _check_icons() -> bool:
	var hud: Variant = main.hud
	var unknown: Array = []
	var pending: Array = []
	for kind: String in ["crops", "recipes", "bows", "buildings"]:
		for e: Variant in Data.catalog(kind):
			var icon := String((e as Dictionary).get("icon", ""))
			if hud._icon_known(icon):
				continue
			if ICONS_PENDING_Q6.has(icon):
				pending.append(icon)
			else:
				unknown.append(icon)
	if not pending.is_empty():
		print("NOTE icons not drawn yet (the owner's Q6; they show as plain discs): %s" % ", ".join(pending))
	return t._expect("every crop, recipe, bow and building icon is a HUD icon id", unknown.is_empty(), {"unknown": unknown})


# ---------------------------------------------------------------- the Bag knows the new things by itself
func _check_bag_kinds() -> bool:
	var bad: Array = []
	for id: String in RECIPES:
		var r := Data.recipe(id)
		if Bag.kind_of(id) != "potion" or Bag.stack_size(id) != int(r["limit"]) or Bag.limit(id) != int(r["limit"]) \
				or Bag.effects(id) != r["effects"] or Bag.desc(id) != String(r["desc"]) or Bag.icon(id) != String(r["icon"]) \
				or Bag.name_of(id, 1) != String(r["name"]) or Bag.name_of(id, 2) != String(r["plural"]) or Data.item_name(id, 2) != String(r["plural"]):
			bad.append(id)
	for id: String in CROPS:
		var g := String(Data.crop(id)["gives"])
		if Bag.kind_of(g) != "food" or Bag.stack_size(g) != 20 or Bag.limit(g) != -1 or Bag.desc(g) == "":
			bad.append(g)
	var ok := t._expect("the Bag knows every recipe as a potion and every crop's harvest as food, from the data", bad.is_empty(), {"bad": bad})
	var order := Bag.ids()
	ok = t._expect("the Bag order: food, then potions, then amber, then towers and spikes",
		order.find("goldfish") < order.find("health_potion") and order.find("speed_potion") < order.find("amber")
		and order.find("amber") < order.find("tower") and order.find("tower") < order.find("spikes") and order.find("berries") == 0,
		{"order": order}) and ok
	ok = t._expect("amber is a material, towers and spikes are build items, an unknown id is nothing",
		Bag.kind_of("amber") == "material" and Bag.kind_of("tower") == "build" and Bag.kind_of("spikes") == "build"
		and Bag.kind_of("barricade") == "" and Bag.kind_of("no_such_thing") == "" and Bag.room_for("no_such_thing") == 0) and ok
	ok = t._expect("raw fish and the carp have a Use (mend the mount); garden food has none",
		(Bag.effects("fish") as Array).size() == 1 and (Bag.effects("goldfish") as Array).size() == 1 and Bag.effects("berries").is_empty()) and ok
	return ok


## A short model check of the Bag (the window and placing are --bag's): stacks, room, the potion limit, a full Bag, a
## forced add, all-or-nothing takes and the events. The Bag is put back afterwards.
func _check_bag_model() -> bool:
	var kept_bag := Save.bag.duplicate(true)
	var kept_items := Save.items.duplicate(true)
	var kept_mats := Save.mats.duplicate(true)
	var gained: Array = []
	var changes: Array[int] = [0]
	var on_gain := func(kind: String, id: String, n: int) -> void: gained.append([kind, id, n])
	var on_change := func() -> void: changes[0] += 1
	Events.item_gained.connect(on_gain)
	Events.bag_changed.connect(on_change)
	Save.bag = {}
	Save.items = {"tower": 0, "spikes": 0}
	Save.mats = {"amber": 0}
	var ok := t._expect("an empty Bag: 24 slots free, no stacks", Bag.slots() == 24 and Bag.free_slots() == 24 and Bag.stacks().is_empty())
	var put := Bag.add("berries", 45)
	var st := Bag.stacks()
	var ns: Array = []
	for s: Dictionary in st:
		ns.append(int(s["n"]))
	ok = t._expect("45 berries take 3 slots (20, 20, 5)", put == 45 and Bag.count("berries") == 45 and ns == [20, 20, 5]
		and Bag.used_slots() == 3 and int(st[2]["index"]) == 2, {"stacks": st}) and ok
	ok = t._expect("add sends item_gained(kind, id, added) and bag_changed", gained.size() == 1 and gained[0] == ["food", "berries", 45]
		and changes[0] == 1, {"gained": gained, "changes": changes[0]}) and ok
	ok = t._expect("room for berries: the rest of the last stack plus 21 free slots of 20", Bag.room_for("berries") == 15 + 21 * 20) and ok
	ok = t._expect("a potion is one stack and refuses past its limit", Bag.add("health_potion", 5) == 3 and Bag.count("health_potion") == 3
		and Bag.room_for("health_potion") == 0 and Bag.add("health_potion", 1) == 0 and Bag.used_slots() == 4) and ok
	ok = t._expect("take is all or nothing", not Bag.take("berries", 46) and Bag.count("berries") == 45 and Bag.take("berries", 45)
		and Bag.count("berries") == 0 and not Save.bag.has("berries")) and ok
	ok = t._expect("has_all / take_all are all or nothing", Bag.has_all({"health_potion": 3}) and not Bag.take_all({"health_potion": 2, "herbs": 1})
		and Bag.count("health_potion") == 3 and Bag.take_all({"health_potion": 2}) and Bag.count("health_potion") == 1) and ok
	# fill every slot: 23 more stacks of herbs (the potion holds one slot)
	Bag.add("herbs", 23 * 20)
	ok = t._expect("a full Bag: no free slot, no room for a new thing, a held potion still has room up to its limit",
		Bag.free_slots() == 0 and Bag.room_for("fish") == 0 and Bag.add("fish", 1) == 0 and Bag.room_for("mount_potion") == 0
		and Bag.room_for("health_potion") == 2 and Bag.room_for("herbs") == 0, {"used": Bag.used_slots()}) and ok
	var left := Bag.add_all({"fish": 2, "herbs": 1})
	ok = t._expect("add_all returns what did not fit", left == {"fish": 2, "herbs": 1}, {"left": left}) and ok
	ok = t._expect("a forced add (a thing already paid for) goes in past 24 slots", Bag.add("tower", 1, true) == 1
		and Bag.count("tower") == 1 and int(Save.items["tower"]) == 1 and Bag.used_slots() == 25 and Bag.free_slots() == 0) and ok
	Bag.add("amber", 2, true)
	ok = t._expect("amber goes through Save.mats and counts a slot", int(Save.mats["amber"]) == 2 and Bag.count("amber") == 2
		and Bag.used_slots() == 26 and Bag.take("amber", 2) and int(Save.mats["amber"]) == 0) and ok
	ok = t._expect("an unknown id in the Bag is kept but never counted or shown", _unknown_kept()) and ok
	ok = t._expect("Data's wrappers go through the Bag", Data.has_items({"health_potion": 1}) and Data.take_items({"health_potion": 1})
		and Bag.count("health_potion") == 0 and Data.food_receipt({"herbs": 0}).ends_with("now %d" % Bag.count("herbs"))) and ok
	Events.item_gained.disconnect(on_gain)
	Events.bag_changed.disconnect(on_change)
	Save.bag = kept_bag
	Save.items = kept_items
	Save.mats = kept_mats
	Events.bag_changed.emit()
	return ok


func _unknown_kept() -> bool:
	var before := Bag.used_slots()
	Save.bag["future_food"] = 7
	var shown := false
	for s: Dictionary in Bag.stacks():
		shown = shown or String(s["id"]) == "future_food"
	var ok := Bag.used_slots() == before and not shown and Bag.count("future_food") == 0 and Bag.add("future_food", 1) == 0 \
		and int(Save.bag["future_food"]) == 7
	Save.bag.erase("future_food")
	return ok


# ---------------------------------------------------------------- helpers
## What is wrong with the fields every entry shares here (id, name, desc, icon, unlock).
func _shared_fields(e: Dictionary) -> Array:
	var why: Array = []
	if e.is_empty():
		return ["no entry"]
	for k: String in ["id", "name", "desc", "icon"]:
		if not e.get(k) is String or String(e[k]) == "":
			why.append(k)
	if not e.get("unlock") is Dictionary:
		why.append("unlock")
	return why


func _price_problems(price: Variant, allow_empty: bool = false) -> Array:
	if not price is Dictionary or (price.is_empty() and not allow_empty):
		return ["price"]
	var why: Array = []
	for k: Variant in price:
		if not Data.CURRENCIES.has(String(k)) or not _is_num(price[k]) or int(price[k]) <= 0:
			why.append("price %s" % k)
	return why


func _effect_problems(e: Variant) -> Array:
	if not e is Dictionary or not (e as Dictionary).get("type") is String:
		return ["an effect without a type"]
	var why: Array = []
	for k: Variant in e:
		if not EFFECT_FIELDS.has(String(k)):
			why.append("effect field %s" % k)
	if not TARGETS.has(String((e as Dictionary).get("target", ""))):
		why.append("effect target")
	for k: String in ["share", "mult", "seconds"]:
		if (e as Dictionary).has(k) and (not _is_num(e[k]) or float(e[k]) <= 0.0):
			why.append("effect %s" % k)
	return why


static func _is_num(v: Variant) -> bool:
	return v is int or v is float
