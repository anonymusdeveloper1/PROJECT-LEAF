extends Node
## Only runs with `-- --autotest` (and a fresh test save: add --fresh). It plays the first stage by itself: walks to
## the gate, picks Fernwood, fights each wave, buys an upgrade at the Training Target after wave 1, calls the next
## waves with the horn, and saves screenshots and report.json to --shots=<folder>.
##   --smoke   just a few screenshots of the camp, then quit
##   --village  the Wishing Well, Mushroom Cottage and Market Stall, Sprig, riding Thistle, the Well mending between waves
##   --newfoes  the five later enemies close up, then each one's specials
##   --laststand  the campfire goes out mid-stage, the enemies hunt the cat, the cat falls: the Gloom Raid, then
##               clearing the crusted building and mending the defences

var main
var shots := "user://autotest"
var report: Array = []
var _t0 := 0.0


func _ready() -> void:
	for a in Data.args():
		if a.begins_with("--shots="):
			shots = a.substr(8)
	DirAccess.make_dir_recursive_absolute(shots)
	_t0 = Time.get_ticks_msec() / 1000.0
	_run.call_deferred()


func _log(step: String, extra := {}) -> void:
	var d := {"t": snappedf(Time.get_ticks_msec() / 1000.0 - _t0, 0.01), "step": step, "leaves": Save.leaves, "timber": Save.timber,
		"cat_hp": main.player.hp, "cat": [snappedf(main.player.global_position.x, 0.01), snappedf(main.player.global_position.z, 0.01)],
		"stage": main.fight.active, "wave": main.fight.wave, "in_wave": main.fight.in_wave, "gate": main.fight.gate_hp,
		"foes": get_tree().get_nodes_in_group("foes").size(), "fps": Engine.get_frames_per_second()}
	d.merge(extra)
	report.append(d)
	print("AUTOTEST ", JSON.stringify(d))


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(shots.path_join(name + ".png"))
	_log("shot " + name)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _go_to(p: Vector3, tol := 0.25, timeout := 15.0) -> bool:
	# through the gate when going in or out of the camp, as a player would
	var w = main.world
	return await _go_straight(p, tol, timeout)


func _go_straight(p: Vector3, tol := 0.25, timeout := 15.0) -> bool:
	var j = main.joystick
	j.force = true
	var t := 0.0
	var last: Vector3 = main.player.global_position
	var check := 0.0
	var side := 0.0
	while t < timeout:
		var d: Vector3 = p - main.player.global_position
		d.y = 0.0
		if d.length() < tol:
			break
		var v := Vector2(d.x, d.z).normalized()
		if side > 0.0:                                  # stuck on something: step round it, as a player would
			v = (v + Vector2(-v.y, v.x) * 1.4).normalized()
			side -= get_process_delta_time()
		j.forced = v * clampf(d.length() * 1.5, 0.35, 1.0)
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += dt
		check += dt
		if check > 0.4:
			if main.player.global_position.distance_to(last) < 0.08:
				side = 0.6
			last = main.player.global_position
			check = 0.0
	j.forced = Vector2.ZERO
	await get_tree().process_frame
	return t < timeout


func _press(label: String, index := 0) -> bool:
	var found := 0
	for b in main.hud.card_buttons():
		if String(b.get_meta("label", "")) == label and not b.disabled:
			if found == index:
				b.pressed.emit()
				_log("pressed " + label)
				return true
			found += 1
	_log("no button " + label)
	return false


## H4: building goes through the build menu now (the Hearthtree's card has no Build tiles). Opens the menu at `id`'s
## detail view (the first building that is open and affordable when `id` is ""), the way a goal's Show does, and
## presses the detail view's Build. Returns the id it built ("" when nothing was on offer or Build did not press).
func _build_from_menu(id := "") -> String:
	var menu = main.hud.windows["build"]
	var pick := id
	if pick == "":
		for e: Dictionary in menu.entries():
			if String(e["state"]) == "open" and Data.can_afford(e["price"] as Dictionary):
				pick = String(e["id"])
				break
	if pick == "":
		_log("build menu: nothing open and affordable")
		return ""
	menu.open_at(pick)
	await _wait(0.3)
	var ok: bool = _press("Build")
	await _wait(0.3)
	_log("built from the menu", {"id": pick, "ok": ok, "level": Data.station_level(pick)})
	return pick if ok and Data.station_level(pick) > 0 else ""


# ---------------------------------------------------------------- taps (19 Nov 2026: cards open by a tap, as dialogs)
var tap_misses := 0                       # taps that had to fall back (the marker hidden, or another one in the way)


## A real tap at a point of the HUD (720 wide): a finger down and up through Input, as on the phone. The joystick,
## interact.gd (the marker under it) and the dialogs (their X, a tap outside) all see it the way they see a finger.
func _tap_at(p: Vector2) -> void:
	var w: Vector2 = get_viewport().get_final_transform() * p
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.position = w
	down.pressed = true
	Input.parse_input_event(down)
	await get_tree().process_frame
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.position = w
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame
	await get_tree().process_frame


## Taps a marker where it shows on the screen (its badge, else the thing itself) through the real input path:
## interact.gd picks it, and its card opens (or the cat walks there first). False (and a fallback through
## interact.use, logged) when no tap could reach it.
func _tap(ring) -> bool:
	if ring == null or not is_instance_valid(ring):
		return false
	var cam: Camera3D = main.cam
	var vis: Rect2 = get_viewport().get_visible_rect().grow(-8.0)
	var spots: Array = []
	var bp: Vector3 = ring.badge_pos()
	if not cam.is_position_behind(bp):
		spots.append(cam.unproject_position(bp))
	var body: Array = ring.body_px(cam)
	if not body.is_empty():
		spots.append(((body[0] as Vector2) + (body[1] as Vector2)) * 0.5)
	for sp in spots:
		if not vis.has_point(sp) or main.joystick._blocked(sp):
			continue
		var n0: int = main.interact.taps
		await _tap_at(sp)
		if main.interact.taps > n0:
			if main.hud.card_ring() == ring or main.interact.walking == ring:
				return true
			_log("tap hit another marker", {"want": String(ring.key), "got": String(main.hud.card_ring().key) if main.hud.card_ring() != null else ""})
			main.hud.hide_card()
			main.interact.stop_walk()
			break
	tap_misses += 1
	_log("tap fallback", {"ring": String(ring.key), "spots": str(spots)})
	main.interact.use(ring)
	return false


## The cat walks to a marker's spot (as before), then a tap on it: its card opens (an open one closes first).
func _use(ring, tol := 0.25, timeout := 15.0) -> bool:
	if main.hud.card_open():
		main.hud.hide_card()
	var ok: bool = await _go_to(ring.global_position, tol, timeout)
	await _tap(ring)
	await _until(func(): return main.hud.card_ring() == ring, 2.0)
	return ok


## The cat put on a marker's spot, the camera with it, then a tap on it: its card opens.
func _at_ring(ring) -> void:
	main.hud.hide_card()
	main.player.global_position = ring.global_position
	main.snap_camera()
	await get_tree().process_frame
	await get_tree().process_frame
	await _tap(ring)
	await _until(func(): return main.hud.card_ring() == ring, 2.0)


## Closes the open dialog with a real tap on its X.
func _tap_close() -> void:
	var b: Button = main.hud.close_button()
	if b != null:
		await _tap_at(b.get_global_rect().get_center())
		await _wait(0.2)


## Closes the open dialog with a real tap on the dimmed game outside it (above it, else below, else beside it).
func _tap_outside() -> void:
	var c: Control = main.hud._card
	if c == null:
		return
	var v: Vector2 = get_viewport().get_visible_rect().size
	var r: Rect2 = c.get_global_rect()
	var top: float = main.hud._safe.x
	var bottom: float = v.y - main.hud._safe.y
	var p := Vector2(v.x * 0.5, (top + r.position.y) * 0.5)
	if r.position.y - top < 50.0:
		p = Vector2(v.x * 0.5, (r.end.y + bottom) * 0.5)
		if bottom - r.end.y < 50.0:
			p = Vector2(r.position.x * 0.5, r.get_center().y)
	await _tap_at(p)
	await _wait(0.2)


func _run() -> void:
	await _wait(1.2)
	await _shot("01_camp_start")
	if Data.args().has("--grasswalk"):
		var spot = null
		for h in main.world.hide_spots:
			if h[2] == "grass":
				spot = h
				break
		var c: Vector3 = spot[0]
		main.player.global_position = c + Vector3(-spot[1] - 1.5, 0, 0)
		main.closeup = Vector3(0.0, 2.6, 3.6)
		await _wait(1.0)
		var j = main.joystick
		j.force = true
		j.forced = Vector2(0.55, 0.0)
		for k in 14:
			await _wait(0.2)
			await _shot("grasswalk_%02d" % k)
		j.forced = Vector2.ZERO
		for k in 5:
			await _wait(0.2)
			await _shot("grasswalk_after_%d" % k)
		_finish()
		return
	if Data.args().has("--lake"):
		var c: Vector3 = main.world.LAKE_C
		main.player.global_position = Vector3(-2.6, 0, 2.2)
		await _wait(1.5)
		await _shot("lake_camp")
		main.player.global_position = c + Vector3(0.5, 0, -3.2)
		await _wait(5.0)
		await _shot("lake_near")
		main.closeup = Vector3(1.5, 3.4, 4.6)
		await _wait(1.0)
		await _shot("lake_closeup")
		main.closeup = Vector3.ZERO
		# walk at the water: the cat must stop at the shore
		var j = main.joystick
		j.force = true
		j.forced = Vector2(c.x - main.player.global_position.x, c.z - main.player.global_position.z).normalized()
		await _wait(2.5)
		j.forced = Vector2.ZERO
		_log("walked into the lake", {"lake_dist": main.world.lake_dist(main.player.global_position)})
		await _shot("lake_shore_stop")
		_finish()
		return
	if Data.args().has("--meadow"):
		await _meadow()
		_finish()
		return
	if Data.args().has("--specials"):
		await _specials()
		_finish()
		return
	if Data.args().has("--grow"):
		await _grow()
		_finish()
		return
	if Data.args().has("--gallery"):
		await _gallery()
		_finish()
		return
	if Data.args().has("--village"):
		await _village()
		_finish()
		return
	if Data.args().has("--newfoes"):
		await _newfoes()
		_finish()
		return
	if Data.args().has("--laststand"):
		await _laststand()
		_finish()
		return
	if Data.args().has("--newfoes2"):
		await _newfoes2()
		_finish()
		return
	if Data.args().has("--siege"):
		await _siege()
		_finish()
		return
	if Data.args().has("--hero"):
		await _hero()
		_finish()
		return
	for a in Data.args():
		if a.begins_with("--resume="):
			await _resume(int(a.substr(9)))
			_finish()
			return
	if Data.args().has("--levels"):
		await _levels()
		_finish()
		return
	if Data.args().has("--skins"):
		await _skins()
		_finish()
		return
	if Data.args().has("--bars"):
		await _bars()
		_finish()
		return
	if Data.args().has("--perf"):
		await _perf()
		_finish()
		return
	if Data.args().has("--fishing"):
		await _fishing()
		_finish()
		return
	if Data.args().has("--camplife"):
		await _camplife()
		_finish()
		return
	if Data.args().has("--guardianab"):
		await _guardianab()
		_finish()
		return
	if Data.args().has("--guardian"):
		await _guardian()
		_finish()
		return
	if await _phase_d():
		_finish()
		return
	if await _phase_e():
		_finish()
		return
	if await _layout_hud():
		_finish()
		return
	if await _phase_f():
		_finish()
		return
	if Data.args().has("--smoke"):
		main.closeup = Vector3(0, 3.5, 5.0)
		await _wait(0.4)
		await _shot("02_cat_closeup")
		main.closeup = Vector3.ZERO
		_finish()
		return
	main.player.invincible = true
	var start_m := 0
	for a in Data.args():
		if a.begins_with("--patch=") or a.begins_with("--raid="):
			start_m = int(a.split("=")[1])
	if start_m > 0:
		_veteran(start_m)
		await _wait(0.5)
	# to the signpost, pick the mission
	await _use(main.stations.rings["sign"])
	await _wait(0.6)
	await _shot("02_sign_card")
	_press("Start")
	var lane0: int = int(Data.mission(start_m)["lanes"][0])
	var hold: Vector3 = main.world.edge_point(lane0) * 1.55
	await _go_to(hold, 0.4)
	Engine.time_scale = 2.0
	var t := 0.0
	var shots := {}
	var shopped := false
	var breaks := 0
	while main.fight.active and t < 1500.0:
		await _wait(0.5)
		t += 0.5
		var f = main.fight
		if f.in_wave:
			var e = main.nearest_enemy(main.player.global_position, 30.0)
			if e != null and e != main.stations.dummy:
				var want: Vector3 = hold + ((e.global_position as Vector3) - hold).limit_length(2.5)
				await _go_to(want, 0.5, 0.6)
			if fmod(t, 30.0) < 0.5 and f.wave_t > 20.0:
				var left: Array = []
				for fo in get_tree().get_nodes_in_group("foes"):
					left.append([fo.id, fo.state, snappedf(fo.global_position.x, 0.1), snappedf(fo.global_position.z, 0.1)])
				_log("wave status", {"wave": f.wave, "wave_t": snappedf(f.wave_t, 0.1), "queue": f._queue.size(), "foes_left": left})
			if not shots.has(f.wave) and f.wave_t > 8.0 and (f.wave == 1 or f.wave % 5 == 0):
				shots[f.wave] = true
				Engine.time_scale = 1.0
				await _shot("03_wave%02d_fight" % f.wave)
				_log("wave fight", {"wave": f.wave, "strength": f.strength(), "left": f.left_in_wave(), "buildings": main.stations.hp})
				Engine.time_scale = 2.0
		elif f.active:
			Engine.time_scale = 1.0
			_log("between waves", {"wave": f.wave, "break": f.on_break, "status": f.status_text(), "power": Data.power()})
			if f.on_break:
				breaks += 1
				await _shot("06_chapter%d_break" % breaks)
				_log("chapter break", {"run": Save.mission_run, "gate": f.gate_hp, "gate_max": f.gate_max})
				await _shop_round()
			if start_m == 0 and not shopped:
				shopped = true
				await _shot("04_breather")
				await _use(main.stations.rings["shop"])
				await _wait(0.8)
				await _shot("05a_shop_card")
				await _build_from_menu()
				await _wait(0.6)
			if main.fight.active and not main.fight.in_wave:
				await _use(main.stations.rings["sign"], 0.25, 10.0)
				await _wait(0.4)
				await _shot("07_sign_breather")
				_press("Start wave")
			await _go_to(hold, 0.4, 8.0)
			Engine.time_scale = 2.0
	Engine.time_scale = 1.0
	_log("raid over", {"time": t, "done": Save.missions_done, "claimed": Save.claimed, "items": Save.items})
	await _wait(1.0)
	await _shot("08_stage_end")
	await _wait(2.0)
	await _shot("09_gloom_lifted")
	await _go_to(Vector3(0.6, 0, 1.5), 0.4, 20.0)
	await _wait(1.0)
	await _shot("10_back_in_camp")
	if start_m > 0:
		_finish()
		return
	# build two barricade rows at the road spots of the first trail (Phase G2: rows of 3, built by tapping a road spot)
	var slots: Array = main.world.barricade_slots()
	var mine: Array = slots.filter(func(sl): return int(sl[2]) == lane0)
	for k in mini(2, mine.size()):
		var idx := 2                                     # the 4 nearest pads are the ones open at Hearthtree level 1-2
		var lane_k: int = (lane0 + k) % 4
		var sl: Array = main.world.barricade_slot(lane_k, idx)
		await _go_to((sl[0] as Vector3) + ((sl[0] as Vector3).normalized() * -1.4), 0.4, 20.0)
		await _wait(0.3)
		for cur in main.defences.row_cost():
			if Save.get(cur) != null and int(Save.get(cur)) < int(main.defences.row_cost()[cur]):
				Save.set(cur, int(main.defences.row_cost()[cur]))      # a mission-1 run may leave too little timber
		var built: bool = main.defences.build_row(lane_k, idx)
		_log("build_row", {"lane": lane_k, "idx": idx, "built": built})
		await _wait(0.5)
		if k == 0:
			await _shot("11_placing_barricade")
	await _wait(0.6)
	await _shot("12_barricades_built")
	_log("barricades", {"pieces": main.defences.pieces.size(), "rows": main.defences.rows_built(), "placed": Save.placed})
	_finish()


## Spend leaves the way a player would at a chapter break: whatever "Buy" is on offer at the Training Target and the
## shop.
func _shop_round() -> void:
	for id in ["target", "shop"]:
		var r = main.stations.rings.get(id)
		if r == null or not r.visible:
			continue
		await _use(r, 0.3, 10.0)
		await _wait(0.5)
		if id == "shop":
			_press("Cat")                        # H4: the Hearthtree's stats are on its Cat tab (it opens on the Hearthtree tab)
			await _wait(0.2)
		for k in 8:
			if not _press("Buy"):
				break
			await _wait(0.2)


