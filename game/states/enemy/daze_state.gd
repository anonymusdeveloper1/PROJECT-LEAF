extends "res://states/enemy/enemy_state.gd"
## Dazed (a missed charge, a pillar, a Stagger, a hard hit): it stands for a moment, then walks again.


func update(delta: float) -> String:
	e._act_t += delta
	if e._act_t > 0.8:
		e.state = "walk"
	return ""
