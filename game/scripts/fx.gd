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
		size: float, gravity := -6.0, spread := 180.0, mesh: Mesh = null) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.mesh = mesh if mesh != null else _leaf()
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


# ---------------------------------------------------------------- G3: Ember fire
static var _ember_mesh: SphereMesh
static var _ember_mat: StandardMaterial3D
static var _ember_ramp: Gradient
static var _ember_curve: Curve


## G4: the mount's Fire-spitter: a short gush of flames from `pos` along `dir`, about `length` metres, spreading
## `half_deg` each side (the ember flames, one burst; scaled by the graphics level). An effect only: no model.
static func fire_cone(parent: Node, pos: Vector3, dir: Vector3, length: float, half_deg: float) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var d := Vector3(dir.x, 0.0, dir.z)
	if d.length() < 0.001:
		return
	var host := Node3D.new()
	parent.add_child(host)
	host.global_position = pos
	var p := embers(host, 0.12, 36, 0.42, 2.2)
	p.local_coords = true
	p.one_shot = true
	p.explosiveness = 0.75
	p.direction = d.normalized()
	p.spread = half_deg
	p.initial_velocity_min = length * 1.6
	p.initial_velocity_max = length * 2.6
	p.damping_min = length * 2.0
	p.damping_max = length * 3.0
	p.gravity = Vector3(0, 1.2, 0)
	p.restart()
	host.get_tree().create_timer(0.8).timeout.connect(host.queue_free)


## G4: the mount's Bellow: three rings of sound swelling out from `pos` (about the mount's head) to `radius`, one after
## another, and a flat shockwave on the ground.
static func bellow(parent: Node, pos: Vector3, radius: float) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var cols: Array = [Color(1.0, 0.92, 0.6, 0.8), Color(1.0, 0.75, 0.4, 0.7), Color(1.0, 0.6, 0.3, 0.6)]
	for k in 3:
		var mi := MeshInstance3D.new()
		var t := TorusMesh.new()
		t.inner_radius = 0.9
		t.outer_radius = 1.0
		t.rings = 24
		t.ring_segments = 4
		mi.mesh = t
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = cols[k]
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)
		mi.global_position = pos
		mi.scale = Vector3(0.1, 0.1, 0.1)
		var tw := mi.create_tween().set_parallel()
		tw.tween_property(mi, "scale", Vector3(radius, 0.5, radius), 0.5).set_delay(0.12 * k).set_ease(Tween.EASE_OUT)
		tw.tween_property(m, "albedo_color:a", 0.0, 0.4).set_delay(0.12 * k + 0.15)
		tw.chain().tween_callback(mi.queue_free)
	shockwave(parent, Vector3(pos.x, 0.0, pos.z), radius, Color(1.0, 0.85, 0.5))


## Small flames that keep rising from a node until they are stopped (emitting = false) or the node goes: a burning
## enemy (enemy.gd ignite) and the Ember arrow's flame trail (arrow_trail). The particles stay where they rise
## (local_coords off), so a moving node leaves a short trail. `amount` is scaled by the graphics level
## (Quality.particles); `size` scales each flame. One mesh, material and colour ramp shared by all.
static func embers(parent: Node3D, radius: float, amount := 10, life := 0.5, size := 1.0) -> CPUParticles3D:
	if _ember_mesh == null:
		_ember_mesh = SphereMesh.new()
		_ember_mesh.radius = 0.045
		_ember_mesh.height = 0.09
		_ember_mesh.radial_segments = 5
		_ember_mesh.rings = 2
		_ember_mat = StandardMaterial3D.new()
		_ember_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ember_mat.vertex_color_use_as_albedo = true
		_ember_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ember_ramp = _grad([Color(1.0, 0.95, 0.55, 0.95), Color(1.0, 0.55, 0.15, 0.85), Color(0.75, 0.18, 0.08, 0.0)])
		_ember_curve = Curve.new()
		_ember_curve.add_point(Vector2(0.0, 1.0))
		_ember_curve.add_point(Vector2(1.0, 0.25))
	var p := CPUParticles3D.new()
	p.mesh = _ember_mesh
	p.material_override = _ember_mat
	p.amount = Quality.particles(amount)
	p.lifetime = life
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = maxf(radius, 0.01)
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.8
	p.gravity = Vector3(0, 0.8, 0)
	p.scale_amount_min = 0.7 * size
	p.scale_amount_max = 1.3 * size
	p.scale_amount_curve = _ember_curve
	p.color_ramp = _ember_ramp
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.emitting = true
	return p



