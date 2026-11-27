extends Node3D
## The map, built in code: light, ground, the camp (the shed and the campfire; the warm firelight round the campfire is
## the safe area), the meadow, the trails from each woods patch to the edge of the firelight, the woods ring with the
## Gloom over it (a step less for every mission won: gloom_level), decorations, grass, and the simple collision the cat
## and the enemies use.
## There is no ready-made fence (fences are gone); the player places road barricades, towers and spikes (defences.gd).
##
## Layout (seen from the game camera, which looks north = -Z): the campfire is at the origin. Around it is the meadow,
## out to WOODS_R. The four woods patches are sectors of the woods in the north half.

const GrassScript := preload("res://scripts/grass.gd")
const BushScript := preload("res://scripts/bush.gd")
const LakeScript := preload("res://scripts/lake.gd")
const LAKE_C := Vector3(-7.8, 0, 5.0)       # the lake beside the camp, south-west (2.6 m further out since 19 Nov 2026)
const OLD_LAKE_C := Vector3(-6.3, 0, 2.7)   # where it was: only the woods' and the hide spots' seeded sequences read it
const LAKE_R := 2.5
const RAYS := preload("res://shaders/sunray.gdshader")
const GROUND := preload("res://shaders/ground.gdshader")
const GROUND_LITE := preload("res://shaders/ground_lite.gdshader")   # Low graphics: no cobbles, pebbles or clouds
const MIST := preload("res://shaders/mist.gdshader")

const WOODS_R := 21.0                       # where the woods start
const MOVE_R := 20.3                        # the cat stays inside this
const PATCH_HALF := 0.36                    # half the angle of a patch sector (radians)
const MAP := 64.0                           # the path map covers this many metres square, centred on the camp
const MASK_PX := 384                        # ... in this many pixels (6 per metre)
const TRAIL_HALF := 0.95                    # half the width of a woods trail
const CAMP_PATH_HALF := 0.55                # half the width of the little paths round the camp
const SCATTER_CELL := 10.0                   # scatter MultiMeshes are cut into cells this big, so they can be culled
const NO_SHADOW := ["flower_hibiscus", "flower_small_white", "flower_purple", "stepping_stone", "mushroom_cluster", "rock_1"]

var main
var camp_r := 4.0                           # radius of the firelight: the safe camp
var gloom: Array[float] = [1.0, 1.0, 1.0, 1.0]           # Gloom left on each patch
var trails: Array = []                      # per patch: PackedVector3Array from the woods to the gate
var circles: Array = []                     # [Vector2 centre, radius, tag]   solid for both
var segments: Array = []                    # [Vector2 a, Vector2 b, radius, enemy_only, tag]
var grass: Node3D
var _ground_mat: ShaderMaterial
var sun: DirectionalLight3D
var fill_light: DirectionalLight3D           # the cool fill light (the Burrows' night turns it down)
var env: Environment
var _camp_root: Node3D                      # signpost and decorations: rebuilt when the camp grows
var _trail_root: Node3D
var _mist: Array = []                       # per patch: [mist material, eyes node]
var _scatter: Array = []                    # woods cells: [kind, MultiMeshInstance3D, patch of each instance
                                            # (PackedInt32Array, -1 = none), coral flags (PackedByteArray, 1 = pink)]
var rng := RandomNumberGenerator.new()
var path_img: Image                         # how much road there is at each spot (0..1), drawn by the ground shader
var path_img_base: Image                    # the same without the Burrows' paths (the hide spots' seeded sequence uses it)
var path_tex: ImageTexture
var hide_spots: Array = []                  # [Vector3 centre, radius, "grass" or "bush", node]: the cat can hide here
var _decor_root: Node3D
var _path_key := ""
var lake: Node3D
var fire_out := false                       # Last Stand: no firelight, the camp is not safe
var sign_node: Node3D                       # the signpost; once every mission is won, the Watch (Phase D)


func build(m) -> void:
	main = m
	rng.seed = 2611
	camp_r = Data.light_radius()
	for i in 4:
		gloom[i] = gloom_level()
	_environment()
	_ground()
	lake = Node3D.new()
	lake.set_script(LakeScript)
	add_child(lake)
	lake.setup(self, LAKE_C, LAKE_R)
	_woods()
	_camp_root = Node3D.new()
	add_child(_camp_root)
	_trail_root = Node3D.new()
	add_child(_trail_root)
	rebuild_camp()
	grass = Node3D.new()
	grass.set_script(GrassScript)
	add_child(grass)
	grass.build(self)
	_apply_gloom()
	apply_quality()
	Quality.changed.connect(apply_quality)


## The graphics level (Quality) is set or changed: sun shadows, glow, the ground shader, lamps, sunrays, the blob
## shadows under characters (only without sun shadows), and how much grass.
func apply_quality() -> void:
	sun.shadow_enabled = Quality.shadows()
	env.glow_enabled = Quality.glow()
	var want: Shader = GROUND_LITE if Quality.lite_ground() else GROUND
	if _ground_mat.shader != want:
		var keep := {}
		for u in _ground_mat.shader.get_shader_uniform_list():
			keep[u["name"]] = _ground_mat.get_shader_parameter(u["name"])
		_ground_mat.shader = want
		for k in keep:
			if keep[k] != null:
				_ground_mat.set_shader_parameter(k, keep[k])
	for n in get_tree().get_nodes_in_group("lamp"):
		n.visible = Quality.lamps()
	for n in get_tree().get_nodes_in_group("sunray"):
		n.visible = Quality.sunrays()
	for n in get_tree().get_nodes_in_group("blob"):
		n.visible = not Quality.shadows()
	if grass != null and not is_equal_approx(grass.share, Quality.grass_share()):
		grass.build(self)


# ---------------------------------------------------------------- light and sky
func _environment() -> void:
	# a bright fantasy afternoon: warm sun, sky-coloured ambient, a cool fill from the other side, soft haze and glow
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.36, 0.62, 0.92)
	sky_mat.sky_horizon_color = Color(0.78, 0.88, 0.86)
	sky_mat.ground_horizon_color = Color(0.55, 0.7, 0.45)
	sky_mat.ground_bottom_color = Color(0.25, 0.38, 0.2)
	sky_mat.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.85
	env.ambient_light_color = Color(0.85, 0.9, 1.0)
	env.ambient_light_energy = 0.62
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.98
	env.tonemap_white = 5.0
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_strength = 1.0
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 0.95
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.fog_enabled = true
	env.fog_light_color = Color(0.82, 0.88, 0.78)
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.25
	env.fog_density = 0.0025
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.22
	env.adjustment_contrast = 1.1
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -38.0, 0.0)
	sun.light_energy = 1.7
	sun.light_color = Color(1.0, 0.93, 0.80)
	sun.shadow_enabled = true
	sun.shadow_blur = 1.2
	sun.shadow_opacity = 0.85
	# one shadow map over what the camera sees (21.5 m away, 50 degrees down: the ground in view is 17-34 m off). The
	# default four splits spent two passes on the empty air in front of the lens and drew every caster up to four times.
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 36.0
	add_child(sun)
	fill_light = DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(-35.0, 150.0, 0.0)
	fill_light.light_energy = 0.35
	fill_light.light_color = Color(0.62, 0.75, 1.0)
	fill_light.shadow_enabled = false
	add_child(fill_light)


func _ground() -> void:
	var g := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(90, 90)
	g.mesh = plane
	_ground_mat = ShaderMaterial.new()
	_ground_mat.shader = GROUND_LITE if Quality.lite_ground() else GROUND
	var angles := Vector4.ZERO
	for i in 4:
		angles[i] = deg_to_rad(float(Data.patch(i)["angle_deg"]))
	_ground_mat.set_shader_parameter("patch_angle", angles)
	_ground_mat.set_shader_parameter("patch_half", PATCH_HALF)
	_ground_mat.set_shader_parameter("woods_radius", WOODS_R)
	g.material_override = _ground_mat
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(g)


# ---------------------------------------------------------------- directions
func patch_dir(i: int) -> Vector3:
	var a := deg_to_rad(float(Data.patch(i)["angle_deg"]))
	return Vector3(sin(a), 0.0, -cos(a))


func patch_of(p: Vector3) -> int:
	var a := atan2(p.x, -p.z)
	for i in 4:
		if absf(wrapf(a - deg_to_rad(float(Data.patch(i)["angle_deg"])), -PI, PI)) < PATCH_HALF:
			return i
	return -1


## The firelight round the campfire is the camp: the cat cannot be hurt in it and no enemy can step into it.
func inside_camp(p: Vector3) -> bool:
	if fire_out or (main != null and main.fight != null and main.fight.active and main.fight.in_wave):
		return false                            # during a wave the enemies come right into the camp (between waves
		                                        # it is safe again, and the cat heals there)
	return Vector2(p.x, p.z).length() < camp_r - 0.1


