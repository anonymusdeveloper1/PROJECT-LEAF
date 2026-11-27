## H6 checks: `--autotest --workshop --foundation` (Stage 1: the converter and the frozen inputs, the Place and Undo commands,
## the enemy grid, zero-armour damage and the first ability) and `--autotest --workshop` (Stage 2, the live game: the
## Workshop, per-piece levels, specialisations, armour and save v6; run() below). The live run uses the real Build, Buy,
## Place, card and Confirm paths at the phone shape and takes the Workshop screenshots. Keep automatic saves held while a
## placement fixture is in use.
extends Node

const AutotestScript := preload("res://scripts/autotest.gd")
const MainScript := preload("res://scripts/main.gd")
const SaveUpgradeV6 := preload("res://core/save_upgrade_v6.gd")
const PlaceDefence := preload("res://commands/place_defence.gd")
const UndoPlaceDefence := preload("res://commands/undo_place_defence.gd")
const EnemyGrid := preload("res://core/enemy_grid.gd")
const Enemy := preload("res://scripts/enemy.gd")
const Ability := preload("res://abilities/ability.gd")
const ExplosiveAcorns := preload("res://abilities/explosive_acorns.gd")
const Buy := preload("res://commands/buy.gd")
const StatusPart := preload("res://parts/status.gd")

const H5_VERSION: int = 5
const H5_BEETLE: Dictionary = {"hp": 110.0, "shield_block": 0.7}
const FROZEN_V6: Dictionary = {
	"default_level": 1, "level_cap": {"barricade": 5, "tower": 5, "spikes": 5},
	"bag_kinds": ["tower", "spikes"], "row_kind": "barricade",
}
const V5_CAMP: Dictionary = {
	"save_v": H5_VERSION, "leaves": 410, "timber": 17, "shards": 2, "camp_level": 2,
	"stations": {"stall": 1}, "missions_done": ["embers", "bramble"],
	"owned": {"pets": {"sprig": {"level": 1}}}, "pet_level": 2,
	"future_field": {"keep": [true, "note"]},
	"def_levels": {"tower": 4, "barricade": 3, "spikes": 5},
	"items": {"tower": 2, "spikes": 0},
	"placed": [
		{"type": "tower", "x": -8.25, "z": 11.5, "rot": 0.4, "wreck": 0.35},
		{"type": "barricade", "slot": [0, 2], "row": 3, "wrecks": [-1.0, 0.0, 0.65], "wreck": 0.0},
		{"type": "barricade", "slot": [1, 2], "wreck": 0.4},
		{"type": "future_piece", "x": 3.5, "z": -6.0},
	],
}
const GRID_GROUP: StringName = &"workshop_grid_test"
const BURST_LEVEL: int = 1
const BURST_RADIUS_M: float = 1.2
const BURST_SHARE: float = 0.30

var t: AutotestScript
var main: MainScript


func run() -> bool:
	if not Data.args().has("--foundation"):
		return await _live()
	var ok: bool = _check_h5_boot()
	ok = _check_converter() and ok
	ok = _check_placement() and ok
	ok = _check_grid() and ok
	ok = _check_damage() and ok
	return _check_burst() and ok


# ---------------------------------------------------------------- the live v5 boot and the dormant v6 step
func _check_h5_boot() -> bool:
	# Stage 2: the switch is live. The v5 camp is converted by the real load path (SaveUpgrades.upgrade) and the live
	# boot is v6 with the Workshop window; the pure step (SaveUpgradeV6) is checked in _check_converter.
	var routed: Dictionary = SaveUpgrades.upgrade(V5_CAMP.duplicate(true))
	var step: Dictionary = SaveUpgradeV6.upgrade(V5_CAMP.duplicate(true))
	step["save_v"] = 6
	var ok: bool = t._expect("the live boot uses v6, converts a v5 camp through the loader and has the Workshop window",
		Save.save_v == 6 and SaveUpgrades.CURRENT_VERSION == 6 and _same(routed, step) and main.hud.windows.has("workshop"),
		{"save_v": Save.save_v, "current": SaveUpgrades.CURRENT_VERSION})
	if Data.args().has("--fresh"):
		var written: Dictionary = _dict(JSON.parse_string(FileAccess.get_file_as_string(Save.path)))
		ok = t._expect("the boot save writes the v6 defence fields and no def_levels",
			written.get("save_v") == 6 and not written.has("def_levels")
			and written.get("defence_reserves") is Dictionary and written.get("defence_legacy_credit") is Dictionary,
			{"save_v": written.get("save_v"), "fields": written.keys()}) and ok
	return ok


func _check_converter() -> bool:
	var cfg: Dictionary = _dict(_dict(Data.b.get("save_upgrades")).get("to_v6"))
	var frozen: Dictionary = {}
	for key: String in FROZEN_V6:
		frozen[key] = cfg.get(key)
	var ok: bool = t._expect("the v6 step keeps the frozen v5 level, cap and stock rules",
		_same(frozen, FROZEN_V6), {"to_v6": cfg})
	var input: Dictionary = _dict(JSON.parse_string(JSON.stringify(V5_CAMP)))
	var expected: Dictionary = V5_CAMP.duplicate(true)
	expected["placed"][0]["level"] = 4
	expected["placed"][1]["level"] = 3
	expected["placed"][2]["level"] = 3
	expected.erase("def_levels")
	expected["defence_reserves"] = {"tower": [{"level": 4}, {"level": 4}]}
	expected["defence_legacy_credit"] = {"spikes": 5}
	var converted: Dictionary = SaveUpgradeV6.upgrade(input)
	# A missing Workshop station gets its default when the save is loaded.
	if _dict(converted.get("stations")).has("workshop"):
		expected["stations"]["workshop"] = 0
	ok = t._expect("the v6 step keeps placed and held levels, row and tower wear, and unrelated v5 fields",
		_same(converted, expected), {"converted": converted}) and ok
	var again: Dictionary = SaveUpgradeV6.upgrade(converted.duplicate(true))
	ok = t._expect("a second v6 conversion leaves reserves and the unused credit intact",
		_same(again, converted), {"reserves": again.get("defence_reserves"),
			"credit": again.get("defence_legacy_credit")}) and ok

	var odd: Dictionary = SaveUpgradeV6.upgrade({
		"save_v": H5_VERSION, "def_levels": {"tower": 99, "spikes": "odd", "barricade": 4},
		"placed": [{"type": "tower", "x": 6.0, "z": 7.0}], "items": {"spikes": 1, "barricade": 2},
	})
	return t._expect("the v6 step clamps old levels and an obsolete Bag barricade cannot use a row credit",
		_same(odd.get("placed"), [{"type": "tower", "x": 6.0, "z": 7.0, "level": 5}])
		and _same(odd.get("defence_reserves"), {}) and _same(odd.get("defence_legacy_credit"), {"barricade": 4}),
		{"converted": odd}) and ok


# ---------------------------------------------------------------- Place and Undo through the commands
func _check_placement() -> bool:
	var held: bool = Save.hold_flush
	var items: Dictionary = Save.items
	var placed: Array = Save.placed
	var reserves: Dictionary = Save.defence_reserves
	Save.hold_flush = true
	Save.items = items.duplicate()
	Save.placed = placed.duplicate()
	Save.defence_reserves = reserves.duplicate(true)
	Save.items["tower"] = 2
	Save.defence_reserves.erase("tower")
	main.defences.start_placing("tower")
	var made: Array[int] = []
	var ok: bool = _place_pair(made)
	main.defences.stop_placing()
	for id: int in made:
		if not main.defences.piece_at(id).is_empty():
			main.defences.remove_placement(id)
	Save.items = items
	Save.placed = placed
	Save.defence_reserves = reserves
	Save.hold_flush = held
	return ok


func _place_pair(made: Array[int]) -> bool:
	var before: Array = Save.placed.duplicate()
	var first: PlaceDefence = _open_tower()
	if first == null or not first.run(main):
		return t._expect("Place commits a tower on a legal spot", false)
	made.append(first.placed_id)
	var record: Dictionary = _dict(Save.placed.back())
	var piece: Dictionary = main.defences.piece_at(first.placed_id)
	var ok: bool = t._expect("Place takes one tower and writes its v5 record and live piece together",
		Bag.count("tower") == 1 and Save.placed.size() == before.size() + 1 and not piece.is_empty()
		and is_same(piece.get("src"), record) and record.get("type") == "tower" and int(record.get("level", 0)) == 1
		and is_equal_approx(float(record.get("x", INF)), first.at.x)
		and is_equal_approx(float(record.get("z", INF)), first.at.z)
		and is_equal_approx(float(record.get("rot", INF)), first.yaw), {"record": record})
	var old: UndoPlaceDefence = UndoPlaceDefence.new(first.placed_id)
	var old_was_current: bool = old.can_run(main).is_empty()
	var after_first: Array = Save.placed.duplicate(true)

	var second: PlaceDefence = _open_tower()
	if second == null or not second.run(main):
		return t._expect("Place commits a second tower in the same visit", false)
	made.append(second.placed_id)
	var after_second: Array = Save.placed.duplicate(true)
	var stale_reason: String = old.can_run(main)
	var stale_ran: bool = old.run(main)
	ok = t._expect("a new placement makes the older receipt stale while both towers still stand",
		old_was_current and second.placed_id > first.placed_id and not stale_reason.is_empty() and not stale_ran
		and Bag.count("tower") == 0 and _same(Save.placed, after_second)
		and not main.defences.piece_at(first.placed_id).is_empty()
		and not main.defences.piece_at(second.placed_id).is_empty(), {"reason": stale_reason}) and ok

	var undo: UndoPlaceDefence = UndoPlaceDefence.new(second.placed_id)
	var undo_reason: String = undo.can_run(main)
	var undone: bool = undo.run(main)
	var duplicate_reason: String = undo.can_run(main)
	var duplicate_ran: bool = undo.run(main)
	return t._expect("Undo takes only the latest tower back and a duplicate returns nothing",
		undo_reason.is_empty() and undone and not duplicate_reason.is_empty() and not duplicate_ran
		and Bag.count("tower") == 1 and _same(Save.placed, after_first)
		and main.defences.piece_at(second.placed_id).is_empty()
		and not main.defences.piece_at(first.placed_id).is_empty(),
		{"undo": undo_reason, "duplicate": duplicate_reason, "held": Bag.count("tower")}) and ok


## Try points around the camp so the fixture uses the same placement rule as the ghost.
func _open_tower() -> PlaceDefence:
	for radius: float in [6.0, 8.0, 10.0, 12.0, 14.0]:
		for i: int in 16:
			var yaw: float = TAU * float(i) / 16.0
			var at: Vector3 = Vector3(sin(yaw), 0.0, cos(yaw)) * radius
			var command: PlaceDefence = PlaceDefence.new("tower", at, yaw)
			if command.can_run(main).is_empty():
				return command
	return null


# ---------------------------------------------------------------- grid membership and order in the same physics frame
func _check_grid() -> bool:
	var width: float = float(_dict(Data.b.get("enemy_grid")).get("cell_m", 0.0))
	if width <= 0.0:
		return t._expect("the enemy grid has a positive cell width in data", false)
	var grid: EnemyGrid = EnemyGrid.new()
	var first: Node3D = Node3D.new()
	var second: Node3D = Node3D.new()
	add_child(first)
	add_child(second)
	first.global_position = Vector3.RIGHT * width * 0.5
	second.global_position = Vector3.LEFT * width * 0.5
	first.add_to_group(GRID_GROUP)
	second.add_to_group(GRID_GROUP)
	grid.add(first)
	grid.add(second)
	var box: Vector2 = Vector2.ONE * width
	var initial: bool = grid.candidates(-box, box, GRID_GROUP) == [first, second]
	first.global_position = Vector3.LEFT * width * 3.0
	grid.move(first)
	var left_old_cell: bool = grid.candidates(-box, box, GRID_GROUP) == [second]
	var wide_order: bool = grid.candidates(Vector2(-width * 4.0, -width), box, GRID_GROUP) == [first, second]
	first.global_position = second.global_position
	grid.move(first)
	var same_cell_order: bool = grid.candidates(-box, box, GRID_GROUP) == [first, second]
	var ok: bool = t._expect("grid queries keep registration order across cell crossings and in the shared cell",
		initial and left_old_cell and wide_order and same_cell_order,
		{"initial": initial, "old cell": left_old_cell, "wide": wide_order, "shared": same_cell_order})

	second.remove_from_group(GRID_GROUP)
	var filtered: bool = grid.candidates(-box, box, GRID_GROUP) == [first]
	second.add_to_group(GRID_GROUP)
	grid.remove(first)
	var removed: bool = grid.candidates(-box, box, GRID_GROUP) == [second]
	second.free()
	var exited: bool = grid.candidates(-box, box, GRID_GROUP).is_empty()
	grid.add(first)
	grid.clear()
	var cleared: bool = grid.candidates(-box, box, GRID_GROUP).is_empty()
	first.free()
	return t._expect("grid queries follow live group membership, removal, tree exit and clear",
		filtered and removed and exited and cleared, {"group": filtered, "removed": removed,
			"tree exit": exited, "clear": cleared}) and ok


