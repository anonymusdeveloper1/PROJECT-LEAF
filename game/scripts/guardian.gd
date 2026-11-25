extends Node3D
## The Moss Warden, the camp's guardian (Phase C): a big, slow golem of mossy stone that sleeps by the Guardian Stone
## east of the camp until the cat frees it in the Gloomwood (`stations.free_guardian()`). In a wave it goes for whatever attacks the camp first
## (buildings, barricades, towers, the campfire), punches, and slams the ground when foes crowd it; enemies that find
## it in their way fight it. Knocked down it is a heap of stones that pulls itself together after a while of mission
## time (twice as fast with the cat beside it), or whole at the next breather. Between missions it sits by its stone.
## It is never in the groups "foes" or "enemies": nothing shoots at it, and a wave never waits for it.
## Every number is in balance.json "guardian" (Data.guardian_*); a look (balance looks.guardian) changes only the model
## and its colours. Model: res://assets/companions/<look>/<look>.glb with <look>.json (clips Idle, Walk, Punch, Slam,
## Hit, Crumble, Reform, Sit; events Punch.hit, Slam.impact; jig.* spring chains). Until it exists a faceted
## placeholder stands in (arm tweens for the punch and the slam, a squash for the heap).

var main
var model: Node3D
var anim: AnimationPlayer
var meta: Dictionary = {}
var _body: Node3D                 # the model, or the placeholder's body (what squashes into a heap)
var _arms: Array = []             # the placeholder's arm pivots: [left, right]
var _arm_tws: Array = []
var _squash_tw: Tween
var home := Vector3.ZERO          # where it sits between missions, beside its stone
var post := Vector3.ZERO          # where it stands in a mission when it has nothing to fight
var hp := 0.0
var _max := 1.0
var radius := 0.6
var state := "sleep"              # sleep, rest, walk, idle, punch, slam, hit, down, rise
var target = null
var _near: Array = []             # non-flier foes within 3 m (refreshed 4 times a second)
var _think_t := 0.0
var _act_t := 0.0
var _act_len := 0.0
var _act_event := 0.0
var _act_done := false
var _punch_cd := 0.0
var _slam_cd := 0.0
var _down_t := 0.0                # seconds of mission time before it pulls itself together
var _down_total := 30.0
var _help_fx_t := 0.0
var _flash_t := 0.0
var _dmg_acc := 0.0               # damage numbers are summed and shown every number_every seconds
var _dmg_t := 0.0
var _rubble: Array = []
var _lane := -1                   # the trail it holds in this mission (-1: it guards the camp)
var _home_t := 0.0
var _detour := Vector3.ZERO           # stepping round something solid in the way
var _detour_t := 0.0
var _path: Array = []                 # waypoints to a fixed goal (its post, its home), round the camp's buildings
var _path_goal := Vector3(1e9, 0, 1e9)
var _prog_t := 0.0                    # following a path and getting no closer: plan again
var _prog_d := 0.0
static var _grid: AStarGrid2D         # the camp's walkable ground for the Warden (rebuilt when a footprint changes)
static var _grid_key := ""
const GRID := 0.5                     # metres per cell
const GRID_HALF := 11.0               # the grid covers the camp out to 11 m: posts, home and the Last Stand
var _t := 0.0
var helping := false              # the cat stands by the heap (the health bar shows "x2")
var hit_t := 0.0                  # seconds left of "was hit just now" (the health bar shows)
var kills := 0                    # counted for the tests
var slams := 0
var downs := 0
var dealt := 0.0


func _g(k: String) -> float:
	return float(Data.b["guardian"][k])


func setup(m, at: Vector3) -> void:
	main = m
	home = at
	post = at
	position = at
	rotation.y = 0.0
	radius = _g("radius")
	_load_model()
	refresh_stats()
	Fx.blob(self, 0.75)
	if Data.guardian_awake():
		state = "rest"
		_play("Sit")
	else:
		state = "sleep"
		_heap(true, true)


# ---------------------------------------------------------------- model
func _load_model() -> void:
	var id := Save.guardian_look
	var base := "res://assets/companions/%s/%s" % [id, id]
	if ResourceLoader.exists(base + ".glb"):
		model = (load(base + ".glb") as PackedScene).instantiate()
		if FileAccess.file_exists(base + ".json"):
			var j = JSON.parse_string(FileAccess.get_file_as_string(base + ".json"))
			if typeof(j) == TYPE_DICTIONARY:
				meta = j
		Props.apply_vc(model)
		add_child(model)
		_body = model
		anim = _find(model, "AnimationPlayer") as AnimationPlayer
		if anim:
			for c in ["Idle", "Walk", "Sit"]:
				if anim.has_animation(c):
					anim.get_animation(c).loop_mode = Animation.LOOP_LINEAR
			_play("Idle")
		var sk := _find(model, "Skeleton3D") as Skeleton3D
		if sk and meta.has("spring_chains") and Quality.springs():
			_springs(sk, meta["spring_chains"])
	else:
		_placeholder()
	_body.set_meta("base_scale", Vector3.ONE)
	Props.set_skin(_body, Data.look("guardian", id), Data.skin("guardian", id, Save.guardian_skin))