## Each road pad is [position, rotation, lane, index]. The gate (2) is near the firelight, and the far pad (0) is
## near the woods' edge. The middle pad (1) is on the outer bend or halfway along the road between the other two.
## Pads follow the roads when the firelight grows and face across the road at each position.
func barricade_slots() -> Array:
	var out: Array = []
	var rule: Dictionary = Data.defence_info("barricade")["pad_rule"]
	for i in trails.size():
		var ss := barricade_s(i, rule)
		for k in 3:
			var s: float = ss[k]
			var p := trail_point(i, s)
			var t := trail_point(i, s + 0.4) - trail_point(i, s - 0.4)
			t.y = 0.0
			t = t.normalized()
			out.append([Vector3(p.x, 0, p.z), atan2(-t.x, -t.z), i, k])
	return out


## The arc lengths [far, middle, near] of the 3 pads on trail i (see barricade_slots).
func barricade_s(i: int, rule: Dictionary) -> Array:
	var L := trail_length(i)
	var gate := L - float(rule["near_from_end_m"])
	var road := Data.patch(i)
	var far_pad: Dictionary = road.get("far_pad", {})
	var want := WOODS_R - float(far_pad.get("in_from_woods_m", rule["far_in_from_woods_m"]))
	var far_s := 0.0
	var far_d := INF
	var s := 0.0
	while s <= L:
		var q := trail_point(i, s)
		var dd := absf(Vector2(q.x, q.z).length() - want)
		if dd < far_d:
			far_d = dd
			far_s = s
		s += 0.05
	if road.get("even_barricade_spacing", false):
		return [far_s, (far_s + gate) * 0.5, gate]

	var win: Array = rule["bend_window"]
	var probe := float(rule["bend_probe_m"])
	var best_s := L * float(win[0])
	var best_a := -1.0
	s = best_s
	while s <= L * float(win[1]) + 0.0001:
		var d1 := trail_point(i, s) - trail_point(i, s - probe)
		var d2 := trail_point(i, s + probe) - trail_point(i, s)
		d1.y = 0.0
		d2.y = 0.0
		var a := absf(d1.angle_to(d2))
		if a > best_a:
			best_a = a
			best_s = s
		s += 0.05 * L
	var mid := minf(best_s, gate - float(rule["mid_min_gap_from_gate_m"]))
	return [far_s, mid, gate]


func barricade_slot(lane: int, index: int) -> Array:
	for s in barricade_slots():
		if int(s[2]) == lane and int(s[3]) == index:
			return s
	return []


## The campfire went out (or is lit again): the firelight on the ground fades, and the camp stops keeping enemies out.
func set_fire_out(on: bool) -> void:
	fire_out = on
	var tw := create_tween()
	tw.tween_method(func(v): _ground_mat.set_shader_parameter("camp_radius", v),
		camp_r if on else 0.6, 0.6 if on else camp_r, 1.2 if on else 0.8)


## Where an enemy coming from patch i reaches the edge of the firelight.
func edge_point(i: int) -> Vector3:
	return patch_dir(i) * (camp_r + 0.45)


func spawn_point(i: int, jitter: float) -> Vector3:
	var a := deg_to_rad(float(Data.patch(i)["angle_deg"])) + jitter
	return Vector3(sin(a), 0.0, -cos(a)) * (WOODS_R + 1.5)


## Where things stand in the camp. The campfire is the centre; the home (the shed, later the hut and the treehouse)
## stands next to it; the buildings go round them. H6 (Stage 1): each building's spot, ring, ground, path and footprint
## now live in its content entry (content/buildings/<id>/entry.json, "layout"; Data.building_layout), read through _geo.
func station_pos(id: String) -> Vector3:
	match id:
		"campfire": return Vector3.ZERO
		"sign": return Vector3(0.0, 0, -camp_r + 0.75)
		"pot": return Vector3(0.7071, 0, -0.7071) * float(POT_R[clampi(Save.camp_level, 1, POT_R.size()) - 1])   # the fire's north-east rim
	var g: Dictionary = _geo(id)
	if bool(g["has"]):
		return g["pos"]
	return HOME_SPOT if id == "home" else Vector3.ZERO     # the home stands in one spot at every level (HOME_SPOT)


## One building's layout as plain numbers, read once from its entry (Data.building_layout) and kept: the lists below are
## read in the hide spots' and decorations' loops, so they must not be rebuilt on every call. Keys: has (the entry has
## a layout), pos, ring (the ring's offset from pos, a zero vector when none), village_r / village_ring_r (-1 when the
## building keeps no village ground), reserved_c / reserved_r (r -1 when none), path (points, empty when none), smooth,
## half_mult, peak (-1 when none).
var _geo_cache := {}


func _geo(id: String) -> Dictionary:
	if _geo_cache.has(id):
		return _geo_cache[id]
	var lay: Dictionary = Data.building_layout(id)
	var g := {"has": not lay.is_empty(), "pos": Vector3.ZERO, "ring": Vector3.ZERO,
		"village_r": -1.0, "village_ring_r": -1.0, "reserved_c": Vector3.ZERO, "reserved_r": -1.0,
		"path": PackedVector3Array(), "smooth": 6, "half_mult": 0.85, "peak": -1.0, "trunk_of": "", "fork_at": Vector3.ZERO}
	if not lay.is_empty():
		g["pos"] = _v3(lay.get("position", [0, 0, 0]))
		if lay.has("ring_offset"):
			g["ring"] = _v3(lay["ring_offset"])
		if lay.has("village"):
			var vl: Dictionary = lay["village"]
			g["village_r"] = float(vl.get("r", 1.3))
			g["village_ring_r"] = float(vl.get("ring_r", 0.9))
		if lay.has("reserved"):
			var rs: Dictionary = lay["reserved"]
			var o: Array = rs.get("offset", [0, 0, 0])
			var pp: Array = lay.get("position", [0, 0, 0])
			g["reserved_c"] = Vector3(float(pp[0]) + float(o[0]), float(pp[1]) + float(o[1]), float(pp[2]) + float(o[2]))   # summed in float64, as H5's literals
			g["reserved_r"] = float(rs.get("r", 0.0))
		if lay.has("path"):
			var pl: Dictionary = lay["path"]
			var pts := PackedVector3Array()
			for q in pl.get("points", []):
				pts.append(_v3(q))
			g["path"] = pts
			g["trunk_of"] = String(pl.get("trunk_of", ""))      # H6: a branch path forks off another building's path (the Workshop's off the Tailor's)
			if pl.has("fork_at"):
				g["fork_at"] = _v3(pl["fork_at"])
			g["smooth"] = int(pl.get("smooth", 6))
			g["half_mult"] = float(pl.get("half_mult", 0.85))
			if pl.has("peak"):       # a number, or true for the worn-trail peak (WALK_PEAK, the well's path)
				g["peak"] = WALK_PEAK if typeof(pl["peak"]) == TYPE_BOOL and bool(pl["peak"]) else float(pl["peak"])
	_geo_cache[id] = g
	return g


func _v3(a) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


const POT_R := [0.78, 0.98, 0.98, 0.98, 1.13, 1.08, 1.08, 1.08]   # the campfire's foot by home level + 0.18
const FISH_RING := Vector3(-7.98, 0, 7.58)               # the Fishing Spot's ring, 0.8 m from the water
## Ground kept for the guardian stone, the garden and the fishing spot, built yet or not (Phase C). H6: each one's
## layout.reserved (its entry), checked in this order.
const RESERVED_IDS := ["stone", "garden", "fishing"]


func in_reserved(p: Vector3, margin: float) -> bool:
	for id in RESERVED_IDS:
		var g: Dictionary = _geo(id)
		if float(g["reserved_r"]) < 0.0:
			continue
		var c: Vector3 = g["reserved_c"]
		if Vector2(p.x - c.x, p.z - c.z).length() < float(g["reserved_r"]) + margin:
			return true
	return false


