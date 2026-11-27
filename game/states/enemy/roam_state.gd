extends "res://states/enemy/enemy_state.gd"
## Every other state name (walk, chase, totem ...): the road walk and the chase. The Golden Grub runs its round, a Gloom
## Totem breathes and looks round for foes, anything else thinks five times a second (think: who to go for) and walks to
## its goal (a squad member to its spot in the formation first).


# enemy.gd's enum CampApproach { NONE, DIRECT, TRAIL, ARRIVED } as plain numbers (the enemy stores the enum; same values)
const CAMP_NONE := 0
const CAMP_DIRECT := 1
const CAMP_TRAIL := 2
const CAMP_ARRIVED := 3


func update(delta: float) -> String:
	if e._ai == "golden_grub":
		e._mover.do_grub(delta, brain.spd)
	elif e._ai == "totem":
		e._status.do_totem(delta)
	else:
		e._think_t -= delta
		if e._think_t <= 0.0:
			e._think_t = 0.2
			think()
		if e._sq_on:
			brain.spd = e._squad_steer(delta, brain.spd)      # Phase G1b: to its spot in the formation, at the leader's pace
		e._mover.walk(delta, brain.spd)
	return ""


## What it does next: stay on its road, or go for the cat, a leaf, a tower, a building or the fire (by its "ai").
func think() -> void:
	if e.patch >= 0 and e.main.world.trails.size() > e.patch:
		e.s = e.main.world.trail_progress(e.patch, e.global_position)
	if not e.awake:
		return
	if e._camp_approach == CAMP_DIRECT or e._camp_approach == CAMP_TRAIL:
		var fire: Vector3 = e.main.world.station_pos("campfire")
		var touch: float = float(e.main.stations.foot("campfire")) + e.radius + float(e.info["reach"])
		if e.global_position.distance_to(fire) > touch:
			e.state = "walk"
			e._goal = fire
			if e._camp_approach == CAMP_TRAIL and e.s + e.radius < float(e.main.world.trail_length(e.patch)):
				e._goal = e._trail_goal()
			return
		e._camp_approach = CAMP_ARRIVED
	var p = e.main.player
	var reach = float(e.info["reach"]) + e.radius + 0.3
	# Phase G1b: a squad member on the march keeps formation (a Frog Shaman still heals, a Crow Drummer still drums)
	e._sq_on = e._keep_formation()
	if e._sq_on:
		if (e._ai == "frog" and e._try_heal()) or (e._ai == "crow" and e._try_drum()):
			return
		e.state = "walk"
		return
	match e._ai:                                      # "ai" lets a kind think like another (the Gloom Herald drums)
		"raccoon":
			if e.carried < int(e.info.get("steals", 20)):
				var leaf = e.main.nearest_pickup(e.global_position, 14.0)
				if leaf != null:
					e._goal = leaf.global_position
					e.state = "chase"
					if e.global_position.distance_to(e._goal) < 0.55:
						e._start_action("grab", leaf)
					return
			if e.carried > 0:
				e.state = "flee"
				e._play("Run")
				return
			if e._cat_reachable(9.0):
				e._goal = p.global_position
				e.state = "chase"
				if e.global_position.distance_to(e._goal) < reach and e._cd <= 0.0:
					e._start_action("attack", p)
				return
		"boar":
			if e._cd2 <= 0.0 and e._cat_reachable(float(e.info["aggro"])) \
					and not e.main.world.blocked_between(e.global_position, p.global_position):
				e._charge_dir = (p.global_position - e.global_position)
				e._charge_dir.y = 0.0
				e._charge_dir = e._charge_dir.normalized()
				e.state = "windup"
				e._act_t = 0.0
				e._play("Windup" if e.anim and e.anim.has_animation("Windup") else "Idle")
				Fx.telegraph_line(e.main, e.global_position, e._charge_dir, float(e.info["charge_speed"]) * float(e.info.get("charge_time", 1.4)),
					e.radius * 2.0, float(e.info.get("windup", 0.8)))
				Fx.text(e.main, e.global_position + Vector3(0, float(e.info["height"]) + 0.3, 0), "!", Color(1, 0.4, 0.3))
				return
			if e._cat_reachable(reach) and e._cd <= 0.0:
				e._start_action("attack", p)
				return
		"bear":
			if e._cd3 <= 0.0:
				e._start_action("roar", null)
				return
			if e._cd4 <= 0.0 and e._cat_reachable(10.0) and not e._cat_reachable(3.2) \
					and not e.main.world.blocked_between(e.global_position, p.global_position):
				e._start_dash()
				return
			if e._cd2 <= 0.0 and e._cat_reachable(float(e.info["slam_range"]) * 0.8):
				e._start_action("slam", p)
				return
			if e._cat_reachable(reach) and e._cd <= 0.0:
				e._start_action("attack", p)
				return
		"moth":
			if e._cd4 <= 0.0 and e._cat_reachable(float(e.info["aggro"])) and not e._cat_reachable(0.9):
				e._start_pounce(p.global_position, 2.6, -0.75, 0.5)
				return
			if e._cat_reachable(reach) and e._cd <= 0.0:
				e._start_action("attack", p)
				return
			if e._cat_reachable(float(e.info["aggro"])):
				e._goal = p.global_position
				e.state = "chase"
				return
			# straight over barricades and buildings at the camp's towers, buildings and campfire (or at the cat,
			# once the fire is out, or below ground)
			if e.main.fight.last_stand or e._in_area():
				e._hunt(p, reach)
				return
			e.state = "walk"
			if e._siege(true):
				return
			e._goal = Vector3.ZERO
			return
		"frog":
			if e._try_heal():
				return
			if e._cd <= 0.0 and e._cat_reachable(float(e.info["cast_range"])):
				e._start_action("cast", p)
				return
			if e._cat_reachable(float(e.info["cast_range"]) * 0.9):
				e.state = "walk"
				e._goal = e.global_position                  # stands its ground and keeps casting
				return
		"beetle":
			if e._cd4 <= 0.0 and e._cat_reachable(2.2) and not e._cat_reachable(0.9):
				e._start_pounce(p.global_position, 2.0, 0.0, 0.32)
				e._cd4 = float(e.info.get("bash_every", 6.0))
				e._power = true
				Fx.text(e.main, e.global_position + Vector3(0, float(e.info["height"]) + 0.3, 0), "Bash!", Color(0.6, 0.9, 1.0))
				return
			if e._cat_reachable(float(e.info["aggro"])):
				e._goal = p.global_position
				e.state = "chase"
				if e.global_position.distance_to(e._goal) < reach and e._cd <= 0.0:
					e._start_action("attack", p)
				return
		"snail":
			if e._cd2 <= 0.0 and e._cat_reachable(float(e.info["slam_range"])):
				e._start_action("slam", p)
				return
			if e._cat_reachable(reach) and e._cd <= 0.0:
				e._start_action("attack", p)
				return
		"owl":
			if e._cd3 <= 0.0:
				e._start_action("summon", null)
				return
			if e._cd5 <= 0.0 and e._cat_reachable(11.0) and not e._cat_reachable(2.5):
				e._start_blink()
				return
			if e._cd2 <= 0.0 and e._cat_reachable(7.0):
				e._start_action("hex", p)
				return
			if e._cd4 <= 0.0 and e._cat_reachable(9.0):
				e._start_action("orbs", p)
				return
			if e._cat_reachable(reach) and e._cd <= 0.0:
				e._start_action("attack", p)
				return
		"stump", "mole":
			if e._cat_reachable(reach) and e._cd <= 0.0:
				e._start_action("attack", p)
				return
		"pitcher":
			# the cat near: spit at it; else the camp's structures from afar (_standoff, below)
			var rng := float(e.info["spit_range"])
			if e._cd <= 0.0 and e._cat_reachable(rng):
				e._start_action("spit", p)
				return
			if e._cat_reachable(rng):
				e.state = "walk"
				e._goal = e.global_position
				return
		"puffball":
			if e._cat_reachable(e.radius + 0.6):
				e._start_action("burst", p)
				return
		"crow":
			if e._try_drum():
				return
			if e._cat_reachable(reach) and e._cd <= 0.0:
				e._start_action("attack", p)
				return
		"stag":
			if e._cd3 <= 0.0:
				e._start_action("roar", null)
				return
			if e._cd2 <= 0.0 and e._cat_reachable(float(e.info["aggro"])) and not e._cat_reachable(3.0) \
					and not e.main.world.blocked_between(e.global_position, p.global_position):
				e._charge_dir = (p.global_position - e.global_position)
				e._charge_dir.y = 0.0
				e._charge_dir = e._charge_dir.normalized()
				e.state = "windup"
				e._act_t = 0.0
				e._play("Windup" if e.anim and e.anim.has_animation("Windup") else "Idle")
				Fx.telegraph_line(e.main, e.global_position, e._charge_dir, float(e.info["charge_speed"]) * float(e.info.get("charge_time", 1.4)),
					e.radius * 2.0, float(e.info.get("windup", 0.8)), Color(0.75, 0.35, 1.0, 0.35))
				Fx.text(e.main, e.global_position + Vector3(0, float(e.info["height"]) + 0.3, 0), "!!", Color(0.9, 0.5, 1.0))
				return
			if e._cd4 <= 0.0 and e._cat_reachable(float(e.info["slam_range"]) * 0.8):
				e._cd4 = float(e.info.get("slam_every", 6.0))
				e._start_action("slam", p)
				e._cd2 = maxf(e._cd2, 2.0)
				return
			if e._cat_reachable(reach) and e._cd <= 0.0:
				e._start_action("attack", p)
				return
		# Phase E: the Burrows' own kinds (stand-in models until the user's Meshy models come)
		"glowcap":
			var dist: float = e.global_position.distance_to(p.global_position)
			if e._cd <= 0.0 and e._cat_reachable(float(e.info["lob_range"])):
				e._start_action("lob", p)
				return
			if e._cat_reachable(float(e.info["keep_away"])):
				var away: Vector3 = e.global_position - p.global_position
				away.y = 0.0
				e._goal = e.global_position + (away.normalized() if away.length() > 0.01 else Vector3.FORWARD) * 2.0
				e.state = "walk"
				return
			if e._cat_reachable(float(e.info["aggro"])):
				e._goal = p.global_position if dist > 6.5 else e.global_position
				e.state = "chase" if dist > 6.5 else "walk"
				return
		"snapper":
			var to: Vector3 = p.global_position - e.global_position
			to.y = 0.0
			e._goal = e.global_position
			if to.length() > 0.01 and p.hp > 0:
				e.rotation.y = rotate_toward(e.rotation.y, atan2(to.x, to.z), float(e.info.get("turn_rate", 2.0)) * 0.2)
			var fwd := Vector3(sin(e.rotation.y), 0, cos(e.rotation.y))
			if e._cd <= 0.0 and e._cat_reachable(float(e.info["reach"])) and to.length() > 0.01 \
					and rad_to_deg(fwd.angle_to(to.normalized())) < float(e.info.get("bite_cone_deg", 35.0)):
				e._start_action("bite", p)
				return
			e.state = "walk"
			return
		"amber_grub":
			e._goal = e.main.area.flee_point(p.global_position) if e._in_area() else e.global_position
			e.state = "chase"
			return
		"brute":
			if e._cd4 <= 0.0 and e._cat_reachable(2.6):
				e._start_action("spores", p)
				return
			if e._cat_reachable(reach) and e._cd <= 0.0:
				e._start_action("attack", p)
				return
		_:
			if e._cd4 <= 0.0 and e._cat_reachable(2.8) and not e._cat_reachable(1.1):
				e._start_pounce(p.global_position)
				return
			if e._cat_reachable(float(e.info["aggro"])):
				e._goal = p.global_position
				e.state = "chase"
				if e.global_position.distance_to(e._goal) < reach and e._cd <= 0.0:
					e._start_action("attack", p)
				return
	e.state = "walk"
	if e._in_area():
		e._hunt(p, reach)                             # below ground there is no camp to siege: they hunt the cat
		return
	# the Moss Warden is in the way: fight it (every kind still tries the cat first, in its own branch above)
	var g = e.main.guardian
	if g != null and e.gate_damage > 0 and not e.flyer and not e.main.fight.last_stand and g.taunts(e):
		e._fight_guardian(g)
		return
	if e.main.fight.last_stand:
		e._hunt(p, reach)
		return
	# near the camp, or near a tower: go and knock it down (ranged kinds shoot it from siege_range m: Phase F)
	if e.gate_damage > 0:
		var sr := float(e.info.get("siege_range", e.info.get("spit_range", 0.0)))
		if sr > 0.0:
			if e._standoff(sr):
				return
		elif e._siege(false):
			return
	e._goal = e._trail_goal()
