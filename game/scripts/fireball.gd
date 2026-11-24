extends Node3D
## A Fire-spitter flame ball. Swept collision finds the first foe; a single burst hurts nearby foes at impact.

var main
var direction := Vector3.BACK
var speed := 0.0
var radius := 0.0
var life := 0.0
var damage := 0.0
var burn_per_s := 0.0
var burn_s := 0.0
var blast_m := 0.0
var _area
var _spent := false
var _trail: Array = []
var _info: Dictionary = {}


func launch(game, start: Vector3, aim: Vector3, info: Dictionary, impact: float, burn: float) -> void:
	main = game
	_info = info
	_area = main.get("area")
	direction = (aim - start).normalized()
	speed = float(info["projectile_speed"])
	radius = float(info["projectile_radius"])
	life = maxf(float(info["projectile_life_s"]), start.distance_to(aim) / maxf(speed, 0.001) + float(info["projectile_flight_grace_s"]))
	blast_m = float(info["blast_m"])
	damage = impact
	burn_per_s = burn
	burn_s = float(info["burn_s"])
	global_position = start
	add_to_group("mount_fireballs")
	_trail = Fx.fireball(self, radius, direction)


func _physics_process(delta: float) -> void:
	if _spent or main == null or not is_instance_valid(main):
		return
	if main.get("area") != _area:
		_gone()
		return
	if main.frozen:
		return
	var dt := minf(delta, 0.1)
	var step := direction * speed * minf(dt, life)
	var first = null
	var nearest := INF
	for foe in get_tree().get_nodes_in_group("foes"):
		if not is_instance_valid(foe) or foe.dead:
			continue
		var center: Vector3 = foe.global_position + Vector3(0, foe.aim_height, 0)
		var t := _contact(global_position, step, center, radius + float(foe.radius))
		if t >= 0.0 and t < nearest:
			nearest = t
			first = foe
	if first != null:
		global_position += step * nearest
		_burst(first.global_position + Vector3(0, first.aim_height, 0))
		return
	global_position += step
	life -= dt
	if life <= 0.0:
		_gone()


## First intersection of this frame's flight segment with a foe's hit sphere (prevents skipping at high speed).
func _contact(start: Vector3, step: Vector3, center: Vector3, hit_radius: float) -> float:
	var from := start - center
	var c := from.length_squared() - hit_radius * hit_radius
	if c <= 0.0:
		return 0.0
	var a := step.length_squared()
	if a < 0.000001:
		return -1.0
	var b := from.dot(step)
	var discriminant := b * b - a * c
	if discriminant < 0.0:
		return -1.0
	var t := (-b - sqrt(discriminant)) / a
	return t if t >= 0.0 and t <= 1.0 else -1.0


func _burst(at: Vector3) -> void:
	if _spent:
		return
	_spent = true
	Fx.fireball_hit(main, at, blast_m)
	Fx.fire_ground(main, at, blast_m, _info)
	# There is one damage pass, including the directly hit foe: no double impact damage on the primary target.
	for foe in get_tree().get_nodes_in_group("foes"):
		if not is_instance_valid(foe) or foe.dead:
			continue
		var center: Vector3 = foe.global_position + Vector3(0, foe.aim_height, 0)
		if center.distance_to(at) > blast_m + float(foe.radius):
			continue
		var outward := center - at
		foe.hit(outward.normalized() if outward.length_squared() > 0.000001 else direction, damage)
		if not foe.dead and foe.has_method("ignite") and float(foe.last_dealt) > 0.0:
			foe.ignite(burn_s, burn_per_s)
	_gone()


func _gone() -> void:
	_spent = true
	if main != null and is_instance_valid(main):
		Fx.drop_trail(_trail, main)
	_trail = []
	queue_free()
