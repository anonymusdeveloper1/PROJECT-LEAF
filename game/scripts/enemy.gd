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
## H6 Stage 1 (27 Nov 2026): this script is the enemy's face to the rest of the game. Inside, it is built from parts
## (child nodes: Health, Armour, Mover, Attack, Heal, Status, Loot, HealthBar, Brain; parts/) and the Brain runs one small
## state script per `state` word (states/enemy/). The old private functions are one-line forwarders to the parts. All
## damage goes through _apply_damage (hit, burn and the thorn patches' hurt_spikes); the enemy grid (main.enemy_grid)
## is told where it is at the end of setup, after every frame, and when it dies or leaves the scene.
## H1 (the event board, Events): every hit that lands and every burn tick announce damage_dealt(self, amount); its
## health reaching 0 announces enemy_died(id, where), once per enemy (_die).

const SlimeScript := preload("res://scripts/slime.gd")
# H6 Stage 1 (27 Nov 2026, docs/ARCHITECTURE.md part 4): the parts an enemy is built from. Each is a child Node made at
# the top of setup() and bound to this enemy once; none has a process callback (this script calls them, so the frame
# order is unchanged). Their old private functions below are one-line forwarders, so tests keep their names.
const HealthPart := preload("res://parts/health.gd")
const ArmourPart := preload("res://parts/armour.gd")
const MoverPart := preload("res://parts/enemy_mover.gd")
const AttackPart := preload("res://parts/enemy_attack.gd")
const HealPart := preload("res://parts/enemy_heal.gd")
const StatusPart := preload("res://parts/status.gd")
const LootPart := preload("res://parts/enemy_loot.gd")
const HealthBarPart := preload("res://parts/health_bar.gd")
const BrainPart := preload("res://parts/enemy_brain.gd")
const TOTEM_GLOOM := 0.32                     # the faint violet a foe near a Gloom Totem shows (the shader's gloom)
static var _ring_mat: StandardMaterial3D      # a Gloom Totem's reach ring on the ground (one material for all)

enum CampApproach { NONE, DIRECT, TRAIL, ARRIVED }

var main
var id := "thornling"
var info: Dictionary
var meta: Dictionary = {}
var patch := 0
var mult := 1.0
# hp and max_hp live in the Health part once setup has made it (before that, in the plain fallbacks)
var _hp0 := 10.0
var _max_hp0 := 10.0
var hp: float:
	get:
		return _health.hp if _health != null else _hp0
	set(value):
		if _health != null:
			_health.set_hp(value)
		else:
			_hp0 = value
var max_hp: float:
	get:
		return _health.max_hp if _health != null else _max_hp0
	set(value):
		if _health != null:
			_health.set_max_hp(value)
		else:
			_max_hp0 = value
var _health: HealthPart                             # the parts (see setup); each is a child named like its role
var _armour: ArmourPart
var _mover: MoverPart
var _attack: AttackPart
var _heal: HealPart
var _status: StatusPart
var _loot: LootPart
var _bar: HealthBarPart
var _brain: BrainPart
var _grid                                     # main.enemy_grid, found by _the_grid()
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
var _camp_approach: CampApproach = CampApproach.NONE
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
var _act_trip := -1                           # H1: a grab's pickup drop (pickup.gd trip): pooled pickups are reused
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
var last_dealt := 0.0                         # G3: the damage the last hit() really did (after shields, dazes, totems, armour)
var last_raw := 0.0                           # H6: the damage the last hit() asked for after shields, dazes and totems, before armour
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


## `armoured`: false for a mission boss, a raid's leader and an expedition room's boss (the callers know; the entry's own
## boss flag is checked here too): they keep their plain health and damage. Anything else takes the armour share of its
## entry (parts.armour.share, none in Stage 1) off its health and its hits.
func setup(kind: String, patch_index: int, strength: float, armoured := true) -> void:
	_make_parts()                                   # first: every health write below goes through the Health part
	id = kind
	info = Data.enemy(kind)
	patch = patch_index
	mult = strength
	_model_id = String(info.get("model", kind))
	_scale = float(info.get("scale", 1.0))
	boss = bool(info.get("boss", false))
	var armour_cfg = (info.get("parts", {}) as Dictionary).get("armour", {})
	if armoured and not boss and armour_cfg is Dictionary:
		_armour.set_share(float((armour_cfg as Dictionary).get("share", 0.0)))
	max_hp = float(info["hp"]) * mult * _armour.factor()
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
	var grid = _the_grid()                          # H6: the enemy grid answers "who is near"; it knows this one from now on
	if grid != null:
		grid.add(self)