## Until the Meshy model is made: a grey-blue stone body, a moss cape, long arms with big fists, stump legs, a sapling
## and two amber eyes. The arms are separate pivots, so the punch and the slam can swing them.
func _placeholder() -> void:
	_body = Node3D.new()
	add_child(_body)
	var stone := Color(0.56, 0.61, 0.68)
	var stone_d := Color(0.45, 0.5, 0.57)
	var moss := Color(0.42, 0.7, 0.28)
	var root := Color(0.5, 0.34, 0.2)
	var amber := Color(1.0, 0.8, 0.28)
	var mi := MeshInstance3D.new()
	mi.mesh = Props.build([
		[Props._cyl(0.15, 0.19, 0.5, 6), Props._at(-0.24, 0.25, 0), root],
		[Props._cyl(0.15, 0.19, 0.5, 6), Props._at(0.24, 0.25, 0), root],
		[Props._box(0.7, 0.5, 0.6), Props._at(0, 0.62, -0.02), stone_d],
		[Props._box(0.9, 1.0, 0.7), Props._at(0, 1.0, 0), stone],
		[Props._box(0.2, 0.2, 0.05), Props._at(0, 1.06, 0.36, Vector3(0, 0, PI / 4)), amber],
		[Props._box(1.12, 0.2, 0.86), Props._at(0, 1.52, -0.02), moss],
		[Props._box(0.86, 0.5, 0.12), Props._at(0, 1.24, -0.37), moss.darkened(0.12)],
		[Props._ball(0.28, 0.5, 7), Props._at(0, 1.74, 0.04), stone],
		[Props._ball(0.27, 0.16, 7), Props._at(0, 1.94, 0.02), moss],
		[Props._ball(0.05, 0.06, 5), Props._at(-0.1, 1.76, 0.3), amber],
		[Props._ball(0.05, 0.06, 5), Props._at(0.1, 1.76, 0.3), amber],
		[Props._cyl(0.012, 0.025, 0.2, 4), Props._at(0, 2.08, 0), root],
		[Props._cyl(0.0, 0.07, 0.12, 4), Props._at(-0.06, 2.18, 0, Vector3(0, 0, 0.9), Vector3(1, 1, 0.4)), moss.lightened(0.15)],
		[Props._cyl(0.0, 0.07, 0.12, 4), Props._at(0.06, 2.18, 0, Vector3(0, 0, -0.9), Vector3(1, 1, 0.4)), moss.lightened(0.15)],
	])
	mi.material_override = Props.vc()
	_body.add_child(mi)
	for x in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(x * 0.6, 1.42, 0.0)
		var am := MeshInstance3D.new()
		am.mesh = Props.build([
			[Props._box(0.26, 0.8, 0.28), Props._at(0, -0.38, 0), stone_d],
			[Props._box(0.3, 0.12, 0.32), Props._at(0, -0.55, 0), root],
			[Props._ball(0.22, 0.4, 6), Props._at(0, -0.88, 0.02), stone],
		])
		am.material_override = Props.vc()
		arm.add_child(am)
		_body.add_child(arm)
		_arms.append(arm)


## Another look (or new colours) for the same Warden: only the model changes.
func set_look() -> void:
	_reset_arms()
	if _squash_tw and _squash_tw.is_valid():
		_squash_tw.kill()
	if _body != null:
		_body.queue_free()
	model = null
	anim = null
	meta = {}
	_body = null
	_arms.clear()
	_load_model()
	if state in ["sleep", "down"]:
		_heap(true, true)
	elif state == "rest":
		_play("Sit")
	Fx.petals(main, global_position + Vector3(0, 1.0, 0))


func _springs(sk: Skeleton3D, chains: Array) -> void:
	var sim := SpringBoneSimulator3D.new()
	sk.add_child(sim)
	var ok: Array = []
	for c in chains:
		if sk.find_bone(String(c["root"])) >= 0 and sk.find_bone(String(c["end"])) >= 0:
			ok.append(c)
	sim.setting_count = ok.size()
	for i in ok.size():
		var c: Dictionary = ok[i]
		sim.set_root_bone_name(i, String(c["root"]))
		sim.set_end_bone_name(i, String(c["end"]))
		sim.set_extend_end_bone(i, true)
		sim.set_end_bone_direction(i, SkeletonModifier3D.BONE_DIRECTION_PLUS_Y)
		sim.set_end_bone_length(i, float(c.get("length", 0.08)))
		sim.set_center_from(i, SpringBoneSimulator3D.CENTER_FROM_WORLD_ORIGIN)
		sim.set_stiffness(i, float(c.get("stiffness", 2.0)))
		sim.set_drag(i, float(c.get("drag", 0.4)))
		sim.set_gravity(i, float(c.get("gravity", 0.3)))
		sim.set_gravity_direction(i, Vector3.DOWN)
		sim.set_radius(i, float(c.get("radius", 0.03)))


func _find(n: Node, type: String) -> Node:
	if n.is_class(type):
		return n
	for c in n.get_children():
		var r := _find(c, type)
		if r != null:
			return r
	return null


