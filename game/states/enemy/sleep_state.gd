extends "res://states/enemy/enemy_state.gd"
## Asleep in a den (a Burrow's monster): it stands still, now and then a "z", and wakes when the cat comes near.


func update(delta: float) -> String:
	e._sleep_tick(delta)
	return ""
