extends "res://states/enemy/enemy_state.gd"
## The charge: a straight run that hurts the cat and breaks fences.


func update(delta: float) -> String:
	e._mover.do_charge(delta)
	return ""
