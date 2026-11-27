extends Node
## The camp's layout and the HUD (18 Nov 2026), run from autotest.gd (`-- --autotest --fresh --<mode>`). Each check logs
## "EXPECT PASS <what>" or "EXPECT FAIL <what>" through autotest.gd's _expect. Modes:
##   --layout          the camp round the campfire at home levels 1-8 with every building built: open ground round the
##                     fire and south of it, the footprints, the lake, the trails and barricade spots, the Burrows' path,
##                     the markers' spots, and nothing tall just south of where the cat walks (from the models
##                     themselves); the markers on the screen (no two overlap, none covers the cat at a marker's spot);
##                     a top-down and two game-camera shots at every level, the walk to every building at levels 1 and 6
##                     (and a tap from 4.5 m away: the cat walks there and the card opens), and the cat at each building
##                     at levels 4 and 6, before and after a tap on it
##   --layoutsave=1/2  an old save with a tower and spikes on the new ground (1, with --fresh): on the next start (2)
##                     they are back in the bag
##   --hudcheck        the HUD (run it at 480x1040 with --safe-top=73 --safe-bottom=42, the S24's shape and bars):
##                     every card opened by a real tap, as a dialog: about 90% of the width, at most 80% of the height,
##                     in the middle, inside the phone's bars, its texts and buttons inside it, its round X inside it and
##                     the safe area, the dim over the game; each closed by its X or a tap outside (taking turns), and
##                     once by Android's back button; the signpost with missions and a saved run, the Watch and a raid's
##                     warning; building; a mission with a boss bar; the Gloomwood's cards, pips and arena; nothing of
##                     the HUD in the middle third of the screen and (H2) no two HUD controls overlapping (the group
##                     "hud_edge"); real taps on Ride / Walk, the Settings gear (a graphics row, the X), the Bag and the
##                     build icon. Also run it at 540x960 (a 16:9 phone).
##   --taps            taps and markers: nothing opens by walking; a drag that ends on a marker or a long press opens
##                     nothing; a tap on empty ground does nothing; a tap in reach opens at once, a far one walks the cat
##                     there first, a drag stops that walk; a tap on the thing itself works; a drag on the dim moves
##                     nothing; the X, a tap outside, back and Escape close a dialog; the markers far, near, in reach and
##                     over the cat
##   --arrows          a mission wave with foes off the screen on two trails: arrows at the screen's edge toward them
##                     (a shot), and none once they are gone

var t                     # autotest.gd (its helpers: _wait, _shot, _expect, _until, _veteran, _go_to, _press, _log, _tap...)
var main
const MarkerScript := preload("res://scripts/marker.gd")

const CLEAR_ZONE := Rect2(-1.5, 0.8, 3.0, 5.2)     # the ground just south of the campfire: nothing taller than the cat
const FIRE_CLEAR := 1.9                            # open ground round the campfire: no footprint nearer than this
const TAN50 := 1.19                                # the camera looks down at 50 degrees
const CAT_H := 0.35                                # a cat is hidden when its body at this height is covered
const IDS := ["target", "bench", "cottage", "stall", "well", "tailor"]   # 23 Nov 2026: and the Tailor's Nook


func run() -> bool:
	var a := Data.args()
	if a.has("--layout"):
		await _layout()
		return true
	if a.has("--hudcheck"):
		await _hudcheck()
		return true
	if a.has("--taps"):
		await _taps()
		return true
	if a.has("--arrows"):
		await _arrows()
		return true
	for arg in a:
		if arg.begins_with("--layoutsave="):
			await _layoutsave(int(arg.substr(13)))
			return true
	return false


# ---------------------------------------------------------------- --layout
func _layout() -> void:
	main.player.invincible = true
	t._veteran(14)                                  # missions 1-14 won: the stall, the cottage, the well, garden, fishing
	Save.stations["saddlery"] = 1                  # 23 Nov 2026: the Saddlery and the Tailor's Nook too, so the Nook is
	Save.stations["tailor"] = 1                    # checked against every building round it (at every home level)
	main.stations.free_guardian()                   # the stone and its ring show
	for id in ["target", "bench"]:
		Save.stations[id] = 3                       # the biggest models (they are capped by the home level below)
	await t._wait(0.5)
	var st = main.stations
	for lv in range(1, 9):
		Save.camp_level = lv
		for id in ["target", "bench"]:
			Save.stations[id] = mini(lv, 3)         # a station's level never passes the home's
		main.on_camp_grown()
		main.fight.gate_max = float(Data.fire_hp())
		await t._wait(0.8)
		_check_level(lv)
		await _top_down("layout_l%d_top" % lv)
		main.player.global_position = Vector3(0.0, 0, 1.6)
		main.player.facing = PI
		await t._wait(4.6)                         # the "Your home grows!" banner goes
		await t._shot("layout_l%d_camp" % lv)
		main.player.global_position = Vector3(3.6, 0, 2.6)    # amid the buildings east of the fire
		await t._wait(1.5)
		await t._shot("layout_l%d_east" % lv)
		if lv == 1 or lv == 6:
			for id in IDS:
				main.hud.hide_card()
				main.player.global_position = Vector3(0.0, 0, 1.6)
				await t._wait(0.3)
				var ok: bool = await t._go_to(st.rings[id].global_position, 0.3, 20.0)
				t._expect("level %d the cat walks from the fire to the %s's spot" % [lv, id], ok and st.rings[id].contains(main.player.global_position),
					{"cat": main.player.global_position})
				t._expect("level %d walking there opens nothing" % lv, main.hud._card == null)
				# from up to 4.5 m back toward the fire, where its badge is on the screen, a tap: the cat walks there itself
				var spot: Vector3 = st.rings[id].global_position
				var back := Vector3(-spot.x, 0, 1.6 - spot.z)
				for dd in [4.5, 4.0, 3.5, 3.0, 2.5]:
					main.player.global_position = spot + back.normalized() * minf(dd, back.length())
					main.snap_camera()
					var bsp: Vector2 = main.cam.unproject_position(st.rings[id].badge_pos())
					if _view_rect().grow(-50.0).has_point(bsp):
						break
				await t._wait(0.3)
				var tapped: bool = await t._tap(st.rings[id])
				var came: bool = await t._until(func(): return main.hud.card_ring() == st.rings[id], 12.0)
				t._expect("level %d a tap on the %s from a few metres: the cat walks there and its card opens" % [lv, id],
					tapped and came and st.rings[id].in_reach(main.player.global_position), {"cat": main.player.global_position})
			main.hud.hide_card()
		if lv == 4 or lv == 6:
			for id in IDS:
				main.hud.hide_card()
				main.player.global_position = st.rings[id].global_position
				main.snap_camera()
				await t._wait(1.4)
				await t._shot("layout_l%d_at_%s" % [lv, id])
				await t._tap(st.rings[id])
				await t._wait(0.7)
				await t._shot("layout_l%d_at_%s_card" % [lv, id])
			main.hud.hide_card()
			main.player.global_position = Vector3(0.0, 0, 1.6)
			await t._wait(0.5)
	var at := {}
	for id in IDS:
		at[id] = main.world.station_pos(id)
	t._log("layout", {"spots": at, "hide_spots": main.world.hide_spots.size()})


## A straight-down view of the camp (no HUD), centred on the campfire.
func _top_down(name: String) -> void:
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.size = 22.0
	cam.far = 80.0
	main.add_child(cam)
	cam.global_position = Vector3(0.0, 30.0, 1.5)
	cam.rotation = Vector3(-PI / 2.0, 0.0, 0.0)
	cam.current = true
	main.hud.visible = false
	await t._wait(0.3)
	await t._shot(name)
	main.hud.visible = true
	main.cam.current = true
	cam.queue_free()


