extends Node3D
## The Burrows (Phase E, docs/PHASE_E_SPEC.md; dungeons as paths since docs/DUNGEON_SPEC.md), open once every mission
## is won. This node is main.burrows. In the camp it keeps each Burrow's hollow (balance.json burrows.list: the Old
## Hollow, the way into the Gloomwood): its model, sealed with Gloom crystals from the first mission won and opened by
## the last mission's first win, its marker and card (the levels: the highest open one, or a lower one), the Hollow keys
## (a bonus only: entry is free and unlimited). The run itself is burrow_run.gd (main.area while the cat is in it).
## Nothing here reads a clock: a run in progress is saved at its checkpoints and waits at the Hollow while the game is
## closed.

const RingScript := preload("res://scripts/marker.gd")
const RunScript := preload("res://scripts/burrow_run.gd")
const VIOLET := Color(0.78, 0.55, 1.0)
const GOLD := Color(1.0, 0.82, 0.3)

var main
var runner                          # burrow_run.gd: the run; main.area points to it while the cat is below ground
var entrances := {}                 # burrow id -> {"node", "ring", "seal", "eyes", "glow", "pos": Vector3}
var use_key := true                 # the Hollow card's choice: spend a key on the next run for a boon at the start
var pick_level := 0                 # the Hollow card's level (0: the highest open one)
var map_override := ""              # tests only: play another map (a treasure-end test map) through the same Hollow
var _eye_t := 0.0
var _eye_on := 0.0
var _rng := RandomNumberGenerator.new()   # only for the eyes' blink (never the game's own random sequence)
var _reveal_waits := 0
var _revealing := false


func cfg() -> Dictionary:
	return Data.burrow_cfg()


func build(m) -> void:
	main = m
	_rng.seed = 4242
	runner = Node3D.new()
	runner.set_script(RunScript)
	runner.b = self
	runner.main = m
	add_child(runner)
	for bd in Data.burrow_list():
		_build_entrance(bd)
	Save.changed.connect(refresh)
	if main.raids != null:                               # Phase D's signals: the marker shows "blocked" while a raid is on
		main.raids.raid_started.connect(func(_spec): refresh())
		main.raids.raid_ended.connect(func(_won, _perfect): refresh())
	refresh()


func _build_entrance(bd: Dictionary) -> void:
	var id := String(bd["id"])
	var en: Dictionary = bd["entrance"]
	var pos := Vector3(float(en["pos"][0]), 0, float(en["pos"][2]))
	var node := Props.instance(String(en.get("model", "burrow_hollow")))
	node.position = pos
	add_child(node)
	main.world.add_circle(pos, float(en["radius"]), "hollow:" + id)
	for r in en.get("roots", []):                       # giant roots snaking from the treeline toward the hollow
		var rt := Props.instance(String(r[0]))
		rt.position = Vector3(float(r[1][0]), 0, float(r[1][2]))
		rt.rotation.y = float(r[2])
		add_child(rt)
	var rg := Node3D.new()
	rg.set_script(RingScript)
	add_child(rg)
	rg.setup("hollow:" + id, Vector3(float(en["ring"][0]), 0, float(en["ring"][2])), float(en.get("ring_r", 0.8)), card.bind(id), VIOLET)
	rg.attach(node, "", 1.9, Vector3(1.05, 0.0, -0.3))   # its badge over the hollow's east side, clear of the cat
	main.register_ring(rg)
	entrances[id] = {"node": node, "ring": rg, "pos": pos, "seal": Props.find_part(node, "seal"),
		"eyes": Props.find_part(node, "eyes"), "glow": Props.find_part(node, "glow")}


## The marker of a Burrow's hollow (the first one when id is "").
func ring(id := "") -> Node3D:
	if id == "":
		id = String(Data.burrow_list()[0]["id"])
	return entrances[id]["ring"] if entrances.has(id) else null


func is_open(id: String) -> bool:
	var bd := Data.burrow_def(id)
	return Data.burrows_open() and String(bd.get("opens", "missions")) == "missions"


## Sealed or open: the seal and the eyes, the glowing rim, the marker (violet while sealed, gold once open; its "!"
## shows when the cat can go in).
func refresh() -> void:
	if main == null:
		return
	for id in entrances:
		var e: Dictionary = entrances[id]
		var bd := Data.burrow_def(id)
		var open := is_open(id)
		if not _revealing:
			if e["seal"] != null:
				(e["seal"] as Node3D).visible = not open
			if e["eyes"] != null and open:
				(e["eyes"] as Node3D).visible = false
		if e["glow"] != null:
			(e["glow"] as Node3D).visible = open
		var r = e["ring"]
		r.visible = Data.progress() >= int(bd["entrance"].get("ring_from_missions", 1)) and main.get("area") == null
		r.set_color(GOLD if open else VIOLET)
		r.pulse = open and blocker() == "" and main.get("area") == null