func _play(clip: String, blend := 0.15) -> void:
	if anim == null or not anim.has_animation(clip):
		return
	if anim.current_animation != clip or not anim.is_playing():
		anim.play(clip, blend)


func _clip_len(clip: String, fallback: float) -> float:
	if anim and anim.has_animation(clip):
		return anim.get_animation(clip).length
	return fallback


func _event(clip: String, ev: String, fallback: float) -> float:
	var e: Dictionary = meta.get("events", {})
	if e.has(clip) and (e[clip] as Dictionary).has(ev):
		return float(e[clip][ev])
	return fallback


func _height() -> float:
	return float(meta.get("height_m", 2.1)) * scale.y


# ---------------------------------------------------------------- numbers
## Health and size by the stone level (and the home level, and a dish). Called when something changes, never per
## frame. In a mission it keeps its share of health; outside one it is whole.
func refresh_stats() -> void:
	var was := _max
	_max = maxf(1.0, Data.guardian_max_hp())
	scale = Vector3.ONE * Data.pick("guardian", "scale_by_level", Data.guardian_level())
	if main != null and main.fight.active and state != "sleep":
		hp = clampf(hp / maxf(was, 1.0) * _max, 0.0, _max)
	else:
		hp = _max


func max_hp() -> float:
	return _max


func up() -> bool:
	return visible and main.fight.active and state in ["idle", "walk", "punch", "slam", "hit"]


## The Well mends the Warden while it stands. Recovery from a knockdown follows its own timer.
func well_mend(share: float) -> void:
	if hp > 0.0 and hp < _max and up():
		hp = minf(_max, hp + _max * share)


func _flat(p: Vector3) -> float:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()


# ---------------------------------------------------------------- what enemies ask
## An enemy close enough to pick a fight with it (enemy.gd, between its own moves).
func taunts(e) -> bool:
	return up() and main.fight.in_wave and _flat(e.global_position) < radius + float(e.radius) + _g("taunt_m")


## An enemy's blow lands: only if the Warden is up and still in reach.
func reachable_from(p: Vector3, reach: float) -> bool:
	return up() and _flat(p) < radius + reach + 0.6


func hurt(amount: int) -> void:
	if not up() or amount <= 0:
		return
	main.fight.busy()
	_dmg_acc += minf(float(amount), hp)             # the number shows what it really lost
	hp -= float(amount)
	hit_t = 2.0
	_flash(true)
	if hp <= 0.0:
		_crumble()
		return
	if float(amount) >= _max * 0.15 and state in ["idle", "walk"]:
		_start("hit")


## A slam, a burst or a stamp round `at`: it hurts the Warden if it stands in it.
func blast(at: Vector3, r: float, amount: int) -> void:
	if up() and _flat(at) < r + radius:
		hurt(amount)


## A charge stopped dead against it (the enemy has already hurt it).
func blocked(at: Vector3) -> void:
	Fx.shockwave(main, at, 1.6, Color(0.7, 0.9, 0.55))
	Fx.text(main, global_position + Vector3(0, _height() + 0.3, 0), "Blocked!", Color(0.75, 1.0, 0.6))
	main.shake(0.25)


## Moves p (a walker of radius r) out of the Warden's circle; the cat never walks through it.
func push_out(p: Vector3, r: float) -> Vector3:
	if not visible:
		return p
	var rr := (radius * 0.8 if state in ["down", "sleep", "rise"] else radius) + r
	var d := Vector2(p.x - global_position.x, p.z - global_position.z)
	var l := d.length()
	if l >= rr:
		return p
	var n := d / l if l > 0.0001 else Vector2(0, 1)
	return Vector3(global_position.x + n.x * rr, p.y, global_position.z + n.y * rr)


# ---------------------------------------------------------------- the camp's calls
## Woken at its stone (the card's Wake, or a mission starting while it sleeps).
func wake() -> void:
	if state != "sleep":
		return
	position = home
	_start("rise")
	main.shake(0.25)
	Fx.dust(main, global_position, 16, 1.6)
	Fx.flower_ring(main, global_position, 1.6)
	Sfx.play("rumble", -4.0)


## Back up whole at once (breathers and chapter breaks).
func refill() -> void:
	if state == "sleep":
		return
	if state in ["down", "rise"]:
		_free_rubble()
		_heap(false, true)
		state = "idle"
		_play("Idle")
	hp = _max
	helping = false


func on_mission_start() -> void:
	if state == "sleep":
		Save.set_flag("warden_awake")
		Save.save_game()
		wake()
		main.hud.banner_later(3.4, "The %s wakes!" % Data.guardian_name(), Color(0.65, 0.95, 0.5), "A big, slow friend: it goes for whatever attacks your camp")
	_free_rubble()
	if state == "down":
		_heap(false, true)
		state = "idle"
	refresh_stats()
	hp = _max
	if state != "rise":
		state = "walk"
	target = null
	_near.clear()
	helping = false
	_punch_cd = 0.0
	_slam_cd = _g("slam_first")
	_home_t = 0.0
	post = _post_spot()


