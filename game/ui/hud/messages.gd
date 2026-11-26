extends RefCounted
## Messages: the banner, the toast, the tip with its arrow, the hint, the status line and the full-screen fade. A part of the HUD (hud.gd).

const HudStyle := preload("res://ui/hud/hud_style.gd")

var hud                                 # the HUD node (untyped on purpose: hud._stage_l and the rest are read at run time)
## A tip that waits for the one on screen to go first (gifts, which come with the "mission won" tips).
var _tip_queue: Array = []


func _init(h) -> void:
	hud = h


func build_overlay() -> void:
	hud._overlay = Control.new()
	hud._overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud._overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud._overlay.draw.connect(_draw_overlay)
	hud.add_child(hud._overlay)


func build() -> void:
	# the banner: a compact strip under the top bar
	hud._banner = PanelContainer.new()
	hud._banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.06, 0.045, 0.03, 0.55)
	bs.set_corner_radius_all(16)
	bs.content_margin_left = 16
	bs.content_margin_right = 16
	bs.content_margin_top = 6
	bs.content_margin_bottom = 8
	hud._banner.add_theme_stylebox_override("panel", bs)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 0)
	bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud._banner.add_child(bv)
	hud._banner_t = HudStyle.label("", 30)
	hud._banner_t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud._banner_t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud._banner_s = HudStyle.label("", 19)
	hud._banner_s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud._banner_s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bv.add_child(hud._banner_t)
	bv.add_child(hud._banner_s)
	hud._banner.modulate.a = 0.0
	hud.add_child(hud._banner)
	hud._toast = HudStyle.label("", 22)
	hud._toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud._toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud._toast.modulate.a = 0.0
	hud.add_child(hud._toast)
	hud._hide_l = HudStyle.label("", 21)
	hud._hide_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(hud._hide_l)
	# the tip and the hint: small lines just above the buttons at the bottom
	hud._tip = HudStyle.label("", 21)
	hud._tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud._tip.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	hud._tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud._tip.max_lines_visible = 2
	hud._tip.modulate.a = 0.0
	hud.add_child(hud._tip)
	hud._hint = HudStyle.label("Drag anywhere to move · tap things to use them", 22)
	hud._hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(hud._hint)


func build_fade() -> void:
	var fl := CanvasLayer.new()
	fl.layer = 20
	hud.add_child(fl)
	hud._fade = ColorRect.new()
	hud._fade.color = Color(0.043, 0.059, 0.039, 0.0)
	hud._fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud._fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud._fade.visible = false
	fl.add_child(hud._fade)


func tick_status() -> void:
	if hud.status != "":
		hud._hide_l.text = hud.status
		hud._hide_l.add_theme_color_override("font_color", Color(1.0, 0.8, 0.5))
		hud._hide_l.visible = true
	elif hud.main.hidden:
		hud._hide_l.text = "Hidden  ·  Ambush ready!" if hud.main.ambush_ready else "Hidden in the grass"
		hud._hide_l.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4) if hud.main.ambush_ready else Color(0.75, 1.0, 0.65))
		hud._hide_l.visible = true
	else:
		hud._hide_l.visible = false


func tick_tip(delta: float) -> void:
	if hud._tip_time > 0.0:
		hud._tip_time -= delta
		if hud._tip_time <= 0.0 or (hud._tip_ring != null and hud._tip_ring == hud._card_ring and hud._card != null):
			hud._tip_time = 0.0
			hud._tip_ring = null
			hud.create_tween().tween_property(hud._tip, "modulate:a", 0.0, 0.4)
	elif not _tip_queue.is_empty():
		var nxt: Array = _tip_queue.pop_front()
		tip(String(nxt[0]), nxt[1] if nxt[1] != null and is_instance_valid(nxt[1]) else null)


func hide_hint() -> void:
	if hud._hint.modulate.a > 0.0:
		hud.create_tween().tween_property(hud._hint, "modulate:a", 0.0, 0.6)


