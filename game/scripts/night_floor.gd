extends RefCounted
## The Burrows' night floor (docs/DUNGEON_SPEC.md, "The floor: a road at night"), built by dungeon_map.gd once its
## walkable shapes, lanterns, glow caps and woods are known. From the dungeon's "floor" block:
##   - one big plane drawn by night_ground.gdshader (Low: night_ground_lite.gdshader) from small maps made here, 2 texels
##     a metre (scaled up 3x with a cubic filter): the ground map (r: the walkable ground's signed distance; g: worn,
##     stones missing; b: moss; a: wet, puddles and mud), the light map (rgb: the warm pools of the lanterns and torches,
##     the glow caps, crystals, embers and the Moonwell baked in, so they show on Low with no lights; a: darker, far from
##     the road and in the woods' shade) and the style map (one texel a metre north to south: the road's section there,
##     floor.sections: flagstones, bricks, cobbles, worn, mossy). One draw call for the whole floor, no pool quads.
##   - the road's life, merged into one mesh per 40 m of the map: torches and stone lanterns at the road's edges (each with
##     a halo, a warm pool and a lamp spot for the lights on Medium and High), barrels and crates, broken slabs, old
##     arrows, blades and shields round the fights, roots crossing the road; the arena's rim: giant old swords stuck in
##     the ground with embers at their feet, rune stones and broken rock (north and sides only). Props near a lantern or
##     torch are tinted warm (their vertex colours; the woods' and the verges' through vc_multi), so Low shows it too.
##   - grass tufts along the verges and in the joints, and big leaves spilling onto the road (one MultiMesh each).
## Tall things keep the camera rule (dungeon_map.hides): nothing hides walkable ground from the camera.

const SHADER := preload("res://shaders/night_ground.gdshader")
const SHADER_LITE := preload("res://shaders/night_ground_lite.gdshader")
const PX := 2.0                     # texels a metre, as built here (cheap in GDScript)
const UP := 3                       # ... then scaled up this many times with a cubic filter (smooth edges, no texel steps)
const SPAN := 4.0                   # the ground map's r = 0.5 - distance / SPAN (so 2 m each side of the edge)
const FAR := 16.0                   # the light map's a: 0..1 over this many metres from the walkable ground
const CHUNK := 40.0                 # the dressing's merged meshes: one per 40 m of the map north to south (draw calls)
const NIGHT := Color(0.74, 0.78, 0.88)        # the props in deeper, cool shades at night (their glowing parts keep theirs)

var m                               # dungeon_map.gd
var fl: Dictionary
var mat: ShaderMaterial
var counts := {}                    # what was placed (the tests and the docs read it)
var _from := Vector2.ZERO           # map position of texel (0, 0)'s corner
var _w := 0
var _h := 0
var _dist: PackedFloat32Array       # per texel: distance to the walkable ground (m)
var _far: PackedFloat32Array
var _ch: PackedFloat32Array         # 3 floats a texel: worn, moss, wet
var _light: PackedFloat32Array      # rgb per texel
var _shd: PackedFloat32Array        # per texel: the woods' shade (0..1)
var _cells := {}                    # Vector2i -> parts [PrimitiveMesh, Transform3D, Color] in map space
var _glow_cells := {}
var _r := RandomNumberGenerator.new()


func build(map) -> void:
	m = map
	fl = m.d.get("floor", {})
	_r.seed = int(fl.get("seed", 7177))
	_grid()
	_distance()
	_far_field()
	_patches()
	_dressing()
	_arena_rim()
	_bake_pools()
	_shade()
	_verges()
	_textures()
	_flush()


# ---------------------------------------------------------------- the maps
func _grid() -> void:
	var b: Rect2 = m._bounds.grow(9.0)
	_from = b.position
	_w = int(ceil(b.size.x * PX)) + 1
	_h = int(ceil(b.size.y * PX)) + 1
	var n := _w * _h
	_dist = PackedFloat32Array()
	_dist.resize(n)
	_dist.fill(SPAN)
	_far = PackedFloat32Array()
	_far.resize(n)
	_far.fill(FAR)
	_ch = PackedFloat32Array()
	_ch.resize(n * 3)
	_ch.fill(0.0)                       # (resize leaves the new memory as it was)
	_light = PackedFloat32Array()
	_light.resize(n * 3)
	_light.fill(0.0)
	_shd = PackedFloat32Array()
	_shd.resize(n)
	_shd.fill(0.0)


func _texel(i: int, j: int) -> Vector2:
	return _from + Vector2(i + 0.5, j + 0.5) / PX


## The walkable ground's signed distance at every texel near it: every shape stamped, the nearest wins.
func _distance() -> void:
	for sh in m.shapes:
		_stamp_shape(sh[0], sh[1], float(sh[2]), SPAN * 0.5 + 0.3)


## (Packed arrays are written as members here, never through a parameter.)
func _stamp_shape(a: Vector2, b: Vector2, r: float, reach: float) -> void:
	var e := r + reach
	var i0 := maxi(0, int(floor((minf(a.x, b.x) - e - _from.x) * PX)))
	var i1 := mini(_w - 1, int(ceil((maxf(a.x, b.x) + e - _from.x) * PX)))
	var j0 := maxi(0, int(floor((minf(a.y, b.y) - e - _from.y) * PX)))
	var j1 := mini(_h - 1, int(ceil((maxf(a.y, b.y) + e - _from.y) * PX)))
	var ab := b - a
	var l2 := ab.length_squared()
	for j in range(j0, j1 + 1):
		var row := j * _w
		for i in range(i0, i1 + 1):
			var q := _texel(i, j)
			var t := 0.0 if l2 < 1e-6 else clampf((q - a).dot(ab) / l2, 0.0, 1.0)
			var dd := q.distance_to(a + ab * t) - r
			if dd < _dist[row + i]:
				_dist[row + i] = dd


