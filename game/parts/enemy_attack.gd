extends Node
## An enemy's Attack (H6 Stage 1, 27 Nov 2026; docs/ARCHITECTURE.md part 4, Component): the moves with a moment of
## impact. start_action sets up the clip, the timings and the telegraph; do_action counts to the moment; impact does the
## damage (melee, slam, spit, spores, summon, roar and so on); burst is the Puffball's, bolt and bolt_at are the Gloom
## bolts, second_ring the enraged boss's wider ring. The drum and heal impacts are the Heal part's.
## Used by: enemy.gd (forwarders keep the old names) and the Brain's ActionState. A child named "Attack" of the
## enemy; no class_name (preload it).
## Rules: no process callback of its own; the code is the H5 code, moved, with the same order of effects.

const BoltScript := preload("res://scripts/bolt.gd")

var e: EnemyNode                           # the enemy (enemy.gd) this part belongs to; set once by bind_enemy


func bind_enemy(enemy: Node3D) -> void:
	e = enemy as EnemyNode


func start_action(kind: String, tgt) -> void:
	e.state = kind
	e._act_target = tgt
	e._act_t = 0.0
	e._act_done = false
	match kind:
		"attack":
			e._act_len = maxf(e._clip_len("Attack", float(e.info["attack_every"])), 0.4)
			e._act_event = e._event("Attack", "hit", e._act_len * 0.45)
			e._play("Attack", 0.08)
			e._cd = float(e.info["attack_every"])
		"grab":
			e._act_trip = int(tgt.trip) if tgt is Object and is_instance_valid(tgt) else -1   # H1: this drop of the leaf
			e._act_len = e._clip_len("Grab", 0.6)
			e._act_event = e._event("Grab", "grab", 0.3)
			e._play("Grab" if e.anim and e.anim.has_animation("Grab") else "Attack", 0.08)
		"slam":
			var c: String = e._clip_or(["Slam", "Attack"])
			e._act_len = maxf(e._clip_len(c, 1.4), 0.9)
			e._act_event = e._event(c, "impact", e._event(c, "hit", 0.7))
			e._play(c, 0.1)
			e._cd2 = float(e.mods.get("slam_every", e.info.get("slam_every", 5.0))) * e._cdk()
			Fx.telegraph_ring(e.main, e.global_position, float(e.info["slam_range"]), e._act_event)
		"spit":
			e._act_len = maxf(e._clip_len("Attack", 0.9), 0.7)
			e._act_event = e._event("Attack", "hit", e._act_len * 0.5)
			e._play("Attack", 0.08)
			e._cd = float(e.info["attack_every"])
		"burst":
			e._act_len = maxf(e._clip_len("Attack", 1.0), 0.7)
			e._act_event = e._event("Attack", "hit", e._act_len * 0.75)
			e._play("Attack", 0.06)
			Fx.telegraph_ring(e.main, e.global_position, float(e.info["burst_range"]), e._act_event, Color(0.95, 0.6, 0.3, 0.35))
		"drum":
			var c0: String = e._clip_or(["Drum", "Attack"])
			e._act_len = maxf(e._clip_len(c0, 1.0), 0.8) * 2.0
			e._act_event = e._event(c0, "beat", 0.25)
			e._play(c0, 0.1)
			e._cd4 = float(e.info["drum_every"])
		"heal", "cast", "orbs":
			var c: String = e._clip_or(["Cast", "Attack"])
			e._act_len = maxf(e._clip_len(c, 1.0), 0.7)
			e._act_event = e._event(c, "cast", e._event(c, "hit", e._act_len * 0.5))
			e._play(c, 0.08)
			if kind == "heal":
				e._cd4 = float(e.info["heal_every"])
				Fx.telegraph_ring(e.main, e.global_position, float(e.info["heal_range"]), e._act_event, Color(0.5, 1.0, 0.45, 0.3))
			elif kind == "orbs":
				e._cd4 = float(e.info["orb_every"])
			else:
				e._cd = float(e.info["attack_every"])
		"hex":
			var c: String = e._clip_or(["Cast", "Attack"])
			e._act_len = maxf(e._clip_len(c, 1.0), 1.15)
			e._act_event = 1.0
			e._play(c, 0.08)
			e._cd2 = float(e.info["hex_every"])
			e._hex_at = e.main.player.global_position
			e._hex_at.y = 0.0
			Fx.telegraph_ring(e.main, e._hex_at, float(e.info["hex_range"]), 1.0, Color(0.8, 0.3, 1.0, 0.4))
			Fx.text(e.main, e._hex_at + Vector3(0, 1.6, 0), "Hex!", Color(0.85, 0.5, 1.0))
		"summon":
			var c: String = e._clip_or(["Roar", "Cast", "Attack"])
			e._act_len = maxf(e._clip_len(c, 1.2), 0.9)
			e._act_event = e._event(c, "roar", e._act_len * 0.45)
			e._play(c, 0.1)
			e._cd3 = float(e.info.get("summon_every", 15.0))
		"spores":
			e._act_len = maxf(e._clip_len("Attack", 1.0), 0.6)
			e._act_event = e._event("Attack", "hit", e._act_len * 0.45)
			e._play("Attack", 0.08)
			e._cd4 = 8.0
			e._cd = float(e.info["attack_every"])
			Fx.telegraph_ring(e.main, e.global_position, 2.6, e._act_event, Color(0.6, 0.9, 0.4, 0.3))
		"roar":
			e._act_len = e._clip_len("Roar", 1.5)
			e._act_event = e._event("Roar", "roar", 0.5)
			e._play("Roar", 0.1)
			e._cd3 = float(e.mods.get("roar_every", e.info.get("roar_every", 14.0))) * e._cdk()
		"lob":
			var c: String = e._clip_or(["Cast", "Attack"])
			e._act_len = maxf(e._clip_len(c, 1.0), 0.8)
			e._act_event = e._event(c, "cast", e._act_len * 0.45)
			e._play(c, 0.08)
			e._cd = float(e.info.get("lob_every", 2.6))
		"bite":
			e._act_len = float(e.info.get("bite_warn", 0.7)) + 0.4
			e._act_event = float(e.info.get("bite_warn", 0.7))
			e._play(e._clip_or(["Windup", "Idle"]), 0.05)
			e._cd = float(e.info["attack_every"])
			var fw := Vector3(sin(e.rotation.y), 0, cos(e.rotation.y))
			e._charge_dir = fw
			Fx.telegraph_line(e.main, e.global_position, fw, float(e.info["reach"]), float(e.info.get("bite_width", 0.9)), e._act_event, Color(1.0, 0.45, 0.3, 0.4))
	if e.anim and e.anim.current_animation != "" and e._act_len > 0.0:
		e.anim.seek(0.0, true)