# ---------------------------------------------------------------- H5 damage and the first ability on the toolbox
func _check_damage() -> bool:
	var strength: float = 1.25
	var foe: Enemy = _spawn("beetle", Vector3.ZERO, strength, false)      # Stage 2: only an unarmoured tank is H5's
	var h5_max: float = float(H5_BEETLE["hp"]) * strength
	var hp: float = foe.hp
	var full: bool = is_equal_approx(hp, h5_max) and is_equal_approx(foe.max_hp, h5_max)
	var hit: float = h5_max * 0.1
	var taken: float = 0.25
	foe.bellowed(1.0, taken)
	var rear_damage: float = hit * (1.0 + taken)
	var shielded: float = rear_damage * (1.0 - float(H5_BEETLE["shield_block"]))
	# The shield faces +Z at yaw zero. A hit travelling toward -Z meets the shield.
	foe.rotation.y = 0.0
	foe.hit(Vector3.FORWARD, hit)
	var front: bool = _hit_matches(foe, hp, shielded)
	hp = foe.hp
	foe.hit(Vector3.BACK, hit)
	var rear: bool = _hit_matches(foe, hp, rear_damage)
	var ok: bool = t._expect("zero armour keeps H5 tank health, shield and Bellow damage",
		full and front and rear, {"full health": full, "front": front, "rear": rear})

	var damage_events: Array[float] = []
	var on_damage: Callable = func(target: Node, amount: float) -> void:
		if target == foe:
			damage_events.append(amount)
	Events.damage_dealt.connect(on_damage)
	hp = foe.hp
	foe._burn_hurt(hit)
	var burn: bool = is_equal_approx(hp - foe.hp, rear_damage) and damage_events.size() == 1 \
		and is_equal_approx(damage_events[0], rear_damage)
	hp = foe.hp
	foe.hurt_spikes(hit)
	var spikes: bool = is_equal_approx(hp - foe.hp, hit) and damage_events.size() == 1
	Events.damage_dealt.disconnect(on_damage)
	hp = foe.hp
	foe.heal_raw(hit)
	var heal: bool = is_equal_approx(foe.hp - hp, hit)
	foe.heal_raw(h5_max)
	var capped: bool = is_equal_approx(foe.hp, h5_max)
	foe.free()
	return t._expect("zero armour keeps H5 burn, quiet spike damage and healing",
		burn and spikes and heal and capped, {"burn": burn, "spikes": spikes, "heal": heal, "cap": capped}) and ok


func _check_burst() -> bool:
	var at: Vector3 = Vector3.ZERO
	var primary: Enemy = _spawn("thornling", at)
	var first: Enemy = _spawn("thornling", at + Vector3.RIGHT * BURST_RADIUS_M * 0.75)
	var second: Enemy = _spawn("thornling", at + Vector3.LEFT * BURST_RADIUS_M * 0.5)
	# This foe is outside the original blast, but a blast from the first neighbour would reach it.
	var outside: Enemy = _spawn("thornling", at)
	outside.global_position.x += BURST_RADIUS_M * 1.1 + outside.radius
	main.enemy_grid.move(outside)
	primary.hit(Vector3.FORWARD, primary.max_hp * 0.5)
	var hps: Array[float] = [primary.hp, first.hp, second.hp, outside.hp]
	var hits: Array[Node] = []
	var on_damage: Callable = func(target: Node, _amount: float) -> void: hits.append(target)
	Events.damage_dealt.connect(on_damage)
	var impact: Vector3 = at + Vector3.UP * primary.aim_height
	var damage: float = primary.last_raw * BURST_SHARE
	ExplosiveAcorns.burst(main, impact, primary, primary.last_raw, BURST_LEVEL)
	Events.damage_dealt.disconnect(on_damage)
	var each_once: bool = hits == [first, second] and _hit_matches(first, hps[1], damage) \
		and _hit_matches(second, hps[2], damage)
	var untouched: bool = is_equal_approx(primary.hp, hps[0]) and is_equal_approx(outside.hp, hps[3])
	var ok: bool = t._expect("ExplosiveAcorns uses the toolbox, hits each neighbour once and skips the primary and chain target",
		(ExplosiveAcorns as GDScript).get_base_script() == Ability and each_once and untouched,
		{"hits": hits.size(), "expected damage": damage, "first loss": hps[1] - first.hp,
			"second loss": hps[2] - second.hp, "outside loss": hps[3] - outside.hp})
	for foe: Enemy in [primary, first, second, outside]:
		foe.free()
	return ok


func _spawn(kind: String, at: Vector3, strength: float = 1.0, armoured: bool = false) -> Enemy:
	var foe: Enemy = Enemy.new()
	foe.main = main
	main.add_child(foe)
	foe.global_position = at
	main.enemy_grid.move(foe)                      # the grid cell follows the spot it was put at
	foe.setup(kind, 0, strength, armoured)
	foe.set_physics_process(false)
	return foe


static func _hit_matches(foe: Enemy, before_hp: float, damage: float) -> bool:
	return is_equal_approx(before_hp - foe.hp, damage) and is_equal_approx(foe.last_raw, damage) \
		and is_equal_approx(foe.last_dealt, damage)


static func _dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


## JSON normalises the integer and float representations of the same save value.
static func _same(a: Variant, b: Variant) -> bool:
	return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))


# ================================================================ the live run (H6 Stage 2)
const NO_SLOT := Vector2i(-1, -1)
const PHONE := Vector2i(480, 1040)
## The owner's price table (27 Nov 2026): a piece's upgrade to level 2..5. Level 4 is timber, never shards; level 5 is leaves only.
const TIERS: Dictionary = {
	"barricade": [{}, {"leaves": 200}, {"leaves": 480}, {"leaves": 1500, "timber": 20}, {"leaves": 3480}],
	"tower": [{}, {"leaves": 220}, {"leaves": 500}, {"leaves": 2400, "timber": 30}, {"leaves": 5760}],
	"spikes": [{}, {"leaves": 180}, {"leaves": 420}, {"leaves": 1200, "timber": 15}, {"leaves": 3060}],
}
const WORKSHOP_BUILD: Dictionary = {"leaves": 250, "timber": 10}
const WORKSHOP_LEVELS: Array = [{"leaves": 400, "timber": 20}, {"leaves": 900, "timber": 35}, {"leaves": 1800, "timber": 55}, {"leaves": 3200, "timber": 80}]
const WORKSHOP_HP: Array = [0.0, 200.0, 320.0, 480.0, 650.0, 850.0]
const WORKSHOP_AT := Vector3(13.5, 0.0, 4.8)
const WORKSHOP_FOOT := 2.13
const WORKSHOP_RING_M := 2.75
const SPEC_PRICES: Array = [{"leaves": 250, "timber": 10}, {"leaves": 550, "timber": 20}, {"leaves": 1100, "timber": 35}]
const SPEC_IDS: Array = ["explosive_acorns", "reinforced_barricades", "deep_thorns"]
const ARMOUR: Dictionary = {"brute": 0.20, "stump": 0.25, "snail": 0.30, "beetle": 0.35}
const NO_ARMOUR: Array = ["thornling", "chief", "raccoon", "boar", "bear", "moth", "frog", "owl", "pitcher", "mole", "puffball", "crow", "stag", "herald"]
const INDEX_DEFENCES: Array = ["tower", "spikes", "barricade"]
const INDEX_SPECS: Array = ["explosive_acorns", "reinforced_barricades", "deep_thorns"]
const RAW: float = 10.0


func _x(what: String, cond: bool, extra: Dictionary = {}) -> bool:
	return t._expect(what, cond, extra)


func _live() -> bool:
	main.player.invincible = true
	var size0: Vector2i = get_window().size
	get_window().size = PHONE
	await t._wait(0.6)
	var ok: bool = _check_boot()
	ok = _check_content() and ok
	ok = await _check_build() and ok
	ok = await _check_shop() and ok
	ok = await _check_place() and ok
	ok = await _check_taps() and ok
	ok = await _check_levels() and ok
	ok = await _check_repair() and ok
	ok = await _check_specs() and ok
	ok = await _check_armour() and ok
	ok = await _check_save() and ok
	get_window().size = size0
	main.closeup = Vector3.ZERO
	main.closeup_at = null
	main.hud.hide_card()
	return ok


# ---------------------------------------------------------------- small helpers
func _rich() -> void:
	Save.leaves = 1000000
	Save.timber = 5000
	Save.camp_level = maxi(Save.camp_level, 3)


## A bare camp: no piece, no row, nothing placed, nothing held, nothing owed, no wave.
func _bare_camp() -> void:
	var d = main.defences
	d.stop_placing()
	d._clear()
	Save.placed = []
	Save.items = {}
	Save.defence_reserves = {}
	Save.defence_legacy_credit = {}
	main.fight.active = false
	main.fight.in_wave = false
	main.hud.hide_card()


## Takes every held tower and patch out of the Bag.
func _drain(kind: String) -> void:
	while Bag.count(kind) > 0:
		Bag.take_defence(kind, false)
	Save.defence_reserves.erase(kind)


## A piece through the real record path (a Save.placed record, then the live piece), like a load does.
func _put(kind: String, at: Vector3, level: int = 1, wear: float = -1.0) -> Dictionary:
	var rec: Dictionary = {"type": kind, "x": at.x, "z": at.z, "rot": 0.0, "level": level}
	if wear >= 0.0:
		rec["wreck"] = wear
	Save.placed.append(rec)
	return main.defences.spawn_placement(rec)


## An open spot of the camp, the n-th one found (so two pieces never share it).
func _spot(kind: String, n: int = 0) -> Vector3:
	var found: int = 0
	for radius: float in [6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0]:
		for i: int in 24:
			var yaw: float = TAU * float(i) / 24.0
			var at: Vector3 = Vector3(sin(yaw), 0.0, cos(yaw)) * radius
			if main.defences._valid(at, kind):
				if found == n:
					return at
				found += 1
	return Vector3(1.0e9, 0.0, 0.0)


func _tank_entry(kind: String) -> Dictionary:
	return _dict(JSON.parse_string(FileAccess.get_file_as_string("res://content/enemies/%s/entry.json" % kind)))


func _cost_eq(a: Variant, b: Dictionary) -> bool:
	return _same(a, b)


## The money left after `fn` ran, as {leaves, timber} spent.
func _spent(before_leaves: int, before_timber: int) -> Dictionary:
	var out: Dictionary = {}
	if before_leaves - Save.leaves != 0:
		out["leaves"] = before_leaves - Save.leaves
	if before_timber - Save.timber != 0:
		out["timber"] = before_timber - Save.timber
	return out


# ---------------------------------------------------------------- the boot
func _check_boot() -> bool:
	Save.save_game(true)
	var written: Dictionary = _dict(JSON.parse_string(FileAccess.get_file_as_string(Save.path)))
	return _x("the live game is v6: its save has the Workshop, the reserves and the credit and no def_levels, and the Workshop has its window",
		Save.save_v == 6 and SaveUpgrades.CURRENT_VERSION == 6 and int(written.get("save_v", 0)) == 6 and not written.has("def_levels")
		and written.get("defence_reserves") is Dictionary and written.get("defence_legacy_credit") is Dictionary
		and (written.get("stations") as Dictionary).has("workshop") and main.hud.windows.has("workshop"),
		{"fields": written.keys()})


