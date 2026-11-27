## Save checks for autotest.gd (`-- --autotest --fresh --saves`).
## Uses Save, Events, Timers, Bag and the v2, v3, v4 and v5 fixtures. Reads and writes only a scratch save and its backup
## during checks.
## H1: the v2 fixture stays a real version-2 save; loading it runs the 2 -> 3 upgrade (core/save_upgrades.gd): its
## amber, glowstone, heartwood and Hollow keys become leaves, only amber is left (at 0), and burrow_keys is gone.
## H3 (26 Nov 2026): then the 3 -> 4 step: the pantry goes into the Bag, an old dish becomes a Health Potion, the snack
## choice goes, and a half-grown crop keeps its share as a Timers job. The v3 fixture is upgraded the same way; the v4
## fixture loads as it is. The Timers clock is held still for the whole test (fake_now: a whole second, never later than
## the real now): the 3 -> 4 step reads it, so every load of an old file gives the same file again and the whole-file
## compares hold (and no future "seen" can reach the test save).
## H3, the real first launch of an old save (two runs, like --resume): `--saves --startup=1` (with --fresh) puts the v3
## fixture in the test slot, and `--saves --startup=2` (without --fresh) checks what Save._ready made of it at launch
## (_check_startup). Until Stage 2's garden.gd is in, run 2 also logs the old garden's script errors (map risk 17).
## H5 (27 Nov 2026): the save is version 5, so every older file also takes the 4 -> 5 step (core/save_upgrade_v5.gd:
## the Mushroom Cottage goes, owned, the shared pet level, the one-level Market, the skill circles). The v2, v3 and v4
## fixtures stay as they were; the v4 fixture is now upgraded (backed up first, its Cottage 2 and Market 3 become pet
## level 2, both pet and mount looks, mount tier 3 and the Market's 500 health), and the v5 fixture loads as it is.
## A file the step made is expected to be exactly the step's output (SaveUpgradeV5.upgrade, checked case by case in
## --h5found) as Save writes it back; the v4 and v5 fixtures are also checked against fixed numbers here.
extends Node

const AutotestScript := preload("res://scripts/autotest.gd")
const MainScript := preload("res://scripts/main.gd")
const SaveUpgradeV5 := preload("res://core/save_upgrade_v5.gd")

const SAMPLE_PATH := "res://tests/saves/v2_sample.json"
const TEST_PATH := "user://leaf_save_test_saves.json"
const BACKUP_PATH := "user://leaf_save_test_saves.bak.json"
## H1 (the owner, 25 Nov 2026): what Bramble paid before H1, so what the 2 -> 3 upgrade gives for each material and key.
const V3_MAT_LEAVES := {"amber": 25, "glowstone": 50, "heartwood": 150}
const V3_KEY_LEAVES := 150
const V3_KEY_CAP := 3
## The frozen version-3 fixture (hand-written in the format save_game writes). H3: loading it runs the 3 -> 4 step.
const SAMPLE_V3_PATH := "res://tests/saves/v3_sample.json"
## H3: the frozen version-4 fixture (hand-written in the format save_game writes, fixed whole-second times): loading it
## must change nothing.
const SAMPLE_V4_PATH := "res://tests/saves/v4_sample.json"
## H5: the frozen version-5 fixture (core/save_upgrade_v5.gd's output for a mid-game v4 save): loading it changes nothing.
const SAMPLE_V5_PATH := "res://tests/saves/v5_sample.json"
## H6: the frozen version-6 fixture (levels on the pieces, held stock levels, a credit, the Defence Workshop): loading it changes nothing.
const SAMPLE_V6_PATH := "res://tests/saves/v6_sample.json"
## H5: the version before the 4 -> 5 step.
const V4 := 4
## H3 (the owner's plan, 26 Nov 2026; balance.json save_upgrades.to_v4, frozen): what the 3 -> 4 step does.
const V4_OLD_DISHES := ["berry_tart", "fernmint_tea", "honey_cake", "hearth_stew", "fish_skewers", "root_stew", "carp_feast"]
const V4_DISH_POTION := "health_potion"
const V4_POTION_CAP := 3
const V4_DISH_LEAVES := 50
const V4_CROP_STEPS := {"sunberry": 4, "fernmint": 5, "honeybell": 6}
const V4_CROP_GROW_S := {"sunberry": 240, "fernmint": 300, "honeybell": 360}
const OLD_FOOD_KEYS := ["pantry", "snack_choice", "meal_ready", "meal_on"]

var t: AutotestScript
var main: MainScript
## H3: the held clock (Timers.clock is _fake_clock for the whole test).
var fake_now := 0.0


func _fake_clock() -> float:
	return fake_now


func run() -> bool:
	var startup := _startup_step()
	if startup == 1:
		return _prepare_startup()
	if startup == 2:
		return _check_startup()
	var sample_text := FileAccess.get_file_as_string(SAMPLE_PATH)
	var sample: Variant = JSON.parse_string(sample_text)
	if not t._expect("the v2 save fixture is readable", sample is Dictionary and int(sample.get("save_v", 0)) == 2):
		return false

	var original_path := Save.path
	if not t._expect("the save test starts in the autotest slot", original_path == "user://leaf_save_test.json"):
		return false
	Save.save_game(true)
	var was_frozen := main.frozen
	main.frozen = true
	Save.path = TEST_PATH
	if FileAccess.file_exists(BACKUP_PATH):
		DirAccess.remove_absolute(BACKUP_PATH)
	# H3: hold the Timers clock still for the whole test, at a whole second that is never later than the real now
	fake_now = floorf(Time.get_unix_time_from_system())
	Timers.clock = _fake_clock
	var ok := await _check_saves(sample_text, sample)
	Save.path = original_path
	Timers.use_real_clock()                            # the real clock again before the test save is loaded back
	Save.load_game()
	main.frozen = was_frozen
	for scratch_path: String in [TEST_PATH, BACKUP_PATH, TEST_PATH + ".tmp", BACKUP_PATH + ".tmp"]:
		if FileAccess.file_exists(scratch_path):
			DirAccess.remove_absolute(scratch_path)
	return ok