# ---------------------------------------------------------------- 22 Nov 2026: the shooting effects, the Frost Bow's ice
## Each bow's balance.json "fx" (see the bows' _note: color, burst, burst_colors, burst_n, trail, trail_len, trail_w,
## trail_alpha, trail_n, hit, hit_colors, hit_n) drives three moments. All cheap for a phone: one shared mesh and
## material per kind (and per colour where the colour sits in the material), one-shot bursts that free themselves, and
## every particle count scaled by the graphics level (Quality.particles), as Fx.embers does.
##   shot_burst   on release: a glint at the bow and a small puff (soft mist) or spray of sparks along the shot
##   arrow_trail  in flight: a streak fading back from the arrow, plus the bow's own bits: "glint" golden sparkles,
##                "flame" the ember flames and falling sparks, "frost" icy mist and sparkles ("wind" and "tint": the
##                streak alone); drop_trail lets them fade where they are when the arrow goes
##   hit_burst    on hit: "leaf" a leaf and wood puff, "flash" a golden flash and sparks, "fire" a burst of flames,
##                "ice" ice shards, "tint" a glint
## The Frost Bow's looks on an enemy (enemy.gd chill): frost_motes while chilled, ice_shell while frozen, shatter when
## it thaws; the tints CHILL_TINT and FROZEN_TINT (x its own tint) and CHILL_FLASH / FROZEN_FLASH (a pale icy sheen).
const CHILL_TINT := Color(0.56, 0.78, 1.0)
const FROZEN_TINT := Color(0.6, 0.84, 1.0)
const CHILL_FLASH := 0.12
const FROZEN_FLASH := 0.3
const ICE_COLS := [Color(1.0, 1.0, 1.0), Color(0.75, 0.92, 1.0), Color(0.5, 0.78, 0.95)]

static var _soft: GradientTexture2D
static var _spark: ArrayMesh
static var _shard: ArrayMesh
static var _streak: ArrayMesh
static var _shell: ArrayMesh
static var _shell_mat: StandardMaterial3D
static var _glint_quad: QuadMesh
static var _mist_quad: QuadMesh
static var _fade: Curve
static var _fx_mats := {}                  # "spark" / "mist" (particles, colour from the ramp), "glint:<hex>" / "streak:<hex>"


## A colour from an fx dictionary ("#RRGGBB"), or `def`.
static func _fx_col(fx: Dictionary, key: String, def: Color) -> Color:
	return Color.html(String(fx[key])) if fx.has(key) and String(fx[key]) != "" else def


## A list of colours from an fx dictionary, or `def`.
static func _fx_cols(fx: Dictionary, key: String, def: Array) -> Array:
	var out: Array = []
	for h in fx.get(key, []):
		out.append(Color.html(String(h)))
	return out if not out.is_empty() else def


## A soft round white spot fading to clear at its rim (mist puffs and glints).
static func _soft_tex() -> GradientTexture2D:
	if _soft == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.4, Color(1, 1, 1, 0.6))
		_soft = GradientTexture2D.new()
		_soft.gradient = g
		_soft.fill = GradientTexture2D.FILL_RADIAL
		_soft.fill_from = Vector2(0.5, 0.5)
		_soft.fill_to = Vector2(0.5, 0.0)
		_soft.width = 32
		_soft.height = 32
	return _soft