## How far from the walkable ground (the forest floor darkens away from it): the coarse shapes on a 2 m grid, then
## spread to the texels.
func _far_field() -> void:
	var cw := int(ceil(_w / (PX * 2.0))) + 2
	var ch := int(ceil(_h / (PX * 2.0))) + 2
	var coarse := PackedFloat32Array()
	coarse.resize(cw * ch)
	coarse.fill(FAR)
	for sh in m.coarse:
		var a: Vector2 = sh[0]
		var b: Vector2 = sh[1]
		var r := float(sh[2])
		var ab := b - a
		var l2 := ab.length_squared()
		var e := r + FAR
		var i0 := maxi(0, int(floor((minf(a.x, b.x) - e - _from.x) / 2.0)))
		var i1 := mini(cw - 1, int(ceil((maxf(a.x, b.x) + e - _from.x) / 2.0)))
		var j0 := maxi(0, int(floor((minf(a.y, b.y) - e - _from.y) / 2.0)))
		var j1 := mini(ch - 1, int(ceil((maxf(a.y, b.y) + e - _from.y) / 2.0)))
		for j in range(j0, j1 + 1):
			for i in range(i0, i1 + 1):
				var q := _from + Vector2(i, j) * 2.0
				var t := 0.0 if l2 < 1e-6 else clampf((q - a).dot(ab) / l2, 0.0, 1.0)
				var dd := q.distance_to(a + ab * t) - r
				if dd < coarse[j * cw + i]:
					coarse[j * cw + i] = dd
	for j in _h:
		for i in _w:
			var g := (_texel(i, j) - _from) / 2.0
			var gi := clampi(int(floor(g.x)), 0, cw - 2)
			var gj := clampi(int(floor(g.y)), 0, ch - 2)
			var fx := clampf(g.x - gi, 0.0, 1.0)
			var fz := clampf(g.y - gj, 0.0, 1.0)
			var top := lerpf(coarse[gj * cw + gi], coarse[gj * cw + gi + 1], fx)
			var bot := lerpf(coarse[(gj + 1) * cw + gi], coarse[(gj + 1) * cw + gi + 1], fx)
			_far[j * _w + i] = lerpf(top, bot, fz)


## A soft blob into channel k (0 worn, 1 moss, 2 wet): v at the centre, nothing at radius r; the most wins.
func _blob(k: int, c: Vector2, r: float, v: float) -> void:
	var i0 := maxi(0, int(floor((c.x - r - _from.x) * PX)))
	var i1 := mini(_w - 1, int(ceil((c.x + r - _from.x) * PX)))
	var j0 := maxi(0, int(floor((c.y - r - _from.y) * PX)))
	var j1 := mini(_h - 1, int(ceil((c.y + r - _from.y) * PX)))
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var t := _texel(i, j).distance_to(c) / r
			if t < 1.0:
				var val := v * (1.0 - t * t)
				var o := (j * _w + i) * 3 + k
				if val > _ch[o]:
					_ch[o] = val


## Light: colour x strength at the centre, a soft falloff to radius r; lights add up.
func _glow(c: Vector2, r: float, col: Color, s: float) -> void:
	var i0 := maxi(0, int(floor((c.x - r - _from.x) * PX)))
	var i1 := mini(_w - 1, int(ceil((c.x + r - _from.x) * PX)))
	var j0 := maxi(0, int(floor((c.y - r - _from.y) * PX)))
	var j1 := mini(_h - 1, int(ceil((c.y + r - _from.y) * PX)))
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var t := _texel(i, j).distance_to(c) / r
			if t < 1.0:
				var a := (1.0 - t * t)
				a *= a * s
				var o := (j * _w + i) * 3
				_light[o] += col.r * a
				_light[o + 1] += col.g * a
				_light[o + 2] += col.b * a


## Worn, mossy and wet places: the data's own, a seeded scatter along the road, and the stream's muddy banks.
func _patches() -> void:
	var names := ["worn", "moss", "wet"]
	for k in 3:
		for e in fl.get(names[k], []):
			_blob(k, m.pt(e[0]), float(e[1]), float(e[2]))
	var au: Dictionary = fl.get("auto", {})
	var every: Array = [float(au.get("worn_every", 7.0)), float(au.get("moss_every", 9.0)), float(au.get("puddle_every", 12.0))]
	for k in 3:
		if every[k] <= 0.0:
			continue
		var s: float = _r.randf_range(2.0, every[k])
		while s < m.length - m.arena_r - 2.0:
			var sm: Array = m.sample(s)
			var hw := float(sm[2])
			var off := _r.randf_range(-hw * 0.8, hw * 0.8) if k != 1 else (hw - _r.randf_range(0.0, 0.8)) * (1.0 if _r.randf() < 0.5 else -1.0)
			var q: Vector2 = (sm[0] as Vector2) + m.right_of(sm[1]) * off
			s += every[k] * _r.randf_range(0.6, 1.4)
			if m.in_water(q, 1.0):
				continue
			match k:
				0: _blob(0, q, _r.randf_range(0.7, 1.5), _r.randf_range(0.35, 0.75))
				1: _blob(1, q, _r.randf_range(1.0, 2.0), _r.randf_range(0.4, 0.8))
				2: _blob(2, q, _r.randf_range(1.2, 1.6), 1.0)
	for q in m._stream:
		_blob(2, q, m._stream_half + 2.0, 0.42)


# ---------------------------------------------------------------- the road's life
func _cell(q: Vector2) -> Vector2i:
	return Vector2i(0, floori(q.y / CHUNK))


## Puts a prop's parts (built at the origin) into its cell's merged mesh at q, turned rot, scaled sc.
func _put(parts: Array, q: Vector2, rot: float, sc := 1.0, y := 0.0) -> void:
	var at := Transform3D(Basis(Vector3.UP, rot).scaled(Vector3.ONE * sc), Vector3(q.x, y, q.y))
	var key := _cell(q)
	if not _cells.has(key):
		_cells[key] = []
	for p in parts:
		var col: Color = p[2]
		var glows: bool = p.size() > 3 and bool(p[3])
		if glows:
			_glow_cells[key] = true
		_cells[key].append([p[0], at * (p[1] as Transform3D), col if glows else col * NIGHT, q, glows])
	counts["props"] = int(counts.get("props", 0)) + 1