func _check_saves(sample_text: String, sample: Dictionary) -> bool:
	var ok := _check_upgrade_rules(sample)
	if not t._expect("the v2 fixture is copied to the scratch slot", _write_test_save(sample_text)):
		return false
	Save.load_game()
	await get_tree().process_frame
	var want_leaves := int(sample["leaves"]) + _v2_worth(sample)
	ok = t._expect("H1: the v2 sample's amber, glowstone, heartwood and keys become leaves (%d + %d)" % [int(sample["leaves"]), _v2_worth(sample)],
		Save.leaves == want_leaves and Save.loaded_v == 2 and Save.save_v == SaveUpgrades.CURRENT_VERSION,
		{"leaves": Save.leaves, "want": want_leaves, "loaded_v": Save.loaded_v, "save_v": Save.save_v}) and ok
	ok = t._expect("H1: after the upgrade only amber is held, at 0", Save.mats == {"amber": 0}, {"mats": Save.mats}) and ok
	ok = t._expect("H3: the v2 sample's pantry is in the Bag and its waiting dish is a Health Potion",
		Save.bag == {"berries": 5, "herbs": 3, "honey": 1, "fish": 2, "health_potion": 1}, {"bag": Save.bag}) and ok
	ok = t._expect("H3: the v2 sample's half-grown crops keep their share (2 of 4 steps, 1 of 5) as Timers jobs",
		is_equal_approx(Timers.progress("crop:0"), 0.5) and is_equal_approx(Timers.left("crop:0"), 120.0)
		and is_equal_approx(Timers.progress("crop:1"), 0.2) and is_equal_approx(Timers.left("crop:1"), 240.0)
		and Save.garden[0] == {"crop": "sunberry"} and Save.garden[1] == {"crop": "fernmint"} and Save.garden[2] == {"crop": ""}
		and float(Save.timers["seen"]) == fake_now, {"timers": Save.timers, "garden": Save.garden}) and ok
	ok = t._expect("the v2 file is backed up before it is upgraded", FileAccess.file_exists(BACKUP_PATH)
		and FileAccess.get_file_as_string(BACKUP_PATH) == sample_text) and ok
	Save.save_game(true)
	var written: Variant = _read_test_save()
	ok = t._expect("the v2 sample survives load and save (as the upgraded current save)", written == _upgraded(sample), {"written": written}) and ok
	ok = t._expect("H1: the written file has no burrow_keys", written is Dictionary and not (written as Dictionary).has("burrow_keys")) and ok
	ok = t._expect("H3: the written file has no pantry, snack choice or dishes", written is Dictionary and _no_old_food(written as Dictionary)) and ok
	ok = t._expect("H1: the written mats hold only amber, at 0", written is Dictionary and (written as Dictionary).get("mats") == {"amber": 0.0},
		{"mats": (written as Dictionary).get("mats") if written is Dictionary else null}) and ok
	ok = t._expect("a successful write leaves no temporary file", not FileAccess.file_exists(TEST_PATH + ".tmp")) and ok

	# the written current file loads again unchanged: no second conversion, and a current save needs no backup
	var written_text := FileAccess.get_file_as_string(TEST_PATH)
	DirAccess.remove_absolute(BACKUP_PATH)
	Save.load_game()
	await get_tree().process_frame
	Save.save_game(true)
	ok = t._expect("H1: loading the written file again changes nothing (no double conversion)", Save.leaves == want_leaves
		and Save.loaded_v == SaveUpgrades.CURRENT_VERSION and FileAccess.get_file_as_string(TEST_PATH) == written_text,
		{"leaves": Save.leaves, "loaded_v": Save.loaded_v}) and ok
	ok = t._expect("a current save needs no backup", not FileAccess.file_exists(BACKUP_PATH)) and ok

	# a v2 save with a run saved halfway: the satchel's materials become leaves too, and its key flag goes
	ok = await _check_saved_run(sample) and ok
	DirAccess.remove_absolute(BACKUP_PATH)
	ok = await _check_v3_sample() and ok
	DirAccess.remove_absolute(BACKUP_PATH)
	ok = await _check_v4_sample() and ok
	DirAccess.remove_absolute(BACKUP_PATH)
	ok = await _check_v5_sample() and ok
	DirAccess.remove_absolute(BACKUP_PATH)
	ok = await _check_v6_sample() and ok
	DirAccess.remove_absolute(BACKUP_PATH)

	# A file without a version goes through the v1 load path (and, H1, the 2 -> 3 step too).
	var old := sample.duplicate(true)
	old.erase("save_v")
	old["owned"] = {"future_kind": {"future_item": {"level": 3}}}
	old["bows"]["future_bow"] = 4
	old["burrows"]["old_hollow"]["future_reward"] = {"count": 2}
	old["saddlery"]["skills"]["future_skill"] = 2
	var old_text := JSON.stringify(old, "  ") + "\n"
	var expected: Dictionary = _upgraded(JSON.parse_string(old_text))
	if not t._expect("the older save is written to the scratch slot", _write_test_save(old_text)):
		return false

	var loaded: Array[bool] = [false]
	var backed_up: Array[bool] = [false]
	var on_save_loaded := func() -> void:
		loaded[0] = true
		backed_up[0] = FileAccess.file_exists(BACKUP_PATH) \
			and FileAccess.get_file_as_bytes(BACKUP_PATH) == old_text.to_utf8_buffer()
	Events.save_loaded.connect(on_save_loaded, CONNECT_ONE_SHOT)
	Save.load_game()
	ok = t._expect("loading remembers the original version", Save.loaded_v == 1) and ok
	ok = t._expect("save_loaded is deferred", not loaded[0]) and ok
	await get_tree().process_frame
	if Events.save_loaded.is_connected(on_save_loaded):
		Events.save_loaded.disconnect(on_save_loaded)
	ok = t._expect("save_loaded fires after loading", loaded[0]) and ok
	ok = t._expect("the older file's original bytes are backed up before save_loaded", backed_up[0]) and ok
	ok = t._expect("H1: the v1 save is upgraded too (its keys and materials as leaves)", Save.leaves == int(expected["leaves"])
		and Save.mats == {"amber": 0} and Save.save_v == SaveUpgrades.CURRENT_VERSION, {"leaves": Save.leaves, "mats": Save.mats}) and ok
	Save.save_game(true)
	ok = t._expect("the older save round-trips its known data and unknown keys", _read_test_save() == expected, {"written": _read_test_save()}) and ok

	if not t._expect("the corrupt main save is written to the scratch slot", _write_test_save("{")):
		return false
	Save.leaves = 0
	Save.load_game()
	ok = t._expect("a corrupt main save loads the backup", Save.leaves == int(expected["leaves"]) and Save.loaded_v == 1) and ok
	await get_tree().process_frame
	Save.flush()
	ok = t._expect("the recovered save replaces the corrupt main file", _read_test_save() == expected) and ok

	# A rewrite would remove the trailing newline, even if the saved state were identical.
	var clean_text := FileAccess.get_file_as_string(TEST_PATH) + "\n"
	if not t._expect("the clean-flush sentinel is written", _write_test_save(clean_text)):
		return false
	Save.flush()
	ok = t._expect("a clean flush leaves the file untouched", FileAccess.get_file_as_string(TEST_PATH) == clean_text) and ok
	Save.leaves += 1
	expected["leaves"] = float(Save.leaves)
	Save.hold_flush = true
	Save.flush()
	ok = t._expect("a held flush leaves the file untouched", FileAccess.get_file_as_string(TEST_PATH) == clean_text) and ok
	Save.hold_flush = false
	Save.flush()
	ok = t._expect("the leaves change flushes after the hold", _read_test_save() == expected) and ok

	Save.add_mat("amber", 1)
	expected["mats"]["amber"] += 1
	Save.flush()
	ok = t._expect("add_mat marks the save dirty", _read_test_save() == expected) and ok

	Bag.add("berries", 1)
	expected["bag"]["berries"] += 1
	Save.flush()
	return t._expect("H3: Bag.add marks the save dirty", _read_test_save() == expected) and ok


