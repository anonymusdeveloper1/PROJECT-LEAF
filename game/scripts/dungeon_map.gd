extends Node3D
## One Burrows map (a dungeon: docs/DUNGEON_SPEC.md), built in code far from the camp from res://data/dungeons/<map>.json:
## a path at night that winds north from the way in to its end (a boss arena or a treasure clearing).
## It owns the walkable ground (the spine's capsules, the clearings, side branches and the arena: the trees are the
## walls), the push-out circles (standing stones, the dead campfire, ...), and the look: the night road and forest floor
## (night_floor.gd: one shaded plane, its light baked in, torches, barrels, relics, roots, grass), the woods as
## MultiMeshes in 14 m cells kept off the camera's side of every walkable spot, lanterns, glow caps and Gloom crystals
## that shine without lights, soft halos (they look the same on Low), fireflies, a stream and its bridge, the arena's
## standing stones and its root gate. The run (burrow_run.gd) adds the props it moves
## (chests, shrines, lifts, the seal) with add_prop / add_ring; reset() takes them away again so the map can be kept
## for the next run (building it is the slow part).
## Map space: x east, z south (north, up the screen, is -z), the way in at (0, 0); the world is origin + (x, 0, z).

const RingScript := preload("res://scripts/marker.gd")
const GLOW := preload("res://shaders/night_glow.gdshader")
const CELL := 14.0                  # scatter cells, culled one by one (as the camp's woods; a little bigger: fewer draw calls)
const FloorScript := preload("res://scripts/night_floor.gd")
const GRID := 6.0                   # the walkable shapes' lookup grid
const NEAR := 2.5                   # the grid knows every shape within this of a cell; further: the coarse shapes
const FLY_OUT := 3.5                # fliers may be this far off the walkable ground (over the stream and the verges)
const HIDE := 0.84                  # a thing h m tall hides about 0.84 x h m of ground north of it (the camera looks 50 degrees down)

var run
var main
var d: Dictionary
var map_id := ""
var origin := Vector3.ZERO
var length := 0.0
var spine: Array = []               # smoothed samples [Vector2 p, float hw, float s]
var clearings := {}                 # id -> [Vector2 centre, float r]
var branches := {}                  # id -> Vector2 junction on the spine
var shapes: Array = []              # [Vector2 a, Vector2 b, float r, String tag] (a circle has a == b)
var coarse: Array = []              # the same at the control points' level (far queries)
var obstacles: Array = []           # [Vector2 centre, float r]
var holes: Array = []               # Vector3 world: where Grublings and the Amber Grub come and go
var ferns: Array = []               # [Vector3 world centre, float r]: hiding places
var lamps: Array = []               # Vector3 world: lantern glass (the lights on Medium and High go to the nearest)
var arena_c := Vector2.ZERO
var arena_r := 0.0
var sealed := false                 # the arena's roots are closed behind the cat (the boss fight)
var rings: Array = []
var parts := {}                     # the run's props and rings (freed by reset)
var gate: Node3D                    # the arena gate's root arch; its part "gate" is the bars
var build_ms := 0
var _grid := {}
var _all: Array = []
var _bounds := Rect2()
var _stream: Array = []             # Vector2 points along the stream's middle
var _stream_half := 0.0
var _glow_mat: ShaderMaterial
var _pool_mat: ShaderMaterial
var _halos: Array = []              # [Vector3 world, float size, Color]
var _pools: Array = []              # [Vector3 world, float radius, Color]


# ---------------------------------------------------------------- building
func build(r, data: Dictionary, at: Vector3) -> void:
	var t0 := Time.get_ticks_msec()
	run = r
	main = r.main
	d = data
	map_id = String(d.get("id", ""))
	origin = at
	_make_spine()
	_make_shapes()
	_build_ground()
	_build_water()
	_build_bridge()
	_build_dressing()
	_build_woods()
	_build_floor()
	_flush_cells()
	_build_glows()
	_base_obstacles = obstacles.size()
	build_ms = Time.get_ticks_msec() - t0


var _base_obstacles := 0


func _make_spine() -> void:
	var cps: Array = d.get("spine", [])
	var pts: Array = []
	for c in cps:
		pts.append(Vector3(float(c[0]), float(c[1]), float(c[2])))
	var sm: Array = []
	var per := 5
	for k in pts.size() - 1:
		var p0: Vector3 = pts[maxi(k - 1, 0)]
		var p1: Vector3 = pts[k]
		var p2: Vector3 = pts[k + 1]
		var p3: Vector3 = pts[mini(k + 2, pts.size() - 1)]
		for st in per:
			var t := float(st) / per
			var t2 := t * t
			var t3 := t2 * t
			sm.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	sm.append(pts[pts.size() - 1])
	spine.clear()
	var s := 0.0
	for i in sm.size():
		var v: Vector3 = sm[i]
		if i > 0:
			s += Vector2(v.x, v.y).distance_to(spine[i - 1][0])
		spine.append([Vector2(v.x, v.y), v.z, s])
	length = s
	for k in pts.size() - 1:
		var a: Vector3 = pts[k]
		var b: Vector3 = pts[k + 1]
		coarse.append([Vector2(a.x, a.y), Vector2(b.x, b.y), maxf(a.z, b.z), "spine"])


## Arc length s along the spine (negative counts back from the end).
func s_of(v) -> float:
	var s := float(v)
	return clampf(length + s if s < 0.0 else s, 0.0, length)


## [Vector2 point, Vector2 direction, float half-width] at arc length s.
func sample(s: float) -> Array:
	s = clampf(s, 0.0, length)
	for i in range(1, spine.size()):
		if float(spine[i][2]) >= s:
			var a: Array = spine[i - 1]
			var b: Array = spine[i]
			var seg: float = float(b[2]) - float(a[2])
			var t: float = (s - float(a[2])) / maxf(seg, 0.0001)
			var pa: Vector2 = a[0]
			var pb: Vector2 = b[0]
			return [pa.lerp(pb, t), (pb - pa).normalized() if seg > 0.0001 else Vector2(0, -1), lerpf(float(a[1]), float(b[1]), t)]
	var last: Array = spine[spine.size() - 1]
	var prev: Array = spine[spine.size() - 2]
	return [last[0], ((last[0] as Vector2) - (prev[0] as Vector2)).normalized(), float(last[1])]


## The right-hand side of walking direction t (walking north, east).
static func right_of(t: Vector2) -> Vector2:
	return Vector2(-t.y, t.x)


