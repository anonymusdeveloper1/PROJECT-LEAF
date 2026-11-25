## Versioned save upgrades used by Save after backing up an old file.
## Each step takes one save dictionary, keeps unrelated fields and advances the format by one.
## A step erases every field it converts: save_game() carries each top-level field it does not write
## (`d.merge(_loaded_fields)`), so a field left in the dictionary would stay in the file for ever.
class_name SaveUpgrades
extends RefCounted

const CURRENT_VERSION := 3
const FIRST_STEP_VERSION := 2  # Version 1 still goes through the existing raid fix (raids.gd, by Save.loaded_v).


static func upgrade(d: Dictionary) -> Dictionary:
	var steps: Dictionary[int, Callable] = {
		2: _upgrade_2_to_3,
		# Next step (3 -> 4): add 3: _upgrade_3_to_4.
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
