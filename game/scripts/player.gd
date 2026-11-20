extends Node3D
## The Cat Ranger. The joystick moves it. Whenever an enemy is within RANGE it faces that enemy and keeps shooting,
## whether it is standing or moving; with no enemy near it lowers the bow.
##
## Clips come from CatRanger.glb (see CatRanger_clips.json next to it). An AnimationTree plays two things at once:
##   legs, hips, tail          Idle / Walk / Run, faster or slower so the feet match the ground speed, and backward
##                             when the cat backs away from what it is shooting at
##   spine and everything up   the Shoot loop while an enemy is near (blended in and out over AIM_BLEND seconds)
## The shooting stance is side-on: the chest is 64 degrees to the right of the aim. So while shooting on the move
## the hips are turned to point the legs along the way the cat is going (body_twist.gd) and the spine is turned back
## by the same amount, which leaves the chest, arms and bow exactly as they were authored.
## The hood, capelet and skirt are not in the clips: cloth.gd simulates them on top, after the body is posed.

## Which hero model to use: "CatRanger" (the first one) or "CatRanger2" (the Meshy remake, same skeleton and clips).
## balance.json "hero_model" picks it; the test flag --cat1 / --cat2 overrides it.
static func hero_base() -> String:
	var args := Data.args()
	var id := "CatRanger2" if args.has("--cat2") else ("CatRanger" if args.has("--cat1") else String(Data.b.get("hero_model", "CatRanger")))
	if not ResourceLoader.exists("res://assets/cat/%s.glb" % id):
		id = "CatRanger"
	return "res://assets/cat/" + id
const ArrowScene := preload("res://assets/cat/CatRanger_Arrow.glb")
const ArrowScript := preload("res://scripts/arrow.gd")
const TwistScript := preload("res://scripts/body_twist.gd")
const ClothScript := preload("res://scripts/cloth.gd")
const RideScript := preload("res://scripts/ride_pose.gd")
const SEAT_DROP := 0.35                                 # m from the cat's feet down to its seat: it sits on the saddle

const MAX_SPEED := 2.6                                  # m/s with the stick fully pushed
const WALK_BELOW := 1.05                                # m/s: slower than this plays Walk
const CLIP_SPEED := {"Walk": 0.65, "Run": 2.143}        # m/s each clip covers at playback speed 1
const SHOOT_LENGTH := 0.8333                            # seconds: one loop of Shoot
const SHOOT_RELEASE := 0.3667                           # seconds into Shoot: the arrow leaves the string
const SHOOT_NOCK := 0.80                                # seconds into Shoot: the next arrow is on the string (frame 25)
const RANGE := 5.5                                      # metres: about what the screen shows
const TURN := 12.0
const MAX_HP := 5
const AIM_BLEND := 0.2                                  # seconds for the bow to come up or go down
const STANCE_HIPS := -0.4206                            # -24.1 deg: where the hips sit in the authored stance
const HIPS_MIN := -2.4260                               # -139 deg and +11 deg: how far the hips may turn from the
const HIPS_MAX := 0.1920                                #   aim, which is 75 deg of twist either way below the chest
const KEEP_GAIT := 0.35                                 # 20 deg: do not swap forward / backward legs for less
const FIRE_CONE := 0.61                                 # 35 deg: hold the arrow until the body has turned this close
const UPPER_FROM := "spine"                             # this bone and everything above it follows the Shoot loop ...
const CLOTH_SIM := true                                 # simulate the hood, capelet and skirt (cloth.gd); -- --no-cloth-sim turns it off
const CLOTH := ["cape.", "hood.", "skirt."]             # ... except the cloth bones, which cloth.gd moves

