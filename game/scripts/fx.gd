class_name Fx
extends RefCounted
## The splashes that give LEAF its look: leaf bursts on hits, confetti on kills, a ring of flowers on upgrades,
## petals when the Gloom lifts, floating damage numbers, the boss's shockwave. All one-shot and self-cleaning.

static var _leaf_mesh: ArrayMesh
static var _mat: StandardMaterial3D
static var _blob_mat: StandardMaterial3D
static var _blob_mesh: PlaneMesh


## A soft dark spot on the ground under a character. It stands in for the sun's shadow on Low graphics, where the sun
## casts none (Quality.shadows()); world.apply_quality() shows or hides the group "blob" when the level changes.
static func blob(parent: Node3D, radius: float) -> MeshInstance3D:
	if _blob_mat == null:
		var g := Gradient.new()
		g.set_color(0, Color(0.02, 0.07, 0.02, 0.72))
		g.set_color(1, Color(0.02, 0.07, 0.02, 0.0))
		g.add_point(0.5, Color(0.02, 0.07, 0.02, 0.55))
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(0.5, 0.0)
		tex.width = 64
		tex.height = 64
		_blob_mat = StandardMaterial3D.new()
		_blob_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_blob_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_blob_mat.albedo_texture = tex
		_blob_mesh = PlaneMesh.new()
		_blob_mesh.size = Vector2(2, 2)
	var mi := MeshInstance3D.new()
	mi.mesh = _blob_mesh
	mi.material_override = _blob_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.y = 0.03
	mi.scale = Vector3(radius, 1.0, radius)
	mi.add_to_group("blob")
	mi.visible = not Quality.shadows()
	parent.add_child(mi)
	return mi


static func _leaf() -> ArrayMesh:
	if _leaf_mesh == null:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var pts := [Vector3(0, 0, -0.07), Vector3(0.035, 0, 0), Vector3(0, 0, 0.07), Vector3(-0.035, 0, 0)]
		for tri in [[0, 1, 2], [0, 2, 3]]:
			for k in tri:
				st.set_normal(Vector3.UP)
				st.set_color(Color.WHITE)
				st.add_vertex(pts[k])
		_leaf_mesh = st.commit()
	return _leaf_mesh


static func _material() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.vertex_color_use_as_albedo = true
		_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mat.roughness = 1.0
	return _mat


static func _burst(parent: Node, pos: Vector3, colors: Gradient, amount: int, speed: float, life: float,
		size: float, gravity := -6.0, spread := 180.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.mesh = _leaf()
	p.material_override = _material()
	p.one_shot = true
	p.explosiveness = 0.92
	p.amount = Quality.particles(amount)
	p.lifetime = life
	p.direction = Vector3.UP
	p.spread = spread
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, gravity, 0)
	p.angular_velocity_min = -540.0
	p.angular_velocity_max = 540.0
	p.particle_flag_rotate_y = true
	p.damping_min = 1.5
	p.damping_max = 3.0
	p.scale_amount_min = size * 0.7
	p.scale_amount_max = size * 1.3
	p.color_initial_ramp = colors
	var fade := Curve.new()
	fade.add_point(Vector2(0.0, 1.0))
	fade.add_point(Vector2(0.75, 1.0))
	fade.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = fade
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.get_tree().create_timer(life + 0.3).timeout.connect(p.queue_free)


static func _grad(cols: Array) -> Gradient:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cs := PackedColorArray()
	for k in cols.size():
		offs.append(float(k) / maxf(cols.size() - 1, 1))
		cs.append(cols[k])
	g.offsets = offs
	g.colors = cs
	return g


## Little pink hearts (a fed mount jumps up).
static func hearts(parent: Node, pos: Vector3) -> void:
	_burst(parent, pos, _grad([Color(1.0, 0.45, 0.6), Color(1.0, 0.7, 0.8), Color(0.95, 0.3, 0.45)]), 12, 2.2, 0.9, 1.4, -1.0, 60.0)


## A soft puff of one colour (water drops from a watering, steam from the cooking pot).
static func puff(parent: Node, pos: Vector3, color: Color, amount := 10) -> void:
	_burst(parent, pos, _grad([color.lightened(0.3), color]), amount, 2.0, 0.6, 0.6, -4.0, 50.0)


static func hit(parent: Node, pos: Vector3, base: Color) -> void:
	_burst(parent, pos, _grad([base.lightened(0.2), Color(0.55, 0.8, 0.3), base]), 8, 3.0, 0.5, 1.0)


static func kill(parent: Node, pos: Vector3, base: Color) -> void:
	_burst(parent, pos, _grad([Color(1.0, 0.85, 0.3), Color(0.55, 0.85, 0.3), base, Color(0.85, 0.45, 1.0)]), 26, 5.0, 0.9, 1.3)


