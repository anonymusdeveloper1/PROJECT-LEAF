extends Node3D
## One Burrows trap (Phase E, on the dungeon maps since docs/DUNGEON_SPEC.md), set up by burrow_run.gd from a map's
## "traps" list. Each trap has its own frame: `at` on the map, with local x across the path and local -z along it (the
## way the cat walks), so a trap works on any bend. Every trap glows on the ground before it strikes (at least 0.8 s),
## hurts the cat through player.hurt (so the dash's protection and close calls apply) and hurts monsters too
## (foe_damage x the run's strength, once per firing), so luring monsters through it is a tactic.
##   log      rolls across the path from one side to the other (half metres each way), changing direction each time
##   thorns   a 3 x 5 grid of plates; one row fires at a time, sweeping north to south
##   crystal  falls near the cat inside the trap's zone
##   spores   a vent: on and off; slows the cat, no damage
##   tide     a violet wall that creeps up the path behind the cat
## Timers clamp their frame time and stop while the game is frozen, or while `active` is off (the run turns traps off
## while the cat is far from them).

var main
var kind := "log"
var cfg: Dictionary
var depth := 1
var strength := 1.0
var dmg := 1                       # what it does to the cat
var active := true
var events: Array = []             # [event, time] for the tests: "warn", "fire", "cat", "foe"
var origin := Vector3.ZERO         # the frame: local (0, 0) in the world
var yaw := 0.0                     # local -z is the walking direction
var half := 3.0                    # how far across the path it reaches (local x)
var span := 12.0                   # how far along the path its zone runs (thorns, crystals, the tide)
var _t := 0.0
var _hit: Dictionary = {}          # instance ids hit in this firing
var _state := ""
var _dir := 1.0
var _x := 0.0
var _node: Node3D
var _plates: Array = []            # thorns: [row][col] -> plate node
var _row_state: Array = []         # thorns: per row: "", "warn", "up"
var _next := 0.0
var _fall_at := Vector3.ZERO
var _tide_z := 0.0
var _tide_mi: MeshInstance3D
var _tick := 0.0
var _vent: Vector3
var _vent_node: Node3D


## m: main. spec: {"type", "at": world Vector3, "yaw", "half", "span", and per type "every", "phase"}. d: the level.
func setup(m, spec: Dictionary, d: int, st: float) -> void:
	main = m
	kind = String(spec.get("type", "log"))
	cfg = (Data.burrow_cfg()["traps"][kind] as Dictionary).duplicate(true)
	if cfg.has("warn"):
		cfg["warn"] = float(cfg["warn"]) + float(Data.run_mods.get("trap_warn", 0.0))   # the Glowworm Lantern (Phase E)
	depth = d
	strength = st
	dmg = Data.depth_trap_damage(d)
	origin = spec.get("at", Vector3.ZERO)
	yaw = float(spec.get("yaw", 0.0))
	half = float(spec.get("half", cfg.get("half", 3.0)))
	span = float(spec.get("span", 12.0))
	match kind:
		"log":
			_next = float(spec.get("phase", cfg.get("phase", 0.0))) + 0.6
			cfg["every"] = float(spec.get("every", cfg.get("every", 3.0)))
			_x = -half
			_dir = 1.0
			_node = Node3D.new()
			add_child(_node)
			var lg := Props.instance("log_fallen")
			lg.rotation.y = PI / 2.0
			lg.position.y = -0.05
			_node.add_child(lg)
			_node.global_position = w(_x, 0.0)
			_node.rotation.y = yaw
		"thorns":
			var rows: Array = cfg["rows_z"]
			for zi in rows.size():
				var row: Array = []
				for x in cfg["cols_x"]:
					var pl := Props.instance("trap_thorns")
					add_child(pl)
					pl.global_position = w(float(x), float(rows[zi]))
					pl.rotation.y = yaw
					var sp := Props.find_part(pl, "spikes")
					if sp != null:
						sp.position.y = -0.5
					row.append(pl)
				_plates.append(row)
				_row_state.append("")
		"crystal":
			_next = 1.2
		"spores":
			_vent = origin
			_next = float(spec.get("phase", 0.4))
			_state = "off"
			_vent_node = Props.instance("spore_vent")
			add_child(_vent_node)
			_vent_node.global_position = _vent
		"tide":
			_tide_z = 0.0
			_tide_mi = MeshInstance3D.new()
			var pm := PlaneMesh.new()
			pm.size = Vector2(half * 2.0, 1.0)
			_tide_mi.mesh = pm
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color = Color(0.55, 0.25, 0.85, 0.45)
			_tide_mi.material_override = mat
			_tide_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_tide_mi.visible = false
			add_child(_tide_mi)


## Local (x across, z along: negative is ahead) to the world.
func w(x: float, z: float) -> Vector3:
	return origin + Basis(Vector3.UP, yaw) * Vector3(x, 0.0, z)


## The world to local (x, z).
func local(p: Vector3) -> Vector2:
	var v: Vector3 = Basis(Vector3.UP, -yaw) * (p - origin)
	return Vector2(v.x, v.z)


func _note(ev: String) -> void:
	events.append([ev, _t])