## The parts (see the consts above): made once, bound once, before the first health write.
func _make_parts() -> void:
	_health = _new_part(HealthPart, "Health") as HealthPart
	_armour = _new_part(ArmourPart, "Armour") as ArmourPart
	_mover = _new_part(MoverPart, "Mover") as MoverPart
	_attack = _new_part(AttackPart, "Attack") as AttackPart
	_heal = _new_part(HealPart, "Heal") as HealPart
	_status = _new_part(StatusPart, "Status") as StatusPart
	_loot = _new_part(LootPart, "Loot") as LootPart
	_bar = _new_part(HealthBarPart, "HealthBar") as HealthBarPart
	_brain = _new_part(BrainPart, "Brain") as BrainPart
	_health.hp = _hp0
	_health.max_hp = _max_hp0
	for part in [_mover, _attack, _heal, _status, _loot, _brain]:
		part.bind_enemy(self)
	_bar.bind_health(_health)
	_health.died.connect(_loot.on_died)             # the loot is worked out where _die emits `died`


func _new_part(script: GDScript, node_name: String) -> Node:
	var part := Node.new()
	part.set_script(script)
	part.name = node_name
	add_child(part)
	return part


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
	_mover.do_emerge(delta)


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
	_tick(delta)
	var grid = _the_grid()                              # H6: the grid learns where it is now, whichever way _tick ended
	if grid != null and not dead:
		grid.move(self)


## One physics frame of this enemy (the H5 _physics_process).
func _tick(delta: float) -> void:
	if dead or main.frozen:
		return
	var frame_dt := delta                               # unscaled by chill: the spikes' lingering slow runs on it
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
		_brain.sleep_step(delta)                        # the Sleep state: _sleep_tick
		return
	var contact_slow: float = main.defences.slow_at(global_position) if main.defences else 0.0
	_slow = _status.step_thorn_slow(contact_slow, frame_dt, _thorn_linger())
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
	spd = _brain.step(delta, spd)                    # the state for `state` runs (states/enemy/); the squad steering may change spd
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


## Seconds a thorn slow lingers after it steps off the patch: only once Deep thorns is learned (0 before, as in H5).
func _thorn_linger() -> float:
	if not Data.has_method("specialisation_level") or int(Data.specialisation_level("deep_thorns")) <= 0:
		return 0.0
	return float((Data.b.get("specialisations", {}) as Dictionary).get("deep_thorns", {}).get("linger_s", 0.0))


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
	_mover.wobble()


func _cat_reachable(range_m: float) -> bool:
	var p = main.player
	if p == null or p.hp <= 0 or main.world.inside_camp(p.global_position):
		return false
	var d: float = p.global_position.distance_to(global_position)
	if main.cat_hidden() and d > radius + 1.2:
		return false                      # hidden in the grass: they only find it by walking into it
	return d < range_m


## A Random Raid straggler takes one walk to the campfire, then goes back to its usual attacks.
func head_to_campfire() -> bool:
	if dead or _camp_approach != CampApproach.NONE:
		return false
	_camp_approach = CampApproach.DIRECT
	_think_t = 0.0
	if state == "flee":
		state = "walk"
	return true


func _trail_goal() -> Vector3:
	return main.world.trail_point(patch, s + 1.4) if patch >= 0 and main.world.trails.size() > patch else main.world.edge_point(clampi(patch, 0, 3))


## A Frog Shaman heals when its heal is ready and a wounded enemy is near. True when it started.
func _try_heal() -> bool:
	return _heal.try_heal()


## A Crow Drummer drums when its drum is ready and another enemy is near. True when it started.
func _try_drum() -> bool:
	return _heal.try_drum()


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
	_attack.burst()


## A Mole Sapper meets a barricade: it burrows under it and pops up on the other side.
func _start_dig() -> void:
	_mover.start_dig()


func _do_dig(delta: float) -> void:
	_mover.do_dig(delta)


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
	_mover.walk(delta, spd)


func _face(dir: Vector3, delta: float, rate: float) -> void:
	_mover.face(dir, delta, rate)


# ---------------------------------------------------------------- actions with a moment of impact
func _start_action(kind: String, tgt) -> void:
	_attack.start_action(kind, tgt)


