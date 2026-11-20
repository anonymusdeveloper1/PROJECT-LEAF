extends SkeletonModifier3D
## Keeps the simulated cloth off the body. Runs after the cloth simulation (cloth.gd adds it behind the simulator).
##
## The simulator only knows the tip of each cloth bone, and only tests it against a few planes and capsules. A panel
## of cloth is wider than its bone, the legs, arms and tail move under it, and the quiver sits on top of it, so
## cloth passed through all of those. (The pouch is not a guard: in the model it rides on the skirt.) Here every cloth bone carries a handful of points spread over its
## panel, and after the simulation each bone is turned, about its own head, until
##   - it is within its limits: how far it may lift off the body, sink toward it and swing sideways (for the second
##     bone of a chain: how far it may bend from the first), and
##   - none of its points is inside a guard: a capsule fixed to a body bone (assets/CatRanger_clips.json, "guards",
##     fitted to the model in Blender). Thighs, shins, arms, tail, quiver and arrows are solid: a point stays
##     outside their radius. Chest, shoulders, hips and head are "keep" guards: a point may not come nearer to their
##     axis than it is in the rest pose, which is where the cloth was modelled lying on them.
## A solid guard never asks for more room than the cloth has at rest, so the rest pose is always allowed.
## The simulator does not hear about the correction: it is made again every frame for as long as it is needed.
##
## Cost: about 2,250 point tests a frame, which was the biggest single cost of a frame in the camp. The tests are
## grouped by guard, and a guard the whole panel is clear of (checked once, with a sphere round the panel) is skipped
## without testing each point: the same result for less work. On Medium and Low graphics (`every` = 2 or 3) the
## fit is worked out every 2nd or 3rd frame, and the frames between reuse each bone's last correction, measured from
## what the bone hangs on so it moves with the body.

const MARGIN := 0.012               # metres kept between a point of cloth and a solid guard
const KEEP_SLACK := 0.004           # metres a point may come nearer to a "keep" guard's axis than at rest
const PASSES := 4                   # corrections per bone and frame, worst point first

# per kind of cloth (cloth.gd names them): half the panel's width at the bone's tip, the radius the panel curves
# round the body with (0 = flat), then the limits in degrees: furthest toward the body, furthest off it, furthest
# sideways. For the second bone of a chain the limits are measured from the first bone, not from the body.
const PANEL := {
	"skirt": [0.075, 0.16, -3.0, 50.0, 16.0],
	"cape_top": [0.040, 0.14, -3.0, 62.0, 16.0],
	"cape_hem": [0.045, 0.16, -10.0, 40.0, 18.0],
	"cape_arm": [0.045, 0.07, -3.0, 38.0, 14.0],
	"hood_top": [0.050, 0.12, -3.0, 38.0, 14.0],
	"hood_tip": [0.045, 0.12, -10.0, 45.0, 18.0],
	"face_top": [0.022, 0.0, -3.0, 32.0, 18.0],
	"face_low": [0.022, 0.0, -8.0, 30.0, 16.0],
	"peak": [0.040, 0.0, -3.0, 28.0, 8.0],
}
# which guards each kind of cloth is tested against
const AGAINST := {
	"skirt": ["thigh.L", "thigh.R", "shin.L", "shin.R", "tail.001", "tail.002", "hips"],
	"cape_top": ["upper_arm.L", "upper_arm.R", "forearm.L", "forearm.R", "quiver", "arrows", "chest", "shoulders"],
	"cape_hem": ["upper_arm.L", "upper_arm.R", "forearm.L", "forearm.R", "quiver", "arrows", "chest", "shoulders"],
	"cape_arm": ["forearm.L", "forearm.R", "quiver", "arrows"],     # of the forearms only its own arm's: see SAME_SIDE
	"hood_top": ["quiver", "arrows", "head", "shoulders"],
	"hood_tip": ["quiver", "arrows", "head", "shoulders", "chest"],
	"face_top": ["head"],
	"face_low": ["head", "chest"],
	"peak": ["head"],
}

