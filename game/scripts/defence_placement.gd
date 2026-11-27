extends RefCounted
## Placing towers and spikes from the Bag (H6, Stage 1; docs/ARCHITECTURE.md part 4, Command). The `defences` facade
## (scripts/defences.gd) builds one of these before load_saved() as `_placement = PlacementScript.new(self)` and forwards
## start_placing, stop_placing, place_here and the ghost reads (placing, ghost, ghost_ok, ghost_pos, valid) to it, and
## calls update_ghost() from its _process.
## It owns three things:
##   - the ghost (the see-through piece in front of the cat, green where it may go) and the drop-in when a piece lands;
##   - the placement transaction, behind the commands PlaceDefence and UndoPlaceDefence (commands/): recheck the spot and
##     the stock, take the piece from the Bag, build it, and only then record and announce it;
##   - the receipt of the last piece placed in this placing visit, which is what Undo may take back.
## Uses: Bag (peek/take/return_defence, defence_changed), Save.placed, DefencePersistence.carried_record, and the facade's
## spawn_placement(record), remove_placement(id), piece_at(id), off_limits(pos), model, level, pieces and main.
## Never saves (the caller does) and never calls the HUD.
## Stage 1 plays exactly like H5: no level is written to the saved record, and no Undo button is shown yet.

const AHEAD := 1.6                  # the ghost floats this far (m) in front of the cat
const DROP_H := 0.6                 # a placed piece drops in from this high (m) ...
const DROP_S := 0.18                # ... in this long (s), then bounces with a puff of dust (_drop_in)
const DefencePersistence := preload("res://scripts/defence_persistence.gd")
const PlaceDefence := preload("res://commands/place_defence.gd")

var placing := ""                   # the kind being placed ("tower" or "spikes"), "" when not placing
var ghost: Node3D
var ghost_ok := false               # last frame's check: the transaction rechecks, so a stale value is harmless
var ghost_pos := Vector3.ZERO
var ghost_rot := 0.0

var defences                        # the facade (a Node3D): owns the pieces, the nodes and the markers
var _receipt := {}                  # {id, kind, record, carried, visit} of the last placed piece, {} when none
var _visit := 0                     # counts placing visits; every invalidation bumps it


func _init(owner_node) -> void:
	defences = owner_node
	if not Events.wave_started.is_connected(_on_wave_started):
		Events.wave_started.connect(_on_wave_started)
	if not Events.area_changed.is_connected(_on_area_changed):
		Events.area_changed.connect(_on_area_changed)
	if not Events.save_loaded.is_connected(_on_save_loaded):
		Events.save_loaded.connect(_on_save_loaded)


func _on_wave_started(_n: int) -> void:
	invalidate()


func _on_area_changed(_inside: bool) -> void:
	invalidate()


func _on_save_loaded() -> void:
	invalidate()


## Nothing placed so far can be undone any more (a wave, leaving the camp, a load, Done/Cancel, a new visit).
func invalidate() -> void:
	_receipt = {}
	_visit += 1


# ---------------------------------------------------------------- the ghost
## Only a Bag "build" thing is placed, only with one held, and never below ground.
func start_placing(kind: String) -> void:
	if Bag.kind_of(kind) != "build" or Bag.count(kind) <= 0 or defences.main.area != null:
		return
	stop_placing()
	invalidate()
	placing = kind
	_make_ghost()
	Events.placing_changed.emit(placing)


## Done, Cancel and the facade's _clear() end the visit: the receipt goes with it.
func stop_placing() -> void:
	var was_placing := placing != ""
	if ghost:
		ghost.queue_free()
	ghost = null
	placing = ""
	invalidate()
	if was_placing:
		Events.placing_changed.emit(placing)


func _make_ghost() -> void:
	if ghost:
		ghost.queue_free()
	ghost = Props.instance(defences.model(placing, defences.level(placing)))
	defences.add_child(ghost)