var main
var model: Node3D
var anim: AnimationPlayer
var tree: AnimationTree
var twist: SkeletonModifier3D
var cloth: Node3D                                       # cloth.gd: the hood, capelet and skirt
var cloth_debug := false
var skeleton: Skeleton3D
var nocked: Node3D                                      # the arrow on the string
var state := "idle"                                     # idle / move / shoot / move_shoot / down
var hp := MAX_HP
var bow_mat: Array = []
var slow_t := 0.0                                       # seconds the cat is slowed (spores)
var reveal_t := 0.0                                     # seconds the cat stays visible after a shot
var target = null
var facing := 0.0
var aim_w := 0.0                                        # 0 bow carried .. 1 shooting
var legs_backward := false
var hips_turn := 0.0                                    # radians the hips are turned from the aim right now
var loco_clip := "Idle"
var loco_scale := 1.0
var shots_fired := 0
var invincible := false                                 # used by the automated test
var riding := false                                     # on Thistle (mount.gd): sits astride, Thistle runs, the cat shoots
var ride_pose: SkeletonModifier3D                       # ride_pose.gd: the legs astride the saddle
var _ride_y := 0.0
var _ride_w := 0.0
var frozen := false
var _was_aiming := false
var _shoot_t := 0.0
var _fired := false
var _invuln := 0.0
var _knock := Vector3.ZERO
var _vc_hero := false                                  # CatRanger2: vertex colours (the vc shader), not textures
var _dash_t := 0.0                                      # Phase E, the Leaf Dash: seconds of the dash left
var _dash_iframe := 0.0                                 # ... nothing can hurt the cat while > 0 (a hit then is a close call)
var _dash_cd := 0.0                                     # ... seconds before the next dash
var _dash_cd_total := 1.4
var _dash_dir := Vector3.ZERO
var _dash_speed := 0.0
var vel := Vector3.ZERO                                 # how fast the cat moves now (the Glowcap leads its lobs with it)
var _vel_from := Vector3.ZERO
var dashes := 0                                         # counted for the tests
var close_calls := 0
var _rod_hold: BoneAttachment3D                         # fishing: the rod in the bow paw (Phase C)
var _rod: Node3D
## The rod in the paw points forward and up, a little out to the side (in the cat's own frame); ROD_XF, the offset on
## the bow-hand bone, is worked out from this when the rod is put in the paw, so it fits any pose the hero idles in.
const ROD_DIR := Vector3(0.2, 0.62, 0.72)               # (out to the bow side, up, forward)


func _ready() -> void:
	model = (load(hero_base() + ".glb") as PackedScene).instantiate()
	_vc_hero = not hero_base().ends_with("/CatRanger")
	if _vc_hero:
		Props.apply_vc(model)                    # the remake is coloured per face, like every other LEAF model
	add_child(model)
	Fx.blob(self, 0.42)
	anim = _find(model, "AnimationPlayer")
	skeleton = _find(model, "Skeleton3D")
	for clip in ["Idle", "Walk", "Run", "Shoot"]:
		anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	# the arrow on the string: the arrow asset rides the bone `arrow` with no offset. The rig aims that bone's Z
	# axis down the shaft (measured in Blender: asset frame = bone frame), and the asset's tip is +Z too.
	var hold := BoneAttachment3D.new()
	skeleton.add_child(hold)
	hold.bone_name = "arrow"
	nocked = Node3D.new()
	hold.add_child(nocked)
	nocked.add_child(ArrowScene.instantiate())
	nocked.visible = false
	ride_pose = SkeletonModifier3D.new()
	ride_pose.set_script(RideScript)
	skeleton.add_child(ride_pose)                       # before the twist, so the seated legs turn with the hips
	twist = SkeletonModifier3D.new()
	twist.set_script(TwistScript)
	skeleton.add_child(twist)
	_build_tree()
	cloth = Node3D.new()
	cloth.set_script(ClothScript)
	cloth.debug = cloth_debug
	cloth.fit_on = not Data.args().has("--no-cloth-fit")
	var args := Data.args()
	add_child(cloth)
	if not CLOTH_SIM or args.has("--no-cloth-sim") or not cloth.setup(skeleton):                       # after the twist, so the cloth hangs from the turned body
		cloth.queue_free()
		cloth = null
	hp = Data.cat_max_hp()
	apply_bow()


