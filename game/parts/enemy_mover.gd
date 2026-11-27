extends Node
## An enemy's Mover (H6 Stage 1, 27 Nov 2026; docs/ARCHITECTURE.md part 4, Component): how it gets about. Walking the
## trail and steering round bends, facing, fleeing, the Mole's dig, the pounce, the Owl's blink, the boar's charge, the
## Gloom Dash, the Grubling's emerge, the Golden Grub's run, and the walking dust and wobble.
## Used by: enemy.gd (its old private functions forward here, so tests and other scripts keep their names) and the
## Brain's states (states/enemy/). It is a child named "Mover" of the enemy; no class_name (preload it).
## Rules: no process callback of its own: enemy._physics_process calls it, so the frame order never changes. Every
## number still comes from the enemy's info (balance.json / its content entry). The code is the H5 code, moved.

# enemy.gd's enum CampApproach { NONE, DIRECT, TRAIL, ARRIVED } as plain numbers (the enemy stores the enum; same values)
const CAMP_NONE := 0
const CAMP_DIRECT := 1
const CAMP_TRAIL := 2
const CAMP_ARRIVED := 3

var e                                     # the enemy (enemy.gd) this part belongs to; set once by bind_enemy (untyped like `main`)


func bind_enemy(enemy: Node3D) -> void:
	e = enemy


func walk(delta: float, spd: float) -> void:
	var goal = e._goal
	if not e.flyer and e._in_area():
		# a Burrow's path bends: round the trees, not into them (checked 4 times a second; a clear line uses the live goal)
		e._steer_t -= delta
		if e._steer_t <= 0.0:
			e._steer_t = 0.25
			var st: Vector3 = e.main.area.steer(e.global_position, e._goal)
			e._steer_on = st.distance_to(e._goal) > 0.01
			e._steer_to = st
		if e._steer_on:
			goal = e._steer_to
	var to = goal - e.global_position
	to.y = 0.0
	var d = to.length()
	var want := Vector3.ZERO
	if d > 0.05:
		var dir = to / d
		want = dir * minf(spd * delta, d)
		e.position += want
		e._face(dir, delta, 8.0)
		e._play("Run" if e.id == "raccoon" and e.anim and e.anim.has_animation("Run") else "Walk")
	else:
		e._play("Idle")
	var before = e.position - want
	e.position = e.main.world.constrain(e.position, e.radius, true, e.flyer)
	# walked into a fence piece? hit it
	if not e.flyer and want.length() > 0.0005 and (e.position - before).length() < want.length() * 0.4 and e._cd <= 0.0 and e.main.defences:
		var fence = e.main.defences.fence_hit(e.global_position, e.radius + 0.25)
		if fence != null and e.info.get("digs", false):
			e._start_dig()
		elif fence != null:
			e._start_action("attack", fence)
	if e._camp_approach != CAMP_DIRECT and e._camp_approach != CAMP_TRAIL:
		return
	if e.flyer or e.state != "walk" or want == Vector3.ZERO:
		return
	var advance: float = (e.position - before).dot(want.normalized())
	if advance > 0.0 and not is_zero_approx(advance):
		return
	if e._camp_approach == CAMP_DIRECT and e.patch >= 0 and e.patch < e.main.world.trails.size():
		# Rejoin this raider's own trail when the straight walk is blocked.
		e.s = e.main.world.trail_progress(e.patch, e.global_position)
		var on_trail: Vector3 = e.main.world.trail_point(e.patch, e.s)
		e.global_position = e.main.world.constrain(on_trail, e.radius, true)
		e._last_pos = e.global_position
		e._camp_approach = CAMP_TRAIL
		e._think_t = 0.0
	else:
		# A sideways step gives the walk room to turn around a solid obstacle.
		e.position = e.main.world.constrain(before + want.cross(Vector3.UP), e.radius, true)


func face(dir: Vector3, delta: float, rate: float) -> void:
	if dir.length_squared() > 0.0001:
		e.rotation.y = lerp_angle(e.rotation.y, atan2(dir.x, dir.z), 1.0 - exp(-rate * delta))


