## Content checks for autotest.gd (`-- --autotest --fresh --content`; docs/ARCHITECTURE.md part 11).
## H3 (26 Nov 2026): the crops and recipes are content folders (game/content/<kind>/<id>/entry.json). Until
## tools/build_content_index exists, game/content/index.json is written by hand, so this checks that it lists every
## entry folder and nothing else. It also checks each entry's fields, its models (Props) and icons (the HUD's icon ids),
## the unlock rules (Data.unlocked), and that the Bag knows every new thing by itself (core/bag.gd reads the kinds from
## data). The effect types are checked in --bag (core/effects.gd comes later in H3).
## Uses Data, Save, Bag, Props and the HUD's icons. Changes only Save.stations (put back) and the Bag (put back).
extends Node

const AutotestScript := preload("res://scripts/autotest.gd")
const MainScript := preload("res://scripts/main.gd")

const INDEX_PATH := "res://content/index.json"
## The H3 entries, in index order (the build map, part 3.3).
const CROPS := ["sunberry", "fernmint", "honeybell", "emberpepper", "swiftroot"]
const RECIPES := ["health_potion", "mount_potion", "cooked_fish", "damage_potion", "speed_potion"]
## The fields an effect may have (the effects list's shared fields, ARCHITECTURE part 5).
const EFFECT_FIELDS := ["type", "target", "share", "stat", "mult", "seconds"]
const TARGETS := ["cat", "mount"]
## Icons not drawn yet (the owner's question Q6): printed as a note until they are, never a failure.
const ICONS_PENDING_Q6 := ["peppers", "roots", "health_potion", "mount_potion", "cooked_fish", "damage_potion", "speed_potion"]

var t: AutotestScript
var main: MainScript


func run() -> bool:
	var ok := _check_index()
	ok = _check_crops() and ok
	ok = _check_recipes() and ok
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


# ---------------------------------------------------------------- unlock rules
func _check_unlocked() -> bool:
	var bad: Array = []
	for kind: String in ["crops", "recipes"]:
		for e: Variant in Data.catalog(kind):
			var rule: Variant = (e as Dictionary).get("unlock")
			if not rule is Dictionary or not _unlock_form_known(rule):
				bad.append("%s/%s" % [kind, (e as Dictionary).get("id", "?")])
	var ok := t._expect("every unlock rule is a form Data.unlocked knows and points to a building that exists", bad.is_empty(), {"bad": bad})
	var was := int(Save.stations.get("fishing", 0))
	Save.stations["fishing"] = 0
	var shut := not Data.unlocked({"building": ["fishing", 1]})
	Save.stations["fishing"] = 1
	var open := Data.unlocked({"building": ["fishing", 1]}) and not Data.unlocked({"building": ["fishing", 2]})
	Save.stations["fishing"] = was
	ok = t._expect("Data.unlocked: {} is open; a building rule opens at its level; the home counts as a building",
		Data.unlocked({}) and shut and open and Data.unlocked({"building": ["home", 1]}), {"shut": shut, "open": open}) and ok
	ok = t._expect("Data.unlocked: a rule of another form stays shut", not Data.unlocked({"flag": "no_such_flag"})
		and not Data.unlocked({"building": "fishing"}) and not Data.unlocked({"building": ["fishing", 1], "flag": "x"})) and ok
	return ok


func _unlock_form_known(rule: Dictionary) -> bool:
	if rule.is_empty():
		return true
	var bld: Variant = rule.get("building")
	if rule.size() != 1 or not bld is Array or (bld as Array).size() != 2:
		return false
	var id := String(bld[0])
	return (id == "home" or (Data.b["stations"] as Dictionary).has(id)) and _is_num(bld[1]) and int(bld[1]) >= 1


# ---------------------------------------------------------------- icons
func _check_icons() -> bool:
	var hud: Variant = main.hud
	var unknown: Array = []
	var pending: Array = []
	for kind: String in ["crops", "recipes"]:
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
	return t._expect("every crop and recipe icon is a HUD icon id (or one still waiting for Q6)", unknown.is_empty(), {"unknown": unknown})


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


func _price_problems(price: Variant) -> Array:
	if not price is Dictionary or (price as Dictionary).is_empty():
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
