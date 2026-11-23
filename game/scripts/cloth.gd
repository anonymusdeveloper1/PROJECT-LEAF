extends Node3D
## Cloth for the Cat Ranger: hood, capelet, tunic skirt and the outfit cloaks.
##
## The original model has 25 small cloth bones (assets/cat/CatRanger_clips.json, "cloth_bones"): two down the back of the hood,
## five round its face opening, five chains of two on the capelet plus one over each upper arm, and six round the skirt. The clips do not move them. Godot's
## SpringBoneSimulator3D does, every frame, from what the body is doing: each bone is a little pendulum with
## weight, air drag and a weak pull back to how the cloth was modelled.
## Dusk and Nightfall Ranger add two chains of two bones from the hips to the cloak hem.
##
##   Resting on the body   Every bone has a "floor": a plane fixed to the body bone it hangs from (head, chest or
##                         hips), lying where the cloth lies at rest. Gravity pulls the cloth down onto it, so it
##                         settles on the body and cannot pass through it; it is free to lift off and swing.
##   Not flipping over     More planes per bone keep it near where it hangs: one across the cloth (a flap can flare
##                         and swing, it cannot fold up over itself) and one each side (a panel cannot slide round
##                         the body). The second bone of a chain may not fold back over the first either.
##   Arms and legs         Capsules on the upper arms and thighs push the capelet and the skirt out of their way.
##   Air                   The simulator's drag is drag against still air. external_force gives back what that
##                         takes off cloth that only travels with the cat; the wind the cloth should feel is added
##                         on purpose: WIND for every m/s the cat moves, unsteady, a little upward. A light breeze
##                         with gusts keeps it alive when the cat stands.
##   The hood's front      Five more bones lie round the face opening (v14). They feel less of the wind (the head
##                         shelters them) but some of it gets under the cloth and lifts it off the cheeks.
##   Off the body          The simulator only tests the tip of each bone. cloth_fit.gd runs after it and turns each
##                         bone until points spread over its panel are clear of the legs, arms, tail, quiver and
##                         pouch, and no nearer to the torso and head than the cloth lies at rest.
##   A ripple, not a plate Every bone gets that wind at its own moment (by its place round the body, the hem after
##                         the top), so the flutter travels round the hem instead of lifting it all at once.
##
## Three things found the hard way (Godot 4.7.2 source, scene/3d/spring_bone_*):
##   - The simulation must stay centred on the world (the default). With CENTER_FROM_NODE the colliders are put in
##     the wrong place as soon as the skeleton is turned, unless that node is the skeleton's own unrotated parent.
##   - Stiffness, gravity and external_force are all "metres per second, times the frame time, added every frame",
##     so the result depends on the frame rate. The project caps it at 60 (project.godot).
##   - The simulator takes one external_force for all bones, but gravity (size and direction) per bone, and
##     changing those every frame does not restart the simulation. So each bone's own wind goes in with its weight.

const FitScript := preload("res://scripts/cloth_fit.gd")

const WIND := 0.30                  # wind the cloth feels for each m/s the cat moves (same units as gravity below)
const FULL_SPEED := 2.6             # m/s: slower than this the wind falls away faster than the speed does
const LIFT := 0.15                  # share of that wind that blows upward, so streaming cloth floats
const DRAG := 0.12                  # air drag, the same for every piece so one tail wind fits them all
const BREEZE := 0.012               # standing breeze (same units as gravity below)
const GUST := 0.045                 # extra on top of it, coming and going
const FLUTTER := 0.8                # how unsteady the wind of the cat's own movement is (0 = a steady stream)
const RIPPLE := 1.0                 # how far the flutter of one flap runs behind its neighbour's (0 = all together)
const HEM_LAG := 1.1                # ... and the hem's behind the cloth above it
const FOLD := 42.0                  # degrees the second bone of a chain may bend away from the first

