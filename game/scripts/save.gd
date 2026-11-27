extends Node
## Save (autoload): everything the player owns, kept in user://leaf_save.json. Purchases and checkpoints can save
## immediately. Other changes wait for a flush. `-- --fresh` starts from nothing. Tests use a separate save.
## New load fixes go in core/save_upgrades.gd. The existing load fixes still run here and in their owning systems.
## H5 (27 Nov 2026): the save is version 5. What the shops sold is `owned` (owned[kind][id] = {"level": n}: mounts,
## pets, outfits, attachments), the pet has one level (`pet_level`), the Market one level (stations.stall 0 or 1) and
## the health an old upgraded Market earned (`market_hp_floor`), the Saddlery's `saddlery` holds the learned skills, the
## three skill circles, the one worn attachment and the mount's carried tier; there is no Mushroom Cottage. An older
## file is brought over by core/save_upgrades.gd (4 -> 5: core/save_upgrade_v5.gd) before it is read here.
## Follow-up: move the frequent writes in raids.gd (_add meter steps and _save_run_state checkpoints),
## burrow_run.gd (on_cat_hurt), fishing.gd (catches), and main.gd (ride toggles) to mark_dirty().

signal changed

const Upgrades := preload("res://core/save_upgrades.gd")
const FLUSH_EVERY_S := 10.0                        # seconds dirty changes may wait during play

var _dirty := false
var _dirty_elapsed := 0.0
var _loading := false
var _loaded_fields: Dictionary = {}

var path := "user://leaf_save.json"
## Keep the last checkpoint on disk while a Raid Mission wave is in progress.
var hold_flush := false
var count_gain := false                            # not saved: on only while a mission chapter is played (fight.gd)
# Every change to leaves goes through this setter (Save.leaves += n, add_leaves, Data.give, a pay...). While a mission
# chapter is being played (count_gain, set by fight.gd) every rise is added to mission_run["gain"]: the leaves gained
# since that chapter began (kill drops, wave pay, bonuses, sales: everything). A camp fall takes its share of
# that only (fight.camp_falls); leaves saved before the chapter are safe.
var leaves := 0:
	set(v):
		if v == leaves:
			return
		if count_gain and v > leaves and mission_run.has("mission"):
			mission_run["gain"] = int(mission_run.get("gain", 0)) + v - leaves
		leaves = v
		_currency_changed("leaves", v)
var timber := 0:
	set(v):
		if v == timber:
			return
		timber = v
		_currency_changed("timber", v)
var camp_level := 1
## 0 = not there yet (23 Nov 2026: the Tailor's Nook, "tailor"). H5: the Market ("stall") is 0 or 1 (one level), and the
## Mushroom Cottage is gone. load_game starts from these every time, then puts the file's levels over them.
const STATIONS_DEFAULT := {"target": 0, "bench": 0, "well": 0, "stall": 0, "stone": 0, "garden": 0, "fishing": 0,
	"saddlery": 0, "tailor": 0}
var stations := STATIONS_DEFAULT.duplicate()
var stats := {"damage": 0, "draw": 0, "range": 0, "health": 0, "speed": 0, "magnet": 0}
var bows := {"twig": 1}                             # bows owned and their level
var bow := "twig"                                   # the one in the cat's paw
var claimed: Array = []                             # patch indices taken back from the Gloom
var spots := {}                                     # (unused, kept for old saves)
var items := {"tower": 0, "spikes": 0}             # bought pieces not placed yet (Phase G2: never barricades; an older
                                                   # save's are refunded as leaves by defences.gd)
var placed: Array = []                              # built in the world: towers and spikes [{"type", "x", "z", "rot",
                                                   # "wreck"?}]; Phase G2 barricade rows {"type": "barricade", "slot":
                                                   # [road, spot], "row": pieces, "wrecks"?: each piece's kept share of
                                                   # health, -1 = whole} (an older save's pieces become rows, defences.gd)
var def_levels := {"barricade": 1, "tower": 1, "spikes": 1}   # one level for all pieces of a kind
var flags := {}                                     # what the first stage has shown already, and the like
var best_night := 0
var stages_won := 0
var stages_lost := 0
var riding := false                                # on Thistle
var ruined: Array = []                             # buildings knocked down by enemies: they do nothing until repaired
var fire_ruined := false                           # the camp fell: the campfire is ashes until it is rebuilt
var missions_done: Array = []                      # ids of the missions won at least once
var mount_look := "thistle"                        # which look rides in the mount slot (same numbers for all)
var pet_look := "sprig"                            # which look fills the pet slot
var mount_skin := "natural"                        # the look's colours (balance.json looks[].skins)
var pet_skin := "natural"
var mission_run := {}                              # campaign raid: wave_done is the last cleared wave; legacy chapter is kept
                                                   # start from, "gain": leaves gained since that chapter began (see
                                                   # leaves; an older save has none: 0)}, saved at every chapter
                                                   # break; {} = none