## H1: the step's numbers (balance.json save_upgrades.to_v3) are the owner's, and it takes a bare version-1 dictionary
## (no mats, no raids, no run) and an odd one (counts below 0, no satchel) without trouble.
func _check_upgrade_rules(sample: Dictionary) -> bool:
	var to: Dictionary = Data.b.get("save_upgrades", {}).get("to_v3", {})
	var ok := t._expect("H1: balance.json save_upgrades.to_v3 pays what Bramble paid before H1",
		to.get("mat_leaves", {}) == {"amber": 25.0, "glowstone": 50.0, "heartwood": 150.0} and int(to.get("key_leaves", 0)) == V3_KEY_LEAVES
		and int(to.get("key_cap", 0)) == V3_KEY_CAP, {"to_v3": to})
	ok = t._expect("H1: the v2 sample holds glowstone, heartwood and keys to convert", int(sample["mats"].get("glowstone", 0)) > 0
		and int(sample["mats"].get("heartwood", 0)) > 0 and int(sample.get("burrow_keys", 0)) > 0) and ok
	var bare := SaveUpgrades.upgrade({"leaves": 5})
	ok = t._expect("H1: a bare version-1 dictionary upgrades (no mats, raids or run)", int(bare.get("save_v", 0)) == SaveUpgrades.CURRENT_VERSION
		and int(bare["leaves"]) == 5 and bare.get("mats") == {"amber": 0} and not bare.has("burrow_keys"), {"got": bare}) and ok
	var odd := SaveUpgrades.upgrade({"save_v": 2, "leaves": 10, "burrow_keys": -1, "mats": {"glowstone": -3, "future_mat": 2},
		"burrow_run": {"v": 2, "key": false}})
	ok = t._expect("H1: odd counts are worth nothing, unknown ids are kept", int(odd["leaves"]) == 10 and odd["mats"] == {"amber": 0, "future_mat": 2}
		and not (odd["burrow_run"] as Dictionary).has("key"), {"got": odd}) and ok
	# both sides of the key cap: exactly the cap's worth at the cap, and still only the cap's worth far above it
	for held_keys: int in [V3_KEY_CAP, 9]:
		var capped := SaveUpgrades.upgrade({"save_v": 2, "leaves": 0, "burrow_keys": held_keys, "mats": {}})
		ok = t._expect("H1: %d Hollow keys give exactly %d x key_leaves" % [held_keys, V3_KEY_CAP],
			int(capped["leaves"]) == V3_KEY_CAP * V3_KEY_LEAVES, {"got": capped}) and ok
	ok = _check_upgrade_rules_v4(bare, odd) and ok
	ok = _check_upgrade_rules_v5(bare) and ok
	return ok


## H5: the bare dictionary takes the 4 -> 5 step too and ends as a fresh v5 camp: no pet, no Market (stall 0), no
## mount look or carried tier, no Market health, only the original outfit, three empty circles and nothing worn.
func _check_upgrade_rules_v5(bare: Dictionary) -> bool:
	var owned: Dictionary = bare.get("owned") if bare.get("owned") is Dictionary else {}
	return t._expect("H5: a bare dictionary also takes the 4 -> 5 step and ends as a fresh v5 camp (no pet, no Market, the original outfit, empty circles)",
		SaveUpgrades.CURRENT_VERSION == 6 and bare.get("defence_reserves") == {} and bare.get("defence_legacy_credit") == {} and int(bare.get("pet_level", -1)) == 0 and int(bare.get("market_hp_floor", -1)) == 0
		and bare.get("stations") == {"stall": 0} and owned.get("outfits") == {"original": {"level": 1}}
		and owned.get("pets") == {} and owned.get("mounts") == {} and owned.get("attachments") == {}
		and bare.get("attach") == {"mount": "", "pet": ""} and not bare.has("cat_skins_owned")
		and bare.get("saddlery") == {"skills": {}, "skill_slots": ["", "", ""], "worn": "", "mount_credit": 0}, {"got": bare})


## H3: the 3 -> 4 step's numbers (balance.json save_upgrades.to_v4) are the frozen ones; the bare dictionary ends with an
## empty Bag and no jobs; the odd v2 one (no pantry, garden or dishes) upgrades without trouble; and an odd v3 one shows
## the step's edge rules: counts above 0 only and no cap, the potion cap with leaves for an extra dish, a saved run's
## dish, a grown-out crop ripe at once, a crop without steps from the start, an unknown crop and a broken plot kept.
func _check_upgrade_rules_v4(bare: Dictionary, odd: Dictionary) -> bool:
	var to: Dictionary = Data.b.get("save_upgrades", {}).get("to_v4", {})
	var ok := t._expect("H3: balance.json save_upgrades.to_v4 holds the frozen numbers", to.get("old_dishes", []) == V4_OLD_DISHES
		and String(to.get("dish_potion", "")) == V4_DISH_POTION and int(to.get("potion_cap", 0)) == V4_POTION_CAP
		and int(to.get("dish_leaves", 0)) == V4_DISH_LEAVES and _same_ints(to.get("crop_steps", {}), V4_CROP_STEPS)
		and _same_ints(to.get("crop_grow_s", {}), V4_CROP_GROW_S), {"to_v4": to})
	ok = t._expect("H3: the bare dictionary ends with an empty Bag and no jobs, seen at the clock", bare.get("bag") == {}
		and bare.get("timers") == {"seen": fake_now, "jobs": {}} and _no_old_food(bare), {"got": bare}) and ok
	ok = t._expect("H3: the odd v2 dictionary (no pantry, garden or dishes) upgrades to v4", int(odd.get("save_v", 0)) == SaveUpgrades.CURRENT_VERSION
		and odd.get("bag") == {} and odd.get("timers") == {"seen": fake_now, "jobs": {}} and int(odd["leaves"]) == 10
		and _no_old_food(odd), {"got": odd}) and ok
	var odd3 := SaveUpgrades.upgrade({"save_v": 3, "leaves": 0,
		"pantry": {"berries": 25, "herbs": -2, "weird": "x", "health_potion": 2},
		"meal_ready": "honey_cake", "meal_on": "carp_feast", "snack_choice": "fish",
		"garden": [{"crop": "honeybell", "grow": 9, "wet": 2}, {"crop": "moonmelon", "grow": 3, "wet": 1}, "junk", {"crop": ""},
			{"crop": "fernmint"}],
		"burrow_run": {"v": 2, "meal": "berry_tart"}})
	var jobs: Dictionary = (odd3.get("timers", {}) as Dictionary).get("jobs", {})
	ok = t._expect("H3: the pantry goes into the Bag with no cap (counts above 0 only)", int(odd3.get("save_v", 0)) == SaveUpgrades.CURRENT_VERSION
		and odd3.get("bag") == {"berries": 25, "health_potion": 3} and _no_old_food(odd3), {"got": odd3}) and ok
	ok = t._expect("H3: two old dishes with room for one more potion: one Health Potion, %d leaves for the other" % V4_DISH_LEAVES,
		int(odd3["leaves"]) == V4_DISH_LEAVES and odd3.get("burrow_run") == {"v": 2}, {"leaves": odd3["leaves"], "run": odd3.get("burrow_run")}) and ok
	var garden: Array = odd3.get("garden", [])
	ok = t._expect("H3: the plots: a known crop becomes {crop}, an empty one {crop: \"\"}, an unknown crop and a broken plot are kept",
		garden.size() == 5 and garden[0] == {"crop": "honeybell"} and garden[1] == {"crop": "moonmelon", "grow": 3, "wet": 1}
		and garden[2] == "junk" and garden[3] == {"crop": ""} and garden[4] == {"crop": "fernmint"}, {"garden": garden}) and ok
	ok = t._expect("H3: a grown-out crop is ripe at once, a crop with no steps starts now, an unknown crop gets no job",
		jobs.size() == 2 and jobs.get("crop:0") == {"start": fake_now - 360.0, "len": 360.0, "data": {"crop": "honeybell"}, "told": false}
		and jobs.get("crop:4") == {"start": fake_now, "len": 300.0, "data": {"crop": "fernmint"}, "told": false}
		and float((odd3["timers"] as Dictionary)["seen"]) == fake_now, {"jobs": jobs}) and ok
	return ok


