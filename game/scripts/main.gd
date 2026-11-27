extends Node3D
## Project LEAF. There is no menu: the game opens in the cat's camp, the safe home base. Tap a building (or the little
## badge over it, marker.gd) to use it: its card opens as a dialog, and the cat walks there first if it is out of reach
## (interact.gd). Tap the signpost to pick the woods to fight in. Outside the camp the Gloom's creatures come down the
## trails; the cat shoots by itself, as in the Cat Ranger prototype.
## This node builds everything in code and ties it together: world, cat, camera, camp, defences, fight and HUD.
## H1: the pickups come from Pools (pickup.gd POOL, _pickup); _ready makes the pools' first arrows, numbers, hit bursts
## and pickups ahead (balance.json "pools").

const PlayerScript := preload("res://scripts/player.gd")
const JoystickScript := preload("res://scripts/joystick.gd")
const WorldScript := preload("res://scripts/world.gd")
const StationsScript := preload("res://scripts/stations.gd")
const DefencesScript := preload("res://scripts/defences.gd")
const FightScript := preload("res://scripts/fight.gd")
const HudScript := preload("res://ui/hud/hud.gd")
const PickupScript := preload("res://scripts/pickup.gd")
const AutotestScript := preload("res://scripts/autotest.gd")
const PetScript := preload("res://scripts/pet.gd")
const MountScript := preload("res://scripts/mount.gd")
const EnemyGridScript := preload("res://core/enemy_grid.gd")
const NpcScript := preload("res://scripts/npc.gd")
const GuardianScript := preload("res://scripts/guardian.gd")
const GardenScript := preload("res://scripts/garden.gd")
const CookingScript := preload("res://scripts/cooking.gd")
const FishingScript := preload("res://scripts/fishing.gd")
const RaidsScript := preload("res://scripts/raids.gd")
const BurrowScript := preload("res://scripts/burrow.gd")
const MarkerScript := preload("res://scripts/marker.gd")
const InteractScript := preload("res://scripts/interact.gd")
const RideCommand := preload("res://commands/ride.gd")

const CAM_PITCH := 0.8727                         # 50 degrees down, as in the prototype
const CAM_FOV := 20.0                             # narrow lens across the short side of the screen
const CAM_DIST_CAMP := 21.5                       # pulled back in the camp: about 7.6 m of ground across
const CAM_DIST_FIGHT := 18.0                      # in a fight: about 6.3 m across
const CAM_LEAD := 0.9                             # the focus sits nearer the camera than the cat: the cat stands
                                                  # above the middle of the screen, clear of the thumb

var world
var player
var joystick
var stations
var defences
var fight
var hud
var cam: Camera3D
var frozen := false
var rings: Array = []                             # every marker (marker.gd): the things the cat can use
var interact                                      # taps: a marker's card, or the walk to it (interact.gd)
var closeup := Vector3.ZERO                       # the automated test can bring the camera in
var closeup_at: Node3D = null                     # ...and point it at something other than the cat
var _show_at := Vector3.ZERO                      # H4: show_spot: the spot the camera shows for a moment (a new building)
var _show_t := 0.0                                # ... and for how long more (0: it follows the cat)
var _cam_dist := CAM_DIST_CAMP
var _shake := 0.0
var _steps: Array = []                            # the cat's recent footsteps [position, age], for the grass
var _respawn_t := 0.0
var _ring_on = null                               # the marker whose card is open
var _last_ring = null                             # the last one opened (fishing's card comes back after a catch)
var _heal_t := 0.0
var hidden := false                               # the cat is in tall grass or a bush, and has not just shot
var ambush_ready := false                         # hidden long enough: the next shot is an Ambush (double damage)
var _hidden_for := 0.0
var hud_note := ""                                # a message for the player once the HUD exists
var _rebuild_t := 0.0                             # seconds the cat has stood on the ashes (Last Stand)
var pet: Node3D                                   # Sprig, once the pet is bought (H5: at the Market's Pets tab)
var mount: Node3D                                 # Thistle, once a mount is owned (it comes free with the Market)
var trader: Node3D                                # Bramble the hedgehog, the Market's trader (while the Market is built)
var guardian: Node3D                              # the Moss Warden, once the Guardian Stone is there (guardian.gd)
var garden: Node3D                                # the garden's plots and plants (garden.gd)
var cooking: Node                                 # the cooking pot's recipes and its timer job (cooking.gd)
var fishing: Node3D                               # fishing at the lake (fishing.gd)
var raids                                         # the Gloom Raids after every mission is won (raids.gd, Phase D)
var burrows: Node3D                               # the Burrows (burrow.gd, Phase E): the hollows in the camp, and the run
var area = null                                   # while the cat is below ground: main.burrows.runner (the area); else null
var _status_mine := false                         # the Last Stand's status line is this one's (it clears only its own)
var empowered_t := 0.0                            # Phase E: a close call (dashing through an attack): the next arrow hits double
var _heading = null                               # the marker the cat is walking to (full size), and for how long more
var _heading_t := 0.0
var enemy_grid = null                             # H6: who is near where (core/enemy_grid.gd); made first in _ready
const RING_NEAR := 3.2                            # markers nearer than this show full size; the rest small and dim


