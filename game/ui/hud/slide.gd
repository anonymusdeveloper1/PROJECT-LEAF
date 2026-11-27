extends RefCounted
## H2: the HUD's buttons slide and fade in and out (about 0.2 s) instead of popping (the owner's sketch, PHASE_H_PLAN H2
## point 5). Static: hud_layout.gd and action_buttons.gd call it; no class_name.
##   show(c, true)   the control shows at once, is back in the ui_block group (so the joystick leaves its touches
##                   alone) and takes touches; it fades in and slides from `from` to its place, easing out.
##   show(c, false)  at once it leaves ui_block and ignores touches (a finger there moves the cat, and the tests no
##                   longer see it), then it fades out, slides back by `from` and hides.
## A slid control keeps its place: the layout puts it with at(c, place) every frame and the slide only adds its offset,
## which shrinks to nothing as the control fades in (its modulate's alpha is the slide's progress). So the per-frame
## layout never fights the tween.

const SECS := 0.2
const FROM := Vector2(0, 24)              # where a button slides in from (just below its place)


## Slides `c` in (on) or out. Nothing happens when it is already going that way. `now` skips the animation (the HUD's
## first frame).
static func show(c: Control, on: bool, from := FROM, now := false) -> void:
	if c == null:
		return
	c.set_meta("slide_from", from)
	if c.has_meta("slide_on") and bool(c.get_meta("slide_on")) == on and not now:
		return
	c.set_meta("slide_on", on)
	var old: Variant = c.get_meta("slide_tw") if c.has_meta("slide_tw") else null
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	if on:
		c.visible = true
		if not c.is_in_group("ui_block"):
			c.add_to_group("ui_block")
		c.mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		c.remove_from_group("ui_block")
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if now or not c.is_inside_tree():
		c.modulate.a = 1.0 if on else 0.0
		c.visible = on
		return
	var tw := c.create_tween()
	c.set_meta("slide_tw", tw)
	tw.tween_property(c, "modulate:a", 1.0 if on else 0.0, SECS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if not on:
		tw.tween_callback(c.hide)


## Puts `c` at `place` (in its parent), offset by what is left of its slide.
static func at(c: Control, place: Vector2) -> void:
	var from: Vector2 = c.get_meta("slide_from", FROM)
	c.position = place + from * (1.0 - clampf(c.modulate.a, 0.0, 1.0))


## The control is in, or sliding in (false once it started sliding out).
static func is_on(c: Control) -> bool:
	return c != null and is_instance_valid(c) and bool(c.get_meta("slide_on", c.visible))
