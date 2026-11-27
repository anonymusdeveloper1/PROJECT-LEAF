extends Node3D
## Thistle, the giant meadow hare that came for the Market's carrots (or its look Bramblewool: looks only, the same
## numbers). Tap Ride and it bounds over to the cat, which hops into the leaf saddle: the cat runs faster (balance.json
## "mount", by the Market's level), keeps shooting, can't hide in the grass, and the mount takes the hits meant for it.
## Tap Walk and it hops back to the Market.
## G4 (21 Nov 2026): no built-in move any more. A mount alone carries the cat and takes the hits; its fighting comes only
## from what it learned and wears at the Saddlery (Data.skill_level / Data.attach_level, Save.saddlery):
##   skills       Stomp, Ram, Pounce, Bellow (balance.json mount_skills): while the cat rides it in a fight (a mission,
##                a raid, the Burrows) it uses each by itself, each on its own timer (cooldowns), never two at once
##                (a shared gap, saddlery.gap_s); the first ready one whose moment has come goes (mount_skills.priority)
##   attachments  the Fire-spitter (splash flame balls at the cat's pace, independent of the skill gap), the Mossweave Saddle (max_hp) and
##                the Saddlebags (Data.saddlebag_leaves, read by the kills). 22 Nov 2026 (the owner's rule): it may own all
##                three but wears one at a time, or none (Data.worn_attach); only the worn one acts and shows
## Ram and Pounce move the mount and the cat on it by code (_move_*); the clip of each move is played if the model has it
## ("Stomp", "Ram", "Pounce", "Bellow"), else "Thump". Timers run on frame time (clamped) and stop while main.frozen.
## Model: res://assets/companions/<look>/<look>.glb with its json (clips Idle, Run, Thump and the skills'; "saddle_bone"
## or "saddle_height_m"); until it exists a faceted placeholder stands in.
## 22 Nov 2026: the attachment it wears (Data.worn_attach) shows its model on it when the file exists:
## res://assets/companions/attachments/<id>_<look>.glb (id fire_spitter, saddle or saddlebags; look thistle or
## bramblewool), made in the saddle bone's frame and hung on a BoneAttachment3D on that bone with no offset, coloured
## with Props.apply_vc_glow (refresh_gear: on load, on a look change, on a purchase). No file: nothing shown. The
## Fire-spitter's firing unit pivots at fire_aim while its harness stays fixed. Shots start at marker_nozzle along +Z.

var main
var model: Node3D
var anim: AnimationPlayer
var meta: Dictionary = {}
var home := Vector3.ZERO
var _body: Node3D
var _ears: Array = []
var _t := 0.0
var _spd := 0.0
var _hop := 0.0
var _skel: Skeleton3D
var _saddle := -1                                  # the rig's saddle bone: where the cat stands, as it bounds
var _track := Vector3.ZERO
var _was_riding := false
var hp := 0                                       # its health: it takes the hits while the cat rides it
var resting := 0.0                                # seconds before it can be ridden again after it was knocked out
var _regen_t := 0.0
# G4: the Saddlery's skills and the Fire-spitter
var cooldowns := {}                               # skill or attachment id -> seconds before it can go again (0: ready)
var gap := 0.0                                    # seconds before the next skill (the Fire-spitter is independent)
var act_t := 0.0                                  # the move's clip: seconds left (Idle and Run wait for it)
var last_move := ""                               # the last move made ("stomp", "ram", "pounce", "bellow", "fire_spitter")
var moves_made := {}                              # id -> how many times it went (the tests read it)
var _move_kind := ""                              # "ram" or "pounce" while one carries the mount (and the cat) by code
var _move_off := Vector3.ZERO                     # ... the whole way it goes
var _move_s := 0.0                                # ... how long it takes
var _move_k := 0.0                                # ... how far along (0..1)
var _move_lv := 1
var _move_from := Vector3.ZERO                    # where the mount's middle was when it started
var _move_dmg := 0.0
var _move_hop := 0.0                              # Pounce without its own clip: how high it hops (hop_m)
var _move_hit := {}                               # Ram: the enemies it already hit on this charge (instance id -> true)
var _lift := 0.0                                  # how high the hop lifts it now
# 22 Nov 2026: the attachments' models on the mount (refresh_gear)
var gear := {}                                    # attachment id -> its model on the saddle bone (only those shown)
var _gear_hold: BoneAttachment3D                  # ... the holder on the saddle bone
var _nozzle: Node3D                               # ... the Fire-spitter model's marker_nozzle, if any
var _fire_pivot: Node3D                           # firing unit; the collar and hangers stay on the saddle
var _fire_rest := Quaternion.IDENTITY
var _fire_target
const Fireball := preload("res://scripts/fireball.gd")


func setup(m, at: Vector3) -> void:
	main = m
	home = at
	global_position = at
	_track = at
	_load_model()
	hp = max_hp()
	Fx.blob(self, 0.62)


