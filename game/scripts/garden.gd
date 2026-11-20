extends Node3D
## The garden south of the camp (Phase C, mission 1's gift). Six plots on a raised bed; the garden's level opens 3, 5
## or 6. The cat plants seeds (Bramble's seed packets: the Plant row pays for them), waters, and picks what is ripe
## into the pantry (Save.pantry) for the cooking pot.
## Growth is never real time: every wave the camp holds (main.on_wave_held), each planted plot grows one step, two
## while it is watered. Nothing grows while the game is closed or while the cat waits in the camp, and ripe plants
## never rot. The save holds plain numbers only (Save.garden: {"crop", "grow", "wet"} per plot).
## No per-frame code: the plants are one merged mesh, rebuilt only when a plot changes.

var main
var bed: Node3D                       # the garden_bed prop (stations.gd), once the garden is there
var _plants: MeshInstance3D           # every plant on the bed, merged into one mesh (one draw call)
var _glint: CPUParticles3D


func setup(m) -> void:
	main = m


func plots() -> int:
	return clampi(Data.garden_plots(), 0, Save.garden.size())


func plot(i: int) -> Dictionary:
	return Save.garden[i]


func _crop_of(i: int) -> Dictionary:
	return Data.crop(String(plot(i).get("crop", "")))


func is_ripe(i: int) -> bool:
	var c := _crop_of(i)
	return not c.is_empty() and int(plot(i)["grow"]) >= int(c["grow"])


func _growing(i: int) -> bool:
	return not _crop_of(i).is_empty() and not is_ripe(i)


func first_empty() -> int:
	for i in plots():
		if _crop_of(i).is_empty():
			return i
	return -1


## How many open plots are ripe, empty, growing, and growing but dry.
func counts() -> Dictionary:
	var out := {"ripe": 0, "empty": 0, "growing": 0, "dry": 0}
	for i in plots():
		if _crop_of(i).is_empty():
			out["empty"] += 1
		elif is_ripe(i):
			out["ripe"] += 1
		else:
			out["growing"] += 1
			if int(plot(i)["wet"]) <= 0:
				out["dry"] += 1
	return out


func wet_waves() -> int:
	return int(Data.pick("garden", "wet_waves_by_level", Data.garden_level()))


## The plots as the card says them: "Sunberries 2/4 (watered) · Fernmint 1/5 · empty".
func summary() -> String:
	var bits: Array = []
	for i in plots():
		var c := _crop_of(i)
		if c.is_empty():
			bits.append("empty")
		elif is_ripe(i):
			bits.append("%s ripe" % String(c["name"]))
		else:
			bits.append("%s %d/%d%s" % [String(c["name"]), int(plot(i)["grow"]), int(c["grow"]), " (watered)" if int(plot(i)["wet"]) > 0 else ""])
	return " · ".join(bits)


## What "Pick" would put in the pantry now: {"add": {ingredient: n}, "full": [ingredients that do not fit]}.
## A plot whose harvest does not fit under the pantry cap stays ripe (nothing is lost).
func pick_preview() -> Dictionary:
	var add := {}
	var full: Array = []
	var cap := int(Data.b["cooking"]["pantry_cap"])
	var extra := int(Data.pick("garden", "extra_by_level", Data.garden_level()))
	for i in plots():
		if not is_ripe(i):
			continue
		var c := _crop_of(i)
		var g := String(c["gives"])
		var n := int(c["yield"]) + extra
		if int(Save.pantry.get(g, 0)) + int(add.get(g, 0)) + n <= cap:
			add[g] = int(add.get(g, 0)) + n
		elif not full.has(g):
			full.append(g)
	return {"add": add, "full": full}


## Plants a crop in the first empty open plot. The seed is paid by the caller (stations._garden_plant).
func plant(crop_id: String) -> bool:
	var i := first_empty()
	if i < 0 or Data.crop(crop_id).is_empty():
		return false
	Save.garden[i] = {"crop": crop_id, "grow": 0, "wet": 0}
	refresh_look()
	return true


## Every planted, unripe plot is watered for wet_waves() waves. Returns how many plots got water.
func water() -> int:
	var n := 0
	var w := wet_waves()
	for i in plots():
		if _growing(i) and int(plot(i)["wet"]) < w:
			Save.garden[i]["wet"] = w
			n += 1
	if n > 0:
		refresh_look()
	return n


## Picks every ripe plot whose harvest fits in the pantry. Returns what went in: {ingredient: n}.
func pick() -> Dictionary:
	var add := {}
	var cap := int(Data.b["cooking"]["pantry_cap"])
	var extra := int(Data.pick("garden", "extra_by_level", Data.garden_level()))
	for i in plots():
		if not is_ripe(i):
			continue
		var c := _crop_of(i)
		var g := String(c["gives"])
		var n := int(c["yield"]) + extra
		if int(Save.pantry.get(g, 0)) + n > cap:
			continue
		Save.pantry[g] = int(Save.pantry.get(g, 0)) + n
		add[g] = int(add.get(g, 0)) + n
		Save.garden[i] = {"crop": "", "grow": 0, "wet": 0}
	if not add.is_empty():
		refresh_look()
	return add


