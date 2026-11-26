extends RefCounted
## Where everything goes: the phone's safe insets, the top stack, the bottom buttons, the tip and the hint. A part of the HUD (hud.gd): it moved here from hud.gd (H2, P1) without a change.

const HudStyle := preload("res://ui/hud/hud_style.gd")
const LINE2_H := 24.0                   # its second line, when there is something on it: the dish, the status line
const GATE_W := 236.0
const EDGE := 14.0                      # side margins

var hud                                 # the HUD node (untyped on purpose: hud._stage_l and the rest are read at run time)


func _init(h) -> void:
	hud = h


## The phone's safe insets (status bar and camera hole on top, the gesture bar at the bottom), in HUD pixels.
func _insets() -> Vector2:
	var out := Vector2.ZERO
	for a in Data.args():
		if a.begins_with("--safe-top="):
			out.x = float(a.substr(11))
		elif a.begins_with("--safe-bottom="):
			out.y = float(a.substr(14))
	if OS.has_feature("mobile"):
		var win := DisplayServer.window_get_size()
		var at := DisplayServer.window_get_position()
		var safe := DisplayServer.get_display_safe_area()
		var vis: Vector2 = hud.get_viewport().get_visible_rect().size
		if win.y > 0 and safe.size.y > 0:
			var k := vis.y / float(win.y)
			out.x = maxf(out.x, float(safe.position.y - at.y) * k)
			out.y = maxf(out.y, float(at.y + win.y - safe.end.y) * k)
	return Vector2(clampf(out.x, 0.0, 160.0), clampf(out.y, 0.0, 120.0))


func _layout() -> void:
	hud._safe = _insets()
	_place_all()
	if hud._card != null and hud._card_list != null and is_instance_valid(hud._card_list):
		var n: int = hud._grid_cols()                         # the screen turned or changed size: the open dialog's grids follow
		for g in hud._card_list.get_children():
			if g is GridContainer and (g as GridContainer).columns != n:
				(g as GridContainer).columns = n


## Where everything goes this frame: the top bar grows a second line when there is something on it, and what sits
## under it stacks down (boss bar, banner, toast, status line); at the bottom the buttons, with the tip and the hint
## just above them. A dialog takes none of this room: it sits over the dim (_place_card).
func _place_all() -> void:
	var size: Vector2 = hud.get_viewport().get_visible_rect().size
	var t: float = hud._safe.x
	var two: bool = hud._stage_l.visible or hud._meal_l.visible or hud._eg_l.visible
	hud._top_h = hud.ROW_H + (LINE2_H if two else 0.0) + 4.0
	hud._top.position = Vector2(0, 0)
	hud._top.size = Vector2(size.x, t + hud._top_h)
	hud._res.position = Vector2(EDGE, t + 8)
	hud._res.size = Vector2(size.x * 0.6, 34)
	hud._gate_bar.position = Vector2(size.x - EDGE - GATE_W, t + 10)
	hud._gate_bar.size = Vector2(GATE_W, 30)
	hud._line2.position = Vector2(EDGE, t + hud.ROW_H)
	hud._line2.size = Vector2(0, LINE2_H)
	var used := 0.0
	if hud._eg_l.visible:
		used += HudStyle.text_w(hud._eg_l)
	if hud._meal_l.visible:
		var mw: float = minf(HudStyle.text_w(hud._meal_l), size.x * 0.4)
		hud._meal_l.custom_minimum_size = Vector2(mw, 0)
		used += mw + (12.0 if hud._eg_l.visible else 0.0)
	var gap := 16.0 if used > 0.0 else 0.0
	hud._stage_l.position = Vector2(EDGE + used + gap, t + hud.ROW_H - 2)
	hud._stage_l.size = Vector2(size.x - EDGE * 2.0 - used - gap, LINE2_H)
	var y: float = t + hud._top_h + 6.0
	hud._boss_bar.position = Vector2(EDGE + 4, y)
	hud._boss_bar.size = Vector2(size.x - EDGE * 2.0 - 8.0, 30)
	if hud._boss_bar.visible:
		y += 36.0
	hud._banner.position = Vector2(26, y)
	hud._banner.size = Vector2(size.x - 52, 0)
	hud._banner.custom_minimum_size = Vector2(size.x - 52, 0)
	if hud._banner.modulate.a > 0.01:
		y += hud._banner.get_combined_minimum_size().y + 6.0
	hud._toast.position = Vector2(30, y)
	hud._toast.size = Vector2(size.x - 60, 30)
	if hud._toast.modulate.a > 0.01:
		y += hud._toast.get_combined_minimum_size().y + 2.0
	hud._hide_l.position = Vector2(0, y)
	hud._hide_l.size = Vector2(size.x, 28)
	if hud._hide_l.visible:
		y += 30.0
	hud._zone_end = y
	# the bottom: the buttons above the gesture bar
	var bottom: float = size.y - hud._safe.y
	var bar_y := bottom - 16.0 - 84.0
	var buttons := true
	hud.bag_button.position = Vector2(20, bar_y)
	hud.bag_button.size = Vector2(116, 84)
	hud.bag_button.visible = not hud._place_bar.visible
	hud.bag_button.disabled = hud.main.frozen or hud.main.player.hp <= 0 or (hud.main.fishing != null and hud.main.fishing.busy())
	hud._build_bar.position = Vector2(148, bar_y)
	hud._build_bar.size = Vector2(size.x - 168, 84)
	hud._place_bar.position = Vector2(20, bar_y - 6.0)
	hud._place_bar.size = Vector2(size.x - 40, 96)
	hud._build_bar.modulate.a = 1.0 if buttons else 0.0
	hud._place_bar.modulate.a = 1.0 if buttons else 0.0
	hud._build_bar.mouse_filter = Control.MOUSE_FILTER_PASS if buttons else Control.MOUSE_FILTER_IGNORE
	for c in hud._build_bar.get_children() + hud._place_bar.get_children():
		(c as Control).visible = buttons
	var line_bottom := bar_y - 6.0
	hud._hint.position = Vector2(0, line_bottom - 30.0)
	hud._hint.size = Vector2(size.x, 30)
	var tip_bottom: float = (line_bottom - 32.0) if hud._hint.modulate.a > 0.01 else line_bottom
	hud._tip.size = Vector2(size.x - 60, 0)
	var th: float = hud._tip.get_combined_minimum_size().y
	hud._tip.position = Vector2(30, tip_bottom - th)
	hud._tip.size = Vector2(size.x - 60, th)
	# the tip and the hint never land mid-screen. While fishing, its words ("Tap!") take the hint's line.
	var low: bool = hud._tip.position.y > size.y * 0.66
	hud._tip.visible = low
	hud._hint.visible = hud._hint.position.y > size.y * 0.66 and not (hud.main.fishing != null and hud.main.fishing.busy())


## The y of the line just above the bottom buttons (fishing's "Tap!" and the like).
func line_y() -> float:
	return hud._hint.position.y + 26.0


## The bottom of the clear part of the screen (above the phone's gesture bar): a dialog takes no room there.
func _card_top() -> float:
	var size: Vector2 = hud.get_viewport().get_visible_rect().size
	return size.y - hud._safe.y