## A small four-pointed star facing the camera (sparks, sparkles, snow).
static func _spark_mesh() -> ArrayMesh:
	if _spark == null:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for k in 4:
			var a := TAU * k / 4.0
			var tip := Vector3(cos(a), sin(a), 0.0) * 0.06
			var l := Vector3(cos(a - PI * 0.25), sin(a - PI * 0.25), 0.0) * 0.014
			var r := Vector3(cos(a + PI * 0.25), sin(a + PI * 0.25), 0.0) * 0.014
			for v in [Vector3.ZERO, l, tip, Vector3.ZERO, tip, r]:
				st.set_color(Color.WHITE)
				st.set_normal(Vector3.BACK)
				st.add_vertex(v)
		_spark = st.commit()
	return _spark


## A thin faceted ice shard (white: the particles' colours tint it).
static func _shard_mesh() -> ArrayMesh:
	if _shard == null:
		_shard = Props.build([[Props._ball(0.022, 0.12, 4), Transform3D.IDENTITY, Color.WHITE]])
	return _shard


## Two crossed strips behind an arrow, from its nock (z 0, full width, opaque) back to z -1 (thin, clear); scaled by
## (half width, half width, length) on the arrow.
static func _streak_mesh() -> ArrayMesh:
	if _streak == null:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for axis in [Vector3.RIGHT, Vector3.UP]:
			var q := [[-axis, 0.0, 1.0], [axis, 0.0, 1.0], [axis * 0.2, -1.0, 0.0], [-axis * 0.2, -1.0, 0.0]]   # [side, z, alpha]
			for k in [0, 1, 2, 0, 2, 3]:
				var v: Array = q[k]
				st.set_color(Color(1, 1, 1, float(v[2])))
				st.set_normal(Vector3.UP)
				st.add_vertex((v[0] as Vector3) + Vector3(0, 0, float(v[1])))
		_streak = st.commit()
	return _streak


## The shared effect materials: "spark" (bright, added on top) and "mist" (soft puffs) for particles, coloured by their
## ramp; "glint:<hex>" (a soft bright flash facing the camera) and "streak:<hex>" (an arrow's trail), one per colour.
static func _fx_mat(kind: String, color := Color.WHITE) -> StandardMaterial3D:
	var key := kind if kind in ["spark", "mist"] else "%s:%s" % [kind, color.to_html()]
	if _fx_mats.has(key):
		return _fx_mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	match kind:
		"spark":
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			m.vertex_color_use_as_albedo = true
			m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		"mist":
			m.vertex_color_use_as_albedo = true
			m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
			m.albedo_texture = _soft_tex()
		"glint":
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			m.billboard_keep_scale = true
			m.albedo_texture = _soft_tex()
			m.albedo_color = color
		_:
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			m.vertex_color_use_as_albedo = true
			m.albedo_color = color
	_fx_mats[key] = m
	return m


## 1 -> 0 over a particle's life (it shrinks away).
static func _fade_curve() -> Curve:
	if _fade == null:
		_fade = Curve.new()
		_fade.add_point(Vector2(0.0, 1.0))
		_fade.add_point(Vector2(0.6, 0.8))
		_fade.add_point(Vector2(1.0, 0.0))
	return _fade


## The colours one after another over a particle's life, the last fading to clear.
static func _fade_ramp(cols: Array, alpha := 1.0) -> Gradient:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cs := PackedColorArray()
	var n := cols.size()
	for k in n:
		offs.append(0.75 * float(k) / maxf(n - 1, 1))
		cs.append(Color(cols[k], alpha))
	offs.append(1.0)
	cs.append(Color(cols[n - 1] if n > 0 else Color.WHITE, 0.0))
	g.offsets = offs
	g.colors = cs
	return g


