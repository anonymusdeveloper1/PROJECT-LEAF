extends Node
## A Health part (H6 Stage 1, 27 Nov 2026; docs/ARCHITECTURE.md part 4, Component): hit points, taking damage and
## healing. A child named "Health" of an enemy; no class_name (preload it).
## Used by: enemy.gd (its `hp` and `max_hp` are properties that read and write here).
## Rules:
##   - Health never decides to kill. It reports the new numbers through `changed(hp, max_hp)`. The thing that owns it
##     (enemy.gd) runs its own death and then emits `died` (once per _die call, at the line where the loot is worked
##     out) so the Loot part reacts in the same place as before.
##   - Inside one thing the parts talk through these signals; only game-wide news goes on the Events board.
##   - hp may go below zero or above max_hp when a test or a rule writes it; set_hp stores what it is given.

signal changed(hp: float, max_hp: float)    # the numbers changed
signal died()                               # the owner's death has begun (the owner emits it)

var hp := 10.0
var max_hp := 10.0


func set_hp(value: float) -> void:
	hp = value
	changed.emit(hp, max_hp)


func set_max_hp(value: float) -> void:
	max_hp = value
	changed.emit(hp, max_hp)


## Takes `amount` off the hit points (the caller has already applied shields, dazes and armour). Returns what was taken.
func apply_damage(amount: float) -> float:
	hp -= amount
	changed.emit(hp, max_hp)
	return amount


## Gives `amount` back, never past max_hp.
func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)
	changed.emit(hp, max_hp)


## hp as a share of max_hp, 0 to 1.
func fraction() -> float:
	return clampf(hp / maxf(max_hp, 0.0001), 0.0, 1.0)