# Phase C: the Moss Warden, the garden, cooking and fishing. H3 (26 Nov 2026): only timers keep running while the game
# is closed (the owner's rule): the crops and the cooking pot are real-time jobs in `timers` (core/timers.gd). Nothing
# else moves on while the game is closed.
var guardian_look := "moss_warden"                 # which look fills the guardian slot (same numbers for all)
var guardian_skin := "natural"
var guardian_post := -1                            # -1 guards the camp, 0-3 holds that trail
var garden: Array = _empty_garden()                # 6 plots: {"crop": id or ""}; a plot's growth is the Timers job "crop:<i>"
## H3: the Bag's food, fish and potions, {id: count} (core/bag.gd writes it; towers and spikes stay in items, amber in
## mats). Unknown ids are kept.
var bag := {}
## H3: the Timers jobs (core/timers.gd writes them): {"seen": the highest clock reading (Unix s), "jobs": {id: {"start",
## "len", "data", "told"}}}.
var timers := {"seen": 0.0, "jobs": {}}
var fish_log := {}                                 # catch id -> how many caught
var fish_dry := 0                                  # catches since the last rare one (the pity counter)
# Phase D: the Gloom Raids. The only timestamps are the Timers jobs (`timers`, above): the raid meter fills only while the
# game runs, and a raid that was coming (or under way) comes back at its warning.
var shards := 0:                                   # Gloom shards: earned in play only, never sold
	set(v):
		if v == shards:
			return
		shards = v
		_currency_changed("shards", v)
var raids := {}                                    # Gloom Raids state; filled from RAIDS_DEFAULT
var wear := {}                                     # building id -> share of health lost in raids (0..0.95, steps of 0.05)
var unlocks: Array = []                            # bought with shards: "watch:lookout", "watch:tracker",
                                                   # "skin:mount:thistle:gloomlit", "fire:shardfire", ...
var fire_look := ""                                # "" or "shardfire"
# H1 (25 Nov 2026): no Hollow keys any more; an older save's "burrow_keys" became leaves (core/save_upgrades.gd 2 -> 3)
var save_v := Upgrades.CURRENT_VERSION             # format version written by save_game()
## Version read from disk before upgrades. Zero means no save was loaded.
var loaded_v := 0
# Phase E: the Burrows. No timestamps here (only the Timers jobs have them): a run in progress waits at the Hollow
# while the game is closed.
var mats := {"amber": 0}                           # the expedition materials (H1: amber only; an older save's glowstone and
                                                   # heartwood became leaves, core/save_upgrades.gd 2 -> 3)
var burrows := {}                                  # burrow id -> {"depth": deepest boss beaten, "runs", "won", "falls", "best"}
var burrow_run := {}                               # a run under way (burrow.gd); {} = none
## The expedition gear worn by the mount and the pet (Burrows only), "" for none. H5: what is owned is owned.attachments.
var attach := {"mount": "", "pet": ""}
# G4: the Saddlery. "skills": what the mount has learned, id -> level (1-5: stomp, ram, pounce, bellow). H5 (the v5
# save): "skill_slots", the skills in the three circles, in order ("" for an empty one; every mount shares them; a
# learned skill outside them keeps its level and is not used); "mount_credit", the mount tier an old save's Market had
# paid for (the owner's Q2 A; 0 otherwise). The attachments bought are owned.attachments. A save from before G4 was
# brought over once by the 4 -> 5 step (the free Stomp and the old Burrows saddle and bags).
# 22 Nov 2026 (the owner's rule): "worn" is the one attachment the mount wears ("" for none); only that one acts and
# shows. A save with none of its owned ones marked worn wears its best one (settle_worn).
var saddlery := {"skills": {}, "skill_slots": ["", "", ""], "worn": "", "mount_credit": 0}
# 23 Nov 2026: the cat's outfits (content/outfits; the Tailor's Nook). Looks only. "original" is always owned and the
# default. H5: the outfits owned are owned.outfits.
var cat_skin := "original"                         # the outfit she wears
## H5 (the v5 save, docs/ARCHITECTURE.md part 10): what the shops sold the player, by content kind (mounts, pets,
## outfits, attachments): owned[kind][id] = {"level": n}: 1 for a look, an outfit or expedition gear, the bought level
## for a Saddlery attachment. A record's other fields, unknown kinds and unknown ids are kept but ignored. Thistle and
## Bramblewool come with the built Market without a record (Data.owned_level).
var owned: Dictionary = {"outfits": {"original": {"level": 1}}}
## H5: the pet's one shared level (every pet look): 0 before Sprig is bought, then 1-3 (Data.pet_level).
var pet_level: int = 0
## H5 (the owner's Q5 A): the building health an old save's upgraded Market had earned (340 or 500); 0 for a Market
## built since (200, its one level). Data.building_hp reads it.
var market_hp_floor: int = 0
var endgame_slot := false                          # debug builds: the separate "endgame" test save is in use (never the real one)
const ENDGAME_PATH := "user://leaf_save_endgame.json"
const ENDGAME_MARK := "user://endgame_slot.txt"   # while this exists, a debug build keeps opening the endgame slot

