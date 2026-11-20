extends Node3D
## A puddle of Crystal Snail slime on the ground. The cat slows down while it stands in it. It fades away after a while.

var main
var radius := 0.55
var life := 7.0
var _age := 0.0
var _mat: StandardMaterial3D


func setup(m, at: Vector3, r: float, life_s: float) -> void:
	main = m
	radius = r
	life = life_s
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = 0.01
	c.radial_segments = 9
	c.rings = 1
	mi.mesh = c
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.albedo_color = Color(0.72, 0.95, 0.55, 0.0)
	_mat.emission_enabled = true
	_mat.emission = Color(0.55, 0.35, 0.9) * 0.25
	mi.material_override = _mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	global_position = Vector3(at.x, 0.035, at.z)
	rotation.y = randf() * TAU
	scale = Vector3(randf_range(0.85, 1.15), 1.0, randf_range(0.85, 1.15))
	add_to_group("slime")


func _process(delta: float) -> void:
	if main.frozen:
		return
	_age += delta
	var a := clampf(_age / 0.4, 0.0, 1.0) * clampf((life - _age) / 1.5, 0.0, 1.0)
	_mat.albedo_color.a = 0.55 * a
	var p = main.player
	var d := Vector2(p.global_position.x - global_position.x, p.global_position.z - global_position.z).length()
	if d < radius and p.hp > 0 and not p.riding:
		p.slow_t = maxf(p.slow_t, 0.25)
	if _age >= life:
		queue_free()