## The village buildings standing round the fire today (H5: the Wishing Well and the Market; the Mushroom Cottage has
## left the camp): grass.gd keeps its grass off each once it is built. The hide spots' map keeps the old village
## (OLD_VILLAGE, with the Cottage) for its seeded sequence only.
const VILLAGE := ["well", "stall"]
## The camp's layout (the user's call, 18 Nov 2026): the campfire is the centre, with open ground all round it, and the
## home beside it (station_pos). The other buildings stand round them, a little apart and not in a ring, each on its own
## path from the fire: the Training Target and the Bow Bench east of the fire, the Market Stall further round to the
## south-east (the north is the four trails, the west the home and the lake, the south the Burrows' path and the
## garden), and the Wishing Well on the lake's near shore. Each ring is on the camera's side of its building, so a
## building never hides the cat at its ring, nothing tall stands just south of where the cat walks, and the ground
## straight south of the fire stays open. The same at every home level. See docs/PHASE_A_PROGRESS.md, "Camp layout and
## HUD".
## G4 (21 Nov 2026): the Saddlery stands south-east, past the Market, on its own path (the Market's lane, then round the
## Saddlery's west side to its ring on the camera's side). It keeps clear of the Market's ring and path (even its
## biggest stand-in, bow_bench_3, 2.3 m tall, hides none of them), of the garden's ground, the Burrow's path and the lake.
## 23 Nov 2026: the Tailor's Nook (the cat's outfits) stands east-south-east, on its own path (the lane the Mushroom
## Cottage had, then on south-east to the Nook's ring on the camera's side, 1.95 m out; its entry's layout.path keeps
## every point of it).
## The owner's model is about 2.6 m wide and 1.77 m tall. At the cat's height (0.1 to 0.6 m), the counter corners reach
## 1.47 m from the centre. The footprint is capped at 1.35 m to leave 0.60 m to the ring.
## The spot is clear of the Saddlery and the Guardian Stone's ground, and far from the roads, barricade pads, lake and
## garden. The Stone's ring is 3.3 m north.
## H5 (27 Nov 2026): the Mushroom Cottage's spot (6.4, 0, 3.6), its ring and its path are gone: that ground is open
## meadow now (grass, decorations and defences may use it). Only the hide spots' map remembers the old village's Cottage.
## The home's one spot at every level 1-8 (the user, 18 Nov 2026: "each home should be in the same place and not too
## close to the campfire"): west of the fire, 4.6 m out, so even the level-6 tree leaves open ground round the fire
## (1.8 m between their footprints). The trails all come from the north and leave no gap a growing tree fits in, so it
## stands beside the WNW trail's mouth, never on it. The lake (with the well and the fishing spot) moved 2.6 m south-west so
## even the biggest home keeps a clear gap from the water (the user, 19 Nov 2026: "too close to the lake"). See docs/PHASE_A_PROGRESS.md, "Camp layout and HUD".
const HOME_SPOT := Vector3(-4.6, 0, 0.25)
## Where the home stood before, by home level (it stepped back as it grew): only the hide spots' map reads it.
const OLD_HOME := [Vector3.ZERO, Vector3(-2.1, 0, -0.9), Vector3(-2.6, 0, -1.1), Vector3(-3.1, 0, -1.6),
	Vector3(-3.4, 0, -1.8), Vector3(-3.7, 0, -2.0), Vector3(-4.0, 0, -2.2)]
## The buildings that can keep village ground and a path from the fire, in the order the paths are laid (H6: only the
## ids; the rest is each entry's layout, and a building takes part only where its layout says "village" / "path").
const CAMP_ORDER := ["target", "bench", "stall", "well", "saddlery", "tailor", "workshop"]
## The village as it stood before, right south of the campfire, and the bench and the target (they grew outward with the
## home). Only the hide spots' seeded sequence still reads them (with their old paths in path_img_base), so the tall
## grass and the bushes stay where they were. H5: the Cottage stays in this old map only (no marker, path, collision or
## defence ground anywhere else); its old door path shows in that map while the pet is owned (_legacy_built), as it
## did while the Cottage stood.
const OLD_VILLAGE := {"well": Vector3(0.0, 0, 3.3), "cottage": Vector3(-2.1, 0, 3.9), "stall": Vector3(2.5, 0, 4.7)}
const OLD_DOOR := {"well": 1.0, "cottage": 1.25, "stall": 1.2}   # each old building's door, that far in front of it


## A building of the old village stands, for the hide spots' map only: its station is built; H5: the old Cottage
## (gone from the camp) counts while the pet is owned, as the pet came with the Cottage before, so the hide spots stay
## where they were.
func _legacy_built(id: String) -> bool:
	if id == "cottage":
		return Data.pet_level() > 0
	return int(Save.stations.get(id, 0)) > 0


func _old_spot(id: String) -> Vector3:
	var k := 1.0 + (mini(Save.camp_level, 6) - 1) * 0.15
	return Vector3(2.3, 0, -1.0) * k if id == "bench" else Vector3(2.1, 0, 1.5) * k


## Where a building's ring is: its position plus its layout.ring_offset (the target, bench, stall, well, Saddlery,
## Tailor's Nook, stone and garden). The fishing spot's ring is FISH_RING.
func spot_ring(id: String) -> Vector3:
	if id == "fishing":
		return FISH_RING
	var g: Dictionary = _geo(id)
	return (g["pos"] as Vector3) + (g["ring"] as Vector3)


## True if p is on the ground kept for the camp's buildings round the fire (each one and its ring), built yet or not:
## the buildings whose layout has "village" (not the home, the stone, the garden or the fishing spot).
func in_village(p: Vector3, margin: float) -> bool:
	for id in CAMP_ORDER:
		var g: Dictionary = _geo(id)
		if float(g["village_r"]) < 0.0:
			continue
		if p.distance_to(g["pos"]) < float(g["village_r"]) + margin or p.distance_to(spot_ring(id)) < float(g["village_ring_r"]) + margin:
			return true
	return false


## True if p is within `margin` of one building's footprint or ring ground (the same two circles in_village uses), for
## the placement ghost and the save's returns (H6). False for a building without village ground.
func on_station_ground(id: String, p: Vector3, margin: float) -> bool:
	var g: Dictionary = _geo(id)
	if float(g["village_r"]) < 0.0:
		return false
	return p.distance_to(g["pos"]) < float(g["village_r"]) + margin or p.distance_to(spot_ring(id)) < float(g["village_ring_r"]) + margin


## The same test for the old village ground (the hide spots' loops only, see OLD_VILLAGE).
func _in_old_village(p: Vector3, margin: float) -> bool:
	for id in OLD_VILLAGE:
		var c: Vector3 = OLD_VILLAGE[id]
		if p.distance_to(c) < 1.3 + margin or p.distance_to(c + Vector3(0, 0, 1.2)) < 0.9 + margin:
			return true
	return false


const CAMP_VIEW_R := 8.0                    # the camp's buildings all stand within this of the fire


## Ground the camera treats as the camp when no fight is on (it stays pulled back): the firelight, and the ring of
## ground round it where the camp's buildings stand, which reaches past the light at the low home levels.
func camp_view(p: Vector3) -> bool:
	return inside_camp(p) or Vector2(p.x, p.z).length() < maxf(camp_r, CAMP_VIEW_R) or in_village(p, 1.2)


## True if one of the camp's buildings stands within d of p (the decorations keep clear of them).
func near_village(p: Vector3, d: float) -> bool:
	for id in CAMP_ORDER:
		var g: Dictionary = _geo(id)
		if float(g["village_r"]) < 0.0:
			continue
		if int(Save.stations.get(id, 0)) > 0 and p.distance_to(g["pos"]) < d:
			return true
	return false


# ---------------------------------------------------------------- the camp: signpost, decorations, trails
func rebuild_camp() -> void:
	camp_r = Data.light_radius()
	for c in _camp_root.get_children():
		c.queue_free()
	_ground_mat.set_shader_parameter("camp_radius", camp_r)
	var lv := Save.camp_level
	sign_node = _make_sign()
	sign_node.position = station_pos("sign")
	_camp_root.add_child(sign_node)
	remove_tag("sign")
	add_circle(sign_node.position, 0.2, "sign")
	update_watch()
	for v in [Vector3(-1.05, 0, 0.5), Vector3(1.05, 0, 0.5)]:
		var seat := Props.instance("log_seat")
		seat.position = v
		seat.rotation.y = atan2(v.x, v.z) + PI / 2.0
		_camp_root.add_child(seat)
	if lv >= 2:
		for v in [station_pos("home") + Vector3(1.7, 0, 0.9), Vector3(1.3, 0, -camp_r + 0.9)]:
			var lantern := Props.instance("lantern_post")
			lantern.position = v
			_camp_root.add_child(lantern)
			var glow := OmniLight3D.new()
			glow.light_color = Color(1.0, 0.78, 0.42)
			glow.light_energy = 0.9
			glow.omni_range = 2.6
			glow.position = Vector3(0, 1.35, 0.15)
			glow.add_to_group("lamp")
			glow.visible = Quality.lamps()
			lantern.add_child(glow)
		for v in [Vector3(-0.35, 0, 1.0), Vector3(0.8, 0, 0.62)]:
			if near_village(v * camp_r, 2.6) or in_village(v * camp_r, 1.0):
				continue
			var bed := Props.instance("flower_bed")
			bed.position = v * camp_r
			bed.rotation.y = randf() * 0.4
			_camp_root.add_child(bed)
	if lv >= 3:
		var pile := Props.instance("timber_pile")
		pile.position = station_pos("home") + Vector3(0.4, 0, 1.9)
		_camp_root.add_child(pile)
	_build_trails()
	if grass != null:
		grass.build(self)