# kinds of cloth that are only tested against guards on their own side of the body (a bone ending in .L against a
# guard ending in .L): the cloth on one arm has nothing to do with the other arm
const SAME_SIDE := ["cape_arm"]
# guards that lie on top of the cloth: cloth that meets one is turned back toward the body, not pushed on through it
const OVER := ["quiver", "arrows"]


## One cloth bone, in typed fields (dictionary look-ups in the inner loop were slow), its tests grouped by guard.
class Piece:
	var bone: int
	var on: int
	var above: int                  # the cloth bone it hangs from, or -1
	var samples: PackedVector3Array # points over its panel, in the bone's own axes
	var centre: Vector3             # the middle of the samples, in the bone's own axes
	var reach := 0.0                # how far the furthest sample is from the centre
	var gid: PackedInt32Array       # per guard it is tested against: which guard
	var gstart: PackedInt32Array    # ... where that guard's pairs start (one more entry at the end)
	var grmax: PackedFloat32Array   # ... the largest radius among them
	var ps: PackedInt32Array        # per pair: which sample
	var pr: PackedFloat32Array      # per pair: how far the sample must stay from the guard's axis
	var rel: Basis                  # rest, seen from what it hangs on
	var low: float
	var high: float
	var side: float
	var fix := Basis()              # its last correction, seen from what it hangs on (for the frames in between)
	var fixed := false

var bones: Array[Piece] = []
var guards: Array = []              # per guard: bone, a, b (in the bone's own axes), r, keep, over
var moved := 0                      # bones corrected in the last frame (read by the test)
var every := 1                      # work it out every n-th frame (Quality); in between the last corrections are reused
var check_restore := false          # test only: put the input pose back afterwards and keep the result in last_out
var last_out := {}                  # test only: bone -> corrected global pose
var _frame := 0
var _ga := PackedVector3Array()     # the guards' end points this frame, in the skeleton's space
var _gab := PackedVector3Array()    # ... b - a
var _ginv := PackedFloat32Array()   # ... 1 / |b - a|^2
var _gover := PackedByteArray()     # 1 = the guard lies over the cloth (OVER)
var _pts := PackedVector3Array()    # a bone's samples this pass, relative to its head


