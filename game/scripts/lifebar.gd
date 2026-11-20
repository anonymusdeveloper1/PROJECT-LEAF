extends Control
## The health bars over the cat's head (Draft 7, the user's design): flat and simple, just red, a little see-through
## so they hide nothing in a crowd. A hit drains the red, and the part just lost shows grey for a moment before it
## goes. While the cat rides, a thinner bar of the same width right under it shows the mount's health (mount.gd).

const W := 96.0                          # bar width, in HUD pixels (the HUD is 720 wide)
const H := 11.0                          # the cat's bar
const H_MOUNT := 7.0                     # the mount's bar, under it
const GAP := 3.0
const LIFT := 1.25                       # metres above the cat's feet (plus the saddle height while riding)
const RED := Color(0.92, 0.18, 0.18, 0.8)
const GREY := Color(0.86, 0.86, 0.86, 0.55)
const BACK := Color(0.0, 0.0, 0.0, 0.3)
const HOLD := 0.35                       # seconds the grey stays before it drains away
const DRAIN := 1.6                       # share of the bar the grey drains per second

const MOSS := Color(0.55, 0.8, 0.35, 0.85)     # the Moss Warden's bar (Phase C), over its head in a mission
const W_WARDEN := 120.0
const H_WARDEN := 7.0

var main
var _bars := {"cat": [1.0, 1.0, 0.0], "mount": [1.0, 1.0, 0.0], "warden": [1.0, 1.0, 0.0]}   # [now, grey trail, hold time], as shares


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	var p = main.player
	if p == null or main.cam == null:
		return
	visible = true                                       # the cat's bars hide in _draw while it is down
	_step("cat", clampf(float(p.hp) / float(maxi(1, Data.cat_max_hp())), 0.0, 1.0), delta)
	var m = main.mount
	if m != null and m.max_hp() > 0:
		_step("mount", clampf(float(m.hp) / float(m.max_hp()), 0.0, 1.0), delta)
	var g = main.guardian
	if g != null:
		_step("warden", clampf(float(g.hp) / maxf(float(g.max_hp()), 1.0), 0.0, 1.0), delta)
	queue_redraw()


func _step(id: String, now: float, delta: float) -> void:
	var b: Array = _bars[id]
	if now < b[0]:
		b[2] = HOLD                                      # just hit: hold the grey a moment
	b[0] = now
	if b[1] < now:
		b[1] = now                                       # healed: no grey
	elif b[2] > 0.0:
		b[2] -= delta
	else:
		b[1] = maxf(now, b[1] - DRAIN * delta)


func _draw() -> void:
	var p = main.player
	if p == null or main.cam == null:
		return
	_draw_warden()
	if p.hp <= 0:
		return
	var head: Vector3 = p.global_position + Vector3(0, LIFT + (p.model.position.y if p.model else 0.0), 0)
	if main.cam.is_position_behind(head):
		return
	var sp: Vector2 = main.cam.unproject_position(head)
	var top := Vector2(sp.x - W * 0.5, sp.y - H - 8.0)
	_bar(Rect2(top, Vector2(W, H)), _bars["cat"])
	var m = main.mount
	var below := top.y + H
	if p.riding and m != null and m.max_hp() > 0:
		_bar(Rect2(top + Vector2(0, H + GAP), Vector2(W, H_MOUNT)), _bars["mount"])
		below += GAP + H_MOUNT
	# Phase E: the Leaf Dash recharging, a small arc under the bars (hidden when it is ready or not available)
	if main.has_method("dash_enabled") and main.dash_enabled() and p.has_method("dash_ready_frac"):
		var f: float = p.dash_ready_frac()
		if f < 1.0:
			var c := Vector2(sp.x, below + 14.0)
			draw_arc(c, 8.0, 0.0, TAU, 20, BACK, 3.0, true)
			draw_arc(c, 8.0, -PI / 2.0, -PI / 2.0 + TAU * f, 20, Color(0.6, 1.0, 0.75, 0.9), 3.0, true)


func _bar(r: Rect2, b: Array, col := RED) -> void:
	draw_rect(r.grow(1.5), BACK)
	if b[1] > b[0]:
		draw_rect(Rect2(r.position + Vector2(r.size.x * b[0], 0), Vector2(r.size.x * (b[1] - b[0]), r.size.y)), GREY)
	if b[0] > 0.0:
		draw_rect(Rect2(r.position, Vector2(r.size.x * b[0], r.size.y)), col)


## The Moss Warden in a mission: a moss-green bar while it is hurt (or was hit in the last 2 s); knocked down, an arc
## over the heap that fills as it pulls itself together, the seconds left, and "x2" while the cat helps.
func _draw_warden() -> void:
	var g = main.guardian
	if g == null or not g.visible or not main.fight.active or g.state == "sleep":
		return
	if g.state == "down":
		var at: Vector3 = g.global_position + Vector3(0, 1.0, 0)
		if main.cam.is_position_behind(at):
			return
		var c: Vector2 = main.cam.unproject_position(at)
		var total: float = maxf(float(g._down_total), 0.01)
		var frac := 1.0 - clampf(float(g._down_t) / total, 0.0, 1.0)
		var rate: float = float(Data.b["guardian"]["help_rate"]) if g.helping else 1.0
		draw_circle(c, 30.0, Color(0, 0, 0, 0.35))
		draw_arc(c, 26.0, -PI / 2.0, -PI / 2.0 + TAU * frac, 40, MOSS, 5.0, true)
		var font := ThemeDB.fallback_font
		draw_string(font, c + Vector2(-26, 7), "%d" % int(ceil(float(g._down_t) / rate)), HORIZONTAL_ALIGNMENT_CENTER, 52, 20, Color(1, 1, 1))
		if g.helping:
			draw_string(font, c + Vector2(-26, -36), "x2", HORIZONTAL_ALIGNMENT_CENTER, 52, 20, Color(0.75, 1.0, 0.55))
		return
	if not (float(g.hp) < float(g.max_hp()) - 0.5 or float(g.hit_t) > 0.0):
		return
	var head: Vector3 = g.global_position + Vector3(0, g._height() + 0.25, 0)
	if main.cam.is_position_behind(head):
		return
	var sp: Vector2 = main.cam.unproject_position(head)
	if not Rect2(Vector2.ZERO, get_viewport_rect().size).grow(60.0).has_point(sp):
		return
	_bar(Rect2(Vector2(sp.x - W_WARDEN * 0.5, sp.y - H_WARDEN), Vector2(W_WARDEN, H_WARDEN)), _bars["warden"], MOSS)