## Saved at a chapter break, closed, opened again (two runs: --resume=1 with --fresh, then --resume=2 without it).
##   1: mission 1 to the end of its first chapter, then quit.
##   2: the save holds the run; the signpost offers "Go on"; it starts at wave 6; the camp falls and the run stays at
##      chapter 2; give up drops it.
func _resume(step: int) -> void:
	var f = main.fight
	if step == 1:
		main.player.invincible = true
		await _use(main.stations.rings["sign"])
		await _wait(0.5)
		_press("Start")
		var hold: Vector3 = main.world.edge_point(int(Data.mission(0)["lanes"][0])) * 1.55
		await _go_to(hold, 0.4)
		Engine.time_scale = 2.0
		var t := 0.0
		while f.active and not f.on_break and t < 400.0:
			await _wait(0.5)
			t += 0.5
			if f.in_wave:
				var e = main.nearest_enemy(main.player.global_position, 30.0)
				if e != null:
					await _go_to(hold + ((e.global_position as Vector3) - hold).limit_length(2.5), 0.5, 0.6)
			elif not f.on_break:
				f.next_phase_now()
		Engine.time_scale = 1.0
		_log("resume 1", {"wave": f.wave, "on_break": f.on_break, "run": Save.mission_run, "leaves": Save.leaves})
		return
	_log("resume 2 loaded", {"run": Save.mission_run, "active": f.active})
	await _use(main.stations.rings["sign"])
	await _wait(0.6)
	await _shot("resume_sign_card")
	_press("Start wave")
	await _wait(1.0)
	await _shot("resume_started")
	_log("resume 2 started", {"active": f.active, "wave": f.wave, "chapter": f.chapter(), "in_wave": f.in_wave, "status": f.status_text()})
	await _wait(2.0)
	f.camp_falls()
	await _wait(1.0)
	_log("resume 2 camp fell", {"active": f.active, "run": Save.mission_run, "fire_ruined": Save.fire_ruined})
	Save.fire_ruined = false
	main.world.set_fire_out(false)
	main.stations.set_fire_out(false)
	main.hud.hide_card()
	await _go_to(Vector3(0.5, 0, 2.5), 0.4)
	await _use(main.stations.rings["sign"])
	await _wait(0.6)
	_press("Give up")
	await _wait(0.4)
	await _shot("resume_gave_up")
	_log("resume 2 gave up", {"run": Save.mission_run})


## A player who has come this far: the missions before it won, a grown camp, a strong cat, barricades and a tower.
func _veteran(n: int) -> void:
	Save.missions_done = []
	for i in n:
		Save.missions_done.append(String(Data.mission(i)["id"]))
		for ln in Data.mission(i)["lanes"]:
			if not Save.claimed.has(int(ln)):
				Save.claimed.append(int(ln))
	Save.camp_level = mini(3, 1 + n / 3)
	Save.stations["target"] = Save.camp_level
	Save.stations["bench"] = Save.camp_level
	for st in ["damage", "draw", "health"]:
		Save.stats[st] = mini(3 * Save.camp_level, 8)
	Save.bows["sunwood"] = 4
	Save.bow = "sunwood"
	for k in ["shop_open", "shop_target", "shop_bench", "home", "first_stage_done"]:
		Save.set_flag(k)
	if n >= 1:                                          # Phase C: mission 1 gives the garden and its pot
		Save.stations["garden"] = 1
	if n >= 2:
		Save.stations["stall"] = 1
	if n >= 3:
		Save.stations["cottage"] = 1
	if n >= 4:
		Save.stations["well"] = 1
	if n >= 6:                                          # Phase C: mission 6 gives the Fishing Spot
		Save.stations["fishing"] = 1
	main.on_camp_grown()
	for sl in main.world.barricade_slots():
		if int(sl[3]) == 2:
			var sp := {"type": "barricade", "slot": [int(sl[2]), int(sl[3])]}
			Save.placed.append(sp)
			var pc: Dictionary = main.defences._spawn("barricade", sl[0], sl[1], [int(sl[2]), int(sl[3])])
			pc["src"] = sp                              # wrecks are saved into their own Save.placed entry
	var lane0: int = int(Data.mission(mini(n, Data.mission_count() - 1))["lanes"][0])
	var e: Vector3 = main.world.edge_point(lane0)
	var side := Vector3(-e.z, 0, e.x).normalized()
	main.defences._spawn("tower", e * 1.6 + side * 2.6, 0.0)
	main.player.apply_bow()
	main.world.rebuild_paths(true)
	main.stations.refresh("all")
	main.refresh_companions()


func _grow() -> void:
	Save.claimed = [0, 1, 2]
	Save.leaves = 5000
	Save.timber = 200
	Save.set_flag("shop_open")
	Save.set_flag("home")
	for lv in [1, 2, 3]:
		Save.stations["target"] = lv
		Save.stations["bench"] = lv
		Save.camp_level = lv
		Save.def_levels = {"barricade": lv, "tower": lv, "spikes": lv}
		main.on_camp_grown()
		for t in ["barricade", "tower", "spikes"]:
			main.defences.relevel(t)
		if lv == 1:
			var e0: Vector3 = main.world.edge_point(0)
			var side := Vector3(-e0.z, 0, e0.x).normalized()
			for sl in main.world.barricade_slots():
				if int(sl[3]) == 2:
					main.defences._spawn("barricade", sl[0], sl[1], [int(sl[2]), int(sl[3])])
			main.defences._spawn("tower", e0 * 1.9 + side * 3.2 + e0.normalized() * -0.8, 0.0)
			main.defences._spawn("spikes", e0 * 1.45, atan2(e0.x, e0.z))
		main.player.global_position = Vector3(0.8, 0, 1.6)
		await _wait(1.6)
		await _shot("grow_level%d_camp" % lv)
		main.player.global_position = main.world.edge_point(0) * 1.6
		await _wait(1.2)
		await _shot("grow_level%d_defences" % lv)


## Roads, grass, flowers, bushes and hiding.
func _meadow() -> void:
	var w = main.world
	var L: float = w.trail_length(0)
	main.player.global_position = w.trail_point(0, L * 0.6)
	await _wait(1.2)
	await _shot("meadow_road")
	main.player.global_position = w.trail_point(2, L * 0.35)
	await _wait(1.0)
	await _shot("meadow_road2")
	var grass_spot = null
	var bush_spot = null
	for h in w.hide_spots:
		if h[2] == "grass" and grass_spot == null:
			grass_spot = h
		if h[2] == "bush" and bush_spot == null:
			bush_spot = h
	main.player.global_position = grass_spot[0]
	await _wait(2.2)
	await _shot("meadow_hidden_grass")
	_log("hidden in grass", {"hidden": main.hidden, "ambush": main.ambush_ready})
	var e = main.fight.spawn("thornling", grass_spot[0] + Vector3(3.2, 0, 0.5), 0)
	e.hp = 1e9
	await _wait(2.0)
	_log("thornling near hidden cat", {"state": e.state, "dist": e.global_position.distance_to(main.player.global_position)})
	e.queue_free()
	main.player.global_position = bush_spot[0]
	await _wait(0.5)
	await _shot("meadow_bush")
	_log("in bush", {"hidden": main.hidden})
	main.closeup = Vector3(0, 3.0, 4.4)
	main.player.global_position = grass_spot[0] + Vector3(0, 0, grass_spot[1] - 0.3)
	await _wait(1.0)
	await _shot("meadow_closeup")
	main.closeup = Vector3.ZERO


## Each enemy near the cat, free to act, so its attacks and special show (screenshots every 0.35 s).
func _specials() -> void:
	main.player.invincible = true
	var cat := Vector3(0.0, 0, -8.5)
	var plan := {"thornling": [Vector3(0.4, 0, -10.6), 2.0], "brute": [Vector3(0.6, 0, -10.4), 2.4],
		"raccoon": [Vector3(3.0, 0, -11.0), 2.4], "boar": [Vector3(0.5, 0, -14.0), 2.4], "bear": [Vector3(0.5, 0, -15.0), 3.2]}
	for kind in plan:
		main.player.global_position = cat
		main.player.facing = PI
		var e = main.fight.spawn(kind, plan[kind][0], 0)
		e.hp = 1e9
		e.max_hp = 1e9
		e._cd4 = 0.0
		e._cd2 = 0.0
		e._cd3 = 99.0
		if kind == "raccoon":
			main.drop_leaves(Vector3(1.6, 0, -10.0), 10)
		var t := 0.0
		var k := 0
		while t < float(plan[kind][1]):
			await _wait(0.35)
			t += 0.35
			main.player.global_position = cat
			await _shot("special_%s_%d" % [kind, k])
			k += 1
		_log("special " + kind, {"state": e.state})
		e.queue_free()
		for pk in get_tree().get_nodes_in_group("pickups"):
			pk.queue_free()
		await _wait(0.3)


## One of each enemy in front of the cat, close up, walking and attacking.
func _gallery() -> void:
	main.player.invincible = true
	main.player.global_position = Vector3(0, 0, -6.0)
	main.closeup = Vector3(0.0, 3.6, 5.2)
	for kind in ["thornling", "brute", "raccoon", "boar", "bear"]:
		var e = main.fight.spawn(kind, Vector3(0.6, 0, -8.6), 0)
		e.set_physics_process(false)
		e.hp = 1e9
		e.rotation.y = 0.5
		var clips: Array = []
		if e.anim:
			clips = Array(e.anim.get_animation_list())
			e.anim.play("Walk")
		await _wait(1.2)
		await _shot("gallery_%s_walk" % kind)
		if e.anim and e.anim.has_animation("Attack"):
			e.anim.play("Attack")
			await _wait(e.anim.get_animation("Attack").length * 0.45)
			await _shot("gallery_%s_attack" % kind)
		_log("gallery " + kind, {"has_model": e.anim != null, "clips": clips, "radius": e.radius})
		e.queue_free()
		await _wait(0.2)
	main.closeup = Vector3.ZERO


## The village: build all three, look at their cards, ride Thistle out with Sprig, fight a wave of Moonmoth Hollow,
## then watch the Well mend a hurt campfire.
func _village() -> void:
	main.player.invincible = true
	Save.claimed = [0, 1, 2, 3]
	Save.leaves = 3000
	Save.timber = 60
	for k in ["shop_open", "shop_target", "shop_bench", "home", "first_stage_done"]:
		Save.set_flag(k)
	Save.missions_done = ["embers", "bramble", "toadstool", "stumps"]
	Save.camp_level = 3
	main.on_camp_grown()
	main.stations.gift("stall")
	main.stations.gift("cottage")
	await _use(main.stations.rings["shop"])
	await _wait(0.8)
	await _shot("village_00_shop")
	for k in 5:
		await _build_from_menu()
		await _wait(0.4)
	await _wait(1.2)                                         # the camera's shot at the last new building ends first
	_log("village built", {"stations": Save.stations, "pet": main.pet != null, "mount": main.mount != null})
	main.player.global_position = Vector3(0.3, 0, 2.2)
	await _wait(1.5)
	await _shot("village_01_camp")
	main.closeup = Vector3(0.0, 4.2, 6.2)
	await _wait(0.6)
	await _shot("village_02_closeup")
	if main.trader != null:
		main.closeup_at = main.trader
		await _wait(0.3)
		var tf: Vector3 = main.trader.global_transform.basis.z.normalized()
		main.closeup = tf * 3.0 + tf.cross(Vector3.UP) * 1.0 + Vector3(0, 1.3, 0)
		await _wait(0.05)
		await _shot("village_02b_trader")
		main.closeup_at = null
	main.closeup = Vector3.ZERO
	for id in ["well", "cottage", "stall"]:
		await _use(main.stations.rings[id], 0.25, 12.0)
		await _wait(0.9)
		await _shot("village_card_" + id)
		if id == "cottage":
			_press("Use")
			await _wait(0.6)
			_log("pet look", {"look": Save.pet_look})
	_press("Use")
	await _wait(0.6)
	_log("mount look", {"look": Save.mount_look})
	await _shot("village_card_stall_ram")
	_press("Ride")
	await _wait(0.8)
	_log("riding", {"riding": main.player.riding})
	main.closeup = Vector3(0.0, 3.0, 4.4)
	await _wait(0.3)
	await _shot("village_03_ride_closeup")
	main.closeup = Vector3(3.4, 1.6, 0.4)
	await _wait(0.3)
	await _shot("village_03b_ride_side")
	main.closeup = Vector3.ZERO
	var hold: Vector3 = main.world.edge_point(0) * 1.6
	await _go_to(hold, 0.4)
	await _shot("village_04_ride_out")
	main.start_stage(4)
	await _wait(0.5)
	var t := 0.0
	var k := 0
	while main.fight.in_wave and t < 80.0:
		await _wait(0.5)
		t += 0.5
		var e = main.nearest_enemy(main.player.global_position, 30.0)
		if e != null and e != main.stations.dummy:
			await _go_to(hold + ((e.global_position as Vector3) - hold).limit_length(2.0), 0.5, 0.6)
		if int(t) % 4 == 0 and k < 6 and fmod(t, 1.0) == 0.0:
			await _shot("village_05_fight_%d" % k)
			if k == 2 or k == 3:
				main.closeup = Vector3(2.2, 2.2, 3.4) if k == 2 else Vector3(-3.0, 1.8, -1.5)
				await _wait(0.1)
				await _shot("village_05b_fight_closeup_%d" % k)
				main.closeup = Vector3.ZERO
			k += 1
	_log("wave 1 of hollow over", {"time": t, "in_wave": main.fight.in_wave})
	main.fight.gate_hp = main.fight.gate_max * 0.4
	var before: float = main.fight.gate_hp
	await _use(main.stations.rings["well"], 0.25, 20.0)
	await _wait(0.8)
	await _shot("village_06_well_card")
	# Phase G2: no wish any more; the built Well mends the hurt campfire by itself between waves
	for i in 40:
		main.stations.well_tick(0.5)
	_log("well mends", {"gate_before": before, "gate_after": main.fight.gate_hp, "mended": main.fight.gate_hp > before})
	await _shot("village_07_after_well_mend")
	await _use(main.stations.rings["stall"], 0.25, 12.0)
	await _wait(0.6)
	_press("Sell")
	_press("Walk")
	await _wait(1.5)
	_log("walk again", {"riding": main.player.riding, "timber": Save.timber})
	await _shot("village_08_thistle_home")


## The five later enemies: close up walking, then each near the cat so its tricks show.
func _newfoes() -> void:
	main.player.invincible = true
	main.player.global_position = Vector3(0, 0, -6.0)
	main.closeup = Vector3(0.0, 3.6, 5.2)
	for kind in ["moth", "frog", "beetle", "snail", "owl"]:
		var e = main.fight.spawn(kind, Vector3(0.6, 0, -8.6), 0)
		e.set_physics_process(false)
		e.hp = 1e9
		e.rotation.y = 0.5
		if e.flyer:
			e._body.position.y = e.fly_h
		if e.anim:
			e.anim.play("Walk")
		await _wait(1.2)
		await _shot("newfoe_%s" % kind)
		_log("newfoe " + kind, {"has_model": e.anim != null, "radius": e.radius, "aim": e.aim_height})
		e.queue_free()
		await _wait(0.2)
	main.closeup = Vector3.ZERO
	var cat := Vector3(0.0, 0, -8.5)
	var plan := {"moth": [Vector3(0.4, 0, -11.0), 2.8], "frog": [Vector3(0.6, 0, -12.5), 3.2],
		"beetle": [Vector3(0.5, 0, -13.0), 3.2], "snail": [Vector3(0.5, 0, -10.0), 3.2], "owl": [Vector3(0.5, 0, -14.0), 5.6]}
	for kind in plan:
		main.player.global_position = cat
		main.player.facing = PI
		var e = main.fight.spawn(kind, plan[kind][0], 0)
		e.hp = 1e9
		e.max_hp = 1e9
		e._cd4 = 0.0
		e._cd2 = 0.0
		e._cd3 = 99.0 if kind != "owl" else 3.0
		e._cd5 = 0.0
		if kind == "beetle":
			e._cd4 = 2.5                         # march in with the shield up first, then bash
		if kind == "frog":
			var hurt = main.fight.spawn("thornling", plan[kind][0] + Vector3(1.0, 0, 0), 0)
			hurt.hp = hurt.max_hp * 0.3
			hurt.set_physics_process(false)
		var t := 0.0
		var k := 0
		var hp0: float = e.hp
		while t < float(plan[kind][1]):
			await _wait(0.35)
			t += 0.35
			main.player.global_position = cat
			await _shot("newspecial_%s_%d" % [kind, k])
			k += 1
		_log("newspecial " + kind, {"state": e.state, "hp_lost": hp0 - e.hp, "foes": get_tree().get_nodes_in_group("foes").size(),
			"slime": get_tree().get_nodes_in_group("slime").size()})
		for f in get_tree().get_nodes_in_group("foes"):
			f.queue_free()
		for pk in get_tree().get_nodes_in_group("pickups"):
			pk.queue_free()
		await _wait(0.3)
	# the Beetle Knight's shield: an arrow from the front against one from the side
	var b = main.fight.spawn("beetle", Vector3(0, 0, -12.0), 0)
	b.set_physics_process(false)
	b.rotation.y = 0.0                                  # facing +Z, toward the cat
	var h0: float = b.hp
	b.hit(Vector3(0, 0, -1), 10.0)                      # flying -Z: comes at its face
	var front: float = h0 - b.hp
	h0 = b.hp
	b.hit(Vector3(1, 0, 0), 10.0)                       # from its side
	_log("shield", {"front": front, "side": h0 - b.hp})
	b.queue_free()