func do_action(delta: float) -> void:
	e._act_t += delta
	if typeof(e._act_target) == TYPE_OBJECT and not is_instance_valid(e._act_target):
		e._act_target = null
	e._drop_pooled_grab()
	var tgt: Variant = e._act_target
	if tgt is Node3D and is_instance_valid(tgt):
		var to: Vector3 = (tgt as Node3D).global_position - e.global_position
		to.y = 0.0
		e._face(to.normalized(), delta, 10.0)
	elif tgt is String and tgt == "gate":
		e._face((Vector3.ZERO - e.global_position).normalized(), delta, 10.0)
	elif tgt != null and is_instance_valid(tgt) and not (tgt is Node3D):
		e._face(((tgt.global_position as Vector3) - e.global_position).normalized(), delta, 10.0)
	if not e._act_done and e._act_t >= e._act_event:
		e._act_done = true
		e._impact()
	if e._act_t >= e._act_len:
		e.state = "walk"
		e._power = false
		e._think_t = 0.0


## H1: a grab's leaf that has gone back to its pool (picked up, swept) is out of the scene: the grab lets it go.
func drop_pooled_grab() -> void:
	if e.state == "grab" and e._act_target is Node and not (e._act_target as Node).is_inside_tree():
		e._act_target = null


func impact() -> void:
	if typeof(e._act_target) == TYPE_OBJECT and not is_instance_valid(e._act_target):
		e._act_target = null
	e._drop_pooled_grab()
	var tgt: Variant = e._act_target
	var reach := float(e.info["reach"]) + e.radius + 0.5
	var fwd := Vector3(sin(e.rotation.y), 0, cos(e.rotation.y))
	match e.state:
		"attack":
			Fx.swipe(e.main, e.global_position + Vector3(0, float(e.info["height"]) * 0.45, 0) + fwd * e.radius * 0.6, e.rotation.y,
				float(e.info["reach"]) + e.radius + 0.25, Color(1.0, 0.85, 0.6) if not e._power else Color(0.85, 0.55, 1.0))
			Fx.hit(e.main, e.global_position + fwd * (e.radius + 0.4) + Vector3(0, 0.3, 0), e._color)
			Fx.dust(e.main, e.global_position + fwd * (e.radius + 0.3), 5, 1.0 + e.radius)
			if tgt is String and tgt == "gate":
				e.main.fight.damage_fire(e.gate_damage, e.global_position)
			elif tgt == e.main.player:
				if e._cat_reachable(reach + (0.8 if e._power else 0.0)):
					e.main.player.hurt(e.global_position, int(round(e.damage * (2 if e._power else 1) * (1.0 + e.buff if e.buff_t > 0.0 else 1.0))))
					e.main.shake(0.12 if not e._power else 0.3)
			elif tgt is Object and tgt == e.main.guardian:
				if e.main.guardian.reachable_from(e.global_position, float(e.info["reach"]) + e.radius):
					e.main.guardian.hurt(int(maxi(e.gate_damage, 4) * (1.0 + e.buff if e.buff_t > 0.0 else 1.0)))
			elif tgt != null and is_instance_valid(tgt) and tgt.has_method("hurt"):
				tgt.hurt(int(maxi(e.gate_damage, 4) * float(e.info.get("siege", 1.0)) * (1.0 + e.buff if e.buff_t > 0.0 else 1.0)))
		"grab":
			# H1: only the drop it reached for (a pooled pickup dropped again elsewhere is a new leaf)
			if tgt != null and is_instance_valid(tgt) and not tgt.taken and int(tgt.trip) == e._act_trip:
				e.carried += tgt.steal()
				Fx.text(e.main, e.global_position + Vector3(0, 1.3, 0), "Stolen!", Color(1.0, 0.55, 0.3))
				Fx.smoke(e.main, e.global_position)
				e._boost_t = 1.4
		"spores":
			Fx.spores(e.main, e.global_position, 2.6)
			e.main.shake(0.12)
			if e._cat_reachable(2.8):
				e.main.player.hurt(e.global_position, e.damage)
				e.main.player.slow_t = 1.8
				Fx.text(e.main, e.main.player.global_position + Vector3(0, 1.5, 0), "Slowed!", Color(0.7, 1.0, 0.5))
		"slam":
			Fx.shockwave(e.main, e.global_position, float(e.info["slam_range"]))
			Fx.dust(e.main, e.global_position, 18, 2.5)
			Fx.hit(e.main, e.global_position + Vector3(0, 0.3, 0), Color(0.55, 0.8, 0.3))
			e.main.shake(0.35)
			if e._cat_reachable(float(e.info["slam_range"])):
				e.main.player.hurt(e.global_position, int(round(e.damage * float(e.mods.get("slam_mult", 1.0)))))
			if e.enraged and e.mods.has("enrage_ring"):
				e._second_ring()
			for f in e.main.defences.near(e.global_position, float(e.info["slam_range"])):
				f.hurt(e.gate_damage)
			if e.main.guardian != null:
				e.main.guardian.blast(e.global_position, float(e.info["slam_range"]), e.gate_damage)
		"spit":
			var b := BoltScript.new()
			e.main.add_child(b)
			var mouth := float(e.meta["mouth_height_m"]) * e._scale if e.meta.has("mouth_height_m") else float(e.info.get("height", 1.0)) * 0.75
			var from: Vector3 = e.global_position + Vector3(0, mouth, 0) + Vector3(sin(e.rotation.y), 0, cos(e.rotation.y)) * (e.radius + 0.1)
			if tgt == e.main.player:
				var aim: Vector3 = e.main.player.global_position + Vector3(0, 0.55, 0)
				b.launch(e.main, from, aim - from, float(e.info["bolt_speed"]), e.damage, Color(0.55, 0.85, 0.3), true, null, 0.0, 0.1, 2.0)
			elif tgt != null and is_instance_valid(tgt):
				b.launch(e.main, from, (tgt.global_position as Vector3) + Vector3(0, 0.7, 0) - from, float(e.info["bolt_speed"]), float(e.gate_damage),
					Color(0.55, 0.85, 0.3), false, null, 0.0, 0.1, 3.0)
				b.struct_target = tgt
		"burst":
			e._burst()
			return
		"drum":
			e._heal.impact_drum()
		"heal":
			e._heal.impact_heal()
		"cast":
			if tgt != null and tgt != e.main.player and is_instance_valid(tgt):
				e._bolt_at(tgt)                            # a tower, a building or the campfire, from afar (Phase F)
			else:
				e._bolt(0.0, 0.6)
		"orbs":
			var n := int(e.info.get("orbs", 3))
			for k in n:
				e._bolt((float(k) - (n - 1) * 0.5) * 0.45, 1.4)
			e.main.shake(0.1)
		"hex":
			Fx.shockwave(e.main, e._hex_at, float(e.info["hex_range"]), Color(0.8, 0.35, 1.0))
			Fx.spores(e.main, e._hex_at, float(e.info["hex_range"]) * 0.8)
			e.main.shake(0.25)
			var cat: Vector3 = e.main.player.global_position
			if Vector2(cat.x - e._hex_at.x, cat.z - e._hex_at.z).length() < float(e.info["hex_range"]):
				e.main.player.hurt(e._hex_at, e.damage)
		"summon":
			e.main.shake(0.2)
			Fx.wind_aura(e, 0.9, 1.4)
			Fx.text(e.main, e.global_position + Vector3(0, float(e.info["height"]) + 0.5, 0), "Hoo-hoo!" if e.id == "owl" else "ROAR!", Color(0.85, 0.5, 1.0))
			for k in int(e.info.get("summon", 3)):
				var a := TAU * k / float(e.info.get("summon", 3)) + randf()
				var mk := String(e.info.get("minion", "moth"))
				var at := e.global_position + Vector3(cos(a), 0, sin(a)) * 1.5
				if e._in_area():
					e.main.area.spawn(mk, at, {"summon": true, "emerge": mk == "grub"})
				else:
					e.main.fight.spawn(mk, at, e.patch)
		"lob":
			# a spore bomb at the cat's spot, where it will be a moment from now
			var lead: Vector3 = e.main.player.get("vel") if e.main.player.get("vel") != null else Vector3.ZERO
			var spot: Vector3 = e.main.player.global_position + lead * float(e.info.get("lob_lead", 0.5))
			spot.y = 0.0
			if e._in_area():
				spot = e.main.area.constrain(spot, 0.3, false)
				e.main.area.strike(spot, float(e.info.get("lob_radius", 1.1)), float(e.info.get("lob_warn", 1.1)), e.damage, float(e.info.get("slow_s", 2.0)))
		"bite":
			Fx.swipe(e.main, e.global_position + Vector3(0, 0.6, 0) + e._charge_dir * e.radius, e.rotation.y, float(e.info["reach"]), Color(0.9, 0.7, 0.4))
			var cp: Vector3 = e.main.player.global_position - e.global_position
			cp.y = 0.0
			var along := cp.dot(e._charge_dir)
			var side := (cp - e._charge_dir * along).length()
			if e.main.player.hp > 0 and along > -0.2 and along < float(e.info["reach"]) + 0.3 and side < float(e.info.get("bite_width", 0.9)) * 0.5 + 0.3:
				e.main.player.hurt(e.global_position, e.damage)
				e.main.shake(0.15)
		"roar":
			e.main.shake(0.25)
			Fx.shockwave(e.main, e.global_position, 4.5, Color(0.85, 0.55, 1.0))
			Fx.wind_aura(e, 0.8, 1.6)
			Fx.text(e.main, e.global_position + Vector3(0, 3.2, 0), "ROAR!", Color(0.85, 0.5, 1.0))
			var nm := int(e.mods.get("roar_minions", e.info.get("roar_minions", 3)))
			for k in nm:
				var a := TAU * k / float(nm) + randf()
				var at := e.global_position + Vector3(cos(a), 0, sin(a)) * 1.6
				if e.enraged and k < int(e.mods.get("enrage_gloom_adds", 0)) and e._in_area():
					e.main.area.spawn(String(e.info.get("minion", "thornling")), at, {"summon": true, "gloomtouched": true})
				else:
					e.main.fight.spawn(String(e.info.get("minion", "thornling")), at, e.patch)


