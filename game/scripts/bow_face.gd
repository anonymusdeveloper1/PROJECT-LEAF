extends SkeletonModifier3D
## 22 Nov 2026 (the owner: "the bow with the string shall be towards the cat in every animation"). While the bow is
## carried (not drawn), this turns the bow paw about the bow's own long axis, through the grip, so the string faces
## her chest, on foot and while riding. It runs after the riding modifier (ride_motion.gd), so it corrects whatever pose
## came before it. The player sets `weight` every frame (1 - aim_w: nothing while she draws and shoots, where the string
## already faces her). The turn is capped (balance.json cat.bow_face_max_deg) so the wrist never twists far.

var weight := 0.0
var max_turn := deg_to_rad(70.0)
var turned := 0.0                                      # the last turn, radians (the tests read it)
var turned_smooth := 0.0                               # the eased turn carried from frame to frame
var _last := 0.0                                       # last frame's wanted turn (keeps its sign near +-180 deg)
var _weapon := -1
var _string := -1
var _chest := -1
var _hand := -1


func _process_modification_with_delta(_delta: float) -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	if _weapon < 0:
		_weapon = sk.find_bone("weapon.L")
		_string = sk.find_bone("bowstring")
		_chest = sk.find_bone("chest")
		_hand = sk.get_bone_parent(_weapon) if _weapon >= 0 else -1
	turned = 0.0
	if weight <= 0.001 or _weapon < 0 or _string < 0 or _chest < 0 or _hand < 0:
		turned_smooth *= 0.65                          # eases back to nothing while she draws or fishes
		return
	var wp := sk.get_bone_global_pose(_weapon)
	var axis := wp.basis.y.normalized()                # the bow's long axis (along the limbs)
	var g := wp.origin                                 # the grip
	var a := sk.get_bone_global_pose(_string).origin - g
	var b := sk.get_bone_global_pose(_chest).origin - g
	a -= axis * a.dot(axis)                            # both seen across the bow's axis
	b -= axis * b.dot(axis)
	if a.length() < 0.0001 or b.length() < 0.0001:
		return
	var want := a.signed_angle_to(b, axis)
	# near +-180 deg the sign flips with tiny arm swings: keep turning the way it turned last frame (22 Nov review)
	if absf(want) > deg_to_rad(135.0) and absf(_last) > 0.001 and signf(want) != signf(_last):
		want = -want
	_last = want
	var target := clampf(want, -max_turn, max_turn) * weight
	turned = lerpf(turned_smooth, target, 0.35)        # eased, so a pose change never snaps the bow
	turned_smooth = turned
	var q := Basis(axis, turned)
	var hp := sk.get_bone_global_pose(_hand)
	hp.basis = q * hp.basis                            # the paw rolls in place (the wrist stays on the forearm, 22 Nov
	sk.set_bone_global_pose(_hand, hp)                 # review); the bow turns with it about its own long axis
