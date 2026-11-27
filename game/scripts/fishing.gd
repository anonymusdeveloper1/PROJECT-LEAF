extends Node3D
## Fishing at the lake (Phase C, mission 6's gift): a calm two-tap game at the Fishing Spot, between waves
## only. "Cast" on the card throws the float into the lake; after a wait (with a nibble or two) it dips: tap anywhere
## to hook the catch. Uncommon and rare catches need reeling: a ring closes on the float, tap while it is green.
## Misses cost nothing. The catch goes into the Bag (H3: for the cooking pot and the mount; Bag.add through
## Data.add_items), or it is timber and leaves. A catch that does not fit in a full Bag swims away.
## No screen of its own: fishing_ui.gd draws the "!" and the ring on the HUD and ignores the mouse; the cat stops by
## walking away (dragging), and a wave starting, the cat going down or leaving the spot's reach pull the line in.
## _process runs only while a line is out.

const UiScript := preload("res://scripts/fishing_ui.gd")
## How high the middle of each catch prop is above its origin (they stand on the ground; the catch spins about its middle).
const MIDDLE := {"fish_minnow": 0.047, "fish_perch": 0.071, "fish_trout": 0.069, "fish_carp": 0.094, "driftwood": 0.045, "sunken_chest": 0.11}

var main
var rng := RandomNumberGenerator.new()
var phase := ""                       # "" | cast | wait | bite | reel | land
var catch: Dictionary = {}
var _t := 0.0
var _wait := 0.0
var _nibbles: Array = []              # [seconds into the wait, done]
var _pulses := 0
var _misses := 0
var _pulse_t := 0.0
var _ring = null
var _at := Vector3.ZERO               # where the float is
var _bobber: MeshInstance3D
var _line: MeshInstance3D
var _imesh: ImmediateMesh
var _ui: Control
var _drag_t := 0.0
var _twitch := 0.0
var _catch_mi: Node3D
var _land_from := Vector3.ZERO
var debug_wait := -1.0                # tests: a fixed wait, a fixed catch, a fixed treasure share
var debug_catch := ""
var debug_share := -1.0
var last := ""                        # how the last cast ended: caught, missed, escaped, stopped (for the tests)


func _cfg() -> Dictionary:
	return Data.b["fishing"]


func setup(m) -> void:
	main = m
	rng.randomize()
	_bobber = MeshInstance3D.new()
	_bobber.mesh = Props.build([
		[Props._ball(0.06, 0.07, 6), Props._at(0, 0.0, 0), Color(0.92, 0.2, 0.18)],
		[Props._ball(0.055, 0.05, 6), Props._at(0, 0.045, 0), Color(0.97, 0.97, 0.95)],
		[Props._cyl(0.006, 0.006, 0.08, 4), Props._at(0, 0.1, 0), Color(0.3, 0.2, 0.1)]])
	_bobber.material_override = Props.vc()
	_bobber.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bobber.visible = false
	add_child(_bobber)
	_imesh = ImmediateMesh.new()
	_line = MeshInstance3D.new()
	_line.mesh = _imesh
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = Color(0.96, 0.96, 0.92)
	_line.material_override = lm
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_line.custom_aabb = AABB(Vector3(-14, -1, -3), Vector3(16, 5, 14))
	_line.visible = false
	add_child(_line)
	set_process(false)


## The "!" and the reel ring, drawn on the HUD.
func build_ui(hud) -> void:
	_ui = Control.new()
	_ui.set_script(UiScript)
	_ui.fishing = self
	_ui.main = main
	hud.add_child(_ui)


## How many kinds of catch are in the fish log.
func log_found() -> int:
	var n := 0
	for e in _cfg()["catches"]:
		if int(Save.fish_log.get(String(e["id"]), 0)) > 0:
			n += 1
	return n


func busy() -> bool:
	return phase != ""


func can_fish() -> bool:
	return not busy() and int(Save.stations.get("fishing", 0)) > 0 and main.player.hp > 0 and not main.player.riding \
		and not (main.fight.active and main.fight.in_wave)


func rarity() -> String:
	return String(catch.get("rarity", "common"))


# ---------------------------------------------------------------- a cast
func cast(ring) -> void:
	if not can_fish():
		return
	_ring = ring
	main.hud.hide_card()                        # the line is out: the dialog closes (it comes back after a catch)
	main.player.facing = PI                     # facing the water, back to the camera: the line goes up the screen
	main.player.rotation.y = PI
	main.player.set_fishing(true)
	_rack_rod(false)
	_at = _landing()
	catch = {}
	_misses = 0
	_pulses = 0
	_drag_t = 0.0
	_twitch = 0.0
	last = ""
	phase = "cast"
	_t = 0.0
	_bobber.global_position = _tip()
	_bobber.visible = true
	_line.visible = true
	set_process(true)


