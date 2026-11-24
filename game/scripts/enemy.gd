extends Node3D
## One enemy. It walks its patch's trail from the woods to the camp gate and fights whatever is in the way.
## The model is res://assets/enemies/<id>/<id>.glb with its <id>.json (clips, events, speeds, spring chains); until
## that exists a faceted placeholder stands in. Behaviour by kind:
##   thornling, chief  chase the cat when it is near, otherwise go for the gate
##   brute             goes for the gate and anything blocking it; hits the cat only when it is right there
##   raccoon           grabs golden leaves lying on the field and runs back to the woods with them
##   boar              paws the ground, then charges in a straight line: hurts the cat, smashes fences and the gate;
##                     a charge that misses the cat ends in a "Bonk!" daze: a moment to hit it for extra damage
##   bear (boss)       swipes, slams the ground (a ring that hurts the cat), roars to call Thornlings, and its
##                     Gloom Dash: wind and leaves swirl round it, a line warns where it goes, then it rushes the cat
## Every attack flashes a swipe and throws up leaves and dust; walkers lean into their stride and kick up dust.
## Specials: Thornlings pounce, Brutes burst spores that slow the cat, Raccoons vanish in smoke and sprint away.
## The later woods (Moonmoth Hollow, Crystal Ridge, the Owl Witch's Spire) add:
##   moth              flies: straight over fences and buildings at the campfire, and dives at the cat
##   frog              heals wounded enemies near it, and lobs Gloom bolts at the cat from a distance
##   beetle            its shield blocks most of an arrow from the front (hit it from the side, from hiding, or while
##                     it attacks); bashes forward with the shield
##   snail             slow and tough, leaves slime that slows the cat, and bursts crystal spikes round itself
##   owl (boss)        blinks next to the cat, throws homing orbs, curses the ground under the cat (a hex circle that
##                     bursts a moment later), and calls Gloom Moths
## The missions add:
##   stump             a slow siege brute: double damage to buildings, towers and barricades
##   pitcher           spits thorns at the cat when it comes near; in the camp it stops siege_range m from a tower,
##                     a building or the campfire and spits at that from there (the Frog Shaman does the same with
##                     its Gloom bolts): out of reach of a cat standing at the fire
##   mole              digs under a barricade in its way and pops up behind it
##   puffball          waddles up to a building (or the cat) and bursts, hurting everything round it
##   crow              drums: the enemies near it get faster and hit harder for a while
##   stag (boss)       charges (breaking barricades), stamps the ground, and roars to call Stump Golems
## Phase F adds two that never attack:
##   golden_grub       a bonus runner (group "bonus"): scurries round the field from one road's woods toward another's,
##                     out of the firelight and shy of the cat, and gets away after mission.golden_grub.life_s
##   gloom_totem       a Gloom crystal on a road (group "totems"): it never moves; every other foe within
##                     mission.totem.radius is faster and tougher (and tinted violet) until the cat breaks it
## Phase G1b, squads (fight.gd sends a mission's enemies in squads): a member (the metas "squad_leader" and
## "squad_offset") keeps its spot beside or behind its leader, at the leader's pace, until it is near the camp, its
## leader is gone, or the cat comes for it; then it acts on its own as before (_keep_formation, _squad_steer). Support
## members keep behind; a Frog Shaman still heals and a Crow Drummer still drums on the march. The leader walks its
## trail as before. Bosses and raid enemies have no squad.

const BoltScript := preload("res://scripts/bolt.gd")
const SlimeScript := preload("res://scripts/slime.gd")
const TOTEM_GLOOM := 0.32                     # the faint violet a foe near a Gloom Totem shows (the shader's gloom)
static var _ring_mat: StandardMaterial3D      # a Gloom Totem's reach ring on the ground (one material for all)

var main
var id := "thornling"
var info: Dictionary
var meta: Dictionary = {}
var patch := 0
var mult := 1.0
var hp := 10.0
var max_hp := 10.0
var speed := 1.0
var damage := 1
var gate_damage := 1
var radius := 0.3
var aim_height := 0.3
var dead := false
var anchored := false
var boss := false
var carried := 0
var state := "walk"
var s := 0.0                                  # how far along the trail
var model: Node3D
var anim: AnimationPlayer
var _body: Node3D                             # what squashes and flashes
var _t := 0.0
var _think_t := 0.0
var _act_t := 0.0
var _act_len := 0.0
var _act_event := 0.0
var _act_done := false
var _act_target = null
var _cd := 0.0                                # attack cooldown
var _cd2 := 0.0                               # boar charge / bear slam cooldown
var _cd3 := 0.0                               # bear roar cooldown
var _cd4 := 0.0                               # special: pounce, spores, dash
var _boost_t := 0.0                           # raccoon smoke sprint
var _step_d := 0.0                            # distance walked since the last dust puff
var _last_pos := Vector3.ZERO
var _from := Vector3.ZERO                     # pounce start
var _to := Vector3.ZERO                       # pounce landing
var _power := false                           # the next impact is a special's (stronger)
var _knock := Vector3.ZERO
var _charge_dir := Vector3.ZERO
var _goal := Vector3.ZERO
var _clip := ""
var _slow := 0.0
var _hit_flash := 0.0
var _color := Color(0.4, 0.7, 0.3)
var _model_id := "thornling"
var _scale := 1.0
var flyer := false                            # moths: fly over everything at fly_h
var fly_h := 0.0
var _arc := 0.65                              # pounce: hop height (negative: a flier's dive)
var _dur := 0.45                              # pounce: seconds
var _cd5 := 0.0                               # owl: blink
var _slime_t := 0.0
var _block_t := 0.0                           # beetle: "Block!" shown recently
var _hex_at := Vector3.ZERO
var _blink_to := Vector3.ZERO
var buff_t := 0.0                             # a Crow Drummer's beat: faster and stronger while > 0
var buff := 0.0
var _dig_to := Vector3.ZERO
# Phase E: the Burrows (monsters there sleep in packs, hunt the cat, are dazed by standing stones and edges)
var awake := true                             # asleep in a den until the cat comes near, crosses the wake line or hits one
var gloomtouched := false
var title := ""                               # the boss bar's name when set ("Gloomtouched Thornling Chief")
var summoned := false                         # called up by a boss (the minion cap counts these)
var _vuln_t := 0.0                            # dazed by a pillar, a wall or a missed charge: takes _vuln_k x damage while > 0
var _zz_t := 0.0
var _emerge_at := Vector3.ZERO
var _steer_t := 0.0                           # a Burrow's path: the way round its bends (area.steer), cached briefly
var _steer_on := false
var _steer_to := Vector3.ZERO
var mods := {}                                # a Burrow boss's own tuning from its map's "end" (missions keep the kind's own)
var enraged := false                          # a Burrow boss at low health (mods.enrage_at): faster, a second slam ring
var _vuln_k := 1.5                            # the damage taken while _vuln_t > 0 (a pillar's daze, a boar's missed charge)
# G4: a mount's Bellow (mount.gd): it takes bellow_k more damage from every hit and burn while bellow_t > 0
var bellow_t := 0.0
var bellow_k := 0.0
# Phase F: missions (boar daze, ranged sieges, the Golden Grub, Gloom Totems)
var _ai := ""                                 # how it thinks: info "ai", else its id
var totem_t := 0.0                            # near a Gloom Totem (it refreshes this): faster and tougher while > 0
var totem_buff := 0.0                         # ... how much faster (mission.totem.speed_buff)
var totem_armor := 0.0                        # ... the share of each hit it shrugs off (mission.totem.armor)
var _totem_on := false                        # ... the violet tint is showing
var life_t := 0.0                             # a Golden Grub: seconds left on the field, then it runs for the woods
var _run_a := 0.0                             # ... the angle of the road whose woods it runs for
var _run_r := 8.0                             # ... how far from the fire it runs round
var _run_dir := 1.0                           # ... which way round (+1 / -1)
var _run_in := false                          # ... it has come out of the woods
var _run_out := false                         # ... it is past the run round and heading into the woods
var _shy_r := 3.0                             # ... it veers away from a cat this near (mission.golden_grub.shy_r)
var _home := Vector3.ZERO                     # a Gloom Totem: where it grew (nothing moves it)
var _scan_t := 0.0                            # ... next look round for foes to strengthen
var _pulse: Node3D                            # ... its crystals, breathing slowly
var _sq_on := false                           # Phase G1b: keeping its squad's formation now (_think decides, _squad_steer steers)
var _sq_prev := Vector3.INF                   # ... where its leader was the frame before (the leader's pace)
var last_dealt := 0.0                         # G3: the damage the last hit() really did (after shields, dazes, totems)
var burn_t := 0.0                             # G3, the Ember Bow: seconds it still burns (ignite)
var burn_per_s := 0.0                         # ... the damage it takes each second while burning
var burn_ticks := 0                           # ... burn damage dealt so far: how many times (for the tests)
var burn_dealt := 0.0                         # ... and how much in all
var _burn_acc := 0.0                          # ... seconds burnt since the last tick
var _burn_fx: CPUParticles3D                  # ... the flames on it (Fx.embers), made the first time it burns
# 22 Nov 2026, the Frost Bow's ice (chill): slowed by each ice hit; the hits_to_freeze-th hit while slowed freezes it
var chill_t := 0.0                            # seconds it stays slowed (each ice hit starts them again)
var chill_slow := 0.0                         # ... how much slower it moves and attacks meanwhile (0.5 = at half speed)
var chill_hits := 0                           # ... ice hits in a row while slowed (the count; 0 again when it freezes)
var freeze_t := 0.0                           # seconds it stays frozen solid: no moving, no attacking
var freezes := 0                              # ... how many times it froze (for the tests)
var _frost_on := 0                            # the frost look showing: 0 none, 1 chilled, 2 frozen
var _frost_fx: CPUParticles3D                 # ... snow sparkles round it (Fx.frost_motes)
var _ice: MeshInstance3D                      # ... its ice shell while frozen (Fx.ice_shell)