## A building's model as a height map (in the world): the highest point in every 0.1 m cell its meshes cover.
func _heights(id: String) -> Dictionary:
	var n: Node3D = main.stations.nodes.get(id)
	var g := {}
	var stack: Array = [n] if n != null else []
	while not stack.is_empty():
		var c = stack.pop_back()
		if c is MeshInstance3D and (c as MeshInstance3D).mesh != null and (c as MeshInstance3D).is_visible_in_tree():
			var xf: Transform3D = (c as MeshInstance3D).global_transform
			var m: Mesh = (c as MeshInstance3D).mesh
			for s in m.get_surface_count():
				var arr := m.surface_get_arrays(s)
				var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				var idx = arr[Mesh.ARRAY_INDEX]
				var tri_n: int = (idx.size() if idx != null and not (idx as PackedInt32Array).is_empty() else vs.size()) / 3
				for k in tri_n:
					var i0: int = idx[k * 3] if idx != null and not (idx as PackedInt32Array).is_empty() else k * 3
					var i1: int = idx[k * 3 + 1] if idx != null and not (idx as PackedInt32Array).is_empty() else k * 3 + 1
					var i2: int = idx[k * 3 + 2] if idx != null and not (idx as PackedInt32Array).is_empty() else k * 3 + 2
					_tri(xf * vs[i0], xf * vs[i1], xf * vs[i2], g)
		for ch in c.get_children():
			stack.append(ch)
	# by 0.1 m column: [[z, height], ...], and the bounds, so a test only looks at the columns under the cat
	var cols := {}
	var lo := Vector3(1e9, 0, 1e9)
	var hi := Vector3(-1e9, 0, -1e9)
	for key in g:
		var hh := float(g[key])
		if hh <= CAT_H:
			continue
		if not cols.has(key.x):
			cols[key.x] = []
		cols[key.x].append([(key.y + 0.5) * 0.1, hh])
		lo = Vector3(minf(lo.x, key.x * 0.1), 0, minf(lo.z, key.y * 0.1))
		hi = Vector3(maxf(hi.x, key.x * 0.1 + 0.1), maxf(hi.y, hh), maxf(hi.z, key.y * 0.1 + 0.1))
	return {"cols": cols, "lo": lo, "hi": hi}


func _tri(a: Vector3, b: Vector3, c: Vector3, g: Dictionary) -> void:
	var n := int(ceil(maxf(a.distance_to(b), maxf(b.distance_to(c), a.distance_to(c))) / 0.05)) + 1
	for i in n + 1:
		for j in n + 1 - i:
			var p := a + (b - a) * (float(i) / n) + (c - a) * (float(j) / n)
			var key := Vector2i(floori(p.x / 0.1), floori(p.z / 0.1))
			if p.y > float(g.get(key, -1.0)):
				g[key] = p.y


## True if a building (its height map) hides a cat standing at p from the game camera (south, looking north 50 degrees
## down): some part of it within the cat's width (0.18 m each side) stands south of p and higher than the cat's body
## seen along the camera's line.
func _hides(h: Dictionary, p: Vector3) -> bool:
	var lo: Vector3 = h["lo"]
	var hi: Vector3 = h["hi"]
	if p.x < lo.x - 0.2 or p.x > hi.x + 0.2 or p.z >= hi.z or p.z < lo.z - (hi.y - CAT_H) / TAN50:
		return false
	for ix in range(floori((p.x - 0.18) / 0.1), floori((p.x + 0.18) / 0.1) + 1):
		for c in h["cols"].get(ix, []):
			var dz: float = c[0] - p.z
			if dz > 0.0 and c[1] > CAT_H + TAN50 * dz:
				return true
	return false


## A model as the surfaces it is made of (the home's crowns float high over open ground, so a height map would not
## do): every 0.1 m cell and 0.25 m layer its meshes pass through, and the bounds.
func _bins(id: String) -> Dictionary:
	var n: Node3D = main.stations.nodes.get(id)
	var g := {}
	var stack: Array = [n] if n != null else []
	while not stack.is_empty():
		var c = stack.pop_back()
		if c is MeshInstance3D and (c as MeshInstance3D).mesh != null and (c as MeshInstance3D).is_visible_in_tree():
			var xf: Transform3D = (c as MeshInstance3D).global_transform
			var m: Mesh = (c as MeshInstance3D).mesh
			for s in m.get_surface_count():
				var arr := m.surface_get_arrays(s)
				var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				var idx = arr[Mesh.ARRAY_INDEX]
				var has_idx: bool = idx != null and not (idx as PackedInt32Array).is_empty()
				for k in (idx.size() if has_idx else vs.size()) / 3:
					var a: Vector3 = xf * vs[idx[k * 3] if has_idx else k * 3]
					var b: Vector3 = xf * vs[idx[k * 3 + 1] if has_idx else k * 3 + 1]
					var e: Vector3 = xf * vs[idx[k * 3 + 2] if has_idx else k * 3 + 2]
					var steps := int(ceil(maxf(a.distance_to(b), maxf(b.distance_to(e), a.distance_to(e))) / 0.05)) + 1
					for i in steps + 1:
						for j in steps + 1 - i:
							var p := a + (b - a) * (float(i) / steps) + (e - a) * (float(j) / steps)
							if p.y > 0.05:
								g[Vector3i(floori(p.x / 0.1), floori(p.z / 0.1), floori(p.y / 0.25))] = true
		for ch in c.get_children():
			stack.append(ch)
	var lo := Vector3(1e9, 0, 1e9)
	var hi := Vector3(-1e9, 0, -1e9)
	for key in g:
		lo = Vector3(minf(lo.x, key.x * 0.1), 0, minf(lo.z, key.y * 0.1))
		hi = Vector3(maxf(hi.x, key.x * 0.1 + 0.1), maxf(hi.y, key.z * 0.25 + 0.25), maxf(hi.z, key.y * 0.1 + 0.1))
	return {"b": g, "lo": lo, "hi": hi}


## True if those surfaces hide most of a cat at p from the camera that follows it (about 48 degrees down): 5 of 9
## lines of sight (3 across the cat, 3 up it) pass through them.
func _hides_bins(h: Dictionary, p: Vector3) -> bool:
	var lo: Vector3 = h["lo"]
	var hi: Vector3 = h["hi"]
	if p.x < lo.x - 0.3 or p.x > hi.x + 0.3 or p.z >= hi.z:
		return false
	var b: Dictionary = h["b"]
	var blocked := 0
	for dx in [-0.15, 0.0, 0.15]:
		var ix := floori((p.x + dx) / 0.1)
		for sh in [0.15, 0.35, 0.55]:
			for iz in range(floori(p.z / 0.1) + 1, floori(hi.z / 0.1) + 1):
				var y: float = sh + 1.12 * ((iz + 0.5) * 0.1 - p.z)
				if y > hi.y + 0.3:
					break
				if b.has(Vector3i(ix, iz, floori(y / 0.25))):
					blocked += 1
					break
	return blocked >= 5


## Where the cat spends time in the camp: every ring that shows, the start and revive spots, the barricade spots and the
## spots the cat holds at the trails' mouths, and the camp's paths and the trails within 14 m (from the path map).
func _cat_places() -> Array:
	var w = main.world
	var out: Array = []
	for r in main.rings:
		if is_instance_valid(r) and r.visible:
			out.append(["ring " + String(r.key), r.global_position])
	out.append(["start", Vector3(0, 0, w.camp_r * 0.42)])
	out.append(["revive", Vector3(0.6, 0, 1.4)])
	for sl in w.barricade_slots():
		out.append(["barricade spot", sl[0]])
	for i in 4:
		out.append(["trail mouth %d" % i, w.edge_point(i) * 1.55])
	var x := -14.0
	while x <= 14.0:
		var z := -14.0
		while z <= 14.0:
			var p := Vector3(x, 0, z)
			if w.path_strength(p) > 0.25:
				out.append(["path", p])
			z += 0.25
		x += 0.25
	return out