func _do_action(delta: float) -> void:
	_attack.do_action(delta)


## H1: a grab's leaf that has gone back to its pool (picked up, swept) is out of the scene: the grab lets it go.
func _drop_pooled_grab() -> void:
	_attack.drop_pooled_grab()


func _impact() -> void:
	_attack.impact()


func _do_charge(delta: float) -> void:
	_mover.do_charge(delta)


## The charge is over: a short pause. A boar whose charge did not hit the cat (`missed`) is dazed instead (Phase F);
## a boss that charges (the Thornstag) only pauses.
func _end_charge(missed := false) -> void:
	_mover.end_charge(missed)


# ---------------------------------------------------------------- specials
## Thornling pounce: a hop at the cat that lands with a splash. The same move is the Gloom Moth's dive (arc < 0) and
## the Beetle Knight's shield bash (arc 0: a quick shove along the ground).
func _start_pounce(at: Vector3, max_d := 2.6, arc := 0.65, dur := 0.45) -> void:
	_mover.start_pounce(at, max_d, arc, dur)


func _do_pounce(delta: float) -> void:
	_mover.do_pounce(delta)


## Mossback's Gloom Dash: wind gathers round it, a line on the ground shows where it will go, then it rushes the cat
## and swipes on arrival with double damage.
func _start_dash() -> void:
	_mover.start_dash()


func _do_dash(delta: float) -> void:
	_mover.do_dash(delta)


func _end_dash() -> void:
	_mover.end_dash()


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
	_attack.second_ring()


func _ring_now(at: Vector3, r: float) -> void:
	_attack.ring_now(at, r)


## A Gloom bolt at the cat (Frog Shaman, Owl Witch's orbs), `turn` radians off the aim.
func _bolt(turn: float, homing: float) -> void:
	_attack.bolt(turn, homing)


## Phase F: a Gloom bolt at a tower, a building or the campfire (a Frog Shaman's siege from afar). It flies home to it
## and hurts it by the frog's gate damage.
func _bolt_at(tgt) -> void:
	_attack.bolt_at(tgt)


## The Owl Witch vanishes in a puff of feathers and comes out of another next to the cat.
func _start_blink() -> void:
	_mover.start_blink()


func _do_blink(delta: float) -> void:
	_mover.do_blink(delta)


func _stride(delta: float) -> void:
	_mover.stride(delta)


func _do_flee(delta: float, spd: float) -> void:
	_mover.do_flee(delta, spd)


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
	_mover.do_grub(delta, spd)


## The Golden Grub reached the woods: gone, quietly (no pay, nothing counted).
func _grub_away() -> void:
	_mover.grub_away()


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
	_status.do_totem(delta)


## A Gloom Totem broken: a burst of Gloom, and the foes round it lose its strength at once (another totem near them
## gives its own back at its next look).
func _totem_burst() -> void:
	_status.totem_burst()


# ---------------------------------------------------------------- getting hit
func hit(direction: Vector3, amount := 10.0) -> void:
	last_dealt = 0.0
	last_raw = 0.0
	if dead or state == "blink" or ((state == "dig" or state == "emerge") and not _body.visible):
		return
	if has_meta("squad_leader") and main.player != null:
		# Phase G1b: the cat attacks it from close by (squad_rules.hit_break_r): it fights back on its own
		var pc: Vector3 = main.player.global_position
		if Vector2(pc.x - global_position.x, pc.z - global_position.z).length() < float(_squad_rules().get("hit_break_r", 4.0)):
			leave_squad()
	var dealt := _apply_damage(direction, amount, "hit")
	last_dealt = dealt
	if dealt > 0.0:
		Events.damage_dealt.emit(self, dealt)
	_brain.check_enrage()
	_hit_flash = 0.12
	Sfx.play("hit", -9.0, 0.05)
	Fx.hit(main, global_position + Vector3(0, aim_height, 0), _color)
	if dealt > 0.0:
		Fx.number(main, global_position + Vector3(0, aim_height * 2.0 + 0.3, 0), dealt, Color(1, 1, 1) if dealt < max_hp * 0.5 else Color(1, 0.85, 0.3))
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
	elif not boss and (state == "walk" or state == "chase") and anim.has_animation("Hit") and dealt >= max_hp * 0.3:
		_play("Hit", 0.05)
		state = "daze"
		_act_t = 0.55
	if hp <= 0.0:
		_die()