const RAIDS_DEFAULT := {
	"meter": 0.0,          # 0..100; fills only while the game runs
	"plan": {},            # the next raid, made at stir: {type, lanes, level, leader, first, seed}
	"pending": false,      # the meter is full: the raid is announced and not over (warning, waves, restarts)
	"warn_left": 0.0,      # warning seconds left (on load clamped to warning.min..max)
	"run": {},             # the pending raid's progress: {wave_done, losses, fire, fire_went_out, rebuilt, ready, revealed}
	"renown": 0, "held": 0, "lost": 0, "perfect": 0, "streak": 0, "best_streak": 0,
	"since_elite": 0, "elite_turn": 0, "last_types": [], "last_lanes": [],
	"first_done": false,   # the first raid has been fought
	"last_lost": false,    # the last raid was lost (the Watch says the next one will be gentler)
}
const RAID_INTS := ["renown", "held", "lost", "perfect", "streak", "best_streak", "since_elite", "elite_turn"]


static func _empty_garden() -> Array:
	var g: Array = []
	for i in 6:
		g.append({"crop": ""})
	return g


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	raids = RAIDS_DEFAULT.duplicate(true)
	var args := Data.args()
	# the debug endgame start (Phase E): `--endgame` (also from files/test_args.txt on the phone) opens a separate save as
	# if every mission were won; it stays on until `--endgame-off`. The real save is never touched meanwhile.
	if args.has("--endgame-off") and FileAccess.file_exists(ENDGAME_MARK):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ENDGAME_MARK))
	if args.has("--autotest"):
		path = "user://leaf_save_test.json"
	elif OS.is_debug_build() and not args.has("--endgame-off"):
		if args.has("--endgame") or FileAccess.file_exists(ENDGAME_MARK):
			endgame_slot = true
			path = ENDGAME_PATH
			if not FileAccess.file_exists(ENDGAME_MARK):
				var mk := FileAccess.open(ENDGAME_MARK, FileAccess.WRITE)
				if mk:
					mk.store_string("endgame test save on: launch with --endgame-off to go back to the real save\n")
	if endgame_slot and (args.has("--fresh") or not FileAccess.file_exists(path)):
		_endgame_seed()
		save_game()
	elif args.has("--fresh"):
		save_game()
	else:
		load_game()