func _check_level(lv: int) -> void:
	var w = main.world
	var st = main.stations
	var lvl := "level %d" % lv
	var places := _cat_places()
	var hollow: Dictionary = Data.burrow_list()[0]["entrance"]
	var hpath := PackedVector3Array()
	for q in hollow["path"]:
		hpath.append(Vector3(float(q[0]), 0, float(q[2])))
	hpath = w._smooth(hpath, 7)
	var info := {}
	for id in IDS:
		var c: Vector3 = w.station_pos(id)
		var f: float = st.foot(id)
		var ring: Vector3 = st.rings[id].global_position
		var hm := _heights(id)
		var bad: Array = []
		# open ground round the fire, and straight south of it
		if id != "well" and Vector2(c.x, c.z).length() - f < FIRE_CLEAR:
			bad.append("crowds the fire %.2f" % (Vector2(c.x, c.z).length() - f))
		if CLEAR_ZONE.grow(f).has_point(Vector2(c.x, c.z)):
			bad.append("in the clear ground south of the fire")
		# the lake: only the well stands by it
		if w.lake_dist(c) < f + (0.05 if id == "well" else 1.0):
			bad.append("at the lake %.2f" % (w.lake_dist(c) - f))
		if w.lake_dist(ring) < 0.6:
			bad.append("ring at the water %.2f" % w.lake_dist(ring))
		# footprints: every other station and the campfire, at this level
		for cc in w.circles:
			var tag := String(cc[2])
			if tag == "st_" + id:
				continue
			var d: float = (cc[0] as Vector2).distance_to(Vector2(c.x, c.z))
			if d < float(cc[1]) + f + 0.3:
				bad.append("touches %s %.2f" % [tag, d - float(cc[1]) - f])
			if (cc[0] as Vector2).distance_to(Vector2(ring.x, ring.z)) < float(cc[1]) + 0.45:
				bad.append("ring on %s" % tag)
		# kept ground: the stone, the garden, the fishing spot and its ring, the Burrow's clearing and path
		if w.in_reserved(c, f):
			bad.append("on reserved ground")
		if c.distance_to(w.FISH_RING) < f + 0.75 + 0.3:
			bad.append("at the fishing ring")
		for k in 12:
			var e: Vector3 = c + Vector3(cos(TAU * k / 12.0), 0, sin(TAU * k / 12.0)) * f
			if w.in_hollow_clear(e):
				bad.append("in the Burrow's clearing")
				break
		var near_path := 99.0
		for k in hpath.size() - 1:
			near_path = minf(near_path, Geometry2D.get_closest_point_to_segment(Vector2(ring.x, ring.z), Vector2(hpath[k].x, hpath[k].z),
				Vector2(hpath[k + 1].x, hpath[k + 1].z)).distance_to(Vector2(ring.x, ring.z)))
		if near_path < 1.35:
			bad.append("ring on the Burrow's path %.2f" % near_path)
		# the trails and the barricade spots
		for i in w.trails.size():
			for q in w.trails[i]:
				if Vector2(q.x - c.x, q.z - c.z).length() < w.TRAIL_HALF + f + 0.5:
					bad.append("near trail %d" % i)
					break
		for sl in w.barricade_slots():
			if (sl[0] as Vector3).distance_to(c) < f + 2.5:
				bad.append("near a barricade spot")
		# nothing hides the cat: no ring, path or trail spot just north of the building
		var hid: Array = []
		for pl in places:
			if _hides(hm, pl[1]):
				hid.append([pl[0], snappedf(pl[1].x, 0.1), snappedf(pl[1].z, 0.1)])
		if not hid.is_empty():
			bad.append("hides the cat at %s" % str(hid.slice(0, 6)))
		t._expect("%s the %s stands clear" % [lvl, id], bad.is_empty(), {"bad": bad, "at": c, "ring": ring})
		info[id] = {"fire_m": snappedf(Vector2(c.x, c.z).length(), 0.01), "in_light": Vector2(c.x, c.z).length() < w.camp_r,
			"ring_in_light": Vector2(ring.x, ring.z).length() < w.camp_r, "model": st.model_name(id)}
	# the home: one spot at every level, open ground between it and the fire, off the trails, the barricade spots and the
	# lake, and it hides no ring and no path of the camp (a big crown can cover a trail's mouth further north: logged)
	var hc: Vector3 = w.station_pos("home")
	var hf: float = st.foot("home")
	var hbad: Array = []
	var gap: float = Vector2(hc.x, hc.z).length() - hf - st.foot("campfire")
	if gap < 1.5:
		hbad.append("crowds the fire %.2f" % gap)
	if hc.distance_to(w.HOME_SPOT) > 0.01:
		hbad.append("not at its one spot")
	if w.lake_dist(hc) < hf + 1.5:                 # a clear gap to the water (the user, 19 Nov 2026)
		hbad.append("at the lake %.2f" % (w.lake_dist(hc) - hf))
	if w.lake_dist(st.rings["shop"].global_position) < 0.6:
		hbad.append("its ring at the water")
	for i in w.trails.size():
		for q in w.trails[i]:
			if Vector2(q.x - hc.x, q.z - hc.z).length() < w.TRAIL_HALF + hf + 0.25:
				hbad.append("on trail %d" % i)
				break
	for sl in w.barricade_slots():
		if (sl[0] as Vector3).distance_to(hc) < hf + 2.0:
			hbad.append("near a barricade spot")
	var hb := _bins("home")
	var trail_hid: Array = []
	for pl in places:
		var pp: Vector3 = pl[1]
		if Vector2(pp.x - hc.x, pp.z - hc.z).length() < hf + 0.6 or not _hides_bins(hb, pp):
			continue                                    # its own doorstep, or in view
		var on_trail: bool = String(pl[0]).begins_with("barricade") or String(pl[0]).begins_with("trail")
		for tr in w.trails:
			for q in tr:
				if Vector2(q.x - pp.x, q.z - pp.z).length() < w.TRAIL_HALF + 0.3:
					on_trail = true
					break
		if on_trail:
			trail_hid.append([snappedf(pp.x, 0.1), snappedf(pp.z, 0.1)])
		else:
			hbad.append("hides the cat at %s (%.1f, %.1f)" % [pl[0], pp.x, pp.z])
	t._expect("%s the home stands clear" % lvl, hbad.is_empty(), {"bad": hbad.slice(0, 6), "at": hc, "gap": snappedf(gap, 0.01)})
	info["home"] = {"fire_gap": snappedf(gap, 0.01), "model": st.model_name("home"), "trail_spots_behind_it": trail_hid.size()}
	# the markers' spots (where the cat stands to use a thing): none closer than 1.5 m to another
	var rings: Array = []
	for r in main.rings:
		# the small road-spot and tower-repair markers (defences.gd) sit on the roads, away from the buildings
		if is_instance_valid(r) and r.is_visible_in_tree() and not String(r.key).begins_with("road_") and not String(r.key).begins_with("tower_"):
			rings.append(r)
	var close: Array = []
	for i in rings.size():
		for j in range(i + 1, rings.size()):
			var d := Vector2(rings[i].global_position.x - rings[j].global_position.x, rings[i].global_position.z - rings[j].global_position.z).length()
			if d < 1.5:
				close.append([rings[i].key, rings[j].key, snappedf(d, 0.01)])
	t._expect(lvl + " no marker spots closer than 1.5 m", close.is_empty(), {"close": close})
	_marker_screen(lvl, rings)
	# no two footprints overlap (the pot sits on the fire's rim on purpose)
	var cs: Array = w.circles.filter(func(cc): return String(cc[2]).begins_with("st_"))
	var over: Array = []
	for i in cs.size():
		for j in range(i + 1, cs.size()):
			if [cs[i][2], cs[j][2]].has("st_campfire") and [cs[i][2], cs[j][2]].has("st_pot"):
				continue
			var d2: float = (cs[i][0] as Vector2).distance_to(cs[j][0])
			if d2 < float(cs[i][1]) + float(cs[j][1]):
				over.append([cs[i][2], cs[j][2], snappedf(d2, 0.01)])
	t._expect(lvl + " no footprints overlap", over.is_empty(), {"overlap": over})
	# nothing random stands on the buildings' ground: no hide spot, no bush
	var on_v: Array = []
	for h in w.hide_spots:
		if w.in_village(h[0], float(h[1]) - 0.2):
			on_v.append([snappedf(h[0].x, 0.1), snappedf(h[0].z, 0.1), h[2]])
	t._expect(lvl + " no hide spot on the buildings' ground", on_v.is_empty(), {"on": on_v})
	t._log("layout level", {"camp_level": lv, "light": w.camp_r, "buildings": info})


