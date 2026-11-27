extends "res://states/enemy/enemy_state.gd"
## The Thornling's pounce (the Moth's dive, the Beetle's shield bash).


func update(delta: float) -> String:
	e._mover.do_pounce(delta)
	return ""
