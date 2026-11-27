extends Node3D
## Sprig, the baby leaf dragon from the Mushroom Cottage. It flutters round the cat's shoulder and spits seed sparks
## (bolt.gd) at the nearest enemy. While the cat hides it only spits at enemies right next to it, so it never gives
## the cat away. Its level is the cottage's level (balance.json "pet").
## Model: res://assets/companions/sprig/sprig.glb with sprig.json (clips Idle, Fly, Attack; spring chains); until it
## exists a faceted placeholder flies instead.

const BoltScript := preload("res://scripts/bolt.gd")

var main
var model: Node3D
var anim: AnimationPlayer
var meta: Dictionary = {}
var _body: Node3D
var _wings: Array = []
var _t := 0.0
var _cd := 1.0
var _spit_t := 0.0
var _side := 1.0
var _vel := Vector3.ZERO


func setup(m) -> void:
	main = m
	_load_model()
	global_position = main.player.global_position + Vector3(0.6, 1.1, 0.4)
	scale = Vector3.ONE * 0.05
	create_tween().tween_property(self, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _load_model() -> void:
	var base := "res://assets/companions/%s/%s" % [Save.pet_look, Save.pet_look]
	if ResourceLoader.exists(base + ".glb"):
		model = (load(base + ".glb") as PackedScene).instantiate()
		if FileAccess.file_exists(base + ".json"):
			var j = JSON.parse_string(FileAccess.get_file_as_string(base + ".json"))
			if typeof(j) == TYPE_DICTIONARY:
				meta = j
		Props.apply_vc(model)
		Props.set_skin(model, Data.look("pet", Save.pet_look), Data.skin("pet", Save.pet_look, Save.pet_skin))
		model.scale = Vector3.ONE * 1.35            # a little bigger than life, so it reads over the grass on a phone
		add_child(model)
		_body = model
		anim = _find(model, "AnimationPlayer") as AnimationPlayer
		if anim:
			for c in ["Idle", "Fly", "Run"]:
				if anim.has_animation(c):
					anim.get_animation(c).loop_mode = Animation.LOOP_LINEAR
			_play("Fly" if _flies() else "Idle")
		var sk := _find(model, "Skeleton3D") as Skeleton3D
		if sk and meta.has("spring_chains"):
			_springs(sk, meta["spring_chains"])
		return
	_body = Node3D.new()
	add_child(_body)
	var mi := MeshInstance3D.new()
	var green := Color(0.42, 0.8, 0.3)
	mi.mesh = Props.build([
		[Props._ball(0.14, 0.24, 7), Props._at(0, 0.0, 0), green],
		[Props._ball(0.1, 0.13, 7), Props._at(0, -0.03, 0.06), Color(1.0, 0.82, 0.38)],
		[Props._ball(0.11, 0.18, 7), Props._at(0, 0.15, 0.06), green.lightened(0.08)],
		[Props._cyl(0.0, 0.035, 0.12, 5), Props._at(0, -0.04, -0.2, Vector3(-1.2, 0, 0)), green.darkened(0.15)],
		[Props._ball(0.05, 0.03, 5), Props._at(0, 0.27, 0.05), Color(1.0, 0.55, 0.75)],
		[Props._ball(0.025, 0.03, 5), Props._at(-0.05, 0.17, 0.15), Color(0.1, 0.1, 0.1)],
		[Props._ball(0.025, 0.03, 5), Props._at(0.05, 0.17, 0.15), Color(0.1, 0.1, 0.1)]])
	mi.material_override = Props.vc()
	_body.add_child(mi)
	for x in [-1.0, 1.0]:
		var w := MeshInstance3D.new()
		w.mesh = Props.build([[Props._cyl(0.0, 0.09, 0.22, 4), Props._at(x * 0.11, 0, 0, Vector3(0, 0, -x * PI / 2), Vector3(1.0, 1.0, 0.25)), Color(0.55, 0.88, 0.35)]])
		w.material_override = Props.vc()
		w.position = Vector3(x * 0.08, 0.05, -0.03)
		_body.add_child(w)
		_wings.append(w)


func _spark_color() -> Color:
	var c: Array = Data.look("pet", Save.pet_look).get("spark", [0.75, 1.0, 0.35])
	return Color(float(c[0]), float(c[1]), float(c[2]))


func _flies() -> bool:
	return bool(Data.look("pet", Save.pet_look).get("flies", true))


## A different look for the same pet (the Nest at the Mushroom Cottage): only the model changes.
func set_look() -> void:
	for c in get_children():
		c.queue_free()
	model = null
	anim = null
	meta = {}
	_body = null
	_wings.clear()
	_load_model()
	Fx.petals(main, global_position + Vector3(0, 0.5, 0))


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
		sim.set_end_bone_length(i, float(c.get("length", 0.05)))
		sim.set_center_from(i, SpringBoneSimulator3D.CENTER_FROM_WORLD_ORIGIN)
		sim.set_stiffness(i, float(c.get("stiffness", 2.0)))
		sim.set_drag(i, float(c.get("drag", 0.4)))
		sim.set_gravity(i, float(c.get("gravity", 0.2)))
		sim.set_gravity_direction(i, Vector3.DOWN)
		sim.set_radius(i, float(c.get("radius", 0.02)))


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


func _process(delta: float) -> void:
	if main.frozen:
		return
	visible = not Save.ruined.has("cottage")       # a ruined cottage: Sprig hides
	if not visible:
		global_position = main.world.station_pos("cottage") + Vector3(0, 1.0, 0)
		return
	_t += delta
	_cd = maxf(0.0, _cd - delta)
	_spit_t = maxf(0.0, _spit_t - delta)
	var cat: Vector3 = main.player.global_position
	var cat_face: float = main.player.facing
	# flutter round the cat's shoulder, swapping sides now and then
	if fmod(_t, 7.0) < delta:
		_side = -_side
	var flies := _flies()
	var lift := (1.15 + (0.75 if main.player.riding else 0.0)) if flies else 0.0
	var beside := (0.55 if flies else (1.25 if main.player.riding else 0.75))
	var offset := Vector3(_side * beside, lift + (0.08 * sin(_t * 2.3) if flies else 0.0), -0.25 if flies else -0.45).rotated(Vector3.UP, cat_face)
	var want := cat + offset
	var to := want - global_position
	_vel = _vel.lerp(to * 4.5, 1.0 - exp(-6.0 * delta))
	global_position += _vel * delta
	if not flies:
		global_position.y = 0.0
	if global_position.distance_to(want) > 6.0:
		global_position = want                         # after the cat respawns, say
	# look where it goes, or at what it spits at
	var look := _vel
	var tgt = _pick_target()
	if tgt != null:
		look = tgt.global_position - global_position
	look.y = 0.0
	if look.length() > 0.05:
		rotation.y = lerp_angle(rotation.y, atan2(look.x, look.z), 1.0 - exp(-8.0 * delta))
	if anim == null:
		for i in _wings.size():
			var w: Node3D = _wings[i]
			w.rotation.z = (0.5 + 0.5 * sin(_t * 22.0)) * (1.0 if i == 1 else -1.0) * 0.9
		_body.rotation.x = lerpf(_body.rotation.x, clampf(_vel.length() * 0.12, 0.0, 0.4), 1.0 - exp(-6.0 * delta))
	elif _spit_t <= 0.0:
		if _flies():
			_play("Fly" if _vel.length() > 0.6 else "Idle")
		else:
			_play("Run" if _vel.length() > 0.4 else "Idle")
			if anim and anim.current_animation == "Run":
				var gs: Dictionary = meta.get("ground_speed_m_per_s", {})
				anim.speed_scale = clampf(_vel.length() / maxf(float(gs.get("Run", 2.0)) * 1.35, 0.1), 0.6, 2.2)
			elif anim:
				anim.speed_scale = 1.0
	if tgt != null and _cd <= 0.0 and main.player.hp > 0:
		_spit(tgt)


func _pick_target():
	var lv := Data.pet_level()
	var reach := float(Data.b["pet"]["range"])
	if main.hidden:
		reach = minf(reach, 2.5)
	var best = null
	var best_d := reach
	for e in get_tree().get_nodes_in_group("foes"):
		if e.dead:
			continue
		var d: float = main.player.global_position.distance_to(e.global_position)
		if not e.awake and d > float(Data.burrow_cfg()["wake_r"]):
			continue                                    # Phase E: Sprig lets sleepers in a den sleep
		if d < best_d:
			best_d = d
			best = e
	return best if lv > 0 else null


func _spit(tgt) -> void:
	var lv := Data.pet_level()
	_cd = Data.pick("pet", "every_by_level", lv) / maxf(float(Data.run_mods.get("pet_rate", 1.0)), 0.1)   # Sprig's Fury (Phase E)
	_spit_t = 0.35
	if anim and anim.has_animation("Attack"):
		anim.play("Attack", 0.05)
	elif _body:
		Fx.boing(_body, 0.2)
	var fwd := Vector3(sin(rotation.y), 0, cos(rotation.y))
	var from := global_position + fwd * 0.18 + Vector3(0, 0.12, 0)
	var aim: Vector3 = tgt.global_position + Vector3(0, float(tgt.aim_height), 0)
	var b := BoltScript.new()
	main.add_child(b)
	b.launch(main, from, aim - from, float(Data.b["pet"]["bolt_speed"]), Data.pick("pet", "damage_by_level", lv) * (1.0 + float(Data.run_mods.get("pet_dmg", 0.0))),
		_spark_color(), false, tgt, 3.0, 0.07, 1.4)