func load_game() -> void:
	set_deferred("_loading", false)                # a bad field can interrupt the load
	loaded_v = 0
	var backup := path.get_basename() + ".bak.json"
	var source := path
	# Windows can be interrupted between removing the main file and renaming the completed temporary file.
	if not FileAccess.file_exists(path) and OS.has_feature("windows") and FileAccess.file_exists(path + ".tmp"):
		source += ".tmp"
	var source_exists := FileAccess.file_exists(source)
	if not source_exists and not FileAccess.file_exists(backup):
		return
	var contents := FileAccess.get_file_as_string(source) if source_exists else ""
	var json := JSON.new()
	var from_backup := json.parse(contents) != OK or not json.data is Dictionary
	if from_backup:
		if not FileAccess.file_exists(backup):
			push_warning("Could not read save %s." % source)
			return
		contents = FileAccess.get_file_as_string(backup)
		if json.parse(contents) != OK or not json.data is Dictionary:
			push_warning("Could not read save %s or its backup %s." % [source, backup])
			return
		push_warning("Could not read save %s. Loaded backup %s." % [source, backup])
	elif source != path:
		var err := DirAccess.rename_absolute(source, path)
		if err != OK:
			push_warning("Loaded %s, but could not restore it to %s: %s" % [source, path, error_string(err)])
		else:
			push_warning("Recovered an interrupted save from %s." % source)

	var d: Dictionary = json.data
	loaded_v = int(d.get("save_v", 1))
	if loaded_v < Upgrades.CURRENT_VERSION:
		if not from_backup:
			var err := _write_save_file(backup, contents)
			if err != OK:
				push_warning("Could not back up %s before upgrading: %s" % [path, error_string(err)])
		d = Upgrades.upgrade(d)

	var previous_currency: Array[int] = [leaves, timber, shards]
	_loading = true
	_clear_dirty()
	_loaded_fields = d
	leaves = int(d.get("leaves", 0))
	timber = int(d.get("timber", 0))
	camp_level = int(d.get("camp_level", 1))
	# H5: from the defaults every time, so a second file loaded in this run never keeps the first one's buildings
	stations = STATIONS_DEFAULT.duplicate()
	var std: Variant = d.get("stations", {})
	if std is Dictionary:
		for k: Variant in std:
			stations[String(k)] = _whole((std as Dictionary)[k])
	for k in d.get("stats", {}):
		stats[k] = int(d["stats"][k])
	bows = {}
	var saved_bows: Dictionary = d.get("bows", {"twig": 1})
	for k in saved_bows:
		bows[k] = int(saved_bows[k])
	bow = String(d.get("bow", "twig"))
	if not Data.has_bow(bow):
		bow = "twig"
		if not bows.has(bow):
			bows[bow] = 1
	claimed = []
	for c in d.get("claimed", []):
		claimed.append(int(c))
	spots = d.get("spots", {})
	for k in spots:
		if spots[k] is Dictionary and spots[k].has("level"):
			spots[k]["level"] = int(spots[k]["level"])
	for k in d.get("items", {}):
		items[k] = int(d["items"][k])
	placed = []
	var pl = d.get("placed", [])
	if typeof(pl) == TYPE_ARRAY:
		for sp in pl:
			if typeof(sp) == TYPE_DICTIONARY and sp.has("type"):
				placed.append(sp)                      # each kind's fields are read with defaults (defences.gd)
	for k in d.get("def_levels", {}):
		def_levels[k] = int(d["def_levels"][k])
	flags = d.get("flags", {})
	best_night = int(d.get("best_night", 0))
	stages_won = int(d.get("stages_won", 0))
	stages_lost = int(d.get("stages_lost", 0))
	riding = bool(d.get("riding", false))
	ruined = []
	for c in d.get("ruined", d.get("crusted", [])):
		ruined.append(String(c))
	fire_ruined = bool(d.get("fire_ruined", false))
	mount_look = String(d.get("mount_look", "thistle"))
	pet_look = String(d.get("pet_look", "sprig"))
	mount_skin = String(d.get("mount_skin", "natural"))
	pet_skin = String(d.get("pet_skin", "natural"))
	missions_done = []
	for c in d.get("missions_done", []):
		missions_done.append(String(c))
	mission_run = {}
	var run = d.get("mission_run", {})
	if typeof(run) == TYPE_DICTIONARY and run.has("mission"):
		mission_run = {"mission": int(run["mission"]), "chapter": int(run.get("chapter", 0)), "gain": maxi(0, int(run.get("gain", 0)))}
		if run.has("wave_done"):
			mission_run["wave_done"] = maxi(0, int(run["wave_done"]))
		mission_run.merge(run)
	# Phase C (an older save has none of these: the defaults stay)
	guardian_look = String(d.get("guardian_look", "moss_warden"))
	guardian_skin = String(d.get("guardian_skin", "natural"))
	guardian_post = int(d.get("guardian_post", -1))
	garden = _empty_garden()
	var gd = d.get("garden", [])
	if typeof(gd) == TYPE_ARRAY:
		for i in mini(gd.size(), 6):
			if typeof(gd[i]) == TYPE_DICTIONARY:
				garden[i] = {"crop": String(gd[i].get("crop", ""))}
				garden[i].merge(gd[i])                   # other keys are kept (a plot with an unknown crop keeps its old form)
	# H3: the Bag and the Timers jobs (a v3 save got them from core/save_upgrades.gd 3 -> 4)
	bag = {}
	var bgd: Variant = d.get("bag", {})
	if bgd is Dictionary:
		for k: Variant in bgd:
			var v: Variant = (bgd as Dictionary)[k]
			if v is int or v is float:
				bag[String(k)] = maxi(0, int(v))
	timers = _load_timers(d.get("timers", {}))
	fish_log = {}
	var fl = d.get("fish_log", {})
	if typeof(fl) == TYPE_DICTIONARY:
		for k in fl:
			fish_log[String(k)] = int(fl[k])
	fish_dry = int(d.get("fish_dry", 0))
	# Phase D (an older save has none of these: the defaults stay; raids.restore_on_load() migrates it)
	shards = maxi(0, int(d.get("shards", 0)))
	raids = _load_raids(d.get("raids", {}))
	wear = {}
	var wd = d.get("wear", {})
	if typeof(wd) == TYPE_DICTIONARY:
		for k in wd:
			wear[String(k)] = clampf(float(wd[k]), 0.0, 0.95)
	unlocks = []
	for u in d.get("unlocks", []):
		unlocks.append(String(u))
	fire_look = String(d.get("fire_look", ""))
	save_v = int(d.get("save_v", 1))
	# Phase E (an older save has none of these: the defaults stay; ids added later keep their defaults)
	mats = {"amber": 0}
	var md = d.get("mats", {})
	if typeof(md) == TYPE_DICTIONARY:
		for k in md:
			mats[String(k)] = maxi(0, int(md[k]))
	burrows = {}
	var bd = d.get("burrows", {})
	if typeof(bd) == TYPE_DICTIONARY:
		for k in bd:
			if typeof(bd[k]) == TYPE_DICTIONARY:
				var st := burrow_stats(String(k))
				for f in st:
					st[f] = maxi(0, int(bd[k].get(f, 0)))
				st.merge(bd[k])
	burrow_run = {}
	var rd = d.get("burrow_run", {})
	if typeof(rd) == TYPE_DICTIONARY:
		burrow_run = rd                                # burrow.gd checks it (version, step) when the game starts
	# H5 (the v5 save): what the shops sold, the pet's level and the old Market's health; each from its default
	owned = _load_owned(d.get("owned", {}))
	pet_level = maxi(0, _whole(d.get("pet_level", 0)))
	market_hp_floor = maxi(0, _whole(d.get("market_hp_floor", 0)))
	# the expedition gear worn (H5: what is owned is owned.attachments)
	attach = {"mount": "", "pet": ""}
	var ad: Variant = d.get("attach", {})
	if ad is Dictionary:
		for slot: String in ["mount", "pet"]:
			var worn: Variant = (ad as Dictionary).get(slot, "")
			attach[slot] = worn if worn is String else ""
		attach.merge(ad)
	# G4: the Saddlery's skills, H5: its circles, the worn attachment and the carried mount tier (a file from before
	# G4 was brought over by the 4 -> 5 step, so every file read here has the key; without it the defaults stay)
	saddlery = _fresh_saddlery()
	var sd: Variant = d.get("saddlery", null)
	if sd is Dictionary:
		var pd2: Variant = (sd as Dictionary).get("skills", {})
		if pd2 is Dictionary:
			for k: Variant in pd2:
				if Data.saddle_info("skills", String(k)).is_empty():
					saddlery["skills"][k] = (pd2 as Dictionary)[k]  # an unknown skill is kept as it is
					continue
				var lv := clampi(_whole((pd2 as Dictionary)[k]), 0, 5)
				if lv > 0:
					saddlery["skills"][String(k)] = lv
		saddlery["skill_slots"] = _load_slots((sd as Dictionary).get("skill_slots", []))
		var sw: Variant = (sd as Dictionary).get("worn", "")
		saddlery["worn"] = sw if sw is String else ""
		saddlery["mount_credit"] = maxi(0, _whole((sd as Dictionary).get("mount_credit", 0)))
		saddlery.merge(sd)
	settle_worn()
	# 23 Nov 2026: the outfit she wears (an older save without it: the original); H5: owned.outfits says what she owns
	cat_skin = String(d.get("cat_skin", "original"))
	settle_cat_skin()
	_loading = false
	if from_backup or save_v > loaded_v:
		mark_dirty()
	_emit_loaded.call_deferred(previous_currency)


