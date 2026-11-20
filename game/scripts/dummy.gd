extends Node3D
## The training target as something to shoot at: the cat aims at it while standing at the target's practice spot (its marker's spot).
## It never breaks; it shows the damage of each arrow, so an upgrade shows at once.

var main
var dead := false
var anchored := true
var radius := 0.5
var aim_height := 0.95
var hp := 1e9


func _ready() -> void:
	add_to_group("enemies")


func hit(_direction: Vector3, amount := 10.0) -> void:
	var m = get_parent().main
	Fx.number(m, global_position + Vector3(0, 1.6, 0), amount, Color(1, 0.92, 0.5), true)
	Fx.hit(m, global_position + Vector3(0, 0.95, 0.2), Color(0.9, 0.8, 0.45))
	var target: Node3D = get_parent().nodes.get("target")
	if target:
		Fx.boing(target, 0.06)