## The cat inside a danger area: hurt (once per firing; a dash makes it a close call).
func _hurt_cat(from: Vector3, n: int) -> void:
	if _hit.has(0) or n <= 0:
		return
	_hit[0] = true
	var p = main.player
	var hp0: int = p.hp
	p.hurt(from, n)
	if p.hp < hp0:
		_note("cat")


## Monsters inside a circle (r) or, with half_x and half_z, inside the log's band (in its own frame).
func _hurt_foes_near(c: Vector3, r: float, half_x := -1.0, half_z := -1.0) -> void:
	if main.area == null:
		return
	for e in main.area.foes():
		if _hit.has(e.get_instance_id()):
			continue
		var dv: Vector3 = e.global_position - c
		var inside: bool
		if half_x < 0.0:
			inside = Vector2(dv.x, dv.z).length() < r + float(e.radius)
		else:
			var lv: Vector3 = Basis(Vector3.UP, -yaw) * dv
			inside = absf(lv.x) < half_x + float(e.radius) and absf(lv.z) < half_z
		if inside and not e.flyer:
			_hit[e.get_instance_id()] = true
			e.hit(Vector3(dv.x, 0, dv.z).normalized() if Vector2(dv.x, dv.z).length() > 0.01 else Vector3.FORWARD, float(cfg.get("foe_damage", 0)) * strength)
			_note("foe")


func _cat_in(c: Vector3, r: float) -> bool:
	var p: Vector3 = main.player.global_position
	return main.player.hp > 0 and Vector2(p.x - c.x, p.z - c.z).length() < r


func _physics_process(delta: float) -> void:
	if main == null or main.frozen or not active:
		return
	var d := minf(delta, 0.1)
	_t += d
	match kind:
		"log": _log(d)
		"thorns": _thorns()
		"crystal": _crystal(d)
		"spores": _spores(d)
		"tide": _tide(d)


# ---------------------------------------------------------------- the rolling log
func _log(d: float) -> void:
	var every := float(cfg["every"])
	var warn := float(cfg["warn"])
	match _state:
		"":
			_next -= d
			if _next <= 0.0:
				_state = "warn"
				_next = warn
				_hit.clear()
				var dir: Vector3 = Basis(Vector3.UP, yaw) * Vector3(_dir, 0, 0)
				Fx.telegraph_line(main, w(-half * _dir, 0.0), dir, half * 2.0, float(cfg["half_len"]) * 2.0, warn, Color(1.0, 0.55, 0.25, 0.4))
				_note("warn")
		"warn":
			_next -= d
			if _next <= 0.0:
				_state = "roll"
				_note("fire")
		"roll":
			var spd := float(cfg["speed"])
			_x += _dir * spd * d
			_node.global_position = w(_x, 0.0)
			_node.rotate_object_local(Vector3(0, 0, 1), -_dir * spd * d / 0.25)
			var c: Vector3 = _node.global_position
			var lp := local(main.player.global_position)
			if main.player.hp > 0 and absf(lp.x - _x) < float(cfg["half_w"]) + 0.3 and absf(lp.y) < float(cfg["half_len"]):
				_hurt_cat(c - Basis(Vector3.UP, yaw) * Vector3(_dir, 0, 0), dmg)
			_hurt_foes_near(c, 0.0, float(cfg["half_w"]), float(cfg["half_len"]))
			if (_dir > 0.0 and _x >= half) or (_dir < 0.0 and _x <= -half):
				_x = clampf(_x, -half, half)
				_dir = -_dir
				_state = ""
				_next = maxf(0.2, every - warn - half * 2.0 / spd)
				Fx.dust(main, _node.global_position, 6, 1.2)


# ---------------------------------------------------------------- thorn plates
func _thorns() -> void:
	var rows: int = _plates.size()
	var cycle := float(cfg["cycle"])
	var gap := float(cfg["row_gap_s"])
	var warn := float(cfg["warn"])
	var up := float(cfg["up_s"])
	var r := float(cfg["radius"])
	for k in rows:
		var zi := rows - 1 - k                              # the furthest row first: they sweep toward the cat's way in
		var tr := fmod(_t + cycle * 10.0 - k * gap, cycle)
		var want := "warn" if tr < warn else ("up" if tr < warn + up else "")
		if want == _row_state[zi]:
			if want == "up":
				for pl in _plates[zi]:
					if _cat_in(pl.global_position, r):
						_hurt_cat(pl.global_position, dmg)
					_hurt_foes_near(pl.global_position, r)
			continue
		_row_state[zi] = want
		match want:
			"warn":
				_hit.clear()
				for pl in _plates[zi]:
					Fx.telegraph_ring(main, pl.global_position, r, warn, Color(1.0, 0.45, 0.3, 0.38))
				if zi == rows - 1:
					_note("warn")
			"up":
				if zi == rows - 1:
					_note("fire")
				for pl in _plates[zi]:
					var sp := Props.find_part(pl, "spikes")
					if sp != null:
						sp.create_tween().tween_property(sp, "position:y", 0.0, 0.06)
					if _cat_in(pl.global_position, r):
						_hurt_cat(pl.global_position, dmg)
					_hurt_foes_near(pl.global_position, r)
			_:
				for pl in _plates[zi]:
					var sp2 := Props.find_part(pl, "spikes")
					if sp2 != null:
						sp2.create_tween().tween_property(sp2, "position:y", -0.5, 0.2)