## The six mission enemies doing their thing: a pitcher spitting at a tower, a mole digging under a barricade, a
## puffball bursting on the home, a crow drumming for a thornling, a stump at the bench, the Thornstag charging.
func _newfoes2() -> void:
	main.player.invincible = true
	_veteran(4)
	await _wait(0.3)
	main.start_stage(1)
	await _wait(0.4)
	main.fight.set_physics_process(false)
	for f in get_tree().get_nodes_in_group("foes"):
		f.queue_free()
	var e0: Vector3 = main.world.edge_point(0).normalized()
	var tw: Dictionary = main.defences._spawn("tower", e0 * 9.0 + Vector3(-e0.z, 0, e0.x) * 2.5, 0.0)
	var slot: Array = main.world.barricade_slot(0, 1)
	var foes := {}
	foes["pitcher"] = main.fight.spawn("pitcher", (tw["pos"] as Vector3) + e0 * 5.0, 0)
	foes["mole"] = main.fight.spawn("mole", main.world.trail_point(0, main.world.trail_progress(0, slot[0]) - 2.5), 0)
	foes["puffball"] = main.fight.spawn("puffball", main.world.station_pos("home") + Vector3(0, 0, -2.6), 0)
	foes["crow"] = main.fight.spawn("crow", Vector3(4.0, 0, 6.5), 2)
	foes["thornling"] = main.fight.spawn("thornling", Vector3(4.8, 0, 6.0), 2)
	foes["stump"] = main.fight.spawn("stump", main.world.station_pos("bench") + Vector3(1.6, 0, -1.6), 2)
	foes["stag"] = main.fight.spawn("stag", Vector3(-2.0, 0, 13.0), 1)
	for k in foes:
		foes[k].hp = 1e6 if k != "puffball" else foes[k].hp
		foes[k].max_hp = maxf(foes[k].max_hp, foes[k].hp)
	main.player.global_position = Vector3(-2.0, 0, 6.0)
	var tw0: float = tw["hp"]
	var home0: float = main.stations.hp.get("home", 0.0)
	var states := {}
	for k in 14:
		await _wait(0.5)
		main.player.global_position = Vector3(-2.0, 0, 6.0)
		for n in foes:
			if is_instance_valid(foes[n]):
				var st: String = foes[n].state
				if not states.has(n):
					states[n] = []
				if not (states[n] as Array).has(st):
					states[n].append(st)
		if k % 4 == 1:
			await _shot("newfoes2_%d" % k)
			for n in ["stump", "pitcher", "puffball", "crow", "mole", "stag"]:
				if is_instance_valid(foes[n]) and foes[n].visible:
					var h := float(foes[n].info.get("height", 1.0))
					main.closeup_at = foes[n]
					main.closeup = Vector3(1.6, 1.5, 2.6) * maxf(h, 0.9) * 1.6
					await _wait(0.05)
					await _shot("nf2_%s_%d" % [n, k])
			main.closeup_at = null
			main.closeup = Vector3.ZERO
	_log("newfoes2", {"states": states, "tower_hp": [tw0, tw["hp"]], "home_hp": [home0, main.stations.hp.get("home", 0.0)],
		"mole_past": is_instance_valid(foes["mole"]) and main.world.trail_progress(0, foes["mole"].global_position) > main.world.trail_progress(0, slot[0]),
		"thornling_buff": foes["thornling"].buff_t if is_instance_valid(foes["thornling"]) else -1.0, "ruined": Save.ruined})


## Enemies near the camp with the cat far away: they must go for buildings, towers and the campfire.
func _siege() -> void:
	main.player.invincible = true
	_veteran(4)
	await _wait(0.3)
	main.start_stage(1)
	await _wait(0.5)
	main.fight.set_physics_process(false)                  # no new enemies: only the ones placed here
	for f in get_tree().get_nodes_in_group("foes"):
		f.queue_free()
	main.player.global_position = Vector3(0, 0, 17.5)        # far south, out of range
	var hp0: Dictionary = main.stations.hp.duplicate()
	var gate0: float = main.fight.gate_hp
	for it in [["brute", Vector3(3.5, 0, -5.5)], ["stump", Vector3(-3.0, 0, -5.0)], ["thornling", Vector3(0.5, 0, -6.5)], ["moth", Vector3(5.0, 0, -4.0)]]:
		var e = main.fight.spawn(it[0], it[1], 0)
		e.hp = 1e6
		e.max_hp = 1e6
	main.closeup = Vector3(0.0, 9.0, 8.5)
	main.player.global_position = Vector3(0, 0, 17.5)
	for k in 8:
		await _wait(2.0)
		main.player.global_position = Vector3(0, 0, 17.5)
		if k % 2 == 1:
			main.closeup = Vector3.ZERO
			main.player.global_position = Vector3(0, 0, 3.0)
			main.player.invincible = true
			await _wait(0.05)
			await _shot("siege_%d" % k)
			main.player.global_position = Vector3(0, 0, 17.5)
	var states: Array = []
	for f in get_tree().get_nodes_in_group("foes"):
		states.append([f.id, f.state, snappedf((f.global_position as Vector3).length(), 0.1)])
	_log("siege", {"hp_before": hp0, "hp_after": main.stations.hp, "gate_before": gate0, "gate_after": main.fight.gate_hp,
		"ruined": Save.ruined, "foes": states, "towers": main.defences.tower_targets().size()})


## The campfire goes out, the cat rebuilds it on the ashes, it goes out again: the camp falls. Then repair a ruin,
## rebuild the campfire and mend the defences.
func _laststand() -> void:
	main.player.invincible = true
	_veteran(4)
	Save.leaves = 1000
	Save.timber = 40
	await _wait(0.3)
	main.fight.skip_gate = true                            # mission 2 is won here (no replays since Phase F): let it start
	main.start_stage(1)
	main.fight.skip_gate = false
	await _wait(2.0)
	main.fight.damage_fire(int(main.fight.gate_hp) + 1, Vector3(0, 0, -5))
	await _wait(1.0)
	_log("fire out", {"last_stand": main.fight.last_stand, "fire_out": main.world.fire_out, "camp_safe": main.world.inside_camp(Vector3(0, 0, 1))})
	await _shot("laststand_01_fire_out")
	await _go_to(Vector3(0, 0, 1.0), 0.3, 10.0)
	main.player.global_position = Vector3(0, 0, 1.05)
	await _wait(1.5)
	await _shot("laststand_02_rebuilding")
	await _wait(3.5)
	_log("rebuilt", {"rebuilt": main.fight.rebuilt, "last_stand": main.fight.last_stand, "gate": main.fight.gate_hp, "timber": Save.timber, "fire_out": main.world.fire_out})
	await _shot("laststand_03_rebuilt")
	# a building knocked down, a barricade broken, then the fire falls again: the camp falls
	main.stations.hurt_building("target", 99999)
	for pc in main.defences.pieces:
		if pc["type"] == "barricade":
			main.defences.hurt_piece(int(pc["id"]), 99999)
			break
	main.collect_leaves(100, Vector3(0, 0, 1.0))           # leaves picked up in this chapter
	var before := Save.leaves
	var gain: int = main.fight.chapter_gain()
	main.fight.damage_fire(int(main.fight.gate_hp) + 1, Vector3(0, 0, -5))
	# 21 Nov 2026: the fall takes raid.leaves_share of the leaves gained in this chapter only (the 1000 saved before it
	# are safe), never more than the cat holds
	var lost_want := mini(before, int(floor(gain * float(Data.b["raid"]["leaves_share"]))))
	_expect("the camp fell: the Gloom took %d of the %d leaves this chapter gained, none of the 1000 saved before" % [lost_want, gain],
		not main.fight.active and Save.fire_ruined and gain >= 100 and int(main.fight.last_fall_lost) == lost_want and before - lost_want >= 1000,
		{"before": before, "gain": gain, "lost": main.fight.last_fall_lost})
	await _wait(1.0)
	_log("camp fell", {"active": main.fight.active, "fire_ruined": Save.fire_ruined, "leaves_before": before, "leaves_after": Save.leaves,
		"ruined": Save.ruined, "wrecked": main.defences.wrecked_count(), "fire_out": main.world.fire_out})
	await _shot("laststand_04_camp_fell")
	await _use(main.stations.rings["sign"], 0.25, 15.0)
	await _wait(0.8)
	await _shot("laststand_05_sign_needs_fire")
	await _use(main.stations.rings["target"], 0.25, 15.0)
	await _wait(0.8)
	await _shot("laststand_06_ruin_card")
	_press("Repair")
	await _wait(0.5)
	await _use(main.stations.rings["fire"], 0.25, 15.0)
	await _wait(0.8)
	await _shot("laststand_07_fire_card")
	_press("Rebuild")
	await _wait(0.8)
	await _use(main.stations.rings["shop"], 0.25, 15.0)
	await _wait(0.8)
	_press("Defences")                       # H4: "Mend the defences" is on the Hearthtree's Defences tab
	await _wait(0.3)
	_press("Mend")
	await _wait(0.5)
	_log("restored", {"ruined": Save.ruined, "fire_ruined": Save.fire_ruined, "fire_out": main.world.fire_out, "wrecked": main.defences.wrecked_count(), "leaves": Save.leaves, "timber": Save.timber})
	await _shot("laststand_08_restored")


func _finish() -> void:
	_log("done", {"claimed": Save.claimed, "stats": Save.stats, "stations": Save.stations})
	var f := FileAccess.open(shots.path_join("report.json"), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report, "  "))
	get_tree().quit()


## The hero close up (run it with --cat1 and with --cat2 to compare the two models): standing, walking, shooting
## at a dummy enemy, from the front, the side and the game camera.
func _hero() -> void:
	main.player.invincible = true
	main.player.global_position = Vector3(0.0, 0, 3.0)
	await _wait(1.0)
	for v in [["front", Vector3(0.0, 1.0, 2.6)], ["three_quarter", Vector3(1.8, 1.1, 1.9)], ["side", Vector3(2.6, 0.9, 0.0)], ["back", Vector3(-1.2, 1.2, -2.3)]]:
		main.closeup = (v[1] as Vector3).rotated(Vector3.UP, main.player.facing)
		await _wait(0.2)
		await _shot("hero_idle_" + String(v[0]))
	main.closeup = Vector3.ZERO
	await _wait(0.4)
	await _shot("hero_idle_game")
	main.start_stage(1)
	await _wait(0.4)
	main.fight.set_physics_process(false)
	for f in get_tree().get_nodes_in_group("foes"):
		f.queue_free()
	var foe = main.fight.spawn("thornling", main.player.global_position + Vector3(0.0, 0, -5.5), 0)
	foe.hp = 1e6
	foe.max_hp = 1e6
	foe.set_physics_process(false)
	foe.set_process(false)
	for k in 6:
		main.closeup = ([Vector3(1.6, 1.0, 1.6), Vector3(-1.6, 1.0, 1.6), Vector3(0.0, 1.0, 2.6)][k % 3] as Vector3).rotated(Vector3.UP, main.player.facing)
		await _wait(0.13 + 0.07 * k)
		await _shot("hero_shoot_%d" % k)
	main.closeup = Vector3.ZERO
	await _wait(0.3)
	await _shot("hero_shoot_game")
	_log("hero", {"model": main.player.hero_base()})



## Frame cost, for tuning the graphics levels: the built-up camp standing still, the cat walking through the meadow,
## and a big fight (18 enemies that never die, the cat shooting). Run it with --quality=low|medium|high to compare.
## Logs "PERF {...}" lines and writes perf.json next to the screenshots.
func _perf() -> void:
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	main.player.invincible = true
	_veteran(6)
	if Data.args().has("--warden"):                     # Phase C: the same run with the Moss Warden at the camp
		main.stations.free_guardian()
	await _wait(1.0)
	var info := {"adapter": RenderingServer.get_video_adapter_name(), "vendor": RenderingServer.get_video_adapter_vendor(),
		"method": RenderingServer.get_current_rendering_method() if RenderingServer.has_method("get_current_rendering_method") else "?",
		"window": DisplayServer.window_get_size(), "scale_3d": get_viewport().scaling_3d_scale, "msaa": get_viewport().msaa_3d,
		"cpus": OS.get_processor_count(), "model": OS.get_model_name(),
		"quality": get_node("/root/Quality").level if has_node("/root/Quality") else -1}
	_log("perf info", info)
	var out := {"info": info}
	main.player.global_position = Vector3(0, 0, main.world.camp_r * 0.42)
	await _wait(2.0)
	out["camp"] = await _measure("camp", 6.0)
	await _shot("perf_camp")
	if Data.args().has("--perfdiag"):
		await _perf_diag_camp()
	var j = main.joystick
	j.force = true
	out["walk"] = await _measure("walk", 6.0, func(t: float): j.forced = Vector2(cos(t * 0.9), sin(t * 0.9)) * 0.8)
	j.forced = Vector2.ZERO
	j.force = false
	main.start_stage(5)
	await _wait(0.5)
	main.fight.set_physics_process(false)                  # only the enemies placed here
	for f in get_tree().get_nodes_in_group("foes"):
		f.queue_free()
	var at := Vector3(0, 0, 9.0)
	main.player.global_position = at
	var kinds := ["thornling", "thornling", "thornling", "thornling", "boar", "boar", "brute", "brute", "moth", "moth",
		"stump", "pitcher", "mole", "puffball", "crow", "frog", "beetle", "stag"]
	for k in kinds.size():
		var a := TAU * k / kinds.size()
		var e = main.fight.spawn(kinds[k], at + Vector3(cos(a), 0, sin(a)) * randf_range(4.5, 7.5), 0)
		if e:
			e.hp = 1e6
			e.max_hp = 1e6
	await _wait(2.0)
	out["fight"] = await _measure("fight", 8.0, func(_t: float): main.player.global_position = main.player.global_position.lerp(at, 0.02))
	await _shot("perf_fight")
	main.closeup = Vector3(0.0, 5.0, 6.0)
	await _wait(0.3)
	await _shot("perf_fight_close")
	main.closeup = Vector3.ZERO
	if Data.args().has("--perfdiag"):
		var foes := get_tree().get_nodes_in_group("foes")
		for e in foes:
			e.set_physics_process(false)
			e.set_process(false)
		await _measure("fight_no_foe_logic", 4.0)
		for e in foes:
			var ap = e.get("anim")
			if ap:
				ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		await _measure("fight_no_foe_logic_no_anim", 4.0)
		for e in foes:
			e.visible = false
		await _measure("fight_foes_hidden", 4.0)
	out["pools"] = Pools.stats()                           # H1: how many pooled objects the run made and reused
	_log("perf pools", out["pools"])
	var f := FileAccess.open(shots.path_join("perf.json"), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(out, "  "))


func _measure(label: String, secs: float, each := Callable()) -> Dictionary:
	var vp := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	await get_tree().process_frame
	var dts: Array = []
	var sums := {"cpu_max": 0.0, "rcpu": 0.0, "gpu": 0.0, "draws": 0.0, "prims": 0.0, "objs": 0.0}
	var t := 0.0
	while t < secs:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += dt
		dts.append(dt * 1000.0)
		if each.is_valid():
			each.call(t)
		sums["cpu_max"] += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		sums["rcpu"] += RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu()
		sums["gpu"] += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		sums["draws"] += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		sums["prims"] += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		sums["objs"] += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	var n := float(dts.size())
	dts.sort()
	var r := {"fps": snappedf(n / t, 0.1), "frame_ms": snappedf(t * 1000.0 / n, 0.01),
		"p95_ms": snappedf(float(dts[int(n * 0.95) - 1]), 0.01),
		"foes": get_tree().get_nodes_in_group("foes").size(),
		"vmem_mb": snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.1),
		"mem_mb": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1)}
	for k in sums:
		r[k] = snappedf(sums[k] / n, 0.01)
	print("PERF ", label, " ", JSON.stringify(r))
	return r


## Which parts cost the most in the camp: switch them off one after another (--perfdiag).
func _perf_diag_camp() -> void:
	var cl = main.player.cloth
	if cl and cl.fit:
		cl.fit.active = false
	await _measure("camp_no_cloth_fit", 4.0)
	if cl and cl.sim:
		cl.sim.active = false
	await _measure("camp_no_cloth", 4.0)
	for n in [main.pet, main.mount, main.trader, main.guardian, main.fishing]:
		if n:
			n.process_mode = Node.PROCESS_MODE_DISABLED
	await _measure("camp_no_companions", 4.0)
	main.hud.process_mode = Node.PROCESS_MODE_DISABLED
	main.stations.process_mode = Node.PROCESS_MODE_DISABLED
	main.world.lake.process_mode = Node.PROCESS_MODE_DISABLED
	await _measure("camp_no_hud_stations_lake", 4.0)
	main.player.process_mode = Node.PROCESS_MODE_DISABLED
	await _measure("camp_no_player", 4.0)
	main.process_mode = Node.PROCESS_MODE_DISABLED
	self.process_mode = Node.PROCESS_MODE_ALWAYS
	await _measure("camp_all_logic_off", 4.0)
	main.process_mode = Node.PROCESS_MODE_INHERIT
	for n in [main.pet, main.mount, main.trader, main.guardian, main.fishing, main.hud, main.stations, main.world.lake, main.player]:
		if n:
			n.process_mode = Node.PROCESS_MODE_INHERIT
	if cl and cl.sim:
		cl.sim.active = true
	if cl and cl.fit:
		cl.fit.active = true



