extends Node
## An Armour part (H6 Stage 1, 27 Nov 2026; docs/ARCHITECTURE.md part 4, Component): the share of a hit that does not
## get through, and the matching share of health the thing starts without. A child named "Armour" of an enemy; no
## class_name (preload it).
## Used by: enemy.setup (set_share, before the health is worked out), enemy._apply_damage (reduce) and enemy.heal_raw (factor).
## Rules: with share 0 (every enemy in Stage 1, bosses, raid leaders and room bosses) factor() is 1.0 and reduce() gives
## back exactly what it was given. An enemy's content entry holds the share (parts.armour.share).

var share := 0.0                          # 0 = none, 0.25 = a quarter of every hit is shrugged off


func set_share(value: float) -> void:
	share = clampf(value, 0.0, 0.95)


## What is left of a hit or a heal: 1.0 with no armour.
func factor() -> float:
	return 1.0 - share


## A hit's damage after armour (the identity with no armour).
func reduce(amount: float) -> float:
	if share <= 0.0:
		return amount
	return amount * factor()