func _build_trails() -> void:
	for c in _trail_root.get_children():
		c.queue_free()
	trails.clear()
	for i in 4:
		var d := patch_dir(i)
		var perp := Vector3(-d.z, 0, d.x) * (1.0 if i % 2 == 0 else -1.0)
		var pts := PackedVector3Array([
			d * (WOODS_R + 2.5), d * (WOODS_R - 3.0), d * 15.5 - perp * 1.1, d * 11.5 + perp * 1.6,
			d * (camp_r + 3.5) + perp * 0.4, edge_point(i)])
		trails.append(_smooth(pts, 7))
	rebuild_paths(true)
	_path_edges()
	_hideouts()


## The road map: every trail and camp path stamped into one small greyscale image. The ground shader turns it into
## dirt and cobblestones with a ragged grassy edge; the grass and the decorations keep off it.
func rebuild_paths(force := false) -> void:
	var key := "%d|%d|%d|%d|%d|%d" % [Save.camp_level, int(Save.stations.get("target", 0)), int(Save.stations.get("bench", 0)),
		int(Save.stations.get("well", 0)), int(_legacy_built("cottage")), int(Save.stations.get("stall", 0))]
	key += "|%d|%d|%d|%d|%d|%d" % [int(Save.stations.get("stone", 0)), int(Save.stations.get("garden", 0)), int(Save.stations.get("fishing", 0)),
		int(Save.stations.get("saddlery", 0)), int(Save.stations.get("tailor", 0)), int(Save.stations.get("workshop", 0))]
	if key == _path_key and not force:
		return
	_path_key = key
	var lines: Array = []
	for t in trails:
		lines.append([t, TRAIL_HALF])
	# little paths round the camp: signpost, home, and the stations once they are built
	var sign := station_pos("sign")
	lines.append([_smooth(PackedVector3Array([sign + Vector3(0, 0, 0.5), Vector3(0.35, 0, -camp_r * 0.45), Vector3(0, 0, -1.2)]), 5), CAMP_PATH_HALF])
	var old_home: Vector3 = OLD_HOME[clampi(Save.camp_level, 0, 6)] + Vector3(0.5, 0, 1.6)
	var old_home_path := _smooth(PackedVector3Array([Vector3(-1.1, 0, 0.4), (old_home + Vector3(-1.1, 0, 0.4)) * 0.5 + Vector3(0, 0, 0.35), old_home]), 5)
	# the lane from the campfire south to the garden
	var any_village := false
	for id in OLD_VILLAGE:
		if _legacy_built(String(id)):
			any_village = true
	var has_garden := int(Save.stations.get("garden", 0)) > 0
	var old_lane := _smooth(PackedVector3Array([Vector3(0.0, 0, 1.0), Vector3(0.55, 0, 2.6), Vector3(0.75, 0, 4.2), Vector3(0.3, 0, 5.4)]), 5)
	if has_garden:                              # the lane goes on to the garden
		lines.append([_smooth(PackedVector3Array([Vector3(0.3, 0, 5.4), Vector3(0.45, 0, 6.3), Vector3(0.5, 0, 7.0)]), 5), CAMP_PATH_HALF * 0.85])
		lines.append([old_lane, CAMP_PATH_HALF])
	# only in the hide spots' map: the paths as they were before the camp was laid out again (to the bench and the
	# target where they stood, the old village lane and its branches; see OLD_VILLAGE)
	var legacy: Array = [[old_home_path, CAMP_PATH_HALF]]
	if int(Save.stations.get("target", 0)) > 0:
		var tg := _old_spot("target") + Vector3(0, 0, 1.2)
		legacy.append([_smooth(PackedVector3Array([Vector3(1.0, 0, 0.7), (tg + Vector3(1.0, 0, 0.7)) * 0.5 + Vector3(0.2, 0, 0.3), tg]), 5), CAMP_PATH_HALF])
	if int(Save.stations.get("bench", 0)) > 0:
		var bn := _old_spot("bench") + Vector3(0, 0, 1.0)
		legacy.append([_smooth(PackedVector3Array([Vector3(1.1, 0, -0.3), (bn + Vector3(1.1, 0, -0.3)) * 0.5 + Vector3(0.1, 0, 0.25), bn]), 5), CAMP_PATH_HALF])
	if any_village and not has_garden:
		legacy.append([old_lane, CAMP_PATH_HALF])
	for id in OLD_VILLAGE:
		if _legacy_built(String(id)):
			var door: Vector3 = OLD_VILLAGE[id] + Vector3(0, 0, float(OLD_DOOR[id]))
			var from := Vector3(0.7, 0, clampf(door.z, 2.6, 5.2))
			legacy.append([_smooth(PackedVector3Array([from, (from + door) * 0.5 + Vector3(0, 0, 0.2), door]), 5), CAMP_PATH_HALF * 0.85])
	# the paths to the camp's buildings (each entry's layout.path), and the Phase E path to each Burrow's hollow, always there (the
	# sealed hollow is a teaser from the start): the lane's trunk south, then round the west side of the garden. Stamped
	# after the map for the hide spots is kept, so their seeded sequence stays as it was.
	var base_n := lines.size()
	var door := HOME_SPOT + Vector3(0.9, 0, 2.3)            # the counter's ring
	lines.append([_smooth(PackedVector3Array([Vector3(-1.1, 0, 0.6), Vector3(-2.4, 0, 1.65), door]), 5), CAMP_PATH_HALF])
	lines.append_array(_station_lines())
	for bd in Data.burrow_list():
		var en: Dictionary = bd["entrance"]
		var trunk := PackedVector3Array()
		for q in en.get("trunk", []):
			trunk.append(Vector3(float(q[0]), 0, float(q[2])))
		if trunk.size() >= 2:
			lines.append([_smooth(trunk, 5), CAMP_PATH_HALF])
		var hp := PackedVector3Array()
		for q in en.get("path", []):
			hp.append(Vector3(float(q[0]), 0, float(q[2])))
		if hp.size() >= 2:
			lines.append([_smooth(hp, 7), CAMP_PATH_HALF])
	var data := PackedByteArray()
	data.resize(MASK_PX * MASK_PX)
	for li in base_n:
		_stamp(data, lines[li])
	# the hide spots' map: what is stamped so far, plus the old paths (it is the max of both, as before)
	var base := data.duplicate()
	for line in legacy:
		_stamp(base, line)
	path_img_base = Image.create_from_data(MASK_PX, MASK_PX, false, Image.FORMAT_L8, base)
	for li in range(base_n, lines.size()):
		_stamp(data, lines[li])
	path_img = Image.create_from_data(MASK_PX, MASK_PX, false, Image.FORMAT_L8, data)
	if path_tex == null:
		path_tex = ImageTexture.create_from_image(path_img)
	else:
		path_tex.update(path_img)
	_ground_mat.set_shader_parameter("path_tex", path_tex)
	_ground_mat.set_shader_parameter("map_size", MAP)
	_stepping_stones()
	if not force and grass != null:
		grass.build(self)


## Stamps one line [points, half width, (peak)] into a path map: the most road wins at each pixel.
func _stamp(data: PackedByteArray, line: Array) -> void:
	var ppm := MASK_PX / MAP
	var pts: PackedVector3Array = line[0]
	var half: float = line[1]
	var peak: float = float(line[2]) if line.size() > 2 else 1.0
	var rad := int(ceil(half * ppm)) + 1
	for k in pts.size() - 1:
		var a := pts[k]
		var b := pts[k + 1]
		var steps := maxi(1, int(a.distance_to(b) / 0.3))
		for j in steps:
			var c := a.lerp(b, float(j) / steps)
			var w := half * (0.85 + 0.3 * sin(c.x * 1.3 + c.z * 0.9))      # the width wanders a little
			var cx := int((c.x / MAP + 0.5) * MASK_PX)
			var cy := int((c.z / MAP + 0.5) * MASK_PX)
			for dy in range(-rad, rad + 1):
				var y := cy + dy
				if y < 0 or y >= MASK_PX:
					continue
				for dx in range(-rad, rad + 1):
					var x := cx + dx
					if x < 0 or x >= MASK_PX:
						continue
					var dist := sqrt(float(dx * dx + dy * dy)) / ppm
					var v := int(clampf(1.0 - dist / w, 0.0, 1.0) * peak * 255.0)
					var idx := y * MASK_PX + x
					if v > data[idx]:
						data[idx] = v