## A soft bright flash at pos that swells and fades in `secs` (a bow's release, a golden hit).
static func glint(parent: Node, pos: Vector3, color: Color, size := 0.4, secs := 0.14) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	if _glint_quad == null:
		_glint_quad = QuadMesh.new()
		_glint_quad.size = Vector2(1, 1)
	var mi := MeshInstance3D.new()
	mi.mesh = _glint_quad
	mi.material_override = _fx_mat("glint", color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3.ONE * size * 0.45
	var tw := mi.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3.ONE * size, secs).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "transparency", 1.0, secs).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)


## A one-shot spray of small bits from pos along dir (spread degrees either side): "spark" stars or "mist" puffs.
static func _spray(parent: Node, pos: Vector3, dir: Vector3, cols: Array, amount: int, speed: float, life: float,
		size: float, spread: float, kind := "spark", gravity := Vector3.ZERO) -> void:
	if parent == null or not parent.is_inside_tree() or amount <= 0:
		return
	var p := CPUParticles3D.new()
	p.mesh = _mist_mesh() if kind == "mist" else _spark_mesh()
	p.material_override = _fx_mat(kind)
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = Quality.particles(amount)
	p.lifetime = life
	p.direction = dir.normalized() if dir.length() > 0.01 else Vector3.UP
	p.spread = spread
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.damping_min = speed * 1.2
	p.damping_max = speed * 2.4
	p.gravity = gravity
	p.scale_amount_min = size * 0.7
	p.scale_amount_max = size * 1.3
	p.scale_amount_curve = _fade_curve()
	p.color_ramp = _fade_ramp(cols, 0.55 if kind == "mist" else 1.0)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.get_tree().create_timer(life + 0.3).timeout.connect(p.queue_free)


static func _mist_mesh() -> QuadMesh:
	if _mist_quad == null:
		_mist_quad = QuadMesh.new()
		_mist_quad.size = Vector2(0.14, 0.14)
	return _mist_quad


## The bow's release (player.gd _fire): a glint at the bow and a small puff or spray of sparks along the shot.
static func shot_burst(parent: Node, pos: Vector3, dir: Vector3, fx: Dictionary) -> void:
	if fx.is_empty():
		return
	var col := _fx_col(fx, "color", Color.WHITE)
	glint(parent, pos, col, 0.42, 0.12)
	var cols := _fx_cols(fx, "burst_colors", [col])
	var n := int(fx.get("burst_n", 6))
	if String(fx.get("burst", "sparks")) == "puff":
		_spray(parent, pos, dir, cols, n, 1.6, 0.35, 1.1, 40.0, "mist")
	else:
		_spray(parent, pos, dir, cols, n, 3.2, 0.26, 0.9, 28.0, "spark")


## An arrow's trail in flight (arrow.gd launch): its streak and the bow's own bits (see above), riding on the arrow
## (length: the arrow's own, nock to tip). The particles stay where they appear (local_coords off), so they trail
## behind. Returns the nodes, for drop_trail.
static func arrow_trail(arrow: Node3D, length: float, fx: Dictionary) -> Array:
	var out: Array = []
	if arrow == null or fx.is_empty():
		return out
	var col := _fx_col(fx, "color", Color.WHITE)
	var st := MeshInstance3D.new()
	st.mesh = _streak_mesh()
	st.material_override = _fx_mat("streak", Color(col, float(fx.get("trail_alpha", 0.45))))
	st.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arrow.add_child(st)
	var w := float(fx.get("trail_w", 0.035))
	st.scale = Vector3(w, w, 0.05)
	st.create_tween().tween_property(st, "scale:z", float(fx.get("trail_len", 0.8)), 0.12)   # it grows out as the arrow leaves
	out.append(st)
	var n := int(fx.get("trail_n", 8))
	var mid := Vector3(0, 0, length * 0.5)
	match String(fx.get("trail", "tint")):
		"glint":
			out.append(_trail_bits(arrow, mid, "spark", _fx_cols(fx, "burst_colors", [col]), n, 0.32, 0.8, 0.25))
		"flame":
			var fl := embers(arrow, 0.03, n, 0.3, 0.8)          # the flames, from near its tip
			fl.position = Vector3(0, 0, length * 0.85)
			out.append(fl)
			var sp := _trail_bits(arrow, Vector3(0, 0, length * 0.7), "spark", [Color(1.0, 0.95, 0.6), Color(1.0, 0.6, 0.2)],
				maxi(2, n / 2), 0.38, 0.7, 1.2)
			sp.gravity = Vector3(0, -3.0, 0)
			out.append(sp)
		"frost":
			out.append(_trail_bits(arrow, mid, "mist", [Color(0.85, 0.95, 1.0), col], roundi(n * 1.4), 0.5, 1.6, 0.15))
			out.append(_trail_bits(arrow, mid, "spark", [Color(1, 1, 1), col], maxi(2, n / 2), 0.35, 0.7, 0.3))
	return out