## H1: a v2 save whose run was saved halfway: amber, glowstone and heartwood in the satchel become leaves as well, the
## satchel keeps nothing of them, the key flag is gone; the rest of the run is kept.
func _check_saved_run(sample: Dictionary) -> bool:
	var d := sample.duplicate(true)
	var sat := {"amber": 3, "glowstone": 2, "heartwood": 1}
	d["burrow_run"] = {"v": 2, "map": "old_hollow", "map_v": 1, "burrow": "old_hollow", "level": 2, "seed": 7, "checkpoint": "moonwell",
		"cleared": [], "chests": [], "hp": 5, "boons": ["sharp"], "satchel": sat, "first_run": false, "key": true}
	if not t._expect("the v2 save with a run saved halfway is written", _write_test_save(JSON.stringify(d, "  ") + "\n")):
		return false
	Save.load_game()
	await get_tree().process_frame
	var want := int(sample["leaves"]) + _v2_worth(sample) + _mat_worth(sat)
	var r: Dictionary = Save.burrow_run
	var ok := t._expect("H1: a saved run's satchel becomes leaves too (%d more)" % _mat_worth(sat), Save.leaves == want, {"leaves": Save.leaves, "want": want})
	ok = t._expect("H1: the saved run keeps no materials and no key flag, and the rest of it", (r.get("satchel", {}) as Dictionary).is_empty()
		and not r.has("key") and String(r.get("checkpoint", "")) == "moonwell" and int(r.get("level", 0)) == 2 and (r.get("boons", []) as Array) == ["sharp"],
		{"run": r}) and ok
	Save.save_game(true)
	var written: Variant = _read_test_save()
	ok = t._expect("H1: the written run has no key flag and an empty satchel", written is Dictionary
		and not ((written as Dictionary)["burrow_run"] as Dictionary).has("key") and ((written as Dictionary)["burrow_run"]["satchel"] as Dictionary).is_empty()) and ok
	Save.load_game()
	await get_tree().process_frame
	ok = t._expect("H1: loading it again adds nothing", Save.leaves == want, {"leaves": Save.leaves}) and ok
	return ok


## H3: the frozen v3 fixture is upgraded to v4 (the build map, part 3.13). It is backed up first; its leaves (no 2 -> 3
## step), items, amber, unknown material and saved run's satchel are kept; the pantry is in the Bag and the waiting dish
## a Health Potion; the half-grown crops are Timers jobs (sunberry 2 of 4: len 240 from now - 120; fernmint 1 of 5: len
## 300 from now - 60); seen is now; it saves as the current version (H5: 5, after the 4 -> 5 step too) without
## burrow_keys, the old food keys or the run's dish.
func _check_v3_sample() -> bool:
	var text := FileAccess.get_file_as_string(SAMPLE_V3_PATH)
	var s: Variant = JSON.parse_string(text)
	if not t._expect("the v3 save fixture is readable", s is Dictionary and int(s.get("save_v", 0)) == 3 and not s.has("burrow_keys")):
		return false
	if not t._expect("the v3 fixture is copied to the scratch slot", _write_test_save(text)):
		return false
	if FileAccess.file_exists(BACKUP_PATH):
		DirAccess.remove_absolute(BACKUP_PATH)
	Save.load_game()
	await get_tree().process_frame
	var ok := t._expect("H3: the v3 sample loads as version 3 and is upgraded to the current version (H5: 5)", Save.loaded_v == 3
		and Save.save_v == SaveUpgrades.CURRENT_VERSION and SaveUpgrades.CURRENT_VERSION == 6, {"loaded_v": Save.loaded_v, "save_v": Save.save_v})
	ok = t._expect("H3: the v3 file is backed up before it is upgraded", FileAccess.file_exists(BACKUP_PATH)
		and FileAccess.get_file_as_string(BACKUP_PATH) == text) and ok
	ok = t._expect("the v3 sample's leaves are not converted (one dish, and room for it)", Save.leaves == int(s["leaves"]), {"leaves": Save.leaves}) and ok
	ok = t._expect("the v3 sample keeps its amber and its unknown material", int(Save.mats.get("amber", -1)) == 3
		and int(Save.mats.get("future_mat", -1)) == 1, {"mats": Save.mats}) and ok
	ok = t._expect("the v3 sample keeps its saved run's satchel and has no key flag or dish",
		int((Save.burrow_run.get("satchel", {}) as Dictionary).get("amber", -1)) == 2 and not Save.burrow_run.has("key")
		and not Save.burrow_run.has("meal"), {"run": Save.burrow_run}) and ok
	ok = t._expect("H3: the v3 sample keeps its towers and spikes to place", Save.items == {"tower": 1, "spikes": 2}, {"items": Save.items}) and ok
	ok = t._expect("H3: the v3 sample's pantry is in the Bag and its waiting dish is a Health Potion",
		Save.bag == {"berries": 5, "herbs": 3, "honey": 1, "fish": 2, "health_potion": 1}, {"bag": Save.bag}) and ok
	var want_jobs := {"crop:0": {"start": fake_now - 120.0, "len": 240.0, "data": {"crop": "sunberry"}, "told": false},
		"crop:1": {"start": fake_now - 60.0, "len": 300.0, "data": {"crop": "fernmint"}, "told": false}}
	ok = t._expect("H3: the v3 sample's half-grown crops are Timers jobs with their share, and seen is now",
		Save.timers.get("jobs") == want_jobs and float(Save.timers["seen"]) == fake_now and Save.garden[0] == {"crop": "sunberry"}
		and Save.garden[1] == {"crop": "fernmint"} and Save.garden[5] == {"crop": ""}, {"timers": Save.timers, "garden": Save.garden}) and ok
	Save.save_game(true)
	var written: Variant = _read_test_save()
	ok = t._expect("H3: the v3 sample is saved as the current version without burrow_keys, the old food keys or the run's dish", written is Dictionary
		and int((written as Dictionary).get("save_v", 0)) == SaveUpgrades.CURRENT_VERSION and not (written as Dictionary).has("burrow_keys")
		and _no_old_food(written as Dictionary), {"written": written}) and ok
	ok = t._expect("H3: the written Bag and jobs are the upgraded ones", written is Dictionary
		and (written as Dictionary).get("bag") == {"berries": 5.0, "herbs": 3.0, "honey": 1.0, "fish": 2.0, "health_potion": 1.0}
		and (written as Dictionary).get("timers") == {"seen": fake_now, "jobs": want_jobs},
		{"bag": (written as Dictionary).get("bag") if written is Dictionary else null}) and ok
	ok = t._expect("H5: the written v3 sample is the 4 -> 5 step's output, as Save writes it back", written == _upgraded_v5(s),
		{"written": written}) and ok
	return ok


