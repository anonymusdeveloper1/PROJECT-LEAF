extends Node3D
## The meadow, in three layers drawn as MultiMesh chunks (only chunks on screen are drawn):
##   meadow grass  everywhere off the roads, shorter in the camp and at road edges
##   tall grass    thick patches beside the trails and in the open: hiding places for the cat (world.hide_spots)
##   flowers       tiny white, pink, yellow and violet flowers peeking out of the grass, in clumps
## The shader (grass.gdshader) sways them, rolls gusts across the meadow and bends them away from up to 24 walkers that
## the game passes in every frame (set_pushers).

const SHADER := preload("res://shaders/grass.gdshader")
const COUNT := 6500
const HEIGHT := 0.5
const TALL := 1.0
const FLOWERS := 2200
const CHUNK := 7.0
const FLOWER_COLS := [Color(1, 1, 1), Color(1.0, 0.62, 0.78), Color(1.0, 0.86, 0.32), Color(0.75, 0.6, 1.0), Color(1.0, 0.5, 0.42)]

var mat: ShaderMaterial
var mat_tall: ShaderMaterial
var mat_flower: ShaderMaterial
var _chunks: Array = []
var share := 1.0                                 # how much of the grass is planted (Quality: Low 0.4, Medium 0.7, High 1)


func _material(h: float, flower: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("blade_height", h)
	m.set_shader_parameter("flower", flower)
	if h > 0.8:
		m.set_shader_parameter("tip_color", Color(0.78, 0.86, 0.36))
		m.set_shader_parameter("bend", 1.3)
	return m


func build(world) -> void:
	for c in _chunks:
		c.queue_free()
	_chunks.clear()
	if mat == null:
		mat = _material(HEIGHT, false)
		mat_tall = _material(TALL, false)
		mat_flower = _material(0.42, true)
	share = Quality.grass_share()
	var count := int(COUNT * share)
	var flowers := int(FLOWERS * share)
	var tall_share := 0.5 + 0.5 * share          # the hiding patches stay thick enough to read
	var grow := 1.0 + (1.0 - share) * 0.35       # fewer tufts, a little bigger each, so the meadow still looks full
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var keep_out: Array = []
	keep_out.append([world.station_pos("campfire"), 1.7])
	# H6: each building's grass keep-out radius is its entry's layout.grass_radius; "grass_always" ones keep it from the
	# start (home, bench, target), the others once they are built. The saddlery has none.
	for id in ["home", "bench", "target", "well", "stall", "stone", "garden", "fishing", "tailor"]:
		var lay: Dictionary = Data.building_layout(id)
		if not lay.has("grass_radius"):
			continue
		if bool(lay.get("grass_always", false)) or int(Save.stations.get(id, 0)) > 0:
			keep_out.append([world.station_pos(id), float(lay["grass_radius"])])
	for bd in Data.burrow_list():                                  # Phase E: each Burrow's hollow and its ring, in their own list
		var en: Dictionary = bd["entrance"]
		keep_out.append([Vector3(float(en["pos"][0]), 0, float(en["pos"][2])), float(en.get("grass_keep_out", 2.4))])
		keep_out.append([Vector3(float(en["ring"][0]), 0, float(en["ring"][2])), float(en.get("ring_keep_out", 1.1))])
	var reach: float = world.WOODS_R + 1.0
	var cells := {}
	# meadow grass
	var tries := 0
	var placed := 0
	while placed < count and tries < count * 5:
		tries += 1
		var p := _random_point(rng, reach)
		if _blocked(p, keep_out):
			continue
		var ps: float = world.path_strength(p)
		if ps > 0.17:
			continue
		var ld: float = world.lake_dist(p)
		if ld < 0.3:
			continue
		var r := Vector2(p.x, p.z).length()
		var s := rng.randf_range(0.75, 1.3) * grow
		if r < world.camp_r - 0.3:
			s *= 0.55
		if ps > 0.04:
			s *= 0.55
		if ld < 0.9:
			s *= 0.6
		var tint := rng.randf_range(0.9, 1.1)
		var warm := rng.randf_range(-0.04, 0.07)
		_add(cells, "grass", p, rng.randf() * TAU, s, Color(tint + warm, tint, tint - warm * 0.5, 1.0))
		placed += 1
	# tall grass in the hiding patches
	for spot in world.hide_spots:
		if spot[2] != "grass":
			continue
		var c: Vector3 = spot[0]
		var rad: float = spot[1]
		var n := int(PI * rad * rad * 8.0 * tall_share)
		for k in n:
			var a := rng.randf() * TAU
			var d := sqrt(rng.randf()) * rad
			var p := c + Vector3(cos(a) * d, 0, sin(a) * d)
			if world.path_strength(p) > 0.12:
				continue
			var edge := 1.0 - d / rad
			var s := rng.randf_range(0.8, 1.15) * (0.55 + 0.45 * smoothstep(0.0, 0.35, edge))
			var tint := rng.randf_range(0.92, 1.08)
			_add(cells, "tall", p, rng.randf() * TAU, s, Color(tint * 1.04, tint, tint * 0.9, 1.0))
	# flowers, in clumps
	var fl := 0
	tries = 0
	while fl < flowers and tries < flowers * 8:
		tries += 1
		var p := _random_point(rng, reach - 1.0)
		var clump := sin(p.x * 0.55) * cos(p.z * 0.47) + sin(p.x * 0.21 + p.z * 0.33)
		if clump < 0.35 or _blocked(p, keep_out) or world.path_strength(p) > 0.1 or world.lake_dist(p) < 0.4:
			continue
		var pick := int(absf(floorf(p.x * 0.13) + floorf(p.z * 0.17))) % FLOWER_COLS.size()
		if rng.randf() > 0.7:
			pick = rng.randi() % FLOWER_COLS.size()
		_add(cells, "flower", p, rng.randf() * TAU, rng.randf_range(0.8, 1.25), FLOWER_COLS[pick])
		fl += 1
	var blades := 7 if share > 0.5 else 5
	var meshes := {"grass": _tuft(blades, HEIGHT, 0.028), "tall": _tuft(blades + 2, TALL, 0.038), "flower": _flower_tuft()}
	var mats := {"grass": mat, "tall": mat_tall, "flower": mat_flower}
	for key in cells:
		var layer: String = key[0]
		var cell: Vector2i = key[1]
		var xfs: Array = cells[key][0]
		var cols: Array = cells[key][1]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = meshes[layer]
		mm.instance_count = xfs.size()
		for k in xfs.size():
			mm.set_instance_transform(k, xfs[k])
			mm.set_instance_color(k, cols[k])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mats[layer]
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.custom_aabb = AABB(Vector3(cell.x * CHUNK - 1.5, -0.5, cell.y * CHUNK - 1.5), Vector3(CHUNK + 3.0, 2.5, CHUNK + 3.0))
		add_child(mmi)
		_chunks.append(mmi)


func _random_point(rng: RandomNumberGenerator, reach: float) -> Vector3:
	var r := sqrt(rng.randf()) * reach
	var a := rng.randf() * TAU
	return Vector3(sin(a) * r, 0, -cos(a) * r)


func _blocked(p: Vector3, keep_out: Array) -> bool:
	for k in keep_out:
		if p.distance_to(k[0]) < k[1]:
			return true
	return false


func _add(cells: Dictionary, layer: String, p: Vector3, rot: float, s: float, col: Color) -> void:
	var key := [layer, Vector2i(floori(p.x / CHUNK), floori(p.z / CHUNK))]
	if not cells.has(key):
		cells[key] = [[], []]
	cells[key][0].append(Transform3D(Basis(Vector3.UP, rot).scaled(Vector3.ONE * s), p))
	cells[key][1].append(col)


## A clump of curved blades, each three segments that narrow to a point.
func _tuft(blades: int, height: float, width: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5 + blades
	for b in blades:
		var a := rng.randf() * TAU
		var out := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-sin(a), 0, cos(a))
		var base := out * rng.randf_range(0.0, 0.1 * height / HEIGHT)
		var h := height * rng.randf_range(0.6, 1.0)
		var lean := rng.randf_range(0.10, 0.3) * h
		var w := width * rng.randf_range(0.8, 1.2)
		var pts: Array = []
		for k in 4:
			var t := k / 3.0
			var centre := base + out * lean * t * t + Vector3(0, h * t, 0)
			var half := w * (1.0 - t * 0.85) if k < 3 else 0.0
			pts.append([centre - side * half, centre + side * half])
		var n := out.cross(side).normalized()
		for k in 3:
			var l0: Vector3 = pts[k][0]
			var r0: Vector3 = pts[k][1]
			var l1: Vector3 = pts[k + 1][0]
			var r1: Vector3 = pts[k + 1][1]
			var tris := [[l0, r0, l1], [r0, r1, l1]] if k < 2 else [[l0, r0, l1]]
			for tri in tris:
				for v in tri:
					st.set_color(Color.WHITE)
					st.set_normal((n + Vector3.UP * 0.6).normalized())
					st.add_vertex(v)
	return st.commit()


## Three thin stems with a little faceted flower head each (vertex alpha 1 marks the heads).
func _flower_tuft() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	for b in 3:
		var a := rng.randf() * TAU
		var base := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.0, 0.08)
		var h := rng.randf_range(0.28, 0.42)
		var top := base + Vector3(rng.randf_range(-0.03, 0.03), h, rng.randf_range(-0.03, 0.03))
		var side := Vector3(-sin(a), 0, cos(a)) * 0.008
		for v in [base - side, base + side, top]:
			st.set_color(Color(1, 1, 1, 0))
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
		var r := rng.randf_range(0.03, 0.045)
		for k in 5:
			var a0 := TAU * k / 5.0
			var a1 := TAU * (k + 1) / 5.0
			for v in [top + Vector3(0, 0.012, 0), top + Vector3(cos(a0) * r, 0, sin(a0) * r), top + Vector3(cos(a1) * r, 0, sin(a1) * r)]:
				st.set_color(Color(1, 1, 1, 1))
				st.set_normal(Vector3.UP)
				st.add_vertex(v)
	return st.commit()


func set_pushers(list: Array) -> void:
	var arr: Array = []
	for i in mini(list.size(), 24):
		arr.append(list[i])
	while arr.size() < 24:
		arr.append(Vector4(0, -100, 0, 0.001))
	for m in [mat, mat_tall, mat_flower]:
		m.set_shader_parameter("pushers", arr)
		m.set_shader_parameter("pusher_count", mini(list.size(), 24))