## The markers on the screen, with the camp's camera following the cat: no two badges overlap (the camera centred
## between them, both at full size), and with the cat at any marker's spot no badge covers it (its own in reach, the
## others at full size).
func _marker_screen(lvl: String, ms: Array) -> void:
	var olap: Array = []
	for i in ms.size():
		for j in range(i + 1, ms.size()):
			var a: Vector3 = ms[i].badge_pos()
			var b: Vector3 = ms[j].badge_pos()
			if Vector2(a.x - b.x, a.z - b.z).length() > 9.0:
				continue
			var mid: Vector3 = (ms[i].global_position + ms[j].global_position) * 0.5
			if _badge_rect(ms[i], mid, 1.0).grow(2.0).intersects(_badge_rect(ms[j], mid, 1.0).grow(2.0)):
				olap.append([String(ms[i].key), String(ms[j].key)])
	t._expect(lvl + " no two markers overlap on the screen", olap.is_empty(), {"overlap": olap})
	var covers: Array = []
	for m in ms:
		var c: Vector3 = m.global_position
		var cat := _cat_rect(c)
		for n in ms:
			if Vector2(n.badge_pos().x - c.x, n.badge_pos().z - c.z).length() > 7.0:
				continue
			if _badge_rect(n, c, 1.18 if n == m else 1.0).intersects(cat):
				covers.append([String(n.key), "at " + String(m.key)])
	t._expect(lvl + " no marker covers the cat at a marker's spot", covers.is_empty(), {"covers": covers})


## The game camera as it follows a cat at `cat` in the camp (main._update_camera, no fight).
func _cam_at(cat: Vector3) -> void:
	var cam: Camera3D = main.cam
	var focus := Vector3(cat.x, 0.0, cat.z + main.CAM_LEAD)
	cam.global_position = focus + Vector3(0.0, sin(main.CAM_PITCH), cos(main.CAM_PITCH)) * main.CAM_DIST_CAMP
	cam.rotation = Vector3(-main.CAM_PITCH, 0.0, 0.0)


## A marker's badge on the screen (HUD pixels) at size s (1 near, 1.18 in reach), the camera following a cat at `cat`.
func _badge_rect(m, cat: Vector3, s: float) -> Rect2:
	var cam: Camera3D = main.cam
	var keep := cam.global_transform
	_cam_at(cat)
	var p: Vector3 = m.badge_pos()
	var k := clampf(cam.global_position.distance_to(p) / MarkerScript.REF_DIST, 0.6, 2.2)
	var c := cam.unproject_position(p)
	var hw := absf(cam.unproject_position(p + cam.global_transform.basis.x * MarkerScript.BADGE_W * 0.5 * s * k).x - c.x)
	cam.global_transform = keep
	return Rect2(c - Vector2(hw, hw * 1.25), Vector2(hw * 2.0, hw * 2.5))


## The cat standing at p on the screen (feet to ears, 0.3 m each side), the camera following it.
func _cat_rect(p: Vector3) -> Rect2:
	var cam: Camera3D = main.cam
	var keep := cam.global_transform
	_cam_at(p)
	var feet := cam.unproject_position(p)
	var head := cam.unproject_position(p + Vector3(0, 0.75, 0))
	var hw := absf(cam.unproject_position(p + cam.global_transform.basis.x * 0.3).x - feet.x)
	cam.global_transform = keep
	return Rect2(feet.x - hw, head.y, hw * 2.0, feet.y - head.y)


# ---------------------------------------------------------------- --layoutsave
## 1 (with --fresh): a veteran save with a tower on the cottage's ground and spikes on the stall's ring, as an old save
## could have them, and one tower well clear of the camp. 2: on start they are back in the bag; the clear one stays.
func _layoutsave(step: int) -> void:
	var w = main.world
	if step == 1:
		t._veteran(6)
		Save.placed.append({"type": "tower", "x": w.station_pos("cottage").x + 0.4, "z": w.station_pos("cottage").z, "rot": 0.0})
		Save.placed.append({"type": "spikes", "x": w.spot_ring("stall").x, "z": w.spot_ring("stall").z, "rot": 0.0})
		Save.placed.append({"type": "tower", "x": 6.0, "z": -6.0, "rot": 0.0})
		Save.items["tower"] = 0
		Save.items["spikes"] = 0
		Save.save_game()
		t._log("layoutsave 1", {"placed": Save.placed})
		return
	var on_ground: Array = []
	var kept := 0
	for sp in Save.placed:
		if sp.has("x"):
			var at := Vector3(float(sp["x"]), 0, float(sp["z"]))
			if w.in_village(at, 0.6):
				on_ground.append(sp)
			elif String(sp["type"]) == "tower":
				kept += 1
	t._expect("pieces on the buildings' new ground are gone from the camp", on_ground.is_empty(), {"placed": Save.placed})
	t._expect("they are back in the bag", int(Save.items.get("tower", 0)) == 1 and int(Save.items.get("spikes", 0)) == 1, {"items": Save.items})
	t._expect("the tower clear of the camp stays", kept >= 1, {"placed": Save.placed})
	t._expect("the player is told", String(main.hud._tip.text).contains("place") or main.hud_note.contains("place"), {"tip": main.hud._tip.text})
	var pieces_ok := true
	for p in main.defences.pieces:
		if p["type"] != "barricade" and w.in_village(p["pos"], 0.6):
			pieces_ok = false
	t._expect("no piece stands on the buildings' ground", pieces_ok)
	await t._shot("layoutsave_after")


# ---------------------------------------------------------------- --hudcheck
var _e                    # autotest_e.gd, for its Burrows helpers