func _process(delta: float) -> void:
	if main == null or main.frozen:
		return
	var d := minf(delta, 0.1)
	# the two violet eyes under the seal blink now and then (0.25 s every 4-7 s), only while sealed
	_eye_t -= d
	_eye_on = maxf(0.0, _eye_on - d)
	if _eye_t <= 0.0:
		_eye_t = _rng.randf_range(4.0, 7.0)
		_eye_on = 0.25
	for id in entrances:
		var eyes = entrances[id]["eyes"]
		if eyes != null:
			(eyes as Node3D).visible = _eye_on > 0.0 and not is_open(id) and not _revealing


# ---------------------------------------------------------------- the reveal (the last mission's first win)
## Called from main.on_stage_end after a mission, and once when the game starts (old_save: a save that already won every
## mission). The condition is checked now; the reveal itself comes a few seconds later, after the other banners.
func check_open(old_save := false) -> void:
	if Data.burrows_open() or Data.next_mission() < Data.mission_count() or _revealing:
		return
	_revealing = true
	_reveal_waits = 0
	var wait := float(cfg()["reveal_old_save_s"] if old_save else cfg()["reveal_after_win_s"])
	get_tree().create_timer(wait).timeout.connect(_try_reveal)


func _try_reveal() -> void:
	if main.hud.banner_busy() and _reveal_waits < int(cfg()["reveal_wait_max"]):
		_reveal_waits += 1
		get_tree().create_timer(float(cfg()["reveal_wait_s"])).timeout.connect(_try_reveal)
		return
	open_hollow(true)


