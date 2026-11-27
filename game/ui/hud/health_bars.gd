extends Control
## One health bar, drawn the same way as the bars over the cat (lifebar.gd): a dark back, the colour filled to the
## share, and the part just lost shown grey for a moment (HOLD, then DRAIN). No numbers. Used by the Bag; others
## preload it (no class_name).

const RED := Color(0.92, 0.18, 0.18, 0.8)       # the cat's bar (same as lifebar.gd)
const MOUNT := Color(0.98, 0.66, 0.16, 0.85)    # the mount's bar (same as lifebar.gd)
const BACK := Color(0.0, 0.0, 0.0, 0.3)
const GREY := Color(0.86, 0.86, 0.86, 0.55)    # the part just lost (same as lifebar.gd)
const HOLD := 0.35                              # seconds the grey stays before it drains away
const DRAIN := 1.6                              # share of the bar the grey drains per second

var share := 1.0
var colour := RED
var _trail := 1.0                               # the grey trail, as a share (above share while a hit is fading)
var _hold := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


## Sets the fill (0..1) and redraws only when it changed. A drop leaves a grey trail that drains away.
func set_share(value: float) -> void:
	value = clampf(value, 0.0, 1.0)
	if is_equal_approx(value, share):
		return
	if value < share:
		_hold = HOLD                            # just hit: hold the grey a moment
		set_process(true)
	share = value
	_trail = maxf(_trail, share)
	queue_redraw()


func set_colour(value: Color) -> void:
	colour = value
	queue_redraw()


func _process(delta: float) -> void:
	if _trail <= share:
		_trail = share
		set_process(false)
		return
	if _hold > 0.0:
		_hold -= delta
	else:
		_trail = maxf(share, _trail - DRAIN * delta)
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size).grow(-1.5)   # the back reaches 1.5 px past the bar, like lifebar.gd
	draw_rect(r.grow(1.5), BACK)
	if _trail > share:
		draw_rect(Rect2(r.position + Vector2(r.size.x * share, 0), Vector2(r.size.x * (_trail - share), r.size.y)), GREY)
	if share > 0.0:
		draw_rect(Rect2(r.position, Vector2(r.size.x * share, r.size.y)), colour)
