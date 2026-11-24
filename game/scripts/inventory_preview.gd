extends SubViewportContainer
## A small isolated world showing the player's actual model, pose, bow and current ridden mount.

var main
var cat_copy: Node3D
var mount_copy: Node3D
var _viewport: SubViewport
var _copies: Array = []
var _bones: Array = []
var _refresh_t := 0.0


func setup(game) -> void:
	main = game
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(206, 252)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(240, 300)
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_viewport)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.88, 0.79, 0.6, 0)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(1.0, 0.94, 0.8)
	settings.ambient_light_energy = 0.5
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = settings
	_viewport.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -35, 0)
	light.light_energy = 0.85
	_viewport.add_child(light)
	cat_copy = _copy(main.player.model)
	var riding: bool = main.player.riding and main.mount != null
	if riding and main.mount.model != null:
		mount_copy = _copy(main.mount.model)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.0 if riding else 1.85
	camera.position = Vector3(2.5, 2.1 if riding else 1.3, 4.5)
	_viewport.add_child(camera)
	camera.transform = camera.transform.looking_at(Vector3(0, 1.0 if riding else 0.68, 0))
	camera.current = true
	_sync()


func _copy(source: Node3D) -> Node3D:
	var copy := source.duplicate(0) as Node3D
	_strip_drivers(copy)
	_viewport.add_child(copy)
	copy.visible = true
	_copies.append([source, copy])
	for original in source.find_children("*", "Skeleton3D", true, false):
		var cloned := copy.get_node_or_null(source.get_path_to(original)) as Skeleton3D
		if cloned != null:
			_bones.append([original, cloned])
	return copy


func _strip_drivers(node: Node) -> void:
	node.set_script(null)
	for child in node.get_children():
		if child is AnimationPlayer or child is AnimationTree or child is SkeletonModifier3D:
			child.free()
		else:
			_strip_drivers(child)


func _process(delta: float) -> void:
	_refresh_t -= delta
	if _refresh_t <= 0.0:
		_refresh_t = 0.1
		_sync()


func _sync() -> void:
	var frame: Transform3D = main.mount.global_transform if main.player.riding and main.mount != null else main.player.global_transform
	for pair in _copies:
		if not is_instance_valid(pair[0]):
			return
		pair[1].transform = frame.affine_inverse() * pair[0].global_transform
	for pair in _bones:
		if not is_instance_valid(pair[0]):
			return
		var original: Skeleton3D = pair[0]
		var cloned: Skeleton3D = pair[1]
		for bone in original.get_bone_count():
			cloned.set_bone_pose(bone, original.get_bone_pose(bone))
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