func _emit_loaded(previous_currency: Array[int]) -> void:
	if leaves != previous_currency[0]:
		Events.currency_changed.emit("leaves", leaves)
	if timber != previous_currency[1]:
		Events.currency_changed.emit("timber", timber)
	if shards != previous_currency[2]:
		Events.currency_changed.emit("shards", shards)
	Events.save_loaded.emit()


func _currency_changed(id: String, total: int) -> void:
	if _loading:
		return
	mark_dirty()
	Events.currency_changed.emit(id, total)


## 23 Nov 2026: she wears an outfit she owns that the game still has (content/outfits), else the original. H5: the
## original is always in owned.outfits.
func settle_cat_skin() -> void:
	var outfits: Variant = owned.get("outfits")
	if not outfits is Dictionary:
		outfits = {}
		owned["outfits"] = outfits
	if not (outfits as Dictionary).has(Data.CAT_SKIN_DEFAULT):
		(outfits as Dictionary)[Data.CAT_SKIN_DEFAULT] = {"level": 1}
	if cat_skin == "" or not Data.cat_skin_owned(cat_skin) or Data.cat_skin(cat_skin).is_empty():
		cat_skin = Data.CAT_SKIN_DEFAULT


## 22 Nov 2026: the mount wears one attachment at a time. When none of the ones it owns is marked worn (a save from
## before that rule, which wore all of them), it wears the highest-level one it owns, the Saddlebags first on a tie
## (Data.best_owned_attach); "" when it owns none. H5: what it owns is owned.attachments (Data.attach_level).
func settle_worn() -> void:
	var worn: Variant = saddlery.get("worn", "")
	var w: String = worn if worn is String else ""
	if w != "" and not Data.saddle_info("attach", w).is_empty() and Data.attach_level(w) >= 1:
		return
	saddlery["worn"] = Data.best_owned_attach()


## H5: the Saddlery part of a fresh camp: nothing learned or worn, every circle empty, no carried mount tier.
static func _fresh_saddlery() -> Dictionary:
	return {"skills": {}, "skill_slots": _load_slots([]), "worn": "", "mount_credit": 0}


