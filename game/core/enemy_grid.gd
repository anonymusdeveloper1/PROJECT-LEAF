extends RefCounted
## The enemy grid (H6 step 1; docs/ARCHITECTURE.md part 4, Spatial Partition): answers "who is near this box?" without
## walking every enemy. The ground (world X and Z) is cut into square cells (balance.json enemy_grid.cell_m); each
## registered enemy sits in the cell its position is in.
## candidates() always gives a SUPERSET of the enemies that could touch the box, in the order they were registered, which
## is the order get_nodes_in_group gives them (every enemy is added to main and then registered, and nothing re-parents).
## So a caller keeps its own exact distance, cone, sleep and tie tests and gets the same answers as before, in the same
## order. The grid never decides a hit.
## Entries are kept by instance id (never a typed list of nodes that may be freed). An enemy is removed when it dies or
## leaves the tree (tree_exiting), so clear() is not used by the game: the Training Target's dummy lives through camp and
## expedition switches.
## Used by: main (creates it; nearest_enemy, separation), enemy.gd and its parts (add, move, remove), arrow.gd, acorn.gd,
## fireball.gd, mount.gd, tower.gd, defences.gd, the abilities.

const MAX_CELLS := 64        # a box spanning more cells than this walks every entry instead

var _cell_m := 4.0
var _slack_m := 0.5
var _cell_of := {}           # instance id -> Vector2i (the cell it is filed in)
var _cells := {}             # Vector2i -> PackedInt64Array (instance ids in that cell)
var _seq := {}               # instance id -> int (registration number, only grows)
var _next_seq := 0
var _max_r := 0.0            # the biggest radius of any registered node (boxes are grown by it)
var _refiled_frame := -1     # the physics frame the entries were last all refiled in


func _init() -> void:
	var cfg: Dictionary = Data.b.get("enemy_grid", {})
	_cell_m = maxf(float(cfg.get("cell_m", 4.0)), 0.5)
	_slack_m = float(cfg.get("slack_m", 0.5))


## The biggest radius of any registered node.
func max_radius() -> float:
	return _max_r


## How many nodes are registered.
func size() -> int:
	return _cell_of.size()


## Registers a node (an enemy, or the Training Target's dummy). A node already registered is left as it is.
func add(node: Node3D) -> void:
	if node == null or not is_instance_valid(node):
		return
	var iid := node.get_instance_id()
	if _cell_of.has(iid):
		return
	_seq[iid] = _next_seq
	_next_seq += 1
	_max_r = maxf(_max_r, _radius_of(node))
	var cell := _cell_for(node)
	_cell_of[iid] = cell
	_file(iid, cell)
	var cb := Callable(self, "_on_exit").bind(node)
	if not node.tree_exiting.is_connected(cb):
		node.tree_exiting.connect(cb)


## A node has moved (or grown): refiles it when its cell changed, and raises the biggest radius. Unregistered nodes are
## ignored.
func move(node: Node3D) -> void:
	if node == null or not is_instance_valid(node):
		return
	var iid := node.get_instance_id()
	if not _cell_of.has(iid):
		return
	_max_r = maxf(_max_r, _radius_of(node))
	var cell := _cell_for(node)
	var old: Vector2i = _cell_of[iid]
	if cell == old:
		return
	_unfile(iid, old)
	_cell_of[iid] = cell
	_file(iid, cell)


## Takes a node out (it died or left the tree). Safe to call again.
func remove(node: Node3D) -> void:
	if node == null:
		return
	if is_instance_valid(node):
		_forget(node.get_instance_id())
		var cb := Callable(self, "_on_exit").bind(node)
		if node.tree_exiting.is_connected(cb):
			node.tree_exiting.disconnect(cb)


## Forgets everything (tests only; the game never calls it).
func clear() -> void:
	_cell_of.clear()
	_cells.clear()
	_seq.clear()
	_max_r = 0.0
	_refiled_frame = -1


## Every live node of `group` that could touch the box min_xz..max_xz (world X and Z), in registration order. A superset:
## the caller keeps its exact tests.
func candidates(min_xz: Vector2, max_xz: Vector2, group: StringName) -> Array[Node3D]:
	var frame := Engine.get_physics_frames()
	if frame != _refiled_frame:
		_refiled_frame = frame
		_refile_all()                                  # catches writers outside our files (pushes, test teleports)
	var grow := _max_r + _slack_m
	var lo := _cell_at(min_xz.x - grow, min_xz.y - grow)
	var hi := _cell_at(max_xz.x + grow, max_xz.y + grow)
	var ids: Array = []
	var span := (hi.x - lo.x + 1) * (hi.y - lo.y + 1)
	if span > MAX_CELLS or span < 0:
		ids = _cell_of.keys()
	else:
		for x in range(lo.x, hi.x + 1):
			for y in range(lo.y, hi.y + 1):
				var list: PackedInt64Array = _cells.get(Vector2i(x, y), PackedInt64Array())
				for iid in list:
					ids.append(iid)
	var found: Array = []                              # [seq, node]
	for iid: int in ids:
		var obj := instance_from_id(iid)
		if obj == null or not is_instance_valid(obj):
			continue
		var n := obj as Node3D
		if n == null or not n.is_inside_tree() or not n.is_in_group(group):
			continue
		found.append([int(_seq.get(iid, 0)), n])
	found.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var out: Array[Node3D] = []
	for f: Array in found:
		out.append(f[1] as Node3D)
	return out


## Convenience for a circle: the candidates for `centre` and `r` on the ground.
func near(centre: Vector3, r: float, group: StringName) -> Array[Node3D]:
	return candidates(Vector2(centre.x - r, centre.z - r), Vector2(centre.x + r, centre.z + r), group)


func _on_exit(node: Node3D) -> void:
	if node != null and is_instance_valid(node):
		_forget(node.get_instance_id())


func _forget(iid: int) -> void:
	if _cell_of.has(iid):
		_unfile(iid, _cell_of[iid])
	_cell_of.erase(iid)
	_seq.erase(iid)


func _refile_all() -> void:
	for iid: int in _cell_of.keys():
		var obj := instance_from_id(iid)
		if obj == null or not is_instance_valid(obj):
			_forget(iid)
			continue
		var n := obj as Node3D
		if n == null or not n.is_inside_tree():
			continue
		move(n)


func _radius_of(node: Node3D) -> float:
	var r = node.get("radius")
	return float(r) if r != null else 0.0


func _cell_for(node: Node3D) -> Vector2i:
	var p := node.global_position if node.is_inside_tree() else node.position
	return _cell_at(p.x, p.z)


func _cell_at(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x / _cell_m), floori(z / _cell_m))


func _file(iid: int, cell: Vector2i) -> void:
	var list: PackedInt64Array = _cells.get(cell, PackedInt64Array())
	list.append(iid)
	_cells[cell] = list


func _unfile(iid: int, cell: Vector2i) -> void:
	if not _cells.has(cell):
		return
	var list: PackedInt64Array = _cells[cell]
	var i := list.find(iid)
	if i >= 0:
		list.remove_at(i)
	if list.is_empty():
		_cells.erase(cell)
	else:
		_cells[cell] = list
