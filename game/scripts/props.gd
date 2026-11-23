class_name Props
extends RefCounted
## Props made in Blender live in res://assets/props/<name>.glb (see docs/ASSET_RULES.md). Every mesh gets the one
## shared vertex-colour material. Until a prop's GLB exists, a faceted placeholder built here from simple shapes
## stands in, so the game is playable while the art is being made.

const VC := preload("res://shaders/vc.gdshader")
const VC_MULTI := preload("res://shaders/vc_multi.gdshader")

static var _vc: ShaderMaterial
static var _vc_multi: ShaderMaterial
static var _meshes := {}
static var missing: Array = []        # props asked for that have neither a GLB nor a placeholder (magenta boxes)


static func vc() -> ShaderMaterial:
	if _vc == null:
		_vc = ShaderMaterial.new()
		_vc.shader = VC
	return _vc


static func vc_multi() -> ShaderMaterial:
	if _vc_multi == null:
		_vc_multi = ShaderMaterial.new()
		_vc_multi.shader = VC_MULTI
	return _vc_multi


static func path(name: String) -> String:
	return "res://assets/props/%s.glb" % name


static func has(name: String) -> bool:
	return ResourceLoader.exists(path(name))


## A prop as a node: the GLB if there is one, else the placeholder. Named parts (flame, door_L, door_R, turret,
## banner) and markers (marker_ring, marker_shoot) can be found with find_part().
static func instance(name: String) -> Node3D:
	var n: Node3D
	if has(name):
		n = (load(path(name)) as PackedScene).instantiate()
	else:
		n = _placeholder(name)
	apply_vc(n)
	n.name = name
	return n


static func apply_vc(n: Node) -> void:
	if n is MeshInstance3D:
		(n as MeshInstance3D).material_override = vc()
	for c in n.get_children():
		apply_vc(c)


## G3: like apply_vc, but a surface whose material is named M_Glow (the glowing bits of the bows and arrows: the sun
## disc, the ember cracks, the foxfire wisps) keeps its own emissive material from the GLB, so it shines; every other
## surface gets the shared colour shader.
static func apply_vc_glow(n: Node) -> void:
	if n is MeshInstance3D:
		vc_surfaces(n as MeshInstance3D)
	for c in n.get_children():
		apply_vc_glow(c)


static func vc_surfaces(mi: MeshInstance3D) -> void:
	mi.material_override = null
	if mi.mesh == null:
		return
	for i in mi.mesh.get_surface_count():
		var m := mi.mesh.surface_get_material(i)
		mi.set_surface_override_material(i, m if m != null and m.resource_name == "M_Glow" else vc())


static func find_part(root: Node, part: String) -> Node3D:
	if root.name == part or String(root.name).begins_with(part + "_") and part.begins_with("marker"):
		return root as Node3D
	for c in root.get_children():
		var r := find_part(c, part)
		if r != null:
			return r
	return null


## Paints a look's skin (Data.skin) on a model that uses the shared colour shader; "natural" turns it off.
static func set_skin(n: Node, look: Dictionary, skin: Dictionary) -> void:
	var to: Array = skin.get("to", [-1, 1, 1])
	var fur: Array = look.get("fur", [0.0, 0.0])
	var on := String(skin.get("id", "natural")) != "natural"
	set_param(n, "skin", Vector4(float(to[0]), float(to[1]), float(to[2]), 1.0 if on else 0.0))
	set_param(n, "skin_from", Vector4(float(fur[0]), float(fur[1]), 0.0, 0.0))


static func set_param(n: Node, param: String, value) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).set_instance_shader_parameter(param, value)
	for c in n.get_children():
		set_param(c, param, value)


## One mesh for a MultiMesh: every mesh in the GLB merged, or the placeholder's mesh.
static func mesh(name: String) -> Mesh:
	if _meshes.has(name):
		return _meshes[name]
	var m: Mesh
	if has(name):
		var root := (load(path(name)) as PackedScene).instantiate()
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var any := [false]
		_merge(root, Transform3D.IDENTITY, st, any)
		root.free()
		m = st.commit() if any[0] else _placeholder_mesh(name)
	else:
		m = _placeholder_mesh(name)
	_meshes[name] = m
	return m


static func _merge(n: Node, xf: Transform3D, st: SurfaceTool, any: Array) -> void:
	var here := xf
	if n is Node3D:
		here = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var mesh_res: Mesh = (n as MeshInstance3D).mesh
		for s in mesh_res.get_surface_count():
			st.append_from(mesh_res, s, here)
			any[0] = true
	for c in n.get_children():
		_merge(c, here, st, any)