## 1.8-2.6 m from the ring toward the lake's middle, and only where the water is deep enough.
func _landing() -> Vector3:
	var c: Dictionary = _cfg()
	var base: Vector3 = _ring.global_position if _ring != null else main.world.FISH_RING
	var lc: Vector3 = main.world.LAKE_C
	var dir := Vector3(lc.x - base.x, 0, lc.z - base.z).normalized()
	for k in 12:
		var p := base + dir.rotated(Vector3.UP, rng.randf_range(-0.25, 0.25)) * rng.randf_range(float(c["cast_m"][0]), float(c["cast_m"][1]))
		if main.world.lake_dist(p) < -0.5:
			return Vector3(p.x, 0, p.z)
	var q := base + dir * 2.4
	return Vector3(q.x, 0, q.z)


## Where the line leaves the rod: the tip of the rod in the cat's paw, else the rack's rod at the Fishing Spot.
func _tip() -> Vector3:
	var tip: Node3D = main.player.rod_tip()
	if tip == null:
		var spot: Node3D = main.stations.nodes.get("fishing")
		if spot:
			tip = Props.find_part(spot, "marker_tip")
			if tip == null:
				var rod := Props.find_part(spot, "rod")
				if rod:
					return rod.global_position + Vector3(0, 1.1, 0)
	if tip != null:
		return tip.global_position
	var p: Vector3 = main.player.global_position
	return p + Vector3(sin(main.player.facing), 0, cos(main.player.facing)) * 0.9 + Vector3(0, 1.5, 0)


func _rack_rod(on: bool) -> void:
	if not on and not main.player.has_rod():
		return                                  # no rod in the paw (another hero model): it stays on the rack
	var spot: Node3D = main.stations.nodes.get("fishing")
	if spot:
		var r := Props.find_part(spot, "rod")
		if r:
			r.visible = on


func _start_wait() -> void:
	var c := _cfg()
	phase = "wait"
	_t = 0.0
	var mult := 1.0
	for t in c["treasures"]:
		if Save.flag(String(t["id"])) and t.has("wait_mult"):
			mult *= float(t["wait_mult"])
	_wait = debug_wait if debug_wait >= 0.0 else rng.randf_range(float(c["wait_s"][0]), float(c["wait_s"][1])) * mult
	_nibbles.clear()
	for k in rng.randi_range(int(c["nibbles"][0]), int(c["nibbles"][1])):
		if _wait > 1.4:
			_nibbles.append([rng.randf_range(0.6, _wait - 0.6), false])


func _misses_allowed() -> int:
	var c := _cfg()
	var n := int(c["misses_allowed"])
	for t in c["treasures"]:
		if Save.flag(String(t["id"])) and t.has("misses"):
			n += int(t["misses"])
	return n


## A tap anywhere (not on a card or a button) while a line is out.
func _input(event: InputEvent) -> void:
	if phase == "" or not (event is InputEventScreenTouch) or not (event as InputEventScreenTouch).pressed:
		return
	if main.joystick._blocked((event as InputEventScreenTouch).position):
		return
	tap()


func tap() -> void:
	var c := _cfg()
	match phase:
		"wait":
			_wait += float(c["early_tap_s"])            # too early: nothing lost, just a little more waiting
			Fx.text(main, _at + Vector3(0, 0.5, 0), "Shh...", Color(0.85, 0.95, 1.0))
		"bite":
			var n := int((c["pulses"] as Dictionary).get(rarity(), 0))
			if n <= 0:
				_land()
			else:
				phase = "reel"
				_pulses = n
				_pulse_t = 0.0
				_t = 0.0
				Fx.text(main, _at + Vector3(0, 0.6, 0), "Hooked!", Color(1.0, 0.9, 0.5))
		"reel":
			if in_zone():
				_pulses -= 1
				var side := Vector3(rng.randf_range(-1.0, 1.0), 0, rng.randf_range(-0.4, 0.4)).normalized() * 0.3
				if main.world.lake_dist(_at + side) < -0.4:
					_at += side                         # the fish tugs sideways
				main.world.lake.splash(_at)
				Sfx.play("splash", -8.0)
				if _pulses <= 0:
					_land()
				else:
					_pulse_t = 0.0
			else:
				_slip()


## Reeling: is the closing ring green now?
func in_zone() -> bool:
	if phase != "reel":
		return false
	var c := _cfg()
	var ps := float(c["pulse_s"])
	return _pulse_t >= ps * (1.0 - float(c["pulse_zone"])) and _pulse_t <= ps + float(c["pulse_grace_s"])