func _load_model() -> void:
	var base := "res://assets/companions/%s/%s" % [Save.mount_look, Save.mount_look]
	if ResourceLoader.exists(base + ".glb"):
		model = (load(base + ".glb") as PackedScene).instantiate()
		if FileAccess.file_exists(base + ".json"):
			var j = JSON.parse_string(FileAccess.get_file_as_string(base + ".json"))
			if typeof(j) == TYPE_DICTIONARY:
				meta = j
		Props.apply_vc(model)
		Props.set_skin(model, Data.look("mount", Save.mount_look), Data.skin("mount", Save.mount_look, Save.mount_skin))
		add_child(model)
		_body = model
		anim = _find(model, "AnimationPlayer") as AnimationPlayer
		if anim:
			for c in ["Idle", "Run"]:
				if anim.has_animation(c):
					anim.get_animation(c).loop_mode = Animation.LOOP_LINEAR
			anim.play("Idle")
		var sk := _find(model, "Skeleton3D") as Skeleton3D
		if sk:
			_skel = sk
			_saddle = sk.find_bone(String(meta.get("saddle_bone", "saddle")))
		if sk and meta.has("spring_chains"):
			var sim := SpringBoneSimulator3D.new()
			sk.add_child(sim)
			var ok: Array = []
			for c in meta["spring_chains"]:
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
				sim.set_stiffness(i, float(c.get("stiffness", 2.5)))
				sim.set_drag(i, float(c.get("drag", 0.4)))
				sim.set_gravity(i, float(c.get("gravity", 0.2)))
				sim.set_gravity_direction(i, Vector3.DOWN)
				sim.set_radius(i, float(c.get("radius", 0.04)))
		refresh_gear()
		return
	_body = Node3D.new()
	add_child(_body)
	var fur := Color(0.86, 0.72, 0.55)
	var cream := Color(0.97, 0.93, 0.85)
	var mi := MeshInstance3D.new()
	mi.mesh = Props.build([
		[Props._ball(0.42, 0.7, 8), Props._at(0, 0.55, -0.05, Vector3.ZERO, Vector3(1.0, 1.0, 1.35)), fur],
		[Props._ball(0.3, 0.42, 7), Props._at(0, 0.42, 0.08), cream],
		[Props._ball(0.26, 0.44, 7), Props._at(0, 0.98, 0.5), fur],
		[Props._ball(0.12, 0.12, 6), Props._at(0, 0.92, 0.72), cream],
		[Props._ball(0.04, 0.04, 5), Props._at(0, 0.95, 0.78), Color(0.9, 0.5, 0.55)],
		[Props._ball(0.04, 0.05, 5), Props._at(-0.13, 1.04, 0.68), Color(0.12, 0.1, 0.1)],
		[Props._ball(0.04, 0.05, 5), Props._at(0.13, 1.04, 0.68), Color(0.12, 0.1, 0.1)],
		[Props._ball(0.17, 0.28, 7), Props._at(0, 0.6, -0.62), Color(1, 1, 1)],
		[Props._box(0.56, 0.08, 0.6), Props._at(0, 0.96, -0.05, Vector3(0.08, 0, 0)), Color(0.36, 0.66, 0.24)],
		[Props._box(0.12, 0.06, 0.1), Props._at(0, 0.99, 0.24), Color(0.95, 0.76, 0.2)],
		[Props._ball(0.13, 0.26, 6), Props._at(-0.22, 0.12, 0.3), fur.darkened(0.08)],
		[Props._ball(0.13, 0.26, 6), Props._at(0.22, 0.12, 0.3), fur.darkened(0.08)],
		[Props._ball(0.16, 0.24, 6), Props._at(-0.28, 0.12, -0.35, Vector3.ZERO, Vector3(1.0, 1.0, 1.6)), fur.darkened(0.08)],
		[Props._ball(0.16, 0.24, 6), Props._at(0.28, 0.12, -0.35, Vector3.ZERO, Vector3(1.0, 1.0, 1.6)), fur.darkened(0.08)]])
	mi.material_override = Props.vc()
	_body.add_child(mi)
	for x in [-1.0, 1.0]:
		var ear := MeshInstance3D.new()
		ear.mesh = Props.build([[Props._ball(0.08, 0.6, 6), Props._at(0, 0.28, 0, Vector3.ZERO, Vector3(1.0, 1.0, 0.45)), fur],
			[Props._ball(0.05, 0.45, 5), Props._at(0, 0.28, 0.02, Vector3.ZERO, Vector3(1.0, 1.0, 0.4)), Color(1.0, 0.75, 0.75)]])
		ear.material_override = Props.vc()
		ear.position = Vector3(x * 0.1, 1.12, 0.45)
		ear.rotation = Vector3(-0.25, 0, x * 0.18)
		_body.add_child(ear)
		_ears.append(ear)


func _find(n: Node, type: String) -> Node:
	if n.is_class(type):
		return n
	for c in n.get_children():
		var r := _find(c, type)
		if r != null:
			return r
	return null


## A different look for the same mount (the Stable at the Market): only the model changes.
func set_look() -> void:
	for c in get_children():
		c.queue_free()
	model = null
	anim = null
	meta = {}
	_body = null
	_ears.clear()
	_skel = null
	_saddle = -1
	gear = {}
	_gear_hold = null
	_nozzle = null
	_fire_pivot = null
	_fire_target = null
	_hazards_of = null
	_hazards = []
	_load_model()
	Fx.petals(main, global_position + Vector3(0, 0.8, 0))


