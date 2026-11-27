extends Node
## Joystick-directed mounts, the wider firing arc, real arrows and seated pose limits on both looks.

const BASE := Vector3(-1.5, 0, 12)
const BEARINGS := [0, 80, 100, 130, 139, -80, -100, -130, -139, 141, -141, 180]
const ArrowScript := preload("res://scripts/arrow.gd")

var t
var main


func run() -> void:
	Save._endgame_seed()
	main.player.invincible = true
	main.raids.manual = true
	main.on_camp_grown()
	if main.pet != null:
		main.pet.set_physics_process(false)
	main.joystick.force = true
	await t._wait(0.3)
	for look in ["thistle", "bramblewool"]:
		Save.mount_look = look
		main.mount.set_look()
		main.set_riding(true, false)
		for bearing in BEARINGS:
			await _reset()
			var angle := deg_to_rad(float(bearing))
			var enemy = _foe(BASE + Vector3(sin(angle), 0, cos(angle)) * 3.5)
			if absi(bearing) > 140:
				var before_rear: int = main.player.shots_fired
				await t._wait(0.8)
				t._expect("%s does not acquire or shoot beyond the 280-degree mounted arc (%d)" % [look, bearing], main.player.target == null and main.player.shots_fired == before_rear and absf(main.mount.rotation.y) < 0.01)
				continue
			var result: Dictionary = await _watch(enemy, 2.8)
			t._expect("%s locks and shoots at %d degrees" % [look, bearing], result["locked"] and result["fired"] and result["hit"], result)
			t._expect("%s aims with the torso above a forward-facing seat at %d degrees" % [look, bearing], result["torso_twist"] < deg_to_rad(110.0) and result["root_turn"] < 0.03 and result["seat_turn"] < deg_to_rad(15.0) and result["pose_weight"] > 0.99, result)
			if absi(bearing) == 139:
				t._expect("%s keeps hips and feet facing the mount during the %d-degree rear shot" % [look, bearing], result["seat_turn"] < deg_to_rad(15.0) and result["foot_heading"] < deg_to_rad(20.0) and result["root_turn"] < 0.03, result)
				await _shot("mounted_%s_arc_%d" % [look, bearing])
		await _moving(look, Vector2(-0.5, 0), "left")
		await _moving(look, Vector2(0.5, 0), "right")
		await _circle(look)
		await _charge(look)
		await _dismount(look)
		await _arc_edge(look)
	await _outfits()
	await _reset()
	main.set_riding(false, false)
	var enemy = _foe(BASE + Vector3(0, 0, -3.5))
	var before: int = main.player.shots_fired
	await t._until(func(): return main.player.shots_fired > before, 2.5)
	t._expect("on-foot targeting still acquires an enemy behind", main.player.target == enemy and main.player.shots_fired > before)
	_clear()
	main.joystick.force = false
	main.closeup = Vector3.ZERO
	Save.mount_look = "thistle"
	main.mount.set_look()
	Save.save_game()
	await t._wait(0.3)


func _reset() -> void:
	_clear()
	main.joystick.forced = Vector2.ZERO
	main.mount._stop_move()
	main.player.global_position = BASE
	main.player.facing = 0.0
	main.player.rotation.y = 0.0
	main.mount.rotation.y = 0.0
	main.mount._track = BASE
	main.mount._spd = 0.0
	await t._wait(0.3)
	main.mount.rotation.y = 0.0
	main.player.facing = 0.0
	main.player.rotation.y = 0.0


func _clear() -> void:
	main.player.target = null
	for child in main.get_children():
		if child.get_script() == ArrowScript:
			child.queue_free()
	for enemy in get_tree().get_nodes_in_group("foes"):
		enemy.dead = true
		enemy.remove_from_group("foes")
		enemy.remove_from_group("enemies")
		enemy.queue_free()


func _foe(at: Vector3):
	var enemy = main.fight.spawn("thornling", at, 0)
	main.hud.hide_card()
	enemy.hp = 1000000.0
	enemy.max_hp = enemy.hp
	enemy.set_physics_process(false)
	return enemy


