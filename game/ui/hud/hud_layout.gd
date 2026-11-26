extends RefCounted
## Where everything goes (H2: the owner's sketch, docs/PHASE_H_PLAN.md H2; the H2 map's part 2 gives every rectangle
## and the proofs that nothing always-on enters the middle third and nothing overlaps). HUD pixels: the canvas is 720
## wide (a 540x960 window shows it at 0.75); t is the phone's top inset, b the bottom of the clear screen (above the
## gesture bar). A part of the HUD (hud.gd).
##   top-left    the three currencies (t+10), the endgame label and the running potions line under them (t+46; H3:
##               it ends before the gear's column)
##   top-right   the Settings gear (64 x 64)
##   top-centre  the raid bar (460 x 24, t+76), the campfire's thin bar (t+104, in a fight), the words line (t+114);
##               then the boss bar and the messages (banner, toast, status line), which never pass H/3 - 4 (a toast that
##               does not fit waits, messages.gd)
##   row 2       the defences to place at the left, Ride / Walk or the Mount Health Potion at the right (b-196)
##   row 1       the Bag and the build icon at the left, the Health Potion at the right (b-100); Place and Done centred
##               while placing (the potion buttons hide then: Done reaches 7 px into row 1's right slot)
##   the tip and the hint just above row 2
## The buttons slide in and out (slide.gd): the layout gives each its place every frame and the slide adds its offset.

const HudStyle := preload("res://ui/hud/hud_style.gd")
const Slide := preload("res://ui/hud/slide.gd")
const ActionButtons := preload("res://ui/hud/action_buttons.gd")
const EDGE := 16.0                      # the top's side margins
const RES_Y := 10.0                     # the currencies
const RES_H := 32.0
const LINE2_Y := 46.0                   # the line under them
const LINE2_H := 22.0
const GEAR := 64.0                      # the round gear, at the top-right
const GEAR_Y := 8.0
const BAR_W := 460.0                    # the raid bar, centred
const BAR_Y := 76.0
const BAR_H := 24.0
const FIRE_Y := 104.0                   # the campfire's thin bar under it
const FIRE_H := 8.0
const WORDS_X := 40.0                   # the words line under them
const WORDS_Y := 114.0
const WORDS_H := 26.0
const GROUP_H := 140.0                  # _top_h while the raid group shows (the words line's bottom)
const GEAR_H := 72.0                    # ... and without it (the gear's bottom)
const STACK_GAP := 6.0
const BOSS_H := 30.0
const GUARD := 4.0                      # the stack ends this far above the middle third
const SIDE := 20.0                      # the bottom's side margins
const ROW1 := 100.0                     # row 1's top, up from b
const ROW2 := 196.0                     # row 2's top, up from b
const BTN := Vector2(170, 84)           # Ride / Walk, the two potion buttons
const BAG := Vector2(116, 84)
const ICON := Vector2(84, 84)           # the build icon
const DEF := Vector2(124, 84)           # the defence buttons (a little smaller)
const GAP := 12.0                       # between the Bag and the build icon
const DEF_GAP := 10.0
const PLACE := Vector2(170, 96)         # Place and Done
const PLACE_Y := 106.0
const PLACE_GAP := 14.0
const LINE_GAP := 6.0                   # between row 2 and the hint

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


## Where everything goes this frame (see the header). A dialog takes none of this room: it sits over the dim
## (_place_card).
func _place_all() -> void:
	var size: Vector2 = hud.get_viewport().get_visible_rect().size
	var t: float = hud._safe.x
	var w := size.x
	# the top-left: the currencies, the line under them
	hud._res.position = Vector2(EDGE, t + RES_Y)
	hud._res.size = Vector2(0, RES_H)
	hud._line2.position = Vector2(EDGE, t + LINE2_Y)
	hud._line2.size = Vector2(0, LINE2_H)
	if hud._meal_l.visible:                              # H3: the running potions line, kept clear of the gear's column
		var room := w - EDGE * 2.0 - GEAR - 12.0
		if hud._eg_l.visible:
			room -= HudStyle.text_w(hud._eg_l) + 12.0
		hud._meal_l.custom_minimum_size = Vector2(clampf(HudStyle.text_w(hud._meal_l), 0.0, maxf(0.0, room)), 0)
	# the top-right: the gear
	hud._gear.position = Vector2(w - EDGE - GEAR, t + GEAR_Y)
	hud._gear.size = Vector2(GEAR, GEAR)
	# the top-centre: the raid bar, the campfire's bar, the words
	hud._top_h = GROUP_H if hud._gate_bar.visible else GEAR_H
	var bx := (w - BAR_W) * 0.5
	hud._gate_bar.position = Vector2(bx, t + BAR_Y)
	hud._gate_bar.size = Vector2(BAR_W, BAR_H)
	hud._fire_bar.position = Vector2(bx, t + FIRE_Y)
	hud._fire_bar.size = Vector2(BAR_W, FIRE_H)
	hud._stage_l.position = Vector2(WORDS_X, t + WORDS_Y)
	hud._stage_l.size = Vector2(w - WORDS_X * 2.0, WORDS_H)
	# under them: the boss bar, the banner, the toast, the status line, never past the guard
	var limit := _limit()
	var y := _toast_y()
	hud._toast.position = Vector2(30, y)
	hud._toast.size = Vector2(w - 60, 30)
	if hud._toast.modulate.a > 0.01:
		y += hud._toast.get_combined_minimum_size().y + 2.0
	hud._hide_l.position = Vector2(0, y)
	hud._hide_l.size = Vector2(w, 28)
	if hud._hide_l.visible:
		if y + 28.0 > limit:
			hud._hide_l.visible = false                  # no room under a big banner: it comes back when the banner goes
		else:
			y += 30.0
	hud._zone_end = y
	_place_bottom(size)


