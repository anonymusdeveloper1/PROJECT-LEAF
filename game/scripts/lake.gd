extends Node3D
## The lake by the tree home. One irregular outline (shore_r) drives everything: the water mesh, the sandy shore the
## ground shader paints, the rocks and reeds round the edge, and keeping walkers out of the water. On it: bobbing
## lily pads, a little dock from the home's side, fireflies, and now and then a fish that jumps with a splash.

const WATER := preload("res://shaders/water.gdshader")

var world
var center := Vector3.ZERO
var base_r := 2.5
var _pads: Array = []
var _fish: Node3D
var _fish_t := 4.0
var _fish_from := Vector3.ZERO
var _fish_to := Vector3.ZERO
var _t := 0.0
var rng := RandomNumberGenerator.new()


func setup(w, c: Vector3, r: float) -> void:
	world = w
	center = c
	base_r = r
	rng.seed = 515
	_water()
	_shore()
	_pads_and_dock()
	_fireflies()
	_make_fish()
	var gm: ShaderMaterial = world._ground_mat
	gm.set_shader_parameter("lake_center", Vector2(c.x, c.z))
	gm.set_shader_parameter("lake_r", r)


## The shore's distance from the centre at angle theta (the same formula is in ground.gdshader).
func shore_r(theta: float) -> float:
	return base_r * (1.0 + 0.16 * sin(2.0 * theta + 1.3) + 0.10 * sin(3.0 * theta + 0.4) + 0.06 * sin(5.0 * theta + 2.1))


## How far p is outside the water (negative inside).
func dist(p: Vector3) -> float:
	var dx := p.x - center.x
	var dz := p.z - center.z
	return sqrt(dx * dx + dz * dz) - shore_r(atan2(dz, dx))


## Pushes a walker of radius r back onto the shore.
func push_out(q: Vector2, r: float) -> Vector2:
	var dx := q.x - center.x
	var dz := q.y - center.z
	var l := sqrt(dx * dx + dz * dz)
	var edge := shore_r(atan2(dz, dx)) + r
	if l < edge:
		var dir := Vector2(dx, dz) / l if l > 0.001 else Vector2(1, 0)
		return Vector2(center.x, center.z) + dir * edge
	return q


func _water() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 56
	var rings := [1.0, 0.8, 0.55, 0.3, 0.0]
	for k in n:
		var a0 := TAU * k / n
		var a1 := TAU * (k + 1) / n
		var r0 := shore_r(a0) + 0.08
		var r1 := shore_r(a1) + 0.08
		for j in rings.size() - 1:
			var fo: float = rings[j]
			var fi: float = rings[j + 1]
			var p00 := Vector3(cos(a0) * r0 * fo, 0, sin(a0) * r0 * fo)
			var p01 := Vector3(cos(a1) * r1 * fo, 0, sin(a1) * r1 * fo)
			var p10 := Vector3(cos(a0) * r0 * fi, 0, sin(a0) * r0 * fi)
			var p11 := Vector3(cos(a1) * r1 * fi, 0, sin(a1) * r1 * fi)
			for v in [[p00, fo], [p01, fo], [p10, fi], [p01, fo], [p11, fi], [p10, fi]]:
				st.set_uv(Vector2(1.0 - v[1], 0))
				st.set_normal(Vector3.UP)
				st.add_vertex(v[0])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := ShaderMaterial.new()
	m.shader = WATER
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = center + Vector3(0, 0.03, 0)
	add_child(mi)


func _ring_point(theta: float, out: float) -> Vector3:
	var r := shore_r(theta) + out
	return center + Vector3(cos(theta) * r, 0, sin(theta) * r)


func _shore() -> void:
	# mossy rocks round the edge, in little groups, and reeds and cattails between them
	var rocks := {"rock_1": [], "rock_2": [], "stepping_stone": []}
	var a := 0.0
	while a < TAU:
		var pick := rng.randf()
		var kind := "rock_1" if pick < 0.5 else ("rock_2" if pick < 0.72 else "stepping_stone")
		var sc := rng.randf_range(0.5, 1.0) if kind != "rock_2" else rng.randf_range(0.45, 0.75)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc), _ring_point(a, rng.randf_range(0.0, 0.3)))
		if _clear_of_fishing(xf.origin):
			rocks[kind].append(xf)
		a += rng.randf_range(0.18, 0.5)
	for kind in rocks:
		_multi(Props.mesh(kind), rocks[kind])
	var reeds: Array = []
	var reed_mesh := _reed_mesh()
	for k in 7:
		var c := rng.randf() * TAU
		for j in rng.randi_range(4, 7):
			var p := _ring_point(c + rng.randf_range(-0.2, 0.2), rng.randf_range(-0.35, 0.15))
			var rx := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.25)), p)
			if _clear_of_fishing(p):
				reeds.append(rx)
	_multi(reed_mesh, reeds)


