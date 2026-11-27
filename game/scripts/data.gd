extends Node
## Data (autoload): the balance numbers and content catalogues, and the cat's numbers worked out from balance
## and what the player has bought (Save).
## H5: the shops' catalogue (mounts, pets, outfits, attachments) is worked out in scripts/shop_data.gd; this file stays
## the front door, so callers always ask Data.

const ShopData := preload("res://scripts/shop_data.gd")
## H5: the Market's building id, named here for one rule only: the health an old save's Market had earned
## (building_hp, Save.market_hp_floor).
const MARKET := "stall"

var b: Dictionary = {}
var _catalogues: Dictionary = {}
var run_mods := {}                   # Phase E: a Burrows run's boons and attachments (burrow.gd sets it, clears it on leaving)
var _args := PackedStringArray()
var _args_read := false


func _ready() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance.json"))
	if typeof(parsed) == TYPE_DICTIONARY:
		b = parsed
	else:
		push_error("data/balance.json did not parse")
	_load_content_index()


func _load_content_index() -> void:
	const INDEX_PATH := "res://content/index.json"
	if not FileAccess.file_exists(INDEX_PATH):
		return
	var index: Variant = JSON.parse_string(FileAccess.get_file_as_string(INDEX_PATH))
	if not index is Dictionary:
		return
	var kinds: Variant = index.get("kinds", {})
	if not kinds is Dictionary:
		return
	for kind: String in kinds:
		var ids: Variant = kinds[kind]
		if not ids is Array:
			continue
		var entries: Dictionary = {}
		for id: Variant in ids:
			if not id is String:
				continue
			var entry_path := "res://content/%s/%s/entry.json" % [kind, id]
			if FileAccess.file_exists(entry_path):
				var entry: Variant = JSON.parse_string(FileAccess.get_file_as_string(entry_path))
				if entry is Dictionary:
					entries[id] = entry
		_catalogues[kind] = entries


## Shared content entries in index order. Callers treat entries as read-only.
func catalog(kind: String) -> Array:
	var entries: Dictionary = _catalogues.get(kind, {})
	return entries.values()


## One shared content entry, or an empty dictionary for an unknown id.
func item(kind: String, id: String) -> Dictionary:
	var entries: Dictionary = _catalogues.get(kind, {})
	return entries.get(id, {})


# ---------------------------------------------------------------- H5: the shops' catalogue (scripts/shop_data.gd)
## H5: every entry of a content kind that can be shown and sold (mounts, pets, outfits, attachments, or any kind), in
## index order; hidden and malformed entries are left out.
func shop_entries(kind: String) -> Array[Dictionary]:
	return ShopData.shop_entries(kind)


## H5: one entry that can be shown and sold, by its exact id; {} for an unknown or hidden id. Check it before paying,
## so an unknown offer never falls back to Sprig or Thistle.
func shop_entry(kind: String, id: String) -> Dictionary:
	return ShopData.shop_entry(kind, id)


## H5: the attachments a shop sells for a slot, in index order: shop "saddlery" (levelled, everywhere) or "stall" (the
## Market's expedition gear); slot "mount" or "pet" ("" for both).
func attachment_entries(shop: String, slot: String) -> Array[Dictionary]:
	return ShopData.attachment_entries(shop, slot)


## H5: the level the player owns of entry id: 0 = not owned, 1 = owned (a look or an outfit), a Saddlery attachment's
## bought level. From the v5 save (Save.owned[kind][id] = {"level": n}); an entry with an explicit free price ({})
## whose unlock rule holds counts as owned at level 1 (Thistle and Bramblewool once the Market is built, the original
## outfit).
func owned_level(kind: String, id: String) -> int:
	return ShopData.owned_level(kind, id)


## H5: a mount's or pet's model (slot "mount" or "pet"; its entry's "model") when the file exists, else "".
func companion_model(slot: String, id: String) -> String:
	return ShopData.companion_model(slot, id)


## H5: an entry's full-body shop picture (its "picture") when the file exists, else "" (the window shows its "icon").
func shop_picture(kind: String, id: String) -> String:
	return ShopData.shop_picture(kind, id)


## H5: an attachment's model fitted to a mount look (res://assets/companions/attachments/<id>_<look>.glb, from its
## entry's "model") when the file exists, else "".
func gear_model(id: String, look_id: String) -> String:
	return ShopData.gear_model(id, look_id)


## H5: what reaching `level` of an entry costs (level 1: its "price"; later levels: its "upgrades"), its currencies
## only; {} when it is free, past its top or unknown. entry_price_ok says whether it can be paid at all.
func entry_price(kind: String, id: String, level: int = 1) -> Dictionary:
	return ShopData.entry_price(kind, id, level)


## H5: that level can be sold: a shown entry, a level it has, a price in currencies the shops take (fails closed).
func entry_price_ok(kind: String, id: String, level: int = 1) -> bool:
	return ShopData.entry_price_ok(kind, id, level)


## H5: what training the pet to `level` costs (balance.json pet.level_prices: levels 2 and 3); {} for level 1 (buying
## the pet is its entry's price) and past the top.
func pet_level_price(level: int) -> Dictionary:
	return ShopData.pet_level_price(level)


## H5: the pet's top level (3). pet_level_cap() is the highest it can be trained to now (never above the Hearthtree).
func pet_top() -> int:
	return ShopData.pet_top()


func pet_level_cap() -> int:
	return ShopData.pet_level_cap()


## H5: the mount's walking-speed multiplier and base health at mount level `level` (balance.json mount tables, levels
## 1-5). The Saddlery's confirm, the pet and mount windows, riding and the mount's health all read these.
func mount_speed_at(level: int) -> float:
	return ShopData.mount_speed_at(level)


func mount_base_hp_at(level: int) -> int:
	return ShopData.mount_base_hp_at(level)


## H5 (the owner's Q2 A): the mount's level with the Saddlery at `level`: 0 when no mount is owned, else the highest of
## 1, that level and the tier an old save already paid for (Save.saddlery mount_credit).
func mount_level_at_saddlery(level: int) -> int:
	return ShopData.mount_level_at_saddlery(level)


## H5: the skill in each of the mount's circles, in order ("" for an empty one), always saddlery.skill_slot_count (3)
## of them; every mount shares them. skill_level(id) is still the learned level, in a circle or not.
func skill_slots() -> Array[String]:
	return ShopData.skill_slots()


func skill_is_slotted(id: String) -> bool:
	return ShopData.skill_is_slotted(id)


## H5: the level the mount fights with: the learned level while the skill is in a circle, else 0.
func active_skill_level(id: String) -> int:
	return ShopData.active_skill_level(id)


## The game's own command-line arguments (after "--"). On a debug build a one-shot file user://test_args.txt (one
## argument per line, put there with `adb shell run-as ...`) adds to them and is then deleted: the phone's launcher
## does not pass intent extras on, so this is how the automated tests run on a phone. Use this, not
## OS.get_cmdline_user_args(), everywhere.
func args() -> PackedStringArray:
	if not _args_read:
		_args_read = true
		_args = OS.get_cmdline_user_args()
		var path := "user://test_args.txt"
		if OS.is_debug_build() and FileAccess.file_exists(path):
			for line in FileAccess.get_file_as_string(path).split("\n", false):
				if line.strip_edges() != "":
					_args.append(line.strip_edges())
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return _args


func enemy(id: String) -> Dictionary:
	return b["enemies"][id]


func patch(i: int) -> Dictionary:
	return b["patches"][i]


func patch_count() -> int:
	return b["patches"].size()


## The trail (one of the four lanes through the woods) a stage's enemies come down. The first four stages are the
## four patches themselves; later stages come back down a lane that is already claimed.
func lane(i: int) -> int:
	return int(patch(i).get("lane", i))


func lane_count() -> int:
	return int(b.get("lanes", 4))