## A position from the data: [x, z], {"s", "off"} along the spine, or {"in": clearing} (plus "x"/"z" in any form).
func pt(v) -> Vector2:
	if v is Array:
		return Vector2(float(v[0]), float(v[1]))
	if v is Dictionary:
		var base := Vector2.ZERO
		if v.has("s"):
			var sm := sample(s_of(v["s"]))
			base = (sm[0] as Vector2) + right_of(sm[1]) * float(v.get("off", 0.0))
		elif v.has("in"):
			base = (clearings[String(v["in"])][0] as Vector2) if clearings.has(String(v["in"])) else Vector2.ZERO
		return base + Vector2(float(v.get("x", 0.0)), float(v.get("z", 0.0)))
	return Vector2.ZERO


func w2(q: Vector2) -> Vector3:
	return Vector3(origin.x + q.x, 0.0, origin.z + q.y)


func m2(p: Vector3) -> Vector2:
	return Vector2(p.x - origin.x, p.z - origin.z)


## A data position straight to the world.
func wpt(v) -> Vector3:
	return w2(pt(v))


## How far along the spine the nearest point to q is, and how far off it: Vector2(s, distance).
func progress(q: Vector2) -> Vector2:
	var best := 1e9
	var best_s := 0.0
	for i in range(1, spine.size()):
		var a: Vector2 = spine[i - 1][0]
		var b: Vector2 = spine[i][0]
		var c := Geometry2D.get_closest_point_to_segment(q, a, b)
		var dd := c.distance_to(q)
		if dd < best:
			best = dd
			best_s = float(spine[i - 1][2]) + a.distance_to(c)
	return Vector2(best_s, best)


func _make_shapes() -> void:
	shapes.clear()
	for i in range(1, spine.size()):
		shapes.append([spine[i - 1][0], spine[i][0], (float(spine[i - 1][1]) + float(spine[i][1])) * 0.5, "spine"])
	clearings.clear()
	for c in d.get("clearings", []):
		var at := pt(c["at"])
		clearings[String(c["id"])] = [at, float(c["r"])]
	var ar: Dictionary = d.get("arena", {})
	if not ar.is_empty():
		arena_c = sample(length)[0]
		arena_r = float(ar.get("r", 11.0))
		clearings["arena"] = [arena_c, arena_r]
	for id in clearings:
		var cl: Array = clearings[id]
		shapes.append([cl[0], cl[0], cl[1], "arena" if id == "arena" else "clearing"])
		coarse.append([cl[0], cl[0], cl[1], "clearing"])
	for br in d.get("branches", []):
		var a := pt(br["from"])
		var b := pt(br["to"])
		branches[String(br["id"])] = [a, b, float(br.get("hw", 1.3)), float(br.get("end_r", 2.5))]
		clearings[String(br["id"])] = [b, float(br.get("end_r", 2.5))]
		shapes.append([a, b, float(br.get("hw", 1.3)), "branch:" + String(br["id"])])
		shapes.append([b, b, float(br.get("end_r", 2.5)), "branch:" + String(br["id"])])
		coarse.append([a, b, float(br.get("hw", 1.3)), "branch"])
		coarse.append([b, b, float(br.get("end_r", 2.5)), "branch"])
	# the lookup grid: every shape within NEAR of a cell
	_grid.clear()
	_all.clear()
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	for i in shapes.size():
		_all.append(i)
		var sh: Array = shapes[i]
		var a: Vector2 = sh[0]
		var b: Vector2 = sh[1]
		var e: float = float(sh[2]) + NEAR
		var mn := Vector2(minf(a.x, b.x) - e, minf(a.y, b.y) - e)
		var mx := Vector2(maxf(a.x, b.x) + e, maxf(a.y, b.y) + e)
		lo = Vector2(minf(lo.x, mn.x), minf(lo.y, mn.y))
		hi = Vector2(maxf(hi.x, mx.x), maxf(hi.y, mx.y))
		for gx in range(floori(mn.x / GRID), floori(mx.x / GRID) + 1):
			for gz in range(floori(mn.y / GRID), floori(mx.y / GRID) + 1):
				var key := Vector2i(gx, gz)
				if not _grid.has(key):
					_grid[key] = []
				_grid[key].append(i)
	_bounds = Rect2(lo, hi - lo)
	# push-out circles: the standing stones, and props that block (added as they are built)
	obstacles.clear()
	for st in d.get("stones", []):
		obstacles.append([arena_c + Vector2(float(st[0]), float(st[1])), float(st[2])])


static func _seg_dist(q: Vector2, a: Vector2, b: Vector2) -> float:
	if a == b:
		return q.distance_to(a)
	return q.distance_to(Geometry2D.get_closest_point_to_segment(q, a, b))


## Signed distance from q to the walkable ground (negative inside).
func sd(q: Vector2) -> float:
	var best := 1e9
	var near: Array = _grid.get(Vector2i(floori(q.x / GRID), floori(q.y / GRID)), [])
	for i in near:
		var sh: Array = shapes[i]
		best = minf(best, _seg_dist(q, sh[0], sh[1]) - float(sh[2]))
	if best <= NEAR:
		return best
	for sh in coarse:
		best = minf(best, _seg_dist(q, sh[0], sh[1]) - float(sh[2]))
	return best


## Signed distance from q to the path itself (the spine's capsules only, not the clearings).
func sd_path(q: Vector2) -> float:
	var best := 1e9
	var near: Array = _grid.get(Vector2i(floori(q.x / GRID), floori(q.y / GRID)), [])
	for i in near:
		var sh: Array = shapes[i]
		if String(sh[3]) == "spine":
			best = minf(best, _seg_dist(q, sh[0], sh[1]) - float(sh[2]))
	if best <= NEAR:
		return best
	for sh in coarse:
		if String(sh[3]) == "spine":
			best = minf(best, _seg_dist(q, sh[0], sh[1]) - float(sh[2]))
	return best


## The walkable point nearest q that keeps `m` metres inside (q itself when it already is).
func _clamp(q: Vector2, m: float) -> Vector2:
	var list: Array = _grid.get(Vector2i(floori(q.x / GRID), floori(q.y / GRID)), [])
	if list.is_empty():
		list = _all
	var best_out := 1e9
	var best_q := q
	for i in list:
		var sh: Array = shapes[i]
		var a: Vector2 = sh[0]
		var b: Vector2 = sh[1]
		var c := a if a == b else Geometry2D.get_closest_point_to_segment(q, a, b)
		var dist := q.distance_to(c)
		var lim := float(sh[2]) - m
		if dist <= lim:
			return q
		var out := dist - lim
		if out < best_out:
			best_out = out
			best_q = c + (q - c) / dist * maxf(lim, 0.0) if dist > 0.0001 else c
	return best_q


