## H7 checks: --autotest --fresh --daynight. The pictures use the camp camera and the runner's window size.
extends Node

const AutotestScript := preload("res://scripts/autotest.gd")
const MainScript := preload("res://scripts/main.gd")
const WorldScript := preload("res://scripts/world.gd")
const StationsScript := preload("res://scripts/stations.gd")
const BurrowRunScript := preload("res://scripts/burrow_run.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const TEST_SAVE_PATH := "user://leaf_save_test_daynight.json"
const SHOT_NAMES: Dictionary = {"morning": "morning", "day": "noon", "evening": "evening", "night": "night"}

var t: AutotestScript
var main: MainScript
var world: WorldScript
var stations: StationsScript
var _keys: Array[Dictionary] = []
var _cycle_s: float
var _step_s: float
var _visual_s: float
var _start_s: float
var _floor_energy: float
var _floor_color: Color
var _fog_cap: float


func run() -> bool:
	world = main.world
	stations = main.stations
	var cfg: Dictionary = Data.day_night_cfg()
	var ids: Array[String] = []
	for key: Dictionary in cfg.get("keyframes", []):
		_keys.append(key)
		ids.append(String(key["id"]))
	_cycle_s = float(cfg.get("cycle_s", 0.0))
	_step_s = float(cfg.get("max_step_s", 0.0))
	_visual_s = float(cfg.get("visual_update_s", 0.0))
	_start_s = float(cfg.get("start_s", 0.0))
	if not t._expect("the clock has four ordered keys and positive timing limits",
			ids == ["morning", "day", "evening", "night"] and _cycle_s > 0.0 and _step_s > 0.0 and _visual_s > 0.0,
			{"keys": ids}):
		return false
	_floor_energy = float(cfg["ambient_min_energy"])
	_floor_color = _color(cfg["ambient_min_color"])
	_fog_cap = float(cfg["fog_max_density"])

	var original_path: String = Save.path
	var original_quality: int = Quality.level
	Save.save_game(true)
	Save.path = TEST_SAVE_PATH
	# Grow the fresh camp so its posts are lit as well as its trail lanterns.
	Save.camp_level += 1
	main.on_camp_grown()
	main.hud.hide_hint()
	main.snap_camera()
	await get_tree().process_frame

	Quality.set_level(Quality.LOW)
	var ok: bool = _check_cycle()
	ok = await _check_live_clock() and ok
	ok = await _check_lights_and_shots() and ok
	ok = await _check_save() and ok
	ok = await _check_burrows() and ok
	ok = await _check_wave() and ok

	Quality.set_level(original_quality)
	Save.path = original_path
	Save.load_game()
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(TEST_SAVE_PATH)
	return ok


func _check_cycle() -> bool:
	var first: Dictionary = _keys.front()
	_set_time(float(first["at_s"]))
	var ok: bool = _check_key(first)
	var floor_ok: bool = _floor_holds()
	for i: int in _keys.size():
		var key: Dictionary = _keys[i]
		var wrap: bool = i == _keys.size() - 1
		var next: Dictionary = _keys.front() if wrap else _keys[i + 1]
		var at: float = float(key["at_s"])
		var hold: float = float(key["hold_until_s"])
		var end: float = _cycle_s if wrap else float(next["at_s"])
		if hold > at:
			var half_hold: float = (hold - at) / 2.0
			floor_ok = _advance(half_hold) and floor_ok
			ok = t._expect("%s holds its light through the middle of its hold" % key["id"],
				is_equal_approx(Save.camp_day_s, at + half_hold) and _matches_key(key)) and ok
			floor_ok = _advance(half_hold) and floor_ok
			ok = t._expect("%s holds its light until the blend starts" % key["id"],
				is_equal_approx(Save.camp_day_s, hold) and _matches_key(key)) and ok

		var half_blend: float = (end - hold) / 2.0
		var energy: float = float(key["sun_energy"])
		var next_energy: float = float(next["sun_energy"])
		floor_ok = _advance(half_blend) and floor_ok
		var live: float = world.sun.light_energy
		var between: bool = is_equal_approx(live, energy) if is_equal_approx(energy, next_energy) \
			else live > minf(energy, next_energy) and live < maxf(energy, next_energy)
		ok = t._expect("%s to %s blends while the clock advances" % [key["id"], next["id"]],
			is_equal_approx(Save.camp_day_s, hold + half_blend) and between, {"sun_energy": live}) and ok

		world.apply_day_night()
		var horizon: Color = _color(key["sky_horizon_color"]).lerp(_color(next["sky_horizon_color"]), 0.5)
		var yaw: float = lerp_angle(deg_to_rad(float(key["sun_yaw_deg"])), deg_to_rad(float(next["sun_yaw_deg"])), 0.5)
		ok = t._expect("%s to %s blends the sun and sky halfway, with the shorter turn" % [key["id"], next["id"]],
			is_equal_approx(world.sun.light_energy, lerpf(energy, next_energy, 0.5))
			and _sky().sky_horizon_color.is_equal_approx(horizon)
			and is_zero_approx(angle_difference(world.sun.rotation.y, yaw)) and _floor_holds()) and ok

		var past_end: float = _step_s / 2.0 if wrap else 0.0
		floor_ok = _advance(half_blend + past_end) and floor_ok
		if wrap:
			ok = t._expect("the clock wraps and keeps the part of the step after dawn",
				is_equal_approx(Save.camp_day_s, past_end), {"camp_day_s": Save.camp_day_s}) and ok
		else:
			world.apply_day_night()
			ok = _check_key(next) and ok
	ok = t._expect("Low keeps the ambient floor, cool fill and fog cap through the whole cycle", floor_ok) and ok
	_set_time(_start_s)
	world.advance_day_night(_step_s + _visual_s)
	return t._expect("one long frame only spends the time allowed by the clock",
		is_equal_approx(Save.camp_day_s, _start_s + _step_s), {"camp_day_s": Save.camp_day_s}) and ok


func _advance(seconds: float) -> bool:
	var left: float = seconds
	var floor_ok: bool = true
	while left > 0.0:
		var step: float = minf(left, _step_s)
		world.advance_day_night(step)
		left -= step
		floor_ok = _floor_holds() and floor_ok
	return floor_ok


func _check_key(key: Dictionary) -> bool:
	return t._expect("%s arrives with its clock, sun, sky and fill" % key["id"],
		is_equal_approx(Save.camp_day_s, float(key["at_s"])) and _matches_key(key),
		{"camp_day_s": Save.camp_day_s, "sun_energy": world.sun.light_energy})


func _matches_key(key: Dictionary) -> bool:
	return is_equal_approx(world.sun.light_energy, float(key["sun_energy"])) \
		and world.sun.light_color.is_equal_approx(_color(key["sun_color"])) \
		and _sky().sky_top_color.is_equal_approx(_color(key["sky_top_color"])) \
		and _sky().sky_horizon_color.is_equal_approx(_color(key["sky_horizon_color"])) \
		and is_equal_approx(world.fill_light.light_energy, float(key["fill_energy"])) and _floor_holds()


func _check_live_clock() -> bool:
	var before: float = Save.camp_day_s
	await t._wait(_visual_s)
	var ok: bool = t._expect("the clock advances in idle camp", main.area == null and not main.fight.active and Save.camp_day_s > before)
	main.frozen = true
	main.player.frozen = true
	before = Save.camp_day_s
	await t._wait(_visual_s)
	ok = t._expect("a frozen camp spends no time", Save.camp_day_s == before) and ok
	main.player.frozen = false
	main.frozen = false
	return ok


func _check_lights_and_shots() -> bool:
	# Hold each time while the fire and renderer catch up. The cat and camera stay in the same place.
	main.set_process(false)
	Quality.set_level(Quality.MEDIUM)
	var day: Dictionary = _keys[1]
	var night: Dictionary = _keys.back()
	var day_lamps: Dictionary = {}
	var day_fire: Vector2 = Vector2.ZERO
	for key: Dictionary in _keys:
		_set_time(float(key["at_s"]))
		await t._wait(_visual_s)
		if key == day:
			day_lamps = _lamps()
			day_fire = _fire_sample()
		await t._shot("daynight_" + String(SHOT_NAMES[key["id"]]))
	var ok: bool = t._expect("Medium brightens the fire and every camp lantern at night with bloom off",
		not world.env.glow_enabled and _boosted(day, night, day_lamps, day_fire))

	_set_time(float(day["at_s"]))
	Quality.set_level(Quality.LOW)
	await t._wait(_visual_s)
	var low_day: Vector2i = _light_count()
	Quality.set_level(Quality.HIGH)
	await t._wait(_visual_s)
	var high_lamps: Dictionary = _lamps()
	var high_fire: Vector2 = _fire_sample()
	_set_time(_night_s())
	await t._wait(_visual_s)
	ok = t._expect("High brightens the fire and every camp lantern at night",
		_boosted(day, night, high_lamps, high_fire)) and ok
	await t._shot("daynight_night_high")

	# A new lantern takes the current light as soon as it is registered.
	var lamp: OmniLight3D = OmniLight3D.new()
	var base: float = lamp.light_energy
	lamp.add_to_group("lamp")
	world.add_child(lamp)
	world.register_camp_lamp(lamp)
	ok = t._expect("a lantern registered after dark gets the night boost straight away",
		is_equal_approx(lamp.light_energy, base * float(night["lamp_scale"]))) and ok
	lamp.queue_free()

	Quality.set_level(Quality.LOW)
	await t._wait(_visual_s)
	var low_night: Vector2i = _light_count()
	ok = t._expect("Low adds no lights at night and keeps the flame visible",
		low_night == low_day and _lamps().is_empty() and is_equal_approx(stations._fire_scale, 1.0) and stations.flame().is_visible_in_tree(),
		{"day": low_day, "night": low_night}) and ok
	await t._shot("daynight_night_low")

	Quality.set_level(Quality.MEDIUM)
	await t._wait(_visual_s)
	ok = t._expect("switching back to Medium at night brings the boost back with bloom off",
		not world.env.glow_enabled and _boosted(day, night, day_lamps, day_fire)) and ok

	Save.fire_look = "shardfire"
	stations.apply_fire_look()
	await t._wait(_visual_s)
	var shardfire: Dictionary = stations._fire_look()
	var tint: Vector3 = stations._flame_mat.get_shader_parameter("tint")
	var light: Color = stations._fire_light.light_color
	ok = t._expect("Shardfire keeps its own tint and the night boost",
		String(shardfire["id"]) == "shardfire" and tint.is_equal_approx(_rgb(shardfire["tint"]))
		and is_equal_approx(light.r, float(shardfire["light"][0]))
		and is_equal_approx(light.b, float(shardfire["light"][2]))
		and _boosted(day, night, day_lamps, day_fire)) and ok
	Save.fire_look = ""
	stations.apply_fire_look()
	main.set_process(true)
	return ok


func _lamps() -> Dictionary:
	var lamps: Dictionary = {}
	for node: Node in get_tree().get_nodes_in_group("lamp"):
		var lamp: OmniLight3D = node as OmniLight3D
		if lamp != null and lamp.is_visible_in_tree():
			lamps[lamp] = lamp.light_energy
	return lamps


func _fire_sample() -> Vector2:
	return Vector2(stations._fire_light.light_energy, float(stations._flame_mat.get_shader_parameter("glow")))


func _boosted(day: Dictionary, night: Dictionary, day_lamps: Dictionary, day_fire: Vector2) -> bool:
	var lamps: Dictionary = _lamps()
	if day_lamps.is_empty() or lamps.size() != day_lamps.size() or not stations._fire_light.is_visible_in_tree():
		return false
	var scale: float = float(night["lamp_scale"]) / float(day["lamp_scale"])
	for lamp: OmniLight3D in day_lamps:
		var energy: float = float(lamps.get(lamp, 0.0))
		if energy <= float(day_lamps[lamp]) or not is_equal_approx(energy, float(day_lamps[lamp]) * scale):
			return false
	var fire: Vector2 = _fire_sample()
	return is_equal_approx(stations._fire_scale, float(night["fire_scale"]) / float(day["fire_scale"])) and fire.y > day_fire.y


func _light_count() -> Vector2i:
	var nodes: Array[Node] = main.find_children("*", "Light3D", true, false)
	var active_omnis: int = 0
	for node: Node in nodes:
		if node is OmniLight3D and (node as OmniLight3D).is_visible_in_tree():
			active_omnis += 1
	return Vector2i(nodes.size(), active_omnis)


func _check_save() -> bool:
	main.set_process(false)
	var saved_s: float = _night_s() + _step_s / 2.0
	_set_time(saved_s)
	Save.save_game(true)
	var written: Variant = JSON.parse_string(FileAccess.get_file_as_string(Save.path))
	var clock: Variant = (written as Dictionary).get("camp_day_s") if written is Dictionary else null
	var ok: bool = t._expect("the normal save writes the clock",
		(clock is float or clock is int) and is_equal_approx(float(clock), saved_s))
	if ok:
		_set_time(_start_s)
		Save.load_game()
		await t._wait(_visual_s)
		ok = t._expect("loading restores both the saved time and its light",
			is_equal_approx(Save.camp_day_s, saved_s) and _matches_key(_keys.back())) and ok
		var fixture: Dictionary = written as Dictionary
		fixture.erase("camp_day_s")
		ok = await _check_morning_save(fixture, "a save without a camp clock") and ok
		fixture["camp_day_s"] = str(saved_s)
		ok = await _check_morning_save(fixture, "a save with a clock written as text") and ok
	main.set_process(true)
	return ok


func _check_morning_save(fixture: Dictionary, what: String) -> bool:
	var err: Error = Save._write_save_file(Save.path, JSON.stringify(fixture))
	if not t._expect("%s can be written" % what, err == OK, {"error": err}):
		return false
	_set_time(_night_s())
	Save.load_game()
	await t._wait(_visual_s)
	return t._expect("%s starts at morning on load" % what,
		is_equal_approx(Save.camp_day_s, _start_s) and _matches_key(_keys.front()),
		{"camp_day_s": Save.camp_day_s})


func _check_burrows() -> bool:
	var first: Dictionary = Data.burrow_list().front()
	main.burrows.open_hollow(false)
	var runner: BurrowRunScript = main.burrows.runner
	var night_s: float = _night_s()
	_set_time(night_s)
	var camp_angle: Vector3 = world.sun.rotation
	await main.burrows.enter(String(first["id"]), 1)
	if not t._expect("the Hollow entrance takes the cat below ground through the fade",
			main.area == runner and runner.active and not main.frozen and not runner.leaving):
		return false
	var theme: Dictionary = runner.data()["theme"]
	await t._wait(_visual_s)
	var ok: bool = t._expect("the clock waits below ground with the expedition moon and fill",
		Save.camp_day_s == night_s and main.cam.environment != null and main.cam.environment == runner.env
		and is_equal_approx(world.sun.light_energy, float(theme["moon_energy"]))
		and world.sun.light_color.is_equal_approx(_color(theme["moon"]))
		and is_equal_approx(world.fill_light.light_energy, float(theme["fill_energy"])),
		{"camp_day_s": Save.camp_day_s})
	await runner._back_up()
	ok = t._expect("climbing back restores the same camp night before the clock resumes",
		main.area == null and not runner.active and main.cam.environment == null and Save.camp_day_s == night_s
		and _matches_key(_keys.back()) and world.sun.rotation.is_equal_approx(camp_angle)) and ok
	await t._wait(_visual_s)
	return t._expect("the camp clock ticks again after the return fade",
		main.area == null and not main.frozen and Save.camp_day_s > night_s) and ok


func _check_wave() -> bool:
	Quality.set_level(Quality.LOW)
	_set_time(_night_s())
	main.player.invincible = true
	var mission: Dictionary = Data.b["mission"]
	Save.timber = maxi(Save.timber, int(mission["rebuild_timber"]))
	main.start_stage(0)
	var before: float = Save.camp_day_s
	await t._wait(_visual_s)
	var ok: bool = t._expect("the clock keeps ticking during a live mission wave",
		main.fight.active and main.fight.in_wave and Save.camp_day_s > before)
	if not main.fight.active or not main.fight.in_wave:
		return false
	main.player.frozen = true
	var timeout: float = float(mission["flee_after"])
	var spawned: bool = await t._until(func() -> bool: return not get_tree().get_nodes_in_group("foes").is_empty(), timeout)
	ok = t._expect("the wave spawns enemies for the night shot", spawned) and ok
	if spawned:
		var foe: EnemyScript = get_tree().get_nodes_in_group("foes").front() as EnemyScript
		var fire_range: float = stations._fire_light.omni_range
		main.player.global_position = world.trail_point(foe.patch, world.trail_length(foe.patch) - fire_range)
		main.snap_camera()
		main.fight.damage_fire(ceili(main.fight.gate_hp), main.player.global_position)
		var in_view: bool = await t._until(func() -> bool: return _foe_in_view(fire_range), timeout)
		ok = t._expect("a Low night wave has a foe in view outside the firelight with the fire out",
			in_view and world.fire_out and not stations.flame().is_visible_in_tree()
			and not stations._fire_light.is_visible_in_tree() and _floor_holds()) and ok
		await t._shot("daynight_night_low_fight")
		for tier: int in [Quality.HIGH, Quality.MEDIUM]:
			Quality.set_level(tier)
			await t._wait(_visual_s)
			ok = t._expect("the ashes stay dark on %s" % Quality.NAMES[tier],
				not stations.flame().is_visible_in_tree() and not stations._fire_light.is_visible_in_tree()) and ok
		var relit: bool = main.fight.rebuild_fire()
		await t._wait(_visual_s)
		ok = t._expect("rebuilding the fire at night restores its flame and light on Medium",
			relit and not world.fire_out and stations.flame().is_visible_in_tree()
			and stations._fire_light.is_visible_in_tree() and _floor_holds()) and ok
	main.player.frozen = false
	t._reset_fight()
	Save.hold_flush = false
	return ok


func _foe_in_view(fire_range: float) -> bool:
	for foe: Node3D in get_tree().get_nodes_in_group("foes"):
		if foe.global_position.length() > fire_range and main.cam.is_position_in_frustum(foe.global_position):
			return true
	return false


func _floor_holds() -> bool:
	var env: Environment = world.env
	var color: Color = env.ambient_light_color
	return env.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR \
		and (env.ambient_light_energy >= _floor_energy or is_equal_approx(env.ambient_light_energy, _floor_energy)) \
		and (color.r >= _floor_color.r or is_equal_approx(color.r, _floor_color.r)) \
		and (color.g >= _floor_color.g or is_equal_approx(color.g, _floor_color.g)) \
		and (color.b >= _floor_color.b or is_equal_approx(color.b, _floor_color.b)) \
		and (env.fog_density <= _fog_cap or is_equal_approx(env.fog_density, _fog_cap)) \
		and world.fill_light.light_energy > 0.0


func _night_s() -> float:
	var night: Dictionary = _keys.back()
	return (float(night["at_s"]) + float(night["hold_until_s"])) / 2.0


func _set_time(seconds: float) -> void:
	Save.camp_day_s = seconds
	world.apply_day_night()


func _sky() -> ProceduralSkyMaterial:
	return world.env.sky.sky_material as ProceduralSkyMaterial


func _color(value: Variant) -> Color:
	if value is Array:
		var rgb: Vector3 = _rgb(value as Array)
		return Color(rgb.x, rgb.y, rgb.z)
	return Color.html(String(value))


func _rgb(values: Array) -> Vector3:
	return Vector3(float(values[0]), float(values[1]), float(values[2]))