func on_wave_start() -> void:
	if state == "sleep":
		return
	post = _post_spot()


## The mission is over (won, or the camp fell): up and whole, and home to its stone.
func on_mission_end() -> void:
	if state == "sleep":
		return
	_free_rubble()
	_reset_arms()
	if state in ["down", "rise"]:
		_heap(false, true)
	refresh_stats()
	hp = _max
	target = null
	_near.clear()
	_lane = -1
	post = home
	helping = false
	state = "walk"
	_home_t = 0.0
	_play("Walk")


## The trail it holds in the running mission (-1: it guards the camp).
func post_lane() -> int:
	return _lane


## The saved post as the stone card says it.
func post_name() -> String:
	return post_text(Save.guardian_post)


func post_text(p: int) -> String:
	if p < 0:
		return "guards the camp"
	return "holds the %s trail" % String(Data.patch(p)["name"])


## Where it stands with nothing to fight: worked out at the start of a mission and of each wave, not per frame.
func _post_spot() -> Vector3:
	var f = main.fight
	var w = main.world
	if f.last_stand:
		return _ls_spot()
	_lane = -1
	var lanes: Array = f.info().get("lanes", []) if f.mission >= 0 else []
	if f.mode == "raid":
		lanes = main.raids.known_lanes()                 # a Gloom Raid's trails (none while a sneak raid hides)
	var p := Save.guardian_post
	if p >= 0:
		for ln in lanes:
			if int(ln) == p:
				_lane = p
	var spot := Vector3.ZERO
	if _lane >= 0:
		spot = w.edge_point(_lane)                       # the trail's mouth on the firelight's edge
	elif lanes.size() == 1:
		spot = w.patch_dir(int(lanes[0])) * w.camp_r * 0.7
	else:
		var sum := Vector3.ZERO
		for ln in lanes:
			sum += w.patch_dir(int(ln))
		spot = sum.normalized() * w.camp_r * 0.5 if sum.length() >= 0.3 else Vector3(0, 0, -w.camp_r * 0.5)
	spot = w.constrain(spot, radius, false)
	for k in 2:                                          # never on a ring (the signpost's, say)
		for r in main.rings:
			if not is_instance_valid(r) or not r.visible:
				continue
			var d := Vector2(spot.x - r.global_position.x, spot.z - r.global_position.z)
			if d.length() < 1.6:
				var n := d.normalized() if d.length() > 0.01 else Vector2(0, 1)
				spot = Vector3(r.global_position.x + n.x * 1.6, 0, r.global_position.z + n.y * 1.6)
	spot = w.constrain(spot, radius, false)
	spot.y = 0.0
	return spot


## The Last Stand: beside the ashes, on the cat's side.
func _ls_spot() -> Vector3:
	var c: Vector3 = main.player.global_position
	var v := Vector2(c.x, c.z)
	var n := v.normalized() if v.length() > 0.1 else Vector2(0, 1)
	var r: float = main.stations.foot("campfire") + 0.9
	return Vector3(n.x * r, 0, n.y * r)


# ---------------------------------------------------------------- every frame
func _physics_process(delta: float) -> void:
	if main == null or main.frozen or state == "sleep":
		return
	_t += delta
	_punch_cd = maxf(0.0, _punch_cd - delta)
	_slam_cd = maxf(0.0, _slam_cd - delta)
	hit_t = maxf(0.0, hit_t - delta)
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			_flash(false)
	_flush_numbers(delta)
	if state == "down":
		_regrow(delta)
		return
	if state in ["rise", "punch", "slam", "hit"]:
		_act(delta)
		_push_near()
		return
	var f = main.fight
	if not f.active:
		_rest(delta)
		return
	if f.in_wave:
		_think_t -= delta
		if _think_t <= 0.0:
			_think_t = _g("think_s")
			_think()
			if state == "slam":
				_push_near()
				return
		if target != null and (not is_instance_valid(target) or target.dead):
			target = null
		var goal := post
		var spd := _g("speed")
		if target != null:
			var tp: Vector3 = target.global_position
			var to := Vector3(tp.x - global_position.x, 0.0, tp.z - global_position.z)
			var dist := to.length()
			var touch := radius + float(target.radius) + _g("fist_reach")
			if dist < touch and _punch_cd <= 0.0:
				if dist > 0.01:
					rotation.y = atan2(to.x, to.z)
				_start("punch")
				_push_near()
				return
			if dist > 0.01:
				goal = tp - to / dist * touch * 0.9
			if target.wrecking():
				spd *= _g("hurry")
		var arrived := _move(goal, delta, spd, target == null)
		state = "idle" if arrived else "walk"
		if arrived and target != null:
			var tt: Vector3 = target.global_position - global_position
			tt.y = 0.0
			if tt.length() > 0.01:
				_face_dir(tt.normalized(), delta, 8.0)
		_push_near()
		return
	# a breather or a chapter break: back at its post, standing ready, facing out
	target = null
	_near.clear()
	var there := _move(post, delta, _g("speed"))
	state = "idle" if there else "walk"
	if there and Vector2(post.x, post.z).length() > 0.1:
		_face_dir(Vector3(post.x, 0, post.z).normalized(), delta, 3.0)


