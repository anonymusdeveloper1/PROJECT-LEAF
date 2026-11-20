extends Node3D
## Something the cat can use (19 Nov 2026, "Tap to open"; docs/PHASE_A_PROGRESS.md). A small leaf-shaped badge floats
## over the thing with an icon that says what it is. Tap the badge or the thing itself (interact.gd) and its card opens
## as a dialog (hud.gd); out of reach, the cat walks there first. Walking near opens nothing.
##   far          small and dim
##   near         full size, a gentle bob (within main.RING_NEAR of the cat, where it is heading, or what a tip shows)
##   in reach     bigger, bobbing, a soft glow behind it, a "tap" ripple, and a rim glow on the thing itself
##   pulse        a "!" dot on the badge: something new or affordable there
## The node itself stands where the cat stands to use the thing (the old ring's spot, on the camera's side): reach, the
## walk's goal and the positional checks (`contains`: the Training Target's practice spot) are measured from there.
## `builder` returns the card: {"title", "sub", "rows": [{"text", "note", "cost", "label", "enabled", "action"}]}, or
## the shop-style rows ({"kind": "section"} headings and {"kind": "item"} tiles, hud.gd).
## Phase G2 (defences.gd): every road spot has one ("road_<road>_<spot>", the barricade badge: build a row, or the row's
## pieces and Repair), and a knocked-down tower shows one ("tower_<id>", the repair badge).
## The badges are drawn from SVG in code (made once per icon and colour), on camera-facing quads that ignore depth and
## fog, so they read at night and over the buildings. The badge fades while it would cover the cat.

const RIM_SHADER := preload("res://shaders/marker_rim.gdshader")
const REACH_PAD := 0.65              # reach: the spot's radius and this (1.4 m for most)
const BADGE_W := 0.8                 # the badge's width at full size, metres at the camp camera's distance
const REF_DIST := 20.0               # the camera distance the sizes are for (they keep their size on screen)
const ICONS := {"shop": "bag", "target": "target", "bench": "bow", "sign": "flag", "well": "bucket", "cottage": "mushroom",
	"stall": "awning", "fire": "flame", "stone": "stone", "garden": "sprout", "pot": "pot", "fishing": "fish",
	"home": "home", "lift": "lift", "end_lift": "lift", "seal": "crystal", "barricade": "barricade",
	"repair": "repair"}       # and hollow:*, chest_*, shrine_*, road_* (barricade), tower_* (repair)

static var cat: Node3D               # the cat (main.gd): reach is measured to it
static var _tex := {}                # "icon|colour" -> the badge's texture; also "halo", "ripple", "dot"

var key := ""
var radius := 0.75
var builder: Callable
var icon := "dot"
var pulse := false                   # something new or affordable here: the "!" dot
var color := Color(1.0, 0.82, 0.3)
var obj = null                       # what the badge floats over (null: over the spot itself)
var _src := Callable()               # or what finds it again (the signpost is rebuilt now and then)
var _base := Vector3.ZERO            # where it stood last (a thing freed while rebuilt)
var _has_thing := false              # it floats over a thing (else over the spot itself)
var lift := 1.6                      # how high over it
var offset := Vector3.ZERO           # and how far to the side
var reached := false                 # the cat is within reach (updated every frame)
var _active := false                 # its card is open
var _near := false
var _engaged := false                # tapped, and the cat still in reach (the Gloom seal breaks while this holds)
var _look := 0.0                     # eased: 0 far, 1 near, 2 in reach or open
var _pop := 0.0                      # a bounce when tapped
var _t := 0.0                        # this marker's own seconds (never the clock)
var _phase := 0.0
var _over_cat := 0.0
var _pin: Node3D                     # faces the camera every frame
var _badge: MeshInstance3D
var _halo: MeshInstance3D
var _ripple: MeshInstance3D
var _dot: MeshInstance3D
var _bm: StandardMaterial3D
var _hm: StandardMaterial3D
var _rm: StandardMaterial3D
var _dm: StandardMaterial3D
var _rim: ShaderMaterial
var _rim_on: Array = []              # the thing's meshes that wear the rim glow now