## H6: the one place damage is worked out. `source` is "hit" (an arrow, a blow, a bolt, a blast), "burn" (an Ember tick) or
## "spikes" (a thorn patch's tick). In order: a hit meets the beetle's shield, then the daze's weak spot; a hit or a burn
## meets a mount's Bellow; a hit meets a Gloom Totem's shrug; the amount before armour is kept (last_raw, hits only);
## armour takes its share; a hit wakes a sleeper; then the Health part subtracts. Returns what was taken. It starts no
## effect of its own: the callers keep their own flash, sound, number, event, enrage and death.
func _apply_damage(direction: Vector3, amount: float, source: String) -> float:
	if source == "hit":
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
	if source != "spikes" and bellow_t > 0.0:
		amount *= 1.0 + bellow_k                            # G4: shaken by a mount's Bellow
	if source == "hit" and totem_t > 0.0:
		amount *= 1.0 - totem_armor                         # a Gloom Totem nearby (Phase F)
	var raw := maxf(amount, 0.0)
	if source == "hit":
		last_raw = raw
	amount = _armour.reduce(raw)
	if source == "hit" and not awake:
		wake()
	return _health.apply_damage(amount)


## A thorn patch's tick of damage (defences.gd): quiet, no flash, sound or number. A lethal tick ends in the same zero hit as
## before, so the kill still wakes it, flashes it and pays once.
func hurt_spikes(amount: float) -> void:
	if dead:
		return
	_apply_damage(Vector3.ZERO, amount, "spikes")
	if hp <= 0.0:
		hit(Vector3.ZERO, 0.0)


## A heal that is not a hit (the Frog Shaman's): `amount` is scaled by the armour factor, never past max health.
func heal_raw(amount: float) -> void:
	_health.heal(amount * _armour.factor())


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
	_status.burn_tick(dt)


func _burn_hurt(amount: float) -> void:
	if dead or amount <= 0.0:
		return
	amount = _apply_damage(Vector3.ZERO, amount, "burn")    # Bellow, armour, then the Health part
	burn_dealt += amount
	burn_ticks += 1
	Events.damage_dealt.emit(self, amount)
	_hit_flash = maxf(_hit_flash, 0.06)
	if amount >= 0.5:
		Fx.number(main, global_position + Vector3(0, aim_height * 2.0 + 0.3, 0), amount, Color(1.0, 0.6, 0.25))
	_brain.check_enrage()
	if hp <= 0.0:
		_die()


## The flames on a burning enemy (Fx.embers, a few rising sparks, scaled by the graphics level).
func _burn_look(on: bool) -> void:
	_status.burn_look(on)


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
	_status.frost_tick(dt)


## A frame frozen solid: no step, no push, no clip; a pale icy sheen (and a hit's flash on top).
func _frozen_frame(delta: float) -> void:
	_status.frozen_frame(delta)


## Its own tint without the ice's (a stand-in model's balance.json tint, a Gloom Totem's violet).
func _base_tint() -> Color:
	return _status.base_tint()


## The ice's look, changed only when it changes: chilled (a frosty blue tint and snow sparkles), frozen (paler and icy,
## an ice shell popping on), neither (its own colours; a thawing enemy's shell shatters).
func _frost_look() -> void:
	_status.frost_look()


## Gone: the ice comes off at once (a frozen one shatters).
func _frost_clear() -> void:
	_status.frost_clear()


## The enemy grid forgets this enemy (it died, or it leaves the scene).
func _grid_remove() -> void:
	var grid = _the_grid()
	if grid != null:
		grid.remove(self)


## main.enemy_grid (core/enemy_grid.gd), looked up once and kept; null when main has none (a bare test scene).
func _the_grid():
	if _grid == null or not is_instance_valid(_grid):
		_grid = main.get("enemy_grid") if main != null and is_instance_valid(main) else null
	return _grid


func _exit_tree() -> void:
	_grid_remove()


func _die() -> void:
	var first := not dead                           # H1: enemy_died goes out once per enemy
	dead = true
	burn_t = 0.0
	_burn_look(false)
	_frost_clear()
	remove_from_group("enemies")
	remove_from_group("foes")
	remove_from_group("bonus")
	remove_from_group("totems")
	_grid_remove()
	_brain.enter_down()
	main.fight.on_enemy_died(self)
	_health.died.emit()                             # the Loot part pays: a Burrow's run, or the leaves in the camp (enemy_loot.gd)
	if first:
		Events.enemy_died.emit(id, global_position)
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