func setup(kind: String, patch_index: int, strength: float) -> void:
	id = kind
	info = Data.enemy(kind)
	patch = patch_index
	mult = strength
	_model_id = String(info.get("model", kind))
	_scale = float(info.get("scale", 1.0))
	boss = bool(info.get("boss", false))
	max_hp = float(info["hp"]) * mult
	hp = max_hp
	speed = float(info["speed"]) * randf_range(0.92, 1.08)
	damage = maxi(1, int(round(float(info["damage"]) * (1.0 + (mult - 1.0) * 0.5))))
	gate_damage = int(round(float(info["gate_damage"]) * mult))
	radius = float(info["radius"])
	aim_height = float(info["height"]) * 0.45
	_color = Color.html(String(info["color"]))
	_cd2 = randf_range(1.0, 2.5)
	_cd3 = float(info.get("roar_every", info.get("summon_every", 10.0))) * 0.6
	_cd4 = randf_range(2.0, 4.0)
	_cd5 = float(info.get("blink_every", 9.0)) * 0.5
	flyer = bool(info.get("flyer", false))
	fly_h = float(info.get("fly_height", 0.0))
	anchored = bool(info.get("anchored", false))
	_ai = String(info.get("ai", kind))
	add_to_group("enemies")
	add_to_group("foes")
	if bool(info.get("bonus", false)):
		add_to_group("bonus")                       # Phase F: a bonus runner never holds a wave up (fight.gd)
	_load_model()
	if info.has("tint"):
		Props.set_param(_body, "tint", Color.html(String(info["tint"])))   # a stand-in model, tinted (Phase E)
	if flyer:
		aim_height += fly_h
	scale = Vector3.ONE * 0.05
	create_tween().tween_property(self, "scale", Vector3.ONE, 1.0 if _ai == "totem" else 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if patch >= 0 and main.world.trails.size() > patch:
		s = main.world.trail_progress(patch, global_position)
	if _ai == "golden_grub":
		_grub_setup()
	elif _ai == "totem":
		_totem_setup()


## Phase E: this monster is in a Burrow (the Burrow's map owns where it stands).
func _in_area() -> bool:
	return main.area != null and main.area.owns(global_position)


## Asleep in a den: it stands still playing Idle, with a "z" now and then.
func sleep() -> void:
	awake = false
	state = "sleep"
	_play("Idle")


func wake() -> void:
	if awake or dead:
		return
	awake = true
	state = "walk"
	_think_t = randf_range(0.0, 0.3)
	Fx.text(main, global_position + Vector3(0, float(info["height"]) + 0.3, 0), "!", Color(1.0, 0.85, 0.3))
	Fx.boing(_body, 0.2)
	if main.area != null and main.area.has_method("wake_pack"):
		main.area.wake_pack(self)                       # its whole fight wakes with it (a boss: with its bar)


## A Gloomtouched elite (or boss): tougher, a little bigger and faster, a violet tint and a wind aura.
func make_gloomtouched(as_boss := false) -> void:
	var g: Dictionary = Data.burrow_cfg()["gloomtouched"]
	gloomtouched = true
	if not as_boss:
		max_hp *= float(g["hp"])
		hp = max_hp
	damage += int(g["damage_add"])
	speed *= float(g["speed"])
	_scale *= float(g["scale"])
	if model != null:
		model.scale = Vector3.ONE * _scale
	elif _body != null:
		_body.scale = Vector3.ONE * _scale
	radius *= float(g["scale"])
	Props.set_param(_body, "gloom", float(g["gloom"]))
	Fx.wind_aura(self, 1.2, 1.0)
	title = "Gloomtouched " + String(info["name"])


## A Grubling (or the boss's adds) bursting out of the floor: a warning ring first, then it pops up; standing on the
## spot hurts.
func start_emerge(at: Vector3) -> void:
	state = "emerge"
	_act_t = 0.0
	_act_done = false
	_emerge_at = Vector3(at.x, 0, at.z)
	_body.visible = false
	Fx.telegraph_ring(main, _emerge_at, 0.8, float(info.get("emerge_warn", 0.8)), Color(0.78, 0.5, 1.0, 0.4))
	Fx.dust(main, _emerge_at, 4, 0.8)


func _do_emerge(delta: float) -> void:
	_act_t += delta
	if not _act_done and _act_t >= float(info.get("emerge_warn", 0.8)):
		_act_done = true
		_body.visible = true
		_play(_clip_or(["Emerge", "Idle"]), 0.05)
		Fx.dust(main, global_position, 10, 1.0)
		Fx.boing(_body, 0.3)
		var p = main.player
		if p.hp > 0 and Vector2(p.global_position.x - _emerge_at.x, p.global_position.z - _emerge_at.z).length() < float(info.get("emerge_r", 0.6)):
			p.hurt(_emerge_at, int(info.get("emerge_damage", 1)))
	if _act_t >= float(info.get("emerge_warn", 0.8)) + 0.35:
		state = "walk"
		_think_t = 0.0


## A charge stopped by a standing stone or the edge of a Burrow: "Bonk!", dazed, and it takes extra damage for a moment
## (`hurt` x, or the Burrows' vuln_mult when it is not given).
func _daze_long(secs: float, hurt := -1.0, shake := 0.2) -> void:
	state = "daze"
	_act_t = 0.8 - secs
	_vuln_t = secs + 0.3
	_vuln_k = hurt if hurt > 0.0 else float(Data.burrow_cfg()["vuln_mult"])
	_cd2 = maxf(_cd2, float(info.get("charge_every", 4.0)))
	_play("Hit" if anim and anim.has_animation("Hit") else "Idle", 0.05)
	Fx.text(main, global_position + Vector3(0, float(info["height"]) + 0.4, 0), "Bonk!", Color(1.0, 0.9, 0.4))
	for k in 3:
		Fx.sparkle(main, global_position + Vector3(cos(k * 2.1) * 0.4, float(info["height"]) + 0.15, sin(k * 2.1) * 0.4))
	if shake > 0.0:
		main.shake(shake)


## Phase F: a boar's charge that ends without hitting the cat (it missed, or a barricade, a building, a tower or the
## Moss Warden took it) leaves it dazed for miss_daze s, taking daze_hurt x damage: the Gloomwood's "Bonk!". The first
## time in a save a tip says so.
func _miss_daze() -> void:
	_daze_long(float(info.get("miss_daze", 1.0)), float(info.get("daze_hurt", 1.5)), 0.0)
	if not Save.flag("told_boar_daze"):
		Save.set_flag("told_boar_daze")
		main.hud.tip("A boar that misses its charge is dazed. Hit it now: it takes extra damage!", null)


# ---------------------------------------------------------------- model
func _load_model() -> void:
	var base := "res://assets/enemies/%s/%s" % [_model_id, _model_id]
	if bool(info.get("totem", false)) and not ResourceLoader.exists(base + ".glb"):
		_totem_look()
	elif ResourceLoader.exists(base + ".glb"):
		model = (load(base + ".glb") as PackedScene).instantiate()
		if FileAccess.file_exists(base + ".json"):
			var j = JSON.parse_string(FileAccess.get_file_as_string(base + ".json"))
			if typeof(j) == TYPE_DICTIONARY:
				meta = j
		Props.apply_vc(model)
		model.scale = Vector3.ONE * _scale
		add_child(model)
		_body = model
		anim = _find(model, "AnimationPlayer") as AnimationPlayer
		if anim:
			for c in ["Idle", "Walk", "Run", "Charge"]:
				if anim.has_animation(c):
					anim.get_animation(c).loop_mode = Animation.LOOP_LINEAR
		var sk := _find(model, "Skeleton3D") as Skeleton3D
		if sk and meta.has("spring_chains") and Quality.springs():
			_springs(sk, meta["spring_chains"])
		if meta.has("radius_m"):
			radius = maxf(float(meta["radius_m"]) * _scale, float(info["radius"]) * 0.8)
		if meta.has("aim_height_m"):
			aim_height = float(meta["aim_height_m"]) * _scale
		_play("Walk")
	else:
		_body = Node3D.new()
		add_child(_body)
		var mi := MeshInstance3D.new()
		mi.mesh = _placeholder_mesh()
		mi.material_override = Props.vc()
		_body.add_child(mi)
		_body.scale = Vector3.ONE * _scale
	Fx.blob(self, radius * (0.8 if flyer else 1.15))


func _springs(sk: Skeleton3D, chains: Array) -> void:
	var sim := SpringBoneSimulator3D.new()
	sk.add_child(sim)
	var ok: Array = []
	for c in chains:
		if sk.find_bone(String(c["root"])) >= 0 and sk.find_bone(String(c["end"])) >= 0:
			ok.append(c)
	sim.setting_count = ok.size()
	for i in ok.size():
		var c: Dictionary = ok[i]
		sim.set_root_bone_name(i, String(c["root"]))
		sim.set_end_bone_name(i, String(c["end"]))
		sim.set_extend_end_bone(i, true)
		sim.set_end_bone_direction(i, SkeletonModifier3D.BONE_DIRECTION_PLUS_Y)
		sim.set_end_bone_length(i, float(c.get("length", 0.08)))
		sim.set_center_from(i, SpringBoneSimulator3D.CENTER_FROM_WORLD_ORIGIN)
		sim.set_stiffness(i, float(c.get("stiffness", 2.0)))
		sim.set_drag(i, float(c.get("drag", 0.4)))
		sim.set_gravity(i, float(c.get("gravity", 0.3)))
		sim.set_gravity_direction(i, Vector3.DOWN)
		sim.set_radius(i, float(c.get("radius", 0.03)))


func _find(n: Node, type: String) -> Node:
	if n.is_class(type):
		return n
	for c in n.get_children():
		var r := _find(c, type)
		if r != null:
			return r
	return null


func _placeholder_mesh() -> ArrayMesh:
	var violet := Color(0.75, 0.3, 1.0)
	var parts: Array = []
	var h := float(info["height"]) / _scale
	match _model_id:
		"thornling":
			parts.append([Props._ball(h * 0.38, h * 0.72, 7), Props._at(0, h * 0.42, 0), _color])
			parts.append([Props._cyl(0.0, 0.03, h * 0.45, 4), Props._at(0, h * 0.85, 0, Vector3(0.3, 0, 0)), Color(0.45, 0.75, 0.3)])
			for x in [-1.0, 1.0]:
				parts.append([Props._cyl(0.025, 0.03, h * 0.25, 4), Props._at(x * h * 0.13, h * 0.1, 0), Color(0.45, 0.3, 0.18)])
		"brute":
			parts.append([Props._ball(h * 0.3, h * 0.6, 7), Props._at(0, h * 0.33, 0), Color(0.93, 0.86, 0.72)])
			parts.append([Props._ball(h * 0.42, h * 0.38, 8), Props._at(0, h * 0.78, 0), _color])
		"raccoon":
			parts.append([Props._ball(h * 0.2, h * 0.62, 7), Props._at(0, h * 0.35, 0), _color])
			parts.append([Props._ball(h * 0.18, h * 0.32, 7), Props._at(0, h * 0.78, 0.02), Color(0.7, 0.66, 0.68)])
			parts.append([Props._ball(h * 0.1, h * 0.5, 6), Props._at(0, h * 0.3, -h * 0.25, Vector3(-1.0, 0, 0)), Color(0.35, 0.32, 0.36)])
			parts.append([Props._box(h * 0.36, h * 0.07, h * 0.05), Props._at(0, h * 0.8, h * 0.16), Color(0.15, 0.12, 0.15)])
		"boar":
			parts.append([Props._ball(h * 0.42, h * 0.75, 7), Props._at(0, h * 0.5, 0, Vector3.ZERO, Vector3(1.0, 1.0, 1.7)), _color])
			parts.append([Props._ball(h * 0.25, h * 0.45, 6), Props._at(0, h * 0.5, h * 0.72), _color.darkened(0.1)])
			for x in [-1.0, 1.0]:
				parts.append([Props._cyl(0.0, 0.04, h * 0.25, 4), Props._at(x * h * 0.13, h * 0.45, h * 0.9, Vector3(1.2, 0, 0)), Color(0.95, 0.9, 0.75)])
			parts.append([Props._box(h * 0.12, h * 0.2, h * 0.9), Props._at(0, h * 0.92, 0), Color(0.3, 0.17, 0.12)])
		"moth":
			parts.append([Props._ball(h * 0.2, h * 0.42, 7), Props._at(0, h * 0.45, 0), Color(0.93, 0.88, 0.8)])
			parts.append([Props._ball(h * 0.17, h * 0.3, 7), Props._at(0, h * 0.62, h * 0.12), Color(0.8, 0.72, 0.95)])
			for x in [-1.0, 1.0]:
				parts.append([Props._box(h * 0.55, h * 0.03, h * 0.38), Props._at(x * h * 0.36, h * 0.55, -h * 0.02, Vector3(0, 0, x * 0.35)), _color])
				parts.append([Props._box(h * 0.38, h * 0.03, h * 0.3), Props._at(x * h * 0.28, h * 0.38, -h * 0.12, Vector3(0, 0, -x * 0.25)), Color(0.62, 0.42, 0.85)])
				parts.append([Props._cyl(0.0, 0.012, h * 0.3, 4), Props._at(x * h * 0.07, h * 0.82, h * 0.16, Vector3(0.5, 0, x * -0.4)), Color(0.55, 0.45, 0.4)])
		"frog":
			parts.append([Props._ball(h * 0.36, h * 0.62, 8), Props._at(0, h * 0.33, 0), _color])
			parts.append([Props._ball(h * 0.3, h * 0.36, 7), Props._at(0, h * 0.7, 0.02), _color.lightened(0.08)])
			parts.append([Props._cyl(h * 0.3, h * 0.42, h * 0.45, 7), Props._at(0, h * 0.42, -0.03), Color(0.36, 0.6, 0.22)])
			parts.append([Props._cyl(0.02, 0.025, h * 1.05, 4), Props._at(h * 0.36, h * 0.52, h * 0.1), Color(0.45, 0.3, 0.18)])
			parts.append([Props._ball(h * 0.08, h * 0.16, 5), Props._at(h * 0.36, h * 1.08, h * 0.1), Color(0.75, 0.3, 1.0)])
		"beetle":
			parts.append([Props._ball(h * 0.3, h * 0.72, 8), Props._at(0, h * 0.5, 0), _color])
			parts.append([Props._ball(h * 0.18, h * 0.24, 7), Props._at(0, h * 0.86, h * 0.06), _color.darkened(0.2)])
			parts.append([Props._cyl(0.0, h * 0.06, h * 0.32, 5), Props._at(0, h * 1.02, h * 0.16, Vector3(0.6, 0, 0)), _color.lightened(0.15)])
			parts.append([Props._cyl(h * 0.3, h * 0.3, h * 0.06, 9), Props._at(-h * 0.14, h * 0.48, h * 0.3, Vector3(PI / 2, 0, 0)), Color(0.55, 0.38, 0.22)])
			parts.append([Props._ball(h * 0.06, h * 0.08, 5), Props._at(-h * 0.14, h * 0.48, h * 0.34), Color(0.75, 0.3, 1.0)])
			for x in [-1.0, 1.0]:
				parts.append([Props._cyl(0.03, 0.035, h * 0.3, 4), Props._at(x * h * 0.12, h * 0.13, 0), Color(0.15, 0.25, 0.25)])
		"snail":
			parts.append([Props._ball(h * 0.28, h * 0.4, 7), Props._at(0, h * 0.18, 0, Vector3.ZERO, Vector3(1.0, 1.0, 2.6)), _color])
			parts.append([Props._ball(h * 0.45, h * 0.85, 8), Props._at(0, h * 0.5, -h * 0.18), Color(0.55, 0.4, 0.25)])
			parts.append([Props._ball(h * 0.36, h * 0.3, 7), Props._at(0, h * 0.86, -h * 0.18), Color(0.4, 0.62, 0.25)])
			for v in [Vector3(0, 1.08, -0.18), Vector3(0.14, 1.0, -0.3), Vector3(-0.12, 1.02, -0.06)]:
				parts.append([Props._cyl(0.0, h * 0.09, h * 0.36, 5), Props._at(v.x * h, v.y * h, v.z * h), Color(0.72, 0.4, 1.0)])
			for x in [-1.0, 1.0]:
				parts.append([Props._cyl(0.012, 0.018, h * 0.32, 4), Props._at(x * h * 0.08, h * 0.45, h * 0.55, Vector3(-0.3, 0, x * 0.2)), _color])
		"owl":
			parts.append([Props._ball(h * 0.3, h * 0.66, 8), Props._at(0, h * 0.36, 0), _color])
			parts.append([Props._ball(h * 0.2, h * 0.42, 7), Props._at(0, h * 0.36, h * 0.12), Color(0.93, 0.85, 0.7)])
			parts.append([Props._ball(h * 0.22, h * 0.3, 7), Props._at(0, h * 0.74, 0.02), _color.lightened(0.1)])
			parts.append([Props._cyl(h * 0.26, h * 0.28, h * 0.03, 8), Props._at(0, h * 0.86, 0), Color(0.42, 0.22, 0.55)])
			parts.append([Props._cyl(0.0, h * 0.15, h * 0.32, 6), Props._at(0, h * 1.02, -0.04, Vector3(-0.25, 0, 0.1)), Color(0.42, 0.22, 0.55)])
			parts.append([Props._cyl(0.03, 0.035, h * 1.0, 4), Props._at(h * 0.34, h * 0.5, h * 0.1), Color(0.45, 0.3, 0.18)])
			parts.append([Props._ball(h * 0.06, h * 0.12, 5), Props._at(h * 0.34, h * 0.98, h * 0.1), Color(0.75, 0.3, 1.0)])
		"stump":
			parts.append([Props._cyl(h * 0.32, h * 0.38, h * 0.75, 8), Props._at(0, h * 0.45, 0), _color])
			parts.append([Props._cyl(h * 0.33, h * 0.33, h * 0.04, 8), Props._at(0, h * 0.84, 0), Color(0.85, 0.7, 0.45)])
			for x in [-1.0, 1.0]:
				parts.append([Props._ball(h * 0.13, h * 0.3, 6), Props._at(x * h * 0.42, h * 0.35, h * 0.05), _color.darkened(0.15)])
			parts.append([Props._ball(h * 0.08, h * 0.08, 5), Props._at(0.1 * h, h * 0.9, 0), Color(0.9, 0.3, 0.25)])
		"pitcher":
			parts.append([Props._cyl(h * 0.3, h * 0.22, h * 0.7, 8), Props._at(0, h * 0.5, 0), _color])
			parts.append([Props._cyl(h * 0.32, h * 0.32, h * 0.05, 8), Props._at(0, h * 0.86, 0), Color(0.8, 0.25, 0.25)])
			parts.append([Props._box(h * 0.4, h * 0.03, h * 0.35), Props._at(0, h * 0.98, -h * 0.12, Vector3(-0.6, 0, 0)), Color(0.4, 0.7, 0.25)])
			for x in [-1.0, 1.0]:
				parts.append([Props._cyl(0.02, 0.03, h * 0.35, 4), Props._at(x * h * 0.15, h * 0.12, 0, Vector3(0, 0, x * 0.4)), Color(0.45, 0.32, 0.2)])
		"mole":
			parts.append([Props._ball(h * 0.32, h * 0.75, 8), Props._at(0, h * 0.4, 0), _color])
			parts.append([Props._ball(h * 0.08, h * 0.08, 5), Props._at(0, h * 0.62, h * 0.3), Color(1.0, 0.6, 0.7)])
			parts.append([Props._cyl(h * 0.2, h * 0.24, h * 0.12, 7), Props._at(0, h * 0.85, 0), Color(0.55, 0.38, 0.22)])
			for x in [-1.0, 1.0]:
				parts.append([Props._box(h * 0.14, h * 0.04, h * 0.18), Props._at(x * h * 0.32, h * 0.38, h * 0.18), Color(1.0, 0.65, 0.72)])
		"puffball":
			parts.append([Props._ball(h * 0.45, h * 0.85, 8), Props._at(0, h * 0.45, 0), _color])
			parts.append([Props._ball(h * 0.18, h * 0.06, 5), Props._at(0, h * 0.88, 0), Color(0.75, 0.3, 1.0)])
		"crow":
			parts.append([Props._ball(h * 0.3, h * 0.65, 8), Props._at(0, h * 0.42, 0), _color])
			parts.append([Props._cyl(0.0, h * 0.06, h * 0.16, 5), Props._at(0, h * 0.7, h * 0.24, Vector3(PI / 2, 0, 0)), Color(1.0, 0.8, 0.2)])
			parts.append([Props._cyl(h * 0.14, h * 0.14, h * 0.26, 8), Props._at(0, h * 0.3, h * 0.28, Vector3(0, 0, PI / 2)), Color(0.55, 0.38, 0.22)])
			for x in [-1.0, 1.0]:
				parts.append([Props._box(h * 0.08, h * 0.35, h * 0.2), Props._at(x * h * 0.32, h * 0.45, 0), _color.lightened(0.1)])
		"stag":
			parts.append([Props._ball(h * 0.2, h * 0.32, 8), Props._at(0, h * 0.45, 0, Vector3.ZERO, Vector3(1.0, 1.0, 2.0)), _color])
			parts.append([Props._ball(h * 0.09, h * 0.14, 7), Props._at(0, h * 0.62, h * 0.36), _color.lightened(0.1)])
			for x in [-1.0, 1.0]:
				parts.append([Props._cyl(0.03, 0.05, h * 0.32, 4), Props._at(x * h * 0.08, h * 0.16, h * 0.2), _color.darkened(0.2)])
				parts.append([Props._cyl(0.03, 0.05, h * 0.32, 4), Props._at(x * h * 0.08, h * 0.16, -h * 0.25), _color.darkened(0.2)])
				parts.append([Props._cyl(0.02, 0.04, h * 0.4, 4), Props._at(x * h * 0.12, h * 0.86, h * 0.34, Vector3(0, 0, -x * 0.6)), Color(0.45, 0.3, 0.18)])
				parts.append([Props._cyl(0.0, h * 0.05, h * 0.16, 5), Props._at(x * h * 0.22, h * 1.0, h * 0.34), Color(0.75, 0.35, 1.0)])
		"bear":
			parts.append([Props._ball(h * 0.3, h * 0.7, 8), Props._at(0, h * 0.38, 0), _color])
			parts.append([Props._ball(h * 0.17, h * 0.3, 7), Props._at(0, h * 0.82, 0.05), _color.lightened(0.1)])
			parts.append([Props._ball(h * 0.33, h * 0.18, 7), Props._at(0, h * 0.68, -0.05), Color(0.55, 0.7, 0.25)])
			parts.append([Props._cyl(0.0, 0.18, 0.6, 5), Props._at(0.2, h * 0.75, -0.35, Vector3(-0.5, 0, 0.3)), violet])
		_:
			parts.append([Props._ball(h * 0.4, h, 7), Props._at(0, h * 0.5, 0), _color])
	# violet eyes on the front (+Z): [height, forward] as parts of the height
	var eyes: Array = {"thornling": [0.5, 0.32], "brute": [0.62, 0.28], "boar": [0.55, 0.88], "moth": [0.66, 0.26],
		"frog": [0.78, 0.26], "beetle": [0.88, 0.2], "snail": [0.6, 0.62], "owl": [0.76, 0.2], "stump": [0.62, 0.36],
		"pitcher": [0.7, 0.3], "mole": [0.7, 0.3], "puffball": [0.55, 0.42], "crow": [0.78, 0.26], "stag": [0.66, 0.42]}.get(_model_id, [0.84, 0.18])
	for x in [-1.0, 1.0]:
		parts.append([Props._ball(h * 0.06, h * 0.06, 5), Props._at(x * h * 0.09, h * float(eyes[0]), h * float(eyes[1])), violet])
	return Props.build(parts)


func _play(clip: String, blend := 0.15) -> void:
	_clip = clip
	if anim == null:
		return
	var c := clip
	if not anim.has_animation(c):
		c = "Walk" if anim.has_animation("Walk") else ""
		if c == "":
			return
	if anim.current_animation != c or not anim.is_playing():
		anim.play(c, blend)


## The first of these clips the model has (placeholders have none: then the first name, which _play ignores).
func _clip_or(names: Array) -> String:
	if anim:
		for n in names:
			if anim.has_animation(n):
				return n
	return String(names[0])


func _clip_len(clip: String, fallback: float) -> float:
	if anim and anim.has_animation(clip):
		return anim.get_animation(clip).length
	return fallback


func _event(clip: String, ev: String, fallback: float) -> float:
	var e: Dictionary = meta.get("events", {})
	if e.has(clip) and (e[clip] as Dictionary).has(ev):
		return float(e[clip][ev])
	return fallback


# ---------------------------------------------------------------- per frame
func _physics_process(delta: float) -> void:
	if dead or main.frozen:
		return
	if burn_t > 0.0:
		_burn_tick(minf(delta, 0.1))                    # G3: Ember fire (frame time, never a clock)
		if dead:
			return
	_vuln_t = maxf(0.0, _vuln_t - delta)
	if bellow_t > 0.0:
		bellow_t = maxf(0.0, bellow_t - minf(delta, 0.1))   # G4: frame time, never a clock
		if bellow_t <= 0.0:
			bellow_k = 0.0
	if chill_t > 0.0 or freeze_t > 0.0:
		_frost_tick(minf(delta, 0.1))                   # 22 Nov 2026: the Frost Bow's ice (frame time, never a clock)
		if freeze_t > 0.0:
			_frozen_frame(delta)                        # frozen solid: nothing moves, nothing attacks
			return
		if chill_t > 0.0:
			delta *= 1.0 - chill_slow                   # chilled: its whole life runs slower (walking, attacks, timers)
	_t += delta
	_cd = maxf(0.0, _cd - delta)
	_cd2 = maxf(0.0, _cd2 - delta)
	_cd3 = maxf(0.0, _cd3 - delta)
	_cd4 = maxf(0.0, _cd4 - delta)
	_boost_t = maxf(0.0, _boost_t - delta)
	if not awake:
		_sleep_tick(delta)
		return
	_slow = main.defences.slow_at(global_position) if main.defences else 0.0
	buff_t = maxf(0.0, buff_t - delta)
	totem_t = maxf(0.0, totem_t - delta)
	if (totem_t > 0.0) != _totem_on:
		_totem_on = totem_t > 0.0
		Props.set_param(_body, "gloom", _gloom_base() + (TOTEM_GLOOM if _totem_on else 0.0))
	var spd := _speed_now()
	position += _knock * delta
	_knock = _knock.lerp(Vector3.ZERO, 1.0 - exp(-8.0 * delta))
	_hit_flash = maxf(0.0, _hit_flash - delta)
	Props.set_param(_body, "flash", clampf(_hit_flash * 8.0 + (Fx.CHILL_FLASH if chill_t > 0.0 else 0.0), 0.0, 1.0))
	match state:
		"attack", "slam", "roar", "grab", "spores", "heal", "cast", "orbs", "hex", "summon", "spit", "burst", "drum", "lob", "bite":
			_do_action(delta)
		"blink":
			_do_blink(delta)
		"dig":
			_do_dig(delta)
		"pounce":
			_do_pounce(delta)
		"dash_windup":
			_act_t += delta
			var to_cat: Vector3 = main.player.global_position - global_position
			to_cat.y = 0.0
			if _act_t < 0.55 and to_cat.length() > 0.5:
				_charge_dir = to_cat.normalized()
			_face(_charge_dir, delta, 8.0)
			if _act_t >= 1.0:
				state = "dash"
				_act_t = 0.0
				_play("Walk", 0.05)
				main.shake(0.15)
		"dash":
			_do_dash(delta)
		"emerge":
			_do_emerge(delta)
		"windup":
			_act_t += delta
			_face(_charge_dir, delta, 10.0)
			if fmod(_act_t, 0.18) < delta:
				Fx.dust(main, global_position + _charge_dir * radius, 4, 0.8)
			if _act_t >= float(info.get("windup", 0.8)):
				state = "charge"
				_act_t = 0.0
				_play("Charge" if anim and anim.has_animation("Charge") else "Run")
		"charge":
			_do_charge(delta)
		"daze":
			_act_t += delta
			if _act_t > 0.8:
				state = "walk"
		"flee":
			_do_flee(delta, spd)
			if _boost_t > 0.0 and fmod(_t, 0.1) < delta:
				Fx.dust(main, global_position, 2, 0.6)
		_:
			if _ai == "golden_grub":
				_do_grub(delta, spd)
			elif _ai == "totem":
				_do_totem(delta)
			else:
				_think_t -= delta
				if _think_t <= 0.0:
					_think_t = 0.2
					_think()
				if _sq_on:
					spd = _squad_steer(delta, spd)      # Phase G1b: to its spot in the formation, at the leader's pace
				_walk(delta, spd)
	if _ai == "totem":
		pass                                        # a crystal: it only breathes (_do_totem)
	elif anim == null:
		_wobble()
	else:
		_stride(delta)
	if flyer:
		var bob := 0.1 * sin(_t * 3.1 + float(get_instance_id() % 7))
		_body.position.y = fly_h + bob
	_block_t = maxf(0.0, _block_t - delta)
	if id == "snail" and (state == "walk" or state == "chase") and not main.world.inside_camp(global_position):
		_slime_t -= delta
		if _slime_t <= 0.0:
			_slime_t = float(info.get("slime_every", 0.9))
			var sl := SlimeScript.new()
			main.add_child(sl)
			sl.setup(main, global_position - Vector3(sin(rotation.y), 0, cos(rotation.y)) * radius * 0.6, radius * 0.95, float(info.get("slime_life", 7.0)))
	if anim and state == "dash":
		anim.speed_scale = 2.6
	elif anim and state == "charge" and anim.current_animation == "Charge":
		var gc: Dictionary = meta.get("ground_speed_m_per_s", {})
		anim.speed_scale = clampf(float(info["charge_speed"]) / maxf(float(gc.get("Charge", info["charge_speed"])) * _scale, 0.05), 0.6, 2.0)
	elif anim and (state == "walk" or state == "chase" or state == "flee"):
		var gs: Dictionary = meta.get("ground_speed_m_per_s", {})
		var clip := "Run" if (state == "flee" or (id == "raccoon" and anim.has_animation("Run"))) else "Walk"
		var ref := float(gs.get(clip, spd))
		anim.speed_scale = clampf(spd / maxf(ref * _scale, 0.05), 0.5, 2.2)
	elif anim:
		anim.speed_scale = 1.0
	if anim and chill_t > 0.0:
		anim.speed_scale *= 1.0 - chill_slow            # 22 Nov 2026: chilled, its clips play slower too (set afresh above every frame)


## How fast it walks now: spikes slow it; a Raccoon's smoke sprint, a Crow Drummer's beat and a Gloom Totem nearby
## (Phase F) speed it up.
func _speed_now() -> float:
	return speed * (1.0 - _slow) * (1.9 if _boost_t > 0.0 else 1.0) * (1.0 + buff if buff_t > 0.0 else 1.0) \
		* (1.0 + totem_buff if totem_t > 0.0 else 1.0)


## Its own Gloom tint without a totem's (Gloomtouched elites and enraged Burrow bosses have one).
func _gloom_base() -> float:
	if enraged:
		return 0.5
	if gloomtouched:
		return float(Data.burrow_cfg()["gloomtouched"]["gloom"])
	return 0.0


func _sleep_tick(delta: float) -> void:
	_zz_t -= delta
	if _zz_t <= 0.0:
		_zz_t = randf_range(0.3, 0.5)
		if randf() < 0.15:
			Fx.text(main, global_position + Vector3(0.2, float(info["height"]) + 0.2, 0), "z", Color(0.85, 0.85, 1.0))
		var p = main.player
		var r := float(Data.burrow_cfg().get("wake_r", 5.0))
		if p.hp > 0 and p.global_position.distance_to(global_position) < r and not main.cat_hidden():
			wake()
	if anim == null:
		_wobble()


func _wobble() -> void:
	# the placeholder hops and squashes as it goes
	var moving := state == "walk" or state == "chase" or state == "flee" or state == "charge"
	var f := 9.0 if id == "thornling" else (12.0 if state == "charge" else 6.0)
	var hop := absf(sin(_t * f)) if moving else 0.25 + 0.25 * sin(_t * 3.0)
	_body.position.y = 0.06 * hop * _scale
	var k := 0.08
	_body.scale = Vector3(1.0 + k * (1.0 - hop), 1.0 - k + 2.0 * k * hop, 1.0 + k * (1.0 - hop)) * _scale
	if state == "attack" or state == "slam":
		var a := clampf(_act_t / maxf(_act_event, 0.05), 0.0, 1.0)
		_body.rotation.x = -0.5 * a if _act_t < _act_event else 0.4 * maxf(0.0, 1.0 - (_act_t - _act_event) * 4.0)
	else:
		_body.rotation.x = lerpf(_body.rotation.x, 0.0, 0.2)


func _cat_reachable(range_m: float) -> bool:
	var p = main.player
	if p == null or p.hp <= 0 or main.world.inside_camp(p.global_position):
		return false
	var d: float = p.global_position.distance_to(global_position)
	if main.cat_hidden() and d > radius + 1.2:
		return false                      # hidden in the grass: they only find it by walking into it
	return d < range_m


func _think() -> void:
	if patch >= 0 and main.world.trails.size() > patch:
		s = main.world.trail_progress(patch, global_position)
	if not awake:
		return
	var p = main.player
	var reach := float(info["reach"]) + radius + 0.3
	# Phase G1b: a squad member on the march keeps formation (a Frog Shaman still heals, a Crow Drummer still drums)
	_sq_on = _keep_formation()
	if _sq_on:
		if (_ai == "frog" and _try_heal()) or (_ai == "crow" and _try_drum()):
			return
		state = "walk"
		return
	match _ai:                                      # "ai" lets a kind think like another (the Gloom Herald drums)
		"raccoon":
			if carried < int(info.get("steals", 20)):
				var leaf = main.nearest_pickup(global_position, 14.0)
				if leaf != null:
					_goal = leaf.global_position
					state = "chase"
					if global_position.distance_to(_goal) < 0.55:
						_start_action("grab", leaf)
					return
			if carried > 0:
				state = "flee"
				_play("Run")
				return
			if _cat_reachable(9.0):
				_goal = p.global_position
				state = "chase"
				if global_position.distance_to(_goal) < reach and _cd <= 0.0:
					_start_action("attack", p)
				return
		"boar":
			if _cd2 <= 0.0 and _cat_reachable(float(info["aggro"])) \
					and not main.world.blocked_between(global_position, p.global_position):
				_charge_dir = (p.global_position - global_position)
				_charge_dir.y = 0.0
				_charge_dir = _charge_dir.normalized()
				state = "windup"
				_act_t = 0.0
				_play("Windup" if anim and anim.has_animation("Windup") else "Idle")
				Fx.telegraph_line(main, global_position, _charge_dir, float(info["charge_speed"]) * float(info.get("charge_time", 1.4)),
					radius * 2.0, float(info.get("windup", 0.8)))
				Fx.text(main, global_position + Vector3(0, float(info["height"]) + 0.3, 0), "!", Color(1, 0.4, 0.3))
				return
			if _cat_reachable(reach) and _cd <= 0.0:
				_start_action("attack", p)
				return
		"bear":
			if _cd3 <= 0.0:
				_start_action("roar", null)
				return
			if _cd4 <= 0.0 and _cat_reachable(10.0) and not _cat_reachable(3.2) \
					and not main.world.blocked_between(global_position, p.global_position):
				_start_dash()
				return
			if _cd2 <= 0.0 and _cat_reachable(float(info["slam_range"]) * 0.8):
				_start_action("slam", p)
				return
			if _cat_reachable(reach) and _cd <= 0.0:
				_start_action("attack", p)
				return
		"moth":
			if _cd4 <= 0.0 and _cat_reachable(float(info["aggro"])) and not _cat_reachable(0.9):
				_start_pounce(p.global_position, 2.6, -0.75, 0.5)
				return
			if _cat_reachable(reach) and _cd <= 0.0:
				_start_action("attack", p)
				return
			if _cat_reachable(float(info["aggro"])):
				_goal = p.global_position
				state = "chase"
				return
			# straight over barricades and buildings at the camp's towers, buildings and campfire (or at the cat,
			# once the fire is out, or below ground)
			if main.fight.last_stand or _in_area():
				_hunt(p, reach)
				return
			state = "walk"
			if _siege(true):
				return
			_goal = Vector3.ZERO
			return
		"frog":
			if _try_heal():
				return
			if _cd <= 0.0 and _cat_reachable(float(info["cast_range"])):
				_start_action("cast", p)
				return
			if _cat_reachable(float(info["cast_range"]) * 0.9):
				state = "walk"
				_goal = global_position                  # stands its ground and keeps casting
				return
		"beetle":
			if _cd4 <= 0.0 and _cat_reachable(2.2) and not _cat_reachable(0.9):
				_start_pounce(p.global_position, 2.0, 0.0, 0.32)
				_cd4 = float(info.get("bash_every", 6.0))
				_power = true
				Fx.text(main, global_position + Vector3(0, float(info["height"]) + 0.3, 0), "Bash!", Color(0.6, 0.9, 1.0))
				return
			if _cat_reachable(float(info["aggro"])):
				_goal = p.global_position
				state = "chase"
				if global_position.distance_to(_goal) < reach and _cd <= 0.0:
					_start_action("attack", p)
				return
		"snail":
			if _cd2 <= 0.0 and _cat_reachable(float(info["slam_range"])):
				_start_action("slam", p)
				return
			if _cat_reachable(reach) and _cd <= 0.0:
				_start_action("attack", p)
				return
		"owl":
			if _cd3 <= 0.0:
				_start_action("summon", null)
				return
			if _cd5 <= 0.0 and _cat_reachable(11.0) and not _cat_reachable(2.5):
				_start_blink()
				return
			if _cd2 <= 0.0 and _cat_reachable(7.0):
				_start_action("hex", p)
				return
			if _cd4 <= 0.0 and _cat_reachable(9.0):
				_start_action("orbs", p)
				return
			if _cat_reachable(reach) and _cd <= 0.0:
				_start_action("attack", p)
				return
		"stump", "mole":
			if _cat_reachable(reach) and _cd <= 0.0:
				_start_action("attack", p)
				return
		"pitcher":
			# the cat near: spit at it; else the camp's structures from afar (_standoff, below)
			var rng := float(info["spit_range"])
			if _cd <= 0.0 and _cat_reachable(rng):
				_start_action("spit", p)
				return
			if _cat_reachable(rng):
				state = "walk"
				_goal = global_position
				return
		"puffball":
			if _cat_reachable(radius + 0.6):
				_start_action("burst", p)
				return
		"crow":
			if _try_drum():
				return
			if _cat_reachable(reach) and _cd <= 0.0:
				_start_action("attack", p)
				return
		"stag":
			if _cd3 <= 0.0:
				_start_action("roar", null)
				return
			if _cd2 <= 0.0 and _cat_reachable(float(info["aggro"])) and not _cat_reachable(3.0) \
					and not main.world.blocked_between(global_position, p.global_position):
				_charge_dir = (p.global_position - global_position)
				_charge_dir.y = 0.0
				_charge_dir = _charge_dir.normalized()
				state = "windup"
				_act_t = 0.0
				_play("Windup" if anim and anim.has_animation("Windup") else "Idle")
				Fx.telegraph_line(main, global_position, _charge_dir, float(info["charge_speed"]) * float(info.get("charge_time", 1.4)),
					radius * 2.0, float(info.get("windup", 0.8)), Color(0.75, 0.35, 1.0, 0.35))
				Fx.text(main, global_position + Vector3(0, float(info["height"]) + 0.3, 0), "!!", Color(0.9, 0.5, 1.0))
				return
			if _cd4 <= 0.0 and _cat_reachable(float(info["slam_range"]) * 0.8):
				_cd4 = float(info.get("slam_every", 6.0))
				_start_action("slam", p)
				_cd2 = maxf(_cd2, 2.0)
				return
			if _cat_reachable(reach) and _cd <= 0.0:
				_start_action("attack", p)
				return
		# Phase E: the Burrows' own kinds (stand-in models until the user's Meshy models come)
		"glowcap":
			var dist: float = global_position.distance_to(p.global_position)
			if _cd <= 0.0 and _cat_reachable(float(info["lob_range"])):
				_start_action("lob", p)
				return
			if _cat_reachable(float(info["keep_away"])):
				var away: Vector3 = global_position - p.global_position
				away.y = 0.0
				_goal = global_position + (away.normalized() if away.length() > 0.01 else Vector3.FORWARD) * 2.0
				state = "walk"
				return
			if _cat_reachable(float(info["aggro"])):
				_goal = p.global_position if dist > 6.5 else global_position
				state = "chase" if dist > 6.5 else "walk"
				return
		"snapper":
			var to: Vector3 = p.global_position - global_position
			to.y = 0.0
			_goal = global_position
			if to.length() > 0.01 and p.hp > 0:
				rotation.y = rotate_toward(rotation.y, atan2(to.x, to.z), float(info.get("turn_rate", 2.0)) * 0.2)
			var fwd := Vector3(sin(rotation.y), 0, cos(rotation.y))
			if _cd <= 0.0 and _cat_reachable(float(info["reach"])) and to.length() > 0.01 \
					and rad_to_deg(fwd.angle_to(to.normalized())) < float(info.get("bite_cone_deg", 35.0)):
				_start_action("bite", p)
				return
			state = "walk"
			return
		"amber_grub":
			_goal = main.area.flee_point(p.global_position) if _in_area() else global_position
			state = "chase"
			return
		"brute":
			if _cd4 <= 0.0 and _cat_reachable(2.6):
				_start_action("spores", p)
				return
			if _cat_reachable(reach) and _cd <= 0.0:
				_start_action("attack", p)
				return
		_:
			if _cd4 <= 0.0 and _cat_reachable(2.8) and not _cat_reachable(1.1):
				_start_pounce(p.global_position)
				return
			if _cat_reachable(float(info["aggro"])):
				_goal = p.global_position
				state = "chase"
				if global_position.distance_to(_goal) < reach and _cd <= 0.0:
					_start_action("attack", p)
				return
	state = "walk"
	if _in_area():
		_hunt(p, reach)                             # below ground there is no camp to siege: they hunt the cat
		return
	# the Moss Warden is in the way: fight it (every kind still tries the cat first, in its own branch above)
	var g = main.guardian
	if g != null and gate_damage > 0 and not flyer and not main.fight.last_stand and g.taunts(self):
		_fight_guardian(g)
		return
	if main.fight.last_stand:
		_hunt(p, reach)
		return
	# near the camp, or near a tower: go and knock it down (ranged kinds shoot it from siege_range m: Phase F)
	if gate_damage > 0:
		var sr := float(info.get("siege_range", info.get("spit_range", 0.0)))
		if sr > 0.0:
			if _standoff(sr):
				return
		elif _siege(false):
			return
	_goal = main.world.trail_point(patch, s + 1.4) if patch >= 0 and main.world.trails.size() > patch else main.world.edge_point(clampi(patch, 0, 3))


## A Frog Shaman heals when its heal is ready and a wounded enemy is near. True when it started.
func _try_heal() -> bool:
	if _cd4 > 0.0:
		return false
	for f in get_tree().get_nodes_in_group("foes"):
		if not f.dead and f.hp < f.max_hp * 0.9 and f.global_position.distance_to(global_position) < float(info["heal_range"]):
			_start_action("heal", null)
			return true
	return false


## A Crow Drummer drums when its drum is ready and another enemy is near. True when it started.
func _try_drum() -> bool:
	if _cd4 > 0.0:
		return false
	for f in get_tree().get_nodes_in_group("foes"):
		if f != self and not f.dead and f.global_position.distance_to(global_position) < float(info["drum_range"]):
			_start_action("drum", null)
			return true
	return false


# ---------------------------------------------------------------- Phase G1b: squads
## mission.squad_rules ({} when missing).
func _squad_rules() -> Dictionary:
	return _mcfg("squad_rules")


## Where a squad member's spot `off` is (x: to the side, z: forward) for a leader at `at` facing rot_y (its rotation.y),
## on the ground. fight.gd sets a squad out with it; a member keeps to it (_squad_steer).
static func squad_spot(at: Vector3, rot_y: float, off: Vector3) -> Vector3:
	var f := Vector3(sin(rot_y), 0.0, cos(rot_y))
	var side := Vector3(f.z, 0.0, -f.x)
	return Vector3(at.x, 0.0, at.z) + side * off.x + f * off.z


## A squad member (the metas "squad_leader" and "squad_offset", from fight.gd) keeps formation while its leader lives
## and it is more than squad_rules.break_off m from the firelight's edge. It breaks off for good (leave_squad) once it is
## that near the camp, its leader is gone, the cat comes within its aggro (or hits it from close by, see hit), the
## campfire is out or it is below ground. While its leader smashes a barricade or a tower, it does its own job too (it
## goes back to its spot after). True while it keeps formation.
func _keep_formation() -> bool:
	if not has_meta("squad_leader"):
		return false
	var ld = get_meta("squad_leader")
	if ld == null or not is_instance_valid(ld) or ld == self or ld.get("dead") == true or boss or main.fight.last_stand or _in_area():
		leave_squad()
		return false
	var me := Vector2(global_position.x, global_position.z)
	if me.length() - float(main.world.camp_r) < float(_squad_rules().get("break_off", 6.0)) \
			or _cat_reachable(float(info.get("aggro", 0.0))):
		leave_squad()
		return false
	if ld.has_method("wrecking") and ld.wrecking():
		return false
	return true


## It leaves its squad: from now on it acts on its own (its squad number, the meta "squad", stays).
func leave_squad() -> void:
	_sq_on = false
	if has_meta("squad_leader"):
		remove_meta("squad_leader")
	if has_meta("squad_offset"):
		remove_meta("squad_offset")


## While it keeps formation (_sq_on): its goal is its spot by its leader (squad_spot of the leader's position and
## facing) and its speed follows the leader's: the leader's own pace plus a little to close the gap, never more than
## squad_rules.pace (1.1) x the leader's speed, nor its own `spd`. Ahead of its spot, it waits for it. Returns the speed
## to walk at.
func _squad_steer(delta: float, spd: float) -> float:
	var ld = get_meta("squad_leader", null)
	if ld == null or not is_instance_valid(ld) or ld.get("dead") == true:
		_sq_on = false
		return spd
	var lp := Vector3(ld.global_position.x, 0.0, ld.global_position.z)
	var v := 0.0
	if is_finite(_sq_prev.x):
		v = lp.distance_to(_sq_prev) / maxf(delta, 0.0001)
	_sq_prev = lp
	var top: float = float(ld._speed_now()) * float(_squad_rules().get("pace", 1.1))
	v = minf(v, top)
	var ry := float(ld.rotation.y)
	var fwd := Vector3(sin(ry), 0.0, cos(ry))
	var off = get_meta("squad_offset", Vector3.ZERO)
	var spot := squad_spot(lp, ry, off if off is Vector3 else Vector3.ZERO)
	var to := spot - Vector3(global_position.x, 0.0, global_position.z)
	var behind := to.dot(fwd)
	if behind < -0.3:
		_goal = global_position                     # ahead of its spot: it waits for the squad
		return 0.0
	var want := v + 1.5 * maxf(to.length() - 0.1, 0.0)
	if behind < 0.0:
		want = minf(want, v * 0.8)                  # a little ahead: it lets its spot come up
	_goal = spot + fwd * (0.6 if v > 0.05 else 0.0)  # with a walking leader, a little along the way (no stop-and-go)
	return minf(spd, minf(want, top))


## The camp guardian is in the way: hit it (structure-scale hits; _impact range-checks them).
func _fight_guardian(g) -> void:
	var c := Vector3(g.global_position.x, 0, g.global_position.z)
	var me := Vector3(global_position.x, 0, global_position.z)
	var away := me - c
	var dist := away.length()
	var touch: float = float(g.radius) + radius + float(info["reach"]) + 0.35
	if dist < touch:
		_goal = global_position
		_face(-away / maxf(dist, 0.01), get_physics_process_delta_time(), 10.0)
		if _cd <= 0.0:
			_start_action("burst" if id == "puffball" else "attack", g)
	else:
		_goal = c + away / maxf(dist, 0.01) * (float(g.radius) + radius + 0.15)


## Hitting a building, a barricade, a tower or the campfire (what the Moss Warden goes for first).
func wrecking() -> bool:
	if not (state in ["attack", "burst", "spit", "cast"]):
		return false
	var t = _act_target
	if t is String:
		return t == "gate"
	return t is Object and is_instance_valid(t) and t != main.player and t != main.guardian


func hitting_cat() -> bool:
	return state == "attack" and _act_target is Object and _act_target == main.player


## The Moss Warden's slam: a short stun for small foes. Ends the way any daze ends (state "daze" until _act_t > 0.8).
func stagger(daze_s: float) -> void:
	if dead or boss or flyer or not (state in ["walk", "chase", "attack"]):
		return
	state = "daze"
	_act_t = 0.8 - daze_s
	_act_target = null
	if anim and anim.has_animation("Hit"):
		_play("Hit", 0.05)


## G4: stunned for secs by a mount's Pounce or Bellow (mount.gd gives bosses their shorter time): it stands dazed
## (state "daze", the way any daze ends) and does nothing. Only a foe that is awake and walking, chasing, attacking or
## already dazed (never mid-charge, mid-special, digging or blinking), never a Gloom Totem or anything anchored. A
## longer daze already on is kept.
func stun(secs: float) -> void:
	if dead or secs <= 0.0 or not awake or anchored or _ai == "totem":
		return
	if not (state in ["walk", "chase", "attack", "daze"]):
		return
	_act_t = (0.8 - secs) if state != "daze" else minf(_act_t, 0.8 - secs)
	state = "daze"
	_act_target = null
	if anim and anim.has_animation("Hit"):
		_play("Hit", 0.05)


## G4: knocked aside by a mount's Ram: pushed along dir at `speed` m/s (the push fades within a moment, as a hit's does;
## the heavy ones a third as far). Never a boss, anything anchored, or a foe mid-charge, mid-dash or mid-pounce.
func shove(dir: Vector3, speed: float) -> void:
	if dead or boss or anchored or speed <= 0.0 or state in ["charge", "dash", "pounce", "dig", "emerge", "blink"]:
		return
	var d := Vector3(dir.x, 0.0, dir.z)
	if d.length() < 0.001:
		return
	_knock = d.normalized() * speed * (0.33 if id in ["brute", "snail", "beetle"] else 1.0)


## G4: shaken by a mount's Bellow: for secs it takes `extra` more damage (a share) from every hit and burn. A second
## call while one is on keeps the longer time and the bigger share.
func bellowed(secs: float, extra: float) -> void:
	if dead or secs <= 0.0:
		return
	bellow_t = maxf(bellow_t, secs)
	bellow_k = maxf(bellow_k, extra)


## What an enemy can hit that is not the cat: a building or the campfire (towers and barricades have their own
## handles in defences.gd).
class Target:
	extends RefCounted
	var main_ref
	var kind := ""
	var id := ""
	var global_position := Vector3.ZERO

	func hurt(amount: int) -> void:
		if kind == "fire":
			main_ref.fight.damage_fire(amount, global_position + Vector3(0.01, 0, 0.01))
		else:
			main_ref.stations.hurt_building(id, amount)


## The camp's structures: a tower within 7 m, else (near the camp) the nearest standing building within 9 m, else the
## campfire. Walks up to it and attacks. Returns false when there is nothing to go for yet (keep to the trail).
func _siege(flier: bool) -> bool:
	var me := Vector3(global_position.x, 0, global_position.z)
	var best: Array = []
	var best_d := 7.0
	for t in main.defences.tower_targets():
		var d: float = me.distance_to(t[1])
		if d < best_d:
			best_d = d
			best = [t[0], t[1], t[2]]
	var near_camp: bool = flier or me.length() < main.world.camp_r + 6.0
	if best.is_empty() and near_camp:
		best_d = 9.0
		for b in main.stations.building_targets():
			var d2: float = me.distance_to(b[1])
			if d2 < best_d:
				best_d = d2
				var h := Target.new()
				h.main_ref = main
				h.kind = "building"
				h.id = String(b[0])
				h.global_position = b[1]
				best = [h, b[1], b[2]]
		if best.is_empty() and (me.length() < main.world.camp_r + 3.0 or flier):
			var f := Target.new()
			f.main_ref = main
			f.kind = "fire"
			f.global_position = Vector3.ZERO
			best = [f, Vector3.ZERO, 0.75]
	if best.is_empty():
		return false
	var c: Vector3 = best[1]
	var away := me - c
	var dist := away.length()
	var touch: float = float(best[2]) + radius + float(info["reach"]) + 0.35
	if dist < touch:
		_goal = global_position
		_face((c - me).normalized(), get_physics_process_delta_time(), 10.0)
		if _cd <= 0.0:
			_start_action("burst" if id == "puffball" else "attack", best[0])
	else:
		_goal = c + (away / maxf(dist, 0.01)) * (float(best[2]) + radius + 0.15)
	return true


## Phase F: a ranged kind (Pitcher Spitter, Frog Shaman) going for the camp in a mission: it stops `sr` m from the edge
## of a tower, a building or the campfire and shoots it from there (spit or a Gloom bolt), out of reach of a cat
## standing at the fire. It looks at towers first, then the nearest building, then the campfire, each once it is within
## sr + 1.5 m. False: nothing in reach yet (it keeps to its trail).
func _standoff(sr: float) -> bool:
	var me := Vector3(global_position.x, 0, global_position.z)
	var best_d := sr + 1.5
	var tower = null
	var bid := ""
	var c := Vector3.ZERO
	var foot := 0.0
	for t in main.defences.tower_targets():
		var d: float = me.distance_to(t[1]) - float(t[2])
		if d < best_d:
			best_d = d
			tower = t[0]
			c = t[1]
			foot = float(t[2])
	if tower == null:
		for b in main.stations.building_targets():
			var d2: float = me.distance_to(b[1]) - float(b[2])
			if d2 < best_d:
				best_d = d2
				bid = String(b[0])
				c = b[1]
				foot = float(b[2])
	var fire := tower == null and bid == "" and me.length() - 0.75 < best_d
	if fire:
		c = Vector3.ZERO
		foot = 0.75
	elif tower == null and bid == "":
		return false
	c.y = 0.0
	var away := me - c
	var dist := away.length()
	if dist - foot > sr:
		_goal = c + away / maxf(dist, 0.01) * (foot + sr - 0.4)       # walk in to its spot, no nearer
		return true
	_goal = global_position
	_face((c - me) / maxf(dist, 0.01), get_physics_process_delta_time(), 10.0)
	if _cd > 0.0:
		return true
	var tgt = tower
	if tower == null:
		var h := Target.new()
		h.main_ref = main
		h.kind = "fire" if fire else "building"
		h.id = bid
		h.global_position = c
		tgt = h
	_start_action("spit" if _ai == "pitcher" else "cast", tgt)
	return true


## A Puffball bursts: everything round it gets hurt (buildings, towers, barricades, the campfire, the cat), then it is
## gone.
func _burst() -> void:
	var r := float(info["burst_range"])
	var me := global_position
	Fx.shockwave(main, me, r + 0.3, Color(0.95, 0.65, 0.35))
	Fx.spores(main, me, r)
	Fx.kill(main, me + Vector3(0, 0.4, 0), _color)
	main.shake(0.3)
	for b in main.stations.building_targets():
		if me.distance_to(b[1]) - float(b[2]) < r:
			main.stations.hurt_building(String(b[0]), gate_damage)
	for h in main.defences.near(me, r + 1.0):
		h.hurt(gate_damage)
	if main.guardian != null:
		main.guardian.blast(me, r, gate_damage)
	if Vector2(me.x, me.z).length() < r + 0.8:
		main.fight.damage_fire(gate_damage, me)
	if _cat_reachable(r):
		main.player.hurt(me, damage)
	hp = 0.0
	_die()


## A Mole Sapper meets a barricade: it burrows under it and pops up on the other side.
func _start_dig() -> void:
	state = "dig"
	_act_t = 0.0
	_act_done = false
	var past: float = main.world.trail_progress(patch, global_position) + 3.0 if main.world.trails.size() > patch else 0.0
	_dig_to = main.world.trail_point(patch, past) if main.world.trails.size() > patch else global_position
	_play(_clip_or(["Dig", "Attack"]), 0.05)
	Fx.dust(main, global_position, 10, 1.2)
	Fx.text(main, global_position + Vector3(0, 1.4, 0), "Digging!", Color(0.85, 0.7, 0.5))


func _do_dig(delta: float) -> void:
	_act_t += delta
	if not _act_done and _act_t >= 0.8:
		_act_done = true
		_body.visible = false
		global_position = Vector3(_dig_to.x, 0, _dig_to.z)
		_last_pos = global_position
	if _act_t >= 1.5 and not _body.visible:
		_body.visible = true
		_play(_clip_or(["Emerge", "Idle"]), 0.05)
		Fx.dust(main, global_position, 12, 1.3)
	if _act_t >= 2.1:
		state = "walk"
		_think_t = 0.0


## Last Stand: no fire to put out, so every enemy goes for the cat. A hidden cat they cannot see: then they mill
## round the embers.
func _hunt(p, reach: float) -> void:
	if p.hp <= 0:
		_goal = global_position
		return
	if main.cat_hidden() and global_position.distance_to(p.global_position) > radius + 1.2:
		if _in_area():
			_goal = global_position                     # below ground: it waits where it is
			return
		var out := Vector3(global_position.x, 0, global_position.z)
		_goal = (out.normalized() if out.length() > 0.1 else Vector3.FORWARD) * 1.6
		return
	_goal = p.global_position
	state = "chase"
	if global_position.distance_to(_goal) < reach and _cd <= 0.0 and _cat_reachable(reach):
		_start_action("attack", p)


func _walk(delta: float, spd: float) -> void:
	var goal := _goal
	if not flyer and _in_area():
		# a Burrow's path bends: round the trees, not into them (checked 4 times a second; a clear line uses the live goal)
		_steer_t -= delta
		if _steer_t <= 0.0:
			_steer_t = 0.25
			var st: Vector3 = main.area.steer(global_position, _goal)
			_steer_on = st.distance_to(_goal) > 0.01
			_steer_to = st
		if _steer_on:
			goal = _steer_to
	var to := goal - global_position
	to.y = 0.0
	var d := to.length()
	var want := Vector3.ZERO
	if d > 0.05:
		var dir := to / d
		want = dir * minf(spd * delta, d)
		position += want
		_face(dir, delta, 8.0)
		_play("Run" if id == "raccoon" and anim and anim.has_animation("Run") else "Walk")
	else:
		_play("Idle")
	var before := position - want
	position = main.world.constrain(position, radius, true, flyer)
	# walked into a fence piece? hit it
	if not flyer and want.length() > 0.0005 and (position - before).length() < want.length() * 0.4 and _cd <= 0.0 and main.defences:
		var fence = main.defences.fence_hit(global_position, radius + 0.25)
		if fence != null and info.get("digs", false):
			_start_dig()
		elif fence != null:
			_start_action("attack", fence)


func _face(dir: Vector3, delta: float, rate: float) -> void:
	if dir.length_squared() > 0.0001:
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), 1.0 - exp(-rate * delta))