## The paths from the campfire to each building's ring, as built (points from the fire out; smoothed). Each leaves the
## fire's dirt and reaches the ring from the camera's side, and passes clear of the other rings. The well's is a short
## stepping-stone path from the lane to the lake (_stepping_stones).
const WALK_PEAK := 0.55                     # the well's path: a worn trail with stepping stones, not a road


## The built buildings' paths: [points, half width, (peak)].
func _station_lines() -> Array:
	var out: Array = []
	for id in CAMP_ORDER:
		if int(Save.stations.get(id, 0)) <= 0:
			continue
		var g: Dictionary = _geo(id)
		var pts: PackedVector3Array = g["path"]
		if pts.is_empty():
			continue
		if String(g["trunk_of"]) != "":
			# H6: a branch (the Workshop's) forks off its trunk building's path. When that building stands, its whole line is
			# stamped already (it comes earlier in CAMP_ORDER); when it does not, the trunk is stamped up to the fork.
			var tg: Dictionary = _geo(String(g["trunk_of"]))
			if int(Save.stations.get(String(g["trunk_of"]), 0)) <= 0:
				var cut := _trunk_to_fork(tg, g["fork_at"])
				if cut.size() >= 2:
					out.append([cut, CAMP_PATH_HALF * float(tg["half_mult"])])
			if pts[0].distance_to(g["fork_at"]) > 0.05:
				var from_fork := PackedVector3Array([g["fork_at"]])
				from_fork.append_array(pts)
				pts = from_fork
		if float(g["peak"]) >= 0.0:
			out.append([_smooth(pts, int(g["smooth"])), CAMP_PATH_HALF * float(g["half_mult"]), float(g["peak"])])
		else:
			out.append([_smooth(pts, int(g["smooth"])), CAMP_PATH_HALF * float(g["half_mult"])])
	return out


## A trunk building's smoothed path from the fire up to the fork point (up to the point of the smoothed line nearest it).
func _trunk_to_fork(trunk_geo: Dictionary, fork: Vector3) -> PackedVector3Array:
	var pts: PackedVector3Array = trunk_geo["path"]
	if pts.size() < 2:
		return PackedVector3Array()
	var sm := _smooth(pts, int(trunk_geo["smooth"]))
	var best := 0
	var best_d := INF
	for k in sm.size():
		var d := sm[k].distance_to(fork)
		if d < best_d:
			best_d = d
			best = k
	return sm.slice(0, best + 1)


var _stones: MultiMeshInstance3D
var _stones_key := ""


## Flat stepping stones along the path to the well (rebuilt with the path map).
func _stepping_stones() -> void:
	var lines: Array = _station_lines().filter(func(l): return l.size() > 2)
	var key := str(int(Save.stations.get("well", 0)) > 0)
	if key == _stones_key:
		return
	_stones_key = key
	if _stones != null and is_instance_valid(_stones):
		_stones.queue_free()
	_stones = null
	if lines.is_empty():
		return
	var r := RandomNumberGenerator.new()
	r.seed = 733                                  # its own sequence: nothing else moves with it
	var xfs: Array = []
	for line in lines:
		var pts: PackedVector3Array = line[0]
		var acc := 0.0
		var side := 1.0
		for k in pts.size() - 1:
			var a := pts[k]
			var b := pts[k + 1]
			var l := a.distance_to(b)
			var t := (b - a) / maxf(l, 0.001)
			while acc < l:
				var at := a + t * acc + Vector3(-t.z, 0, t.x) * side * r.randf_range(0.08, 0.2)
				side = -side
				if lake_dist(at) > 0.4:
					xfs.append(Transform3D(Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(1.0, 0.6, 1.0) * r.randf_range(1.15, 1.45)), at + Vector3(0, 0.005, 0)))
				acc += r.randf_range(0.55, 0.7)
			acc -= l
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = Props.mesh("stepping_stone")
	mm.instance_count = xfs.size()
	for k in xfs.size():
		mm.set_instance_transform(k, xfs[k])
		mm.set_instance_custom_data(k, Color(0, 0, 0, 0))
	_stones = MultiMeshInstance3D.new()
	_stones.multimesh = mm
	_stones.material_override = Props.vc_multi()
	_stones.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_stones)


## How far p is from the lake's water (negative = in it). Far away when there is no lake.
func lake_dist(p: Vector3) -> float:
	return lake.dist(p) if lake != null else 99.0


## How far p is from where the lake used to be (the seeded sequences only, see OLD_LAKE_C).
func _old_lake_dist(p: Vector3) -> float:
	if lake == null:
		return 99.0
	var dx := p.x - OLD_LAKE_C.x
	var dz := p.z - OLD_LAKE_C.z
	return sqrt(dx * dx + dz * dz) - lake.shore_r(atan2(dz, dx))


## True if p is within margin of the home's ground (its biggest footprint, and its counter's ring).
func near_home(p: Vector3, margin: float) -> bool:
	return Vector2(p.x - HOME_SPOT.x, p.z - HOME_SPOT.z).length() < 1.9 + margin \
		or Vector2(p.x - HOME_SPOT.x - 0.9, p.z - HOME_SPOT.z - 2.3).length() < 0.9 + margin


## How much road there is at p: 0 = none, 1 = the middle of a trail.
func path_strength(p: Vector3) -> float:
	return _strength_in(path_img, p)


func _strength_in(img: Image, p: Vector3) -> float:
	if img == null:
		return 0.0
	var x := int((p.x / MAP + 0.5) * MASK_PX)
	var y := int((p.z / MAP + 0.5) * MASK_PX)
	if x < 0 or y < 0 or x >= MASK_PX or y >= MASK_PX:
		return 0.0
	return img.get_pixel(x, y).r


## Phase E: the wedge of woods and meadow kept clear round each Burrow's hollow, and a strip along its path. Works from
## balance.json alone (the woods are scattered before the path is stamped).
func in_hollow_clear(p: Vector3) -> bool:
	for bd in Data.burrow_list():
		var h: Dictionary = bd["entrance"]
		var c: Dictionary = h["clear"]
		var hx := float(h["pos"][0])
		if p.z > float(c["z_from"]) and p.z < float(c["z_to"]):
			if absf(p.x - hx) < float(c["half_x"]) + float(c["widen"]) * (p.z - float(c["z_from"])):
				return true
		var q := Vector2(p.x, p.z)
		var pts: Array = h["path"]
		for i in pts.size() - 1:
			var a := Vector2(float(pts[i][0]), float(pts[i][2]))
			var e := Vector2(float(pts[i + 1][0]), float(pts[i + 1][2]))
			if Geometry2D.get_closest_point_to_segment(q, a, e).distance_to(q) < float(c["path_clear"]):
				return true
	return false


## Near a Burrow's hollow (within r of its centre, or of its ring with ring_r).
func near_hollow(p: Vector3, r: float, ring_r := -1.0) -> bool:
	for bd in Data.burrow_list():
		var h: Dictionary = bd["entrance"]
		if Vector2(p.x - float(h["pos"][0]), p.z - float(h["pos"][2])).length() < r:
			return true
		if ring_r > 0.0 and Vector2(p.x - float(h["ring"][0]), p.z - float(h["ring"][2])).length() < ring_r:
			return true
	return false