## H3: the frozen v4 fixture (fixed whole-second times). The clock is held at the fixture's own seen, so its growing
## job is still growing and its ripe one keeps told; a check sends nothing (the ripe job was told before it was saved).
## H5: it is upgraded now (4 -> 5), so it is backed up first, byte for byte. Its Mushroom Cottage 2, Market 3 and
## Saddlery 2 become pet level 2 with Sprig and Lumi, a built Market with Thistle and Bramblewool, mount tier 3 carried
## (the mount rides at 3), the Market's 500 health kept; its Dusk Ranger, Mossweave Saddle 2 (worn) and Stomp 2 (in the
## first circle) stay owned; the written file has none of the old forms and is the step's output field for field. The
## held clock goes back to fake_now afterwards.
func _check_v4_sample() -> bool:
	var text := FileAccess.get_file_as_string(SAMPLE_V4_PATH)
	var s: Variant = JSON.parse_string(text)
	if not t._expect("H3: the v4 save fixture is readable", s is Dictionary and int(s.get("save_v", 0)) == V4
			and (s as Dictionary).get("timers") is Dictionary and _no_old_food(s as Dictionary)):
		return false
	if not t._expect("H3: the v4 fixture is copied to the scratch slot", _write_test_save(text)):
		return false
	if FileAccess.file_exists(BACKUP_PATH):
		DirAccess.remove_absolute(BACKUP_PATH)
	var held := fake_now
	fake_now = float(s["timers"]["seen"])
	Save.load_game()
	await get_tree().process_frame
	var ok := t._expect("H5: the v4 sample loads as version 4 and is upgraded to the current version (H6: 6)", Save.loaded_v == V4 and Save.save_v == 6
		and SaveUpgrades.CURRENT_VERSION == 6, {"loaded_v": Save.loaded_v, "save_v": Save.save_v})
	ok = t._expect("H5: the v4 file is backed up byte for byte before it is upgraded", FileAccess.file_exists(BACKUP_PATH)
		and FileAccess.get_file_as_string(BACKUP_PATH) == text) and ok
	ok = t._expect("H3: the v4 sample's Bag: food, a potion, and an unknown id kept but not counted",
		Save.bag == {"berries": 5, "herbs": 3, "honey": 1, "fish": 2, "health_potion": 1, "future_food": 4}
		and Bag.count("health_potion") == 1 and Bag.count("future_food") == 0, {"bag": Save.bag}) and ok
	ok = t._expect("H3: the growing job is still growing, the ripe one is done and keeps told", Timers.has("crop:0")
		and not Timers.done("crop:0") and is_equal_approx(Timers.left("crop:0"), 120.0) and Timers.done("crop:1")
		and Save.timers["jobs"]["crop:0"]["told"] == false and Save.timers["jobs"]["crop:1"]["told"] == true
		and String(Timers.job_data("crop:0").get("crop", "")) == "sunberry" and float(Save.timers["seen"]) == fake_now,
		{"timers": Save.timers}) and ok
	var sent: Array = []
	var on_finished := func(id: String) -> void: sent.append(id)
	Events.timer_finished.connect(on_finished)
	Timers.check()
	Events.timer_finished.disconnect(on_finished)
	ok = t._expect("H3: a check sends nothing for a job told before it was saved", sent.is_empty(), {"sent": sent}) and ok
	ok = t._expect("H5: the v4 sample's Cottage 2 is pet level 2 with Sprig and Lumi, its Market 3 a built Market with both mount looks",
		not Save.stations.has("cottage") and int(Save.stations.get("stall", -1)) == 1 and Save.pet_level == 2 and Data.pet_level() == 2
		and Data.owned_level("pets", "sprig") == 1 and Data.owned_level("pets", "lumi") == 1
		and Data.owned_level("mounts", "thistle") == 1 and Data.owned_level("mounts", "bramblewool") == 1,
		{"stations": Save.stations, "pet_level": Save.pet_level, "owned": Save.owned}) and ok
	ok = t._expect("H5: the mount keeps tier 3 with the Saddlery at 2 (mount_credit 3), and the Market keeps its 500 health",
		int(Save.stations.get("saddlery", -1)) == 2 and int(Save.saddlery.get("mount_credit", -1)) == 3 and Data.mount_level() == 3
		and Save.market_hp_floor == 500 and Data.building_hp("stall", 1) == 500.0,
		{"saddlery": Save.saddlery, "floor": Save.market_hp_floor, "mount_level": Data.mount_level()}) and ok
	ok = t._expect("H5: the Dusk Ranger is still owned and worn; the Mossweave Saddle 2 owned and worn; Stomp 2 in the first circle",
		Save.cat_skin == "dusk_ranger" and Data.cat_skin_owned("dusk_ranger") and not Data.cat_skin_owned("nightfall_ranger")
		and Data.attach_level("saddle") == 2 and Data.worn_attach() == "saddle" and Data.skill_level("stomp") == 2
		and _slots_text() == "stomp,," and Data.active_skill_level("stomp") == 2,
		{"slots": Data.skill_slots(), "owned": Save.owned}) and ok
	Save.save_game(true)
	var written: Variant = _read_test_save()
	var w: Dictionary = written if written is Dictionary else {}
	ok = t._expect("H5: the written v4 sample has no old form: no cat_skins_owned, saddlery.attach, attach.owned or Cottage",
		int(w.get("save_v", 0)) == 6 and not w.has("cat_skins_owned") and not (w.get("saddlery", {}) as Dictionary).has("attach")
		and not (w.get("attach", {}) as Dictionary).has("owned") and not (w.get("stations", {}) as Dictionary).has("cottage")
		and not (w.get("wear", {}) as Dictionary).has("cottage"), {"written": written}) and ok
	ok = t._expect("H5: the written v4 sample is the 4 -> 5 step's output field for field (seen, the growing job and told stay)",
		written == _upgraded_v5(s), {"written": written}) and ok
	fake_now = held
	return ok