# ---------------------------------------------------------------- the area contract (burrow_run.gd forwards these)
## Keeps p on the walkable ground (radius r inside its edge), out of the stones and blocking props; while the arena is
## sealed, its edge is a wall from both sides. Fliers may hover FLY_OUT metres off the ground's edge.
func constrain(p: Vector3, radius: float, _is_enemy: bool, flyer := false) -> Vector3:
	var q := m2(p)
	var m := radius - FLY_OUT if flyer else radius
	var in_arena := sealed and arena_r > 0.0 and q.distance_to(arena_c) < arena_r
	q = _hold(q, m, in_arena)
	if not flyer and not obstacles.is_empty():
		var moved := false
		for pass_i in 2:
			for o in obstacles:
				var c: Vector2 = o[0]
				var need: float = float(o[1]) + radius
				var dv := q - c
				var dl := dv.length()
				if dl < need:
					q = c + (dv / dl if dl > 0.0001 else Vector2(0, 1)) * need
					moved = true
		if moved:
			q = _hold(q, m, in_arena)
	return Vector3(origin.x + q.x, p.y, origin.z + q.y)


func _hold(q: Vector2, m: float, in_arena: bool) -> Vector2:
	if in_arena:
		var dv := q - arena_c
		var lim := arena_r - maxf(m, 0.05)
		if dv.length() > lim:
			q = arena_c + dv.normalized() * lim
		return q
	q = _clamp(q, m)
	if sealed and arena_r > 0.0:
		var da := q - arena_c
		var need := arena_r + maxf(m, 0.05)
		if da.length() < need:
			q = arena_c + (da.normalized() if da.length() > 0.0001 else Vector2(0, 1)) * need
	return q


## Touching the edge of the walkable ground or a stone (a charge ends there).
func outside(p: Vector3, radius := 0.3) -> bool:
	var q := m2(p)
	if sealed and arena_r > 0.0 and q.distance_to(arena_c) < arena_r:
		if q.distance_to(arena_c) > arena_r - radius - 0.03:
			return true
	elif sd(q) > -(radius + 0.03):
		return true
	return hits_obstacle(p, radius)


func hits_obstacle(p: Vector3, radius: float) -> bool:
	var q := m2(p)
	for o in obstacles:
		if q.distance_to(o[0]) < float(o[1]) + radius + 0.05:
			return true
	return false


func inside(p: Vector3, margin := 0.0) -> bool:
	return sd(m2(p)) < -margin


func in_arena(p: Vector3, margin := 0.0) -> bool:
	return arena_r > 0.0 and m2(p).distance_to(arena_c) < arena_r - margin


## Where a monster at `from` should walk to reach `goal`: the goal itself when the straight line stays on the walkable
## ground, else a point a few metres along the path toward it (out of a side branch by its junction).
func steer(from: Vector3, goal: Vector3) -> Vector3:
	var q0 := m2(from)
	var q1 := m2(goal)
	var dist := q0.distance_to(q1)
	if dist < 2.5 or _line_ok(q0, q1, dist):
		return goal
	for id in branches:
		var br: Array = branches[id]
		if _in_branch(q0, br) and not _in_branch(q1, br):
			return w2(br[0])
	var a := progress(q0).x
	var b := progress(q1).x
	return w2(sample(a + clampf(b - a, -4.0, 4.0))[0])


## In a side branch (its path or its end), away from where it meets the spine.
func _in_branch(q: Vector2, br: Array) -> bool:
	var jn: Vector2 = br[0]
	var en: Vector2 = br[1]
	if q.distance_to(jn) < 1.5 * float(br[2]):
		return false
	return _seg_dist(q, jn, en) < float(br[2]) + 0.3 or q.distance_to(en) < float(br[3]) + 0.3


func _line_ok(q0: Vector2, q1: Vector2, dist: float) -> bool:
	var n := clampi(int(ceil(dist / 1.2)), 2, 10)
	for k in range(1, n):
		if sd(q0.lerp(q1, float(k) / n)) > -0.15:
			return false
	return true


## The hole furthest from p within 16 m of it (the Amber Grub runs there), else a spot 8 m along the path.
func flee_point(p: Vector3) -> Vector3:
	var best := Vector3.ZERO
	var bd := -1.0
	for h in holes:
		var dd := (h as Vector3).distance_to(p)
		if dd < 16.0 and dd > bd:
			bd = dd
			best = h
	if bd >= 0.0:
		return best
	var s := progress(m2(p)).x
	return w2(sample(s + (8.0 if s + 8.0 < length else -8.0))[0])


## The fern patch at p, or null (the Hidden and Ambush mechanic works in the Burrows too).
func hide_at(p: Vector3):
	for f in ferns:
		if Vector2(p.x - f[0].x, p.z - f[0].z).length() < float(f[1]):
			return [f[0], f[1], "grass", null]
	return null


# ---------------------------------------------------------------- the run's props and rings
func add_prop(key: String, nm: String, at: Vector3, rot := 0.0, s := 1.0) -> Node3D:
	var p := Props.instance(nm)
	p.position = at
	p.rotation.y = rot
	p.scale = Vector3.ONE * s
	add_child(p)
	parts[key] = p
	return p


func add_ring(key: String, at: Vector3, builder: Callable, col := Color(1.0, 0.82, 0.3), r := 0.75) -> Node3D:
	var rg := Node3D.new()
	rg.set_script(RingScript)
	add_child(rg)
	rg.setup("burrow", at, r, builder, col)
	rg.attach(parts.get(key), key)                  # its badge over its prop (marker.gd), with the icon for `key`
	main.register_ring(rg)
	rings.append(rg)
	parts[key + "_ring"] = rg
	return rg


## The arena's roots close behind the cat (true) or open again.
func seal_arena(on: bool, quick := false) -> void:
	sealed = on
	if gate == null:
		return
	var bars := Props.find_part(gate, "gate")
	if bars == null:
		return
	var y := 0.0 if on else -2.2
	if quick:
		bars.position.y = y
	else:
		bars.create_tween().tween_property(bars, "position:y", y, 0.7 if on else 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT if on else Tween.EASE_IN)
		Fx.dust(main, gate.global_position + Vector3(0, 0, 0.4), 10, 1.6)


