extends "res://states/enemy/enemy_state.gd"
## Mossback's Gloom Dash gathering: it keeps facing the cat until 0.55 s, then holds the line, then dashes at 1 s.


func update(delta: float) -> String:
	e._act_t += delta
	var to_cat: Vector3 = e.main.player.global_position - e.global_position
	to_cat.y = 0.0
	if e._act_t < 0.55 and to_cat.length() > 0.5:
		e._charge_dir = to_cat.normalized()
	e._face(e._charge_dir, delta, 8.0)
	if e._act_t >= 1.0:
		e.state = "dash"
		e._act_t = 0.0
		e._play("Walk", 0.05)
		e.main.shake(0.15)
	return ""
