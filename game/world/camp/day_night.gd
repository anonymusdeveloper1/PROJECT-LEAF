extends RefCounted
## The camp clock follows play time. The same light nodes are reused all day.

class Keyframe:
	var at_s: float
	var hold_until_s: float
	var sun_pitch: float
	var sun_yaw: float
	var sun_color: Color
	var sun_energy: float
	var sky_top: Color
	var sky_horizon: Color
	var ambient_color: Color
	var ambient_energy: float
	var fill_energy: float
	var fog_color: Color
	var fog_density: float
	var shadow_opacity: float
	var shadow_blur: float
	var sunray_strength: float
	var fire_scale: float
	var lamp_scale: float

	func _init(values: Dictionary, ambient_min: Color, energy_min: float, fog_max: float) -> void:
		at_s = float(values["at_s"])
		hold_until_s = float(values["hold_until_s"])
		sun_pitch = deg_to_rad(float(values["sun_pitch_deg"]))
		sun_yaw = deg_to_rad(float(values["sun_yaw_deg"]))
		sun_color = Color.html(String(values["sun_color"]))
		sun_energy = float(values["sun_energy"])
		sky_top = Color.html(String(values["sky_top_color"]))
		sky_horizon = Color.html(String(values["sky_horizon_color"]))
		var ambient: Color = Color.html(String(values["ambient_color"]))
		ambient_color = Color(maxf(ambient.r, ambient_min.r), maxf(ambient.g, ambient_min.g),
			maxf(ambient.b, ambient_min.b))
		ambient_energy = maxf(float(values["ambient_energy"]), energy_min)
		fill_energy = float(values["fill_energy"])
		fog_color = Color.html(String(values["fog_color"]))
		fog_density = minf(float(values["fog_density"]), fog_max)
		shadow_opacity = float(values["shadow_opacity"])
		shadow_blur = float(values["shadow_blur"])
		sunray_strength = float(values["sunray_strength"])
		fire_scale = float(values["fire_scale"])
		lamp_scale = float(values["lamp_scale"])


var _cycle_s: float
var _max_step_s: float
var _visual_update_s: float
var _elapsed: float
var _keys: Array[Keyframe] = []
var _sky: ProceduralSkyMaterial
var _env: Environment
var _sun: DirectionalLight3D
var _fill: DirectionalLight3D
var _rays: ShaderMaterial
var _last_key: Keyframe
var _next_key: Keyframe
var _last_blend: float
var _lamps: Dictionary[OmniLight3D, float] = {}
var _window: StandardMaterial3D
var _window_base: Color
var _fire_update: Callable
var _lamp_scale: float = 1.0
var _fire_scale: float = 1.0


func _init(sky: ProceduralSkyMaterial, env: Environment, sun: DirectionalLight3D,
		fill: DirectionalLight3D, rays: ShaderMaterial) -> void:
	_sky = sky
	_env = env
	_sun = sun
	_fill = fill
	_rays = rays
	var cfg: Dictionary = Data.day_night_cfg()
	_cycle_s = float(cfg["cycle_s"])
	_max_step_s = float(cfg["max_step_s"])
	_visual_update_s = float(cfg["visual_update_s"])
	var ambient_min: Color = Color.html(String(cfg["ambient_min_color"]))
	var energy_min: float = float(cfg["ambient_min_energy"])
	var fog_max: float = float(cfg["fog_max_density"])
	for values: Dictionary in cfg["keyframes"]:
		_keys.append(Keyframe.new(values, ambient_min, energy_min, fog_max))


func advance(delta: float) -> void:
	var step: float = minf(delta, _max_step_s)
	if step <= 0.0:
		return
	Save.camp_day_s = fposmod(Save.camp_day_s + step, _cycle_s)
	_elapsed += step
	if _elapsed >= _visual_update_s:
		_elapsed = fposmod(_elapsed, _visual_update_s)
		apply()


func apply(force: bool = false) -> void:
	if force:
		_elapsed = 0.0
	var offset: float = Save.camp_day_s
	var last: int = _keys.size() - 1
	var index: int = last
	while index > 0 and offset < _keys[index].at_s:
		index -= 1
	var key: Keyframe = _keys[index]
	var next: Keyframe = _keys[0] if index == last else _keys[index + 1]
	var blend: float = 0.0
	if offset > key.hold_until_s:
		var end_s: float = _cycle_s if index == last else next.at_s
		blend = inverse_lerp(key.hold_until_s, end_s, offset)
	if not force and key == _last_key and blend == _last_blend:
		return
	_last_key = key
	_next_key = next
	_last_blend = blend
	_sun.rotation = Vector3(lerpf(key.sun_pitch, next.sun_pitch, blend), lerp_angle(key.sun_yaw, next.sun_yaw, blend), 0.0)
	_sun.light_color = key.sun_color.lerp(next.sun_color, blend)
	_sun.light_energy = lerpf(key.sun_energy, next.sun_energy, blend)
	_sun.shadow_opacity = lerpf(key.shadow_opacity, next.shadow_opacity, blend)
	_sun.shadow_blur = lerpf(key.shadow_blur, next.shadow_blur, blend)
	_sky.sky_top_color = key.sky_top.lerp(next.sky_top, blend)
	_sky.sky_horizon_color = key.sky_horizon.lerp(next.sky_horizon, blend)
	# Both ends of each blend have enough ambient light to see beyond the fire.
	_env.ambient_light_color = key.ambient_color.lerp(next.ambient_color, blend)
	_env.ambient_light_energy = lerpf(key.ambient_energy, next.ambient_energy, blend)
	_fill.light_energy = lerpf(key.fill_energy, next.fill_energy, blend)
	_env.fog_light_color = key.fog_color.lerp(next.fog_color, blend)
	_env.fog_density = lerpf(key.fog_density, next.fog_density, blend)
	_rays.set_shader_parameter("strength", lerpf(key.sunray_strength, next.sunray_strength, blend))
	update_boosts()


func register_lamp(light: OmniLight3D, window: StandardMaterial3D) -> void:
	_lamps[light] = light.light_energy
	light.tree_exiting.connect(_remove_lamp.bind(light), Object.CONNECT_ONE_SHOT)
	light.add_to_group("lamp")
	light.visible = Quality.lamps()
	light.light_energy *= _lamp_scale
	if window != null:
		_window = window
		_window_base = window.albedo_color
		_update_window()


func _remove_lamp(light: OmniLight3D) -> void:
	_lamps.erase(light)


func register_fire(update_scale: Callable) -> void:
	_fire_update = update_scale
	_fire_update.call(_fire_scale)


func update_boosts() -> void:
	# Low keeps the usual campfire light and flame.
	var boost: bool = Quality.lamps()
	var lamp: float = lerpf(_last_key.lamp_scale, _next_key.lamp_scale, _last_blend) if boost else 1.0
	var fire: float = lerpf(_last_key.fire_scale, _next_key.fire_scale, _last_blend) if boost else 1.0
	if lamp != _lamp_scale:
		_lamp_scale = lamp
		for light: OmniLight3D in _lamps:
			light.light_energy = _lamps[light] * lamp
		_update_window()
	if fire != _fire_scale:
		_fire_scale = fire
		if _fire_update.is_valid():
			_fire_update.call(fire)


func _update_window() -> void:
	if _window != null:
		_window.albedo_color = _window_base * Color(_lamp_scale, _lamp_scale, _lamp_scale)