## H5: the saved skill circles, one skill id per circle ("" for an empty one), as many circles as the Saddlery has
## (balance.json saddlery.skill_slot_count, 3). Anything that is not text is an empty circle; Data.skill_slots() still
## empties an unknown or repeated id when it reads them.
static func _load_slots(v: Variant) -> Array:
	var saved: Array = v if v is Array else []
	var out: Array = []
	for i in maxi(0, int(Data.saddlery_cfg().get("skill_slot_count", 3))):
		out.append(saved[i] if i < saved.size() and saved[i] is String else "")
	return out


## H5: owned from the file: each kind's records, a record's level as a whole number of 0 or more. A record's other
## fields, unknown kinds and unknown ids are kept as they are (ignored by the shops, never lost).
static func _load_owned(v: Variant) -> Dictionary:
	var out: Dictionary = {}
	if not v is Dictionary:
		return out
	for kind: Variant in v:
		var shelf: Variant = (v as Dictionary)[kind]
		if not shelf is Dictionary:
			out[String(kind)] = shelf
			continue
		var records: Dictionary = {}
		for id: Variant in shelf:
			var rec: Variant = (shelf as Dictionary)[id]
			if rec is Dictionary and _is_num((rec as Dictionary).get("level")):
				var r: Dictionary = (rec as Dictionary).duplicate(true)
				r["level"] = maxi(0, _whole(r["level"]))
				rec = r
			records[String(id)] = rec
		out[String(kind)] = records
	return out


## A JSON number as a whole number (cut like int()); anything else, or a number that is not finite, is 0.
static func _whole(v: Variant) -> int:
	if v is int:
		return v as int
	if v is float and is_finite(v as float):
		return int(v as float)
	return 0


static func _is_num(v: Variant) -> bool:
	return v is int or v is float


## The debug endgame start: a camp as if all 15 missions were won (home level 5, a grown cat, some leaves, timber and
## shards, the Burrows open). The Moss Warden is not there: it is found in the Burrows, as in a real game. Phase F: the
## Training Target and the Bow Bench at 5 and every other building at the top home 5 allows, so the new caps (stats and
## bows by the Target's and the Bench's level) never hold the endgame tester back. H5: the Market built (one level),
## the pet at its top level, both H4 mount looks and both H4 pet looks owned (balance.json save_upgrades.to_v5), the
## original outfit; the mount's level follows the Saddlery's (Data.mount_level), no carried tier.
func _endgame_seed() -> void:
	leaves = 8000
	timber = 300
	camp_level = 5
	stations = STATIONS_DEFAULT.duplicate()
	stations["fishing"] = 1
	# G4: the Saddlery built, nothing learned; 23 Nov 2026: the Tailor's Nook built, only the original outfit owned
	for id in ["target", "bench", "well", "stall", "garden", "saddlery", "tailor"]:
		stations[id] = mini(camp_level, Data.building_levels(id).size())
	var to: Dictionary = (Data.b.get("save_upgrades", {}) as Dictionary).get("to_v5", {})
	owned = {"mounts": {}, "pets": {}, "outfits": {Data.CAT_SKIN_DEFAULT: {"level": 1}}, "attachments": {}}
	for pair: Array in [["mounts", "mount_looks"], ["pets", "pet_looks"]]:
		for id: Variant in to.get(pair[1], []):
			if id is String:
				owned[pair[0]][id] = {"level": 1}
	pet_level = Data.pet_top()
	market_hp_floor = 0
	stats = {"damage": 9, "draw": 9, "range": 6, "health": 9, "speed": 8, "magnet": 5}
	bows = {"twig": 10, "sunwood": 9, "volley": 6}
	bow = "sunwood"
	claimed = [0, 1, 2, 3]
	items = {"tower": 3, "spikes": 2}
	placed = []
	var bar: Dictionary = Data.b.get("defences", {}).get("barricade", {})
	var per := int(bar.get("row", {}).get("pieces", 3))
	for ln in 4:                                     # Phase G2: a barricade row on every road (was 4 pieces to place)
		placed.append({"type": "barricade", "slot": [ln, 2], "row": per})
	def_levels = {"barricade": 3, "tower": 3, "spikes": 3}
	missions_done = []
	for i in Data.mission_count():
		missions_done.append(String(Data.mission(i)["id"]))
	stages_won = Data.mission_count()
	flags = {}
	for f in ["shop_open", "shop_target", "shop_bench", "home", "first_stage_done", "told_horn", "told_chapter", "told_go_out",
			"told_barricade", "told_ride", "told_hide", "told_garden", "told_cook", "told_fish", "told_feed", "told_raids", "hollow_open"]:
		flags[f] = true
	bag = {"berries": 8, "herbs": 4, "honey": 2, "fish": 3}   # H3: the Bag (was the pantry)
	timers = {"seen": 0.0, "jobs": {}}
	garden = _empty_garden()
	shards = 60
	raids = RAIDS_DEFAULT.duplicate(true)
	raids["meter"] = 20.0
	save_v = Upgrades.CURRENT_VERSION
	mats = {"amber": 0}
	burrows = {}
	burrow_run = {}
	attach = {"mount": "", "pet": ""}
	saddlery = _fresh_saddlery()
	cat_skin = Data.CAT_SKIN_DEFAULT