## The run is over: its props and rings go, the arena opens; the map itself stays for the next run.
func reset() -> void:
	for rg in rings:
		if is_instance_valid(rg):
			main.unregister_ring(rg)
	for k in parts:
		var n = parts[k]
		if n != null and is_instance_valid(n):
			(n as Node).queue_free()
	rings.clear()
	parts.clear()
	obstacles.resize(_base_obstacles)
	seal_arena(false, true)


# ---------------------------------------------------------------- the ground
func _col(hex: String, fallback := "#333333") -> Color:
	return Color.html(String(d.get("theme", {}).get(hex, fallback)))


## The stream's line first (the dressing keeps out of the water); the floor itself comes after the dressing and the
## woods (_build_floor).
func _build_ground() -> void:
	var st0 := d.get("stream", {}) as Dictionary
	if not st0.is_empty():
		_make_stream_line(st0)


## The night road and the forest floor (night_floor.gd): one plane drawn from a ground map and a light map (the pools
## of the lanterns, glow caps and crystals are baked into it), the road's torches, barrels, relics and roots, and the
## verges' grass and leaves.
var floor_info := {}
var _floor                          # night_floor.gd (its light map tints the woods near the lanterns)


func _build_floor() -> void:
	_floor = FloorScript.new()
	_floor.build(self)
	floor_info = _floor.counts


# ---------------------------------------------------------------- the stream and the bridge
func _make_stream_line(st: Dictionary) -> void:
	var sm := sample(s_of(st["s"]))
	var c: Vector2 = sm[0]
	var t: Vector2 = sm[1]
	var across := right_of(t)
	var half_len := float(st.get("len", 60.0)) * 0.5
	var mea := float(st.get("meander", 1.0))
	_stream_half = float(st.get("width", 3.6)) * 0.5
	_stream.clear()
	var k := -half_len
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	while k <= half_len + 0.01:
		var q: Vector2 = c + across * k + t * mea * sin(k * 0.21) * clampf(absf(k) / 6.0, 0.0, 1.0)
		_stream.append(q)
		lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y))
		hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.y))
		k += 1.5
	_stream_box = Rect2(lo, hi - lo).grow(_stream_half + 2.0)


var _stream_box := Rect2()


func _stream_dist(q: Vector2) -> float:
	if not _stream_box.has_point(q):
		return 1e9
	var best := 1e9
	for i in range(1, _stream.size()):
		best = minf(best, _seg_dist(q, _stream[i - 1], _stream[i]))
	return best


func in_water(q: Vector2, margin := 0.0) -> bool:
	return _stream_half > 0.0 and _stream_dist(q) < _stream_half + margin


func _build_water() -> void:
	if _stream.size() < 2:
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var water := _col("water")
	var glint := _col("water_glint")
	var r := RandomNumberGenerator.new()
	r.seed = 5150
	for i in range(1, _stream.size()):
		var a: Vector2 = _stream[i - 1]
		var b: Vector2 = _stream[i]
		var tn := (b - a).normalized()
		var sd2 := Vector2(-tn.y, tn.x) * _stream_half
		var lanes := 4
		for ln in lanes:
			var f0 := -1.0 + 2.0 * ln / lanes
			var f1 := -1.0 + 2.0 * (ln + 1) / lanes
			var c := water.lerp(water.lightened(0.15), r.randf() * 0.5)
			if r.randf() < 0.1 and ln > 0 and ln < lanes - 1:
				c = water.lerp(glint, 0.3)
			c = c.srgb_to_linear()
			var v := [a + sd2 * f0, b + sd2 * f0, b + sd2 * f1, a + sd2 * f0, b + sd2 * f1, a + sd2 * f1]
			for q in v:
				st.set_color(c)
				st.set_normal(Vector3.UP)
				st.add_vertex(Vector3((q as Vector2).x, 0.02, (q as Vector2).y))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = Props.vc()
	mi.set_instance_shader_parameter("glow", 1.4)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(origin.x, 0.0, origin.z)
	add_child(mi)
	# stones and ferns on the banks (low: nothing on the camera's side may hide the bridge)
	var kinds := {"rock_1": [], "fern": [], "stepping_stone": []}
	var k := 0
	for i in _stream.size():
		var q: Vector2 = _stream[i]
		for side in [-1.0, 1.0]:
			k += 1
			var tn2 := ((_stream[mini(i + 1, _stream.size() - 1)] as Vector2) - (_stream[maxi(i - 1, 0)] as Vector2)).normalized()
			var at: Vector2 = q + Vector2(-tn2.y, tn2.x) * side * (_stream_half + r.randf_range(0.1, 0.9))
			if sd(at) < 0.3:
				continue
			var kind: String = ["rock_1", "fern", "stepping_stone", "fern"][k % 4]
			kinds[kind].append(Transform3D(Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3.ONE * r.randf_range(0.7, 1.2)), Vector3(at.x, 0, at.y)))
	for kind in kinds:
		_cells(kind, kinds[kind], Color(0, 0, float(d["theme"].get("woods_night", 0.5)) * 0.7, 0), false)


## A wooden bridge over the stream, built from boards in code (2.9 m wide, low rails, so it hides nothing).
func _build_bridge() -> void:
	var br: Dictionary = d.get("bridge", {})
	if br.is_empty():
		return
	var s0 := s_of(br["from_s"])
	var s1 := s_of(br["to_s"])
	var mid := sample((s0 + s1) * 0.5)
	var ln := s1 - s0
	var wd := float(br.get("width", 2.8))
	var wood := Color("#7A5A3A")
	var dark := Color("#563E28")
	var moss := Color("#3F5A2E")
	var parts_list: Array = []
	var n := int(ln / 0.42)
	for i in n:
		var z := -ln * 0.5 + (i + 0.5) * ln / n
		var c := wood if i % 2 == 0 else wood.darkened(0.12)
		if i % 7 == 3:
			c = dark
		parts_list.append([Props._box(wd - 0.05 * (i % 3), 0.07, ln / n - 0.04), Props._at(0.03 * ((i % 3) - 1), 0.05, z, Vector3(0, 0.02 * ((i % 5) - 2), 0)), c])
	for side in [-1.0, 1.0]:
		parts_list.append([Props._box(0.16, 0.14, ln + 0.2), Props._at(side * (wd * 0.5 - 0.06), 0.04, 0), dark])
		for z in [-ln * 0.5, -ln / 6.0, ln / 6.0, ln * 0.5]:
			parts_list.append([Props._box(0.13, 0.72, 0.13), Props._at(side * wd * 0.5, 0.36, z), dark])
			parts_list.append([Props._ball(0.09, 0.06, 5), Props._at(side * wd * 0.5, 0.74, z), moss])
		parts_list.append([Props._box(0.08, 0.08, ln), Props._at(side * wd * 0.5, 0.64, 0), wood])
	var mi := MeshInstance3D.new()
	mi.mesh = Props.build(parts_list)
	mi.material_override = Props.vc()
	var t: Vector2 = mid[1]
	mi.rotation.y = atan2(-t.x, -t.y)
	mi.position = w2(mid[0])
	add_child(mi)