# ---------------------------------------------------------------- the content (indexed folders, prices, models, armour)
func _check_content() -> bool:
	var index: Dictionary = _dict(_dict(JSON.parse_string(FileAccess.get_file_as_string("res://content/index.json"))).get("kinds"))
	var ok: bool = _x("the index lists the defences, the specialisations and the Workshop (after the Tailor's Nook) in order",
		index.get("defences") == INDEX_DEFENCES and index.get("specialisations") == INDEX_SPECS
		and (index.get("buildings", []) as Array).back() == "workshop" and (index.get("buildings", []) as Array)[-2] == "tailor", {"kinds": index.keys()})
	var bad: Array = []
	for kind: String in INDEX_DEFENCES:
		var entry: Dictionary = Data.defence_info(kind)
		var levels: Array = entry.get("levels", [])
		if levels.size() != 5 or String(entry.get("id", "")) != kind or String(entry.get("name", "")) == "":
			bad.append(kind + " shape")
			continue
		for lv: int in range(1, 6):
			var tier: Dictionary = levels[lv - 1]
			if not Props.has(String(tier.get("model", ""))):
				bad.append("%s %d model" % [kind, lv])
			if lv >= 2 and not _cost_eq(Data.defence_level_info(kind, lv).get("price", {}), TIERS[kind][lv - 1]):
				bad.append("%s %d price" % [kind, lv])
			if lv == 1 and not (tier.get("price", {}) as Dictionary).is_empty():
				bad.append("%s 1 price" % kind)
			if (Data.defence_level_info(kind, lv).get("price", {}) as Dictionary).has("shards"):
				bad.append("%s %d shards" % [kind, lv])
		if not bool(levels[4].get("needs_burrows", false)) or bool(levels[3].get("needs_burrows", false)):
			bad.append(kind + " burrows gate")
		if kind != "barricade" and not (entry.get("icon", "") is String and main.hud._icon_known(String(entry["icon"]))):
			bad.append(kind + " icon")
	ok = _x("each defence has five tiers with a model, the owner's price (level 4 timber, level 5 leaves only, never shards) and the Burrows gate on 5",
		bad.is_empty(), {"bad": bad}) and ok
	var spec_bad: Array = []
	for sid: String in SPEC_IDS:
		var e: Dictionary = Data.specialisation_info(sid)
		if e.is_empty() or bool(e.get("hidden", false)):
			spec_bad.append(sid + " hidden or missing")
			continue
		var ups: Array = e.get("upgrades", [])
		if not _cost_eq(e.get("price", {}), SPEC_PRICES[0]) or ups.size() != 2 or not _cost_eq(ups[0], SPEC_PRICES[1]) or not _cost_eq(ups[1], SPEC_PRICES[2]):
			spec_bad.append(sid + " price")
		if not main.hud._icon_known(String(e.get("icon", ""))):
			spec_bad.append(sid + " icon")
	ok = _x("the three specialisations are shown (not hidden) and cost 250/10, 550/20, 1,100/35", spec_bad.is_empty(), {"bad": spec_bad}) and ok
	var w: Dictionary = Data.building("workshop")
	var hp: Array = []
	var level_prices: Array = []
	for lv: int in range(1, 6):
		hp.append(Data.building_hp("workshop", lv))
		if lv >= 2:
			level_prices.append(Data.level_price("workshop", lv))
	var picture: String = Data.building_picture("workshop")
	var layout: Dictionary = _dict(w.get("layout"))
	ok = _x("the Defence Workshop: 250 leaves and 10 timber after Mission 2, four paid levels, health 200 to 850, its picture, model and layout",
		String(w.get("name", "")) == "Defence Workshop" and _cost_eq(Data.build_price("workshop"), WORKSHOP_BUILD)
		and int(_dict(w.get("unlock")).get("missions_won", 0)) == 2 and _same(level_prices, WORKSHOP_LEVELS)
		and _same(hp, WORKSHOP_HP.slice(1)) and picture != "" and load(picture) is Texture2D and String(w.get("model", "")) == "defence_workshop"
		and Props.has("defence_workshop") and _same(layout.get("position"), [13.5, 0.0, 4.8])
		and is_equal_approx(float(layout.get("foot_radius", 0.0)), WORKSHOP_FOOT) and _same(layout.get("ring_offset"), [0.0, 0.0, 2.75]),
		{"prices": level_prices, "hp": hp, "picture": picture}) and ok
	var armour_bad: Array = []
	for kind: String in ARMOUR:
		var share: float = float(_dict(_dict(_tank_entry(kind).get("parts")).get("armour")).get("share", -1.0))
		if not is_equal_approx(share, float(ARMOUR[kind])):
			armour_bad.append([kind, share])
	for kind: String in NO_ARMOUR:
		if not _dict(_tank_entry(kind).get("parts")).is_empty() and _dict(_tank_entry(kind).get("parts")).has("armour"):
			armour_bad.append([kind, "has armour"])
	ok = _x("armour is on the four tank kinds only: Brute 20%, Stump Golem 25%, Crystal Snail 30%, Beetle Knight 35%", armour_bad.is_empty(), {"bad": armour_bad}) and ok
	var squad_bad: Array = []
	for sid: String in index.get("squads", []):
		var entry: Dictionary = _dict(JSON.parse_string(FileAccess.get_file_as_string("res://content/squads/%s/entry.json" % sid)))
		if String(entry.get("id", "")) != sid:
			squad_bad.append(sid)
	ok = _x("every indexed squad folder reads and names its own id, and every indexed enemy is known", squad_bad.is_empty()
		and (index.get("enemies", []) as Array).all(func(k: Variant) -> bool: return Data.enemy_has(String(k))), {"bad": squad_bad}) and ok
	return ok


# ---------------------------------------------------------------- Build and the shop
func _check_build() -> bool:
	var st = main.stations
	var menu = main.hud.windows["build"]
	_bare_camp()
	Save.stations["workshop"] = 0
	Save.ruined = []
	Save.fire_ruined = false
	t._veteran(1)
	_rich()
	Save.camp_level = 1
	st.refresh("all")
	main.hud.refresh()
	var locked: Dictionary = {}
	for e: Dictionary in menu.entries():
		if String(e["id"]) == "workshop":
			locked = e
	var ok: bool = _x("Mission 1: the Workshop is locked in the build menu (it needs two missions) and builds nothing",
		String(locked.get("state", "")) == "locked" and String(locked.get("needs", "")) == Data.word("needs_missions") % 2, {"entry": locked})
	var l0: int = Save.leaves
	st._build_station("workshop")
	ok = _x("a Mission 1 build is refused and charges nothing", int(Save.stations["workshop"]) == 0 and Save.leaves == l0) and ok
	ok = _x("no tower can be bought before the Workshop stands", Buy.new("defences", "tower").can_run(main) != "") and ok

	t._veteran(2)
	_rich()
	Save.camp_level = 1
	Save.timber = 50
	Save.leaves = 1000
	st.refresh("all")
	main.hud.refresh()
	main.fight.active = true
	main.fight.in_wave = true
	st._build_station("workshop")
	ok = _x("during a wave the Workshop does not build and nothing is paid", int(Save.stations["workshop"]) == 0 and Save.leaves == 1000 and Save.timber == 50) and ok
	main.fight.active = false
	main.fight.in_wave = false
	Save.fire_ruined = true
	st._build_station("workshop")
	ok = _x("with the campfire out it does not build either", int(Save.stations["workshop"]) == 0 and Save.leaves == 1000) and ok
	Save.fire_ruined = false

	var built: String = await t._build_from_menu("workshop")
	await t._wait(1.8)
	ok = _x("Mission 2: the build menu builds the Workshop for 250 leaves and 10 timber exactly, at level 1",
		built == "workshop" and int(Save.stations["workshop"]) == 1 and Save.leaves == 1000 - 250 and Save.timber == 50 - 10,
		{"built": built, "leaves": Save.leaves, "timber": Save.timber}) and ok
	var l1: int = Save.leaves
	var t1: int = Save.timber
	st._build_station("workshop")
	ok = _x("a second Build charges nothing (no double charge) and the level stays 1", Save.leaves == l1 and Save.timber == t1 and int(Save.stations["workshop"]) == 1) and ok

	# the place it stands on: the full footprint, its ring, a walk to it, the finished model
	var w = main.world
	var pos: Vector3 = w.station_pos("workshop")
	var ring: Vector3 = w.spot_ring("workshop")
	var node: Node3D = st.nodes.get("workshop")
	ok = _x("the Workshop stands on its spot at its full footprint with its ring 2.75 m in front, and the model is the Defence Workshop",
		pos.distance_to(WORKSHOP_AT) < 0.01 and is_equal_approx(st.foot("workshop"), WORKSHOP_FOOT)
		and ring.distance_to(pos + Vector3(0, 0, WORKSHOP_RING_M)) < 0.05 and node != null and node.visible
		and st.model_name("workshop") == "defence_workshop" and w.in_village(pos, 0.0) and w.in_village(pos + Vector3(WORKSHOP_FOOT * 0.8, 0, 0), 0.0),
		{"pos": pos, "ring": ring}) and ok
	var scale_a: Vector3 = node.scale if node != null else Vector3.ZERO
	await t._wait(0.4)
	ok = _x("after its rise the model rests at its own size", node != null and node.scale.is_equal_approx(scale_a) and node.scale.y > 0.2) and ok
	main.player.global_position = Vector3(0.0, 0.0, 1.6)
	main.snap_camera()
	await t._wait(0.3)
	var reached: bool = await t._go_to(ring, 0.5, 30.0)
	await t._wait(0.3)
	ok = _x("the cat can walk to the Workshop's ring from the fire and stand in it", reached and st.rings["workshop"].contains(main.player.global_position),
		{"cat": main.player.global_position, "ring": ring}) and ok
	main.hud.hide_card()
	main.closeup_at = node
	main.closeup = Vector3(2.0, 2.4, 5.2)
	await t._wait(0.5)
	await t._shot("workshop_in_camp")
	main.closeup = Vector3.ZERO
	main.closeup_at = null

	# its card: both tabs
	await t._at_ring(st.rings["workshop"])
	await t._wait(0.5)
	var win = main.hud.windows["workshop"]
	ok = _x("a tap on the Workshop opens its card on the Defences tab with two tabs", main.hud.card_ring() == st.rings["workshop"] and win.tab_ids() == ["defences", "specialisations"]
		and win.tab == "defences", {"title": main.hud.card_title()}) and ok
	await t._shot("workshop_tab_defences")
	win.select("specialisations")
	await t._wait(0.4)
	ok = _x("the Specialisations tab shows what is open now (Reinforced barricades after Mission 1, Explosive acorns after Mission 2, not Deep thorns)",
		_ids(win.tab_spec("specialisations")["rows"]) == ["explosive_acorns", "reinforced_barricades"] or _ids(win.tab_spec("specialisations")["rows"]) == ["reinforced_barricades", "explosive_acorns"],
		{"rows": _ids(win.tab_spec("specialisations")["rows"])}) and ok
	await t._shot("workshop_tab_specialisations")
	win.select("defences")
	main.hud.hide_card()

	# standing or in ruins: the refusals, then the building's own repair
	Save.ruined.append("workshop")
	ok = _x("a ruined Workshop sells nothing, upgrades nothing and says so", st.workshop_reason() != "" and Buy.new("defences", "tower").can_run(main) != ""
		and Buy.new("specialisations", "reinforced_barricades", 1, 1).can_run(main) != "" and st.workshop_upgrade_reason(1) != ""
		and d_piece_cap("tower") == 0, {"reason": st.workshop_reason()}) and ok
	Save.ruined = []
	st.ruin("workshop")
	st.refresh("all")
	await t._at_ring(st.rings["workshop"])
	await t._wait(0.5)
	await t._shot("workshop_ruin_card")
	var l2: int = Save.leaves
	var pressed: bool = t._press("Repair")
	await t._wait(0.6)
	ok = _x("a fallen Workshop is repaired from its card (the building's own rule) and then serves again", pressed and not Save.ruined.has("workshop")
		and Save.leaves < l2 and st.workshop_reason() == "", {"ruined": Save.ruined}) and ok
	main.hud.hide_card()
	main.fight.active = true
	main.fight.in_wave = true
	ok = _x("in a wave the Workshop says Between waves and sells nothing", st.workshop_reason() == Data.word("workshop_wave")
		and Buy.new("defences", "tower").can_run(main) != "") and ok
	main.fight.active = false
	main.fight.in_wave = false
	return ok


func d_piece_cap(kind: String) -> int:
	return int(main.defences.piece_cap(kind))


func _ids(rows: Array) -> Array:
	return rows.map(func(r: Variant) -> String: return String((r as Dictionary).get("id", "")))


