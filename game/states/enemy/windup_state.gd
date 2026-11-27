extends "res://states/enemy/enemy_state.gd"
## A charge gathering (the boar's paw, the Thornstag's lowered head): it faces its line and kicks up dust.


func update(delta: float) -> String:
	e._act_t += delta
	e._face(e._charge_dir, delta, 10.0)
	if fmod(e._act_t, 0.18) < delta:
		Fx.dust(e.main, e.global_position + e._charge_dir * e.radius, 4, 0.8)
	if e._act_t >= float(e.info.get("windup", 0.8)):
		e.state = "charge"
		e._act_t = 0.0
		e._play("Charge" if e.anim and e.anim.has_animation("Charge") else "Run")
	return ""