## A Puffball bursts: everything round it gets hurt (buildings, towers, barricades, the campfire, the cat), then it is
## gone.
func burst() -> void:
	var r := float(e.info["burst_range"])
	var me := e.global_position
	Fx.shockwave(e.main, me, r + 0.3, Color(0.95, 0.65, 0.35))
	Fx.spores(e.main, me, r)
	Fx.kill(e.main, me + Vector3(0, 0.4, 0), e._color)
	e.main.shake(0.3)
	for b in e.main.stations.building_targets():
		if me.distance_to(b[1]) - float(b[2]) < r:
			e.main.stations.hurt_building(String(b[0]), e.gate_damage)
	for h in e.main.defences.near(me, r + 1.0):
		h.hurt(e.gate_damage)
	if e.main.guardian != null:
		e.main.guardian.blast(me, r, e.gate_damage)
	if Vector2(me.x, me.z).length() < r + 0.8:
		e.main.fight.damage_fire(e.gate_damage, me)
	if e._cat_reachable(r):
		e.main.player.hurt(me, e.damage)
	e.hp = 0.0
	e._die()


## A Gloom bolt at the cat (Frog Shaman, Owl Witch's orbs), `turn` radians off the aim.
func bolt(turn: float, homing: float) -> void:
	var fwd := Vector3(sin(e.rotation.y), 0, cos(e.rotation.y))
	var from := e.global_position + Vector3(0, float(e.info["height"]) * 0.6, 0) + fwd * (e.radius + 0.15)
	var aim: Vector3 = e.main.player.global_position + Vector3(0, 0.55, 0)
	var d := (aim - from).rotated(Vector3.UP, turn)
	var b := BoltScript.new()
	e.main.add_child(b)
	b.launch(e.main, from, d, float(e.info.get("bolt_speed", 5.0)), e.damage, Color(0.78, 0.35, 1.0), true, e.main.player if homing > 0.0 else null, homing, 0.13, 3.2)


