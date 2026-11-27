extends Node
## An enemy's Status (H6 Stage 1, 27 Nov 2026; docs/ARCHITECTURE.md part 4, Component): the timed effects on it. Ember
## fire (burn_tick, burn_look), the Frost Bow's ice (frost_tick, frost_look, frozen_frame, frost_clear), a Gloom
## Totem's aura (do_totem, totem_burst) and the slow of thorn spikes with its after-effect (step_thorn_slow). The numbers
## (burn_t, chill_t, freeze_t ...) stay plain fields of the enemy so the tests and the bows keep reading them.
## Used by: enemy.gd (its old private functions forward here). A child named "Status" of the enemy; no class_name.
## Rules: no process callback of its own. The thorn slow lingers only when Deep thorns is learned (linger_s above 0): with
## linger 0 it is exactly H5's "slow while standing on the patch".

var thorn_slow_strength := 0.0            # the slow it still carries from spikes (0 = none)
var thorn_slow_left_s := 0.0              # seconds the slow lingers after it leaves the patch

var e: EnemyNode                           # the enemy (enemy.gd) this part belongs to; set once by bind_enemy


func bind_enemy(enemy: Node3D) -> void:
	e = enemy as EnemyNode


## The spikes' slow this frame. `contact_slow` is what the patch under it gives now (0 off the patch); a fresh contact
## refreshes the strength and the linger; off the patch the last strength stays for linger_s seconds (frame time).
## Returns the slow to use now.
func step_thorn_slow(contact_slow: float, dt: float, linger_s: float) -> float:
	if contact_slow > 0.0:
		thorn_slow_strength = contact_slow
		thorn_slow_left_s = maxf(linger_s, 0.0)
		return contact_slow
	if thorn_slow_left_s > 0.0:
		thorn_slow_left_s = maxf(0.0, thorn_slow_left_s - dt)
		if thorn_slow_left_s > 0.0:
			return thorn_slow_strength
	thorn_slow_strength = 0.0
	return 0.0


## The burn's frame time (clamped, and not called while the game is frozen): one tick of burn_per_s each whole second;
## when it runs out, the part of a second left over hurts its share, so a full burn deals seconds x per_s.
func burn_tick(dt: float) -> void:
	var step := minf(dt, e.burn_t)
	e.burn_t -= step
	e._burn_acc += step
	while e._burn_acc >= 1.0 and not e.dead:
		e._burn_acc -= 1.0
		e._burn_hurt(e.burn_per_s)
	if e.burn_t <= 0.0:
		e.burn_t = 0.0
		if e._burn_acc > 0.001 and not e.dead:
			e._burn_hurt(e.burn_per_s * e._burn_acc)
		e._burn_acc = 0.0
		e._burn_look(false)


## The flames on a burning enemy (Fx.embers, a few rising sparks, scaled by the graphics level).
func burn_look(on: bool) -> void:
	if on and (e._burn_fx == null or not is_instance_valid(e._burn_fx)):
		e._burn_fx = Fx.flames(e, e.radius * 0.55, 10, 0.55, clampf(e.radius * 1.8, 0.3, 0.85))
		e._burn_fx.position = Vector3(0, e.aim_height, 0)
	if e._burn_fx != null and is_instance_valid(e._burn_fx):
		e._burn_fx.emitting = on


## The ice's frame time (clamped by the caller): the freeze runs out, then the chill; the count is lost with the chill.
func frost_tick(dt: float) -> void:
	e.freeze_t = maxf(0.0, e.freeze_t - dt)
	e.chill_t = maxf(0.0, e.chill_t - dt)
	if e.chill_t <= 0.0:
		e.chill_hits = 0
	e._frost_look()


## A frame frozen solid: no step, no push, no clip; a pale icy sheen (and a hit's flash on top).
func frozen_frame(delta: float) -> void:
	e._knock = Vector3.ZERO
	e._hit_flash = maxf(0.0, e._hit_flash - delta)
	Props.set_param(e._body, "flash", clampf(Fx.FROZEN_FLASH + e._hit_flash * 8.0, 0.0, 1.0))
	if e.anim:
		e.anim.speed_scale = 0.0


## Its own tint without the ice's (a stand-in model's balance.json tint, a Gloom Totem's violet).
func base_tint() -> Color:
	if e.info.has("tint"):
		return Color.html(String(e.info["tint"]))
	if e._ai == "totem" and not ResourceLoader.exists("res://assets/enemies/%s/%s.glb" % [e._model_id, e._model_id]):
		return Color(0.88, 0.72, 1.0)
	return Color(1, 1, 1)