# ---------------------------------------------------------------- dressing: lanterns, glow caps, crystals, props
## A thing h m tall with a top radius cr at q: does it hide walkable ground from the camera? (The camera looks north
## from the south: the ground up to cr + 0.84 h north of it, across its width.)
func hides(q: Vector2, h: float, cr: float) -> bool:
	var reach := cr + HIDE * h
	var z := q.y + cr * 0.5
	while z > q.y - reach:
		for fx in [-0.85, 0.0, 0.85]:
			if sd(Vector2(q.x + fx * cr, z)) < 0.2:
				return true
		z -= 0.8
	return false


func _night() -> float:
	return float(d.get("theme", {}).get("woods_night", 0.5))


func _build_dressing() -> void:
	var th: Dictionary = d.get("theme", {})
	var lantern := Color.html(String(th.get("lantern", "#FFB35C")))
	var mush := Color.html(String(th.get("mushroom", "#4FE3C6")))
	var crys := Color.html(String(th.get("crystal", "#A774FF")))
	# the way in: the hollow's far side, behind the cat
	var wi: Dictionary = d.get("wayin", {})
	if wi.has("hollow"):
		var ho := Props.instance("burrow_hollow")
		ho.position = wpt(wi["hollow"])
		add_child(ho)
		for pn in ["seal", "eyes"]:
			var pp := Props.find_part(ho, pn)
			if pp != null:
				pp.visible = false
		obstacles.append([pt(wi["hollow"]), 1.35])
	# lanterns along the path, alternating sides, just off the walkable ground
	var lt: Dictionary = d.get("lanterns", {})
	var lx: Array = []
	var every := float(lt.get("every", 10.0))
	var s := float(lt.get("from", 6.0))
	var side := 1.0
	while s < length and every > 0.0:
		var skip := false
		for rg in lt.get("skip", []):
			var a := s_of(rg[0])
			var b := float(rg[1]) if float(rg[1]) > 0.0 else length
			if s >= a and s <= minf(b, length):
				skip = true
		if not skip:
			var sm := sample(s)
			var off := float(sm[2]) + 0.4
			var q: Vector2 = (sm[0] as Vector2) + right_of(sm[1]) * side * off
			while sd(q) < 0.45 and off < 9.0:
				off += 0.3
				q = (sm[0] as Vector2) + right_of(sm[1]) * side * off
			if not in_water(q, 0.4):
				var to_path: Vector2 = (sm[0] as Vector2) - q
				lx.append([q, atan2(to_path.x, to_path.y)])
		side = -side
		s += every
	for e in lt.get("extra", []):
		var qe := pt(e)
		var pr := progress(qe)
		var to_p: Vector2 = (sample(pr.x)[0] as Vector2) - qe
		lx.append([qe, atan2(to_p.x, to_p.y) if to_p.length() > 0.1 else 0.0])
	var lxf: Array = []
	for e in lx:
		var q: Vector2 = e[0]
		var xf := Transform3D(Basis(Vector3.UP, float(e[1])), Vector3(q.x, 0, q.y))
		lxf.append(xf)
		var glass: Vector3 = w2(q) + Basis(Vector3.UP, float(e[1])) * Vector3(0, 1.36, 0.14)
		lamps.append(glass)
		_halos.append([glass, 0.62, Color(lantern.r, lantern.g * 0.85, lantern.b * 0.6, 0.6)])     # the flame only: the pool is on the ground
		_pools.append([w2(q), 2.3, Color(lantern.r, lantern.g * 0.85, lantern.b * 0.6, 0.17)])
		if sd(q) < 0.25:
			obstacles.append([q, 0.18])
	_cells("lantern_post", lxf, Color(0, 0, _night() * 0.4, 2.6), true)
	# glow caps round the clearings (small ones where a big one would hide the ground behind it)
	var mxf: Array = []
	var r := RandomNumberGenerator.new()
	r.seed = hash([map_id, "mush"])
	for ring in d.get("mushroom_rings", []):
		var c := pt({"in": ring["in"]})
		var rr := float(ring["r"])
		var nn := int(ring["n"])
		for k in nn:
			var a := TAU * (k + r.randf_range(-0.25, 0.25)) / nn
			var q := c + Vector2(sin(a), -cos(a)) * (rr + r.randf_range(-0.3, 0.4))
			if sd_path(q) < 0.6 or in_water(q, 0.5):
				continue
			var sc := r.randf_range(0.85, 1.2)
			while sc > 0.3 and hides(q, 1.37 * sc, 0.45 * sc):
				sc -= 0.15
			if sc <= 0.3:
				continue
			mxf.append(Transform3D(Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3.ONE * sc), Vector3(q.x, 0, q.y)))
			_halos.append([w2(q) + Vector3(0, 1.0 * sc, 0), 1.25 * sc + 0.3, Color(mush.r, mush.g, mush.b, 0.55)])
			_pools.append([w2(q), 1.5 * sc + 0.3, Color(mush.r, mush.g, mush.b, 0.13)])
	# a few more glow caps along the verges
	var vs := 4.0
	while vs < length - 2.0:
		var sm2 := sample(vs)
		var sd2 := 1.0 if r.randf() < 0.5 else -1.0
		var q2: Vector2 = (sm2[0] as Vector2) + right_of(sm2[1]) * sd2 * (float(sm2[2]) + r.randf_range(0.7, 1.8))
		vs += r.randf_range(5.0, 9.0)
		if sd(q2) < 0.5 or in_water(q2, 0.6) or r.randf() < 0.35:
			continue
		var sc2 := r.randf_range(0.45, 0.8)
		if hides(q2, 1.37 * sc2, 0.45 * sc2):
			continue
		mxf.append(Transform3D(Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3.ONE * sc2), Vector3(q2.x, 0, q2.y)))
		_halos.append([w2(q2) + Vector3(0, 1.0 * sc2, 0), 1.2 * sc2 + 0.2, Color(mush.r, mush.g, mush.b, 0.5)])
		_pools.append([w2(q2), 1.3 * sc2 + 0.3, Color(mush.r, mush.g, mush.b, 0.12)])
	_cells("glow_mushroom_big", mxf, Color(0, 0, _night() * 0.3, 1.7), false)
	# Gloom crystals
	var cxf: Array = []
	for cv in d.get("crystals", []):
		var q3 := pt(cv)
		var sc3 := r.randf_range(1.2, 1.7)
		cxf.append(Transform3D(Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3.ONE * sc3), Vector3(q3.x, 0, q3.y)))
		_halos.append([w2(q3) + Vector3(0, 0.45 * sc3, 0), 1.1, Color(crys.r, crys.g, crys.b, 0.5)])
		_pools.append([w2(q3), 1.3, Color(crys.r, crys.g, crys.b, 0.14)])
	_cells("gloom_crystal", cxf, Color(0, 0, 0, 0), false)
	# burrow holes (the spawners' and the Amber Grub's)
	var hxf: Array = []
	for f in d.get("fights", []):
		for sp in f.get("spawners", []):
			if sp.has("hole"):
				var hq := pt(sp["hole"])
				hxf.append(Transform3D(Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3.ONE * 0.95), Vector3(hq.x, 0, hq.y)))
				holes.append(w2(hq))
	for hv in d.get("holes", []):
		var hq2 := pt(hv)
		hxf.append(Transform3D(Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3.ONE * 0.8), Vector3(hq2.x, 0, hq2.y)))
		holes.append(w2(hq2))
	_cells("burrow_hole", hxf, Color(0, 0, _night() * 0.4, 0), false)
	# fern patches to hide in
	var fxf: Array = []
	for fv in d.get("ferns", []):
		var fc := pt(fv["at"])
		var fr := float(fv.get("r", 1.0))
		ferns.append([w2(fc), fr])
		for k in 5:
			var a2 := TAU * k / 5.0 + 0.3
			var fq := fc + Vector2(cos(a2), sin(a2)) * fr * (0.25 if k == 0 else 0.6)
			fxf.append(Transform3D(Basis(Vector3.UP, a2).scaled(Vector3.ONE * 1.3), Vector3(fq.x, 0, fq.y)))
	_cells("fern", fxf, Color(0, 0, _night() * 0.7, 0), false)
	# the arena's standing stones: rune stones (night_floor.rune_stone) with an ember glyph; the ones in the south half
	# are broken low (the camera looks north: nothing tall on its side of the fight)
	if not (d.get("stones", []) as Array).is_empty():
		var sxf: Array = []
		var sxl: Array = []
		var emb := Color.html(String(th.get("ember", "#FF5A2A")))
		for st in d["stones"]:
			var q4 := arena_c + Vector2(float(st[0]), float(st[1]))
			var k4 := float(st[2]) / 0.55
			var face := atan2(-float(st[0]), -float(st[1])) + r.randf_range(-0.3, 0.3)      # the glyph toward the middle
			var xf4 := Transform3D(Basis(Vector3.UP, face).scaled(Vector3.ONE * k4), Vector3(q4.x, 0, q4.y))
			(sxl if float(st[1]) > 0.5 else sxf).append(xf4)
			_pools.append([w2(q4), 1.3, Color(emb.r, emb.g, emb.b, 0.12)])
		_cells_mesh("standing_stone", Props.build(FloorScript.rune_stone(true)), sxf, Color(0, 0, _night() * 0.35, 1.4), true)
		_cells_mesh("standing_stone_low", Props.build(FloorScript.rune_stone(false)), sxl, Color(0, 0, _night() * 0.35, 1.4), true)
	# the arena gate: a root arch across the path, its bars down (open) until the boss fight
	var ar: Dictionary = d.get("arena", {})
	var gd: Dictionary = d.get("gate", {})
	if not ar.is_empty() and not gd.is_empty():
		var gs := s_of(ar.get("gate_s", -12.0))
		var sm3 := sample(gs)
		if String(gd.get("model", "roots")) == "roots":
			gate = _root_gate(float(gd.get("posts", 2.0)))
		else:
			gate = Props.instance(String(gd["model"]))
			var gsc: Array = gd.get("scale", [1.0, 1.0, 1.0])
			gate.scale = Vector3(float(gsc[0]), float(gsc[1]), float(gsc[2]))
		gate.position = w2(sm3[0])
		var t3: Vector2 = sm3[1]
		gate.rotation.y = atan2(-t3.x, -t3.y)
		add_child(gate)
		var bars := Props.find_part(gate, "gate")
		if bars != null:
			bars.position.y = -2.2
		var post := float(gd.get("posts", 1.0))
		for sgn in [-1.0, 1.0]:
			obstacles.append([(sm3[0] as Vector2) + right_of(t3) * sgn * post, 0.28])
	# the data's own props (a dead campfire, log seats, roots, rocks)
	for pr in d.get("props", []):
		var nm := String(pr[0])
		var q5 := pt(pr[1])
		var node := Props.instance(nm)
		node.position = w2(q5)
		node.rotation.y = float(pr[2])
		node.scale = Vector3.ONE * float(pr[3])
		add_child(node)
		var opts: Dictionary = pr[4] if pr.size() > 4 else {}
		for pn in opts.get("hide", []):
			var pp2 := Props.find_part(node, String(pn))
			if pp2 != null:
				pp2.visible = false
		if opts.has("block"):
			obstacles.append([q5, float(opts["block"])])
		if nm.begins_with("campfire"):
			_halos.append([w2(q5) + Vector3(0, 0.25, 0), 0.9, Color.html(String(th.get("ember", "#FF5A2A"))) * Color(1, 1, 1, 0.45)])
			_pools.append([w2(q5), 1.6, Color.html(String(th.get("ember", "#FF5A2A"))) * Color(1, 1, 1, 0.16)])
	# the path's edges: pebbles, little rocks, ferns, red mushrooms and roots
	var ek := {"stepping_stone": [], "rock_1": [], "fern": [], "mushroom_cluster": [], "root_tangle": []}
	var es := 1.0
	var r2 := RandomNumberGenerator.new()
	r2.seed = hash([map_id, "edges"])
	while es < length:
		var sm4 := sample(es)
		var sd4 := 1.0 if r2.randf() < 0.5 else -1.0
		var q6: Vector2 = (sm4[0] as Vector2) + right_of(sm4[1]) * sd4 * (float(sm4[2]) + r2.randf_range(-0.1, 0.9))
		var pick := r2.randf()
		var kind := "stepping_stone" if pick < 0.32 else ("fern" if pick < 0.6 else ("rock_1" if pick < 0.72 else ("mushroom_cluster" if pick < 0.86 else "root_tangle")))
		var sc4 := r2.randf_range(0.5, 0.9) if kind in ["stepping_stone", "rock_1"] else r2.randf_range(0.8, 1.25)
		var rot := r2.randf() * TAU
		es += r2.randf_range(0.8, 1.7)
		var sdq := sd(q6)
		if sdq < (-0.25 if kind in ["stepping_stone", "fern", "mushroom_cluster"] else 0.25) or in_water(q6, 0.3):
			continue
		ek[kind].append(Transform3D(Basis(Vector3.UP, rot).scaled(Vector3.ONE * sc4), Vector3(q6.x, 0, q6.y)))
	for kind in ek:
		_cells(kind, ek[kind], Color(0, 0, _night() * 0.55, 0), false)