static func sparkle(parent: Node, pos: Vector3) -> void:
	_burst(parent, pos, _grad([Color(1.0, 0.92, 0.5), Color(1.0, 0.8, 0.25)]), 14, 2.5, 0.7, 0.8, -1.0, 60.0)


static func petals(parent: Node, pos: Vector3) -> void:
	_burst(parent, pos, _grad([Color(1.0, 0.75, 0.85), Color(1.0, 0.95, 0.6), Color(0.7, 0.95, 0.5), Color(1, 1, 1)]), 30, 4.5, 2.2, 1.5, -1.2, 70.0)


## A ring of flowers bursting outward on the ground (upgrades, new buildings).
static func flower_ring(parent: Node, pos: Vector3, radius := 1.2) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var cols := [Color(0.95, 0.3, 0.25), Color(1.0, 0.85, 0.3), Color(0.65, 0.45, 0.9), Color(1, 1, 1)]
	for k in 14:
		var a := TAU * k / 14.0
		var f := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.09
		s.height = 0.08
		s.radial_segments = 5
		s.rings = 2
		f.mesh = s
		var m := StandardMaterial3D.new()
		m.albedo_color = cols[k % cols.size()]
		m.emission_enabled = true
		m.emission = m.albedo_color
		m.emission_energy_multiplier = 0.4
		f.material_override = m
		parent.add_child(f)
		f.global_position = pos + Vector3(0, 0.05, 0)
		f.scale = Vector3.ONE * 0.1
		var to := pos + Vector3(cos(a), 0, sin(a)) * radius + Vector3(0, 0.05, 0)
		var tw := f.create_tween().set_parallel()
		tw.tween_property(f, "global_position", to, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(f, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK)
		tw.chain().tween_interval(0.4)
		tw.chain().tween_property(f, "scale", Vector3.ONE * 0.01, 0.35)
		tw.chain().tween_callback(f.queue_free)
	sparkle(parent, pos + Vector3(0, 0.4, 0))


## A number popping up (a hit, a heal): small and quick, so a busy fight stays readable (18 Nov 2026).
static func number(parent: Node, pos: Vector3, value: float, color := Color(1, 1, 1), big := false) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var l := Label3D.new()
	l.text = str(int(round(value)))
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.pixel_size = 0.00078 if big else 0.0006
	l.font_size = 48
	l.outline_size = 12
	l.modulate = color
	l.outline_modulate = Color(0.1, 0.06, 0.1, 0.85)
	parent.add_child(l)
	l.global_position = pos + Vector3(randf_range(-0.15, 0.15), 0, randf_range(-0.1, 0.1))
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "global_position", l.global_position + Vector3(0, 0.6, 0), 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, 0.22).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)


## Recent "+N thing" popups, by thing: a second one of the same kind landing close by within a moment adds to it.
static var _recent := {}
const MERGE_MS := 600
const MERGE_M := 2.5


## A word popping up and floating away ("+2 amber", "Bonk!"): small and quick. "+N thing" popups of the same thing that
## land within a moment and a few steps of each other merge into one ("+3 amber"), as long as it is still showing.
static func text(parent: Node, pos: Vector3, s: String, color := Color(1, 0.9, 0.4)) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var kind := ""
	var n := 0
	if s.begins_with("+") and s.contains(" "):
		var num := s.substr(1, s.find(" ") - 1)
		if num.is_valid_int():
			n = int(num)
			kind = s.substr(s.find(" ") + 1)
	var now := Time.get_ticks_msec()
	if kind != "" and _recent.has(kind):
		var r: Array = _recent[kind]                     # [label, n, when]
		var old = r[0]                                   # untyped: it may have been freed
		if is_instance_valid(old) and now - int(r[2]) < MERGE_MS and (old as Label3D).global_position.distance_to(pos) < MERGE_M:
			r[1] = int(r[1]) + n
			r[2] = now
			old.text = "+%d %s" % [int(r[1]), kind]
			old.modulate.a = 1.0
			_float(old, old.global_position)
			return
	var l := Label3D.new()
	l.text = s
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.pixel_size = 0.00068
	l.font_size = 44
	l.outline_size = 12
	l.modulate = color
	l.outline_modulate = Color(0.1, 0.06, 0.1, 0.85)
	parent.add_child(l)
	l.global_position = pos
	if kind != "":
		_recent[kind] = [l, n, now]
	_float(l, pos)