# ---------------------------------------------------------------- actions with a moment of impact
func _start_action(kind: String, tgt) -> void:
	state = kind
	_act_target = tgt
	_act_t = 0.0
	_act_done = false
	match kind:
		"attack":
			_act_len = maxf(_clip_len("Attack", float(info["attack_every"])), 0.4)
			_act_event = _event("Attack", "hit", _act_len * 0.45)
			_play("Attack", 0.08)
			_cd = float(info["attack_every"])
		"grab":
			_act_len = _clip_len("Grab", 0.6)
			_act_event = _event("Grab", "grab", 0.3)
			_play("Grab" if anim and anim.has_animation("Grab") else "Attack", 0.08)
		"slam":
			var c := _clip_or(["Slam", "Attack"])
			_act_len = maxf(_clip_len(c, 1.4), 0.9)
			_act_event = _event(c, "impact", _event(c, "hit", 0.7))
			_play(c, 0.1)
			_cd2 = float(mods.get("slam_every", info.get("slam_every", 5.0))) * _cdk()
			Fx.telegraph_ring(main, global_position, float(info["slam_range"]), _act_event)
		"spit":
			_act_len = maxf(_clip_len("Attack", 0.9), 0.7)
			_act_event = _event("Attack", "hit", _act_len * 0.5)
			_play("Attack", 0.08)
			_cd = float(info["attack_every"])
		"burst":
			_act_len = maxf(_clip_len("Attack", 1.0), 0.7)
			_act_event = _event("Attack", "hit", _act_len * 0.75)
			_play("Attack", 0.06)
			Fx.telegraph_ring(main, global_position, float(info["burst_range"]), _act_event, Color(0.95, 0.6, 0.3, 0.35))
		"drum":
			var c0 := _clip_or(["Drum", "Attack"])
			_act_len = maxf(_clip_len(c0, 1.0), 0.8) * 2.0
			_act_event = _event(c0, "beat", 0.25)
			_play(c0, 0.1)
			_cd4 = float(info["drum_every"])
		"heal", "cast", "orbs":
			var c := _clip_or(["Cast", "Attack"])
			_act_len = maxf(_clip_len(c, 1.0), 0.7)
			_act_event = _event(c, "cast", _event(c, "hit", _act_len * 0.5))
			_play(c, 0.08)
			if kind == "heal":
				_cd4 = float(info["heal_every"])
				Fx.telegraph_ring(main, global_position, float(info["heal_range"]), _act_event, Color(0.5, 1.0, 0.45, 0.3))
			elif kind == "orbs":
				_cd4 = float(info["orb_every"])
			else:
				_cd = float(info["attack_every"])
		"hex":
			var c := _clip_or(["Cast", "Attack"])
			_act_len = maxf(_clip_len(c, 1.0), 1.15)
			_act_event = 1.0
			_play(c, 0.08)
			_cd2 = float(info["hex_every"])
			_hex_at = main.player.global_position
			_hex_at.y = 0.0
			Fx.telegraph_ring(main, _hex_at, float(info["hex_range"]), 1.0, Color(0.8, 0.3, 1.0, 0.4))
			Fx.text(main, _hex_at + Vector3(0, 1.6, 0), "Hex!", Color(0.85, 0.5, 1.0))
		"summon":
			var c := _clip_or(["Roar", "Cast", "Attack"])
			_act_len = maxf(_clip_len(c, 1.2), 0.9)
			_act_event = _event(c, "roar", _act_len * 0.45)
			_play(c, 0.1)
			_cd3 = float(info.get("summon_every", 15.0))
		"spores":
			_act_len = maxf(_clip_len("Attack", 1.0), 0.6)
			_act_event = _event("Attack", "hit", _act_len * 0.45)
			_play("Attack", 0.08)
			_cd4 = 8.0
			_cd = float(info["attack_every"])
			Fx.telegraph_ring(main, global_position, 2.6, _act_event, Color(0.6, 0.9, 0.4, 0.3))
		"roar":
			_act_len = _clip_len("Roar", 1.5)
			_act_event = _event("Roar", "roar", 0.5)
			_play("Roar", 0.1)
			_cd3 = float(mods.get("roar_every", info.get("roar_every", 14.0))) * _cdk()
		"lob":
			var c := _clip_or(["Cast", "Attack"])
			_act_len = maxf(_clip_len(c, 1.0), 0.8)
			_act_event = _event(c, "cast", _act_len * 0.45)
			_play(c, 0.08)
			_cd = float(info.get("lob_every", 2.6))
		"bite":
			_act_len = float(info.get("bite_warn", 0.7)) + 0.4
			_act_event = float(info.get("bite_warn", 0.7))
			_play(_clip_or(["Windup", "Idle"]), 0.05)
			_cd = float(info["attack_every"])
			var fw := Vector3(sin(rotation.y), 0, cos(rotation.y))
			_charge_dir = fw
			Fx.telegraph_line(main, global_position, fw, float(info["reach"]), float(info.get("bite_width", 0.9)), _act_event, Color(1.0, 0.45, 0.3, 0.4))
	if anim and anim.current_animation != "" and _act_len > 0.0:
		anim.seek(0.0, true)