## The arena gate, built in code: two root posts and a low root arch across the path (open, so the arena shows through
## it), and its part "gate": a row of root bars that rise out of the ground when the boss fight starts.
func _root_gate(half: float) -> Node3D:
	var root := Color("#6B4A2E")
	var dark := Color("#4A3220")
	var moss := Color("#4C6B34")
	var bud := Color("#B47CFF")
	var arch: Array = []
	for sgn in [-1.0, 1.0]:
		arch.append([Props._cyl(0.17, 0.34, 1.75, 6), Props._at(sgn * half, 0.85, 0.0, Vector3(0.0, 0.0, -sgn * 0.08)), root])
		arch.append([Props._cyl(0.1, 0.42, 0.35, 6), Props._at(sgn * (half + 0.12), 0.12, 0.05), dark])
		arch.append([Props._ball(0.22, 0.16, 6), Props._at(sgn * (half - 0.05), 1.7, 0.0), moss])
	var pts: Array = []
	for k in 7:
		var a := PI * k / 6.0
		pts.append(Vector2(cos(a) * half, 1.55 + 0.5 * sin(a)))
	for k in 6:
		var p0: Vector2 = pts[k]
		var p1: Vector2 = pts[k + 1]
		var mid := (p0 + p1) * 0.5
		var dv := p1 - p0
		arch.append([Props._cyl(0.12, 0.14, dv.length() + 0.12, 6), Props._at(mid.x, mid.y, 0.0, Vector3(0.0, 0.0, atan2(dv.y, dv.x) - PI * 0.5)), root if k % 2 == 0 else dark])
		if k % 2 == 1:
			arch.append([Props._ball(0.07, 0.07, 5), Props._at(mid.x, mid.y + 0.13, 0.06), bud])
	var node := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = Props.build(arch)
	mi.material_override = Props.vc()
	mi.name = "arch"
	node.add_child(mi)
	var bars: Array = []
	var n := 7
	for i in n:
		var x := -half + 0.35 + i * (2.0 * half - 0.7) / (n - 1)
		var h := 1.35 + 0.18 * float(i % 3)
		bars.append([Props._cyl(0.05, 0.12, h, 5), Props._at(x, h * 0.5, 0.0, Vector3(0.0, 0.0, 0.06 * float((i % 3) - 1))), root if i % 2 == 0 else dark])
		bars.append([Props._cyl(0.0, 0.07, 0.28, 5), Props._at(x, h + 0.1, 0.0), bud if i % 2 == 1 else root])
	var gnode := Node3D.new()
	gnode.name = "gate"
	var bmi := MeshInstance3D.new()
	bmi.mesh = Props.build(bars)
	bmi.material_override = Props.vc()
	gnode.add_child(bmi)
	node.add_child(gnode)
	return node