## The boss bar and the banner (from the top group down); returns where the toast goes.
func _toast_y() -> float:
	var w: float = hud.get_viewport().get_visible_rect().size.x
	var y: float = hud._safe.x + hud._top_h + STACK_GAP
	hud._boss_bar.position = Vector2(18, y)
	hud._boss_bar.size = Vector2(w - 36.0, BOSS_H)
	if hud._boss_bar.visible:
		y += BOSS_H + STACK_GAP
	hud._banner.position = Vector2(26, y)
	hud._banner.size = Vector2(w - 52, 0)
	hud._banner.custom_minimum_size = Vector2(w - 52, 0)
	var tw: Tween = hud._banner_tw
	if hud._banner.modulate.a > 0.01 or (tw != null and tw.is_valid() and tw.is_running()):
		y += hud._banner.get_combined_minimum_size().y + STACK_GAP
	return y


## The bottom of the room the top stack may use: just above the middle third.
func _limit() -> float:
	return hud.get_viewport().get_visible_rect().size.y / 3.0 - GUARD


## The toast fits under the boss bar and the banner without reaching the middle third.
func toast_fits() -> bool:
	return _toast_y() + hud._toast.get_combined_minimum_size().y <= _limit()


## The bottom rows (header). Each button sits in a fixed place; a button sliding out keeps its place until it hides.
func _place_bottom(size: Vector2) -> void:
	var w := size.x
	var b: float = size.y - hud._safe.y
	var r1 := b - ROW1
	var r2 := b - ROW2
	var a: ActionButtons = hud.p_actions
	# row 1, left: the Bag and the build icon
	hud.bag_button.size = BAG
	Slide.at(hud.bag_button, Vector2(SIDE, r1))
	hud.bag_button.disabled = hud.main.frozen or hud.main.player.hp <= 0 or (hud.main.fishing != null and hud.main.fishing.busy())
	hud._build_icon.size = ICON
	Slide.at(hud._build_icon, Vector2(SIDE + BAG.x + GAP, r1))
	# the right-hand column (_build_bar): Ride / Walk or the Mount Health Potion in row 2, the Health Potion in row 1
	hud._build_bar.position = Vector2(w - SIDE - BTN.x, r2)
	hud._build_bar.size = Vector2(BTN.x, ROW2 - ROW1 + BTN.y)
	for c in [a.ride_button, a.mount_potion_button]:
		_right(c as Button, 0.0)
	_right(a.potion_button, ROW2 - ROW1)
	# row 2, left: the defences, packed from the left
	hud._defence_bar.position = Vector2(SIDE, r2)
	hud._defence_bar.size = Vector2(maxf(0.0, w - SIDE * 2.0 - BTN.x - GAP), DEF.y)
	var x := 0.0
	var row2: bool = (a.ride_button as Button).visible or (a.mount_potion_button as Button).visible
	for type in ActionButtons.DEFENCES:
		var d: Button = a.def_buttons[type]
		if not d.visible:
			continue
		d.size = DEF
		Slide.at(d, Vector2(x, 0))
		x += d.size.x + DEF_GAP
		row2 = true
	# Place and Done, centred in row 1 while placing
	hud._place_bar.position = Vector2(0, b - PLACE_Y)
	hud._place_bar.size = Vector2(w, PLACE.y)
	hud.p_actions.place_button.size = PLACE
	hud.p_actions.done_button.size = PLACE
	Slide.at(hud.p_actions.place_button, Vector2(w * 0.5 - PLACE_GAP * 0.5 - PLACE.x, 0))
	Slide.at(hud.p_actions.done_button, Vector2(w * 0.5 + PLACE_GAP * 0.5, 0))
	hud._bottom_h = ROW2 if row2 else ROW1               # the edge arrows stay above the rows that show
	# the hint and the tip just above row 2; they never land mid-screen. While fishing, its words ("Tap!") take the
	# hint's line.
	var line_bottom := r2 - LINE_GAP
	hud._hint.position = Vector2(0, line_bottom - 30.0)
	hud._hint.size = Vector2(w, 30)
	var tip_bottom: float = (line_bottom - 32.0) if hud._hint.modulate.a > 0.01 else line_bottom
	hud._tip.size = Vector2(w - 60, 0)
	var th: float = hud._tip.get_combined_minimum_size().y
	hud._tip.position = Vector2(30, tip_bottom - th)
	hud._tip.size = Vector2(w - 60, th)
	var low: bool = hud._tip.position.y > size.y * 0.66
	hud._tip.visible = low
	hud._hint.visible = hud._hint.position.y > size.y * 0.66 and not (hud.main.fishing != null and hud.main.fishing.busy())


## A button of the right-hand column at its place, `y` down in the column, against its right edge (a long word makes
## it wider to the left, never off the screen).
func _right(c: Button, y: float) -> void:
	c.size = BTN
	Slide.at(c, Vector2(BTN.x - c.size.x, y))


## The y of the line just above the bottom buttons (fishing's "Tap!" and the like).
func line_y() -> float:
	return hud._hint.position.y + 26.0


## The bottom of the clear part of the screen (above the phone's gesture bar): a dialog takes no room there.
func _card_top() -> float:
	var size: Vector2 = hud.get_viewport().get_visible_rect().size
	return size.y - hud._safe.y