func _slip() -> void:
	_misses += 1
	if _misses > _misses_allowed():
		main.world.lake.splash(_at)                     # a cheeky jump, and it is gone
		Fx.text(main, _at + Vector3(0, 0.6, 0), "Splash!", Color(0.8, 0.95, 1.0))
		stop("It got away!", true, "escaped")
		return
	Fx.text(main, _at + Vector3(0, 0.6, 0), "Easy now...", Color(1.0, 0.85, 0.6))
	_pulse_t = 0.0


func _bite() -> void:
	catch = _roll()
	phase = "bite"
	_t = 0.0
	main.world.lake.splash(_at)
	Sfx.play("splash", -4.0)


## What bites, rolled when it bites (weights in balance.json fishing.catches). After rare_pity - 1 catches without a
## rare one, only the rare ones can bite. A rare one is the next lake treasure not found yet, treasure_share of the
## time (found once each, in order).
func _roll() -> Dictionary:
	var c := _cfg()
	var pick: Dictionary = {}
	if debug_catch != "":
		pick = Data.catch_info(debug_catch).duplicate()
	else:
		var rare_only := Save.fish_dry >= int(c["rare_pity"]) - 1
		var pool: Array = []
		for e in c["catches"]:
			if not rare_only or String(e["rarity"]) == "rare":
				pool.append(e)
		var total := 0.0
		for e in pool:
			total += float(e["weight"])
		var r := rng.randf() * total
		for e in pool:
			r -= float(e["weight"])
			if r <= 0.0:
				pick = (e as Dictionary).duplicate()
				break
		if pick.is_empty():
			pick = (pool[pool.size() - 1] as Dictionary).duplicate()
	if String(pick.get("rarity", "")) == "rare":
		var share := debug_share if debug_share >= 0.0 else float(c["treasure_share"])
		for tr in c["treasures"]:
			if not Save.flag(String(tr["id"])):
				if rng.randf() < share:
					var out: Dictionary = (tr as Dictionary).duplicate()
					out["rarity"] = "rare"
					out["treasure"] = true
					out["mesh"] = "sunken_chest"
					return out
				break
	return pick


## Out of the water: the catch arcs to the cat.
func _land() -> void:
	phase = "land"
	_t = 0.0
	_land_from = _at
	var mesh_name := String(catch.get("mesh", "fish_minnow"))
	_catch_mi = Node3D.new()                        # spins about the catch's middle (the props stand on the ground)
	var mi := MeshInstance3D.new()
	mi.mesh = Props.mesh(mesh_name)
	mi.material_override = Props.vc()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0, -float(MIDDLE.get(mesh_name, 0.06)), 0)
	_catch_mi.add_child(mi)
	main.add_child(_catch_mi)
	_catch_mi.global_position = _at
	main.world.lake.splash(_at)
	Sfx.play("splash", -6.0)


func _give() -> void:
	var p = main.player
	var c := catch
	last = "caught"
	if main.raids:
		main.raids.add_gloom("fish")
	var nm := String(c.get("name", "a fish"))
	var gives: Dictionary = c.get("gives", {})
	var bits: Array = []
	var let_go := false
	if bool(c.get("treasure", false)):
		Save.set_flag(String(c["id"]))              # a lake treasure: found once, kept for good
		Save.fish_dry = 0
		main.hud.banner("A lake treasure!", Color(1.0, 0.85, 0.35), "%s: %s" % [nm, String(c.get("says", ""))])
	else:
		var id := String(c.get("id", ""))
		var first := int(Save.fish_log.get(id, 0)) == 0
		Save.fish_log[id] = int(Save.fish_log.get(id, 0)) + 1
		Save.fish_dry = 0 if String(c.get("rarity", "")) == "rare" else Save.fish_dry + 1
		if first:
			main.hud.banner_later(0.6, "New catch: %s!" % nm, Color(0.6, 0.85, 1.0), "%d of %d in your fish log" % [log_found(), (_cfg()["catches"] as Array).size()])
	for k in gives:
		var n := int(gives[k])
		match String(k):
			"leaves":
				Save.add_leaves(n)
				bits.append("+%d leaves · now %d" % [n, Save.leaves])
			"timber":
				Save.timber += n
				bits.append("+%d timber · now %d" % [n, Save.timber])
			_:
				var left: Dictionary = Data.add_items({k: n})        # into the Bag; what does not fit comes back
				var put := n - int(left.get(k, 0))
				if put < n:
					let_go = true
				if put > 0:
					bits.append(Data.food_receipt({k: put}))
	if let_go:
		bits.append("Bag full, the rest swims away")
	if not bits.is_empty():
		main.hud.toast("%s · %s" % [nm, " · ".join(bits)])
	if p.model:
		Fx.boing(p.model, 0.2)
	Fx.sparkle(main, p.global_position + Vector3(0, 1.0, 0))
	Sfx.play("pluck", -4.0)
	Save.save_game()
	_end_line()
	main.hud.refresh()
	main.reopen_ring()                          # the card comes back with "Cast"