# stiffness (pull back to the modelled shape), gravity, joint radius in metres, the furthest from rest in degrees
# (any way, and sideways along the body), metres the floor lies under the resting cloth, the share of the wind this
# cloth feels, and how much of the cat's own wind gets under it and pushes it off the body
const FEEL := {
	"hood_top": [0.10, 0.11, 0.020, 60.0, 20.0, 0.003, 1.0, 0.0],
	"hood_tip": [0.04, 0.11, 0.020, 85.0, 28.0, 0.003, 1.0, 0.0],
	"cape_top": [0.05, 0.11, 0.012, 68.0, 20.0, 0.003, 1.0, 0.0],
	"cape_hem": [0.02, 0.11, 0.012, 85.0, 25.0, 0.003, 1.0, 0.0],
	"cloak_top": [0.04, 0.12, 0.015, 50.0, 8.0, 0.003, 0.20, 0.0],
	"cloak_hem": [0.02, 0.12, 0.015, 65.0, 14.0, 0.003, 0.28, 0.0],
	"skirt": [0.03, 0.12, 0.015, 50.0, 22.0, 0.003, 0.45, 0.0],     # the whole panel follows its bone now: less wind does the same
	# the cloth over each upper arm, by the elbow: it rides on the arm and mostly stays put
	"cape_arm": [0.14, 0.05, 0.012, 45.0, 12.0, 0.003, 0.25, 0.0],
	# the front of the hood: down each side of the face (temple to cheek, cheek to jaw) and the peak over the brow.
	# It is modelled already fallen onto the face, and the piece under the jaw is held by the fastening below it,
	# so little weight is left to pull it further: the stiffness brings it back to where it fell
	"face_top": [0.09, 0.05, 0.016, 34.0, 20.0, 0.004, 0.32, 0.65],
	"face_low": [0.12, 0.02, 0.014, 34.0, 20.0, 0.004, 0.32, 0.50],
	"peak": [0.10, 0.05, 0.016, 30.0, 10.0, 0.004, 0.32, 0.50],
}
# name, body bone, radius, which cloth it pushes
const LIMBS := [
	["arm.L", "upper_arm.L", 0.050, "cape"], ["arm.R", "upper_arm.R", 0.050, "cape"],
	["leg.L", "thigh.L", 0.062, "skirt"], ["leg.R", "thigh.R", 0.062, "skirt"],
	["cloak_leg.L", "thigh.L", 0.062, "cloak"], ["cloak_leg.R", "thigh.R", 0.062, "cloak"],
	["cloak_shin.L", "shin.L", 0.055, "cloak"], ["cloak_shin.R", "shin.R", 0.055, "cloak"],
]

var skeleton: Skeleton3D
var sim: SpringBoneSimulator3D
var fit: SkeletonModifier3D          # cloth_fit.gd: keeps the simulated cloth off the body
var fit_on := true                  # -- --no-cloth-fit turns it off, to compare
var bones: Array = []               # one entry per cloth bone: name, bone, on, length, setting, rest_dir, rest_out
var debug := false                  # draw the planes and capsules
var wind := Vector3.ZERO            # the breeze right now (read by the test)
var measure := false                # keep each bone's angle from rest up to date (for the test)
var record := false                 # keep every bone's turn from its rest pose up to date (for the test)
var pose_now := PackedFloat32Array()   # ... four numbers a bone: w, x, y, z
var _t := 0.0
var _last := Vector3.ZERO
var _has_last := false


