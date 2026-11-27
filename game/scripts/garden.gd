extends Node3D
## The garden south of the camp (Phase C, mission 1's gift; H3, 26 Nov 2026: real time). Six plots on a raised bed; the
## garden's level opens 3, 5 or 6 (balance.json garden.plots_by_level). The cat plants a seed on one plot (paid on the
## drop in the garden's window), waters, and picks a ripe plot into the Bag for the cooking pot.
## Used by: the garden's window (ui/windows/garden_window.gd: every rule it shows is asked here), stations.gd (the bed,
## the ring's pulse), main.gd (made in its setup), cooking.gd (flush_pending) and the tests (autotest_garden.gd).
## Uses: Timers (a plot's growth is the job "crop:<plot>", data {"crop", "wet_until"}), Bag (the harvest), Data (the
## crops are content entries, content/crops/<id>/entry.json; balance.json garden: plots, watering, the extra per
## harvest), Save.garden (6 x {"crop": id or ""}), Events (timer_finished, save_loaded), main.cooking (take_note: one
## toast for a crop and the pot done in the same check), Fx, Sfx and Props.
## Rules:
##   - Crops grow in real time, also while the game is closed (the owner's rule: only timers keep running then). A
##     planted plot is ripe when its job is done; a planted plot with no job counts as ripe (nothing is lost). Ripe
##     plants never rot. A plot with an unknown crop id (kept from a save) shows as empty, and planting replaces it.
##   - Watering is free, with no cooldown: every growing plot that is not watered grows water_speed times as fast for the
##     level's water_s_by_level seconds, or until it is ripe if that is sooner. That time is taken off the job at once
##     (Timers.shorten), and the soil shows wet until wet_until. A plot planted later is dry; ripe plots are skipped.
##   - What changes the game happens only on the player's taps: plant (pays), water, pick (the Bag, and the Gloom meter
##     "harvest" once per window visit that picks something). The timer handler only refreshes the look, the rings
##     and toasts; it never adds Gloom (map risk 13).
##   - A handler can miss an event, so the look and the ring also follow Timers' state: a 2 s check (a Timer node, no
##     per-frame code) rebuilds the plants when a plot's stage or wet soil changed, and refreshes the stations when the
##     ring's pulse would change (the water running out).
##   - The plants are one merged mesh, rebuilt only when a plot's look changes.

const SPROUT_SHARE := 0.5                 # below half its time a plot shows the sprout, then the growing plant
const LOOK_CHECK_S := 2.0                 # how often the stages are checked (seconds of real time)

var main
var bed: Node3D                       # the garden_bed prop (stations.gd), once the garden is there
var _plants: MeshInstance3D           # every plant on the bed, merged into one mesh (one draw call)
var _glint: CPUParticles3D
var _look_timer: Timer
var _look_sig := ""                   # the stages and wet soil the plants were last built for
var _pulse := false                   # wants_pulse() when the stations were last refreshed from here
var _visit_picked := false            # this window visit has picked something (the Gloom bump is counted)
var _ripe_new: Array[int] = []        # plots told ripe this frame (one toast for them)
var _flush_queued := false
var _warned_speed := false


func setup(m) -> void:
	main = m
	Events.timer_finished.connect(_on_timer_finished)
	Events.save_loaded.connect(_on_save_loaded)
	_look_timer = Timer.new()
	_look_timer.name = "LookCheck"
	_look_timer.wait_time = LOOK_CHECK_S
	_look_timer.autostart = true
	_look_timer.timeout.connect(_on_look_check)
	add_child(_look_timer)
	# catch up from the state (an event may have been missed): the look comes with the bed (attach), the ring with the
	# stations' first refresh
	_look_sig = _look_signature()
	_pulse = wants_pulse()


# ---------------------------------------------------------------- what the plots are
## The open plots (the garden's level).
func plots() -> int:
	return clampi(Data.garden_plots(), 0, Save.garden.size())


func plot(i: int) -> Dictionary:
	if i < 0 or i >= Save.garden.size():
		return {}
	var p: Variant = Save.garden[i]
	return p if p is Dictionary else {}