## Pulls the line in. msg: a toast ("It got away" by itself when a fish was hooked); reopen: the card comes back.
func stop(msg := "", reopen := false, why := "stopped") -> void:
	if phase == "":
		return
	if phase == "land":
		_give()                                 # already out of the water: the cat keeps it
		return
	var hooked := phase in ["bite", "reel"]
	last = why
	_end_line()
	if msg == "" and hooked:
		msg = "It got away"
	if msg != "":
		main.hud.toast(msg)
	if reopen:
		main.reopen_ring()


func _end_line() -> void:
	phase = ""
	_bobber.visible = false
	_line.visible = false
	_imesh.clear_surfaces()
	if _catch_mi != null and is_instance_valid(_catch_mi):
		_catch_mi.queue_free()
	_catch_mi = null
	main.player.set_fishing(false)
	_rack_rod(true)
	set_process(false)
	if _ui:
		_ui.queue_redraw()


# ---------------------------------------------------------------- while a line is out
func _process(delta: float) -> void:
	if phase == "":
		set_process(false)
		return
	if main.frozen:
		stop("")
		return
	var p = main.player
	if (main.fight.active and main.fight.in_wave) or p.hp <= 0 or p.riding \
			or (_ring != null and not _ring.in_reach(p.global_position)):
		stop("")
		return
	if main.joystick.vector.length() > float(_cfg()["cancel_drag"]):
		_drag_t += delta
		if _drag_t > 0.15:                          # dragging: the cat walks off, the line comes in
			stop("")
			return
	else:
		_drag_t = 0.0
	_t += delta
	var c := _cfg()
	var bob := Vector3(_at.x, 0.06 + sin(_t * 3.0) * 0.012, _at.z)
	match phase:
		"cast":
			var k := clampf(_t / float(c["cast_s"]), 0.0, 1.0)
			var from := _tip()
			var q := from.lerp(_at, k)
			q.y = lerpf(from.y, 0.06, k) + sin(PI * k) * 0.8
			_bobber.global_position = q
			if k >= 1.0:
				main.world.lake.splash(_at)
				Sfx.play("plop", -6.0)
				_start_wait()
		"wait":
			_twitch = maxf(0.0, _twitch - delta)
			for n in _nibbles:
				if not n[1] and _t >= float(n[0]):
					n[1] = true
					_twitch = 0.15
					_ripple(_at, 0.35)
			_bobber.global_position = bob + (Vector3(0, -0.035, 0) if _twitch > 0.0 else Vector3.ZERO)
			if _t >= _wait:
				_bite()
		"bite":
			_bobber.global_position = Vector3(_at.x, -0.05 + sin(_t * 22.0) * 0.012, _at.z)
			var limit := float((c["bite_s"] as Dictionary).get(rarity(), 1.0))
			if _t >= limit:
				stop("It got away", true, "missed")
				return
		"reel":
			_pulse_t += delta
			_bobber.global_position = bob + Vector3(sin(_t * 9.0) * 0.05, -0.025, 0)
			if _pulse_t > float(c["pulse_s"]) + float(c["pulse_grace_s"]):
				_slip()
				if phase == "":
					return
		"land":
			var k2 := clampf(_t / 0.6, 0.0, 1.0)
			var to: Vector3 = p.global_position + Vector3(0, 1.0, 0)
			_catch_mi.global_position = _land_from.lerp(to, k2) + Vector3(0, sin(PI * k2) * 1.0, 0)
			_catch_mi.rotation.x = lerpf(0.9, -0.9, k2)
			_bobber.global_position = _catch_mi.global_position
			if k2 >= 1.0:
				_give()
				return
	_update_line()
	if _ui:
		_ui.queue_redraw()


## The fishing line: 6 points from the rod tip to the float, sagging while it waits, taut while it fights.
func _update_line() -> void:
	var a := _tip()
	var b := _bobber.global_position + Vector3(0, 0.1, 0)
	var sag := 0.22 if phase in ["cast", "wait"] else 0.04
	_imesh.clear_surfaces()
	_imesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for k in 6:
		var t := k / 5.0
		_imesh.surface_add_vertex(a.lerp(b, t) - Vector3(0, sin(PI * t) * sag, 0))
	_imesh.surface_end()


## A tiny ring on the water (a nibble).
func _ripple(at: Vector3, r: float) -> void:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.9
	tm.outer_radius = 1.0
	tm.rings = 16
	tm.ring_segments = 3
	mi.mesh = tm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.9, 0.97, 1.0, 0.7)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	main.add_child(mi)
	mi.global_position = Vector3(at.x, 0.06, at.z)
	mi.scale = Vector3(0.05, 0.1, 0.05)
	var tw := mi.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3(r, 0.1, r), 0.5)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.5)
	tw.chain().tween_callback(mi.queue_free)
