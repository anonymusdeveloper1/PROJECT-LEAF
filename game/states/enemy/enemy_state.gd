extends RefCounted
## The base of an enemy's Brain states (H6 Stage 1, 27 Nov 2026; docs/ARCHITECTURE.md part 4, State): one short script
## per state, each with enter(), exit() and update(delta). update returns the next state's name, or "" to stay.
## In Stage 1 the H5 code that sets `state = "..."` stays where it is (it runs inside the moves); enter() and exit() only
## do bookkeeping and update() always returns "", so every H5 timing and order of events is kept.
## No class_name: the Brain preloads the states.

var e: EnemyNode                           # the enemy (enemy.gd) this part belongs to; set once by bind_enemy
var brain                                 # the Brain (parts/enemy_brain.gd): brain.spd is the walking speed of this frame
var entered_t := 0.0                      # bookkeeping: the enemy's _t when this state was entered


func bind(enemy: Node3D, owner_brain: Node) -> void:
	e = enemy as EnemyNode
	brain = owner_brain


func enter() -> void:
	entered_t = float(e._t)


func exit() -> void:
	pass


func update(_delta: float) -> String:
	return ""