func _watch(enemy, seconds: float, travel := false) -> Dictionary:
	var shots: int = main.player.shots_fired
	var health: float = enemy.hp
	var result := {"locked": false, "fired": false, "hit": false, "torso_twist": 0.0, "body_turn": 0.0, "pose_weight": 0.0, "root_turn": 0.0, "seat_turn": 0.0, "foot_heading": 0.0}
	var elapsed := 0.0
	while elapsed < seconds:
		if travel:
			enemy.global_position = main.player.global_position + Vector3(0, 0, 3.5)
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		result["locked"] = bool(result["locked"]) or main.player.target == enemy
		result["fired"] = main.player.shots_fired > shots
		result["hit"] = enemy.hp < health
		result["pose_weight"] = float(main.player.tree.get("parameters/seat_mix/blend_amount"))
		if elapsed > 0.4 and result["pose_weight"] > 0.99:
			var sk: Skeleton3D = main.player.skeleton
			var hips := _yaw(sk, "hips")
			var chest := _yaw(sk, "chest")
			result["torso_twist"] = maxf(float(result["torso_twist"]), absf(wrapf(chest - hips, -PI, PI)))
			var root_turn := wrapf(main.player.rotation.y - main.mount.rotation.y, -PI, PI)
			var hip_heading := wrapf(root_turn + hips, -PI, PI)
			result["root_turn"] = maxf(float(result["root_turn"]), absf(root_turn))
			result["seat_turn"] = maxf(float(result["seat_turn"]), absf(hip_heading))
			for side in ["L", "R"]:
				var foot := sk.global_basis * sk.get_bone_global_pose(sk.find_bone("foot." + side)).basis.y
				var foot_heading: float = atan2(foot.x, foot.z) - main.mount.rotation.y
				result["foot_heading"] = maxf(float(result["foot_heading"]), absf(wrapf(foot_heading, -PI, PI)))
		result["body_turn"] = maxf(float(result["body_turn"]), absf(wrapf(main.player.facing - main.mount.rotation.y, -PI, PI)))
		if not travel and elapsed > 1.1 and result["fired"] and result["hit"]:
			break
	return result


func _yaw(sk: Skeleton3D, name: String) -> float:
	var b := sk.find_bone(name)
	var basis := sk.get_bone_global_pose(b).basis * sk.get_bone_global_rest(b).basis.inverse()
	return atan2(basis.z.x, basis.z.z)


## A held target must stop receiving new shots as soon as it crosses the strict 140-degree half-arc.
func _arc_edge(look: String) -> void:
	for side in [-1.0, 1.0]:
		await _reset()
		var inside: float = deg_to_rad(139.0) * side
		var enemy = _foe(BASE + Vector3(sin(inside), 0, cos(inside)) * 3.5)
		var before: int = main.player.shots_fired
		await t._until(func(): return main.player.shots_fired > before, 2.5)
		var acquired: bool = main.player.target == enemy and main.player.shots_fired > before
		var outside: float = deg_to_rad(141.0) * side
		enemy.global_position = BASE + Vector3(sin(outside), 0, cos(outside)) * 3.5
		await t._wait(0.08)
		var stopped: int = main.player.shots_fired
		await t._wait(0.8)
		t._expect("%s releases a held %s target outside the 280-degree arc and stops shooting" % [look, "left" if side > 0.0 else "right"], acquired and main.player.target == null and main.player.shots_fired == stopped)


func _dismount(look: String) -> void:
	await _reset()
	var angle := deg_to_rad(139.0)
	var enemy = _foe(BASE + Vector3(sin(angle), 0, cos(angle)) * 3.5)
	await t._wait(1.0)
	main.set_riding(false, false)
	var before: int = main.player.shots_fired
	await t._wait(0.1)
	var sk: Skeleton3D = main.player.skeleton
	var shaft := sk.global_basis * sk.get_bone_global_pose(sk.find_bone("arrow")).basis.z
	var to: Vector3 = enemy.global_position - main.player.global_position
	var arrow_error := absf(wrapf(atan2(shaft.x, shaft.z) - atan2(to.x, to.z), -PI, PI))
	await t._wait(0.8)
	# The loop can be re-nocking during the hop: use the same angular allowance as the existing shot release gate.
	t._expect("%s dismounts during a rear shot without turning the upper body twice" % look, arrow_error < main.player.FIRE_CONE and main.player.shots_fired > before and not main.player.riding, {"arrow_error": arrow_error})
	main.set_riding(true, false)
	await t._wait(0.3)


