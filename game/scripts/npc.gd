extends Node3D
## Bramble, the hedgehog trader who stands by the Market Stall. He idles, waves when the cat walks up, and chats
## (Talk) while the stall's card is open. Model: res://assets/npcs/trader/trader.glb (clips Idle, Wave, Talk); until it
## exists a faceted placeholder stands in.

var main
var model: Node3D
var anim: AnimationPlayer
var _near := false
var _wave_t := 0.0


func setup(m, at: Vector3) -> void:
	main = m
	global_position = at
	Fx.blob(self, 0.4)
	var base := "res://assets/npcs/trader/trader"
	if ResourceLoader.exists(base + ".glb"):
		model = (load(base + ".glb") as PackedScene).instantiate()
		Props.apply_vc(model)
		add_child(model)
		anim = _find(model, "AnimationPlayer") as AnimationPlayer
		if anim:
			for c in ["Idle", "Talk"]:
				if anim.has_animation(c):
					anim.get_animation(c).loop_mode = Animation.LOOP_LINEAR
			if anim.has_animation("Idle"):
				anim.play("Idle")
		var sk := _find(model, "Skeleton3D") as Skeleton3D
		if sk and FileAccess.file_exists(base + ".json"):
			var j = JSON.parse_string(FileAccess.get_file_as_string(base + ".json"))
			if typeof(j) == TYPE_DICTIONARY and j.has("spring_chains"):
				_springs(sk, j["spring_chains"])
		return
	var mi := MeshInstance3D.new()
	mi.mesh = Props.build([
		[Props._ball(0.36, 0.62, 8), Props._at(0, 0.36, 0), Color(0.55, 0.36, 0.2)],
		[Props._ball(0.26, 0.42, 7), Props._at(0, 0.36, 0.14), Color(0.96, 0.88, 0.74)],
		[Props._ball(0.2, 0.3, 7), Props._at(0, 0.72, 0.1), Color(0.96, 0.88, 0.74)],
		[Props._box(0.5, 0.55, 0.3), Props._at(0, 0.6, -0.32), Color(0.4, 0.6, 0.3)],
		[Props._cyl(0.06, 0.06, 0.03, 8), Props._at(-0.07, 0.76, 0.27, Vector3(PI / 2, 0, 0)), Color(0.9, 0.75, 0.3)],
		[Props._cyl(0.06, 0.06, 0.03, 8), Props._at(0.07, 0.76, 0.27, Vector3(PI / 2, 0, 0)), Color(0.9, 0.75, 0.3)]])
	mi.material_override = Props.vc()
	add_child(mi)
	model = mi


## The scarf ends and the lantern swing on spring bones (jig.*), never keyed in the clips.
func _springs(sk: Skeleton3D, chains: Array) -> void:
	var ok: Array = []
	for c in chains:
		if sk.find_bone(String(c["root"])) >= 0 and sk.find_bone(String(c["end"])) >= 0:
			ok.append(c)
	if ok.is_empty():
		return
	var sim := SpringBoneSimulator3D.new()
	sk.add_child(sim)
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


func _find(n: Node, type: String) -> Node:
	if n.is_class(type):
		return n
	for c in n.get_children():
		var r := _find(c, type)
		if r != null:
			return r
	return null


func _process(delta: float) -> void:
	if main.frozen:
		return
	visible = not Save.ruined.has("stall")
	_wave_t = maxf(0.0, _wave_t - delta)
	var cat: Vector3 = main.player.global_position
	var to := cat - global_position
	to.y = 0.0
	var near := to.length() < 3.5
	if near:
		rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), 1.0 - exp(-5.0 * delta))
	else:
		rotation.y = lerp_angle(rotation.y, 0.0, 1.0 - exp(-2.0 * delta))
	if near and not _near:
		_wave_t = 1.2
		if anim and anim.has_animation("Wave"):
			anim.play("Wave", 0.15)
		elif model:
			Fx.boing(model, 0.2)
	_near = near
	if anim == null or _wave_t > 0.0:
		return
	var talking: bool = main.stations.rings.has("stall") and main.stations.rings["stall"].contains(cat)
	var clip := "Talk" if talking and anim.has_animation("Talk") else "Idle"
	if anim.current_animation != clip:
		anim.play(clip, 0.2)
