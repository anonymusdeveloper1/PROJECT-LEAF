extends Node
## The cooking pot (H3, 26 Nov 2026; docs/ARCHITECTURE.md part 4 Type Object, part 9 "Long job"): the pot on the fire's
## north-east rim comes with the garden. The player puts ingredients in the pot's slots (the window,
## ui/windows/cooking_window.gd); Cook takes them from the Bag and starts the Timers job "cook:pot", which runs in real
## time, also while the game is closed. The result waits in the pot until Collect puts it in the Bag.
## Used by: the pot's window (every rule it shows is asked here), stations._card_pot (wants_pulse), the tests.
## Uses: Timers (the job), Bag (the ingredients and the result), Data (content/recipes: needs, cook_s, limit, unlock;
## balance.json ingredients and fishing.catches for the pieces that hop into the pot), Events (timer_finished), and
## main: raids (the Gloom bump), stations (the pot, its ring, the fire), hud (toasts), world.
## Rules:
##   - The recipes are content entries (content/recipes/<id>/entry.json): a recipe is its result's type, and its id is
##     the Bag item's id. known() is every entry whose unlock passes (Data.unlocked) and that is not hidden.
##   - The saved state is the job alone: "cook:pot" with data {"recipe": id}. There is no other save key. The pot is
##     busy from Cook until Collect; a job whose recipe is not a known entry (content taken out) is kept but ignored:
##     the pot shows empty and the next Cook replaces it (ARCHITECTURE part 10: unknown ids are kept but ignored).
##   - Nothing leaves the Bag until Cook (Q14). Cook is refused when the result would not fit in the Bag now (Q16); if
##     the Bag fills while it cooks, Collect says "Bag full" and the result waits in the pot.
##   - The Gloom meter gets +3 ("dish") on the Cook tap only, never when the timer ends (risk 13).
##   - The fire out (the Last Stand, the ashes; Q13): the job keeps running and the pot's ring hides, as before; Cook
##     and Collect wait for the fire. In a wave nothing is cooked or collected (the card is blank then, Q12).
##   - The handler hears Events.timer_finished for "cook:pot" only (other "cook:" ids are the tests'): a toast and a
##     stations refresh, so the ring pulses (it changes only on a refresh). It changes nothing in the game. A missed
##     event loses nothing: the state is in Timers, and wants_pulse reads it on every stations refresh (stations.build
##     ends with one).

const JOB := "cook:pot"

var main


func setup(m) -> void:
	main = m
	if not Events.timer_finished.is_connected(_on_timer_finished):
		Events.timer_finished.connect(_on_timer_finished)


# ---------------------------------------------------------------- the recipes
## The recipe entries whose unlock passes, in index order (Cooked Fish once the Fishing Spot is built).
func known() -> Array:
	var out: Array = []
	for e: Variant in Data.catalog("recipes"):
		if e is Dictionary and _is_known(e as Dictionary):
			out.append(e)
	return out


## Every ingredient a known recipe needs, in balance.json ingredients order (the window's tiles).
func needed_ingredients() -> Array[String]:
	var want := {}
	var extra: Array[String] = []
	for r: Variant in known():
		var needs: Variant = (r as Dictionary).get("needs", {})
		if not needs is Dictionary:
			continue
		for k: Variant in needs:
			want[String(k)] = true
	var out: Array[String] = []
	for id: Variant in Data.b.get("ingredients", {}):
		if want.has(String(id)):
			out.append(String(id))
			want.erase(String(id))
	for id: Variant in want:                        # a need that is not an ingredient (the content test forbids it)
		extra.append(String(id))
	out.append_array(extra)
	return out


## The known recipe whose needs are exactly these pieces (one id per filled slot, any order), or {}.
func match_recipe(pieces: Array[String]) -> Dictionary:
	var have := {}
	for p in pieces:
		if p != "":
			have[p] = int(have.get(p, 0)) + 1
	if have.is_empty():
		return {}
	for r: Variant in known():
		if _same_counts((r as Dictionary).get("needs", {}), have):
			return r as Dictionary
	return {}


