extends Node
const ArrowShot := preload("res://scripts/acorn.gd")
const CatArrow := preload("res://scripts/arrow.gd")
const BASE := Vector3(-3.0, 0, 14.0)
var t
var main
var d


func _x(what: String, ok: bool, extra := {}) -> void:
	t._expect(what, ok, extra)


func _clear_foes() -> void:
	for arrow in get_tree().get_nodes_in_group("tower_arrows"):
		arrow.queue_free()
		arrow.remove_from_group("tower_arrows")
	for foe in get_tree().get_nodes_in_group("foes"):
		foe.dead = true
		foe.remove_from_group("foes")
		foe.remove_from_group("enemies")
		foe.queue_free()


func _foe(at: Vector3):
	var foe = main.fight.spawn("thornling", at, 0)
	foe.hp = 100000.0
	foe.max_hp = foe.hp
	foe.set_physics_process(false)
	return foe


func _spawn(level: int) -> Dictionary:
	_clear_foes()
	d._clear()
	return d._spawn("tower", BASE, 0.37, [], level)       # H6: each piece has its own level


func run() -> void:
	d = main.defences
	main.hud.hide_card()
	main.fight.active = false
	main.fight.in_wave = false
	main.fight.set_physics_process(false)
	main.player.set_process(false)
	if main.mount:
		main.mount.set_process(false)
	if main.pet:
		main.pet.set_process(false)
	main.player.global_position = BASE + Vector3(2.0, 0, 0)
	var levels: Array = Data.defence_info("tower")["levels"]
	var ranges: Array = []
	var damages: Array = []
	var scales: Array = []
	for lv in range(1, 6):
		var p := _spawn(lv)
		var tower = p["node"]
		ranges.append(float(levels[lv - 1]["range"]))
		damages.append(float(levels[lv - 1]["damage"]))
		scales.append(float(levels[lv - 1]["arrow_scale"]))
		_x("tower level %d uses its own model, a movable string and a larger Twig arrow" % lv, String(tower.name).begins_with("acorn_tower_%d" % lv) and tower._string != null and tower._loaded != null and tower._loaded.scale.x > 1.0)
		await t._wait(0.12)
		var loading: float = tower.load_progress
		_x("tower level %d visibly loads before it can shoot" % lv, loading > 0.0 and loading < 1.0 and tower.shots == 0)
		await t._wait(0.35)
		_x("tower level %d holds a loaded arrow and drawn string while idle" % lv, tower.load_progress == 1.0 and tower._loaded.visible and is_equal_approx(float(tower._string.get_shader_parameter("draw")), 1.0))
		main.closeup_at = tower
		main.closeup = Vector3(4.0, 4.0, 5.2)
		await t._wait(0.1)
		await t._shot("acorn_level_%d_loaded" % lv)
		var root_transform: Transform3D = tower.transform
		var range_edge: float = float(levels[lv - 1]["range"]) - 0.1
		# Front, sides, rear and intermediate bearings: real arrow collisions and full upgraded damage.
		for bearing in [0, 45, 90, 135, 180, 225, 270, 315]:
			_clear_foes()
			var angle := deg_to_rad(float(bearing))
			var foe = _foe(BASE + Vector3(sin(angle), 0, cos(angle)) * range_edge)
			var hit: bool = await t._until(func(): return float(foe.hp) < 100000.0, 1.8)
			var dealt: float = 100000.0 - float(foe.hp)
			_x("tower %d hits at %d degrees near its range edge" % [lv, bearing], hit and dealt >= float(levels[lv - 1]["damage"]) - 0.001 and tower.transform.is_equal_approx(root_transform), {"damage": dealt, "range": range_edge})
		_clear_foes()
		var close = _foe(BASE + Vector3(0, 0, 0.65))
		var close_hit: bool = await t._until(func(): return float(close.hp) < 100000.0, 1.8)
		_x("tower %d pitches down to hit a close enemy" % lv, close_hit)
		_clear_foes()
		var outside = _foe(BASE + Vector3(0, 0, float(levels[lv - 1]["range"]) + 0.1))
		var shots: int = tower.shots
		await t._wait(0.8)
		_x("tower %d refuses a target outside its upgraded range" % lv, tower.shots == shots and outside.hp == 100000.0 and tower.target == null)
	_x("every upgrade increases range, damage and arrow size", ranges == [5.0, 6.0, 7.0, 8.0, 9.0] and damages == [8.0, 14.0, 24.0, 36.0, 44.0] and scales == [1.6, 1.8, 2.0, 2.2, 2.4])
	# A visible release, recoil and reload, then an upgrade/repair during a partial loading cycle.
	var p := _spawn(3)
	var tower = p["node"]
	var foe = _foe(BASE + Vector3(0, 0, 5.0))
	var flight_view := Node3D.new()
	main.add_child(flight_view)
	flight_view.global_position = BASE + Vector3(0, 0, 2.0)
	main.closeup_at = flight_view
	main.closeup = Vector3(4.0, 5.0, 8.0)
	await t._until(func(): return tower.shots > 0, 1.0)
	_x("release hides the loaded arrow and recoils the crossbow", not tower._loaded.visible and tower._kick > 0.0)
	await t._shot("acorn_arrow_release")
	var arrows := get_tree().get_nodes_in_group("tower_arrows")
	_x("the launched arrow reuses the Twig model with a larger scale and trail", not arrows.is_empty() and arrows[0]._model.scale.x == 2.0 and arrows[0].length > CatArrow.length_for("twig") and not arrows[0]._trail.is_empty())
	await t._wait(0.18)
	await t._shot("acorn_arrow_flight")
	await t._wait(0.12)
	_x("the arrow returns to the rail and the string draws back during reload", tower._loaded.visible and tower.load_progress > 0.0 and tower.load_progress < 1.0)
	await t._shot("acorn_arrow_reload")
	_clear_foes()
	# H6: one real upgrade of this target (the Workshop at level 4, every raid mission won, leaves and timber in hand)
	Save.leaves = 100000
	Save.timber = 100000
	for i in Data.mission_count():
		if not Save.missions_done.has(String(Data.mission(i)["id"])):
			Save.missions_done.append(String(Data.mission(i)["id"]))
	Save.stations["workshop"] = 4
	Save.camp_level = maxi(Save.camp_level, 4)
	main.stations.refresh("all")
	var upgraded: bool = d.upgrade_placed("tower", int(p["id"]), Vector2i(-1, -1), 3)
	tower = p["node"]
	_x("the upgrade of this one tower went through (level 3 to 4)", upgraded and d.piece_level(p) == 4, {"level": d.piece_level(p)})
	_x("upgrading mid-reload replaces the model and loads the new tier arrow", tower.level == 4 and tower.shots == 0 and is_equal_approx(float(tower._loaded.scale.x), 2.2) and tower._string != null,
		{"level": tower.level, "shots": tower.shots, "arrow_scale": tower._loaded.scale.x, "string": tower._string != null})
	d.hurt_piece(int(p["id"]), 999999)
	var stopped: int = tower.shots
	_foe(BASE + Vector3(0, 0, 3.0))
	await t._wait(0.6)
	_x("a broken tower hides its arrow and cannot shoot", tower.shots == stopped and not tower._loaded.visible)
	Save.leaves = 100000
	Save.timber = 100000
	var repaired: bool = d.repair_tower(p)
	var repaired_hit: bool = await t._until(func(): return tower.shots > stopped, 1.0)
	_x("a repaired tower reloads and resumes shooting", repaired and repaired_hit)
	_clear_foes()
	# Pause and swept collision: an arrow cannot jump over a foe on a long frame, hit twice or turn after firing.
	var shot := Node3D.new()
	shot.set_script(ArrowShot)
	main.add_child(shot)
	shot.launch(main, BASE + Vector3(0, 0.6, 0), Vector3.BACK, 1)
	var start: Vector3 = shot.global_position
	main.frozen = true
	await t._wait(0.2)
	_x("paused gameplay freezes tower arrows", is_instance_valid(shot) and shot.global_position.is_equal_approx(start))
	main.frozen = false
	var intercepted = _foe(BASE + Vector3(0, 0, 1.2))
	var beyond = _foe(BASE + Vector3(0, 0, 2.1))
	shot._physics_process(0.1)
	_x("a long-frame arrow hits only the first intercepted foe once", absf(100000.0 - float(intercepted.hp) - 8.0) < 0.001 and beyond.hp == 100000.0)
	_clear_foes()
	d._clear()
	main.closeup = Vector3.ZERO
	main.closeup_at = null
	flight_view.queue_free()
	main.player.set_process(true)
	main.fight.set_physics_process(true)
	if main.mount:
		main.mount.set_process(true)
	if main.pet:
		main.pet.set_process(true)
	t._log("acorn towers done")