func do_flee(delta: float, spd: float) -> void:
	if e._in_area():
		e.state = "walk"                              # nowhere to flee below ground
		return
	var out: Vector3 = e.main.world.spawn_point(e.patch, 0.0)
	var to = out - e.global_position
	to.y = 0.0
	if to.length() < 1.0:
		e.main.fight.on_escaped(e)
		e.queue_free()
		return
	var dir = to.normalized()
	e.position += dir * spd * 1.15 * delta
	e._face(dir, delta, 10.0)
	e._play("Run")
	e.position = e.main.world.constrain(e.position, e.radius, true)


## A Mole Sapper meets a barricade: it burrows under it and pops up on the other side.
func start_dig() -> void:
	e.state = "dig"
	e._act_t = 0.0
	e._act_done = false
	var past: float = e.main.world.trail_progress(e.patch, e.global_position) + 3.0 if e.main.world.trails.size() > e.patch else 0.0
	e._dig_to = e.main.world.trail_point(e.patch, past) if e.main.world.trails.size() > e.patch else e.global_position
	e._play(e._clip_or(["Dig", "Attack"]), 0.05)
	Fx.dust(e.main, e.global_position, 10, 1.2)
	Fx.text(e.main, e.global_position + Vector3(0, 1.4, 0), "Digging!", Color(0.85, 0.7, 0.5))


func do_dig(delta: float) -> void:
	e._act_t += delta
	if not e._act_done and e._act_t >= 0.8:
		e._act_done = true
		e._body.visible = false
		e.global_position = Vector3(e._dig_to.x, 0, e._dig_to.z)
		e._last_pos = e.global_position
	if e._act_t >= 1.5 and not e._body.visible:
		e._body.visible = true
		e._play(e._clip_or(["Emerge", "Idle"]), 0.05)
		Fx.dust(e.main, e.global_position, 12, 1.3)
	if e._act_t >= 2.1:
		e.state = "walk"
		e._think_t = 0.0


## Thornling pounce: a hop at the cat that lands with a splash. The same move is the Gloom Moth's dive (arc < 0) and
## the Beetle Knight's shield bash (arc 0: a quick shove along the ground).
func start_pounce(at: Vector3, max_d := 2.6, arc := 0.65, dur := 0.45) -> void:
	e.state = "pounce"
	e._act_t = 0.0
	e._arc = arc
	e._dur = dur
	e._from = e.global_position
	var d = at - e._from
	d.y = 0.0
	e._to = e._from + d.limit_length(max_d)
	e._cd4 = randf_range(3.5, 5.0)
	e._play("Attack", 0.05)
	if not e.flyer:
		Fx.dust(e.main, e.global_position, 4, 0.7)


func do_pounce(delta: float) -> void:
	e._act_t += delta
	var t := clampf(e._act_t / e._dur, 0.0, 1.0)
	var p = e._from.lerp(e._to, t)
	p.y = sin(PI * t) * e._arc
	e.global_position = p
	e._face((e._to - e._from).normalized(), delta, 14.0)
	if t >= 1.0:
		e.global_position.y = 0.0
		e.position = e.main.world.constrain(e.position, e.radius, true, e.flyer)
		if not e.flyer:
			Fx.dust(e.main, e.global_position, 7, 1.0)
		Fx.hit(e.main, e.global_position + Vector3(0, 0.2 + e.fly_h * 0.5, 0), e._color)
		if e._cat_reachable(0.9 + (0.3 if e._power else 0.0)):
			e.main.player.hurt(e.global_position, e.damage)
			e.main.shake(0.1 if not e._power else 0.22)
		e._power = false
		e.state = "walk"
		e._cd = float(e.info["attack_every"]) * 0.5


## The Owl Witch vanishes in a puff of feathers and comes out of another next to the cat.
func start_blink() -> void:
	e.state = "blink"
	e._act_t = 0.0
	e._act_done = false
	e._cd5 = float(e.info.get("blink_every", 9.0))
	Fx.smoke(e.main, e.global_position)
	Fx.kill(e.main, e.global_position + Vector3(0, 1.0, 0), Color(0.6, 0.4, 0.85))
	var a := randf() * TAU
	var to: Vector3 = e.main.player.global_position + Vector3(cos(a), 0, sin(a)) * 3.0
	e._blink_to = e.main.world.constrain(to, e.radius, true)
	e._body.visible = false