func _do_action(delta: float) -> void:
	_act_t += delta
	if typeof(_act_target) == TYPE_OBJECT and not is_instance_valid(_act_target):
		_act_target = null
	var tgt = _act_target
	if tgt is Node3D and is_instance_valid(tgt):
		var to: Vector3 = (tgt as Node3D).global_position - global_position
		to.y = 0.0
		_face(to.normalized(), delta, 10.0)
	elif tgt is String and tgt == "gate":
		_face((Vector3.ZERO - global_position).normalized(), delta, 10.0)
	elif tgt != null and is_instance_valid(tgt) and not (tgt is Node3D):
		_face(((tgt.global_position as Vector3) - global_position).normalized(), delta, 10.0)
	if not _act_done and _act_t >= _act_event:
		_act_done = true
		_impact()
	if _act_t >= _act_len:
		state = "walk"
		_power = false
		_think_t = 0.0


func _impact() -> void:
	if typeof(_act_target) == TYPE_OBJECT and not is_instance_valid(_act_target):
		_act_target = null
	var tgt = _act_target
	var reach := float(info["reach"]) + radius + 0.5
	var fwd := Vector3(sin(rotation.y), 0, cos(rotation.y))
	match state:
		"attack":
			Fx.swipe(main, global_position + Vector3(0, float(info["height"]) * 0.45, 0) + fwd * radius * 0.6, rotation.y,
				float(info["reach"]) + radius + 0.25, Color(1.0, 0.85, 0.6) if not _power else Color(0.85, 0.55, 1.0))
			Fx.hit(main, global_position + fwd * (radius + 0.4) + Vector3(0, 0.3, 0), _color)
			Fx.dust(main, global_position + fwd * (radius + 0.3), 5, 1.0 + radius)
			if tgt is String and tgt == "gate":
				main.fight.damage_fire(gate_damage, global_position)
			elif tgt == main.player:
				if _cat_reachable(reach + (0.8 if _power else 0.0)):
					main.player.hurt(global_position, int(round(damage * (2 if _power else 1) * (1.0 + buff if buff_t > 0.0 else 1.0))))
					main.shake(0.12 if not _power else 0.3)
			elif tgt is Object and tgt == main.guardian:
				if main.guardian.reachable_from(global_position, float(info["reach"]) + radius):
					main.guardian.hurt(int(maxi(gate_damage, 4) * (1.0 + buff if buff_t > 0.0 else 1.0)))
			elif tgt != null and is_instance_valid(tgt) and tgt.has_method("hurt"):
				tgt.hurt(int(maxi(gate_damage, 4) * float(info.get("siege", 1.0)) * (1.0 + buff if buff_t > 0.0 else 1.0)))
		"grab":
			if tgt != null and is_instance_valid(tgt) and not tgt.taken:
				carried += tgt.steal()
				Fx.text(main, global_position + Vector3(0, 1.3, 0), "Stolen!", Color(1.0, 0.55, 0.3))
				Fx.smoke(main, global_position)
				_boost_t = 1.4
		"spores":
			Fx.spores(main, global_position, 2.6)
			main.shake(0.12)
			if _cat_reachable(2.8):
				main.player.hurt(global_position, damage)
				main.player.slow_t = 1.8
				Fx.text(main, main.player.global_position + Vector3(0, 1.5, 0), "Slowed!", Color(0.7, 1.0, 0.5))
		"slam":
			Fx.shockwave(main, global_position, float(info["slam_range"]))
			Fx.dust(main, global_position, 18, 2.5)
			Fx.hit(main, global_position + Vector3(0, 0.3, 0), Color(0.55, 0.8, 0.3))
			main.shake(0.35)
			if _cat_reachable(float(info["slam_range"])):
				main.player.hurt(global_position, int(round(damage * float(mods.get("slam_mult", 1.0)))))
			if enraged and mods.has("enrage_ring"):
				_second_ring()
			for f in main.defences.near(global_position, float(info["slam_range"])):
				f.hurt(gate_damage)
			if main.guardian != null:
				main.guardian.blast(global_position, float(info["slam_range"]), gate_damage)
		"spit":
			var b := BoltScript.new()
			main.add_child(b)
			var mouth := float(meta["mouth_height_m"]) * _scale if meta.has("mouth_height_m") else float(info.get("height", 1.0)) * 0.75
			var from: Vector3 = global_position + Vector3(0, mouth, 0) + Vector3(sin(rotation.y), 0, cos(rotation.y)) * (radius + 0.1)
			if tgt == main.player:
				var aim: Vector3 = main.player.global_position + Vector3(0, 0.55, 0)
				b.launch(main, from, aim - from, float(info["bolt_speed"]), damage, Color(0.55, 0.85, 0.3), true, null, 0.0, 0.1, 2.0)
			elif tgt != null and is_instance_valid(tgt):
				b.launch(main, from, (tgt.global_position as Vector3) + Vector3(0, 0.7, 0) - from, float(info["bolt_speed"]), float(gate_damage),
					Color(0.55, 0.85, 0.3), false, null, 0.0, 0.1, 3.0)
				b.struct_target = tgt
		"burst":
			_burst()
			return
		"drum":
			Fx.shockwave(main, global_position, float(info["drum_range"]), Color(1.0, 0.75, 0.4))
			Fx.text(main, global_position + Vector3(0, float(info["height"]) + 0.3, 0), "Boom! Boom!", Color(1.0, 0.75, 0.45))
			for f in get_tree().get_nodes_in_group("foes"):
				if not f.dead and f.global_position.distance_to(global_position) < float(info["drum_range"]):
					f.buff = float(info["drum_buff"])
					f.buff_t = float(info["drum_time"])
					Fx.sparkle(main, f.global_position + Vector3(0, f.aim_height * 2.0, 0))
		"heal":
			var amt := float(info["heal"]) * mult
			Fx.shockwave(main, global_position, float(info["heal_range"]), Color(0.5, 1.0, 0.45))
			for f in get_tree().get_nodes_in_group("foes"):
				if f.dead or f.global_position.distance_to(global_position) > float(info["heal_range"]):
					continue
				if f.hp < f.max_hp:
					f.hp = minf(f.max_hp, f.hp + amt)
					Fx.number(main, f.global_position + Vector3(0, f.aim_height * 2.0 + 0.3, 0), amt, Color(0.5, 1.0, 0.5))
					Fx.sparkle(main, f.global_position + Vector3(0, f.aim_height, 0))
		"cast":
			if tgt != null and tgt != main.player and is_instance_valid(tgt):
				_bolt_at(tgt)                            # a tower, a building or the campfire, from afar (Phase F)
			else:
				_bolt(0.0, 0.6)
		"orbs":
			var n := int(info.get("orbs", 3))
			for k in n:
				_bolt((float(k) - (n - 1) * 0.5) * 0.45, 1.4)
			main.shake(0.1)
		"hex":
			Fx.shockwave(main, _hex_at, float(info["hex_range"]), Color(0.8, 0.35, 1.0))
			Fx.spores(main, _hex_at, float(info["hex_range"]) * 0.8)
			main.shake(0.25)
			var cat: Vector3 = main.player.global_position
			if Vector2(cat.x - _hex_at.x, cat.z - _hex_at.z).length() < float(info["hex_range"]):
				main.player.hurt(_hex_at, damage)
		"summon":
			main.shake(0.2)
			Fx.wind_aura(self, 0.9, 1.4)
			Fx.text(main, global_position + Vector3(0, float(info["height"]) + 0.5, 0), "Hoo-hoo!" if id == "owl" else "ROAR!", Color(0.85, 0.5, 1.0))
			for k in int(info.get("summon", 3)):
				var a := TAU * k / float(info.get("summon", 3)) + randf()
				var mk := String(info.get("minion", "moth"))
				var at := global_position + Vector3(cos(a), 0, sin(a)) * 1.5
				if _in_area():
					main.area.spawn(mk, at, {"summon": true, "emerge": mk == "grub"})
				else:
					main.fight.spawn(mk, at, patch)
		"lob":
			# a spore bomb at the cat's spot, where it will be a moment from now
			var lead: Vector3 = main.player.get("vel") if main.player.get("vel") != null else Vector3.ZERO
			var spot: Vector3 = main.player.global_position + lead * float(info.get("lob_lead", 0.5))
			spot.y = 0.0
			if _in_area():
				spot = main.area.constrain(spot, 0.3, false)
				main.area.strike(spot, float(info.get("lob_radius", 1.1)), float(info.get("lob_warn", 1.1)), damage, float(info.get("slow_s", 2.0)))
		"bite":
			Fx.swipe(main, global_position + Vector3(0, 0.6, 0) + _charge_dir * radius, rotation.y, float(info["reach"]), Color(0.9, 0.7, 0.4))
			var cp: Vector3 = main.player.global_position - global_position
			cp.y = 0.0
			var along := cp.dot(_charge_dir)
			var side := (cp - _charge_dir * along).length()
			if main.player.hp > 0 and along > -0.2 and along < float(info["reach"]) + 0.3 and side < float(info.get("bite_width", 0.9)) * 0.5 + 0.3:
				main.player.hurt(global_position, damage)
				main.shake(0.15)
		"roar":
			main.shake(0.25)
			Fx.shockwave(main, global_position, 4.5, Color(0.85, 0.55, 1.0))
			Fx.wind_aura(self, 0.8, 1.6)
			Fx.text(main, global_position + Vector3(0, 3.2, 0), "ROAR!", Color(0.85, 0.5, 1.0))
			var nm := int(mods.get("roar_minions", info.get("roar_minions", 3)))
			for k in nm:
				var a := TAU * k / float(nm) + randf()
				var at := global_position + Vector3(cos(a), 0, sin(a)) * 1.6
				if enraged and k < int(mods.get("enrage_gloom_adds", 0)) and _in_area():
					main.area.spawn(String(info.get("minion", "thornling")), at, {"summon": true, "gloomtouched": true})
				else:
					main.fight.spawn(String(info.get("minion", "thornling")), at, patch)


