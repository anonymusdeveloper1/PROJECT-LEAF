extends RefCounted
## The ability toolbox (H6 step 1; docs/ARCHITECTURE.md): the small shared pieces a special ability is built from.
## Static functions only, no state. An ability file (explosive_acorns.gd) extends this one and adds its own rule.
## Used by: explosive_acorns.gd, the tests.
## Uses: main (main.enemy_grid), the foes (hit, dead, radius, aim_height), Fx.

const DEFAULT_EFFECTS := {                             # effect id -> html colour; balance.json abilities.effects wins
	"acorn_burst": "d99e4d",
	"spark": "ffd966",
}
const DEFAULT_COLOUR := "ffeb80"


## Hurts every foe within `radius` of `centre` for `damage`, once each, except the nodes in `excluded`. Same rule as the
## Fire-spitter's blast: the foe's centre is its position at aim_height, and it is hit when that is within
## radius + the foe's own radius. Each is hit along the way out from the centre (forward when it is right on it).
## Returns the foes hit, in the order they were hit.
static func damage_circle(main: Node3D, centre: Vector3, radius: float, damage: float, excluded: Array) -> Array:
	var hit: Array = []
	if main == null or not is_instance_valid(main) or main.get("enemy_grid") == null:
		return hit
	var seen := {}
	for n: Node3D in excluded:
		if n != null and is_instance_valid(n):
			seen[n.get_instance_id()] = true
	var snapshot: Array[Node3D] = main.enemy_grid.near(centre, radius, &"foes")   # taken first: a hit may kill and change the group
	for e in snapshot:
		if not is_instance_valid(e) or not e.is_in_group("foes") or e.dead:
			continue
		var iid := e.get_instance_id()
		if seen.has(iid):
			continue
		seen[iid] = true
		var c: Vector3 = e.global_position + Vector3(0.0, float(e.aim_height), 0.0)
		if c.distance_to(centre) > radius + float(e.radius):
			continue
		var outward := c - centre
		e.hit(outward.normalized() if outward.length_squared() > 0.000001 else Vector3.FORWARD, damage)
		hit.append(e)
	return hit


## Plays one of the existing hit effects at `at` (an unknown id plays the plain hit).
static func play_effect(main: Node3D, at: Vector3, effect_id: String) -> void:
	if main == null or not is_instance_valid(main):
		return
	var table: Dictionary = Data.b.get("abilities", {}).get("effects", DEFAULT_EFFECTS)
	var col := Color.html(String(table.get(effect_id, table.get("default", DEFAULT_COLOUR))))
	Fx.hit(main, at, col)
