extends Node3D
## Thistle, the giant meadow hare that came for the Market Stall's carrots. Tap Ride and it bounds over to the cat, which
## hops into the leaf saddle: the cat runs faster (balance.json "mount"), keeps shooting, can't hide in the grass, and
## Thistle thumps the ground when enemies crowd in (a shockwave that hurts and pushes them back). Tap Walk and Thistle
## hops back to the stall. Its level is the stall's level.
## Model: res://assets/companions/thistle/thistle.glb with thistle.json (clips Idle, Run, Thump; "saddle_height_m");
## until it exists a faceted placeholder stands in.

var main
var model: Node3D
var anim: AnimationPlayer
var meta: Dictionary = {}
var home := Vector3.ZERO
var _body: Node3D
var _ears: Array = []
var _t := 0.0
var _thump_cd := 1.0
var _spd := 0.0
var _hop := 0.0
var _thump_t := 0.0
var _skel: Skeleton3D
var _saddle := -1                                  # the rig's saddle bone: where the cat stands, as it bounds
var _track := Vector3.ZERO
var _was_riding := false
var hp := 0                                       # its health: it takes the hits while the cat rides it
var resting := 0.0                                # seconds before it can be ridden again after it was knocked out
var _regen_t := 0.0


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


## A different look for the same mount (the Stable at the Market Stall): only the model changes.
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
	_load_model()
	Fx.petals(main, global_position + Vector3(0, 0.8, 0))


## How high the cat stands on the saddle right now (it bobs with Thistle's hops).
func rider_height() -> float:
	if _saddle >= 0:
		return _saddle_world().y - global_position.y
	return float(meta.get("saddle_height_m", 0.98)) + _hop


func _saddle_world() -> Vector3:
	return _skel.global_transform * _skel.get_bone_global_pose(_saddle).origin


## Thistle bounds over to the cat in a puff of petals.
## Health grows with the Market Stall's level (balance.json mount.hp_by_level).
func max_hp() -> int:
	return int(Data.pick("mount", "hp_by_level", Data.mount_level()) * (1.0 + float(Data.run_mods.get("mount_hp", 0.0))))   # a saddle (Phase E)


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
		main.hud.refresh_build()


## Knocked out: it cannot be ridden until it is fed, a chapter break comes, or (outside missions) it has rested.
func out() -> bool:
	return resting > 0.0


## Back to full (chapter breaks, the end of a mission, a meal).
func refill() -> void:
	var was_out := resting > 0.0
	resting = 0.0
	hp = max_hp()
	if was_out and main != null and main.hud != null:
		main.hud.refresh_build()


func come_to(at: Vector3) -> void:
	Fx.petals(main, global_position + Vector3(0, 0.6, 0))
	global_position = Vector3(at.x, 0, at.z)
	Fx.petals(main, global_position + Vector3(0, 0.6, 0))
	Fx.dust(main, global_position, 8, 1.3)
	Fx.boing(_body, 0.3)


