extends Node3D
## A Burrows run (docs/DUNGEON_SPEC.md): the cat (with its pet and mount) walks a dungeon, one continuous map at night
## built far from the camp (dungeon_map.gd, from res://data/dungeons/<map>.json): a path past fights (packs asleep that
## wake together, holes and the dark that spawn monsters as the cat passes) to a boss in a big arena, or a treasure
## clearing. This node is main.burrows.runner, and main.area points to it while the cat is in a Burrow: it hands the
## camp's code what the map needs (constrain, the camera, spawning, the cat going down). Replays are levels of the same
## map (Save burrow stats "depth" = the highest level beaten). Saved at every checkpoint (the way in, the Moonwell, the
## arena gate), when hurt and on pause; "Go back in" starts at the last checkpoint. Nothing moves while the game is closed.

const MapScript := preload("res://scripts/dungeon_map.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const TrapScript := preload("res://scripts/trap.gd")
const AREA_PATCH := 99              # monsters in a Burrow: never a trail index (-1 would silently use the last trail)
const RUN_V := 2                    # the saved run's format (1 = Phase E's room runs: closed kindly)

var b                               # main.burrows (the camp side: the hollows, keys, the card)
var main
var run := {}                       # the live copy of Save.burrow_run while a run is on
var map                             # dungeon_map.gd: kept between runs (building it is the slow part)
var active := false                 # the cat is in a Burrow
var leaving := false                # a fade into or out of the Burrow is on
var env: Environment
var fights: Array = []              # {"id", "name", "def", "c" (world), "s", "i", "state": far/asleep/awake/done, "foes", "spawners", "pip"}
var checkpoints: Array = []         # {"id", "name", "at" (world), "r", "s"}, along the path
var chests := {}                    # id -> {"def", "node", "at", "state"}
var traps: Array = []               # trap.gd nodes
var strikes := 0                    # spore bombs called (for the tests)
var strike_at: Array = []           # ... and where the last one lands: [Vector3, radius]
var _sun_was := -1.0
var _sun_col := Color.WHITE
var _fill_was := -1.0
var _save_cd := 0.0
var _sum_t := 0.0
var _last_sum := -1.0
var _stuck_t := 0.0
var _slow_t := 0.0
var _boss = null
var _boss_down := false
var _seal_t := 0.0
var _seal_due := false              # the Moss Warden waits sealed behind the beaten boss (the lift waits too)
var _drink_t := 0.0
var _halo: Node3D
var _lights: Array = []
var _buds: Array = []               # dew buds blooming where a fight was won
var _grub = null                    # the Amber Grub, while one is out
var _grub_t := 0.0
var _zone_in := false               # the cat has walked into the unhurt chest's stretch
var _zone_hurt := false             # ...and was hurt there
var _nook_guard: Array = []         # the guard that burst out of a broken Gloom seal, and its friends
var _lead := Vector2.ZERO           # the camera's lead along the path (eased)
var _moonwell_seen := false


func cfg() -> Dictionary:
	return Data.burrow_cfg()


func level() -> int:
	return int(run.get("level", 1))



func bid() -> String:
	return String(run.get("burrow", Data.burrow_list()[0]["id"]))


func map_id() -> String:
	return String(run.get("map", Data.burrow_map_id(bid())))


func data() -> Dictionary:
	return Data.dungeon(map_id())


func tier() -> Dictionary:
	return Data.depth_tier(bid(), level())


func map_name() -> String:
	return String(data().get("name", Data.burrow_def(bid()).get("name", "The Burrow")))


func end_type() -> String:
	return String(data().get("end", {}).get("type", "boss"))


# ---------------------------------------------------------------- going in
## A new run at `lvl` (the card's Go in): free; a Hollow key (when the card's choice is on) gives a boon from the start.
func start_run(id: String, lvl: int) -> void:
	if active or leaving or b.blocker() != "":
		return
	var with_key: bool = b.use_key and Save.burrow_keys > 0
	if with_key:
		Save.burrow_keys -= 1
	var st := Save.burrow_stats(id)
	st["runs"] = int(st["runs"]) + 1
	var s := hash([int(st["runs"]), lvl, id])
	var boons: Array = []
	if with_key:
		boons.append(_key_boon(s))
	var mid := Data.burrow_map_id(id)
	if b.map_override != "":
		mid = b.map_override
	run = {"v": RUN_V, "map": mid, "map_v": int(Data.dungeon(mid).get("version", 1)), "burrow": id, "level": lvl, "seed": s,
		"checkpoint": "wayin", "cleared": [], "chests": [], "hp": main.player.hp, "boons": boons, "satchel": {}, "spring_used": false,
		"boon_taken": false, "first_run": int(st["runs"]) == 1 and lvl == 1, "meal": "", "key": with_key, "boss_down": false, "woke": false}
	Save.burrow_run = run
	Save.save_game()
	await _go_down(false)


## "Go back in": the saved run at its last checkpoint, with its health, boons and satchel. No key is spent.
func resume_run() -> void:
	if active or leaving or b.blocker() != "" or Save.burrow_run.is_empty():
		return
	run = Save.burrow_run.duplicate(true)
	await _go_down(true)


func _key_boon(s: int) -> String:
	var ids: Array = (cfg()["boons"] as Dictionary).keys()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([s, "key"])
	return String(ids[rng.randi() % ids.size()])


func _go_down(resumed: bool) -> void:
	leaving = true
	main.hud.hide_card()
	if main.defences.placing != "":
		main.defences.stop_placing()
	if main.fishing != null:
		main.fishing.stop("")
	main.frozen = true
	main.player.frozen = true
	await main.hud.fade(1.0, float(cfg()["fade_s"]))
	active = true
	main.area = self
	Data.run_mods = _mods()
	if main.mount != null and main.mount.resting <= 0.0:
		main.mount.hp = main.mount.max_hp()                    # a saddle's extra health comes with it
	if resumed:
		main.player.hp = clampi(int(run.get("hp", main.player.hp)), 1, Data.cat_max_hp())
	else:
		main.player.hp = mini(main.player.hp + int(Data.run_mods.get("hp", 0)), Data.cat_max_hp())
	if bool(cfg().get("meals_in_runs", true)) and main.cooking != null and Save.meal_ready != "":
		main.cooking.eat("run")                               # a dish waiting in the pot goes down with the cat
		run["meal"] = Save.meal_on
	_build_map()
	_env_on()
	_setup(resumed)
	var tr = main.hud.tip_ring()
	if tr != null and not owns(tr.global_position):
		main.hud.drop_tip_ring()                          # a camp tip's arrow would point 400 m away
	var p = main.player
	var cp := _checkpoint(String(run.get("checkpoint", "wayin")))
	var start: Vector3 = map.wpt(data().get("wayin", {}).get("start", [0.0, 0.6])) if String(run.get("checkpoint", "wayin")) == "wayin" or cp.is_empty() else cp["at"]
	p.global_position = map.constrain(start, 0.3, false)
	p.facing = PI
	p.target = null
	if main.pet != null:
		main.pet.global_position = p.global_position + Vector3(0.5, 1.1, 0.3)
	if main.mount != null:
		main.mount.come_to(p.global_position + (Vector3.ZERO if p.riding else Vector3(1.2, 0, 0.6)))
	_lead = Vector2.ZERO
	main.snap_camera()
	main.hud.refresh()
	main.hud.refresh_build()
	b.refresh()
	_save_run(true)
	await main.hud.fade(0.0, float(cfg()["fade_s"]))
	main.frozen = false
	main.player.frozen = false
	leaving = false
	main.hud.banner(map_name(), Color.html(String(data()["theme"].get("halo", "#FFC877"))), "Level %d · %s" % [level(), _plan_text()])
	if not Save.flag("told_dash") and main.player.has_method("dash"):
		Save.set_flag("told_dash")
		main.hud.tip_after("Flick your thumb to dash! Nothing can hurt you mid-dash, and dodging through an attack makes your next arrow hit double.", null)


## "6 fights and Mossback", "1 fight and a treasure".
func _plan_text() -> String:
	var n := 0
	for f in data().get("fights", []):
		if bool(f.get("pip", true)):
			n += 1
	var e: Dictionary = data().get("end", {})
	var tail := "a treasure"
	if String(e.get("type", "boss")) == "boss":
		tail = String(Data.enemy(String(e.get("kind", "bear")))["name"])
	return "%d fight%s and %s" % [n, "" if n == 1 else "s", tail]


## The map: built the first time (behind the fade), then kept hidden between runs and reused.
func _build_map() -> void:
	if map != null and is_instance_valid(map) and (map.map_id != map_id() or int(map.get_meta("quality", -1)) != Quality.level):
		map.queue_free()
		map = null
	if map == null or not is_instance_valid(map):
		map = MapScript.new()
		add_child(map)
		var o: Array = cfg()["origin"]
		map.build(self, data(), Vector3(float(o[0]), 0, float(o[2])))
		map.set_meta("quality", Quality.level)
	map.visible = true
	map.reset()


## The map's night: a camera environment of its own (never a second WorldEnvironment), the sun turned into a dim blue
## moon and the fill light down (both restored on the way out), Sprig's lantern glow, and on Medium and High a few
## lights at the lanterns nearest the cat.
func _env_on() -> void:
	var th: Dictionary = data().get("theme", {})
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.html(String(th.get("sky", "#070C1C")))
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.html(String(th.get("ambient", "#5266A0")))
	env.ambient_light_energy = float(th.get("ambient_energy", 0.6))
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white = 5.0
	env.fog_enabled = true
	env.fog_light_color = Color.html(String(th.get("fog", "#0E1830")))
	env.fog_density = float(th.get("fog_density", 0.011))
	env.fog_sky_affect = 0.0
	env.glow_enabled = Quality.glow()
	env.glow_intensity = 0.75
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 0.85
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.1
	env.adjustment_contrast = 1.08
	main.cam.environment = env
	if not Quality.changed.is_connected(_on_quality):
		Quality.changed.connect(_on_quality)
	var sun = main.world.sun
	if _sun_was < 0.0:
		_sun_was = sun.light_energy
		_sun_col = sun.light_color
	sun.light_energy = float(th.get("moon_energy", 0.6))
	sun.light_color = Color.html(String(th.get("moon", "#9FB6FF")))
	var fill = main.world.get("fill_light")
	if fill != null:
		if _fill_was < 0.0:
			_fill_was = fill.light_energy
		fill.light_energy = float(th.get("fill_energy", 0.14))
	_make_halo(Color.html(String(th.get("halo", "#FFC877"))))
	_make_lights(Color.html(String(th.get("lantern", "#FFB35C"))))


func _on_quality() -> void:
	if env != null:
		env.glow_enabled = Quality.glow()
	for lt in _lights:
		if is_instance_valid(lt):
			lt.visible = Quality.lamps() and active


func _env_off() -> void:
	main.cam.environment = null
	env = null
	if _sun_was >= 0.0:
		main.world.sun.light_energy = _sun_was
		main.world.sun.light_color = _sun_col
		_sun_was = -1.0
	var fill = main.world.get("fill_light")
	if fill != null and _fill_was >= 0.0:
		fill.light_energy = _fill_was
		_fill_was = -1.0
	if _halo != null and is_instance_valid(_halo):
		_halo.queue_free()
	_halo = null
	for lt in _lights:
		if is_instance_valid(lt):
			lt.queue_free()
	_lights.clear()


## Sprig glows like a lantern: an unshaded soft disc and a pool of light on the ground (they work on Low), and on
## Medium and High one small light on top.
func _make_halo(col: Color) -> void:
	if _halo != null and is_instance_valid(_halo):
		_halo.queue_free()
	_halo = Node3D.new()
	add_child(_halo)
	var disc := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.9)
	disc.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = _soft_disc()
	m.albedo_color = Color(col.r, col.g, col.b, 0.75)
	disc.material_override = m
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disc.name = "disc"
	_halo.add_child(disc)
	var pool := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(4.4, 4.4)
	pool.mesh = pm
	var m2 := m.duplicate() as StandardMaterial3D
	m2.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	m2.albedo_color = Color(col.r, col.g, col.b, 0.26)
	pool.material_override = m2
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pool.name = "pool"
	_halo.add_child(pool)
	if Quality.lamps():
		var lt := OmniLight3D.new()
		lt.light_color = col
		lt.light_energy = 0.9
		lt.omni_range = 4.5
		lt.add_to_group("lamp")
		lt.name = "lamp"
		_halo.add_child(lt)


