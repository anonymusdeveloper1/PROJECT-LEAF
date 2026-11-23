extends SkeletonModifier3D
## 22 Nov 2026 (the owner: "the cat is stationary while riding; make the cat move"): the seated cat rides. It runs after
## body_twist.gd (the turn for aiming is done) and before the cloth (so the hood, capelet and skirt swing with it), on
## the pose of the moment, only while she is on the mount (`amount`, 0..1, eased as she hops on and off). player.gd
## fills these in every frame from the mount's real motion (balance.json mount.ride_*):
##   fwd          the mount's forward in the skeleton's frame (she may aim elsewhere; she leans the way it goes)
##   hip_tilt     her hips rock with the saddle: a share of the saddle bone's own tilt (ride_follow)
##   upright      the share of that rocking her back takes back again (she sits more upright than the saddle)
##   lean         her back bends, radians: x forward (+) or back, y to her left (+) or right: the bounce giving under
##                her, her lean with speed and into turns, a slow sway standing still, the jolt of a skill
##   head_steady  the share of all this her head does not follow (a rider's head stays level)
##   aim, aim_steady  while she aims her chest, and so her arms and bow, keep the pose the aim gave them: drawing and
##                aiming are not touched
## While she does not aim, how she carries the bow (bow_*): from her carry pose of the moment (whatever the clips hold),
## the bow hand goes up, out and forward and the bow tips forward and its top out, about its grip; tipped further forward
## while its lower tip would still hang below the saddle (bow_clear above seat_y), up to bow_more_max. The arm follows the
## hand by a two-bone reach (upper arm and forearm, the elbow kept on its side). A new carry pose needs no change here.

var amount := 0.0
var fwd := Vector3(0, 0, 1)                            # +Z: the skeleton's own forward
var hip_tilt := Quaternion.IDENTITY
var upright := 0.0
var lean := Vector2.ZERO
var head_steady := 0.0
var aim := 0.0
var aim_steady := 1.0
# the bow carry (lengths in metres, angles in radians)
var bow_on := true
var bow_weapon := "weapon.L"                         # the bow bone (the hero's clips json, bones.bow_hand)
var bow_lo := -0.45                                  # how far the bow reaches along that bone's +Y: its lower tip ...
var bow_hi := 0.5                                    # ... and its upper tip
var bow_lift := 0.0
var bow_out := 0.0
var bow_fwd := 0.0
var bow_tilt_fwd := 0.0
var bow_tilt_out := 0.0
var bow_clear := 0.0
var bow_more_max := 0.0
var seat_y := 0.35                                   # the saddle's height in the skeleton's frame
var bow_extra := 0.0                                 # the extra forward tip the lower tip needs now (eased)
var bow_low_y := 0.0                                 # where the lower tip ended up (the tests read it), skeleton frame
# clear of the mount (the owner, 22 Nov 2026): points on its head, ears, horns and neck (mount.rider_hazards) must stay
# outside her spheres (player.rider_spheres) by clear_margin; she leans away (at most clear_max radians) when one comes in
var mount_skel: Skeleton3D
var hazards: Array = []                              # [[mount bone, point in its frame], ...]
var spheres: Array = []                              # [[her bone, centre in its frame, radius, name], ...]
var clear_margin := 0.03
var clear_max := 0.6
var clear_slide := 0.0                               # how far back on the saddle she may slide when leaning is not enough (m)
var clear_lean := Vector2.ZERO                       # the lean away she has now (eased), like `lean`
var clear_shift := Vector3.ZERO                      # the slide she has now (eased), skeleton frame
var clear_in := 0.0                                  # how far the worst mount point came inside (metres) before the lean away
var clear_left := INF                                # the tests: the closest any mount point is to her spheres after it (when measure)
var clear_what := ""                                 # ... and which of her spheres
var measure := false
var clear_on := true                                 # the tests turn it off to see the mount's reach without it

var _b := {}