func _check_shop() -> bool:
	var st = main.stations
	var d = main.defences
	var win = main.hud.windows["workshop"]
	_bare_camp()
	t._veteran(2)
	_rich()
	Save.camp_level = 1
	st.refresh("all")
	main.hud.refresh()
	var tower_row: Callable = func() -> Dictionary:
		for r: Dictionary in win.tab_spec("defences")["rows"]:
			if String(r.get("id", "")) == "tower":
				return r
		return {}
	var spikes_row: Callable = func() -> Dictionary:
		for r: Dictionary in win.tab_spec("defences")["rows"]:
			if String(r.get("id", "")) == "spikes":
				return r
		return {}
	var ok: bool = _x("Mission 2: Thorn Spikes are not sold yet (a locked row with no price) and cannot be bought", Buy.new("defences", "spikes").can_run(main) != ""
		and String((spikes_row.call() as Dictionary).get("label", "x")) == "", {"row": spikes_row.call()})
	var cap: int = int(d.tower_cap())
	var l0: int = Save.leaves
	var t0: int = Save.timber
	ok = _x("buying a tower takes exactly its price (90 leaves) and puts one fresh level-1 tower in the Bag", Buy.new("defences", "tower").price() == {"leaves": 90}
		and st._buy_piece("tower") and Bag.count("tower") == 1 and l0 - Save.leaves == 90 and t0 == Save.timber and Bag.best_held_level("tower") == 1,
		{"leaves": [l0, Save.leaves]}) and ok
	var note: String = String((tower_row.call() as Dictionary).get("text", ""))
	ok = _x("the row counts the Bag, the placed ones, the total and the limit", note.contains(Data.word("workshop_count_tower") % [1, int(d.placed_count("tower")), 1 + int(d.placed_count("tower")), cap]), {"note": note, "cap": cap}) and ok
	while Bag.count("tower") + int(d.placed_count("tower")) < cap:
		st._buy_piece("tower")
	var l1: int = Save.leaves
	var refused: bool = not st._buy_piece("tower")
	ok = _x("at the tower limit (%d for this Hearthtree) a purchase spends nothing and adds nothing" % cap, refused and Save.leaves == l1 and Bag.count("tower") + int(d.placed_count("tower")) == cap,
		{"held": Bag.count("tower"), "reason": Buy.new("defences", "tower").can_run(main)}) and ok
	# the placed ones count towards the limit as well
	var spot: Vector3 = _spot("tower", 0)
	var id: int = int(d.commit_placement("tower", spot, 0.0)) if spot.x < 1.0e8 else -1
	ok = _x("a placed tower still counts towards the limit: held plus placed stays at the cap", id >= 0 and Bag.count("tower") + int(d.placed_count("tower")) == cap
		and not st._buy_piece("tower"), {"held": Bag.count("tower"), "placed": d.placed_count("tower")}) and ok
	d.stop_placing()

	# a full Bag: refused before paying, for a patch after Mission 3
	t._veteran(3)
	_rich()
	st.refresh("all")
	main.hud.refresh()
	_drain("tower")
	ok = _x("Mission 3 opens Thorn Spikes: a priced row with a Buy", Buy.new("defences", "spikes").can_run(main) == ""
		and String((spikes_row.call() as Dictionary).get("label", "")) == Data.word("buy")) and ok
	Save.bag = {}
	Bag.add("berries", Bag.room_for("berries"))
	var l2: int = Save.leaves
	ok = _x("a full Bag refuses a patch and charges nothing", Bag.room_for("spikes") == 0 and not st._buy_piece("spikes") and Save.leaves == l2) and ok
	var noted: String = String((spikes_row.call() as Dictionary).get("text", ""))
	ok = _x("the row says Bag full", noted.contains(Data.word("bag_full")), {"note": noted}) and ok
	Save.bag = {}
	var l3: int = Save.leaves
	ok = _x("with room again a patch is bought for its price", st._buy_piece("spikes") and Bag.count("spikes") == 1 and l3 - Save.leaves == int(Data.defence_info("spikes")["piece"])) and ok
	_drain("spikes")

	# a stale call buys nothing
	var spec_rows: Array = win.tab_spec("specialisations")["rows"]
	ok = _x("Mission 3 adds Deep thorns to the Specialisations tab", _ids(spec_rows).has("deep_thorns") and _ids(spec_rows).size() == 3, {"ids": _ids(spec_rows)}) and ok
	var l4: int = Save.leaves
	var stale: bool = st.buy_specialisation("reinforced_barricades", 2) or st.buy_specialisation("not_a_specialisation", 1)
	ok = _x("a stale or unknown Learn spends nothing and learns nothing", not stale and Save.leaves == l4 and Data.specialisation_level("reinforced_barricades") == 0) and ok
	return ok


# ---------------------------------------------------------------- Place, Done and the last-placement Undo
func _check_place() -> bool:
	var d = main.defences
	var hud = main.hud
	_bare_camp()
	t._veteran(3)
	_rich()
	_drain("tower")
	Bag.return_defence("tower", {"level": 3, "wreck": 0.25}, false)
	Bag.return_defence("tower", {"level": 2}, false)
	var ok: bool = _x("a paid level 3 tower and a level 2 one are held, the best held level is 3", Bag.count("tower") == 2 and Bag.best_held_level("tower") == 3,
		{"reserves": Save.defence_reserves})
	var spot: Vector3 = _spot("tower", 0)
	if spot.x > 1.0e8:
		return _x("an open spot for a placement test exists", false) and ok
	main.player.global_position = spot - Vector3(0, 0, 1.6)
	main.player.facing = 0.0
	main.snap_camera()
	d.start_placing("tower")
	await t._wait(0.4)
	ok = _x("Place mode shows the ghost of the paid level, the Place, Done buttons and no Undo yet", d.placing == "tower" and d.ghost != null and d.ghost_ok
		and hud.p_actions.place_button.visible and hud.p_actions.done_button.visible and not d.can_undo_place(), {"placing": d.placing}) and ok
	await t._shot("workshop_place_ghost")
	var p0: int = Save.placed.size()
	hud.p_actions.place_button.pressed.emit()
	await t._wait(0.5)
	var rec: Dictionary = _dict(Save.placed.back()) if Save.placed.size() > p0 else {}
	var first_id: int = -1
	for p: Dictionary in d.pieces:
		if is_same(p.get("src"), rec):
			first_id = int(p["id"])
	var piece: Dictionary = d.piece_at(first_id)
	ok = _x("Place puts the paid level 3 tower down with its saved record (level and wear) and the live piece agrees",
		Save.placed.size() == p0 + 1 and int(rec.get("level", 0)) == 3 and is_equal_approx(float(rec.get("wreck", -1.0)), 0.25)
		and not piece.is_empty() and d.piece_level(piece) == 3 and Bag.count("tower") == 1, {"record": rec}) and ok
	var file_rec: Array = _dict(JSON.parse_string(FileAccess.get_file_as_string(Save.path))).get("placed", [])
	ok = _x("the placement was saved at once (the file holds the record)", file_rec.size() == Save.placed.size() and _same(file_rec.back(), rec)) and ok
	await t._wait(0.3)
	ok = _x("after a placement the Undo button shows and Undo is available", d.can_undo_place() and hud.p_actions.undo_button.visible) and ok
	await t._shot("workshop_place_undo")
	hud.p_actions.undo_button.pressed.emit()
	await t._wait(0.4)
	ok = _x("Undo takes the tower back at its own level and wear, the record goes, the Bag holds it again",
		d.piece_at(first_id).is_empty() and Save.placed.size() == p0 and Bag.count("tower") == 2 and Bag.best_held_level("tower") == 3
		and not d.can_undo_place() and not d.undo_place(), {"held": Bag.count("tower")}) and ok
	# the same piece placed again, then a second one: the older receipt is stale, only the last can be undone
	hud.p_actions.place_button.pressed.emit()
	await t._wait(0.3)
	var second: Vector3 = _spot("tower", 3)
	main.player.global_position = second - Vector3(0, 0, 1.6)
	await t._wait(0.3)
	hud.p_actions.place_button.pressed.emit()
	await t._wait(0.3)
	ok = _x("after the last piece in the Bag the visit stays (Done, no ghost) and the last one can still be undone", Bag.count("tower") == 0 and d.placing == "tower"
		and d.ghost == null and d.can_undo_place() and hud.p_actions.done_button.visible, {"placing": d.placing}) and ok
	# a full Bag on return
	Save.bag = {}
	Bag.add("berries", Bag.room_for("berries"))
	var held_before: int = Bag.used_slots()
	hud.p_actions.undo_button.pressed.emit()
	await t._wait(0.3)
	ok = _x("a full Bag still takes the undone piece back (forced), once, and the ghost returns", Bag.count("tower") == 1 and Bag.used_slots() > Bag.slots()
		and held_before >= Bag.slots() and d.ghost != null and not d.undo_place(), {"used": Bag.used_slots(), "slots": Bag.slots()}) and ok
	Save.bag = {}
	# Done closes the visit: nothing can be undone afterwards
	hud.p_actions.place_button.pressed.emit()
	await t._wait(0.3)
	var can_before: bool = d.can_undo_place()
	hud.p_actions.done_button.pressed.emit()
	await t._wait(0.3)
	ok = _x("Done ends the visit: no ghost, no placing, and the last placement can no longer be undone", can_before and d.placing == "" and d.ghost == null
		and not d.can_undo_place() and not hud.p_actions.undo_button.visible) and ok
	d.stop_placing()
	return ok


# ---------------------------------------------------------------- taps on pieces (the real touch path)
func _screen(world: Vector3) -> Vector2:
	return main.cam.unproject_position(world)


func _check_taps() -> bool:
	var d = main.defences
	var hud = main.hud
	_bare_camp()
	t._veteran(3)
	_rich()
	Save.camp_level = 3
	main.stations.refresh("all")
	var spot_t: Vector3 = _spot("tower", 0)
	var spot_s: Vector3 = _spot("tower", 6)
	var tower: Dictionary = _put("tower", spot_t, 1)
	var patch: Dictionary = _put("spikes", spot_s, 1)
	var pad: Vector2i = t.build_any_row()
	var row: Dictionary = d.row_at(pad.x, pad.y)
	var ok: bool = _x("a tower, a patch and a row stand for the tap checks", not tower.is_empty() and not patch.is_empty() and not row.is_empty())
	if not ok:
		return false
	var tm: Node = d.piece_marker("tower", int(tower["id"]), NO_SLOT)
	var sm: Node = d.piece_marker("spikes", int(patch["id"]), NO_SLOT)
	var rm: Node = d.piece_marker("barricade", -1, pad)
	ok = _x("each piece has a marker with its own key", tm != null and sm != null and rm != null and String(tm.key) == "tower_%d" % int(tower["id"])
		and String(sm.key) == "spikes_%d" % int(patch["id"]) and String(rm.key) == "road_%d_%d" % [pad.x, pad.y]) and ok
	if tm == null or sm == null or rm == null:
		return false
	# a healthy tower, from beside it
	main.player.global_position = spot_t + Vector3(1.4, 0, 0)
	main.snap_camera()
	await t._wait(0.4)
	hud.hide_card()
	var shown: bool = await t._tap(tm)
	await t._until(func() -> bool: return hud.card_ring() == tm, 2.0)
	ok = _x("a real tap on a healthy tower opens its card (its title, its level, an Upgrade, no Repair)", shown and hud.card_ring() == tm
		and hud.card_title() == String(Data.defence_info("tower")["name"]) and hud.p_card.footer_button(Data.word("upgrade")) != null
		and not bool(main.defences.repair_quote("tower", int(tower["id"]), NO_SLOT)["show"]), {"shown": shown, "ring": hud.card_ring() == tm, "title": hud.card_title(), "up": hud.p_card.footer_button(Data.word("upgrade")) != null}) and ok
	await t._shot("workshop_piece_card")
	hud.hide_card()
	# the patch
	main.player.global_position = spot_s + Vector3(1.4, 0, 0)
	main.snap_camera()
	await t._wait(0.4)
	shown = await t._tap(sm)
	await t._until(func() -> bool: return hud.card_ring() == sm, 2.0)
	ok = _x("a tap on a patch opens its card (never a Repair)", shown and hud.card_ring() == sm and not bool(d.repair_quote("spikes", int(patch["id"]), NO_SLOT)["show"])) and ok
	hud.hide_card()
	# either end of a row
	var pieces: Array = row["pieces"]
	main.player.global_position = (row["root"] as Node3D).global_position + Vector3(0, 0, 1.6)
	main.snap_camera()
	await t._wait(0.4)
	var both: bool = true
	for end: int in [0, pieces.size() - 1]:
		hud.hide_card()
		var at: Vector3 = (pieces[end]["pos"] as Vector3) + Vector3(0, 0.35, 0)
		var sp: Vector2 = _screen(at)
		await t._tap_at(sp)
		await t._until(func() -> bool: return hud.card_ring() == rm, 1.5)
		both = both and hud.card_ring() == rm
	ok = _x("a tap on either end of a row opens the row's card", both) and ok
	hud.hide_card()
	# the downed tower: its badge, and a tap opens the Repair card
	d.hurt_piece(int(tower["id"]), 999999)
	await t._wait(0.3)
	ok = _x("a downed tower shows the repair badge", tm.visible and String(tm.icon) == "repair" and bool(d.repair_quote("tower", int(tower["id"]), NO_SLOT)["show"])) and ok
	main.player.global_position = spot_t + Vector3(1.4, 0, 0)
	main.snap_camera()
	await t._wait(0.3)
	shown = await t._tap(tm)
	await t._until(func() -> bool: return hud.card_ring() == tm, 2.0)
	ok = _x("a tap on the downed tower opens a card with Repair", hud.card_ring() == tm and _has_button("Repair")) and ok
	hud.hide_card()
	d.repair_placed("tower", int(tower["id"]), NO_SLOT)
	# bare ground, a HUD-origin touch, a drag
	var ground: Vector3 = spot_t + Vector3(-4.0, 0, 3.0)
	await t._tap_at(_screen(ground))
	await t._wait(0.2)
	ok = _x("a tap on bare ground opens no card", not hud.card_open() or hud.card_ring() == null) and ok
	hud.hide_card()
	var before_ring: Node = hud.card_ring()
	await t._tap_at(hud.bag_button.get_global_rect().get_center())
	await t._wait(0.3)
	ok = _x("a touch that starts on a HUD button does not reach a piece under it", hud.card_ring() != tm and hud.card_ring() != sm and hud.card_ring() != rm, {"before": before_ring}) and ok
	hud.hide_card()
	var start: Vector2 = _screen(spot_t + Vector3(0, 0.3, 0))
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.position = get_viewport().get_final_transform() * start
	down.pressed = true
	Input.parse_input_event(down)
	await get_tree().process_frame
	for k: int in 6:
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = down.position + Vector2(18.0 * float(k + 1), 0.0)
		drag.relative = Vector2(18.0, 0.0)
		Input.parse_input_event(drag)
		await get_tree().process_frame
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.position = down.position + Vector2(108.0, 0.0)
	up.pressed = false
	Input.parse_input_event(up)
	await t._wait(0.3)
	ok = _x("a drag that starts on a piece steers the cat and opens no card", hud.card_ring() != tm) and ok
	hud.hide_card()
	# an active ghost: pieces do not open
	Bag.return_defence("tower", {"level": 1}, false)
	main.player.global_position = spot_t + Vector3(1.4, 0, 0)
	d.start_placing("tower")
	await t._wait(0.3)
	await t._tap_at(_screen(spot_t + Vector3(0, 0.3, 0)))
	await t._wait(0.3)
	ok = _x("while the ghost is out a tap on a piece opens no card", d.placing == "tower" and hud.card_ring() != tm) and ok
	d.stop_placing()
	hud.hide_card()
	_drain("tower")
	# walking to a marker from a distance, then the card opens by itself
	main.player.global_position = spot_t + Vector3(9.0, 0, 0)
	main.snap_camera()
	await t._wait(0.4)
	await t._tap(tm)
	var walked: bool = await t._until(func() -> bool: return hud.card_ring() == tm, 20.0)
	ok = _x("a tap from far away walks the cat to the piece and its card opens", walked and hud.card_ring() == tm) and ok
	hud.hide_card()
	# a neighbouring building still opens with today's rule
	var ring = main.stations.rings["workshop"]
	main.player.global_position = ring.global_position + Vector3(0, 0, 1.0)
	main.snap_camera()
	await t._wait(0.4)
	await t._tap(ring)
	await t._until(func() -> bool: return hud.card_ring() == ring, 2.0)
	ok = _x("a tap on the Workshop building itself opens the Workshop's card", hud.card_ring() == ring) and ok
	hud.hide_card()
	return ok