func _do_charge(delta: float) -> void:
	_act_t += delta
	var step := _charge_dir * float(info["charge_speed"]) * delta
	var before := global_position
	position += step
	_face(_charge_dir, delta, 20.0)
	if int(_t * 20.0) % 2 == 0:
		Fx.dust(main, global_position - _charge_dir * radius, 3, 1.2)
	# the cat
	var p = main.player
	if p.hp > 0 and not main.world.inside_camp(p.global_position) and p.global_position.distance_to(global_position) < radius + 0.4:
		p.hurt(global_position, damage * 2)
		Fx.shockwave(main, global_position + _charge_dir * radius, 1.6, Color(1.0, 0.7, 0.4))
		Fx.hit(main, p.global_position + Vector3(0, 0.5, 0), Color(1.0, 0.5, 0.4))
		main.shake(0.3)
		_end_charge()
		return
	# the Moss Warden stands its ground: the charge stops there
	var g = main.guardian
	if g != null and g.up() and global_position.distance_to(g.global_position) < radius + float(g.radius) + 0.2:
		g.hurt(gate_damage)
		g.blocked(global_position)
		_end_charge(true)
		return
	# a fence or the gate
	var fence = main.defences.fence_hit(global_position, radius + 0.3)
	if fence != null:
		fence.hurt(int(info.get("fence_damage", 100)))
		Fx.shockwave(main, global_position + _charge_dir * radius, 1.6, Color(0.8, 0.6, 0.4))
		main.shake(0.2)
		_end_charge(true)
		return
	position = main.world.constrain(position, radius, true)
	if _in_area():
		if global_position.distance_to(before + step) > 0.05:
			_daze_long(float(Data.burrow_cfg()["daze_on_block_s"]))   # into a pillar or a wall: dazed, a weak spot
			return
		if _act_t > float(info.get("charge_time", 1.4)):
			_end_charge(true)
		return
	if global_position.distance_to(before + step) > 0.05:
		# rammed something solid: a building or a tower takes the blow
		for b in main.stations.building_targets():
			if global_position.distance_to(b[1]) < float(b[2]) + radius + 0.6:
				main.stations.hurt_building(String(b[0]), gate_damage)
				main.shake(0.25)
				break
		for t in main.defences.tower_targets():
			if global_position.distance_to(t[1]) < float(t[2]) + radius + 0.6:
				t[0].hurt(gate_damage)
				main.shake(0.2)
				break
		_end_charge(true)
		return
	if _act_t > float(info.get("charge_time", 1.4)) or global_position.length() > main.world.WOODS_R + 2.0:
		_end_charge(true)