func mission(i: int) -> Dictionary:
	return b["missions"][i]


func mission_count() -> int:
	return b["missions"].size()


func mission_index(id: String) -> int:
	for i in mission_count():
		if String(mission(i)["id"]) == id:
			return i
	return -1


## How far the player has come: the number of different missions won.
func progress() -> int:
	var won := 0
	for entry: Dictionary in b["missions"]:
		if Save.missions_done.has(String(entry["id"])):
			won += 1
	return won


## The first mission not won yet (mission_count() when all are won).
func next_mission() -> int:
	for i in mission_count():
		if not Save.missions_done.has(String(mission(i)["id"])):
			return i
	return mission_count()


# ---------------------------------------------------------------- Phase F: mission gates and the home's goals
## The home level mission i needs before it can start (balance.json missions[i].needs_home, 1 when there is none).
func mission_needs_home(i: int) -> int:
	if i < 0 or i >= mission_count():
		return 1
	return int(mission(i).get("needs_home", 1))


## Can mission i start now? Only the next mission to win, once the home is big enough for it, or a mission with a saved
## run (a wave checkpoint or a camp fall). Completed raid missions are available for replay.
## Since 21 Nov 2026 every mission's needs_home is 1 (the owner: missions never wait for a Hearthtree upgrade), so in
## practice the next mission opens as soon as the one before it is won.
func mission_unlocked(i: int) -> bool:
	if i < 0 or i >= mission_count():
		return false
	if Save.mission_run.has("mission") and int(Save.mission_run["mission"]) == i:
		return true
	if Save.missions_done.has(String(mission(i)["id"])):
		return true                                   # completed raid missions remain available for replay
	return i == next_mission() and mission_needs_home(i) <= Save.camp_level


## The goals to reach home `level` (the home entry's levels[level - 1].goals; its _note lists the types),
## worked out from the save now, in the list's order. Each is
##   {text: "Damage 4", progress: "Damage 3/4", have, need, done, station}
## `text` names the goal, `progress` is what the card shows while it is not met. `station` is the station whose card
## sells it: "target" (damage, draw, range), "home" (the Hearthtree's own window: health, speed and magnet on its Cat
## tab, towers and defences on its Defences tab), "build" (the build menu, H4: a building not built yet, the bows
## before the Bow Shop, the Target's stats before the Target), "bench" (bows), "sign" (a mission, or a building a
## mission gives),
## "hollow" (a Gloomwood level), or the station's own id (its level). [] for level 1 or a level past the top.
func home_goals(level: int) -> Array:
	var levels := building_levels("home")
	if level < 2 or level > levels.size():
		return []
	var out: Array = []
	for g in (levels[level - 1] as Dictionary).get("goals", []):
		if typeof(g) == TYPE_DICTIONARY:
			out.append(_goal(g))
	return out


## Every goal for home `level` is met, and the older gates on levels 6-8 too (needs_burrows, needs_depth; needs_missions
## when a level still has one). The price is not part of it (home_can_grow checks both).
func home_goals_met(level: int) -> bool:
	var levels := building_levels("home")
	if level <= 1:
		return true
	if level > levels.size():
		return false
	var lv: Dictionary = levels[level - 1]
	if progress() < int(lv.get("needs_missions", 0)):
		return false
	if bool(lv.get("needs_burrows", false)) and not burrows_open():
		return false
	if burrow_depth(String(burrow_list()[0]["id"])) < int(lv.get("needs_depth", 0)):
		return false
	for g in home_goals(level):
		if not bool(g["done"]):
			return false
	return true


## What growing the home to `level` costs (every currency its level names; {} past the top).
func home_price(level: int) -> Dictionary:
	return level_price("home", level)


## The home can grow now: a next level exists, its goals are met and its price is affordable.
func home_can_grow() -> bool:
	var nxt := Save.camp_level + 1
	return nxt <= building_levels("home").size() and home_goals_met(nxt) and can_afford(home_price(nxt))


## Phase G2: the camp's heart, the tree home and the campfire under one name (balance.json camp_name, "the
## Hearthtree"). cap: "The Hearthtree", for the start of a sentence or a title.
func camp_name(cap := false) -> String:
	var n := String(b.get("camp_name", "the Hearthtree"))
	if cap and n != "":
		n = n.substr(0, 1).to_upper() + n.substr(1)
	return n


## H4: a building's content entry (content/buildings/<id>/entry.json: name, desc, icon, price, unlock, arrives, levels),
## by the save's building id; "camp" and "shop" are the Hearthtree's older ids and mean "home". {} for an unknown id.
func building(id: String) -> Dictionary:
	return item("buildings", "home" if id == "camp" or id == "shop" else id)


## H4: every building entry, in content/index.json's order.
func buildings() -> Array:
	return catalog("buildings")


## H4: the buildings bought in the build menu (their "arrives" is "menu"), in index order.
func menu_buildings() -> Array:
	var out: Array = []
	for entry: Dictionary in buildings():
		if from_menu(String(entry["id"])):
			out.append(entry)
	return out


## H4: building id is bought in the build menu ("arrives": "menu"; it replaces the old SHOP_BUILT list). The garden
## and the fishing spot come as mission gifts ("gift"), the Guardian Stone is found ("found"), the home is always there.
func from_menu(id: String) -> bool:
	return building(id).get("arrives", "") == "menu"


## H4: a building's levels as its entry has them (levels[0] is {}; levels[n - 1] is what reaching level n costs, and
## the home's also hold its goals).
func building_levels(id: String) -> Array:
	return building(id).get("levels", [])


## H4: what building it costs (its entry's "price"), its real currencies only, never 0s; {} when it is free.
func build_price(id: String) -> Dictionary:
	return _currency_price(building(id).get("price", {}))


## H4: what reaching `level` costs (the currencies of levels[level - 1]); level 1 is the build price (build_price), so
## {} outside 2..the number of levels.
func level_price(id: String, level: int) -> Dictionary:
	var levels := building_levels(id)
	if level < 2 or level > levels.size():
		return {}
	return _currency_price(levels[level - 1])


## H4: a building's short line (its entry's "desc"), with {pet_look} and {mount_look} (the looks' names), {pet}
## (Data.pet_name()) and {mount} (Data.mount_name(), the short name) filled in, so it reads as the old card's line.
func building_desc(id: String) -> String:
	var desc := String(building(id).get("desc", ""))
	if "{pet_look}" in desc:
		desc = desc.replace("{pet_look}", String(look("pet", Save.pet_look)["name"]))
	if "{mount_look}" in desc:
		desc = desc.replace("{mount_look}", String(look("mount", Save.mount_look)["name"]))
	if "{pet}" in desc:
		desc = desc.replace("{pet}", pet_name())
	if "{mount}" in desc:
		desc = desc.replace("{mount}", mount_name())
	return desc


## H4: a building's picture for the windows, "res://assets/ui/buildings/<id>.png" when that file exists, else "" (the
## window then shows the building's icon).
func building_picture(id: String) -> String:
	var path := "res://assets/ui/buildings/%s.png" % id
	return path if ResourceLoader.exists(path) else ""


## Phase G2: the Hearthtree level station id needs before it can be built: the level of the ["home", n] part of its
## entry's unlock rule, 1 when the rule has none (the Market needs level 2).
func station_needs_home(id: String) -> int:
	return _required_building_level(building(id).get("unlock", {}), "home")


## Station id can be built now: its entry's unlock rule holds (unlocked), every part of it, so a flag in it counts too
## (H4; real play is the same, because a Build tile only shows once its flag is set, but a test that builds with the
## flags unset is refused now). An unknown id is shut.
func station_open(id: String) -> bool:
	var entry := building(id)
	return not entry.is_empty() and unlocked(entry.get("unlock", {}))