## Nothing stands in front of the Fishing Spot's ring, or under the well (or any camp building) or on its ring (every
## random number is still drawn, so the rest of the shore stays where it was).
func _clear_of_fishing(p: Vector3) -> bool:
	var f: Vector3 = world.FISH_RING
	return Vector2(p.x - f.x, p.z - f.z).length() >= 1.1 and not world.in_village(p, -0.3)


func _multi(mesh: Mesh, xfs: Array) -> void:
	if xfs.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for k in xfs.size():
		mm.set_instance_transform(k, xfs[k])
		mm.set_instance_custom_data(k, Color(0, 0, 0, 0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = Props.vc_multi()
	add_child(mmi)


func _reed_mesh() -> ArrayMesh:
	var parts: Array = []
	var green := Color(0.36, 0.58, 0.22)
	var dark := Color(0.25, 0.45, 0.16)
	for k in 5:
		var a := TAU * k / 5.0
		var h := 0.75 + 0.1 * k
		var off := Vector3(cos(a), 0, sin(a)) * 0.05
		var tilt := Vector3(sin(a) * 0.12, 0, -cos(a) * 0.12)
		parts.append([Props._cyl(0.006, 0.013, h, 4), Props._at(off.x, h * 0.5, off.z, tilt), green if k % 2 == 0 else dark])
		if k % 2 == 1:
			parts.append([Props._cyl(0.03, 0.03, 0.17, 6), Props._at(off.x + tilt.x * h, h - 0.06, off.z - tilt.z * h, tilt), Color(0.48, 0.3, 0.17)])
	for k in 3:
		var a := TAU * k / 3.0 + 0.5
		parts.append([Props._cyl(0.0, 0.03, 0.6, 3), Props._at(cos(a) * 0.06, 0.3, sin(a) * 0.06, Vector3(sin(a) * 0.35, 0, -cos(a) * 0.35)), Color(0.42, 0.66, 0.26)])
	return Props.build(parts)


func _pads_and_dock() -> void:
	var pad := Props.build([[Props._cyl(0.26, 0.26, 0.02, 9), Props._at(0, 0, 0), Color(0.33, 0.6, 0.24)],
		[Props._cyl(0.2, 0.2, 0.025, 9), Props._at(0, 0.002, 0), Color(0.42, 0.68, 0.28)]])
	var pad_flower := Props.build([[Props._cyl(0.26, 0.26, 0.02, 9), Props._at(0, 0, 0), Color(0.33, 0.6, 0.24)],
		[Props._ball(0.07, 0.07, 6), Props._at(0.05, 0.05, 0.02), Color(1.0, 0.62, 0.78)],
		[Props._ball(0.035, 0.04, 5), Props._at(0.05, 0.08, 0.02), Color(1.0, 0.9, 0.5)]])
	for k in 9:
		var a := rng.randf() * TAU
		var p := center + Vector3(cos(a), 0, sin(a)) * shore_r(a) * rng.randf_range(0.25, 0.8)
		var mi := MeshInstance3D.new()
		mi.mesh = pad_flower if k % 3 == 0 else pad
		mi.material_override = Props.vc()
		mi.position = p + Vector3(0, 0.05, 0)
		mi.rotation.y = rng.randf() * TAU
		mi.scale = Vector3.ONE * rng.randf_range(0.8, 1.3)
		add_child(mi)
		_pads.append(mi)
	# a little dock reaching out from the side that faces the home (the big home's side at every level, so it never
	# lands on the well, which stands on the near shore)
	var home: Vector3 = world.HOME_SPOT
	var ang := atan2(home.z - center.z, home.x - center.x) + 0.55
	var start := _ring_point(ang, 0.25)
	var dir := (center - start)
	dir.y = 0.0
	dir = dir.normalized()
	var parts: Array = []
	var wood := Color(0.62, 0.42, 0.25)
	var wood_d := Color(0.45, 0.3, 0.18)
	var length := 2.0
	for k in 8:
		var along := 0.15 + k * (length - 0.2) / 7.0
		parts.append([Props._box(0.9, 0.06, 0.2), Props._at(0, 0.12, along, Vector3(0, 0.02 * sin(k * 2.3), 0)), wood if k % 2 == 0 else wood.lightened(0.08)])
	for side in [-1.0, 1.0]:
		parts.append([Props._box(0.08, 0.08, length), Props._at(side * 0.36, 0.06, length * 0.5), wood_d])
		for along in [0.2, length - 0.1]:
			parts.append([Props._cyl(0.05, 0.05, 0.5, 6), Props._at(side * 0.4, -0.05, along), wood_d])
	var dock := MeshInstance3D.new()
	dock.mesh = Props.build(parts)
	dock.material_override = Props.vc()
	dock.position = start
	dock.basis = Basis.looking_at(-dir, Vector3.UP)
	add_child(dock)


func _fireflies() -> void:
	var p := CPUParticles3D.new()
	var q := SphereMesh.new()
	q.radius = 0.025
	q.height = 0.05
	q.radial_segments = 6
	q.rings = 3
	p.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	p.material_override = m
	p.amount = Quality.particles(16)
	p.lifetime = 4.0
	p.preprocess = 4.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(base_r * 1.1, 0.4, base_r * 1.1)
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.25
	p.gravity = Vector3.ZERO
	p.linear_accel_min = -0.15
	p.linear_accel_max = 0.15
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.5, 0.8, 1.0])
	g.colors = PackedColorArray([Color(1.0, 1.0, 0.5, 0.0), Color(1.0, 1.0, 0.55, 1.0) * 2.0, Color(0.8, 1.0, 0.4, 0.4), Color(1.0, 1.0, 0.55, 1.0) * 2.0, Color(1.0, 1.0, 0.5, 0.0)])
	p.color_ramp = g
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	p.position = center + Vector3(0, 0.7, 0)