## The charge is over: a short pause. A boar whose charge did not hit the cat (`missed`) is dazed instead (Phase F);
## a boss that charges (the Thornstag) only pauses.
func _end_charge(missed := false) -> void:
	if missed and not boss and _ai == "boar":
		_miss_daze()
		return
	state = "daze"
	_act_t = 0.0
	_cd2 = float(info.get("charge_every", 4.0))
	_play("Idle")


# ---------------------------------------------------------------- specials
## Thornling pounce: a hop at the cat that lands with a splash. The same move is the Gloom Moth's dive (arc < 0) and
## the Beetle Knight's shield bash (arc 0: a quick shove along the ground).
func _start_pounce(at: Vector3, max_d := 2.6, arc := 0.65, dur := 0.45) -> void:
	state = "pounce"
	_act_t = 0.0
	_arc = arc
	_dur = dur
	_from = global_position
	var d := at - _from
	d.y = 0.0
	_to = _from + d.limit_length(max_d)
	_cd4 = randf_range(3.5, 5.0)
	_play("Attack", 0.05)
	if not flyer:
		Fx.dust(main, global_position, 4, 0.7)


func _do_pounce(delta: float) -> void:
	_act_t += delta
	var t := clampf(_act_t / _dur, 0.0, 1.0)
	var p := _from.lerp(_to, t)
	p.y = sin(PI * t) * _arc
	global_position = p
	_face((_to - _from).normalized(), delta, 14.0)
	if t >= 1.0:
		global_position.y = 0.0
		position = main.world.constrain(position, radius, true, flyer)
		if not flyer:
			Fx.dust(main, global_position, 7, 1.0)
		Fx.hit(main, global_position + Vector3(0, 0.2 + fly_h * 0.5, 0), _color)
		if _cat_reachable(0.9 + (0.3 if _power else 0.0)):
			main.player.hurt(global_position, damage)
			main.shake(0.1 if not _power else 0.22)
		_power = false
		state = "walk"
		_cd = float(info["attack_every"]) * 0.5


