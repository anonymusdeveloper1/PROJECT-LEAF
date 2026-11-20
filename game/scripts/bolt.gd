extends Node3D
## A glowing shot that flies on its own: Sprig's seed sparks (they hit enemies), and the Gloom bolts of the Frog Shaman
## and the Owl Witch (they hurt the cat, who can step aside). It flies at `speed`, turns toward its target by up to
## `homing` radians a second, and pops on a hit, at the edge of the firelight, or when its life runs out.

var main
var hurts_cat := false
var target = null
var dir := Vector3.FORWARD
var speed := 6.0
var homing := 0.0
var damage := 1.0
var life := 2.6
var color := Color(1, 1, 1)
var _trail: CPUParticles3D
var struct_target = null        # a building, tower or the campfire (enemy.gd handles): homes on it and hurts it


func launch(m, from: Vector3, direction: Vector3, spd: float, dmg: float, col: Color, cat_side: bool, homes_on = null,
		turn := 0.0, size := 0.11, life_s := 2.6) -> void:
	main = m
	speed = spd
	damage = dmg
	color = col
	hurts_cat = cat_side
	target = homes_on
	homing = turn
	life = life_s
	dir = direction.normalized() if direction.length() > 0.001 else Vector3.FORWARD
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = size
	s.height = size * 2.0
	s.radial_segments = 8
	s.rings = 4
	mi.mesh = s
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col.lightened(0.35)
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 2.0
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_trail = CPUParticles3D.new()
	var q := SphereMesh.new()
	q.radius = size * 0.45
	q.height = size * 0.9
	q.radial_segments = 6
	q.rings = 3
	_trail.mesh = q
	var tm := StandardMaterial3D.new()
	tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tm.vertex_color_use_as_albedo = true
	tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_trail.material_override = tm
	_trail.amount = 14
	_trail.lifetime = 0.35
	_trail.local_coords = false
	_trail.direction = Vector3.UP
	_trail.spread = 180.0
	_trail.initial_velocity_min = 0.05
	_trail.initial_velocity_max = 0.3
	_trail.gravity = Vector3.ZERO
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color(col, 0.8), Color(col.lightened(0.4), 0.0)])
	_trail.color_ramp = g
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_trail)
	global_position = from


func _aim_point(t) -> Vector3:
	if t == main.player:
		return main.player.global_position + Vector3(0, 0.55, 0)
	return (t as Node3D).global_position + Vector3(0, float(t.aim_height), 0)


func _physics_process(delta: float) -> void:
	if main == null or main.frozen:
		return
	life -= delta
	if target != null and (not is_instance_valid(target) or (not hurts_cat and target.dead)):
		target = null
	if target != null and homing > 0.0:
		var want := (_aim_point(target) - global_position).normalized()
		var ang := dir.angle_to(want)
		if ang > 0.0001:
			var axis := dir.cross(want)
			if axis.length() > 0.0001:
				dir = dir.rotated(axis.normalized(), minf(ang, homing * delta)).normalized()
	if struct_target != null:
		var goal: Vector3 = (struct_target.global_position as Vector3) + Vector3(0, 0.7, 0)
		dir = (goal - global_position).normalized()
		global_position += dir * speed * delta
		if global_position.distance_to(goal) < 0.6:
			struct_target.hurt(int(damage))
			_pop()
		elif life <= 0.0:
			_pop()
		return
	global_position += dir * speed * delta
	if hurts_cat:
		var p = main.player
		if p.hp > 0 and global_position.distance_to(p.global_position + Vector3(0, 0.55, 0)) < 0.42:
			p.hurt(global_position - dir, int(damage))
			_pop()
			return
		if main.world.inside_camp(global_position):
			_pop()
			return
	else:
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.dead:
				continue
			if global_position.distance_to(e.global_position + Vector3(0, e.aim_height, 0)) < e.radius + 0.12:
				e.hit(dir, damage)
				_pop()
				return
	if life <= 0.0 or global_position.y < 0.05:
		_pop()


func _pop() -> void:
	Fx.hit(main, global_position, color)
	queue_free()
