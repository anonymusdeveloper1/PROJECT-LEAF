## Versioned save upgrades used by Save after backing up an old file.
## Each step takes one save dictionary, keeps unrelated fields and advances the format by one.
## A step erases every field it converts: save_game() carries each top-level field it does not write
## (`d.merge(_loaded_fields)`), so a field left in the dictionary would stay in the file for ever.
## A step reads only frozen numbers (balance.json save_upgrades.to_vN) and takes any key missing or odd as none: the
## tests run every step on a bare {"leaves": 5} and on odd dictionaries.
class_name SaveUpgrades
extends RefCounted

const CURRENT_VERSION := 5
const FIRST_STEP_VERSION := 2  # Version 1 still goes through the existing raid fix (raids.gd, by Save.loaded_v).
const UpgradeV5 := preload("res://core/save_upgrade_v5.gd")   # the 4 -> 5 step's moves (H5)


static func upgrade(d: Dictionary) -> Dictionary:
	var steps: Dictionary[int, Callable] = {
		2: _upgrade_2_to_3,
		3: _upgrade_3_to_4,
		4: _upgrade_4_to_5,
		# The legacy raid fix for v1 saves runs by Save.loaded_v (raids.gd), whatever CURRENT_VERSION is.
	}
	var original_version := int(d.get("save_v", 1))
	# The raid fix still owns the v1 version stamp. Start the versioned steps at v2 for those files.
	var version := FIRST_STEP_VERSION if original_version == 1 else original_version
	while version < CURRENT_VERSION and steps.has(version):
		d = steps[version].call(d)
		version += 1
		d["save_v"] = version
	if version != CURRENT_VERSION:
		push_error("Save upgrade stopped at version %d (expected %d)." % [version, CURRENT_VERSION])
	return d


## 2 -> 3 (H1, 25 Nov 2026, the owner): amber is the one expedition material, and the Hollow keys are gone. The save's
## amber, glowstone and heartwood (its mats, and the satchel of a run saved halfway) and its Hollow keys turn into
## leaves at what Bramble paid for them before H1 (balance.json save_upgrades.to_v3). Afterwards mats holds amber at 0
## (and any unknown id, kept), the saved run's satchel holds none of those materials and no key flag, and the save has
## no burrow_keys field. A version-1 dictionary may lack mats, burrow_keys and burrow_run: those count as none.
static func _upgrade_2_to_3(d: Dictionary) -> Dictionary:
	var to: Dictionary = Data.b["save_upgrades"]["to_v3"]
	var rates: Dictionary = to["mat_leaves"]
	var gain := 0
	var md: Variant = d.get("mats", {})
	var mats: Dictionary = (md as Dictionary).duplicate() if md is Dictionary else {}
	gain += _take_mats(mats, rates)
	mats["amber"] = 0
	d["mats"] = mats
	gain += clampi(int(d.get("burrow_keys", 0)), 0, int(to["key_cap"])) * int(to["key_leaves"])   # the old loader held 0-3
	d.erase("burrow_keys")
	var rd: Variant = d.get("burrow_run", {})
	if rd is Dictionary:
		var run: Dictionary = rd
		var sat: Variant = run.get("satchel", {})
		if sat is Dictionary:
			gain += _take_mats(sat as Dictionary, rates)
		run.erase("key")
	d["leaves"] = int(d.get("leaves", 0)) + gain
	return d


## Erases every material of `rates` from `held` and returns what they were worth in leaves (a count below 0 is none).
static func _take_mats(held: Dictionary, rates: Dictionary) -> int:
	var gain := 0
	for k: String in rates:
		if held.has(k):
			gain += maxi(0, int(held[k])) * int(rates[k])
			held.erase(k)
	return gain


