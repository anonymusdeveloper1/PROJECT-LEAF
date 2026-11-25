extends Node3D
## An arrow in flight. The asset's origin is the nock and its tip points along +Z.
## G3: each bow may have its own arrow, res://assets/cat/arrows/arrow_<bow id>.glb (the same frame: origin at the nock,
## tip along +Z); a bow without one shoots CatRanger_Arrow.glb as before. The nocked arrow on the cat's string is the
## same model (player.gd). An arrow from a bow with `burn` (the Ember Bow) sets each enemy it hits burning (enemy.gd
## ignite: share_per_s x the damage that hit did, every second, for seconds).
## 22 Nov 2026:
##   - an arrow from a bow with `frost` (the Frost Bow) chills each enemy it hits (enemy.gd chill: slower, and the 3rd
##     hit while chilled freezes it)
##   - each arrow's length (nock to tip) comes from its own model (the farthest point of its meshes along +Z, measured
##     once per bow: length_for), so a longer arrow still starts its hits at its tip; LENGTH is the fallback
##   - each bow's shooting effects (balance.json "fx", fx.gd): its trail in flight (Fx.arrow_trail, left to fade where
##     it is when the arrow goes) and its burst on every hit (Fx.hit_burst)
## H1 (docs/ARCHITECTURE.md part 4, Object Pool): the cat's arrows come from Pools (player.gd _fire, pool POOL). An
## arrow keeps its model and its trail between flights while the bow stays the same (dress), and swaps them only when
## the bow changed. When it is gone it stands still with its model hidden while its trail fades where it is (as the
## trail did before pools), then goes back to its pool (Pools.give_back_in); one that never came from a pool is freed
## as before (_back).
## Flight, hits, pierce, burn, frost, trails and hit bursts are as before. The nocked arrow on the string is not pooled.

const ArrowScene := preload("res://assets/cat/CatRanger_Arrow.glb")
const POOL := &"arrow"          # its pool (Pools)
const SPEED := 15.0
const LIFE := 1.4               # seconds of flight before it drops
const LENGTH := 0.48            # the plain arrow's length; also the fallback when a model cannot be measured

static var _scenes := {}        # bow id -> its arrow's PackedScene (its own, or ArrowScene), loaded once
static var _vc := {}            # bow id -> its own arrow is vertex-coloured (it gets the shared colour shader)
static var _lengths := {}       # bow id -> its arrow's length, nock to tip (length_for), measured once

var main
var dir := Vector3.BACK
var life := LIFE
var damage := 10.0
var pierce := 0
var burn := {}                  # the bow's burn ({seconds, share_per_s}); {} for a plain arrow
var frost := {}                 # the bow's ice ({slow, seconds, hits_to_freeze, freeze_s, boss_freeze_s}); {} for none
var bow_id := ""
var length := LENGTH            # this arrow's length, nock to tip (length_for)
var fx := {}                    # the bow's shooting effects (Data.bow_fx)
var _done: Array = []
var _trail: Array = []          # its trail's nodes (Fx.arrow_trail)
var _model: Node3D = null       # the model it wears (make), kept between flights while the bow stays the same
var _dressed := "-"             # what model and trail it wears: "<bow id>[+fire]@<graphics level>" (+fire: a fire bow
                                # without fx, with the short flame trail)
var _flying := false            # in flight (false while its trail fades and while it waits in its pool)


## Where bow bid's own arrow model would be.
static func arrow_path(bid: String) -> String:
	return "res://assets/cat/arrows/arrow_%s.glb" % bid


## Bow bid's arrow: its own model when the file exists, else the plain CatRanger arrow.
static func scene_for(bid: String) -> PackedScene:
	if not _scenes.has(bid):
		var ps: PackedScene = null
		var p := arrow_path(bid)
		if bid != "" and ResourceLoader.exists(p):
			ps = load(p) as PackedScene
		_scenes[bid] = ps if ps != null else ArrowScene
	return _scenes[bid]


## A new arrow model for bow bid (flying, or nocked on the string). A bow's own vertex-coloured arrow gets the shared
## colour shader, as every LEAF model does; the plain arrow keeps its own materials.
static func make(bid: String) -> Node3D:
	var ps := scene_for(bid)
	var n := ps.instantiate() as Node3D
	if ps != ArrowScene:
		if not _vc.has(bid):
			_vc[bid] = has_vc(n)
		if bool(_vc[bid]):
			Props.apply_vc_glow(n)                         # its M_Glow tip or fletching keeps its glow
	return n


## How long bow bid's arrow is, nock (its origin) to tip: the farthest point of its meshes along +Z, measured once from
## its model (its own, or the plain one). LENGTH when the model gives nothing sensible (under 0.1 m or over 3 m).
static func length_for(bid: String) -> float:
	if not _lengths.has(bid):
		var n := scene_for(bid).instantiate()
		var z := _max_z(n, Transform3D.IDENTITY)
		n.free()
		_lengths[bid] = z if z > 0.1 and z < 3.0 else LENGTH
	return float(_lengths[bid])