func _hudcheck() -> void:
	_e = load("res://scripts/autotest_e.gd").new()
	_e.t = t
	_e.main = main
	add_child(_e)
	main.player.invincible = true
	var hud = main.hud
	# 1. mid-game: the signpost with the next mission, a saved run and the replays; the camp's messages
	t._veteran(4)
	Save.mission_run = {"mission": 4, "chapter": 1}
	Save.leaves = 5000
	Save.timber = 200
	await t._wait(0.6)
	_middle_free("camp, mid-game")
	await _card_at(main.stations.rings["sign"], "sign_missions")
	_expect_rows("the signpost: the saved run and the replays", ["Start wave", "Give up"])
	# Android's back button: the dialog's while one is open (it closes it), the game's again after
	t._expect("back is the dialog's while it is open", not get_tree().quit_on_go_back)
	get_tree().root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await t._wait(0.2)
	t._expect("Android's back button closes the dialog", hud._card == null and get_tree().quit_on_go_back)
	main.player.global_position = Vector3(0, 0, 1.6)
	await t._wait(0.6)
	hud.banner("Your home grows!", Color(1.0, 0.9, 0.4), "Home level 3 · a bigger firelight")
	hud.toast("Wave 3 of 15")
	hud.tip("Tap the signpost to defend the camp.", main.stations.rings["sign"])
	await t._wait(0.5)
	await t._shot("hud_messages")
	_middle_free("a banner, a toast and a tip")
	t._expect("the banner sits just under the top bar", hud._banner.global_position.y < hud._safe.x + hud._top_h + 60.0, {"y": hud._banner.global_position.y})
	var bar_top: float = hud._build_bar.global_position.y
	t._expect("the tip sits just above the bottom buttons", hud._tip.get_global_rect().end.y <= bar_top + 1.0, {"tip": hud._tip.get_global_rect(), "bar": bar_top})
	await t._wait(2.2)
	t._expect("a banner is gone within 2.5 s", hud._banner.modulate.a < 0.05, {"a": hud._banner.modulate.a})
	hud.banner("First Embers won!", Color(1.0, 0.9, 0.4), "+120 leaves  ·  +6 timber", true)
	await t._wait(0.5)
	await t._shot("hud_banner_big")
	_middle_free("a raid won")
	await t._wait(3.6)
	# 2. the endgame camp: every card
	await _e._endgame_camp()
	main.stations.free_guardian()
	Save.camp_level = 6
	main.on_camp_grown()
	Save.leaves = 60000
	Save.timber = 900
	Save.shards = 300
	Save.mats = {"amber": 80}                          # H1: amber is the one material; no Hollow keys
	main.on_purchase()
	main.player.global_position = Vector3(0, 0, 1.6)
	await t._wait(4.0)
	_middle_free("camp, endgame")
	await t._shot("hud_camp_endgame")
	await _hud_taps()
	for id in ["shop", "target", "bench", "well", "cottage", "stall", "sign", "stone", "garden", "pot", "fishing"]:
		await _card_at(main.stations.rings[id], id)
		if id == "stall" or id == "cottage":
			_expect_rows("the %s card has its colours" % id, ["Colours"])
			var att := false
			for b in hud.card_buttons():
				if String(b.get_meta("label", "")) in ["Buy", "Wear", "Take off"]:
					att = true
			t._expect("the %s card has attachment rows" % id, att)
			if t._press("Next"):
				await t._wait(0.4)
				await t._shot("hud_card_%s_next" % id)
				_card_fits(id + " after Next")
	await _card_at(main.burrows.ring(), "hollow")
	await _close_dialog("hollow")
	# 3. a raid: the meter in the top bar, then its warning and the raid card
	main.player.global_position = Vector3(0, 0, 1.6)
	Save.raids["meter"] = 62.0
	main.raids.test_awake = true
	await t._wait(0.8)
	await t._shot("hud_raid_meter")
	_middle_free("the raid meter")
	await t._raid_to_warning()
	await t._wait(1.0)
	await t._shot("hud_raid_warning")
	_middle_free("a raid's warning")
	await _card_at(main.stations.rings["sign"], "raid")
	await _close_dialog("raid")
	# ... and its attack (the whole attack's share in the raid bar, the campfire's bar, the leader's boss bar)
	main.player.global_position = Vector3(0, 0, 1.6)
	main.fight.next_phase_now()
	await t._until(func(): return main.fight.in_wave, 3.0)
	await t._wait(1.5)
	t._expect("the raid's attack runs", main.fight.active and main.fight.mode == "raid" and main.fight.in_wave and hud._fire_bar.visible,
		{"mode": main.fight.mode, "in_wave": main.fight.in_wave, "fire_bar": hud._fire_bar.visible})
	_middle_free("a raid's attack")
	t._reset_fight()
	t._clear_raid_state()
	main.hud.refresh()
	# 4. building: row 2 full (towers and spikes in the Bag beside Ride, then beside Feed; barricades never stay in the
	# Bag: defences.gd refunds them, so two is the most row 2 shows), then placing
	main.player.global_position = Vector3(5.0, 0, -6.0)
	if main.player.riding:
		main.set_riding(false, false)
	if main.mount != null:
		main.mount.refill()
	Save.items["tower"] = 2
	Save.items["spikes"] = 1
	main.hud.refresh_build()
	await t._wait(0.6)
	var acts = hud.p_actions
	var defs: Array = (acts.def_buttons as Dictionary).values().filter(func(b): return b.is_visible_in_tree() and b.modulate.a > 0.95)
	t._expect("row 2: the towers, the spikes and Ride", defs.size() == 2 and acts.ride_button.is_visible_in_tree()
		and defs.all(func(b): return b.get_global_rect().size.x <= 130.0), {"defs": defs.map(func(b): return b.get_global_rect())})
	# all three would still end before Ride (each button at its own smallest size, 10 px apart, from 20 px in)
	var three := 20.0
	for k in acts.def_buttons:
		three += maxf((acts.def_buttons[k] as Button).get_combined_minimum_size().x, 124.0) + 10.0
	t._expect("three defence buttons would still end before Ride", three - 10.0 < acts.ride_button.get_global_rect().position.x,
		{"end": three - 10.0, "ride": acts.ride_button.get_global_rect().position.x})
	_middle_free("two defences and Ride")
	main.mount.resting = 30.0                            # knocked out: Feed takes Ride's place (its words are longer)
	main.hud.refresh_build()
	await t._wait(0.4)
	t._expect("row 2: the defences and Feed (three would still end before it)", acts.feed_button.is_visible_in_tree() and not acts.ride_button.is_visible_in_tree()
		and three - 10.0 < acts.feed_button.get_global_rect().position.x, {"end": three - 10.0, "feed": acts.feed_button.get_global_rect()})
	_middle_free("two defences and Feed")
	main.mount.refill()
	main.hud.refresh_build()
	await t._wait(0.4)
	main.defences.start_placing("tower")
	await t._wait(0.6)
	await t._shot("hud_placing")
	var pb: Array = hud._place_bar.get_children().filter(func(c): return c is Button and c.is_visible_in_tree())
	t._expect("placing: Place and Done at the bottom", pb.size() == 2 and pb.all(func(b): return b.get_global_rect().position.y > _view().y * 0.66), {"n": pb.size()})
	_middle_free("placing a tower")
	main.defences.stop_placing()
	await t._wait(0.3)
	# 5. the Burrows: a room, its rings' cards, the boss, the seal
	await _burrow_cards()
	# 6. a mission wave with a boss bar (the saved run of step 1 dropped, or mission 1 would be refused)
	main.player.global_position = Vector3(0, 0, 1.6)
	Save.mission_run = {}
	await t._wait(0.5)
	main.start_stage(0)
	await t._wait(1.0)
	var f = main.fight
	t._expect("the mission wave runs", f.active and f.in_wave and f.mode == "mission", {"active": f.active, "in_wave": f.in_wave, "mode": f.mode})
	var bear = f.spawn("bear", main.world.spawn_point(0, 0.0) * 0.6, 0)
	bear.hp = 1e9
	# the raid bar fills as the wave's enemies fall: one beaten (not the bear)
	var one: Node3D = null
	for i in 20:
		for e in get_tree().get_nodes_in_group("foes"):
			if e != bear and not e.dead and not e.is_in_group("bonus"):
				one = e
				break
		if one != null:
			break
		await t._wait(0.3)
	if one != null:
		one.hit(Vector3.FORWARD, one.hp + 1.0)
	await t._wait(0.4)
	var fl: float = hud.p_fight.fill()
	var share := float(f.wave_total() - f.left_in_wave()) / float(maxi(f.wave_total(), 1))
	t._expect("the mission's raid bar fills as enemies fall", one != null and f.in_wave and fl > 0.0 and is_equal_approx(fl, share) and hud.p_fight.progress_done > 0,
		{"fill": fl, "share": share, "total": f.wave_total(), "left": f.left_in_wave(), "done": hud.p_fight.progress_done})
	await t._wait(1.0)
	await t._shot("hud_mission_boss")
	t._expect("the boss bar shows under the top bar", hud._boss_bar.visible and hud._boss_bar.global_position.y >= hud._safe.x + hud._top_h, {"y": hud._boss_bar.global_position.y})
	t._expect("the campfire's bar shows in the wave", hud._fire_bar.visible)
	_middle_free("a mission wave with a boss")
	# the Last Stand: the fire out, its banner and the words line
	f._start_last_stand()
	await t._wait(0.5)
	t._expect("the Last Stand: the words line says so", String(hud._stage_l.text) == "Last stand: rebuild the fire" and hud._fire_bar.visible, {"text": hud._stage_l.text})
	await t._shot("hud_last_stand")
	_middle_free("the Last Stand")
	t._reset_fight()


## The view in HUD pixels.
func _view_rect() -> Rect2:
	return Rect2(Vector2.ZERO, _view())


## The view's size in HUD pixels.
func _view() -> Vector2:
	return main.hud.get_viewport().get_visible_rect().size