func setup(sk: Skeleton3D) -> bool:
	skeleton = sk
	var INFO: String = preload("res://scripts/player.gd").hero_clips()     # 23 Nov 2026: the outfit's, else the original's
	var info = JSON.parse_string(FileAccess.get_file_as_string(INFO))
	if typeof(info) != TYPE_DICTIONARY or not info.has("cloth_bones"):
		push_warning("cloth: no cloth_bones in " + INFO)
		return false
	sim = SpringBoneSimulator3D.new()
	skeleton.add_child(sim)                         # after body_twist: modifiers run in child order

	# parents before children, so a bone's own parent has already moved when its turn comes
	var names: Array = info["cloth_bones"].keys()
	names.sort_custom(func(a, b): return _depth(info["cloth_bones"], a) < _depth(info["cloth_bones"], b))
	for n in names:
		var d: Dictionary = info["cloth_bones"][n]
		var bone := skeleton.find_bone(n)
		var on := skeleton.find_bone(d["on"])
		if bone < 0 or on < 0:
			push_warning("cloth: bone missing: " + n)
			continue
		var rest := skeleton.get_bone_global_rest(bone)
		var body := skeleton.get_bone_global_rest(on)
		bones.append({
			"name": n, "bone": bone, "on": on, "length": float(d["length"]), "kind": _kind(n), "parent": String(d["parent"]),
			"rest_dir": body.basis.inverse() * rest.basis.y.normalized(),      # along the bone, in the body bone's frame
			"rest_out": body.basis.inverse() * rest.basis.z.normalized(),      # away from the body
			# where this bone's flutter is in its cycle: by its place round the body, the hem behind the top
			"phase": RIPPLE * atan2(rest.basis.z.x, rest.basis.z.z) + (HEM_LAG if String(d["parent"]) != "" else 0.0),
		})

	var limbs := _add_limbs()
	sim.setting_count = bones.size()
	for i in bones.size():
		var b: Dictionary = bones[i]
		var feel: Array = FEEL[b["kind"]]
		b["setting"] = i
		sim.set_root_bone_name(i, b["name"])
		sim.set_end_bone_name(i, b["name"])
		sim.set_extend_end_bone(i, true)                                    # the bone itself swings, about its head
		sim.set_end_bone_direction(i, SkeletonModifier3D.BONE_DIRECTION_PLUS_Y)
		sim.set_end_bone_length(i, b["length"])
		sim.set_center_from(i, SpringBoneSimulator3D.CENTER_FROM_WORLD_ORIGIN)
		sim.set_stiffness(i, feel[0])
		sim.set_drag(i, DRAG)
		sim.set_gravity(i, feel[1])
		sim.set_gravity_direction(i, Vector3.DOWN)
		sim.set_radius(i, feel[2])
		var hits: Array = [_add_floor(b, feel[2], feel[5]), _add_cap(b, feel[2], feel[3])]
		hits.append_array(_add_walls(b, feel[2], feel[4]))
		var fold := _add_fold(b, feel[2])
		if fold != null:
			hits.append(fold)
		for limb in limbs:
			if String(b["name"]).begins_with(limb["cloth"]) and b["on"] != limb["bone"]:
				hits.append(limb["node"])
		sim.set_enable_all_child_collisions(i, false)
		sim.set_collision_count(i, hits.size())
		for k in hits.size():
			sim.set_collision_path(i, k, sim.get_path_to(hits[k]))
	if fit_on and info.has("guards"):
		fit = SkeletonModifier3D.new()
		fit.set_script(FitScript)
		fit.name = "ClothFit"
		skeleton.add_child(fit)                     # after the simulator
		fit.setup(skeleton, bones, info["guards"])
		_fit_rate()
		Quality.changed.connect(_fit_rate)
	settle()
	skeleton.skeleton_updated.connect(_on_skeleton_updated)
	return true


## The fit is worked out every frame on High graphics, every 2nd on Medium and every 3rd on Low (cloth_fit.gd).
func _fit_rate() -> void:
	if fit:
		fit.every = [3, 2, 1][Quality.level]


## 23 Nov 2026: the cloth is taken off with its model (player.apply_skin swaps the hero's model): it stops listening to
## that skeleton.
func detach() -> void:
	if skeleton != null and is_instance_valid(skeleton) and skeleton.skeleton_updated.is_connected(_on_skeleton_updated):
		skeleton.skeleton_updated.disconnect(_on_skeleton_updated)


func _on_skeleton_updated() -> void:
	# the simulated pose only exists inside the skeleton's update; afterwards the bones go back to the clip's pose
	if not skeleton.is_inside_tree():
		return                                      # a model being taken away (an outfit swap)
	if measure:
		for b in bones:
			b["lift"] = _lift_now(b)
	if record:
		var count := skeleton.get_bone_count()
		pose_now.resize(count * 4)
		for i in count:
			var q := skeleton.get_bone_rest(i).basis.get_rotation_quaternion().inverse() * skeleton.get_bone_pose_rotation(i)
			pose_now[i * 4] = q.w
			pose_now[i * 4 + 1] = q.x
			pose_now[i * 4 + 2] = q.y
			pose_now[i * 4 + 3] = q.z
	for b in bones:                                 # which way is "off the body" for the cloth that billows
		if float(FEEL[b["kind"]][7]) > 0.0:
			b["out_now"] = skeleton.global_transform.basis * (skeleton.get_bone_global_pose(b["on"]).basis * b["rest_out"])