func setup(k: String, pos: Vector3, r: float, b: Callable, col := Color(1.0, 0.82, 0.3)) -> void:
	key = k
	radius = r
	builder = b
	color = col
	icon = icon_for(k)
	global_position = Vector3(pos.x, 0.03, pos.z)
	_phase = fmod(absf(pos.x * 1.7 + pos.z * 2.3), TAU)
	_pin = Node3D.new()
	_pin.top_level = true
	add_child(_pin)
	_hm = _mat(_texture("halo"), 1, false)
	_halo = _quad(Vector2(BADGE_W * 1.9, BADGE_W * 1.9), Vector3(0, BADGE_W * 0.1, -0.02), _hm)
	_rm = _mat(_texture("ripple"), 2, false)
	_ripple = _quad(Vector2(BADGE_W * 1.5, BADGE_W * 1.5), Vector3(0, BADGE_W * 0.1, -0.01), _rm)
	_bm = _mat(_texture(icon, color), 3, false)
	_badge = _quad(Vector2(BADGE_W, BADGE_W * 1.25), Vector3.ZERO, _bm)
	_dm = _mat(_texture("dot"), 4, false)
	_dot = _quad(Vector2(BADGE_W * 0.36, BADGE_W * 0.36), Vector3(-BADGE_W * 0.36, BADGE_W * 0.46, 0.01), _dm)
	_apply(0.0)


## What the badge floats over (a node, or a Callable that finds it) and which icon it shows (`what`: a key of ICONS
## or a prefix). h < 0: just over the thing's top (from its meshes, 1.15-3.1 m; 2.4 m over the spot when there is no
## thing); `off`: to the side of it, so it never sits on the cat at the spot.
func attach(o, what := "", h := -1.0, off := Vector3.ZERO) -> void:
	if what != "":
		icon = icon_for(what)
		if _bm != null:
			_bm.albedo_texture = _texture(icon, color)
	_src = o if o is Callable else Callable()
	if o is Callable:
		o = (o as Callable).call()
	_set_rim(false)
	obj = o if o != null and is_instance_valid(o) else null
	_has_thing = obj != null or _src.is_valid()
	if obj != null:
		_base = (obj as Node3D).global_position
	lift = h if h > 0.0 else _auto_lift(obj)
	offset = off


## The thing, found again if it was rebuilt (null when there is none).
func thing() -> Node3D:
	if obj != null and not is_instance_valid(obj):
		obj = null
		_rim_on.clear()
	if obj == null and _src.is_valid():
		var o = _src.call()
		obj = o if o != null and is_instance_valid(o) else null
	return obj


static func icon_for(k: String) -> String:
	if ICONS.has(k):
		return String(ICONS[k])
	if k.begins_with("hollow"):
		return "hollow"
	if k.begins_with("chest"):
		return "chest"
	if k.begins_with("shrine"):
		return "shrine"
	if k.begins_with("road_"):
		return "barricade"
	if k.begins_with("tower_"):
		return "repair"
	return "dot"


## The badge's colour (the Old Hollow turns from violet to gold when it opens).
func set_color(c: Color) -> void:
	if c.is_equal_approx(color):
		return
	color = c
	if _bm != null:
		_bm.albedo_texture = _texture(icon, color)
	_rim = null
	if not _rim_on.is_empty():
		_set_rim(false)


func contains(p: Vector3) -> bool:
	return visible and Vector2(p.x - global_position.x, p.z - global_position.z).length() < radius


## Close enough to use it (a tap opens its card at once; further away the cat walks here first).
func in_reach(p: Vector3) -> bool:
	return is_visible_in_tree() and Vector2(p.x - global_position.x, p.z - global_position.z).length() < radius + REACH_PAD


func reach() -> float:
	return radius + REACH_PAD


## Its card is open (true) or closed.
func set_active(on: bool) -> void:
	_active = on


## Near the cat (or where it is heading, or what a tip points at): full size. Else small and dim.
func set_near(on: bool) -> void:
	_near = on


## The player tapped it (interact.gd): a bounce, and it is "engaged" while the cat stays in reach.
func tapped() -> void:
	_engaged = true
	_pop = 1.0


func engaged(p: Vector3) -> bool:
	return _engaged and in_reach(p)


