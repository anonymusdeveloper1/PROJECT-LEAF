extends SkeletonModifier3D
## Turns the hips (and with them the legs and tail) about the body's up axis and turns the spine and chest back,
## after the animation has been applied. The player sets the two angles every frame. It is how the cat runs one way
## while its upper body keeps aiming another.

var hips_yaw := 0.0          # radians, positive = to the cat's left
var upper_yaw := 0.0         # radians, shared equally by spine and chest
var aim_yaw := 0.0           # radians: where the arrow should point, seen from the body's own forward
var aim_lock := 0.0          # 0..1: how firmly the arrow is held on that line
var _arrow := -1
var _hips := -1
var _spine := -1
var _chest := -1


func _process_modification_with_delta(_delta: float) -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	if _hips < 0:
		_hips = sk.find_bone("hips")
		_spine = sk.find_bone("spine")
		_chest = sk.find_bone("chest")
		_arrow = sk.find_bone("arrow")
	_turn(sk, _hips, hips_yaw)
	_turn(sk, _spine, upper_yaw * 0.5)
	_turn(sk, _chest, upper_yaw * 0.5)
	# the run sways the hips and the body is still turning to its target: take up what is left, so the arrow on
	# the string points where the arrow in flight will go
	if aim_lock > 0.01 and _arrow >= 0:
		var shaft := sk.get_bone_global_pose(_arrow).basis.z
		var off := clampf(wrapf(atan2(shaft.x, shaft.z) - aim_yaw, -PI, PI), -0.5, 0.5) * aim_lock
		_turn(sk, _spine, -off * 0.5)
		_turn(sk, _chest, -off * 0.5)


func _turn(sk: Skeleton3D, bone: int, angle: float) -> void:
	if bone < 0 or absf(angle) < 0.0001:
		return
	var pose := sk.get_bone_global_pose(bone)                # skeleton space: Y is up; the bone keeps its place
	pose.basis = Basis(Vector3.UP, angle) * pose.basis
	sk.set_bone_global_pose(bone, pose)