func _outfits() -> void:
	for outfit in ["dusk_ranger", "nightfall_ranger"]:
		Save.cat_skin = outfit
		Save.bow = "ember" if outfit == "dusk_ranger" else "frost"
		main.player.apply_skin()
		for bearing in [-139, 139]:
			await _reset()
			var angle := deg_to_rad(float(bearing))
			var enemy = _foe(BASE + Vector3(sin(angle), 0, cos(angle)) * 3.5)
			var result := await _watch(enemy, 2.8)
			t._expect("%s rear shot %d keeps its bow, hits and forward-facing seat" % [outfit, bearing], result["hit"] and result["fired"] and result["pose_weight"] > 0.99 and result["torso_twist"] < deg_to_rad(110.0) and result["seat_turn"] < deg_to_rad(15.0), result)
			await _shot("rear_%s_%d" % [outfit, bearing])
	Save.cat_skin = "original"
	Save.bow = "twig"
	main.player.apply_skin()


func _moving(look: String, direction: Vector2, name: String) -> void:
	await _reset()
	var enemy = _foe(BASE + Vector3(0, 0, 3.5))
	await t._wait(0.3)
	main.joystick.forced = direction
	var start: Vector3 = main.player.global_position
	var result := await _watch(enemy, 1.3, true)
	var moved: Vector3 = main.player.global_position - start
	var wanted := Vector3(direction.x, 0, direction.y).normalized()
	var heading_error := absf(wrapf(main.mount.rotation.y - atan2(direction.x, direction.y), -PI, PI))
	t._expect("%s steers and shoots while moving %s" % [look, name], result["fired"] and moved.dot(wanted) > 0.4 and heading_error < 0.08, result)
	t._expect("%s runs forward along the thumb's %s heading" % [look, name], main.mount.anim.current_animation == "Run" and main.mount.anim.speed_scale > 0.0)
	await _shot("mounted_%s_%s" % [look, name])
	main.joystick.forced = Vector2.ZERO


func _circle(look: String) -> void:
	await _reset()
	var enemy = _foe(BASE + Vector3(0, 0, 3.5))
	var before: int = main.player.shots_fired
	var elapsed := 0.0
	var dropped_rear := false
	var reacquired := false
	while elapsed < 3.0:
		var angle := elapsed * TAU / 3.0
		enemy.global_position = main.player.global_position + Vector3(sin(angle), 0, cos(angle)) * 3.5
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		if absf(wrapf(angle, -PI, PI)) > deg_to_rad(165.0):
			dropped_rear = dropped_rear or main.player.target == null
		if elapsed > 2.1:
			reacquired = reacquired or main.player.target == enemy
	t._expect("%s drops a rear target and reacquires it in the wider arc" % look, dropped_rear and reacquired and main.player.shots_fired > before,
		{"dropped": dropped_rear, "reacquired": reacquired, "shots": main.player.shots_fired - before, "heading": main.mount.rotation.y})


func _charge(look: String) -> void:
	await _reset()
	var front = _foe(BASE + Vector3(0, 0, 2.5))
	Save.saddlery["skills"]["ram"] = 1
	# H5: the mount fights only with the skills in its three circles (Data.active_skill_level): Ram goes in one for this
	# check, and the circles are put back as they were afterwards
	var keep_slots: Variant = Save.saddlery.get("skill_slots", [])
	Save.saddlery["skill_slots"] = ["ram", "", ""]
	main.mount.cooldowns.clear()
	main.mount.gap = 0.0
	var started: bool = main.mount.try_move("ram")
	var heading: float = main.mount.rotation.y
	var rear = _foe(BASE + Vector3(0, 0, -3))
	main.player.target = rear
	await t._wait(0.1)
	t._expect("%s finishes Ram along its committed heading" % look, started and main.mount.moving() == "ram" and absf(wrapf(main.mount.rotation.y - heading, -PI, PI)) < 0.001)
	main.mount._stop_move()
	Save.saddlery["skills"].clear()
	Save.saddlery["skill_slots"] = (keep_slots as Array).duplicate() if keep_slots is Array else []
	front.dead = true


func _shot(name: String) -> void:
	main.closeup = Vector3(-2.8, 2.8, 4.3).rotated(Vector3.UP, main.mount.rotation.y)
	await t._wait(0.15)
	await t._shot(name)
	main.closeup = Vector3(-2.8, 2.8, 4.3).rotated(Vector3.UP, main.player.facing)
	await t._wait(0.1)
	await t._shot(name + "_rider_view")
	main.closeup = Vector3.ZERO
