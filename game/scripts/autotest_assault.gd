extends Node
## Random Raids: one capped roster, overlapping trail groups, checkpoints and one completion.
var t
var main


func _x(message: String, ok: bool, extra := {}) -> void:
	t._expect(message, ok, extra)


func _prepare(seed: int, level := 1, kind := "siege") -> Dictionary:
	t._reset_fight()
	t._clear_raid_state()
	Save.fire_ruined = false
	var types: Dictionary = main.raids.cfg()["types"]
	var type: Dictionary = types[kind]
	var leader := String(type.get("leader", ""))
	if type.has("leaders"):
		leader = String(type["leaders"][0])
	Save.raids["plan"] = {"type": kind, "lanes": range(Data.lane_count()), "level": level,
		"leader": leader, "seed": seed, "first": true, "called": false}
	Save.raids["pending"] = true
	Save.raids["warn_left"] = 30.0
	main.raids.try_warning()
	main.fight.set_physics_process(false)
	return main.fight.raid


func _queue() -> void:
	var f = main.fight
	f._rng.seed = hash([int(f.raid["seed"]), 1])
	f._raid_queue(1, true)


func _remove(enemy) -> void:
	main.fight.on_enemy_died(enemy)
	enemy.dead = true
	enemy.remove_from_group("foes")
	enemy.remove_from_group("enemies")
	enemy.queue_free()