# ---------------------------------------------------------------- the woods
## Trees, bushes and undergrowth along both sides, darker at night. Every candidate is drawn from the seeded sequence
## first; a tall one that would hide walkable ground from the camera is swapped for something lower (or left out).
func _build_woods() -> void:
	var wd: Dictionary = d.get("woods", {})
	var r := RandomNumberGenerator.new()
	r.seed = int(wd.get("seed", 1))
	var sp := float(wd.get("spacing", 2.4))
	var band := float(wd.get("band", 11.0))
	# [kind, height, top radius, trunk radius] at scale 1, tallest first
	var trees := [["tree_jungle_1", 6.0, 3.3, 0.65], ["tree_jungle_2", 7.0, 3.3, 0.7], ["tree_round", 3.56, 1.25, 0.25]]
	var low := [["bush_1", 0.87, 0.7, 0.5], ["bush_2", 1.26, 0.65, 0.4], ["rock_2", 0.7, 0.6, 0.5], ["log_fallen", 0.66, 1.0, 0.0]]
	var under := [["fern", 0.34, 0.38, 0.0], ["mushroom_cluster", 0.28, 0.2, 0.0], ["fern", 0.34, 0.38, 0.0], ["rock_1", 0.5, 0.3, 0.0]]
	var kinds := {}
	var lo := _bounds.position - Vector2(band, band)
	var hi := _bounds.end + Vector2(band, band)
	var gx := lo.x
	while gx < hi.x:
		var gz := lo.y
		while gz < hi.y:
			var q := Vector2(gx + r.randf_range(-0.45, 0.45) * sp, gz + r.randf_range(-0.45, 0.45) * sp)
			var roll := r.randf()
			var rot := r.randf() * TAU
			var sc := r.randf_range(0.8, 1.15)
			var roll2 := r.randf()
			gz += sp
			var s := sd(q)
			if s < 0.55 or s > band or in_water(q, 0.7):
				continue
			var pick: Array = []
			var order: Array = []
			if s > 3.6:
				order = [trees[0] if roll < 0.32 else (trees[1] if roll < 0.6 else trees[2]), trees[2], low[0], under[0]]
			elif s > 1.8:
				order = [trees[2] if roll < 0.4 else low[int(roll2 * 3.99)], low[0], under[0]]
			else:
				order = [low[int(roll2 * 3.99)] if roll < 0.45 else under[int(roll2 * 3.99)], under[0]]
			for o in order:
				var h := float(o[1]) * sc
				var cr := float(o[2]) * sc
				if s < float(o[3]) * sc + 0.35:
					continue
				if float(o[1]) > 0.6 and hides(q, h, cr):
					continue
				pick = o
				break
			if pick.is_empty():
				continue
			var kind := String(pick[0])
			if not kinds.has(kind):
				kinds[kind] = []
			var ksc := sc * (0.85 if kind.begins_with("tree_jungle") else 1.0)
			kinds[kind].append(Transform3D(Basis(Vector3.UP, rot).scaled(Vector3.ONE * ksc), Vector3(q.x, 0, q.y)))
		gx += sp
	for kind in kinds:
		_cells(kind, kinds[kind], Color(0, 0, _night(), 0), kind.begins_with("tree") or kind.begins_with("bush"))


