extends RefCounted
## The top-centre group (H2, the owner's sketch "Raid indicator and progress"): the raid bar, the campfire's thin bar
## under it during a fight, the words line under them, and the boss bar under the group. A part of the HUD (hud.gd).
## The raid bar (_gate_bar) draws no words and no numbers (the owner: progress, "not showing how many enemies are
## left"); every word is on the words line (_stage_l). What it shows:
##   a Raid Mission's wave    the share of this wave's enemies beaten (fight.wave_total(); a Gloom Totem raises it)
##   between waves            an empty track (the words: the next wave and its roads)
##   the Gloom meter          violet, filling (paler while it waits for you; pulsing when a raid waits)
##   a raid's warning         the countdown, gold to red
##   a Random Raid's attack   the share of the whole attack beaten (the save's defeated list, exact after a resume)
##   the Gloomwood            the fight pips (filled = won, a ring = on now, hollow = ahead, a crown on the boss)
## The campfire bar (the owner, 26 Nov 2026): gold to red, no number, flashing white when the fire is hit; in the Last
## Stand it pulses red and the words line says so.

const HudStyle := preload("res://ui/hud/hud_style.gd")
const LAST_STAND := "Last stand: rebuild the fire"
const BACK := Color(0.05, 0.035, 0.02, 0.55)            # the bars' dark track
const PROGRESS := Color(0.56, 0.86, 0.36)               # the share beaten
const GLOOM := Color(0.62, 0.4, 0.95)                   # the Gloom meter
const GOLD := Color(0.95, 0.75, 0.3)
const RED := Color(1.0, 0.3, 0.25)
const PAD := 3.0                                        # the fill inside the raid bar's track

var hud                                 # the HUD node (untyped on purpose: hud._stage_l and the rest are read at run time)
var progress_done := 0                  # the last fight_progress (the bar itself reads the fight when it draws)
var progress_total := 0
var _fire_hp := -1.0
var _fire_max := -1.0
var _fire_flashing := false
var _track_sb: StyleBoxFlat
var _fill_sb: StyleBoxFlat
var _fire_sb: StyleBoxFlat


func _init(h) -> void:
	hud = h


func build() -> void:
	# the words line under the bars
	hud._stage_l = HudStyle.label("", 19)
	hud._stage_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud._stage_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hud._stage_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hud._stage_l.clip_text = true
	hud._stage_l.add_to_group("hud_edge")
	hud.add_child(hud._stage_l)
	hud._gate_bar = Control.new()
	hud._gate_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud._gate_bar.draw.connect(_draw_gate)
	hud._gate_bar.add_to_group("hud_edge")
	hud.add_child(hud._gate_bar)
	hud._fire_bar = Control.new()
	hud._fire_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud._fire_bar.visible = false
	hud._fire_bar.draw.connect(_draw_fire)
	hud._fire_bar.add_to_group("hud_edge")
	hud.add_child(hud._fire_bar)
	hud._boss_bar = Control.new()
	hud._boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud._boss_bar.draw.connect(_draw_boss)
	hud._boss_bar.add_to_group("hud_edge")
	hud.add_child(hud._boss_bar)
	_track_sb = StyleBoxFlat.new()
	_track_sb.bg_color = BACK
	_track_sb.set_corner_radius_all(12)
	_track_sb.border_color = Color(1.0, 0.93, 0.8, 0.35)
	_track_sb.set_border_width_all(2)
	_fill_sb = StyleBoxFlat.new()
	_fill_sb.set_corner_radius_all(9)
	_fire_sb = StyleBoxFlat.new()
	_fire_sb.set_corner_radius_all(4)


func refresh(below: bool) -> void:
	var f = hud.main.fight
	var shown: bool = below or f.active or (hud.main.raids != null and hud.main.raids.meter_shown())
	hud._stage_l.visible = shown
	hud._gate_bar.visible = shown
	if shown:
		hud._stage_l.text = _words(below)


## What the words line says now: the Gloomwood's level, the fight's line (the next wave's roads, the wave, the raid's
## name), the Last Stand, or the Gloom meter's words.
func _words(below: bool) -> String:
	if below:
		return hud.main.area.status_text()
	var f = hud.main.fight
	if f.active:
		return LAST_STAND if f.last_stand else f.status_text()
	return hud.main.raids.hud_text() if hud.main.raids != null else ""