## Medium and High: a few lights (theme.lights, 4) that go to the lanterns and torches nearest the cat (with Sprig's,
## five: under the Mobile renderer's 8 lights a mesh). Low has none: the floor's baked pools and halos do the work.
func _make_lights(col: Color) -> void:
	for lt in _lights:
		if is_instance_valid(lt):
			lt.queue_free()
	_lights.clear()
	for k in int(data().get("theme", {}).get("lights", 3)):
		var lt := OmniLight3D.new()
		lt.light_color = col
		lt.light_energy = float(data().get("theme", {}).get("light_energy", 1.3))
		lt.omni_range = float(data().get("theme", {}).get("light_range", 5.5))
		lt.omni_attenuation = 1.4
		lt.shadow_enabled = false
		lt.add_to_group("lamp")
		lt.visible = false
		add_child(lt)
		_lights.append(lt)


func _place_lights() -> void:
	if not Quality.lamps() or map == null:
		for lt in _lights:
			lt.visible = false
		return
	var cat: Vector3 = main.player.global_position
	var near: Array = []
	for l in map.lamps:
		var dd: float = (l as Vector3).distance_to(cat)
		if dd < 20.0:
			near.append([dd, l])
	near.sort_custom(func(a, c): return float(a[0]) < float(c[0]))
	for k in _lights.size():
		var lt: OmniLight3D = _lights[k]
		lt.visible = k < near.size()
		if lt.visible:
			lt.global_position = near[k][1]


static var _disc_tex: ImageTexture