func do_blink(delta: float) -> void:
	e._act_t += delta
	if not e._act_done and e._act_t >= 0.45:
		e._act_done = true
		e.global_position = e._blink_to
		e._last_pos = e.global_position
		e._body.visible = true
		Fx.smoke(e.main, e.global_position)
		Fx.shockwave(e.main, e.global_position, 1.6, Color(0.8, 0.45, 1.0))
		Fx.boing(e._body, 0.3)
		var to: Vector3 = e.main.player.global_position - e.global_position
		to.y = 0.0
		if to.length() > 0.01:
			e.rotation.y = atan2(to.x, to.z)
	if e._act_t >= 0.8:
		e.state = "walk"
		e._think_t = 0.0


func do_charge(delta: float) -> void:
	e._act_t += delta
	var step = e._charge_dir * float(e.info["charge_speed"]) * delta
	var before = e.global_position
	e.position += step
	e._face(e._charge_dir, delta, 20.0)
	if int(e._t * 20.0) % 2 == 0:
		Fx.dust(e.main, e.global_position - e._charge_dir * e.radius, 3, 1.2)
	# the cat
	var p = e.main.player
	if p.hp > 0 and not e.main.world.inside_camp(p.global_position) and p.global_position.distance_to(e.global_position) < e.radius + 0.4:
		p.hurt(e.global_position, e.damage * 2)
		Fx.shockwave(e.main, e.global_position + e._charge_dir * e.radius, 1.6, Color(1.0, 0.7, 0.4))
		Fx.hit(e.main, p.global_position + Vector3(0, 0.5, 0), Color(1.0, 0.5, 0.4))
		e.main.shake(0.3)
		e._end_charge()
		return
	# the Moss Warden stands its ground: the charge stops there
	var g = e.main.guardian
	if g != null and g.up() and e.global_position.distance_to(g.global_position) < e.radius + float(g.radius) + 0.2:
		g.hurt(e.gate_damage)
		g.blocked(e.global_position)
		e._end_charge(true)
		return
	# a fence or the gate
	var fence = e.main.defences.fence_hit(e.global_position, e.radius + 0.3)
	if fence != null:
		fence.hurt(int(e.info.get("fence_damage", 100)))
		Fx.shockwave(e.main, e.global_position + e._charge_dir * e.radius, 1.6, Color(0.8, 0.6, 0.4))
		e.main.shake(0.2)
		e._end_charge(true)
		return
	e.position = e.main.world.constrain(e.position, e.radius, true)
	if e._in_area():
		if e.global_position.distance_to(before + step) > 0.05:
			e._daze_long(float(Data.burrow_cfg()["daze_on_block_s"]))   # into a pillar or a wall: dazed, a weak spot
			return
		if e._act_t > float(e.info.get("charge_time", 1.4)):
			e._end_charge(true)
		return
	if e.global_position.distance_to(before + step) > 0.05:
		# rammed something solid: a building or a tower takes the blow
		for b in e.main.stations.building_targets():
			if e.global_position.distance_to(b[1]) < float(b[2]) + e.radius + 0.6:
				e.main.stations.hurt_building(String(b[0]), e.gate_damage)
				e.main.shake(0.25)
				break
		for t in e.main.defences.tower_targets():
			if e.global_position.distance_to(t[1]) < float(t[2]) + e.radius + 0.6:
				t[0].hurt(e.gate_damage)
				e.main.shake(0.2)
				break
		e._end_charge(true)
		return
	if e._act_t > float(e.info.get("charge_time", 1.4)) or e.global_position.length() > e.main.world.WOODS_R + 2.0:
		e._end_charge(true)


## The charge is over: a short pause. A boar whose charge did not hit the cat (`missed`) is dazed instead (Phase F);
## a boss that charges (the Thornstag) only pauses.
func end_charge(missed := false) -> void:
	if missed and not e.boss and e._ai == "boar":
		e._miss_daze()
		return
	e.state = "daze"
	e._act_t = 0.0
	e._cd2 = float(e.info.get("charge_every", 4.0))
	e._play("Idle")