func open_hollow(celebrate: bool) -> void:
	_revealing = false
	if Data.burrows_open():
		refresh()
		return
	Save.set_flag("hollow_open")
	Save.burrow_keys = maxi(Save.burrow_keys, int(cfg()["keys"]["open_fill"]))
	Save.save_game()
	var first: Dictionary = Data.burrow_list()[0]
	var e: Dictionary = entrances.get(String(first["id"]), {})
	if celebrate and not e.is_empty():
		var h: Vector3 = e["pos"]
		main.shake(0.35)
		var seal = e["seal"]
		if seal != null:
			var tw := (seal as Node3D).create_tween().set_parallel()
			tw.tween_property(seal, "position:y", (seal as Node3D).position.y - 1.2, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_property(seal, "scale:y", 0.1, 0.9)
			tw.chain().tween_callback(func(): (seal as Node3D).visible = false)
		Fx.shockwave(main, h, 2.4)
		for k in 3:
			Fx.kill(main, h + Vector3(0, 0.8, 0), VIOLET)
		Fx.flower_ring(main, h, 2.0)
		Sfx.play("win", -3.0)
		main.hud.banner("%s opens!" % hollow_name(first), GOLD, "%s waits under the roots" % String(first["name"]))
		if not Save.flag("told_hollow"):
			Save.set_flag("told_hollow")
			main.hud.tip_after_delay(3.6, "%s is open at the woods' edge: the way into %s. Go in as often as you like: your pet and %s come too." % [
				hollow_name(first), String(first["name"]), Data.mount_name() if main.mount != null else "your mount"], ring())
	refresh()
	main.stations.refresh()
	main.hud.refresh()


# ---------------------------------------------------------------- Hollow keys (a bonus only)
## Every key comes through here (raids held, first clears; the "replay" key is kept but no longer comes, Phase F has no
## mission replays): at most keys.cap held; one more turns into leaves. Returns how many fitted.
func grant_key(_reason: String, n := 1) -> int:
	var k: Dictionary = cfg()["keys"]
	var cap := int(k["cap"])
	var fit := clampi(cap - Save.burrow_keys, 0, n)
	Save.burrow_keys += fit
	var over := n - fit
	if over > 0:
		Save.leaves += over * int(k["overflow_leaves"])
		main.hud.toast("Key ring full: +%d leaves" % (over * int(k["overflow_leaves"])))
	elif fit > 0:
		main.hud.toast("+%d Hollow key%s (%d of %d)" % [fit, "" if fit == 1 else "s", Save.burrow_keys, cap])
	Save.save_game()
	return fit


# ---------------------------------------------------------------- the Hollow card
## Why the cat cannot go in now ("" when it can). The user's rule: only a fight on, or a Gloom Raid on its way.
## A damaged camp only shows a warning on the card.
func blocker() -> String:
	if main.fight.active:
		return "Finish the fight first"
	if bool(Save.raids.get("pending", false)):
		return "A Gloom Raid is coming: defend the camp first"
	return ""


## What a damaged camp shows on the card (a reminder only: it never blocks).
func camp_warning() -> String:
	var n := 0
	if Data.raids_open() and main.raids != null:
		n = (main.raids.camp_check()["items"] as Array).size()
	else:
		n = Save.ruined.size() + int(main.defences.wrecked_count())
	if Save.fire_ruined:
		return "The campfire is ashes: rebuild it when you come back"
	if n > 0:
		return "%d thing%s to mend · raids wait while you are away" % [n, "" if n == 1 else "s"]
	return ""


## The hollow in the camp ("The Old Hollow"); the Burrow's own name is its dungeon's ("The Gloomwood").
static func hollow_name(bd: Dictionary) -> String:
	return String(bd.get("entrance", {}).get("name", bd["name"]))


func card(id: String) -> Dictionary:
	var bd := Data.burrow_def(id)
	var nm := hollow_name(bd)
	var anchor: Vector3 = entrances[id]["pos"] + Vector3(0, 2.2, 0) if entrances.has(id) else Vector3.ZERO
	if not is_open(id):
		return {"title": nm, "sub": "Sealed by the Gloom", "anchor": anchor, "rows": [
			{"text": "Win every mission to open it", "note": "%d of %d won · something sleeps under the roots" % [Data.progress(), Data.mission_count()],
				"cost": {}, "label": "", "enabled": false, "action": Callable()}]}
	var rows: Array = []
	var why := blocker()
	if not Save.burrow_run.is_empty() and String(Save.burrow_run.get("burrow", id)) == id:
		return {"title": nm, "sub": "Your run is waiting", "anchor": anchor, "rows": runner.run_card_rows(id, why)}
	var sub := "The way into %s · Hollow keys %d of %d" % [String(bd["name"]), Save.burrow_keys, int(cfg()["keys"]["cap"])]
	if Save.meal_ready != "" and bool(cfg().get("meals_in_runs", true)):
		sub += " · your %s goes down with you" % String(Data.recipe(Save.meal_ready).get("name", "dish"))
	if why != "":
		rows.append({"text": why, "note": "", "cost": {}, "label": "", "enabled": false, "action": Callable()})
		return {"title": nm, "sub": sub, "anchor": anchor, "rows": rows}
	var top := Data.burrow_depth(id) + 1
	var lv := top if pick_level <= 0 or pick_level > top else pick_level
	var nf := Data.burrow_fights(id)
	var note := "%d fight%s and %s · pays %s" % [nf, "" if nf == 1 else "s", Data.burrow_end_name(id), _pays(lv)]
	if Data.power() < Data.depth_power(lv):
		note += " · tough for you now"
	rows.append({"text": "%s · Level %d" % [String(bd["name"]), lv] + (" · new" if lv == top and top > 1 else ""), "note": note, "cost": {}, "label": "Go in",
		"enabled": true, "pulse": lv == top, "action": enter.bind(id, lv)})
	if top > 1:
		rows.append({"text": "Play another level", "note": "Levels 1 to %d are open · lower ones are easier" % top, "cost": {},
			"label": "Lower" if lv > 1 else "Highest", "enabled": true, "action": _cycle_level.bind(top)})
	if Save.burrow_keys > 0:
		rows.append({"text": "Use a Hollow key: %s" % ("yes" if use_key else "no"), "note": "A key gives the run a boon from the start · you have %d" % Save.burrow_keys,
			"cost": {}, "label": "Change", "enabled": true, "action": _toggle_key})
	rows.append({"text": "Your materials", "note": Data.mats_text(Save.mats), "cost": {}, "label": "", "enabled": false, "action": Callable()})
	var warn := camp_warning()
	if warn != "":
		rows.append({"text": "The camp needs mending", "note": warn, "cost": {}, "label": "", "enabled": false, "action": Callable()})
	return {"title": nm, "sub": sub, "anchor": anchor, "rows": rows}


func _pays(d: int) -> String:
	var bits: Array = ["amber"]
	var dr: Dictionary = cfg()["drops"]
	if Data.depth_drop(dr["boss"], "glowstone", d) > 0.0:
		bits.append("glowstone")
	if Data.depth_drop(dr["boss"], "heartwood", d) > 0.0:
		bits.append("heartwood")
	return ", ".join(bits)


func _toggle_key() -> void:
	use_key = not use_key
	main.hud.refresh_card()


## The card's Change: the next lower level, round to the highest open one again.
func _cycle_level(top: int) -> void:
	var lv := top if pick_level <= 0 or pick_level > top else pick_level
	lv -= 1
	pick_level = top if lv < 1 else lv
	main.hud.refresh_card()


## The card's Go in: free, as often as the player likes.
func enter(id: String, lvl: int) -> void:
	if blocker() != "" or not is_open(id):
		return
	await runner.start_run(id, lvl)


# ---------------------------------------------------------------- what the camp's code asks (forwarded to the run)
func start_run(id: String, lvl: int) -> void:
	await runner.start_run(id, lvl)


func resume_run() -> void:
	await runner.resume_run()


func abandon_run() -> void:
	runner.abandon_run()


func persist() -> void:
	runner.persist()


func collect_mat(kind: String, n: int, at: Vector3) -> void:
	runner.collect_mat(kind, n, at)


func on_cat_hurt() -> void:
	runner.on_cat_hurt()


## Once the HUD exists (main._ready, deferred): a saved run that no longer fits the game is closed kindly.
func check_saved_run() -> void:
	runner.check_saved_run()
