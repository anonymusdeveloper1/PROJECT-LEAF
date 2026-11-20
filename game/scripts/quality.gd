extends Node
## Graphics level (autoload "Quality"): 0 Low, 1 Medium, 2 High. Picked on the first launch from the phone (memory,
## CPU cores, GPU, and whether it got Vulkan), stepped down by itself when the game keeps running slow, and the player
## can set it on the Shop card. Kept in user://settings.json, apart from the save, so a new game keeps it.
##   Low     3D drawn about 540 px across (the UI stays sharp), no MSAA, no sun shadows (a soft blob under each
##           character instead), no glow, a simpler ground, 40% of the grass, lanterns unlit, no sunrays, half the
##           particles, no spring bones on enemies. If even that is slow it holds a steady 30 fps.
##   Medium  3D about 810 px across, MSAA 2x, sun shadows at 1024 px, no glow, 70% of the grass
##   High    full resolution, MSAA 2x, sun shadows at 2048 px, glow, all the grass
## Tests: --quality=low|medium|high sets the level for that run only (and nothing steps down by itself).

signal changed
signal stepped_down

const LOW := 0
const MEDIUM := 1
const HIGH := 2
const NAMES := ["Low", "Medium", "High"]
const PATH := "user://settings.json"
const WIDTH_3D := [540.0, 810.0, 100000.0]      # pixels across the short side the 3D is drawn at, per level

var level := HIGH
var auto := true                                 # the game picked it (not the player), so it may still step down
var fps30 := false                               # Low and still slow: a steady 30 fps
var _test := false                               # an automated test: no stepping down, nothing saved
var _win_t := 0.0
var _win_frames := 0
var _since_start := 0.0
var _slow_windows := 0


func _ready() -> void:
	var args := Data.args()
	_test = args.has("--autotest")
	if not _load():
		level = detect()
		auto = true
		_save()
	for a in args:
		if a.begins_with("--quality="):
			var want := ["low", "medium", "high"].find(a.substr(10).to_lower())
			if want >= 0:
				level = want
				_test = true
	get_tree().root.size_changed.connect(apply_viewport)
	apply_viewport()


# ---------------------------------------------------------------- what each level does
func shadows() -> bool:
	return level >= MEDIUM


func glow() -> bool:
	return level == HIGH


func lamps() -> bool:
	return level >= MEDIUM


func sunrays() -> bool:
	return level >= MEDIUM


func lite_ground() -> bool:
	return level == LOW


func springs() -> bool:
	return level >= MEDIUM


func grass_share() -> float:
	return [0.4, 0.7, 1.0][level]


func particles(n: int) -> int:
	return maxi(1, int(round(n * [0.5, 0.8, 1.0][level])))


func label() -> String:
	return NAMES[level] + (" (auto)" if auto else "")


## The viewport: how sharp the 3D is drawn, anti-aliasing, the sun's shadow map, the frame cap.
func apply_viewport() -> void:
	var vp := get_tree().root
	var win := DisplayServer.window_get_size()
	var short := float(mini(win.x, win.y))
	var s := clampf(float(WIDTH_3D[level]) / maxf(short, 1.0), 0.5, 1.0)
	vp.scaling_3d_scale = s
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR if (s > 0.99 or level == LOW) else Viewport.SCALING_3D_MODE_FSR
	vp.msaa_3d = Viewport.MSAA_DISABLED if level == LOW else Viewport.MSAA_2X
	RenderingServer.directional_shadow_atlas_set_size(2048 if level == HIGH else 1024, true)
	if not _test:
		Engine.max_fps = 30 if fps30 else 60


## The player picked one on the Shop card: Auto, Low, Medium, High, then round again.
func cycle() -> void:
	if auto:
		auto = false
		level = LOW
	elif level < HIGH:
		level += 1
	else:
		auto = true
		level = detect()
	fps30 = false
	_save()
	apply_viewport()
	changed.emit()


# ---------------------------------------------------------------- the first guess
## A first guess from the phone; the frame-rate watch below corrects it if it was too hopeful.
func detect() -> int:
	var method := RenderingServer.get_current_rendering_method()
	if method == "gl_compatibility":
		return LOW                               # no (usable) Vulkan: an older or low-end phone
	if not OS.has_feature("mobile"):
		return HIGH
	var cap := HIGH
	var mem_gb := float(OS.get_memory_info().get("physical", 0)) / 1073741824.0
	if mem_gb > 0.1 and mem_gb < 3.5:
		return LOW
	if mem_gb > 0.1 and mem_gb < 5.5:
		cap = MEDIUM
	if OS.get_processor_count() <= 4:
		return LOW
	return mini(cap, _gpu_level(RenderingServer.get_video_adapter_name().to_lower()))


func _gpu_level(gpu: String) -> int:
	var num := 0
	var digits := ""
	for ch in gpu:
		if ch >= "0" and ch <= "9":
			digits += ch
		elif digits != "":
			break
	if digits != "":
		num = int(digits)
	if gpu.contains("adreno"):
		if num >= 800 or (num >= 730 and num < 800) or (num >= 650 and num < 700):
			return HIGH
		if num >= 615:
			return MEDIUM
		return LOW
	if gpu.contains("immortalis") or gpu.contains("xclipse"):
		return HIGH
	if gpu.contains("mali"):
		if gpu.contains("mali-t") or num in [31, 51, 52, 57]:
			return LOW
		if num in [68, 71, 72, 76]:
			return MEDIUM
		if num in [77, 78] or num >= 610:
			return HIGH
		return MEDIUM
	if gpu.contains("powervr") or gpu.contains("ge8") or gpu.contains("img "):
		return LOW
	return MEDIUM


# ---------------------------------------------------------------- the frame-rate watch
## While the level is the game's own pick: 4 s windows; two slow windows in a row step it down one level (and at Low,
## to a steady 30 fps). Windows with a hitch (a load, the app coming back) are thrown away.
func _process(delta: float) -> void:
	if _test or not auto:
		return
	_since_start += delta
	if _since_start < 8.0:
		return
	if delta > 0.25:
		_win_t = 0.0
		_win_frames = 0
		return
	_win_t += delta
	_win_frames += 1
	if _win_t < 4.0:
		return
	var fps := _win_frames / _win_t
	_win_t = 0.0
	_win_frames = 0
	var want := 30.0 if fps30 else 60.0
	if fps < want * 0.8:
		_slow_windows += 1
	else:
		_slow_windows = 0
	if _slow_windows < 2:
		return
	_slow_windows = 0
	if level > LOW:
		level -= 1
	elif not fps30:
		fps30 = true
	else:
		return
	_save()
	apply_viewport()
	changed.emit()
	stepped_down.emit()


# ---------------------------------------------------------------- settings file
func _load() -> bool:
	if not FileAccess.file_exists(PATH):
		return false
	var j = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(j) != TYPE_DICTIONARY or not j.has("quality"):
		return false
	level = clampi(int(j["quality"]), LOW, HIGH)
	auto = bool(j.get("auto", true))
	fps30 = bool(j.get("fps30", false))
	return true


func _save() -> void:
	if _test:
		return
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"quality": level, "auto": auto, "fps30": fps30}))