## Phase F: a Gloom bolt at a tower, a building or the campfire (a Frog Shaman's siege from afar). It flies home to it
## and hurts it by the frog's gate damage.
func bolt_at(tgt) -> void:
	var fwd := Vector3(sin(e.rotation.y), 0, cos(e.rotation.y))
	var from := e.global_position + Vector3(0, float(e.info["height"]) * 0.6, 0) + fwd * (e.radius + 0.15)
	var spd := maxf(float(e.info.get("bolt_speed", 5.0)), 0.5)
	var b := BoltScript.new()
	e.main.add_child(b)
	b.launch(e.main, from, (tgt.global_position as Vector3) + Vector3(0, 0.7, 0) - from, spd, float(e.gate_damage),
		Color(0.78, 0.35, 1.0), false, null, 0.0, 0.13, (float(e.info.get("siege_range", 8.0)) + 4.0) / spd)
	b.struct_target = tgt


## Enraged: the slam's second ring, wider, a moment after the first (step out of it, or dash through it).
func second_ring() -> void:
	var at := Vector3(e.global_position.x, 0.0, e.global_position.z)
	var r := float(e.info["slam_range"]) * float(e.mods.get("enrage_ring", 1.7))
	var warn := float(e.mods.get("enrage_ring_warn", 0.7))
	Fx.telegraph_ring(e.main, at, r, warn, Color(1.0, 0.45, 0.25, 0.4))
	e.get_tree().create_timer(warn).timeout.connect(e._ring_now.bind(at, r))


func ring_now(at: Vector3, r: float) -> void:
	if e.dead or e.main.frozen:
		return
	Fx.shockwave(e.main, at, r, Color(1.0, 0.55, 0.3))
	e.main.shake(0.3)
	var p: Node3D = e.main.player
	if p.hp > 0 and Vector2(p.global_position.x - at.x, p.global_position.z - at.z).length() < r:
		p.hurt(at, int(round(e.damage * float(e.mods.get("slam_mult", 1.0)))))