## How much lantern and torch light falls at q (0..1): the warm part of the light map.
func warm_at(q: Vector2) -> float:
	var i := clampi(int((q.x - _from.x) * PX), 0, _w - 1)
	var j := clampi(int((q.y - _from.y) * PX), 0, _h - 1)
	var o := (j * _w + i) * 3
	return clampf((_light[o] - _light[o + 2] * 0.8) * 1.3, 0.0, 1.0)


## A spot just off the walkable ground: from a clearing's centre toward deg (0 = north, 90 = east), or across the path
## at arc length s (side +1 = right). Pushed out until it is `clear` metres off the edge.
func _edge_spot(e: Dictionary, clear: float) -> Vector2:
	var c: Vector2
	var dir: Vector2
	if e.has("in"):
		c = m.pt({"in": e["in"]})
		var a := deg_to_rad(float(e.get("deg", 90.0)))
		dir = Vector2(sin(a), -cos(a))
	else:
		var sm: Array = m.sample(m.s_of(e.get("s", 0.0)))
		c = sm[0]
		dir = m.right_of(sm[1]) * float(e.get("side", 1.0))
	var q := c
	var k := 0
	while m.sd(q) < clear and k < 80:
		q += dir * 0.25
		k += 1
	return q + dir * float(e.get("out", 0.0))


## A tall thing at q may stand there (it hides no walkable ground from the camera); else a little further out.
func _tall_spot(q: Vector2, out: Vector2, h: float, cr: float) -> Variant:
	for k in 5:
		if not m.hides(q, h, cr) and not m.in_water(q, 0.4):
			return q
		q += out * 0.4
	return null


func _dressing() -> void:
	var lantern := Color.html(String(m.d.get("theme", {}).get("lantern", "#FFB35C")))
	var torch_light := Color.html(String(fl.get("torch_light", "#FF8A3A")))
	var li: Dictionary = fl.get("light", {})
	# torches on posts, and stone lanterns
	for kind in ["torches", "stone_lanterns"]:
		var is_torch: bool = kind == "torches"
		for e in fl.get(kind, []):
			var q0 := _edge_spot(e, 0.5)
			var c: Vector2 = m.pt({"in": e["in"]}) if e.has("in") else (m.sample(m.s_of(e.get("s", 0.0)))[0] as Vector2)
			var q = _tall_spot(q0, (q0 - c).normalized(), 1.0 if is_torch else 1.2, 0.14 if is_torch else 0.3)
			if q == null:
				continue
			var rot := atan2(c.x - q.x, c.y - q.y)
			_put(_torch() if is_torch else _stone_lantern(), q, rot)
			var top: Vector3 = m.w2(q) + Vector3(0, 1.72 if is_torch else 0.9, 0)
			m._halos.append([top, 0.7 if is_torch else 0.55, Color(lantern.r, lantern.g * 0.8, lantern.b * 0.5, 0.65 if is_torch else 0.55)])
			m.lamps.append(top)
			_glow(q, float(li.get("torch_r", 4.6)) if is_torch else 3.4, torch_light if is_torch else lantern, float(li.get("torch", 0.8)) if is_torch else float(li.get("stone_lantern", 0.6)))
			counts[kind] = int(counts.get(kind, 0)) + 1
	# barrels and crates in little groups at the edges
	for e in fl.get("barrels", []):
		var q0 := _edge_spot(e, 0.35)
		var c2: Vector2 = m.pt({"in": e["in"]}) if e.has("in") else (m.sample(m.s_of(e.get("s", 0.0)))[0] as Vector2)
		var out := (q0 - c2).normalized()
		var side := Vector2(-out.y, out.x)
		for k in int(e.get("n", 2)):
			var q1: Vector2 = q0 + side * (k - (int(e.get("n", 2)) - 1) * 0.5) * 0.62 + out * _r.randf_range(0.0, 0.35)
			if m.sd(q1) < 0.25 or m.hides(q1, 0.62, 0.32) or m.in_water(q1, 0.3):
				continue
			var pick := _r.randf()
			_put(_barrel(pick < 0.2) if pick < 0.75 else _crate(), q1, _r.randf() * TAU)
			counts["barrels"] = int(counts.get("barrels", 0)) + 1
	# broken slabs and chips along the verges
	var every := float(fl.get("slabs_every", 6.0))
	var s := 3.0
	while every > 0.0 and s < m.length - 2.0:
		var sm: Array = m.sample(s)
		var sd2 := 1.0 if _r.randf() < 0.5 else -1.0
		var q2: Vector2 = (sm[0] as Vector2) + m.right_of(sm[1]) * sd2 * (float(sm[2]) + _r.randf_range(-0.4, 0.5))
		s += every * _r.randf_range(0.6, 1.4)
		if m.in_water(q2, 0.5) or m.sd(q2) < -0.6 or m.hides(q2, 0.25, 0.4):
			continue
		_put(_slabs(), q2, _r.randf() * TAU)
	# old arrows, blades and shields where the fights are
	for f in m.d.get("fights", []):
		var fc: Vector2 = m.pt(f["at"])
		var cr := 3.0
		for id in m.clearings:
			if (m.clearings[id][0] as Vector2).distance_to(fc) < 0.5:
				cr = float(m.clearings[id][1]) * 0.85
		for k in int(fl.get("relics_per_fight", 4)):
			var a := _r.randf() * TAU
			var q3 := fc + Vector2(cos(a), sin(a)) * _r.randf_range(1.2, cr)
			if m.sd(q3) > -0.3 or m.hits_obstacle(m.w2(q3), 0.4):
				continue
			var pick := _r.randf()
			_put(_arrows() if pick < 0.55 else (_blade() if pick < 0.8 else _shield()), q3, _r.randf() * TAU)
			counts["relics"] = int(counts.get("relics", 0)) + 1
	if m.arena_r > 0.0:
		for k in int(fl.get("relics_arena", 6)):
			var a2 := _r.randf() * TAU
			var q4: Vector2 = m.arena_c + Vector2(cos(a2), sin(a2)) * _r.randf_range(3.0, m.arena_r - 1.0)
			if m.hits_obstacle(m.w2(q4), 0.5):
				continue
			var pick2 := _r.randf()
			_put(_arrows() if pick2 < 0.5 else (_blade() if pick2 < 0.8 else _shield()), q4, _r.randf() * TAU)
			counts["relics"] = int(counts.get("relics", 0)) + 1
	# roots crossing the road here and there
	var re := float(fl.get("roots_every", 15.0))
	var rs := _r.randf_range(6.0, re)
	var skip: Array = fl.get("roots_skip", [])
	while re > 0.0 and rs < m.length - m.arena_r - 3.0:
		var ok := true
		for rg in skip:
			if rs >= float(rg[0]) and rs <= float(rg[1]):
				ok = false
		if ok:
			_root(rs, 1.0 if _r.randf() < 0.5 else -1.0)
		rs += re * _r.randf_range(0.65, 1.35)