## Nothing of the HUD in the middle third of the screen (but the bars over the cat and the pointer arrow), and (H2) no
## two of the HUD's edge controls overlapping: every control in the group "hud_edge" that shows (visible, not faded
## out) is checked against the band and against each other (a control and one inside it are not a pair).
func _middle_free(what: String) -> void:
	var hud = main.hud
	var v := _view()
	var band := Rect2(0, v.y / 3.0, v.x, v.y / 3.0)
	var bad: Array = []
	var shown := _edge_shown()
	for c in shown:
		if (c as Control).get_global_rect().intersects(band):
			bad.append([_edge_name(c), (c as Control).get_global_rect()])
	t._expect("nothing of the HUD mid-screen: %s" % what, bad.is_empty() and shown.size() >= 4, {"bad": str(bad), "shown": shown.size()})
	t._expect("the top bar clears the safe area: %s" % what, hud._res.global_position.y >= hud._safe.x, {"y": hud._res.global_position.y, "safe": hud._safe.x})
	var over: Array = []
	for i in shown.size():
		for j in range(i + 1, shown.size()):
			var a: Control = shown[i]
			var b: Control = shown[j]
			if a.is_ancestor_of(b) or b.is_ancestor_of(a):
				continue
			if a.get_global_rect().intersects(b.get_global_rect()):
				over.append("%s %s / %s %s" % [_edge_name(a), a.get_global_rect(), _edge_name(b), b.get_global_rect()])
	t._expect("no two HUD controls overlap: %s" % what, over.is_empty(), {"overlap": over.slice(0, 4)})


## The HUD's edge controls that show now (group "hud_edge": visible and not faded out, with a size).
func _edge_shown() -> Array:
	var out: Array = []
	for n in get_tree().get_nodes_in_group("hud_edge"):
		var c := n as Control
		if c == null or not c.is_visible_in_tree() or c.modulate.a < 0.05:
			continue
		var r := c.get_global_rect()
		if r.size.x < 1.0 or r.size.y < 1.0:
			continue
		out.append(c)
	return out


func _edge_name(c: Control) -> String:
	var label := String(c.get_meta("label", "")) if c.has_meta("label") else ""
	return label if label != "" else (String((c as Label).text) if c is Label else String(c.name))


## H2: real taps on the HUD's own buttons: Ride, then Walk (the mount comes and goes); the gear opens the Settings
## window, a tap on a graphics row's button sets that level (put back after), the X closes it; the Bag opens by its
## button (a shot), and the build icon opens the Hearthtree's card from where the cat stands.
func _hud_taps() -> void:
	var hud = main.hud
	hud.hide_card()
	main.player.global_position = Vector3(0, 0, 1.6)
	if main.player.riding:
		main.set_riding(false, false)
	await t._wait(0.5)
	var rb: Button = hud.p_actions.ride_button
	t._expect("the Ride button shows at the bottom right", rb != null and rb.is_visible_in_tree() and rb.text == "Ride"
		and rb.get_global_rect().position.x > _view().x * 0.6 and rb.get_global_rect().position.y > _view().y * 0.66, {"rect": rb.get_global_rect() if rb != null else Rect2()})
	await t._tap_at(rb.get_global_rect().get_center())
	await t._wait(0.5)
	t._expect("a real tap on Ride: the cat rides, the button reads Walk", main.player.riding and rb.text == "Walk", {"riding": main.player.riding, "text": rb.text})
	await t._shot("hud_riding")
	_middle_free("riding")
	await t._tap_at(rb.get_global_rect().get_center())
	await t._wait(0.5)
	t._expect("a real tap on Walk: the cat walks, the button reads Ride", not main.player.riding and rb.text == "Ride", {"riding": main.player.riding, "text": rb.text})
	# the gear: the Settings window
	var gear: Button = hud._gear
	t._expect("the gear shows at the top right, round and thumb-sized", gear != null and gear.is_visible_in_tree() and gear.is_in_group("ui_block")
		and gear.get_global_rect().size.x >= 60.0 and gear.get_global_rect().end.x > _view().x * 0.85 and gear.get_global_rect().position.y >= hud._safe.x)
	await t._tap_at(gear.get_global_rect().get_center())
	await t._wait(0.5)
	t._expect("a real tap on the gear opens the Settings window", hud.card_ring() == hud.settings and hud.card_title() != "", {"title": hud.card_title()})
	await t._shot("hud_settings")
	_card_fits("settings")
	var was_level: int = Quality.level
	var was_auto: bool = Quality.auto
	var use: Button = null
	for b in hud.card_buttons():
		if String(b.get_meta("label", "")) == "Use" and not b.disabled:
			use = b
			break
	t._expect("the Settings window has a graphics row to pick", use != null)
	if use != null:
		await t._tap_at(use.get_global_rect().get_center())
		await t._wait(0.4)
		t._expect("a real tap on a graphics row's button changes the graphics", Quality.level != was_level or Quality.auto != was_auto,
			{"level": [was_level, Quality.level], "auto": [was_auto, Quality.auto]})
	if was_auto:
		Quality.set_auto()
	else:
		Quality.set_level(was_level)
	await t._tap_close()
	t._expect("the Settings window closes by its X", hud._card == null)
	await t._wait(0.3)
	# the Bag through its button
	await t._tap_at(hud.bag_button.get_global_rect().get_center())
	await t._wait(0.6)
	t._expect("a real tap on the Bag opens it", hud.card_ring() == hud.inventory)
	await t._shot("hud_bag")
	hud.hide_card()
	await t._wait(0.3)
	# the build icon: the Hearthtree's card from here
	var bi: Button = hud._build_icon
	t._expect("the build icon shows next to the Bag", bi != null and bi.is_visible_in_tree() and bi.get_global_rect().position.x >= hud.bag_button.get_global_rect().end.x)
	await t._tap_at(bi.get_global_rect().get_center())
	await t._wait(0.6)
	t._expect("a real tap on the build icon opens the Hearthtree's card", hud.card_ring() == main.stations.rings["shop"], {"title": hud.card_title()})
	await t._shot("hud_build_icon")
	hud.hide_card()
	await t._wait(0.3)


var _close_way := 0                 # the dialogs close by their X and by a tap outside, taking turns
var _open_id := ""


## The dialog open now closes, by its X or by a tap outside it (taking turns), through real taps.
func _close_dialog(what: String) -> void:
	var hud = main.hud
	if hud._card == null:
		return
	var by_x := _close_way % 2 == 0
	_close_way += 1
	if by_x:
		await t._tap_close()
	else:
		await t._tap_outside()
	await t._wait(0.1)
	t._expect("the %s dialog closes by %s" % [what, "its X" if by_x else "a tap outside"], hud._card == null)


## A tap on a marker (the cat put at its spot): its card opens as a dialog; a shot and the checks.
func _card_at(ring, id: String) -> void:
	await _close_dialog(_open_id)
	await t._at_ring(ring)
	await t._wait(0.6)
	await t._shot("hud_card_%s" % id)
	_card_fits(id)
	_open_id = id


func _card_fits(id: String) -> void:
	var hud = main.hud
	var v := _view()
	if hud._card == null:
		t._expect("the %s card opens" % id, false)
		return
	var cr: Rect2 = hud._card.get_global_rect()
	var bad: Array = []
	var top: float = hud._safe.x
	var bottom: float = v.y - hud._safe.y
	if cr.position.x < 0.0 or cr.end.x > v.x + 0.5 or cr.position.y < top - 0.5 or cr.end.y > bottom + 0.5:
		bad.append("off the screen or under the phone's bars %s" % cr)
	if cr.size.x < v.x * 0.86 or cr.size.x > v.x * 0.94:
		bad.append("not about 90%% of the width (%.0f)" % cr.size.x)
	if cr.size.y > (bottom - top) * 0.81:
		bad.append("taller than 80%% of the screen (%.0f)" % cr.size.y)
	if absf(cr.get_center().x - v.x * 0.5) > 2.0 or absf(cr.get_center().y - (top + bottom) * 0.5) > 2.0:
		bad.append("not in the middle %s" % cr)
	var xb: Button = hud.close_button()
	if xb == null:
		bad.append("no close button")
	else:
		var xr: Rect2 = xb.get_global_rect()
		if xr.size.x < 60.0 or xr.size.y < 60.0:
			bad.append("the X is small %s" % xr.size)
		if not cr.grow(0.5).encloses(xr) or xr.position.y < top or xr.end.y > bottom:
			bad.append("the X is outside the dialog or the safe area %s" % xr)
		if xr.get_center().x < cr.get_center().x + cr.size.x * 0.3 or xr.get_center().y > cr.position.y + 110.0:
			bad.append("the X is not at the top right %s" % xr)
	if hud._dim == null or not hud._dim.get_global_rect().grow(0.5).encloses(Rect2(Vector2.ZERO, v)) or hud._dim.color.a < 0.2:
		bad.append("no dim over the game")
	elif hud._dim.get_index() < hud._build_bar.get_index() or hud._card.get_index() < hud._dim.get_index():
		bad.append("the bottom buttons over the dim, or the dialog under it")
	var scrolls: bool = hud._card_list != null and hud._card_scroll != null and hud._card_list.size.y > hud._card_scroll.size.y + 1.0
	var stack: Array = [hud._card]
	while not stack.is_empty():
		var n = stack.pop_back()
		for ch in n.get_children():
			stack.append(ch)
		if n is Button or n is Label:
			var r: Rect2 = (n as Control).get_global_rect()
			var in_scroll := false
			var q = n.get_parent()
			while q != null and q != hud._card:
				if q is ScrollContainer and scrolls:
					in_scroll = true
				q = q.get_parent()
			var nm := String(n.text) if n is Label else String(n.get_meta("label", "button"))
			if r.position.x < cr.position.x - 0.5 or r.end.x > cr.end.x + 0.5:
				bad.append("%s sticks out sideways" % nm)
			elif not in_scroll and (r.position.y < cr.position.y - 0.5 or r.end.y > cr.end.y + 0.5):
				bad.append("%s sticks out" % nm)
	t._expect("the %s dialog fits" % id, bad.is_empty(), {"bad": bad.slice(0, 6), "card": cr, "scrolls": scrolls})