# ---------------------------------------------------------------- 22 Nov 2026: the attachments' models
## Where attachment id's model for mount look `look` would be.
static func gear_path(id: String, look: String) -> String:
	return "res://assets/companions/attachments/%s_%s.glb" % [id, look]


## Shows the model of the attachment it wears (see the top), for the look in use; takes away any other (one taken off
## or no longer owned). A mount without a saddle bone (the placeholder) or without the files shows nothing, as before.
func refresh_gear() -> void:
	for k in gear.keys():
		var old = gear[k]
		if old != null and is_instance_valid(old):
			if (old as Node).get_parent() != null:
				(old as Node).get_parent().remove_child(old)
			(old as Node).queue_free()
	gear = {}
	_nozzle = null
	_fire_pivot = null
	_fire_target = null
	if _skel == null or _saddle < 0 or not is_instance_valid(_skel):
		return
	for id in Data.saddle_items("attach"):
		if Data.worn_attach() != String(id):
			continue
		var p := gear_path(String(id), Save.mount_look)
		if not ResourceLoader.exists(p):
			continue
		var ps := load(p) as PackedScene
		if ps != null:
			_hang_gear(String(id), ps)


## One attachment's model hung on the saddle bone with no offset (its file is made in that bone's frame), coloured with
## the shared shader (M_Glow parts keep their glow); the Fire-spitter's marker_nozzle is remembered. Null if it can't.
func _hang_gear(id: String, ps: PackedScene) -> Node3D:
	if _skel == null or _saddle < 0 or not is_instance_valid(_skel):
		return null
	var n := ps.instantiate() as Node3D
	if n == null:
		return null
	if _gear_hold == null or not is_instance_valid(_gear_hold):
		_gear_hold = BoneAttachment3D.new()
		_gear_hold.name = "gear_hold"
		_skel.add_child(_gear_hold)
		_gear_hold.bone_name = _skel.get_bone_name(_saddle)
	Props.apply_vc_glow(n)
	n.name = id
	n.transform = Transform3D.IDENTITY
	_gear_hold.add_child(n)
	gear[id] = n
	if id == "fire_spitter":
		_nozzle = Props.find_part(n, "marker_nozzle")
		_fire_pivot = Props.find_part(n, "fire_aim")
		_fire_rest = _fire_pivot.quaternion if _fire_pivot != null else Quaternion.IDENTITY
	return n


## The actual rotating nozzle's position and +Z firing axis, including side and rear shots. [from, dir]
func _fire_from() -> Array:
	var fwd := _fwd()
	if _nozzle != null and is_instance_valid(_nozzle) and _nozzle.is_inside_tree():
		return [_nozzle.global_position, _nozzle.global_basis.z.normalized()]
	return [global_position + fwd * 0.45 + Vector3(0, 0.75, 0), fwd]


func _fire_target_ok(foe) -> bool:
	if foe == null or not is_instance_valid(foe) or not foe.is_in_group("foes") or foe.dead:
		return false
	var distance: float = main.player.global_position.distance_to(foe.global_position)
	return distance <= Data.cat_range() and (foe.awake or distance <= float(Data.burrow_cfg()["wake_r"]))


## Assist the cat's current enemy; otherwise hold a valid lock or acquire the nearest foe in any direction.
func _select_fire_target() -> void:
	if _fire_target_ok(main.player.target):
		_fire_target = main.player.target
	elif not _fire_target_ok(_fire_target):
		var foe = main.nearest_enemy(main.player.global_position, Data.cat_range())
		_fire_target = foe if _fire_target_ok(foe) else null


func _fire_aim_at() -> Vector3:
	return _fire_target.global_position + Vector3(0, _fire_target.aim_height, 0)