## Tints the bow in the cat's paw to the one that is equipped.
func apply_bow() -> void:
	var bow_mesh := model.find_child("SK_CatBow", true, false) as MeshInstance3D
	if bow_mesh == null:
		return
	var tint := Color.html(String(Data.bow_info(Save.bow)["tint"]))
	if _vc_hero:
		bow_mesh.set_instance_shader_parameter("tint", tint)
		return
	for i in bow_mesh.get_surface_override_material_count():
		if not bow_mesh.has_meta("orig_%d" % i):
			bow_mesh.set_meta("orig_%d" % i, bow_mesh.get_active_material(i))
		var orig = bow_mesh.get_meta("orig_%d" % i)
		if orig is BaseMaterial3D:
			var mm := (orig as BaseMaterial3D).duplicate() as BaseMaterial3D
			mm.albedo_color = mm.albedo_color * tint
			if Save.bow != "twig":
				mm.emission_enabled = true
				mm.emission = tint * 0.25
			bow_mesh.set_surface_override_material(i, mm)


## Fishing (fishing.gd): the bow goes away and the rod from the Fishing Spot sits in the bow paw (the bone named
## bones.bow_hand in the hero's clips JSON). A hero without that bone keeps its bow; the rod then stays on the rack.
func set_fishing(on: bool) -> void:
	var bow := model.find_child("SK_CatBow", true, false) as Node3D
	if not on:
		if _rod_hold != null and is_instance_valid(_rod_hold):
			_rod_hold.queue_free()
		_rod_hold = null
		_rod = null
		if bow:
			bow.visible = true
		return
	if has_rod():
		return
	var idx := skeleton.find_bone(_bow_hand())
	if idx < 0:
		return
	if bow:
		bow.visible = false
	_rod_hold = BoneAttachment3D.new()
	skeleton.add_child(_rod_hold)
	_rod_hold.bone_name = skeleton.get_bone_name(idx)
	_rod = Props.instance("fishing_rod")
	_rod_hold.add_child(_rod)
	_rod.transform = _rod_xf(idx)


func has_rod() -> bool:
	return _rod != null and is_instance_valid(_rod)


func rod_tip() -> Node3D:
	return Props.find_part(_rod, "marker_tip") if has_rod() else null


func _bow_hand() -> String:
	var path := hero_base() + "_clips.json"
	if FileAccess.file_exists(path):
		var j = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(j) == TYPE_DICTIONARY:
			return String((j.get("bones", {}) as Dictionary).get("bow_hand", "weapon.L"))
	return "weapon.L"


## ROD_XF: the rod's place on the bone, so that in the world (right now, standing) its grip is in the paw and it points
## along ROD_DIR. The fishing_rod prop points along its own -Z from the grip.
func _rod_xf(idx: int) -> Transform3D:
	var bone_g: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(idx)
	var b := global_transform.basis.orthonormalized()
	var d := (b.x * ROD_DIR.x + Vector3.UP * ROD_DIR.y + b.z * ROD_DIR.z).normalized()
	var z := -d
	var x := Vector3.UP.cross(z).normalized()
	var y := z.cross(x)
	return bone_g.affine_inverse() * Transform3D(Basis(x, y, z), bone_g.origin)


## How far the cat shoots right now. Hidden in grass or a bush it holds its fire until an enemy is close (3 m):
## that first shot is the Ambush.
func _reach() -> float:
	return minf(3.0, Data.cat_range()) if main.hidden else Data.cat_range()


## Hidden in grass or a bush: the cat turns a little see-through.
func set_hidden_look(on: bool) -> void:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var g := mi as GeometryInstance3D
		var tw := create_tween()
		tw.tween_property(g, "transparency", 0.45 if on else 0.0, 0.25)


