## H6 Stage 1 checks for --autotest --workshop --foundation. The v6 step reads test dictionaries, and the
## commands and combat checks use the test camp. Keep automatic saves held while a placement fixture is in use.
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
		return t._expect("Stage 1 runs --workshop with --foundation", false)
	var ok: bool = _check_h5_boot()
	ok = _check_converter() and ok
	ok = _check_placement() and ok
	ok = _check_grid() and ok
	ok = _check_damage() and ok
	return _check_burst() and ok


# ---------------------------------------------------------------- the live v5 boot and the dormant v6 step
func _check_h5_boot() -> bool:
	var routed: Dictionary = SaveUpgrades.upgrade(V5_CAMP.duplicate(true))
	var ok: bool = t._expect("the live boot uses v5, leaves v5 saves alone and has no Workshop window",
		Save.save_v == H5_VERSION and SaveUpgrades.CURRENT_VERSION == H5_VERSION and _same(routed, V5_CAMP)
		and not main.hud.windows.has("workshop"), {"save_v": Save.save_v, "current": SaveUpgrades.CURRENT_VERSION})
	if Data.args().has("--fresh"):
		var written: Dictionary = _dict(JSON.parse_string(FileAccess.get_file_as_string(Save.path)))
		ok = t._expect("the boot save writes the H5 defence fields",
			written.get("save_v") == H5_VERSION and written.get("def_levels") is Dictionary
			and not written.has("defence_reserves") and not written.has("defence_legacy_credit"),
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
		and is_same(piece.get("src"), record) and record.get("type") == "tower" and not record.has("level")
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
	var foe: Enemy = _spawn("beetle", Vector3.ZERO, strength)
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


func _spawn(kind: String, at: Vector3, strength: float = 1.0) -> Enemy:
	var foe: Enemy = Enemy.new()
	foe.main = main
	main.add_child(foe)
	foe.global_position = at
	foe.setup(kind, 0, strength)
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