# ---------------------------------------------------------------- falling crystals
func _crystal(d: float) -> void:
	match _state:
		"":
			_next -= d
			if _next <= 0.0:
				var p: Vector3 = main.player.global_position
				var a := randf() * TAU
				var at := p + Vector3(cos(a), 0, sin(a)) * randf_range(0.0, float(cfg["near_cat"]))
				var lp := local(at)
				lp.x = clampf(lp.x, -half, half)
				lp.y = clampf(lp.y, float(cfg["z_to"]), float(cfg["z_from"]))
				_fall_at = w(lp.x, lp.y)
				if main.area != null:
					_fall_at = main.area.constrain(_fall_at, 0.2, false)
				_state = "warn"
				_next = float(cfg["warn"])
				_hit.clear()
				Fx.telegraph_ring(main, _fall_at, float(cfg["radius"]), float(cfg["warn"]), Color(0.78, 0.5, 1.0, 0.4))
				_note("warn")
				var cr := Props.instance("gloom_crystal")
				add_child(cr)
				cr.global_position = _fall_at + Vector3(0, 6.0, 0)
				cr.rotation.y = randf() * TAU
				var tw := cr.create_tween()
				tw.tween_interval(maxf(float(cfg["warn"]) - 0.15, 0.0))
				tw.tween_property(cr, "position:y", cr.position.y - 6.0, 0.15).set_ease(Tween.EASE_IN)
				tw.tween_interval(0.25)
				tw.tween_property(cr, "scale", Vector3.ONE * 0.05, 0.25)
				tw.tween_callback(cr.queue_free)
		"warn":
			_next -= d
			if _next <= 0.0:
				_state = ""
				_next = maxf(0.2, float(cfg["every"]) - float(cfg["warn"]))
				_note("fire")
				Fx.shockwave(main, _fall_at, float(cfg["radius"]) + 0.2, Color(0.8, 0.55, 1.0))
				Fx.kill(main, _fall_at + Vector3(0, 0.4, 0), Color(0.78, 0.5, 1.0))
				main.shake(0.1)
				if _cat_in(_fall_at, float(cfg["radius"])):
					_hurt_cat(_fall_at, dmg)
				_hurt_foes_near(_fall_at, float(cfg["radius"]))


# ---------------------------------------------------------------- a spore vent
func _spores(d: float) -> void:
	_next -= d
	var r := float(cfg["radius"])
	match _state:
		"off":
			if _next <= 0.0:
				_state = "warn"
				_next = float(cfg["warn"])
				Fx.telegraph_ring(main, _vent, r, float(cfg["warn"]), Color(0.65, 0.9, 0.4, 0.35))
				_note("warn")
				var cap := _cap()
				if cap != null:
					cap.create_tween().tween_property(cap, "scale:y", 0.6, float(cfg["warn"]))
		"warn":
			if _next <= 0.0:
				_state = "on"
				_next = float(cfg["on_s"])
				_tick = 0.0
				_note("fire")
				var cap2 := _cap()
				if cap2 != null:
					cap2.create_tween().tween_property(cap2, "scale:y", 1.0, 0.12).set_trans(Tween.TRANS_BACK)
		"on":
			_tick -= d
			if _tick <= 0.0:
				_tick = 0.5
				Fx.spores(main, _vent, r)
			if _cat_in(_vent, r):
				if main.player.slow_t <= 0.05:
					_note("cat")
				main.player.slow_t = float(cfg["slow_s"])
			if _next <= 0.0:
				_state = "off"
				_next = float(cfg["off_s"]) - float(cfg["warn"])


func _cap() -> Node3D:
	return Props.find_part(_vent_node, "cap") if _vent_node != null else null


# ---------------------------------------------------------------- the Gloom tide
func _tide(d: float) -> void:
	if _t < float(cfg["start_after_s"]):
		return
	if _state == "":
		_state = "on"
		_note("fire")
		_tide_mi.visible = true
	_tide_z -= float(cfg["speed"]) * d
	_tide_z = maxf(_tide_z, -span + 0.5)
	var depth_m := -_tide_z
	(_tide_mi.mesh as PlaneMesh).size = Vector2(half * 2.0, maxf(depth_m, 0.01))
	_tide_mi.global_position = w(0.0, -depth_m * 0.5) + Vector3(0, 0.05, 0)
	_tide_mi.rotation.y = yaw
	_tick -= d
	if _tick <= 0.0:
		_tick = float(cfg["tick_s"])
		_hit.clear()
		var lp := local(main.player.global_position)
		if main.player.hp > 0 and lp.y > _tide_z and absf(lp.x) < half + 0.5:
			_hurt_cat(main.player.global_position + Basis(Vector3.UP, yaw) * Vector3(0, 0, 1), int(cfg["damage"]))


## How far the tide has come up the path (metres from where it started).
func tide_depth() -> float:
	return -_tide_z
