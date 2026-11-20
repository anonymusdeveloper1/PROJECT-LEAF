extends Node3D
## A bush in the meadow. The cat can hide in it. Whoever pushes through it (the cat or an enemy) makes it shake and
## shed a few leaves.

var main
var radius := 0.8
var _model: Node3D
var _inside := {}            # walker -> true while inside
var _shake := 0.0
var _t := 0.0


func setup(m, kind: String, at: Vector3, sc: float, rot: float) -> void:
	main = m
	_model = Props.instance(kind)
	add_child(_model)
	position = at
	rotation.y = rot
	scale = Vector3.ONE * sc
	radius = 0.6 * sc
	_t = randf() * 10.0


func _physics_process(delta: float) -> void:
	if main == null or main.player == null:
		return
	_t += delta
	var walkers: Array = [main.player]
	for e in get_tree().get_nodes_in_group("foes"):
		if (e.global_position as Vector3).distance_to(global_position) < radius + 1.5:
			walkers.append(e)
	for w in walkers:
		var p: Vector3 = w.global_position
		var inside := Vector2(p.x - global_position.x, p.z - global_position.z).length() < radius + 0.15
		if inside and not _inside.has(w):
			_inside[w] = true
			rustle(1.0)
		elif not inside and _inside.has(w):
			_inside.erase(w)
			rustle(0.6)
	for w in _inside.keys():
		if not is_instance_valid(w):
			_inside.erase(w)
	# shaking: quick sideways wobble that dies away; a slow sway in the wind the rest of the time
	_shake = maxf(0.0, _shake - delta * 2.2)
	var wob := sin(_t * 28.0) * 0.12 * _shake
	_model.rotation = Vector3(wob, 0.0, wob * 0.7 + sin(_t * 1.3) * 0.015)
	_model.scale = Vector3.ONE * (1.0 + 0.05 * _shake * sin(_t * 21.0))


func rustle(amount: float) -> void:
	_shake = maxf(_shake, amount)
	Fx.hit(main, global_position + Vector3(0, 0.5 * scale.y, 0), Color(0.35, 0.62, 0.25))