# ---------------------------------------------------------------- cooking
## Why recipe r cannot be cooked now ("" when it can): "Not known yet", "A wave is on", "The fire is out", "Cooking
## already", "Collect first", "Need 2 Fernmint", "No room in the Bag".
func can_cook(r: Dictionary) -> String:
	var id := String(r.get("id", ""))
	var e := Data.recipe(id)
	if e.is_empty() or not _is_known(e):
		return "Not known yet"
	if _in_wave():
		return "A wave is on"
	if _fire_out():
		return "The fire is out"
	if cooking_id() != "":
		return "Collect first" if is_ready() else "Cooking already"
	var short := _missing(e)
	if short != "":
		return short
	if Bag.room_for(id) <= 0:
		return "No room in the Bag"
	return ""


## Cooks recipe id: its ingredients leave the Bag, the job "cook:pot" starts (cook_s seconds of real time), the
## pieces hop into the pot with steam, and the Gloom meter gets its "dish" bump. "" when it started, else why not.
func cook(id: String) -> String:
	var r := Data.recipe(id)
	var why := can_cook(r)
	if why != "":
		return why
	var needs: Dictionary = r.get("needs", {})
	if not Bag.take_all(needs):
		return _missing(r)
	if not Timers.start(JOB, float(r.get("cook_s", 0.0)), {"recipe": id}):
		Bag.add_all(needs, true)                     # balance.json timers.jobs has no "cook": give them back
		push_warning("cooking.cook: the job %s could not start" % JOB)
		return "The pot cannot cook"
	var spent := {}
	for k: Variant in needs:
		spent[k] = -int(needs[k])
	_cook_look(r)
	if main.raids != null:
		main.raids.add_gloom("dish")                 # on the tap, never when the timer ends
	Save.save_game()
	main.on_purchase()
	if main.hud != null:
		main.hud.toast(Data.food_receipt(spent))
	return ""


## The recipe cooking or waiting in the pot ("" when the pot is empty).
func cooking_id() -> String:
	if not Timers.has(JOB):
		return ""
	var id := String(Timers.job_data(JOB).get("recipe", ""))
	return id if not Data.recipe(id).is_empty() else ""


## Seconds until it is done (0 when done or the pot is empty).
func left_s() -> float:
	return Timers.left(JOB) if cooking_id() != "" else 0.0


## The result is done and waits for Collect.
func is_ready() -> bool:
	return cooking_id() != "" and Timers.done(JOB)


## Puts the finished result in the Bag and empties the pot. "" when it went in; "Bag full" (it waits in the pot),
## "Not ready yet", "The pot is empty", "A wave is on" or "The fire is out".
func collect() -> String:
	var id := cooking_id()
	if id == "":
		return "The pot is empty"
	if not Timers.done(JOB):
		return "Not ready yet"
	if _in_wave():
		return "A wave is on"
	if _fire_out():
		return "The fire is out"
	if Bag.add(id, 1) < 1:
		return "Bag full"
	Timers.remove(JOB)
	var at := _steam_pos()
	Fx.sparkle(main, at)
	Sfx.play("pop", -2.0)
	Save.save_game()
	if main.stations != null:
		main.stations.refresh()                      # the ring stops pulsing at once
	if main.hud != null:
		main.hud.toast(Data.food_receipt({id: 1}))
	return ""


## The pot's ring should pulse: a result waits, or the pot is empty and a known recipe can be made from the Bag.
func wants_pulse() -> bool:
	if is_ready():
		return true
	if cooking_id() != "":
		return false
	for r: Variant in known():
		var e := r as Dictionary
		if _missing(e) == "" and Bag.room_for(String(e.get("id", ""))) > 0:
			return true
	return false


# ---------------------------------------------------------------- the end of the job (Timers)
func _on_timer_finished(id: String) -> void:
	if id != JOB or main == null:
		return
	var rid := cooking_id()
	if rid != "" and main.hud != null:
		main.hud.toast("%s is ready at the pot" % Data.item_name(rid, 1))
	if main.stations != null:
		main.stations.refresh()                      # the ring pulses