# ---------------------------------------------------------------- upgrades, levels, gates and the confirm
func _check_levels() -> bool:
	var d = main.defences
	var st = main.stations
	var hud = main.hud
	_bare_camp()
	t._veteran(3)
	_rich()
	Save.camp_level = 3
	Save.stations["workshop"] = 3
	st.refresh("all")
	var a: Dictionary = _put("tower", _spot("tower", 0), 1)
	var b: Dictionary = _put("tower", _spot("tower", 2), 1)
	var sa: Dictionary = _put("spikes", _spot("spikes", 4), 1)
	var sb: Dictionary = _put("spikes", _spot("spikes", 7), 1)
	var r1: Vector2i = t.build_any_row()
	var r2: Vector2i = t.build_any_row()
	var ra: Dictionary = d.row_at(r1.x, r1.y)
	var rb: Dictionary = d.row_at(r2.x, r2.y)
	var ok: bool = _x("two of each kind stand at level 1", not a.is_empty() and not b.is_empty() and not sa.is_empty() and not sb.is_empty() and not ra.is_empty() and not rb.is_empty()
		and r1 != r2)
	if not ok:
		return false
	# the card path once: marker -> card -> Upgrade -> the confirm -> Confirm (and Cancel), with a worn tower
	d._wreck(a, 0.4)
	d._save_wrecks()
	var am: Node = d.piece_marker("tower", int(a["id"]), NO_SLOT)
	await t._at_ring(am)
	await t._wait(0.4)
	var up: Button = hud.p_card.footer_button(Data.word("upgrade"))
	ok = _x("the worn tower's card offers Upgrade (no Repair: it is only worn)", up != null and not up.disabled and not bool(d.repair_quote("tower", int(a["id"]), NO_SLOT)["show"])) and ok
	up.pressed.emit()
	await t._wait(0.4)
	ok = _x("Upgrade opens the confirm with the price and what the next level gives", hud.card_ring() == hud.confirm and hud.card_title().contains("2")) and ok
	await t._shot("workshop_confirm")
	var cancel: Button = hud.p_card.footer_button(Data.word("cancel"))
	if cancel != null:
		cancel.pressed.emit()
	await t._wait(0.4)
	ok = _x("Cancel goes back to the piece's card and spends nothing", hud.card_ring() == am and d.piece_level(a) == 1) and ok
	Save.leaves = 50
	hud.p_card.footer_button(Data.word("upgrade")).pressed.emit()
	await t._wait(0.4)
	var ok_btn: Button = hud.p_card.footer_button(Data.word("confirm"))
	ok = _x("an unaffordable Confirm is grey", ok_btn != null and ok_btn.disabled) and ok
	_rich()
	hud.refresh_card()
	await t._wait(0.3)
	ok_btn = hud.p_card.footer_button(Data.word("confirm"))
	var l0: int = Save.leaves
	var t0: int = Save.timber
	ok_btn.pressed.emit()
	await t._wait(0.5)
	var rec_a: Dictionary = _dict(a.get("src"))
	ok = _x("Confirm upgrades this one tower: level 2, whole, its wear cleared in the piece and in the saved record, 220 leaves paid",
		d.piece_level(a) == 2 and float(a["hp"]) >= float(a["max_hp"]) - 0.01 and not a["wrecked"] and not rec_a.has("wreck") and int(rec_a.get("level", 0)) == 2
		and _cost_eq(_spent(l0, t0), TIERS["tower"][1]), {"spent": _spent(l0, t0), "record": rec_a}) and ok
	hud.hide_card()
	# the same piece compared with its untouched twin
	var tower_a = a["node"]
	var tower_b = b["node"]
	var sa_stats: Dictionary = d.level_stats("tower", 2)
	var sb_stats: Dictionary = d.level_stats("tower", 1)
	ok = _x("the upgraded tower has more health, a faster cadence, a longer range, a better arrow and its own model than its twin",
		float(a["max_hp"]) > float(b["max_hp"]) and is_equal_approx(float(a["max_hp"]), float(sa_stats["hp"])) and is_equal_approx(float(b["max_hp"]), float(sb_stats["hp"]))
		and float(sa_stats["every"]) < float(sb_stats["every"]) and float(sa_stats["range"]) > float(sb_stats["range"]) and float(sa_stats["damage"]) > float(sb_stats["damage"])
		and int(tower_a.level) == 2 and int(tower_b.level) == 1 and String(tower_a.name).begins_with("acorn_tower_2") and not String(tower_b.name).begins_with("acorn_tower_2"),
		{"a": sa_stats, "b": sb_stats, "na": String(tower_a.name), "nb": String(tower_b.name), "la": tower_a.level, "lb": tower_b.level}) and ok
	# a patch
	var sa_before: float = float(d.slow_at((sa["pos"] as Vector3)))
	l0 = Save.leaves
	ok = _x("a patch upgrades alone for 180 leaves: stronger slow and damage than its twin, its own model",
		d.upgrade_placed("spikes", int(sa["id"]), NO_SLOT, 1) and d.piece_level(sa) == 2 and d.piece_level(sb) == 1 and _cost_eq(_spent(l0, Save.timber), {"leaves": 180})
		and float(d.slow_at(sa["pos"])) > float(d.slow_at(sb["pos"])) and sa_before < float(d.slow_at(sa["pos"]))
		and float(d.level_stats("spikes", 2)["dps"]) > float(d.level_stats("spikes", 1)["dps"]) and String((sa["node"] as Node3D).name).begins_with("thorn_spikes_2")
		and not String((sb["node"] as Node3D).name).begins_with("thorn_spikes_2"), {"sa": String((sa["node"] as Node3D).name), "sb": String((sb["node"] as Node3D).name), "slow": [d.slow_at(sa["pos"]), d.slow_at(sb["pos"]), sa_before], "lv": [d.piece_level(sa), d.piece_level(sb)]}) and ok
	# a row with a broken section: the whole row mends, the saved wrecks clear
	var pcs: Array = ra["pieces"]
	d.hurt_piece(int(pcs[0]["id"]), 999999)
	d.hurt_piece(int(pcs[1]["id"]), int(float(pcs[1]["max_hp"]) * 0.7))
	d._wreck(pcs[0], 0.0)
	d._wreck(pcs[1], 0.3)
	d._save_wrecks()
	var rec_row: Dictionary = _dict(ra.get("src"))
	var had_wrecks: bool = rec_row.has("wrecks") or rec_row.has("wreck")
	l0 = Save.leaves
	var before_hp: float = float(pcs[2]["max_hp"])
	ok = _x("a row with a broken section upgrades for 200 leaves: every section is whole at the new health, the wrecks clear, its twin stays level 1",
		had_wrecks and d.upgrade_placed("barricade", -1, r1, 1) and d.row_level(ra) == 2 and d.row_level(rb) == 1
		and pcs.all(func(p: Dictionary) -> bool: return float(p["hp"]) >= float(p["max_hp"]) - 0.01 and not p["wrecked"] and not p["broken"] and d.piece_level(p) == 2)
		and float(pcs[2]["max_hp"]) > before_hp and not rec_row.has("wrecks") and not rec_row.has("wreck") and int(rec_row.get("level", 0)) == 2
		and _cost_eq(_spent(l0, Save.timber), {"leaves": 200}) and not d.row_broken(ra), {"record": rec_row}) and ok
	ok = _x("the twin row is untouched (health and level 1 for all its sections)", (rb["pieces"] as Array).all(func(p: Dictionary) -> bool: return d.piece_level(p) == 1)
		and is_equal_approx(float((rb["pieces"] as Array)[0]["max_hp"]), float(d.level_stats("barricade", 1)["hp"]))) and ok
	# stale, missing and money-short targets spend nothing
	l0 = Save.leaves
	var stale: bool = d.upgrade_placed("tower", int(a["id"]), NO_SLOT, 1)
	var gone: bool = d.upgrade_placed("tower", 999999, NO_SLOT, 1)
	var reason_stale: String = String(d.upgrade_quote("tower", int(a["id"]), NO_SLOT, 1)["reason"])
	ok = _x("an upgrade for a level that has changed, or for a piece that is gone, spends nothing and says why", not stale and not gone and Save.leaves == l0
		and reason_stale == Data.word("upgrade_stale") and String(d.upgrade_quote("tower", 999999, NO_SLOT, 1)["reason"]) == Data.word("upgrade_gone"),
		{"stale": reason_stale}) and ok
	Save.leaves = 10
	ok = _x("a quote never gives money as a reason, and a purchase without the money fails whole", String(d.upgrade_quote("tower", int(b["id"]), NO_SLOT, 1)["reason"]) == ""
		and not d.upgrade_placed("tower", int(b["id"]), NO_SLOT, 1) and d.piece_level(b) == 1 and Save.leaves == 10) and ok
	_rich()
	# the gates: the Workshop's own level, then the raids, then the Burrows
	Save.stations["workshop"] = 2
	var q3: Dictionary = d.upgrade_quote("tower", int(a["id"]), NO_SLOT, 2)
	ok = _x("a level-2 Workshop caps pieces at 2: level 3 says Needs Workshop lv 3", d.piece_cap("tower") == 2 and String(q3["reason"]) == Data.word("upgrade_cap") % 3 and not d.upgrade_placed("tower", int(a["id"]), NO_SLOT, 2),
		{"q": q3}) and ok
	Save.stations["workshop"] = 4
	var saved_missions: Array = Save.missions_done.duplicate()
	var left_missions: Array = []
	for i: int in Data.mission_count():
		left_missions.append(String(Data.mission(i)["id"]))
	Save.missions_done = left_missions.slice(0, Data.mission_count() - 1)
	d.upgrade_placed("tower", int(a["id"]), NO_SLOT, 2)
	var q4: Dictionary = d.upgrade_quote("tower", int(a["id"]), NO_SLOT, 3)
	ok = _x("level 4 needs every Raid Mission won even with a level-4 Workshop: capped at 3 with the raids word", not Data.raids_open() and d.piece_cap("tower") == 3
		and int(q4["next_level"]) == 4 and String(q4["reason"]) == Data.word("needs_raids") and not d.upgrade_placed("tower", int(a["id"]), NO_SLOT, 3), {"q": q4}) and ok
	Save.missions_done = left_missions
	main.raids.refresh_open()
	l0 = Save.leaves
	t0 = Save.timber
	var s0: int = Save.shards
	ok = _x("with every raid won level 4 is allowed: timber, no shards (tower 2,400 leaves and 30 timber), per piece", Data.raids_open() and d.piece_cap("tower") == 4
		and d.upgrade_placed("tower", int(a["id"]), NO_SLOT, 3) and d.piece_level(a) == 4 and _cost_eq(_spent(l0, t0), TIERS["tower"][3]) and Save.shards == s0,
		{"spent": _spent(l0, t0)}) and ok
	Save.stations["workshop"] = 5
	var q5: Dictionary = d.upgrade_quote("tower", int(a["id"]), NO_SLOT, 4)
	ok = _x("level 5 needs the Burrows even with a level-5 Workshop", not Data.burrows_open() and d.piece_cap("tower") == 4 and int(q5["next_level"]) == 5
		and String(q5["reason"]) != "" and String(q5["reason"]) != Data.word("upgrade_cap") % 5 and not d.upgrade_placed("tower", int(a["id"]), NO_SLOT, 4), {"q": q5}) and ok
	main.burrows.open_hollow(false)
	main.raids.refresh_open()
	var quote5: Dictionary = d.upgrade_quote("tower", int(a["id"]), NO_SLOT, 4)
	l0 = Save.leaves
	t0 = Save.timber
	ok = _x("with the Burrows open the level-5 quote and price are leaves only (5,760) and it upgrades", Data.burrows_open() and d.piece_cap("tower") == 5 and String(quote5["reason"]) == ""
		and _cost_eq(quote5["price"], {"leaves": 5760}) and d.upgrade_placed("tower", int(a["id"]), NO_SLOT, 4) and d.piece_level(a) == 5 and Save.leaves == l0 - 5760 and Save.timber == t0
		and String(tower_node_name(a)).begins_with("acorn_tower_5")) and ok
	ok = _x("a level-5 piece has no next upgrade (Max level)", int(d.upgrade_quote("tower", int(a["id"]), NO_SLOT, 5)["next_level"]) == 0) and ok
	# the Workshop's cap preview and its own upgrade confirm
	Save.stations["workshop"] = 1
	Save.camp_level = 3
	st.refresh("all")
	var win = main.hud.windows["workshop"]
	await t._at_ring(st.rings["workshop"])
	await t._wait(0.4)
	win.ask_upgrade()
	await t._wait(0.4)
	ok = _x("the Workshop's own Upgrade opens a confirm that lists what level 2 gives and Confirm raises it", hud.card_ring() == hud.confirm) and ok
	await t._shot("workshop_upgrade_confirm")
	var confirm_btn: Button = hud.p_card.footer_button(Data.word("confirm"))
	if confirm_btn != null:
		confirm_btn.pressed.emit()
	await t._wait(0.5)
	ok = _x("Confirm raises the Workshop to level 2, and the card returns to the tab it came from", Data.station_level("workshop") == 2 and win.tab == "defences") and ok
	hud.hide_card()
	return ok