func refresh_bar() -> void:
	hud._bar_key = ""
	hud._gate_bar.queue_redraw()
	hud._fire_bar.queue_redraw()


func tick_stage() -> void:
	var rd = hud.main.raids
	var meter_on: bool = rd != null and rd.meter_shown()
	var below: bool = hud.main.get("area") != null
	if below:
		hud._stage_l.visible = true
		hud._gate_bar.visible = true
		hud._stage_l.text = _words(true)
		meter_on = false
	elif hud.main.fight.active:
		hud._stage_l.text = _words(false)
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
	var f = hud.main.fight
	var below: bool = hud.main.get("area") != null
	# the campfire's bar: in a fight at the camp (a mission, or a raid's attack; not its warning)
	var fire_on: bool = hud._gate_bar.visible and not below and f.active and not (f.mode == "raid" and f.warning)
	if hud._fire_bar.visible != fire_on:
		hud._fire_bar.visible = fire_on
		_fire_hp = -1.0
	if fire_on:
		var hp: float = f.gate_hp
		var max_hp: float = f.gate_max
		var flashing: bool = hud._gate_flash > 0.0
		if hp != _fire_hp or max_hp != _fire_max or flashing != _fire_flashing or f.last_stand:
			_fire_hp = hp
			_fire_max = max_hp
			_fire_flashing = flashing
			hud._fire_bar.queue_redraw()
	if hud._gate_bar.visible:
		if below:
			hud._gate_bar.queue_redraw()
		elif not f.active or (f.mode == "raid" and f.warning):
			# the Gloom meter or the warning: only when what it shows changes (half a meter point, a second), or every
			# frame while it pulses
			var key: String = rd.bar_key() if rd != null else ""
			if key != hud._bar_key or key.begins_with("pulse"):
				hud._bar_key = key
				hud._gate_bar.queue_redraw()
		elif hud._bar_key != "fight":
			hud._bar_key = "fight"                       # a fight began: the bar redraws on fight_progress from now on
			hud._gate_bar.queue_redraw()
	hud._boss_bar.visible = hud.boss != null and is_instance_valid(hud.boss) and not hud.boss.dead
	if hud._boss_bar.visible:
		hud._boss_bar.queue_redraw()


func gate_hit() -> void:
	hud._gate_flash = 0.25
	hud._fire_bar.queue_redraw()


## The raid bar's fill in a fight: the share of this wave (a Raid Mission) or of the whole attack (a Random Raid)
## beaten, 0 between waves; -1 when the bar shows something else (the Gloom meter, a warning, the Gloomwood's pips).
func fill() -> float:
	var f = hud.main.fight
	if hud.main.get("area") != null or not f.active or (f.mode == "raid" and f.warning):
		return -1.0
	if not f.in_wave:
		return 0.0
	if f.mode == "raid":
		var run: Dictionary = Save.raids.get("run", {})
		var beaten: int = (run.get("defeated", []) as Array).size()
		return clampf(float(beaten) / float(maxi(int(f.raid_total()), 1)), 0.0, 1.0)
	var total: int = f.wave_total()
	return clampf(float(maxi(0, total - int(f.left_in_wave()))) / float(maxi(total, 1)), 0.0, 1.0)


func _draw_gate() -> void:
	if hud.main.get("area") != null:
		_draw_pips()
		return
	var f = hud.main.fight
	if not f.active or (f.mode == "raid" and f.warning):
		_draw_raid_bar()
		return
	_bar(fill(), PROGRESS)


## The track and its fill (0..1) in `col`.
func _bar(share: float, col: Color) -> void:
	var g: Control = hud._gate_bar
	g.draw_style_box(_track_sb, Rect2(Vector2.ZERO, g.size))
	if share <= 0.0:
		return
	var inner := Rect2(PAD, PAD, g.size.x - PAD * 2.0, g.size.y - PAD * 2.0)
	_fill_sb.bg_color = col
	g.draw_style_box(_fill_sb, Rect2(inner.position, Vector2(maxf(inner.size.x * share, inner.size.y), inner.size.y)))


