extends Node3D
## A golden leaf on the ground. It pops out of a beaten enemy, bobs and spins, and flies to the cat when the cat
## comes within its magnet range. A Raccoon Bandit can steal it first.

var main
var value := 2
var kind := "leaf"                      # "leaf", or "shard" (display only: a raid's shards are banked at once); Phase E:
                                        # "amber", "glowstone", "heartwood" (into the run's satchel) and "dew" (heals)
var taken := false
var _vel := Vector3.ZERO
var _t := 0.0
var _flying := false
var _model: Node3D
var _ground := 0.0


func setup(m, v: int, at: Vector3, k := "leaf") -> void:
	main = m
	value = v
	kind = k
	add_to_group("pickups")
	if kind == "shard":
		_model = Props.instance("gloom_shard" if Props.has("gloom_shard") else "gloom_crystal")
		_model.scale = Vector3.ONE * (1.6 if Props.has("gloom_shard") else 0.25)
		_model.position.y = -0.09
	elif kind in ["amber", "glowstone", "heartwood"]:
		_model = Props.instance("mat_" + kind)
		_model.scale = Vector3.ONE * 1.7
	elif kind == "dew":
		_model = Props.instance("dew_drop")
		_model.scale = Vector3.ONE * 1.8
	else:
		_model = Props.instance("golden_leaf")
		_model.scale = Vector3.ONE * 1.7
	add_child(_model)
	global_position = at + Vector3(0, 0.4, 0)
	var a := randf() * TAU
	_vel = Vector3(cos(a) * randf_range(1.0, 2.4), randf_range(3.0, 4.5), sin(a) * randf_range(1.0, 2.4))
	_t = randf() * 3.0
	_ground = 0.45                      # above the tall grass


func _physics_process(delta: float) -> void:
	if taken:
		return
	_t += delta
	var cat = main.player
	var to: Vector3 = cat.global_position + Vector3(0, 0.5, 0) - global_position
	if not _flying and cat.hp > 0 and to.length() < Data.cat_magnet() and _vel.length() < 0.5:
		_flying = true
	if _flying:
		var sp := 6.0 + _t * 2.0
		global_position += to.normalized() * minf(sp * delta, to.length())
		if to.length() < 0.25:
			_collect()
		return
	# pop and settle
	_vel.y -= 14.0 * delta
	global_position += _vel * delta
	if global_position.y <= _ground:
		global_position.y = _ground
		_vel = Vector3(_vel.x * 0.4, -_vel.y * 0.35 if absf(_vel.y) > 1.0 else 0.0, _vel.z * 0.4)
	_model.rotation.y += delta * 2.5
	_model.position.y = 0.06 * sin(_t * 3.0) if _vel.length() < 0.5 else 0.0
	if main.area != null and main.area.owns(global_position):
		var y := global_position.y
		global_position = main.area.constrain(global_position, 0.25, false)   # inside the room's walls (Phase E)
		global_position.y = y
	else:
		global_position = Vector3(clampf(global_position.x, -20.5, 20.5), global_position.y, clampf(global_position.z, -20.5, 20.5))


func _collect() -> void:
	taken = true
	remove_from_group("pickups")
	if kind == "shard":
		main.collect_shard_fx(value, global_position)   # never touches Save: its value is already banked
	elif kind in ["amber", "glowstone", "heartwood"]:
		main.burrows.collect_mat(kind, value, global_position)
	elif kind == "dew":
		main.drink_dew(value, global_position)
	else:
		main.collect_leaves(value, global_position)
	queue_free()


## The raccoon takes it: returns how many leaves it was worth.
func steal() -> int:
	if taken or kind != "leaf":
		return 0
	taken = true
	remove_from_group("pickups")
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 0.05, 0.15)
	tw.tween_callback(queue_free)
	return value


## Flies to the cat even from far away (end of a wave).
func call_home() -> void:
	if not taken:
		_flying = true
		_vel = Vector3.ZERO


## Swept home at the end of a stage.
func sweep() -> void:
	if not taken:
		_collect()
