extends Node
## Taps (19 Nov 2026, "Tap to open"; docs/PHASE_A_PROGRESS.md). The cat moves by dragging anywhere (joystick.gd); a tap
## is a short touch that barely moves (TAP_S, TAP_PX), so the end of a drag is never a tap. A tap on a marker's badge
## (marker.gd) or on the thing it marks opens its card as a dialog (hud.show_card) when the cat is within reach; further
## away the cat walks there by itself and the card opens when it arrives. A finger down (a drag, or a tap somewhere
## else) stops that walk. A tap on empty ground does nothing. Taps on the HUD's buttons and dialogs are theirs, and
## taps are ignored while fishing (the line takes them), while placing a defence and while the game is frozen.
## Nothing here reads a clock: only its own frame seconds.

const TAP_S := 0.35                  # a tap is shorter than this
const TAP_PX := 26.0                 # and moves less than this (HUD pixels: the canvas is 720 wide)
const PICK_PAD := 1.35               # a badge takes taps a little beyond its edge (a thumb is bigger than a badge)
const GIVE_UP_S := 14.0              # a walk that has not arrived by then stops

var main
var walking = null                   # the marker the cat walks to (its card opens on arrival)
var taps := 0                        # taps that reached a marker (the tests read it)
var _touch := {}                     # finger -> [where it went down, when, how far it has moved, on the HUD]
var _clock := 0.0
var _walk_t := 0.0
var _check_t := 0.0
var _side_t := 0.0
var _side := 1.0
var _last := Vector3.ZERO


func _input(event: InputEvent) -> void:
	if main == null:
		return
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			var on_hud: bool = main.joystick._blocked(e.position)
			_touch[e.index] = [e.position, _clock, 0.0, on_hud]
			if not on_hud and walking != null:
				stop_walk()                              # a finger on the ground takes the cat back
		elif _touch.has(e.index):
			var tc: Array = _touch[e.index]
			_touch.erase(e.index)
			var moved := maxf(float(tc[2]), e.position.distance_to(tc[0]))
			if not bool(tc[3]) and _clock - float(tc[1]) <= TAP_S and moved <= TAP_PX:
				tap(e.position)
	elif event is InputEventScreenDrag and _touch.has((event as InputEventScreenDrag).index):
		var tc2: Array = _touch[(event as InputEventScreenDrag).index]
		tc2[2] = maxf(float(tc2[2]), (event as InputEventScreenDrag).position.distance_to(tc2[0]))


## Can a tap use something now?
func can_tap() -> bool:
	return not main.frozen and main.player.hp > 0 and not main.player.frozen and not main.hud.card_open() \
		and not (main.fishing != null and main.fishing.busy()) and main.defences.placing == ""


## A tap at a point of the screen (HUD pixels): the marker there, if any, is used. True if one was.
func tap(pos: Vector2) -> bool:
	if not can_tap():
		return false
	var r = pick(pos)
	if r == null:
		return false
	taps += 1
	use(r)
	return true


## The marker under a point of the screen: its badge (a little bigger than it looks), or the thing itself (from its
## foot to its top). The nearest wins; a badge wins a close call.
func pick(pos: Vector2):
	var cam: Camera3D = main.cam
	if cam == null:
		return null
	var best = null
	var best_d := INF
	for r in main.rings:
		if not is_instance_valid(r) or not r.is_visible_in_tree():
			continue
		var bp: Vector3 = r.badge_pos()
		if not cam.is_position_behind(bp):
			var sp := cam.unproject_position(bp)
			var hw: float = maxf(r.half_px(cam), 22.0) * PICK_PAD
			var d := Vector2((pos.x - sp.x) / hw, (pos.y - sp.y) / (hw * 1.25)).length()
			if d < 1.0 and d < best_d:
				best = r
				best_d = d
		var body: Array = r.body_px(cam)
		if not body.is_empty():
			var c := Geometry2D.get_closest_point_to_segment(pos, body[0], body[1])
			var dd := pos.distance_to(c) / float(body[2]) + 0.4
			if dd < 1.4 and dd < best_d:
				best = r
				best_d = dd
	return best


## Use a marker: its card opens now if the cat is within reach, else the cat walks there first.
func use(r) -> void:
	if r == null or not is_instance_valid(r) or main.player.hp <= 0:
		return
	r.tapped()
	Sfx.play("pop", -14.0)
	if r.in_reach(main.player.global_position):
		stop_walk()
		main.open_ring(r)
		return
	walking = r
	_walk_t = 0.0
	_check_t = 0.0
	_side_t = 0.0
	_last = main.player.global_position


func stop_walk() -> void:
	walking = null
	if main != null and main.joystick != null:
		main.joystick.auto = Vector2.ZERO


func _process(delta: float) -> void:
	var d := minf(delta, 0.1)
	_clock += d
	if walking == null:
		return
	var p: Vector3 = main.player.global_position
	if not is_instance_valid(walking) or not walking.is_visible_in_tree() or main.frozen or main.player.frozen or main.player.hp <= 0 \
			or main.hud.card_open() or (main.fishing != null and main.fishing.busy()) or main.defences.placing != "":
		stop_walk()
		return
	var to: Vector3 = walking.global_position - p
	to.y = 0.0
	var dist := to.length()
	# arrived: well inside its spot (the Training Target's practice spot too), or in reach once the way is blocked
	if dist < walking.radius * 0.7 or (dist < walking.reach() and _walk_t > 3.0 and _side_t > 0.0):
		var r = walking
		stop_walk()
		r.tapped()
		main.open_ring(r)
		return
	_walk_t += d
	if _walk_t > GIVE_UP_S:
		if walking.in_reach(p):
			var r2 = walking
			stop_walk()
			main.open_ring(r2)
		else:
			stop_walk()
		return
	_check_t += d
	if _check_t > 0.4:
		if p.distance_to(_last) < 0.08:
			_side_t = 0.6                                # stuck on something: step round it, then go on
			_side = -_side
		_last = p
		_check_t = 0.0
	var v := Vector2(to.x, to.z).normalized()
	if _side_t > 0.0:
		v = (v + Vector2(-v.y, v.x) * 1.4 * _side).normalized()
		_side_t -= d
	main.joystick.auto = v * clampf(dist * 1.5, 0.35, 1.0)
