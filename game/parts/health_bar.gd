extends Node
## A Health bar part (H6 Stage 1, 27 Nov 2026; docs/ARCHITECTURE.md part 4, Component): the share of health left, kept
## from the Health part's `changed` signal, for a bar over the enemy's head. A child named "HealthBar" of the enemy; no
## class_name (preload it).
## Rules: it shows nothing in Stage 1 (the boss bar on the HUD still reads the boss's hp). It only keeps `ratio` up to
## date, so a later step can draw a bar from it without touching the enemy.

var ratio := 1.0                          # hp / max_hp, 0 to 1


## Listens to the Health part. Called once by the enemy's setup.
func bind_health(health: Node) -> void:
	health.changed.connect(_on_changed)
	_on_changed(float(health.hp), float(health.max_hp))


func _on_changed(hp: float, max_hp: float) -> void:
	ratio = clampf(hp / maxf(max_hp, 0.0001), 0.0, 1.0)