## Where the badge floats (its middle), in the world.
func badge_pos() -> Vector3:
	var o := thing()
	if o != null:
		_base = o.global_position
	var b: Vector3 = (_base if _has_thing else Vector3(global_position.x, 0.0, global_position.z)) + offset
	return Vector3(b.x, b.y + lift, b.z)


## The top of the badge (a tip's arrow points here).
func tip_point() -> Vector3:
	return badge_pos() + Vector3(0, BADGE_W * 0.75, 0)


## How big the badge is on the screen now, in HUD pixels (its half width), for tapping it.
func half_px(cam: Camera3D) -> float:
	if cam == null or _pin == null:
		return 30.0
	var p := badge_pos()
	var s := _pin.global_transform.basis.get_scale().x
	return absf(cam.unproject_position(p + cam.global_transform.basis.x * BADGE_W * 0.5 * maxf(s, 0.5)).x - cam.unproject_position(p).x)


## The thing itself on the screen, for tapping it: [base, top, half width] in HUD pixels ([] when there is no thing).
func body_px(cam: Camera3D) -> Array:
	var o := thing()
	if o == null or cam == null:
		return []
	var b: Vector3 = o.global_position
	var top := b + Vector3(0, maxf(lift - 0.55, 0.4), 0)
	if cam.is_position_behind(b) or cam.is_position_behind(top):
		return []
	var a := cam.unproject_position(b)
	var t := cam.unproject_position(top)
	var w := absf(cam.unproject_position(b + cam.global_transform.basis.x * 0.6).x - a.x)
	return [a, t, maxf(w, 26.0)]


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		if not _rim_on.is_empty():
			_set_rim(false)
		return
	var d := minf(delta, 0.1)
	_t += d
	var cam := get_viewport().get_camera_3d()
	var cp: Vector3 = cat.global_position if cat != null and is_instance_valid(cat) else Vector3(1e6, 0, 1e6)
	reached = in_reach(cp)
	if not reached:
		_engaged = false
	var want := 2.0 if (reached or _active) else (1.0 if _near else 0.0)
	_look = move_toward(_look, want, d * 4.0)
	_pop = maxf(0.0, _pop - d * 3.2)
	_over_cat = move_toward(_over_cat, 1.0 if _covers_cat(cam, cp) else 0.0, d * 5.0)
	_apply(d)
	if cam == null:
		return
	var near := clampf(_look, 0.0, 1.0)
	var close := clampf(_look - 1.0, 0.0, 1.0)
	var s := lerpf(0.68, 1.0, near) + 0.18 * close + 0.9 * _pop * (1.0 - _pop)
	var p := badge_pos()
	p.y += sin(_t * 2.6 + _phase) * (0.035 * near + 0.035 * close)
	var k := clampf(cam.global_position.distance_to(p) / REF_DIST, 0.6, 2.2)
	_pin.global_transform = Transform3D(cam.global_transform.basis.orthonormalized().scaled(Vector3.ONE * s * k), p)
	_set_rim(close > 0.5 and thing() != null)
	if not _rim_on.is_empty() and _rim != null:
		_rim.set_shader_parameter("strength", 0.6 + 0.25 * sin(_t * 3.4))


func _apply(_d: float) -> void:
	if _bm == null:
		return
	var near := clampf(_look, 0.0, 1.0)
	var close := clampf(_look - 1.0, 0.0, 1.0)
	var v := lerpf(0.8, 1.0, near)
	var a := lerpf(0.6, 1.0, near) * lerpf(1.0, 0.28, _over_cat)
	_bm.albedo_color = Color(v, v, v, a)
	_halo.visible = close > 0.02
	var glow := color.lerp(Color(1.0, 0.98, 0.85), 0.45)
	_hm.albedo_color = Color(glow.r, glow.g, glow.b, (0.55 + 0.12 * sin(_t * 3.4)) * close * (1.0 - 0.7 * _over_cat))
	var show_ripple := close > 0.5 and not _active
	_ripple.visible = show_ripple
	if show_ripple:
		var c := fmod(_t + _phase, 1.7) / 1.7
		var e := 1.0 - pow(1.0 - c, 2.0)
		_ripple.scale = Vector3.ONE * lerpf(0.75, 1.55, e)
		_rm.albedo_color = Color(1.0, 0.97, 0.86, (1.0 - c) * 0.9 * close * (1.0 - 0.7 * _over_cat))
	_dot.visible = pulse
	if pulse:
		_dot.scale = Vector3.ONE * (1.0 + 0.1 * sin(_t * 5.0))
		_dm.albedo_color = Color(1, 1, 1, a)