## The ghost's part of the facade's _process: follows the cat, checks the spot, tints green or red.
func update_ghost() -> void:
	if placing == "" or ghost == null:
		return
	var main = defences.main
	var t := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
	var cat: Vector3 = main.player.global_position
	var f: float = main.player.facing
	ghost_pos = cat + Vector3(sin(f), 0, cos(f)) * AHEAD
	ghost_pos.y = 0.0
	ghost_rot = f
	ghost_ok = valid(ghost_pos, placing)
	ghost.position = ghost_pos + Vector3(0, 0.02, 0)
	ghost.rotation.y = ghost_rot
	Props.set_param(ghost, "tint", Color(0.7, 1.25, 0.7) if ghost_ok else Color(1.3, 0.45, 0.4))
	Props.set_param(ghost, "flash", 0.15 + 0.15 * t)


## The spot is fine for this kind: inside the camp, off the ground kept clear (the facade's off_limits, the same rule as
## the start-up check), off the props and other pieces, and off the roads (spikes may go on a road). The kind is an
## argument so a placement made without a ghost (a test) gets the right road rule; "" means the kind being placed.
func valid(pos: Vector3, kind := "") -> bool:
	var main = defences.main
	var k := kind if kind != "" else placing
	var r := Vector2(pos.x, pos.z).length()
	if r < 1.5 or r > main.world.MOVE_R - 0.3:
		return false
	if defences.off_limits(pos):
		return false
	var q := Vector2(pos.x, pos.z)
	for c in main.world.circles:
		if String(c[2]).begins_with("piece_"):
			continue
		if q.distance_to(c[0]) < float(c[1]) + 0.6:
			return false
	for p in defences.pieces:
		if (p["pos"] as Vector3).distance_to(pos) < 0.9:
			return false
	return main.world.path_strength(pos) < 0.5 or k == "spikes"


# ---------------------------------------------------------------- Place
## "" when kind may be placed at `at` now, else the refusal in words (Data.word keys place_*).
func placement_reason(kind: String, at: Vector3) -> String:
	if Bag.kind_of(kind) != "build" or Bag.peek_defence(kind).is_empty():
		return Data.word("place_none_held")
	if defences.main.area != null:
		return Data.word("place_below")
	if not valid(at, kind):
		return Data.word("place_blocked")
	return ""


## The transaction. Rechecks the spot and the stock against the live world (at the snapshot spot and yaw the ghost
## showed), takes the piece from the Bag without announcing, builds it, and only then records and announces it.
## Returns the new piece's id, or -1 (nothing changed).
func commit(kind: String, at: Vector3, yaw: float) -> int:
	if placement_reason(kind, at) != "":
		return -1
	var carried: Dictionary = Bag.take_defence(kind, false)
	if carried.is_empty():
		return -1
	var sp := {"type": kind, "x": at.x, "z": at.z, "rot": yaw}      # Stage 1: no "level", the v5 file keeps its shape
	var p: Dictionary = defences.spawn_placement(sp)
	if p.is_empty():
		Bag.return_defence(kind, carried, false)
		return -1
	var id := int(p["id"])
	Save.placed.append(sp)
	_receipt = {"id": id, "kind": kind, "record": sp, "carried": carried, "visit": _visit}
	Save.mark_dirty()
	Bag.defence_changed(kind, -1)
	return id


## The Place button: the ghost's spot, the transaction, a save, the drop-in, and the ghost for the next piece.
func place_here() -> void:
	if placing == "" or not ghost_ok:
		return
	var kind := placing
	var at := ghost_pos
	var cmd := PlaceDefence.new(kind, at, ghost_rot)
	if not cmd.run(defences.main):
		return
	Save.save_game()                                    # H5 saved here, and --bag reads the file
	var p: Dictionary = defences.piece_at(cmd.placed_id)
	if not p.is_empty():
		_drop_in(p["node"], at)
	if Bag.peek_defence(kind).is_empty():
		stop_placing()
	elif ghost:
		_make_ghost()                                   # same visit: the receipt stays, so no stop/start here