func setup(sk: Skeleton3D, cloth_bones: Array, guard_info: Array) -> void:
	var index := {}
	for g in guard_info:
		var bone := sk.find_bone(String(g["bone"]))
		if bone < 0:
			continue
		index[String(g["name"])] = guards.size()
		guards.append({"bone": bone, "a": _v(g["a"]), "b": _v(g["b"]), "r": float(g["r"]), "keep": bool(g["keep"]),
				"over": String(g["name"]) in OVER})
	_ga.resize(guards.size())
	_gab.resize(guards.size())
	_ginv.resize(guards.size())
	_gover.resize(guards.size())
	for i in guards.size():
		_gover[i] = 1 if guards[i]["over"] else 0
	var by_name := {}
	for c in cloth_bones:
		var kind := String(c["kind"])
		if not PANEL.has(kind):
			continue
		var panel: Array = PANEL[kind]
		var rest := sk.get_bone_global_rest(c["bone"])
		var above := -1
		var frame := sk.get_bone_global_rest(c["on"]).basis
		if String(c["parent"]) != "" and by_name.has(String(c["parent"])):
			above = bones[by_name[String(c["parent"])]].bone
			frame = sk.get_bone_global_rest(above).basis
		var length := float(c["length"])
		var half := minf(float(panel[0]), length * 0.9)
		var dip := -half * half / (2.0 * float(panel[1])) if float(panel[1]) > 0.0 else 0.0     # the panel curves toward the body
		var pc := Piece.new()
		for row in [[1.2, 1.0], [0.8, 0.9], [0.4, 0.75]]:      # three rows: the first is past the tip, the hem hangs lower
			var y: float = length * row[0]
			var x: float = half * row[1]
			pc.samples.append(Vector3(0.0, y, 0.0))
			pc.samples.append(Vector3(x, y, dip * row[1] * row[1]))
			pc.samples.append(Vector3(-x, y, dip * row[1] * row[1]))
		for v in pc.samples:
			pc.centre += v / float(pc.samples.size())
		for v in pc.samples:
			pc.reach = maxf(pc.reach, v.distance_to(pc.centre))
		var by_guard := {}                                  # guard -> [[sample, radius], ...]
		for i in pc.samples.size():
			var at: Vector3 = rest * pc.samples[i]
			for name in AGAINST.get(kind, []):
				if not index.has(name):
					continue
				var sided := String(name).ends_with(".L") or String(name).ends_with(".R")
				if kind in SAME_SIDE and sided and String(name).right(2) != String(c["name"]).right(2):
					continue
				var g: Dictionary = guards[index[name]]
				var home := sk.get_bone_global_rest(g["bone"])
				var room := at.distance_to(Geometry3D.get_closest_point_to_segment(at, home * g["a"], home * g["b"]))
				var radius := room - KEEP_SLACK if g["keep"] else minf(float(g["r"]) + MARGIN, room - 0.002)
				if radius > 0.01:
					if not by_guard.has(index[name]):
						by_guard[index[name]] = []
					by_guard[index[name]].append([i, radius])
		for gi in by_guard:
			pc.gid.append(gi)
			pc.gstart.append(pc.ps.size())
			var rmax := 0.0
			for pair in by_guard[gi]:
				pc.ps.append(pair[0])
				pc.pr.append(pair[1])
				rmax = maxf(rmax, pair[1])
			pc.grmax.append(rmax)
		pc.gstart.append(pc.ps.size())
		pc.bone = c["bone"]
		pc.on = c["on"]
		pc.above = above
		pc.rel = frame.orthonormalized().inverse() * rest.basis.orthonormalized()
		pc.low = deg_to_rad(float(panel[2]))
		pc.high = deg_to_rad(float(panel[3]))
		pc.side = deg_to_rad(float(panel[4]))
		by_name[String(c["name"])] = bones.size()
		bones.append(pc)
	_pts.resize(9)


func _v(a) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