## Scatter: every kind's instances are gathered (from the woods, the path's edges, the banks, the clearings...) and
## built at the end as one MultiMesh per kind per CELL-sized cell (the camp's way: what is off screen is culled), each
## instance with its own custom data: the vc_multi shader's (gloom, coral, night, shine).
var _scat := {}                     # kind -> {"mesh", "xfs", "cus", "shadow"}


func _cells(kind: String, xfs: Array, custom: Color, shadow: bool) -> void:
	if xfs.is_empty():
		return
	_cells_mesh(kind, Props.mesh(kind), xfs, custom, shadow)


func _cells_mesh(kind: String, mesh: Mesh, xfs: Array, custom: Color, shadow: bool) -> void:
	if not _scat.has(kind):
		_scat[kind] = {"mesh": mesh, "xfs": [], "cus": [], "shadow": false}
	var e: Dictionary = _scat[kind]
	for xf in xfs:
		e["xfs"].append(xf)
		e["cus"].append(custom)
	e["shadow"] = bool(e["shadow"]) or shadow


func _flush_cells() -> void:
	for kind in _scat:
		var e: Dictionary = _scat[kind]
		var xfs: Array = e["xfs"]
		var cells := {}
		for k in xfs.size():
			var o: Vector3 = (xfs[k] as Transform3D).origin
			var key := Vector2i(floori(o.x / CELL), floori(o.z / CELL))
			if not cells.has(key):
				cells[key] = []
			cells[key].append(k)
		for key in cells:
			var idx: Array = cells[key]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_custom_data = true
			mm.mesh = e["mesh"]
			mm.instance_count = idx.size()
			for n in idx.size():
				mm.set_instance_transform(n, xfs[idx[n]])
				var cu: Color = e["cus"][idx[n]]
				if _floor != null and cu.b > 0.0:                # at night: the lanterns' warm light on it (vc_multi)
					var o2: Vector3 = (xfs[idx[n]] as Transform3D).origin
					cu.g = _floor.warm_at(Vector2(o2.x, o2.z))
				mm.set_instance_custom_data(n, cu)
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.material_override = Props.vc_multi()
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if bool(e["shadow"]) and Quality.shadows() else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.position = Vector3(origin.x, 0.0, origin.z)
			add_child(mmi)
	_scat.clear()


# ---------------------------------------------------------------- light without lights
## Halos over the lanterns, glow caps and crystals, pools of light under them, and fireflies: additive discs from three
## MultiMeshes (no lights, so the same on Low; never near the Mobile renderer's 8 lights a mesh).
func _build_glows() -> void:
	_glow_mat = ShaderMaterial.new()
	_glow_mat.shader = GLOW
	_glow_mat.set_shader_parameter("billboard", 1.0)
	_glow_mat.set_shader_parameter("energy", 1.0)
	_pool_mat = ShaderMaterial.new()
	_pool_mat.shader = GLOW
	_pool_mat.set_shader_parameter("billboard", 0.0)
	_pool_mat.set_shader_parameter("energy", 1.0)
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var halo_mm := MultiMesh.new()
	halo_mm.transform_format = MultiMesh.TRANSFORM_3D
	halo_mm.use_colors = true
	halo_mm.mesh = q
	halo_mm.instance_count = _halos.size()
	for i in _halos.size():
		var h: Array = _halos[i]
		halo_mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * float(h[1])), (h[0] as Vector3) - Vector3(origin.x, 0, origin.z)))
		halo_mm.set_instance_color(i, h[2])
	_glow_node("halos", halo_mm, _glow_mat)
	var pm := PlaneMesh.new()
	pm.size = Vector2(2.0, 2.0)
	var pool_mm := MultiMesh.new()
	pool_mm.transform_format = MultiMesh.TRANSFORM_3D
	pool_mm.use_colors = true
	pool_mm.mesh = pm
	pool_mm.instance_count = _pools.size()
	for i in _pools.size():
		var p: Array = _pools[i]
		pool_mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(float(p[1]), 1.0, float(p[1]))), (p[0] as Vector3) - Vector3(origin.x, -0.025, origin.z)))
		pool_mm.set_instance_color(i, p[2])
	if not _pools.is_empty():                # the night floor bakes them into its light map (night_floor.gd)
		_glow_node("pools", pool_mm, _pool_mat)
	# fireflies: a few dozen specks drifting over the verges and the path
	var n := int(round(float(d.get("fireflies", 50)) * [0.5, 0.8, 1.0][clampi(Quality.level, 0, 2)]))
	var col := Color.html(String(d.get("theme", {}).get("fireflies", "#D6FF7A")))
	var r := RandomNumberGenerator.new()
	r.seed = hash([map_id, "fireflies"])
	var ff := MultiMesh.new()
	ff.transform_format = MultiMesh.TRANSFORM_3D
	ff.use_colors = true
	var fq := QuadMesh.new()
	fq.size = Vector2.ONE
	ff.mesh = fq
	var spots: Array = []
	var tries := 0
	while spots.size() < n and tries < n * 20:
		tries += 1
		var s := r.randf() * length
		var sm := sample(s)
		var qq: Vector2 = (sm[0] as Vector2) + right_of(sm[1]) * r.randf_range(-7.0, 7.0)
		if sd(qq) > 4.0:
			continue
		spots.append(Vector3(qq.x, r.randf_range(0.5, 2.4), qq.y))
	ff.instance_count = spots.size()
	for i in spots.size():
		ff.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * r.randf_range(0.16, 0.24)), spots[i]))
		ff.set_instance_color(i, Color(col.r, col.g, col.b, r.randf_range(0.7, 1.0)))
	var fmat := ShaderMaterial.new()
	fmat.shader = GLOW
	fmat.set_shader_parameter("billboard", 1.0)
	fmat.set_shader_parameter("drift", 0.8)
	fmat.set_shader_parameter("energy", 1.6)
	_glow_node("fireflies", ff, fmat)


func _glow_node(nm: String, mm: MultiMesh, mat: Material) -> void:
	var mmi := MultiMeshInstance3D.new()
	mmi.name = nm
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.position = Vector3(origin.x, 0.0, origin.z)
	mmi.custom_aabb = AABB(Vector3(_bounds.position.x - 20.0, -2.0, _bounds.position.y - 20.0), Vector3(_bounds.size.x + 40.0, 8.0, _bounds.size.y + 40.0))
	add_child(mmi)