## H4: a window word or short line from balance.json "windows" (the buttons' words, tab names, the confirm's lines),
## or the key itself when it is missing, so a missing word shows as its key and never breaks a window.
func word(key: String) -> String:
	var words: Dictionary = b.get("windows", {})
	return String(words.get(key, key))


## The mission (index) whose win gives building id ("garden": mission 1's index), -1 when none gives it.
func gift_mission(id: String) -> int:
	for i in mission_count():
		if String(mission(i).get("gift", "")) == id:
			return i
	return -1


const _DEF_NAMES := {"barricade": "Barricades", "tower": "Towers", "spikes": "Thorn Spikes", "fence": "Fences"}


## "Barricades", "Towers", "Thorn Spikes": a defence kind as a whole (goals, the level tiles on the Hearthtree's card).
func def_kind_name(type: String) -> String:
	return String(_DEF_NAMES.get(type, type))


## One goal from the home entry worked out from the save (see home_goals). An unknown type counts as met, so a typo in
## the data never locks the home. H4: a goal whose building is not built yet has station "build" (the build menu: a
## building bought there, the bows before the Bow Shop, the Training Target's stats before the Target); the
## Hearthtree's Show opens the menu at that building.
func _goal(g: Dictionary) -> Dictionary:
	var type := String(g.get("type", ""))
	var lv := int(g.get("level", 1))
	var text := type
	var prog := ""
	var have := 0
	var need := 1
	var station := "home"
	var done := false
	var gid := String(g.get("id", ""))
	match type:
		"mission":
			need = int(g.get("n", 1))
			var won := need >= 1 and need <= mission_count() and Save.missions_done.has(String(mission(need - 1)["id"]))
			for i in mini(need, mission_count()):
				if Save.missions_done.has(String(mission(i)["id"])):
					have += 1
			have = need if won else mini(have, need - 1)
			text = "Finish Raid Mission %d" % need
			prog = "Finish Raid Mission %d · %d/%d finished" % [need, have, need]
			station = "sign"
		"station":
			var id := String(g.get("id", ""))
			var nm := String(building(id).get("name", id))
			have = int(Save.stations.get(id, 0))
			need = lv
			text = ("%s built" % nm) if lv <= 1 else ("%s lv %d" % [nm, lv])
			var gm := gift_mission(id)
			if have > 0:
				prog = "%s lv %d/%d" % [nm, have, lv]
				station = id
			elif gm >= 0:
				prog = "%s: finish Raid Mission %d" % [nm, gm + 1]
				station = "sign"
			else:
				prog = ("Build the %s" % nm) if lv <= 1 else ("Build the %s, then lv %d" % [nm, lv])
				station = "build" if from_menu(id) else id    # H4: bought in the build menu
		"pet_level":
			# H5 (the owner's Q4 A): the pet trained to `level`. The pet is bought and trained at the shop its entry
			# names (the Market): Go walks to it once it is built, else Show opens the build menu at it (id).
			var shop := ShopData.pet_shop()
			var pn := pet_name()
			have = pet_level()
			need = lv
			text = word("pet_level_goal") % [pn, lv]
			if have > 0:
				prog = word("pet_level_progress") % [pn, have, lv]
			else:
				prog = word("pet_level_get") % [pn, String(building(shop).get("name", shop)), lv]
			station = shop if station_level(shop) > 0 or not from_menu(shop) else "build"
			gid = shop
		"stat":
			var sid := String(g.get("id", ""))
			var si := stat_info(sid)
			have = int(Save.stats.get(sid, 0))
			need = lv
			text = "%s %d" % [String(si["name"]), lv]
			prog = "%s %d/%d" % [String(si["name"]), have, lv]
			station = _stat_station(sid)
		"bow":
			var bid := String(g.get("id", ""))
			var bn := String(bow_info(bid)["name"])
			have = int(Save.bows.get(bid, 0))
			need = lv
			text = "%s lv %d" % [bn, lv]
			prog = ("%s lv %d/%d" % [bn, have, lv]) if have > 0 else ("Buy the %s, then lv %d" % [bn, lv])
			station = "bench" if int(Save.stations.get("bench", 0)) > 0 else "build"
		"bow_any":
			for k: String in bow_ids():
				have = maxi(have, int(Save.bows.get(k, 0)))
			need = lv
			text = "A bow at lv %d" % lv
			prog = "Best bow lv %d/%d" % [have, lv]
			station = "bench" if int(Save.stations.get("bench", 0)) > 0 else "build"
		"bow_owned":
			var oid := String(g.get("id", ""))
			var on := String(bow_info(oid)["name"])
			have = 1 if Save.bows.has(oid) else 0
			text = "%s owned" % on
			prog = "Buy the %s" % on
			station = "bench" if int(Save.stations.get("bench", 0)) > 0 else "build"
		"towers":
			need = int(g.get("count", 1))
			var placed := 0
			for sp in Save.placed:
				if typeof(sp) == TYPE_DICTIONARY and String(sp.get("type", "")) == "tower":
					placed += 1
			var tl := int(Save.def_levels.get("tower", 1))
			have = placed if tl >= lv else 0
			var tn := String(defence_info("tower")["name"]) + "s"
			text = ("%d %s" % [need, tn]) if lv <= 1 else ("Towers lv %d: %d" % [lv, need])
			if tl < lv:
				prog = "Towers to lv %d (now %d)" % [lv, tl]
			else:
				prog = ("%s %d/%d" % [tn, placed, need]) if lv <= 1 else ("Towers lv %d: %d/%d" % [lv, placed, need])
				var held := int(Save.items.get("tower", 0))
				if held > 0 and placed < need:
					prog += " · %d to place" % held
		"defence":
			var did := String(g.get("id", ""))
			var dn := String(_DEF_NAMES.get(did, did))
			have = int(Save.def_levels.get(did, 1))
			need = lv
			text = "%s lv %d" % [dn, lv]
			prog = "%s lv %d/%d" % [dn, have, lv]
		"all_stats":
			have = 999
			var low := ""
			for k in b["stats"]:
				var sl := int(Save.stats.get(k, 0))
				if sl < have:
					have = sl
					low = String(k)
			need = lv
			text = "All stats %d" % lv
			prog = "All stats %d/%d" % [have, lv]
			if low != "":
				prog += " · %s lowest" % String(stat_info(low)["name"])
				station = _stat_station(low)
				gid = low
		"depth":
			need = int(g.get("n", 1))
			var bd: Dictionary = burrow_list()[0]
			have = burrow_depth(String(bd["id"]))
			var dname := String(bd["name"]).trim_prefix("The ")
			text = "%s level %d" % [dname, need]
			prog = "Beat %s level %d" % [dname, need]
			station = "hollow"
		_:
			push_warning("balance.json: unknown home goal type %s" % type)
			have = need
	done = have >= need
	# type / id / level: the goal as the home entry has it (all_stats: id is the lowest stat), for the cards
	return {"text": text, "progress": prog if prog != "" else text, "have": have, "need": need, "done": done, "station": station,
		"type": type, "id": gid, "level": lv}


## Where a stat is bought: its own station ("target", or "home" for Health, Move speed and Leaf magnet: the
## Hearthtree's Cat tab); H4: "build" (the build menu) while that station is not built yet (the Training Target).
func _stat_station(id: String) -> String:
	var st := String(stat_info(id)["station"])
	if st == "camp":
		st = "home"
	if st != "home" and int(Save.stations.get(st, 0)) <= 0:
		return "build"
	return st


## A rough strength for the camp and the cat. Phase F: missions no longer show or hint with it (the home's goals and the
## mission gates lead the way); the Gloomwood's card still compares it with depth_power.
func power() -> int:
	var p := 0
	for k: String in b["stats"]:
		p += int(Save.stats.get(k, 0))
	p += int(Save.bows.get(Save.bow, 1)) - 1 + int(round((float(bow_info(Save.bow)["damage"]) - 1.0) * 6.0))
	p += (Save.camp_level - 1) * 3
	for sp in Save.placed:
		if String(sp.get("type", "")) == "tower":
			p += 1
	if guardian_awake():
		p += 2 * guardian_level()
	return p