## The crop planted on plot i (its content entry), or {} when the plot is empty or its crop is unknown.
func crop_of(i: int) -> Dictionary:
	return Data.crop(String(plot(i).get("crop", "")))


## "locked" (not open at this level), "empty", "sprout" (under half its time), "growing" or "ripe".
func stage(i: int) -> String:
	if i < 0 or i >= plots():
		return "locked"
	if crop_of(i).is_empty():
		return "empty"
	var id := _job(i)
	if not Timers.has(id) or Timers.done(id):
		return "ripe"
	return "sprout" if Timers.progress(id) < SPROUT_SHARE else "growing"


func is_ripe(i: int) -> bool:
	return stage(i) == "ripe"


## A growing plot that was watered and is still in its watered time.
func is_wet(i: int) -> bool:
	if not _growing(i):
		return false
	return Timers.now() < float(Timers.job_data(_job(i)).get("wet_until", 0.0))


## Seconds until plot i is ripe (0 when it is not growing).
func left_s(i: int) -> float:
	return Timers.left(_job(i)) if _growing(i) else 0.0


## The seeds the cat can plant: every crop entry (content index order) whose unlock rule passes and that is not hidden.
func seeds() -> Array:
	var out: Array = []
	for e: Variant in Data.catalog("crops"):
		if not e is Dictionary:
			continue
		var d: Dictionary = e
		var rule: Variant = d.get("unlock", {})
		if bool(d.get("hidden", false)) or not (rule is Dictionary and Data.unlocked(rule)):
			continue
		out.append(d)
	return out


# ---------------------------------------------------------------- the player's actions
## Plants crop_id on plot i and pays its seed. "" when it worked; else why not: "A wave is on", "Locked plot",
## "Plot in use", "Unknown seed", "Not unlocked yet", "Not enough leaves" (or the currency that is short).
func plant(crop_id: String, i: int) -> String:
	if _wave_on():
		return "A wave is on"
	if i < 0 or i >= plots():
		return "Locked plot"
	if not crop_of(i).is_empty():
		return "Plot in use"
	if Data.crop(crop_id).is_empty():
		return "Unknown seed"
	var c := _seed(crop_id)
	if c.is_empty():
		return "Not unlocked yet"
	var price: Dictionary = c["price"] if c.get("price") is Dictionary else {}
	if not Data.can_afford(price):
		return _short_of(price)
	if not Timers.start(_job(i), float(c.get("grow_s", 0.0)), {"crop": crop_id}):
		return "Can't plant now"
	Data.pay(price)
	Save.garden[i] = {"crop": crop_id}
	refresh_look()
	Fx.dust(main, plot_pos(i), 6, 0.7)
	pop()
	Sfx.play("pop", -6.0)
	Save.save_game()
	main.on_purchase()
	_pulse = wants_pulse()
	return ""


## Some growing plot is dry and watering would help it now.
func can_water() -> bool:
	if not _water_ok():
		return false
	for i in plots():
		if _waterable(i):
			return true
	return false


## Waters every growing plot that is not watered (see the rules at the top). Returns how many plots got water.
func water() -> int:
	if _wave_on() or not _water_ok():
		return 0
	var speed := _water_speed()
	var water_s := _water_s()
	var t := Timers.now()
	var n := 0
	for i in plots():
		if not _waterable(i):
			continue
		var id := _job(i)
		var saved := minf(Timers.left(id) * (1.0 - 1.0 / speed), water_s * (speed - 1.0))
		if saved <= 0.0:
			continue
		Timers.shorten(id, saved)
		Timers.set_job_data(id, "wet_until", t + saved / (speed - 1.0))
		n += 1
	if n > 0:
		refresh_look()
		Fx.puff(main, main.world.station_pos("garden") + Vector3(0, 0.6, 0), Color(0.55, 0.8, 1.0), 12)
		Sfx.play("water", -6.0)
		Save.save_game()
		main.on_purchase()
		_pulse = wants_pulse()
	return n