## Between missions: home to the stone, then it sits; it turns to the cat when the cat comes close.
func _rest(delta: float) -> void:
	target = null
	var to := home - global_position
	to.y = 0.0
	if to.length() > 0.35:
		state = "walk"
		_home_t += delta
		if _home_t > 25.0:                                # a safety net: it never wanders for ever
			Fx.dust(main, global_position, 8, 1.2)
			position = home
			Fx.dust(main, home, 8, 1.2)
		else:
			_move(home, delta, _g("speed"))
		return
	_home_t = 0.0
	position = position.lerp(home, 1.0 - exp(-4.0 * delta))      # into the mossy hollow beside the stone
	if state != "rest":
		state = "rest"
		_walk_look(false, 0.0)
		_play("Sit")
	var face := Vector3(0, 0, 1)
	var cat: Vector3 = main.player.global_position
	if _flat(cat) < 3.0:
		face = Vector3(cat.x - global_position.x, 0, cat.z - global_position.z)
	if face.length() > 0.01:
		_face_dir(face.normalized(), delta, 3.0)


## Walks toward goal (buildings and the lake block it and it slides round them; barricades do not). Walking straight
## into something round it would stop dead, so then it steps round it for a moment; walking to a fixed spot (its post,
## its home) and getting no closer (wedged between two buildings), it tries one side and then the other.
func _move(goal: Vector3, delta: float, spd: float, fixed := true) -> bool:
	var to := goal - global_position
	to.y = 0.0
	var d := to.length()
	if d < 0.12:
		_walk_look(false, 0.0)
		_detour_t = 0.0
		_prog_t = 0.0
		return true
	if fixed:
		var wp := _waypoint(goal, d, delta)
		to = wp - global_position
		to.y = 0.0
		if to.length() < 0.01:
			to = goal - global_position
			to.y = 0.0
	var dir := to.normalized()
	var step_dir := dir
	if _detour_t > 0.0:
		_detour_t -= delta
		step_dir = (dir + _detour * 1.4).normalized()
	var want := step_dir * minf(spd * delta, maxf(to.length(), 0.05) if fixed else d)
	var before := position
	var tried := position + want
	position = main.world.constrain(tried, radius, false)
	position.y = 0.0
	var moved := (position - before).length()
	if _detour_t <= 0.0 and want.length() > 0.0005 and moved < want.length() * 0.35:
		var push := position - tried
		push.y = 0.0
		var side := Vector3(-dir.z, 0, dir.x)
		if push.length() > 0.0001:
			var tang := Vector3(-push.z, 0, push.x).normalized()
			side = tang if tang.dot(dir) >= 0.0 else -tang
		_detour = side
		_detour_t = 0.8
	_face_dir(step_dir, delta, 5.0)
	var spd_now := moved / maxf(delta, 0.0001)
	_walk_look(spd_now > 0.05, spd_now)
	return false


## The next point to walk to on the way to a fixed goal: a path round the camp's buildings and the lake, planned when
## the goal moves (a new post, home, the Last Stand) or when it stops getting closer; a straight line when there is
## no grid there or no path.
func _waypoint(goal: Vector3, d: float, delta: float) -> Vector3:
	if goal.distance_to(_path_goal) > 1.0:
		_plan(goal)
	_prog_t += delta
	if _prog_t > 1.2:
		if _prog_d - d < 0.3:
			_plan(goal)                                  # stuck (something new in the way): plan again
		_prog_t = 0.0
		_prog_d = d
	while not _path.is_empty():
		var w: Vector3 = _path[0]
		if Vector2(w.x - global_position.x, w.z - global_position.z).length() < 0.35 and _path.size() > 1:
			_path.pop_front()
		else:
			break
	return _path[0] if not _path.is_empty() else goal


func _plan(goal: Vector3) -> void:
	_path_goal = goal
	_path.clear()
	_prog_t = 0.0
	_prog_d = Vector2(goal.x - global_position.x, goal.z - global_position.z).length()
	var a := _walk_grid()
	var n := int(GRID_HALF * 2.0 / GRID)
	var from := _cell(global_position)
	var to := _cell(goal)
	if a == null or from.x < 0 or from.y < 0 or from.x >= n or from.y >= n or to.x < 0 or to.y < 0 or to.x >= n or to.y >= n:
		return
	var from_solid := a.is_point_solid(from)
	var to_solid := a.is_point_solid(to)
	a.set_point_solid(from, false)                       # it may stand inside a footprint (its hollow by the stone)
	a.set_point_solid(to, false)
	var ids := a.get_id_path(from, to)
	a.set_point_solid(from, from_solid)
	a.set_point_solid(to, to_solid)
	for k in range(1, ids.size() - 1):
		var c: Vector2i = ids[k]
		_path.append(Vector3(-GRID_HALF + (c.x + 0.5) * GRID, 0, -GRID_HALF + (c.y + 0.5) * GRID))
	_path.append(goal)