func _torch() -> Array:
	var wood := Color("#5A3E28")
	return [
		[Props._cyl(0.15, 0.21, 0.16, 5), Props._at(0, 0.08, 0), Color("#55566A")],
		[Props._cyl(0.045, 0.06, 1.36, 5), Props._at(0, 0.76, 0), wood],
		[Props._cyl(0.09, 0.065, 0.2, 6), Props._at(0, 1.5, 0), Color("#3E2E22")],
		[Props._cyl(0.1, 0.1, 0.04, 6), Props._at(0, 1.41, 0), Color("#6C6E78")],
		[Props._cyl(0.0, 0.13, 0.4, 6), Props._at(0, 1.78, 0), Color("#FF7A22"), true],
		[Props._cyl(0.0, 0.075, 0.28, 5), Props._at(0.01, 1.72, 0.02), Color("#FFD24A"), true]]


func _stone_lantern() -> Array:
	var st := Color("#7A7E90")
	var dk := Color("#5A5C6C")
	var fire := Color("#FFAA3C")
	return [
		[Props._cyl(0.22, 0.28, 0.14, 6), Props._at(0, 0.07, 0), dk],
		[Props._cyl(0.08, 0.11, 0.56, 6), Props._at(0, 0.42, 0), st],
		[Props._cyl(0.22, 0.18, 0.08, 6), Props._at(0, 0.74, 0), dk],
		[Props._box(0.28, 0.24, 0.28), Props._at(0, 0.9, 0), st],
		[Props._box(0.3, 0.13, 0.12), Props._at(0, 0.9, 0), fire, true],
		[Props._box(0.12, 0.13, 0.3), Props._at(0, 0.9, 0), fire, true],
		[Props._cyl(0.0, 0.34, 0.22, 4), Props._at(0, 1.13, 0, Vector3(0, PI / 4.0, 0)), dk],
		[Props._ball(0.05, -1.0, 5), Props._at(0, 1.27, 0), st]]


func _barrel(lying: bool) -> Array:
	var body := Color("#6E4C30")
	var band := Color("#3A383E")
	var parts := [
		[Props._cyl(0.25, 0.25, 0.6, 8), Props._at(0, 0.3, 0), body],
		[Props._cyl(0.275, 0.275, 0.3, 8), Props._at(0, 0.3, 0), body.lightened(0.06)],
		[Props._cyl(0.285, 0.285, 0.05, 8), Props._at(0, 0.13, 0), band],
		[Props._cyl(0.285, 0.285, 0.05, 8), Props._at(0, 0.47, 0), band],
		[Props._cyl(0.22, 0.22, 0.02, 8), Props._at(0, 0.605, 0), body.darkened(0.25)]]
	if lying:
		var tip := Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0, 0.27, 0.3))
		for p in parts:
			p[1] = tip * (p[1] as Transform3D)
	return parts


func _crate() -> Array:
	var wood := Color("#7A5A38")
	return [
		[Props._box(0.5, 0.44, 0.5), Props._at(0, 0.22, 0), wood],
		[Props._box(0.53, 0.07, 0.53), Props._at(0, 0.05, 0), wood.darkened(0.25)],
		[Props._box(0.53, 0.07, 0.53), Props._at(0, 0.4, 0), wood.darkened(0.25)],
		[Props._box(0.07, 0.42, 0.53), Props._at(0, 0.22, 0, Vector3(0, 0, 0.78)), wood.darkened(0.15)]]


func _slabs() -> Array:
	var out: Array = []
	var cols := [Color("#6C7084"), Color("#615A72"), Color("#767A8C")]
	for k in _r.randi_range(2, 3):
		out.append([Props._box(_r.randf_range(0.35, 0.6), 0.08, _r.randf_range(0.25, 0.42)),
			Props._at(_r.randf_range(-0.35, 0.35), 0.03, _r.randf_range(-0.3, 0.3), Vector3(_r.randf_range(-0.25, 0.25), _r.randf() * TAU, _r.randf_range(-0.2, 0.2))),
			cols[k % 3]])
	for k in _r.randi_range(1, 3):
		out.append([Props._box(0.12, 0.08, 0.1), Props._at(_r.randf_range(-0.6, 0.6), 0.03, _r.randf_range(-0.5, 0.5), Vector3(0.3, _r.randf() * TAU, 0.2)), cols[1]])
	return out


func _arrows() -> Array:
	var out: Array = []
	for k in _r.randi_range(2, 4):
		var lean := Vector3(_r.randf_range(-0.55, 0.55), 0, _r.randf_range(-0.55, 0.55))
		var at := Vector3(_r.randf_range(-0.3, 0.3), 0, _r.randf_range(-0.3, 0.3))
		var b := Basis.from_euler(lean)
		var fl2 := Color("#C23A2E") if k % 2 == 0 else Color("#E2DCCB")
		out.append([Props._cyl(0.022, 0.022, 0.6, 4), Transform3D(b, at + b * Vector3(0, 0.22, 0)), Color("#8A6A44")])
		out.append([Props._box(0.075, 0.13, 0.015), Transform3D(b, at + b * Vector3(0, 0.46, 0)), fl2])
		out.append([Props._box(0.015, 0.13, 0.075), Transform3D(b, at + b * Vector3(0, 0.46, 0)), fl2])
	return out


