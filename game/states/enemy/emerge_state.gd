extends "res://states/enemy/enemy_state.gd"
## A Grubling (or a boss's add) bursting out of the floor.


func update(delta: float) -> String:
	e._mover.do_emerge(delta)
	return ""