## Life along the trails: pebbles, rocks, ferns, flowers, mushrooms and the odd log, and a lantern on each trail.
func _path_edges() -> void:
	var kinds := {"stepping_stone": [], "rock_1": [], "fern": [], "flower_small_white": [], "flower_hibiscus": [],
		"flower_purple": [], "mushroom_cluster": [], "log_fallen": []}
	var r2 := RandomNumberGenerator.new()
	r2.seed = 4242
	for i in trails.size():
		var pts: PackedVector3Array = trails[i]
		var L := trail_length(i)
		var s_at := 1.5
		while s_at < L - 1.0:
			var p := trail_point(i, s_at)
			var ahead := trail_point(i, s_at + 0.4)
			var t := (ahead - p).normalized()
			var side := Vector3(-t.z, 0, t.x) * (1.0 if r2.randf() < 0.5 else -1.0)
			var at := p + side * (TRAIL_HALF + r2.randf_range(0.05, 0.6))
			if Vector2(at.x, at.z).length() > camp_r + 0.5:
				var pick := r2.randf()
				var kind := "stepping_stone" if pick < 0.3 else ("rock_1" if pick < 0.45 else ("fern" if pick < 0.58 else (
					"flower_small_white" if pick < 0.68 else ("flower_hibiscus" if pick < 0.76 else ("flower_purple" if pick < 0.84 else (
					"mushroom_cluster" if pick < 0.95 else "log_fallen"))))))
				var sc := r2.randf_range(0.5, 0.9) if kind in ["stepping_stone", "rock_1"] else (0.6 if kind == "log_fallen" else r2.randf_range(0.8, 1.2))
				var rot := atan2(t.x, t.z) + PI / 2.0 if kind == "log_fallen" else r2.randf() * TAU
				var keep := not in_village(at, 0.2) and not near_home(at, 0.2)   # every number drawn; the camp's ground skips
				if keep:
					kinds[kind].append(Transform3D(Basis(Vector3.UP, rot).scaled(Vector3.ONE * sc), at))
				# pebbles come in little groups
				if kind == "stepping_stone":
					for k in 2:
						var px := Transform3D(Basis(Vector3.UP, r2.randf() * TAU).scaled(Vector3.ONE * r2.randf_range(0.3, 0.5)),
							at + Vector3(r2.randf_range(-0.35, 0.35), 0, r2.randf_range(-0.35, 0.35)))
						if keep:
							kinds["stepping_stone"].append(px)
			s_at += r2.randf_range(0.9, 1.8)
		# a lantern half way along, lighting the way
		var lp := trail_point(i, L * 0.55)
		var lt := (trail_point(i, L * 0.55 + 0.4) - lp).normalized()
		var lantern := Props.instance("lantern_post")
		lantern.position = lp + Vector3(-lt.z, 0, lt.x) * (TRAIL_HALF + 0.45)
		lantern.rotation.y = atan2(-lt.z, lt.x)
		_trail_root.add_child(lantern)
		var glow := OmniLight3D.new()
		glow.light_color = Color(1.0, 0.78, 0.42)
		glow.light_energy = 0.7
		glow.omni_range = 2.4
		glow.position = Vector3(0, 1.35, 0.15)
		glow.add_to_group("lamp")
		glow.visible = Quality.lamps()
		lantern.add_child(glow)
	for kind in kinds:
		_scatter_cells(kind, kinds[kind], _trail_root)


## Scatter as MultiMeshes in 10 m cells, so the plants off screen (and outside the sun's shadow box) are skipped: one
## MultiMesh round the whole map is never culled and was drawn in full every frame and in every shadow pass.
## Returns [kind, MultiMeshInstance3D, indices into xfs] per cell. Small things cast no shadow.
func _scatter_cells(kind: String, xfs: Array, parent: Node) -> Array:
	var cells := {}
	for k in xfs.size():
		var o: Vector3 = (xfs[k] as Transform3D).origin
		var key := Vector2i(floori(o.x / SCATTER_CELL), floori(o.z / SCATTER_CELL))
		if not cells.has(key):
			cells[key] = []
		cells[key].append(k)
	var out: Array = []
	if xfs.is_empty():
		return out
	var mesh := Props.mesh(kind)
	for key in cells:
		var idx: Array = cells[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = mesh
		mm.instance_count = idx.size()
		for n in idx.size():
			mm.set_instance_transform(n, xfs[idx[n]])
			mm.set_instance_custom_data(n, Color(0, 0, 0, 0))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = Props.vc_multi()
		if kind in NO_SHADOW:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mmi)
		out.append([kind, mmi, idx])
	return out


## Hiding places in the meadow: patches of tall grass beside the trails and in the open, and bushes.
func _hideouts() -> void:
	for h in hide_spots:
		if h[3] != null and is_instance_valid(h[3]):
			h[3].queue_free()
	hide_spots.clear()
	var r3 := RandomNumberGenerator.new()
	r3.seed = 909
	for i in trails.size():
		var L := trail_length(i)
		for f in [0.32, 0.58, 0.82]:
			var p := trail_point(i, L * f)
			var t := (trail_point(i, L * f + 0.4) - p).normalized()
			var side := Vector3(-t.z, 0, t.x) * (1.0 if (int(f * 10) + i) % 2 == 0 else -1.0)
			var r := r3.randf_range(1.7, 2.4)
			hide_spots.append([p + side * (TRAIL_HALF + r + 0.3), r, "grass", null])
	var tries := 0
	while hide_spots.size() < 18 and tries < 200:
		tries += 1
		var a := r3.randf() * TAU
		var rr := r3.randf_range(camp_r + 3.5, WOODS_R - 3.0)
		var c := Vector3(sin(a), 0, -cos(a)) * rr
		if _strength_in(path_img_base, c) > 0.0 or _near_hide(c, 4.0) or _old_lake_dist(c) < 3.0 or _in_old_village(c, 2.5):
			continue
		hide_spots.append([c, r3.randf_range(1.6, 2.3), "grass", null])
	# bushes, alone or in twos and threes
	var made := 0
	tries = 0
	while made < 22 and tries < 400:
		tries += 1
		var a := r3.randf() * TAU
		var rr := r3.randf_range(camp_r + 1.8, WOODS_R - 1.5)
		var c := Vector3(sin(a), 0, -cos(a)) * rr
		if _strength_in(path_img_base, c) > 0.0 or _near_hide(c, 2.6) or _old_lake_dist(c) < 1.6 or _in_old_village(c, 1.0):
			continue
		var n := 1 + r3.randi() % 3
		for k in n:
			var at := c + Vector3(r3.randf_range(-1.0, 1.0), 0, r3.randf_range(-1.0, 1.0)) * (0.0 if k == 0 else 1.0)
			if _strength_in(path_img_base, at) > 0.0 or _old_lake_dist(at) < 1.2 or _in_old_village(at, 0.8):
				continue
			var bush := Node3D.new()
			bush.set_script(BushScript)
			add_child(bush)
			var sc := r3.randf_range(1.35, 1.9)
			bush.setup(main, "bush_1" if r3.randf() < 0.5 else "bush_2", at, sc, r3.randf() * TAU)
			hide_spots.append([at, 0.6 * sc, "bush", bush])
			made += 1
	# the ground kept for the stone, the garden and the fishing spot, round the Burrows' hollows (Phase E), and the
	# camp's buildings and their new paths, stays clear (filtered after the loops, so the random sequence above is the
	# same as before)
	for i in range(hide_spots.size() - 1, -1, -1):
		var h: Array = hide_spots[i]
		if in_reserved(h[0], float(h[1])) or in_hollow_clear(h[0]) or near_hollow(h[0], _hollow_keep() + float(h[1])) \
				or in_village(h[0], float(h[1])) or _strength_in(path_img, h[0]) > _strength_in(path_img_base, h[0]) \
				or lake_dist(h[0]) < float(h[1]) + 0.3 or near_home(h[0], float(h[1])):
			if h[3] != null and is_instance_valid(h[3]):
				h[3].queue_free()
			hide_spots.remove_at(i)


func _hollow_keep() -> float:
	return float(Data.burrow_list()[0]["entrance"].get("hideout_keep_out", 3.0))


func _near_hide(p: Vector3, d: float) -> bool:
	for h in hide_spots:
		if (h[0] as Vector3).distance_to(p) < d + float(h[1]):
			return true
	return false


## The hiding place the point p is in (null if none).
func hide_at(p: Vector3):
	for h in hide_spots:
		if Vector2(p.x - h[0].x, p.z - h[0].z).length() < float(h[1]):
			return h
	return null