## The health bars over the cat and the mount (--bars): full, just hit (grey trail), riding, the mount hit, the mount
## knocked out (the cat is thrown off and cannot ride while it rests).
func _bars() -> void:
	_veteran(3)
	await _wait(0.5)
	main.player.global_position = Vector3(0, 0, 8.0)        # out of the camp, where hits land
	await _wait(3.0)
	await _shot("bars_game_full")
	main.player.hurt(main.player.global_position + Vector3(1, 0, 0), 1)
	await _wait(0.12)
	await _shot("bars_game_hit")
	main.player._invuln = 0.0
	main.closeup = Vector3(0.0, 4.5, 6.0)
	await _wait(0.8)
	await _shot("bars_full")
	main.player.hurt(main.player.global_position + Vector3(1, 0, 0), 2)
	await _wait(0.12)
	await _shot("bars_hit")
	await _wait(1.6)
	await _shot("bars_after")
	main.set_riding(true, false)
	await _wait(0.8)
	await _shot("bars_riding")
	main.player._invuln = 0.0
	main.player.hurt(main.player.global_position + Vector3(1, 0, 0), 3)
	await _wait(0.12)
	await _shot("bars_mount_hit")
	_log("bars", {"cat_hp": main.player.hp, "cat_max": Data.cat_max_hp(), "mount_hp": main.mount.hp, "mount_max": main.mount.max_hp(), "riding": main.player.riding})
	main.player._invuln = 0.0
	main.player.hurt(main.player.global_position + Vector3(1, 0, 0), 20)
	await _wait(0.6)
	main.set_riding(true)
	await _wait(0.3)
	await _shot("bars_mount_out")
	_log("mount out", {"riding": main.player.riding, "resting": main.mount.resting, "mount_hp": main.mount.hp, "cat_hp": main.player.hp})
	main.mount.refill()
	main.set_riding(true, false)
	_log("mount refilled", {"riding": main.player.riding, "mount_hp": main.mount.hp})


## Every skin of the mount and the pet, riding, close up (--skins); then the other looks (Bramblewool, Lumi).
func _skins() -> void:
	_veteran(3)
	await _wait(0.5)
	main.player.global_position = Vector3(0, 0, 2.5)
	main.set_riding(true, false)
	main.closeup = Vector3(0.0, 3.2, 4.6)
	for pair in [["thistle", "sprig"], ["bramblewool", "lumi"]]:
		main.stations._use_look("mount", pair[0])
		main.stations._use_look("pet", pair[1])
		Save.mount_skin = "natural"
		Save.pet_skin = "natural"
		main.mount.set_look()
		main.pet.set_look()
		for k in 5:
			await _wait(1.0)
			main.pet.global_position = main.player.global_position + Vector3(0.9, 0, 0.6)
			await _wait(0.4)
			await _shot("skin_%s_%d" % [pair[0], k])
			_log("skin", {"mount": Save.mount_look, "mount_skin": Save.mount_skin, "pet": Save.pet_look, "pet_skin": Save.pet_skin})
			main.stations._next_skin("mount")
			main.stations._next_skin("pet")
	# the Moss Warden's colours (Phase C): every skin but Lakeweed, which waits for the Lake-moss Charm
	main.closeup = Vector3.ZERO
	main.stations.free_guardian()
	await _wait(2.0)
	var g = main.guardian
	main.closeup_at = g
	main.closeup = Vector3(1.4, 2.2, 3.8)
	var seen: Array = []
	for k in 6:
		await _wait(0.5)
		await _shot("skin_warden_%d" % k)
		seen.append(Save.guardian_skin)
		main.stations._next_skin("guardian")
	_expect("Lakeweed waits for the Lake-moss Charm", not seen.has("lakeweed"), {"seen": seen})
	Save.set_flag("lake_charm")
	seen.clear()
	for k in 6:
		main.stations._next_skin("guardian")
		seen.append(Save.guardian_skin)
	_expect("Lakeweed with the charm", seen.has("lakeweed"), {"seen": seen})
	Save.guardian_skin = "lakeweed"
	main.stations._use_look("guardian", "moss_warden")
	await _wait(0.6)
	await _shot("skin_warden_lakeweed")
	main.closeup = Vector3.ZERO
	main.closeup_at = null


## The home and the campfire at home levels 3 to 6 (--levels): the camp from the game camera and the fire close up.
func _levels() -> void:
	_veteran(14)
	await _wait(0.5)
	for lv in [3, 4, 5, 6]:
		Save.camp_level = lv
		main.on_camp_grown()
		main.fight.gate_max = float(Data.fire_hp())
		main.player.global_position = Vector3(0.0, 0, 2.6)
		main.closeup = Vector3.ZERO
		main.closeup_at = null
		await _wait(2.0)
		await _shot("level_%d_camp" % lv)
		main.closeup_at = main.stations.nodes.get("campfire")
		main.closeup = Vector3(0.0, 3.4, 4.6)
		await _wait(0.8)
		await _shot("level_%d_fire" % lv)
		main.closeup_at = main.stations.nodes.get("home")
		main.closeup = Vector3(1.5, 6.5, 9.0)
		await _wait(0.8)
		await _shot("level_%d_home" % lv)
		_log("level", {"camp_level": lv, "fire": main.stations.model_name("campfire"), "home": main.stations.model_name("home"),
			"fire_foot": main.stations.foot("campfire"), "home_foot": main.stations.foot("home"), "fire_hp": Data.fire_hp(),
			"light": Data.light_radius(), "towers": main.defences.tower_cap() if main.defences.has_method("tower_cap") else -1})
	main.closeup = Vector3.ZERO
	main.closeup_at = null


# ---------------------------------------------------------------- Phase C
## A check for the Phase C tests: logs "EXPECT PASS <what>" or "EXPECT FAIL <what>" (the runner counts them).
func _expect(what: String, ok: bool, extra := {}) -> bool:
	var line := "EXPECT %s %s" % ["PASS" if ok else "FAIL", what]
	if not extra.is_empty():
		line += " " + JSON.stringify(extra)
	print(line)
	report.append({"expect": what, "ok": ok, "extra": extra})
	return ok


## Waits up to `secs` for cond to be true (checked every 0.1 s). Returns whether it came true.
func _until(cond: Callable, secs: float) -> bool:
	var t := 0.0
	while t < secs:
		if cond.call():
			return true
		await _wait(0.1)
		t += 0.1
	return bool(cond.call())


## The camp at home levels 1 to 6 with everything built (--camplife): nothing random stands on the ground kept for
## the new stations, no placed defence either, no two rings overlap, no new footprint overlaps another, the cat's start
## and revive spots are off every ring, and no prop is a magenta box.
func _camplife() -> void:
	main.player.invincible = true
	_veteran(14)
	main.stations.free_guardian()
	await _wait(0.5)
	var w = main.world
	for lv in [1, 2, 3, 4, 5, 6]:
		Save.camp_level = lv
		main.on_camp_grown()
		await _wait(1.2)
		var bad_hide: Array = []
		for h in w.hide_spots:
			if w.in_reserved(h[0], float(h[1])):
				bad_hide.append([snappedf(h[0].x, 0.01), snappedf(h[0].z, 0.01), h[2]])
		var bad_placed: Array = []
		for sp in Save.placed:
			if sp.has("x") and w.in_reserved(Vector3(float(sp["x"]), 0, float(sp["z"])), 0.6):
				bad_placed.append(sp)
		var rings: Array = []
		for id in main.stations.rings:
			var r = main.stations.rings[id]
			if r.visible:
				rings.append([id, r.global_position])
		var close: Array = []
		for i in rings.size():
			for j in range(i + 1, rings.size()):
				var d := Vector2(rings[i][1].x - rings[j][1].x, rings[i][1].z - rings[j][1].z).length()
				if d < 1.5:
					close.append([rings[i][0], rings[j][0], snappedf(d, 0.01)])
		var st: Array = []
		for c in w.circles:
			if String(c[2]).begins_with("st_"):
				st.append(c)
		var overlap: Array = []
		var news := ["st_stone", "st_garden", "st_pot", "st_fishing"]
		for i in st.size():
			for j in range(i + 1, st.size()):
				if not (news.has(st[i][2]) or news.has(st[j][2])):
					continue
				if [st[i][2], st[j][2]].has("st_campfire") and [st[i][2], st[j][2]].has("st_pot"):
					continue                        # the pot sits on the fire's rim on purpose (spec 4.1)
				var d2: float = (st[i][0] as Vector2).distance_to(st[j][0])
				if d2 < float(st[i][1]) + float(st[j][1]):
					overlap.append([st[i][2], st[j][2], snappedf(d2, 0.01)])
		var spots_on_ring: Array = []
		for sp2 in [["start", Vector3(0, 0, w.camp_r * 0.42)], ["revive", Vector3(0.6, 0, 1.4)]]:
			for r2 in rings:
				if Vector2(sp2[1].x - r2[1].x, sp2[1].z - r2[1].z).length() < 0.75:
					spots_on_ring.append([sp2[0], r2[0]])
		var lvl := "level %d" % lv
		_expect(lvl + " no hide spot on reserved ground", bad_hide.is_empty(), {"bad": bad_hide})
		_expect(lvl + " no placed defence on reserved ground", bad_placed.is_empty(), {"bad": bad_placed})
		_expect(lvl + " no rings closer than 1.5 m", close.is_empty(), {"close": close})
		_expect(lvl + " no new footprint overlaps", overlap.is_empty(), {"overlap": overlap})
		_expect(lvl + " start and revive spots off the rings", spots_on_ring.is_empty(), {"on": spots_on_ring})
		_expect(lvl + " no magenta placeholders", Props.missing.is_empty(), {"missing": Props.missing})
		main.player.global_position = Vector3(0.0, 0, 2.6)
		main.closeup = Vector3.ZERO
		main.closeup_at = null
		await _wait(1.0)
		await _shot("camplife_l%d_overview" % lv)
		for id in ["stone", "garden", "pot", "fishing"]:
			var rr = main.stations.rings.get(id)
			if rr == null or not rr.visible:
				continue
			main.player.global_position = rr.global_position
			await _wait(1.0)
			await _shot("camplife_l%d_%s" % [lv, id])
		main.hud.hide_card()
	_log("camplife", {"stations": Save.stations, "placed": Save.placed.size(), "hide_spots": w.hide_spots.size()})


## The Moss Warden (--guardian): asleep, woken at its stone, at its post in a mission; then fighting, wrecking foes
## first, a charge blocked, knocked down and pulled together, the Last Stand, the end of a wave and of the mission.
func _guardian() -> void:
	main.player.invincible = true
	_veteran(4)
	await _wait(0.3)
	_expect("no guardian before it is freed", main.guardian == null and not main.stations.rings["stone"].visible)
	main.stations.free_guardian()                       # what Phase E calls in the first Burrow
	var g = main.guardian
	_expect("the Warden exists", g != null)
	if g == null:
		return
	_expect("it wakes at its stone", g.state == "rise", {"state": g.state})
	_expect("not in foes or enemies", not g.is_in_group("foes") and not g.is_in_group("enemies"))
	await _closeup_shot(g, "warden_free", Vector3(1.4, 2.2, 3.8))
	var woke: bool = await _until(func(): return g.state == "rest", 3.0)
	await _use(main.stations.rings["stone"], 0.25, 15.0)
	await _wait(0.8)
	await _shot("warden_stone_card")
	_expect("awake and resting within 3 s", woke, {"state": g.state})
	_expect("flag warden_awake", Save.flag("warden_awake"))
	_expect("full health (690 at home level 2)", absf(g.hp - Data.guardian_max_hp()) < 0.5, {"hp": g.hp, "max": Data.guardian_max_hp()})
	await _closeup_shot(g, "warden_wake", Vector3(1.4, 2.2, 3.8))
	await _wait(0.4)
	await _shot("warden_stone_card_awake")
	main.hud.hide_card()
	# its post in a mission (Mossback Wakes: one lane, so it stands at the inner mouth of that trail). After 4 wins the
	# next mission is Bandit Night, so the Phase F gate would refuse Mossback Wakes: the test opens it (as --laststand does)
	main.fight.skip_gate = true
	main.start_stage(5)
	main.fight.skip_gate = false
	await _wait(0.5)
	main.fight.set_physics_process(false)
	for f in get_tree().get_nodes_in_group("foes"):
		f.queue_free()
	main.player.global_position = Vector3(0, 0, 17.5)
	var there: bool = await _until(func(): return Vector2(g.global_position.x - g.post.x, g.global_position.z - g.post.z).length() < 1.0, 14.0)
	_expect("at its post (about 11 m from its stone) within 14 s", there, {"at": [snappedf(g.global_position.x, 0.01), snappedf(g.global_position.z, 0.01)], "post": [snappedf(g.post.x, 0.01), snappedf(g.post.z, 0.01)], "state": g.state})
	await _closeup_shot(g, "warden_post", Vector3(3.5, 4.0, 1.0))
	if not g.has_method("_think"):
		return
	await _guardian_fight(g)


## A close-up of `who` from `off`, then back to the game camera.
func _closeup_shot(who: Node3D, name: String, off: Vector3) -> void:
	main.closeup_at = who
	main.closeup = off
	await _wait(0.3)
	await _shot(name)
	main.closeup = Vector3.ZERO
	main.closeup_at = null