## Picks ripe plot i into the Bag (its yield plus the level's extra). "" when it worked; "Bag full" (the plot stays
## ripe), "Not ripe" or "A wave is on".
func pick(i: int) -> String:
	if _wave_on():
		return "A wave is on"
	if not is_ripe(i):
		return "Not ripe"
	var c := crop_of(i)
	var gives := String(c.get("gives", ""))
	var n := int(c.get("yield", 0)) + int(Data.pick("garden", "extra_by_level", Data.garden_level()))
	if Bag.room_for(gives) < n:
		return "Bag full"
	Bag.add(gives, n)
	Save.garden[i] = {"crop": ""}
	Timers.remove(_job(i))
	refresh_look()
	Fx.text(main, plot_pos(i) + Vector3(0, 0.8, 0), "+%d %s" % [n, Data.item_name(gives, n)], Color(0.75, 1.0, 0.5))
	Fx.flower_ring(main, main.world.station_pos("garden"), 1.0)
	Sfx.play("pluck", -4.0)
	if not _visit_picked:                       # the Gloom meter: once per window visit that picks something (Q11)
		_visit_picked = true
		if main.get("raids") != null:
			main.raids.add_gloom("harvest")
	Save.save_game()
	main.on_purchase()
	_pulse = wants_pulse()
	if main.hud != null:
		main.hud.toast(Data.food_receipt({gives: n}))
		if not Save.flag("told_cook"):
			Save.set_flag("told_cook")
			main.hud.tip("Cook what you pick at the pot by the campfire: potions for the cat and the mount.",
				main.stations.rings.get("pot") if main.get("stations") != null else null)
	return ""


## The garden's window opened for a new visit (its opened() hook; card.gd tells a visit from a rebuild).
func window_opened() -> void:
	_visit_picked = false


## The ring pulses: a ripe plot, a growing plot that watering would help, or an empty open plot and a seed the cat can
## pay for.
func wants_pulse() -> bool:
	var empty := false
	var water_ok := _water_ok()
	for i in plots():
		match stage(i):
			"ripe":
				return true
			"empty":
				empty = true
			_:
				if water_ok and not is_wet(i):
					return true
	if empty:
		for e: Variant in seeds():
			var price: Variant = (e as Dictionary).get("price", {})
			if price is Dictionary and Data.can_afford(price):
				return true
	return false


# ---------------------------------------------------------------- Timers' news and the 2 s check
func _on_timer_finished(job_id: String) -> void:
	var i := _plot_of(job_id)
	if i < 0:
		return
	if not _ripe_new.has(i):
		_ripe_new.append(i)
	if not _flush_queued:                       # every job told in this frame gives one toast and one refresh
		_flush_queued = true
		_flush_ripe.call_deferred()


func _flush_ripe() -> void:
	_flush_queued = false
	var names := PackedStringArray()
	for i in _ripe_new:
		if stage(i) == "ripe":
			var nm := String(crop_of(i).get("name", ""))
			if nm != "" and not names.has(nm):
				names.append(nm)
	_ripe_new.clear()
	refresh_look()
	if main != null and main.get("stations") != null:
		main.stations.refresh()                 # the ring pulses only after a stations refresh (stations.gd)
	_pulse = wants_pulse()
	var lines := PackedStringArray()
	if not names.is_empty():
		lines.append("Ripe in the garden: %s" % " and ".join(names))
	if main != null and main.get("cooking") != null:
		var pot: String = main.cooking.take_note()    # the pot's line, if it finished in the same check
		if pot != "":
			lines.append(pot)
	if not lines.is_empty() and main != null and main.hud != null:
		main.hud.toast(" · ".join(lines))


## A toast for plots that ripened this frame is queued (the pot's "ready" line waits for it).
func flush_pending() -> bool:
	return _flush_queued


## A save was loaded (Save.garden is new): the plants follow it. The 2 s check refreshes the ring if it must change.
func _on_save_loaded() -> void:
	refresh_look()