func _depth(all: Dictionary, n: String) -> int:
	var d := 0
	while all.has(n) and String(all[n]["parent"]) != "":
		n = all[n]["parent"]
		d += 1
	return d


func _kind(n: String) -> String:
	if n.begins_with("cape.arm"):
		return "cape_arm"
	if n == "hood.T":
		return "peak"
	if n.begins_with("hood.L") or n.begins_with("hood.R"):
		return "face_top" if n.ends_with(".1") else "face_low"
	if n.begins_with("hood"):
		return "hood_top" if n.ends_with(".1") else "hood_tip"
	if n.begins_with("cape"):
		return "cape_top" if n.ends_with(".1") else "cape_hem"
	if n.begins_with("cloak"):
		return "cloak_top" if n.ends_with(".1") else "cloak_hem"
	return "skirt"


func _tail_rest(b: Dictionary) -> Vector3:
	var rest := skeleton.get_bone_global_rest(b["bone"])
	return rest.origin + rest.basis.y.normalized() * b["length"]


func _add_floor(b: Dictionary, joint_radius: float, gap: float) -> SpringBoneCollisionPlane3D:
	# a plane through the resting cloth (a plane's +Y is its free side), carried by the body bone
	var rest := skeleton.get_bone_global_rest(b["bone"])
	var out := rest.basis.z.normalized()
	var along := rest.basis.y.normalized()
	var at := Transform3D(Basis(out.cross(along).normalized(), out, along), _tail_rest(b) - out * (joint_radius + gap))
	return _add_plane("floor_", b, at, Color(0.2, 0.7, 1.0, 0.6))


func _add_cap(b: Dictionary, joint_radius: float, most: float) -> SpringBoneCollisionPlane3D:
	# a plane across the cloth, part of the way down the bone: the tip has to stay beyond it, which keeps the bone
	# within `most` degrees of its resting direction. The plane rides on the body, not on the bone above, so for
	# the second bone of a chain it is moved back by as far as the first bone's swing can carry this one's head:
	# `most` then holds with the bone above at its own limit.
	var rest := skeleton.get_bone_global_rest(b["bone"])
	var out := rest.basis.z.normalized()
	var along := rest.basis.y.normalized()
	var carried := 0.0
	for p in bones:
		if p["name"] == b["parent"]:
			var above := skeleton.get_bone_global_rest(p["bone"])
			var turn := deg_to_rad(float(FEEL[p["kind"]][3]))
			var moved: Vector3 = (above.basis.y.normalized() * (cos(turn) - 1.0) + above.basis.z.normalized() * sin(turn)) * float(p["length"])
			carried = minf(moved.dot(along), 0.0)
	var at := Transform3D(Basis(out, along, out.cross(along).normalized()),
			rest.origin + along * (float(b["length"]) * cos(deg_to_rad(most)) + carried - joint_radius))
	return _add_plane("cap_", b, at, Color(1.0, 0.9, 0.2, 0.5))


func _add_walls(b: Dictionary, joint_radius: float, most: float) -> Array:
	# two planes, one each side of the bone, so it cannot slide round the body: cloth is a ring, a panel of it
	# cannot leave its place. As with the cap, the second bone of a chain gets the first bone's allowance on top.
	var rest := skeleton.get_bone_global_rest(b["bone"])
	var along := rest.basis.y.normalized()
	var across := rest.basis.x.normalized()
	var room := float(b["length"]) * sin(deg_to_rad(most))
	for p in bones:
		if p["name"] == b["parent"]:
			room += float(p["length"]) * sin(deg_to_rad(float(FEEL[p["kind"]][4])))
	var walls := []
	for way in [1.0, -1.0]:
		var inward: Vector3 = -across * way
		var at := Transform3D(Basis(along, inward, along.cross(inward).normalized()), rest.origin - inward * (room + joint_radius))
		walls.append(_add_plane("wall%s_" % ("a" if way > 0.0 else "b"), b, at, Color(0.9, 0.3, 0.9, 0.4)))
	return walls


