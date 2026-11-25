## Save checks for autotest.gd (`-- --autotest --fresh --saves`).
## Uses Save, Events and the v2 fixture. Reads and writes only a scratch save and its backup during checks.
## H1: the v2 fixture stays a real version-2 save; loading it runs the 2 -> 3 upgrade (core/save_upgrades.gd): its
## amber, glowstone, heartwood and Hollow keys become leaves, only amber is left (at 0), and burrow_keys is gone.
extends Node

const AutotestScript := preload("res://scripts/autotest.gd")
const MainScript := preload("res://scripts/main.gd")

const SAMPLE_PATH := "res://tests/saves/v2_sample.json"
const TEST_PATH := "user://leaf_save_test_saves.json"
const BACKUP_PATH := "user://leaf_save_test_saves.bak.json"
## H1 (the owner, 25 Nov 2026): what Bramble paid before H1, so what the 2 -> 3 upgrade gives for each material and key.
const V3_MAT_LEAVES := {"amber": 25, "glowstone": 50, "heartwood": 150}
const V3_KEY_LEAVES := 150
const V3_KEY_CAP := 3
## The frozen version-3 fixture (hand-written in the format save_game writes): loading it must change nothing.
const SAMPLE_V3_PATH := "res://tests/saves/v3_sample.json"

var t: AutotestScript
var main: MainScript


func run() -> bool:
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
	var ok := await _check_saves(sample_text, sample)
	Save.path = original_path
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
	ok = t._expect("the v2 file is backed up before it is upgraded", FileAccess.file_exists(BACKUP_PATH)
		and FileAccess.get_file_as_string(BACKUP_PATH) == sample_text) and ok
	Save.save_game(true)
	var written: Variant = _read_test_save()
	ok = t._expect("the v2 sample survives load and save (as the upgraded v3 save)", written == _upgraded(sample), {"written": written}) and ok
	ok = t._expect("H1: the written file has no burrow_keys", written is Dictionary and not (written as Dictionary).has("burrow_keys")) and ok
	ok = t._expect("H1: the written mats hold only amber, at 0", written is Dictionary and (written as Dictionary).get("mats") == {"amber": 0.0},
		{"mats": (written as Dictionary).get("mats") if written is Dictionary else null}) and ok
	ok = t._expect("a successful write leaves no temporary file", not FileAccess.file_exists(TEST_PATH + ".tmp")) and ok

	# the written v3 file loads again unchanged: no second conversion, and a current save needs no backup
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

	Data.add_items({"berries": 1})
	expected["pantry"]["berries"] += 1
	Save.flush()
	return t._expect("add_items marks the save dirty", _read_test_save() == expected) and ok


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


## H1: the frozen v3 fixture loads as it is: no conversion, no backup, unknown materials kept, and it saves as v3.
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
	var ok := t._expect("the v3 sample loads as version 3", Save.loaded_v == 3 and Save.save_v == SaveUpgrades.CURRENT_VERSION, {"loaded_v": Save.loaded_v})
	ok = t._expect("the v3 sample's leaves are not converted", Save.leaves == int(s["leaves"]), {"leaves": Save.leaves}) and ok
	ok = t._expect("the v3 sample keeps its amber and its unknown material", int(Save.mats.get("amber", -1)) == 3
		and int(Save.mats.get("future_mat", -1)) == 1, {"mats": Save.mats}) and ok
	ok = t._expect("the v3 sample keeps its saved run's satchel and has no key flag", int((Save.burrow_run.get("satchel", {}) as Dictionary).get("amber", -1)) == 2
		and not Save.burrow_run.has("key"), {"run": Save.burrow_run}) and ok
	ok = t._expect("a v3 save is not backed up before loading", not FileAccess.file_exists(BACKUP_PATH)) and ok
	Save.save_game(true)
	var written: Variant = _read_test_save()
	ok = t._expect("the v3 sample is saved as v3 without burrow_keys", written is Dictionary and int((written as Dictionary).get("save_v", 0)) == 3
		and not (written as Dictionary).has("burrow_keys"), {"written": written}) and ok
	return ok


## What the 2 -> 3 upgrade adds for a v2 dictionary's mats and keys (its saved run's satchel aside).
func _v2_worth(d: Dictionary) -> int:
	return _mat_worth(d.get("mats", {})) + clampi(int(d.get("burrow_keys", 0)), 0, V3_KEY_CAP) * V3_KEY_LEAVES


func _mat_worth(held: Dictionary) -> int:
	var n := 0
	for k: String in V3_MAT_LEAVES:
		n += maxi(0, int(held.get(k, 0))) * int(V3_MAT_LEAVES[k])
	return n


## The file a v1 or v2 dictionary (as JSON gives it back: numbers are floats) becomes after loading and saving: the
## leaves with the conversion, mats {"amber": 0}, no burrow_keys, the current version.
func _upgraded(d: Dictionary) -> Dictionary:
	var out := d.duplicate(true)
	out["leaves"] = float(int(d["leaves"]) + _v2_worth(d))
	out["mats"] = {"amber": 0.0}
	out.erase("burrow_keys")
	out["save_v"] = float(SaveUpgrades.CURRENT_VERSION)
	return out


func _write_test_save(contents: String) -> bool:
	var f := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	if f == null:
		return false
	var written := f.store_string(contents)
	f.close()
	return written


func _read_test_save() -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH))