func _expect_rows(what: String, want: Array) -> void:
	var labels: Array = []
	for b in main.hud.card_buttons():
		labels.append(String(b.get_meta("label", "")))
	var texts := ""
	var stack: Array = [main.hud._card] if main.hud._card != null else []
	while not stack.is_empty():
		var n = stack.pop_back()
		for ch in n.get_children():
			stack.append(ch)
		if n is Label:
			texts += String(n.text) + "|"
	var ok := true
	for w in want:
		if not labels.has(w) and not texts.contains(String(w)):
			ok = false
	t._expect(what, ok, {"buttons": labels})


## Into the Gloomwood: the top bar (status, fight pips, satchel), the card of every ring on the way (the way home, the
## Gloom-bound chest, the Moonwell's shrines and lift), the arena with the boss bar, the Gloom seal, and the lift home.
func _burrow_cards() -> void:
	var hud = main.hud
	var r = main.burrows.runner
	main.player.global_position = Vector3(0, 0, 15.5)
	await t._wait(0.3)
	await main.burrows.enter("old_hollow", 1)
	await t._wait(1.0)
	await t._shot("hud_burrow_wayin")
	_middle_free("the Gloomwood's way in")
	t._expect("in a Burrow: the fight pips and the status line show", hud._gate_bar.visible and hud._stage_l.visible and hud._stage_l.text.contains("Level 1"),
		{"status": hud._stage_l.text})
	var m = r.map
	await _rings_near(r, m.wpt([0.0, 0.0]), "wayin")
	for f in r.fights:
		f["state"] = "done"                              # quiet: no fight on the way (the cards are what is checked)
	for e in r.foes():
		e.queue_free()
	await _rings_near(r, m.wpt({"in": "nook"}), "nook")
	main.player.global_position = m.wpt({"in": "moonwell", "z": 1.6})
	await t._wait(0.8)
	await _rings_near(r, m.wpt({"in": "moonwell"}), "moonwell")
	main.player.global_position = m.w2(m.sample(m.length - 13.0)[0])
	await t._wait(1.0)
	main.player.global_position = m.w2(m.sample(m.length - 7.5)[0])
	await t._wait(2.0)
	await t._shot("hud_burrow_arena")
	t._expect("the arena: the boss bar under the top bar", hud._boss_bar.visible, {"boss": r._boss != null})
	_middle_free("the arena with the boss")
	if r._boss != null:
		r._boss.hit(Vector3.FORWARD, r._boss.hp + 1.0)
		await t._wait(1.2)
	await _rings_near(r, m.w2(m.arena_c), "arena", 14.0)
	if m.parts.has("end_lift_ring") and m.parts["end_lift_ring"].visible:
		await _close_dialog("burrow")
		await t._at_ring(m.parts["end_lift_ring"])
		await t._wait(0.6)
		if hud._card != null:
			await t._shot("hud_card_burrow_lift")
			_card_fits("the lift")
			t._press("Climb")
	await t._until(func(): return main.area == null and not r.leaving, 6.0)
	await t._wait(1.0)


## Every ring of the Burrow within `r_m` of `at` (the way home, chests, shrines, the lift, the Gloom seal): its card.
func _rings_near(r, at: Vector3, tag: String, r_m := 8.0) -> void:
	var seen := 0
	for rg in main.rings.duplicate():
		if not is_instance_valid(rg) or not rg.visible or not r.owns(rg.global_position) or rg.global_position.distance_to(at) > r_m:
			continue
		await _close_dialog("burrow")
		await t._at_ring(rg)
		await t._wait(0.6)
		if main.hud._card != null:
			await t._shot("hud_card_burrow_%s_%d" % [tag, seen])
			_card_fits("burrow %s %d (%s)" % [tag, seen, String(main.hud._card_ring.key) if main.hud._card_ring != null else ""])
			seen += 1
			if rg.key == "burrow" and r.map.parts.get("seal_ring") == rg:
				await t._wait(3.5)                          # tapped, the seal breaks: the Warden is free, the lift shows
		await _close_dialog("burrow")
		main.player.global_position = rg.global_position + Vector3(0, 0, 1.6)
		await t._wait(0.3)