## In the Gloomwood: one circle per fight on the way and one for the end, centred in the raid bar's place.
func _draw_pips() -> void:
	var g: Control = hud._gate_bar
	var pips: Array = hud.main.area.fight_pips()
	if pips.is_empty():
		return
	var w: float = g.size.x
	var gap := 12.0
	var r := 9.0
	var need := pips.size() * 2.0 * r + (pips.size() - 1) * gap
	if need > w - 8.0:
		var k := (w - 8.0) / need
		r *= k
		gap *= k
		need = w - 8.0
	var x := (w - need) * 0.5 + r
	var cy: float = g.size.y * 0.5
	for p in pips:
		var c := Vector2(x, cy)
		var col := Color(1.0, 0.86, 0.45)
		g.draw_circle(c, r + 2.5, Color(0.1, 0.07, 0.04, 0.55))
		match int(p[0]):
			2: g.draw_circle(c, r, col)
			1:
				g.draw_arc(c, r - 1.5, 0, TAU, 24, col, 3.5, true)
				g.draw_circle(c, 3.5, col)
			_: g.draw_arc(c, r - 1.5, 0, TAU, 24, Color(1, 1, 1, 0.55), 2.0, true)
		if bool(p[1]):
			var t := c + Vector2(0, -r - 3)
			g.draw_colored_polygon(PackedVector2Array([t + Vector2(-7, 0), t + Vector2(-7, -6), t + Vector2(-3.5, -2.5), t + Vector2(0, -8),
				t + Vector2(3.5, -2.5), t + Vector2(7, -6), t + Vector2(7, 0)]), Color(1.0, 0.5, 0.45))
		x += 2.0 * r + gap


## The Gloom meter (violet), or a raid's warning counting down (gold to red). No words: they are on the words line.
func _draw_raid_bar() -> void:
	var rd = hud.main.raids
	if rd == null:
		return
	var st: String = rd.hud_state()
	var frac: float = rd.hud_frac()
	if st == "warning":
		_bar(frac, GOLD.lerp(RED, 1.0 - frac))
		return
	var col := GLOOM
	if st == "idle":
		col.a = 0.6
	_bar(frac, col)
	if st == "blocked":
		var g: Control = hud._gate_bar
		var pulse := 0.25 + 0.3 * sin(Time.get_ticks_msec() * 0.008)
		_fill_sb.bg_color = Color(0.95, 0.8, 1.0, pulse)
		g.draw_style_box(_fill_sb, Rect2(PAD, PAD, g.size.x - PAD * 2.0, g.size.y - PAD * 2.0))


## The campfire's thin bar: gold to red as it burns down, white for a moment when hit; the Last Stand pulses red.
func _draw_fire() -> void:
	var b: Control = hud._fire_bar
	var f = hud.main.fight
	var rect := Rect2(Vector2.ZERO, b.size)
	var sb := _fire_sb
	sb.bg_color = BACK
	b.draw_style_box(sb, rect)
	if f.last_stand:
		sb.bg_color = Color(0.8, 0.12, 0.1, 0.55 + 0.4 * sin(Time.get_ticks_msec() * 0.008))
		b.draw_style_box(sb, rect)
		b.queue_redraw()
		return
	var frac := clampf(f.gate_hp / maxf(f.gate_max, 1.0), 0.0, 1.0)
	if frac <= 0.0:
		return
	sb.bg_color = Color(1, 1, 1) if hud._gate_flash > 0.0 else GOLD.lerp(RED, 1.0 - frac)
	b.draw_style_box(sb, Rect2(Vector2.ZERO, Vector2(maxf(b.size.x * frac, b.size.y), b.size.y)))


func _draw_boss() -> void:
	if hud.boss == null or not is_instance_valid(hud.boss):
		return
	var w: float = hud._boss_bar.size.x
	var frac: float = clampf(hud.boss.hp / maxf(hud.boss.max_hp, 1.0), 0.0, 1.0)
	hud._boss_bar.draw_rect(Rect2(0, 0, w, 30), Color(0, 0, 0, 0.5))
	hud._boss_bar.draw_rect(Rect2(3, 3, (w - 6) * frac, 24), Color(0.7, 0.35, 0.95))
	var bt: String = String(hud.boss.get("title")) if hud.boss.get("title") != null and String(hud.boss.get("title")) != "" else String(hud.boss.info["name"])
	hud._boss_bar.draw_string(ThemeDB.fallback_font, Vector2(10, 22), bt, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(1, 1, 1))
