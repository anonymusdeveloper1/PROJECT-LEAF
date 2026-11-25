## Save checks for autotest.gd (`-- --autotest --fresh --saves`).
## Uses Save, Events and the v2 fixture. Reads and writes only a scratch save and its backup during checks.
extends Node

const AutotestScript := preload("res://scripts/autotest.gd")
const MainScript := preload("res://scripts/main.gd")

const SAMPLE_PATH := "res://tests/saves/v2_sample.json"
const TEST_PATH := "user://leaf_save_test_saves.json"
const BACKUP_PATH := "user://leaf_save_test_saves.bak.json"

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
	if not t._expect("the v2 fixture is copied to the scratch slot", _write_test_save(sample_text)):
		return false
	Save.load_game()
	await get_tree().process_frame
	Save.save_game(true)
	var ok := t._expect("the v2 sample survives load and save", _read_test_save() == sample)
	ok = t._expect("a successful write leaves no temporary file", not FileAccess.file_exists(TEST_PATH + ".tmp")) and ok
	ok = t._expect("a current save needs no backup", not FileAccess.file_exists(BACKUP_PATH)) and ok

	# A file without a version goes through the v1 load path.
	var old := sample.duplicate(true)
	old.erase("save_v")
	old["owned"] = {"future_kind": {"future_item": {"level": 3}}}
	old["bows"]["future_bow"] = 4
	old["burrows"]["old_hollow"]["future_reward"] = {"count": 2}
	old["saddlery"]["skills"]["future_skill"] = 2
	var old_text := JSON.stringify(old, "  ") + "\n"
	var expected: Dictionary = JSON.parse_string(old_text)
	expected["save_v"] = 1.0
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
	Save.save_game(true)
	ok = t._expect("the older save round-trips its known data and unknown keys", _read_test_save() == expected) and ok

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


func _write_test_save(contents: String) -> bool:
	var f := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	if f == null:
		return false
	var written := f.store_string(contents)
	f.close()
	return written


func _read_test_save() -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH))