static func _soft_disc() -> ImageTexture:
	if _disc_tex != null:
		return _disc_tex
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var dd := Vector2(x + 0.5 - n * 0.5, y + 0.5 - n * 0.5).length() / (n * 0.5)
			var a := clampf(1.0 - dd, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	_disc_tex = ImageTexture.create_from_image(img)
	return _disc_tex


# ---------------------------------------------------------------- what the map holds this run
## The run's state on the map: the fights (cleared ones before the checkpoint stay cleared; after it they are full
## again), the checkpoints, the way home, chests, the Moonwell, the traps and the end.
func _setup(resumed: bool) -> void:
	_reset_state()
	var dd := data()
	checkpoints.clear()
	for c in dd.get("checkpoints", []):
		var at: Vector3 = map.wpt(c["at"])
		checkpoints.append({"id": String(c["id"]), "name": String(c.get("name", c["id"])), "at": at, "r": float(c.get("r", 2.5)),
			"s": map.progress(map.m2(at)).x})
	checkpoints.sort_custom(func(a, c): return float(a["s"]) < float(c["s"]))
	var cp := _checkpoint(String(run.get("checkpoint", "wayin")))
	var cp_s: float = float(cp.get("s", 0.0))
	fights.clear()
	var i := 0
	for f in dd.get("fights", []):
		var c: Vector3 = map.wpt(f["at"])
		var fs: float = map.progress(map.m2(c)).x
		var fd := {"id": String(f["id"]), "name": String(f.get("name", f["id"])), "def": f, "c": c, "s": fs, "i": i, "state": "far",
			"foes": [], "spawners": [], "pip": bool(f.get("pip", true))}
		for sp in f.get("spawners", []):
			var sm: Array = map.sample(map.s_of(sp["line_s"]))
			var right: Vector2 = map.right_of(sm[1])
			var half := float(sm[2]) + 1.2
			var fr: Array = []
			for v in sp.get("from", []):
				fr.append(map.wpt(v))
			fd["spawners"].append({"def": sp, "fired": false, "a": map.w2((sm[0] as Vector2) + right * half), "b": map.w2((sm[0] as Vector2) - right * half),
				"hole": map.wpt(sp["hole"]) if sp.has("hole") else Vector3.ZERO, "from": fr})
		fights.append(fd)
		i += 1
	# resumed: only fights won before the checkpoint stay won
	if resumed:
		var keep: Array = []
		for fd in fights:
			if (run.get("cleared", []) as Array).has(fd["id"]) and float(fd["s"]) < cp_s:
				keep.append(fd["id"])
		run["cleared"] = keep
		if String(run.get("checkpoint", "wayin")) == "wayin" and keep.is_empty() and (run.get("satchel", {}) as Dictionary).is_empty():
			run["woke"] = false                                # back at the start with nothing won: the way home is open again
	for fd in fights:
		if (run.get("cleared", []) as Array).has(fd["id"]):
			fd["state"] = "done"
			for sp in fd["spawners"]:
				sp["fired"] = true
	_setup_wayin()
	_setup_chests()
	_setup_moonwell()
	_setup_traps()
	_setup_end()
	_moonwell_seen = String(run.get("checkpoint", "")) == "moonwell"


func _reset_state() -> void:
	_save_cd = 0.0
	_sum_t = 0.0
	_last_sum = -1.0
	_stuck_t = 0.0
	_slow_t = 0.0
	_boss = null
	_boss_down = bool(run.get("boss_down", false))
	_seal_t = 0.0
	_seal_due = false
	_drink_t = 0.0
	_buds.clear()
	_grub = null
	_zone_in = false
	_zone_hurt = false
	_nook_guard.clear()
	chests.clear()
	for tr in traps:
		if is_instance_valid(tr):
			tr.queue_free()
	traps.clear()


func _checkpoint(id: String) -> Dictionary:
	for c in checkpoints:
		if String(c["id"]) == id:
			return c
	return {}


## The way in: the hollow's far side behind the cat, and its marker ("Go home") while nothing has woken.
func _setup_wayin() -> void:
	var wi: Dictionary = data().get("wayin", {})
	if wi.has("home_ring"):
		var rg = map.add_ring("home", map.wpt(wi["home_ring"]), _card_home, Color(1.0, 0.82, 0.3))
		rg.visible = not bool(run.get("woke", false))


func _card_home() -> Dictionary:
	var note := "Your key comes back" if bool(run.get("key", false)) else "Back to the camp, nothing lost"
	return {"title": "The way home", "sub": "Up the hollow, before anything wakes", "anchor": main.player.global_position + Vector3(0, 2.0, 0), "rows": [
		{"text": "Go home", "note": note, "cost": {}, "label": "Go home", "enabled": not leaving and not bool(run.get("woke", false)), "action": _back_up}]}


## The Gloom-bound chest (open it, or break the seal for twice the loot and a guard) and the chest that opens only for
## a cat that crossed its stretch unhurt.
func _setup_chests() -> void:
	for c in data().get("chests", []):
		var id := String(c["id"])
		var at: Vector3 = map.wpt(c["at"])
		var done: bool = (run.get("chests", []) as Array).has(id)
		var node: Node3D = map.add_prop("chest_" + id, "burrow_chest", at, 0.0, 1.0)
		map.obstacles.append([map.m2(at), 0.45])
		chests[id] = {"def": c, "node": node, "at": at, "state": "done" if done else "shut"}
		if done:
			_lid_open(node, true)
			continue
		if String(c.get("type", "")) == "sealed":
			map.add_prop("seal_" + id, "gloom_seal", at)
			map.add_ring("chest_" + id, map.wpt(c.get("ring", c["at"])), _card_sealed.bind(id))
		elif String(c.get("type", "")) == "unhurt":
			var zone: Array = c.get("zone", [0.0, 0.0])
			chests[id]["zone"] = [map.s_of(zone[0]), map.s_of(zone[1])]


func _lid_open(chest: Node3D, quick: bool) -> void:
	var lid := Props.find_part(chest, "lid")
	if lid == null:
		return
	if quick:
		lid.rotation.x = deg_to_rad(-100.0)
	else:
		lid.create_tween().tween_property(lid, "rotation:x", deg_to_rad(-100.0), 0.4).set_trans(Tween.TRANS_BACK)


func _card_sealed(id: String) -> Dictionary:
	var ch: Dictionary = chests.get(id, {})
	var ok: bool = not leaving and String(ch.get("state", "")) == "shut"
	return {"title": "A Gloom-bound chest", "sub": "Crusted with Gloom crystals", "anchor": main.player.global_position + Vector3(0, 2.0, 0), "rows": [
		{"text": "Open it", "note": "Amber, maybe glowstone", "cost": {}, "label": "Open", "enabled": ok, "action": _chest_open.bind(id)},
		{"text": "Break the Gloom seal", "note": "Twice the loot · a Gloomtouched guard bursts out", "cost": {}, "label": "Break", "enabled": ok, "action": _chest_break.bind(id)}]}


func _chest_open(id: String) -> void:
	var ch: Dictionary = chests.get(id, {})
	if ch.is_empty() or String(ch["state"]) != "shut":
		return
	ch["state"] = "done"
	_drop_seal(id, false)
	main.hud.hide_card()
	_open_chest(ch["node"], "chest", false)
	_chest_done(id)


func _chest_break(id: String) -> void:
	var ch: Dictionary = chests.get(id, {})
	if ch.is_empty() or String(ch["state"]) != "shut":
		return
	ch["state"] = "guarded"
	_drop_seal(id, true)
	main.hud.hide_card()
	main.shake(0.3)
	var c: Dictionary = ch["def"]
	var r := _rng("guard:" + id)
	var elites: Array = (tier().get("elites", ["thornling"]) as Array).filter(func(k): return Data.b["enemies"].has(String(k)))
	var ek := String(elites[r.randi() % elites.size()]) if not elites.is_empty() else "thornling"
	_nook_guard.clear()
	var g = spawn(ek, map.wpt(c.get("guard", c["at"])), {"gloomtouched": true, "elite": true})
	if g != null:
		g.set_meta("guard", id)
		_nook_guard.append(g)
	for a in c.get("adds", []):
		var e = spawn(_pool_kind(r, tier()["pool"]), map.wpt(a), {})
		if e != null:
			e.set_meta("guard", id)
			_nook_guard.append(e)
	run["woke"] = true
	_hide_home()
	main.hud.banner("The seal breaks!", Color(0.85, 0.55, 1.0), "Beat its guard for twice the loot")


func _drop_seal(id: String, shatter: bool) -> void:
	var seal = map.parts.get("seal_" + id)
	if seal != null and is_instance_valid(seal):
		if shatter:
			Fx.shockwave(main, (seal as Node3D).global_position, 1.8)
			Fx.kill(main, (seal as Node3D).global_position + Vector3(0, 0.5, 0), Color(0.78, 0.55, 1.0))
		(seal as Node3D).queue_free()
	var rg = map.parts.get("chest_" + id + "_ring")
	if rg != null and is_instance_valid(rg):
		rg.visible = false


func _chest_done(id: String) -> void:
	if not (run["chests"] as Array).has(id):
		(run["chests"] as Array).append(id)
	_save_run(true)


## The Moonwell: the spring (wade in once to heal), two boon shrines (take one) and a root lift home.
func _setup_moonwell() -> void:
	var mw: Dictionary = data().get("moonwell", {})
	if mw.is_empty():
		return
	var base := {"in": mw.get("in", "moonwell")}
	var at := func(v: Array) -> Vector3: return map.wpt({"in": base["in"], "x": float(v[0]), "z": float(v[1])})
	map.add_prop("spring", "burrow_spring", at.call(mw.get("spring", [0.0, 0.0])))
	var lf: Array = mw.get("lift", [4.0, 0.0, -90.0])
	map.add_prop("lift", "root_lift", at.call(lf), deg_to_rad(float(lf[2])))
	map.add_ring("lift", at.call(mw.get("lift_ring", [3.0, 0.0])), _card_lift.bind("moonwell"))
	if not bool(run.get("boon_taken", false)):
		var offer := _boon_offer()
		var shr: Array = mw.get("shrines", [])
		for k in mini(2, mini(offer.size(), shr.size())):
			var p: Vector3 = at.call(shr[k])
			map.add_prop("shrine_%d" % k, "boon_shrine", p)
			map.obstacles.append([map.m2(p), 0.35])
			map.add_ring("shrine_%d" % k, p + Vector3(0, 0, 1.15), _card_shrine.bind(String(offer[k])), Color(0.7, 1.0, 0.55))


## The rolling logs (and any other trap the map lists), each in its own frame along the path.
func _setup_traps() -> void:
	for t in data().get("traps", []):
		var s: float = map.s_of(t["at"].get("s", 0.0)) if t["at"] is Dictionary and t["at"].has("s") else map.progress(map.pt(t["at"])).x
		var sm: Array = map.sample(s)
		var dir: Vector2 = sm[1]
		var spec: Dictionary = (t as Dictionary).duplicate()
		spec["at"] = map.wpt(t["at"])
		spec["yaw"] = atan2(-dir.x, -dir.y)
		var tr := TrapScript.new()
		add_child(tr)
		tr.setup(main, spec, level(), strength())
		tr.active = false
		traps.append(tr)


## The end: the boss asleep in its arena (spawned when the cat comes near), or the treasure; after the boss, its chest,
## the root lift and (on the first clear) the Moss Warden's seal.
func _setup_end() -> void:
	var e: Dictionary = data().get("end", {})
	if e.is_empty():
		return
	if end_type() == "treasure":
		var at: Vector3 = map.wpt(e["chest"])
		var done: bool = (run["chests"] as Array).has("end")
		var node: Node3D = map.add_prop("end_chest", "burrow_chest_boss", at)
		map.obstacles.append([map.m2(at), 0.6])
		chests["end"] = {"def": e, "node": node, "at": at, "state": "done" if done else "shut", "end": true}
		_lift_ring(e)
		map.parts["end_lift_ring"].visible = done
		if done:
			_lid_open(node, true)
		return
	if _boss_down:
		_after_boss(true)


func _lift_ring(e: Dictionary) -> void:
	if map.parts.has("end_lift"):
		return
	var at: Vector3 = map.wpt(e["lift"])
	var lift: Node3D = map.add_prop("end_lift", "root_lift", at)
	lift.rotation.y = 0.0
	map.add_ring("end_lift", at + Vector3(0, 0, 0.95), _card_lift.bind("end"))


## After the boss: the roots stay open, its chest (until opened), the lift (after the seal, if the Warden waits).
func _after_boss(quick: bool) -> void:
	var e: Dictionary = data().get("end", {})
	map.seal_arena(false, quick)
	if not (run["chests"] as Array).has("end"):
		var at: Vector3 = map.wpt(e["chest"])
		var node: Node3D = map.add_prop("end_chest", "burrow_chest_boss", at)
		map.obstacles.append([map.m2(at), 0.6])
		chests["end"] = {"def": e, "node": node, "at": at, "state": "shut", "end": true}
		if not quick:
			node.scale = Vector3.ONE * 0.05
			node.create_tween().tween_property(node, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_BACK)
	_lift_ring(e)
	if _warden_waits():
		_seal_due = true
		_make_seal()
	map.parts["end_lift_ring"].visible = not _seal_due


# ---------------------------------------------------------------- seeded choices
## A seeded random number for `what` in this run (a resumed run makes the same packs).
func _rng(what: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash([int(run.get("seed", 1)), what, level()])
	return r


## A kind from the level's pool (weighted); kinds the game does not have yet are skipped.
func _pool_kind(r: RandomNumberGenerator, pool: Array) -> String:
	var ok: Array = pool.filter(func(e): return Data.b["enemies"].has(String(e[0])))
	if ok.is_empty():
		return "thornling"
	var tot := 0.0
	for e in ok:
		tot += float(e[1])
	var x := r.randf() * tot
	for e in ok:
		x -= float(e[1])
		if x <= 0.0:
			return String(e[0])
	return String(ok[0][0])


func _by_level(key: String) -> float:
	var t: Array = cfg().get(key, [0])
	return float(t[clampi(level(), 0, t.size() - 1)])


## Who sleeps in a fight's pack: [kind, world position, opts]. The first run ever at level 1 has the map's fixed packs;
## otherwise base + per_level monsters from the level's pool, maybe a Gloomtouched elite (pack_elite_chance_by_level) and
## from level 2 Root Snappers. A pack with an "elite" spot always has a Gloomtouched elite there.
func pack_plan(f: Dictionary) -> Array:
	var pk: Dictionary = f["def"].get("pack", {})
	if pk.is_empty():
		return []
	var r := _rng("pack:" + String(f["id"]))
	var c: Vector3 = f["c"]
	var spots: Array = pk.get("spots", [[0.0, 0.0]])
	var first: bool = bool(run.get("first_run", false)) and level() == 1
	var cap: int = int(cfg()["max_alive_by_quality"][clampi(Quality.level, 0, 2)])
	var kinds: Array = []
	if first and pk.has("first_run"):
		kinds = (pk["first_run"] as Array).filter(func(k): return Data.b["enemies"].has(String(k)))
	else:
		var n := int(round(float(pk.get("base", 3)) + float(pk.get("per_level", 0.0)) * (level() - 1)))
		n = clampi(n, 1, cap - (1 if pk.has("elite") else 0))
		for k in n:
			kinds.append(_pool_kind(r, tier()["pool"]))
	var out: Array = []
	for k in kinds.size():
		var sp: Array = spots[k % spots.size()]
		var at := c + Vector3(float(sp[0]), 0, float(sp[1]))
		if k >= spots.size():
			at += Vector3(r.randf_range(-0.7, 0.7), 0, r.randf_range(-0.7, 0.7))
		out.append([String(kinds[k]), at, {}])
	var elites: Array = (tier().get("elites", ["thornling"]) as Array).filter(func(k): return Data.b["enemies"].has(String(k)))
	if pk.has("elite"):
		var ek := String(pk.get("first_elite", "")) if first and pk.has("first_elite") else (String(elites[r.randi() % elites.size()]) if not elites.is_empty() else "thornling")
		var ep: Array = pk["elite"]
		out.append([ek, c + Vector3(float(ep[0]), 0, float(ep[1])), {"gloomtouched": true, "elite": true}])
	elif not first and not out.is_empty() and r.randf() < _by_level("pack_elite_chance_by_level") and not elites.is_empty():
		out[0][0] = String(elites[r.randi() % elites.size()])
		out[0][2] = {"gloomtouched": true, "elite": true}
	if not first and level() >= 2 and Data.b["enemies"].has("snapper"):
		var ch := _by_level("snapper_chance_by_depth")
		for sn in pk.get("snappers", []):
			if r.randf() < ch:
				out.append(["snapper", c + Vector3(float(sn[0]), 0, float(sn[1])), {"facing": deg_to_rad(float(sn[2]))}])
	return out


## How many a spawner sends at this level.
func spawner_count(sp: Dictionary) -> int:
	return maxi(1, int(round(float(sp.get("count", 2)) + float(sp.get("per_level", 0.0)) * (level() - 1))))


# ---------------------------------------------------------------- fights
func _spawn_pack(f: Dictionary) -> void:
	f["state"] = "asleep"
	var face_in := bool(f["def"].get("face_in", false))
	for p in pack_plan(f):
		var opts: Dictionary = (p[2] as Dictionary).duplicate()
		opts["asleep"] = true
		opts["fight"] = int(f["i"])
		var e = spawn(String(p[0]), p[1], opts)
		if e == null:
			continue
		if opts.has("facing"):
			e.rotation.y = float(opts["facing"])
		elif face_in:
			var to: Vector3 = (f["c"] as Vector3) - e.global_position
			e.rotation.y = atan2(to.x, to.z)
		else:
			e.rotation.y = deg_to_rad(float(f["def"].get("face", 0.0)))
		(f["foes"] as Array).append(e)


## A fight wakes: all its sleepers at once ("!"), the way home closes.
func _wake_fight(f: Dictionary) -> void:
	if String(f["state"]) == "done" or String(f["state"]) == "awake":
		return
	f["state"] = "awake"
	for e in f["foes"]:
		if is_instance_valid(e) and not e.dead and not e.awake:
			e.wake()
	run["woke"] = true
	_hide_home()
	# a pull: a pack asleep close by hears it and joins in (link_r)
	var lr := float(cfg().get("link_r", 0.0))
	for o in fights:
		if o != f and String(o["state"]) == "asleep" and not (o["foes"] as Array).is_empty() and (o["c"] as Vector3).distance_to(f["c"]) < lr:
			_wake_fight(o)
	_save_run(true)


func _hide_home() -> void:
	var rg = map.parts.get("home_ring") if map != null else null
	if rg != null and is_instance_valid(rg):
		rg.visible = false


## A spawner fires: Grublings burst out of its hole, or moths fly in from the dark.
func _fire_spawner(f: Dictionary, sp: Dictionary) -> void:
	sp["fired"] = true
	var def: Dictionary = sp["def"]
	var kind := String(def.get("kind", "grub"))
	var n := spawner_count(def)
	var fr: Array = sp["from"]
	for k in n:
		var at: Vector3
		var opts := {"fight": int(f["i"])}
		if bool(def.get("emerge", false)):
			var a := TAU * k / n + 0.6
			at = (sp["hole"] as Vector3) + Vector3(cos(a), 0, sin(a)) * 0.55
			opts["emerge"] = true
		elif not fr.is_empty():
			at = fr[k % fr.size()]
		else:
			at = main.player.global_position + Vector3(0, 0, -5.0)
		var e = spawn(kind, at, opts)
		if e != null:
			(f["foes"] as Array).append(e)
	if String(f["state"]) != "awake":
		_wake_fight(f)


func _fight_of(e) -> Dictionary:
	if e != null and is_instance_valid(e) and e.has_meta("fight"):
		var i := int(e.get_meta("fight"))
		if i >= 0 and i < fights.size():
			return fights[i]
	return {}


## Wins: a fight is won when its spawners have all fired and nothing of it is left.
func _check_fights() -> void:
	if not active or leaving:
		return
	for f in fights:
		if String(f["state"]) != "awake":
			continue
		var left := false
		for sp in f["spawners"]:
			if not bool(sp["fired"]):
				left = true
		for e in f["foes"]:
			if is_instance_valid(e) and not e.dead:
				left = true
		if not left:
			_fight_won(f)


func _fight_won(f: Dictionary) -> void:
	f["state"] = "done"
	if not (run["cleared"] as Array).has(f["id"]):
		(run["cleared"] as Array).append(f["id"])
	var at: Vector3 = map.constrain(f["c"], 0.4, false)
	if not f["def"].has("pack"):
		at = map.constrain(main.player.global_position + Vector3(0.6, 0, -0.8), 0.4, false)
	# a dew bud blooms now and then where a fight with a pip was won (dew.bud_chance, seeded: the same every replay)
	if bool(f["pip"]) and _rng("bud:" + String(f["id"])).randf() < float(cfg()["dew"].get("bud_chance", 1.0)):
		var bud: Node3D = map.add_prop("bud_" + String(f["id"]), "dew_bud", at)
		var petals := Props.find_part(bud, "petals")
		if petals != null:
			petals.create_tween().tween_property(petals, "scale", Vector3(1.7, 0.45, 1.7), 0.6).set_trans(Tween.TRANS_BACK)
		Fx.flower_ring(main, at, 0.8)
		_buds.append(bud)
	for p in get_tree().get_nodes_in_group("pickups"):
		if owns(p.global_position) and p.global_position.distance_to(main.player.global_position) < 16.0:
			p.call_home()
	main.hud.toast("%s: won" % String(f["name"]))
	_save_run(true)
	main.hud.refresh()
	_maybe_grub("fight", String(f["id"]))


# ---------------------------------------------------------------- spawning (fight.spawn hands summons here)
## A monster in the Burrow: health x the level's strength (x the fight ramp; a boss x its hp_mult), damage = the kind's
## own plus the level's (never scaled by strength), no structure damage. opts: asleep, gloomtouched, boss, hp_mult,
## summon, elite, emerge, fight. Returns null when the boss's adds are at their cap (callers ignore it).
func spawn(kind: String, at: Vector3, opts := {}) -> Node3D:
	if not active or map == null or not Data.b["enemies"].has(kind):
		return null
	if kind == "raccoon":
		return null                                        # nothing to steal here
	var live := foes()
	var cap: int = int(cfg()["max_alive_by_quality"][clampi(Quality.level, 0, 2)])
	if bool(opts.get("summon", false)):
		var n := 0
		var up := 0                                        # sleepers further back on the path do not count
		for e in live:
			if e.summoned:
				n += 1
			if e.awake:
				up += 1
		if n >= int(cfg()["boss_minions_max"]) or up >= cap + 2:
			return null
	var info: Dictionary = Data.enemy(kind)
	var e := Node3D.new()
	e.set_script(EnemyScript)
	e.main = main
	e.position = map.constrain(at, float(info.get("radius", 0.4)), true, bool(info.get("flyer", false)))
	main.add_child(e)
	var st := strength()
	if bool(opts.get("boss", false)):
		st *= float(opts.get("hp_mult", 1.0))
	elif opts.has("fight"):
		st *= 1.0 + float(cfg()["fight_ramp"]) * int(opts["fight"])
	e.setup(kind, AREA_PATCH, st)
	e.damage = int(info["damage"]) + damage_add()
	e.gate_damage = 0
	e.summoned = bool(opts.get("summon", false))
	if bool(opts.get("gloomtouched", false)):
		e.make_gloomtouched(bool(opts.get("boss", false)))
	if bool(opts.get("elite", false)):
		e.set_meta("elite", true)
	if opts.has("fight"):
		e.set_meta("fight", int(opts["fight"]))
	if bool(opts.get("asleep", false)):
		e.sleep()
	if bool(opts.get("emerge", false)) and e.has_method("start_emerge"):
		e.start_emerge(e.position)
	if bool(opts.get("boss", false)):
		e.set_meta("boss_of_room", true)
	return e


## enemy.gd: a monster woke (the cat came near, or it was hurt): its whole fight wakes; the boss wakes with its bar.
func wake_pack(e) -> void:
	if not active:
		return
	if e == _boss or (e != null and e.has_meta("boss_of_room")):
		_boss_wakes()
		return
	var f := _fight_of(e)
	if not f.is_empty():
		_wake_fight(f)


## A monster in the Burrow fell (enemy.gd _die): leaves (never from a boss), a chance of amber and of a dew drop.
func on_enemy_died(e) -> void:
	var at: Vector3 = e.global_position
	var info: Dictionary = e.info
	if e == _boss or e.has_meta("boss_of_room"):
		_boss_beaten(e)
		return
	## Enemy drops get the bonus here. The boss chest pays through its own loot table.
	var kill_leaf_bonus := float(Data.b["kill_leaf_bonus"])
	if String(e.id) == "amber_grub":
		var ag: Dictionary = cfg()["amber_grub"]
		var leaves := roundi(float(ag["leaves"]) * leaf_mult())
		main.drop_leaves(at, roundi(leaves * kill_leaf_bonus))
		main.drop_item(at, "amber", int(ag["amber"]))
		main.hud.toast("Caught it! The Amber Grub bursts into treasure")
		_grub = null
		for p in get_tree().get_nodes_in_group("pickups"):
			if owns(p.global_position):
				get_tree().create_timer(0.6).timeout.connect(p.call_home)
		return
	# G4: the Saddlebags (a Saddlery attachment now, working everywhere) add to a kill's leaves; loot_mult is the old
	# Burrows-only bags' (none since G4) and any boon's
	var lv := Data.saddlebag_leaves(int(round(float(info.get("leaves", 0)) * leaf_mult() * float(Data.run_mods.get("loot_mult", 1.0)))))
	if lv > 0:
		main.drop_leaves(at, roundi(lv * kill_leaf_bonus))
	var dr: Dictionary = cfg()["drops"]
	var ch: Array = dr["kill_amber_chance"]
	if randf() < float(ch[clampi(level(), 0, ch.size() - 1)]) * float(Data.run_mods.get("loot_mult", 1.0)):
		main.drop_item(at, "amber", 1)
	if e.has_meta("elite"):
		for k in Data.MATS:
			_roll_drop(at, k, Data.depth_drop(dr["elite"], k, level()))
	var dew: Dictionary = cfg()["dew"]
	var dc := float(dew["elite_chance"] if e.has_meta("elite") else dew["chance"]) * float(Data.run_mods.get("dew_mult", 1.0))
	if randf() < dc:
		main.drop_item(at, "dew", int(dew["heal"]))
	if e.has_meta("guard"):
		call_deferred("_check_guard", String(e.get_meta("guard")))
	call_deferred("_check_fights")


## The broken seal's guard and its friends are down: the chest opens with twice the loot.
func _check_guard(id: String) -> void:
	var ch: Dictionary = chests.get(id, {})
	if ch.is_empty() or String(ch["state"]) != "guarded":
		return
	for e in _nook_guard:
		if is_instance_valid(e) and not e.dead:
			return
	ch["state"] = "done"
	_open_chest(ch["node"], "chest", true)
	_chest_done(id)


## v of a material at `at`: floor(v), and one more with chance frac(v).
func _roll_drop(at: Vector3, kind: String, v: float) -> int:
	var n := int(floor(v))
	if randf() < v - floor(v):
		n += 1
	if n > 0:
		if kind in Data.MATS:
			main.drop_item(at, kind, n)
		elif kind == "leaves":
			main.drop_leaves(at, n)
		elif kind == "timber":
			Save.timber += n
			Fx.text(main, at + Vector3(0, 1.0, 0), "+%d timber" % n, Color(0.95, 0.8, 0.55))
	return n


# ---------------------------------------------------------------- the boss
func _spawn_boss() -> void:
	var e: Dictionary = data().get("end", {})
	var g := level() >= int(e.get("gloomtouched_from", 99))
	_boss = spawn(String(e.get("kind", "bear")), map.wpt(e["at"]), {"boss": true, "asleep": true, "hp_mult": float(e.get("hp_mult", 1.0)), "gloomtouched": g})
	if _boss != null:
		_boss.rotation.y = 0.0
		_boss.mods = (e.get("mods", {}) as Dictionary).duplicate()      # this map's boss: its slams, roars and enrage


## enemy.gd: the boss is enraged (low health): a banner.
func boss_enraged(e) -> void:
	if not active or e != _boss:
		return
	main.hud.banner("%s is enraged!" % (e.title if e.title != "" else String(e.info["name"])), Color(1.0, 0.45, 0.3), "Its slams send a second ring")


## The cat steps into the arena: the roots close behind it and the boss wakes.
func _enter_arena() -> void:
	map.seal_arena(true)
	main.shake(0.2)
	if _boss != null and is_instance_valid(_boss) and not _boss.awake:
		_boss.wake()
	else:
		_boss_wakes()


func _boss_wakes() -> void:
	if _boss == null or not is_instance_valid(_boss) or _boss.dead:
		return
	if main.hud.boss == _boss:
		return
	main.hud.boss = _boss
	run["woke"] = true
	_hide_home()
	main.hud.banner("%s wakes!" % (_boss.title if _boss.title != "" else String(_boss.info["name"])), Color(1.0, 0.55, 0.45), "The roots close behind you")
	if not Save.flag("told_pillar"):
		Save.set_flag("told_pillar")
		main.hud.tip_after("Lure its charge into a standing stone: it gets dazed and takes extra damage.", null)
	_save_run(true)


## The boss fell: its helpers vanish into petals, the roots open, its chest waits, the lift rises (after the seal, if
## the Moss Warden waits behind it). The first clear of a level raises the record and pays heartwood and a key.
func _boss_beaten(e) -> void:
	_boss = null
	_boss_down = true
	run["boss_down"] = true
	main.hud.boss = null
	for f in foes():
		if f != e and (f.summoned or map.in_arena(f.global_position, -1.0)):
			f.dead = true
			f.remove_from_group("foes")
			f.remove_from_group("enemies")
			Fx.petals(main, f.global_position + Vector3(0, 0.4, 0))
			f.queue_free()
	var first := _record_clear()
	main.hud.banner("%s falls!" % (e.title if e.title != "" else String(e.info["name"])), Color(1.0, 0.85, 0.4),
		("Level %d beaten for the first time!" % level()) if first else "Its chest waits for you")
	Sfx.play("win", -4.0)
	_after_boss(false)
	_save_run(true)
	main.hud.refresh()


## A level's end reached (the boss down, or the treasure opened): the record, and on a first clear heartwood and a key.
## Returns whether it was the first clear of this level.
func _record_clear() -> bool:
	var st := Save.burrow_stats(bid())
	var first := level() > int(st["depth"])
	st["best"] = maxi(int(st["best"]), level())
	if first:
		st["depth"] = level()
		var hw := Data.depth_drop(cfg()["drops"]["first_clear"], "heartwood", level())
		if hw > 0.0:
			var sat: Dictionary = run["satchel"]
			sat["heartwood"] = int(sat.get("heartwood", 0)) + int(round(hw))
		b.grant_key("first_clear", int(cfg()["keys"]["first_clear"]))
	return first


# ---------------------------------------------------------------- the Moss Warden, sealed behind the first boss
## The Warden lies in a cage of violet Gloom crystals at the arena's north edge. The player taps the seal and the cat
## stays close for seal_s seconds to break it; then it is free (stations.free_guardian) and waits at its stone in the camp.
func _make_seal() -> void:
	var e: Dictionary = data().get("end", {})
	var c: Vector3 = map.wpt(e.get("seal", e["at"]))
	var seal := Node3D.new()
	seal.position = c
	map.add_child(seal)
	map.parts["seal"] = seal
	var look := Save.guardian_look
	var path := "res://assets/companions/%s/%s.glb" % [look, look]
	if ResourceLoader.exists(path):
		var w := (load(path) as PackedScene).instantiate() as Node3D
		Props.apply_vc(w)
		w.scale = Vector3.ONE * 0.9
		seal.add_child(w)
		Props.set_param(w, "gloom", 0.75)
		var ap := _find_anim(w)
		if ap != null and ap.has_animation("Crumble"):
			ap.play("Crumble")
			ap.seek(ap.get_animation("Crumble").length * 0.6, true)
			ap.pause()
	var r := RandomNumberGenerator.new()
	r.seed = 77
	for k in 7:
		var cr := Props.instance("gloom_crystal")
		var a := TAU * k / 7.0
		cr.position = Vector3(cos(a), 0, sin(a)) * 0.95
		cr.rotation = Vector3(r.randf_range(-0.35, 0.35), r.randf() * TAU, r.randf_range(-0.35, 0.35))
		cr.scale = Vector3.ONE * r.randf_range(1.0, 1.6)
		seal.add_child(cr)
	map.add_ring("seal", c + Vector3(0, 0, 1.15), _card_seal, Color(0.78, 0.55, 1.0), 0.8)
	main.hud.tip_after("Something stirs in the Gloom crystals behind the boss. Tap the seal to break it!", map.parts["seal_ring"])


func _find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_anim(c)
		if r != null:
			return r
	return null


## The Moss Warden is still sealed in this Burrow: its level was beaten and it is not free yet.
func _warden_waits() -> bool:
	var sg: Dictionary = Data.burrow_def(bid()).get("sealed_guardian", {})
	return end_type() == "boss" and not sg.is_empty() and int(sg.get("depth", 1)) == level() and not Data.guardian_awake() \
		and int(Save.burrow_stats(bid())["depth"]) >= level()


func _card_seal() -> Dictionary:
	return {"title": "A Gloom seal", "sub": "A guardian of mossy stone sleeps inside", "anchor": main.player.global_position + Vector3(0, 2.0, 0), "rows": [
		{"text": "Breaking the seal...", "note": "Stay close a moment", "cost": {}, "label": "", "enabled": false, "action": Callable()}]}


func _free_warden() -> void:
	if not _seal_due:
		return
	_seal_due = false
	var seal = map.parts.get("seal") if map != null else null
	if seal != null and is_instance_valid(seal):
		Fx.shockwave(main, seal.global_position, 2.2, Color(0.78, 0.55, 1.0))
		for k in 3:
			Fx.kill(main, seal.global_position + Vector3(0, 0.8, 0), Color(0.78, 0.55, 1.0))
		Fx.flower_ring(main, seal.global_position, 1.6)
		seal.queue_free()
		main.shake(0.3)
	if map != null:
		var rg = map.parts.get("seal_ring")
		if rg != null and is_instance_valid(rg):
			rg.visible = false
		if map.parts.has("end_lift_ring"):
			map.parts["end_lift_ring"].visible = true
	main.stations.free_guardian()                          # it follows the cat home and waits at its stone
	_save_run(true)


# ---------------------------------------------------------------- cards
func _boon_offer() -> Array:
	var ids: Array = (cfg()["boons"] as Dictionary).keys()
	var have: Array = run.get("boons", [])
	var free: Array = ids.filter(func(i): return not have.has(i))
	if free.size() < 2:
		free = ids.duplicate()
	var r := _rng("boons")
	var out: Array = []
	while out.size() < 2 and not free.is_empty():
		var k := r.randi() % free.size()
		out.append(free[k])
		free.remove_at(k)
	return out


func _card_shrine(id: String) -> Dictionary:
	var e: Dictionary = cfg()["boons"][id]
	return {"title": String(e["name"]), "sub": String(e["note"]), "anchor": main.player.global_position + Vector3(0, 2.0, 0), "rows": [
		{"text": "Take this boon", "note": "Until you leave · only one", "cost": {}, "label": "Take",
			"enabled": not leaving and not bool(run.get("boon_taken", false)), "action": take_boon.bind(id)}]}


func _card_lift(where: String) -> Dictionary:
	var bring := Data.mats_text(_banked_preview(1.0))
	var sub := "Back up to the camp with the whole satchel" + (" (no boss loot)" if where == "moonwell" and end_type() == "boss" and not _boss_down else "")
	return {"title": "Root lift", "sub": sub, "anchor": main.player.global_position + Vector3(0, 2.0, 0), "rows": [
		{"text": "Climb out", "note": "Bring home: %s" % bring, "cost": {}, "label": "Climb", "enabled": not leaving and not _seal_due, "action": climb_out}]}


## The way home at the way in, before anything woke: as if the run never happened (the key comes back).
func _back_up() -> void:
	if leaving or bool(run.get("woke", false)):
		return
	if bool(run.get("key", false)):
		Save.burrow_keys = mini(Save.burrow_keys + 1, int(cfg()["keys"]["cap"]))
		main.hud.toast("The key slips back into your pocket")
	var st := Save.burrow_stats(bid())
	st["runs"] = maxi(0, int(st["runs"]) - 1)
	await _leave("back")


# ---------------------------------------------------------------- leaving
func climb_out() -> void:
	if leaving or not active or _seal_due:
		return
	await _leave("out")


## The cat is knocked out: Sprig drags it back up the hollow. Half the satchel is kept.
func cat_down() -> void:
	if leaving or not active:
		return
	leaving = true
	main.hud.banner("Knocked out!", Color(1.0, 0.6, 0.5), "%s drags you back up the hollow" % Data.pet_name())
	await get_tree().create_timer(1.2).timeout
	await _leave("down")


## "Leave it" on the Hollow card (a saved run, from the camp): ends it like a knock-out, half the satchel banked.
func abandon_run() -> void:
	if active or leaving or Save.burrow_run.is_empty():
		return
	run = Save.burrow_run.duplicate(true)
	var got := _bank(float(cfg()["knockout_keep"]))
	var st := Save.burrow_stats(bid())
	st["falls"] = int(st["falls"]) + 1
	var free_it := bool(run.get("boss_down", false)) and _warden_waits()
	run = {}
	Save.burrow_run = {}
	Save.save_game()
	if free_it:
		main.stations.free_guardian()                      # the boss was beaten: the Warden was found all the same
	main.hud.banner("The run is over", Color(1.0, 0.85, 0.5), "Brought home: %s" % Data.mats_text(got))
	b.refresh()
	main.hud.refresh_card()


func _leave(result: String) -> void:
	leaving = true
	main.hud.hide_card()
	main.frozen = true
	main.player.frozen = true
	await main.hud.fade(1.0, float(cfg()["fade_s"]))
	_sweep()
	if _seal_due:
		_free_warden()                                     # the boss fell: the Warden is free whatever happens next
	var share := 1.0
	if result == "down":
		share = float(cfg()["knockout_keep"])
	var got := _bank(share)
	var st := Save.burrow_stats(bid())
	if result == "down":
		st["falls"] = int(st["falls"]) + 1
	elif result == "out" and bool(run.get("boss_down", false)):
		st["won"] = int(st["won"]) + 1
	_clear_foes()
	for tr in traps:
		if is_instance_valid(tr):
			tr.queue_free()
	traps.clear()
	_buds.clear()
	if map != null and is_instance_valid(map):
		map.reset()
		map.visible = false
	active = false
	main.area = null
	Data.run_mods = {}
	_env_off()
	main.hud.boss = null
	if String(run.get("meal", "")) != "" and main.cooking != null:
		main.cooking.finish(true)                          # the dish that went down is used up
	run = {}
	Save.burrow_run = {}
	Save.save_game()
	var p = main.player
	var ret := _return_spot()
	if result == "down":
		p.revive(ret)
	else:
		p.global_position = ret
		p.hp = clampi(p.hp, 1, Data.cat_max_hp())
	p.facing = PI
	if main.mount != null:
		main.mount.home = main.stall_spot()
		main.mount.come_to(ret + Vector3(1.2, 0, 0.4) if not p.riding else ret)
	if main.pet != null:
		main.pet.global_position = ret + Vector3(0.5, 1.1, 0.3)
	main.snap_camera()
	b.refresh()
	await main.hud.fade(0.0, float(cfg()["fade_s"]))
	main.frozen = false
	main.player.frozen = false
	leaving = false
	var bits := Data.mats_text(got)
	if result == "back":
		main.hud.toast("Back at camp")
	else:
		main.hud.banner("Back at camp", Color(1.0, 0.9, 0.55), ("Brought home: %s" % bits) if not got.is_empty() else "Nothing in the satchel this time")
	main.on_area_left(result)


func _return_spot() -> Vector3:
	var r: Array = Data.burrow_def(bid())["entrance"]["return"]
	return Vector3(float(r[0]), 0, float(r[2]))


func _sweep() -> void:
	for p in get_tree().get_nodes_in_group("pickups"):
		if owns(p.global_position):
			p.sweep()


func _clear_foes() -> void:
	for e in get_tree().get_nodes_in_group("foes"):
		if e.patch == AREA_PATCH:
			e.dead = true
			e.remove_from_group("foes")
			e.remove_from_group("enemies")
			e.queue_free()
	_boss = null
	_grub = null


# ---------------------------------------------------------------- the satchel
## Banks the satchel x share (rounded down per material; a whole share never brings less than the satchel itself).
func _bank(share: float) -> Dictionary:
	var got := _banked_preview(share)
	for k in got:
		Save.add_mat(String(k), int(got[k]))
	return got


func _banked_preview(share: float) -> Dictionary:
	var sat: Dictionary = run.get("satchel", {})
	var got := {}
	for k in sat:
		var n := int(sat[k])
		var m := int(floor(n * share + 0.0001))
		if share >= 1.0:
			m = maxi(m, n)
		if m > 0:
			got[k] = m
	return got


func satchel() -> Dictionary:
	return run.get("satchel", {})


## A material picked up goes into the satchel (pickup.gd calls this through main.burrows).
func collect_mat(kind: String, n: int, at: Vector3) -> void:
	if run.is_empty():
		Save.add_mat(kind, n)
		return
	var sat: Dictionary = run["satchel"]
	sat[kind] = int(sat.get(kind, 0)) + n
	Fx.sparkle(main, at)
	Fx.text(main, at + Vector3(0, 0.6, 0), "+%d %s" % [n, Data.mat_name(kind)], Color.html(String(cfg()["materials"][kind]["color"])).lightened(0.3))
	Sfx.play("pickup", -8.0, 0.05)
	main.hud.refresh()
	if not Save.flag("told_satchel"):
		Save.set_flag("told_satchel")
		main.hud.tip_after("Materials go in your satchel. Take a root lift home to keep them all; knocked out, you keep half.", null)


# ---------------------------------------------------------------- boons (for one run) and attachments
func _mods() -> Dictionary:
	var m := {}
	var bo: Dictionary = cfg()["boons"]
	var list: Array = []
	for id in run.get("boons", []):
		list.append(bo.get(String(id), {}))
	for a in Data.attachments_on():
		list.append(a.get("mods", {}))
	for e in list:
		for k in e:
			if k in ["name", "note"]:
				continue
			if k in ["pet_rate", "dew_mult", "loot_mult"]:
				m[k] = float(m.get(k, 1.0)) * float(e[k])
			else:
				m[k] = float(m.get(k, 0.0)) + float(e[k])
	return m


func take_boon(id: String) -> void:
	if not active or leaving or bool(run.get("boon_taken", false)):
		return
	(run["boons"] as Array).append(id)
	run["boon_taken"] = true
	var e: Dictionary = cfg()["boons"][id]
	Data.run_mods = _mods()
	if e.has("hp"):
		main.player.hp = mini(main.player.hp + int(e["hp"]), Data.cat_max_hp())
	Fx.flower_ring(main, main.player.global_position, 1.2)
	Fx.sparkle(main, main.player.global_position + Vector3(0, 1.0, 0))
	main.hud.banner(String(e["name"]), Color(0.75, 1.0, 0.6), String(e["note"]) + " · until you leave")
	for k in ["shrine_0", "shrine_1"]:
		var s = map.parts.get(k)
		if s != null and is_instance_valid(s):
			(s as Node3D).create_tween().tween_property(s, "scale", Vector3.ONE * 0.05, 0.5)
		var rg = map.parts.get(k + "_ring")
		if rg != null:
			rg.visible = false
	_save_run(false)
	main.hud.refresh_card()


# ---------------------------------------------------------------- saving (nothing moves while the game is closed)
func _save_run(quiet: bool) -> void:
	if run.is_empty():
		return
	run["hp"] = main.player.hp
	Save.burrow_run = run
	Save.save_game(quiet)


## The app pauses, loses focus or closes: the cat's health goes into the saved run (main._notification).
func persist() -> void:
	if active and not run.is_empty():
		_save_run(true)


## The cat was hurt: the unhurt chest's stretch remembers it, and the run is saved (at most every 1.5 s; always at
## 2 health or less, so closing the app cannot dodge a knock-out).
func on_cat_hurt() -> void:
	if _zone_in:
		_zone_hurt = true
	if _save_cd <= 0.0 or main.player.hp <= int(cfg()["save_hurt_low_hp"]):
		_save_cd = float(cfg()["save_hurt_every_s"])
		_save_run(true)


## At start: a saved run of another format (Phase E's rooms) or map version is closed kindly: the whole satchel is
## banked and the key is given back.
func check_saved_run() -> void:
	var r: Dictionary = Save.burrow_run
	if r.is_empty():
		# a safety net: the first boss was beaten but the Warden was never freed (an old or odd save)
		var sg: Dictionary = Data.burrow_list()[0].get("sealed_guardian", {})
		if not sg.is_empty() and not Data.guardian_awake() and Data.burrows_open() \
				and Data.burrow_depth(String(Data.burrow_list()[0]["id"])) >= int(sg.get("depth", 1)):
			main.stations.free_guardian()
		return
	var known := false
	for bd in Data.burrow_list():
		if String(bd["id"]) == String(r.get("burrow", "")):
			known = true
	var mid := String(r.get("map", ""))
	var ok := known and int(r.get("v", 0)) == RUN_V and mid != "" and not Data.dungeon(mid).is_empty() \
		and int(r.get("map_v", -1)) == int(Data.dungeon(mid).get("version", 1))
	if ok and int(r.get("hp", 1)) <= 0:
		run = r.duplicate(true)                            # closed during a knock-out: it counts as one
		_bank(float(cfg()["knockout_keep"]))
		Save.burrow_stats(bid())["falls"] = int(Save.burrow_stats(bid())["falls"]) + 1
		run = {}
		Save.burrow_run = {}
		Save.save_game()
		return
	if ok:
		return
	run = r.duplicate(true)
	if typeof(run.get("satchel", null)) != TYPE_DICTIONARY:
		run["satchel"] = {}
	if not known:
		run["burrow"] = String(Data.burrow_list()[0]["id"])
	_bank(1.0)
	if bool(r.get("key", false)):
		Save.burrow_keys = mini(Save.burrow_keys + 1, int(cfg()["keys"]["cap"]))
	run = {}
	Save.burrow_run = {}
	Save.save_game()
	main.hud.toast("An update closed your run: everything was brought home")


## The Hollow card while a run is saved: go back in, or leave it.
func run_card_rows(_id: String, why: String) -> Array:
	var r: Dictionary = Save.burrow_run
	var rows: Array = []
	var where := String(r.get("checkpoint", "wayin"))
	for c in Data.dungeon(String(r.get("map", ""))).get("checkpoints", []):
		if String(c["id"]) == where:
			where = String(c.get("name", where))
	if why != "":
		rows.append({"text": why, "note": "", "cost": {}, "label": "", "enabled": false, "action": Callable()})
	else:
		rows.append({"text": "Go back in", "note": "Level %d · at %s · %d health · satchel: %s" % [int(r.get("level", 1)), ("the" + where.substr(3)) if where.begins_with("The ") else where,
			int(r.get("hp", 1)), Data.mats_text(r.get("satchel", {}))], "cost": {}, "label": "Go back in", "enabled": true, "pulse": true, "action": resume_run})
	rows.append({"text": "Leave it", "note": "Bring home half the satchel", "cost": {}, "label": "Leave", "enabled": not active, "action": abandon_run})
	rows.append({"text": "Your materials", "note": Data.mats_text(Save.mats), "cost": {}, "label": "", "enabled": false, "action": Callable()})
	return rows


# ---------------------------------------------------------------- the area contract (main, world, fight, enemies ask)
## A run is on and p is in the Burrow (the camp keeps its own rules: Thistle walking home, the trader, the Warden).
func owns(p: Vector3) -> bool:
	return active and p.x > float(cfg()["own_x"])


func constrain(p: Vector3, radius: float, is_enemy: bool, flyer := false) -> Vector3:
	if map == null or not is_instance_valid(map):
		return p
	return map.constrain(p, radius, is_enemy, flyer)


func outside(p: Vector3, radius := 0.3) -> bool:
	return map == null or not is_instance_valid(map) or map.outside(p, radius)


## A monster's way to the cat round the bends (enemy.gd _walk).
func steer(from: Vector3, goal: Vector3) -> Vector3:
	if map == null or not is_instance_valid(map):
		return goal
	return map.steer(from, goal)


## The camera: a little further out than the camp on the path, the focus leading along the path's direction; further
## out in the arena, leaning toward the boss so its telegraphs stay on screen. While a card is docked the focus is the
## camp's (the HUD's card lift works from it).
func cam_focus(cat: Vector3) -> Vector3:
	var base := Vector3(cat.x, 0.0, cat.z + main.CAM_LEAD)
	if map == null or not is_instance_valid(map) or main.hud.card_open():
		_lead = Vector2.ZERO
		return base
	var cc: Dictionary = cfg()["cam"]
	var want := Vector2.ZERO
	var q: Vector2 = map.m2(cat)
	if map.in_arena(cat, -1.0):
		var tgt: Vector2 = map.arena_c
		if _boss != null and is_instance_valid(_boss) and _boss.awake and not _boss.dead:
			tgt = map.m2(_boss.global_position)
		want = ((tgt - q) * float(cc["arena_bias"])).limit_length(float(cc["arena_bias_max"]))
	else:
		var s: float = map.progress(q).x
		var dv: Vector2 = (map.sample(s - 2.0)[1] as Vector2) + (map.sample(s + 1.0)[1] as Vector2) + (map.sample(s + 4.0)[1] as Vector2)
		want = dv.normalized() * float(cc["lead"]) if dv.length() > 0.01 else Vector2.ZERO
	var dt := minf(get_process_delta_time(), 0.1)
	_lead = _lead.lerp(want, 1.0 - exp(-2.5 * dt))
	return base + Vector3(_lead.x, 0.0, _lead.y)


func cam_dist() -> float:
	var cc: Dictionary = cfg()["cam"]
	if map != null and is_instance_valid(map) and map.in_arena(main.player.global_position, -2.0) and not main.hud.card_open():
		return float(cc["arena"])
	return float(cc["path"])


func hide_at(p: Vector3):
	return map.hide_at(p) if map != null and is_instance_valid(map) else null


func flee_point(p: Vector3) -> Vector3:
	return map.flee_point(p) if map != null and is_instance_valid(map) else p


## The monsters of the run (the "foes" group members in the Burrow).
func foes() -> Array:
	var out: Array = []
	for e in get_tree().get_nodes_in_group("foes"):
		if not e.dead and owns(e.global_position):
			out.append(e)
	return out


func strength() -> float:
	return Data.depth_strength(level())


func damage_add() -> int:
	return Data.depth_damage_add(level())


func leaf_mult() -> float:
	return Data.depth_leaf_mult(level())


## "The Gloomwood · Level 1".
func status_text() -> String:
	if not active or run.is_empty():
		return ""
	return "%s · Level %d" % [map_name(), level()]


## The pips at the top right: [state, is_end] per fight and one for the end (state 2 = won, 1 = on now, 0 = ahead).
func fight_pips() -> Array:
	var out: Array = []
	for f in fights:
		if not bool(f["pip"]):
			continue
		var st := String(f["state"])
		out.append([2 if st == "done" else (1 if st == "awake" else 0), false])
	var e := 0
	if _boss_down or (run.get("chests", []) as Array).has("end") and end_type() == "treasure":
		e = 2
	elif map != null and map.sealed:
		e = 1
	out.append([e, true])
	return out


# ---------------------------------------------------------------- every frame
func _physics_process(delta: float) -> void:
	if not active or leaving or main.frozen or map == null or not is_instance_valid(map):
		return
	var d := minf(delta, 0.1)
	_save_cd = maxf(0.0, _save_cd - d)
	if _halo != null and is_instance_valid(_halo):
		var pet_on: bool = main.pet != null and main.pet.visible
		var at: Vector3 = main.pet.global_position if pet_on else main.player.global_position + Vector3(0.3, 1.3, 0)
		(_halo.get_node("disc") as Node3D).global_position = at + Vector3(0, 0.05, 0)
		(_halo.get_node("pool") as Node3D).global_position = Vector3(at.x, 0.03, at.z)
		var lamp = _halo.get_node_or_null("lamp")
		if lamp != null:
			(lamp as Node3D).global_position = at + Vector3(0, 0.4, 0)
	_slow_t -= d
	if _slow_t <= 0.0:
		_slow_t = 0.25
		_tick_slow()
	_tick(d)


## Four times a second: packs spawn as the cat comes near (asleep), the nearest lanterns get the lights, traps run
## only near the cat, checkpoints.
func _tick_slow() -> void:
	var cat: Vector3 = main.player.global_position
	var sr := float(cfg()["spawn_r"])
	for f in fights:
		if String(f["state"]) == "far" and cat.distance_to(f["c"]) < sr:
			_spawn_pack(f)
	if end_type() == "boss" and not _boss_down and _boss == null and map.arena_r > 0.0 and cat.distance_to(map.w2(map.arena_c)) < sr:
		_spawn_boss()
	var near := float(data().get("traps_near", 16.0))
	for tr in traps:
		if is_instance_valid(tr):
			tr.active = cat.distance_to(tr.origin) < near
	_place_lights()
	# checkpoints: only forward along the path
	var cur := _checkpoint(String(run.get("checkpoint", "wayin")))
	for c in checkpoints:
		if float(c["s"]) <= float(cur.get("s", -1.0)):
			continue
		if Vector2(cat.x - c["at"].x, cat.z - c["at"].z).length() < float(c["r"]) and main.player.hp > 0:
			run["checkpoint"] = String(c["id"])
			_save_run(true)
			if String(c["id"]) == "moonwell":
				main.hud.banner("The Moonwell", Color(0.6, 0.95, 1.0), "Drink once, take a boon · a root lift home · saved here")
			else:
				main.hud.toast("%s · your run is saved here" % String(c["name"]))
			break
	if not _moonwell_seen and String(run.get("checkpoint", "")) == "moonwell":
		_moonwell_seen = true
		_maybe_grub("moonwell", "moonwell")


func _tick(d: float) -> void:
	var cat: Vector3 = main.player.global_position
	var hp_ok: bool = main.player.hp > 0
	# packs wake together when the cat comes within their wake radius (unless it is hidden in the ferns)
	for f in fights:
		if String(f["state"]) == "asleep" and f["def"].has("wake_r") and not (f["foes"] as Array).is_empty() and hp_ok and not main.cat_hidden():
			if Vector2(cat.x - f["c"].x, cat.z - f["c"].z).length() < float(f["def"]["wake_r"]):
				_wake_fight(f)
		# spawners fire as the cat crosses their line
		if String(f["state"]) != "done":
			for sp in f["spawners"]:
				if not bool(sp["fired"]) and hp_ok:
					var a: Vector3 = sp["a"]
					var c: Vector3 = sp["b"]
					if Geometry2D.get_closest_point_to_segment(Vector2(cat.x, cat.z), Vector2(a.x, a.z), Vector2(c.x, c.z)).distance_to(Vector2(cat.x, cat.z)) < 0.8:
						_fire_spawner(f, sp)
	# the arena: stepping in closes the roots and wakes the boss
	if end_type() == "boss" and not _boss_down and not map.sealed and _boss != null and is_instance_valid(_boss) and hp_ok \
			and map.in_arena(cat, 1.4):
		_enter_arena()
	# dew buds: walk into one
	for bud in _buds.duplicate():
		if not is_instance_valid(bud):
			_buds.erase(bud)
		elif cat.distance_to(bud.global_position) < 0.8:
			main.drink_dew(int(cfg()["dew"]["bud_heal"]), bud.global_position)
			Fx.flower_ring(main, bud.global_position, 0.7)
			bud.queue_free()
			_buds.erase(bud)
	_tick_chests(cat)
	_tick_spring(d, cat)
	_grub_tick(d)
	# the seal: tap it, and it breaks while the cat stays close (marker.gd engaged)
	if _seal_due:
		var rg = map.parts.get("seal_ring")
		var need := float(Data.burrow_def(bid())["sealed_guardian"].get("seal_s", 3.0))
		if rg != null and rg.engaged(cat) and hp_ok:
			_seal_t += d
			main.hud.status = "Breaking the seal... %d%%" % int(clampf(_seal_t / need, 0.0, 1.0) * 100.0)
			if fmod(_seal_t, 0.3) < d:
				Fx.sparkle(main, rg.global_position + Vector3(0, 0.6, 0))
			if _seal_t >= need:
				main.hud.status = ""
				_free_warden()
		elif _seal_t > 0.0:
			_seal_t = 0.0
			main.hud.status = ""
	_tick_stuck(d)


## The chests that open by walking up: the unhurt chest at the end of its stretch, and the end chest.
func _tick_chests(cat: Vector3) -> void:
	for id in chests:
		var ch: Dictionary = chests[id]
		if String(ch["state"]) != "shut":
			continue
		var def: Dictionary = ch["def"]
		if bool(ch.get("end", false)):
			if (end_type() == "treasure" or _boss_down) and cat.distance_to(ch["at"]) < 1.45:
				ch["state"] = "done"
				_open_chest(ch["node"], "boss", false)
				_chest_done("end")
				if end_type() == "treasure":
					_boss_down = true
					run["boss_down"] = true
					var first := _record_clear()
					main.hud.banner("The treasure!", Color(1.0, 0.85, 0.4), ("Level %d beaten for the first time!" % level()) if first else "Take the root lift home")
					map.parts["end_lift_ring"].visible = true
					_save_run(true)
			continue
		if String(def.get("type", "")) != "unhurt":
			continue
		var zone: Array = ch.get("zone", [0.0, 0.0])
		var pr: Vector2 = map.progress(map.m2(cat))
		if not _zone_in and pr.x >= float(zone[0]) and pr.x <= float(zone[1]) and pr.y < 3.0:
			_zone_in = true
			_zone_hurt = false
			if not Save.flag("told_traps"):
				Save.set_flag("told_traps")
				main.hud.tip_after("Logs roll across the path: a glow on the ground warns where. Cross unhurt and the chest at the end opens.", null)
		if cat.distance_to(ch["at"]) < 1.45:
			ch["state"] = "done"
			if _zone_in and not _zone_hurt:
				_open_chest(ch["node"], "chest", false, float(cfg()["drops"]["unhurt_share"]))
			else:
				main.hud.toast("The chest stays shut: you were hit")
				Fx.puff(main, (ch["at"] as Vector3) + Vector3(0, 0.4, 0), Color(0.6, 0.5, 0.4), 10)
				(ch["node"] as Node3D).create_tween().tween_property(ch["node"], "scale", Vector3.ONE * 0.05, 0.5)
			_chest_done(id)


## The Moonwell's spring: wade in and stand still to drink (spring.heal of the cat's health, once).
func _tick_spring(d: float, cat: Vector3) -> void:
	if bool(run.get("spring_used", false)):
		return
	var sp = map.parts.get("spring")
	if sp == null or not is_instance_valid(sp):
		return
	if Vector2(cat.x - sp.global_position.x, cat.z - sp.global_position.z).length() < 1.0 and main.player.hp > 0:
		_drink_t += d
		var need := float(cfg()["spring"]["drink_s"])
		main.hud.status = "Drinking... %d%%" % int(clampf(_drink_t / need, 0.0, 1.0) * 100.0)
		if _drink_t >= need:
			_drink_t = 0.0
			main.hud.status = ""
			run["spring_used"] = true
			var heal := int(ceil(Data.cat_max_hp() * float(cfg()["spring"].get("heal", 1.0))))
			main.player.hp = mini(main.player.hp + heal, Data.cat_max_hp())
			Fx.flower_ring(main, sp.global_position, 1.2)
			Fx.hearts(main, cat + Vector3(0, 1.2, 0))
			main.hud.toast("The spring heals you!")
			main.hud.refresh_hp()
			_save_run(true)
	elif _drink_t > 0.0:
		_drink_t = 0.0
		main.hud.status = ""


## The safety net: nothing has changed for a long while in a fight (no boss up): the rest crumble into the roots.
func _tick_stuck(d: float) -> void:
	_sum_t += d
	if _sum_t < 0.5:
		return
	_sum_t = 0.0
	var live: Array = foes().filter(func(e): return e.awake and not e.has_meta("boss_of_room") and String(e.id) != "amber_grub")
	if live.is_empty() or (_boss != null and is_instance_valid(_boss) and _boss.awake):
		_stuck_t = 0.0
		_last_sum = -1.0
		return
	var sum := float(main.player.hp)
	for e in live:
		sum += float(e.hp)
	if absf(sum - _last_sum) < 0.01:
		_stuck_t += 0.5
		if _stuck_t >= float(cfg()["stuck_after_s"]):
			_crumble(live)
	else:
		_stuck_t = 0.0
	_last_sum = sum


func _crumble(list: Array) -> void:
	_stuck_t = 0.0
	for e in list:
		e.dead = true
		e.remove_from_group("foes")
		e.remove_from_group("enemies")
		Fx.petals(main, e.global_position + Vector3(0, 0.4, 0))
		e.queue_free()
	main.hud.toast("The last of them crumble into the roots")
	call_deferred("_check_fights")
	for id in chests:
		if String(chests[id]["state"]) == "guarded":
			call_deferred("_check_guard", id)


## A glowing ring on the ground, then (after `warn`) a burst there: damage and a slow for the cat if it is still inside
## (a Glowcap's spore bomb). The dash's protection applies.
func strike(at: Vector3, r: float, warn: float, dmg: int, slow_s: float) -> void:
	strikes += 1
	strike_at = [at, r]                                   # the last one (the tests' careful cat steps out of it)
	warn += float(Data.run_mods.get("trap_warn", 0.0))
	Fx.telegraph_ring(main, at, r, warn, Color(0.5, 0.95, 0.85, 0.38))
	get_tree().create_timer(warn).timeout.connect(_strike_now.bind(at, r, dmg, slow_s))


func _strike_now(at: Vector3, r: float, dmg: int, slow_s: float) -> void:
	if not active or leaving:
		return
	Fx.spores(main, at, r)
	var p = main.player
	if p.hp > 0 and Vector2(p.global_position.x - at.x, p.global_position.z - at.z).length() < r:
		if dmg > 0:
			p.hurt(at, dmg)
		if slow_s > 0.0 and not p.dashing():
			p.slow_t = slow_s


## Now and then an Amber Grub pops out of a hole (after a fight is won, or at the Moonwell): catch it before it digs
## away for leaves and amber.
func _maybe_grub(where: String, what: String) -> void:
	var ag: Dictionary = cfg()["amber_grub"]
	var ch := float(ag["fight_chance"] if where == "fight" else ag["spring_chance"])
	if _rng("grub:" + what).randf() >= ch or not Data.b["enemies"].has("amber_grub") or (_grub != null and is_instance_valid(_grub)):
		return
	var cat: Vector3 = main.player.global_position
	var hole := Vector3.ZERO
	var bd := 1e9
	for h in map.holes:
		var dd := (h as Vector3).distance_to(cat)
		if dd > 3.5 and dd < bd:
			bd = dd
			hole = h
	if bd > 14.0:
		hole = map.constrain(cat + Vector3(2.5, 0, -2.5), 0.3, false)
	_grub = spawn("amber_grub", hole, {})
	if _grub != null:
		_grub_t = float(ag["life_s"])
		Fx.sparkle(main, hole + Vector3(0, 0.5, 0))
		main.hud.toast("Ooh, an Amber Grub!")


func _grub_tick(d: float) -> void:
	if _grub == null:
		return
	if not is_instance_valid(_grub) or _grub.dead:
		_grub = null
		return
	_grub_t -= d
	if _grub_t <= 0.0:
		Fx.dust(main, _grub.global_position, 12, 1.0)
		_grub.dead = true
		_grub.remove_from_group("foes")
		_grub.remove_from_group("enemies")
		_grub.queue_free()
		_grub = null
		main.hud.toast("It got away!")


## A chest's loot: leaves fly to the cat, timber (and Gloom shards) are banked at once, materials go in the satchel.
## kind: "boss" (the end's chest) or "chest" (x share); sealed doubles it.
func _open_chest(chest: Node3D, kind: String, sealed: bool, share := 1.0) -> void:
	_lid_open(chest, false)
	Fx.flower_ring(main, chest.global_position, 1.0)
	Fx.sparkle(main, chest.global_position + Vector3(0, 0.8, 0))
	Sfx.play("win", -8.0)
	_chest_loot(chest.global_position + Vector3(0, 0.6, 0), kind, sealed, share)
	_save_run(true)


func _chest_loot(at: Vector3, kind: String, sealed: bool, share: float) -> void:
	var dr: Dictionary = cfg()["drops"]
	var table: Dictionary = dr["boss"] if kind == "boss" else dr["chest"]
	var mult := share * (float(dr["sealed_mult"]) if sealed else 1.0) * float(Data.run_mods.get("loot_mult", 1.0))
	var plus := int(Data.run_mods.get("chest_plus", 0))
	for k in Data.MATS:
		var v := Data.depth_drop(table, k, level()) * mult
		if v > 0.0 or (plus > 0 and int(round(Data.depth_drop(table, k, level()))) > 0):
			_roll_drop(at, k, v + (plus if v > 0.0 else 0))
	var lv := int(round(Data.depth_drop(table, "leaves", level()) * mult))
	if lv > 0:
		main.drop_leaves(at, lv)
	var tb := int(round(Data.depth_drop(table, "timber", level()) * mult))
	if tb > 0:
		Save.timber += tb
		Fx.text(main, at + Vector3(0, 0.6, 0), "+%d timber" % tb, Color(0.95, 0.8, 0.55))
	if kind == "boss" and Data.b.has("gloom_raids"):
		var sh := int(round(Data.depth_drop(table, "shards", level())))
		if sh > 0:
			Save.shards += sh
			main.drop_shards_fx(sh, at)
	for p in get_tree().get_nodes_in_group("pickups"):
		if owns(p.global_position):
			get_tree().create_timer(0.7).timeout.connect(p.call_home)
	main.hud.refresh()