func _cell(p: Vector3) -> Vector2i:
	return Vector2i(int(floor((p.x + GRID_HALF) / GRID)), int(floor((p.z + GRID_HALF) / GRID)))


## The walkable cells, built once and again only when a footprint is added, moved or taken away.
func _walk_grid() -> AStarGrid2D:
	var w = main.world
	var key := "%d" % w.circles.size()
	var sum := 0.0
	for c in w.circles:
		sum += (c[0] as Vector2).x * 3.1 + (c[0] as Vector2).y * 1.7 + float(c[1])
	key += "|%.3f" % sum
	if _grid != null and key == _grid_key:
		return _grid
	var n := int(GRID_HALF * 2.0 / GRID)
	var a := AStarGrid2D.new()
	a.region = Rect2i(0, 0, n, n)
	a.cell_size = Vector2(GRID, GRID)
	a.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	a.update()
	var clear := radius + 0.1
	for c in w.circles:
		var cc: Vector2 = c[0]
		var rr := float(c[1]) + clear
		var lo := _cell(Vector3(cc.x - rr, 0, cc.y - rr))
		var hi := _cell(Vector3(cc.x + rr, 0, cc.y + rr))
		for cx in range(maxi(lo.x, 0), mini(hi.x, n - 1) + 1):
			for cy in range(maxi(lo.y, 0), mini(hi.y, n - 1) + 1):
				var p := Vector2(-GRID_HALF + (cx + 0.5) * GRID, -GRID_HALF + (cy + 0.5) * GRID)
				if p.distance_to(cc) < rr:
					a.set_point_solid(Vector2i(cx, cy))
	var lc: Vector3 = w.LAKE_C
	var lr := float(w.LAKE_R) * 1.35 + clear
	var llo := _cell(lc - Vector3(lr, 0, lr))
	var lhi := _cell(lc + Vector3(lr, 0, lr))
	for cx in range(maxi(llo.x, 0), mini(lhi.x, n - 1) + 1):
		for cy in range(maxi(llo.y, 0), mini(lhi.y, n - 1) + 1):
			var q := Vector3(-GRID_HALF + (cx + 0.5) * GRID, 0, -GRID_HALF + (cy + 0.5) * GRID)
			if w.lake_dist(q) < clear:
				a.set_point_solid(Vector2i(cx, cy))
	_grid = a
	_grid_key = key
	return a


func _walk_look(on: bool, spd: float) -> void:
	if anim:
		if on:
			_play("Walk")
			var gs: Dictionary = meta.get("ground_speed_m_per_s", {})
			anim.speed_scale = clampf(spd / maxf(float(gs.get("Walk", 1.15)) * scale.x, 0.05), 0.5, 2.0)
		else:
			if anim.current_animation == "Walk":
				_play("Idle")
			anim.speed_scale = 1.0
		return
	if _body == null or state in ["down", "sleep", "rise"]:
		return
	_body.rotation.z = sin(_t * 5.5) * 0.07 if on else lerpf(_body.rotation.z, 0.0, 0.2)


func _face_dir(dir: Vector3, delta: float, rate: float) -> void:
	if dir.length_squared() > 0.0001:
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), 1.0 - exp(-rate * delta))


## Foes it touches are pushed out of its body (only the foe moves). O(k) over the foes within 3 m.
func _push_near() -> void:
	var me := Vector2(global_position.x, global_position.z)
	for e in _near:
		if not is_instance_valid(e) or e.dead or e.flyer or e.state in ["charge", "dash", "pounce", "dig", "blink"]:
			continue
		var p := Vector2(e.global_position.x, e.global_position.z)
		var d := p - me
		var need := radius + float(e.radius)
		var l := d.length()
		if l < need:
			var n := d / l if l > 0.0001 else Vector2(0, 1)
			var q := me + n * need
			e.global_position = Vector3(q.x, e.global_position.y, q.y)


# ---------------------------------------------------------------- choosing a target (4 times a second)
func _think() -> void:
	var f = main.fight
	if f.last_stand:
		post = _ls_spot()
	_near.clear()
	var best = null
	var best_s := INF
	var slam_r := _g("slam_range")
	var in_slam := 0
	var boss_near := false
	for e in get_tree().get_nodes_in_group("foes"):
		if e.dead or e.flyer:
			continue
		var d := _flat(e.global_position)
		if d < 3.0:
			_near.append(e)
		if not _in_leash(e):
			continue
		if d < slam_r + float(e.radius):
			in_slam += 1
			if e.boss:
				boss_near = true
		var sc := _score(e, d)
		if sc < best_s:
			best_s = sc
			best = e
	target = best
	if _slam_cd <= 0.0 and state in ["idle", "walk"] and (in_slam >= int(_g("slam_min_foes")) or boss_near):
		_start("slam")


## Where its targets may be: round the camp, at the trail it holds, or (Last Stand) near the cat or the ashes.
func _in_leash(e) -> bool:
	var p: Vector3 = e.global_position
	if main.fight.last_stand:
		var reach := _g("last_stand_reach")
		var c: Vector3 = main.player.global_position
		return Vector2(p.x - c.x, p.z - c.z).length() < reach or Vector2(p.x, p.z).length() < reach + main.stations.foot("campfire")
	if _lane >= 0:
		return Vector2(p.x - post.x, p.z - post.z).length() < _g("hold_leash_m")
	return Vector2(p.x, p.z).length() < main.world.camp_r + _g("leash_extra_m")


