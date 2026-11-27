## H6 checks: `--autotest --workshop --foundation` (Stage 1: the converter and the frozen inputs, the Place and Undo commands,
## the enemy grid, zero-armour damage and the first ability) and `--autotest --workshop` (Stage 2, the live game: the
## Workshop, per-piece levels, specialisations, armour and save v6; run() below). The live run uses the real Build, Buy,
## Place, card and Confirm paths at the phone shape and takes the Workshop screenshots. Keep automatic saves held while a
## placement fixture is in use.
## Split on 27 Nov 2026 (house rule 1, about 800 lines a file): this file keeps the Stage 1 checks, the helpers, and the
## boot, content, build and shop checks; autotest_workshop_pieces.gd runs Place, taps, levels and repair, and
## autotest_workshop_rules.gd the specialisations, armour and save, in that order, using the helpers here.
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
	ok = await _run_half("res://scripts/autotest_workshop_pieces.gd") and ok   # Place, taps, levels, repair
	ok = await _run_half("res://scripts/autotest_workshop_rules.gd") and ok    # specialisations, armour, save
	get_window().size = size0
	main.closeup = Vector3.ZERO
	main.closeup_at = null
	main.hud.hide_card()
	return ok


## Runs one of the two other halves of the live checks on this node's helpers, then frees it (the way autotest_g3_bow.gd
## runs autotest_g3_bow_windows.gd).
func _run_half(path: String) -> bool:
	var half = load(path).new()
	half.t = t
	half.main = main
	half.g = self
	add_child(half)
	var ok: bool = await half.run()
	half.queue_free()
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