func _process_modification_with_delta(_delta: float) -> void:
	var sk := get_skeleton()
	if sk == null or bones.is_empty():
		return
	_frame += 1
	if every > 1 and _frame % every != 0 and not check_restore:
		_reuse(sk)
		return
	for i in guards.size():
		var g: Dictionary = guards[i]
		var at := sk.get_bone_global_pose(g["bone"])
		var a: Vector3 = at * (g["a"] as Vector3)
		var ab: Vector3 = at * (g["b"] as Vector3) - a
		_ga[i] = a
		_gab[i] = ab
		_ginv[i] = 1.0 / ab.length_squared() if ab.length_squared() > 1e-12 else 0.0
	var before := {}
	if check_restore:
		last_out.clear()
		for b in bones:
			before[b.bone] = sk.get_bone_global_pose(b.bone)
	moved = 0
	for b in bones:                                         # a chain's first bone comes before its second
		var pose := sk.get_bone_global_pose(b.bone)
		var head := pose.origin
		var basis := pose.basis.orthonormalized()
		var sim_basis := basis
		var hung: int = b.above if b.above >= 0 else b.on
		var ref: Basis = sk.get_bone_global_pose(hung).basis.orthonormalized() * b.rel     # x across, y along, z off the body
		var changed := false
		var fixed := _within(basis, ref, b.low, b.high, b.side)
		if fixed != basis:
			basis = fixed
			changed = true
		var ns := b.samples.size()
		var ng := b.gid.size()
		for _pass in PASSES:
			for i in ns:
				_pts[i] = basis * b.samples[i]                  # relative to the head
			var c: Vector3 = head + basis * b.centre
			var worst := 0.0005
			var from := Vector3.ZERO
			var to := Vector3.ZERO
			var over := false
			for gi in ng:
				var g := b.gid[gi]
				var a: Vector3 = _ga[g]
				var ab: Vector3 = _gab[g]
				var inv: float = _ginv[g]
				# the whole panel is clear of this guard: none of its points can be inside it
				if c.distance_to(a + ab * clampf((c - a).dot(ab) * inv, 0.0, 1.0)) - b.reach >= b.grmax[gi]:
					continue
				for k in range(b.gstart[gi], b.gstart[gi + 1]):
					var p: Vector3 = head + _pts[b.ps[k]]
					var q: Vector3 = a + ab * clampf((p - a).dot(ab) * inv, 0.0, 1.0)     # nearest point on the guard's axis
					var d := p.distance_to(q)
					var r: float = b.pr[k]
					var inside: float = r - d
					if inside > worst and d > 0.0001:
						worst = inside
						from = p - head
						to = q + (p - q) * (r / d) - head
						over = _gover[g] == 1
			if from == Vector3.ZERO or to.length_squared() < 0.000001:
				break
			if over:                                        # under something: come back down by as much as it is in
				var v := ref.inverse() * basis.y.normalized()
				var lift := atan2(v.z, v.y)
				var lower := maxf(b.low, lift - clampf(worst / maxf(from.length(), 0.02), 0.01, 0.35))
				if lower >= lift - 0.0001:
					break
				basis = _within(basis, ref, b.low, lower, 3.2)
			else:
				basis = Basis(Quaternion(from.normalized(), to.normalized())) * basis
			changed = true
		b.fixed = changed
		if changed:
			basis = _within(basis, ref, b.low, 3.2, 3.2)     # a guard may push the cloth out, never into the body
			sk.set_bone_global_pose(b.bone, Transform3D(basis, head))
			moved += 1
			if every > 1:                                   # the turn it was given, seen from what it hangs on
				var rt := ref.transposed()
				b.fix = (rt * basis) * (rt * sim_basis).transposed()
	if check_restore:
		for b in bones:
			last_out[b.bone] = sk.get_bone_global_pose(b.bone)
		for b in bones:
			sk.set_bone_global_pose(b.bone, before[b.bone])


## A frame in between: each bone gets the turn it was given last time, measured from what it hangs on, so the
## correction moves with the body. It is off by at most a frame or two of swing.
func _reuse(sk: Skeleton3D) -> void:
	for b in bones:
		if not b.fixed:
			continue
		var pose := sk.get_bone_global_pose(b.bone)
		var hung: int = b.above if b.above >= 0 else b.on
		var ref: Basis = sk.get_bone_global_pose(hung).basis.orthonormalized() * b.rel
		var basis := (ref * b.fix * ref.transposed() * pose.basis.orthonormalized()).orthonormalized()
		sk.set_bone_global_pose(b.bone, Transform3D(basis, pose.origin))


func _within(basis: Basis, ref: Basis, low: float, high: float, side: float) -> Basis:
	## `basis` turned as little as needed for its Y (the bone) to be within the limits, measured in `ref`.
	var along := basis.y.normalized()
	var v := ref.inverse() * along
	var lift := atan2(v.z, v.y)
	var sway := asin(clampf(v.x, -1.0, 1.0))
	var lift_to := clampf(lift, low, high)
	var sway_to := clampf(sway, -side, side)
	if is_equal_approx(lift, lift_to) and is_equal_approx(sway, sway_to):
		return basis
	var want := ref * Vector3(sin(sway_to), cos(sway_to) * cos(lift_to), cos(sway_to) * sin(lift_to))
	return Basis(Quaternion(along, want.normalized())) * basis