func _blade() -> Array:
	var b := Basis.from_euler(Vector3(_r.randf_range(-0.3, 0.3), 0, _r.randf_range(-0.35, 0.35)))
	return [
		[Props._box(0.08, 0.64, 0.018), Transform3D(b, b * Vector3(0, 0.2, 0)), Color("#A2A8B4")],
		[Props._box(0.26, 0.045, 0.05), Transform3D(b, b * Vector3(0, 0.53, 0)), Color("#6B5A40")],
		[Props._cyl(0.024, 0.024, 0.17, 5), Transform3D(b, b * Vector3(0, 0.64, 0)), Color("#4A3424")],
		[Props._ball(0.04, -1.0, 5), Transform3D(b, b * Vector3(0, 0.74, 0)), Color("#8A7A5A")]]


func _shield() -> Array:
	var tilt := Vector3(1.35, 0, 0)
	return [
		[Props._cyl(0.27, 0.27, 0.045, 8), Props._at(0, 0.09, 0, tilt), Color("#7A5636")],
		[Props._cyl(0.295, 0.295, 0.03, 8), Props._at(0, 0.075, -0.012, tilt), Color("#5E6070")],
		[Props._ball(0.06, 0.05, 6), Props._at(0, 0.11, 0.03, tilt), Color("#8E909C")]]


## A root crossing the road at arc length s from one side: a few sunk, tapering pieces that wander across part of it.
func _root(s: float, side: float) -> void:
	var sm: Array = m.sample(s)
	var c: Vector2 = sm[0]
	var t: Vector2 = sm[1]
	var rt: Vector2 = m.right_of(t) * side
	var hw := float(sm[2])
	var q: Vector2 = c + rt * (hw + 0.7)
	var dir: Vector2 = (-rt + t * _r.randf_range(-0.5, 0.5)).normalized()
	var reach := hw * _r.randf_range(0.45, 0.85)
	var n := 5
	var rad := _r.randf_range(0.12, 0.17)
	var parts: Array = []
	var col := Color("#7A5638")
	var gone := 0.0
	for k in n:
		var seg := (reach + 0.7) / n
		dir = dir.rotated(_r.randf_range(-0.35, 0.35)).lerp(-rt, 0.15).normalized()
		var nq: Vector2 = q + dir * seg
		var r0 := rad * (1.0 - float(k) / n * 0.75)
		var r1 := rad * (1.0 - float(k + 1) / n * 0.75)
		var mid: Vector2 = (q + nq) * 0.5
		var ax := Vector3(nq.x - q.x, 0.0, nq.y - q.y).normalized()
		var xx := Vector3.UP.cross(ax).normalized()
		var basis := Basis(xx, ax, xx.cross(ax))
		parts.append([Props._cyl(r1, r0, seg + 0.06, 5), Transform3D(basis, Vector3(mid.x, r0 * 0.35, mid.y)), col if k % 2 == 0 else col.darkened(0.12)])
		if k == 1 or (k == 3 and _r.randf() < 0.5):
			# a small side root
			var sdir := dir.rotated(1.1 if _r.randf() < 0.5 else -1.1)
			var sq := q + sdir * 0.35
			var sm2 := (q + sq) * 0.5
			var ax2 := Vector3(sq.x - q.x, 0.0, sq.y - q.y).normalized()
			var xx2 := Vector3.UP.cross(ax2).normalized()
			parts.append([Props._cyl(0.02, r0 * 0.55, 0.42, 4), Transform3D(Basis(xx2, ax2, xx2.cross(ax2)), Vector3(sm2.x, r0 * 0.2, sm2.y)), col.darkened(0.1)])
		q = nq
		gone += seg
	var key := _cell(c)
	if not _cells.has(key):
		_cells[key] = []
	for p in parts:
		_cells[key].append([p[0], p[1], (p[2] as Color) * NIGHT, c, false])
	counts["roots"] = int(counts.get("roots", 0)) + 1



# ---------------------------------------------------------------- the road's sections
## The style map: one texel a metre north to south, the section of the road at that z (the path runs north): floor.
## sections [[s from, s to, style]], style "flags", "bricks", "cobbles", "worn", "moss" or [bricks, cobbles, worn, moss].
func _style() -> void:
	var looks := {"flags": [0.0, 0.0, 0.0, 0.0], "bricks": [1.0, 0.0, 0.0, 0.0], "cobbles": [0.0, 1.0, 0.0, 0.0],
		"worn": [0.0, 0.0, 1.0, 0.15], "moss": [0.0, 0.0, 0.1, 1.0]}
	var secs: Array = fl.get("sections", [])
	var z0 := _from.y
	var hh := int(ceil(_h / PX)) + 1
	var bytes := PackedByteArray()
	bytes.resize(hh * 4)
	bytes.fill(0)
	for j in hh:
		var z := z0 + j + 0.5
		# the arc length where the spine crosses this z (it runs north, so the nearest sample in z will do)
		var s := 0.0
		var best := 1e9
		for sp in m.spine:
			var dz: float = absf((sp[0] as Vector2).y - z)
			if dz < best:
				best = dz
				s = float(sp[2])
		var w: Array = looks["flags"]
		for sec in secs:
			if s >= float(sec[0]) and s < float(sec[1]):
				w = sec[2] if sec[2] is Array else looks.get(String(sec[2]), looks["flags"])
		for k in 4:
			bytes[j * 4 + k] = int(clampf(float(w[k]), 0.0, 1.0) * 255.0)
	var img := Image.create_from_data(1, hh, false, Image.FORMAT_RGBA8, bytes)
	mat.set_shader_parameter("style_map", ImageTexture.create_from_image(img))
	mat.set_shader_parameter("style_z", Vector2(m.origin.z + z0, float(hh)))
	counts["sections"] = secs.size()


