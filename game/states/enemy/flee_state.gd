extends "res://states/enemy/enemy_state.gd"
## The Raccoon running home with the leaves it stole.


func update(delta: float) -> String:
	e._mover.do_flee(delta, brain.spd)
	if e._boost_t > 0.0 and fmod(e._t, 0.1) < delta:
		Fx.dust(e.main, e.global_position, 2, 0.6)
	return ""
