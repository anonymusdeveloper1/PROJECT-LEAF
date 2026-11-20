extends Control
## Floating joystick. It appears under the finger when the screen is touched, trails the finger when it is dragged
## past the rim, and disappears when the finger lifts. `vector` is the stick: length 0..1, y pointing down the screen.
## On a desktop the mouse acts as a finger (project setting "emulate touch from mouse"); WASD / arrow keys also work.
## Phase E: a quick flick as the finger lifts (or Space) emits `flicked`: the Leaf Dash in the Burrows.

signal flicked(dir: Vector2)

const RADIUS := 110.0     # travel of the stick in canvas pixels (the canvas is 720 wide)
const KNOB := 46.0
const DEADZONE := 0.12

var vector := Vector2.ZERO
var pressed := false
var origin := Vector2.ZERO
var knob := Vector2.ZERO
var _index := -1
var forced := Vector2.ZERO                # the automated test steers with this
var force := false
var auto := Vector2.ZERO                  # the cat walking to a tapped marker (interact.gd), while no finger is down
var _trail: Array = []                    # the active touch's recent [position, clock] (the flick test)
var _clock := 0.0                         # seconds of this joystick's own frames (never the system clock)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _index == -1 and not _blocked(event.position):
			_index = event.index
			origin = event.position
			knob = origin
			pressed = true
			_trail = [[event.position, _clock]]
			_update()
		elif not event.pressed and event.index == _index:
			_index = -1
			pressed = false
			vector = Vector2.ZERO
			_flick_test(event.position)
			queue_redraw()
	elif event is InputEventScreenDrag and event.index == _index:
		_trail.append([event.position, _clock])
		knob = event.position
		var off := knob - origin
		if off.length() > RADIUS:          # the base trails the finger, so the stick never runs out of travel
			origin = knob - off.normalized() * RADIUS
		_update()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_SPACE:
		flicked.emit(vector)                  # Space dashes the way the stick points (or the way the cat faces)


## The finger lifted: if it moved fast enough over the last flick window, that was a flick in that direction. A thumb
## that steers and then lifts slows down first, so steering, taps and slow lifts never dash.
func _flick_test(end: Vector2) -> void:
	var dc: Dictionary = Data.burrow_cfg()["dash"]
	var window := float(dc["flick_window_s"])
	var from := end
	for i in range(_trail.size() - 1, -1, -1):
		if _clock - float(_trail[i][1]) > window:
			break
		from = _trail[i][0]
	_trail.clear()
	var d := end - from
	if d.length() >= float(dc["flick_min_px"]):
		flicked.emit(d.normalized())


## The automated test flicks with this.
func force_flick(dir: Vector2) -> void:
	flicked.emit(dir)


func _blocked(p: Vector2) -> bool:
	# touches on a card are for its buttons, not for walking
	for c in get_tree().get_nodes_in_group("ui_block"):
		if c is Control and (c as Control).is_visible_in_tree() and (c as Control).get_global_rect().has_point(p):
			return true
	return false


func _update() -> void:
	var off := (knob - origin) / RADIUS
	var m := off.length()
	if m < DEADZONE:
		vector = Vector2.ZERO
	else:
		vector = off.normalized() * clampf((m - DEADZONE) / (1.0 - DEADZONE), 0.0, 1.0)
	queue_redraw()


func _process(delta: float) -> void:
	_clock += minf(delta, 0.1)
	while _trail.size() > 24:
		_trail.pop_front()
	if force:
		vector = forced if forced != Vector2.ZERO else auto      # a test holding still lets a tapped walk go on
		return
	if _index != -1:
		return
	var k := Vector2(
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))
		- float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))
		- float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	vector = k.normalized() if k != Vector2.ZERO else auto


func _draw() -> void:
	if not pressed:
		return                              # nothing on screen while no finger is down
	draw_circle(origin, RADIUS + 14.0, Color(0, 0, 0, 0.18))
	draw_arc(origin, RADIUS + 14.0, 0.0, TAU, 64, Color(1, 1, 1, 0.55), 4.0, true)
	var k := origin + (knob - origin).limit_length(RADIUS)
	draw_circle(k, KNOB, Color(1, 1, 1, 0.82))
	draw_arc(k, KNOB, 0.0, TAU, 48, Color(0.15, 0.25, 0.15, 0.6), 3.0, true)