## The drop-in: the node starts DROP_H up and falls to its spot.
func _drop_in(node: Node3D, at: Vector3) -> void:
	if node == null:
		return
	var ground := node.position
	node.position = ground + Vector3(0, DROP_H, 0)
	var tw := node.create_tween()
	tw.tween_property(node, "position", ground, DROP_S).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_landed.bind(node, at))


func _landed(node: Node3D, at: Vector3) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree():
		return
	Fx.boing(node, 0.35)
	Fx.dust(defences.main, at, 8, 0.9)
	Sfx.play("buy", -6.0)


# ---------------------------------------------------------------- Undo
func can_undo() -> bool:
	return not _receipt.is_empty() and undo_reason(int(_receipt["id"])) == ""


## The id of the piece Undo would take back, -1 when none.
func undo_id() -> int:
	return int(_receipt.get("id", -1))


## "" when piece `id` may be taken back now: it is the last piece of this visit, still the same piece with the same
## saved record, and the camp is quiet and above ground.
func undo_reason(id: int) -> String:
	if id < 0 or _receipt.is_empty() or int(_receipt["id"]) != id or int(_receipt["visit"]) != _visit:
		return Data.word("undo_stale")
	var p: Dictionary = defences.piece_at(id)
	if p.is_empty() or not (String(p["type"]) == "tower" or String(p["type"]) == "spikes"):
		return Data.word("undo_stale")
	var rec: Dictionary = _receipt["record"]
	if not is_same(p.get("src"), rec) or _record_index(rec) < 0:
		return Data.word("undo_stale")                  # a save return or a reload relinked it: refuse
	if defences.main.area != null or defences._wave_on():
		return Data.word("undo_stale")
	return ""


## Takes piece `id` back: its node, collision and marker go, its record leaves Save.placed, and the Bag gets back the
## record it paid (forced, so a full Bag still takes it). The receipt goes first, so a second Undo finds nothing.
func revert(id: int) -> bool:
	if undo_reason(id) != "":
		return false
	var kind := String(_receipt["kind"])
	var carried: Dictionary = _receipt["carried"]
	var idx := _record_index(_receipt["record"])
	_receipt = {}
	if not defences.remove_placement(id):
		return false
	Save.placed.remove_at(idx)
	Bag.return_defence(kind, carried, false)
	Save.mark_dirty()
	Bag.defence_changed(kind, 1)
	return true


## The index of a record in Save.placed by identity (never by value: two pieces can look the same), -1 when absent.
func _record_index(rec: Dictionary) -> int:
	for i in Save.placed.size():
		if is_same(Save.placed[i], rec):
			return i
	return -1


# ---------------------------------------------------------------- a new building on the ground (Stage 2 calls this)
## Every tower and spikes patch that stands on station `station_id`'s ground goes back to the Bag, held at its own
## record. Returns how many. Not called in Stage 1.
func return_blocked_for_station(station_id: String) -> int:
	var back := {}                                      # kind -> how many went back
	var total := 0
	for p: Dictionary in defences.pieces.duplicate():
		var kind := String(p["type"])
		if kind != "tower" and kind != "spikes":
			continue
		if not defences.main.world.on_station_ground(station_id, p["pos"], 0.6):
			continue
		var carried: Dictionary = DefencePersistence.carried_record(p)
		var src: Variant = p.get("src")
		var idx := _record_index(src) if src is Dictionary else -1
		if not defences.remove_placement(int(p["id"])):
			continue
		if idx >= 0:
			Save.placed.remove_at(idx)
		Bag.return_defence(kind, carried, false)
		if not _receipt.is_empty() and int(_receipt["id"]) == int(p["id"]):
			_receipt = {}
		back[kind] = int(back.get(kind, 0)) + 1
		total += 1
	for kind: String in back:
		Bag.defence_changed(kind, int(back[kind]))
	if total > 0:
		Save.mark_dirty()
	return total
