extends Control
## Where an attack comes from (19 Nov 2026, the user's ask): small arrows at the edge of the screen pointing toward
## the foes that are off the screen, one per direction (eight sectors round the cat), while a wave or a raid is on, or
## below ground for awake foes. They fade in and out; a foe on the screen needs no arrow. An arrow pulses when a
## building or the campfire was just hit by a foe on its side. The foes are looked at every 0.15 s (own frame seconds,
## never a clock); drawing is a few triangles. Part of the HUD (hud.gd builds it under the cards).

const EVERY := 0.15
const SECTORS := 8
const COL := Color(1.0, 0.5, 0.32)

var main
var _t := 0.0
var _clock := 0.0
var _want: Array = []                 # per sector: [direction on the screen, how many, hit] or null
var _alpha := PackedFloat32Array()
var _dir: Array = []                  # per sector: the arrow's direction now (eased)
var _count := PackedInt32Array()
var _hit := PackedFloat32Array()      # per sector: the pulse left after a hit from that side
var _fire_hp := -1.0
var _bhp := {}
var _drawn := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_alpha.resize(SECTORS)
	_count.resize(SECTORS)
	_hit.resize(SECTORS)
	for k in SECTORS:
		_dir.append(Vector2.UP)
		_want.append(null)


func _process(delta: float) -> void:
	var d := minf(delta, 0.1)
	_clock += d
	_t -= d
	if _t <= 0.0:
		_t = EVERY
		_scan()
	var any := false
	for k in SECTORS:
		var w = _want[k]
		_alpha[k] = move_toward(_alpha[k], 0.85 if w != null else 0.0, d * 3.0)
		_hit[k] = maxf(0.0, _hit[k] - d)
		if w != null:
			_dir[k] = (_dir[k] as Vector2).slerp(w[0], 1.0 - exp(-10.0 * d))
			_count[k] = int(w[1])
		if _alpha[k] > 0.01:
			any = true
	if any or _drawn:
		queue_redraw()
	_drawn = any


## Which foes are off the screen, by direction from the cat; which side just hit a building or the fire.
func _scan() -> void:
	for k in SECTORS:
		_want[k] = null
	var cam: Camera3D = main.cam if main != null else null
	if cam == null or main.player == null or main.frozen:
		return
	var below: bool = main.get("area") != null
	var f = main.fight
	if not below and not (f.active and not (f.mode == "raid" and f.warning)):
		_fire_hp = -1.0
		_bhp.clear()
		return
	var hits: Array = []
	if not below:
		if _fire_hp >= 0.0 and float(f.gate_hp) < _fire_hp - 0.01:
			hits.append(Vector3.ZERO)
		_fire_hp = float(f.gate_hp)
		for id in main.stations.hp:
			var h := float(main.stations.hp[id])
			if _bhp.has(id) and h < float(_bhp[id]) - 0.01:
				hits.append(main.world.station_pos(String(id)))
			_bhp[id] = h
	var cat: Vector3 = main.player.global_position
	var view := get_viewport_rect().grow(-30.0)
	var sum: Array = []
	for k in SECTORS:
		sum.append(Vector2.ZERO)
	for e in get_tree().get_nodes_in_group("foes"):
		if e.dead or not bool(e.get("awake") if e.get("awake") != null else true):
			continue
		var p: Vector3 = e.global_position
		var on_screen: bool = not cam.is_position_behind(p) and view.has_point(cam.unproject_position(p + Vector3(0, 0.3, 0)))
		if on_screen:
			continue                                            # in sight: no arrow needed
		var hit := false
		for h in hits:
			if Vector2(p.x - (h as Vector3).x, p.z - (h as Vector3).z).length() < 3.2:
				hit = true
		var v := Vector2(p.x - cat.x, p.z - cat.z)            # the screen's right is +x, its up is -z
		if v.length() < 0.5:
			continue
		var k := posmod(int(round(atan2(v.y, v.x) / (TAU / SECTORS))), SECTORS)
		sum[k] += v.normalized()
		if _want[k] == null:
			_want[k] = [Vector2.ZERO, 0]
		_want[k][1] = int(_want[k][1]) + 1
		if hit:
			_hit[k] = 0.6
	for k in SECTORS:
		if _want[k] != null:
			_want[k][0] = (sum[k] as Vector2).normalized()


func _draw() -> void:
	if main == null or main.cam == null or main.player == null:
		return
	var size := get_viewport_rect().size
	var hud = main.hud
	var top: float = float(hud._safe.x) + float(hud._top_h) + 40.0 if hud != null else 120.0
	var bottom: float = size.y - (float(hud._safe.y) if hud != null else 0.0) - 130.0
	var c: Vector2 = main.cam.unproject_position(main.player.global_position + Vector3(0, 0.4, 0))
	var box := Rect2(Vector2(28.0, top), Vector2(size.x - 56.0, bottom - top))
	c = c.clamp(box.position + Vector2(1, 1), box.end - Vector2(1, 1))
	for k in SECTORS:
		var a: float = _alpha[k]
		if a <= 0.01:
			continue
		var dv: Vector2 = _dir[k]
		# where the line from the cat that way leaves the box
		var tx := INF
		if dv.x > 0.001:
			tx = (box.end.x - c.x) / dv.x
		elif dv.x < -0.001:
			tx = (box.position.x - c.x) / dv.x
		var ty := INF
		if dv.y > 0.001:
			ty = (box.end.y - c.y) / dv.y
		elif dv.y < -0.001:
			ty = (box.position.y - c.y) / dv.y
		var at := c + dv * minf(tx, ty)
		var pulse: float = _hit[k] / 0.6
		var s := (1.0 + 0.12 * minf(float(_count[k]) - 1.0, 3.0)) * (1.0 + 0.35 * pulse * (0.5 + 0.5 * sin(_clock * 18.0)))
		var side := Vector2(-dv.y, dv.x)
		var tip := at + dv * 19.0 * s
		var pts := PackedVector2Array([tip, at - dv * 11.0 * s + side * 16.0 * s, at - dv * 4.0 * s, at - dv * 11.0 * s - side * 16.0 * s])
		var col := COL.lerp(Color(1.0, 0.92, 0.6), pulse * 0.6)
		col.a = a
		draw_colored_polygon(pts, col)
		pts.append(tip)
		draw_polyline(pts, Color(0.25, 0.08, 0.04, a * 0.8), 2.5, true)
