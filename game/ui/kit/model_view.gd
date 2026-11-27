extends SubViewportContainer
## H4 (the window kit): a small turning 3D picture inside a window: the Bow Shop's inspect view
## (ui/windows/bow_inspect.gd) shows a bow and its arrow with it; H5's attachments and the Tailor's Nook can reuse it.
## It is a little world of its own (a SubViewport with its own 3D world and a see-through background), lit like the
## Bag's picture of the cat (scripts/inventory_preview.gd: the same warm ambient light and sun). What it shows turns
## slowly about the upright axis, centred, and an orthographic camera looking from the front and a little above frames
## the whole of it at every angle (its bounding sphere).
##   setup(px)      its size in HUD pixels (the drawing is that size too); once, right after new()
##   show_node(n)   shows n instead of what it showed (n belongs to the view from then on: clear() and freeing the view
##                  free it); it starts facing the front
##   clear()        shows nothing
##   box_of(n)      (static) the box round every mesh under n, in n's own space
## It turns only while it is on the screen (TURN_DEG_S), and keeps its turn when a window moves it to a new parent (a
## card's rebuild re-parents it: nothing restarts). The drawing follows the graphics level: every frame while it shows
## (UPDATE_WHEN_VISIBLE), on Low one drawing every LOW_EVERY s (about 10 a second, as the Bag's picture).
## It takes no touches (MOUSE_FILTER_IGNORE): a drag over it still scrolls the dialog. No class_name: preload it.
## Used by: ui/windows/bow_inspect.gd, the tests. Uses: Quality (the graphics level).

const TURN_DEG_S := 30.0               # how fast it turns (an animation timing, in code like the Fx timings)
const LOW_EVERY := 0.1                 # on Low graphics: one drawing this often
const LIFT := 2.0                      # the pivot stands this high in its world (the colour shader shades near y = 0)
const VIEW_DIR := Vector3(0.0, 0.4, 1.0)   # where the camera looks from: the front, a little from above
const MARGIN := 1.08                   # a little room round the thing

var _vp: SubViewport
var _cam: Camera3D
var _pivot: Node3D                     # what it shows hangs under this; this is what turns
var _low_t := 0.0


## Builds the little world: px is its size in HUD pixels (and its drawing's).
func setup(px: Vector2i) -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(px)
	_vp = SubViewport.new()
	_vp.size = px
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_DISABLED if Quality.level == Quality.LOW else Viewport.MSAA_2X   # a thin bow turning
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE if Quality.level == Quality.LOW else SubViewport.UPDATE_WHEN_VISIBLE
	add_child(_vp)
	var env := WorldEnvironment.new()                 # the Bag preview's light and environment
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.88, 0.79, 0.6, 0.0)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1.0, 0.94, 0.8)
	e.ambient_light_energy = 0.5
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	_vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -35, 0)
	sun.light_energy = 0.85
	_vp.add_child(sun)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.current = true
	_vp.add_child(_cam)
	_pivot = Node3D.new()
	_pivot.position = Vector3(0.0, LIFT, 0.0)
	_vp.add_child(_pivot)
	_fit(0.5)


## Shows n (and only n), centred by the box round its meshes, the camera fitted to it.
func show_node(n: Node3D) -> void:
	clear()
	if n == null or _pivot == null:
		return
	_pivot.rotation = Vector3.ZERO
	_pivot.add_child(n)
	var box: AABB = n.transform * box_of(n)
	n.position -= box.get_center()
	_fit(maxf(box.size.length() * 0.5, 0.05))


## Shows nothing (what it showed is freed).
func clear() -> void:
	if _pivot == null:
		return
	for c in _pivot.get_children():
		_pivot.remove_child(c)
		c.queue_free()


## What it shows now (null when nothing): the tests read it.
func shown() -> Node3D:
	if _pivot == null or _pivot.get_child_count() == 0:
		return null
	return _pivot.get_child(0) as Node3D


## How far it has turned, in radians (0 to TAU): the tests read it.
func turned() -> float:
	return _pivot.rotation.y if _pivot != null else 0.0


func _process(delta: float) -> void:
	if _pivot == null or not is_visible_in_tree():
		return
	_pivot.rotation.y = wrapf(_pivot.rotation.y + deg_to_rad(TURN_DEG_S) * delta, 0.0, TAU)
	if Quality.level == Quality.LOW:
		_low_t -= delta
		if _low_t <= 0.0:
			_low_t = LOW_EVERY
			_vp.render_target_update_mode = SubViewport.UPDATE_ONCE    # draws once, then waits for the next
	elif _vp.render_target_update_mode != SubViewport.UPDATE_WHEN_VISIBLE:
		_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE


## The orthographic camera framing a ball of radius r round the pivot, whatever the view's shape (its size is the
## height it sees; a view taller than wide needs more).
func _fit(r: float) -> void:
	var aspect := float(_vp.size.x) / float(maxi(_vp.size.y, 1))
	_cam.size = 2.0 * r * MARGIN / minf(1.0, aspect)
	_cam.near = 0.05
	_cam.far = r * 6.0 + 4.0
	var at := _pivot.position
	_cam.transform = Transform3D(Basis(), at + VIEW_DIR.normalized() * (r * 3.0 + 1.0)).looking_at(at, Vector3.UP)


## The box round every mesh under n, in n's own space (n's own place and turn left out); an empty box when it has none.
static func box_of(n: Node3D) -> AABB:
	var acc := {"box": AABB(), "any": false}
	_add_boxes(n, Transform3D.IDENTITY, acc)
	return acc["box"]


static func _add_boxes(n: Node, xf: Transform3D, acc: Dictionary) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var b: AABB = xf * (n as MeshInstance3D).mesh.get_aabb()
		var so_far: AABB = acc["box"]
		acc["box"] = so_far.merge(b) if bool(acc["any"]) else b
		acc["any"] = true
	for c in n.get_children():
		_add_boxes(c, xf * (c as Node3D).transform if c is Node3D else xf, acc)