func revive(at: Vector3) -> void:
	hp = Data.cat_max_hp()
	global_position = at
	_invuln = 1.5
	_knock = Vector3.ZERO
	target = null
	Fx.sparkle(main, global_position + Vector3(0, 0.6, 0))


func _find(node: Node, type: String) -> Node:
	if node.is_class(type):
		return node
	for c in node.get_children():
		var r := _find(c, type)
		if r != null:
			return r
	return null


func _is_upper(bone: int) -> bool:
	while bone >= 0:
		var n := skeleton.get_bone_name(bone)
		for c in CLOTH:
			if n.begins_with(c):
				return false
		if n == UPPER_FROM:
			return true
		bone = skeleton.get_bone_parent(bone)
	return false


func _build_tree() -> void:
	var graph := AnimationNodeBlendTree.new()
	var loco := AnimationNodeTransition.new()
	loco.xfade_time = 0.18
	graph.add_node("loco", loco, Vector2.ZERO)
	var i := 0
	for clip in ["Idle", "Walk", "Run"]:
		var node := AnimationNodeAnimation.new()
		node.animation = clip
		graph.add_node("clip_" + clip, node, Vector2.ZERO)
		loco.add_input(clip)
		graph.connect_node("loco", i, "clip_" + clip)
		i += 1
	graph.add_node("loco_speed", AnimationNodeTimeScale.new(), Vector2.ZERO)
	graph.connect_node("loco_speed", 0, "loco")
	var shoot := AnimationNodeAnimation.new()
	shoot.animation = "Shoot"
	graph.add_node("clip_Shoot", shoot, Vector2.ZERO)
	graph.add_node("shoot_seek", AnimationNodeTimeSeek.new(), Vector2.ZERO)
	graph.connect_node("shoot_seek", 0, "clip_Shoot")
	graph.add_node("shoot_speed", AnimationNodeTimeScale.new(), Vector2.ZERO)
	graph.connect_node("shoot_speed", 0, "shoot_seek")
	var mix := AnimationNodeBlend2.new()
	mix.sync = true                                     # the Shoot loop keeps time even while it is blended out
	mix.filter_enabled = true
	var shoot_anim := anim.get_animation("Shoot")
	for t in shoot_anim.get_track_count():
		var path := shoot_anim.track_get_path(t)
		if path.get_subname_count() == 0:
			continue
		var bone := skeleton.find_bone(path.get_subname(0))
		if bone >= 0 and _is_upper(bone):
			mix.set_filter_path(path, true)
	graph.add_node("mix", mix, Vector2.ZERO)
	graph.connect_node("mix", 0, "loco_speed")
	graph.connect_node("mix", 1, "shoot_speed")
	graph.connect_node("output", 0, "mix")
	tree = AnimationTree.new()
	tree.tree_root = graph
	model.add_child(tree)
	tree.anim_player = tree.get_path_to(anim)
	tree.active = true
	tree.set("parameters/loco/transition_request", "Idle")
	tree.set("parameters/loco_speed/scale", 1.0)
	tree.set("parameters/mix/blend_amount", 0.0)
	tree.set("parameters/shoot_speed/scale", 1.0)


func _loco(clip: String, scale: float) -> void:
	if clip != loco_clip:
		loco_clip = clip
		tree.set("parameters/loco/transition_request", clip)
	loco_scale = scale
	tree.set("parameters/loco_speed/scale", scale)