func _process(delta: float) -> void:
	if main.frozen:
		return
	_t += delta
	_thump_cd = maxf(0.0, _thump_cd - delta)
	_thump_t = maxf(0.0, _thump_t - delta)
	# knocked out: rest, then come back at full health; not ridden: get a little better every 2 s
	var below: bool = main.get("area") != null
	if below and not main.player.riding:
		# Phase E: the mount came down with the cat; it keeps near it (a knocked-out one limps after it)
		home = main.area.constrain(main.player.global_position + Vector3(1.1, 0, 0.7), 0.45, false)   # on the path, not in the trees
		if global_position.distance_to(home) > 8.0:
			global_position = home
	if resting > 0.0:
		if not main.fight.active and not below:       # in a mission or a run it stays out until fed (or a chapter break)
			resting -= delta
			if resting <= 0.0:
				resting = 0.01
				refill()
	elif not main.player.riding and hp < max_hp():
		_regen_t += delta
		if _regen_t >= 2.0:
			_regen_t = 0.0
			hp += 1
	hp = mini(hp, max_hp())
	if main.player.riding:
		var p: Vector3 = main.player.global_position
		var off := Vector3.ZERO                      # keep the saddle (at rest), not the hare's middle, under the cat
		if _saddle >= 0:
			off = _skel.global_transform * _skel.get_bone_global_rest(_saddle).origin - global_position
			off.y = 0.0
		global_position = Vector3(p.x, 0, p.z) - off
		if (main.fight.active or main.get("area") != null) and _thump_cd <= 0.0:
			var r := float(Data.b["mount"]["thump_range"])
			for e in get_tree().get_nodes_in_group("foes"):
				if not e.dead and not e.flyer and e.global_position.distance_to(global_position) < r + float(e.radius):
					_thump()
					break
	else:
		var to := home - global_position
		to.y = 0.0
		if to.length() > 0.08:
			global_position += to.normalized() * minf(3.0 * delta, to.length())
		elif absf(wrapf(rotation.y, -PI, PI)) > 0.02:
			rotation.y = lerp_angle(rotation.y, 0.0, 1.0 - exp(-4.0 * delta))
	# how fast and which way Thistle goes: the cat's own steps while riding (the saddle offset turns with the hare,
	# so its position would feed back into its own heading)
	var track: Vector3 = main.player.global_position if main.player.riding else global_position
	var moved := track - _track
	if _was_riding != main.player.riding:
		moved = Vector3.ZERO                         # a hop on or off is not a step
	_track = track
	_was_riding = main.player.riding
	moved.y = 0.0
	_spd = lerpf(_spd, moved.length() / maxf(delta, 0.0001), 1.0 - exp(-10.0 * delta))
	if moved.length() > 0.002:
		rotation.y = lerp_angle(rotation.y, atan2(moved.x, moved.z), 1.0 - exp(-10.0 * delta))
	# hopping: the body bounds, the ears swing back
	var running := _spd > 0.3
	var hop_goal := absf(sin(_t * 9.0)) * 0.12 if running else 0.0
	_hop = lerpf(_hop, hop_goal, 1.0 - exp(-14.0 * delta))
	if anim:
		if _thump_t <= 0.0:
			var clip := "Run" if running and anim.has_animation("Run") else "Idle"
			if anim.current_animation != clip:
				anim.play(clip, 0.15)
			if clip == "Run":
				var gs: Dictionary = meta.get("ground_speed_m_per_s", {})
				anim.speed_scale = clampf(_spd / maxf(float(gs.get("Run", 3.5)), 0.1), 0.6, 2.0)
			else:
				anim.speed_scale = 1.0
	else:
		_body.position.y = _hop
		_body.rotation.x = -0.12 * sin(_t * 9.0) if running else lerpf(_body.rotation.x, 0.0, 0.2)
		for i in _ears.size():
			var e: Node3D = _ears[i]
			e.rotation.x = lerpf(e.rotation.x, -0.25 - (0.5 if running else 0.08 * sin(_t * 2.0 + i)), 1.0 - exp(-8.0 * delta))


func _thump() -> void:
	var lv := Data.mount_level()
	_thump_cd = float(Data.b["mount"]["thump_every"])
	_thump_t = 0.5
	var r := float(Data.b["mount"]["thump_range"])
	var dmg := Data.pick("mount", "thump_damage_by_level", lv) * (1.0 + Data.meal_boost("friends")) * (1.0 + float(Data.run_mods.get("thump_mult", 0.0)))
	if anim and anim.has_animation("Thump"):
		anim.play("Thump", 0.05)
		_thump_t = anim.get_animation("Thump").length
	else:
		Fx.boing(_body, 0.35)
	Fx.shockwave(main, global_position, r + 0.4, Color(1.0, 0.9, 0.6))
	Fx.dust(main, global_position, 12, 1.6)
	Fx.text(main, global_position + Vector3(0, 2.0, 0), String(Data.look("mount", Save.mount_look).get("shout", "Thump!")), Color(1.0, 0.9, 0.55))
	main.shake(0.15)
	for e in get_tree().get_nodes_in_group("foes"):
		if e.dead or e.flyer:
			continue
		var d: Vector3 = e.global_position - global_position
		d.y = 0.0
		if d.length() < r + float(e.radius):
			e.hit(d.normalized() if d.length() > 0.01 else Vector3.FORWARD, dmg)