## The ice's look, changed only when it changes: chilled (a frosty blue tint and snow sparkles), frozen (paler and icy,
## an ice shell popping on), neither (its own colours; a thawing enemy's shell shatters).
func frost_look() -> void:
	var want := 2 if e.freeze_t > 0.0 else (1 if e.chill_t > 0.0 else 0)
	if want == e._frost_on or e._body == null:
		return
	var was := e._frost_on
	e._frost_on = want
	var tint := e._base_tint()
	Props.set_param(e._body, "tint", tint * (Fx.FROZEN_TINT if want == 2 else (Fx.CHILL_TINT if want == 1 else Color(1, 1, 1))))
	if want > 0 and (e._frost_fx == null or not is_instance_valid(e._frost_fx)):
		e._frost_fx = Fx.frost_motes(e, e.radius * 0.7, 6)
		e._frost_fx.position = Vector3(0, e.aim_height, 0)
	if e._frost_fx != null and is_instance_valid(e._frost_fx):
		e._frost_fx.emitting = want > 0
	if want == 2:
		if e._ice == null or not is_instance_valid(e._ice):
			e._ice = Fx.ice_shell(e, e.radius, float(e.info.get("height", 0.6)))
			e._ice.position.y = e.fly_h if e.flyer else 0.0
		Fx.hit_burst(e.main, e.global_position + Vector3(0, e.aim_height, 0), Vector3.FORWARD, {"hit": "ice", "hit_n": 10,
			"hit_colors": ["#FFFFFF", "#BFEAFF", "#7CC8F0"]})
		if e.anim:
			e.anim.speed_scale = 0.0
	elif was == 2:
		if e._ice != null and is_instance_valid(e._ice):
			e._ice.queue_free()
		e._ice = null
		Fx.shatter(e.main, e.global_position + Vector3(0, e.aim_height, 0), e.radius)
	Props.set_param(e._body, "flash", [0.0, Fx.CHILL_FLASH, Fx.FROZEN_FLASH][want])   # (its frames keep it up, a hit's flash on top)


## Gone: the ice comes off at once (a frozen one shatters).
func frost_clear() -> void:
	e.chill_t = 0.0
	e.freeze_t = 0.0
	e.chill_hits = 0
	e._frost_look()


## The Gloom Totem stands where it grew (the crowd's pushing never moves it) and breathes slowly. A few times a second it
## strengthens every other foe within its reach for a moment (totem_t): faster and tougher. Not bonus runners.
func do_totem(delta: float) -> void:
	e.global_position = e._home
	if e._pulse != null:
		e._pulse.scale = Vector3.ONE * (1.0 + 0.05 * sin(e._t * 2.4))
	e._scan_t -= delta
	if e._scan_t > 0.0:
		return
	e._scan_t = 0.3
	var cfg := e._mcfg("totem")
	var r := float(cfg.get("radius", 4.0))
	var sb := float(cfg.get("speed_buff", 0.25))
	var ar := clampf(float(cfg.get("armor", 0.25)), 0.0, 0.9)
	for f in e._heal.foes_near(r):
		if f == e or f.dead or f.is_in_group("totems") or f.is_in_group("bonus"):
			continue
		var d: Vector3 = f.global_position - e._home
		if d.x * d.x + d.z * d.z < r * r:
			f.totem_t = 0.5
			f.totem_buff = sb
			f.totem_armor = ar


## A Gloom Totem broken: a burst of Gloom, and the foes round it lose its strength at once (another totem near them
## gives its own back at its next look).
func totem_burst() -> void:
	var at := Vector3(e.global_position.x, 0, e.global_position.z)
	Fx.shockwave(e.main, at, 2.6, Color(0.75, 0.4, 1.0))
	Fx.text(e.main, at + Vector3(0, float(e.info["height"]) + 0.4, 0), "Shattered!", Color(0.85, 0.6, 1.0))
	e.main.shake(0.2)
	var r := float(e._mcfg("totem").get("radius", 4.0)) + 0.5
	for f in e._heal.foes_near(r):
		if not f.dead and Vector2(f.global_position.x - at.x, f.global_position.z - at.z).length() < r:
			f.totem_t = 0.0