func _process(delta: float) -> void:
	if frozen:
		return
	_invuln = maxf(0.0, _invuln - delta)
	slow_t = maxf(0.0, slow_t - delta)
	reveal_t = maxf(0.0, reveal_t - delta)
	model.visible = _invuln <= 0.0 or fmod(_invuln, 0.12) < 0.08        # blink while hurt
	position += _knock * delta
	_knock = _knock.lerp(Vector3.ZERO, 1.0 - exp(-9.0 * delta))

	var joy: Vector2 = main.joystick.vector
	var moving := hp > 0 and joy.length() > 0.01
	var dir := Vector3.ZERO
	var speed := 0.0
	_dash_cd = maxf(0.0, _dash_cd - delta)
	_dash_iframe = maxf(0.0, _dash_iframe - delta)
	if _dash_t > 0.0 and hp > 0:
		# the Leaf Dash: straight along its line (walls and pillars still hold the cat), the cat keeps aiming and shooting
		_dash_t -= delta
		position += _dash_dir * _dash_speed * delta
		slow_t = 0.0
		moving = true
		dir = _dash_dir
		speed = _dash_speed
		if fmod(_dash_t, 0.06) < delta:
			Fx.petals(main, global_position + Vector3(0, 0.4, 0))
	elif moving:
		dir = Vector3(joy.x, 0.0, joy.y).normalized()               # screen up = away from the camera = -Z
		speed = Data.cat_speed() * minf(joy.length(), 1.0) * (0.55 if slow_t > 0.0 else 1.0)
		if riding:
			speed *= Data.pick("mount", "speed_by_level", Data.mount_level())
		position += dir * speed * delta
	position = main.world.constrain(position, 0.3, false)
	vel = vel.lerp((global_position - _vel_from) / maxf(delta, 0.0001), 0.5) if delta > 0.0 else vel
	_vel_from = global_position
	if main.guardian != null:
		position = main.guardian.push_out(position, 0.3)       # the cat never walks through the Moss Warden
	# on Thistle the cat sits in the saddle, astride, and rides the hops
	var on_mount: bool = riding and main.mount != null
	_ride_w = move_toward(_ride_w, 1.0 if on_mount else 0.0, delta / 0.25)
	ride_pose.amount = _ride_w
	var ride_want: float = main.mount.rider_height() - SEAT_DROP if on_mount else 0.0
	_ride_y = lerpf(_ride_y, ride_want, 1.0 - exp(-16.0 * delta))
	model.position.y = _ride_y
	var heading: float = main.mount.rotation.y if on_mount else 0.0
	if cloth != null:
		cloth.follow(global_position, delta)

	# who to shoot: stay on the same enemy until it is gone or out of reach
	if hp <= 0:
		target = null
	elif target == null or not is_instance_valid(target) or target.dead or not main.target_ok(target) \
			or target.global_position.distance_to(global_position) > _reach() + 1.0:
		target = main.nearest_enemy(global_position, _reach())
	elif target == main.stations.dummy:
		var other = main.nearest_enemy(global_position, Data.cat_range())
		if other != null and other != target:
			target = other
	var aiming: bool = target != null
	aim_w = move_toward(aim_w, 1.0 if aiming else 0.0, delta / AIM_BLEND)

	# the body faces what it shoots at; with nothing to shoot it faces the way it goes
	var aim_error := 0.0
	var aim_offset := 0.0                                           # the target's bearing seen from the body
	if aiming:
		var to: Vector3 = target.global_position - global_position
		var want := atan2(to.x, to.z)
		facing = lerp_angle(facing, want, 1.0 - exp(-TURN * delta))
		aim_offset = wrapf(want - facing, -PI, PI)
		aim_error = absf(aim_offset)
	elif on_mount:
		facing = lerp_angle(facing, heading, 1.0 - exp(-TURN * delta))      # sits facing the way Thistle runs
	elif moving:
		facing = lerp_angle(facing, atan2(dir.x, dir.z), 1.0 - exp(-TURN * delta))
	rotation.y = facing

	# the legs: along the way the cat is going, forward or backward, whichever twists the body less
	var want_turn := 0.0
	var backward := false
	if aiming and moving:
		var ahead := wrapf(atan2(dir.x, dir.z) - facing, -PI, PI)           # travel direction seen from the aim
		var behind := wrapf(ahead - PI, -PI, PI)
		var turn_fwd := clampf(ahead, HIPS_MIN, HIPS_MAX)
		var turn_back := clampf(behind, HIPS_MIN, HIPS_MAX)
		var miss_fwd := absf(ahead - turn_fwd)
		var miss_back := absf(behind - turn_back)
		if legs_backward:
			backward = miss_back <= miss_fwd + KEEP_GAIT
		else:
			backward = miss_back < miss_fwd - KEEP_GAIT
		want_turn = turn_back if backward else turn_fwd
	elif aiming:
		want_turn = STANCE_HIPS
	legs_backward = backward
	hips_turn = lerpf(hips_turn, want_turn, 1.0 - exp(-10.0 * delta))
	twist.hips_yaw = hips_turn * aim_w
	twist.upper_yaw = (STANCE_HIPS - hips_turn) * aim_w         # the chest ends up where the stance put it
	if on_mount:
		# in the saddle the hips and legs stay with Thistle, and only the upper body turns to aim
		var seat := wrapf(heading - facing, -PI, PI)
		hips_turn = seat
		twist.hips_yaw = seat
		twist.upper_yaw = -seat + STANCE_HIPS * aim_w
	twist.aim_yaw = aim_offset
	twist.aim_lock = aim_w

	model.rotation.x = lerpf(model.rotation.x, 0.26 if _dash_t > 0.0 else 0.0, 1.0 - exp(-18.0 * delta))   # leans into a dash
	if moving and not riding:
		var clip := "Walk" if speed < WALK_BELOW else "Run"
		var rate := clampf(speed / CLIP_SPEED[clip], 0.6, 1.7 if _dash_t <= 0.0 else 2.0)
		_loco(clip, -rate if (backward and aim_w > 0.5) else rate)
	else:
		_loco("Idle", 1.0)
	tree.set("parameters/mix/blend_amount", aim_w)

	# shooting: a clock that runs with the Shoot loop
	if aiming and not _was_aiming:
		tree.set("parameters/shoot_seek/seek_request", 0.0)
		_shoot_t = 0.0
		_fired = false
	_was_aiming = aiming
	var draw := Data.cat_draw()
	tree.set("parameters/shoot_speed/scale", draw)
	if aiming:
		_shoot_t += delta * draw
		if _shoot_t >= SHOOT_LENGTH:
			_shoot_t -= SHOOT_LENGTH
			_fired = false
		# the arrow goes at the release, or a moment later if the body is still turning to a new enemy
		if not _fired and _shoot_t >= SHOOT_RELEASE and _shoot_t < SHOOT_NOCK - 0.1 \
				and aim_w > 0.9 and aim_error < FIRE_CONE:
			_fired = true
			_fire()
	nocked.visible = aim_w > 0.5 and (not _fired or _shoot_t >= SHOOT_NOCK)

	if hp <= 0:
		state = "down"
	elif aiming:
		state = "move_shoot" if moving else "shoot"
	else:
		state = "move" if moving else "idle"


