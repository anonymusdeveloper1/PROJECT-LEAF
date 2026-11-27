extends Node3D
## Only the crossbow swivels, pitches and recoils. The tower foundation stays fixed.
const ArrowShot := preload("res://scripts/acorn.gd")
const CatArrow := preload("res://scripts/arrow.gd")
var main
var piece: Dictionary
var level := 1
var target
var shots := 0
var load_progress := 0.0
var _cfg: Dictionary
var _data: Dictionary
var _yaw: Node3D
var _pitch: Node3D
var _loaded: Node3D
var _string: ShaderMaterial
var _rest := Vector3.ZERO
var _nock := Vector3.ZERO
var _load_elapsed := 0.0
var _kick := 0.0
var _active := true


func setup(game, data: Dictionary, lv: int) -> void:
	main = game
	piece = data
	level = lv
	_cfg = Data.defence_info("tower")
	_data = Data.defence_level_info("tower", level)
	var turret := Props.find_part(self, "turret")
	if turret == null:
		return
	var marker := Props.find_part(turret, "marker_shoot")
	if marker == null:
		return
	var rail_height := marker.position.y
	var asset_scale := rail_height / 0.2975
	_yaw = Node3D.new()
	_yaw.name = "TowerYaw"
	add_child(_yaw)
	_yaw.position = turret.position
	_pitch = Node3D.new()
	_pitch.name = "TowerPitch"
	_yaw.add_child(_pitch)
	_rest = Vector3(0, rail_height, 0)
	_pitch.position = _rest
	turret.reparent(_pitch)
	turret.position = Vector3(0, -rail_height, 0)
	_nock = Vector3(0, 0, -0.075 * asset_scale)
	_loaded = ArrowShot.make(level)
	_loaded.name = "LoadedArrow"
	_pitch.add_child(_loaded)
	var string_node := Props.find_part(turret, "bow_string")
	if string_node is MeshInstance3D:
		_string = ShaderMaterial.new()
		_string.shader = preload("res://shaders/tower_string.gdshader")
		_string.set_shader_parameter("half_width", 0.42 * asset_scale)
		_string.set_shader_parameter("relax_m", float(_cfg["string_relax_m"]) * asset_scale)
		(string_node as MeshInstance3D).material_override = _string
	marker.position = Vector3(0, rail_height, _nock.z + CatArrow.length_for("twig") * float(_data["arrow_scale"]))
	_pose()


func set_active(on: bool) -> void:
	_active = on
	if not on:
		target = null
		_load_elapsed = 0.0
		load_progress = 0.0
	if is_instance_valid(_loaded):
		_loaded.visible = on and _load_elapsed >= 0.0


func _valid(foe) -> bool:
	if foe == null or not is_instance_valid(foe) or foe.dead:
		return false
	var offset: Vector3 = foe.global_position - global_position
	return Vector2(offset.x, offset.z).length() <= float(_data["range"])


func tick(delta: float, foes: Array) -> void:
	if not _active or _yaw == null or main.area != null:
		return
	var dt := minf(delta, 0.1)
	piece["cd"] = maxf(0.0, float(piece["cd"]) - dt)
	_load_elapsed += dt
	_kick = maxf(0.0, _kick - dt / float(_cfg["recover_s"]))
	if not _valid(target):
		target = null
		var nearest := float(_data["range"]) + 0.001
		for foe in foes:
			if _valid(foe):
				var offset: Vector3 = foe.global_position - global_position
				var dist := Vector2(offset.x, offset.z).length()
				if dist < nearest:
					nearest = dist
					target = foe
	if target != null:
		var aim: Vector3 = target.global_position + Vector3(0, target.aim_height, 0) - _pitch.global_position
		var yaw := atan2(aim.x, aim.z)
		var pitch := atan2(-aim.y, Vector2(aim.x, aim.z).length())
		var max_pitch := deg_to_rad(float(_cfg["aim_pitch_deg"]))
		pitch = clampf(pitch, -max_pitch, max_pitch)
		var step := deg_to_rad(float(_cfg["aim_turn_deg_per_s"])) * dt
		_yaw.global_rotation.y += clampf(wrapf(yaw - _yaw.global_rotation.y, -PI, PI), -step, step)
		_pitch.rotation.x = move_toward(_pitch.rotation.x, pitch, step)
	_pose()
	if target != null and load_progress >= 1.0 and float(piece["cd"]) <= 0.0:
		var aim: Vector3 = target.global_position + Vector3(0, target.aim_height, 0) - _pitch.to_global(_nock)
		if _pitch.global_basis.z.angle_to(aim) <= deg_to_rad(float(_cfg["aim_tolerance_deg"])):
			_shoot()


func _pose() -> void:
	if _loaded == null:
		return
	load_progress = clampf(_load_elapsed / float(_cfg["load_s"]), 0.0, 1.0)
	var eased := smoothstep(0.0, 1.0, load_progress)
	_loaded.visible = _active and _load_elapsed >= 0.0
	_loaded.position = _nock + Vector3(0, -(1.0 - eased) * 0.12, -(1.0 - eased) * float(_cfg["arrow_load_back_m"]))
	_pitch.position = _rest - _pitch.basis.z * (_kick * float(_cfg["recoil_m"]))
	if _string != null:
		_string.set_shader_parameter("draw", eased)


func _shoot() -> void:
	var shot := Node3D.new()
	shot.set_script(ArrowShot)
	main.add_child(shot)
	shot.launch(main, _pitch.to_global(_nock), _pitch.global_basis.z, level)
	shots += 1
	piece["cd"] = float(_data["every"])
	_load_elapsed = -float(_cfg["recover_s"])
	_kick = 1.0
	_pose()
	Sfx.play("shoot", -15.0)
