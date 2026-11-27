extends "res://states/enemy/enemy_state.gd"
## The Mole's dig under a barricade.


func update(delta: float) -> String:
	e._mover.do_dig(delta)
	return ""