func _fire() -> void:
	var start := nocked.global_position
	var aim_at: Vector3 = target.global_position + Vector3(0.0, target.aim_height, 0.0)
	var bow := Data.bow_info(Save.bow)
	var n := int(bow["arrows"])
	var spread := deg_to_rad(float(bow["spread_deg"]))
	var dmg := Data.arrow_damage()
	if main.ambush_ready and target != main.stations.dummy:
		main.ambush_ready = false
		dmg *= 2.0
		Fx.text(main, target.global_position + Vector3(0, float(target.aim_height) * 2.0 + 0.6, 0), "Ambush!", Color(1.0, 0.85, 0.3))
		Fx.sparkle(main, start)
	elif main.empowered_t > 0.0 and target != main.stations.dummy:
		main.empowered_t = 0.0                           # Phase E: a close call's arrow hits double
		dmg *= 2.0
		Fx.text(main, target.global_position + Vector3(0, float(target.aim_height) * 2.0 + 0.6, 0), "Double!", Color(0.6, 1.0, 0.8))
		Fx.sparkle(main, start)
	reveal_t = 1.4
	for k in n:
		var dir := aim_at - start
		if n > 1:
			dir = dir.rotated(Vector3.UP, spread * (float(k) - (n - 1) * 0.5))
		var arrow := Node3D.new()
		arrow.set_script(ArrowScript)
		main.add_child(arrow)
		arrow.launch(start, dir, main, dmg, int(bow["pierce"]))
	shots_fired += 1
	Sfx.play("shoot", -10.0)