## A Burrow's counters (made with zeros the first time it is asked for).
func burrow_stats(id: String) -> Dictionary:
	if not burrows.has(id) or typeof(burrows[id]) != TYPE_DICTIONARY:
		burrows[id] = {"depth": 0, "runs": 0, "won": 0, "falls": 0, "best": 0}
	return burrows[id]


func add_mat(id: String, n: int) -> void:
	var before := int(mats.get(id, 0))
	var total := maxi(0, before + n)
	mats[id] = total
	if total == before:
		return
	mark_dirty()
	if total > before:
		Events.item_gained.emit("material", id, total - before)
	Events.bag_changed.emit()


## The Gloom Raids state from the save: RAIDS_DEFAULT with the saved keys merged over it, every value cast.
func _load_raids(rd) -> Dictionary:
	var r: Dictionary = RAIDS_DEFAULT.duplicate(true)
	if typeof(rd) != TYPE_DICTIONARY:
		return r
	r.merge(rd)
	r["meter"] = clampf(float(rd.get("meter", 0.0)), 0.0, 100.0)
	r["pending"] = bool(rd.get("pending", false))
	r["warn_left"] = float(rd.get("warn_left", 0.0))
	r["first_done"] = bool(rd.get("first_done", false))
	r["last_lost"] = bool(rd.get("last_lost", false))
	for k in RAID_INTS:
		r[k] = int(rd.get(k, 0))
	for k in ["last_types", "last_lanes"]:
		var a: Array = []
		for v in rd.get(k, []):
			a.append(int(v) if k == "last_lanes" else String(v))
		r[k] = a
	var plan = rd.get("plan", {})
	var types: Dictionary = Data.b.get("gloom_raids", {}).get("types", {})
	if typeof(plan) == TYPE_DICTIONARY and not plan.is_empty() and types.has(String(plan.get("type", ""))):
		var lanes: Array = []
		for ln in plan.get("lanes", []):
			lanes.append(int(ln))
		r["plan"] = {"type": String(plan["type"]), "lanes": lanes, "level": int(plan.get("level", 1)),
			"leader": String(plan.get("leader", "")), "first": bool(plan.get("first", false)), "seed": int(plan.get("seed", 1)),
			"called": bool(plan.get("called", false))}
		if plan.has("assault_total"):
			r["plan"]["assault_total"] = clampi(int(plan["assault_total"]), 1, int(Data.gr()["assault"]["max_enemies"]))
		r["plan"].merge(plan)
		var run = rd.get("run", {})
		if typeof(run) == TYPE_DICTIONARY and not run.is_empty():
			r["run"] = {"wave_done": int(run.get("wave_done", 0)), "losses": int(run.get("losses", 0)), "fire": float(run.get("fire", 1.0)),
				"fire_went_out": bool(run.get("fire_went_out", false)), "rebuilt": bool(run.get("rebuilt", false)),
				"last_stand": bool(run.get("last_stand", false)), "ready": bool(run.get("ready", false)),
				"revealed": bool(run.get("revealed", false)), "started": bool(run.get("started", false))}
			r["run"].merge(run)
			if int(run.get("assault_format", 0)) == 1:
				r["run"]["assault_format"] = 1
				r["run"]["legacy_held"] = maxi(0, int(run.get("legacy_held", 0)))
				var defeated: Array = []
				var total := int(r["plan"].get("assault_total", Data.gr()["assault"]["max_enemies"]))
				var summons: Array = []
				for summon in run.get("summons", []):
					if total + summons.size() >= int(Data.gr()["assault"]["max_enemies"]):
						break
					if summon is Dictionary and Data.b["enemies"].has(String(summon.get("kind", ""))):
						var entry: Dictionary = summon.duplicate()
						entry["kind"] = String(summon["kind"])
						entry["lane"] = clampi(int(summon.get("lane", 0)), 0, Data.lane_count() - 1)
						summons.append(entry)
				r["run"]["summons"] = summons
				total += summons.size()
				for member in run.get("defeated", []):
					var id := int(member)
					if id >= 0 and id < total and not defeated.has(id):
						defeated.append(id)
				r["run"]["defeated"] = defeated
			else:
				for key: String in ["assault_format", "legacy_held", "summons", "defeated"]:
					r["run"].erase(key)
	else:
		r["pending"] = false                               # no plan (or a kind that is gone): nothing is coming
		r["run"] = {}
		r["warn_left"] = 0.0
	return r


