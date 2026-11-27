extends Control
## H3: a place in a window that takes a dragged thing (a garden plot takes a seed, a pot slot an ingredient): the other
## half of the drag kit (drag_source.gd). The window decides what it takes and what a drop does:
##   accepts  payload -> bool   e.g. a seed, on an empty open plot
##   dropped  payload -> void   e.g. main.garden.plant(id, i)
## A press and release that moves less than TAP_PX is a tap (the `tapped` signal: pick a ripe plot, empty a pot slot).
## It stops the touch (MOUSE_FILTER_STOP), so the card does not scroll under it. The window draws the slot itself.

signal tapped

const TAP_PX := 12.0                    # less movement than this between press and release is a tap

var accepts: Callable                   # payload (Dictionary) -> bool; without one the slot takes nothing
var dropped: Callable                   # payload (Dictionary) -> void

var _down := false
var _from := Vector2.ZERO


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary) or not accepts.is_valid():
		return false
	return bool(accepts.call(data))


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is Dictionary and dropped.is_valid():
		dropped.call(data)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			_down = true
			_from = mb.position
		elif _down:
			_down = false
			if mb.position.distance_to(_from) < TAP_PX:
				tapped.emit()
				accept_event()
	elif event is InputEventMouseMotion and _down:
		if (event as InputEventMouseMotion).position.distance_to(_from) >= TAP_PX:
			_down = false                           # moved too far: no tap on release


## A drag started anywhere: the press it began with is not a tap.
func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		_down = false