## Mossback's Gloom Dash: wind gathers round it, a line on the ground shows where it will go, then it rushes the cat
## and swipes on arrival with double damage.
func _start_dash() -> void:
	state = "dash_windup"
	_act_t = 0.0
	var to_cat: Vector3 = main.player.global_position - global_position
	to_cat.y = 0.0
	_charge_dir = to_cat.normalized()
	_cd4 = float(mods.get("dash_every", info.get("dash_every", 8.0))) * _cdk()
	_play("Roar" if anim and anim.has_animation("Roar") else "Idle", 0.1)
	Fx.wind_aura(self, 1.8, radius * 1.4)
	Fx.telegraph_line(main, global_position, _charge_dir, minf(to_cat.length() + 1.0, 9.0), radius * 1.8, 1.0, Color(0.75, 0.35, 1.0, 0.35))
	Fx.text(main, global_position + Vector3(0, float(info["height"]) + 0.4, 0), "!!", Color(0.9, 0.5, 1.0))


func _do_dash(delta: float) -> void:
	_act_t += delta
	var step := _charge_dir * 9.0 * delta
	var before := global_position
	position += step
	_face(_charge_dir, delta, 20.0)
	if fmod(_act_t, 0.07) < delta:
		Fx.dust(main, global_position - _charge_dir * radius, 4, 1.6)
	var fence = main.defences.fence_hit(global_position, radius + 0.3)
	if fence != null:
		fence.hurt(150)
		Fx.shockwave(main, global_position + _charge_dir * radius, 2.2, Color(0.8, 0.55, 1.0))
		main.shake(0.3)
		_end_dash()
		return
	position = main.world.constrain(position, radius, true)
	var reach := float(info["reach"]) + radius + 0.3
	var blocked := global_position.distance_to(before + step) > 0.05
	if blocked and _in_area() and not _cat_reachable(reach):
		_daze_long(float(Data.burrow_cfg()["daze_on_block_s"]))       # the Gloom Dash ends in a pillar or a wall
		return
	if _cat_reachable(reach) or blocked or _act_t > 0.8:
		_end_dash()


func _end_dash() -> void:
	_power = true
	_start_action("attack", main.player)
	_cd = float(info["attack_every"])


## A Burrow boss's cooldowns: shorter once it is enraged.
func _cdk() -> float:
	return float(mods.get("enrage_cd", 1.0)) if enraged else 1.0


## A Burrow boss at low health (mods.enrage_at): faster, its cooldowns shorter, a red wind, at once a roar for help, and
## from now on each slam sends a second, wider ring a moment later.
func _enrage() -> void:
	enraged = true
	speed *= float(mods.get("enrage_speed", 1.3))
	_cd3 = minf(_cd3, 0.8)
	_cd4 = minf(_cd4, 2.0)
	Props.set_param(_body, "gloom", 0.5)
	Fx.wind_aura(self, 2.5, radius * 1.7)
	Fx.text(main, global_position + Vector3(0, float(info["height"]) + 0.6, 0), "ENRAGED!", Color(1.0, 0.4, 0.3))
	main.shake(0.35)
	if _in_area() and main.area.has_method("boss_enraged"):
		main.area.boss_enraged(self)


## Enraged: the slam's second ring, wider, a moment after the first (step out of it, or dash through it).
func _second_ring() -> void:
	var at := Vector3(global_position.x, 0.0, global_position.z)
	var r := float(info["slam_range"]) * float(mods.get("enrage_ring", 1.7))
	var warn := float(mods.get("enrage_ring_warn", 0.7))
	Fx.telegraph_ring(main, at, r, warn, Color(1.0, 0.45, 0.25, 0.4))
	get_tree().create_timer(warn).timeout.connect(_ring_now.bind(at, r))


func _ring_now(at: Vector3, r: float) -> void:
	if dead or main.frozen:
		return
	Fx.shockwave(main, at, r, Color(1.0, 0.55, 0.3))
	main.shake(0.3)
	var p = main.player
	if p.hp > 0 and Vector2(p.global_position.x - at.x, p.global_position.z - at.z).length() < r:
		p.hurt(at, int(round(damage * float(mods.get("slam_mult", 1.0)))))


## A Gloom bolt at the cat (Frog Shaman, Owl Witch's orbs), `turn` radians off the aim.
func _bolt(turn: float, homing: float) -> void:
	var fwd := Vector3(sin(rotation.y), 0, cos(rotation.y))
	var from := global_position + Vector3(0, float(info["height"]) * 0.6, 0) + fwd * (radius + 0.15)
	var aim: Vector3 = main.player.global_position + Vector3(0, 0.55, 0)
	var d := (aim - from).rotated(Vector3.UP, turn)
	var b := BoltScript.new()
	main.add_child(b)
	b.launch(main, from, d, float(info.get("bolt_speed", 5.0)), damage, Color(0.78, 0.35, 1.0), true, main.player if homing > 0.0 else null, homing, 0.13, 3.2)


## Phase F: a Gloom bolt at a tower, a building or the campfire (a Frog Shaman's siege from afar). It flies home to it
## and hurts it by the frog's gate damage.
func _bolt_at(tgt) -> void:
	var fwd := Vector3(sin(rotation.y), 0, cos(rotation.y))
	var from := global_position + Vector3(0, float(info["height"]) * 0.6, 0) + fwd * (radius + 0.15)
	var spd := maxf(float(info.get("bolt_speed", 5.0)), 0.5)
	var b := BoltScript.new()
	main.add_child(b)
	b.launch(main, from, (tgt.global_position as Vector3) + Vector3(0, 0.7, 0) - from, spd, float(gate_damage),
		Color(0.78, 0.35, 1.0), false, null, 0.0, 0.13, (float(info.get("siege_range", 8.0)) + 4.0) / spd)
	b.struct_target = tgt


## The Owl Witch vanishes in a puff of feathers and comes out of another next to the cat.
func _start_blink() -> void:
	state = "blink"
	_act_t = 0.0
	_act_done = false
	_cd5 = float(info.get("blink_every", 9.0))
	Fx.smoke(main, global_position)
	Fx.kill(main, global_position + Vector3(0, 1.0, 0), Color(0.6, 0.4, 0.85))
	var a := randf() * TAU
	var to: Vector3 = main.player.global_position + Vector3(cos(a), 0, sin(a)) * 3.0
	_blink_to = main.world.constrain(to, radius, true)
	_body.visible = false


func _do_blink(delta: float) -> void:
	_act_t += delta
	if not _act_done and _act_t >= 0.45:
		_act_done = true
		global_position = _blink_to
		_last_pos = global_position
		_body.visible = true
		Fx.smoke(main, global_position)
		Fx.shockwave(main, global_position, 1.6, Color(0.8, 0.45, 1.0))
		Fx.boing(_body, 0.3)
		var to: Vector3 = main.player.global_position - global_position
		to.y = 0.0
		if to.length() > 0.01:
			rotation.y = atan2(to.x, to.z)
	if _act_t >= 0.8:
		state = "walk"
		_think_t = 0.0


func _stride(delta: float) -> void:
	# rigged walkers lean into their stride and kick up a little dust as they go
	var moved := global_position - _last_pos
	moved.y = 0.0
	_last_pos = global_position
	var v := moved.length() / maxf(delta, 0.0001)
	var lean := clampf(v * 0.045, 0.0, 0.2) if state in ["walk", "chase", "flee", "charge", "dash"] else 0.0
	model.rotation.x = lerpf(model.rotation.x, lean, 1.0 - exp(-8.0 * delta))
	_step_d += moved.length()
	var step_len := maxf(0.45, radius * 1.6)
	if _step_d > step_len:
		_step_d = 0.0
		if v > 0.4 and not flyer and global_position.distance_to(main.player.global_position) < 11.0:
			Fx.dust(main, global_position, 2 if id == "thornling" else 3, 0.5 + radius)


func _do_flee(delta: float, spd: float) -> void:
	if _in_area():
		state = "walk"                              # nowhere to flee below ground
		return
	var out: Vector3 = main.world.spawn_point(patch, 0.0)
	var to := out - global_position
	to.y = 0.0
	if to.length() < 1.0:
		main.fight.on_escaped(self)
		queue_free()
		return
	var dir := to.normalized()
	position += dir * spd * 1.15 * delta
	_face(dir, delta, 10.0)
	_play("Run")
	position = main.world.constrain(position, radius, true)


# ---------------------------------------------------------------- Phase F: the Golden Grub and the Gloom Totem
## A block of balance.json "mission" ({} when it is not there).
func _mcfg(key: String) -> Dictionary:
	var m: Dictionary = Data.b.get("mission", {})
	return m.get(key, {})


## The Golden Grub: it never attacks. It picks another road's woods to run for, which way round the camp, and how far
## out from the fire it runs.
func _grub_setup() -> void:
	var g := _mcfg("golden_grub")
	damage = 0
	life_t = float(g.get("life_s", 14.0))
	_shy_r = float(g.get("shy_r", 3.0))
	state = "chase"
	var w = main.world
	var n: int = Data.patch_count()
	var to := 0
	if n > 1:
		var from: int = patch if patch >= 0 and patch < n else w.patch_of(global_position)
		if from < 0:
			to = randi() % n
		else:
			to = randi() % (n - 1)
			if to >= from:
				to += 1                                  # any road but its own
	_run_a = deg_to_rad(float(Data.patch(to)["angle_deg"]))
	var sweep := wrapf(_run_a - atan2(global_position.x, -global_position.z), -PI, PI)
	if absf(sweep) > 0.05 and absf(sweep) < PI - 0.3:
		_run_dir = signf(sweep)                        # the short way round
	else:
		_run_dir = 1.0 if randf() < 0.5 else -1.0      # the road across the camp: either way
	_run_r = clampf(float(w.camp_r) + randf_range(2.5, 5.0), float(w.camp_r) + 2.0, w.WOODS_R - 4.0)
	_run_in = false
	_run_out = false


## The Golden Grub scurries in from the woods, round the camp at _run_r, then out into its road's woods. It never steps
## into the firelight, veers away from a cat within _shy_r m (not a hidden one), and once life_t runs out it makes for
## the nearest woods. In the woods it is gone (_grub_away).
func _do_grub(delta: float, spd: float) -> void:
	state = "chase"
	life_t -= delta
	var w = main.world
	var me := Vector3(global_position.x, 0, global_position.z)
	var r := me.length()
	if r < w.WOODS_R - 0.5:
		_run_in = true
	if r > w.WOODS_R + 0.8 and (_run_in or life_t <= 0.0):
		_grub_away()
		return
	var a := atan2(me.x, -me.z)
	var goal: Vector3
	if life_t <= 0.0:
		goal = me / maxf(r, 0.01) * (w.WOODS_R + 2.0)                 # time is up: into the nearest woods
	else:
		var left := fposmod((_run_a - a) * _run_dir, TAU)             # how far round it still has to go
		if _run_in and (left < 0.4 or left > TAU - 0.3):
			_run_out = true
		if _run_out:
			goal = Vector3(sin(_run_a), 0, -cos(_run_a)) * (w.WOODS_R + 2.0)
		else:
			var ca := a + _run_dir * 0.55                            # a point a little further round the run
			goal = Vector3(sin(ca), 0, -cos(ca)) * _run_r
	var dir := goal - me
	dir /= maxf(dir.length(), 0.01)
	var p = main.player
	if p.hp > 0 and not main.cat_hidden():
		var off: Vector3 = me - Vector3(p.global_position.x, 0, p.global_position.z)
		var dc := off.length()
		if dc < _shy_r and dc > 0.01:
			var side := Vector3(-off.z, 0, off.x) / dc                # round the cat, the side it was going anyway
			if side.dot(dir) < 0.0:
				side = -side
			dir = (dir + (off / dc + side) * (2.0 * (1.0 - dc / _shy_r) + 0.5)).normalized()
	position += dir * spd * delta
	_face(dir, delta, 10.0)
	_play("Run" if anim and anim.has_animation("Run") else "Walk")
	# never into the firelight; round buildings and the lake (it slips under barricades)
	var keep: float = float(w.camp_r) + radius + 0.3
	var q := Vector2(position.x, position.z)
	if q.length() < keep:
		q = q / maxf(q.length(), 0.01) * keep
		position.x = q.x
		position.z = q.y
	if q.length() < w.MOVE_R - 0.4:
		position = w.constrain(position, radius, false)


## The Golden Grub reached the woods: gone, quietly (no pay, nothing counted).
func _grub_away() -> void:
	dead = true
	remove_from_group("enemies")
	remove_from_group("foes")
	remove_from_group("bonus")
	main.hud.toast("The Golden Grub got away!")
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 0.02, 0.25)
	tw.tween_callback(queue_free)


## A Gloom Totem: it never moves or attacks. It grows with a puff of Gloom.
func _totem_setup() -> void:
	add_to_group("totems")
	damage = 0
	state = "totem"
	_home = Vector3(global_position.x, 0, global_position.z)
	_scan_t = 0.0
	Fx.shockwave(main, _home, 1.4, Color(0.75, 0.4, 1.0))


## The Gloom Totem's look until the owner decides on a model: Gloom crystals from the props (a tall shard over a cluster
## at its foot), tinted violet and glowing faintly, and a faint violet ring on the ground as far as its Gloom reaches
## (mission.totem.radius). The ring hangs on the totem itself, not on _body, so hit flashes leave it alone.
func _totem_look() -> void:
	_body = Node3D.new()
	add_child(_body)
	_pulse = Node3D.new()
	_body.add_child(_pulse)
	var h := float(info["height"])
	var spire: Node3D
	if Props.has("gloom_shard"):
		spire = Props.instance("gloom_shard")                      # 0.12 m wide, 0.18 m high, on its lower tip
		spire.scale = Vector3(h * 3.3, h / 0.18 * 0.9, h * 3.3)
	else:
		spire = Props.instance("gloom_crystal")                    # a cluster 0.55 m high
		spire.scale = Vector3(1.6, h / 0.55, 1.6)
	_pulse.add_child(spire)
	for k in 4:
		var cr := Props.instance("gloom_crystal")
		var a := TAU * k / 4.0 + 0.5
		cr.position = Vector3(cos(a), 0, sin(a)) * 0.3
		cr.rotation = Vector3(0.3 * sin(k * 2.3), k * 1.9, 0.3 * cos(k * 1.7))
		cr.scale = Vector3.ONE * (1.25 if k % 2 == 0 else 0.95)
		_pulse.add_child(cr)
	Props.set_param(_body, "tint", Color(0.88, 0.72, 1.0))
	Props.set_param(_body, "glow", 0.7)
	if _ring_mat == null:
		_ring_mat = StandardMaterial3D.new()
		_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ring_mat.albedo_color = Color(0.72, 0.42, 1.0, 0.38)
	var r := float(_mcfg("totem").get("radius", 4.0))
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = maxf(r - 0.1, 0.1)
	tm.outer_radius = maxf(r, 0.2)
	tm.rings = 48
	tm.ring_segments = 3
	ring.mesh = tm
	ring.material_override = _ring_mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.scale = Vector3(1.0, 0.3, 1.0)
	ring.position.y = 0.05
	add_child(ring)