## A building's health at level lv (balance.json building_hp). H5 (the owner's Q5 A): a standing Market never has less
## than the health an old save's upgraded Market had earned (Save.market_hp_floor: 340 or 500; 0 for one built since).
func building_hp(id: String, lv: int) -> float:
	var t: Array = b["building_hp"].get(id, [0, 200])
	var hp := float(t[clampi(lv, 0, t.size() - 1)])
	if id == MARKET and lv >= 1:
		hp = maxf(hp, float(Save.market_hp_floor))
	return hp


## A look's skin by id (its first, "natural", when there is no such skin).
func skin(slot: String, look_id: String, skin_id: String) -> Dictionary:
	var skins: Array = look(slot, look_id).get("skins", [])
	for s in skins:
		if String(s["id"]) == skin_id:
			return s
	return skins[0] if not skins.is_empty() else {}


## A companion look by id, the slot's first look for an unknown id. H5: the mount's and the pet's looks are content
## entries (content/mounts, content/pets: name, short, fur, skins; a pet's flies and spark); the guardian's stay in
## balance.json looks.guardian.
func look(slot: String, id: String) -> Dictionary:
	if ShopData.SLOT_KINDS.has(slot):
		return ShopData.look(slot, id)
	for l in b["looks"][slot]:
		if String(l["id"]) == id:
			return l
	return b["looks"][slot][0]


## The short name of the look in the mount or pet slot now ("Thistle", "Bramblewool", "Sprig", "Lumi").
func mount_name() -> String:
	return String(look("mount", Save.mount_look).get("short", "Thistle"))


func pet_name() -> String:
	return String(look("pet", Save.pet_look).get("short", "Sprig"))


## H5: the pet's one shared level (Save.pet_level): 0 before the pet is bought at the Market's Pets tab, then 1-3.
## Every pet look fights at it (pet.gd: balance.json pet damage_by_level, every_by_level).
func pet_level() -> int:
	return ShopData.pet_level()


## H5 (the owner's Q2 A): the mount's level now: 0 while no mount is owned, else the highest of 1, the Saddlery's level
## and the tier an old save's Market paid for (mount_level_at_saddlery). Riding speed and the mount's health read it.
func mount_level() -> int:
	return mount_level_at_saddlery(saddlery_level())


func pick(table: String, key: String, lv: int) -> float:
	var t: Array = b[table][key]
	return float(t[clampi(lv, 0, t.size() - 1)])


func stat_info(id: String) -> Dictionary:
	return b["stats"][id]


## H4: a bow's content entry (content/bows/<id>/entry.json: name, desc, price, unlock and its shooting numbers), {}
## for an unknown id. It is the shared entry, not a copy: the bow tests can change a number and put it back.
func bow_info(id: String) -> Dictionary:
	return item("bows", id)


## H4: every bow entry, in content/index.json's order (the Bow Shop's order).
func bows() -> Array:
	return catalog("bows")


## H4: every bow id, in index order.
func bow_ids() -> Array:
	var entries: Dictionary = _catalogues.get("bows", {})
	return entries.keys()


## H4: a bow entry with this id exists (a save whose bow in the paw is unknown goes back to the twig bow, save.gd).
func has_bow(id: String) -> bool:
	return not bow_info(id).is_empty()


## H4: the Bow Shop level a bow needs before it is sold: the level of the ["bench", n] part of its unlock rule, 1 when
## the rule has none.
func bow_shop_level(bid: String) -> int:
	return _required_building_level(bow_info(bid).get("unlock", {}), "bench")


## H4: the bow waits for a place the cat has not reached yet: its unlock rule has a flag part that is not set (the
## Foxfire Bow's "hollow_open" before the Gloomwood).
func bow_waits(bid: String) -> bool:
	var rule: Dictionary = bow_info(bid).get("unlock", {})
	return rule.has("flag") and not Save.flag(String(rule["flag"]))


## H4: a bow's picture for the Bow Shop, "res://assets/ui/bows/bow_<id>.png" when that file exists, else "" (the bow's
## art stays in assets/ by id, like the crops').
func bow_picture(bid: String) -> String:
	var path := "res://assets/ui/bows/bow_%s.png" % bid
	return path if ResourceLoader.exists(path) else ""


## Bow upgrades are additive shares of base damage. The stronger late levels also apply to existing purchases.
func bow_level_mult(id: String, level: int) -> float:
	var curve: Dictionary = b["bow_upgrade_curve"]
	var first := int(curve["late_from_level"])
	var last := int(curve["late_to_level"])
	var upgrades := maxi(0, level - 1)
	var late := maxi(0, mini(level, last) - first + 1)
	return 1.0 + float(bow_info(id)["per_level"]) * (upgrades - late) + float(curve["late_per_level"]) * late


func defence_info(id: String) -> Dictionary:
	return b["defences"][id]


# ---------------------------------------------------------------- caps (what a station's level allows)
func station_level(id: String) -> int:
	if id == "home" or id == "camp" or id == "shop":
		return Save.camp_level
	return int(Save.stations.get(id, 0))


## The highest level stat id can be bought to now: stat_cap_by_station_level at its station's level (Phase F: the
## Training Target has 5 levels, 4/6/8/9/10; Health, Move speed and Leaf magnet use the home level, so homes 5-8 all
## give 10), 0 below the station level it needs; mastery (11-12) once the Burrows are open.
func stat_cap(id: String) -> int:
	var st := station_level(String(stat_info(id)["station"]))
	var caps: Array = b["stat_cap_by_station_level"]
	var need := int(stat_info(id).get("needs_station_level", 1))
	if st < need:
		return 0
	var cap := int(caps[clampi(st, 0, caps.size() - 1)])
	# Phase E: mastery (levels 11-12, paid with the price balance.json names, leaves today) once the Burrows are open; never by home level
	var mastery: Array = stat_info(id).get("mastery", [])
	if burrows_open() and cap >= (stat_info(id)["cost"] as Array).size() and not mastery.is_empty():
		cap = (stat_info(id)["cost"] as Array).size() + mastery.size()
	return cap


## The highest bow level now: bow_cap_by_bench_level at the Bow Shop's level (station "bench"; Phase F: 5 levels,
## 4/6/8/9/10); 12 once the Burrows are open and the shop allows 10.
func bow_cap() -> int:
	var caps: Array = b["bow_cap_by_bench_level"]
	var cap := int(caps[clampi(station_level("bench"), 0, caps.size() - 1)])
	if burrows_open() and cap >= 10:
		cap = 12                                       # Phase E: bow mastery 11 and 12
	return cap


## What raising a stat from level lv costs: leaves, then (mastery, past the cost list) the price balance.json names (leaves today).
func stat_cost(id: String, lv: int) -> Dictionary:
	var costs: Array = stat_info(id)["cost"]
	if lv < costs.size():
		return {"leaves": int(costs[lv])}
	var mastery: Array = stat_info(id).get("mastery", [])
	var k := lv - costs.size()
	return (mastery[k] as Dictionary).duplicate() if k >= 0 and k < mastery.size() else {}


## The most levels a stat has (its cost list plus its mastery once the Burrows are open).
func stat_top(id: String) -> int:
	var n := (stat_info(id)["cost"] as Array).size()
	if burrows_open():
		n += (stat_info(id).get("mastery", []) as Array).size()
	return n


## What raising bow bid from level lv costs (bow levels start at 1).
func bow_cost(bid: String, lv: int) -> Dictionary:
	var costs: Array = bow_info(bid)["cost"]
	if lv < costs.size():
		return {"leaves": int(costs[lv])}
	var mastery: Array = bow_info(bid).get("mastery", [])
	var k := lv - costs.size()
	return (mastery[k] as Dictionary).duplicate() if k >= 0 and k < mastery.size() else {}


