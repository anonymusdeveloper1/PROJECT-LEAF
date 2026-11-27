extends RefCounted
## The player's settings file, user://settings.json (kept apart from the save, so a new game keeps it). A static helper
## (use it with preload): Quality writes "quality", "auto" and "fps30"; the sound switch writes "sound"; a new setting
## writes its own key. Every write reads the file, changes its keys and writes the whole file back, so nobody overwrites
## another's keys, and keys this version does not know are kept. Nothing is written during --autotest runs.

const PATH := "user://settings.json"


## The whole file as a dictionary ({} when it is missing or broken). When Windows was interrupted between removing the
## file and renaming the finished .tmp, the .tmp is read instead (as save.gd does).
static func read() -> Dictionary:
	var src := PATH
	if not FileAccess.file_exists(PATH) and OS.has_feature("windows") and FileAccess.file_exists(PATH + ".tmp"):
		src = PATH + ".tmp"
	if not FileAccess.file_exists(src):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(src))
	if parsed is Dictionary:
		return parsed
	return {}


## Set one key and save the file. Does nothing in an automated test.
static func write(key: String, value: Variant) -> void:
	write_many({key: value})


## Set several keys and save the file once. Does nothing in an automated test.
static func write_many(values: Dictionary) -> void:
	if Data.args().has("--autotest"):
		return
	var all := read()
	all.merge(values, true)
	_write_file(JSON.stringify(all))


## Write to a .tmp file, check its size, then rename it over the real file. The failure path is save.gd's: on Windows
## the old file is removed and the rename tried again, and the .tmp is deleted only while the real file still exists.
static func _write_file(contents: String) -> void:
	var tmp := PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Could not write %s: %s" % [tmp, error_string(FileAccess.get_open_error())])
		return
	var bytes := contents.to_utf8_buffer()
	var written := f.store_buffer(bytes)
	f.close()
	if not written or FileAccess.get_size(tmp) != bytes.size():
		DirAccess.remove_absolute(tmp)
		push_warning("Could not write %s: short write" % PATH)
		return
	var err := DirAccess.rename_absolute(tmp, PATH)
	if err != OK and OS.has_feature("windows") and FileAccess.file_exists(PATH):
		err = DirAccess.remove_absolute(PATH)
		if err == OK:
			err = DirAccess.rename_absolute(tmp, PATH)
	if err != OK:
		if FileAccess.file_exists(PATH):
			DirAccess.remove_absolute(tmp)
		push_warning("Could not save %s: %s" % [PATH, error_string(err)])