## Floats a popup up and fades it (a merged one starts again from where it is).
static func _float(l: Label3D, from: Vector3) -> void:
	if l.has_meta("tw"):
		var old: Tween = l.get_meta("tw")
		if old != null and old.is_valid():
			old.kill()
	var tw := l.create_tween().set_parallel()
	l.set_meta("tw", tw)
	tw.tween_property(l, "global_position", from + Vector3(0, 0.6, 0), 0.8).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.3).set_delay(0.5)
	tw.chain().tween_callback(l.queue_free)


## A flat ring that grows outward on the ground: the boss's slam.
static func shockwave(parent: Node, pos: Vector3, radius: float, color := Color(0.75, 0.45, 1.0)) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var mi := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.85
	t.outer_radius = 1.0
	t.rings = 24
	t.ring_segments = 4
	mi.mesh = t
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos + Vector3(0, 0.08, 0)
	mi.scale = Vector3(0.2, 0.15, 0.2)
	var tw := mi.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3(radius, 0.15, radius), 0.45).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.45).set_delay(0.1)
	tw.chain().tween_callback(mi.queue_free)
	_burst(parent, pos, _grad([Color(0.6, 0.45, 0.3), Color(0.45, 0.7, 0.3)]), 24, 6.0, 0.8, 1.2)


## A short squash-and-stretch on a node (upgrades, pickups, hits).
static func boing(n: Node3D, amount := 0.25) -> void:
	if n == null:
		return
	if not n.has_meta("base_scale"):
		n.set_meta("base_scale", n.scale)
	var base: Vector3 = n.get_meta("base_scale")
	if n.has_meta("boing_tween"):
		var old = n.get_meta("boing_tween")
		if old is Tween and (old as Tween).is_valid():
			(old as Tween).kill()
	var tw := n.create_tween()
	n.set_meta("boing_tween", tw)
	tw.tween_property(n, "scale", base * Vector3(1.0 + amount, 1.0 - amount, 1.0 + amount), 0.08)
	tw.tween_property(n, "scale", base * Vector3(1.0 - amount * 0.5, 1.0 + amount * 0.6, 1.0 - amount * 0.5), 0.12)
	tw.tween_property(n, "scale", base, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------- attacks and specials
static var _arc_mesh: ArrayMesh


## A crescent swipe flashing in front of an attacker (yaw = where it faces).
static func swipe(parent: Node, pos: Vector3, yaw: float, radius: float, color := Color(1, 1, 1)) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	if _arc_mesh == null:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var n := 14
		for k in n:
			var a0 := lerpf(-1.1, 1.1, float(k) / n)
			var a1 := lerpf(-1.1, 1.1, float(k + 1) / n)
			var w0 := sin(PI * float(k) / n)
			var w1 := sin(PI * float(k + 1) / n)
			var i0 := Vector3(sin(a0), 0, cos(a0)) * (1.0 - 0.35 * w0)
			var o0 := Vector3(sin(a0), 0, cos(a0))
			var i1 := Vector3(sin(a1), 0, cos(a1)) * (1.0 - 0.35 * w1)
			var o1 := Vector3(sin(a1), 0, cos(a1))
			for v in [[i0, w0 * 0.3], [o0, w0], [o1, w1], [i0, w0 * 0.3], [o1, w1], [i1, w1 * 0.3]]:
				st.set_color(Color(1, 1, 1, v[1]))
				st.set_normal(Vector3.UP)
				st.add_vertex(v[0])
		_arc_mesh = st.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = _arc_mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = color
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos
	mi.rotation = Vector3(0.25, yaw - 0.6, 0)
	mi.scale = Vector3.ONE * radius * 0.8
	var tw := mi.create_tween().set_parallel()
	tw.tween_property(mi, "rotation:y", yaw + 0.6, 0.16).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "scale", Vector3.ONE * radius * 1.15, 0.22)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.22).set_delay(0.06)
	tw.chain().tween_callback(mi.queue_free)


## Puffs of dust at the feet (steps, charges, landings).
static func dust(parent: Node, pos: Vector3, amount := 5, size := 1.0) -> void:
	_burst(parent, pos + Vector3(0, 0.05, 0), _grad([Color(0.78, 0.66, 0.48), Color(0.66, 0.55, 0.40), Color(0.85, 0.78, 0.62)]),
		amount, 1.2 * size, 0.55, 1.6 * size, -1.5, 70.0)