func bow_top(bid: String) -> int:
	var n := (bow_info(bid)["cost"] as Array).size()
	if burrows_open():
		n += (bow_info(bid).get("mastery", []) as Array).size()
	return n


## A bow's price on the Bow Shop as a cost dictionary (its entry's "price", such as {"leaves": 250, "timber": 10}; only
## real currencies are kept, never 0s; {} for the twig bow, which is free).
func craft_cost(bid: String) -> Dictionary:
	return _currency_price(bow_info(bid).get("price", {}))


## G3: a bow's Ember fire ({"seconds", "share_per_s"}: the enemy hit burns for seconds, taking share_per_s x the hit's
## damage each second); {} for a bow without fire.
func bow_burn(bid: String) -> Dictionary:
	var f = bow_info(bid).get("burn", {})
	return (f as Dictionary).duplicate() if typeof(f) == TYPE_DICTIONARY else {}


## 22 Nov 2026: the Frost Bow's ice ({"slow", "seconds", "hits_to_freeze", "freeze_s", "boss_freeze_s"}: each hit slows
## the enemy, the hits_to_freeze-th hit while it is slowed freezes it; enemy.gd chill); {} for a bow without ice.
func bow_frost(bid: String) -> Dictionary:
	var f = bow_info(bid).get("frost", {})
	return (f as Dictionary).duplicate() if typeof(f) == TYPE_DICTIONARY else {}


## 22 Nov 2026: a bow kept out of the Bow Shop for now (the entry's "hidden": Thorn Volley, Foxfire). It is not sold and
## its tile is not shown, but a save that owns it still sees it (Owned / Equipped) and can use it.
func bow_hidden(bid: String) -> bool:
	return bool(bow_info(bid).get("hidden", false))


## 22 Nov 2026: a bow's shooting effects (the entry's "fx", read by fx.gd: colours, kinds and particle counts); {} if none.
func bow_fx(bid: String) -> Dictionary:
	if not has_bow(bid):
		return {}
	var f = bow_info(bid).get("fx", {})
	return f if typeof(f) == TYPE_DICTIONARY else {}


## The highest level a station can have now: its level list's size (Target and Bench 5, most others 3), never above the
## home level. The home itself: its own list (8).
func station_max_level(id: String) -> int:
	var top := building_levels(id).size()
	if id == "home" or id == "camp" or id == "shop":
		return top
	return mini(Save.camp_level, top)


func fire_hp() -> int:
	var t: Array = b["fire_hp_by_camp_level"]
	return int(t[clampi(Save.camp_level, 0, t.size() - 1)])


func light_radius() -> float:
	var t: Array = b["light_radius_by_camp_level"]
	return float(t[clampi(Save.camp_level, 0, t.size() - 1)])


# ---------------------------------------------------------------- the cat's numbers now
func _lv(id: String) -> int:
	return int(Save.stats.get(id, 0))


func cat_max_hp() -> int:
	return int(b["cat"]["hp"]) + int(stat_info("health")["per_level"]) * _lv("health") + int(run_mods.get("hp", 0))


## H3: x (1 + the Speed Potion's share) while one runs (Data.effect_mult; riding multiplies this by the mount's speed).
func cat_speed() -> float:
	return float(b["cat"]["speed"]) * (1.0 + float(stat_info("speed")["per_level"]) * _lv("speed")) * (1.0 + effect_mult("speed"))


func cat_range() -> float:
	# a bow's range_bonus may be negative (Ember); never below cat.min_range_m
	return maxf(float(b["cat"].get("min_range_m", 2.0)), float(b["cat"]["range"]) + float(stat_info("range")["per_level"]) * _lv("range") \
		+ float(bow_info(Save.bow)["range_bonus"]))


## 22 Nov 2026: a bow's draw_mult (default 1.0) multiplies the time a draw and shot take: 1.25 = 25% slower.
func bow_draw_mult(id: String) -> float:
	return maxf(0.1, float(bow_info(id).get("draw_mult", 1.0)))


func cat_draw() -> float:
	return float(b["cat"]["draw"]) * (1.0 + float(stat_info("draw")["per_level"]) * _lv("draw"))


func cat_magnet() -> float:
	return float(b["cat"]["magnet"]) + float(stat_info("magnet")["per_level"]) * _lv("magnet")


## H3: x (1 + the Damage Potion's share) while one runs (Data.effect_mult; arrows only). H4: `bid` names another bow
## (the Bow Shop's inspect view shows each bow's arrow with the same sum); "" is the bow in the cat's paw, which every
## shot uses (player.gd _fire). A bow not owned counts at level 1.
func arrow_damage(bid := "") -> float:
	var id := Save.bow if bid == "" else bid
	var bow := bow_info(id)
	var bow_lv := int(Save.bows.get(id, 1))
	return float(b["cat"]["damage"]) * (1.0 + float(stat_info("damage")["per_level"]) * _lv("damage")) \
		* float(bow["damage"]) * bow_level_mult(id, bow_lv) * (1.0 + effect_mult("damage")) \
		* (1.0 + float(run_mods.get("damage", 0.0)))


var _effect_mults := {}              # H3: the cat's running potion effects, stat -> share (the Effects holder sets it)


## H3: the cat's Effects holder (parts/effects_holder.gd) hands over the full map of every stat with a running
## stat_mult effect ({"damage": 0.25, "speed": 0.25}, or {} when none): it replaces the whole map (a copy is kept).
func set_effect_mults(d: Dictionary) -> void:
	_effect_mults = d.duplicate()


## H3: a running potion's share for a stat (the stat becomes x (1 + this)); 0.0 when none runs.
func effect_mult(stat: String) -> float:
	return float(_effect_mults.get(stat, 0.0))


# ---------------------------------------------------------------- Phase C: the Moss Warden, the garden, the pantry
func guardian_level() -> int:
	return int(Save.stations.get("stone", 0))


func guardian_awake() -> bool:
	return guardian_level() > 0 and Save.flag("warden_awake")


func guardian_name() -> String:
	return String(look("guardian", Save.guardian_look).get("short", "Moss Warden"))


## The Warden grows with the home too: every number is x this.
func guardian_power() -> float:
	return pick("guardian", "power_by_camp_level", Save.camp_level)


func guardian_max_hp() -> float:
	return pick("guardian", "hp_by_level", guardian_level()) * guardian_power()


func guardian_fist() -> float:
	return pick("guardian", "fist_damage_by_level", guardian_level()) * guardian_power()


func guardian_slam() -> float:
	return pick("guardian", "slam_damage_by_level", guardian_level()) * guardian_power()


func guardian_revive_s() -> float:
	return float(b["guardian"]["revive_s"])


func garden_level() -> int:
	return int(Save.stations.get("garden", 0))


func garden_plots() -> int:
	return int(pick("garden", "plots_by_level", garden_level()))


func _by_id(list: Array, id: String) -> Dictionary:
	for e in list:
		if String(e["id"]) == id:
			return e
	return {}


## H3: a crop's content entry (content/crops/<id>/entry.json: name, desc, icon, model, gives, yield, grow_s, price,
## unlock), or {} for "" or an unknown id.
func crop(id: String) -> Dictionary:
	return item("crops", id) if id != "" else {}


## H3: a recipe's content entry (content/recipes/<id>/entry.json: the recipe is its result's type, and its id is the
## Bag item's id: name, plural, desc, icon, color, needs, cook_s, limit, unlock, effects), or {}.
func recipe(id: String) -> Dictionary:
	return item("recipes", id) if id != "" else {}