## Mossback's Gloom Dash: wind gathers round it, a line on the ground shows where it will go, then it rushes the cat
## and swipes on arrival with double damage.
func start_dash() -> void:
	e.state = "dash_windup"
	e._act_t = 0.0
	var to_cat: Vector3 = e.main.player.global_position - e.global_position
	to_cat.y = 0.0
	e._charge_dir = to_cat.normalized()
	e._cd4 = float(e.mods.get("dash_every", e.info.get("dash_every", 8.0))) * e._cdk()
	e._play("Roar" if e.anim and e.anim.has_animation("Roar") else "Idle", 0.1)
	Fx.wind_aura(e, 1.8, e.radius * 1.4)
	Fx.telegraph_line(e.main, e.global_position, e._charge_dir, minf(to_cat.length() + 1.0, 9.0), e.radius * 1.8, 1.0, Color(0.75, 0.35, 1.0, 0.35))
	Fx.text(e.main, e.global_position + Vector3(0, float(e.info["height"]) + 0.4, 0), "!!", Color(0.9, 0.5, 1.0))


func do_dash(delta: float) -> void:
	e._act_t += delta
	var step = e._charge_dir * 9.0 * delta
	var before = e.global_position
	e.position += step
	e._face(e._charge_dir, delta, 20.0)
	if fmod(e._act_t, 0.07) < delta:
		Fx.dust(e.main, e.global_position - e._charge_dir * e.radius, 4, 1.6)
	var fence = e.main.defences.fence_hit(e.global_position, e.radius + 0.3)
	if fence != null:
		fence.hurt(150)
		Fx.shockwave(e.main, e.global_position + e._charge_dir * e.radius, 2.2, Color(0.8, 0.55, 1.0))
		e.main.shake(0.3)
		e._end_dash()
		return
	e.position = e.main.world.constrain(e.position, e.radius, true)
	var reach = float(e.info["reach"]) + e.radius + 0.3
	var blocked = e.global_position.distance_to(before + step) > 0.05
	if blocked and e._in_area() and not e._cat_reachable(reach):
		e._daze_long(float(Data.burrow_cfg()["daze_on_block_s"]))       # the Gloom Dash ends in a pillar or a wall
		return
	if e._cat_reachable(reach) or blocked or e._act_t > 0.8:
		e._end_dash()


func end_dash() -> void:
	e._power = true
	e._start_action("attack", e.main.player)
	e._cd = float(e.info["attack_every"])


func do_emerge(delta: float) -> void:
	e._act_t += delta
	if not e._act_done and e._act_t >= float(e.info.get("emerge_warn", 0.8)):
		e._act_done = true
		e._body.visible = true
		e._play(e._clip_or(["Emerge", "Idle"]), 0.05)
		Fx.dust(e.main, e.global_position, 10, 1.0)
		Fx.boing(e._body, 0.3)
		var p = e.main.player
		if p.hp > 0 and Vector2(p.global_position.x - e._emerge_at.x, p.global_position.z - e._emerge_at.z).length() < float(e.info.get("emerge_r", 0.6)):
			p.hurt(e._emerge_at, int(e.info.get("emerge_damage", 1)))
	if e._act_t >= float(e.info.get("emerge_warn", 0.8)) + 0.35:
		e.state = "walk"
		e._think_t = 0.0