func _make_fish() -> void:
	_fish = MeshInstance3D.new()
	(_fish as MeshInstance3D).mesh = Props.build([
		[Props._ball(0.07, 0.07, 6), Props._at(0, 0, 0, Vector3.ZERO, Vector3(1.0, 1.0, 2.2)), Color(1.0, 0.55, 0.25)],
		[Props._cyl(0.0, 0.07, 0.12, 3), Props._at(0, 0, -0.17, Vector3(-PI / 2, 0, 0), Vector3(1.0, 1.0, 0.3)), Color(1.0, 0.75, 0.4)]])
	(_fish as MeshInstance3D).material_override = Props.vc()
	_fish.visible = false
	add_child(_fish)


func _splash(at: Vector3) -> void:
	splash(at)


## A splash on the water (a jumping fish, the fishing float).
func splash(at: Vector3) -> void:
	Fx._burst(world.main, at + Vector3(0, 0.05, 0), Fx._grad([Color(0.85, 0.97, 1.0), Color(0.55, 0.85, 0.95), Color(1, 1, 1)]),
		12, 2.2, 0.6, 0.9, -6.0, 40.0)
	Fx.shockwave(world.main, at, 0.9, Color(0.8, 0.95, 1.0))


func _process(delta: float) -> void:
	_t += delta
	for k in _pads.size():
		var pad: Node3D = _pads[k]
		pad.position.y = 0.05 + sin(_t * 1.3 + k * 1.7) * 0.012
		pad.rotation.y += sin(_t * 0.3 + k) * 0.0015
	# now and then a fish jumps out of the water
	_fish_t -= delta
	if _fish_t <= 0.0 and not _fish.visible:
		_fish_t = rng.randf_range(5.0, 10.0)
		var a := rng.randf() * TAU
		var from := center + Vector3(cos(a), 0, sin(a)) * shore_r(a) * rng.randf_range(0.1, 0.55)
		var b := a + rng.randf_range(-0.8, 0.8)
		var to := from + Vector3(cos(b), 0, sin(b)) * 0.9
		_fish.visible = true
		_fish.position = from
		_fish.basis = Basis.looking_at(-(to - from).normalized(), Vector3.UP)
		_splash(from)
		_fish_from = from
		_fish_to = to
		var tw := create_tween()
		tw.tween_method(_fish_arc, 0.0, 1.0, 0.7)
		tw.tween_callback(_fish_land)


func _fish_arc(t: float) -> void:
	_fish.position = _fish_from.lerp(_fish_to, t) + Vector3(0, sin(PI * t) * 0.55, 0)
	_fish.rotation.x = lerpf(0.9, -0.9, t)


func _fish_land() -> void:
	_fish.visible = false
	_splash(_fish_to)