func _ready() -> void:
	enemy_grid = EnemyGridScript.new()            # H6: first, before the world, the fight and the defences use it
	Sfx.init(self)
	world = Node3D.new()
	world.set_script(WorldScript)
	add_child(world)
	world.build(self)
	fight = Node.new()
	fight.set_script(FightScript)
	fight.main = self
	add_child(fight)
	raids = Node.new()
	raids.set_script(RaidsScript)
	raids.main = self
	add_child(raids)
	var ui := CanvasLayer.new()
	ui.layer = 5
	add_child(ui)
	joystick = Control.new()
	joystick.set_script(JoystickScript)
	ui.add_child(joystick)
	joystick.flicked.connect(_on_flick)
	player = Node3D.new()
	player.set_script(PlayerScript)
	player.main = self
	add_child(player)
	player.global_position = Vector3(0, 0, world.camp_r * 0.42)
	player.facing = PI
	MarkerScript.cat = player
	interact = Node.new()
	interact.set_script(InteractScript)
	interact.main = self
	add_child(interact)
	defences = Node3D.new()
	defences.set_script(DefencesScript)
	add_child(defences)
	defences.build(self)
	garden = Node3D.new()                         # Phase C: before the stations, whose cards ask it
	garden.set_script(GardenScript)
	add_child(garden)
	garden.setup(self)
	cooking = Node.new()
	cooking.set_script(CookingScript)
	add_child(cooking)
	cooking.setup(self)
	fishing = Node3D.new()
	fishing.set_script(FishingScript)
	add_child(fishing)
	fishing.setup(self)
	stations = Node3D.new()
	stations.set_script(StationsScript)
	stations.main = self
	add_child(stations)
	stations.build(self)
	enemy_grid.add(stations.dummy)                # H6: the dummy is registered first, as it is first in group order
	burrows = Node3D.new()                        # Phase E: after the stations (its card asks them), before the HUD
	burrows.set_script(BurrowScript)
	add_child(burrows)
	burrows.build(self)
	hud = CanvasLayer.new()
	hud.set_script(HudScript)
	hud.layer = 4
	add_child(hud)
	hud.build(self)
	fishing.build_ui(hud)
	Quality.stepped_down.connect(func(): hud.toast("Graphics lowered to %s for smoother play" % Quality.NAMES[Quality.level]))
	if Save.fire_ruined:
		world.set_fire_out(true)
		stations.set_fire_out(true)
	if hud_note != "":
		hud.tip(hud_note, null)
	cam = Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.fov = CAM_FOV
	cam.far = 120.0
	add_child(cam)
	cam.current = true
	refresh_companions()
	if Save.riding and mount != null:
		set_riding(true, false)
	stations.catch_up_gifts()                     # an older save gets the gifts of missions it already won
	_update_camera(1.0, true)
	if Save.stages_won == 0 and not Save.flag("first_stage_done"):
		hud.tip("Tap the signpost to defend the camp.", stations.rings["sign"])
	raids.refresh_open()
	raids.call_deferred("restore_on_load")       # a pending Gloom Raid comes back at its warning
	burrows.check_open(true)                      # a save that already won every mission: the Old Hollow opens soon
	burrows.call_deferred("check_saved_run")      # a saved run that no longer fits the game is closed kindly
	_check_home_ready()                           # Phase F: knows whether the home's goals are met (no toast at start)
	# H1: the pools' first objects, made now so the first fight makes none (balance.json "pools", by graphics level)
	player.prewarm_arrows()
	Fx.prewarm()
	Pools.prewarm(PickupScript.POOL, _new_pickup, Pools.size_for("pickups"))
	if Data.args().has("--autotest"):
		var t := Node.new()
		t.set_script(AutotestScript)
		t.main = self
		add_child(t)


# ---------------------------------------------------------------- every frame
func _process(delta: float) -> void:
	if frozen:
		return
	empowered_t = maxf(0.0, empowered_t - minf(delta, 0.1))
	raids.tick(delta)
	_update_camera(delta)
	_update_rings()
	if joystick.vector != Vector2.ZERO:
		hud.hide_hint()
	_update_hiding(delta)
	# rest in camp: the cat heals
	if player.hp > 0 and player.hp < Data.cat_max_hp() and world.inside_camp(player.global_position):
		_heal_t += delta
		if _heal_t > 0.8:
			_heal_t = 0.0
			player.hp += 1
			hud.refresh_hp()
			Fx.text(self, player.global_position + Vector3(0, 1.4, 0), "+1", Color(0.5, 1.0, 0.5))
	if _respawn_t > 0.0:
		_respawn_t -= delta
		if _respawn_t <= 0.0:
			player.revive(Vector3(0.6, 0, 1.4))
			hud.refresh_hp()
	_update_grass(delta)
	_update_rebuild(delta)


