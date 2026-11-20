extends Node3D
## An arrow in flight. The asset's origin is the nock and its tip points along +Z.

const ArrowScene := preload("res://assets/cat/CatRanger_Arrow.glb")
const SPEED := 15.0
const LENGTH := 0.48

var main
var dir := Vector3.BACK
var life := 1.4
var damage := 10.0
var pierce := 0
var _done: Array = []


func launch(start: Vector3, direction: Vector3, m, dmg := 10.0, through := 0) -> void:
	main = m
	damage = dmg
	pierce = through
	dir = direction.normalized()
	add_child(ArrowScene.instantiate())
	global_position = start
	global_basis = Basis.looking_at(-dir, Vector3.UP)        # looking_at points -Z at its target, the tip is +Z


func _physics_process(delta: float) -> void:
	var tip0 := global_position + dir * LENGTH
	global_position += dir * SPEED * delta
	var seg := dir * SPEED * delta
	life -= delta
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.dead or _done.has(e):
			continue
		var c: Vector3 = e.global_position + Vector3(0.0, e.aim_height, 0.0)
		var t := clampf((c - tip0).dot(seg) / maxf(seg.length_squared(), 0.000001), 0.0, 1.0)
		if (tip0 + seg * t).distance_to(c) < e.radius + 0.08:
			e.hit(dir, damage)
			_done.append(e)
			pierce -= 1
			if pierce < 0:
				queue_free()
				return
	if life <= 0.0:
		queue_free()