func run() -> void:
	await t._raid_camp()
	main.raids.manual = true
	main.player.set_process(false)
	main.set_riding(false)
	if main.guardian != null:
		main.guardian.process_mode = Node.PROCESS_MODE_DISABLED
	var f = main.fight
	var rd = main.raids
	var missions_before: Dictionary = t._mission_fields()
	var valid_count := true
	var valid_roads := true
	var valid_groups := true
	var leader_last := true
	var varied_sizes := {}
	var rosters := {}
	for kind in rd.cfg()["types"]:
		for level in [1, 15, 30]:
			for seed in [1234, 9876, 58234]:
				var spec := _prepare(seed, level, String(kind))
				_queue()
				valid_count = valid_count and f.waves() == 1 and f._queue.size() == int(spec["enemy_count"]) and f._queue.size() <= 50
				var roads := {}
				var groups := {}
				for row in f._qinfo:
					roads[int(row[0])] = true
					groups[int(row[1])] = int(groups.get(int(row[1]), 0)) + 1
				valid_roads = valid_roads and roads.size() == Data.lane_count()
				for size in groups.values():
					valid_groups = valid_groups and int(size) >= 1 and int(size) <= 3
					varied_sizes[int(size)] = true
				leader_last = leader_last and (String(spec["leader"]) == "" or f._queue.back() == String(spec["leader"]))
				rosters[JSON.stringify([f._queue, f._qinfo])] = true
	_x("all raid types and difficulty levels use one roster of at most 50 including the leader", valid_count)
	_x("every tested raid mixes arrivals across all four trails", valid_roads)
	_x("arrival groups contain one to three enemies and vary in size", valid_groups and varied_sizes.size() == 3)
	_x("the leader arrives last in the roster", leader_last)
	_x("different seeds produce different mixed arrival plans", rosters.size() > 3)
	_prepare(12345)
	_queue()
	var full_queue: Array = f._queue.duplicate()
	var full_info: Array = f._qinfo.duplicate(true)
	_queue()
	_x("the same seed recreates kinds, trails, group sizes and timing", f._queue == full_queue and f._qinfo == full_info)
	var card: Dictionary = rd.card_raid(Vector3.ZERO)
	_x("the ready menu offers Defend Camp rather than another wave", String(card["rows"][0]["label"]) == "Defend Camp" and not JSON.stringify(card).to_lower().contains("start wave"))
	main.hud.show_card(main.stations.rings["sign"])
	await t._wait(1.0)
	await t._shot("assault_ready")
	main.hud.hide_card()
	main.frozen = true
	f._physics_process(30.0)
	_x("preparation never starts combat automatically", not f.in_wave)
	main.frozen = false
	f.next_phase_now()
	var initial: int = f._queue.size()
	f.next_phase_now()
	_x("one start launches the entire roster and repeated starts do nothing", f.in_wave and f.wave == 1 and f._queue.size() == initial)
	f._physics_process(0.1)
	_x("the opening is paced rather than dumping the roster at once", f._wave_foe_count() == 0 and f._queue.size() == initial)
	# Step the actual spawn loop without combat. Live-cap backpressure must not turn into another wave.
	for tick in 1000:
		f._physics_process(0.1)
		for enemy in f._wave_foes():
			enemy.set_process(false)
			enemy.set_physics_process(false)
		if f._wave_foe_count() >= f._max_alive():
			break
	var queued_at_cap: int = f._queue.size()
	for tick in 30:
		f._physics_process(0.1)
	_x("the simultaneous-enemy cap holds without a wave break", f._wave_foe_count() == f._max_alive() and f._queue.size() == queued_at_cap and f.in_wave and queued_at_cap > 0)
	var first_enemy = f._wave_foes()[0]
	_remove(first_enemy)
	f._physics_process(0.1)
	_x("arrivals continue as soon as a live slot opens", f._queue.size() == queued_at_cap - 1 and f.wave == 1 and f.in_wave)
	for enemy in f._wave_foes().slice(0, 4):
		_remove(enemy)
	var defeated: Array = Save.raids["run"]["defeated"].duplicate()
	_x("defeated members receive individual checkpoints", defeated.size() == 5)
	var queue_before_pause: Array = f._queue.duplicate()
	main.frozen = true
	f._physics_process(30.0)
	_x("pause freezes continuous arrivals", f._queue == queue_before_pause)
	main.frozen = false
	f.gate_hp = f.gate_max * 0.65
	f.raid_losses = 2
	rd.persist()
	f._clear_foes()
	f.active = false
	f.in_wave = false
	Save.load_game()
	main.defences.relink_saved()
	_x("save loading retains the roster size and resolved member IDs", int(Save.raids["plan"]["assault_total"]) == initial and Save.raids["run"]["defeated"] == defeated)
	rd.try_warning()
	f.next_phase_now()
	var same_remaining := true
	for i in f._qinfo.size():
		var member: int = f._qinfo[i][3]
		same_remaining = same_remaining and not defeated.has(member) and f._queue[i] == full_queue[member] and f._qinfo[i] == full_info[member]
	_x("resume restores only remaining raiders with the same kinds and arrival plan", same_remaining and f._queue.size() == initial - defeated.size())
	_x("resume preserves campfire damage and building losses", is_equal_approx(f.gate_hp / f.gate_max, 0.65) and f.raid_losses == 2)
	_x("active raid status shows the raid's name, no count and no wave numbers (H2: the raid bar shows the progress)", f.status_text() == f.title() and not f.status_text().contains("wave"))
	main.hud.show_card(main.stations.rings["sign"])
	await t._wait(0.6)
	await t._shot("assault_in_progress")
	main.hud.hide_card()
	var held_before: int = Save.raids["held"]
	var shards_before := Save.shards
	var leaves_before: int = Save.leaves
	var timber_at_start: int = Save.timber
	var all_arrivals := {}
	var last_raider: Node3D
	var no_breaks := true
	for tick in 2000:
		if not f.active:
			break
		no_breaks = no_breaks and f.in_wave and f.wave == 1
		f._physics_process(0.1)
		for enemy in f._wave_foes():
			all_arrivals[int(enemy.get_meta("raid_member", -1))] = true
			if last_raider == null:
				last_raider = enemy
			elif enemy != last_raider:
				_remove(enemy)
		if f.left_in_wave() <= 1:
			break
	_x("all remaining raiders arrive in one uninterrupted assault", no_breaks and all_arrivals.size() == initial - defeated.size())
	var quiet_after: float = float(Data.b["mission"]["flee_after"])
	var fire: Vector3 = main.world.station_pos("campfire")
	if is_instance_valid(last_raider):
		last_raider.set_physics_process(false)
		last_raider.global_position = main.world.spawn_point(last_raider.patch, 0.0)
		last_raider.state = "walk"
		last_raider._goal = last_raider.global_position
		last_raider._think_t = quiet_after
	f._quiet_t = quiet_after
	f._physics_process(0.1)
	var distance_before: float = last_raider.global_position.distance_to(fire) if is_instance_valid(last_raider) else INF
	for _tick: int in 30:
		f._physics_process(0.1)
		if is_instance_valid(last_raider) and not last_raider.dead:
			last_raider._physics_process(0.1)
	var last_standing: bool = is_instance_valid(last_raider) and not last_raider.dead and last_raider.hp > 0.0 \
		and not last_raider.is_queued_for_deletion() and last_raider.is_in_group("foes")
	_x("the last raider walks toward the campfire after the quiet timer passes",
		last_standing and last_raider.global_position.distance_to(fire) < distance_before and f._quiet_t < quiet_after)
	f._quiet_t = quiet_after
	f._physics_process(0.1)
	_x("a second quiet spell does not restart the last raider's walk", f._quiet_t > quiet_after)
	_x("the last raider stays after the leader falls and the quiet timer passes", last_standing and f.active and f.in_wave and f.left_in_wave() == 1)
	_x("the assault has yet to pay while a raider stands", int(Save.raids["held"]) == held_before and Save.shards == shards_before
		and Save.leaves == leaves_before and Save.timber == timber_at_start)
	if last_standing:
		_remove(last_raider)
	f._physics_process(0.1)
	_x("the last kill ends the assault and pays once", not f.active and int(Save.raids["held"]) == held_before + 1 and Save.shards > shards_before and not bool(Save.raids["pending"]))
	var paid := Save.shards
	var leaves_paid := Save.leaves
	var timber_paid := Save.timber
	f._raid_wave_cleared()
	_x("a late duplicate clear cannot repeat completion rewards", Save.shards == paid and Save.leaves == leaves_paid and Save.timber == timber_paid and int(Save.raids["held"]) == held_before + 1)
	_x("Random Raids never alter Raid Mission progress or saved runs", t._mission_fields() == missions_before)
	# Old three-wave checkpoints become a smaller remaining roster once, retaining damage and loss credit.
	_prepare(98765)
	var old_total: int = f.raid["enemy_count"]
	t._reset_fight()
	Save.raids["run"] = {"wave_done": 2, "fire": 0.6, "losses": 1, "rebuilt": true}
	var migrated: Dictionary = rd.spec_for(Save.raids["plan"])
	var again: Dictionary = rd.spec_for(Save.raids["plan"])
	_x("legacy completed waves reduce the remaining assault once", int(migrated["enemy_count"]) == ceili(float(old_total) / 3.0) and int(again["enemy_count"]) == int(migrated["enemy_count"]) and int(Save.raids["run"]["legacy_held"]) == 2)
	_x("legacy migration preserves fire health, losses and the used rebuild", float(Save.raids["run"]["fire"]) == 0.6 and int(Save.raids["run"]["losses"]) == 1 and bool(Save.raids["run"]["rebuilt"]))
	_prepare(12345)
	f.next_phase_now()
	var summoned: Array = []
	for i in 55:
		var enemy = f.spawn("thornling", main.world.spawn_point(0, 0.0), 0)
		if enemy != null:
			summoned.append(enemy)
	_x("boss reinforcements share the 50-enemy total rather than bypassing it", f.raid_total() == 50 and summoned.size() == 50 - int(f.raid["enemy_count"]))
	var summon_id := int(summoned[0].get_meta("raid_member"))
	_remove(summoned[0])
	_x("fallen summons do not reopen the total spawn budget", f.spawn("thornling", main.world.spawn_point(0, 0.0), 0) == null)
	var loaded: Dictionary = Save._load_raids(Save.raids)
	_x("summon checkpoints survive save sanitizing", loaded["run"]["summons"] == Save.raids["run"]["summons"] and (loaded["run"]["defeated"] as Array).has(summon_id))
	t._reset_fight()
	_prepare(7654)
	f.next_phase_now()
	var timber_before := Save.timber
	f.damage_fire(int(f.gate_hp) + 1, Vector3(0, 0, -5))
	rd.persist()
	f._clear_foes()
	t._reset_fight()
	Save.load_game()
	main.defences.relink_saved()
	rd.restore_on_load()
	rd.try_warning()
	_x("Last Stand resume keeps its one used rebuild at 30% without charging twice", f.active and f.warning and is_equal_approx(f.gate_hp / f.gate_max, 0.3) and f.rebuilt and f.fire_went_out and Save.timber == timber_before)
	t._reset_fight()
	_prepare(4321)
	f.next_phase_now()
	Save.raids["run"]["defeated"] = range(ceili(float(f.raid["enemy_count"]) / 3.0))
	shards_before = Save.shards
	var lost_before: int = Save.raids["lost"]
	f._raid_over(false)
	_x("a partial defence still earns consolation without completing a wave", int(Save.raids["lost"]) == lost_before + 1 and Save.shards - shards_before == int(rd.cfg()["pay"]["lost_per_wave_held"]))
	t._clear_raid_state()
	main.player.set_process(true)
	f.set_physics_process(true)
	if main.guardian != null:
		main.guardian.process_mode = Node.PROCESS_MODE_INHERIT
	t._log("continuous random assault done")