## H3: the Timers jobs from the save. Each job needs a number "start" and "len" (else it is dropped); "data" (a
## Dictionary) and "told" get their defaults; seen is never below 0. Other keys are kept.
static func _load_timers(td: Variant) -> Dictionary:
	var out := {"seen": 0.0, "jobs": {}}
	if not td is Dictionary:
		return out
	var t: Dictionary = td
	var sv: Variant = t.get("seen", 0.0)
	out["seen"] = maxf(0.0, float(sv)) if (sv is float or sv is int) else 0.0
	var jobs: Dictionary = {}
	var jd: Variant = t.get("jobs", {})
	if jd is Dictionary:
		for id: Variant in jd:
			var j: Variant = (jd as Dictionary)[id]
			if not j is Dictionary:
				continue
			var s: Variant = (j as Dictionary).get("start")
			var l: Variant = (j as Dictionary).get("len")
			if not (s is float or s is int) or not (l is float or l is int):
				continue
			var data: Variant = (j as Dictionary).get("data", {})
			var job := {"start": float(s), "len": maxf(0.0, float(l)), "data": data if data is Dictionary else {},
				"told": (j as Dictionary).get("told", false) == true}
			job.merge(j)
			jobs[String(id)] = job
	out["jobs"] = jobs
	out.merge(t)
	return out


func mark_dirty() -> void:
	if not _dirty:
		_dirty = true
		set_process(true)


func flush() -> void:
	if _dirty and not hold_flush:
		_dirty_elapsed = 0.0
		save_game(true)


func _clear_dirty() -> void:
	_dirty = false
	_dirty_elapsed = 0.0
	set_process(false)


func _process(delta: float) -> void:
	if hold_flush:
		return
	_dirty_elapsed += delta
	if _dirty_elapsed >= FLUSH_EVERY_S:
		flush()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_WM_GO_BACK_REQUEST:
			flush()
		NOTIFICATION_PREDELETE:
			# A mid-wave exit keeps the last completed checkpoint.
			flush()
			hold_flush = false


## quiet: write the file without the `changed` signal (the meter's steps and pause saves: the open card stays as it is).
## Always writes: hold_flush only holds the automatic flushes (the timer, pause, background), never a save the game
## asks for on purpose (a mission's checkpoints, a camp falling, a purchase).
func save_game(quiet := false) -> void:
	var d := {
		"leaves": leaves, "timber": timber, "camp_level": camp_level, "stations": stations, "stats": stats,
		"bows": bows, "bow": bow, "claimed": claimed, "items": items, "placed": placed, "def_levels": def_levels, "flags": flags, "best_night": best_night,
		"stages_won": stages_won, "stages_lost": stages_lost, "riding": riding, "ruined": ruined, "fire_ruined": fire_ruined, "missions_done": missions_done, "mount_look": mount_look, "pet_look": pet_look, "mount_skin": mount_skin, "pet_skin": pet_skin, "mission_run": mission_run,
		"guardian_look": guardian_look, "guardian_skin": guardian_skin, "guardian_post": guardian_post, "garden": garden,
		"bag": bag, "timers": timers, "fish_log": fish_log, "fish_dry": fish_dry,
		"shards": shards, "raids": raids, "wear": wear, "unlocks": unlocks, "fire_look": fire_look,
		"save_v": save_v,
		"mats": mats, "burrows": burrows, "burrow_run": burrow_run, "attach": attach,
		"saddlery": saddlery,
		"cat_skin": cat_skin,
		"owned": owned, "pet_level": pet_level, "market_hp_floor": market_hp_floor,   # H5: the v5 save
	}
	# Write current values for fields this version owns, and carry other top-level fields through.
	d.merge(_loaded_fields)
	var err := _write_save_file(path, JSON.stringify(d, "  "))
	if err == OK:
		_clear_dirty()
	else:
		mark_dirty()
		push_warning("Could not save %s: %s" % [path, error_string(err)])
	if not quiet:
		changed.emit()


## Check the closed file's size to catch a short write from flushing buffered data.
static func _write_save_file(file_path: String, contents: String) -> Error:
	var tmp := file_path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	var bytes := contents.to_utf8_buffer()
	var written := f.store_buffer(bytes)
	f.close()
	if not written or FileAccess.get_size(tmp) != bytes.size():
		DirAccess.remove_absolute(tmp)
		return ERR_FILE_CANT_WRITE
	var err := DirAccess.rename_absolute(tmp, file_path)
	if err != OK and OS.has_feature("windows") and FileAccess.file_exists(file_path):
		err = DirAccess.remove_absolute(file_path)
		if err == OK:
			err = DirAccess.rename_absolute(tmp, file_path)
	if err != OK and FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(tmp)
	return err


func add_leaves(n: int) -> void:
	leaves += n
	changed.emit()


func flag(k: String) -> bool:
	return bool(flags.get(k, false))


func set_flag(k: String) -> void:
	flags[k] = true