func tower_node_name(p: Dictionary) -> String:
	return String((p["node"] as Node3D).name)


func _has_button(label: String) -> bool:
	for b in main.hud.card_buttons():
		if String(b.get_meta("label", "")) == label and not b.disabled:
			return true
	return false


# ---------------------------------------------------------------- repair, the Well, the Hearthtree's goals and raid weights
func _check_repair() -> bool:
	var d = main.defences
	var st = main.stations
	var rd = main.raids
	var hud = main.hud
	_bare_camp()
	t._veteran(3)
	_rich()
	Save.camp_level = 3
	Save.stations["workshop"] = 3
	Save.ruined = []
	st.refresh("all")
	var tw: Dictionary = _put("tower", _spot("tower", 0), 2)
	var pad: Vector2i = t.build_any_row()
	var row: Dictionary = d.row_at(pad.x, pad.y)
	var ok: bool = _x("a level-2 tower and a row stand", not tw.is_empty() and not row.is_empty())
	if not ok:
		return false
	var id: int = int(tw["id"])
	# a worn but standing tower has no Repair (the Well mends it); a downed one has, at the mend price
	d._wreck(tw, 0.5)
	d._save_wrecks()
	var q_worn: Dictionary = d.repair_quote("tower", id, NO_SLOT)
	var l0: int = Save.leaves
	ok = _x("a worn, standing tower shows no Repair and Repair spends nothing", not bool(q_worn["show"]) and not d.repair_placed("tower", id, NO_SLOT) and Save.leaves == l0, {"q": q_worn}) and ok
	for i: int in 140:
		d.well_mend(0.1, 0.05, 1.0)
	ok = _x("the Wishing Well mends the standing wear on its own, to full", not tw["wrecked"] and float(tw["hp"]) >= float(tw["max_hp"]) - 0.01) and ok
	d.hurt_piece(id, 999999)
	await t._wait(0.2)
	var q_down: Dictionary = d.repair_quote("tower", id, NO_SLOT)
	var want: int = int(d.mend_price(tw))
	ok = _x("a downed tower shows Repair at the mend price", bool(q_down["show"]) and String(q_down["reason"]) == "" and int((q_down["price"] as Dictionary).get("leaves", 0)) == want and want > 0, {"q": q_down}) and ok
	for i: int in 40:
		d.well_mend(0.1, 0.05, 1.0)
	ok = _x("the Well never lifts a downed tower", float(tw["hp"]) <= 0.0) and ok
	# a wave: a row repairs, a tower waits
	main.fight.active = true
	main.fight.in_wave = true
	var q_wave: Dictionary = d.repair_quote("tower", id, NO_SLOT)
	ok = _x("in a wave a downed tower cannot be repaired", not d.repair_placed("tower", id, NO_SLOT) and (String(q_wave["reason"]) != "" or not bool(q_wave["show"])), {"q": q_wave}) and ok
	var pcs: Array = row["pieces"]
	d.hurt_piece(int(pcs[0]["id"]), 999999)
	d.hurt_piece(int(pcs[1]["id"]), int(float(pcs[1]["max_hp"]) * 0.7))
	var rq: Dictionary = d.repair_quote("barricade", -1, pad)
	l0 = Save.leaves
	ok = _x("in a wave a row with a broken section shows Repair and repairs for its own price", bool(rq["show"]) and d.repair_placed("barricade", -1, pad)
		and Save.leaves < l0 and not d.row_broken(row) and pcs.all(func(p: Dictionary) -> bool: return float(p["hp"]) >= float(p["max_hp"]) - 0.01), {"q": rq}) and ok
	d.hurt_piece(int(pcs[1]["id"]), int(float(pcs[1]["max_hp"]) * 0.6))
	ok = _x("a row that is only cracked shows no Repair (the Well mends it)", not bool(d.repair_quote("barricade", -1, pad)["show"])) and ok
	main.fight.active = false
	main.fight.in_wave = false
	l0 = Save.leaves
	ok = _x("between waves the downed tower repairs for the mend price and stands whole", d.repair_placed("tower", id, NO_SLOT) and l0 - Save.leaves == want
		and float(tw["hp"]) >= float(tw["max_hp"]) - 0.01) and ok
	# the Hearthtree's Mend all: buildings only, defences never in its price
	d.hurt_piece(id, 999999)
	d._wreck(pcs[2], 0.3)
	Save.wear["stall"] = 0.5
	st.refresh()
	var cc: Dictionary = rd.camp_check()
	var wrecks: int = (cc["items"] as Array).filter(func(i: Dictionary) -> bool: return String(i["kind"]) == "wreck").size()
	var pay_kinds: Array = (cc["pay"] as Array).map(func(i: Dictionary) -> String: return String(i["kind"]))
	ok = _x("the camp check counts broken defences in its items but never in what Mend all and Mend some pay", wrecks >= 1 and not pay_kinds.has("wreck") and pay_kinds.has("wear"),
		{"pay": pay_kinds, "wrecks": wrecks}) and ok
	rd.mend_all()
	await t._wait(0.4)
	ok = _x("Mend all mends the building and leaves the downed tower for its own card", not Save.wear.has("stall") and float(tw["hp"]) <= 0.0) and ok
	d.repair_placed("tower", id, NO_SLOT)
	# raid weights read the pieces as before: a lane's guard is its barricade health plus a fixed bonus per tower in reach
	var cfg: Dictionary = Data.gr()["lane_guard"]
	var lane: int = pad.x
	var expect: float = 0.0
	var mid: Vector3 = main.world.trail_point(lane, 0.5 * main.world.trail_length(lane))
	for p: Dictionary in d.pieces:
		if float(p["hp"]) <= 0.0:
			continue
		if p["type"] == "barricade" and int((p["slot"] as Array)[0]) == lane:
			expect += float(p["hp"])
		elif p["type"] == "tower" and (p["pos"] as Vector3).distance_to(mid) <= float(Data.defence_level_info("tower", d.piece_level(p)).get("range", 5.0)) + float(cfg["tower_reach_bonus"]):
			expect += float(cfg["tower"])
	ok = _x("the lane guard (a raid weight) is the pieces' health and towers' bonus as before, with mixed levels", is_equal_approx(float(d.lane_guard(lane)), expect), {"got": d.lane_guard(lane), "want": expect}) and ok

	# the Hearthtree's goals read the saved pieces' own levels
	var two: Dictionary = Data._goal({"type": "towers", "level": 3, "count": 2})
	_bare_camp()
	var t1: Dictionary = _put("tower", _spot("tower", 0), 3)
	var t2: Dictionary = _put("tower", _spot("tower", 3), 3)
	d.hurt_piece(int(t2["id"]), 999999)
	var after: Dictionary = Data._goal({"type": "towers", "level": 3, "count": 2})
	var kinds_goal: Dictionary = Data._goal({"type": "defence", "id": "barricade", "level": 2})
	_bare_camp()
	var row_pad: Vector2i = t.build_any_row()
	var rec_row: Dictionary = Save.placed.back()
	var low: Dictionary = Data._goal({"type": "defence", "id": "barricade", "level": 2})
	rec_row["level"] = 3
	var high: Dictionary = Data._goal({"type": "defence", "id": "barricade", "level": 2})
	ok = _x("a towers goal counts saved tower records at the level (a downed one too) and a defence goal reads the best record",
		not bool(two["done"]) and bool(after["done"]) and not bool(kinds_goal["done"]) and not bool(low["done"]) and bool(high["done"]), {"after": after.get("progress"), "low": low.get("progress")}) and ok
	# the real Show and Go routes the Hearthtree's window takes
	var win = hud.windows["shop"]
	_bare_camp()
	Save.stations["workshop"] = 0
	st.refresh("all")
	var g_tower: Dictionary = {"type": "towers", "level": 1, "count": 1, "need": 1}
	var g_bar: Dictionary = {"type": "defence", "id": "barricade", "level": 1}
	var t_build: Dictionary = win._defence_goal_target("tower", g_tower)
	var t_pad: Dictionary = win._defence_goal_target("barricade", g_bar)
	Save.stations["workshop"] = 3
	st.refresh("all")
	var t_shop: Dictionary = win._defence_goal_target("tower", g_tower)
	Bag.return_defence("tower", {"level": 1}, false)
	var t_bag: Dictionary = win._defence_goal_target("tower", g_tower)
	_drain("tower")
	var placed_t: Dictionary = _put("tower", _spot("tower", 0), 1)
	var g_lv3: Dictionary = {"type": "towers", "level": 3, "count": 1, "need": 1}
	Save.stations["workshop"] = 2
	var t_wk: Dictionary = win._defence_goal_target("tower", g_lv3)
	Save.stations["workshop"] = 5
	var t_piece: Dictionary = win._defence_goal_target("tower", g_lv3)
	var marker_want: Node = d.goal_marker("tower", 3)
	ok = _x("a tower goal with no Workshop built leads to the build menu at the Workshop", t_build.get("build") == "workshop", {"t": t_build.keys()}) and ok
	ok = _x("a barricade goal with no row leads to the nearest open empty pad", t_pad.has("ring") and t_pad["ring"] == d.empty_pad_marker(), {"t": t_pad.keys()}) and ok
	ok = _x("a tower goal with the Workshop built and nothing held leads to the Workshop; a held tower leads to the Bag", t_shop.get("workshop") == true and t_bag.get("bag") == "tower", {"shop": t_shop.keys(), "bag": t_bag.keys()}) and ok
	ok = _x("a level goal beyond the Workshop's level leads to the Workshop, and to the piece below it once the Workshop is high enough", (t_wk.get("workshop") == true or placed_t.is_empty())
		and t_piece.has("ring") and t_piece["ring"] == marker_want and marker_want != null, {"wk": t_wk.keys(), "piece": t_piece.keys()}) and ok
	_drain("tower")
	Save.stations["workshop"] = 3
	return ok