func _on_look_check() -> void:
	if _look_signature() != _look_sig:
		refresh_look()
	var p := wants_pulse()
	if p != _pulse:
		_pulse = p
		if main != null and main.get("stations") != null:
			main.stations.refresh()


func _look_signature() -> String:
	var s := ""
	for i in Save.garden.size():
		s += "%s:%s:%s;" % [stage(i), String(plot(i).get("crop", "")), "w" if is_wet(i) else ""]
	return s


# ---------------------------------------------------------------- inside
static func _job(i: int) -> String:
	return "crop:%d" % i


## The plot of a "crop:<i>" job id, or -1.
static func _plot_of(job_id: String) -> int:
	if not job_id.begins_with("crop:"):
		return -1
	var key := job_id.get_slice(":", 1)
	return int(key) if key.is_valid_int() else -1


func _growing(i: int) -> bool:
	var st := stage(i)
	return st == "sprout" or st == "growing"


func _waterable(i: int) -> bool:
	return _growing(i) and not is_wet(i)


## The seed's entry when the cat may plant it now ({} when it is unknown, hidden or not unlocked).
func _seed(crop_id: String) -> Dictionary:
	for e: Variant in seeds():
		if String((e as Dictionary).get("id", "")) == crop_id:
			return e
	return {}


func _short_of(price: Dictionary) -> String:
	for k: String in Data.CURRENCIES:
		if Data.have(k) < int(price.get(k, 0)):
			return "Not enough %s" % k
	return "Not enough leaves"


func _wave_on() -> bool:
	if main == null or main.get("fight") == null:
		return false
	return bool(main.fight.active) and bool(main.fight.in_wave)


func _water_speed() -> float:
	return float((Data.b.get("garden", {}) as Dictionary).get("water_speed", 0.0))


func _water_s() -> float:
	return Data.pick("garden", "water_s_by_level", Data.garden_level())


## Watering can act: a speed above 1 (else a warning, once) and some watered time at this level.
func _water_ok() -> bool:
	if _water_speed() <= 1.0:
		if not _warned_speed:
			_warned_speed = true
			push_warning("garden: balance.json garden.water_speed must be above 1, so watering does nothing")
		return false
	return _water_s() > 0.0


# ---------------------------------------------------------------- the look
## Where plot i sits on the bed, in the bed's own space: its marker_plot_N, else a 3 x 2 grid 0.6 m apart (plots 1-3
## are the row nearest the ring).
func _plot_xf(i: int) -> Transform3D:
	if bed != null and is_instance_valid(bed):
		var mk := Props.find_part(bed, "marker_plot_%d" % (i + 1))
		if mk:
			return bed.global_transform.affine_inverse() * mk.global_transform
	return Transform3D(Basis.IDENTITY, Vector3(-0.6 + (i % 3) * 0.6, 0.3, 0.3 if i < 3 else -0.3))


## Plot i in the world (a puff of dust when something is planted, the harvest's floating text).
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


## Rebuilds the plants from stage() and is_wet(): weeds on locked plots, then a sprout, the growing plant or the ripe
## one per crop (the entry's model: <model>_growing, <model>_ripe), and dark wet soil under every watered plot.
func refresh_look() -> void:
	_look_sig = _look_signature()
	if _plants == null or not is_instance_valid(_plants):
		return
	var list: Array = []
	var any_ripe := false
	for i in Save.garden.size():
		var xf := _plot_xf(i)
		var st := stage(i)
		if st == "locked":
			list.append([Props.mesh("plot_weeds"), xf])
			continue
		if st == "empty":
			continue
		var c := crop_of(i)
		var model := String(c.get("model", c.get("id", "")))
		if is_wet(i):
			list.append([Props.mesh("soil_wet"), xf])
		match st:
			"ripe":
				list.append([Props.mesh(model + "_ripe"), xf])
				any_ripe = true
			"sprout":
				list.append([Props.mesh("plant_sprout"), xf])
			_:
				list.append([Props.mesh(model + "_growing"), xf])
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