## Any touch, drag or key: the player is here (the Gloom meter fills only while someone is playing). Nothing is consumed.
func _input(event: InputEvent) -> void:
	if raids == null:
		return
	if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed) \
			or event is InputEventScreenDrag or (event is InputEventKey and event.pressed):
		raids.touch()


## The app pauses, loses focus or closes: the Gloom Raids save what they have (never a time). On a phone, a paused app
## is frozen until it comes back.
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			if raids:
				raids.persist()
			if burrows:
				burrows.persist()                         # a run below ground keeps the cat's health
			frozen = true
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST:
			if raids:
				raids.persist()
			if burrows:
				burrows.persist()
		NOTIFICATION_APPLICATION_RESUMED:
			frozen = false


func _physics_process(_delta: float) -> void:
	if frozen:
		return
	var foes := get_tree().get_nodes_in_group("foes")
	for i in foes.size():                                  # keep enemies from standing inside each other
		var a = foes[i]
		for j in range(i + 1, foes.size()):
			var b = foes[j]
			var d: Vector3 = b.position - a.position
			d.y = 0.0
			var need: float = (a.radius + b.radius) * 0.9
			var dist := d.length()
			if dist < need and dist > 0.0001:
				var push := d / dist * (need - dist) * 0.5
				if a.state != "charge":
					a.position -= push
				if b.state != "charge":
					b.position += push
	for f in foes:                                         # H6: the grid learns where the separation put them
		enemy_grid.move(f)


## H4: the camera glides to `at` (a building just built from the build menu, build_menu_window.gd), holds it there,
## then follows the cat again, `hold` seconds in all (the glide is today's smoothing, about 0.45 s, the time Fx.rise
## waits). The cat keeps control the whole time; the shot ends at once when the joystick moves, a wave is on or the
## cat goes below ground (_update_camera).
func show_spot(at: Vector3, hold := 2.2) -> void:
	_show_at = at
	_show_t = maxf(hold, 0.0)


func _update_camera(delta: float, snap := false) -> void:
	# H4: show_spot's shot counts down. It ends at once when the player moves the joystick, when a wave is on (a Raid
	# Mission's wave or a Random Raid's attack, which sends no wave_started: fight.in_wave is set only then, so a wave
	# is never watched from a building) or when the cat is below ground. Counted here, before the test's closeup,
	# which it never moves.
	if _show_t > 0.0:
		if joystick.vector != Vector2.ZERO or fight.in_wave or area != null:
			_show_t = 0.0
		else:
			_show_t = maxf(0.0, _show_t - delta)
	if closeup != Vector3.ZERO:
		cam.fov = 26.0
		var c: Vector3 = closeup_at.global_position if closeup_at != null and is_instance_valid(closeup_at) else player.global_position
		cam.global_position = c + closeup
		cam.look_at(c + Vector3(0.0, 0.6, 0.0))
		return
	cam.fov = CAM_FOV
	var outside: bool = fight.active or not world.camp_view(player.global_position)   # the buildings round the fire are camp too
	var want_dist: float = CAM_DIST_FIGHT if outside else CAM_DIST_CAMP
	if area != null:
		want_dist = area.cam_dist()                     # Phase E: the Burrows show a whole room, walls and all
	_cam_dist = want_dist if snap else lerpf(_cam_dist, want_dist, 1.0 - exp(-2.0 * delta))
	var focus: Vector3 = _show_at if _show_t > 0.0 else player.global_position   # H4: show_spot's spot, for a moment
	focus.y = 0.0
	focus.z += CAM_LEAD
	if area != null:
		focus = area.cam_focus(player.global_position)
	elif focus.length() > 16.5:
		focus = focus.normalized() * 16.5
	var want := focus + Vector3(0.0, sin(CAM_PITCH), cos(CAM_PITCH)) * _cam_dist
	cam.position = want if snap else cam.position.lerp(want, 1.0 - exp(-6.0 * delta))
	cam.rotation = Vector3(-CAM_PITCH, 0.0, 0.0)
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 1.5)
		cam.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake * 0.25


## The Leaf Dash works below ground only (burrows.dash.everywhere turns it on everywhere).
func dash_enabled() -> bool:
	return area != null or bool(Data.burrow_cfg()["dash"].get("everywhere", false))


func _on_flick(dir: Vector2) -> void:
	if frozen or not dash_enabled():
		return
	player.dash(dir)


## The camera jumps to where it should be (after the cat is moved into or out of the Burrows).
func snap_camera() -> void:
	_update_camera(1.0, true)