func _process_modification_with_delta(delta: float) -> void:
	if amount <= 0.001:
		bow_extra = 0.0
		return
	var sk := get_skeleton()
	if sk == null:
		return
	var hips := _bone(sk, "hips")
	var spine := _bone(sk, "spine")
	var chest := _bone(sk, "chest")
	var neck := _bone(sk, "neck")
	var head := _bone(sk, "head")
	if hips < 0 or spine < 0 or chest < 0:
		return
	var chest0 := _q(sk, chest)
	var head0 := _q(sk, head) if head >= 0 else Quaternion.IDENTITY
	# 1. her hips rock with the saddle
	var ht := Quaternion.IDENTITY.slerp(hip_tilt, amount)
	_turn(sk, hips, ht)
	# 2. her back takes back part of it and bends with the lean: half at the spine, half at the chest (a curve)
	var back := _lean_q(lean * amount) * Quaternion.IDENTITY.slerp(ht.inverse(), clampf(upright, 0.0, 1.0))
	var half := Quaternion.IDENTITY.slerp(back, 0.5)
	_turn(sk, spine, half)
	_turn(sk, chest, half)
	# 2b. clear of the mount's head, ears and horns: she leans away (and slides back a little if that is not enough),
	# quickly in and slowly back
	var pts := _hazard_points(sk)
	var need: Array = _clear_need(sk, spine, pts)
	var lean_want: Vector2 = need[0] if clear_on else Vector2.ZERO
	var shift_want: Vector3 = need[1] if clear_on else Vector3.ZERO
	var rate := 30.0 if lean_want.length() > clear_lean.length() else 5.0
	clear_lean = clear_lean.lerp(lean_want, 1.0 - exp(-rate * maxf(delta, 0.0)))
	var rate2 := 30.0 if shift_want.length() > clear_shift.length() else 5.0
	clear_shift = clear_shift.lerp(shift_want, 1.0 - exp(-rate2 * maxf(delta, 0.0)))
	if clear_shift.length() > 0.0001:
		var hp := sk.get_bone_global_pose(hips)
		hp.origin += clear_shift * amount
		sk.set_bone_global_pose(hips, hp)
	# 3. aiming: the chest (arms, bow) turned back to the pose the aim gave it
	var hold := clampf(aim * aim_steady, 0.0, 1.0)
	if hold > 0.001:
		_turn(sk, chest, Quaternion.IDENTITY.slerp(chest0 * _q(sk, chest).inverse(), hold))
	# 4. her head stays level: neck and head turn back toward how they were, half each
	if head >= 0 and head_steady > 0.001:
		var k := clampf(head_steady, 0.0, 1.0)
		var cur := _q(sk, head)
		var want := Quaternion.IDENTITY.slerp(head0 * cur.inverse(), k) * cur
		if neck >= 0:
			_turn(sk, neck, Quaternion.IDENTITY.slerp(head0 * cur.inverse(), k * 0.5))
		_turn(sk, head, want * _q(sk, head).inverse())
	# 4b. (22 Nov review) the lean away from the mount's head comes last, as one turn at the spine (the stiff lean 2b
	# measured), so steps 3 and 4 no longer undo it while she aims: her whole upper body and head move clear together
	if clear_lean.length() > 0.0001:
		_turn(sk, spine, _lean_q(clear_lean * amount))
	if measure:
		_measure_left(sk, pts)
	# 5. the bow, carried (not while she aims)
	var bw := amount * (1.0 - clampf(aim, 0.0, 1.0)) if bow_on else 0.0
	if bw > 0.001:
		_carry_bow(sk, bw, delta)
	else:
		bow_extra = move_toward(bow_extra, 0.0, delta * 2.0)