## A wave was held: every planted plot that is not ripe grows a step (two while watered). Returns how many turned
## ripe, with one toast for them.
func grow_wave() -> int:
	var turned := 0
	var names: Array = []
	var changed := false
	var dry := int(Data.b["garden"]["grow_dry"])
	var wet := int(Data.b["garden"]["grow_wet"])
	for i in plots():
		if not _growing(i):
			continue
		var p: Dictionary = Save.garden[i]
		var add := wet if int(p["wet"]) > 0 else dry
		if int(p["wet"]) > 0:
			p["wet"] = int(p["wet"]) - 1
		p["grow"] = mini(int(p["grow"]) + add, int(_crop_of(i)["grow"]))
		changed = true
		if is_ripe(i):
			turned += 1
			var nm := String(_crop_of(i)["name"])
			if not names.has(nm):
				names.append(nm)
	if changed:
		refresh_look()
	if not names.is_empty() and main != null and main.hud != null:
		main.hud.toast("%s %s ripe!" % [" and ".join(names), "is" if names.size() == 1 and names[0] == "Fernmint" else "are"])
	return turned


# ---------------------------------------------------------------- the look
## Where plot i sits on the bed, in the bed's own space: its marker_plot_N, else a 3 x 2 grid 0.6 m apart (plots 1-3
## are the row nearest the ring).
func _plot_xf(i: int) -> Transform3D:
	if bed != null and is_instance_valid(bed):
		var mk := Props.find_part(bed, "marker_plot_%d" % (i + 1))
		if mk:
			return bed.global_transform.affine_inverse() * mk.global_transform
	return Transform3D(Basis.IDENTITY, Vector3(-0.6 + (i % 3) * 0.6, 0.3, 0.3 if i < 3 else -0.3))


## Plot i in the world (for a puff of dust when something is planted).
func plot_pos(i: int) -> Vector3:
	if bed != null and is_instance_valid(bed):
		return bed.global_transform * _plot_xf(i).origin
	return main.world.station_pos("garden") + Vector3(0, 0.3, 0)


## The bed prop (stations.refresh hands it over, or null when there is none). The plants are one mesh on it.
func attach(b: Node3D) -> void:
	if b == bed and _plants != null and is_instance_valid(_plants):
		return
	bed = b
	_plants = null
	_glint = null
	if bed == null:
		return
	_plants = MeshInstance3D.new()
	_plants.name = "plants"
	_plants.material_override = Props.vc()
	bed.add_child(_plants)
	_glint = _make_glint()
	bed.add_child(_glint)
	refresh_look()


## Rebuilds the plants: weeds on locked plots, then a sprout, the growing plant and the ripe one per crop, and dark wet
## soil under every watered plot. Only when a plot changes (a card action, a wave held, a new bed).
func refresh_look() -> void:
	if _plants == null or not is_instance_valid(_plants):
		return
	var list: Array = []
	var any_ripe := false
	for i in Save.garden.size():
		var xf := _plot_xf(i)
		if i >= plots():
			list.append([Props.mesh("plot_weeds"), xf])
			continue
		var p := plot(i)
		var c := _crop_of(i)
		if c.is_empty():
			continue
		if int(p["wet"]) > 0:
			list.append([Props.mesh("soil_wet"), xf])
		var id := String(c["id"])
		if is_ripe(i):
			list.append([Props.mesh(id + "_ripe"), xf])
			any_ripe = true
		elif int(p["grow"]) * 2 < int(c["grow"]):
			list.append([Props.mesh("plant_sprout"), xf])
		else:
			list.append([Props.mesh(id + "_growing"), xf])
	_plants.mesh = Props.merge(list)
	if _glint != null and is_instance_valid(_glint):
		_glint.emitting = any_ripe


## A new sprout pops in.
func pop() -> void:
	if _plants != null and is_instance_valid(_plants):
		Fx.boing(_plants, 0.25)


## Golden glints over the bed while something is ripe.
func _make_glint() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.06, 0.06)
	p.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	p.material_override = m
	p.amount = Quality.particles(6)
	p.lifetime = 1.4
	p.position = Vector3(0, 0.55, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.9, 0.15, 0.5)
	p.direction = Vector3.UP
	p.spread = 20.0
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.3
	p.gravity = Vector3.ZERO
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	g.colors = PackedColorArray([Color(1.0, 0.95, 0.5, 0.0), Color(1.0, 0.9, 0.45, 1.0) * 1.6, Color(1.0, 0.8, 0.3, 0.0)])
	p.color_ramp = g
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.emitting = false
	return p
