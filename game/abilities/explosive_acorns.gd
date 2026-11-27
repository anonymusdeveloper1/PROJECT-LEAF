extends "res://abilities/ability.gd"
## Explosive acorns (H6 step 1): a tower's acorn that hit a foe bursts, hurting the foes round the spot for a share of the
## damage the hit did before armour. The radius and the shares per level are data (balance.json specialisations
## explosive_acorns, read through Data.specialisation_info). It never chains: burst hurts with e.hit directly, and the
## acorn is spent before it bursts (acorn.gd calls this once per hit). In Stage 1 the specialisation level is always 0,
## so only tests reach it.
## Used by: acorn.gd.


## The burst at `impact`, round `primary` (already hit, so left out), for `raw_damage` x the level's share. Returns how
## many foes it hurt; 0 for a level below 1 or a damage below 0.
static func burst(main: Node3D, impact: Vector3, primary: Node3D, raw_damage: float, level: int) -> int:
	if level < 1 or raw_damage <= 0.0:
		return 0
	var info: Dictionary = Data.specialisation_info("explosive_acorns")
	var tune: Dictionary = info.get("tuning", info) if info.get("tuning") is Dictionary else info
	var shares: Array = tune.get("share", [])
	if shares.is_empty():
		return 0
	var share := float(shares[clampi(level, 1, shares.size()) - 1])
	var radius := float(tune.get("radius_m", 0.0))
	play_effect(main, impact, "acorn_burst")
	return damage_circle(main, impact, radius, raw_damage * share, [primary]).size()