## True while the badge would sit on the cat on the screen (the cat comes first: the badge fades).
func _covers_cat(cam: Camera3D, cp: Vector3) -> bool:
	if cam == null or _pin == null or cp.x > 1e5:
		return false
	var p := badge_pos()
	if Vector2(p.x - cp.x, p.z - cp.z).length() > 6.0 or cam.is_position_behind(p) or cam.is_position_behind(cp):
		return false
	var bp := cam.unproject_position(p)
	var hw := half_px(cam)
	var hh := hw * 1.25
	var feet := cam.unproject_position(cp)
	var head := cam.unproject_position(cp + Vector3(0, 0.75, 0))
	var cw := absf(cam.unproject_position(cp + cam.global_transform.basis.x * 0.3).x - feet.x)
	return absf(bp.x - feet.x) < hw + cw and bp.y + hh > head.y and bp.y - hh < feet.y


## How high over the thing the badge floats: just over its top, from its meshes (1.15-3.1 m).
func _auto_lift(o) -> float:
	if o == null:
		return 2.4
	var top := -1.0
	var stack: Array = [o]
	while not stack.is_empty():
		var n = stack.pop_back()
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null and (n as MeshInstance3D).visible:
			var ab: AABB = (n as MeshInstance3D).global_transform * (n as MeshInstance3D).get_aabb()
			top = maxf(top, ab.end.y - o.global_position.y)
		for c in n.get_children():
			stack.append(c)
	return clampf(top + 0.55, 1.15, 3.1) if top > 0.0 else 1.6


## The rim glow on the thing while it is in reach (an additive overlay on its own meshes, so only it lights up).
func _set_rim(on: bool) -> void:
	if not on:
		for mi in _rim_on:
			if is_instance_valid(mi) and (mi as MeshInstance3D).material_overlay == _rim:
				(mi as MeshInstance3D).material_overlay = null
		_rim_on.clear()
		return
	var o := thing()
	if not _rim_on.is_empty() or o == null:
		return
	if _rim == null:
		_rim = ShaderMaterial.new()
		_rim.shader = RIM_SHADER
		_rim.set_shader_parameter("color", color.lerp(Color(1, 1, 1), 0.25))
	var stack: Array = [o]
	while not stack.is_empty():
		var n = stack.pop_back()
		if n is MeshInstance3D and (n as MeshInstance3D).material_overlay == null:
			(n as MeshInstance3D).material_overlay = _rim
			_rim_on.append(n)
		for c in n.get_children():
			stack.append(c)


func _exit_tree() -> void:
	_set_rim(false)