func hurt(from: Vector3, amount := 1) -> void:
	if invincible or _invuln > 0.0 or hp <= 0 or main.world.inside_camp(global_position):
		return
	if _dash_iframe > 0.0:
		_close_call()                                # mid-dash: nothing hurts, and the next arrow hits double
		return
	main.fight.busy()
	if riding and main.mount != null and main.mount.hp > 0:
		_invuln = 1.2                                # the mount takes the hit for the cat
		main.mount.hurt(amount, from)
		if main.area != null:
			main.burrows.on_cat_hurt()
		return
	hp = maxi(0, hp - amount)
	_invuln = 1.2
	if main.area != null:
		main.burrows.on_cat_hurt()                   # Phase E: the run is saved (and a gauntlet chest stays shut)
	var away := global_position - from
	away.y = 0.0
	_knock = away.normalized() * 4.0
	main.on_player_hurt()
	if hp <= 0:
		main.on_player_down()


# ---------------------------------------------------------------- Phase E: the Leaf Dash
## A dash of burrows.dash.distance metres in dir (a screen direction; the stick's or the facing when zero), in
## dash.time seconds, untouchable for dash.iframes seconds. False when it is recharging or the cat is down.
func dash(dir: Vector2) -> bool:
	if hp <= 0 or frozen or _dash_cd > 0.0 or _dash_t > 0.0:
		return false
	var dc: Dictionary = Data.burrow_cfg()["dash"]
	var d3 := Vector3(dir.x, 0.0, dir.y)
	if d3.length() < 0.01:
		d3 = Vector3(sin(facing), 0.0, cos(facing))
	_dash_dir = d3.normalized()
	var dist := float(dc["distance"]) + float(Data.run_mods.get("dash_dist", 0.0))
	var secs := float(dc["time"])
	_dash_speed = dist / secs
	_dash_t = secs
	_dash_iframe = float(dc["iframes"])
	_dash_cd_total = float(dc["cooldown"]) * (1.0 - float(Data.run_mods.get("dash_cd", 0.0)))
	_dash_cd = _dash_cd_total
	if target == null and dir.length() > 0.01:
		facing = atan2(_dash_dir.x, _dash_dir.z)
	dashes += 1
	Fx.boing(model, 0.18)
	Fx.dust(main, global_position, 6, 1.0)
	Fx.petals(main, global_position + Vector3(0, 0.5, 0))
	if ResourceLoader.exists("res://assets/sfx/whoosh.wav"):
		Sfx.play("whoosh", -6.0)
	else:
		Sfx.play("pop", -10.0)
	return true


## Something would have hurt the cat mid-dash: it is ignored, and the next arrow within close_call_s hits double.
func _close_call() -> void:
	close_calls += 1
	main.empowered_t = float(Data.burrow_cfg()["dash"]["close_call_s"])
	Fx.text(main, global_position + Vector3(0, 1.7, 0), "Close call!", Color(0.6, 1.0, 0.8))
	Fx.sparkle(main, global_position + Vector3(0, 1.0, 0))


## How far the dash has recharged (1 = ready); the HUD draws an arc under the health bar while it is below 1.
func dash_ready_frac() -> float:
	if _dash_cd <= 0.0:
		return 1.0
	return clampf(1.0 - _dash_cd / maxf(_dash_cd_total, 0.01), 0.0, 1.0)


func dashing() -> bool:
	return _dash_t > 0.0