# ---------------------------------------------------------------- shade (Low has no shadows)
## The woods' shade on the floor: a soft dark blob a little south-east of every tree, bush, big rock and log (the moon is
## high in the north-west). Medium and High also have real shadows, so less of it shows there (shade_k).
func _shade() -> void:
	var size := {"tree_jungle_1": [2.6, 0.55], "tree_jungle_2": [2.6, 0.55], "tree_round": [1.15, 0.45], "bush_1": [0.7, 0.35],
		"bush_2": [0.65, 0.35], "rock_2": [0.6, 0.3], "log_fallen": [0.8, 0.3], "lantern_post": [0.35, 0.2]}
	for kind in m._scat:
		if not size.has(kind):
			continue
		var r0 := float(size[kind][0])
		var v := float(size[kind][1])
		for xf in m._scat[kind]["xfs"]:
			var o: Vector3 = (xf as Transform3D).origin
			var sc: float = (xf as Transform3D).basis.get_scale().x
			var r := r0 * sc
			var c := Vector2(o.x, o.z) + Vector2(0.3, 0.45) * r
			var i0 := maxi(0, int(floor((c.x - r - _from.x) * PX)))
			var i1 := mini(_w - 1, int(ceil((c.x + r - _from.x) * PX)))
			var j0 := maxi(0, int(floor((c.y - r - _from.y) * PX)))
			var j1 := mini(_h - 1, int(ceil((c.y + r - _from.y) * PX)))
			for j in range(j0, j1 + 1):
				for i in range(i0, i1 + 1):
					var tt := _texel(i, j).distance_to(c) / r
					if tt < 1.0:
						var val := v * (1.0 - tt * tt)
						if val > _shd[j * _w + i]:
							_shd[j * _w + i] = val


# ---------------------------------------------------------------- the arena's rim
## Round the arena (north and sides only: nothing tall on the camera's side of the fight): giant old swords stuck point
## down with embers glowing at their feet, rune stones, and broken rock; a warm glow beyond the rim (the shader).
func _arena_rim() -> void:
	var ar: Dictionary = fl.get("arena_rim", {})
	if m.arena_r <= 0.0 or ar.is_empty():
		return
	var c: Vector2 = m.arena_c
	var rr: float = m.arena_r
	var ember := Color.html(String(fl.get("ember_light", "#FF5A1A")))
	for a in ar.get("swords", []):
		var dir := Vector2(sin(deg_to_rad(float(a))), -cos(deg_to_rad(float(a))))
		var q0: Vector2 = c + dir * (rr + float(ar.get("sword_out", 1.6)))
		var q = _tall_spot(q0, dir, 2.7, 0.5)
		if q == null:
			continue
		_put(_sword(), q, atan2(dir.x, dir.y) + _r.randf_range(-0.5, 0.5))
		_glow(q, 2.4, ember, float(ar.get("ember", 0.7)))
		m._halos.append([m.w2(q) + Vector3(0, 0.2, 0), 0.6, Color(ember.r, ember.g, ember.b, 0.45)])
		counts["swords"] = int(counts.get("swords", 0)) + 1
	for a in ar.get("stones", []):
		var dir2 := Vector2(sin(deg_to_rad(float(a))), -cos(deg_to_rad(float(a))))
		var q2 = _tall_spot(c + dir2 * (rr + 0.9), dir2, 1.45, 0.45)
		if q2 == null:
			continue
		_put(rune_stone(true, _r.randi()), q2, atan2(-dir2.x, -dir2.y) + _r.randf_range(-0.25, 0.25))
		counts["rim_stones"] = int(counts.get("rim_stones", 0)) + 1
	for k in int(ar.get("rocks", 14)):
		var a3 := deg_to_rad(_r.randf_range(-120.0, 120.0))
		var q3: Vector2 = c + Vector2(sin(a3), -cos(a3)) * (rr + _r.randf_range(0.3, 2.6))
		if m.sd(q3) < 0.15 or m.hides(q3, 0.4, 0.4):
			continue
		_put(_slabs(), q3, _r.randf() * TAU, _r.randf_range(1.0, 1.6))


## A giant old sword stuck point down: about 2.7 m tall, tilted a little, embers glowing where it went in.
func _sword() -> Array:
	var b := Basis.from_euler(Vector3(_r.randf_range(-0.16, 0.16), 0, _r.randf_range(-0.16, 0.16)))
	var iron := Color("#555A66")
	var out: Array = [
		[Props._box(0.26, 2.1, 0.07), Transform3D(b, b * Vector3(0, 0.95, 0)), iron],
		[Props._box(0.1, 2.0, 0.08), Transform3D(b, b * Vector3(0, 0.95, 0)), Color("#6C7280")],
		[Props._box(0.95, 0.13, 0.16), Transform3D(b, b * Vector3(0, 2.05, 0)), Color("#5E4A32")],
		[Props._cyl(0.06, 0.06, 0.48, 6), Transform3D(b, b * Vector3(0, 2.36, 0)), Color("#3A2A20")],
		[Props._ball(0.11, -1.0, 6), Transform3D(b, b * Vector3(0, 2.65, 0)), Color("#6E5A3A")]]
	for k in 4:
		var a := TAU * k / 4.0 + _r.randf() * 0.8
		out.append([Props._box(0.14, 0.07, 0.11), Props._at(cos(a) * 0.24, 0.03, sin(a) * 0.24, Vector3(0.2, a, 0.1)), Color("#FF6A1A"), true])
	out.append([Props._box(0.22, 0.12, 0.18), Props._at(0.18, 0.05, -0.15, Vector3(0.2, 0.7, 0.15)), Color("#3E3E48")])
	return out


## A rune stone: a weathered slab like an old grave marker, a glyph cut into its face glowing ember orange, rubble at its
## foot. tall: about 1.45 m; else a broken stub about 0.7 m (on the camera's side of a fight it must stay low).
static func rune_stone(tall: bool, seed_n := 0) -> Array:
	var st := Color("#6E7486")
	var dk := Color("#4E5262")
	var glyph := Color("#FF7A2A")
	var h := 1.15 if tall else 0.55
	var lean := 0.18 * (1.0 if seed_n % 2 == 0 else -1.0)
	var out: Array = [
		[Props._box(0.82, h, 0.3), Props._at(0, h * 0.5, 0), st],
		[Props._box(0.95, 0.14, 0.38), Props._at(0, 0.07, 0), dk],
		[Props._box(0.12, 0.08, 0.1), Props._at(0.5, 0.04, 0.22, Vector3(0.2, 0.5, 0.1)), dk],
		[Props._box(0.16, 0.1, 0.14), Props._at(-0.46, 0.05, 0.2, Vector3(0.1, 1.1, 0.2)), st]]
	if tall:
		out.append([Props._box(0.82, 0.3, 0.3), Props._at(0.06 * signf(lean), h + 0.1, 0, Vector3(0, 0, lean)), st])
		out.append([Props._box(0.6, 0.08, 0.31), Props._at(0, h + 0.28, 0, Vector3(0, 0, lean)), dk])
	else:
		out.append([Props._box(0.5, 0.18, 0.3), Props._at(0.12, h + 0.04, 0, Vector3(0, 0, 0.5)), st])
	var gy := h * (0.62 if tall else 0.55)
	out.append([Props._box(0.07, h * 0.42, 0.03), Props._at(0, gy, 0.155), glyph, true])
	out.append([Props._box(0.32, 0.06, 0.03), Props._at(0, gy + h * 0.12, 0.155), glyph, true])
	out.append([Props._box(0.06, 0.2, 0.03), Props._at(-0.13, gy - h * 0.1, 0.155, Vector3(0, 0, 0.6)), glyph, true])
	out.append([Props._box(0.06, 0.2, 0.03), Props._at(0.13, gy - h * 0.1, 0.155, Vector3(0, 0, -0.6)), glyph, true])
	return out

