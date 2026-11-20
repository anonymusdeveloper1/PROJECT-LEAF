extends SkeletonModifier3D
## Sits the cat astride Thistle. It runs after the clip is applied and before body_twist.gd turns the hips, so the legs
## turn with the hips: the thighs swing forward and out round the saddle, the shins hang down the hare's sides and the
## feet point ahead. `amount` (0..1) blends it in and out as the cat hops on and off.

## Where each bone should point (its +Y axis) in skeleton space (Y up, +Z ahead), for the left side (+X); the right
## side is the mirror image.
const POSE := {
	"thigh": Vector3(0.75, -0.3, 0.6),
	"shin": Vector3(0.25, -0.95, -0.15),
	"foot": Vector3(0.1, -0.3, 1.0),
}

var amount := 0.0
var _bones := {}


func _process_modification_with_delta(_delta: float) -> void:
	if amount <= 0.001:
		return
	var sk := get_skeleton()
	if sk == null:
		return
	for side in ["L", "R"]:
		var sx := 1.0 if side == "L" else -1.0
		for part in ["thigh", "shin", "foot"]:          # in this order: each one moves the bones below it
			var bone := _bone(sk, "%s.%s" % [part, side])
			if bone < 0:
				continue
			var d: Vector3 = POSE[part]
			var want := Vector3(d.x * sx, d.y, d.z).normalized()
			var pose := sk.get_bone_global_pose(bone)
			var cur := pose.basis.y.normalized()
			if cur.dot(want) > 0.9999:
				continue
			var q := Quaternion.IDENTITY.slerp(Quaternion(cur, want), amount)
			pose.basis = Basis(q) * pose.basis
			sk.set_bone_global_pose(bone, pose)


func _bone(sk: Skeleton3D, n: String) -> int:
	if not _bones.has(n):
		_bones[n] = sk.find_bone(n)
	return _bones[n]