## Hiding: tall grass and bushes hide the cat (outside the camp). Enemies don't see a hidden cat unless they walk
## right into it. Shooting gives the cat away for a moment; after 1.5 s hidden, the next shot is an Ambush.
func _update_hiding(delta: float) -> void:
	var spot = world.hide_at(player.global_position) if player.hp > 0 and not player.riding and not world.inside_camp(player.global_position) else null
	if area != null:
		spot = area.hide_at(player.global_position) if player.hp > 0 and not player.riding else null   # ferns below ground
	var now: bool = spot != null and player.reveal_t <= 0.0
	if now != hidden:
		hidden = now
		player.set_hidden_look(now)
		if now and not Save.flag("told_hide"):
			Save.set_flag("told_hide")
			hud.tip("Hidden! Enemies can't see you in tall grass and bushes. Wait a moment: your next shot is an Ambush.", null)
	if hidden:
		_hidden_for += delta
		if _hidden_for > 1.5 and not ambush_ready:
			ambush_ready = true
			Fx.sparkle(self, player.global_position + Vector3(0, 1.2, 0))
	else:
		_hidden_for = 0.0
		if spot == null:
			ambush_ready = false


func cat_hidden() -> bool:
	return hidden


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


## Nothing opens by walking near any more (19 Nov 2026): a card opens when the player taps its marker (interact.gd,
## open_ring). Here the open card's marker is kept in step: the dialog closed by its X, a tap outside or the game, or
## the marker gone, or the cat moved well out of reach (a knock-back, a respawn).
func _update_rings() -> void:
	_ring_glow()
	if _ring_on == null:
		return
	if not is_instance_valid(_ring_on):
		_ring_on = null
		hud.hide_card()
		return
	if hud.card_ring() != _ring_on:
		_ring_on.set_active(false)
		_ring_on = null
		return
	var far: bool = Vector2(_ring_on.global_position.x - player.global_position.x, _ring_on.global_position.z - player.global_position.z).length() 		> _ring_on.reach() + 1.0
	if not _ring_on.is_visible_in_tree() or player.hp <= 0 or far:
		_ring_on.set_active(false)
		_ring_on = null
		hud.hide_card()


## Opens a marker's card as a dialog (a tap on it within reach, or the cat arriving where a tap sent it).
func open_ring(r) -> void:
	if r == null or not is_instance_valid(r) or not r.is_visible_in_tree() or player.hp <= 0:
		return
	if _ring_on != null and is_instance_valid(_ring_on) and _ring_on != r:
		_ring_on.set_active(false)
	_ring_on = r
	_last_ring = r
	r.set_active(true)
	hud.show_card(r)


## Only the markers near the cat (within RING_NEAR), the one it is walking toward and the one a tip points at show full
## size; the others are small and dim (marker.gd).
func _ring_glow() -> void:
	var p: Vector3 = player.global_position
	var joy: Vector2 = joystick.vector
	_heading_t = maxf(0.0, _heading_t - get_process_delta_time())
	if joy.length() > 0.2:
		var dir := Vector3(joy.x, 0.0, joy.y).normalized()
		var best := 0.94
		var pick = null
		for r in rings:
			if not is_instance_valid(r) or not r.visible:
				continue
			var to: Vector3 = r.global_position - p
			to.y = 0.0
			var d := to.length()
			if d < 0.3 or d > 12.0:
				continue
			var a := dir.dot(to / d) - d * 0.004                # nearer wins a close call
			if a > best:
				best = a
				pick = r
		if pick != null:
			_heading = pick
			_heading_t = 1.2
	if _heading_t <= 0.0:
		_heading = null
	var tipped = hud.tip_ring() if hud != null else null
	for r in rings:
		if not is_instance_valid(r):
			continue
		var near: bool = Vector2(r.global_position.x - p.x, r.global_position.z - p.z).length() < RING_NEAR \
			or r == _heading or r == tipped
		r.set_near(near)


## The last card comes back if the cat is still within its reach (fishing, after a catch).
func reopen_ring() -> void:
	if _last_ring != null and is_instance_valid(_last_ring) and _last_ring.in_reach(player.global_position):
		open_ring(_last_ring)


func register_ring(r) -> void:
	rings.append(r)


func unregister_ring(r) -> void:
	rings.erase(r)
	if _last_ring == r:
		_last_ring = null
	if interact != null and interact.walking == r:
		interact.stop_walk()
	if _ring_on == r:
		_ring_on = null
		hud.hide_card()