# ---------------------------------------------------------------- --taps
## Taps and markers (19 Nov 2026), all through real input (autotest.gd _tap_at, _drag): see the header.
func _taps() -> void:
	main.player.invincible = true
	t._veteran(6)
	Save.leaves = 5000
	main.on_purchase()
	await t._wait(0.6)
	var st = main.stations
	var hud = main.hud
	var ia = main.interact
	var bench = st.rings["bench"]
	var target = st.rings["target"]
	var stall = st.rings["stall"]
	var v := _view()
	# 1. walking onto a marker's spot opens nothing; the marker there is in reach, the next one near, a far one small
	main.player.global_position = Vector3(0, 0, 1.6)
	main.snap_camera()
	await t._wait(0.4)
	await t._go_to(bench.global_position, 0.2, 10.0)
	await t._wait(1.0)
	t._expect("walking onto the bench's spot opens nothing", hud._card == null and bench.reached, {"reached": bench.reached})
	t._expect("in reach: bigger, glowing, a tap ripple, the bench's rim glow", bench._look > 1.9 and bench._halo.visible and bench._ripple.visible
		and not bench._rim_on.is_empty(), {"look": bench._look, "rim": bench._rim_on.size()})
	t._expect("near (the target, 2.6 m): full size, no glow", target._look > 0.9 and target._look < 1.1 and not target._halo.visible, {"look": target._look})
	t._expect("far (the stall, 5 m): small and dim", stall._look < 0.1 and stall._bm.albedo_color.a < 0.7, {"look": stall._look, "a": stall._bm.albedo_color.a})
	await t._shot("taps_01_near_far")
	# 2. a drag that ends on the badge opens nothing; nor does a long press on it
	var bp: Vector2 = main.cam.unproject_position(bench.badge_pos())
	await _drag(bp + Vector2(-150, 140), bp, 0.45)
	await t._wait(0.3)
	t._expect("a drag that ends on a marker opens nothing", hud._card == null and ia.walking == null)
	await t._go_to(bench.global_position, 0.2, 6.0)
	await t._wait(0.5)
	bp = main.cam.unproject_position(bench.badge_pos())
	await _press_long(bp, 0.6)
	t._expect("a long press on a marker opens nothing", hud._card == null)
	# 3. a tap on empty ground: nothing opens and the cat stays
	var at: Vector3 = main.player.global_position
	var empty := _empty_spot()
	await t._tap_at(empty)
	await t._wait(0.4)
	t._expect("a tap on empty ground opens nothing and the cat stays", hud._card == null and ia.walking == null
		and main.player.global_position.distance_to(at) < 0.05, {"at": empty})
	# 4. a tap on the badge in reach: its dialog at once
	var n0: int = ia.taps
	await t._tap(bench)
	await t._wait(0.3)
	t._expect("a tap on the badge in reach opens its dialog at once", hud.card_ring() == bench and ia.taps == n0 + 1 and t.tap_misses == 0)
	await t._shot("taps_02_dialog_bench")
	# 5. the dialog: a drag on the dim moves nothing; the X, a tap outside, back and Escape close it
	at = main.player.global_position
	var cr: Rect2 = hud._card.get_global_rect()
	var dy: float = (cr.end.y + v.y - hud._safe.y) * 0.5 if v.y - hud._safe.y - cr.end.y > 60.0 else (cr.position.y + hud._safe.x) * 0.5
	await _drag(Vector2(v.x * 0.2, dy), Vector2(v.x * 0.8, dy), 0.4)
	await t._wait(0.3)
	t._expect("a drag on the dim moves nothing and keeps the dialog", hud.card_ring() == bench and main.player.global_position.distance_to(at) < 0.02
		and main.joystick.vector == Vector2.ZERO, {"moved": main.player.global_position.distance_to(at)})
	await t._tap_close()
	t._expect("its X closes it", hud._card == null)
	await t._tap(bench)
	await t._wait(0.3)
	await t._tap_outside()
	t._expect("a tap outside closes it", hud._card == null)
	await t._tap(bench)
	await t._wait(0.3)
	t._expect("back is the dialog's while it is open", hud._card != null and not get_tree().quit_on_go_back)
	get_tree().root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await t._wait(0.2)
	t._expect("Android's back button closes it, and back quits the game again after", hud._card == null and get_tree().quit_on_go_back)
	await t._tap(bench)
	await t._wait(0.3)
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	Input.parse_input_event(esc)
	await t._wait(0.1)
	var esc_up := esc.duplicate() as InputEventKey
	esc_up.pressed = false
	Input.parse_input_event(esc_up)
	await t._wait(0.2)
	t._expect("Escape closes it", hud._card == null)
	# 6. a far marker: the cat walks there by itself and its card opens on arrival
	await t._tap(stall)
	t._expect("a tap on a far marker: the cat sets off, no card yet", ia.walking == stall and hud._card == null)
	await t._wait(0.6)
	await t._shot("taps_03_walking_to_stall")
	var arrived: bool = await t._until(func(): return hud.card_ring() == stall, 10.0)
	t._expect("it walks there and the stall's card opens on arrival", arrived and stall.in_reach(main.player.global_position),
		{"cat": main.player.global_position})
	await t._shot("taps_04_dialog_stall")
	await t._tap_close()
	# 7. a drag stops the walk
	await t._go_to(bench.global_position, 0.2, 10.0)
	await t._wait(0.4)
	await t._tap(stall)
	await t._wait(0.4)
	await _drag(Vector2(v.x * 0.5, v.y * 0.62), Vector2(v.x * 0.5 - 140, v.y * 0.62), 0.3)
	await t._wait(1.5)
	t._expect("a drag stops the walk: no card", ia.walking == null and hud._card == null and not stall.in_reach(main.player.global_position))
	# 8. a tap on the thing itself, not its badge
	var cot = st.rings["cottage"]
	main.player.global_position = cot.global_position
	main.snap_camera()
	await t._wait(0.6)
	var body: Array = cot.body_px(main.cam)
	var hit := Vector2.ZERO
	if not body.is_empty():
		hit = (body[0] as Vector2).lerp(body[1], 0.35)
	t._expect("the cottage's body is away from its badge", not body.is_empty() and hit.distance_to(main.cam.unproject_position(cot.badge_pos())) > cot.half_px(main.cam) * 1.4,
		{"hit": hit})
	await t._tap_at(hit)
	await t._wait(0.3)
	t._expect("a tap on the cottage itself opens its card", hud.card_ring() == cot)
	await t._tap_close()
	# 9. a badge over the cat fades (the cat comes first)
	var sb: Vector3 = stall.badge_pos()
	main.player.global_position = Vector3(sb.x, 0, sb.z - 1.7)
	main.snap_camera()
	await t._wait(0.8)
	t._expect("a badge that would cover the cat fades", stall._over_cat > 0.9 and stall._bm.albedo_color.a < 0.45,
		{"over": stall._over_cat, "a": stall._bm.albedo_color.a})
	await t._shot("taps_05_badge_fades_over_cat")
	# 10. the "!" dot: something affordable at the bench
	t._expect("the bench shows its \"!\" (an upgrade it can afford)", bench.pulse and bench._dot.visible)
	t._expect("no tap had to fall back", t.tap_misses == 0, {"misses": t.tap_misses})


## A real drag through Input: a finger down at `from`, moving to `to` over `secs`, then up.
func _drag(from: Vector2, to: Vector2, secs: float) -> void:
	var xf: Transform2D = get_viewport().get_final_transform()
	var d := InputEventScreenTouch.new()
	d.index = 0
	d.position = xf * from
	d.pressed = true
	Input.parse_input_event(d)
	var n := maxi(3, int(secs / 0.05))
	for k in n:
		await t._wait(secs / n)
		var m := InputEventScreenDrag.new()
		m.index = 0
		m.position = xf * from.lerp(to, float(k + 1) / n)
		m.relative = xf.basis_xform((to - from) / n)
		Input.parse_input_event(m)
	var u := InputEventScreenTouch.new()
	u.index = 0
	u.position = xf * to
	u.pressed = false
	Input.parse_input_event(u)
	await get_tree().process_frame
	await get_tree().process_frame


## A real finger held still at p for `secs`, then lifted.
func _press_long(p: Vector2, secs: float) -> void:
	var xf: Transform2D = get_viewport().get_final_transform()
	var d := InputEventScreenTouch.new()
	d.index = 0
	d.position = xf * p
	d.pressed = true
	Input.parse_input_event(d)
	await t._wait(secs)
	var u := d.duplicate() as InputEventScreenTouch
	u.pressed = false
	Input.parse_input_event(u)
	await get_tree().process_frame
	await get_tree().process_frame


## A point of the screen with no marker or thing under it, away from the cat and the HUD.
func _empty_spot() -> Vector2:
	var v := _view()
	var cat: Vector2 = main.cam.unproject_position(main.player.global_position)
	var y := v.y * 0.3
	while y < v.y * 0.7:
		var x := v.x * 0.12
		while x < v.x * 0.9:
			var p := Vector2(x, y)
			if main.interact.pick(p) == null and not main.joystick._blocked(p) and p.distance_to(cat) > 120.0:
				return p
			x += 50.0
		y += 50.0
	return Vector2(v.x * 0.1, v.y * 0.5)


# ---------------------------------------------------------------- --arrows
## Where an attack comes from (threat_arrows.gd): foes off the screen on two trails in a wave give arrows at the edge;
## when they are gone the arrows fade.
func _arrows() -> void:
	main.player.invincible = true
	t._veteran(2)
	await t._wait(0.5)
	var ar = null
	for c in main.hud.get_children():
		if c.has_method("_scan"):
			ar = c
	t._expect("the arrows are part of the HUD", ar != null)
	if ar == null:
		return
	main.player.global_position = Vector3(0, 0, 1.6)
	main.start_stage(0)
	await t._wait(1.0)
	await t._clear_test_foes()
	for k in 3:
		var e = main.fight.spawn("thornling", main.world.spawn_point(0, 0.0), 0)
		e.hp = 1e9
	for k in 2:
		var e2 = main.fight.spawn("thornling", main.world.spawn_point(2, 0.0), 2)
		e2.hp = 1e9
	await t._wait(1.2)
	var shown := 0
	for k in ar.SECTORS:
		if ar._alpha[k] > 0.5:
			shown += 1
	t._expect("foes off the screen on two trails: two or three arrows", shown >= 2 and shown <= 3, {"shown": shown})
	await t._shot("arrows_wave")
	t._reset_fight()
	await t._clear_test_foes()
	await t._wait(1.0)
	var left := 0.0
	for k in ar.SECTORS:
		left = maxf(left, ar._alpha[k])
	t._expect("the fight over, no foes: the arrows fade", left < 0.05, {"alpha": left})