func _add_fold(b: Dictionary, joint_radius: float) -> SpringBoneCollisionSphere3D:
	# the second bone of a chain may not fold back over the first. The first bone's head is fixed to the body, so
	# a ball round it does that: the second bone's tip has to stay outside, and the ball is as big as the two bones
	# bent FOLD degrees reach
	for p in bones:
		if p["name"] != b["parent"]:
			continue
		var top := skeleton.get_bone_global_rest(p["bone"]).origin
		var a := float(p["length"])
		var c := float(b["length"])
		var reach := sqrt(a * a + c * c + 2.0 * a * c * cos(deg_to_rad(FOLD)))
		reach = minf(reach, top.distance_to(_tail_rest(b)) - 0.004)         # never touching at rest
		var ball := SpringBoneCollisionSphere3D.new()
		ball.name = "fold_" + String(b["name"]).replace(".", "_")
		sim.add_child(ball)
		ball.bone_name = skeleton.get_bone_name(b["on"])
		ball.position_offset = skeleton.get_bone_global_rest(b["on"]).affine_inverse() * top
		ball.radius = reach - joint_radius
		ball.inside = false
		return ball
	return null


func _add_plane(prefix: String, b: Dictionary, at: Transform3D, colour: Color) -> SpringBoneCollisionPlane3D:
	var local := skeleton.get_bone_global_rest(b["on"]).affine_inverse() * at
	var plane := SpringBoneCollisionPlane3D.new()
	plane.name = prefix + String(b["name"]).replace(".", "_")
	sim.add_child(plane)
	plane.bone_name = skeleton.get_bone_name(b["on"])
	plane.position_offset = local.origin
	plane.rotation_offset = local.basis.orthonormalized().get_rotation_quaternion()
	if debug:
		var mesh := MeshInstance3D.new()
		var quad := BoxMesh.new()
		quad.size = Vector3(0.05, 0.002, 0.05)
		mesh.mesh = quad
		mesh.material_override = _debug_material(colour)
		plane.add_child(mesh)
	return plane


func _add_limbs() -> Array:
	# Capsules along the upper arms, thighs and shins. Each leaves the resting cloth untouched.
	var out := []
	for l in LIMBS:
		if not bones.any(func(b): return String(b["name"]).begins_with(l[3])):
			continue
		var bone := skeleton.find_bone(l[1])
		if bone < 0:
			continue
		var kids := skeleton.get_bone_children(bone)
		if kids.is_empty():
			continue
		var next := -1                                 # the bone the limb goes on with: not a cloth bone hung on it
		for k in kids:
			var kid := skeleton.get_bone_name(k)
			if not (kid.begins_with("cape.") or kid.begins_with("hood.") or kid.begins_with("skirt.") or kid.begins_with("cloak.")):
				next = k
				break
		if next < 0:
			continue
		var rest := skeleton.get_bone_global_rest(bone)
		var a := rest.origin
		var c := skeleton.get_bone_global_rest(next).origin
		var radius: float = l[2]
		for b in bones:
			if String(b["name"]).begins_with(l[3]) and b["on"] != bone:      # not the cloth that lies on this limb
				var gap := _to_segment(_tail_rest(b), a, c) - float(FEEL[b["kind"]][2]) - 0.004
				radius = minf(radius, gap)
		if radius < 0.012:
			continue
		var axis := (c - a).normalized()
		var side := axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
		var at := Transform3D(Basis(side, axis, side.cross(axis).normalized()), (a + c) * 0.5)
		var local := rest.affine_inverse() * at
		var cap := SpringBoneCollisionCapsule3D.new()
		cap.name = "limb_" + String(l[0]).replace(".", "_")
		sim.add_child(cap)
		cap.bone_name = l[1]
		cap.radius = radius
		cap.height = a.distance_to(c) + radius * 2.0
		cap.position_offset = local.origin
		cap.rotation_offset = local.basis.orthonormalized().get_rotation_quaternion()
		if debug:
			var mesh := MeshInstance3D.new()
			var shape := CapsuleMesh.new()
			shape.radius = radius
			shape.height = cap.height
			mesh.mesh = shape
			mesh.material_override = _debug_material(Color(1.0, 0.4, 0.2, 0.45))
			cap.add_child(mesh)
		out.append({"node": cap, "cloth": l[3], "radius": radius, "name": l[0], "bone": bone})
	return out