## The grass parts round the cat and springs back behind it: each spot the cat has passed keeps pushing for about a
## second, fading like a spring (it swings a little past upright, then settles). Enemies push too.
func _update_grass(delta: float) -> void:
	if area != null:
		return                                              # no grass below ground
	var p: Vector3 = player.global_position
	for st in _steps:
		st[1] += delta
	while not _steps.is_empty() and _steps[_steps.size() - 1][1] > 1.1:
		_steps.pop_back()
	if _steps.is_empty() or (_steps[0][0] as Vector3).distance_to(p) > 0.14:
		_steps.push_front([p, 0.0])
		if _steps.size() > 11:
			_steps.pop_back()
	var list: Array = [Vector4(p.x, 1.0, p.z, 0.8)]
	for st in _steps:
		var age: float = st[1]
		if age < 0.04:
			continue
		var spring := exp(-4.2 * age) * cos(7.5 * age)
		list.append(Vector4(st[0].x, spring, st[0].z, 0.78))
	if player.riding:
		list[0] = Vector4(p.x, 1.0, p.z, 1.1)
	if guardian and guardian.visible:
		var g: Vector3 = guardian.global_position
		list.append(Vector4(g.x, 1.0, g.z, 0.9))
	for e in get_tree().get_nodes_in_group("foes"):
		if list.size() >= 24:
			break
		if e.flyer:
			continue
		var q: Vector3 = e.global_position
		if q.distance_to(p) < 12.0:
			list.append(Vector4(q.x, 1.0, q.z, float(e.radius) + 0.5))
	world.grass.set_pushers(list)


# ---------------------------------------------------------------- what the cat shoots at
## The nearest foe within max_dist of from (or the Training Target's dummy when the cat stands in its ring and no foe is
## near). 22 Nov 2026: with `ahead` (a flat direction, the mount's heading while the cat rides) only those within
## `cone` radians either side of it count.
func nearest_enemy(from: Vector3, max_dist: float, ahead := Vector3.ZERO, cone := PI):
	var best = null
	var best_d := max_dist
	# H6: only the foes near enough to matter (a 3D distance within max_dist is also within it on the ground), in group
	# order, with the same tests and ties
	for e in enemy_grid.near(from, max_dist, &"foes"):
		if e.dead:
			continue
		var d: float = from.distance_to(e.global_position)
		if not e.awake and d > float(Data.burrow_cfg()["wake_r"]):
			continue                                    # Phase E: a sleeper far off is left asleep (walk up, or ambush it)
		if d < best_d and in_cone(from, e.global_position, ahead, cone):
			best_d = d
			best = e
	if best == null and stations.rings["target"].visible and stations.rings["target"].contains(player.global_position) \
			and in_cone(from, stations.dummy.global_position, ahead, cone):
		return stations.dummy
	return best


## 22 Nov 2026: whether `to` lies within `cone` radians either side of the flat direction `ahead`, seen from `from`
## (always when ahead is zero or the cone is a full turn).
static func in_cone(from: Vector3, to: Vector3, ahead: Vector3, cone: float) -> bool:
	if ahead == Vector3.ZERO or cone >= PI:
		return true
	var d := Vector3(to.x - from.x, 0.0, to.z - from.z)
	if d.length() < 0.001:
		return true
	return absf(wrapf(atan2(d.x, d.z) - atan2(ahead.x, ahead.z), -PI, PI)) <= cone


func target_ok(t) -> bool:
	if t == stations.dummy:
		return stations.rings["target"].contains(player.global_position)
	return true


func nearest_pickup(from: Vector3, max_dist: float):
	var best = null
	var best_d := max_dist
	for p in get_tree().get_nodes_in_group("pickups"):
		if p.taken or p._flying:
			continue
		var d: float = from.distance_to(p.global_position)
		if d < best_d:
			best_d = d
			best = p
	return best


# ---------------------------------------------------------------- leaves
func drop_leaves(at: Vector3, value: int) -> void:
	if value <= 0:
		return
	var n := clampi(int(ceil(value / float(Data.b["pickup_value"]))), 1, 6)
	var left := value
	for k in n:
		var v := left / (n - k)
		left -= v
		var p := _pickup()
		add_child(p)
		p.setup(self, v, at)


## H1: a pickup from the pickup pool (pickup.gd), to add and set up.
func _pickup() -> Node3D:
	return Pools.take(PickupScript.POOL, _new_pickup) as Node3D


## H1: a new pickup for the pool (made only when none is waiting), already wearing the leaf's model.
func _new_pickup() -> Node:
	var p: Node3D = PickupScript.new()
	p.wear()
	return p


## The Gloom shards a raid paid, shown flying to the cat (display only: they were banked at once). The HUD counter
## counts up as they land.
func drop_shards_fx(shards: int, at: Vector3) -> void:
	var n := mini(Quality.particles(8), shards / 3)
	if n <= 0:
		return
	hud.shards_held = shards
	call_deferred("_shard_shower", shards, n, at)        # after the raid's end has swept the field


func _shard_shower(shards: int, n: int, at: Vector3) -> void:
	var left := shards
	for k in n:
		var v := left / (n - k)
		left -= v
		var p := _pickup()
		add_child(p)
		p.setup(self, v, at, "shard")
		p.call_home_in(0.8)                             # H1: not if it is back in its pool and dropped again by then