func _guardian_fight(g) -> void:
	var f = main.fight
	var post: Vector3 = g.post
	# a pack near its post: 3 thornlings (normal health), a tough thornling, a brute and a stump (1e6)
	var foes: Array = []
	var kinds := [["thornling", false], ["thornling", false], ["thornling", false], ["thornling", true], ["brute", true], ["stump", true]]
	for k in kinds.size():
		var a := TAU * k / kinds.size()
		var e = f.spawn(kinds[k][0], post + Vector3(cos(a), 0, sin(a)) * 2.2, 3)
		if kinds[k][1]:
			e.hp = 1e6
			e.max_hp = 1e6
		foes.append(e)
	g.kills = 0
	g.slams = 0
	var got_target := false
	var fought := false
	var dazed := false
	var shot_punch := false
	var shot_slam := false
	var t := 0.0
	while t < 16.0:
		await _wait(0.1)
		t += 0.1
		main.player.global_position = Vector3(0, 0, 17.5)
		if g.target != null and t <= 2.05:
			got_target = true
		for e in foes:
			if is_instance_valid(e) and not e.dead:
				if e._act_target is Object and e._act_target == g:
					fought = true
				if e.state == "daze":
					dazed = true
		if g.state == "punch" and not shot_punch and t > 1.0:
			shot_punch = true
			await _closeup_shot(g, "warden_punch", Vector3(3.0, 3.0, 3.5))
		if g.state == "slam" and not shot_slam:
			shot_slam = true
			await _wait(0.5)
			await _closeup_shot(g, "warden_slam", Vector3(3.0, 3.0, 3.5))
		if fmod(t, 2.0) < 0.1:
			var fl: Array = []
			for e in foes:
				if is_instance_valid(e) and not e.dead:
					fl.append({"id": e.id, "state": e.state, "at_warden": e._act_target is Object and e._act_target == g})
			_log("warden fight", {"state": g.state, "target": g.target.id if g.target != null and is_instance_valid(g.target) else "", "hp": g.hp, "foes": fl, "kills": g.kills, "slams": g.slams})
	_expect("a target within 2 s", got_target)
	_expect("kills >= 3", g.kills >= 3, {"kills": g.kills})
	_expect("slams >= 1", g.slams >= 1, {"slams": g.slams})
	_expect("a foe fights the Warden", fought)
	_expect("a foe dazed", dazed)
	await _clear_test_foes()
	g.refill()
	# wrecking first: a stump hitting the well beats an idle thornling right next to the Warden
	g.global_position = g.post                          # out of the stump's way while it picks the well
	var well: Vector3 = main.world.station_pos("well")
	var stump = f.spawn("stump", well + Vector3(1.4, 0, 0.2), 3)
	stump.hp = 1e6
	stump.max_hp = 1e6
	var wr: bool = await _until(func(): return is_instance_valid(stump) and stump.wrecking(), 6.0)
	_expect("the stump attacks a building", wr, {"state": stump.state})
	g.global_position = stump.global_position + Vector3(-1.2, 0, -2.4)
	g.target = null
	var th = f.spawn("thornling", g.global_position + Vector3(-1.0, 0, 0), 3)
	th.hp = 1e6
	th.max_hp = 1e6
	th.set_physics_process(false)
	var picked: bool = await _until(func(): return g.target != null and is_instance_valid(g.target) and g.target.id == "stump", 1.0)
	_expect("goes for the wrecker first", picked, {"target": g.target.id if g.target != null and is_instance_valid(g.target) else ""})
	await _clear_test_foes()
	g.refill()
	# a charge blocked: a boar charging into the Warden stops there, dazed
	g.global_position = Vector3(-1.5, 0, 9.2)          # open ground south of the camp, nothing solid in the way (clear of the well since 19 Nov)
	await _wait(0.3)
	var gp: Vector3 = g.global_position
	var boar = f.spawn("boar", gp + Vector3(-4.0, 0, 0), 3)
	boar.hp = 1e6
	boar.max_hp = 1e6
	await _wait(0.1)
	var hp0: float = g.hp
	boar.global_position = g.global_position + Vector3(-3.5, 0, 0)
	boar._charge_dir = Vector3(1, 0, 0)
	boar.state = "charge"
	boar._act_t = 0.0
	var blocked: bool = await _until(func(): return boar.state == "daze", 2.0)
	var lost: float = hp0 - g.hp
	_expect("the charge ends in a daze", blocked, {"state": boar.state})
	_expect("the Warden took about the boar's gate damage", absf(lost - float(boar.gate_damage)) <= float(boar.gate_damage) * 0.5 + 1.0, {"lost": lost, "gate_damage": boar.gate_damage})
	await _closeup_shot(g, "warden_block", Vector3(3.0, 3.0, 3.5))
	await _clear_test_foes()
	g.refill()
	# knocked down: a heap that cannot be fought; the cat beside it doubles the regrowth; it rises at 60%
	var brute = f.spawn("brute", g.global_position + Vector3(1.0, 0, 0), 3)
	brute.hp = 1e6
	brute.max_hp = 1e6
	brute.set_physics_process(false)
	g.hurt(100000)
	_expect("down", g.state == "down", {"state": g.state})
	_expect("no taunt while down", not g.taunts(brute))
	main.player.global_position = g.global_position + Vector3(0, 0, 1.0)
	var d0: float = g._down_t
	await _wait(3.0)
	_expect("the cat's help: about 6 s in 3 s", absf((d0 - g._down_t) - 6.0) < 1.2, {"dropped": d0 - g._down_t})
	await _shot("warden_down")
	await _closeup_shot(g, "warden_down_close", Vector3(2.5, 2.5, 3.0))
	g._down_t = 1.0
	var rose: bool = await _until(func(): return g.up(), 3.5)
	_expect("up again within 3.5 s", rose, {"state": g.state})
	_expect("at about 60% health", absf(g.hp / g.max_hp() - 0.6) < 0.05, {"share": g.hp / g.max_hp()})
	g.hurt(100000)
	main.on_wave_cleared()
	await _wait(0.2)
	_expect("whole after a breather", g.up() and absf(g.hp - g.max_hp()) < 0.5, {"state": g.state, "hp": g.hp})
	f.in_wave = true
	brute.queue_free()
	main.player.global_position = Vector3(0, 0, 17.5)
	# the Last Stand: beside the ashes on the cat's side; nothing fights it, it swats what comes for the cat
	main.set_riding(false)
	g.global_position = g.post                      # back by the fire, where a wave would find it
	f._start_last_stand()
	main.player.global_position = Vector3(2, 0, -3)
	var ls_spot: Vector3 = g._ls_spot()
	var near_ash := false
	for k in 30:
		await _wait(0.2)
		main.player.global_position = Vector3(2, 0, -3)
		if k % 5 == 0:
			_log("last stand walk", {"state": g.state, "at": [snappedf(g.global_position.x, 0.01), snappedf(g.global_position.z, 0.01)], "post": [snappedf(g.post.x, 0.01), snappedf(g.post.z, 0.01)], "target": g.target != null})
		if Vector2(g.global_position.x - ls_spot.x, g.global_position.z - ls_spot.z).length() < 1.5:
			near_ash = true
			break
	_expect("beside the ashes within 6 s", near_ash, {"at": [snappedf(g.global_position.x, 0.01), snappedf(g.global_position.z, 0.01)], "spot": [snappedf(ls_spot.x, 0.01), snappedf(ls_spot.z, 0.01)]})
	var k0: float = g.dealt
	var ls_foes: Array = []
	for k in 3:
		var lf = f.spawn("thornling", Vector3(2, 0, -3) + Vector3(cos(k * 2.1), 0, sin(k * 2.1)) * 1.2, 3)
		lf.hp = 1e6                                    # tough, so the cat's own arrows do not end it first
		lf.max_hp = 1e6
		ls_foes.append(lf)
	var on_warden := false
	t = 0.0
	while t < 5.0:
		await _wait(0.1)
		t += 0.1
		main.player.global_position = Vector3(2, 0, -3)
		for e in ls_foes:
			if is_instance_valid(e) and not e.dead and e._act_target is Object and e._act_target == g:
				on_warden = true
	_expect("no foe fights it in the Last Stand", not on_warden)
	_expect("it swats the foes near the cat", g.dealt > k0, {"dealt": g.dealt - k0})
	await _shot("warden_last_stand")
	# the wave still ends with it standing there
	await _clear_test_foes()
	f._queue.clear()
	f.set_physics_process(true)
	var ended: bool = await _until(func(): return not f.in_wave, 2.0)
	_expect("the wave ends (it never blocks a wave)", ended)
	# the camp falls: it gets up whole and walks home, then sits by its stone
	f.camp_falls()
	await _wait(0.2)
	_expect("whole and walking home after the camp fell", g.state == "walk" and absf(g.hp - g.max_hp()) < 0.5, {"state": g.state, "hp": g.hp})
	main.player.global_position = Vector3(0, 0, 2.0)
	var home: bool = await _until(func(): return g.state == "rest", 20.0)
	_expect("resting at home within 20 s", home, {"state": g.state, "at": [snappedf(g.global_position.x, 0.01), snappedf(g.global_position.z, 0.01)]})
	await _closeup_shot(g, "warden_home", Vector3(1.6, 2.4, 4.0))
	_log("warden", {"kills": g.kills, "slams": g.slams, "downs": g.downs, "dealt": g.dealt})
	# its post: "Change" on the stone card goes round guard the camp, then each trail of the coming mission
	Save.fire_ruined = false
	main.world.set_fire_out(false)
	main.stations.set_fire_out(false)
	Save.mission_run = {}
	Save.guardian_post = -1
	await _use(main.stations.rings["stone"], 0.25, 15.0)
	await _wait(0.6)
	var seen: Array = [Save.guardian_post]
	for k in 3:
		_press("Change")
		await _wait(0.3)
		seen.append(Save.guardian_post)
	var lanes: Array = main.stations._post_lanes()
	_expect("the post goes round the camp and the next raid's trails", seen == [-1] + lanes + [-1], {"seen": seen, "lanes": lanes})
	await _shot("warden_post_card")
	Save.guardian_post = int(lanes[0])
	main.hud.hide_card()
	main.player.global_position = Vector3(0, 0, 2.0)
	main.start_stage(Data.next_mission())
	await _wait(0.5)
	main.fight.set_physics_process(false)
	await _clear_test_foes()
	_expect("it holds that trail's mouth", g.post_lane() == int(lanes[0]) and g.post.distance_to(main.world.edge_point(int(lanes[0]))) < 1.0,
		{"lane": g.post_lane(), "post": [snappedf(g.post.x, 0.01), snappedf(g.post.z, 0.01)]})
	main.fight._end(false)
	Save.guardian_post = -1


func _clear_test_foes() -> void:
	for e in get_tree().get_nodes_in_group("foes"):
		e.dead = true
		e.remove_from_group("foes")
		e.remove_from_group("enemies")
		e.queue_free()
	await _wait(0.2)


## The Warden's worth (--guardianab): Mossback Wakes for 120 s of mission time with the Warden and without it (the
## cat far away, invincible). Campfire and building damage, ruins, waves held, and the Warden's share of the damage.
func _guardianab() -> void:
	main.player.invincible = true
	_veteran(5)
	main.stations.free_guardian()
	await _wait(2.5)
	var out := {}
	for with_it in [true, false]:
		var g = main.guardian
		Save.ruined.clear()
		Save.fire_ruined = false
		main.world.set_fire_out(false)
		main.stations.set_fire_out(false)
		main.stations.refresh("all")
		main.defences.repair_all()
		g.process_mode = Node.PROCESS_MODE_INHERIT if with_it else Node.PROCESS_MODE_DISABLED
		g.visible = with_it
		g.kills = 0
		g.slams = 0
		g.downs = 0
		g.dealt = 0.0
		main.start_stage(5)
		main.player.global_position = Vector3(0, 0, 17.5)
		var f = main.fight
		var last_gate: float = f.gate_hp
		var last_b: Dictionary = main.stations.hp.duplicate()
		var seen := {}
		var gate_lost := 0.0
		var build_lost := 0.0
		var foe_dmg := 0.0
		var cleared := 0
		var was_in := true
		Engine.time_scale = 2.0
		var t := 0.0
		while t < 240.0 and f.active:
			await get_tree().physics_frame
			t += get_physics_process_delta_time() * Engine.time_scale
			main.player.global_position = Vector3(0, 0, 17.5)
			if f.gate_hp < last_gate:
				gate_lost += last_gate - f.gate_hp
			last_gate = f.gate_hp
			for id in main.stations.hp:
				var now := float(main.stations.hp[id])
				if now < float(last_b.get(id, now)):
					build_lost += float(last_b[id]) - now
				last_b[id] = now
			var alive := {}
			for e in get_tree().get_nodes_in_group("foes"):
				var k: int = e.get_instance_id()
				alive[k] = true
				var h := maxf(float(e.hp), 0.0)
				if seen.has(k) and h < float(seen[k]):
					foe_dmg += float(seen[k]) - h
				seen[k] = h
			for k in seen.keys():
				if not alive.has(k):
					foe_dmg += float(seen[k])
					seen.erase(k)
			if was_in and not f.in_wave:
				cleared += 1
			was_in = f.in_wave
			if not f.in_wave:
				f.next_phase_now()
		Engine.time_scale = 1.0
		var key := "with" if with_it else "without"
		out[key] = {"gate_lost": snappedf(gate_lost, 0.1), "building_lost": snappedf(build_lost, 0.1), "ruins": Save.ruined.size(),
			"waves_cleared": cleared, "wave": f.wave, "kills": g.kills, "slams": g.slams, "downs": g.downs, "dealt": snappedf(g.dealt, 0.1),
			"warden_share": snappedf(g.dealt / maxf(foe_dmg, 1.0), 0.01), "foe_damage": snappedf(foe_dmg, 0.1)}
		_log("guardianab " + key, out[key])
		await _shot("guardianab_" + key)
		if f.active:
			f._clear_foes()
			f._end(false)
		await _wait(1.0)
	main.guardian.process_mode = Node.PROCESS_MODE_INHERIT
	main.guardian.visible = true
	var w: Dictionary = out["with"]
	var wo: Dictionary = out["without"]
	_expect("less camp damage with the Warden", float(w["gate_lost"]) + float(w["building_lost"]) < float(wo["gate_lost"]) + float(wo["building_lost"]), out)
	_expect("no stuck wave with the Warden", int(w["waves_cleared"]) >= int(wo["waves_cleared"]) and int(w["wave"]) >= 2, out)


## The bottom-right HUD button whose label starts with prefix (null when none shows; tests of the HUD buttons use it).
func _build_button(prefix: String) -> Button:
	for bb in main.hud.build_buttons():
		if String(bb.get_meta("label", "")).begins_with(prefix) and not bb.is_queued_for_deletion():
			return bb
	return null


## Fishing (--fishing): five casts landed (taps on the bite, reeling in the green), a tap while waiting only waits, a
## bite let go, a Golden Carp lost to early taps and then landed (H3: into the Bag), the pity, the three lake treasures
## in order, stopping by dragging and by a wave starting.
func _fishing() -> void:
	main.player.invincible = true
	_veteran(6)
	await _wait(0.4)
	var fs = main.fishing
	fs.rng.seed = 7
	fs.debug_wait = 0.8
	var sk: Skeleton3D = main.player.skeleton
	_log("hero bones", {"bow_hand": main.player._bow_hand(), "found": sk.find_bone(main.player._bow_hand()) >= 0, "bones": sk.get_bone_count()})
	var ring = main.stations.rings["fishing"]
	await _at_ring(ring)
	await _wait(0.8)
	await _shot("fish_card")
	var caught := 0
	for k in 5:
		fs.debug_catch = "trout" if k == 0 else ""          # the first one is reeled in, for the shots
		await _cast_once(k == 0)
		if fs.last == "caught":
			caught += 1
		_log("catch", {"catch": fs.catch.get("id", ""), "last": fs.last, "fish": Bag.count("fish"), "goldfish": Bag.count("goldfish"),
			"log": Save.fish_log, "timber": Save.timber})
	_expect("five casts landed", caught == 5, {"caught": caught})
	# a tap while it waits only waits; a bite nobody taps gets away
	_press_cast()
	await _until(func(): return fs.phase == "wait", 3.0)
	fs.tap()
	_expect("a tap while waiting keeps it waiting", fs.phase == "wait", {"phase": fs.phase})
	await _until(func(): return fs.phase == "bite", 8.0)
	await _until(func(): return fs.phase == "", 3.0)
	_expect("a bite not tapped gets away", fs.last == "missed", {"last": fs.last})
	# the Golden Carp: early taps lose it, taps in the green land it
	fs.debug_catch = "carp"
	fs.debug_share = 0.0
	_press_cast()
	await _until(func(): return fs.phase == "bite", 8.0)
	fs.tap()
	await _wait(0.1)
	fs.tap()
	await _wait(0.1)
	fs.tap()
	await _wait(0.2)
	_expect("early taps: it escapes", fs.last == "escaped" and fs.phase == "", {"last": fs.last, "phase": fs.phase})
	var carp0 := Bag.count("goldfish")
	await _cast_once(false)
	_expect("landed: 1 Golden Carp in the Bag", Bag.count("goldfish") == carp0 + 1, {"before": carp0, "goldfish": Bag.count("goldfish")})
	# the pity: the 20th catch since a rare one is rare
	fs.debug_catch = ""
	Save.fish_dry = 19
	await _cast_once(false)
	_expect("the pity: a rare one", String(fs.catch.get("rarity", "")) == "rare" and Save.fish_dry == 0, {"catch": fs.catch.get("id", ""), "dry": Save.fish_dry})
	# the lake treasures, in order
	fs.debug_catch = "carp"
	fs.debug_share = 1.0
	var got: Array = []
	for k in 3:
		await _cast_once(false)
		got.append(String(fs.catch.get("id", "")))
	_expect("treasures in order", got == ["lake_lure", "lake_line", "lake_charm"] and Save.flag("lake_charm"), {"got": got})
	await _shot("fish_treasure")
	fs.debug_catch = ""
	fs.debug_share = -1.0
	# stop by dragging, and when a wave starts
	_press_cast()
	await _until(func(): return fs.phase == "wait", 3.0)
	var j = main.joystick
	j.force = true
	j.forced = Vector2(0.8, 0)
	await _wait(0.3)
	j.forced = Vector2.ZERO
	j.force = false
	_expect("dragging stops it", fs.phase == "", {"phase": fs.phase})
	await _at_ring(ring)
	await _wait(0.6)
	_press_cast()
	await _until(func(): return fs.phase == "wait", 3.0)
	main.on_wave_start(1)
	_expect("a wave starting stops it", fs.phase == "" and not main.player.has_rod(), {"phase": fs.phase})


func _press_cast() -> void:
	main.hud.refresh_card()
	await _wait(0.3)
	if not _press("Cast"):
		main.reopen_ring()
		await _wait(0.4)
		_press("Cast")


## One cast, played well: tap on the bite, then tap whenever the reel ring is green.
func _cast_once(shots: bool) -> void:
	var fs = main.fishing
	await _press_cast()
	await _until(func(): return fs.phase == "wait", 3.0)
	if shots:
		await _wait(0.2)
		if main.player._rod != null:
			_log("ROD_XF", {"xf": str(main.player._rod.transform)})
		await _shot("fish_cast_game")
		main.closeup_at = main.player
		main.closeup = Vector3(1.3, 1.9, 1.9)
		await _wait(0.1)
		await _shot("fish_cast")
		main.closeup = Vector3.ZERO
		main.closeup_at = null
	await _until(func(): return fs.phase == "bite", 8.0)
	if shots:
		await _shot("fish_bite")
	fs.tap()
	var reel_shot := shots
	while fs.phase == "reel":
		await _until(func(): return fs.in_zone() or fs.phase != "reel", 3.0)
		if fs.phase != "reel":
			break
		if reel_shot:
			reel_shot = false
			await _shot("fish_reel")
		fs.tap()
		await _wait(0.05)
	if shots and fs.phase == "land":
		await _wait(0.25)
		await _shot("fish_catch")
	await _until(func(): return fs.phase == "", 3.0)
	await _wait(0.5)


# ---------------------------------------------------------------- Phase D: the Gloom Raids
## Runs a Phase D mode if one was asked for; false when none was.
func _phase_d() -> bool:
	var args := Data.args()
	if args.has("--assault"):
		await _raidsave()
		return true
	if args.has("--shards"):
		await _shards()
		return true
	if args.has("--raid"):
		await _raid()
		return true
	if args.has("--raidloss"):
		await _raidloss()
		return true
	if args.has("--meter"):
		await _meter()
		return true
	if args.has("--raidsave"):
		await _raidsave()
		return true
	if args.has("--raidshots"):
		await _raidshots()
		return true
	if args.has("--raidintro"):
		await _raidintro()
		return true
	if args.has("--raidtypes"):
		await _raidtypes()
		return true
	if args.has("--wear"):
		await _wear()
		return true
	if args.has("--raidperf"):
		await _raidperf()
		return true
	for a in args:
		if a.begins_with("--raidresume="):
			await _raidresume(int(a.substr(13)))
			return true
	return false