## H6: the frozen v5 fixture is backed up byte for byte and takes the 5 -> 6 step: the placed pieces carry their kind's old
## level, the file has no def_levels, and a mixed-level v5 camp (towers held, a worn tower, a row with uneven wear, a paid
## kind with nothing to carry it) keeps every paid level and its wear, and gives its credit once.
func _check_v5_sample() -> bool:
	var text := FileAccess.get_file_as_string(SAMPLE_V5_PATH)
	var s: Variant = JSON.parse_string(text)
	if not t._expect("H6: the v5 save fixture is readable", s is Dictionary and int(s.get("save_v", 0)) == 5
			and (s as Dictionary).get("def_levels") is Dictionary):
		return false
	if not t._expect("H6: the v5 fixture is copied to the scratch slot", _write_test_save(text)):
		return false
	if FileAccess.file_exists(BACKUP_PATH):
		DirAccess.remove_absolute(BACKUP_PATH)
	var held := fake_now
	fake_now = float(s["timers"]["seen"])
	Save.load_game()
	await get_tree().process_frame
	var ok := t._expect("H6: the v5 sample loads as version 5, is upgraded to 6 and is backed up byte for byte", Save.loaded_v == 5 and Save.save_v == 6
		and FileAccess.file_exists(BACKUP_PATH) and FileAccess.get_file_as_string(BACKUP_PATH) == text, {"loaded_v": Save.loaded_v, "save_v": Save.save_v})
	Save.save_game(true)
	var written: Variant = _read_test_save()
	var w: Dictionary = written if written is Dictionary else {}
	ok = t._expect("H6: the written v5 sample is the 5 -> 6 step's output field for field, without def_levels",
		written == _upgraded_v5(s) and not w.has("def_levels") and int(w.get("save_v", 0)) == 6, {"written": written}) and ok
	var placed: Array = w.get("placed", [])
	ok = t._expect("H6: the v5 sample's row keeps its old level 2 and its tower level 1 on the pieces, and nothing is held or owed",
		placed.size() == 2 and int(placed[0].get("level", 0)) == 2 and int(placed[1].get("level", 0)) == 1
		and w.get("defence_reserves") == {} and w.get("defence_legacy_credit") == {}, {"placed": placed}) and ok
	# a mixed-level v5 camp (a second file in the same run)
	var mixed: Dictionary = (s as Dictionary).duplicate(true)
	mixed["def_levels"] = {"barricade": 3, "tower": 4, "spikes": 5}
	mixed["items"] = {"tower": 2, "spikes": 0}
	mixed["placed"] = [
		{"type": "tower", "x": -8.25, "z": 11.5, "rot": 0.4, "wreck": 0.35},
		{"type": "barricade", "slot": [0, 2], "row": 3, "wrecks": [-1.0, 0.0, 0.65], "wreck": 0.0},
	]
	var mixed_text := JSON.stringify(mixed, "  ") + "\n"
	if not t._expect("H6: the mixed-level v5 file is written", _write_test_save(mixed_text)):
		return false
	DirAccess.remove_absolute(BACKUP_PATH)
	Save.load_game()
	await get_tree().process_frame
	Save.save_game(true)
	var mw: Variant = _read_test_save()
	var m: Dictionary = mw if mw is Dictionary else {}
	var mp: Array = m.get("placed", [])
	ok = t._expect("H6: a mixed-level v5 camp: every placed piece takes its kind's level and keeps its wear, held towers keep their level, a paid kind with no piece becomes a credit",
		mp.size() == 2 and int(mp[0].get("level", 0)) == 4 and is_equal_approx(float(mp[0].get("wreck", 0.0)), 0.35)
		and int(mp[1].get("level", 0)) == 3 and JSON.stringify(mp[1].get("wrecks", [])) == JSON.stringify([-1.0, 0.0, 0.65])
		and JSON.stringify(m.get("defence_reserves")) == JSON.stringify(JSON.parse_string("{\"tower\": [{\"level\": 4}, {\"level\": 4}]}"))
		and JSON.stringify(m.get("defence_legacy_credit")) == JSON.stringify(JSON.parse_string("{\"spikes\": 5}"))
		and not m.has("def_levels") and FileAccess.get_file_as_string(BACKUP_PATH) == mixed_text, {"written": mw}) and ok
	Save.load_game()
	await get_tree().process_frame
	Save.save_game(true)
	ok = t._expect("H6: loading the written file again keeps the reserves and the credit exactly (no second conversion)", _read_test_save() == mw, {"written": _read_test_save()}) and ok
	fake_now = held
	return ok


## H6: the frozen v6 fixture loads as it is (no conversion, no backup) and is written back field for field, with the
## clock held at its own seen. Data reads it: pet level 2 with Lumi out, the mount at tier 2 (Saddlery 2, credit 2),
## the Market's 340 health, Stomp and Ram in the circles, the saddle worn. Then the same file with an empty triangle
## stays empty after a reload, and a second, bare v5 file loaded in the same run keeps nothing of the first one's
## companions, buildings or gear.
func _check_v6_sample() -> bool:
	var text := FileAccess.get_file_as_string(SAMPLE_V6_PATH)
	var s: Variant = JSON.parse_string(text)
	if not t._expect("H6: the v6 save fixture is readable", s is Dictionary and int(s.get("save_v", 0)) == 6
			and (s as Dictionary).get("owned") is Dictionary and (s as Dictionary).get("timers") is Dictionary):
		return false
	(s as Dictionary)["camp_day_s"] = float(Data.day_night_cfg()["start_s"])
	if not t._expect("H6: the v6 fixture is copied to the scratch slot", _write_test_save(text)):
		return false
	if FileAccess.file_exists(BACKUP_PATH):
		DirAccess.remove_absolute(BACKUP_PATH)
	var held := fake_now
	fake_now = float(s["timers"]["seen"])
	Save.load_game()
	await get_tree().process_frame
	var ok := t._expect("H6: the v6 sample loads as version 6 and is not backed up", Save.loaded_v == 6 and Save.save_v == 6
		and not FileAccess.file_exists(BACKUP_PATH), {"loaded_v": Save.loaded_v})
	ok = t._expect("H6: Data reads the v6 sample: pet level 2 with Lumi out, the mount at tier 2, the Market's 340 health",
		Data.pet_level() == 2 and Save.pet_look == "lumi" and Data.owned_level("pets", "lumi") == 1 and Save.mount_look == "bramblewool"
		and Data.owned_level("mounts", "bramblewool") == 1 and Data.mount_level() == 2 and Data.building_hp("stall", 1) == 340.0,
		{"pet": Data.pet_level(), "mount": Data.mount_level(), "hp": Data.building_hp("stall", 1)}) and ok
	ok = t._expect("H6: Data reads the v6 sample: Stomp and Ram in the circles, the saddle 2 worn, the Dusk Ranger owned and worn",
		_slots_text() == "stomp,ram," and Data.active_skill_level("ram") == 1 and Data.active_skill_level("pounce") == 0
		and Data.worn_attach() == "saddle" and Data.attach_level("saddle") == 2 and Save.cat_skin == "dusk_ranger"
		and Data.cat_skin_owned("dusk_ranger") and not Data.cat_skin_owned("nightfall_ranger"),
		{"slots": Data.skill_slots(), "worn": Data.worn_attach()}) and ok
	var rows_ok: bool = Save.placed.size() == 2 and int(Save.placed[0].get("level", 0)) == 2 and int(Save.placed[1].get("level", 0)) == 3 \
		and is_equal_approx(float(Save.placed[1].get("wreck", 0.0)), 0.35) and (Save.placed[0].get("wrecks", []) as Array).size() == 3
	ok = t._expect("H6: the v6 sample keeps each piece's own level and wear, the held stock's levels and the unused credit, and no def_levels",
		rows_ok and JSON.stringify(Save.defence_reserves) == JSON.stringify({"tower": [{"level": 3}, {"level": 2, "wreck": 0.25}]})
		and JSON.stringify(Save.defence_legacy_credit) == JSON.stringify({"spikes": 2})
		and int(Save.stations.get("workshop", 0)) == 2 and Data.station_level("workshop") == 2,
		{"placed": Save.placed, "reserves": Save.defence_reserves, "credit": Save.defence_legacy_credit}) and ok
	Save.save_game(true)
	ok = t._expect("H6: the v6 sample survives load and save field for field", _read_test_save() == s, {"written": _read_test_save()}) and ok
	Save.load_game()
	await get_tree().process_frame
	Save.save_game(true)
	ok = t._expect("H6: a second load and save of the v6 sample changes nothing (reserves and credit are not used up or repeated)",
		_read_test_save() == s and not FileAccess.file_exists(BACKUP_PATH), {"written": _read_test_save()}) and ok
	# an empty triangle the player chose stays empty: no refill on reload, every learned level kept
	var empty: Dictionary = (s as Dictionary).duplicate(true)
	empty["saddlery"]["skill_slots"] = ["", "", ""]
	if not t._expect("H6: the v6 sample with an empty triangle is written", _write_test_save(JSON.stringify(empty, "  ") + "\n")):
		return false
	Save.load_game()
	await get_tree().process_frame
	Save.save_game(true)
	var again: Variant = _read_test_save()
	var again_slots: Variant = (again as Dictionary).get("saddlery", {}).get("skill_slots") if again is Dictionary else null
	ok = t._expect("H5: an empty triangle stays empty after a reload, and the learned skills keep their levels",
		_slots_text() == ",," and Data.skill_level("stomp") == 2 and Data.skill_level("ram") == 1
		and again_slots == ["", "", ""] and again == empty, {"written": again}) and ok
	# a second file loaded in the same run starts from the defaults: nothing of the first one's companions or gear
	if not t._expect("H6: a bare v6 file is written", _write_test_save(JSON.stringify({"save_v": 6, "leaves": 7}) + "\n")):
		return false
	Save.load_game()
	await get_tree().process_frame
	ok = t._expect("H6: a second, bare v6 file keeps nothing of the first: no levels, reserves, credit, pet, Market, mount, gear, outfit, skills or Market health",
		Save.leaves == 7 and Save.pet_level == 0 and Data.pet_level() == 0 and Data.owned_level("pets", "lumi") == 0
		and int(Save.stations.get("stall", -1)) == 0 and int(Save.stations.get("saddlery", -1)) == 0 and Data.mount_level() == 0
		and Save.market_hp_floor == 0 and Save.defence_reserves.is_empty() and Save.defence_legacy_credit.is_empty() and Save.placed.is_empty() and int(Save.stations.get("workshop", -1)) == 0 and Data.attach_level("saddle") == 0 and Data.worn_attach() == ""
		and not Data.cat_skin_owned("dusk_ranger") and Save.cat_skin == "original"
		and (Save.saddlery.get("skills", {}) as Dictionary).is_empty() and int(Save.saddlery.get("mount_credit", -1)) == 0
		and _slots_text() == ",," and Save.pet_look == "sprig",
		{"owned": Save.owned, "stations": Save.stations, "saddlery": Save.saddlery}) and ok
	fake_now = held
	return ok