func collect_shard_fx(v: int, at: Vector3) -> void:
	hud.shards_held = maxi(0, hud.shards_held - v)
	Fx.sparkle(self, at)
	raids.sfx("shard", "pickup", -8.0)


## Phase E: a material or a dew drop below ground, popping out at `at` (it flies to the cat like a leaf).
func drop_item(at: Vector3, kind: String, n: int) -> void:
	if n <= 0:
		return
	var p := _pickup()
	add_child(p)
	p.setup(self, n, at, kind)


## A dew drop (or a dew bud) heals the cat below ground.
func drink_dew(v: int, at: Vector3) -> void:
	player.hp = mini(player.hp + v, Data.cat_max_hp())
	Fx.text(self, player.global_position + Vector3(0, 1.5, 0), "+%d" % v, Color(0.5, 1.0, 0.5))
	Fx.sparkle(self, at)
	Sfx.play("pickup", -10.0, 0.05)
	hud.refresh_hp()


func collect_leaves(v: int, at: Vector3) -> void:
	Save.add_leaves(v)
	Fx.sparkle(self, at)
	Sfx.play("pickup", -12.0, 0.05)


# ---------------------------------------------------------------- what happens
func start_stage(i: int) -> void:
	hud.hide_card()
	fight.start_stage(i)


## The Last Stand: standing on the campfire's ashes rebuilds it (once a chapter, for timber). A hit starts it over.
func _update_rebuild(delta: float) -> void:
	var f = fight
	if not (f.active and f.last_stand and not f.rebuilt) or player.hp <= 0:
		_rebuild_t = 0.0
		if _status_mine:                                    # only the line this set (the spring's "Drinking..." is not)
			hud.status = ""
			_status_mine = false
		return
	_status_mine = true
	if Vector2(player.global_position.x, player.global_position.z).length() > stations.foot("campfire") + 0.65:
		_rebuild_t = 0.0
		hud.status = "Stand on the ashes to rebuild the campfire"
		return
	var cost: Dictionary = {"timber": int(Data.b["mission"]["rebuild_timber"])}
	if f.has_method("rebuild_cost"):
		cost = f.rebuild_cost()
	if not Data.can_afford(cost):
		hud.status = "You need %s to rebuild the fire" % _cost_text(cost)
		return
	var total := float(Data.b["mission"]["rebuild_s"])
	_rebuild_t += delta
	hud.status = "Rebuilding the campfire... %d%%" % int(clampf(_rebuild_t / total, 0.0, 1.0) * 100.0)
	if fmod(_rebuild_t, 0.4) < delta:
		Fx.sparkle(self, Vector3(0, 0.5, 0))
	if _rebuild_t >= total:
		_rebuild_t = 0.0
		hud.status = ""
		f.rebuild_fire()


func _cost_text(cost: Dictionary) -> String:
	var parts: Array = []
	for k in cost:
		parts.append("%d %s" % [int(cost[k]), String(k)])
	return ", ".join(parts)


func on_stage_start() -> void:
	player.hp = Data.cat_max_hp()
	hud.refresh()
	stations.refresh()
	if guardian:
		guardian.on_mission_start()
	if fishing:
		fishing.stop("")                                    # a mission starts: the line comes in
	var c: int = fight.chapter_of(fight.wave + 1)
	if c > 0:
		hud.banner(fight.title(), Color(1.0, 0.9, 0.5), "Raid %d · wave %d of %d" % [fight.mission + 1, fight.wave + 1, fight.waves()])
	else:
		hud.banner(fight.title(), Color(1.0, 0.9, 0.5), String(fight.info().get("intro", "Protect the camp!")))
	if not Save.flag("told_go_out"):
		Save.set_flag("told_go_out")
		hud.tip("Go out to meet them. The cat shoots by itself.", null)


## A wave starts: a banner for the first wave of a chapter, an elite wave and the last wave, a toast otherwise.
func on_wave_start(n: int, elite := false, last := false) -> void:
	if guardian:
		guardian.on_wave_start()
	if fishing:
		fishing.stop("")
	stations.refresh()
	if fight.mode == "raid":
		raids.on_wave_begins(n, last)                       # the raid's own banners ("They're here!", "Final push!")
		return
	var c: int = fight.chapter_of(n)
	if last:
		hud.banner("Last wave!", Color(1.0, 0.6, 0.45), "Wave %d of %d · %s" % [n, fight.waves(), fight.chapter_name(c)])
	elif elite:
		hud.banner("Elite wave!", Color(1.0, 0.7, 0.4), "Wave %d of %d · tougher foes" % [n, fight.waves()])
	elif n > 1 and (n - 1) % fight.chapter_waves() == 0:
		hud.banner("Wave %d of %d" % [n, fight.waves()], Color(1.0, 0.85, 0.5), fight.chapter_name(c))
	elif n > 1:
		hud.toast("Wave %d of %d" % [n, fight.waves()])