func _point_fire_target(dt: float, instant := false) -> void:
	if _fire_pivot == null or not is_instance_valid(_fire_pivot) or not _fire_target_ok(_fire_target):
		return
	var to := _fire_aim_at() - _fire_pivot.global_position
	if to.length_squared() < 0.000001:
		return
	var up := Vector3.UP if absf(to.normalized().dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
	var want := Quaternion(Basis.looking_at(-to.normalized(), up))
	var current := Quaternion(_fire_pivot.global_basis.orthonormalized())
	var step := deg_to_rad(float(Data.saddle_info("attach", "fire_spitter")["aim_turn_deg_per_s"])) * dt
	var weight := 1.0 if instant else minf(1.0, step / maxf(current.angle_to(want), 0.000001))
	_fire_pivot.global_basis = Basis(current.slerp(want, weight))


func _update_fire_aim(dt: float) -> void:
	if main.player.riding and _fighting() and Data.worn_level("fire_spitter") > 0:
		_select_fire_target()
	else:
		_fire_target = null
	if _fire_target_ok(_fire_target):
		_point_fire_target(dt)
	elif _fire_pivot != null and is_instance_valid(_fire_pivot):
		var current := _fire_pivot.quaternion
		var step := deg_to_rad(float(Data.saddle_info("attach", "fire_spitter")["aim_turn_deg_per_s"])) * dt
		_fire_pivot.quaternion = current.slerp(_fire_rest, minf(1.0, step / maxf(current.angle_to(_fire_rest), 0.000001)))


func _fire_aligned() -> bool:
	if not _fire_target_ok(_fire_target):
		return false
	if _fire_pivot == null or not is_instance_valid(_fire_pivot):
		return true                                # a missing model still has the gameplay effect
	var from := _fire_from()
	var to := _fire_aim_at() - (from[0] as Vector3)
	var tolerance := deg_to_rad(float(Data.saddle_info("attach", "fire_spitter")["aim_tolerance_deg"]))
	return to.length_squared() < 0.000001 or (from[1] as Vector3).dot(to.normalized()) >= cos(tolerance)


## How high the cat stands on the saddle right now (it bobs with the mount's hops, and rises with a Pounce's hop).
func rider_height() -> float:
	if _saddle >= 0:
		return _saddle_world().y - global_position.y
	return float(meta.get("saddle_height_m", 0.98)) + _hop + _lift


func _saddle_world() -> Vector3:
	return _skel.global_transform * _skel.get_bone_global_pose(_saddle).origin


## 22 Nov 2026, for the rider's motion (player.gd, ride_motion.gd): how fast it goes now (m/s, smoothed).
func speed() -> float:
	return _spd


## 22 Nov 2026 (the owner: the mount's head or ears must never go into the cat): what the rider keeps clear of: points on
## its neck, head and everything the head carries (ears, horns, nose, jaw, tassels), sampled from its own mesh, each on
## the bone that moves it most, as [[bone, point in that bone's frame], ...] (at most HAZARD_PER_BONE a bone, the
## farthest from the bone always in). Measured once per model; ride_motion.gd leans the cat away from them.
const HAZARD_PER_BONE := 14
var _hazards: Array = []
var _hazards_of: Node = null


func rider_hazards() -> Array:
	if _skel == null or not is_instance_valid(_skel) or model == null:
		return []
	if _hazards_of == model:
		return _hazards
	_hazards_of = model
	_hazards = []
	var keep := {}
	var head := _skel.find_bone("head")
	var neck := _skel.find_bone("neck")
	if neck >= 0:
		keep[neck] = true
	for b in _skel.get_bone_count():
		var p := b
		while p >= 0 and p != head:
			p = _skel.get_bone_parent(p)
		if head >= 0 and p == head:
			keep[b] = true
	var per := {}
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or mi.skin == null:
			continue                                     # the attachments are not skinned: only the mount's own body
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bones = arr[Mesh.ARRAY_BONES]
			var weights = arr[Mesh.ARRAY_WEIGHTS]
			if bones == null or weights == null or verts.is_empty():
				continue
			var stride := int(float(bones.size()) / float(verts.size()))
			if stride <= 0:
				continue
			for v in verts.size():
				var best := -1
				var bw := 0.0
				for k in stride:
					var w: float = weights[v * stride + k]
					if w > bw:
						bw = w
						best = int(bones[v * stride + k])
				if best < 0 or best >= mi.skin.get_bind_count():
					continue
				var bone := mi.skin.get_bind_bone(best)
				if bone < 0:
					bone = _skel.find_bone(String(mi.skin.get_bind_name(best)))
				if not keep.has(bone):
					continue
				if not per.has(bone):
					per[bone] = []
				(per[bone] as Array).append(mi.skin.get_bind_pose(best) * verts[v])
	for bone in per:
		var pts: Array = per[bone]
		var far_i := 0
		for i in pts.size():
			if (pts[i] as Vector3).length() > (pts[far_i] as Vector3).length():
				far_i = i
		_hazards.append([bone, pts[far_i]])
		var step := maxi(1, int(ceil(float(pts.size()) / float(HAZARD_PER_BONE - 1))))
		for i in range(0, pts.size(), step):
			if i != far_i:
				_hazards.append([bone, pts[i]])
	return _hazards


## How the saddle is tipped now (the hare's back rocks as it bounds, the ram's as it trots): the turn in world space from
## upright to the saddle bone's up axis. None for a mount without a saddle bone (the placeholder).
func saddle_tilt() -> Quaternion:
	if _saddle < 0 or _skel == null or not is_instance_valid(_skel):
		return Quaternion.IDENTITY
	var up := (_skel.global_transform.basis * _skel.get_bone_global_pose(_saddle).basis.y).normalized()
	if up.dot(Vector3.UP) < 0.5:
		return Quaternion.IDENTITY
	return Quaternion(Vector3.UP, up)


## Its health: by the Market's level (balance.json mount.hp_by_level), x the Mossweave Saddle (G4, Data.mount_hp_mult)
## and x any Burrows help (run_mods.mount_hp).
func max_hp() -> int:
	return roundi(Data.pick("mount", "hp_by_level", Data.mount_level()) * (1.0 + float(Data.run_mods.get("mount_hp", 0.0))) * Data.mount_hp_mult())


## A hit meant for the rider. Out of health: it throws the cat off. In a mission it stays out until the cat feeds it
## (the HUD's Feed button) or the next chapter break; outside one it rests and gets up by itself.
func hurt(amount: int, _from: Vector3) -> void:
	if hp <= 0:
		return
	hp = maxi(0, hp - amount)
	Fx.hit(main, global_position + Vector3(0, 0.6, 0), Color(1.0, 0.6, 0.4))
	Fx.number(main, global_position + Vector3(0, 1.1, 0), amount, Color(1.0, 0.55, 0.35))
	Fx.boing(_body, 0.15)
	main.shake(0.1)
	if hp <= 0:
		resting = float(Data.b["mount"]["rest_s"])
		main.set_riding(false)
		Fx.dust(main, global_position, 8, 1.2)
		if main.fight.active or main.get("area") != null:
			main.hud.toast("%s is knocked out! Feed it to bring it back" % Data.mount_name())
			if not Save.flag("told_feed"):
				Save.set_flag("told_feed")
				main.hud.tip("%s is out. Tap Feed (%s from your garden) to bring it back, or it gets up at the next chapter break." % [
					Data.mount_name(), main.feed_text()], null)
		else:
			main.hud.toast("%s is hurt and runs home to rest" % Data.mount_name())
		Events.mount_down_changed.emit(true)


## Knocked out: it cannot be ridden until it is fed, a chapter break comes, or (outside missions) it has rested.
func out() -> bool:
	return resting > 0.0


## Back to full (chapter breaks, the end of a mission, a meal).
func refill() -> void:
	var was_out := resting > 0.0
	resting = 0.0
	hp = max_hp()
	if was_out:
		Events.mount_down_changed.emit(false)


func come_to(at: Vector3) -> void:
	_stop_move()
	Fx.petals(main, global_position + Vector3(0, 0.6, 0))
	global_position = Vector3(at.x, 0, at.z)
	Fx.petals(main, global_position + Vector3(0, 0.6, 0))
	Fx.dust(main, global_position, 8, 1.3)
	Fx.boing(_body, 0.3)


func _process(delta: float) -> void:
	if main.frozen:
		return
	var dt := minf(delta, 0.1)                        # frame time, clamped: nothing runs on while the game is away
	_t += dt
	_tick_moves(dt)
	# knocked out: rest, then come back at full health; not ridden: get a little better every 2 s
	var below: bool = main.get("area") != null
	if below and not main.player.riding:
		# Phase E: the mount came down with the cat; it keeps near it (a knocked-out one limps after it)
		home = main.area.constrain(main.player.global_position + Vector3(1.1, 0, 0.7), 0.45, false)   # on the path, not in the trees
		if global_position.distance_to(home) > 8.0:
			global_position = home
	if resting > 0.0:
		if not main.fight.active and not below:       # in a mission or a run it stays out until fed (or a chapter break)
			resting -= dt
			if resting <= 0.0:
				resting = 0.01
				refill()
	elif not main.player.riding and hp < max_hp():
		_regen_t += dt
		if _regen_t >= 2.0:
			_regen_t = 0.0
			hp += 1
	hp = mini(hp, max_hp())
	if main.player.riding:
		if _move_kind != "":
			_step_move(dt)                             # G4: a Ram or a Pounce carries the cat (and so the mount)
		var p: Vector3 = main.player.global_position
		var off := Vector3.ZERO                      # keep the saddle (at rest), not the hare's middle, under the cat
		if _saddle >= 0:
			off = _skel.global_transform * _skel.get_bone_global_rest(_saddle).origin - global_position
			off.y = 0.0
		global_position = Vector3(p.x, 0, p.z) - off
		if _move_kind == "ram":
			_ram_strike()                            # the enemies along the way so far
		if _move_kind != "" and _move_k >= 1.0:
			_finish_move()                           # a Pounce lands here
	else:
		_stop_move()                                 # off the mount: a charge or a leap stops
		var to := home - global_position
		to.y = 0.0
		if to.length() > 0.08:
			global_position += to.normalized() * minf(3.0 * dt, to.length())
		elif absf(wrapf(rotation.y, -PI, PI)) > 0.02:
			rotation.y = lerp_angle(rotation.y, 0.0, 1.0 - exp(-4.0 * dt))
	# how fast and which way it goes: the cat's own steps while riding (the saddle offset turns with the hare,
	# so its position would feed back into its own heading)
	var track: Vector3 = main.player.global_position if main.player.riding else global_position
	var moved := track - _track
	if _was_riding != main.player.riding:
		moved = Vector3.ZERO                         # a hop on or off is not a step
	_track = track
	_was_riding = main.player.riding
	moved.y = 0.0
	_spd = lerpf(_spd, moved.length() / maxf(dt, 0.0001), 1.0 - exp(-10.0 * dt))
	if moved.length() > 0.002:
		rotation.y = lerp_angle(rotation.y, atan2(moved.x, moved.z), 1.0 - exp(-10.0 * dt))
	# hopping: the body bounds, the ears swing back
	var running := _spd > 0.3
	var hop_goal := absf(sin(_t * 9.0)) * 0.12 if running else 0.0
	_hop = lerpf(_hop, hop_goal, 1.0 - exp(-14.0 * dt))
	if anim:
		_body.position.y = _lift
		if act_t <= 0.0:
			var clip := "Run" if running and anim.has_animation("Run") else "Idle"
			if anim.current_animation != clip:
				anim.play(clip, 0.15)
			if clip == "Run":
				var gs: Dictionary = meta.get("ground_speed_m_per_s", {})
				anim.speed_scale = clampf(_spd / maxf(float(gs.get("Run", 3.5)), 0.1), 0.6, 2.0)
			else:
				anim.speed_scale = 1.0
	else:
		_body.position.y = _hop + _lift
		_body.rotation.x = -0.12 * sin(_t * 9.0) if running else lerpf(_body.rotation.x, 0.0, 0.2)
		for i in _ears.size():
			var e: Node3D = _ears[i]
			e.rotation.x = lerpf(e.rotation.x, -0.25 - (0.5 if running else 0.08 * sin(_t * 2.0 + i)), 1.0 - exp(-8.0 * dt))
	_update_fire_aim(dt)
	if main.player.riding and _fighting():
		_try_moves()


# ---------------------------------------------------------------- G4: skills and the Fire-spitter
## The timers: each move's own, the shared gap and the clip's time (frame time, clamped by the caller).
func _tick_moves(dt: float) -> void:
	gap = maxf(0.0, gap - dt)
	act_t = maxf(0.0, act_t - dt)
	for k in cooldowns.keys():
		cooldowns[k] = maxf(0.0, float(cooldowns[k]) - dt)


## It fights only while the cat rides it in a fight: a mission or raid (fight.active) or a Burrows run, the cat up.
func _fighting() -> bool:
	return (main.fight.active or main.get("area") != null) and main.player.hp > 0 and not main.player.frozen


## Skills share their gap and respect an active charge/leap. The worn Fire-spitter has its own faster firing clock.
func _try_moves() -> void:
	if gap <= 0.0 and _move_kind == "":
		for id in Data.skill_priority():
			var lv := Data.skill_level(String(id))
			if lv > 0 and float(cooldowns.get(id, 0.0)) <= 0.0 and _use(String(id), lv):
				break
	var fl := Data.worn_level("fire_spitter")             # only when it is the one worn (22 Nov 2026)
	if fl > 0 and float(cooldowns.get("fire_spitter", 0.0)) <= 0.0:
		_spit_fire(fl, false)


## Tests and tools: make move id now if it is owned (the Fire-spitter: worn) and its moment has come (an enemy where it
## needs one), whatever its timer and the gap say. True when it went.
func try_move(id: String) -> bool:
	var lv := Data.worn_level(id) if id == "fire_spitter" else Data.skill_level(id)
	if lv <= 0 or (_move_kind != "" and id != "fire_spitter") or not main.player.riding:
		return false
	return _use(id, lv)


## The move under way that carries the mount ("ram", "pounce"), or "".
func moving() -> String:
	return _move_kind


func _use(id: String, lv: int) -> bool:
	match id:
		"stomp": return _stomp(lv)
		"ram": return _ram(lv)
		"pounce": return _pounce(lv)
		"bellow": return _bellow(lv)
		"fire_spitter": return _spit_fire(lv)
	return false


## Skills start their cooldown and shared gap; the Fire-spitter uses the current cat attack interval independently.
func _went(id: String, info: Dictionary, busy_s := 0.0) -> void:
	if id == "fire_spitter":
		cooldowns[id] = main.player.attack_interval()
	else:
		cooldowns[id] = float(info.get("every_s", 4.0))
		gap = Data.saddle_gap() + busy_s
	last_move = id
	moves_made[id] = int(moves_made.get(id, 0)) + 1
	_jolt(id)


## 22 Nov 2026: the cat on its back jolts with the move (player.ride_jolt; balance.json mount.ride_jolt).
func _jolt(kind: String) -> void:
	if main != null and main.player != null and main.player.riding and main.player.has_method("ride_jolt"):
		main.player.ride_jolt(kind)


## The enemies now (alive), and the ones on the ground (fliers pass over Stomp, Ram and Pounce).
func _foes(ground: bool) -> Array:
	var out: Array = []
	for e in get_tree().get_nodes_in_group("foes"):
		if is_instance_valid(e) and not e.dead and not (ground and e.flyer):
			out.append(e)
	return out


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


## Where it faces, following the direction of travel.
func _fwd() -> Vector3:
	return Vector3(sin(rotation.y), 0.0, cos(rotation.y))


## Companions hit harder after a Honey Cake (the meal's "friends" boost), as the Thump did.
func _friends() -> float:
	return 1.0 + Data.meal_boost("friends")


## The move's clip: its own ("Stomp", "Ram", "Pounce", "Bellow") when the model has it, else "Thump", else a squash.
func _play(info: Dictionary) -> void:
	var clip := String(info.get("clip", "Thump"))
	if anim and not anim.has_animation(clip):
		clip = "Thump"
	if anim and anim.has_animation(clip):
		anim.play(clip, 0.05)
		anim.speed_scale = 1.0
		act_t = anim.get_animation(clip).length
	else:
		Fx.boing(_body, 0.35)
		act_t = 0.4


func _shout(info: Dictionary, col: Color) -> void:
	var s := String(info.get("shout", ""))
	if s != "":
		Fx.text(main, global_position + Vector3(0, 2.0, 0), s, col)


## Stomp: an enemy within trigger_m: a shockwave round the mount reaching radius_m, its damage to each enemy on the ground
## there and the small push back of a hit. The Burrows' thump_mult (the Thunder Shoes) makes it stronger.
func _stomp(lv: int) -> bool:
	var info := Data.saddle_info("skills", "stomp")
	var trig := float(info.get("trigger_m", 1.6))
	var near := false
	var foes := _foes(true)
	for e in foes:
		if _flat(e.global_position - global_position).length() < trig + float(e.radius):
			near = true
			break
	if not near:
		return false
	var r := float(info.get("radius_m", 2.0))
	var dmg := Data.skill_damage("stomp", lv) * _friends() * (1.0 + float(Data.run_mods.get("thump_mult", 0.0)))
	_went("stomp", info)
	_play(info)
	Fx.shockwave(main, global_position, r + 0.4, Color(1.0, 0.9, 0.6))
	Fx.dust(main, global_position, 12, 1.6)
	_shout(info, Color(1.0, 0.9, 0.55))
	main.shake(0.15)
	for e in foes:
		if not is_instance_valid(e) or e.dead:
			continue
		var d: Vector3 = _flat(e.global_position - global_position)
		if d.length() < r + float(e.radius):
			e.hit(d.normalized() if d.length() > 0.01 else _fwd(), dmg)
	return true


## Ram: an enemy ahead (within ahead_m, ahead_deg either side of its heading): a short charge forward (dash_m over
## dash_s, the cat on it); each enemy on the ground it passes within width_m takes its damage once and is knocked aside.
func _ram(lv: int) -> bool:
	var info := Data.saddle_info("skills", "ram")
	var fwd := _fwd()
	var reach := float(info.get("ahead_m", 4.0))
	var cosa := cos(deg_to_rad(float(info.get("ahead_deg", 35.0))))
	var any := false
	for e in _foes(true):
		var to: Vector3 = _flat(e.global_position - global_position)
		if to.length() < reach + float(e.radius) and (to.length() < 0.05 or to.normalized().dot(fwd) > cosa):
			any = true
			break
	if not any:
		return false
	var secs := float(info.get("dash_s", 0.35))
	_begin_move("ram", fwd * float(info.get("dash_m", 3.0)), secs, lv)
	_move_dmg = Data.skill_damage("ram", lv) * _friends()
	_went("ram", info, secs)
	_play(info)
	_shout(info, Color(1.0, 0.85, 0.5))
	Fx.dust(main, global_position, 10, 1.4)
	main.shake(0.12)
	_ram_strike()
	return true


## Ram, each frame of its charge: the enemies along the way from where it started to where it is now.
func _ram_strike() -> void:
	var info := Data.saddle_info("skills", "ram")
	var w := float(info.get("width_m", 0.9))
	var knock := float(info.get("knock", 6.0))
	var a := Vector2(_move_from.x, _move_from.z)
	var b := Vector2(global_position.x, global_position.z)
	var fwd := _move_off.normalized() if _move_off.length() > 0.01 else _fwd()
	for e in _foes(true):
		var id: int = e.get_instance_id()
		if _move_hit.has(id):
			continue
		var q := Vector2(e.global_position.x, e.global_position.z)
		var c := Geometry2D.get_closest_point_to_segment(q, a, b)
		if c.distance_to(q) >= w + float(e.radius):
			continue
		_move_hit[id] = true
		var side := Vector3(q.x - c.x, 0.0, q.y - c.y)
		if side.length() < 0.05:
			side = Vector3(-fwd.z, 0.0, fwd.x) * (1.0 if (id % 2) == 0 else -1.0)
		var dir := (side.normalized() + fwd * 0.35).normalized()
		e.hit(dir, _move_dmg)
		if not e.dead and e.has_method("shove"):
			e.shove(dir, knock)
		Fx.hit(main, e.global_position + Vector3(0, 0.5, 0), Color(1.0, 0.85, 0.5))


## Pounce: an enemy on the ground within reach_m: it leaps (the cat on it) onto the middle of the biggest group there
## (the most enemies within blast_m of one of them; the nearest such group on a tie) over leap_s, and lands with a blast
## of blast_m: its damage and a stun (stun_s; bosses boss_stun_s at most).
func _pounce(lv: int) -> bool:
	var info := Data.saddle_info("skills", "pounce")
	var reach := float(info.get("reach_m", 6.0))
	var blast := float(info.get("blast_m", 2.5))
	var foes := _foes(true)
	var best_n := 0
	var best_d := INF
	var best_at := Vector3.ZERO
	for c in foes:
		var dc: float = _flat(c.global_position - global_position).length()
		if dc > reach + float(c.radius):
			continue
		var n := 0
		var sum := Vector3.ZERO
		for e in foes:
			if _flat(e.global_position - c.global_position).length() < blast:
				n += 1
				sum += _flat(e.global_position)
		if n > best_n or (n == best_n and dc < best_d):
			best_n = n
			best_d = dc
			best_at = sum / float(n)
	if best_n <= 0:
		return false
	var secs := float(info.get("leap_s", 0.55))
	_begin_move("pounce", _flat(best_at - global_position), secs, lv)
	_move_hop = float(info.get("hop_m", 0.7)) if not (anim and anim.has_animation(String(info.get("clip", "Pounce")))) else 0.0
	_went("pounce", info, secs)
	_play(info)
	_shout(info, Color(1.0, 0.8, 0.45))
	Fx.dust(main, global_position, 8, 1.2)
	return true


## Pounce lands: the blast round where it came down.
func _pounce_land(lv: int) -> void:
	var info := Data.saddle_info("skills", "pounce")
	var r := float(info.get("blast_m", 2.5))
	var dmg := Data.skill_damage("pounce", lv) * _friends()
	var stun := Data.skill_stun("pounce", lv)
	var boss_stun := minf(stun, float(info.get("boss_stun_s", 0.5)))
	Fx.shockwave(main, global_position, r + 0.3, Color(1.0, 0.8, 0.5))
	Fx.dust(main, global_position, 14, 1.8)
	main.shake(0.22)
	var any := false
	for e in _foes(true):
		var d: Vector3 = _flat(e.global_position - global_position)
		if d.length() >= r + float(e.radius):
			continue
		e.hit(d.normalized() if d.length() > 0.01 else _fwd(), dmg)
		if not e.dead and e.has_method("stun"):
			e.stun(boss_stun if e.boss else stun)
			any = true
	if any:
		Fx.text(main, global_position + Vector3(0, 1.6, 0), "Stunned!", Color(1.0, 0.95, 0.6))


## Bellow: at least min_foes enemies within radius_m (fliers too): a mighty call that stuns them (stun_s; bosses
## boss_stun_s at most), and for taken_s they take `taken` more damage.
func _bellow(lv: int) -> bool:
	var info := Data.saddle_info("skills", "bellow")
	var r := float(info.get("radius_m", 4.0))
	var near: Array = []
	for e in _foes(false):
		if _flat(e.global_position - global_position).length() < r + float(e.radius):
			near.append(e)
	if near.size() < int(info.get("min_foes", 4)):
		return false
	var stun := Data.skill_stun("bellow", lv)
	var boss_stun := minf(stun, float(info.get("boss_stun_s", 0.5)))
	var taken := Data.skill_taken("bellow", lv)
	var secs := float(info.get("taken_s", 3.0))
	_went("bellow", info)
	_play(info)
	_shout(info, Color(1.0, 0.75, 0.4))
	Fx.bellow(main, global_position + Vector3(0, 1.0, 0), r)
	main.shake(0.2)
	for e in near:
		if not is_instance_valid(e) or e.dead:
			continue
		if e.has_method("stun"):
			e.stun(boss_stun if e.boss else stun)
		if e.has_method("bellowed"):
			e.bellowed(secs, taken)
	return true


## A flame ball at the current lock, within the cat's arrow range. Automatic fire waits for the visible unit to aim.
func _spit_fire(lv: int, instant := true) -> bool:
	var info := Data.saddle_info("attach", "fire_spitter")
	_select_fire_target()
	if _fire_target == null:
		return false
	if instant:
		_point_fire_target(0.0, true)
	if not _fire_aligned():
		return false
	_went("fire_spitter", info)
	var from := _fire_from()                            # 22 Nov 2026: from its model's nozzle when it has one
	var ball := Node3D.new()
	ball.set_script(Fireball)
	main.add_child(ball)
	var aim := _fire_aim_at()
	ball.launch(main, from[0], aim, info, Data.fire_damage(lv) * _friends(), Data.fire_burn_per_s(lv) * _friends())
	return true


## A charge or a leap starts: it carries the cat (and so the mount) along off over secs.
func _begin_move(kind: String, off: Vector3, secs: float, lv: int) -> void:
	_move_kind = kind
	_move_off = off
	_move_s = maxf(secs, 0.05)
	_move_k = 0.0
	_move_lv = lv
	_move_from = global_position
	_move_hit = {}
	_move_hop = 0.0
	if off.length() > 0.05:
		rotation.y = atan2(off.x, off.z)


## One frame of it: the cat goes its share of the way (kept on walkable ground by the world, or the Burrow's map).
func _step_move(dt: float) -> void:
	var k := minf(1.0, _move_k + dt / _move_s)
	var p: Vector3 = main.player.global_position + _move_off * (k - _move_k)
	main.player.global_position = main.world.constrain(p, 0.3, false)
	_move_k = k
	_lift = _move_hop * 4.0 * k * (1.0 - k)


## The whole way is gone (called once the mount stands where the cat is): a leap lands with its blast.
func _finish_move() -> void:
	var kind := _move_kind
	var lv := _move_lv
	_stop_move()
	if kind == "pounce":
		_jolt("pounce_land")
		_pounce_land(lv)


## A charge or a leap ends, or is cut short (the cat got off, the mount came to the cat): nothing more happens.
func _stop_move() -> void:
	_move_kind = ""
	_move_k = 0.0
	_lift = 0.0
