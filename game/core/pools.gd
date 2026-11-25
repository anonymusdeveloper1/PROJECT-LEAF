extends Node
## Object pools (autoload "Pools"; docs/ARCHITECTURE.md part 4, Object Pool): hands out reusable objects and takes them
## back, so a busy fight does not keep making and freeing nodes.
## Used by: player.gd and arrow.gd (the cat's arrows), fx.gd (damage numbers and text pop-ups, the one-shot bursts),
## main.gd and pickup.gd (leaves and the other pickups), the tests (autotest_pools.gd) and the speed tests (stats()).
## Uses: Data (balance.json "pools": how many of each to make ahead, per graphics level) and Quality (the level).
## Rules:
##   - take(key, make) gives the oldest waiting object of that key, or a new one from make (a Callable returning a Node).
##     It comes with no parent, visible and processing as it was made, and its reset() (if it has one) already called;
##     the caller adds it to the scene and sets it up.
##   - give_back(node) hides it, stops its processing (process_mode disabled), takes it out of the scene and keeps it for
##     the next take. A pooled object is never queue_free'd; only the waiting ones are freed, when the game closes.
##     Giving one back twice does nothing. A node that never came from a pool is queue_free'd, as before pools.
##   - give_back_in(node, seconds) does the same later, unless it was given back and taken again in the meantime.
##   - A pool is not capped: when every object is out it makes another, and keeps it afterwards.
##   - A pooled object freed by something else (its parent freed, a test clearing the field) is counted as "lost".

const KEY := &"pool_key"            # meta on a pooled node: its pool
const GEN := &"pool_gen"            # meta: how many times it was taken (a late give_back_in for an older take is ignored)
const MODE := &"pool_mode"          # meta: its process_mode as made, put back on each take

var _waiting: Dictionary[StringName, Array] = {}       # key -> the waiting nodes, oldest first
var _out: Dictionary[StringName, Dictionary] = {}      # key -> {instance id: node} of the ones handed out
var _made: Dictionary[StringName, int] = {}            # key -> how many were ever made
var _taken: Dictionary[StringName, int] = {}           # key -> how many takes
var _lost: Dictionary[StringName, int] = {}            # key -> how many were freed by something else


## A waiting object of pool `key` (its reset() called), or a new one from `make`. Add it to the scene yourself.
func take(key: StringName, make: Callable) -> Node:
	_ensure(key)
	var node: Node = null
	var list: Array = _waiting[key]
	while not list.is_empty() and node == null:
		var w: Variant = list.pop_front()
		if is_instance_valid(w) and not (w as Node).is_queued_for_deletion():
			node = w
		else:
			_lost[key] += 1                         # freed while it waited (by hand)
	if node == null:
		node = _make(key, make)
	var parent := node.get_parent()
	if parent != null:
		parent.remove_child(node)                  # only if give_back could not take it out of the scene
	node.process_mode = node.get_meta(MODE, Node.PROCESS_MODE_INHERIT)
	_show(node, true)
	node.set_meta(GEN, int(node.get_meta(GEN, 0)) + 1)
	_out[key][node.get_instance_id()] = node
	_taken[key] += 1
	if node.has_method(&"reset"):
		node.call(&"reset")
	return node


## Puts a pooled object back to wait: hidden, not processing, out of the scene. A node that is not pooled is
## queue_free'd instead.
func give_back(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if not node.has_meta(KEY):
		node.queue_free()
		return
	var key: StringName = node.get_meta(KEY)
	_ensure(key)
	var id := node.get_instance_id()
	if not _out[key].has(id):
		return                                      # already waiting
	_out[key].erase(id)
	if node.is_queued_for_deletion():
		_lost[key] += 1
		return
	_park(node)
	_waiting[key].append(node)


## give_back after `seconds` (scaled by Engine.time_scale, running while the game is paused, as the effects' own timers
## did), unless the object was given back and taken again before then.
func give_back_in(node: Node, seconds: float) -> void:
	if node == null or not is_instance_valid(node):
		return
	if seconds <= 0.0 or not is_inside_tree():
		give_back(node)                             # nothing to wait for: at once
		return
	var gen := int(node.get_meta(GEN, 0))
	get_tree().create_timer(seconds).timeout.connect(_due.bind(node.get_instance_id(), gen))


## Makes objects of pool `key` ahead of time until `count` exist (waiting or out). The waiting ones are hidden and idle.
func prewarm(key: StringName, make: Callable, count: int) -> void:
	_ensure(key)
	while _made[key] < count:
		var node := _make(key, make)
		_park(node)
		_waiting[key].append(node)


## How many to make ahead for `name` at the current graphics level (balance.json "pools", [Low, Medium, High]).
func size_for(name: String) -> int:
	var block: Dictionary = Data.b.get("pools", {})
	var v: Variant = block.get(name, 0)
	if v is Array:
		var a: Array = v
		return int(a[clampi(Quality.level, 0, a.size() - 1)]) if not a.is_empty() else 0
	return int(v)


## Whether `node` belongs to a pool (it came from take or prewarm).
func is_pooled(node: Node) -> bool:
	return node != null and is_instance_valid(node) and node.has_meta(KEY)


## Every pool: {key: {"waiting": n, "out": n, "made": n, "taken": n, "lost": n}}. "out" counts only the live ones;
## any handed-out object that was freed meanwhile moves to "lost".
func stats() -> Dictionary:
	var out := {}
	for key: StringName in _made:
		var live := 0
		var gone: Array[int] = []
		for id: int in _out[key]:
			var n: Variant = _out[key][id]
			if is_instance_valid(n) and not (n as Node).is_queued_for_deletion():
				live += 1
			else:
				gone.append(id)
		for id in gone:
			_out[key].erase(id)
			_lost[key] += 1
		out[String(key)] = {"waiting": (_waiting[key] as Array).size(), "out": live, "made": _made[key],
			"taken": _taken[key], "lost": _lost[key]}
	return out


func _ensure(key: StringName) -> void:
	if not _made.has(key):
		_made[key] = 0
		_taken[key] = 0
		_lost[key] = 0
		_waiting[key] = []
		_out[key] = {}


func _make(key: StringName, make: Callable) -> Node:
	var node: Node = make.call()
	node.set_meta(KEY, key)
	node.set_meta(MODE, node.process_mode)
	node.set_meta(GEN, 0)
	_made[key] += 1
	return node


func _park(node: Node) -> void:
	_show(node, false)
	node.process_mode = Node.PROCESS_MODE_DISABLED
	var parent := node.get_parent()
	if parent != null:
		parent.remove_child(node)


func _show(node: Node, on: bool) -> void:
	if node is Node3D:
		(node as Node3D).visible = on
	elif node is CanvasItem:
		(node as CanvasItem).visible = on


func _due(id: int, gen: int) -> void:
	var node := instance_from_id(id) as Node
	if node != null and int(node.get_meta(GEN, 0)) == gen:
		give_back(node)


## The waiting objects are out of the scene, so nothing else frees them: they go when the game closes.
func _exit_tree() -> void:
	for key: StringName in _waiting:
		for n: Variant in _waiting[key]:
			if is_instance_valid(n):
				(n as Node).free()
		(_waiting[key] as Array).clear()