# ---------------------------------------------------------------- the verges: grass tufts and big leaves
func _verges() -> void:
	var night: float = m._night()
	var tufts: Array = []
	var leaves: Array = []
	var every := float(fl.get("tufts_every", 0.6))
	var s := 0.3
	while every > 0.0 and s < m.length:
		var sm: Array = m.sample(s)
		for side in [-1.0, 1.0]:
			var q: Vector2 = (sm[0] as Vector2) + m.right_of(sm[1]) * side * (float(sm[2]) + _r.randf_range(-0.55, 0.45))
			var sd := m.sd(q) as float
			if sd < -0.7 or sd > 0.8 or m.in_water(q, 0.3):
				continue
			tufts.append(Transform3D(Basis(Vector3.UP, _r.randf() * TAU).scaled(Vector3.ONE * _r.randf_range(0.7, 1.25)), Vector3(q.x, 0, q.y)))
		s += every * _r.randf_range(0.6, 1.4)
	for id in m.clearings:
		var cl: Array = m.clearings[id]
		var c: Vector2 = cl[0]
		var rr := float(cl[1])
		var n := int(TAU * rr / maxf(every, 0.3))
		for k in n:
			var a := TAU * (k + _r.randf()) / n
			var q2 := c + Vector2(cos(a), sin(a)) * (rr + _r.randf_range(-0.5, 0.4))
			var sd2 := m.sd(q2) as float
			if sd2 < -0.6 or sd2 > 0.8 or m.in_water(q2, 0.3):
				continue
			tufts.append(Transform3D(Basis(Vector3.UP, _r.randf() * TAU).scaled(Vector3.ONE * _r.randf_range(0.7, 1.2)), Vector3(q2.x, 0, q2.y)))
	# a few small ones in the road's joints
	var je := float(fl.get("joint_tufts_every", 3.0))
	s = 1.0
	while je > 0.0 and s < m.length - m.arena_r:
		var sm3: Array = m.sample(s)
		var q3: Vector2 = (sm3[0] as Vector2) + m.right_of(sm3[1]) * _r.randf_range(-1.0, 1.0) * float(sm3[2]) * 0.85
		s += je * _r.randf_range(0.5, 1.5)
		if not m.in_water(q3, 0.5):
			tufts.append(Transform3D(Basis(Vector3.UP, _r.randf() * TAU).scaled(Vector3.ONE * _r.randf_range(0.45, 0.7)), Vector3(q3.x, 0, q3.y)))
	_multi("grass_tufts", _tuft_mesh(), tufts, Color(0, 0, night * 0.45, 0))
	counts["tufts"] = tufts.size()
	# big leaves spilling onto the road
	var le := float(fl.get("leaves_every", 4.5))
	s = 2.0
	while le > 0.0 and s < m.length - 1.0:
		var sm4: Array = m.sample(s)
		var side2 := 1.0 if _r.randf() < 0.5 else -1.0
		var q4: Vector2 = (sm4[0] as Vector2) + m.right_of(sm4[1]) * side2 * (float(sm4[2]) + _r.randf_range(0.15, 0.7))
		s += le * _r.randf_range(0.6, 1.4)
		var sc := _r.randf_range(0.8, 1.15)
		var sd4 := m.sd(q4) as float
		if sd4 < 0.05 or m.in_water(q4, 0.4) or m.hides(q4, 0.61 * sc, 0.5 * sc):
			continue
		var to_path: Vector2 = (sm4[0] as Vector2) - q4
		leaves.append(Transform3D(Basis(Vector3.UP, atan2(to_path.x, to_path.y) + _r.randf_range(-0.6, 0.6)).scaled(Vector3.ONE * sc), Vector3(q4.x, 0, q4.y)))
	_multi("big_leaves", Props.mesh("monstera"), leaves, Color(0, 0, night * 0.55, 0))
	counts["big_leaves"] = leaves.size()


## Small things everywhere along the road: one MultiMesh for the whole map (one draw call; a few hundred tiny meshes
## cost the GPU less than more draw calls would).
func _multi(nm: String, mesh: Mesh, xfs: Array, custom: Color) -> void:
	if xfs.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for k in xfs.size():
		var o: Vector3 = (xfs[k] as Transform3D).origin
		mm.set_instance_transform(k, xfs[k])
		mm.set_instance_custom_data(k, Color(custom.r, warm_at(Vector2(o.x, o.z)), custom.b, custom.a))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = nm
	mmi.multimesh = mm
	mmi.material_override = Props.vc_multi()
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.position = Vector3(m.origin.x, 0.0, m.origin.z)
	m.add_child(mmi)


static var _tuft: ArrayMesh


func _tuft_mesh() -> ArrayMesh:
	if _tuft != null:
		return _tuft
	var cols := [Color("#5C8A3C"), Color("#4A7432"), Color("#6E9A48")]
	var parts: Array = []
	for k in 7:
		var a := TAU * k / 7.0 + 0.4 * sin(k * 2.3)
		var lean := 0.25 + 0.2 * float(k % 3)
		var h := 0.2 + 0.05 * float((k * 5) % 3)
		var b := Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, lean)
		parts.append([Props._cyl(0.0, 0.035, h, 3), Transform3D(b, Vector3(cos(a) * 0.04, 0, sin(a) * 0.04) + b * Vector3(0, h * 0.5, 0)), cols[k % 3]])
	_tuft = Props.build(parts)
	return _tuft