## The Golden Grub scurries in from the woods, round the camp at _run_r, then out into its road's woods. It never steps
## into the firelight, veers away from a cat within _shy_r m (not a hidden one), and once life_t runs out it makes for
## the nearest woods. In the woods it is gone (_grub_away).
func do_grub(delta: float, spd: float) -> void:
	e.state = "chase"
	e.life_t -= delta
	var w = e.main.world
	var me := Vector3(e.global_position.x, 0, e.global_position.z)
	var r := me.length()
	if r < w.WOODS_R - 0.5:
		e._run_in = true
	if r > w.WOODS_R + 0.8 and (e._run_in or e.life_t <= 0.0):
		e._grub_away()
		return
	var a := atan2(me.x, -me.z)
	var goal: Vector3
	if e.life_t <= 0.0:
		goal = me / maxf(r, 0.01) * (w.WOODS_R + 2.0)                 # time is up: into the nearest woods
	else:
		var left := fposmod((e._run_a - a) * e._run_dir, TAU)             # how far round it still has to go
		if e._run_in and (left < 0.4 or left > TAU - 0.3):
			e._run_out = true
		if e._run_out:
			goal = Vector3(sin(e._run_a), 0, -cos(e._run_a)) * (w.WOODS_R + 2.0)
		else:
			var ca = a + e._run_dir * 0.55                            # a point a little further round the run
			goal = Vector3(sin(ca), 0, -cos(ca)) * e._run_r
	var dir := goal - me
	dir /= maxf(dir.length(), 0.01)
	var p = e.main.player
	if p.hp > 0 and not e.main.cat_hidden():
		var off: Vector3 = me - Vector3(p.global_position.x, 0, p.global_position.z)
		var dc := off.length()
		if dc < e._shy_r and dc > 0.01:
			var side := Vector3(-off.z, 0, off.x) / dc                # round the cat, the side it was going anyway
			if side.dot(dir) < 0.0:
				side = -side
			dir = (dir + (off / dc + side) * (2.0 * (1.0 - dc / e._shy_r) + 0.5)).normalized()
	e.position += dir * spd * delta
	e._face(dir, delta, 10.0)
	e._play("Run" if e.anim and e.anim.has_animation("Run") else "Walk")
	# never into the firelight; round buildings and the lake (it slips under barricades)
	var keep: float = float(w.camp_r) + e.radius + 0.3
	var q := Vector2(e.position.x, e.position.z)
	if q.length() < keep:
		q = q / maxf(q.length(), 0.01) * keep
		e.position.x = q.x
		e.position.z = q.y
	if q.length() < w.MOVE_R - 0.4:
		e.position = w.constrain(e.position, e.radius, false)


## The Golden Grub reached the woods: gone, quietly (no pay, nothing counted).
func grub_away() -> void:
	e.dead = true
	e._grid_remove()
	e.remove_from_group("enemies")
	e.remove_from_group("foes")
	e.remove_from_group("bonus")
	e.main.hud.toast("The Golden Grub got away!")
	var tw = e.create_tween()
	tw.tween_property(e, "scale", Vector3.ONE * 0.02, 0.25)
	tw.tween_callback(e.queue_free)


func stride(delta: float) -> void:
	# rigged walkers lean into their stride and kick up a little dust as they go
	var moved = e.global_position - e._last_pos
	moved.y = 0.0
	e._last_pos = e.global_position
	var v = moved.length() / maxf(delta, 0.0001)
	var lean := clampf(v * 0.045, 0.0, 0.2) if e.state in ["walk", "chase", "flee", "charge", "dash"] else 0.0
	e.model.rotation.x = lerpf(e.model.rotation.x, lean, 1.0 - exp(-8.0 * delta))
	e._step_d += moved.length()
	var step_len := maxf(0.45, e.radius * 1.6)
	if e._step_d > step_len:
		e._step_d = 0.0
		if v > 0.4 and not e.flyer and e.global_position.distance_to(e.main.player.global_position) < 11.0:
			Fx.dust(e.main, e.global_position, 2 if e.id == "thornling" else 3, 0.5 + e.radius)


func wobble() -> void:
	# the placeholder hops and squashes as it goes
	var moving = e.state == "walk" or e.state == "chase" or e.state == "flee" or e.state == "charge"
	var f := 9.0 if e.id == "thornling" else (12.0 if e.state == "charge" else 6.0)
	var hop := absf(sin(e._t * f)) if moving else 0.25 + 0.25 * sin(e._t * 3.0)
	e._body.position.y = 0.06 * hop * e._scale
	var k := 0.08
	e._body.scale = Vector3(1.0 + k * (1.0 - hop), 1.0 - k + 2.0 * k * hop, 1.0 + k * (1.0 - hop)) * e._scale
	if e.state == "attack" or e.state == "slam":
		var a := clampf(e._act_t / maxf(e._act_event, 0.05), 0.0, 1.0)
		e._body.rotation.x = -0.5 * a if e._act_t < e._act_event else 0.4 * maxf(0.0, 1.0 - (e._act_t - e._act_event) * 4.0)
	else:
		e._body.rotation.x = lerpf(e._body.rotation.x, 0.0, 0.2)
