extends Node3D
## An acorn from a tower: flies at its target, curving to follow it, and hits it.

var main
var target
var damage := 8.0
var _life := 2.0
var _model: Node3D


func launch(m, from: Vector3, tgt, dmg: float) -> void:
	main = m
	target = tgt
	damage = dmg
	_model = Props.instance("acorn")
	add_child(_model)
	global_position = from


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0 or target == null or not is_instance_valid(target) or target.dead:
		queue_free()
		return
	var aim: Vector3 = target.global_position + Vector3(0, target.aim_height, 0)
	var to := aim - global_position
	var d := to.length()
	if d < 0.25 + float(target.radius) * 0.5:
		target.hit(to.normalized(), damage)
		queue_free()
		return
	global_position += to / d * minf(11.0 * delta, d)
	_model.rotation.x += delta * 12.0