# ---------------------------------------------------------------- light and the textures
## The map's pools (lanterns, glow caps, crystals, standing stones, embers) baked into the light map, so they no longer
## need additive quads; the Moonwell's soft moonlight.
func _bake_pools() -> void:
	var gain := float(fl.get("light", {}).get("pools", 3.0))
	var cool := float(fl.get("light", {}).get("cool_pools", 0.5))
	for p in m._pools:
		var c: Color = p[2]
		var k := 1.0 if c.r > c.b else cool                  # warm is the one accent: cool pools (glow caps, crystals) softer
		if c.r > c.b:
			c = Color(1.0, 0.5, 0.18, c.a)                    # the lanterns' pools: orange on the stones
		_glow(m.m2(p[0]), float(p[1]) * 1.25, Color(c.r, c.g, c.b), c.a * gain * k)
	m._pools.clear()
	var mw: Dictionary = m.d.get("moonwell", {})
	if not mw.is_empty() and m.clearings.has(String(mw.get("in", "moonwell"))):
		var cl: Array = m.clearings[String(mw.get("in", "moonwell"))]
		_glow(cl[0], float(cl[1]) * 1.1, Color.html(String(fl.get("moon_glow", "#8FB0FF"))), float(fl.get("light", {}).get("moonwell", 0.35)))


func _textures() -> void:
	var n := _w * _h
	var gb := PackedByteArray()
	gb.resize(n * 4)
	var lb := PackedByteArray()
	lb.resize(n * 4)

	for i in n:
		gb[i * 4] = int(clampf(0.5 - _dist[i] / SPAN, 0.0, 1.0) * 255.0)
		gb[i * 4 + 1] = int(clampf(_ch[i * 3], 0.0, 1.0) * 255.0)
		gb[i * 4 + 2] = int(clampf(_ch[i * 3 + 1], 0.0, 1.0) * 255.0)
		gb[i * 4 + 3] = int(clampf(_ch[i * 3 + 2], 0.0, 1.0) * 255.0)
		lb[i * 4] = int(clampf(_light[i * 3], 0.0, 1.0) * 255.0)
		lb[i * 4 + 1] = int(clampf(_light[i * 3 + 1], 0.0, 1.0) * 255.0)
		lb[i * 4 + 2] = int(clampf(_light[i * 3 + 2], 0.0, 1.0) * 255.0)
		lb[i * 4 + 3] = int(clampf(maxf(_far[i] / FAR, _shd[i]), 0.0, 1.0) * 255.0)
	var gi := Image.create_from_data(_w, _h, false, Image.FORMAT_RGBA8, gb)
	var lim := Image.create_from_data(_w, _h, false, Image.FORMAT_RGBA8, lb)
	gi.resize(_w * UP, _h * UP, Image.INTERPOLATE_CUBIC)
	lim.resize(_w * UP, _h * UP, Image.INTERPOLATE_CUBIC)
	for a in Data.args():
		if a.begins_with("--floormaps="):                  # tests: the two maps as pictures
			gi.save_png(a.substr(12).path_join("floor_ground_map.png"))
			lim.save_png(a.substr(12).path_join("floor_light_map.png"))
	var gt := ImageTexture.create_from_image(gi)
	var lt := ImageTexture.create_from_image(lim)
	mat = ShaderMaterial.new()
	mat.shader = SHADER_LITE if Quality.lite_ground() else SHADER
	mat.set_shader_parameter("ground_map", gt)
	mat.set_shader_parameter("light_map", lt)
	mat.set_shader_parameter("map_from", Vector2(m.origin.x + _from.x, m.origin.z + _from.y))
	mat.set_shader_parameter("map_size", Vector2(_w, _h) / PX)
	if m.arena_r > 0.0:
		var ac: Vector3 = m.w2(m.arena_c)
		mat.set_shader_parameter("arena", Vector4(ac.x, ac.z, m.arena_r, 1.0))
	var mw: Dictionary = m.d.get("moonwell", {})
	if not mw.is_empty() and m.clearings.has(String(mw.get("in", "moonwell"))):
		var cl: Array = m.clearings[String(mw.get("in", "moonwell"))]
		var wc: Vector3 = m.w2(cl[0])
		mat.set_shader_parameter("well", Vector4(wc.x, wc.z, float(cl[1]), 1.0))
	var cols: Dictionary = fl.get("colors", {})
	for k in cols:
		mat.set_shader_parameter(String(k), Color.html(String(cols[k])))
	for k in ["light_gain", "dapple", "wash_k"]:
		if fl.has(k):
			mat.set_shader_parameter(k, float(fl[k]))
	mat.set_shader_parameter("shade_k", 1.0 if not Quality.shadows() else float(fl.get("shade_with_shadows", 0.45)))
	_style()
	# one plane under everything (it also covers the far ground the woods stand on)
	var mi := MeshInstance3D.new()
	mi.name = "floor"
	var pm := PlaneMesh.new()
	pm.size = Vector2(m._bounds.size.x + 160.0, m._bounds.size.y + 160.0)
	mi.mesh = pm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = m.w2(m._bounds.get_center())
	m.add_child(mi)
	counts["map_px"] = [_w, _h]


func _flush() -> void:
	for key in _cells:
		var parts: Array = []
		for p in _cells[key]:
			var col: Color = p[2]
			if not bool(p[4]):
				var w := warm_at(p[3])
				if w > 0.01:
					col = col.lerp(Color(minf(col.r * 1.7 + 0.12, 1.0), minf(col.g * 1.1 + 0.04, 1.0), col.b * 0.75), w)
			parts.append([p[0], p[1], col])
		var mi := MeshInstance3D.new()
		mi.mesh = Props.build(parts)
		mi.material_override = Props.vc()
		if _glow_cells.has(key):
			mi.set_instance_shader_parameter("glow", 1.8)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if Quality.shadows() else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(m.origin.x, 0.0, m.origin.z)
		m.add_child(mi)
	counts["dress_cells"] = _cells.size()
	_cells.clear()
