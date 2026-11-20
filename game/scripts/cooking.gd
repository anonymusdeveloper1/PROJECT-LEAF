extends Node
## Cooking at the campfire (Phase C): the pot on the fire's north-east rim comes with the garden. The cat cooks one
## dish from the pantry (Save.pantry); it waits in the pot (Save.meal_ready) and is eaten when the next chapter starts
## (main.on_wave_start), then lasts that chapter (Save.meal_on, its boost cached in Data.set_meal). A held chapter or a
## won mission uses it up; if the camp falls it goes back into the pot, so the chapter's retry gets it again. Closing
## the game mid-chapter turns an eaten dish back into a waiting one (save.gd). No timers, no per-frame code.

var main


func setup(m) -> void:
	main = m


## The recipes whose unlock is met: garden | fishing | fishing+stone | goldfish (one was ever caught).
func known() -> Array:
	var out: Array = []
	for r in Data.b["cooking"]["recipes"]:
		if _unlocked(String(r.get("unlock", "garden"))):
			out.append(r)
	return out


func _unlocked(u: String) -> bool:
	match u:
		"garden": return Data.garden_level() > 0
		"fishing": return int(Save.stations.get("fishing", 0)) > 0
		"fishing+stone": return int(Save.stations.get("fishing", 0)) > 0 and Data.guardian_level() > 0
		"goldfish": return int(Save.fish_log.get("carp", 0)) > 0
	return false


func _fire_out() -> bool:
	return Save.fire_ruined or (main != null and main.stations != null and main.stations._out)


func can_cook(r: Dictionary) -> bool:
	return not _fire_out() and Data.has_items(r.get("needs", {}))


## Why a dish cannot be cooked now ("The fire is out", "Needs 1 more Sunberry").
func why_not(r: Dictionary) -> String:
	if _fire_out():
		return "The fire is out"
	var needs: Dictionary = r.get("needs", {})
	for k in needs:
		var short := int(needs[k]) - int(Save.pantry.get(k, 0))
		if short > 0:
			return "Needs %d more %s" % [short, Data.item_name(String(k), short)]
	return ""


## "3 Sunberries (have 5), 1 honey (have 0)".
func needs_text(r: Dictionary) -> String:
	var bits: Array = []
	var needs: Dictionary = r.get("needs", {})
	for k in needs:
		var n := int(needs[k])
		bits.append("%d %s (have %d)" % [n, Data.item_name(String(k), n), int(Save.pantry.get(k, 0))])
	return ", ".join(bits)


## The ingredients without the have-counts ("2 fish, 1 Fernmint"), for the "More recipes" line.
func needs_short(r: Dictionary) -> String:
	var bits: Array = []
	var needs: Dictionary = r.get("needs", {})
	for k in needs:
		var n := int(needs[k])
		bits.append("%d %s" % [n, Data.item_name(String(k), n)])
	return ", ".join(bits)


## The pantry as the pot card says it: "5 Sunberries · 2 Fernmint · 1 honey · 3 fish".
func pantry_text() -> String:
	var bits: Array = []
	for k in ["berries", "herbs", "honey", "fish", "goldfish"]:
		var n := int(Save.pantry.get(k, 0))
		if n > 0 or (k != "goldfish" and (k != "fish" or int(Save.stations.get("fishing", 0)) > 0)):
			bits.append("%d %s" % [n, Data.item_name(k, n)])
	return " · ".join(bits)


func pantry_empty() -> bool:
	for k in Save.pantry:
		if int(Save.pantry[k]) > 0:
			return false
	return true


## Cooks a dish: the ingredients go into the pot, and the dish waits there for the next chapter. One dish at a time:
## a new one replaces the one waiting (its ingredients are not given back).
func cook(id: String) -> bool:
	var r := Data.recipe(id)
	if r.is_empty() or not can_cook(r):
		return false
	Data.take_items(r["needs"])
	Save.meal_ready = id
	var pot: Node3D = main.stations.nodes.get("pot")
	var at: Vector3 = main.world.station_pos("pot")
	var steam := at + Vector3(0, 0.55, 0)
	if pot:
		var mk := Props.find_part(pot, "marker_steam")
		if mk:
			steam = mk.global_position
		Fx.boing(pot, 0.3)
	_fly_in(r, steam)
	Fx.puff(main, steam, Color.html(String(r.get("color", "#ffffff"))), 8)
	Sfx.play("sizzle", -4.0)
	main.hud.banner("%s is ready" % String(r["name"]), Color.html(String(r.get("color", "#ffffff"))).lightened(0.25),
		"Eaten when the next chapter starts: %s" % String(r.get("says", "")))
	if main.raids:
		main.raids.add_gloom("dish")
	Save.save_game()
	main.on_purchase()
	return true