## Lower is better: its distance, then first whatever is wrecking the camp, then what is hitting the cat nearby.
func _score(e, d: float) -> float:
	if main.fight.last_stand:
		return d
	var s := d
	if e.wrecking():
		s -= 6.0
	if e.hitting_cat() and d < 4.0:
		s -= 2.5
	var p: Vector3 = e.global_position
	if Vector2(p.x, p.z).length() < main.world.camp_r + 1.0:
		s -= 2.0
	if e == target:
		s -= 1.5
	return s


# ---------------------------------------------------------------- moves with a moment of impact
func _start(kind: String) -> void:
	state = kind
	_act_t = 0.0
	_act_done = false
	match kind:
		"punch":
			_act_len = _clip_len("Punch", 1.1)
			_act_event = _event("Punch", "hit", 0.45)
			_punch_cd = _g("fist_every")
			_play("Punch", 0.08)
			_arm_swing("punch")
		"slam":
			_act_len = _clip_len("Slam", 1.6)
			_act_event = _event("Slam", "impact", 0.95)
			_slam_cd = _g("slam_every")
			_play("Slam", 0.1)
			_arm_swing("slam")
			Fx.telegraph_ring(main, global_position, _g("slam_range"), _act_event, Color(0.55, 0.9, 0.4, 0.35))
		"hit":
			_act_len = _clip_len("Hit", 0.45)
			_act_event = 99.0
			_act_done = true
			_play("Hit", 0.05)
			if anim == null:
				Fx.boing(_body, 0.1)
		"rise":
			_act_len = _clip_len("Reform", 1.4)
			_act_event = 99.0
			_act_done = true
			_play("Reform", 0.1)
			_heap(false, false)
	if anim and anim.current_animation != "" and kind in ["punch", "slam", "rise"]:
		anim.seek(0.0, true)


func _act(delta: float) -> void:
	_act_t += delta
	if state == "punch" and target != null and is_instance_valid(target) and not target.dead:
		var to: Vector3 = target.global_position - global_position
		to.y = 0.0
		_face_dir(to.normalized(), delta, 8.0)
	if not _act_done and _act_t >= _act_event:
		_act_done = true
		_impact()
	if _act_t >= _act_len:
		if state == "rise" and not main.fight.active:
			state = "walk"
		else:
			state = "idle"
		_play("Idle")


func _impact() -> void:
	var fwd := Vector3(sin(rotation.y), 0, cos(rotation.y))
	match state:
		"punch":
			var at := global_position + fwd * (radius + 0.45)
			var t = target
			if t != null and is_instance_valid(t) and not t.dead \
					and _flat(t.global_position) < radius + float(t.radius) + _g("fist_reach") + 0.4:
				var dir: Vector3 = t.global_position - global_position
				dir.y = 0.0
				_deal(t, dir.normalized() if dir.length() > 0.01 else fwd, Data.guardian_fist())
				Fx.dust(main, at, 5, 1.0)
				main.shake(0.06)
				Sfx.play("thud", -6.0)
			else:
				Fx.dust(main, at, 5, 1.0)                 # a whiff
		"slam":
			_slam_hits()


func _deal(e, dir: Vector3, amount: float) -> void:
	var before := float(e.hp)
	e.hit(dir, amount)
	dealt += maxf(0.0, before - maxf(float(e.hp), 0.0))
	if e.dead:
		kills += 1


## The ground slam: every non-flier in reach is hit; small ones are dazed a moment (never a boss).
func _slam_hits() -> void:
	var r := _g("slam_range")
	var dmg := Data.guardian_slam()
	var daze_r := _g("daze_radius")
	for e in get_tree().get_nodes_in_group("foes"):
		if e.dead or e.flyer:
			continue
		if _flat(e.global_position) >= r + float(e.radius):
			continue
		var dir: Vector3 = e.global_position - global_position
		dir.y = 0.0
		_deal(e, dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD, dmg)
		if not e.dead and float(e.radius) <= daze_r:
			e.stagger(_g("slam_daze_s"))
	Fx.shockwave(main, global_position, r + 0.3, Color(0.6, 0.9, 0.45))
	Fx.dust(main, global_position, 14, 1.8)
	Fx.text(main, global_position + Vector3(0, _height() + 0.2, 0), String(Data.look("guardian", Save.guardian_look).get("shout", "Rumble!")), Color(0.75, 1.0, 0.55))
	main.shake(0.2)
	Sfx.play("thud", -3.0)
	_punch_cd = maxf(_punch_cd, 0.6)
	slams += 1
	if anim == null:
		Fx.boing(_body, 0.12)