## 3 -> 4 (H3, 26 Nov 2026; the owner's plan, Part A: old saves keep what they paid for). Food, potions and the garden
## move to the H3 forms (balance.json save_upgrades.to_v4, frozen):
##   1. the pantry goes into the new Bag (`bag`, {id: count}): every count above 0, with no cap (the old garden gift
##      added berries past the pantry's cap); the pantry field goes
##   2. each old dish id in meal_ready (waiting in the pot) and meal_on (eaten mid-mission) becomes a Health Potion
##      (dish_potion), up to potion_cap in the Bag; each one past that pays dish_leaves leaves. meal_ready, meal_on and
##      a saved run's "meal" go
##   3. snack_choice goes
##   4. a plot with a crop of crop_steps keeps its share of growth (old steps / the crop's steps, 0..1) as the Timers job
##      "crop:<plot>": len = crop_grow_s, start = now - len x share, so it ripens in the rest of the time and looks as
##      far along as it was (an old ripe plot is ripe at once). The plot becomes {"crop": id}; an empty one
##      {"crop": ""}. Old watering is dropped. A plot whose crop id is not in crop_steps is kept exactly as it is (no
##      job: ARCHITECTURE part 10, unknown ids are kept but ignored)
##   5. timers = {"seen": now, "jobs": the crop jobs}
## now is the Timers clock (Timers.clock, not Timers.now(): seen would still be the old save's), so a test that holds
## the clock still holds the upgrade too. Godot makes every autoload and its global name before any _ready runs, so
## this can read Timers while Save loads, although Timers comes after Save.
static func _upgrade_3_to_4(d: Dictionary) -> Dictionary:
	var to: Dictionary = Data.b["save_upgrades"]["to_v4"]
	var now := float(Timers.clock.call()) if Timers.clock.is_valid() else Time.get_unix_time_from_system()
	var bag: Dictionary = {}
	# 1. the pantry
	var pd: Variant = d.get("pantry", {})
	if pd is Dictionary:
		for k: Variant in pd:
			var n := int(_num((pd as Dictionary)[k]))
			if n > 0:
				bag[String(k)] = int(bag.get(String(k), 0)) + n
	d.erase("pantry")
	# 2. the old dishes
	var old_dishes: Array = to["old_dishes"]
	var dishes := 0
	for key: String in ["meal_ready", "meal_on"]:
		var dish: Variant = d.get(key, "")
		if dish is String and old_dishes.has(dish):
			dishes += 1
	var potion := String(to["dish_potion"])
	var room := maxi(0, int(to["potion_cap"]) - int(bag.get(potion, 0)))
	var put := mini(dishes, room)
	if put > 0:
		bag[potion] = int(bag.get(potion, 0)) + put
	if dishes > put:
		d["leaves"] = int(_num(d.get("leaves", 0))) + (dishes - put) * int(to["dish_leaves"])
	d.erase("meal_ready")
	d.erase("meal_on")
	var rd: Variant = d.get("burrow_run", {})
	if rd is Dictionary:
		(rd as Dictionary).erase("meal")
	# 3. the snack choice
	d.erase("snack_choice")
	# 4. the garden
	var steps: Dictionary = to["crop_steps"]
	var grow_s: Dictionary = to["crop_grow_s"]
	var jobs: Dictionary = {}
	var gd: Variant = d.get("garden", [])
	if gd is Array:
		var plots: Array = gd
		for i in plots.size():
			if not plots[i] is Dictionary:
				continue
			var p: Dictionary = plots[i]
			var crop: Variant = p.get("crop", "")
			if not crop is String:
				continue                                    # not a crop id: kept as it is
			var id := String(crop)
			if id == "":
				plots[i] = {"crop": ""}
			elif steps.has(id) and grow_s.has(id):
				var full := maxf(1.0, _num(steps[id]))
				var length := _num(grow_s[id])
				var grown := clampf(_num(p.get("grow", 0)), 0.0, full)
				jobs["crop:%d" % i] = {"start": now - length * grown / full, "len": length, "data": {"crop": id}, "told": false}
				plots[i] = {"crop": id}
			# else: an unknown crop id, kept exactly as it is (no job)
	# 5. the new fields
	d["timers"] = {"seen": now, "jobs": jobs}
	d["bag"] = bag
	return d


## 4 -> 5 (H5, 27 Nov 2026; the owner's answers Q1-Q5): the Mushroom Cottage leaves the camp and what the shops sell
## gets one form, owned[kind][id] = {"level": n}; the pet gets one shared level, the Market one level, the mount a
## carried tier and the Saddlery three skill circles. Its moves are in core/save_upgrade_v5.gd (frozen numbers:
## balance.json save_upgrades.to_v5); it erases every field it converts (cat_skins_owned, saddlery.attach,
## attach.owned, the Cottage everywhere).
static func _upgrade_4_to_5(d: Dictionary) -> Dictionary:
	return UpgradeV5.upgrade(d)


## A JSON number as a float; anything else counts as 0.
static func _num(v: Variant) -> float:
	return float(v) if (v is float or v is int) else 0.0
