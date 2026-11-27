extends Node3D
## The tower's enlarged Twig Bow arrow: straight flight, a visible trail and swept collision, one impact only.
const ArrowScript := preload("res://scripts/arrow.gd")
const ExplosiveAcorns := preload("res://abilities/explosive_acorns.gd")
static var _materials := {}
var main
var direction := Vector3.BACK
var damage := 0.0
var level := 1
var length := 0.0
var speed := 0.0
var remaining := 0.0
var life := 0.0
var _spent := false
var _trail: Array = []
var _model: Node3D


static func make(lv: int) -> Node3D:
	var data: Dictionary = Data.defence_info("tower")["levels"][lv - 1]
	var model := ArrowScript.make("twig")
	model.scale = Vector3.ONE * float(data["arrow_scale"])
	if not _materials.has(lv):
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://shaders/tower_arrow.gdshader")
		mat.set_shader_parameter("arrow_length", ArrowScript.length_for("twig"))
		mat.set_shader_parameter("tip_color", Color.html(String(data["arrow_tip"])))
		mat.set_shader_parameter("fletch_color", Color.html(String(data["arrow_fletch"])))
		mat.set_shader_parameter("glow", float(data["arrow_glow"]))
		_materials[lv] = mat
	_apply(model, _materials[lv])
	return model


static func _apply(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = mat
	for child in node.get_children():
		_apply(child, mat)


func launch(game, start: Vector3, aim: Vector3, lv: int) -> void:
	main = game
	level = lv
	var cfg := Data.defence_info("tower")
	var data: Dictionary = cfg["levels"][level - 1]
	direction = aim.normalized()
	damage = float(data["damage"])
	speed = float(cfg["projectile_speed"])
	length = ArrowScript.length_for("twig") * float(data["arrow_scale"])
	remaining = float(data["range"]) + length
	life = remaining / speed + float(cfg["projectile_grace_s"])
	global_position = start
	look_at(global_position + direction, Vector3.UP, true)
	_model = make(level)
	add_child(_model)
	add_to_group("tower_arrows")
	var fx: Dictionary = Data.bow_fx("twig").duplicate(true)
	fx["color"] = data["arrow_tip"]
	fx["trail_len"] = length * 1.2
	fx["trail_w"] = 0.045
	fx["trail_alpha"] = 0.55
	_trail = Fx.arrow_trail(self, length, fx)


func _physics_process(delta: float) -> void:
	if _spent or main == null or not is_instance_valid(main):
		return
	if main.area != null:
		_gone()
		return
	if main.frozen:
		return
	var dt := minf(delta, 0.1)
	var step := minf(speed * dt, remaining)
	var end := global_position + direction * (step + length)
	var first = null
	var closest := INF
	var pad := float(Data.defence_info("tower")["projectile_radius"])
	var box_lo := Vector2(minf(global_position.x, end.x) - pad, minf(global_position.z, end.z) - pad)
	var box_hi := Vector2(maxf(global_position.x, end.x) + pad, maxf(global_position.z, end.z) + pad)
	for foe in main.enemy_grid.candidates(box_lo, box_hi, &"foes"):       # H6: only the foes near the sweep, in group order
		if not is_instance_valid(foe) or foe.dead:
			continue
		var center: Vector3 = foe.global_position + Vector3(0, foe.aim_height, 0)
		var segment := end - global_position
		var along := clampf((center - global_position).dot(segment) / maxf(segment.length_squared(), 0.000001), 0.0, 1.0)
		var point := global_position + segment * along
		if point.distance_to(center) <= float(foe.radius) + pad and along < closest:
			first = foe
			closest = along
	if first != null:
		_spent = true
		var impact := global_position.lerp(end, closest)
		first.hit(direction, damage)
		# H6: the blast is worked out from what the hit did (last_raw is set inside hit, even when it kills). A miss or an
		# absorbed hit (a blink) gives raw 0 and so no blast. The acorn is spent, so the blast never chains.
		var raw = first.get("last_raw")
		var raw_damage := float(raw) if raw != null else 0.0
		Fx.hit_burst(main, impact, direction, Data.bow_fx("twig"))
		if raw_damage > 0.0 and Data.specialisation_level("explosive_acorns") > 0:
			ExplosiveAcorns.burst(main, impact, first, raw_damage, Data.specialisation_level("explosive_acorns"))
		_gone()
		return
	global_position += direction * step
	remaining -= step
	life -= dt
	if remaining <= 0.0 or life <= 0.0:
		_gone()


func _gone() -> void:
	_spent = true
	remove_from_group("tower_arrows")
	if is_instance_valid(main):
		Fx.drop_trail(_trail, main)
	_trail = []
	queue_free()