# ---------------------------------------------------------------- knocked down
func _crumble() -> void:
	state = "down"
	hp = 0.0
	target = null
	_near.clear()
	downs += 1
	_down_total = Data.guardian_revive_s()
	_down_t = _down_total
	_help_fx_t = 0.0
	helping = false
	_reset_arms()
	_play("Crumble", 0.1)
	_heap(true, false)
	for k in 4:
		var rk := Props.instance("rock_1")
		var a := TAU * k / 4.0 + randf() * 0.5
		rk.scale = Vector3.ONE * 0.5
		rk.rotation.y = randf() * TAU
		main.add_child(rk)
		rk.global_position = global_position + Vector3(cos(a), 0, sin(a)) * (radius + 0.3)
		_rubble.append(rk)
	Fx.kill(main, global_position + Vector3(0, 0.8, 0), Color(0.6, 0.65, 0.7))
	Fx.dust(main, global_position, 16, 1.6)
	main.shake(0.3)
	Sfx.play("rumble", -4.0)
	main.hud.toast("The %s crumbles!" % Data.guardian_name())
	if not Save.flag("told_warden_down"):
		Save.set_flag("told_warden_down")
		main.hud.tip("It pulls itself together in %d s. Stand next to it to help." % int(round(_down_total)), null)


## Mission time only (never while the game is frozen or between missions); twice as fast with the cat beside it.
func _regrow(delta: float) -> void:
	if not main.fight.active:
		return
	var cat = main.player
	helping = cat.hp > 0 and _flat(cat.global_position) < _g("help_range")
	_down_t -= delta * (_g("help_rate") if helping else 1.0)
	if helping:
		_help_fx_t -= delta
		if _help_fx_t <= 0.0:
			_help_fx_t = 0.4
			Fx.sparkle(main, cat.global_position + Vector3(0, 0.8, 0))
	if _down_t <= 0.0:
		_rise(_g("revive_hp"))


func _rise(share: float) -> void:
	helping = false
	hp = _max * share
	_free_rubble()
	_start("rise")
	Fx.flower_ring(main, global_position, 1.4)
	Sfx.play("rumble", -6.0)


func _free_rubble() -> void:
	for r in _rubble:
		if is_instance_valid(r):
			r.queue_free()
	_rubble.clear()


## The heap of stones (asleep or knocked down), or standing up again. The model plays Crumble / Reform; the
## placeholder squashes to 0.3 of its height.
func _heap(on: bool, quick: bool) -> void:
	if _squash_tw and _squash_tw.is_valid():
		_squash_tw.kill()
	if _body == null:
		return
	if _body.has_meta("boing_tween"):
		var old = _body.get_meta("boing_tween")
		if old is Tween and (old as Tween).is_valid():
			(old as Tween).kill()
	if anim != null:
		if on and anim.has_animation("Crumble"):
			if quick:
				anim.play("Crumble")
				anim.seek(anim.get_animation("Crumble").length, true)
				anim.pause()
			else:
				anim.play("Crumble", 0.1)
		return
	var want := Vector3(1.15, 0.3, 1.15) if on else Vector3.ONE
	_body.rotation.z = 0.0
	if quick:
		_body.scale = want
		return
	_squash_tw = _body.create_tween()
	if on:
		_squash_tw.tween_property(_body, "scale", want, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	else:
		_squash_tw.tween_property(_body, "scale", Vector3(0.92, 1.1, 0.92), 0.9).set_trans(Tween.TRANS_SINE)
		_squash_tw.tween_property(_body, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------- the placeholder's arms
func _arm_swing(kind: String) -> void:
	if anim != null or _arms.size() < 2:
		return
	_reset_arms()
	var e := _act_event
	var rest := maxf(_act_len - e, 0.2)
	if kind == "punch":
		_swing(_arms[1], [[0.7, e * 0.6], [-1.7, e * 0.4], [0.0, rest]])
	else:
		for a in _arms:
			_swing(a, [[-2.9, e * 0.65], [-2.9, e * 0.15], [-0.5, e * 0.2], [0.0, rest]])


func _swing(arm: Node3D, keys: Array) -> void:
	var tw := create_tween()
	for k in keys:
		tw.tween_property(arm, "rotation:x", float(k[0]), maxf(float(k[1]), 0.01)).set_trans(Tween.TRANS_SINE)
	_arm_tws.append(tw)


func _reset_arms() -> void:
	for tw in _arm_tws:
		if tw is Tween and (tw as Tween).is_valid():
			(tw as Tween).kill()
	_arm_tws.clear()
	for a in _arms:
		if is_instance_valid(a):
			(a as Node3D).rotation.x = 0.0


# ---------------------------------------------------------------- hit flash and damage numbers
func _flash(on: bool) -> void:
	if _body:
		Props.set_param(_body, "flash", 1.0 if on else 0.0)
	_flash_t = 0.12 if on else 0.0


func _flush_numbers(delta: float) -> void:
	_dmg_t = maxf(0.0, _dmg_t - delta)
	if _dmg_acc > 0.0 and _dmg_t <= 0.0:
		Fx.number(main, global_position + Vector3(0, _height() + 0.1, 0), _dmg_acc, Color(0.85, 0.82, 0.65))
		_dmg_acc = 0.0
		_dmg_t = _g("number_every")