func on_wave_cleared() -> void:
	for p in get_tree().get_nodes_in_group("pickups"):      # what is left on the field flies to the cat
		p.call_home()
	if guardian:
		guardian.refill()                                   # the Moss Warden is back up and whole
	stations.refresh()
	Save.save_game()
	if fight.wave == 1 and not Save.flag("told_horn"):
		Save.set_flag("told_horn")
		hud.tip("Wave saved! Spend your golden leaves, then tap Start wave at the signpost. The next wave waits for you.", stations.rings["sign"])


## A chapter is held: the camp rests until the player goes on from the signpost (fight.gd saved the run).
func on_chapter_done() -> void:
	on_wave_cleared()
	if mount:
		mount.refill()                                      # the mount is up and whole again at a chapter break
	if not Save.flag("told_chapter"):
		Save.set_flag("told_chapter")
		hud.tip("Supply chest earned! Cleared waves stay cleared. Rest, shop and repair, then start the next wave at the signpost.", stations.rings["sign"])


func on_stage_end(_won: bool) -> void:
	for p in get_tree().get_nodes_in_group("pickups"):
		p.sweep()
	var raid: bool = fight.mode == "raid"                    # a Gloom Raid: no free mending, the damage stays
	if _won and not raid:
		defences.repair_all()
		if fight._endgame_run:
			stations.repair_all_free(fight._ruined_at_start)   # a replay never mends what a Gloom Raid left
		else:
			stations.repair_all_free()
	if guardian:
		guardian.on_mission_end()
	if fishing:
		fishing.stop("")
	if mount:
		mount.refill()
	stations.refresh()
	Save.save_game()
	if not raid:
		burrows.check_open()                            # the last mission's first win: the Old Hollow opens after the banners
	if _won and not raid and Data.progress() == 1 and not Save.flag("told_barricade"):
		Save.set_flag("told_barricade")
		hud.tip("Barricades are open! Tap a barricade spot on a road near the camp to build a row there: it blocks the way. More spots open as the Hearthtree grows.", null)
	# Phase F: the next act's first mission waits for a bigger home (told once, after the banners)
	var nxt := Data.next_mission()
	if _won and not raid and nxt < Data.mission_count() and not Data.mission_unlocked(nxt) and not Save.flag("told_home_goals"):
		Save.set_flag("told_home_goals")
		hud.tip_after_delay(3.6, "The next raid needs a bigger %s. Meet its goals, then grow it." % Data.camp_name().trim_prefix("the "), stations.rings["shop"])
	if _won and not raid:
		_check_home_ready()                             # "Win raid N" may have been the last goal
	hud.refresh_build()


## A Gloom Raid's warning starts (fight.start_raid): the cat is whole, everything shows the raid.
func on_raid_start(_spec: Dictionary) -> void:
	player.hp = Data.cat_max_hp()
	hud.refresh_hp()
	stations.refresh()


func on_purchase() -> void:
	Sfx.play("buy", -4.0)
	stations.refresh()
	hud.refresh()
	player.apply_bow()
	refresh_companions()
	_check_home_ready()


var _home_ready := -1                             # Phase F: the next home level's goals all met (1) or not (0); -1 not known yet


## A purchase (or a mission won) met the last goal on the Hearthtree's list: a toast says so (its badge shows its "!"
## when the price is affordable too).
func _check_home_ready() -> void:
	var nxt: int = Save.camp_level + 1
	var met: bool = nxt <= Data.building_levels("home").size() and (Data.progress() >= 1 or Save.camp_level > 1) \
		and Data.home_goals_met(nxt)
	if met and _home_ready == 0:
		hud.toast("Every goal met: %s can grow to level %d!" % [Data.camp_name(), nxt])
	_home_ready = 1 if met else 0


## The companions who have joined the camp come out (each only once). H5 (the map's part 3.3): each follows its own
## entitlement. The pet follows the pet's level (Data.pet_level() > 0: bought at the Market, or an old save's Mushroom
## Cottage), even in a camp with no Market; the mount follows ownership (Data.mount_level() > 0: a mount is owned, and
## the Market's come free with it) and waits by the Market; Bramble follows the built Market.
func refresh_companions() -> void:
	if pet == null and Data.pet_level() > 0:
		pet = Node3D.new()
		pet.set_script(PetScript)
		add_child(pet)
		pet.setup(self)
		Fx.flower_ring(self, player.global_position, 1.0)
	if mount == null and Data.mount_level() > 0:
		mount = Node3D.new()
		mount.set_script(MountScript)
		add_child(mount)
		mount.setup(self, stall_spot())
	if mount != null:
		mount.home = stall_spot()
	if trader == null and Data.station_level(StationsScript.MARKET) > 0:
		trader = Node3D.new()
		trader.set_script(NpcScript)
		add_child(trader)
		trader.setup(self, world.station_pos("stall") + Vector3(-1.45, 0, 0.35))
	if guardian == null and Data.guardian_level() > 0:
		guardian = Node3D.new()
		guardian.set_script(GuardianScript)
		add_child(guardian)
		var off: Array = Data.b["guardian"]["rest_offset"]
		guardian.setup(self, world.station_pos("stone") + Vector3(float(off[0]), float(off[1]), float(off[2])))
	if guardian:
		guardian.refresh_stats()
	hud.refresh_build()


