extends Control
## H3: a thing the player drags out of a window (a seed in the garden's window, an ingredient in the pot's): the first
## drag-and-drop in the game. It uses Godot's own drag (_get_drag_data and set_drag_preview), so on the phone a touch
## drags it as the mouse would (touch is emulated as the mouse). A press and release that moves less than TAP_PX is a
## tap instead (the `tapped` signal). It stops the touch (MOUSE_FILTER_STOP), so the card's scrolling body never takes
## the drag; the windows that use it fit without scrolling (drag and scroll do not mix).
## The payload says what is dragged: {"kind": "seed", "id": "<crop id>"} or {"kind": "food", "id": "<ingredient id>"}.
## The window draws the source itself (its children); `icon` is the picture that follows the finger.

signal tapped

const TAP_PX := 12.0                    # less movement than this between press and release is a tap, not a drag
const PREVIEW_MIN := 64.0               # the dragged picture's smallest side, HUD pixels

var payload: Dictionary = {}
var can_drag := true                    # false: it does not drag (you cannot pay for the seed, none left)
var icon: Texture2D

var _down := false
var _from := Vector2.ZERO


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not can_drag or payload.is_empty():
		return null
	var side := maxf(PREVIEW_MIN, minf(size.x, size.y))
	var pic := TextureRect.new()
	pic.texture = icon
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.size = Vector2(side, side)
	pic.position = -pic.size * 0.5                  # the picture sits centred on the finger
	pic.modulate.a = 0.9
	var holder := Control.new()                     # the viewport moves the preview's own position to the finger
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(pic)
	set_drag_preview(holder)                        # Godot shows it over everything, never inside the card's rows
	return payload.duplicate(true)


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


## A drag started (this one or any other): the press it began with is not a tap.
func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		_down = false