## H3, H4: an entry's unlock rule (ARCHITECTURE part 5) holds. It knows four forms, and a rule may have several keys,
## which must all hold:
##   {}                          always open
##   {"building": [id, level]}   that building (Save.stations, or the home) has reached level
##   {"flag": id}                that Save flag is set (for example "shop_open", "hollow_open")
##   {"missions_won": n}         at least n missions won (Data.progress() >= n)
## An unknown key or a malformed part warns and stays shut.
func unlocked(rule: Dictionary) -> bool:
	return unlock_missing(rule).is_empty()


## H4: the parts of an unlock rule that are not met yet (see unlocked), in the rule's order; [] when it holds. Each is
## one of:
##   {"type": "building", "id": String, "level": int}   that building is not built or not at that level yet
##   {"type": "flag", "id": String}                      that flag is not set
##   {"type": "missions_won", "n": int}                  fewer missions won than n
##   {"type": "unknown", "id": <the key>}                an unknown key or a malformed part (it also warns): nothing
##                                                        the player can do, so a window's "needs" words skip it
func unlock_missing(rule: Dictionary) -> Array:
	var missing: Array = []
	for key: Variant in rule:
		var value: Variant = rule[key]
		match key:
			"building":
				var part := _unlock_building(value)
				if not part.is_empty():
					var id := String(part[0])
					var level := int(part[1])
					if building(id).is_empty() or station_level(id) < level:
						missing.append({"type": "building", "id": id, "level": level})
					continue
			"flag":
				if value is String and not String(value).is_empty():
					var id := String(value)
					if not Save.flag(id):
						missing.append({"type": "flag", "id": id})
					continue
			"missions_won":
				if _unlock_count(value, 0):
					var n := int(value)
					if progress() < n:
						missing.append({"type": "missions_won", "n": n})
					continue
		push_warning("Data.unlocked: an unlock rule of a form it does not know: %s" % JSON.stringify(rule))
		missing.append({"type": "unknown", "id": str(key)})
	return missing


## The level a rule's "building" part asks of building id, 1 when the part names another building or there is none.
func _required_building_level(rule: Dictionary, id: String) -> int:
	var part := _unlock_building(rule.get("building"))
	return int(part[1]) if not part.is_empty() and String(part[0]) == id else 1


## A well-formed "building" part, [id, level] (an id and a whole level of at least 1), else [].
func _unlock_building(value: Variant) -> Array:
	if value is Array and value.size() == 2 and value[0] is String and _unlock_count(value[1], 1):
		return value
	return []