func _smooth(pts: PackedVector3Array, per: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	for k in pts.size() - 1:
		var p0 := pts[maxi(k - 1, 0)]
		var p1 := pts[k]
		var p2 := pts[k + 1]
		var p3 := pts[mini(k + 2, pts.size() - 1)]
		for s in per:
			var t := float(s) / per
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(pts[pts.size() - 1])
	return out


func _ribbon(pts: PackedVector3Array, width: float, col: Color) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var left := PackedVector3Array()
	var right := PackedVector3Array()
	for k in pts.size():
		var a := pts[maxi(k - 1, 0)]
		var b := pts[mini(k + 1, pts.size() - 1)]
		var t := (b - a).normalized()
		var side := Vector3(-t.z, 0, t.x)
		var w := width * (0.5 + 0.08 * sin(k * 1.7))
		left.append(pts[k] + side * w + Vector3(0, 0.015, 0))
		right.append(pts[k] - side * w + Vector3(0, 0.015, 0))
	for k in pts.size() - 1:
		var c1 := col.darkened(0.06 * (k % 2)).srgb_to_linear()
		for v in [left[k], right[k], left[k + 1], right[k], right[k + 1], left[k + 1]]:
			st.set_color(c1)
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = Props.vc()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Where a trail is at distance s from its start (the woods).
func trail_point(i: int, s: float) -> Vector3:
	var pts: PackedVector3Array = trails[i]
	var acc := 0.0
	for k in pts.size() - 1:
		var l := pts[k].distance_to(pts[k + 1])
		if acc + l >= s:
			return pts[k].lerp(pts[k + 1], (s - acc) / maxf(l, 0.0001))
		acc += l
	return pts[pts.size() - 1]


func trail_length(i: int) -> float:
	var pts: PackedVector3Array = trails[i]
	var acc := 0.0
	for k in pts.size() - 1:
		acc += pts[k].distance_to(pts[k + 1])
	return acc


## How far along trail i the nearest point to p is.
func trail_progress(i: int, p: Vector3) -> float:
	var pts: PackedVector3Array = trails[i]
	var best := 1e9
	var best_s := 0.0
	var acc := 0.0
	for k in pts.size() - 1:
		var a := pts[k]
		var b := pts[k + 1]
		var ab := b - a
		var l := ab.length()
		var t := clampf((p - a).dot(ab) / maxf(l * l, 0.0001), 0.0, 1.0)
		var d := p.distance_to(a + ab * t)
		if d < best:
			best = d
			best_s = acc + l * t
		acc += l
	return best_s


# ---------------------------------------------------------------- the woods and the Gloom
func _woods() -> void:
	var kinds := {"tree_jungle_1": [], "tree_jungle_2": [], "tree_round": [], "bush_1": [], "bush_2": [], "fern": [],
		"monstera": [], "rock_2": [], "gloom_crystal": [], "mushroom_cluster": [], "flower_hibiscus": [],
		"flower_small_white": [], "flower_purple": [], "rock_1": [], "log_fallen": []}
	# the wall of trees
	var coral: Array = []
	var n := 0
	while n < 260:
		var a := rng.randf() * TAU
		var r := WOODS_R + 0.6 + pow(rng.randf(), 0.7) * 14.0
		var p := Vector3(sin(a), 0, -cos(a)) * r
		var pick := rng.randf()
		var kind := "tree_jungle_1" if pick < 0.38 else ("tree_jungle_2" if pick < 0.7 else "tree_round")
		# Phase E: every random number is drawn first, then a tree in the Hollow's clearing is skipped, so the rest of
		# the seed-2611 woods stays exactly where it was
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.85, 1.25)), p)
		var is_pink := rng.randf() < (0.45 if kind == "tree_round" else 0.18)
		n += 1
		if in_hollow_clear(p):
			continue
		kinds[kind].append(xf)
		coral.append([kind, kinds[kind].size() - 1, is_pink])
	# undergrowth at the woods edge
	for k in 220:
		var a := rng.randf() * TAU
		var r := WOODS_R - 1.2 + rng.randf() * 5.0
		var p := Vector3(sin(a), 0, -cos(a)) * r
		var kind: String = ["bush_1", "bush_2", "fern", "monstera", "fern", "rock_2", "mushroom_cluster", "log_fallen"][rng.randi() % 8]
		var xf2 := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.3)), p)
		if not in_hollow_clear(p):
			kinds[kind].append(xf2)
	# violet crystals in each patch's woods
	for i in 4:
		for k in 9:
			var a := deg_to_rad(float(Data.patch(i)["angle_deg"])) + rng.randf_range(-PATCH_HALF, PATCH_HALF) * 0.9
			var p := Vector3(sin(a), 0, -cos(a)) * (WOODS_R + rng.randf_range(-0.6, 3.0))
			kinds["gloom_crystal"].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.6)), p))
	# a few coral trees standing in the meadow near the woods, framing it
	for k in 10:
		var a := rng.randf() * TAU
		var p := Vector3(sin(a), 0, -cos(a)) * rng.randf_range(16.5, 20.0)
		var xf3 := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.9, 1.3)), p)
		if in_hollow_clear(p):
			continue
		kinds["tree_round"].append(xf3)
		coral.append(["tree_round", kinds["tree_round"].size() - 1, true])
	# flowers, rocks and mushrooms in the meadow, kept off the trails later by the grass pass
	for k in 90:
		var a := rng.randf() * TAU
		var r := 8.5 + rng.randf() * 11.0
		var p := Vector3(sin(a), 0, -cos(a)) * r
		if absf(p.x) < 1.6 and p.z < 0.0:
			continue
		if _old_lake_dist(p) < 0.9:
			continue
		var kind: String = ["flower_hibiscus", "flower_small_white", "flower_purple", "flower_small_white", "rock_1", "mushroom_cluster", "fern"][rng.randi() % 7]
		var xf4 := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.2)), p)
		# drawn first, then skipped (the seed-2611 woods stay)
		if not in_hollow_clear(p) and not in_village(p, 0.2) and lake_dist(p) >= 0.9 and not near_home(p, 0.3):
			kinds[kind].append(xf4)
	var pink := {}                                          # kind -> {instance index: true}
	for c in coral:
		if c[2]:
			if not pink.has(c[0]):
				pink[c[0]] = {}
			pink[c[0]][c[1]] = true
	for kind in kinds:
		for cell in _scatter_cells(kind, kinds[kind], self):
			var idx: Array = cell[2]
			var patches := PackedInt32Array()
			var flags := PackedByteArray()
			for k in idx:
				var o: Vector3 = (kinds[kind][k] as Transform3D).origin
				patches.append(patch_of(o) if o.length() > WOODS_R - 2.0 else -1)
				flags.append(1 if pink.get(kind, {}).has(k) else 0)
			_scatter.append([kind, cell[1], patches, flags])
	# soft rays of sunlight slanting through the trees
	var ray_mat := ShaderMaterial.new()
	ray_mat.shader = RAYS
	for k in 9:
		var a := deg_to_rad(rng.randf_range(-80.0, 80.0))
		var q := MeshInstance3D.new()
		var pm := QuadMesh.new()
		pm.size = Vector2(rng.randf_range(1.6, 3.2), 9.0)
		q.mesh = pm
		q.material_override = ray_mat
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		q.position = Vector3(sin(a), 0, -cos(a)) * rng.randf_range(WOODS_R - 3.5, WOODS_R + 0.5) + Vector3(0, 3.6, 0)
		q.rotation = Vector3(0.0, deg_to_rad(-38.0) + rng.randf_range(-0.15, 0.15), deg_to_rad(28.0))
		q.set_instance_shader_parameter("phase", rng.randf() * 10.0)
		q.add_to_group("sunray")
		q.visible = Quality.sunrays()
		add_child(q)
	# mist and watching eyes over each patch
	for i in 4:
		var mat := ShaderMaterial.new()
		mat.shader = MIST
		var q := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(16, 14)
		q.mesh = plane
		q.material_override = mat
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var d := patch_dir(i)
		q.position = d * (WOODS_R + 5.5) + Vector3(0, 0.9, 0)
		q.rotation.y = atan2(d.x, d.z)
		add_child(q)
		var eyes := Node3D.new()
		add_child(eyes)
		for k in 4:
			var e := _eye_pair()
			var a := deg_to_rad(float(Data.patch(i)["angle_deg"])) + rng.randf_range(-0.25, 0.25)
			e.position = Vector3(sin(a), 0, -cos(a)) * (WOODS_R + rng.randf_range(1.0, 3.5)) + Vector3(0, rng.randf_range(0.5, 1.4), 0)
			eyes.add_child(e)
		_mist.append([mat, eyes])


func _eye_pair() -> Node3D:
	var n := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.85, 0.45, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.8, 0.35, 1.0)
	mat.emission_energy_multiplier = 3.0
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	for x in [-0.09, 0.09]:
		var q := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.045
		s.height = 0.05
		s.radial_segments = 6
		s.rings = 3
		q.mesh = s
		q.material_override = mat
		q.position.x = x
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(q)
	var tw := n.create_tween().set_loops()
	tw.tween_interval(rng.randf_range(1.5, 4.0))
	tw.tween_property(n, "scale", Vector3(1, 0.05, 1), 0.08)
	tw.tween_property(n, "scale", Vector3.ONE, 0.08)
	return n


func _apply_gloom() -> void:
	var v := Vector4(gloom[0], gloom[1], gloom[2], gloom[3])
	_ground_mat.set_shader_parameter("gloom_patch", v)
	for i in 4:
		(_mist[i][0] as ShaderMaterial).set_shader_parameter("amount", gloom[i])
		(_mist[i][1] as Node3D).visible = gloom[i] > 0.5
	for ch in _scatter:
		var kind: String = ch[0]
		var mm: MultiMesh = (ch[1] as MultiMeshInstance3D).multimesh
		var patches: PackedInt32Array = ch[2]
		var cf: PackedByteArray = ch[3]
		for k in patches.size():
			var pi := patches[k]
			var g: float = gloom[pi] if pi >= 0 else 0.0
			if kind == "gloom_crystal":
				var xf := mm.get_instance_transform(k)
				var s: float = 0.0 if g < 0.02 else 1.0
				if s == 0.0 and xf.basis.get_scale().x > 0.01:
					mm.set_instance_transform(k, Transform3D(xf.basis.scaled(Vector3.ONE * 0.001), xf.origin))
			mm.set_instance_custom_data(k, Color(g, float(cf[k]), 0, 0))