## Many meshes into one (one draw call): [[Mesh, Transform3D], ...]. The garden's plants use it.
static func merge(list: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	for it in list:
		var m: Mesh = it[0]
		for s in m.get_surface_count():
			st.append_from(m, s, it[1])
			any = true
	return st.commit() if any else ArrayMesh.new()


# ---------------------------------------------------------------- placeholders
static func _c(hex: String) -> Color:
	return Color.html(hex)


static func _cyl(r_top: float, r_bottom: float, h: float, seg := 7) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bottom
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c


static func _ball(r: float, h := -1.0, seg := 7) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = h if h > 0.0 else r * 2.0
	s.radial_segments = seg
	s.rings = maxi(3, seg / 2)
	return s


static func _box(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b


static func _at(x: float, y: float, z: float, rot := Vector3.ZERO, scale := Vector3.ONE) -> Transform3D:
	var b := Basis.from_euler(rot).scaled(scale)
	return Transform3D(b, Vector3(x, y, z))


## Parts are [PrimitiveMesh, Transform3D, Color]. Built with one flat normal per triangle: the faceted look.
static func build(parts: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in parts:
		var arrays: Array = (p[0] as PrimitiveMesh).get_mesh_arrays()
		var xf: Transform3D = p[1]
		var col: Color = p[2]
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var i := 0
		while i + 2 < idx.size():
			var a := xf * verts[idx[i]]
			var b := xf * verts[idx[i + 1]]
			var c := xf * verts[idx[i + 2]]
			var n := (b - a).cross(c - a)
			if n.length_squared() > 1e-12:
				n = n.normalized()
				var avg := xf.basis * (norms[idx[i]] + norms[idx[i + 1]] + norms[idx[i + 2]])
				if n.dot(avg) < 0.0:
					n = -n
				var shade := col.srgb_to_linear()      # glTF vertex colours are linear; keep placeholders the same
				for v in [a, b, c]:
					st.set_color(shade)
					st.set_normal(n)
					st.add_vertex(v)
			i += 3
	return st.commit()


static func _placeholder(name: String) -> Node3D:
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = _placeholder_mesh(name)
	root.add_child(mi)
	# moving parts and markers the game looks for
	match name:
		"campfire_1", "campfire_2":
			var f := MeshInstance3D.new()
			f.name = "flame"
			f.mesh = build([[_cyl(0.0, 0.22, 0.55, 5), _at(0, 0.27, 0), _c("#FFB02E")],
				[_cyl(0.0, 0.12, 0.35, 5), _at(0.05, 0.42, 0.04), _c("#FFE07A")]])
			f.position.y = 0.12
			root.add_child(f)
		"gate_small", "gate_big":
			var w := 1.6 if name == "gate_small" else 2.4
			var h := 0.9 if name == "gate_small" else 2.1
			var col := _c("#9C6538")
			for side in [-1.0, 1.0]:
				var d := Node3D.new()
				d.name = "door_L" if side < 0.0 else "door_R"
				d.position = Vector3(side * w * 0.5, 0, 0)
				var dm := MeshInstance3D.new()
				dm.mesh = build([[_box(w * 0.5 - 0.05, h, 0.12), _at(-side * w * 0.25, h * 0.5, 0), col],
					[_box(w * 0.5 - 0.05, 0.1, 0.14), _at(-side * w * 0.25, h * 0.7, 0), _c("#6B4226")]])
				d.add_child(dm)
				root.add_child(d)
		"acorn_tower_1", "acorn_tower_2", "acorn_tower_3":
			var lv := int(name.right(1))
			var t := Node3D.new()
			t.name = "turret"
			t.position.y = 1.7 + lv * 0.4
			var tm := MeshInstance3D.new()
			tm.mesh = build([[_box(0.2, 0.18, 0.8), _at(0, 0.12, 0), _c("#6B4226")],
				[_box(0.8, 0.06, 0.08), _at(0, 0.16, 0.25), _c("#9C6538")],
				[_ball(0.08), _at(0, 0.24, 0.35), _c("#B8783E")]])
			t.add_child(tm)
			var mk := Marker3D.new()
			mk.name = "marker_shoot"
			mk.position = Vector3(0, 0.24, 0.45)
			t.add_child(mk)
			root.add_child(t)
		# Phase C (camp_life): the parts and markers the game looks for, until the Blender props exist
		"guardian_stone":
			for k in 3:
				var r := MeshInstance3D.new()
				r.name = "rune_%d" % (k + 1)
				r.mesh = build([[_box(0.12, 0.1, 0.04), _at(0, 0, 0, Vector3(0, 0, PI / 4)), _c("#FFC93C")]])
				r.position = Vector3(0, 0.75 + k * 0.18, 0.43)
				root.add_child(r)
			var mr := Marker3D.new()
			mr.name = "marker_ring"
			mr.position = Vector3(0, 0, 1.1)
			root.add_child(mr)
		"garden_bed":
			for k in 6:
				var mk := Marker3D.new()
				mk.name = "marker_plot_%d" % (k + 1)
				mk.position = Vector3(-0.6 + (k % 3) * 0.6, 0.4, 0.3 if k < 3 else -0.3)
				root.add_child(mk)
		"cook_pot":
			var ms := Marker3D.new()
			ms.name = "marker_steam"
			ms.position = Vector3(0, 0.52, 0)
			root.add_child(ms)
		"fishing_spot":
			var rod := MeshInstance3D.new()
			rod.name = "rod"
			rod.mesh = build([[_box(0.03, 1.1, 0.03), _at(0, 0.55, 0), _c("#B8873E")], [_cyl(0.04, 0.04, 0.05, 6), _at(0, 0.18, 0.03, Vector3(PI / 2, 0, 0)), _c("#5A5A5A")]])
			rod.position = Vector3(-0.35, 0.05, -0.3)
			rod.rotation = Vector3(-0.25, 0, 0.15)
			var tip := Marker3D.new()
			tip.name = "marker_tip"
			tip.position = Vector3(0, 1.1, 0)
			rod.add_child(tip)
			root.add_child(rod)
		"fishing_rod":
			var mt := Marker3D.new()
			mt.name = "marker_tip"
			mt.position = Vector3(0, 0, -1.0)
			root.add_child(mt)
	return root


static func _placeholder_mesh(name: String) -> ArrayMesh:
	var wood := _c("#9C6538")
	var wood_d := _c("#6B4226")
	var leaf := _c("#6FA83A")
	var leaf_d := _c("#3F7A2A")
	var stone := _c("#9A978F")
	var gold := _c("#F2C230")
	var p: Array = []
	match name:
		"campfire_1", "campfire_2":
			var r := 0.42 if name == "campfire_1" else 0.6
			for i in 7:
				var a := TAU * i / 7.0
				p.append([_ball(0.13, 0.18, 5), _at(cos(a) * r, 0.06, sin(a) * r), stone])
			p.append([_cyl(0.07, 0.07, 0.7, 5), _at(0, 0.1, 0, Vector3(0, 0.5, PI / 2)), wood])
			p.append([_cyl(0.07, 0.07, 0.7, 5), _at(0, 0.14, 0, Vector3(0, -0.6, PI / 2)), wood_d])
		"log_seat":
			p.append([_cyl(0.16, 0.16, 1.0, 6), _at(0, 0.16, 0, Vector3(0, 0, PI / 2)), wood])
		"home_tent":
			p.append([_cyl(1.0, 1.0, 1.8, 3), _at(0, 0.62, 0, Vector3(PI / 2, 0, 0), Vector3(1.0, 1.0, 1.25)), _c("#5E8A2E")])
			p.append([_ball(0.22, 0.05, 5), _at(0, 0.7, 0.92), gold])
		"home_hut":
			p.append([_box(2.2, 1.5, 1.9), _at(0, 0.75, 0), wood])
			p.append([_cyl(0.0, 1.75, 1.3, 4), _at(0, 2.1, 0, Vector3(0, PI / 4, 0)), _c("#8DB33A")])
			p.append([_box(0.7, 1.1, 0.1), _at(0, 0.55, 0.96), wood_d])
		"home_treehouse":
			p.append([_cyl(0.55, 0.9, 4.2, 7), _at(0, 2.1, 0), _c("#7B5333")])
			p.append([_box(2.4, 1.3, 2.0), _at(0, 3.0, 0.4), wood])
			p.append([_cyl(0.0, 1.8, 1.1, 4), _at(0, 4.1, 0.4, Vector3(0, PI / 4, 0)), _c("#8DB33A")])
			for v in [Vector3(-1.4, 5.0, -0.2), Vector3(1.3, 5.2, 0.0), Vector3(0, 5.9, -0.5)]:
				p.append([_ball(1.4, 2.2, 7), _at(v.x, v.y, v.z), leaf])
			p.append([_box(0.5, 2.4, 0.08), _at(0.6, 1.2, 1.4), _c("#C9A66B")])
		"bow_bench_1", "bow_bench_2", "bow_bench_3":
			p.append([_box(1.6, 0.12, 0.7), _at(0, 0.85, 0), wood])
			for v in [Vector3(-0.7, 0.4, -0.28), Vector3(0.7, 0.4, -0.28), Vector3(-0.7, 0.4, 0.28), Vector3(0.7, 0.4, 0.28)]:
				p.append([_box(0.1, 0.8, 0.1), _at(v.x, v.y, v.z), wood_d])
			p.append([_cyl(0.02, 0.02, 1.1, 4), _at(0, 0.95, 0, Vector3(0, 0, PI / 2)), _c("#C99A5E")])
			if name != "bow_bench_1":
				p.append([_box(1.4, 1.2, 0.08), _at(0, 1.5, -0.3), wood_d])
			if name == "bow_bench_3":
				p.append([_box(2.4, 0.08, 1.6), _at(0, 2.2, 0, Vector3(-0.15, 0, 0)), _c("#5E8A2E")])
		"target_1", "target_2":
			p.append([_box(0.1, 1.2, 0.1), _at(0, 0.6, -0.1), wood_d])
			p.append([_cyl(0.55, 0.55, 0.14, 10), _at(0, 0.95, 0, Vector3(PI / 2, 0, 0)), _c("#E6C76E")])
			p.append([_cyl(0.36, 0.36, 0.15, 10), _at(0, 0.95, 0, Vector3(PI / 2, 0, 0)), _c("#D9483B")])
			p.append([_cyl(0.15, 0.15, 0.16, 10), _at(0, 0.95, 0, Vector3(PI / 2, 0, 0)), _c("#F2E5C4")])
		"leaf_basket":
			p.append([_cyl(0.42, 0.32, 0.55, 8), _at(0, 0.27, 0), _c("#C9A66B")])
			p.append([_ball(0.38, 0.3, 7), _at(0, 0.56, 0), gold])
		"leaf_chest":
			p.append([_box(1.0, 0.55, 0.65), _at(0, 0.28, 0), wood])
			p.append([_ball(0.45, 0.3, 7), _at(0, 0.6, 0), gold])
		"timber_pile":
			for i in 4:
				p.append([_cyl(0.12, 0.12, 1.1, 6), _at(0, 0.12 + (i / 2) * 0.22, (i % 2) * 0.24 - 0.12, Vector3(0, 0, PI / 2)), wood])
		"fence_twig":
			p.append([_box(2.0, 0.08, 0.06), _at(0, 0.5, 0), wood])
			p.append([_box(2.0, 0.08, 0.06), _at(0, 0.25, 0), wood_d])
			p.append([_box(0.1, 0.7, 0.1), _at(-1.0, 0.35, 0), wood_d])
		"palisade", "palisade_stone":
			var base := 0.0
			if name == "palisade_stone":
				p.append([_box(2.0, 0.35, 0.4), _at(0, 0.17, 0), stone])
				base = 0.3
			for i in 6:
				p.append([_cyl(0.15, 0.17, 1.4, 6), _at(-0.85 + i * 0.34, base + 0.7, 0), wood if i % 2 == 0 else wood_d])
				p.append([_cyl(0.0, 0.15, 0.25, 6), _at(-0.85 + i * 0.34, base + 1.52, 0), wood])
		"gate_small", "gate_big":
			var w := 1.6 if name == "gate_small" else 2.4
			var h := 1.0 if name == "gate_small" else 2.3
			for side in [-1.0, 1.0]:
				p.append([_box(0.18, h, 0.18), _at(side * (w * 0.5 + 0.1), h * 0.5, 0), wood_d])
			if name == "gate_big":
				p.append([_box(w + 0.6, 0.25, 0.25), _at(0, h + 0.1, 0), wood_d])
		"acorn_tower_1", "acorn_tower_2", "acorn_tower_3":
			var lv := int(name.right(1))
			var h := 1.6 + lv * 0.4
			for v in [Vector3(-0.5, 0, -0.5), Vector3(0.5, 0, -0.5), Vector3(-0.5, 0, 0.5), Vector3(0.5, 0, 0.5)]:
				p.append([_box(0.14, h, 0.14), _at(v.x, h * 0.5, v.z), wood_d])
			p.append([_box(1.3, 0.12, 1.3), _at(0, h, 0), wood])
			if lv >= 2:
				p.append([_cyl(0.0, 1.0, 0.6, 4), _at(0, h + 1.0, 0, Vector3(0, PI / 4, 0)), _c("#8DB33A")])
			if lv >= 3:
				p.append([_box(1.5, 0.5, 1.5), _at(0, 0.25, 0), stone])
		"thorn_spikes_1", "thorn_spikes_2", "thorn_spikes_3":
			var lv := int(name.right(1))
			for i in 4 + lv * 3:
				var a := float(i) * 2.4
				p.append([_cyl(0.0, 0.07, 0.25 + lv * 0.05, 5), _at(cos(a) * 0.5 * (0.3 + 0.7 * fmod(i * 0.37, 1.0)), 0.13, sin(a) * 0.35, Vector3(0.2 * sin(a), 0, 0.2 * cos(a))), wood if i % 2 == 0 else _c("#C99A5E")])
			p.append([_box(1.4, 0.05, 1.0), _at(0, 0.02, 0), leaf_d])
		"bramble_fence_1", "bramble_fence_2", "bramble_fence_3":
			var lv := int(name.right(1))
			var h := 0.6 + lv * 0.15
			for i in 5:
				p.append([_ball(0.3 + lv * 0.04, h, 6), _at(-0.9 + i * 0.45, h * 0.5, 0), leaf_d if i % 2 == 0 else _c("#4E8A2E")])
			for i in 8:
				p.append([_cyl(0.0, 0.04, 0.18, 4), _at(-0.9 + i * 0.26, h * 0.55, 0.25, Vector3(PI / 2, 0, 0)), _c("#F2E5C4")])
		"barricade_log":
			for k in 3:
				p.append([_cyl(0.13, 0.13, 3.0, 6), _at(0, 0.15 + k * 0.24, 0.0, Vector3(0, 0, PI / 2)), wood if k % 2 == 0 else wood_d])
			for x in [-1.25, 0.0, 1.25]:
				p.append([_cyl(0.0, 0.09, 1.1, 5), _at(x, 0.55, 0.12, Vector3(0.35, 0, 0)), wood_d])
		"barricade_stone":
			for k in 6:
				p.append([_box(0.5, 0.42, 0.55), _at(-1.25 + k * 0.5, 0.21, 0, Vector3(0, 0.1 * (k % 2), 0)), stone if k % 2 == 0 else stone.darkened(0.1)])
			for k in 5:
				p.append([_box(0.5, 0.38, 0.5), _at(-1.0 + k * 0.5, 0.6, 0.02), stone.lightened(0.05) if k % 2 == 0 else stone])
			p.append([_box(2.9, 0.08, 0.5), _at(0, 0.83, 0), leaf_d])
		"barricade_thorn":
			for k in 7:
				p.append([_ball(0.32, 0.9, 6), _at(-1.3 + k * 0.43, 0.45, 0), leaf_d if k % 2 == 0 else _c("#4E8A2E")])
			for k in 12:
				p.append([_cyl(0.0, 0.05, 0.3, 4), _at(-1.35 + k * 0.245, 0.55 + 0.25 * (k % 3) * 0.5, 0.3, Vector3(PI / 2, 0, 0)), _c("#F2E5C4")])
			p.append([_cyl(0.0, 0.14, 0.4, 5), _at(0, 1.05, 0), _c("#B565E0")])
		# ---- Phase C (camp_life) placeholders, until the Blender props exist
		"guardian_stone":
			for i in 7:
				var a := TAU * i / 7.0
				p.append([_box(0.3, 0.1, 0.22), _at(cos(a) * 0.62, 0.05, sin(a) * 0.62, Vector3(0, -a, 0)), stone.darkened(0.08)])
			p.append([_cyl(0.36, 0.44, 1.45, 7), _at(0, 0.72, 0), stone])
			p.append([_ball(0.4, 0.3, 7), _at(0, 1.45, 0), leaf_d])
			p.append([_ball(0.22, 0.14, 6), _at(-0.3, 0.12, 0.3), leaf])
			p.append([_cyl(0.05, 0.08, 0.6, 5), _at(0.35, 0.1, 0.2, Vector3(0, 0, 1.2)), wood_d])
			p.append([_ball(0.05, 0.05, 5), _at(-0.25, 0.25, 0.45), _c("#FFFFFF")])
		"garden_bed":
			for z in [-0.62, 0.62]:
				p.append([_cyl(0.11, 0.11, 2.2, 6), _at(0, 0.14, z, Vector3(0, 0, PI / 2)), wood])
				p.append([_cyl(0.1, 0.1, 2.2, 6), _at(0, 0.32, z, Vector3(0, 0, PI / 2)), wood_d])
			for x in [-1.05, 1.05]:
				p.append([_box(0.12, 0.42, 1.36), _at(x, 0.21, 0), wood_d])
			p.append([_box(2.0, 0.34, 1.16), _at(0, 0.18, 0), _c("#5B3A22")])
			for k in 6:
				p.append([_ball(0.22, 0.1, 7), _at(-0.6 + (k % 3) * 0.6, 0.36, 0.3 if k < 3 else -0.3), _c("#4A2E1A")])
			p.append([_cyl(0.16, 0.16, 0.4, 7), _at(1.3, 0.2, -0.4), wood])
			p.append([_box(0.3, 0.2, 0.25), _at(-1.32, 0.1, 0.35), wood])
		"cook_pot":
			for i in 3:
				var a := TAU * i / 3.0 + 0.5
				p.append([_ball(0.11, 0.12, 5), _at(cos(a) * 0.22, 0.05, sin(a) * 0.22), stone])
				p.append([_cyl(0.02, 0.02, 0.2, 4), _at(cos(a) * 0.15, 0.15, sin(a) * 0.15), _c("#2C2C30")])
			p.append([_ball(0.06, 0.04, 5), _at(0.05, 0.08, 0.02), _c("#FF8A2E")])
			p.append([_ball(0.25, 0.32, 8), _at(0, 0.34, 0), _c("#3A3A40")])
			p.append([_cyl(0.18, 0.18, 0.02, 8), _at(0, 0.48, 0), _c("#7FB84A")])
			p.append([_cyl(0.015, 0.015, 0.4, 4), _at(0.08, 0.6, 0, Vector3(0, 0, -0.4)), wood])
		"fishing_spot":
			p.append([_cyl(0.24, 0.28, 0.42, 7), _at(0, 0.21, 0), wood])
			p.append([_cyl(0.25, 0.25, 0.05, 7), _at(0, 0.44, 0), leaf_d])
			p.append([_box(0.36, 0.26, 0.3), _at(0.05, 0.13, 0.4), _c("#C9A66B")])
			p.append([_cyl(0.07, 0.07, 0.08, 6), _at(0.32, 0.04, -0.2), _c("#8A8A8A")])
			p.append([_box(0.06, 0.6, 0.06), _at(-0.35, 0.3, -0.45), wood_d])
			p.append([_box(0.3, 0.05, 0.06), _at(-0.35, 0.45, -0.45), wood_d])
		"fishing_rod":
			p.append([_box(0.025, 0.025, 1.1), _at(0, 0, -0.45), _c("#C9A050")])
			p.append([_cyl(0.035, 0.035, 0.04, 6), _at(0, -0.04, -0.05, Vector3(0, 0, PI / 2)), _c("#5A5A5A")])
		"plot_weeds":
			for i in 4:
				var a := TAU * i / 4.0
				p.append([_cyl(0.0, 0.04, 0.14, 3), _at(cos(a) * 0.1, 0.06, sin(a) * 0.1, Vector3(sin(a) * 0.4, 0, -cos(a) * 0.4)), leaf_d])
			p.append([_ball(0.05, 0.04, 5), _at(0.08, 0.02, -0.08), stone])
		"soil_wet":
			p.append([_box(0.45, 0.02, 0.45), _at(0, 0.0, 0), _c("#2E1C10")])
		"plant_sprout":
			p.append([_cyl(0.008, 0.01, 0.1, 4), _at(0, 0.05, 0), leaf_d])
			for x in [-1.0, 1.0]:
				p.append([_ball(0.04, 0.02, 5), _at(x * 0.035, 0.11, 0, Vector3(0, 0, -x * 0.5)), leaf])
		"sunberry_growing", "sunberry_ripe":
			p.append([_ball(0.16, 0.26, 7), _at(0, 0.13, 0), leaf_d])
			p.append([_ball(0.11, 0.16, 6), _at(0.06, 0.24, 0.02), leaf])
			if name == "sunberry_ripe":
				for i in 6:
					var a := TAU * i / 6.0
					p.append([_ball(0.045, 0.05, 5), _at(cos(a) * 0.14, 0.16 + 0.05 * (i % 2), sin(a) * 0.14), _c("#F0602A")])
		"fernmint_growing", "fernmint_ripe":
			var ripe := name == "fernmint_ripe"
			for i in (7 if ripe else 5):
				var a := TAU * i / (7.0 if ripe else 5.0)
				p.append([_cyl(0.0, 0.05, 0.3 if ripe else 0.22, 3), _at(cos(a) * 0.05, 0.12, sin(a) * 0.05, Vector3(sin(a) * 0.45, 0, -cos(a) * 0.45)), _c("#8FD1B0") if ripe else leaf])
				if ripe:
					p.append([_ball(0.02, 0.02, 4), _at(cos(a) * 0.15, 0.27, sin(a) * 0.15), _c("#FFFFFF")])
		"honeybell_growing", "honeybell_ripe":
			for i in 3:
				var x := -0.07 + i * 0.07
				p.append([_cyl(0.008, 0.012, 0.36, 4), _at(x, 0.18, 0.0), leaf_d])
				if name == "honeybell_ripe":
					p.append([_cyl(0.025, 0.06, 0.08, 6), _at(x, 0.36, 0.0), _c("#FFC23C")])
				else:
					p.append([_ball(0.025, 0.05, 5), _at(x, 0.37, 0.0), leaf])
			p.append([_cyl(0.0, 0.05, 0.14, 3), _at(0.05, 0.06, 0.04, Vector3(0.6, 0, 0)), leaf])
		"fish_minnow", "fish_perch", "fish_trout", "fish_carp":
			var size: float = {"fish_minnow": 0.15, "fish_perch": 0.22, "fish_trout": 0.3, "fish_carp": 0.35}[name]
			var col: Color = {"fish_minnow": _c("#B8C4CC"), "fish_perch": _c("#E8B04A"), "fish_trout": _c("#C9D6E0"), "fish_carp": _c("#FFC23C")}[name]
			p.append([_ball(size * 0.22, size * 0.4, 6), _at(0, 0, 0, Vector3.ZERO, Vector3(1.0, 1.0, 2.2)), col])
			p.append([_cyl(0.0, size * 0.2, size * 0.25, 3), _at(0, 0, -size * 0.55, Vector3(-PI / 2, 0, 0), Vector3(1.0, 1.0, 0.3)), col.darkened(0.15)])
		"driftwood":
			p.append([_cyl(0.04, 0.06, 0.4, 5), _at(0, 0, 0, Vector3(PI / 2, 0, 0.3)), _c("#9C8E78")])
			p.append([_cyl(0.02, 0.03, 0.14, 4), _at(0.04, 0.03, 0.06, Vector3(0.6, 0, -0.8)), _c("#8C7E68")])
		"sunken_chest":
			p.append([_box(0.3, 0.18, 0.2), _at(0, 0, 0), wood_d])
			p.append([_box(0.31, 0.06, 0.21), _at(0, 0.1, 0), leaf_d])
			p.append([_ball(0.03, 0.03, 4), _at(0, 0.02, 0.105), gold])
		"golden_leaf":
			p.append([_cyl(0.0, 0.12, 0.26, 4), _at(0, 0, 0, Vector3(PI / 2, 0, 0), Vector3(1.0, 1.0, 0.25)), gold])
		"wishing_well":
			for i in 9:
				var a := TAU * i / 9.0
				p.append([_box(0.36, 0.5, 0.22), _at(cos(a) * 0.5, 0.25, sin(a) * 0.5, Vector3(0, -a, 0)), stone if i % 2 == 0 else stone.darkened(0.1)])
			p.append([_cyl(0.42, 0.42, 0.05, 9), _at(0, 0.42, 0), _c("#2E6E8E")])
			p.append([_cyl(0.6, 0.6, 0.08, 9), _at(0, 0.52, 0), leaf_d])
			for x in [-0.55, 0.55]:
				p.append([_box(0.1, 1.2, 0.1), _at(x, 1.0, 0), wood_d])
			p.append([_cyl(0.035, 0.035, 1.2, 5), _at(0, 1.35, 0, Vector3(0, 0, PI / 2)), wood])
			p.append([_cyl(0.0, 0.95, 0.5, 4), _at(0, 1.78, 0, Vector3(0, PI / 4, 0), Vector3(1.0, 1.0, 0.7)), leaf])
			p.append([_cyl(0.11, 0.09, 0.16, 6), _at(0, 0.95, 0), wood])
		"mushroom_cottage":
			p.append([_cyl(0.62, 0.72, 1.3, 9), _at(0, 0.65, 0), _c("#F2E5C4")])
			p.append([_ball(1.15, 1.1, 10), _at(0, 1.55, 0), _c("#D9483B")])
			for v in [Vector3(0.5, 1.92, 0.55), Vector3(-0.6, 1.85, 0.35), Vector3(0.05, 2.05, -0.2), Vector3(-0.25, 1.8, 0.85), Vector3(0.75, 1.75, -0.4)]:
				p.append([_ball(0.16, 0.08, 6), _at(v.x, v.y, v.z), _c("#F2E5C4")])
			p.append([_cyl(0.28, 0.28, 0.06, 8), _at(0, 0.45, 0.68, Vector3(PI / 2, 0, 0), Vector3(1.0, 1.0, 1.5)), wood])
			p.append([_ball(0.04), _at(0.12, 0.45, 0.72), gold])
			for x in [-0.45, 0.45]:
				p.append([_cyl(0.13, 0.13, 0.05, 8), _at(x, 0.98, 0.52, Vector3(PI / 2 - 0.5, 0, 0)), _c("#FFD27A")])
			p.append([_box(0.18, 0.4, 0.18), _at(0.55, 2.2, -0.35), stone])
			for i in 6:
				var a := TAU * i / 6.0 + 0.4
				p.append([_ball(0.09, 0.12, 5), _at(cos(a) * 0.85, 0.06, sin(a) * 0.85), [_c("#FF9EC7"), gold, _c("#FFFFFF")][i % 3]])
		"market_stall":
			p.append([_box(1.7, 0.75, 0.75), _at(0, 0.38, 0.1), wood])
			p.append([_box(1.8, 0.07, 0.85), _at(0, 0.78, 0.12), wood_d])
			for v in [Vector3(-0.85, 0, -0.3), Vector3(0.85, 0, -0.3), Vector3(-0.85, 0, 0.5), Vector3(0.85, 0, 0.5)]:
				p.append([_box(0.09, 1.9, 0.09), _at(v.x, 0.95, v.z), wood_d])
			for i in 6:
				p.append([_box(0.33, 0.05, 1.15), _at(-0.83 + i * 0.33, 1.95 + 0.0, 0.1, Vector3(0.28, 0, 0)), _c("#6FA83A") if i % 2 == 0 else _c("#F2E5C4")])
			for x in [-0.5, 0.0, 0.5]:
				p.append([_cyl(0.2, 0.15, 0.18, 7), _at(x, 0.9, 0.2), _c("#C9A66B")])
				p.append([_ball(0.17, 0.12, 6), _at(x, 1.0, 0.2), [_c("#FF8A2E"), _c("#D9483B"), _c("#F2C230")][int(x * 2 + 1)]])
			p.append([_box(0.6, 0.32, 0.05), _at(0, 2.35, 0.62), wood])
			p.append([_ball(0.08, 0.04, 5), _at(0, 2.35, 0.66), gold])
		"acorn":
			p.append([_ball(0.06, 0.13, 6), _at(0, 0, 0), _c("#B8783E")])
			p.append([_ball(0.065, 0.06, 6), _at(0, 0.04, 0), _c("#7A5530")])
		"tree_jungle_1", "tree_jungle_2":
			var h := 4.5 if name == "tree_jungle_1" else 5.5
			p.append([_cyl(0.32, 0.6, h, 6), _at(0, h * 0.5, 0), _c("#7B5333")])
			for v in [Vector3(-1.1, h, 0.2), Vector3(1.0, h + 0.3, -0.2), Vector3(0, h + 0.9, 0.3), Vector3(0.2, h - 0.2, 1.0)]:
				p.append([_ball(1.3, 1.6, 6), _at(v.x, v.y, v.z), leaf if v.y > h else leaf_d])
		"tree_round":
			p.append([_cyl(0.18, 0.28, 2.0, 6), _at(0, 1.0, 0), _c("#7B5333")])
			p.append([_ball(1.2, 2.0, 7), _at(0, 2.6, 0), _c("#7AB847")])
		"bush_1", "bush_2":
			p.append([_ball(0.55, 0.8, 6), _at(0, 0.38, 0), leaf_d if name == "bush_1" else leaf])
			p.append([_ball(0.4, 0.6, 6), _at(0.35, 0.3, 0.15), leaf])
		"fern", "monstera":
			for i in 6:
				var a := TAU * i / 6.0
				p.append([_cyl(0.0, 0.1, 0.6, 3), _at(cos(a) * 0.15, 0.25, sin(a) * 0.15, Vector3(sin(a) * 0.7, 0, -cos(a) * 0.7)), leaf_d if name == "fern" else _c("#4E8A2E")])
		"rock_1", "rock_2", "stepping_stone":
			var s := 0.5 if name == "rock_1" else (1.0 if name == "rock_2" else 0.4)
			p.append([_ball(s * 0.5, s * (0.6 if name != "stepping_stone" else 0.15), 6), _at(0, s * 0.18, 0), stone])
			if name == "rock_2":
				p.append([_ball(s * 0.42, s * 0.2, 6), _at(0, s * 0.42, 0), _c("#8DB33A")])
		"flower_hibiscus", "flower_small_white", "flower_purple":
			var col := _c("#E8463A") if name == "flower_hibiscus" else (_c("#F6F1E6") if name == "flower_small_white" else _c("#9C6CDB"))
			p.append([_cyl(0.01, 0.015, 0.3, 4), _at(0, 0.15, 0), leaf_d])
			p.append([_ball(0.09, 0.07, 5), _at(0, 0.32, 0), col])
		"mushroom_cluster":
			for v in [Vector3(0, 0, 0), Vector3(0.12, 0, 0.08), Vector3(-0.1, 0, 0.1)]:
				p.append([_cyl(0.025, 0.03, 0.14, 5), _at(v.x, 0.07, v.z), _c("#F2E2C2")])
				p.append([_ball(0.08, 0.07, 6), _at(v.x, 0.15, v.z), _c("#D9443A")])
		"gloom_crystal":
			for v in [Vector3(0, 0, 0, ), Vector3(0.15, 0, 0.1), Vector3(-0.12, 0, 0.08)]:
				p.append([_cyl(0.0, 0.09, 0.5 - v.x, 5), _at(v.x, 0.25, v.z, Vector3(v.z, 0, -v.x)), _c("#A64DFF")])
		"log_fallen":
			p.append([_cyl(0.22, 0.25, 2.0, 6), _at(0, 0.22, 0, Vector3(0, 0, PI / 2)), _c("#7B5333")])
			p.append([_box(1.2, 0.08, 0.3), _at(0, 0.45, 0), _c("#8DB33A")])
		_:
			if not missing.has(name):
				missing.append(name)
			p.append([_box(0.5, 0.5, 0.5), _at(0, 0.25, 0), _c("#FF00FF")])
	return build(p)