## Wind and leaves swirling round a node for a while (the boss gathering for its dash).
static func wind_aura(target: Node3D, duration: float, radius: float, color := Color(0.85, 0.7, 1.0)) -> void:
	if target == null or not target.is_inside_tree():
		return
	for leaves in [false, true]:
		var p := CPUParticles3D.new()
		if leaves:
			p.mesh = _leaf()
			p.material_override = _material()
			p.amount = Quality.particles(18)
			p.color_initial_ramp = _grad([Color(0.55, 0.8, 0.3), Color(0.8, 0.6, 1.0), Color(0.95, 0.85, 0.4)])
			p.scale_amount_min = 1.2
			p.scale_amount_max = 1.8
			p.particle_flag_rotate_y = true
			p.angular_velocity_min = -400.0
			p.angular_velocity_max = 400.0
		else:
			var q := QuadMesh.new()
			q.size = Vector2(0.06, 0.55)
			p.mesh = q
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
			m.vertex_color_use_as_albedo = true
			p.material_override = m
			p.amount = Quality.particles(34)
			var g := Gradient.new()
			g.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
			g.colors = PackedColorArray([Color(color, 0.0), Color(color, 0.8), Color(color, 0.0)])
			p.color_ramp = g
		p.lifetime = 0.8
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		p.emission_ring_axis = Vector3.UP
		p.emission_ring_radius = radius
		p.emission_ring_inner_radius = radius * 0.7
		p.emission_ring_height = 0.3
		p.direction = Vector3.UP
		p.spread = 10.0
		p.initial_velocity_min = 0.8
		p.initial_velocity_max = 1.6
		p.gravity = Vector3(0, 1.5, 0)
		p.tangential_accel_min = 16.0
		p.tangential_accel_max = 22.0
		p.radial_accel_min = -5.0
		p.radial_accel_max = -3.0
		p.local_coords = true
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		target.add_child(p)
		p.position = Vector3(0, 0.3, 0)
		p.emitting = true
		var t := target.get_tree().create_timer(duration)
		var wr: WeakRef = weakref(p)             # the target may be gone by then (a foe killed at once): no freed capture
		t.timeout.connect(func():
			var pp = wr.get_ref()
			if pp != null and is_instance_valid(pp):
				pp.emitting = false
				pp.get_tree().create_timer(1.0).timeout.connect(pp.queue_free))


static func _ground_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	m.albedo_color = color
	return m


## A warning on the ground: the strip something is about to charge along, filling up until it goes.
static func telegraph_line(parent: Node, from: Vector3, dir: Vector3, length: float, width: float, duration: float, color := Color(1.0, 0.3, 0.25, 0.4)) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = Vector3(from.x, 0.05, from.z)
	root.rotation.y = atan2(dir.x, dir.z)
	for fill in [false, true]:
		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(width, length)
		pm.center_offset = Vector3(0, 0, length * 0.5)
		mi.mesh = pm
		mi.material_override = _ground_mat(Color(color, color.a * (1.6 if fill else 0.6)))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
		if fill:
			mi.scale = Vector3(1, 1, 0.01)
			mi.create_tween().tween_property(mi, "scale:z", 1.0, duration)
	root.get_tree().create_timer(duration + 0.1).timeout.connect(root.queue_free)


## A warning ring on the ground that fills from the middle (the boss's slam).
static func telegraph_ring(parent: Node, pos: Vector3, radius: float, duration: float, color := Color(0.75, 0.35, 1.0, 0.35)) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = Vector3(pos.x, 0.05, pos.z)
	for fill in [false, true]:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = radius
		cm.bottom_radius = radius
		cm.height = 0.01
		cm.radial_segments = 32
		cm.rings = 1
		mi.mesh = cm
		mi.material_override = _ground_mat(Color(color, color.a * (1.5 if fill else 0.55)))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
		if fill:
			mi.scale = Vector3(0.02, 1, 0.02)
			mi.create_tween().tween_property(mi, "scale", Vector3.ONE, duration)
	root.get_tree().create_timer(duration + 0.1).timeout.connect(root.queue_free)


## A cloud of spores bursting outward (the Toadstool Brute).
static func spores(parent: Node, pos: Vector3, radius: float) -> void:
	_burst(parent, pos + Vector3(0, 0.5, 0), _grad([Color(0.75, 0.5, 1.0), Color(0.6, 0.85, 0.4), Color(0.9, 0.8, 1.0)]),
		40, radius * 2.2, 1.3, 2.2, 0.4, 90.0)
	shockwave(parent, pos, radius, Color(0.6, 0.9, 0.45))


## A puff of smoke (the Raccoon Bandit's getaway).
static func smoke(parent: Node, pos: Vector3) -> void:
	_burst(parent, pos + Vector3(0, 0.4, 0), _grad([Color(0.8, 0.78, 0.82), Color(0.62, 0.6, 0.66), Color(0.9, 0.88, 0.9)]),
		22, 2.0, 0.9, 2.6, 0.6, 180.0)