# ---------------------------------------------------------------- inside
func _is_known(e: Dictionary) -> bool:
	if e.get("hidden", false) == true:
		return false
	var rule: Variant = e.get("unlock", {})
	return rule is Dictionary and Data.unlocked(rule as Dictionary)


## The first need the Bag is short of, as "Need 2 Fernmint" ("" when the Bag has them all).
func _missing(e: Dictionary) -> String:
	var needs: Variant = e.get("needs", {})
	if not needs is Dictionary:
		return "Not known yet"
	for k: Variant in needs:
		var n := int((needs as Dictionary)[k])
		if Bag.count(String(k)) < n:
			return "Need %d %s" % [n, Data.item_name(String(k), n)]
	return ""


## needs (a recipe's) holds exactly the counts in have.
static func _same_counts(needs: Variant, have: Dictionary) -> bool:
	if not needs is Dictionary:
		return false
	var want := {}
	for k: Variant in needs:
		var n := int((needs as Dictionary)[k])
		if n > 0:
			want[String(k)] = n
	if want.size() != have.size():
		return false
	for k: Variant in want:
		if int(have.get(k, 0)) != int(want[k]):
			return false
	return true


func _in_wave() -> bool:
	return main != null and main.fight != null and bool(main.fight.active) and bool(main.fight.in_wave)


func _fire_out() -> bool:
	return Save.fire_ruined or (main != null and main.stations != null and bool(main.stations._out))


## Where the steam rises: the pot's steam marker, else just over its spot.
func _steam_pos() -> Vector3:
	var at: Vector3 = main.world.station_pos("pot") + Vector3(0, 0.55, 0)
	var pot: Node3D = main.stations.nodes.get("pot") if main.stations != null else null
	if pot != null:
		var mk := Props.find_part(pot, "marker_steam")
		if mk != null:
			at = mk.global_position
	return at


## Cook's look and sound, as before: the pot bounces, the pieces hop in, steam in the recipe's colour, the sizzle.
func _cook_look(r: Dictionary) -> void:
	var steam := _steam_pos()
	var pot: Node3D = main.stations.nodes.get("pot") if main.stations != null else null
	if pot != null:
		Fx.boing(pot, 0.3)
	_fly_in(r, steam)
	Fx.puff(main, steam, Color.html(String(r.get("color", "#ffffff"))), 8)
	Sfx.play("sizzle", -4.0)


## The ingredients hop from the cat into the pot (three small ones, 0.3 s).
func _fly_in(r: Dictionary, to: Vector3) -> void:
	var kinds: Array = (r.get("needs", {}) as Dictionary).keys() if r.get("needs") is Dictionary else []
	if kinds.is_empty() or main.player == null:
		return
	var from: Vector3 = main.player.global_position + Vector3(0, 0.9, 0)
	for k in mini(3, kinds.size() * 2):
		var mesh_id := _piece_mesh(String(kinds[k % kinds.size()]))
		if mesh_id == "" or not Props.has(mesh_id):
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = Props.mesh(mesh_id)
		mi.material_override = Props.vc()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		main.add_child(mi)
		mi.global_position = from
		mi.scale = Vector3.ONE * 0.5
		var tw := mi.create_tween()
		tw.tween_interval(0.07 * k)
		tw.tween_property(mi, "global_position", to, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(mi.queue_free)


## The 3D piece for an ingredient, from data (no name list): the ripe plant of the crop that gives it
## (content/crops "gives" -> "<model>_ripe"), else the first fishing catch that gives it (balance.json
## fishing.catches "mesh"); "" when nothing gives it.
func _piece_mesh(ingredient: String) -> String:
	for c: Variant in Data.catalog("crops"):
		if c is Dictionary and String((c as Dictionary).get("gives", "")) == ingredient:
			return String((c as Dictionary).get("model", "")) + "_ripe"
	var catches: Variant = (Data.b.get("fishing", {}) as Dictionary).get("catches", [])
	if catches is Array:
		for c: Variant in catches:
			if c is Dictionary and (c as Dictionary).get("gives") is Dictionary and ((c as Dictionary)["gives"] as Dictionary).has(ingredient):
				return String((c as Dictionary).get("mesh", ""))
	return ""