## The mount's hazard points now, in her skeleton's frame ([] without a mount skeleton).
func _hazard_points(sk: Skeleton3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	if mount_skel == null or not is_instance_valid(mount_skel) or hazards.is_empty() or spheres.is_empty():
		return out
	var to_her := sk.global_transform.affine_inverse() * mount_skel.global_transform
	var poses := {}
	for hz in hazards:
		var b: int = hz[0]
		if not poses.has(b):
			poses[b] = to_her * mount_skel.get_bone_global_pose(b)
		out.append((poses[b] as Transform3D) * (hz[1] as Vector3))
	return out


## The lean away (like `lean`: x forward, y to her left, radians) and the slide back (skeleton frame, metres) that take
## her spheres clear of the points, as [lean, slide]. A few steps, each on where the spheres would then be: the deepest
## point inside any sphere pushes it straight away from that point (level; straight back when the push is mostly up or
## down), as an angle about her spine's root; past clear_max the rest is a slide, at most clear_slide.
func _clear_need(sk: Skeleton3D, spine: int, pts: PackedVector3Array) -> Array:
	clear_in = 0.0
	if pts.is_empty():
		return [Vector2.ZERO, Vector3.ZERO]
	var f := Vector3(fwd.x, 0.0, fwd.z).normalized()
	var left := f.rotated(Vector3.UP, PI * 0.5)
	var pivot := sk.get_bone_global_pose(spine).origin
	var cs: Array = []
	for sph in spheres:
		cs.append(sk.get_bone_global_pose(sph[0]) * (sph[1] as Vector3))
	var lean_v := Vector2.ZERO
	var shift := Vector3.ZERO
	for it in 5:
		var rot := _lean_q(lean_v)
		var worst := 0.0
		var dir := Vector3.ZERO
		var at := Vector3.ZERO
		for i in spheres.size():
			var c: Vector3 = pivot + rot * ((cs[i] as Vector3) - pivot) + shift
			var r: float = float(spheres[i][2]) + clear_margin
			for p in pts:
				var d := c - p
				var dl := d.length()
				if dl < r and r - dl > worst:
					worst = r - dl
					dir = d / maxf(dl, 0.0001)
					at = c
		if it == 0:
			clear_in = worst
		if worst <= 0.002:
			break
		var flat := Vector3(dir.x, 0.0, dir.z)
		flat = flat.normalized() if flat.length() > 0.3 else -f
		var add := Vector2(flat.dot(f), flat.dot(left)) * (worst * 1.15 / maxf((at - pivot).length(), 0.1))
		var to := lean_v + add
		if to.length() <= clear_max:
			lean_v = to
		else:
			var room := maxf(0.0, clear_max - lean_v.length())
			lean_v = (lean_v + add.normalized() * room).limit_length(clear_max)
			var used := room * maxf((at - pivot).length(), 0.1)
			shift = (shift + flat * maxf(0.0, worst * 1.15 - used)).limit_length(clear_slide)
	return [lean_v, shift]


## The tests: how close the mount's points come to her spheres now (after the lean away), and to which sphere.
func _measure_left(sk: Skeleton3D, pts: PackedVector3Array) -> void:
	clear_left = INF
	clear_what = ""
	for sph in spheres:
		var c: Vector3 = sk.get_bone_global_pose(sph[0]) * (sph[1] as Vector3)
		for p in pts:
			var g := c.distance_to(p) - float(sph[2])
			if g < clear_left:
				clear_left = g
				clear_what = String(sph[3])


## Rotation that bends her: lean.x forward along fwd, lean.y toward her left (radians, small).
func _lean_q(v: Vector2) -> Quaternion:
	var f := Vector3(fwd.x, 0.0, fwd.z).normalized()
	var left := f.rotated(Vector3.UP, PI * 0.5)
	var l := f * v.x + left * v.y
	if l.length() < 0.00001:
		return Quaternion.IDENTITY
	return Quaternion(Vector3.UP.cross(l).normalized(), l.length())


## The bow hand to its carry while seated (see the top), weight bw.
func _carry_bow(sk: Skeleton3D, bw: float, delta: float) -> void:
	var weapon := _bone(sk, bow_weapon)
	if weapon < 0:
		return
	var hand := sk.get_bone_parent(weapon)
	var fore := sk.get_bone_parent(hand) if hand >= 0 else -1
	var upper := sk.get_bone_parent(fore) if fore >= 0 else -1
	if upper < 0:
		return
	var f := Vector3(fwd.x, 0.0, fwd.z).normalized()
	var left := f.rotated(Vector3.UP, PI * 0.5)
	var p_axis := Vector3.UP.cross(f).normalized()        # turning about it tips the top forward
	var r_axis := Vector3.UP.cross(left).normalized()     # ... the top toward her left (out, away from the mount)
	var wp := sk.get_bone_global_pose(weapon)
	var hp := sk.get_bone_global_pose(hand)
	var grip := wp.origin
	var along := wp.basis.y.normalized()
	var off := Vector3.UP * bow_lift + left * bow_out + f * bow_fwd
	var r := Quaternion(r_axis, bow_tilt_out) * Quaternion(p_axis, bow_tilt_fwd)
	# how much further forward the lower tip needs (1 degree steps, never past 10 degrees above level)
	var need := 0.0
	var step := deg_to_rad(1.0)
	while need < bow_more_max:
		var d := Quaternion(p_axis, need) * r * along
		if (grip + off + d * bow_lo).y >= seat_y + bow_clear or d.y < 0.17:
			break
		need += step
	bow_extra = lerpf(bow_extra, need, 1.0 - exp(-8.0 * maxf(delta, 0.0)))
	var rq := Quaternion.IDENTITY.slerp(Quaternion(p_axis, bow_extra) * r, bw)
	var to := grip + rq * (hp.origin - grip) + off * bw
	var basis := Basis(rq) * hp.basis
	_reach(sk, upper, fore, hand, to)
	var hp2 := sk.get_bone_global_pose(hand)
	hp2.basis = basis
	sk.set_bone_global_pose(hand, hp2)
	var wp2 := sk.get_bone_global_pose(weapon)
	bow_low_y = (wp2.origin + wp2.basis.y.normalized() * bow_lo).y


## Two bones (upper arm, forearm) turned so the hand's root reaches `to` (or as near as the arm allows), the elbow kept
## on the side it was.
func _reach(sk: Skeleton3D, upper: int, fore: int, hand: int, to: Vector3) -> void:
	var s := sk.get_bone_global_pose(upper).origin
	var e := sk.get_bone_global_pose(fore).origin
	var h := sk.get_bone_global_pose(hand).origin
	var a := s.distance_to(e)
	var b := e.distance_to(h)
	var dv := to - s
	if a < 0.0001 or b < 0.0001 or dv.length() < 0.0001:
		return
	var d := clampf(dv.length(), absf(a - b) + 0.001, a + b - 0.001)
	var u := dv.normalized()
	var n := (e - s).cross(h - s)
	if n.length() < 0.000001:
		n = Vector3.UP.cross(u)
		if n.length() < 0.000001:
			n = Vector3.RIGHT
	n = n.normalized()
	var al := acos(clampf((a * a + d * d - b * b) / (2.0 * a * d), -1.0, 1.0))
	var e1 := s + u.rotated(n, al) * a
	var e2 := s + u.rotated(n, -al) * a
	var e_new := e1 if e1.distance_to(e) <= e2.distance_to(e) else e2
	_turn(sk, upper, _arc((e - s), (e_new - s)))
	var e3 := sk.get_bone_global_pose(fore).origin
	var h3 := sk.get_bone_global_pose(hand).origin
	_turn(sk, fore, _arc(h3 - e3, (s + u * d) - e3))


## The shortest turn from direction a to direction b.
func _arc(a: Vector3, b: Vector3) -> Quaternion:
	if a.length() < 0.000001 or b.length() < 0.000001:
		return Quaternion.IDENTITY
	var an := a.normalized()
	var bn := b.normalized()
	if an.dot(bn) > 0.999999:
		return Quaternion.IDENTITY
	return Quaternion(an, bn)


## A bone turned by q in the skeleton's frame, about its own root.
func _turn(sk: Skeleton3D, bone: int, q: Quaternion) -> void:
	if bone < 0 or q.is_equal_approx(Quaternion.IDENTITY):
		return
	var p := sk.get_bone_global_pose(bone)
	p.basis = Basis(q) * p.basis
	sk.set_bone_global_pose(bone, p)


## A bone's turn in the skeleton's frame (its scale left out).
func _q(sk: Skeleton3D, bone: int) -> Quaternion:
	return Quaternion(sk.get_bone_global_pose(bone).basis.orthonormalized())


func _bone(sk: Skeleton3D, n: String) -> int:
	if not _b.has(n):
		_b[n] = sk.find_bone(n)
	return _b[n]