## Gloom shards (--shards): Data.can_afford and pay with shards, and the new save fields kept through a save and a
## load (an old save without them loads with the defaults).
func _shards() -> void:
	Save.shards = 0
	_expect("can't afford 5 shards with none", not Data.can_afford({"shards": 5}))
	Save.shards = 12
	var leaves0 := Save.leaves
	_expect("can afford 5 shards with 12", Data.can_afford({"shards": 5}))
	_expect("pay 5 shards", Data.pay({"shards": 5}) and Save.shards == 7 and Save.leaves == leaves0, {"shards": Save.shards})
	_expect("can't pay 8 shards with 7", not Data.pay({"shards": 8}) and Save.shards == 7)
	await _wait(0.4)
	await _shot("shards_hud_row")
	# the new fields go through a save and a load
	Save.raids["meter"] = 42.5
	Save.raids["plan"] = {"type": "siege", "lanes": [2], "level": 6, "leader": "herald", "first": true, "seed": 12345, "called": false}
	Save.raids["held"] = 3
	Save.wear = {"home": 0.3}
	Save.unlocks = ["watch:lookout"]
	Save.fire_look = "shardfire"
	var got := [0]
	var cb := func(): got[0] += 1
	Save.changed.connect(cb)
	Save.save_game(true)
	_expect("a quiet save does not emit changed", got[0] == 0)
	Save.save_game()
	_expect("a normal save emits changed", got[0] == 1)
	Save.changed.disconnect(cb)
	Save.shards = 0
	Save.raids = Save.RAIDS_DEFAULT.duplicate(true)
	Save.wear = {}
	Save.unlocks = []
	Save.fire_look = ""
	Save.load_game()
	_expect("fields kept through save and load", Save.shards == 7 and absf(float(Save.raids["meter"]) - 42.5) < 0.01 and int(Save.raids["held"]) == 3
		and String(Save.raids["plan"].get("type", "")) == "siege" and int(Save.raids["plan"]["seed"]) == 12345 and (Save.raids["plan"]["lanes"] as Array) == [2]
		and absf(float(Save.wear.get("home", 0.0)) - 0.3) < 0.001 and Save.unlocks == ["watch:lookout"] and Save.fire_look == "shardfire"
		and Save.save_v == SaveUpgrades.CURRENT_VERSION and not Save._loaded_fields.has("burrow_keys"),
		{"shards": Save.shards, "raids": Save.raids, "wear": Save.wear, "unlocks": Save.unlocks, "save_v": Save.save_v})
	# an old save (before Phase D): none of the new keys, and a plan of a kind that does not exist
	var d = JSON.parse_string(FileAccess.get_file_as_string(Save.path))
	for k in ["shards", "wear", "unlocks", "fire_look", "save_v"]:
		d.erase(k)
	d["raids"] = {"meter": 30.0, "plan": {"type": "nope", "lanes": [1]}, "pending": true, "run": {"wave_done": 1}}
	var f := FileAccess.open(Save.path, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	Save.load_game()
	_expect("an old save loads with the defaults", Save.shards == 0 and Save.wear.is_empty() and Save.unlocks.is_empty() and Save.fire_look == ""
		and Save.loaded_v == 1 and Save.save_v == SaveUpgrades.CURRENT_VERSION, {"save_v": Save.save_v, "loaded_v": Save.loaded_v})
	_expect("a plan of an unknown kind is dropped with pending and run", (Save.raids["plan"] as Dictionary).is_empty()
		and not bool(Save.raids["pending"]) and (Save.raids["run"] as Dictionary).is_empty() and absf(float(Save.raids["meter"]) - 30.0) < 0.01, {"raids": Save.raids})
	Save.save_v = SaveUpgrades.CURRENT_VERSION
	Save.save_game()
	await _shard_goods()


## A veteran camp with every mission won, raids open, the player never idle (the tests drive the cat by code).
func _raid_camp() -> void:
	main.player.invincible = true
	_veteran(15)
	Save.leaves = 3000
	Save.timber = 100
	main.raids.refresh_open()
	main.raids.test_awake = true
	if Data.args().has("--with-warden"):
		main.stations.free_guardian()                  # Phase E frees it; raids must work with and without it
	if main.world.has_method("swap_sign"):
		main.world.swap_sign()
	main.world.settle_gloom()                          # every trail is claimed: no Gloom left on them
	Save.save_game()


## Fills the meter to the brim and waits for the warning to start.
func _raid_to_warning() -> bool:
	Save.raids["meter"] = 99.97
	return await _until(func(): return main.fight.active and main.fight.mode == "raid", 5.0)


## Kills every foe on the field except the leader (and the leader too when `leader`).
func _kill_foes(leader := false) -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("foes"):
		if e.dead or (e.has_meta("leader") and not leader):
			continue
		e.hit(Vector3.FORWARD, e.hp + 1.0)
		n += 1
	return n


## The mission save fields a raid must never touch.
func _mission_fields() -> Dictionary:
	return {"run": Save.mission_run.duplicate(), "done": Save.missions_done.size(), "claimed": Save.claimed.duplicate(),
		"won": Save.stages_won, "lost": Save.stages_lost}


## A Random Raid held (--raid, with --raid-small): the warning, the leader, the surviving raiders and the pay.
func _raid() -> void:
	await _raid_camp()
	await _wait(0.5)
	var mf := _mission_fields()
	var f = main.fight
	var r: Dictionary = Save.raids
	var started: bool = await _raid_to_warning()
	_expect("the meter fills to full and the raid is pending", bool(r["pending"]))
	_expect("the warning starts", started and f.mode == "raid" and f.warning and not f.in_wave, {"mode": f.mode, "warning": f.warning})
	_expect("the camp is safe in the warning", main.world.inside_camp(Vector3(0, 0, 1)))
	await _wait(1.0)
	var plan: Dictionary = (r["plan"] as Dictionary).duplicate(true)
	_expect("the HUD shows the warning", String(main.hud._stage_l.text).begins_with(String(f.raid["name"])) and main.hud._stage_l.visible, {"text": main.hud._stage_l.text})
	await _shot("raid_01_warning")
	if main.guardian != null:
		var gp: Vector3 = main.guardian.post
		var lane_dir: Vector3 = main.world.patch_dir(int(f.raid["lanes"][0]))
		_expect("the Warden takes a post toward the raid's trail", gp.length() > 0.5 and Vector2(gp.x, gp.z).normalized().dot(Vector2(lane_dir.x, lane_dir.z)) > 0.5,
			{"post": gp, "lanes": f.raid["lanes"]})
	var shards0 := Save.shards
	var leaves0 := Save.leaves
	f.next_phase_now()
	await _until(func(): return f.in_wave, 3.0)
	_expect("Meet them now starts wave 1", f.in_wave and f.wave == 1 and not f.warning, {"wave": f.wave})
	var leader_down := false
	var t := 0.0
	while f.active and t < 150.0:
		await _wait(0.3)
		t += 0.3
		if not f.in_wave:
			f.next_phase_now()
			continue
		var leader = null
		for e in get_tree().get_nodes_in_group("foes"):
			if e.has_meta("leader") and not e.dead:
				leader = e
		if leader != null and not leader_down:
			# the leader is here: two raiders beside it, then topple it
			main.fight.spawn("thornling", leader.global_position + Vector3(1.5, 0, 0), int(f.lane))
			main.fight.spawn("thornling", leader.global_position + Vector3(-1.5, 0, 0), int(f.lane))
			await _wait(0.6)
			await _shot("raid_02_leader")
			_expect("the leader has the boss bar", main.hud.boss == leader)
			var others := get_tree().get_nodes_in_group("foes").size() - 1
			leader.hit(Vector3.FORWARD, leader.hp + 1.0)
			leader_down = leader.dead
			var left: int = f._wave_foe_count()
			_expect("the leader falls and the other raiders stay in the fight", leader_down and others > 0 and left == others and f.in_wave,
				{"others": others, "left": left})
			continue
		_kill_foes(false)
	_expect("the leader was defeated during the assault", leader_down)
	await _wait(0.5)
	await _shot("raid_03_held")
	var run_ready: bool = main.raids.last_ready
	var lv := int(plan["level"])
	var base := (10.0 + lv) * float(Data.gr()["types"][String(plan["type"])]["shards"])
	var want := int(round(base * (1.0 + 0.5 + (0.2 if run_ready else 0.0))))
	_expect("the raid is over and held", not f.active and f.mode == "mission" and int(r["held"]) == 1, {"held": r["held"], "active": f.active})
	_expect("shards: the formula x1.5 (perfect) (+0.2 when ready)", Save.shards - shards0 == want, {"got": Save.shards - shards0, "want": want, "ready": run_ready, "level": lv})
	_expect("leaves paid (100 + 15 x level at least)", Save.leaves - leaves0 >= 100 + 15 * lv, {"got": Save.leaves - leaves0})
	_expect("renown +1, meter 0, perfect streak 1", int(r["renown"]) == 1 and float(r["meter"]) < 1.0 and int(r["streak"]) == 1, {"r": r})
	# H1: the file on disk after a save, the Save node and the raid pay (the old _loaded_fields test was always true)
	Save.save_game(true)
	var sf: Variant = JSON.parse_string(FileAccess.get_file_as_string(Save.path))
	_expect("no Hollow key any more (H1): the saved file has no key field, the raid pay names none", sf is Dictionary
		and not (sf as Dictionary).has("burrow_keys") and not "burrow_keys" in Save and not (Data.gr()["pay"] as Dictionary).has("keys"),
		{"pay": Data.gr()["pay"]})
	_expect("the plan and the run are cleared", (r["plan"] as Dictionary).is_empty() and not bool(r["pending"]) and (r["run"] as Dictionary).is_empty())
	_expect("the raid save fields are untouched", _mission_fields() == mf, {"before": mf, "after": _mission_fields()})
	_expect("the fire burns", not Save.fire_ruined and not main.world.fire_out)
	await _wait(3.0)
	var g := 0.0
	for ln in plan["lanes"]:
		g = maxf(g, float(main.world.gloom[int(ln)]))
	_expect("the Gloom lifted off the raid's trails", g < 0.02, {"gloom": main.world.gloom})
	await _shot("raid_04_after")
	if main.guardian != null:
		_expect("the Warden is up and going home after the raid", main.guardian.state != "sleep" and main.guardian.state != "down", {"state": main.guardian.state})
	_log("raid", {"plan": plan, "raids": r, "shards": Save.shards})


## A Gloom Raid lost (--raidloss): only the damage stays. Nothing else is taken, the fire is not ashes; then a won
## mission replay does not mend that ruin.
func _raidloss() -> void:
	await _raid_camp()
	await _wait(0.5)
	var f = main.fight
	var r: Dictionary = Save.raids
	r["renown"] = 1
	var mf := _mission_fields()
	await _raid_to_warning()
	f.next_phase_now()
	await _until(func(): return f.in_wave, 3.0)
	f.set_physics_process(false)                       # only what the test does
	for e in get_tree().get_nodes_in_group("foes"):
		e.queue_free()
	await _wait(0.2)
	var leaves0 := Save.leaves
	var timber0 := Save.timber
	var shards0 := Save.shards
	var lost0 := int(r["lost"])
	main.stations.hurt_building("well", 99999)
	var bar: Dictionary = {}
	for pc in main.defences.pieces:
		if pc["type"] == "barricade" and pc.get("src") != null:
			bar = pc
			break
	main.defences.hurt_piece(int(bar["id"]), 150)
	f.damage_fire(int(f.gate_hp) + 1, Vector3(0, 0, -5))
	await _wait(0.5)
	_expect("the Last Stand", f.last_stand)
	var rebuilt: bool = f.rebuild_fire()
	await _wait(0.5)
	_expect("the fire rebuilt once (10 timber)", rebuilt and Save.timber == timber0 - 10)
	f.damage_fire(int(f.gate_hp) + 1, Vector3(0, 0, -5))
	await _wait(1.0)
	f.set_physics_process(true)
	await _shot("raidloss_01_lost")
	_expect("the raid is lost", not f.active and f.mode == "mission" and int(r["lost"]) == lost0 + 1 and not bool(r["pending"]), {"r": r})
	_expect("no leaves or timber taken (only the rebuild's 10 timber)", Save.leaves == leaves0 and Save.timber == timber0 - 10, {"leaves": [leaves0, Save.leaves], "timber": [timber0, Save.timber]})
	_expect("the fire is lit, not ashes", not Save.fire_ruined and not main.world.fire_out)
	_expect("the raid run untouched", Save.mission_run.is_empty() and _mission_fields() == mf)
	_expect("the ruin is kept", Save.ruined.has("well"))
	var src: Dictionary = bar["src"]
	_expect("the barricade is wrecked in its own Save.placed entry", src.has("wreck") and absf(float(src["wreck"]) - float(bar["hp"]) / float(bar["max_hp"])) < 0.01 and Save.placed.has(src), {"src": src})
	_expect("renown -2 (not below 0)", int(r["renown"]) == 0, {"renown": r["renown"]})
	_expect("shards: 2 per wave held (none held)", Save.shards == shards0, {"shards": [shards0, Save.shards]})
	_expect("meter back to 0, streak 0", float(r["meter"]) < 1.0 and int(r["streak"]) == 0)
	await _wait(2.0)
	# a mission replay won mends only what it broke
	main.start_stage(0)
	await _wait(0.5)
	_expect("a replay can start (no raid pending)", f.active and f.mode == "mission")
	f.set_physics_process(false)
	for e in get_tree().get_nodes_in_group("foes"):
		e.queue_free()
	main.stations.hurt_building("target", 99999)
	await _wait(0.3)
	f._win()
	await _wait(1.0)
	f.set_physics_process(true)
	_expect("a won replay mends its own ruin but not the raid's", Save.ruined.has("well") and not Save.ruined.has("target"), {"ruined": Save.ruined})
	_expect("the barricade is still wrecked after the replay", src.has("wreck"))
	await _shot("raidloss_02_after_replay")


## Ends a running raid without a win or a loss (test cleanup): nothing is paid, nothing is counted.
func _reset_fight() -> void:
	var f = main.fight
	for e in get_tree().get_nodes_in_group("foes"):
		e.dead = true
		e.remove_from_group("foes")
		e.remove_from_group("enemies")
		e.queue_free()
	f._queue.clear()
	f.active = false
	f.in_wave = false
	f.on_break = false
	Save.count_gain = false                            # as fight._end does: no chapter gain counted outside a fight
	f.warning = false
	f.last_stand = false
	f._breather = 0.0
	f.mode = "mission"
	f.raid = {}
	main.hud.boss = null
	main.world.set_fire_out(false)
	main.stations.set_fire_out(false)


func _clear_raid_state() -> void:
	var r: Dictionary = Save.raids
	r["plan"] = {}
	r["pending"] = false
	r["run"] = {}
	r["warn_left"] = 0.0
	r["meter"] = 0.0


## The Gloom meter (--meter): it fills only from clamped live play and actions; idle, fights, ashes and a pending raid
## stop it; actions stop at 95; the plan is made at 75; a focus-out saves quietly; Sound the horn from 50.
func _meter() -> void:
	await _raid_camp()
	var rd = main.raids
	var r: Dictionary = Save.raids
	rd.manual = true
	_clear_raid_state()
	r["first_done"] = true
	await _wait(0.3)
	for k in 600:
		rd.step(0.1)
	_expect("600 ticks of 0.1 s: +10", absf(float(r["meter"]) - 10.0) < 0.1, {"meter": r["meter"]})
	var m0 := float(r["meter"])
	rd.step(30.0)
	_expect("one tick of 30 s adds at most 0.1 s worth", float(r["meter"]) - m0 <= 0.0167 + 0.0001, {"added": float(r["meter"]) - m0})
	rd.test_awake = false
	rd.idle_t = 46.0
	m0 = float(r["meter"])
	for k in 50:
		rd.step(0.1)
	_expect("idle: no fill", float(r["meter"]) == m0 and rd.idle(), {"meter": r["meter"]})
	rd.test_awake = true
	rd.idle_t = 0.0
	main.fight.active = true
	m0 = float(r["meter"])
	rd.step(0.1)
	_expect("in a fight: no fill", float(r["meter"]) == m0)
	main.fight.active = false
	Save.fire_ruined = true
	rd.step(0.1)
	_expect("on the ashes: no fill", float(r["meter"]) == m0)
	Save.fire_ruined = false
	r["pending"] = true
	_expect("a raid pending: no fill", not rd.can_fill())
	r["pending"] = false
	m0 = float(r["meter"])
	rd.add_gloom("replay_chapter")
	_expect("add_gloom(replay_chapter): +6", absf(float(r["meter"]) - m0 - 6.0) < 0.001, {"meter": r["meter"]})
	r["meter"] = 70.0
	r["plan"] = {}
	rd.add_gloom("replay_won")
	rd.add_gloom("replay_won")
	rd.add_gloom("replay_won")
	_expect("action points from 70 stop at 95", absf(float(r["meter"]) - 95.0) < 0.001 and not bool(r["pending"]), {"meter": r["meter"]})
	_expect("crossing 75 made a plan", not (r["plan"] as Dictionary).is_empty(), {"plan": r["plan"]})
	r["meter"] = 74.99
	r["plan"] = {}
	rd.step(0.1)
	_expect("ticking past 75 made a plan", not (r["plan"] as Dictionary).is_empty() and float(r["meter"]) >= 75.0)
	# a focus-out saves quietly, and nothing moves
	var got := [0]
	var cb := func(): got[0] += 1
	Save.changed.connect(cb)
	r["meter"] = 63.25
	main._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	Save.changed.disconnect(cb)
	var d = JSON.parse_string(FileAccess.get_file_as_string(Save.path))
	_expect("focus out: a quiet save of the meter", got[0] == 0 and absf(float(d["raids"]["meter"]) - 63.25) < 0.001 and float(r["meter"]) == 63.25, {"saved": d["raids"]["meter"]})
	# Sound the horn: nothing below 50; from 50 a 30 s warning (45 with the Lookout)
	r["meter"] = 40.0
	rd.call_now()
	_expect("Sound the horn below 50 does nothing", not bool(r["pending"]) and not main.fight.active)
	r["meter"] = 55.0
	r["plan"] = {}
	rd.call_now()
	await _wait(0.2)
	_expect("Sound the horn at 55: a 30 s warning", main.fight.active and main.fight.warning and absf(main.fight._breather - 30.0) < 0.6, {"breather": main.fight._breather})
	await _shot("meter_called")
	_reset_fight()
	_clear_raid_state()
	Save.unlocks.append("watch:lookout")
	r["meter"] = 55.0
	rd.call_now()
	await _wait(0.2)
	_expect("with the Lookout: 45 s", main.fight.active and absf(main.fight._breather - 45.0) < 0.6, {"breather": main.fight._breather})
	_reset_fight()
	_clear_raid_state()
	Save.unlocks.clear()
	rd.manual = false
	_log("meter", {"raids": r})


## Continuous assault and restart checks (--assault / --raidsave).
func _raidsave() -> void:
	var test := Node.new()
	test.set_script(load("res://scripts/autotest_assault.gd"))
	test.t = self
	test.main = main
	add_child(test)
	await test.run()
	test.queue_free()


## A real restart in the middle of a raid (--raidresume=1 with --fresh, then =2, then =3):
##   1: a veteran camp, the meter full, wave 1 starts, the target is ruined, the app closes.
##   2: the save is read: the raid is back at its warning, the target still ruined, the shards unchanged. The raid is
##      won; then the meter is played up to 40 and the app closes.
##   3: the meter reads exactly what was saved.
func _raidresume(step: int) -> void:
	var f = main.fight
	var rd = main.raids
	var keep := "user://raidresume.json"
	if step == 1:
		await _raid_camp()
		Save.raids["first_done"] = true
		await _wait(0.3)
		await _raid_to_warning()
		f.next_phase_now()
		await _until(func(): return f.in_wave, 3.0)
		main.stations.hurt_building("target", 99999)
		await _wait(0.5)
		var kf := FileAccess.open(keep, FileAccess.WRITE)
		kf.store_string(JSON.stringify({"shards": Save.shards, "plan": Save.raids["plan"]}))
		kf.close()
		_log("raidresume 1", {"raids": Save.raids, "ruined": Save.ruined})
		main._notification(NOTIFICATION_WM_CLOSE_REQUEST)       # what the system sends when the app closes
		return
	var was = JSON.parse_string(FileAccess.get_file_as_string(keep))
	if step == 2:
		rd.test_awake = true
		var back: bool = await _until(func(): return f.active and f.mode == "raid", 4.0)
		_expect("the raid is back after a restart", back and bool(Save.raids["pending"]), {"raids": Save.raids})
		_expect("back at its warning (30 s or more)", f.warning and not f.in_wave and f._breather >= 29.0, {"breather": f._breather})
		_expect("the same plan", JSON.parse_string(JSON.stringify(Save.raids["plan"])) == was["plan"], {"was": was["plan"], "now": Save.raids["plan"]})
		_expect("the target is still ruined", Save.ruined.has("target"))
		_expect("the shards unchanged", Save.shards == int(was["shards"]), {"was": was["shards"], "now": Save.shards})
		await _shot("raidresume_back")
		f.next_phase_now()
		var t := 0.0
		while f.active and t < 200.0:
			_kill_foes(true)
			if not f.in_wave:
				f.next_phase_now()
			await _wait(0.3)
			t += 0.3
		_expect("the raid was won after the restart", not f.active and int(Save.raids["held"]) == 1, {"raids": Save.raids})
		Save.raids["meter"] = 39.9
		rd.manual = true
		while float(Save.raids["meter"]) < 40.0:
			rd.step(0.1)
		Save.raids["meter"] = 40.0
		var kf2 := FileAccess.open(keep, FileAccess.WRITE)
		kf2.store_string(JSON.stringify({"meter": Save.raids["meter"]}))
		kf2.close()
		main._notification(NOTIFICATION_WM_CLOSE_REQUEST)
		return
	if step == 3:
		await _wait(0.2)
		_expect("the meter reads exactly what was saved", float(Save.raids["meter"]) == float(was["meter"]) and not bool(Save.raids["pending"]),
			{"was": was["meter"], "now": Save.raids["meter"]})


## Close-ups for the lead's review (--raidshots): the Watch at fill 0, 0.5 and 1 with its flag, bell and ribbons; the
## HUD's meter, idle, Tracker, blocked, warning and wave states; the Watch and raid cards; "Perfect defence!".
func _raidshots() -> void:
	await _raid_camp()
	var rd = main.raids
	var r: Dictionary = Save.raids
	var w = main.world
	rd.manual = true
	_clear_raid_state()
	r["first_done"] = true
	var s: Node3D = w.sign_node
	_expect("the signpost is the Watch", s != null and String(s.get_meta("model", "")) == "signpost_watch", {"model": s.get_meta("model", "") if s else ""})
	var hidden_ok := true
	for part in ["lookout_flag", "tracker_bell", "ribbon_1", "ribbon_2", "ribbon_3"]:
		var n := Props.find_part(s, part)
		if n == null or n.visible:
			hidden_ok = false
	_expect("its earned parts start hidden", hidden_ok)
	main.player.global_position = Vector3(-1.2, 0, 2.4)
	main.hud.hide_card()
	await _wait(0.3)
	main.closeup_at = s
	main.closeup = Vector3(0.8, 1.7, 3.8)
	await _wait(3.0)                                   # the "home grows" banner of the veteran camp goes first
	for share in [0.0, 0.5, 0.999]:
		r["meter"] = share * 100.0
		rd._update_watch_model(true)
		await _wait(0.4)
		await _shot("watch_fill_%d" % int(round(share * 100.0)))
	var fill := Props.find_part(s, "fill")
	_expect("the crystal fills with the meter", fill != null and fill.scale.y > 0.95, {"y": fill.scale.y if fill else -1})
	Save.unlocks.append_array(["watch:lookout", "watch:tracker"])
	r["streak"] = 10
	rd._update_watch_model(true)
	var shown_ok := true
	for part in ["lookout_flag", "tracker_bell", "ribbon_1", "ribbon_2", "ribbon_3"]:
		var n2 := Props.find_part(s, part)
		if n2 == null or not n2.visible:
			shown_ok = false
	_expect("the flag, the bell and the ribbons show when earned", shown_ok)
	await _wait(0.4)
	await _shot("watch_extras")
	main.closeup = Vector3(-2.6, 1.8, 2.6)
	await _wait(0.4)
	await _shot("watch_extras_side")
	main.closeup = Vector3.ZERO
	main.closeup_at = null
	Save.unlocks.clear()
	r["streak"] = 0
	rd._update_watch_model(true)
	# the HUD
	r["meter"] = 62.4
	main.player.global_position = Vector3(0, 0, 1.6)
	await _wait(0.5)
	_expect("HUD: Gloom 62%", main.hud._stage_l.text == "Gloom 62%" and main.hud._stage_l.visible, {"text": main.hud._stage_l.text})
	await _shot("hud_meter")
	rd.test_awake = false
	rd.idle_t = 50.0
	await _wait(0.3)
	_expect("HUD: waits for you while idle", String(main.hud._stage_l.text).ends_with("waits for you"), {"text": main.hud._stage_l.text})
	await _shot("hud_idle")
	rd.test_awake = true
	rd.idle_t = 0.0
	Save.unlocks.append("watch:tracker")
	r["meter"] = 80.0
	r["plan"] = rd._plan()
	await _wait(0.3)
	_expect("HUD with the Tracker: Next: ...", String(main.hud._stage_l.text).begins_with("Next: "), {"text": main.hud._stage_l.text})
	await _shot("hud_tracker")
	Save.unlocks.clear()
	r["pending"] = true
	Save.fire_ruined = true
	await _wait(0.3)
	_expect("HUD: Raid waiting · rebuild the fire", main.hud._stage_l.text == "Raid waiting · rebuild the fire", {"text": main.hud._stage_l.text})
	await _shot("hud_blocked")
	Save.fire_ruined = false
	r["pending"] = false
	r["meter"] = 64.0
	# the Watch card (calm)
	await _at_ring(main.stations.rings["sign"])
	await _wait(0.8)
	await _shot("card_watch")
	var spec: Dictionary = main.stations._card_sign()
	_expect("the Watch card", String(spec["title"]) == "The Watch" and main.hud._card != null, {"title": spec["title"], "rows": (spec["rows"] as Array).map(func(rw): return rw["text"])})
	main.player.global_position = Vector3(0, 0, 1.6)
	await _wait(0.5)
	# the warning, the raid card, a wave
	rd.manual = false
	r["plan"] = {}
	await _raid_to_warning()
	await _wait(1.0)
	await _shot("hud_warning")
	await _at_ring(main.stations.rings["sign"])
	await _wait(0.8)
	await _shot("card_raid_warning")
	main.fight.next_phase_now()
	main.player.global_position = Vector3(0, 0, 1.6)
	await _until(func(): return main.fight.in_wave, 3.0)
	await _wait(2.0)
	# H2: one raider beaten (not the leader): the raid bar shows the whole attack's share beaten, the words no count
	var one: Node3D = null
	for i in 20:
		for e in get_tree().get_nodes_in_group("foes"):
			if not e.dead and e.has_meta("raid_member") and not e.has_meta("leader"):
				one = e
				break
		if one != null:
			break
		await _wait(0.3)
	if one != null:
		one.hit(Vector3.FORWARD, one.hp + 1.0)
	await _wait(0.4)
	var run_d: Array = Save.raids.get("run", {}).get("defeated", [])
	var fl: float = main.hud.p_fight.fill()
	_expect("HUD shows continuous raid progress (H2: the raid bar fills with the attack's share beaten, the words give no count)",
		one != null and not String(main.hud._stage_l.text).contains("left") and main.hud._gate_bar.visible and fl > 0.0
		and is_equal_approx(fl, float(run_d.size()) / float(main.fight.raid_total())) and main.hud.p_fight.progress_done > 0,
		{"text": main.hud._stage_l.text, "fill": fl, "defeated": run_d.size(), "total": main.fight.raid_total(), "done": main.hud.p_fight.progress_done})
	await _shot("hud_wave")
	var t := 0.0
	while main.fight.active and t < 120.0:
		_kill_foes(true)
		if not main.fight.in_wave:
			main.fight.next_phase_now()
		await _wait(0.3)
		t += 0.3
	await _wait(0.6)
	await _shot("banner_perfect")
	_log("raidshots", {"raids": r})


## The last mission's first win opens the raids (--raidintro): the Watch wakes, the meter starts at 70, the intro shows;
## an old save with every mission won gets the same on load.
func _raidintro() -> void:
	main.player.invincible = true
	_veteran(14)
	await _wait(0.3)
	var f = main.fight
	main.start_stage(14)
	await _wait(0.5)
	f.set_physics_process(false)
	for e in get_tree().get_nodes_in_group("foes"):
		e.queue_free()
	f._win()
	await _wait(0.5)
	f.set_physics_process(true)
	_expect("raids open after the last raid's first win", main.raids.open and Data.raids_open())
	_expect("the meter starts at 70", absf(float(Save.raids["meter"]) - 70.0) < 0.5, {"meter": Save.raids["meter"]})
	_expect("the intro was told", Save.flag("told_raids"))
	_expect("the signpost is the Watch", String(main.world.sign_node.get_meta("model", "")) == "signpost_watch")
	await _wait(4.0)
	await _shot("raidintro_banner")
	await _wait(5.0)
	await _shot("raidintro_tip")
	# an old save (before Phase D) with every mission won
	Save.save_v = 1
	Save.raids = Save.RAIDS_DEFAULT.duplicate(true)
	Save.flags.erase("told_raids")
	Save.save_game()
	Save.load_game()
	main.defences.relink_saved()
	main.raids.restore_on_load()
	_expect("an old save: the meter at 70 and the save brought up to date", absf(float(Save.raids["meter"]) - 70.0) < 0.01 and Save.save_v == SaveUpgrades.CURRENT_VERSION and Save.flag("told_raids"),
		{"meter": Save.raids["meter"], "save_v": Save.save_v})


## Removes a placed defence piece (tests).
func _remove_piece(pc: Dictionary) -> void:
	var d = main.defences
	main.world.remove_tag("piece_%d" % int(pc["id"]))
	(pc["node"] as Node3D).queue_free()
	d.pieces.erase(pc)
	if pc.get("src") != null:
		Save.placed.erase(pc["src"])


## The raid kinds (--raidtypes): sky brings moths, a sneak raid takes the least-guarded trail and hides it until 15 s
## before, an elite raid's last wave is led by a boss, the siege's pool; no raccoon in any raid; no kind 3 times in a
## row; every warning 30-60 s with and without the Lookout.
func _raidtypes() -> void:
	await _raid_camp()
	var rd = main.raids
	var f = main.fight
	var r: Dictionary = Save.raids
	var w = main.world
	r["first_done"] = true
	r["held"] = 6
	r["since_elite"] = 6
	# barricades on trails 0, 1 and 2 only
	for pc in main.defences.pieces.duplicate():
		if pc["type"] == "barricade" and (pc["slot"] as Array).size() == 2 and int(pc["slot"][0]) == 3:
			_remove_piece(pc)
	Save.save_game()
	await _wait(3.0)
	var guards: Array = []
	for ln in 4:
		guards.append(main.defences.lane_guard(ln))
	_log("lane guard", {"guard": guards})
	var raccoon := false
	for kind in ["siege", "sky", "sneak", "elite"]:
		rd.forced_type = kind
		_clear_raid_state()
		main.player.global_position = Vector3(0, 0, 1.6)
		await _raid_to_warning()
		var spec: Dictionary = f.raid
		var plan: Dictionary = r["plan"]
		var pool: Array = (spec["chapters"][0]["pool"] as Array).map(func(p): return String(p[0]))
		if pool.has("raccoon"):
			raccoon = true
		_expect("%s: the warning is 30-60 s" % kind, f._breather >= 29.9 and f._breather <= 60.1, {"breather": f._breather})
		if kind == "sneak":
			_expect("sneak: all four trails are planned", (plan["lanes"] as Array) == range(Data.lane_count()), {"lanes": plan["lanes"]})
			await _wait(1.0)
			_expect("sneak: hidden, no Gloom on its trail before the reveal", rd.trail_text() == "trail unknown" and float(w.gloom[3]) < 0.02,
				{"text": rd.trail_text(), "gloom": w.gloom})
			f._breather = 15.4
			await _wait(1.6)
			_expect("sneak: revealed at 15 s", bool(r["run"].get("revealed", false)) and float(w.gloom[3]) > 0.05, {"gloom": w.gloom})
		if kind == "elite":
			_expect("elite: a boss leads it", ["bear", "owl", "stag"].has(String(plan["leader"])) and String(spec["leader"]) == String(plan["leader"]), {"leader": plan["leader"]})
			f.wave = f.waves() - 1                       # straight to the last wave
		f.next_phase_now()
		await _until(func(): return f.in_wave, 3.0)
		var seen := {}
		var lanes_seen := {}
		var boss_ok := false
		var t := 0.0
		while t < (14.0 if kind == "elite" else 8.0):
			await _wait(0.5)
			t += 0.5
			for e in get_tree().get_nodes_in_group("foes"):
				seen[String(e.id)] = true
				lanes_seen[int(e.patch)] = true
				if e.has_meta("leader") and main.hud.boss == e and bool(Data.enemy(String(e.id)).get("boss", false)):
					boss_ok = true
		await _shot("raidtypes_%s" % kind)
		if seen.has("raccoon"):
			raccoon = true
		_log("raid kind " + kind, {"plan": plan, "pool": pool, "seen": seen.keys(), "lanes": lanes_seen.keys()})
		match kind:
			"siege":
				_expect("siege: stumps, brutes and boars in its pool", pool.has("stump") and pool.has("brute") and pool.has("boar"), {"pool": pool})
			"sky":
				_expect("sky: moths come", seen.has("moth"), {"seen": seen.keys()})
			"sneak":
				_expect("sneak: groups arrive from different trails", lanes_seen.size() >= 2, {"lanes": lanes_seen.keys()})
			"elite":
				_expect("elite: its last wave's boss has the boss bar", boss_ok, {"seen": seen.keys()})
		_reset_fight()
		_clear_raid_state()
		w.settle_gloom()
		await _wait(1.5)
	rd.forced_type = ""
	_expect("no raccoon in any raid", not raccoon)
	# never the same kind 3 times in a row (20 rolls)
	r["last_types"] = []
	r["since_elite"] = 0
	var rolls: Array = []
	var bad := false
	for k in 20:
		var kind2: String = rd._pick_kind(10)
		var lt: Array = r["last_types"]
		if lt.size() >= 2 and String(lt[lt.size() - 1]) == kind2 and String(lt[lt.size() - 2]) == kind2:
			bad = true
		rolls.append(kind2)
		lt.append(kind2)
		while lt.size() > 2:
			lt.pop_front()
		r["since_elite"] = 0 if kind2 == "elite" else int(r["since_elite"]) + 1
	_expect("no kind 3 times in a row in 20 rolls", not bad, {"rolls": rolls})
	# every warning 30-60 s, with and without the Lookout
	var lens: Array = []
	var ok := true
	for look in [false, true]:
		if look:
			Save.unlocks.append("watch:lookout")
		for kind3 in ["siege", "sky", "sneak", "elite"]:
			for first in [false, true]:
				for called in [false, true]:
					var s: float = rd.warn_seconds({"type": kind3, "first": first}, called)
					lens.append(s)
					if s < 30.0 or s > 60.0:
						ok = false
	Save.unlocks.clear()
	_expect("every warning is 30-60 s", ok, {"lengths": lens})
	_expect("normal 45, called 30; with the Lookout 60 and 45", rd.warn_seconds({"type": "siege"}, false) == 45.0 and rd.warn_seconds({"type": "siege"}, true) == 30.0)


## Keeping the camp up (--wear): wear from a raid (the home at 70% next time), the Patch price, Mend some in priority
## order with few leaves, Mend all with plenty, and the camp's condition back to 100%.
func _wear() -> void:
	await _raid_camp()
	var rd = main.raids
	var f = main.fight
	var st = main.stations
	var r: Dictionary = Save.raids
	r["first_done"] = true
	await _wait(3.0)
	await _raid_to_warning()
	f.next_phase_now()
	await _until(func(): return f.in_wave, 3.0)
	f.set_physics_process(false)
	for e in get_tree().get_nodes_in_group("foes"):
		e.queue_free()
	st.hurt_building("home", st.full_hp("home") * 0.3 + 1.0)
	rd.on_wave_held(1)
	_expect("wear after a raid wave: {home: 0.3}", Save.wear == {"home": 0.3}, {"wear": Save.wear})
	_reset_fight()
	_clear_raid_state()
	f.set_physics_process(true)
	st.reset_hp()
	_expect("the next reset_hp: the home at 70%", absf(float(st.hp["home"]) - st.full_hp("home") * 0.7) < 0.5, {"hp": st.hp["home"], "full": st.full_hp("home")})
	var ruin_l := float(st.repair_cost("home")["leaves"])
	var want := maxi(5, int(ceil(ruin_l * 0.3 * 0.5 - 0.0001)))
	_expect("the Patch price follows the formula", int(st.patch_cost("home")["leaves"]) == want, {"got": st.patch_cost("home"), "want": want})
	st.refresh()
	var cc: Dictionary = rd.camp_check()
	_expect("the camp is not whole (condition under 100%)", float(cc["condition"]) < 0.999 and (cc["items"] as Array).size() == 1, {"cc": cc["condition"]})
	main.player.global_position = Vector3(1.0, 0, 2.6)
	main.closeup_at = st.nodes["home"]
	main.closeup = Vector3(1.6, 2.6, 4.8)
	await _wait(0.5)
	await _shot("wear_home")
	main.closeup = Vector3.ZERO
	main.closeup_at = null
	# more to mend: a ruin, a wrecked barricade, a worn stall
	st.ruin("well")
	var bar: Dictionary = {}
	for pc in main.defences.pieces:
		if pc["type"] == "barricade" and pc.get("src") != null:
			bar = pc
			break
	main.defences._wreck(bar, 0.2)
	main.defences._save_wrecks()
	Save.wear["stall"] = 0.5
	st.refresh()
	cc = rd.camp_check()
	var kinds: Array = (cc["items"] as Array).map(func(it): return String(it["kind"]) + ":" + String(it.get("id", "piece")))
	_expect("the camp check in priority order: ruins, wrecks, wear (highest first)", kinds == ["ruin:well", "wreck:piece", "wear:stall", "wear:home"], {"items": kinds})
	await _at_ring(st.rings["sign"])
	await _wait(0.8)
	await _shot("wear_watch_card")
	# Mend some: leaves for the ruin and the wreck only
	var c_ruin := int(cc["items"][0]["cost"]["leaves"])
	var c_wreck := int(cc["items"][1]["cost"]["leaves"])
	Save.leaves = c_ruin + c_wreck + 2
	var row: Dictionary = rd.camp_row(cc)
	_expect("the row reads Mend some", String(row["label"]) == "Mend some", {"row": row["label"], "note": row["note"]})
	main.hud.refresh_card()
	await _wait(0.4)
	await _shot("wear_mend_some_card")
	rd.mend_all()
	await _wait(0.8)
	_expect("Mend some mended the ruin and the wreck first", not Save.ruined.has("well") and not bar["wrecked"] and Save.wear.has("stall") and Save.wear.has("home")
		and Save.leaves == 2, {"ruined": Save.ruined, "wear": Save.wear, "leaves": Save.leaves})
	await _shot("wear_mend_some")
	Save.leaves = 5000
	main.hud.refresh_card()
	await _wait(0.3)
	_expect("with plenty it reads Mend all", String(rd.camp_row(rd.camp_check())["label"]) == "Mend all")
	rd.mend_all()
	await _wait(0.8)
	cc = rd.camp_check()
	_expect("Mend all: nothing left, the camp at 100%", (cc["items"] as Array).is_empty() and Save.wear.is_empty() and absf(float(cc["condition"]) - 1.0) < 0.001,
		{"cc": cc["condition"], "wear": Save.wear})
	await _shot("wear_mended")
	# the Patch row on a building's own card
	Save.wear["cottage"] = 0.4
	st.refresh()
	await _at_ring(st.rings["cottage"])
	await _wait(0.8)
	await _shot("wear_patch_row")
	var ok: bool = _press("Patch")
	await _wait(0.3)
	_expect("Patch on the cottage's card", ok and not Save.wear.has("cottage"))


## What Gloom shards buy (the rest of --shards): defence level 4 (hidden before every mission is won, blocked below
## home level 4, then bought), Lookout and Tracker, Gloomlit colours, the shard trade, Shardfire.
func _shard_goods() -> void:
	main.player.invincible = true
	_veteran(14)
	var st = main.stations
	var d = main.defences
	Save.shards = 1000
	Save.leaves = 20000
	Save.timber = 500
	for t in ["barricade", "tower", "spikes"]:
		Save.def_levels[t] = 3
		d.relevel(t)
	d._spawn("spikes", Vector3(2.6, 0, -6.2), 0.0)
	var w = main.hud.windows["shop"]                         # H4: the Defences shelf is the Hearthtree's Defences tab
	_expect("the Hearthtree has its Defences tab", (w.tab_ids() as Array).has("defences"), {"tabs": w.tab_ids()})
	var texts := func() -> Array: return (w.tab_spec("defences")["rows"] as Array).map(func(rw): return String(rw.get("title", "")) + " " + String(rw.get("text", "")))
	_expect("level 4 is hidden before every raid is won", not " ".join(texts.call()).contains("Shardstone"), {"rows": texts.call()})
	Save.missions_done.append(String(Data.mission(Data.mission_count() - 1)["id"]))
	main.raids.refresh_open()
	main.world.swap_sign()
	var row4: Dictionary = {}
	for rw in w.tab_spec("defences")["rows"]:
		if String(rw.get("title", "")) == "Barricades: Shardstone":
			row4 = rw
	_expect("level 4 shows once raids are open, blocked below Hearthtree level 4", not row4.is_empty() and not bool(row4["enabled"]) and String(row4.get("text", "")).contains("Hearthtree at level 4")
		and int(row4["cost"].get("shards", 0)) == 60, {"row": row4})
	Save.camp_level = 4
	main.on_camp_grown()
	await _wait(0.5)
	var leaves0 := Save.leaves
	var shards0 := Save.shards
	for t in ["barricade", "tower", "spikes"]:
		st._upgrade_defence(t)
	_expect("all three bought at level 4 (leaves and shards taken)", d.level("barricade") == 4 and d.level("tower") == 4 and d.level("spikes") == 4
		and Save.leaves == leaves0 - 1500 - 2400 - 1200 and Save.shards == shards0 - 60 - 90 - 50,
		{"levels": Save.def_levels, "leaves": [leaves0, Save.leaves], "shards": [shards0, Save.shards]})
	var bar: Dictionary = {}
	var tower: Dictionary = {}
	var spikes: Dictionary = {}
	for pc in d.pieces:
		if pc["type"] == "barricade" and bar.is_empty():
			bar = pc
		elif pc["type"] == "tower" and tower.is_empty():
			tower = pc
		elif pc["type"] == "spikes" and spikes.is_empty():
			spikes = pc
	_expect("a Shardstone barricade has 1,400 health", absf(float(bar["max_hp"]) - 1400.0) < 0.5 and String((bar["node"] as Node3D).name) == "barricade_shard", {"max": bar["max_hp"], "model": (bar["node"] as Node3D).name})
	_expect("the level 4 tower and spikes models", String((tower["node"] as Node3D).name) == "acorn_tower_4" and String((spikes["node"] as Node3D).name) == "thorn_spikes_4")
	main.player.global_position = Vector3(0, 0, 1.6)
	for pc in [bar, tower, spikes]:
		main.closeup_at = pc["node"]
		main.closeup = Vector3(1.4, 2.2, 3.4)
		await _wait(0.4)
		await _shot("shards_level4_%s" % String(pc["type"]))
	main.closeup = Vector3.ZERO
	main.closeup_at = null
	# the Watch's Lookout and Tracker
	var rd = main.raids
	rd.buy_watch("lookout")
	_expect("Lookout: a normal warning is 60 s (not 75), a called one 45", rd.has_unlock("watch:lookout") and rd.warn_seconds({"type": "siege"}, false) == 60.0
		and rd.warn_seconds({"type": "siege"}, true) == 45.0 and Save.shards == shards0 - 200 - 25)
	rd.buy_watch("tracker")
	_expect("Tracker: sneak raids can't hide", rd.has_unlock("watch:tracker") and not rd.hidden_kind({"type": "sneak"}))
	# Gloomlit colours
	_expect("Gloomlit is not in Next before it is unlocked", not st._skins("pet").any(func(s): return String(s["id"]) == "gloomlit"))
	var sh := Save.shards
	st._unlock_skin("mount", "gloomlit")
	_expect("Gloomlit unlocked for the mount: worn, and in Next", Save.mount_skin == "gloomlit" and st._skins("mount").any(func(s): return String(s["id"]) == "gloomlit")
		and Save.shards == sh - 60, {"skin": Save.mount_skin})
	if main.mount:
		main.closeup_at = main.mount
		main.closeup = Vector3(1.2, 1.2, 2.4)
		await _wait(0.4)
		await _shot("shards_gloomlit_mount")
		main.closeup = Vector3.ZERO
		main.closeup_at = null
	# the shard trade
	var l0 := Save.leaves
	sh = Save.shards
	rd.trade_shards()
	_expect("Bramble pays 100 leaves for 5 shards", Save.leaves == l0 + 100 and Save.shards == sh - 5)
	# Shardfire
	rd.unlock_fire("shardfire")
	var tint = st._flame_mat.get_shader_parameter("tint") if st._flame_mat != null else null
	_expect("Shardfire: the flame's tint is set", Save.fire_look == "shardfire" and tint != null and (tint as Vector3).is_equal_approx(Vector3(0.6, 0.65, 1.25)), {"tint": tint})
	main.closeup_at = st.nodes["campfire"]
	main.closeup = Vector3(0.8, 1.3, 2.4)
	await _wait(0.5)
	await _shot("shards_shardfire")
	main.closeup = Vector3.ZERO
	main.closeup_at = null
	await _at_ring(st.rings["sign"])
	await _wait(0.8)
	await _shot("shards_watch_card")
	await _at_ring(st.rings["stall"])
	await _wait(0.8)
	await _shot("shards_stall_card")
	_log("shard goods", {"shards": Save.shards, "unlocks": Save.unlocks, "def_levels": Save.def_levels})


## Frame cost of a big Gloom Raid (--raidperf, with --quality=low|medium|high): a level 23 siege on two trails, the cat
## holding a trail mouth. Logs PERF lines and writes raidperf.json; shots of the warning (the Gloom on the trails) and
## the raid card.
func _raidperf() -> void:
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await _raid_camp()
	var f = main.fight
	var r: Dictionary = Save.raids
	r["first_done"] = true
	r["plan"] = {"type": "siege", "lanes": [0, 1], "level": 23, "leader": "herald", "first": false, "seed": 1234567, "called": false}
	await _wait(3.0)
	await _raid_to_warning()
	main.player.global_position = main.world.edge_point(0) * 1.3
	await _wait(2.5)
	await _shot("raidperf_warning")
	await _at_ring(main.stations.rings["sign"])
	await _wait(0.8)
	await _shot("raidperf_card")
	main.player.global_position = main.world.edge_point(0) * 1.4
	f.next_phase_now()
	await _wait(12.0)
	var out := {"quality": Quality.level, "strength": f.strength(), "spec": {"level": f.raid["level"], "count": f.raid["count"], "max_alive": f.raid["max_alive"]}}
	out["raid"] = await _measure("raid", 30.0, func(_t: float): main.player.global_position = main.player.global_position.lerp(main.world.edge_point(0) * 1.4, 0.02))
	await _shot("raidperf_fight")
	var pf := FileAccess.open(shots.path_join("raidperf.json"), FileAccess.WRITE)
	if pf:
		pf.store_string(JSON.stringify(out, "  "))
	_log("raidperf", out)


# ---------------------------------------------------------------- Phase E: the Burrows (tests in autotest_e.gd)
func _phase_e() -> bool:
	var e = load("res://scripts/autotest_e.gd").new()
	e.t = self
	e.main = main
	add_child(e)
	return await e.run()


# ---------------------------------------------------------------- Phase F: missions, enemies, home goals (autotest_f_*.gd)
## --fightf (roads, waves, bonuses), --enemyf (boar daze, siege, Golden Grub, Gloom Totem), --homegoals (the home's
## goal lists, mission gates, caps). Each file's run() does its checks and logs EXPECT PASS / EXPECT FAIL lines.
## H1: --pools (autotest_pools.gd: the object pools and the event board) and --saves (autotest_saves.gd: the sample
## saves); a mode whose file is missing logs one EXPECT FAIL saying so. H3: --timers, --content, --bag (and the old
## --inventory), --garden, --cook and --feed have their own files too (the old garden, cook and feed checks are gone).
func _phase_f() -> bool:
	var a := Data.args()
	var file := ""
	if a.has("--fightf"):
		file = "res://scripts/autotest_f_fight.gd"
	elif a.has("--enemyf"):
		file = "res://scripts/autotest_f_enemy.gd"
	elif a.has("--homegoals"):
		file = "res://scripts/autotest_f_home.gd"
	elif a.has("--missions"):
		file = "res://scripts/autotest_missions.gd"
	elif a.has("--rows"):                               # Phase G2: barricade rows, tower repair
		file = "res://scripts/autotest_g2_def.gd"
	elif a.has("--campg"):                              # Phase G2: the Hearthtree, Market, pet, the automatic Well
		file = "res://scripts/autotest_g2_camp.gd"
	elif a.has("--cards"):                              # Phase G2: the shop-style cards (and screenshots)
		file = "res://scripts/autotest_g2_cards.gd"
	elif a.has("--bowshop"):                            # Phase G3: the Bow Shop, the five bows, pierce, fan, burn
		file = "res://scripts/autotest_g3_bow.gd"
	elif a.has("--saddlery"):                           # Phase G4: the Saddlery, the mount's skills and attachments
		file = "res://scripts/autotest_g4_saddle.gd"
	elif a.has("--mountedaim"):
		file = "res://scripts/autotest_mounted_aim.gd"
	elif a.has("--tailor"):                             # 23 Nov 2026: the Tailor's Nook and the cat's outfits
		file = "res://scripts/autotest_cat_skins.gd"
	elif a.has("--pools"):                              # H1: the object pools and the event board
		file = "res://scripts/autotest_pools.gd"
	elif a.has("--saves"):                              # H1: the sample saves load, upgrade and save (autotest_saves.gd)
		file = "res://scripts/autotest_saves.gd"
	elif a.has("--settings"):                          # H2: the Settings window
		file = "res://scripts/autotest_settings.gd"
	elif a.has("--timers"):                            # H3: the Timers jobs and the clock rule
		file = "res://scripts/autotest_timers.gd"
	elif a.has("--content"):                           # H3: the content folders and index.json
		file = "res://scripts/autotest_content.gd"
	elif a.has("--bag") or a.has("--inventory"):       # H3: the Bag (and its potions); --inventory was the H2 name
		file = "res://scripts/autotest_bag.gd"
	elif a.has("--garden"):                            # H3: the garden's window, real-time growth, picking
		file = "res://scripts/autotest_garden.gd"
	elif a.has("--cook"):                              # H3: the cooking pot's window, cooking and collecting
		file = "res://scripts/autotest_cook.gd"
	elif a.has("--feed"):                              # H3: the potions and the mount (the old --feed checks)
		file = "res://scripts/autotest_potions.gd"
	elif a.has("--buildmenu"):                         # H4: the build menu, its icon, the camera and the rise
		file = "res://scripts/autotest_build_menu.gd"
	if file == "":
		return false
	if not ResourceLoader.exists(file):
		_expect("the test file %s is there" % file, false)
		return true
	var e = load(file).new()
	e.t = self
	e.main = main
	add_child(e)
	await e.run()
	return true


# ---------------------------------------------------------------- the camp's layout and the HUD (autotest_layout.gd)
func _layout_hud() -> bool:
	var e = load("res://scripts/autotest_layout.gd").new()
	e.t = self
	e.main = main
	add_child(e)
	return await e.run()