## H3: 1 or 2 from `--startup=<n>` (the first-launch check's two runs), 0 for the usual --saves checks.
func _startup_step() -> int:
	for a: String in Data.args():
		if a.begins_with("--startup="):
			return int(a.substr(10))
	return 0


## H3, run 1 of the first-launch check (`-- --autotest --fresh --saves --startup=1`): the test slot becomes the v3
## fixture byte for byte, and its old backup and temporary files go (a stale backup would prove nothing in run 2). The
## automatic flushes are held, so quitting does not write the fresh state over it.
func _prepare_startup() -> bool:
	var slot := Save.path
	if not t._expect("startup 1: the save test runs in the autotest slot", slot == "user://leaf_save_test.json"):
		return false
	Save.hold_flush = true
	var backup := slot.get_basename() + ".bak.json"
	for p: String in [slot + ".tmp", backup, backup + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	var text := FileAccess.get_file_as_string(SAMPLE_V3_PATH)
	var f := FileAccess.open(slot, FileAccess.WRITE)
	var stored := f != null and f.store_string(text)
	if f != null:
		f.close()
	return t._expect("startup 1: the test slot holds the v3 fixture, with no backup or temporary file", stored
		and FileAccess.get_file_as_string(slot) == text and not FileAccess.file_exists(backup)
		and not FileAccess.file_exists(slot + ".tmp"))


## H3, run 2 (`-- --autotest --saves --startup=2`, without --fresh): Save._ready loaded the v3 fixture that run 1 left
## in the slot, at launch, before Timers was in the tree (the 3 -> 4 step reads Timers.clock then). It was backed up
## first, as it was; the upgrade gave the numbers of the build map part 3.13 at the real clock: the two jobs' starts
## sit 120 s and 60 s before one moment U of this launch, and seen is U or later. It saves as the current version (H5: 5) with no old food key,
## and the jobs' starts round-trip within 0.01 s (map risk 5). The old garden.gd's errors on the {crop} plots (risk 17)
## are not judged here.
func _check_startup() -> bool:
	var text := FileAccess.get_file_as_string(SAMPLE_V3_PATH)
	var s: Variant = JSON.parse_string(text)
	if not t._expect("startup 2: the v3 save fixture is readable", s is Dictionary and int((s as Dictionary).get("save_v", 0)) == 3):
		return false
	var fixture: Dictionary = s
	var real_now := Time.get_unix_time_from_system()
	var launched := real_now - Time.get_ticks_msec() / 1000.0
	var backup := Save.path.get_basename() + ".bak.json"
	var ok := t._expect("startup 2: the save test runs in the autotest slot", Save.path == "user://leaf_save_test.json")
	ok = t._expect("startup 2: the v3 file on disk was loaded at launch as version 3 and upgraded to the current version (H5: 5)", Save.loaded_v == 3
		and Save.save_v == SaveUpgrades.CURRENT_VERSION and SaveUpgrades.CURRENT_VERSION == 6,
		{"loaded_v": Save.loaded_v, "save_v": Save.save_v}) and ok
	var bak_text := FileAccess.get_file_as_string(backup) if FileAccess.file_exists(backup) else ""
	var bak: Variant = JSON.parse_string(bak_text) if bak_text != "" else null
	ok = t._expect("startup 2: the v3 file was backed up as it was before the upgrade (save_v 3, %d leaves)" % int(fixture["leaves"]),
		bak_text == text and bak is Dictionary and int((bak as Dictionary).get("save_v", 0)) == 3
		and int((bak as Dictionary).get("leaves", -1)) == int(fixture["leaves"]),
		{"backup_exists": FileAccess.file_exists(backup), "same_bytes": bak_text == text}) and ok
	var satchel: Dictionary = Save.burrow_run.get("satchel", {})
	ok = t._expect("startup 2: the leaves, towers and spikes, amber, unknown material and the run's satchel are kept",
		Save.leaves == int(fixture["leaves"]) and Save.items == {"tower": 1, "spikes": 2} and int(Save.mats.get("amber", -1)) == 3
		and int(Save.mats.get("future_mat", -1)) == 1 and int(satchel.get("amber", -1)) == 2 and not Save.burrow_run.has("meal"),
		{"leaves": Save.leaves, "items": Save.items, "mats": Save.mats, "run": Save.burrow_run}) and ok
	ok = t._expect("startup 2: the pantry is in the Bag and the waiting dish is a Health Potion",
		Save.bag == {"berries": 5, "herbs": 3, "honey": 1, "fish": 2, "health_potion": 1}, {"bag": Save.bag}) and ok
	var jobs: Dictionary = Save.timers.get("jobs", {})
	var seen := float(Save.timers.get("seen", 0.0))
	var u0 := _job_moment(jobs.get("crop:0"), "sunberry", 240.0, 120.0)
	var u1 := _job_moment(jobs.get("crop:1"), "fernmint", 300.0, 60.0)
	ok = t._expect("startup 2: the half-grown crops are jobs at the real clock (sunberry len 240 from U - 120, fernmint len 300 from U - 60, U in this launch, seen U or later)",
		jobs.size() == 2 and u0 > 0.0 and u1 > 0.0 and absf(u0 - u1) < 0.01 and u0 >= launched - 2.0 and u0 <= real_now + 0.01
		and seen >= u0 - 0.01 and seen <= real_now + 0.01,
		{"timers": Save.timers, "U": u0, "launched": launched, "now": real_now}) and ok
	var want_crops: Array[String] = ["sunberry", "fernmint", "", "", "", ""]
	var plots_ok := Save.garden.size() == want_crops.size()
	for i in mini(Save.garden.size(), want_crops.size()):
		plots_ok = plots_ok and Save.garden[i] == {"crop": want_crops[i]}
	ok = t._expect("startup 2: the plots are {crop} (sunberry, fernmint, four empty), without the old grow and wet", plots_ok,
		{"garden": Save.garden}) and ok
	Save.save_game(true)
	var written: Variant = JSON.parse_string(FileAccess.get_file_as_string(Save.path))
	var w: Dictionary = written if written is Dictionary else {}
	ok = t._expect("startup 2: it saves as the current version with no pantry, snack choice, dishes or run dish",
		int(w.get("save_v", 0)) == SaveUpgrades.CURRENT_VERSION
		and _no_old_food(w), {"written_v": w.get("save_v")}) and ok
	ok = t._expect("startup 2: the written Bag is the upgraded one and the jobs round-trip (starts within 0.01 s)",
		w.get("bag") == {"berries": 5.0, "herbs": 3.0, "honey": 1.0, "fish": 2.0, "health_potion": 1.0}
		and _same_timers(w.get("timers"), Save.timers), {"bag": w.get("bag"), "timers": w.get("timers")}) and ok
	return ok


## H3: start + grown_s for an upgraded crop job with this crop, length and told false (the moment the upgrade ran),
## or -1 when the job is missing or different.
func _job_moment(job: Variant, crop: String, length: float, grown_s: float) -> float:
	if not job is Dictionary:
		return -1.0
	var j: Dictionary = job
	var told: Variant = j.get("told")
	if not (told is bool and not told) or j.get("data") != {"crop": crop} or not is_equal_approx(float(j.get("len", -1.0)), length):
		return -1.0
	return float(j.get("start", -1e12)) + grown_s


## H3: a written timers block (numbers as JSON gives them back) matches the one in memory: seen and every start within
## 0.01 s, the same lengths, data and told.
func _same_timers(written: Variant, held: Dictionary) -> bool:
	if not written is Dictionary:
		return false
	var w: Dictionary = written
	var wj: Variant = w.get("jobs")
	var hj: Dictionary = held.get("jobs", {})
	if not wj is Dictionary or (wj as Dictionary).size() != hj.size() or absf(float(w.get("seen", 0.0)) - float(held.get("seen", 0.0))) >= 0.01:
		return false
	for id: String in hj:
		var a: Variant = (wj as Dictionary).get(id)
		var b: Dictionary = hj[id]
		if not a is Dictionary or absf(float((a as Dictionary).get("start", 0.0)) - float(b["start"])) >= 0.01 \
				or float((a as Dictionary).get("len", 0.0)) != float(b["len"]) or (a as Dictionary).get("data") != b["data"] \
				or (a as Dictionary).get("told") != b["told"]:
			return false
	return true


## What the 2 -> 3 upgrade adds for a v2 dictionary's mats and keys (its saved run's satchel aside).
func _v2_worth(d: Dictionary) -> int:
	return _mat_worth(d.get("mats", {})) + clampi(int(d.get("burrow_keys", 0)), 0, V3_KEY_CAP) * V3_KEY_LEAVES


func _mat_worth(held: Dictionary) -> int:
	var n := 0
	for k: String in V3_MAT_LEAVES:
		n += maxi(0, int(held.get(k, 0))) * int(V3_MAT_LEAVES[k])
	return n


## The file a v1 or v2 dictionary (as JSON gives it back: numbers are floats) becomes after loading and saving: the
## leaves with the conversion, mats {"amber": 0}, no burrow_keys, the current version. H3, the 3 -> 4 step: the pantry
## (counts above 0) in the Bag and an old dish as a Health Potion (up to the cap; an extra one as leaves); no pantry,
## snack choice, dishes or run dish; the plots as {crop}, with a Timers job for each known crop (its share of growth, at
## the held clock); seen at the held clock. H5: then the later steps (_upgraded_v5).
func _upgraded(d: Dictionary) -> Dictionary:
	var out := d.duplicate(true)
	out["mats"] = {"amber": 0.0}
	out.erase("burrow_keys")
	var bag := {}
	var pantry: Dictionary = d.get("pantry", {})
	for k: String in pantry:
		if int(pantry[k]) > 0:
			bag[k] = float(int(pantry[k]))
	var dishes := 0
	for key: String in ["meal_ready", "meal_on"]:
		if V4_OLD_DISHES.has(String(d.get(key, ""))):
			dishes += 1
	var put := mini(dishes, maxi(0, V4_POTION_CAP - int(bag.get(V4_DISH_POTION, 0))))
	if put > 0:
		bag[V4_DISH_POTION] = float(int(bag.get(V4_DISH_POTION, 0)) + put)
	out["leaves"] = float(int(d["leaves"]) + _v2_worth(d) + (dishes - put) * V4_DISH_LEAVES)
	for key: String in OLD_FOOD_KEYS:
		out.erase(key)
	if out.get("burrow_run") is Dictionary:
		(out["burrow_run"] as Dictionary).erase("meal")
	var jobs := {}
	var plots: Array = out.get("garden", [])
	for i in plots.size():
		var id := String((plots[i] as Dictionary).get("crop", ""))
		if id == "":
			plots[i] = {"crop": ""}
		elif V4_CROP_STEPS.has(id):
			var full := float(V4_CROP_STEPS[id])
			var length := float(V4_CROP_GROW_S[id])
			var grown := clampf(float((plots[i] as Dictionary).get("grow", 0)), 0.0, full)
			jobs["crop:%d" % i] = {"start": fake_now - length * grown / full, "len": length, "data": {"crop": id}, "told": false}
			plots[i] = {"crop": id}
	out["bag"] = bag
	out["timers"] = {"seen": fake_now, "jobs": jobs}
	out["save_v"] = float(V4)
	return _upgraded_v5(out)


## H5: the file an older dictionary becomes after loading and saving from version 4 on: SaveUpgrades.upgrade runs the
## steps still due from its own version (a v4 one: only 4 -> 5; core/save_upgrade_v5.gd, whose rules --h5found checks
## case by case) and stamps the current version; read back the way a file is read (every number a float).
func _upgraded_v5(d: Dictionary) -> Dictionary:
	var out: Dictionary = SaveUpgrades.upgrade(d.duplicate(true))
	if out.get("stations") is Dictionary and not (out["stations"] as Dictionary).has("workshop"):
		(out["stations"] as Dictionary)["workshop"] = 0       # H6: the loader gives a missing Workshop station its default (0)
	if not out.has("camp_day_s"):
		out["camp_day_s"] = float(Data.day_night_cfg()["start_s"])
	var back: Variant = JSON.parse_string(JSON.stringify(out))
	return back if back is Dictionary else {}


## H5: the skill circles as one text, "stomp,ram," (Data.skill_slots: "" for an empty circle).
func _slots_text() -> String:
	return ",".join(PackedStringArray(Data.skill_slots()))


## H3: none of the old food keys is left (pantry, snack_choice, meal_ready, meal_on, and a saved run's meal).
func _no_old_food(d: Dictionary) -> bool:
	for key: String in OLD_FOOD_KEYS:
		if d.has(key):
			return false
	return not (d.get("burrow_run") is Dictionary and (d["burrow_run"] as Dictionary).has("meal"))


## The same keys, each with the same whole number.
func _same_ints(a: Variant, b: Dictionary) -> bool:
	if not a is Dictionary or (a as Dictionary).size() != b.size():
		return false
	for k: String in b:
		if int((a as Dictionary).get(k, -1)) != int(b[k]):
			return false
	return true


func _write_test_save(contents: String) -> bool:
	var f := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	if f == null:
		return false
	var written := f.store_string(contents)
	f.close()
	return written


func _read_test_save() -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH))