# ---------------------------------------------------------------- the three specialisations
func _check_specs() -> bool:
	var d = main.defences
	var st = main.stations
	_bare_camp()
	t._veteran(3)
	_rich()
	Save.camp_level = 3
	Save.stations["workshop"] = 3
	st.refresh("all")
	var win = main.hud.windows["workshop"]
	var ok: bool = true
	# learning each once, then to level 3, prices and stale buys
	for sid: String in SPEC_IDS:
		var wrong_stale: bool = st.buy_specialisation(sid, 2)
		var price_ok: bool = true
		for lv: int in [1, 2, 3]:
			var buy := Buy.new("specialisations", sid, 1, lv)
			price_ok = price_ok and buy.next_level() == lv and _cost_eq(buy.price(), SPEC_PRICES[lv - 1]) and buy.can_run(main) == ""
			var l0: int = Save.leaves
			var t0: int = Save.timber
			var bought: bool = st.buy_specialisation(sid, lv)
			price_ok = price_ok and bought and Data.specialisation_level(sid) == lv and _cost_eq(_spent(l0, t0), SPEC_PRICES[lv - 1])
			var l1: int = Save.leaves
			var again: bool = st.buy_specialisation(sid, lv)
			price_ok = price_ok and not again and Save.leaves == l1
		ok = _x("%s: a stale Learn buys nothing; learned then raised to 3 at 250/10, 550/20, 1,100/35; a repeat buy spends nothing; there is no level 4" % sid,
			not wrong_stale and price_ok and Data.specialisation_level(sid) == 3 and not st.buy_specialisation(sid, 4)) and ok
	await t._shot("workshop_specialisations_learned")
	# explosive acorns: each other foe in the blast once, the primary skipped, no chain
	var tun: Dictionary = _dict(Data.b["specialisations"]["explosive_acorns"])
	var shares: Array = tun["share"]
	var radius: float = float(tun["radius_m"])
	var blast_ok: bool = true
	for lv: int in [1, 2, 3]:
		var at: Vector3 = Vector3(0, 0, -20)
		var primary: Enemy = _spawn("thornling", at, 1.0)
		var near_a: Enemy = _spawn("thornling", at + Vector3.RIGHT * radius * 0.6, 1.0)
		var near_b: Enemy = _spawn("thornling", at + Vector3.LEFT * radius * 0.4, 1.0)
		var far: Enemy = _spawn("thornling", at + Vector3.RIGHT * (radius * 1.6), 1.0)
		for e: Enemy in [primary, near_a, near_b, far]:
			e.hp = 1000.0
			e.max_hp = 1000.0
		var hits: Array[Node] = []
		var on_damage: Callable = func(target: Node, _amount: float) -> void: hits.append(target)
		Events.damage_dealt.connect(on_damage)
		ExplosiveAcorns.burst(main, at + Vector3.UP * primary.aim_height, primary, 100.0, lv)
		Events.damage_dealt.disconnect(on_damage)
		var share: float = float(shares[lv - 1])
		blast_ok = blast_ok and hits.size() == 2 and hits.has(near_a) and hits.has(near_b) and not hits.has(primary) and not hits.has(far) \
			and is_equal_approx(1000.0 - near_a.hp, 100.0 * share) and is_equal_approx(1000.0 - near_b.hp, 100.0 * share) \
			and is_equal_approx(primary.hp, 1000.0) and is_equal_approx(far.hp, 1000.0)
		for e: Enemy in [primary, near_a, near_b, far]:
			e.free()
	ok = _x("Explosive acorns at levels 1 to 3: a 1.2 m blast of 30, 45 and 60% of the hit reaches every other foe once, skips the primary and the foe outside, and never chains", blast_ok) and ok
	# a real tower shot: the blast shows only when it is learned
	var tw: Dictionary = _put("tower", Vector3(0, 0, 12), 1)
	var tnode = tw["node"]
	var primary2: Enemy = main.fight.spawn("thornling", Vector3(0, 0, 12) + Vector3(0, 0, 3.0), 0) as Enemy
	var neighbour: Enemy = main.fight.spawn("thornling", Vector3(0.6, 0, 15.0), 0) as Enemy
	for e: Enemy in [primary2, neighbour]:
		e.set_physics_process(false)
		e.hp = 100000.0
		e.max_hp = 100000.0
	var shot: bool = await t._until(func() -> bool: return neighbour.hp < 100000.0 or primary2.hp < 100000.0 and tnode.shots > 1, 3.0)
	var spent_neighbour: bool = neighbour.hp < 100000.0
	ok = _x("a real tower's acorn with Explosive acorns learned also hurts the foe beside the one it hit", shot and primary2.hp < 100000.0 and spent_neighbour,
		{"primary": primary2.hp, "neighbour": neighbour.hp}) and ok
	primary2.queue_free()
	neighbour.queue_free()
	d.remove_placement(int(tw["id"]))
	Save.placed = []
	# reinforced barricades: health, crack threshold, the model's rows
	var pad: Vector2i = t.build_any_row()
	var row: Dictionary = d.row_at(pad.x, pad.y)
	var base_hp: float = float(Data.defence_level_info("barricade", 1)["hp"])
	var bonus: Array = Data.b["specialisations"]["reinforced_barricades"]["hp_bonus"]
	var crack: float = float(Data.b["specialisations"]["reinforced_barricades"]["crack_at"])
	var sec: Dictionary = (row["pieces"] as Array)[0]
	ok = _x("Reinforced barricades at level 3 gives every section +55% health", is_equal_approx(float(sec["max_hp"]), base_hp * (1.0 + float(bonus[2]))), {"max": sec["max_hp"], "base": base_hp}) and ok
	sec["hp"] = float(sec["max_hp"]) * (crack + 0.05)
	var whole_above: bool = d.piece_stage(sec) == "whole"
	sec["hp"] = float(sec["max_hp"]) * (crack - 0.05)
	var cracked_below: bool = d.piece_stage(sec) == "cracked"
	sec["hp"] = 0.0
	var broken_at_zero: bool = d.piece_stage(sec) == "broken"
	ok = _x("a section cracks at 35% (not 50%) and still breaks at 0", whole_above and cracked_below and broken_at_zero) and ok
	sec["hp"] = float(sec["max_hp"])
	# deep thorns: the strongest overlapping patch, +50% slow, and the linger of one second
	var spot: Vector3 = _spot("spikes", 5)
	var low: Dictionary = _put("spikes", spot, 1)
	var high: Dictionary = _put("spikes", spot + Vector3(0.5, 0, 0), 3)
	var mult: float = float(Data.b["specialisations"]["deep_thorns"]["slow_mult"][2])
	var slow3: float = float(Data.defence_level_info("spikes", 3)["slow"])
	var at_both: float = float(d.slow_at(spot + Vector3(0.25, 0, 0)))
	ok = _x("Deep thorns at level 3: where two patches overlap the strongest one counts, and its slow is 50% stronger", not low.is_empty() and not high.is_empty()
		and is_equal_approx(at_both, slow3 * mult) and is_equal_approx(float(d.level_stats("spikes", 3)["slow"]), slow3 * mult), {"slow": at_both, "want": slow3 * mult}) and ok
	var part = StatusPart.new()
	var linger: float = float(Data.b["specialisations"]["deep_thorns"]["linger_s"])
	var carry: float = part.step_thorn_slow(0.4, 0.1, linger)
	var half: float = part.step_thorn_slow(0.0, 0.5, linger)
	var paused: float = part.step_thorn_slow(0.0, 0.0, linger)
	var gone: float = part.step_thorn_slow(0.0, 0.6, linger)
	ok = _x("the slow lasts one second after the foe steps off, holds while the game is paused (no time passes) and then ends", is_equal_approx(carry, 0.4) and is_equal_approx(half, 0.4)
		and is_equal_approx(paused, 0.4) and is_equal_approx(gone, 0.0), {"half": half, "paused": paused, "gone": gone}) and ok
	var no_linger: float = part.step_thorn_slow(0.0, 0.1, 0.0)
	ok = _x("with no linger (not learned) it is H5's: the slow ends the moment the foe leaves the patch", is_equal_approx(no_linger, 0.0)) and ok
	part.free()
	var foe: Enemy = _spawn("thornling", Vector3(0, 0, -25), 1.0)
	ok = _x("a foe's own linger follows what is learned (1 s)", is_equal_approx(float(foe._thorn_linger()), linger)) and ok
	foe.free()
	return ok


# ---------------------------------------------------------------- armour on the four tanks
func _check_armour() -> bool:
	var ok: bool = true
	var deaths: Array[String] = []
	var on_death: Callable = func(kind: String, _at: Vector3) -> void: deaths.append(kind)
	Events.enemy_died.connect(on_death)
	for kind: String in ARMOUR:
		var share: float = float(ARMOUR[kind])
		var plain: Enemy = _spawn(kind, Vector3(0, 0, -30), 1.0, false)
		var tough: Enemy = _spawn(kind, Vector3(4, 0, -30), 1.0, true)
		var health_ok: bool = is_equal_approx(tough.max_hp, plain.max_hp * (1.0 - share))
		# one ordinary hit from behind (outside every shield): raw is kept, dealt is after armour, kill time is H5's
		plain.rotation.y = 0.0
		tough.rotation.y = 0.0
		plain.hit(Vector3.BACK, RAW)
		tough.hit(Vector3.BACK, RAW)
		var hit_ok: bool = is_equal_approx(tough.last_raw, RAW) and is_equal_approx(tough.last_dealt, RAW * (1.0 - share)) and is_equal_approx(plain.last_dealt, RAW) \
			and is_equal_approx(tough.max_hp / tough.last_dealt, plain.max_hp / plain.last_dealt)
		# a burn tick, a spike tick, a heal
		var h0: float = tough.hp
		tough._burn_hurt(RAW)
		var burn_ok: bool = is_equal_approx(h0 - tough.hp, RAW * (1.0 - share))
		h0 = tough.hp
		tough.hurt_spikes(RAW)
		var spike_ok: bool = is_equal_approx(h0 - tough.hp, RAW * (1.0 - share))
		h0 = tough.hp
		tough.heal_raw(RAW)
		var heal_ok: bool = is_equal_approx(tough.hp - h0, RAW * (1.0 - share))
		var side_ok: bool = true
		if kind == "beetle":
			var block: float = float(_tank_entry("beetle")["parts"]["status"]["shield_block"])
			tough.rotation.y = 0.0
			tough.hit(Vector3.FORWARD, RAW)
			var front_dealt: float = tough.last_dealt
			tough.hit(Vector3.RIGHT, RAW)
			side_ok = is_equal_approx(front_dealt, RAW * (1.0 - block) * (1.0 - share)) and is_equal_approx(tough.last_dealt, RAW * (1.0 - share)) and is_equal_approx(tough.last_raw, RAW)
		# one death and one reward, through the real spawn path
		var real = main.fight.spawn(kind, Vector3(8, 0, -30), 0)
		var one_death: bool = false
		if real != null and is_instance_valid(real):
			(real as Node3D).set_physics_process(false)
			var armoured_ok: bool = is_equal_approx((real as Enemy).max_hp, plain.max_hp * float(main.fight.strength()) * (1.0 - share))
			var count0: int = deaths.size()
			(real as Enemy).hit(Vector3.BACK, (real as Enemy).hp * 10.0 + 100.0)
			await t._wait(0.15)
			one_death = armoured_ok and deaths.size() - count0 == 1 and deaths.back() == kind
		ok = _x("%s: %d%% armour: health and hits scale together (same kill time), raw and dealt are kept apart, burn, spikes and heals follow, and it dies once" % [kind, int(share * 100.0)],
			health_ok and hit_ok and burn_ok and spike_ok and heal_ok and side_ok and one_death,
			{"health": health_ok, "hit": hit_ok, "burn": burn_ok, "spikes": spike_ok, "heal": heal_ok, "side": side_ok, "death": one_death, "real": real != null, "deaths": deaths}) and ok
		plain.free()
		tough.free()
	Events.enemy_died.disconnect(on_death)
	# a Gloomtouched (stronger) tank keeps the same share of its scaled health
	var strong: Enemy = _spawn("stump", Vector3(0, 0, -30), 1.5, true)
	var strong_plain: Enemy = _spawn("stump", Vector3(4, 0, -30), 1.5, false)
	ok = _x("a stronger (Gloomtouched) tank is scaled first and armoured after: its health is the unarmoured scaled health times the armour factor",
		is_equal_approx(strong.max_hp, strong_plain.max_hp * (1.0 - float(ARMOUR["stump"])))) and ok
	strong.free()
	strong_plain.free()
	# a mission boss, and a tank made a raid leader or an expedition room's boss, keep H5's health and damage
	var boss = main.fight.spawn("stump", Vector3(0, 0, -30), 0, -1, true)
	var plain_stump: Enemy = _spawn("stump", Vector3(4, 0, -30), 1.0, false)
	var boss_ok: bool = boss != null and is_instance_valid(boss)
	if boss_ok:
		(boss as Node3D).set_physics_process(false)
		var h0: float = (boss as Enemy).hp
		(boss as Enemy).hit(Vector3.BACK, RAW)
		boss_ok = is_equal_approx(h0 - (boss as Enemy).hp, RAW) and is_equal_approx((boss as Enemy).last_dealt, RAW)
	ok = _x("a tank spawned as a mission boss has no armour: a hit does its full damage", boss_ok) and ok
	if boss != null and is_instance_valid(boss):
		boss.queue_free()
	var leader: Enemy = _spawn("beetle", Vector3(8, 0, -30), 1.0, false)
	var leader_h: float = leader.hp
	leader.hit(Vector3.BACK, RAW)
	ok = _x("a tank set up unarmoured (a raid leader or an expedition room's boss) keeps its H5 health and takes the full hit", is_equal_approx(leader.max_hp, float(Data.enemy("beetle")["hp"]))
		and is_equal_approx(leader_h - leader.hp, RAW)) and ok
	leader.free()
	plain_stump.free()
	return ok