## The farthest point along +Z of any mesh under n, in the frame of the model's root (xf: n's transform from the root).
static func _max_z(n: Node, xf: Transform3D) -> float:
	var best := -INF
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var bb: AABB = (n as MeshInstance3D).mesh.get_aabb()
		for i in 8:
			best = maxf(best, (xf * bb.get_endpoint(i)).z)
	for c in n.get_children():
		best = maxf(best, _max_z(c, xf * (c as Node3D).transform if c is Node3D else xf))
	return best


## Some mesh under n carries vertex colours (a model made to the asset rules: one flat colour per face).
static func has_vc(n: Node) -> bool:
	if n is MeshInstance3D:
		var m := (n as MeshInstance3D).mesh
		if m is ArrayMesh:
			var am := m as ArrayMesh
			for i in am.get_surface_count():
				if (am.surface_get_format(i) & Mesh.ARRAY_FORMAT_COLOR) != 0:
					return true
	for c in n.get_children():
		if has_vc(c):
			return true
	return false


func launch(start: Vector3, direction: Vector3, m, dmg := 10.0, through := 0, fire: Dictionary = {}, bid := "",
		ice: Dictionary = {}) -> void:
	main = m
	damage = dmg
	pierce = through
	burn = fire
	frost = ice
	bow_id = bid
	life = LIFE
	_done.clear()
	dress(bid, fire)
	dir = direction.normalized()
	global_position = start
	global_basis = Basis.looking_at(-dir, Vector3.UP)        # looking_at points -Z at its target, the tip is +Z
	_model.visible = true
	Fx.restart_trail(_trail, fx)                           # its trail sets off from here
	_flying = true
	set_physics_process(true)


## H1: wears bow bid's model and trail (built idle), keeping them when it already wears that bow's. `fire` is the bow's
## burn: a fire bow without fx gets the short flame trail. Also sets length and fx for that bow.
func dress(bid: String, fire: Dictionary) -> void:
	length = length_for(bid)
	fx = Data.bow_fx(bid)
	# the trail's particle counts follow the graphics level, so a level change dresses it anew too
	var want := "%s%s@%d" % [bid, "+fire" if fx.is_empty() and not fire.is_empty() else "", Quality.level]
	if want == _dressed and _model != null and is_instance_valid(_model):
		return
	var old: Array[Node] = []
	for n: Variant in _trail:
		if is_instance_valid(n):
			old.append(n as Node)
	if _model != null and is_instance_valid(_model):
		old.append(_model)
	for n: Node in old:
		if n.get_parent() != null:
			n.get_parent().remove_child(n)
		n.queue_free()
	_model = make(bid)
	add_child(_model)
	_trail = []
	if not fx.is_empty():
		_trail = Fx.arrow_trail(self, length, fx, false)   # 22 Nov 2026: the bow's own trail
	elif not fire.is_empty():
		var trail := Fx.embers(self, 0.02, 8, 0.14, 0.6)    # a fire bow without fx: the short flame trail, from its tip
		trail.position = Vector3(0, 0, length * 0.9)
		trail.emitting = false
		_trail = [trail]
	_dressed = want


## H1, Pools: put back to new when it is taken from its pool (launch then sets it flying).
func reset() -> void:
	_flying = false
	set_physics_process(false)
	life = LIFE
	_done.clear()
	main = null


func _physics_process(delta: float) -> void:
	if not _flying:
		return
	var tip0 := global_position + dir * length
	global_position += dir * SPEED * delta
	var seg := dir * SPEED * delta
	life -= delta
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.dead or _done.has(e):
			continue
		var c: Vector3 = e.global_position + Vector3(0.0, e.aim_height, 0.0)
		var t := clampf((c - tip0).dot(seg) / maxf(seg.length_squared(), 0.000001), 0.0, 1.0)
		if (tip0 + seg * t).distance_to(c) < e.radius + 0.08:
			e.hit(dir, damage)
			var dealt = e.get("last_dealt")                  # null for a target without it (the training dummy)
			var landed: bool = dealt == null or float(dealt) > 0.0
			if landed and not fx.is_empty():
				Fx.hit_burst(main, tip0 + seg * t, dir, fx)
			if not burn.is_empty() and not e.dead and e.has_method("ignite"):
				e.ignite(float(burn.get("seconds", 0.0)), float(burn.get("share_per_s", 0.0)) * float(e.last_dealt))
			if not frost.is_empty() and landed and not e.dead and e.has_method("chill"):
				e.chill(frost)
			_done.append(e)
			pierce -= 1
			if pierce < 0:
				_gone()
				return
	if life <= 0.0:
		_gone()


## It hits its last enemy or runs out of flight: it stops with its model hidden, its trail fades where it is
## (Fx.fade_trail), then the arrow goes back to its pool (Pools.give_back_in), or is freed if it had none (_back).
func _gone() -> void:
	_flying = false
	set_physics_process(false)
	_done.clear()
	if _model != null and is_instance_valid(_model):
		_model.visible = false
	var wait := Fx.fade_trail(_trail)
	if Pools.is_pooled(self):
		Pools.give_back_in(self, wait)                   # skipped by Pools if it was taken again by then
	elif wait > 0.0 and is_inside_tree():
		get_tree().create_timer(wait).timeout.connect(_back)
	else:
		_back()


## An arrow that never came from a pool (a test's) is freed once its trail has faded, as every arrow was before pools.
func _back() -> void:
	if _flying:
		return                                          # flying again already (launched by hand meanwhile)
	queue_free()