## The value is a whole, finite number of at least minimum (JSON numbers come as floats).
func _unlock_count(value: Variant, minimum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum \
		and float(value) == floorf(float(value))


func catch_info(id: String) -> Dictionary:
	return _by_id(b["fishing"]["catches"], id) if id != "" else {}


## "Sunberry" or "Sunberries" (balance.json ingredients); H3: a potion's "name" or "plural" (content/recipes); else
## the id itself.
func item_name(id: String, n: int) -> String:
	var names: Variant = (b["ingredients"] as Dictionary).get(id)
	if names is Array and (names as Array).size() >= 2:
		return String(names[0] if n == 1 else names[1])
	var r := recipe(id)
	if not r.is_empty():
		var one := String(r.get("name", id))
		return one if n == 1 else String(r.get("plural", one))
	return id


## H2 legacy: nothing calls it since H3 (kept; removing it was not part of H3).
func food_known(id: String) -> bool:
	if Bag.count(id) > 0:
		return true
	match id:
		"goldfish": return int(Save.fish_log.get("carp", 0)) > 0
		"fish": return int(Save.stations.get("fishing", 0)) > 0 or not Save.fish_log.is_empty()
	return b["ingredients"].has(id)


## Completed Bag changes and what the Bag holds now, shared by gathering, cooking and trading: "+3 Sunberries · now 8"
## (H3: no cap any more; the Bag's room is Bag.room_for).
func food_receipt(changes: Dictionary) -> String:
	var bits: Array = []
	for id: Variant in changes:
		var n := int(changes[id])
		bits.append("%+d %s · now %d" % [n, Bag.name_of(String(id), absi(n)), Bag.count(String(id))])
	return " · ".join(bits)


## H3: the Bag holds at least needs[id] of every id (Bag.has_all).
func has_items(needs: Dictionary) -> bool:
	return Bag.has_all(needs)


## H3: takes every needs[id] from the Bag, all or nothing (Bag.take_all).
func take_items(needs: Dictionary) -> bool:
	return Bag.take_all(needs)


## H3: puts things in the Bag, each as far as it has room (Bag.add_all). Returns what did not fit.
func add_items(d: Dictionary) -> Dictionary:
	return Bag.add_all(d)


# ---------------------------------------------------------------- money
## Everything a cost dictionary can ask for. Cost dictionaries may also hold other keys (needs_missions, needs_burrows,
## mats, ...): those are not money, so can_afford and pay loop over these only.
## H1 (25 Nov 2026, the owner): amber is the one expedition material. No price asks for it: it is held (the Bag) and
## sold to Bramble, who takes it with pay(). Glowstone, heartwood and the Hollow keys are gone (an old save's turned
## into leaves: core/save_upgrades.gd).
const CURRENCIES := ["leaves", "timber", "shards", "amber"]
const MATS := ["amber"]                  # the expedition materials (balance.json burrows.materials), held in Save.mats


## H4: only the real currencies of a price (CURRENCIES), never 0s: a level's other keys (goals, needs_burrows, ...) are
## not money.
func _currency_price(price: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: String in CURRENCIES:
		var amount := int(price.get(key, 0))
		if amount > 0:
			out[key] = amount
	return out


func have(k: String) -> int:
	match k:
		"leaves": return Save.leaves
		"timber": return Save.timber
		"shards": return Save.shards
	return int(Save.mats.get(k, 0)) if k in MATS else 0


func give(k: String, n: int) -> void:
	match k:
		"leaves": Save.leaves += n
		"timber": Save.timber += n
		"shards": Save.shards += n
		_:
			if k in MATS:
				Save.add_mat(k, n)
			else:
				push_warning("Data.give: %s is not a currency" % k)


func take(k: String, n: int) -> void:
	give(k, -n)


func can_afford(cost: Dictionary) -> bool:
	for k in CURRENCIES:
		if have(k) < int(cost.get(k, 0)):
			return false
	return true


func pay(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for k in CURRENCIES:
		var n := int(cost.get(k, 0))
		if n != 0:
			take(k, n)
	return true


# ---------------------------------------------------------------- Phase D: the Gloom Raids
func gr() -> Dictionary:
	return b["gloom_raids"]


## Every mission has been won: the Gloom Raids are on (and the signpost is the Watch).
func raids_open() -> bool:
	return next_mission() >= mission_count()


# ---------------------------------------------------------------- Phase E: the Burrows
func burrow_cfg() -> Dictionary:
	return b["burrows"]


## Every Burrow (balance.json burrows.list): name, entrance, tiers (pools, looks), bosses. A new Burrow is data plus models.
func burrow_list() -> Array:
	return burrow_cfg()["list"]


func burrow_def(id: String) -> Dictionary:
	for bd in burrow_list():
		if String(bd["id"]) == id:
			return bd
	return burrow_list()[0]


## The Burrows are open: the last mission was won and the Old Hollow broke its seal (burrow.gd open_hollow).
func burrows_open() -> bool:
	return Save.flag("hollow_open")


## The highest level beaten in a Burrow (level + 1 is open). Saved as "depth" (Phase E's word) so old saves keep it.
func burrow_depth(id: String) -> int:
	return int(Save.burrow_stats(id)["depth"])


var _maps := {}


## A Burrow's map (res://data/dungeons/<map>.json: the path, clearings, fights, the end; docs/DUNGEON_SPEC.md). The
## Burrow's "map" key names it (its id when there is none). {} when the file is missing or does not parse.
func dungeon(map_id: String) -> Dictionary:
	if not _maps.has(map_id):
		var path := "res://data/dungeons/%s.json" % map_id
		var m = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		if typeof(m) != TYPE_DICTIONARY:
			push_error("%s is missing or did not parse" % path)
			m = {}
		_maps[map_id] = m
	return _maps[map_id]


func burrow_map_id(id: String) -> String:
	return String(burrow_def(id).get("map", id))


func mat_name(id: String) -> String:
	return String(burrow_cfg()["materials"].get(id, {}).get("short", id))


## " · have 12 amber": the materials a cost asks for, as the player has them ("" when it asks for none; since H1 no
## price asks for one).
func mats_line(cost: Dictionary) -> String:
	var bits: Array = []
	for k in MATS:
		if int(cost.get(k, 0)) > 0:
			bits.append("%d %s" % [have(k), mat_name(k)])
	return " · have " + ", ".join(bits) if not bits.is_empty() else ""


## "9 amber" (only those above 0), "nothing yet" when empty.
func mats_text(d: Dictionary) -> String:
	var bits: Array = []
	for k in MATS:
		if int(d.get(k, 0)) > 0:
			bits.append("%d %s" % [int(d[k]), mat_name(k)])
	return " · ".join(bits) if not bits.is_empty() else "nothing yet"


func _by_depth(key: String, d: int) -> float:
	var t: Array = burrow_cfg()[key]
	return float(t[clampi(d, 0, t.size() - 1)])


## The tier (monster pool, elites) of level d in a Burrow: levels past the last tier reuse it.
func depth_tier(id: String, d: int) -> Dictionary:
	var tiers: Array = burrow_def(id)["tiers"]
	var best: Dictionary = tiers[0]
	for t in tiers:
		if int(t["first"]) <= d:
			best = t
	return best


func depth_strength(d: int) -> float:
	var s := _by_depth("strength_by_depth", d)
	if d > 5:
		s += float(burrow_cfg()["strength_per_depth_after"]) * (d - 5)
	return s


func depth_damage_add(d: int) -> int:
	var a := int(_by_depth("damage_add_by_depth", d))
	if d > 5:
		var after: Dictionary = burrow_cfg()["damage_add_after"]
		a = mini(int(after["max"]), a + (d - 5) / int(after["every"]))
	return a


func depth_trap_damage(d: int) -> int:
	return int(_by_depth("trap_damage_by_depth", d))


## Pay grows past depth 5 by pay_per_depth_after a depth.
func depth_pay(d: int) -> float:
	return 1.0 + float(burrow_cfg()["pay_per_depth_after"]) * maxi(0, d - 5)


func depth_leaf_mult(d: int) -> float:
	return minf(_by_depth("leaf_mult_by_depth", d) * depth_pay(d), float(burrow_cfg()["leaf_mult_max"]))


func depth_power(d: int) -> int:
	var p := int(_by_depth("power_by_depth", d))
	if d > 5:
		p += int(burrow_cfg()["power_per_depth_after"]) * (d - 5)
	return p


## A drop table's value at depth d (a number; floor plus a chance of one more is rolled by the caller).
func depth_drop(table: Dictionary, key: String, d: int) -> float:
	var t: Array = table.get(key, [])
	if t.is_empty():
		return 0.0
	return float(t[clampi(d, 0, t.size() - 1)]) * depth_pay(d)


## What a Burrow's map ends in, for the card and banners: "Mossback" (a boss), or "a treasure".
func burrow_end_name(id: String) -> String:
	var e: Dictionary = dungeon(burrow_map_id(id)).get("end", {})
	if String(e.get("type", "boss")) == "boss":
		return String(enemy(String(e.get("kind", "bear"))).get("name", "the boss"))
	return "a treasure"


## How many fights a Burrow's map has (one pip each on the HUD).
func burrow_fights(id: String) -> int:
	return (dungeon(burrow_map_id(id)).get("fights", []) as Array).size()


## The attachments worn now (the mount's and the pet's): Burrows-only help, each entry with its "mods". G4: the mount's
## saddle and bags moved to the Saddlery (below); only the Thunder Shoes are left in the mount slot. H5: the expedition
## gear is content (content/attachments, "scope": "expedition"); what is worn is Save.attach "mount" and "pet", what is
## owned the v5 save's owned.attachments (owned_level).
func attachments_on() -> Array:
	return ShopData.expedition_worn()


# ---------------------------------------------------------------- G4: the Saddlery (the mount's skills and attachments)
## The Saddlery's own rules (balance.json saddlery: gap_s, free_stomp, old_attachments, stand_in). The building's price
## and levels are stations.saddlery, like any station's.
func saddlery_cfg() -> Dictionary:
	return b.get("saddlery", {})


## The Saddlery's level (0 while it is not built). It caps the level of every skill and attachment.
func saddlery_level() -> int:
	return int(Save.stations.get("saddlery", 0))


## One shelf of the Saddlery: "skills" (balance.json mount_skills.items: stomp, ram, pounce, bellow) or "attach"
## (H5: the content/attachments entries the Saddlery sells: fire_spitter, saddle, saddlebags), in the card's order,
## id -> entry. What is learned is Save.saddlery "skills"; what is bought, Save.owned "attachments" (the v5 save).
func saddle_items(part: String) -> Dictionary:
	if part != "skills":
		return ShopData.saddle_attachments()
	var blk: Dictionary = b.get("mount_skills", {})
	return blk.get("items", {})


## A skill's or a Saddlery attachment's entry ({} for an unknown id). H5: an attachment's is its content entry (name,
## desc, icon, its numbers; price and upgrades are read through saddle_price).
func saddle_info(part: String, id: String) -> Dictionary:
	if part != "skills":
		return ShopData.saddle_attachment(id)
	return saddle_items(part).get(id, {})


## How far skill or attachment id is learned: 0 = not yet, else its level (1-5). A skill: Save.saddlery "skills"; H5
## (the v5 save), an attachment: its bought level in Save.owned.attachments (owned_level; Saddlery attachments only).
func saddle_level(part: String, id: String) -> int:
	if part != "skills":
		return ShopData.saddle_attachment_level(id)
	var skills: Variant = Save.saddlery.get(part, {})
	var lv: Variant = (skills as Dictionary).get(id, 0) if skills is Dictionary else 0
	return int(lv) if lv is int or lv is float else 0


func skill_level(id: String) -> int:
	return saddle_level("skills", id)


func attach_level(id: String) -> int:
	return saddle_level("attach", id)


## 22 Nov 2026 (the owner's rule): the mount owns any of its attachments but wears one at a time, or none. The one it
## wears now: Save.saddlery "worn" when that one is owned, else "".
func worn_attach() -> String:
	var id := String(Save.saddlery.get("worn", ""))
	return id if id != "" and attach_level(id) >= 1 else ""


## Attachment id's level when the mount wears it, else 0. Only the worn one acts: the Fire-spitter fires, the Mossweave
## Saddle's health and the Saddlebags' leaves count (mount_hp_mult, leaf_bonus, mount.gd).
func worn_level(id: String) -> int:
	return attach_level(id) if worn_attach() == id else 0


## What a save that owns attachments but wears none of them (one from before the one-worn rule) puts on: the highest
## level it owns; on a tie the first in saddlery.worn_tie_order (the Saddlebags). "" when it owns none.
func best_owned_attach() -> String:
	var order: Array = []
	for id in saddlery_cfg().get("worn_tie_order", []):
		order.append(String(id))
	for id in saddle_items("attach"):
		if not order.has(String(id)):
			order.append(String(id))
	var best := ""
	var best_lv := 0
	for id in order:
		var lv := attach_level(String(id))
		if lv > best_lv:
			best_lv = lv
			best = String(id)
	return best


## Its top level (5). A skill: the length of its price list; H5, an attachment: its price plus its upgrades.
func saddle_top(part: String, id: String) -> int:
	if part != "skills":
		return ShopData.entry_top("attachments", id) if not saddle_info(part, id).is_empty() else 0
	return (saddle_info(part, id).get("price", []) as Array).size()


## What reaching level lv costs (lv 1: learning it), its currencies only (needs_burrows is not money); {} past the top.
func saddle_price(part: String, id: String, lv: int) -> Dictionary:
	if part != "skills":
		return ShopData.entry_price("attachments", id, lv) if not saddle_info(part, id).is_empty() else {}
	var prices: Array = saddle_info(part, id).get("price", [])
	var out := {}
	if lv < 1 or lv > prices.size():
		return out
	var p: Dictionary = prices[lv - 1]
	for k in CURRENCIES:
		if int(p.get(k, 0)) > 0:
			out[k] = int(p[k])
	return out


## Level lv is sold only once the Burrows are open (after the missions). Since H1 its price is leaves and timber.
func saddle_needs_burrows(part: String, id: String, lv: int) -> bool:
	if part != "skills":
		return not saddle_info(part, id).is_empty() and ShopData.entry_needs_burrows("attachments", id, lv)
	var prices: Array = saddle_info(part, id).get("price", [])
	return lv >= 1 and lv <= prices.size() and bool((prices[lv - 1] as Dictionary).get("needs_burrows", false))


## Why the next level of id cannot be bought now, money aside ("" when it can): "built" (no Saddlery, or it is in
## ruins), "max" (at its top), "cap" (the Saddlery's level holds it back), "burrows" (the next level needs the Burrows).
func saddle_block(part: String, id: String) -> String:
	if saddlery_level() <= 0 or Save.ruined.has("saddlery"):
		return "built"
	var lv := saddle_level(part, id)
	if lv >= saddle_top(part, id):
		return "max"
	if lv + 1 > saddlery_level():
		return "cap"
	if saddle_needs_burrows(part, id, lv + 1) and not burrows_open():
		return "burrows"
	return ""


## base grown by level lv: x (1 + share x (lv - 1)) when share_key is in info, + add x (lv - 1) when add_key is.
func _grown(info: Dictionary, base_key: String, share_key: String, add_key: String, lv: int) -> float:
	var v := float(info.get(base_key, 0.0))
	var n := float(maxi(lv, 1) - 1)
	if share_key != "" and info.has(share_key):
		v *= 1.0 + float(info[share_key]) * n
	if add_key != "" and info.has(add_key):
		v += float(info[add_key]) * n
	return v


## A skill's damage at level lv (Stomp, Ram, Pounce: +40% a level).
func skill_damage(id: String, lv: int) -> float:
	return _grown(saddle_info("skills", id), "damage", "damage_per_level", "", lv)


## A skill's stun at level lv, seconds (Pounce 1 s +0.1 a level, Bellow 1.5 s +0.2).
func skill_stun(id: String, lv: int) -> float:
	return _grown(saddle_info("skills", id), "stun_s", "", "stun_add_per_level", lv)


## Bellow: the extra share of damage the stunned enemies take at level lv (0.2, +0.05 a level).
func skill_taken(id: String, lv: int) -> float:
	return _grown(saddle_info("skills", id), "taken", "", "taken_add_per_level", lv)


## The Fire-spitter's burn at level lv, damage a second (8, +40% a level).
func fire_burn_per_s(lv: int) -> float:
	return _grown(saddle_info("attach", "fire_spitter"), "burn_per_s", "burn_per_level", "", lv)


## A flame ball's impact damage, also applied to enemies in its splash radius.
func fire_damage(lv: int) -> float:
	return _grown(saddle_info("attach", "fire_spitter"), "damage", "damage_per_level", "", lv)


## The Mossweave Saddle: the mount's health x this (1 + 0.15 a level; 1 when it is not worn).
func mount_hp_mult() -> float:
	return 1.0 + float(saddle_info("attach", "saddle").get("hp_per_level", 0.0)) * worn_level("saddle")


## The Saddlebags: the extra share of leaves kills drop (0.05 a level; 0 when they are not worn).
func leaf_bonus() -> float:
	return float(saddle_info("attach", "saddlebags").get("leaves_per_level", 0.0)) * worn_level("saddlebags")


var _bag_acc := 0.0                  # G4: the Saddlebags' fractions of a leaf, carried from kill to kill


## G4: the leaves a kill drops (n) with the Saddlebags: n x (1 + leaf_bonus()), the fractions added up from kill to kill,
## so the bonus pays on small kills too. n itself without the bags.
func saddlebag_leaves(n: int) -> int:
	var k := leaf_bonus()
	if n <= 0 or k <= 0.0:
		return n
	_bag_acc += float(n) * k
	var extra := int(floor(_bag_acc + 0.0001))
	_bag_acc = maxf(0.0, _bag_acc - float(extra))
	return n + extra


## The order the mount tries its ready skills in (balance.json mount_skills.priority, then any not listed).
func skill_priority() -> Array:
	var items := saddle_items("skills")
	var out: Array = []
	for id in (b.get("mount_skills", {}) as Dictionary).get("priority", []):
		if items.has(String(id)) and not out.has(String(id)):
			out.append(String(id))
	for id in items:
		if not out.has(String(id)):
			out.append(String(id))
	return out


## The shortest time between two of the mount's moves (saddlery.gap_s).
func saddle_gap() -> float:
	return float(saddlery_cfg().get("gap_s", 0.6))


# ---------------------------------------------------------------- 23 Nov 2026: the cat's outfits (the Tailor's Nook)
## The outfits, looks only: each is a whole hero model with the CatRanger skeleton and clips. "original" is always
## owned and the default. H5: they are content entries (content/outfits/<id>/entry.json: name, desc, icon, picture,
## model, price, unlock), read through scripts/shop_data.gd. A price in a currency the shops cannot take (a premium
## one, later, or amber) leaves the outfit unbuyable, never free.
const CAT_SKIN_DEFAULT := "original"


## The outfit ids in content/index.json's order (the Tailor's Nook shows them in this order), hidden ones left out.
func cat_skin_ids() -> Array:
	return ShopData.outfit_ids(CAT_SKIN_DEFAULT)


## Outfit id in the H4 shape ({"name", "short" (its desc), "price" (one amount, 0 when free), "currency", "model",
## "picture"}), {} for an unknown id. H5: a copy made from its content entry; to change what the game does, change
## the shared entry (Data.item("outfits", id)).
func cat_skin(id: String) -> Dictionary:
	return ShopData.outfit_view(id)


func cat_skin_name(id: String) -> String:
	return String(item("outfits", id).get("name", id))


## What outfit id costs: every amount its price names ({} when it is free).
func cat_skin_cost(id: String) -> Dictionary:
	return ShopData.outfit_cost(id)


## An outfit can be sold when its model is available and its price is in currencies the shops take.
func cat_skin_buyable(id: String) -> bool:
	return ShopData.outfit_price_ok(id) and (id == CAT_SKIN_DEFAULT or cat_skin_model(id) != "")


## H5: outfit id is owned (the v5 save's owned.outfits; the original always).
func cat_skin_owned(id: String) -> bool:
	return id == CAT_SKIN_DEFAULT or owned_level("outfits", id) >= 1


## Outfit id's hero model (a res:// .glb) when its file exists, else "" (the original look is used).
func cat_skin_model(id: String) -> String:
	if id == CAT_SKIN_DEFAULT:
		return ""
	return ShopData.outfit_model(id)


## Outfit id's tile picture (its entry's "picture": res://assets/ui/cat_skins/<id>.png); the tile uses it only when the
## file exists. "" for an unknown id.
func cat_skin_picture(id: String) -> String:
	return String(item("outfits", id).get("picture", ""))