func _quad(size: Vector2, at: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	mi.material_override = m
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_pin.add_child(mi)
	return mi


func _mat(tex: Texture2D, prio: int, add: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	m.disable_receive_shadows = true
	m.set("disable_fog", true)
	m.render_priority = prio
	if add:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return m


# ---------------------------------------------------------------- the badges, drawn from SVG once
const INK := "#5B3417"
const PIN := "M60 144 C50 126 12 104 12 60 A48 48 0 1 1 108 60 C108 104 70 126 60 144 Z"
const ART := {
	"bag": """<path d="M48 50 v-5 a12 12 0 0 1 24 0 v5" fill="none" stroke="#5B3417" stroke-width="4.5" stroke-linecap="round"/>
<path d="M37 50 h46 l-5 34 h-36 z" fill="#D08A3E" stroke="#5B3417" stroke-width="4.5" stroke-linejoin="round"/>
<path d="M60 79 c-10 -4 -10 -17 0 -22 c10 5 10 18 0 22 z" fill="#7CC447" stroke="#3E6B1F" stroke-width="2.5" stroke-linejoin="round"/>""",
	"target": """<circle cx="58" cy="60" r="25" fill="#FFF7E3" stroke="#5B3417" stroke-width="4.5"/>
<circle cx="58" cy="60" r="17" fill="#D9483B"/><circle cx="58" cy="60" r="10" fill="#FFF7E3"/><circle cx="58" cy="60" r="4.5" fill="#D9483B"/>
<path d="M85 33 L60 58" stroke="#5B3417" stroke-width="4.5" stroke-linecap="round"/>
<path d="M85 33 l-1 9 M85 33 l-9 1" stroke="#5B3417" stroke-width="4" stroke-linecap="round"/>""",
	"bow": """<path d="M47 33 Q86 58 47 83" fill="none" stroke="#5B3417" stroke-width="10" stroke-linecap="round"/>
<path d="M47 33 Q86 58 47 83" fill="none" stroke="#C9813A" stroke-width="5" stroke-linecap="round"/>
<path d="M47 33 L47 83" stroke="#5B3417" stroke-width="2.5"/>
<path d="M36 58 H84" stroke="#5B3417" stroke-width="4.5" stroke-linecap="round"/>
<path d="M88 58 l-11 -7 v14 z" fill="#5B3417"/><path d="M36 58 l-4 -6 M36 58 l-4 6 M42 58 l-4 -6 M42 58 l-4 6" stroke="#D9483B" stroke-width="3" stroke-linecap="round"/>""",
	"bucket": """<path d="M41 50 Q60 24 79 50" fill="none" stroke="#5B3417" stroke-width="4" stroke-linecap="round"/>
<path d="M40 50 h40 l-6 33 h-28 z" fill="#B87434" stroke="#5B3417" stroke-width="4.5" stroke-linejoin="round"/>
<path d="M42 61 h36 M44 73 h32" stroke="#5B3417" stroke-width="3"/>
<ellipse cx="60" cy="50" rx="18" ry="4.5" fill="#5BB6EE" stroke="#5B3417" stroke-width="2.5"/>
<path d="M84 30 l2 5 l5 2 l-5 2 l-2 5 l-2 -5 l-5 -2 l5 -2 z" fill="#F2B640"/>""",
	"mushroom": """<path d="M46 62 h28 v22 h-28 z" fill="#FFF0D0" stroke="#5B3417" stroke-width="4.5" stroke-linejoin="round"/>
<path d="M55 84 v-9 a5 5 0 0 1 10 0 v9 z" fill="#A8692E" stroke="#5B3417" stroke-width="2.5"/>
<path d="M33 63 Q35 33 60 31 Q85 33 87 63 Z" fill="#D9483B" stroke="#5B3417" stroke-width="4.5" stroke-linejoin="round"/>
<circle cx="49" cy="47" r="4.5" fill="#FFF7E3"/><circle cx="66" cy="41" r="4" fill="#FFF7E3"/><circle cx="75" cy="54" r="3.5" fill="#FFF7E3"/><circle cx="58" cy="56" r="3" fill="#FFF7E3"/>""",
	"awning": """<path d="M41 52 V84 M79 52 V84" stroke="#5B3417" stroke-width="4.5" stroke-linecap="round"/>
<rect x="36" y="69" width="48" height="11" rx="2.5" fill="#B87434" stroke="#5B3417" stroke-width="4"/>
<path d="M54 69 l5 -11 l5 11 z" fill="#F08A2E" stroke="#5B3417" stroke-width="2"/>
<path d="M33 48 L40 32 H80 L87 48 Z" fill="#FFF7E3"/>
<path d="M48 32 L56 32 L54.6 48 L43.8 48 Z M64 32 L72 32 L76.2 48 L65.4 48 Z" fill="#5DA83A"/>
<path d="M33 48 a5.4 5.4 0 0 0 10.8 0 Z M54.6 48 a5.4 5.4 0 0 0 10.8 0 Z M76.2 48 a5.4 5.4 0 0 0 10.8 0 Z" fill="#FFF7E3" stroke="#5B3417" stroke-width="2.5"/>
<path d="M43.8 48 a5.4 5.4 0 0 0 10.8 0 Z M65.4 48 a5.4 5.4 0 0 0 10.8 0 Z" fill="#5DA83A" stroke="#5B3417" stroke-width="2.5"/>
<path d="M33 48 L40 32 H80 L87 48 Z" fill="none" stroke="#5B3417" stroke-width="4.5" stroke-linejoin="round"/>""",
	"flag": """<path d="M45 86 V30" stroke="#5B3417" stroke-width="6" stroke-linecap="round"/>
<path d="M48 31 H84 L75 42 L84 53 H48 Z" fill="#FF8A5B" stroke="#5B3417" stroke-width="4" stroke-linejoin="round"/>
<path d="M55 37 l3 6 l6 1 l-5 4 l1 6 l-5 -3 l-5 3 l1 -6 l-4 -4 l6 -1 z" fill="#FFF7E3" transform="translate(4 -2) scale(0.9)"/>
<path d="M36 86 H56" stroke="#5B3417" stroke-width="5" stroke-linecap="round"/>""",
	"stone": """<path d="M43 85 L45 43 Q60 27 75 43 L77 85 Z" fill="#A3ACB2" stroke="#4A4F55" stroke-width="4.5" stroke-linejoin="round"/>
<path d="M60 76 c-9 -4 -9 -17 0 -24 c9 7 9 20 0 24 z M60 76 V56" fill="none" stroke="#47D18E" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M45 50 q7 -6 13 -1 M62 36 q6 -2 9 3" stroke="#5DA83A" stroke-width="4.5" fill="none" stroke-linecap="round"/>""",
	"sprout": """<path d="M34 84 Q60 64 86 84 Z" fill="#8A5A2B" stroke="#5B3417" stroke-width="4" stroke-linejoin="round"/>
<path d="M60 77 V50" stroke="#3E6B1F" stroke-width="4.5" stroke-linecap="round"/>
<path d="M60 56 C47 56 38 46 38 34 C51 34 60 43 60 56 Z" fill="#7CC447" stroke="#3E6B1F" stroke-width="3.5" stroke-linejoin="round"/>
<path d="M60 52 C71 52 82 44 82 31 C69 31 60 39 60 52 Z" fill="#8FD656" stroke="#3E6B1F" stroke-width="3.5" stroke-linejoin="round"/>""",
	"pot": """<path d="M49 46 q-4 -5 0 -9 q4 -4 0 -9 M61 46 q-4 -5 0 -9 q4 -4 0 -9 M73 46 q-4 -5 0 -9" fill="none" stroke="#A9B2B8" stroke-width="3.5" stroke-linecap="round"/>
<path d="M38 55 h44 v6 q0 23 -22 23 q-22 0 -22 -23 z" fill="#555B63" stroke="#2E2A26" stroke-width="4.5" stroke-linejoin="round"/>
<rect x="33" y="51" width="54" height="8" rx="4" fill="#7A8189" stroke="#2E2A26" stroke-width="3.5"/>
<path d="M44 66 q4 8 12 10" stroke="#8A929A" stroke-width="3" fill="none" stroke-linecap="round"/>""",
	"fish": """<path d="M33 58 Q50 39 72 52 L87 41 L84 58 L87 75 L72 64 Q50 77 33 58 Z" fill="#5BB6EE" stroke="#24557A" stroke-width="4.5" stroke-linejoin="round"/>
<path d="M52 50 q-4 8 0 16" stroke="#24557A" stroke-width="3" fill="none" stroke-linecap="round"/>
<circle cx="43" cy="55" r="3.2" fill="#24557A"/>""",
	"flame": """<path d="M60 86 C42 86 35 72 41 60 C45 52 50 49 50 39 C58 45 60 51 60 56 C64 49 68 42 66 31 C78 41 85 55 81 68 C78 80 70 86 60 86 Z" fill="#FF8A3B" stroke="#8A3A12" stroke-width="4.5" stroke-linejoin="round"/>
<path d="M60 83 C52 83 48 76 52 68 C56 62 60 62 60 56 C66 62 70 70 68 76 C66 81 64 83 60 83 Z" fill="#FFD54A"/>""",
	"hollow": """<path d="M31 85 Q33 43 60 39 Q87 43 89 85 Z" fill="#8A5A2B" stroke="#5B3417" stroke-width="4.5" stroke-linejoin="round"/>
<path d="M45 85 V65 a15 15 0 0 1 30 0 V85 Z" fill="#2A1A2E" stroke="#5B3417" stroke-width="3"/>
<circle cx="54" cy="69" r="3" fill="#C9A6FF"/><circle cx="66" cy="69" r="3" fill="#C9A6FF"/>
<path d="M36 55 q9 -7 17 -1 M69 46 q8 -3 13 4" stroke="#5DA83A" stroke-width="4" fill="none" stroke-linecap="round"/>""",
	"home": """<path d="M39 60 L60 41 L81 60 V84 H39 Z" fill="#F7D27A" stroke="#5B3417" stroke-width="4.5" stroke-linejoin="round"/>
<path d="M33 62 L60 37 L87 62" fill="none" stroke="#A8692E" stroke-width="7" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M33 62 L60 37 L87 62" fill="none" stroke="#5B3417" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/>
<rect x="54" y="66" width="12" height="18" rx="5" fill="#5B3417"/>""",
	"chest": """<rect x="35" y="52" width="50" height="31" rx="3" fill="#B87434" stroke="#5B3417" stroke-width="4.5"/>
<path d="M35 55 V47 Q60 30 85 47 V55 Z" fill="#D08A3E" stroke="#5B3417" stroke-width="4.5" stroke-linejoin="round"/>
<path d="M35 57 H85" stroke="#5B3417" stroke-width="3.5"/>
<rect x="54" y="52" width="12" height="14" rx="2.5" fill="#F2B640" stroke="#5B3417" stroke-width="3"/>""",
	"shrine": """<path d="M60 87 C40 77 35 53 45 33 C62 37 81 52 75 72 C71 81 65 85 60 87 Z" fill="#9BE36B" stroke="#3E6B1F" stroke-width="4.5" stroke-linejoin="round"/>
<path d="M60 86 Q58 60 47 38" stroke="#3E6B1F" stroke-width="3" fill="none" stroke-linecap="round"/>
<path d="M82 32 l2.5 6.5 l6.5 2.5 l-6.5 2.5 l-2.5 6.5 l-2.5 -6.5 l-6.5 -2.5 l6.5 -2.5 z" fill="#FFE27A"/>""",
	"lift": """<rect x="35" y="74" width="50" height="9" rx="3" fill="#B87434" stroke="#5B3417" stroke-width="4"/>
<path d="M60 31 L79 52 H67 V70 H53 V52 H41 Z" fill="#F2B640" stroke="#5B3417" stroke-width="4.5" stroke-linejoin="round"/>""",
	"crystal": """<path d="M47 85 L39 61 L46 52 L55 67 Z M73 85 L81 61 L74 52 L65 67 Z" fill="#8F63E8" stroke="#3E2378" stroke-width="3.5" stroke-linejoin="round"/>
<path d="M60 29 L71 46 L67 85 H53 L49 46 Z" fill="#B48CFF" stroke="#3E2378" stroke-width="4" stroke-linejoin="round"/>
<path d="M60 34 L65 46 L62 70" stroke="#EDE2FF" stroke-width="3" fill="none" stroke-linecap="round"/>""",
	"barricade": """<path d="M45 86 L55 33 M75 86 L65 33" stroke="#5B3417" stroke-width="8" stroke-linecap="round"/>
<path d="M45 86 L55 33 M75 86 L65 33" stroke="#C9813A" stroke-width="3.5" stroke-linecap="round"/>
<rect x="31" y="68" width="58" height="13" rx="6.5" fill="#B87434" stroke="#5B3417" stroke-width="3.5"/>
<rect x="33" y="55" width="54" height="13" rx="6.5" fill="#D08A3E" stroke="#5B3417" stroke-width="3.5"/>
<rect x="35" y="42" width="50" height="13" rx="6.5" fill="#B87434" stroke="#5B3417" stroke-width="3.5"/>
<circle cx="37.5" cy="74.5" r="3" fill="#F2C98A"/><circle cx="39.5" cy="61.5" r="3" fill="#F2C98A"/><circle cx="41.5" cy="48.5" r="3" fill="#F2C98A"/>
<path d="M70 42 q5 -8 12 -6" stroke="#5DA83A" stroke-width="4" fill="none" stroke-linecap="round"/>""",
	"repair": """<path d="M47 86 L69 50" stroke="#5B3417" stroke-width="11" stroke-linecap="round"/>
<path d="M47 86 L69 50" stroke="#C9813A" stroke-width="5" stroke-linecap="round"/>
<path d="M56.4 45.9 L80.5 60.1 L87.6 48.1 L63.5 33.9 Z" fill="#8A929A" stroke="#2E2A26" stroke-width="4" stroke-linejoin="round"/>
<path d="M62 40 L80 51" stroke="#C3CAD0" stroke-width="2.5" stroke-linecap="round"/>
<path d="M38 34 l2.5 6 l6 2.5 l-6 2.5 l-2.5 6 l-2.5 -6 l-6 -2.5 l6 -2.5 z" fill="#F2B640"/>""",
	"dot": """<circle cx="60" cy="58" r="10" fill="#5B3417"/>"""}


## The texture of a badge (an icon in a leaf-topped pin with a rim of `col`), or of "halo", "ripple" or "dot".
static func _texture(what: String, col := Color(1, 1, 1)) -> Texture2D:
	var k := what if what in ["halo", "ripple", "dot"] else "%s|%s" % [what, col.to_html(false)]
	if _tex.has(k):
		return _tex[k]
	var svg := ""
	var sc := 1.0
	match what:
		"halo":
			svg = """<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 96 96"><defs><radialGradient id="g">
<stop offset="0" stop-color="#fff" stop-opacity="1"/><stop offset="0.45" stop-color="#fff" stop-opacity="0.45"/><stop offset="1" stop-color="#fff" stop-opacity="0"/>
</radialGradient></defs><circle cx="48" cy="48" r="48" fill="url(#g)"/></svg>"""
		"ripple":
			svg = """<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
<circle cx="64" cy="64" r="56" fill="none" stroke="#fff" stroke-opacity="0.35" stroke-width="12"/>
<circle cx="64" cy="64" r="56" fill="none" stroke="#fff" stroke-width="5"/></svg>"""
		"dot":
			svg = """<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
<circle cx="32" cy="32" r="27" fill="#F4603E" stroke="#FFF7E3" stroke-width="5"/>
<path d="M32 15 V36" stroke="#FFFFFF" stroke-width="8" stroke-linecap="round"/><circle cx="32" cy="47" r="4.8" fill="#FFFFFF"/></svg>"""
		_:
			var rim := col.lerp(Color(0.35, 0.2, 0.08), 0.12)
			svg = """<svg xmlns="http://www.w3.org/2000/svg" width="144" height="180" viewBox="0 0 120 150">
<path d="%s" transform="translate(3 5)" fill="#000000" fill-opacity="0.3"/>
<path d="%s" fill="#%s" stroke="%s" stroke-width="4" stroke-linejoin="round"/>
<path d="M88 22 C92 9 106 4 115 7 C112 20 99 27 88 22 Z" fill="#7CC447" stroke="#3E6B1F" stroke-width="3" stroke-linejoin="round"/>
<path d="M88 22 Q98 15 109 10" stroke="#3E6B1F" stroke-width="2" fill="none" stroke-linecap="round"/>
<circle cx="60" cy="58" r="39" fill="#FFF7E3" stroke="%s" stroke-opacity="0.45" stroke-width="2.5"/>
%s
<path d="M27 46 A35 35 0 0 1 47 24" stroke="#FFFFFF" stroke-opacity="0.75" stroke-width="4" fill="none" stroke-linecap="round"/>
</svg>""" % [PIN, PIN, rim.to_html(false), INK, INK, String(ART.get(what, ART["dot"]))]
	var img := Image.new()
	var err := img.load_svg_from_string(svg, sc)
	if err != OK or img.is_empty():
		img = Image.create(8, 8, false, Image.FORMAT_RGBA8)
		img.fill(col)
	img.convert(Image.FORMAT_RGBA8)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_tex[k] = tex
	return tex