## Bits that keep coming off a moving arrow (glints, sparks, mist) until stopped.
static func _trail_bits(arrow: Node3D, at: Vector3, kind: String, cols: Array, amount: int, life: float, size: float,
		speed: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.mesh = _mist_mesh() if kind == "mist" else _spark_mesh()
	p.material_override = _fx_mat(kind)
	p.amount = Quality.particles(amount)
	p.lifetime = life
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.04
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.3
	p.initial_velocity_max = speed
	p.gravity = Vector3.ZERO
	p.scale_amount_min = size * 0.7
	p.scale_amount_max = size * 1.3
	if kind == "mist":
		var grow := Curve.new()
		grow.add_point(Vector2(0.0, 0.5))
		grow.add_point(Vector2(1.0, 1.0))
		p.scale_amount_curve = grow
	else:
		p.scale_amount_curve = _fade_curve()
	p.color_ramp = _fade_ramp(cols, 0.4 if kind == "mist" else 1.0)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arrow.add_child(p)
	p.position = at
	p.emitting = true
	return p


## The arrow is gone (a hit, or out of flight): its trail stays where it is, stops and fades, then frees itself.
static func drop_trail(nodes: Array, to: Node) -> void:
	if to == null or not to.is_inside_tree():
		return
	for n in nodes:
		if n == null or not is_instance_valid(n) or not (n as Node).is_inside_tree():
			continue
		(n as Node).reparent(to)                            # keeps where it is
		if n is CPUParticles3D:
			var p := n as CPUParticles3D
			p.emitting = false
			p.get_tree().create_timer(p.lifetime + 0.1).timeout.connect(p.queue_free)
		elif n is GeometryInstance3D:
			var g := n as GeometryInstance3D
			var tw := g.create_tween()
			tw.tween_property(g, "transparency", 1.0, 0.12)
			tw.tween_callback(g.queue_free)


## An arrow's hit (arrow.gd, at each enemy it hits; a piercing arrow at each one it passes through).
static func hit_burst(parent: Node, pos: Vector3, dir: Vector3, fx: Dictionary) -> void:
	if fx.is_empty() or parent == null or not parent.is_inside_tree():
		return
	var col := _fx_col(fx, "color", Color.WHITE)
	var cols := _fx_cols(fx, "hit_colors", [col])
	var n := int(fx.get("hit_n", 8))
	var back := Vector3(-dir.x, 0.6, -dir.z)                  # bits fly back and up from the hit
	match String(fx.get("hit", "tint")):
		"leaf":
			_burst(parent, pos, _grad(cols), n, 2.6, 0.45, 0.75, -6.0, 110.0)
		"flash":
			glint(parent, pos, cols[0], 0.7, 0.16)
			glint(parent, pos, col, 0.4, 0.22)
			_spray(parent, pos, back, cols, n, 3.0, 0.32, 0.9, 70.0, "spark", Vector3(0, -2.0, 0))
		"fire":
			glint(parent, pos, Color(1.0, 0.6, 0.25), 0.6, 0.18)
			var host := Node3D.new()
			parent.add_child(host)
			host.global_position = pos
			var p := embers(host, 0.08, n, 0.45, 1.1)
			p.one_shot = true
			p.explosiveness = 0.85
			p.spread = 180.0
			p.initial_velocity_min = 0.8
			p.initial_velocity_max = 2.0
			p.restart()
			host.get_tree().create_timer(0.8).timeout.connect(host.queue_free)
			_spray(parent, pos, back, cols, maxi(2, n / 2), 3.2, 0.35, 0.8, 80.0, "spark", Vector3(0, -4.0, 0))
		"ice":
			glint(parent, pos, Color(0.8, 0.94, 1.0), 0.45, 0.14)
			_burst(parent, pos, _grad(cols), n, 3.2, 0.5, 1.0, -9.0, 130.0, _shard_mesh())
		_:
			glint(parent, pos, col, 0.4, 0.14)


## Snow sparkles drifting down round a chilled enemy until stopped (emitting = false), like Fx.embers for a burn.
static func frost_motes(parent: Node3D, radius: float, amount := 6) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.mesh = _spark_mesh()
	p.material_override = _fx_mat("spark")
	p.amount = Quality.particles(amount)
	p.lifetime = 0.9
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = maxf(radius, 0.05)
	p.direction = Vector3.DOWN
	p.spread = 35.0
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.35
	p.gravity = Vector3(0, -0.4, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.1
	p.scale_amount_curve = _fade_curve()
	p.color_ramp = _fade_ramp([Color(1, 1, 1), Color(0.7, 0.9, 1.0)])
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.emitting = true
	return p


## A frozen enemy's ice: a faceted see-through shell with crystals on top, `radius` wide and `height` high, popping on.
## One mesh and material shared by all.
static func ice_shell(parent: Node3D, radius: float, height: float) -> MeshInstance3D:
	if _shell == null:
		var ice := Color(0.85, 0.95, 1.0)
		var tip := Color(0.96, 0.99, 1.0)
		var parts: Array = [[Props._ball(1.0, 1.0, 6), Props._at(0, 0.5, 0), ice]]
		for k in 5:
			var a := TAU * k / 5.0 + 0.4
			parts.append([Props._cyl(0.0, 0.2, 0.55, 5), Props._at(cos(a) * 0.55, 0.72 + 0.1 * (k % 2), sin(a) * 0.55,
				Vector3(sin(a) * 0.6, 0.0, -cos(a) * 0.6)), tip])
		parts.append([Props._cyl(0.0, 0.22, 0.7, 5), Props._at(0.08, 1.02, -0.05, Vector3(0.15, 0.0, 0.1)), tip])
		_shell = Props.build(parts)
		_shell_mat = StandardMaterial3D.new()
		_shell_mat.vertex_color_use_as_albedo = true
		_shell_mat.albedo_color = Color(1, 1, 1, 0.42)
		_shell_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_shell_mat.roughness = 0.15
		_shell_mat.metallic_specular = 0.9
		_shell_mat.emission_enabled = true
		_shell_mat.emission = Color(0.3, 0.55, 0.75)
		_shell_mat.emission_energy_multiplier = 0.45
	var mi := MeshInstance3D.new()
	mi.mesh = _shell
	mi.material_override = _shell_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	var s := Vector3(radius * 1.35, height * 1.05, radius * 1.35)
	mi.scale = s * 0.6
	mi.create_tween().tween_property(mi, "scale", s, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return mi


## Ice breaking off (a frozen enemy thaws or falls): shards and a pale glint.
static func shatter(parent: Node, pos: Vector3, radius: float) -> void:
	glint(parent, pos, Color(0.8, 0.94, 1.0), 0.5 + radius, 0.18)
	_burst(parent, pos, _grad(ICE_COLS), 14, 3.6, 0.6, clampf(radius / 0.3, 0.9, 2.0), -9.0, 160.0, _shard_mesh())