## The ingredients hop from the cat into the pot (three small ones, 0.3 s).
func _fly_in(r: Dictionary, to: Vector3) -> void:
	var meshes := {"berries": "sunberry_ripe", "herbs": "fernmint_ripe", "honey": "honeybell_ripe", "fish": "fish_perch", "goldfish": "fish_carp"}
	var kinds: Array = (r.get("needs", {}) as Dictionary).keys()
	var from: Vector3 = main.player.global_position + Vector3(0, 0.9, 0)
	for k in mini(3, maxi(kinds.size(), 1) * 2):
		var kind := String(kinds[k % kinds.size()]) if not kinds.is_empty() else "berries"
		var mi := MeshInstance3D.new()
		mi.mesh = Props.mesh(String(meshes.get(kind, "sunberry_ripe")))
		mi.material_override = Props.vc()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		main.add_child(mi)
		mi.global_position = from
		mi.scale = Vector3.ONE * 0.5
		var tw := mi.create_tween()
		tw.tween_interval(0.07 * k)
		tw.tween_property(mi, "global_position", to, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(mi.queue_free)


## A chapter starts (wave 1, a resumed chapter, or "Go" after a chapter break): the dish in the pot is eaten. Phase E:
## scope "run" when it goes down into the Burrows with the cat (it lasts the run, used up when the run ends).
func eat(scope := "chapter") -> void:
	if Save.meal_ready == "" or Data.recipe(Save.meal_ready).is_empty():
		Save.meal_ready = ""
		return
	if Save.meal_on != "":
		finish(true)
	var r := Data.recipe(Save.meal_ready)
	Save.meal_on = Save.meal_ready
	Save.meal_ready = ""
	Data.set_meal(Save.meal_on)
	var b: Dictionary = r.get("boost", {})
	var p = main.player
	if b.has("hp"):
		p.hp = mini(p.hp + int(b["hp"]), Data.cat_max_hp())
	if b.has("fire") and main.fight.active:
		var f = main.fight
		var gain := float(f.gate_max) * float(b["fire"])
		f.gate_max += gain
		f.gate_hp += gain
	if main.guardian:
		main.guardian.refresh_stats()
	Fx.sparkle(main, p.global_position + Vector3(0, 1.0, 0))
	main.hud.banner_later(3.4, "The cat eats the %s" % String(r["name"]), Color.html(String(r.get("color", "#ffffff"))).lightened(0.25),
		"%s this %s" % [_first_up(String(r.get("says", ""))), "run" if scope == "run" else "chapter"])
	main.hud.refresh()


func _first_up(s: String) -> String:
	return s.substr(0, 1).to_upper() + s.substr(1) if s != "" else s


## The chapter is over. held: it was held (or the mission won): the dish is used up. Not held (the camp fell): the
## dish goes back into the pot, unless another one waits there.
func finish(held: bool) -> void:
	if Save.meal_on == "":
		return
	var id := Save.meal_on
	Save.meal_on = ""
	if not held and Save.meal_ready == "":
		Save.meal_ready = id
	Data.set_meal("")
	var f = main.fight
	f.gate_max = float(Data.fire_hp())
	f.gate_hp = minf(f.gate_hp, f.gate_max)
	main.player.hp = mini(main.player.hp, Data.cat_max_hp())
	if main.guardian:
		main.guardian.refresh_stats()
	main.hud.refresh()


func eating() -> bool:
	return Save.meal_on != ""


## The HUD chip: "Eating: Berry Tart · shoots 15% faster", or "In the pot: Berry Tart (next chapter)".
func chip_text() -> String:
	if Save.meal_on != "":
		var r := Data.recipe(Save.meal_on)
		return "Eating: %s · %s" % [String(r.get("name", "")), String(r.get("says", ""))]
	if Save.meal_ready != "":
		return "In the pot: %s (next chapter)" % String(Data.recipe(Save.meal_ready).get("name", ""))
	return ""
