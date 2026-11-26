extends RefCounted
## The fight's slot at the top: the words line, the campfire / raid / Burrow bar on the right, and the boss bar under it. A part of the HUD (hud.gd).

const HudStyle := preload("res://ui/hud/hud_style.gd")

var hud                                 # the HUD node (untyped on purpose: hud._stage_l and the rest are read at run time)
var progress_done := 0
var progress_total := 0
var _fire_hp := -1.0
var _fire_max := -1.0
var _fire_flashing := false


func _init(h) -> void:
	hud = h


func build() -> void:
	# the fight: the status line and the bar on the right of the top bar, the boss bar under it
	hud._stage_l = HudStyle.label("", 18)
	hud._stage_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud._stage_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hud._stage_l.clip_text = true
	hud.add_child(hud._stage_l)
	hud._gate_bar = Control.new()
	hud._gate_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud._gate_bar.draw.connect(_draw_gate)
	hud.add_child(hud._gate_bar)
	hud._boss_bar = Control.new()
	hud._boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud._boss_bar.draw.connect(_draw_boss)
	hud.add_child(hud._boss_bar)


func refresh(below: bool) -> void:
	var f = hud.main.fight
	var shown: bool = below or f.active or (hud.main.raids != null and hud.main.raids.meter_shown())
	hud._stage_l.visible = shown
	hud._gate_bar.visible = shown
	if below:
		hud._stage_l.text = hud.main.area.status_text()
	elif f.active:
		hud._stage_l.text = f.status_text()
	elif shown:
		hud._stage_l.text = hud.main.raids.hud_text()


func refresh_bar() -> void:
	hud._bar_key = ""
	hud._gate_bar.queue_redraw()


func tick_stage() -> void:
	var rd = hud.main.raids
	var meter_on: bool = rd != null and rd.meter_shown()
	if hud.main.get("area") != null:
		hud._stage_l.visible = true
		hud._gate_bar.visible = true
		hud._stage_l.text = hud.main.area.status_text()
		meter_on = false
	elif hud.main.fight.active:
		hud._stage_l.text = hud.main.fight.status_text()
	elif meter_on:
		hud._stage_l.visible = true
		hud._gate_bar.visible = true
		hud._stage_l.text = rd.hud_text()
		hud._stage_l.modulate.a = 0.6 if rd.hud_state() == "idle" else 1.0
	elif hud._stage_l.visible:
		hud._stage_l.visible = false
		hud._gate_bar.visible = false
	if hud.main.fight.active or not meter_on:
		hud._stage_l.modulate.a = 1.0


func tick_bar() -> void:
	var rd = hud.main.raids
	if hud._gate_bar.visible:
		if hud.main.get("area") != null:
			hud._gate_bar.queue_redraw()
		elif hud.main.fight.active and not (hud.main.fight.mode == "raid" and hud.main.fight.warning):
			var hp: float = hud.main.fight.gate_hp
			var max_hp: float = hud.main.fight.gate_max
			var flashing: bool = hud._gate_flash > 0.0
			if hp != _fire_hp or max_hp != _fire_max or flashing != _fire_flashing or hud.main.fight.last_stand:
				_fire_hp = hp
				_fire_max = max_hp
				_fire_flashing = flashing
				hud._gate_bar.queue_redraw()
		else:
			# the raid bar: only when what it shows changes (half a meter point, a second), or every frame while it pulses
			var key: String = rd.bar_key() if rd != null else ""
			if key != hud._bar_key or key.begins_with("pulse"):
				hud._bar_key = key
				hud._gate_bar.queue_redraw()
	hud._boss_bar.visible = hud.boss != null and is_instance_valid(hud.boss) and not hud.boss.dead
	if hud._boss_bar.visible:
		hud._boss_bar.queue_redraw()


func gate_hit() -> void:
	hud._gate_flash = 0.25
	hud._gate_bar.queue_redraw()


func _draw_gate() -> void:
	var f = hud.main.fight
	if hud.main.get("area") != null:
		_draw_pips()
		return
	if not f.active or (f.mode == "raid" and f.warning):
		_draw_raid_bar()
		return
	var w: float = hud._gate_bar.size.x
	var frac := clampf(f.gate_hp / maxf(f.gate_max, 1.0), 0.0, 1.0)
	hud._gate_bar.draw_rect(Rect2(0, 0, w, 30), Color(0, 0, 0, 0.45))
	var c := Color(0.95, 0.75, 0.3).lerp(Color(1, 0.3, 0.25), 1.0 - frac)
	if hud._gate_flash > 0.0:
		c = Color(1, 1, 1)
	hud._gate_bar.draw_rect(Rect2(3, 3, (w - 6) * frac, 24), c)
	if f.last_stand:
		var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.008)
		hud._gate_bar.draw_rect(Rect2(3, 3, w - 6, 24), Color(0.55, 0.1, 0.1, pulse))
		hud._gate_bar.draw_string(ThemeDB.fallback_font, Vector2(8, 24), "LAST STAND", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 0.92, 0.85))
		hud._gate_bar.queue_redraw()
		return
	hud._gate_bar.draw_string(ThemeDB.fallback_font, Vector2(8, 24), "Campfire %d" % int(ceil(f.gate_hp)), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.15, 0.08, 0.05))