func _to_segment(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _debug_material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = true
	return m


func follow(cat_position: Vector3, delta: float) -> void:
	## Call once a frame after the cat has moved.
	if sim == null:
		return
	var velocity := Vector3.ZERO
	if _has_last and delta > 0.0:
		var step := cat_position - _last
		if step.length() > 0.5:                     # put somewhere else in one frame: not a movement
			sim.reset()
		else:
			velocity = step / delta
	_last = cat_position
	_has_last = true
	_t += delta
	# a breeze that wanders round the compass, with gusts
	var heading := 0.35 * _t + 1.3 * sin(0.21 * _t)
	var breeze := Vector3(cos(heading), 0.12 * sin(2.6 * _t), sin(heading))
	wind = breeze * (BREEZE + GUST * _gust(_t))
	# the simulator's drag is against still air: give back what it takes off cloth that only travels with the cat
	sim.external_force = velocity * DRAG
	# the air the cat runs through. It is not a steady stream: it comes and goes about twice a second (near the
	# cloth's own swing, so the flaps wave), wags sideways and lifts. Each bone meets it at its own moment, so the
	# flutter runs round the hem as a ripple. A bone's own wind goes in with its weight, the only force the
	# simulator takes per bone.
	var speed := velocity.length()
	var ahead := velocity / speed if speed > 0.01 else Vector3.ZERO
	var sideways := Vector3(-ahead.z, 0.0, ahead.x)
	var felt := WIND * speed * sqrt(minf(speed / FULL_SPEED, 1.0))
	for b in bones:
		var ph: float = b["phase"]
		var along := 0.5 * sin(11.0 * _t - ph) + 0.3 * sin(17.3 * _t - 1.7 * ph + 1.3) + 0.2 * sin(31.0 * _t - 2.3 * ph + 0.5)
		var across := 0.7 * sin(9.1 * _t - ph + 0.7) + 0.3 * sin(23.0 * _t - 2.0 * ph)
		var up := sin(13.7 * _t - 1.3 * ph + 2.1)
		var feel: Array = FEEL[b["kind"]]
		var own: float = felt * float(feel[6])
		var force := Vector3.DOWN * float(feel[1]) + breeze * ((BREEZE + GUST * _gust(_t - 0.25 * ph)) * float(feel[6]))
		force += ahead * (-own * (1.0 + FLUTTER * along)) + sideways * (own * FLUTTER * 0.6 * across)
		force += Vector3.UP * (own * (LIFT + FLUTTER * 0.4 * up))
		if float(feel[7]) > 0.0 and b.has("out_now"):       # air caught under the cloth, coming and going
			force += b["out_now"] * (own * float(feel[7]) * (0.55 + 0.45 * sin(8.3 * _t - ph)))
		var pull := force.length()
		sim.set_gravity(b["setting"], pull)
		sim.set_gravity_direction(b["setting"], force / pull if pull > 0.0001 else Vector3.DOWN)


func _gust(t: float) -> float:
	return maxf(0.0, sin(1.9 * t) * sin(0.73 * t + 1.0)) + 0.35 * maxf(0.0, sin(5.3 * t + 0.4))


func settle() -> void:
	## Forget all motion (after the cat is put somewhere else in one step).
	if sim != null:
		_has_last = false
		sim.external_force = Vector3.ZERO
		sim.reset()


func lift(b: Dictionary) -> Dictionary:
	## How far a cloth bone is from where it rests, in degrees: `out` away from the body, `side` along it, `off` in all;
	## `dip` is how far its tip is under where it rests, toward the body, in millimetres (0 or negative).
	## Needs `measure` switched on.
	return b.get("lift", {"out": 0.0, "side": 0.0, "off": 0.0, "dip": 0.0})


func _lift_now(b: Dictionary) -> Dictionary:
	var body := skeleton.get_bone_global_pose(b["on"])
	var now := skeleton.get_bone_global_pose(b["bone"]).basis.y.normalized()
	var rest: Vector3 = (body.basis * b["rest_dir"]).normalized()
	var out: Vector3 = (body.basis * b["rest_out"]).normalized()
	var side := rest.cross(out).normalized()
	return {"out": rad_to_deg(atan2(now.dot(out), now.dot(rest))), "side": rad_to_deg(asin(clampf(now.dot(side), -1.0, 1.0))),
			"off": rad_to_deg(acos(clampf(now.dot(rest), -1.0, 1.0))),
			"dip": minf(0.0, now.dot(out)) * float(b["length"]) * 1000.0}