## The Gloom Totem stands where it grew (the crowd's pushing never moves it) and breathes slowly. A few times a second it
## strengthens every other foe within its reach for a moment (totem_t): faster and tougher. Not bonus runners.
func _do_totem(delta: float) -> void:
	global_position = _home
	if _pulse != null:
		_pulse.scale = Vector3.ONE * (1.0 + 0.05 * sin(_t * 2.4))
	_scan_t -= delta
	if _scan_t > 0.0:
		return
	_scan_t = 0.3
	var cfg := _mcfg("totem")
	var r := float(cfg.get("radius", 4.0))
	var sb := float(cfg.get("speed_buff", 0.25))
	var ar := clampf(float(cfg.get("armor", 0.25)), 0.0, 0.9)
	for f in get_tree().get_nodes_in_group("foes"):
		if f == self or f.dead or f.is_in_group("totems") or f.is_in_group("bonus"):
			continue
		var d: Vector3 = f.global_position - _home
		if d.x * d.x + d.z * d.z < r * r:
			f.totem_t = 0.5
			f.totem_buff = sb
			f.totem_armor = ar


## A Gloom Totem broken: a burst of Gloom, and the foes round it lose its strength at once (another totem near them
## gives its own back at its next look).
func _totem_burst() -> void:
	var at := Vector3(global_position.x, 0, global_position.z)
	Fx.shockwave(main, at, 2.6, Color(0.75, 0.4, 1.0))
	Fx.text(main, at + Vector3(0, float(info["height"]) + 0.4, 0), "Shattered!", Color(0.85, 0.6, 1.0))
	main.shake(0.2)
	var r := float(_mcfg("totem").get("radius", 4.0)) + 0.5
	for f in get_tree().get_nodes_in_group("foes"):
		if not f.dead and Vector2(f.global_position.x - at.x, f.global_position.z - at.z).length() < r:
			f.totem_t = 0.0


# ---------------------------------------------------------------- getting hit
func hit(direction: Vector3, amount := 10.0) -> void:
	last_dealt = 0.0
	if dead or state == "blink" or ((state == "dig" or state == "emerge") and not _body.visible):
		return
	if has_meta("squad_leader") and main.player != null:
		# Phase G1b: the cat attacks it from close by (squad_rules.hit_break_r): it fights back on its own
		var pc: Vector3 = main.player.global_position
		if Vector2(pc.x - global_position.x, pc.z - global_position.z).length() < float(_squad_rules().get("hit_break_r", 4.0)):
			leave_squad()
	if info.has("shield_block") and amount > 0.0 and not (state in ["attack", "pounce", "daze"]):
		var fwd := Vector3(sin(rotation.y), 0, cos(rotation.y))
		var incoming := -direction
		incoming.y = 0.0
		if incoming.length() > 0.01 and fwd.dot(incoming.normalized()) > cos(deg_to_rad(float(info.get("shield_cone_deg", 65.0)))):
			amount *= 1.0 - float(info["shield_block"])
			Fx.hit(main, global_position + fwd * (radius + 0.1) + Vector3(0, aim_height, 0), Color(0.75, 0.9, 1.0))
			if _block_t <= 0.0:
				_block_t = 0.7
				Fx.text(main, global_position + Vector3(0, float(info["height"]) + 0.35, 0), "Block!", Color(0.65, 0.9, 1.0))
	if _vuln_t > 0.0:
		amount *= _vuln_k                               # dazed by a pillar or a missed charge: the weak spot
	if bellow_t > 0.0:
		amount *= 1.0 + bellow_k                        # G4: shaken by a mount's Bellow
	if totem_t > 0.0:
		amount *= 1.0 - totem_armor                     # a Gloom Totem nearby (Phase F)
	if not awake:
		wake()
	hp -= amount
	last_dealt = maxf(amount, 0.0)
	if not enraged and mods.has("enrage_at") and hp > 0.0 and hp <= max_hp * float(mods["enrage_at"]):
		_enrage()
	_hit_flash = 0.12
	Sfx.play("hit", -9.0, 0.05)
	Fx.hit(main, global_position + Vector3(0, aim_height, 0), _color)
	if amount > 0.0:
		Fx.number(main, global_position + Vector3(0, aim_height * 2.0 + 0.3, 0), amount, Color(1, 1, 1) if amount < max_hp * 0.5 else Color(1, 0.85, 0.3))
	if id == "raccoon" and carried > 0 and _boost_t <= 0.0 and hp > 0.0:
		Fx.smoke(main, global_position)
		_boost_t = 1.2
	var solid := freeze_t > 0.0                         # 22 Nov 2026: frozen solid, a hit neither pushes it nor makes it flinch
	if not solid and not anchored and not boss and state != "charge" and state != "dash" and state != "pounce":
		var push := direction
		push.y = 0.0
		_knock = push.normalized() * (0.8 if id in ["brute", "snail", "beetle"] else 2.4)
	if solid:
		pass
	elif anim == null:
		Fx.boing(_body, 0.15)
	elif not boss and (state == "walk" or state == "chase") and anim.has_animation("Hit") and amount >= max_hp * 0.3:
		_play("Hit", 0.05)
		state = "daze"
		_act_t = 0.55
	if hp <= 0.0:
		_die()


# ---------------------------------------------------------------- G3: Ember fire
## Sets it burning (an Ember arrow's hit, arrow.gd): for `seconds` it takes `per_s` damage every second (per_s is the
## bow's share_per_s x that hit's damage). A new hit restarts the burn with the new numbers; the tick keeps its rhythm.
## Bosses burn too. Burn damage is the cat's damage like an arrow's: a kill by fire pays the same (_die).
func ignite(seconds: float, per_s: float) -> void:
	if dead or seconds <= 0.0 or per_s <= 0.0:
		return
	if burn_t <= 0.0:
		_burn_acc = 0.0
	burn_t = seconds
	burn_per_s = per_s
	_burn_look(true)


## The burn's frame time (clamped, and not called while the game is frozen): one tick of burn_per_s each whole second;
## when it runs out, the part of a second left over hurts its share, so a full burn deals seconds x per_s.
func _burn_tick(dt: float) -> void:
	var step := minf(dt, burn_t)
	burn_t -= step
	_burn_acc += step
	while _burn_acc >= 1.0 and not dead:
		_burn_acc -= 1.0
		_burn_hurt(burn_per_s)
	if burn_t <= 0.0:
		burn_t = 0.0
		if _burn_acc > 0.001 and not dead:
			_burn_hurt(burn_per_s * _burn_acc)
		_burn_acc = 0.0
		_burn_look(false)


func _burn_hurt(amount: float) -> void:
	if dead or amount <= 0.0:
		return
	if bellow_t > 0.0:
		amount *= 1.0 + bellow_k                        # G4: shaken by a mount's Bellow
	hp -= amount
	burn_dealt += amount
	burn_ticks += 1
	_hit_flash = maxf(_hit_flash, 0.06)
	if amount >= 0.5:
		Fx.number(main, global_position + Vector3(0, aim_height * 2.0 + 0.3, 0), amount, Color(1.0, 0.6, 0.25))
	if not enraged and mods.has("enrage_at") and hp > 0.0 and hp <= max_hp * float(mods["enrage_at"]):
		_enrage()
	if hp <= 0.0:
		_die()


## The flames on a burning enemy (Fx.embers, a few rising sparks, scaled by the graphics level).
func _burn_look(on: bool) -> void:
	if on and (_burn_fx == null or not is_instance_valid(_burn_fx)):
		_burn_fx = Fx.flames(self, radius * 0.55, 10, 0.55, clampf(radius * 1.8, 0.3, 0.85))
		_burn_fx.position = Vector3(0, aim_height, 0)
	if _burn_fx != null and is_instance_valid(_burn_fx):
		_burn_fx.emitting = on


# ---------------------------------------------------------------- 22 Nov 2026: the Frost Bow's ice
## Chilled by an ice arrow (the Frost Bow; arrow.gd passes the bow's Data.bow_frost: slow, seconds, hits_to_freeze,
## freeze_s, boss_freeze_s). For `seconds` it moves and attacks `slow` slower (0.5: at half speed), with a frosty blue
## look; each hit starts the seconds again. The hits_to_freeze-th hit in a row while it is chilled freezes it solid for
## freeze_s (a boss, or anything on the boss bar, boss_freeze_s): it stands still and does nothing, icy and pale in an
## ice shell, then the count starts over. Hits while it is frozen keep it chilled for after but do not count. Its timers
## run on frame time and stop while the game is frozen (_physics_process). Never a Gloom Totem.
func chill(cfg: Dictionary) -> void:
	var secs := float(cfg.get("seconds", 0.0))
	if dead or secs <= 0.0 or _ai == "totem":
		return
	var was := chill_t > 0.0
	chill_t = secs
	chill_slow = clampf(float(cfg.get("slow", 0.0)), 0.0, 0.95)
	if freeze_t <= 0.0:
		chill_hits = (chill_hits + 1) if was else 1
		if chill_hits >= maxi(1, int(cfg.get("hits_to_freeze", 3))):
			chill_hits = 0
			var fs := float(cfg.get("boss_freeze_s" if is_boss() else "freeze_s", 0.0))
			if fs > 0.0:
				freeze_t = fs
				freezes += 1
				_knock = Vector3.ZERO
	_frost_look()


## A boss for the ice: a boss kind, or anything on the boss bar (a Burrow's boss, a raid's leader).
func is_boss() -> bool:
	return boss or (main != null and main.hud != null and main.hud.get("boss") == self)


## The ice's frame time (clamped by the caller): the freeze runs out, then the chill; the count is lost with the chill.
func _frost_tick(dt: float) -> void:
	freeze_t = maxf(0.0, freeze_t - dt)
	chill_t = maxf(0.0, chill_t - dt)
	if chill_t <= 0.0:
		chill_hits = 0
	_frost_look()


## A frame frozen solid: no step, no push, no clip; a pale icy sheen (and a hit's flash on top).
func _frozen_frame(delta: float) -> void:
	_knock = Vector3.ZERO
	_hit_flash = maxf(0.0, _hit_flash - delta)
	Props.set_param(_body, "flash", clampf(Fx.FROZEN_FLASH + _hit_flash * 8.0, 0.0, 1.0))
	if anim:
		anim.speed_scale = 0.0


## Its own tint without the ice's (a stand-in model's balance.json tint, a Gloom Totem's violet).
func _base_tint() -> Color:
	if info.has("tint"):
		return Color.html(String(info["tint"]))
	if _ai == "totem" and not ResourceLoader.exists("res://assets/enemies/%s/%s.glb" % [_model_id, _model_id]):
		return Color(0.88, 0.72, 1.0)
	return Color(1, 1, 1)


## The ice's look, changed only when it changes: chilled (a frosty blue tint and snow sparkles), frozen (paler and icy,
## an ice shell popping on), neither (its own colours; a thawing enemy's shell shatters).
func _frost_look() -> void:
	var want := 2 if freeze_t > 0.0 else (1 if chill_t > 0.0 else 0)
	if want == _frost_on or _body == null:
		return
	var was := _frost_on
	_frost_on = want
	var tint := _base_tint()
	Props.set_param(_body, "tint", tint * (Fx.FROZEN_TINT if want == 2 else (Fx.CHILL_TINT if want == 1 else Color(1, 1, 1))))
	if want > 0 and (_frost_fx == null or not is_instance_valid(_frost_fx)):
		_frost_fx = Fx.frost_motes(self, radius * 0.7, 6)
		_frost_fx.position = Vector3(0, aim_height, 0)
	if _frost_fx != null and is_instance_valid(_frost_fx):
		_frost_fx.emitting = want > 0
	if want == 2:
		if _ice == null or not is_instance_valid(_ice):
			_ice = Fx.ice_shell(self, radius, float(info.get("height", 0.6)))
			_ice.position.y = fly_h if flyer else 0.0
		Fx.hit_burst(main, global_position + Vector3(0, aim_height, 0), Vector3.FORWARD, {"hit": "ice", "hit_n": 10,
			"hit_colors": ["#FFFFFF", "#BFEAFF", "#7CC8F0"]})
		if anim:
			anim.speed_scale = 0.0
	elif was == 2:
		if _ice != null and is_instance_valid(_ice):
			_ice.queue_free()
		_ice = null
		Fx.shatter(main, global_position + Vector3(0, aim_height, 0), radius)
	Props.set_param(_body, "flash", [0.0, Fx.CHILL_FLASH, Fx.FROZEN_FLASH][want])   # (its frames keep it up, a hit's flash on top)


## Gone: the ice comes off at once (a frozen one shatters).
func _frost_clear() -> void:
	chill_t = 0.0
	freeze_t = 0.0
	chill_hits = 0
	_frost_look()


func _die() -> void:
	dead = true
	burn_t = 0.0
	_burn_look(false)
	_frost_clear()
	remove_from_group("enemies")
	remove_from_group("foes")
	remove_from_group("bonus")
	remove_from_group("totems")
	main.fight.on_enemy_died(self)
	if _in_area():
		main.area.on_enemy_died(self)               # in a Burrow: the run pays (leaves, amber, dew) and counts the fight
	else:
		var value := Data.saddlebag_leaves(int(info["leaves"]))
		if main.fight.active:
			value = roundi(value * float(Data.b["mission"]["enemy_leaf_mult"]))
		value += carried                           # returned stolen leaves are never multiplied
		main.drop_leaves(global_position, value)
	Sfx.play("pop", -6.0)
	Fx.kill(main, global_position + Vector3(0, aim_height, 0), _color)
	if _ai == "golden_grub":
		for k in 2:                                 # caught: a shower of gold
			Fx.sparkle(main, global_position + Vector3(0, 0.35 + 0.35 * k, 0))
		Fx.text(main, global_position + Vector3(0, float(info["height"]) + 0.5, 0), "Golden Grub!", Color(1.0, 0.85, 0.3))
	elif _ai == "totem":
		_totem_burst()
	Props.set_param(_body, "flash", 0.0)
	if flyer:
		create_tween().tween_property(_body, "position:y", 0.0, 0.35).set_ease(Tween.EASE_IN)
	if anim and anim.has_animation("Die"):
		_play("Die", 0.05)
		anim.speed_scale = 1.0
		var tw := create_tween()
		tw.tween_interval(maxf(_clip_len("Die", 1.0), 0.6) + 0.5)
		tw.tween_property(self, "position:y", -float(info["height"]) * 0.6, 0.6)
		tw.tween_callback(queue_free)
	else:
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector3(1.4, 0.2, 1.4), 0.12)
		tw.tween_property(self, "scale", Vector3.ONE * 0.02, 0.18)
		tw.tween_callback(queue_free)
