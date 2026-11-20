extends Control
## What fishing draws on the HUD while a line is out (fishing.gd): a "!" bubble over the float when it bites (white
## for a common catch, blue for an uncommon one, gold for a rare one), the closing ring while reeling (green when a
## tap pulls), and a word at the bottom of the screen. No buttons and no panel: it never takes a touch.

const BITE := {"common": Color(1.0, 1.0, 1.0), "uncommon": Color(0.45, 0.75, 1.0), "rare": Color(1.0, 0.8, 0.25)}

var fishing
var main


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if fishing == null or not fishing.busy() or main.cam == null:
		return
	var font := ThemeDB.fallback_font
	var vs := get_viewport_rect().size            # the HUD canvas (720 wide)
	var w := vs.x
	var at: Vector3 = fishing._at + Vector3(0, 0.12, 0)
	var on_screen: bool = not main.cam.is_position_behind(at)
	var sp: Vector2 = main.cam.unproject_position(at) if on_screen else Vector2(w * 0.5, vs.y * 0.4)
	var ph: String = fishing.phase
	var col: Color = BITE.get(fishing.rarity(), Color(1, 1, 1))
	var bottom := ""
	var bottom_col := Color(1, 1, 1)
	match ph:
		"cast", "wait":
			bottom = "Wait for the bite..."
			bottom_col = Color(0.85, 0.95, 1.0)
		"bite":
			var c := sp + Vector2(0, -70)
			draw_circle(c, 30.0, Color(0.1, 0.08, 0.05, 0.55))
			draw_circle(c, 26.0, col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-8, 20), c + Vector2(8, 20), c + Vector2(0, 40)]), col)
			draw_string(font, c + Vector2(-30, 15), "!", HORIZONTAL_ALIGNMENT_CENTER, 60, 42, Color(0.2, 0.12, 0.05))
			bottom = "Tap!"
			bottom_col = col
		"reel":
			_reel_ring(sp)
			bottom = "Tap when the ring turns green!" if not fishing.in_zone() else "Now!"
			bottom_col = Color(0.55, 1.0, 0.5) if fishing.in_zone() else Color(1, 1, 1)
		"land":
			bottom = ""
	if bottom != "":
		var y: float = main.hud.line_y()        # the small line just above the buttons, never mid-screen
		var fs := 28
		draw_string_outline(font, Vector2(0, y), bottom, HORIZONTAL_ALIGNMENT_CENTER, w, fs, 12, Color(0.12, 0.08, 0.05, 0.85))
		draw_string(font, Vector2(0, y), bottom, HORIZONTAL_ALIGNMENT_CENTER, w, fs, bottom_col)


## The ring closes from 110 px to 36 px over one pulse; it is green while a tap would be a good pull.
func _reel_ring(sp: Vector2) -> Vector2:
	var c: Dictionary = Data.b["fishing"]
	var k := clampf(fishing._pulse_t / float(c["pulse_s"]), 0.0, 1.0)
	var r := lerpf(110.0, 36.0, k)
	var green: bool = fishing.in_zone()
	draw_arc(sp, 36.0, 0.0, TAU, 40, Color(1, 1, 1, 0.5), 3.0, true)
	draw_arc(sp, r, 0.0, TAU, 48, Color(0.45, 1.0, 0.4, 0.95) if green else Color(1.0, 0.95, 0.8, 0.85), 6.0 if green else 4.0, true)
	return sp