## A banner: a compact strip just under the top bar for about two seconds. `big` (a mission or a raid won or lost) is
## a little larger and stays a little longer, still at the top.
func banner(title: String, color := Color(1, 1, 1), sub := "", big := false) -> void:
	hud._banner_t.text = title
	hud._banner_t.add_theme_color_override("font_color", color)
	hud._banner_t.add_theme_font_size_override("font_size", 40 if big else 30)
	hud._banner_s.text = sub
	hud._banner_s.visible = sub != ""
	hud._banner_s.add_theme_font_size_override("font_size", 22 if big else 19)
	if hud._banner_tw != null and hud._banner_tw.is_valid():
		hud._banner_tw.kill()
	hud._banner.pivot_offset = Vector2(hud._banner.size.x * 0.5, 0)
	hud._banner.scale = Vector2(0.92, 0.92)
	var tw: Tween = hud.create_tween()
	hud._banner_tw = tw
	tw.set_parallel()
	tw.tween_property(hud._banner, "modulate:a", 1.0, 0.15)
	tw.tween_property(hud._banner, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval((3.0 if big else 1.6) + (0.5 if sub.length() > 40 else 0.0))
	tw.chain().tween_property(hud._banner, "modulate:a", 0.0, 0.35)


## Fades the whole screen to `alpha` over `secs` (Phase E: into and out of the Burrows). While it covers
## the screen, touches are for nothing (the joystick ignores them). Await it.
func fade(alpha: float, secs: float) -> void:
	hud._fade.visible = true
	if not hud._fade.is_in_group("ui_block"):
		hud._fade.add_to_group("ui_block")
	hud._fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw: Tween = hud._fade.create_tween()
	tw.tween_property(hud._fade, "color:a", alpha, maxf(secs, 0.01))
	await tw.finished
	if alpha <= 0.01:
		hud._fade.visible = false
		hud._fade.remove_from_group("ui_block")
		hud._fade.mouse_filter = Control.MOUSE_FILTER_IGNORE


## True while a banner is on screen (the Old Hollow's reveal waits for it).
func banner_busy() -> bool:
	return hud._banner.modulate.a > 0.02


## The same banner a moment later (a gift after the "mission won" banner, so both can be read).
func banner_later(delay: float, title: String, color := Color(1, 1, 1), sub := "", big := false) -> void:
	hud.get_tree().create_timer(delay).timeout.connect(banner.bind(title, color, sub, big))


## A short message under the top bar (under the banner when one shows).
func toast(text: String) -> void:
	hud._toast.text = text
	if hud._toast_tw != null and hud._toast_tw.is_valid():
		hud._toast_tw.kill()
	var tw: Tween = hud.create_tween()
	hud._toast_tw = tw
	tw.tween_property(hud._toast, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.7)
	tw.tween_property(hud._toast, "modulate:a", 0.0, 0.35)


## tip_after, a few seconds from now (after a banner).
func tip_after_delay(delay: float, text: String, ring) -> void:
	hud.get_tree().create_timer(delay).timeout.connect(func():
		tip_after(text, ring if ring != null and is_instance_valid(ring) else null))


func tip_after(text: String, ring) -> void:
	if hud._tip_time <= 0.0:
		tip(text, ring)
	else:
		_tip_queue.append([text, ring])


## A tip: a small line just above the buttons at the bottom, with an arrow to the marker it is about (it goes when
## that marker's card opens).
func tip(text: String, ring) -> void:
	hud._tip.text = text
	hud._tip_ring = ring
	hud._tip_time = 14.0
	hud.create_tween().tween_property(hud._tip, "modulate:a", 1.0, 0.3)


## Points the tip arrow at a spot in the world (a raid's trail) for `secs`: bobbing over it when it is on screen, at the
## screen's edge when it is not.
func point_at(world_pos: Vector3, secs: float) -> void:
	hud._point_pos = world_pos
	hud._point_t = secs


func _draw_overlay() -> void:
	if hud.main.cam == null:
		return
	var world_p: Vector3
	if hud._tip_ring != null and hud._tip_time > 0.0 and is_instance_valid(hud._tip_ring):
		world_p = hud._tip_ring.tip_point()
	elif hud._point_t > 0.0:
		world_p = hud._point_pos + Vector3(0, 0.3, 0)
	else:
		return
	var size: Vector2 = hud._overlay.size
	var behind: bool = hud.main.cam.is_position_behind(world_p)
	var sp: Vector2 = hud.main.cam.unproject_position(world_p)
	var t := Time.get_ticks_msec() * 0.001
	var gold := Color(1.0, 0.85, 0.3)
	var clear_top: float = hud._safe.x + hud._top_h + 40.0
	if not behind and Rect2(Vector2(30, clear_top), Vector2(size.x - 60, hud.p_layout._card_top() - clear_top - 30.0)).has_point(sp):
		var bob := sin(t * 6.0) * 10.0
		var tip_p := sp + Vector2(0, -50 + bob)
		hud._overlay.draw_colored_polygon(PackedVector2Array([tip_p, tip_p + Vector2(-26, -34), tip_p + Vector2(26, -34)]), gold)
		hud._overlay.draw_polyline(PackedVector2Array([tip_p, tip_p + Vector2(-26, -34), tip_p + Vector2(26, -34), tip_p]), Color(0.3, 0.18, 0.05), 3.0)
	else:
		var c := size * 0.5
		var dir := (sp - c).normalized() if not behind else (c - sp).normalized()
		var edge := c + dir * minf(size.x, size.y) * 0.42
		var a := dir.angle()
		var pts := PackedVector2Array([edge + Vector2(34, 0).rotated(a), edge + Vector2(-16, -22).rotated(a), edge + Vector2(-16, 22).rotated(a)])
		hud._overlay.draw_colored_polygon(pts, gold)


## The tip's arrow lets go of its marker (the cat went into a Burrow: a marker in the camp is 400 m away). The words stay.
func drop_tip_ring() -> void:
	hud._tip_ring = null


## The marker a tip points at, while the tip shows (it shows full size; main.gd).
func tip_ring():
	return hud._tip_ring if hud._tip_time > 0.0 and hud._tip_ring != null and is_instance_valid(hud._tip_ring) else null
