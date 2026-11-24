extends Node3D
## A temporary visual burn mark with rising flames. Damage remains in fireball.gd's impact and enemy burn.

var main
var source_area
var age := 0.0
var life := 3.0
var radius := 1.0
var _fade := 0.8
var _ground: MeshInstance3D
var _ground_mat: ShaderMaterial
var _flames: CPUParticles3D
var _flame_mat: ShaderMaterial
var _sparks: CPUParticles3D


func setup(game, at: Vector3, spread: float, info: Dictionary) -> void:
	main = game
	source_area = main.get("area")
	life = float(info["ground_fire_s"])
	_fade = minf(float(info["ground_fire_fade_s"]), life)
	radius = spread
	global_position = Vector3(at.x, 0.045, at.z)
	add_to_group("mount_ground_fire")
	_ground = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * radius * 2.0
	_ground.mesh = plane
	_ground_mat = ShaderMaterial.new()
	_ground_mat.shader = preload("res://shaders/fire_ground.gdshader")
	_ground.material_override = _ground_mat
	_ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ground)
	_flames = Fx.flames(self, radius * 0.65, 22, 0.6, 0.42)
	_flames.name = "GroundFlames"
	_flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_flames.emission_box_extents = Vector3(radius * 0.65, 0.015, radius * 0.65)
	_flames.position.y = 0.18
	_flames.initial_velocity_min = 0.25
	_flames.initial_velocity_max = 0.65
	_flames.preprocess = 0.2
	_flame_mat = _flames.material_override.duplicate() as ShaderMaterial
	_flames.material_override = _flame_mat
	_sparks = Fx.embers(self, radius * 0.3, 8, 0.7, 0.8)
	_sparks.position.y = 0.15
	_sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_sparks.emission_box_extents = Vector3(radius * 0.5, 0.01, radius * 0.5)
	_sync()


func refresh() -> void:
	age = 0.0
	_flames.emitting = true
	_sparks.emitting = true
	_sync()


func _process(delta: float) -> void:
	if main == null or not is_instance_valid(main) or main.get("area") != source_area:
		retire()
		return
	var paused: bool = main.frozen
	_flames.speed_scale = 0.0 if paused else 1.0
	_sparks.speed_scale = 0.0 if paused else 1.0
	if paused:
		return
	age += minf(delta, 0.1)
	if age >= life:
		retire()
		return
	_sync()


func _sync() -> void:
	var fade := clampf((life - age) / maxf(_fade, 0.001), 0.0, 1.0)
	var bloom := clampf(age / 0.14, 0.0, 1.0)
	_ground_mat.set_shader_parameter("clock", age)
	_ground_mat.set_shader_parameter("opacity", fade * lerpf(0.4, 1.0, bloom))
	_ground_mat.set_shader_parameter("heat", fade)
	_flame_mat.set_shader_parameter("clock", age)
	_flame_mat.set_shader_parameter("opacity", fade)
	_flames.emitting = age < life - _fade
	_sparks.emitting = age < life - _fade * 0.5


func retire() -> void:
	remove_from_group("mount_ground_fire")
	queue_free()
