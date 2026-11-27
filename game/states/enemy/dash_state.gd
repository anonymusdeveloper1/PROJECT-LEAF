extends "res://states/enemy/enemy_state.gd"
## The Gloom Dash itself: a rush at nine metres a second.


func update(delta: float) -> String:
	e._mover.do_dash(delta)
	return ""
