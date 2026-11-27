extends "res://states/enemy/enemy_state.gd"
## The Owl Witch's blink: gone in smoke, out next to the cat.


func update(delta: float) -> String:
	e._mover.do_blink(delta)
	return ""