## In a Burrow: one circle per fight on the way, and one for the end (filled = won, a ring = on now, hollow = ahead,
## a crown on the boss).
func _draw_pips() -> void:
	var pips: Array = hud.main.area.fight_pips()
	var w: float = hud._gate_bar.size.x
	var gap := 12.0
	var r := 11.0
	var need := pips.size() * 2.0 * r + (pips.size() - 1) * gap
	if need > w - 8.0:
		var k := (w - 8.0) / need
		r *= k
		gap *= k
	var x := w - r - 4.0 - (pips.size() - 1) * (2.0 * r + gap)
	for p in pips:
		var c := Vector2(x, 15)
		var col := Color(1.0, 0.86, 0.45)
		hud._gate_bar.draw_circle(c, r + 2.5, Color(0.1, 0.07, 0.04, 0.55))
		match int(p[0]):
			2: hud._gate_bar.draw_circle(c, r, col)
			1:
				hud._gate_bar.draw_arc(c, r - 1.5, 0, TAU, 24, col, 3.5, true)
				hud._gate_bar.draw_circle(c, 4.0, col)
			_: hud._gate_bar.draw_arc(c, r - 1.5, 0, TAU, 24, Color(1, 1, 1, 0.55), 2.0, true)
		if bool(p[1]):
			var t := c + Vector2(0, -r - 4)
			hud._gate_bar.draw_colored_polygon(PackedVector2Array([t + Vector2(-8, 0), t + Vector2(-8, -7), t + Vector2(-4, -3), t + Vector2(0, -9),
				t + Vector2(4, -3), t + Vector2(8, -7), t + Vector2(8, 0)]), Color(1.0, 0.5, 0.45))
		x += 2.0 * r + gap


## The Gloom meter (violet, "Raid at 100%"), or a raid's warning counting down (gold to red, "0:38").
func _draw_raid_bar() -> void:
	var rd = hud.main.raids
	if rd == null:
		return
	var w: float = hud._gate_bar.size.x
	var st: String = rd.hud_state()
	var frac: float = rd.hud_frac()
	hud._gate_bar.draw_rect(Rect2(0, 0, w, 30), Color(0.08, 0.05, 0.14, 0.6))
	if st == "warning":
		var c := Color(0.95, 0.75, 0.3).lerp(Color(1, 0.3, 0.25), 1.0 - frac)
		hud._gate_bar.draw_rect(Rect2(3, 3, (w - 6) * frac, 24), c)
		var txt: String = "Defend Camp at signpost"
		hud._gate_bar.draw_string(ThemeDB.fallback_font, Vector2(8, 24), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.15, 0.08, 0.05))
		return
	var col := Color(0.62, 0.4, 0.95)
	if st == "idle":
		col.a = 0.6
	hud._gate_bar.draw_rect(Rect2(3, 3, (w - 6) * frac, 24), col)
	var label := "Raid at 100%"
	if st == "blocked":
		var pulse := 0.35 + 0.35 * sin(Time.get_ticks_msec() * 0.008)
		hud._gate_bar.draw_rect(Rect2(3, 3, w - 6, 24), Color(0.95, 0.8, 1.0, pulse))
		label = "Raid waiting"
	hud._gate_bar.draw_string(ThemeDB.fallback_font, Vector2(8, 24), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 0.95, 1.0, 0.95 if st != "idle" else 0.6))


func _draw_boss() -> void:
	if hud.boss == null or not is_instance_valid(hud.boss):
		return
	var w: float = hud._boss_bar.size.x
	var frac: float = clampf(hud.boss.hp / maxf(hud.boss.max_hp, 1.0), 0.0, 1.0)
	hud._boss_bar.draw_rect(Rect2(0, 0, w, 30), Color(0, 0, 0, 0.5))
	hud._boss_bar.draw_rect(Rect2(3, 3, (w - 6) * frac, 24), Color(0.7, 0.35, 0.95))
	var bt: String = String(hud.boss.get("title")) if hud.boss.get("title") != null and String(hud.boss.get("title")) != "" else String(hud.boss.info["name"])
	hud._boss_bar.draw_string(ThemeDB.fallback_font, Vector2(10, 22), bt, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(1, 1, 1))
