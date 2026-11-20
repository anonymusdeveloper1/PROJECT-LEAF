extends Node3D
## One barricade row across a road (Phase G2, 20 Nov 2026). defences.gd builds it at a road spot (world.barricade_slots())
## and keeps each piece's health and collision; this node only shows the pieces. They stand side by side along the
## row's local X, each its own model (the barricade level's: barricade_log ... barricade_heartwood, made as long as the
## whole row, so each is squeezed to its share of it); local +Z faces the woods. A piece looks:
##   whole    as built
##   cracked  darker (the props' gloom shade) and leaning back a little
##   broken   fallen flat on its back (stakes up), a little rubble pile by it; nothing blocks the gap it leaves
## Nothing here reads a clock: the fall is a one-off tween.

const CRACK_TILT := 0.14            # a cracked piece leans back toward the camp (radians)
const CRACK_ROLL := 0.06            # and a little to one side (left and right in turn)
const CRACK_GLOOM := 0.4            # and darkens
const FALL_TILT := 1.42             # a broken piece lies on its back
const FALL_ROLL := 0.07
const FALL_LIFT := 0.16             # held up a little, so it lies on the ground and not in it
const FALL_S := 0.4                 # how long the fall takes
const BROKEN_GLOOM := 0.55
const FILL := 0.96                  # each piece fills this share of its part of the row: a thin gap shows the pieces

var lane := -1
var index := -1
var count := 3
var seg := 1.0                      # each piece's part of the row, metres
var models: Array = []              # each piece's model node (defences.gd's piece "node")
var looks: Array = []               # "whole", "cracked" or "broken"
var rubble: Array = []              # each broken piece's rubble pile (null when there is none)
var _sx := 1.0


## A row of n pieces over `length` metres at a road spot (pos, rot: world.barricade_slots()).
func setup(ln: int, idx: int, pos: Vector3, rot: float, n: int, length: float) -> void:
	lane = ln
	index = idx
	count = maxi(1, n)
	seg = length / float(count)
	_sx = FILL / float(count)            # the models span the whole row (balance.json barricade.length)
	models.resize(count)
	rubble.resize(count)
	looks.resize(count)
	for k in count:
		looks[k] = "whole"
	place(pos, rot)


## The row moves with its road spot (the camp grew and the trails moved a little).
func place(pos: Vector3, rot: float) -> void:
	position = Vector3(pos.x, 0.0, pos.z)
	rotation = Vector3(0.0, rot, 0.0)


## Where piece k's middle is along the row (local X).
func piece_x(k: int) -> float:
	return (float(k) - float(count - 1) * 0.5) * seg


## Where piece k's middle stands in the world.
func piece_pos(k: int) -> Vector3:
	return position + transform.basis.x * piece_x(k)


## Piece k gets the model `prop` (built, or a new barricade level); its look stays. Returns the model.
func set_model(k: int, prop: String) -> Node3D:
	var old = models[k]
	if is_instance_valid(old):
		(old as Node3D).name = String((old as Node3D).name) + "_old"
		(old as Node3D).queue_free()
	var m := Props.instance(prop)
	m.position = Vector3(piece_x(k), 0.0, 0.0)
	m.scale = Vector3(_sx, 1.0, 1.0)
	add_child(m)
	models[k] = m
	show_piece(k, String(looks[k]))
	return m


## Shows piece k whole, cracked or broken. `anim`: a piece breaking falls over (else it jumps to its look).
func show_piece(k: int, look: String, anim := false) -> void:
	if k < 0 or k >= count:
		return
	looks[k] = look
	var mv = models[k]
	if not is_instance_valid(mv):
		return
	var m := mv as Node3D
	if m.has_meta("look_tw"):
		var old = m.get_meta("look_tw")
		if old is Tween and (old as Tween).is_valid():
			(old as Tween).kill()
		m.remove_meta("look_tw")
	var side := -1.0 if k % 2 == 0 else 1.0
	var rot := Vector3.ZERO
	var y := 0.0
	var gloom := 0.0
	match look:
		"cracked":
			rot = Vector3(-CRACK_TILT, 0.0, CRACK_ROLL * side)
			gloom = CRACK_GLOOM
		"broken":
			rot = Vector3(-FALL_TILT, 0.0, FALL_ROLL * side)
			y = FALL_LIFT
			gloom = BROKEN_GLOOM
	Props.set_param(m, "gloom", gloom)
	if anim and look == "broken" and m.is_inside_tree():
		var tw := m.create_tween().set_parallel()
		tw.tween_property(m, "rotation", rot, FALL_S).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.tween_property(m, "position:y", y, FALL_S * 0.6)
		m.set_meta("look_tw", tw)
	else:
		m.rotation = rot
		m.position.y = y
	_set_rubble(k, look == "broken")


## Piece k's look now ("whole", "cracked", "broken").
func look_of(k: int) -> String:
	return String(looks[k]) if k >= 0 and k < count else ""


## Piece k's rubble pile (null while it is not broken).
func rubble_at(k: int) -> Node3D:
	if k < 0 or k >= count or not is_instance_valid(rubble[k]):
		return null
	return rubble[k] as Node3D


## A broken piece leaves a little rubble pile at its foot, on the woods' side where it stood (the existing rubble prop).
func _set_rubble(k: int, on: bool) -> void:
	var r: Node3D = rubble_at(k)
	if on and r == null:
		r = Props.instance("rubble_pile" if Props.has("rubble_pile") else "rock_1")
		var side := -1.0 if k % 2 == 0 else 1.0
		r.position = Vector3(piece_x(k) + 0.18 * side, 0.0, 0.42)
		r.rotation.y = 0.9 * k + 0.4
		add_child(r)
		rubble[k] = r
	elif not on and r != null:
		r.queue_free()
		rubble[k] = null
