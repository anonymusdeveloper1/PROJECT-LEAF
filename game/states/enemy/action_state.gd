extends "res://states/enemy/enemy_state.gd"
## The 15 moves with a moment of impact (attack, slam, roar, grab, spores, heal, cast, orbs, hex, summon, spit, burst,
## drum, lob, bite): one shared state. The Attack part counts to the impact and back to walking.


func update(delta: float) -> String:
	e._attack.do_action(delta)
	return ""