func stall_spot() -> Vector3:
	return world.station_pos("stall") + Vector3(1.35, 0, 0.3)


## Up on Thistle, or back on the cat's own paws.
func set_riding(on: bool, show := true) -> void:
	if RideCommand.new(int(on), not show).run(self):
		stations.refresh()


func toggle_ride() -> void:
	if RideCommand.new().run(self):
		stations.refresh()


# H3 (26 Nov 2026, the owner's Q1 and Q2): Feed (2 Sunberries) and the food snacks below ground are gone. A Mount
# Health Potion brings a knocked-out mount back and Health Potions heal the cat; the HUD's potion buttons, the Bag's
# Use and the tests send the Use-potion command (commands/use_potion.gd, core/effects.gd).


## Back from the Burrows (burrow_run.gd _leave): the camp's cards and HUD, and a little Gloom on the meter (Phase D).
func on_area_left(_result: String) -> void:
	Events.area_changed.emit(false)
	stations.refresh()
	if raids != null:
		raids.add_gloom("burrow_run")


func on_camp_grown() -> void:
	world.rebuild_camp()
	defences.rebuild()                              # 22 Nov 2026: the pads and built rows follow the roads the bigger firelight reshaped
	stations.refresh("all")
	player.global_position = world.constrain(player.global_position, 0.3, false)
	var names: Array = Data.b["home_names"]
	hud.banner("%s grows!" % Data.camp_name(true), Color(1.0, 0.9, 0.4), "Level %d: %s · a bigger firelight" % [Save.camp_level,
		String(names[clampi(Save.camp_level - 1, 0, names.size() - 1)])])
	Fx.flower_ring(self, Vector3.ZERO, world.camp_r * 0.6)
	shake(0.2)
	on_purchase()
	# Phase G2: what opens at this level (the Market with Thistle; H5: the Mushroom Cottage is gone), told once, after
	# the banner
	var opened: Array = []
	for sid in [StationsScript.MARKET]:
		if int(Save.stations.get(sid, 0)) == 0 and Data.station_needs_home(sid) == Save.camp_level and Data.station_open(sid):
			opened.append(String(Data.building(sid)["name"]))
	if not opened.is_empty() and not Save.flag("told_market"):
		Save.set_flag("told_market")
		# H4 (the owner's Q17 (a)): building is in the build menu now, so the tip says where its icon is, with no arrow
		# (a tip can point only at a marker in the camp, never at a button)
		hud.tip_after_delay(3.0, Data.word("tip_build_new") % [Data.camp_name(), " and the ".join(opened)], null)


func on_player_hurt() -> void:
	_rebuild_t = 0.0
	hud.refresh_hp()
	shake(0.15)
	Fx.hit(self, player.global_position + Vector3(0, 0.6, 0), Color(1.0, 0.45, 0.4))
	Fx.number(self, player.global_position + Vector3(0, 1.5, 0), 1, Color(1.0, 0.4, 0.35))


func on_player_down() -> void:
	if area != null:
		area.cat_down()                                     # below ground: no respawn, the run ends (half the satchel kept)
		return
	_respawn_t = float(Data.b["cat"]["respawn_s"])
	set_riding(false)
	if fight.active and fight.last_stand:
		fight.cat_fell()                          # no campfire to come back to: the Gloom raids the camp
		return
	hud.banner("Knocked out!", Color(1.0, 0.6, 0.5), "Back at the gate in a moment")


func loss_hint() -> String:
	var dl := int(Save.stats["damage"])
	if Data.stat_cap("damage") > dl and dl < Data.stat_top("damage") and Data.can_afford(Data.stat_cost("damage", dl)):
		return "Your arrows could hit harder: try the Training Target."
	var bl := int(Save.bows[Save.bow])
	if bl < Data.bow_cap() and bl < Data.bow_top(Save.bow) and Data.can_afford(Data.bow_cost(Save.bow, bl)):
		return "Level up your bow at the Bow Shop."
	if Save.camp_level < Data.building_levels("home").size() and not Data.home_goals_met(Save.camp_level + 1):
		return "Spend your leaves on the goals at %s, then try again." % Data.camp_name()
	return "You kept your leaves. Upgrade and try again!"