## How much Gloom hangs over the woods when nothing stirs it: a step less for every mission won (Phase F: every mission
## uses every road, so the four woods clear together, not one by one as their roads were claimed). Only a look:
## Save.claimed is still kept by fight.gd for the code that reads it, but no longer drives this.
func gloom_level() -> float:
	return clampf(1.0 - float(Data.progress()) / float(maxi(1, Data.mission_count())), 0.0, 1.0)


## A mission is won: the Gloom over all four woods fades to gloom_level(), animated, with petals out of each.
func fade_gloom() -> void:
	var want := gloom_level()
	var from: Array = []
	for i in 4:
		from.append(gloom[i])
	var tw := create_tween()
	tw.tween_method(_fade_all.bind(from, want), 0.0, 1.0, 2.6).set_trans(Tween.TRANS_SINE)
	for i in 4:
		var d := patch_dir(i)
		for k in 3:
			var p := d * (WOODS_R + randf_range(-1.0, 4.0)) + Vector3(randf_range(-3, 3), 0.5, randf_range(-3, 3))
			get_tree().create_timer((i * 3 + k) * 0.2).timeout.connect(func(): Fx.petals(self, p))


## One step of fade_gloom: every patch from where it was (from) to `to`, t from 0 to 1.
func _fade_all(t: float, from: Array, to: float) -> void:
	for i in 4:
		gloom[i] = lerpf(float(from[i]), to, t)
	_apply_gloom()


## The Gloom bursts away from patch i: animated, with petals (a Gloom Raid held on its trails).
func lift_gloom(i: int) -> void:
	var tw := create_tween()
	tw.tween_method(_set_gloom.bind(i), maxf(gloom[i], 0.6), 0.0, 2.6).set_trans(Tween.TRANS_SINE)
	var d := patch_dir(i)
	for k in 7:
		var p := d * (WOODS_R + rng.randf_range(-1.0, 4.0)) + Vector3(rng.randf_range(-3, 3), 0.5, rng.randf_range(-3, 3))
		get_tree().create_timer(k * 0.25).timeout.connect(func(): Fx.petals(self, p))


## A later stage brings some Gloom back over lane i while it is fought for.
func gloom_returns(i: int) -> void:
	var tw := create_tween()
	tw.tween_method(_set_gloom.bind(i), gloom[i], 0.65, 1.8).set_trans(Tween.TRANS_SINE)


## Back to the level the missions won have left (after a raid's warning or a lost raid).
func settle_gloom() -> void:
	var want := gloom_level()
	for i in 4:
		if absf(gloom[i] - want) > 0.01:
			var tw := create_tween()
			tw.tween_method(_set_gloom.bind(i), gloom[i], want, 1.5)


func _set_gloom(v: float, i: int) -> void:
	gloom[i] = v
	_apply_gloom()


# ---------------------------------------------------------------- collision
func add_circle(center: Vector3, r: float, tag: String) -> void:
	circles.append([Vector2(center.x, center.z), r, tag])


func remove_tag(tag: String) -> void:
	circles = circles.filter(func(c): return c[2] != tag)
	segments = segments.filter(func(s): return s[4] != tag)


func add_segment(a: Vector3, b: Vector3, r: float, enemy_only: bool, tag: String) -> void:
	segments.append([Vector2(a.x, a.z), Vector2(b.x, b.z), r, enemy_only, tag])


## Pushes a walker of radius `radius` out of anything solid. Barricades only stop enemies, and enemies cannot step
## into the firelight between waves.
func constrain(p: Vector3, radius: float, is_enemy: bool, flyer := false) -> Vector3:
	if main != null and main.area != null and main.area.owns(p):
		return main.area.constrain(p, radius, is_enemy, flyer)   # Phase E: in a Burrow, its map's walkable ground and stones
	var q := Vector2(p.x, p.z)
	for pass_i in 2:
		if flyer:
			break                               # fliers go over buildings, barricades and water
		for c in circles:
			var d: Vector2 = q - c[0]
			var need: float = c[1] + radius
			var l := d.length()
			if l < need:
				q = c[0] + (d / maxf(l, 0.0001) if l > 0.0001 else Vector2(0, 1)) * need
		if lake != null:
			q = lake.push_out(q, radius)
		if is_enemy:
			for s in segments:
				var a: Vector2 = s[0]
				var b: Vector2 = s[1]
				var ab := b - a
				var t := clampf((q - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
				var close := a + ab * t
				var d := q - close
				var need: float = s[2] + radius
				var l := d.length()
				if l < need:
					q = close + (d / l if l > 0.0001 else Vector2(-ab.y, ab.x).normalized()) * need
	if not is_enemy and q.length() > MOVE_R:
		q = q.normalized() * MOVE_R
	return Vector3(q.x, p.y, q.y)


## True if a barricade (or other blocking piece) lies on the straight line from a to b (used by the boar's charge).
func blocked_between(a: Vector3, b: Vector3) -> bool:
	var p := Vector2(a.x, a.z)
	var q := Vector2(b.x, b.z)
	for s in segments:
		if Geometry2D.segment_intersects_segment(p, q, s[0], s[1]) != null:
			return true
	return false


# ---------------------------------------------------------------- the Watch (Phase D)
## The signpost, or once every mission is won the Watch: the same post with a horn on a cradle, a crystal that fills
## with the Gloom meter, and hidden parts that show what the Watch has (Lookout flag, Tracker bell, streak ribbons).
func _make_sign() -> Node3D:
	if not Data.raids_open():
		var plain := Props.instance("signpost")
		plain.set_meta("model", "signpost")
		return plain
	if Props.has("signpost_watch"):
		var w := Props.instance("signpost_watch")
		w.set_meta("model", "signpost_watch")
		for part in ["lookout_flag", "tracker_bell", "ribbon_1", "ribbon_2", "ribbon_3"]:
			var n := Props.find_part(w, part)
			if n:
				n.visible = false                       # every part is visible in the GLB: the game shows them as earned
		return w
	# placeholder until the Watch model exists: the old signpost with a crystal that fills
	var s := Props.instance("signpost")
	s.set_meta("model", "signpost_fill")
	var fill := Props.instance("gloom_crystal")
	fill.name = "fill"
	fill.position = Vector3(0, 1.55, 0)
	fill.scale = Vector3.ONE * 0.35
	s.add_child(fill)
	return s


## Every mission is won (or an old save is loaded): the signpost becomes the Watch, in the same spot.
func swap_sign() -> void:
	var want := "signpost"
	if Data.raids_open():
		want = "signpost_watch" if Props.has("signpost_watch") else "signpost_fill"
	if sign_node != null and is_instance_valid(sign_node) and String(sign_node.get_meta("model", "")) == want:
		update_watch()
		return
	if sign_node != null and is_instance_valid(sign_node):
		sign_node.queue_free()
	sign_node = _make_sign()
	sign_node.position = station_pos("sign")
	_camp_root.add_child(sign_node)
	Fx.boing(sign_node, 0.3)
	update_watch()


## The Watch shows the meter (its crystal fills), the Lookout flag, the Tracker bell and the perfect-streak ribbons.
func update_watch() -> void:
	if sign_node == null or not is_instance_valid(sign_node) or String(sign_node.get_meta("model", "")) == "signpost":
		return
	var r: Dictionary = Save.raids
	var full := float(Data.gr()["meter"]["full"])
	var share := clampf(float(r.get("meter", 0.0)) / full, 0.0, 1.0)
	if bool(r.get("pending", false)):
		share = 1.0
	var fill := Props.find_part(sign_node, "fill")
	if fill:
		if String(sign_node.get_meta("model", "")) == "signpost_watch":
			fill.scale = Vector3(1.0, lerpf(0.06, 1.0, share), 1.0)
		else:
			fill.scale = Vector3(0.35, 0.35 * lerpf(0.15, 1.0, share), 0.35)
		Props.set_param(fill, "flash", 0.35 if share >= 1.0 else 0.0)
	var flag := Props.find_part(sign_node, "lookout_flag")
	if flag:
		flag.visible = Save.unlocks.has("watch:lookout")
	var bell := Props.find_part(sign_node, "tracker_bell")
	if bell:
		bell.visible = Save.unlocks.has("watch:tracker")
	var rib: Array = Data.gr()["streak_ribbons"]
	for k in rib.size():
		var n := Props.find_part(sign_node, "ribbon_%d" % (k + 1))
		if n:
			n.visible = int(r.get("streak", 0)) >= int(rib[k])