# ---------------------------------------------------------------- the save: v5 in, v6 out, held stock, wear, credit, two loads
func _write_scratch(path: String, text: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	var ok: bool = f.store_string(text)
	f.close()
	return ok


func _read_scratch(path: String) -> Dictionary:
	return _dict(JSON.parse_string(FileAccess.get_file_as_string(path)))


func _check_save() -> bool:
	var d = main.defences
	var st = main.stations
	var w = main.world
	_bare_camp()
	t._veteran(3)
	_rich()
	Save.camp_level = 3
	Save.stations["workshop"] = 0
	Save.ruined = []
	st.refresh("all")
	# the fixture's places, found in the live camp before the old file replaces it
	var wp: Vector3 = w.station_pos("workshop")
	var stall: Vector3 = w.station_pos("stall")
	var clear: Vector3 = Vector3(1.0e9, 0, 0)
	for n: int in range(6, 30):
		var cand: Vector3 = _spot("tower", n)
		if cand.x > 1.0e8:
			break
		if not w.on_station_ground("workshop", cand, 1.5) and not w.on_station_ground("stall", cand, 1.5):
			clear = cand
			break
	var slot: Vector2i = NO_SLOT
	for sl: Array in w.barricade_slots():
		if d.pad_open(int(sl[2]), int(sl[3])):
			slot = Vector2i(int(sl[2]), int(sl[3]))
			break
	var ok: bool = _x("the save fixture's places exist (a clear spot and an open road pad)", clear.x < 1.0e8 and slot != NO_SLOT)
	if not ok:
		return false
	var missions: Array = []
	for i: int in 3:
		missions.append(String(Data.mission(i)["id"]))
	var v5: Dictionary = {
		"save_v": 5, "leaves": 5000, "timber": 100, "shards": 12, "camp_level": 3, "missions_done": missions,
		"stations": {"target": 1, "bench": 1, "stall": 1, "well": 1}, "pet_level": 1, "claimed": [0, 1],
		"flags": {"shop_open": true, "shop_target": true, "shop_bench": true, "home": true, "first_stage_done": true},
		"owned": {"pets": {"sprig": {"level": 1}}}, "future_field": {"keep": [true, "note"]},
		"def_levels": {"barricade": 3, "tower": 4, "spikes": 5}, "items": {"tower": 1, "spikes": 0},
		"placed": [
			{"type": "tower", "x": wp.x + 0.6, "z": wp.z - 0.4, "rot": 0.0, "wreck": 0.4},
			{"type": "tower", "x": stall.x + 0.3, "z": stall.z, "rot": 0.0},
			{"type": "tower", "x": clear.x, "z": clear.z, "rot": 0.0},
			{"type": "barricade", "slot": [slot.x, slot.y], "row": 3, "wrecks": [-1.0, 0.0, 0.65], "wreck": 0.0},
		],
	}
	var text: String = JSON.stringify(v5, "  ") + "\n"
	var original: String = Save.path
	Save.save_game(true)
	var was_frozen: bool = main.frozen
	main.frozen = true
	var scratch: String = "user://leaf_save_test_workshop.json"
	var backup: String = scratch.get_basename() + ".bak.json"
	for p: String in [scratch, backup, scratch + ".tmp", backup + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	Save.path = scratch
	ok = _x("the mixed-level v5 file is written", _write_scratch(scratch, text)) and ok
	Save.load_game()
	await get_tree().process_frame
	ok = _x("the v5 file loads as v5, becomes v6 and is backed up byte for byte", Save.loaded_v == 5 and Save.save_v == 6 and FileAccess.file_exists(backup)
		and FileAccess.get_file_as_string(backup) == text, {"loaded": Save.loaded_v, "save_v": Save.save_v}) and ok
	ok = _x("old ownership, currencies and unrelated fields survive the step", Save.shards == 12 and Save.leaves == 5000 and Data.owned_level("pets", "sprig") == 1
		and Save.camp_level == 3 and Save.missions_done == missions) and ok
	var lv_ok: bool = Save.placed.size() == 4 and int(Save.placed[0].get("level", 0)) == 4 and is_equal_approx(float(Save.placed[0].get("wreck", 0.0)), 0.4) \
		and int(Save.placed[3].get("level", 0)) == 3 and _same(Save.placed[3].get("wrecks"), [-1.0, 0.0, 0.65])
	ok = _x("every placed piece carries its kind's old level and its own wear, the row keeps its uneven section wear", lv_ok, {"placed": Save.placed}) and ok
	ok = _x("the held tower keeps level 4 and the paid-for patch level 5 waits as one credit", _same(Save.defence_reserves, {"tower": [{"level": 4}]})
		and _same(Save.defence_legacy_credit, {"spikes": 5}) and Bag.best_held_level("tower") == 4, {"reserves": Save.defence_reserves, "credit": Save.defence_legacy_credit}) and ok
	# a full Bag when the older obstruction goes back
	Bag.add("berries", Bag.room_for("berries"))
	d.load_saved()
	await get_tree().process_frame
	ok = _x("the towers on the Market's and the Workshop's ground go back into a full Bag at their level and wear (forced): the Workshop's ground counts as camp even before it is built",
		Bag.count("tower") == 3 and Bag.used_slots() >= Bag.slots() and Bag.best_held_level("tower") == 4 and Save.placed.size() == 2
		and _reserve_has("tower", 4, 0.4), {"held": Bag.count("tower"), "placed": Save.placed.size(), "slots": [Bag.used_slots(), Bag.slots()], "best": Bag.best_held_level("tower"), "res": Save.defence_reserves}) and ok
	Save.bag = {}
	st.refresh("all")
	# the Workshop is built over the worn tower: it goes back with its level and wear, once
	_put("tower", wp + Vector3(0.6, 0.0, -0.4), 4, 0.3)
	var held0: int = Bag.count("tower")
	st._build_station("workshop")
	await t._wait(0.4)
	var back_wear: bool = false
	for rec: Variant in (Save.defence_reserves.get("tower", []) as Array):
		if rec is Dictionary and is_equal_approx(float((rec as Dictionary).get("wreck", -1.0)), 0.3) and int((rec as Dictionary).get("level", 0)) == 4:
			back_wear = true
	ok = _x("building the Workshop sends the tower standing on its ground back to the Bag at level 4 with its wear (0.3), once", int(Save.stations["workshop"]) == 1
		and Bag.count("tower") == held0 + 1 and back_wear and not _on_ground(wp), {"held": Bag.count("tower"), "reserves": Save.defence_reserves}) and ok
	# placing each again keeps the paid level, and the wear comes with the piece that had it
	var made: Array[int] = []
	var seen_wear: int = 0
	for n: int in Bag.count("tower"):
		var at: Vector3 = _spot("tower", 2 + 3 * n)
		if at.x > 1.0e8:
			continue
		d.start_placing("tower")
		var id: int = int(d.commit_placement("tower", at, 0.0))
		d.stop_placing()
		if id >= 0:
			made.append(id)
			var p: Dictionary = d.piece_at(id)
			var src: Dictionary = _dict(p.get("src"))
			if d.piece_level(p) == 4 and int(src.get("level", 0)) == 4:
				if is_equal_approx(float(src.get("wreck", 0.0)), 0.4) or is_equal_approx(float(src.get("wreck", 0.0)), 0.3):
					seen_wear += 1
				elif not src.has("wreck"):
					seen_wear += 0
	ok = _x("placed again, all four held towers keep level 4 and exactly two carry their wear (0.4 and 0.3), and the Bag is empty of towers", made.size() == 4 and seen_wear == 2 and Bag.count("tower") == 0
		and Save.defence_reserves.get("tower", []).is_empty(), {"made": made, "wear": seen_wear}) and ok
	# the credit is redeemed once
	var l0: int = Save.leaves
	st._buy_piece("spikes")
	st._buy_piece("spikes")
	var first_best: int = int(Bag.peek_defence("spikes").get("level", 0))
	var s1: int = int(d.commit_placement("spikes", _spot("spikes", 12), 0.0)) if Bag.count("spikes") > 0 else -1
	var s2: int = int(d.commit_placement("spikes", _spot("spikes", 14), 0.0)) if Bag.count("spikes") > 0 else -1
	var lv1: int = d.piece_level(d.piece_at(s1)) if s1 >= 0 else 0
	var lv2: int = d.piece_level(d.piece_at(s2)) if s2 >= 0 else 0
	ok = _x("the old Thorn Spikes level 5 comes back once: the first patch is level 5, the second level 1, the credit is gone", first_best == 5 and maxi(lv1, lv2) == 5 and mini(lv1, lv2) == 1
		and not Save.defence_legacy_credit.has("spikes") and l0 > Save.leaves, {"levels": [lv1, lv2], "credit": Save.defence_legacy_credit}) and ok
	d.stop_placing()
	# resave and reload twice
	Save.save_game(true)
	var one: Dictionary = _read_scratch(scratch)
	Save.load_game()
	await get_tree().process_frame
	Save.save_game(true)
	var two: Dictionary = _read_scratch(scratch)
	Save.load_game()
	await get_tree().process_frame
	Save.save_game(true)
	var three: Dictionary = _read_scratch(scratch)
	ok = _x("loading and saving v6 twice changes nothing (reserves, credit and wear are not used up or repeated); no def_levels is ever written; the unknown field stays",
		_same(_no_clock(one), _no_clock(two)) and _same(_no_clock(two), _no_clock(three)) and not one.has("def_levels") and int(one.get("save_v", 0)) == 6 and one.has("defence_reserves") and one.has("defence_legacy_credit")
		and _same(one.get("future_field"), v5["future_field"]), {"diff12": _diff(one, two), "diff23": _diff(two, three), "one_placed": (one.get("placed", []) as Array).size(), "one": one.get("placed"), "two": two.get("placed"), "r1": one.get("defence_reserves"), "r2": two.get("defence_reserves")}) and ok
	# a second, bare save in the same process keeps nothing of the first
	ok = _x("a bare v6 file is written", _write_scratch(scratch, JSON.stringify({"save_v": 6, "leaves": 3}) + "\n")) and ok
	Save.load_game()
	await get_tree().process_frame
	ok = _x("a second fresh save keeps no piece, stock, credit, Workshop, pet or shards of the first", Save.leaves == 3 and Save.placed.is_empty() and Save.defence_reserves.is_empty()
		and Save.defence_legacy_credit.is_empty() and int(Save.stations.get("workshop", -1)) == 0 and Save.shards == 0 and Data.owned_level("pets", "sprig") == 0
		and Bag.count("tower") == 0, {"placed": Save.placed, "stations": Save.stations}) and ok
	# back to the test slot
	Save.path = original
	Save.load_game()
	main.frozen = was_frozen
	for p: String in [scratch, backup, scratch + ".tmp", backup + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	st.refresh("all")
	d.load_saved()
	await t._wait(0.3)
	return ok


func _on_ground(_at: Vector3) -> bool:
	for p: Dictionary in main.defences.pieces:
		if main.world.on_station_ground("workshop", p["pos"], 0.6):
			return true
	return false


## Does the Bag's reserve list for this kind hold a record of this level and this wear?
func _reserve_has(kind: String, level: int, wear: float) -> bool:
	for rec: Variant in (Save.defence_reserves.get(kind, []) as Array):
		if rec is Dictionary and int((rec as Dictionary).get("level", 0)) == level and is_equal_approx(float((rec as Dictionary).get("wreck", -1.0)), wear):
			return true
	return false


func _diff(a: Dictionary, b: Dictionary) -> Array:
	var out: Array = []
	for k: Variant in a:
		if not b.has(k) or not _same(a[k], b[k]):
			out.append(k)
	for k: Variant in b:
		if not a.has(k):
			out.append(k)
	return out


## A save without its clock fields (timers.seen moves with the real time between two saves).
func _no_clock(d: Dictionary) -> Dictionary:
	var c: Dictionary = d.duplicate(true)
	c.erase("timers")
	return c
