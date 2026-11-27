extends Node
## An enemy's Heal (H6 Stage 1, 27 Nov 2026; docs/ARCHITECTURE.md part 4, Component): the Frog Shaman's heal and the
## Crow Drummer's drum: who is near, and what the moment of impact does to them.
## Used by: enemy.gd (_try_heal and _try_drum forward here) and the Attack part's impact. A child named "Heal" of the
## enemy; no class_name (preload it).
## Rules: the foes near it come from the enemy grid (candidates, group "foes"); the exact distance checks stay here.

var e: EnemyNode                           # the enemy (enemy.gd) this part belongs to; set once by bind_enemy


func bind_enemy(enemy: Node3D) -> void:
	e = enemy as EnemyNode


## The foes that may be within `range_m` of the enemy: the grid's superset (registration order), or the whole group
## when there is no grid. Callers keep their exact distance checks.
func foes_near(range_m: float) -> Array:
	var grid := e._the_grid()
	if grid == null:
		return e.get_tree().get_nodes_in_group("foes")
	var c := Vector2(e.global_position.x, e.global_position.z)
	return grid.candidates(c - Vector2(range_m, range_m), c + Vector2(range_m, range_m), &"foes")


## The Crow's beat lands: every foe within drum_range gets the drum's buff.
func impact_drum() -> void:
	Fx.shockwave(e.main, e.global_position, float(e.info["drum_range"]), Color(1.0, 0.75, 0.4))
	Fx.text(e.main, e.global_position + Vector3(0, float(e.info["height"]) + 0.3, 0), "Boom! Boom!", Color(1.0, 0.75, 0.45))
	for f in foes_near(float(e.info["drum_range"])):
		if not f.dead and f.global_position.distance_to(e.global_position) < float(e.info["drum_range"]):
			f.buff = float(e.info["drum_buff"])
			f.buff_t = float(e.info["drum_time"])
			Fx.sparkle(e.main, f.global_position + Vector3(0, f.aim_height * 2.0, 0))


## The Frog's heal lands: every wounded foe within heal_range gets heal x the Frog's strength (heal_raw: the same
## max-health clamp; a foe's armour scales what it takes in).
func impact_heal() -> void:
	var amt := float(e.info["heal"]) * e.mult
	Fx.shockwave(e.main, e.global_position, float(e.info["heal_range"]), Color(0.5, 1.0, 0.45))
	for f in foes_near(float(e.info["heal_range"])):
		if f.dead or f.global_position.distance_to(e.global_position) > float(e.info["heal_range"]):
			continue
		if f.hp < f.max_hp:
			f.heal_raw(amt)
			Fx.number(e.main, f.global_position + Vector3(0, f.aim_height * 2.0 + 0.3, 0), amt, Color(0.5, 1.0, 0.5))
			Fx.sparkle(e.main, f.global_position + Vector3(0, f.aim_height, 0))


## A Frog Shaman heals when its heal is ready and a wounded enemy is near. True when it started.
func try_heal() -> bool:
	if e._cd4 > 0.0:
		return false
	for f in foes_near(float(e.info["heal_range"])):
		if not f.dead and f.hp < f.max_hp * 0.9 and f.global_position.distance_to(e.global_position) < float(e.info["heal_range"]):
			e._start_action("heal", null)
			return true
	return false


## A Crow Drummer drums when its drum is ready and another enemy is near. True when it started.
func try_drum() -> bool:
	if e._cd4 > 0.0:
		return false
	for f in foes_near(float(e.info["drum_range"])):
		if f != e and not f.dead and f.global_position.distance_to(e.global_position) < float(e.info["drum_range"]):
			e._start_action("drum", null)
			return true
	return false
