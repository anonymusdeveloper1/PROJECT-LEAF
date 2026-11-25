extends Node3D
## The camp: the Hearthtree (Phase G2: the tree home and the campfire under one name, Data.camp_name; its counter is
## the camp's shop, ring "shop"), and the buildings bought on its card. Upgrades are gated like this (Phase F, the
## progression chain: docs/PHASE_F_PLAN.md part 1):
##   Hearthtree level (the camp level)    caps every station and defence level, sets the firelight's size; it grows
##                                        when every goal on its list is met (Data.home_goals) and its price is paid;
##                                        the next act's missions need it (needs_home)
##   Training Target level (1-5)          caps Damage, Draw speed and Range (Range needs level 2)
##   Bow Shop level (1-5)                 caps bow levels and decides which bows it sells (station id "bench": the
##                                        Bow Bench before G3, the same model and save keys)
## The Hearthtree's card sells (shop-style item tiles in sections, Phase G2): growing it (its goals first: a tap on one
## takes the cat to where it is bought), the cat's own upgrades, the buildings, the defences (acorn towers, spikes, and
## the levels of barricades, towers and spikes: barricade rows are built at the road spots, defences.gd), and the
## graphics setting. The signpost lists all Raid Missions, with completed replays and the next unfinished mission;
## its separate Random Raids view unlocks once every Raid Mission is finished.
## The buildings round the campfire (world.SPOTS; the well stands on the lake's near shore):
##   Market            (Hearthtree 2)     Bramble trades timber, food and (after the missions) buys amber; Thistle
##                                        the hare comes free with it: ride it (mount.gd)
##   Mushroom Cottage  (Hearthtree 2)     Sprig the leaf dragon moves in and fights beside the cat (pet.gd)
##   Wishing Well      (Hearthtree 3)     mends the camp by itself (well_tick): never tapped, only upgraded
##   Saddlery   (mission 8, Hearthtree 2) G4: teaches the mount skills and makes it attachments (_card_saddlery); levels
##                                        1-5, never above the Hearthtree; a stand-in model until the owner's comes
##   Tailor's Nook      (Hearthtree 3)    23 Nov 2026: the cat's outfits, looks only (_card_tailor; balance.json
##                                        cat_skins); one level; a stand-in model until the owner's comes
## Every building has health during a mission (hp, hurt_building). Knocked down, it is a ruin: it shows only a Repair
## row and does nothing until then (no Sprig, no riding, no mending, no training, no crafting, no shop). A won mission
## mends every ruin for free; when the camp falls they stay, and repairs cost a share of what the building cost.
## When the camp has fallen, the campfire's ring offers to rebuild the fire; no mission can start before that.

const RingScript := preload("res://scripts/marker.gd")      # a tap on its badge or the building opens its card
const FLAME := preload("res://shaders/flame.gdshader")

var main
var nodes := {}          # "home", "campfire", "target", "bench", "well", "cottage", "stall", "saddlery", "tailor" -> prop node
var rings := {}          # "shop", "target", "bench", "sign", "well", "cottage", "stall", "saddlery", "tailor", "fire" -> marker (marker.gd)
var hp := {}             # building -> health in the current mission
const VILLAGE := ["well", "cottage", "stall"]
const BUILDINGS := ["home", "target", "bench", "well", "cottage", "stall", "saddlery", "tailor"]
const FOOT := {"campfire": 0.6, "home": 1.15, "bench": 0.8, "target": 0.45, "well": 0.62, "cottage": 0.95, "stall": 0.9,
	"stone": 0.7, "garden": 1.1, "pot": 0.25, "fishing": 0.45, "saddlery": 0.8, "tailor": 1.35}
## Phase C stations: never wrecked, never in BUILDINGS or VILLAGE (the Moss Warden takes the hits for the camp).
const CAMP_LIFE := ["stone", "garden", "pot", "fishing"]
var dummy: Node3D        # what the cat shoots at the training target
var sign_tab := ""       # empty selects the current progression view; otherwise missions / raids


func build(m) -> void:
	main = m
	for id in ["shop", "target", "bench", "sign", "well", "cottage", "stall", "saddlery", "tailor", "fire"] + CAMP_LIFE:
		var ring := Node3D.new()
		ring.set_script(RingScript)
		add_child(ring)
		var col := Color(1.0, 0.82, 0.3) if id != "sign" and id != "fire" else Color(1.0, 0.55, 0.35)
		ring.setup(id, Vector3.ZERO, 0.75, Callable(self, "_card_" + id), col)
		rings[id] = ring
		main.register_ring(ring)
	dummy = Node3D.new()
	dummy.set_script(preload("res://scripts/dummy.gd"))
	add_child(dummy)
	refresh()


## The home and the campfire by home level (1-6). A level whose model is not made yet shows the one before it.
## Home levels 7 and 8 (Phase E; H1: paid with leaves and timber) have no models of their own yet: they show level 6's.
const HOME_MODELS := ["home_tree_1", "home_tree_1", "home_treehouse", "home_tree_4", "home_tree_5", "home_tree_6", "home_tree_7", "home_tree_8"]
const FIRE_MODELS := ["campfire_1", "campfire_2", "campfire_2", "campfire_hearth", "campfire_bonfire", "campfire_brazier", "campfire_7", "campfire_8"]
const HOME_FOOT := [1.15, 1.32, 1.15, 1.5, 1.7, 1.9, 1.9, 1.9]   # footprint radius of the home, by home level
const FIRE_FOOT := [0.6, 0.8, 0.8, 0.8, 0.95, 0.9, 0.9, 0.9]     # ... and of the campfire (camp_hi.json for 4-6)
## The Training Target and the Bow Shop (id "bench") by their level (Phase F: 5 levels each). There are no models for the new levels
## (the owner decides how new models are made): the Target's levels 3-5 show target_2, the Bench's 4-5 bow_bench_3.
const TARGET_MODELS := ["target_1", "target_2", "target_2", "target_2", "target_2"]
const BENCH_MODELS := ["bow_bench_1", "bow_bench_2", "bow_bench_3", "bow_bench_3", "bow_bench_3"]


func _by_level(list: Array) -> String:
	var i := clampi(Save.camp_level, 1, list.size()) - 1
	while i > 0 and not Props.has(String(list[i])):
		i -= 1
	return String(list[i])


## How far a building reaches on the ground, for collisions and for the enemies that attack it.
func foot(id: String) -> float:
	match id:
		"home": return float(HOME_FOOT[clampi(Save.camp_level, 1, HOME_FOOT.size()) - 1])
		"campfire": return float(FIRE_FOOT[clampi(Save.camp_level, 1, FIRE_FOOT.size()) - 1])
	return float(FOOT[id])


func model_name(id: String) -> String:
	match id:
		"campfire": return _by_level(FIRE_MODELS)
		"home": return _by_level(HOME_MODELS)
		"bench": return String(BENCH_MODELS[clampi(int(Save.stations["bench"]), 1, BENCH_MODELS.size()) - 1])
		"target": return String(TARGET_MODELS[clampi(int(Save.stations["target"]), 1, TARGET_MODELS.size()) - 1])
		"well": return "wishing_well"
		"cottage": return "mushroom_cottage"
		"stall": return "market_stall"
		"saddlery": return _saddlery_model()
		"tailor": return _tailor_model()
		"stone": return "guardian_stone"
		"garden": return "garden_bed"
		"pot": return "cook_pot"
		"fishing": return "fishing_spot"
	return ""


## G4: the Saddlery's model: the owner's (props/saddlery.glb) once it is made, else the stand-in by its level
## (balance.json saddlery.stand_in.models: the Bow Bench's, tinted brown, see _saddlery_tint).
func _saddlery_model() -> String:
	if Props.has("saddlery"):
		return "saddlery"
	var list: Array = (Data.saddlery_cfg().get("stand_in", {}) as Dictionary).get("models", ["bow_bench_1"])
	if list.is_empty():
		return "bow_bench_1"
	return String(list[clampi(Data.saddlery_level(), 1, list.size()) - 1])


## The stand-in's tint (balance.json saddlery.stand_in.tint); white (none) on the owner's own model.
func _saddlery_tint() -> Color:
	if Props.has("saddlery"):
		return Color(1, 1, 1)
	return Color.html(String((Data.saddlery_cfg().get("stand_in", {}) as Dictionary).get("tint", "#B98A5C")))


## 23 Nov 2026: the Tailor's Nook's model: the owner's (props/tailors_nook.glb) once it is made, else the stand-in
## (balance.json stations.tailor.stand_in: the Market's stall, tinted a fabric purple, see _tailor_tint).
func _tailor_model() -> String:
	if Props.has("tailors_nook"):
		return "tailors_nook"
	return String((Data.b["stations"]["tailor"].get("stand_in", {}) as Dictionary).get("model", "market_stall"))


## The stand-in's tint (balance.json stations.tailor.stand_in.tint); white (none) on the owner's own model.
func _tailor_tint() -> Color:
	if Props.has("tailors_nook"):
		return Color(1, 1, 1)
	return Color.html(String((Data.b["stations"]["tailor"].get("stand_in", {}) as Dictionary).get("tint", "#B48CE6")))


func shown(id: String) -> bool:
	match id:
		"campfire", "home": return true
		"bench": return Save.stations["bench"] >= 1
		"target": return Save.stations["target"] >= 1
		"well", "cottage", "stall", "saddlery", "tailor": return int(Save.stations.get(id, 0)) >= 1
		"stone", "garden", "fishing": return int(Save.stations.get(id, 0)) >= 1
		"pot": return int(Save.stations.get("garden", 0)) >= 1          # the pot comes with the garden
	return false


func ring_shown(id: String) -> bool:
	match id:
		"shop", "sign": return true
		"target", "bench", "well", "cottage", "stall", "saddlery", "tailor": return shown(id)
		"fire": return Save.fire_ruined
		"stone", "garden", "fishing": return shown(id)
		"pot": return shown("pot") and not _out and not Save.fire_ruined     # no cooking on the ashes
	return false


## Rebuilds the buildings that changed (new level, newly built) and moves the rings.
func refresh(celebrate := "") -> void:
	var w = main.world
	for id in ["campfire", "home", "bench", "target", "well", "cottage", "stall", "saddlery", "tailor"] + CAMP_LIFE:
		var want := model_name(id) if shown(id) else ""
		var have: Node3D = nodes.get(id)
		if have != null and String(have.get_meta("model", "")) != want:
			have.queue_free()
			nodes.erase(id)
			have = null
		w.remove_tag("st_" + id)
		if want != "":
			if have == null:
				have = Props.instance(want)
				have.set_meta("model", want)
				add_child(have)
				nodes[id] = have
				if id == "home":
					_glow(have)
				if id == "saddlery":
					Props.set_param(have, "tint", _saddlery_tint())   # G4: the stand-in Bow Bench, tinted brown
				if id == "tailor":
					Props.set_param(have, "tint", _tailor_tint())     # 23 Nov 2026: the stand-in stall, tinted purple
				if celebrate == id or celebrate == "all":
					Fx.boing(have, 0.35)
					Fx.flower_ring(main, w.station_pos(id), 1.6)
			elif celebrate == id and (CAMP_LIFE.has(id) or id == "target" or id == "bench" or id == "saddlery"):
				Fx.boing(have, 0.3)                # an upgrade that keeps its model (Phase C stations, Target 3-5, Bench 4-5): a boing shows it
				Fx.flower_ring(main, w.station_pos(id), 1.4)
			have.position = w.station_pos(id)
			if id == "home" and Save.camp_level == 2:
				have.scale = Vector3.ONE * 1.15
			if id == "well":
				have.rotation.y = PI / 2.0        # the roof ridge runs toward the camera, so the water and bucket show
			if id == "garden":
				have.rotation.y = PI              # the bed's work side faces the camp
			if id == "stone":
				for k in 3:                       # the leaf rune lights up a part per stone level
					var rune := Props.find_part(have, "rune_%d" % (k + 1))
					if rune:
						rune.visible = k < int(Save.stations.get("stone", 0))
				# level 4 (Phase E): a heartwood knot with an amber core in the stone's top (amber crystals stand in)
				var heart := Props.find_part(have, "heart")
				var l4 := int(Save.stations.get("stone", 0)) >= 4
				if heart != null:
					heart.visible = l4
				elif l4 and have.get_node_or_null("amber_heart") == null:
					var am := Props.instance("amber_cluster")
					am.name = "amber_heart"
					am.position = Vector3(0, 1.7, 0)
					am.scale = Vector3.ONE * 0.6
					have.add_child(am)
			w.add_circle(w.station_pos(id), foot(id), "st_" + id)
	for id in nodes:
		_ruin_look(id)
		if BUILDINGS.has(id):
			_wear_look(id)
	if main.garden:
		main.garden.attach(nodes.get("garden"))
	for id in rings:
		var ring = rings[id]
		ring.visible = ring_shown(id)
		var pos: Vector3
		match id:
			"shop":
				var marker: Node3D = Props.find_part(nodes["home"], "marker_ring") if nodes.has("home") else null
				pos = marker.global_position if marker else w.station_pos("home") + Vector3(0.75, 0, 2.1)
			"target", "bench", "well", "cottage", "stall", "saddlery", "tailor": pos = w.spot_ring(id)    # on the camera's side of each
			"sign": pos = w.station_pos("sign") + Vector3(0, 0, 0.95)
			"fire": pos = Vector3(0, 0, maxf(1.15, foot("campfire") + 0.45))
			"stone": pos = w.station_pos("stone") + Vector3(0, 0, 1.1)
			"garden": pos = w.station_pos("garden") + Vector3(0, 0, -1.2)
			"pot": pos = Vector3(1.0, 0, -1.0)
			"fishing": pos = w.FISH_RING
		ring.global_position = Vector3(pos.x, 0.03, pos.z)
		_attach_marker(id, ring)
	dummy.global_position = w.station_pos("target") + Vector3(0, 0, 0.05)
	dummy.visible = nodes.has("target")
	w.rebuild_paths()                 # little paths to newly built stations
	_update_pulses()
	if main.get("burrows") != null:
		main.burrows.refresh()        # Phase E: the hollows' rings (sealed, open, blocked)


## What each marker's badge floats over (marker.gd): its building or prop, just over the top. The shop's floats over the
## home's counter, the garden's beside the bed and the pot's higher and over its spot, so no badge sits on the cat at
## any marker's spot (--layout checks it).
func _attach_marker(id: String, ring) -> void:
	var w = main.world
	match id:
		"shop":
			var home: Node3D = nodes.get("home")
			var at: Vector3 = ring.global_position - (home.global_position if home != null else Vector3.ZERO)
			ring.attach(home, "", 2.5, Vector3(at.x, 0.0, at.z - 1.0))
		"sign": ring.attach(func(): return w.sign_node, "", 2.4)
		"fire": ring.attach(nodes.get("campfire"), "", 1.9)
		"garden": ring.attach(nodes.get("garden"), "", 1.3, Vector3(1.55, 0.0, 0.0))
		"pot": ring.attach(nodes.get("pot"), "", 2.3, Vector3(0.45, 0.0, 0.0))
		_: ring.attach(nodes.get(id))


## A ruined building slumps, darkens and grows a few Gloom crystals; a repaired one stands up again.
func _ruin_look(id: String) -> void:
	var node: Node3D = nodes.get(id)
	if node == null:
		return
	var on := Save.ruined.has(id)
	node.rotation.z = 0.1 if on else 0.0
	node.position.y = -0.12 if on else 0.0
	var crust: Node3D = node.get_node_or_null("crust")
	if on and crust == null:
		crust = Node3D.new()
		crust.name = "crust"
		node.add_child(crust)
		for k in 4:
			var c := Props.instance("gloom_crystal")
			var a := TAU * k / 4.0 + 0.4
			c.position = Vector3(cos(a) * 0.7, 0.0, sin(a) * 0.7)
			c.rotation = Vector3(randf_range(-0.3, 0.3), randf() * TAU, randf_range(-0.3, 0.3))
			c.scale = Vector3.ONE * randf_range(0.8, 1.3)
			crust.add_child(c)
		Props.set_param(node, "gloom", 0.9)
	elif not on and crust != null:
		crust.queue_free()
		Props.set_param(node, "gloom", 0.0)


## A building worn by Gloom Raids darkens a little and has rubble at its foot (1, 2 or 3 piles as the wear grows).
func _wear_look(id: String) -> void:
	var node: Node3D = nodes.get(id)
	if node == null:
		return
	var w := 0.0 if Save.ruined.has(id) else float(Save.wear.get(id, 0.0))
	var r: Dictionary = Data.gr()["repair"]
	if not Save.ruined.has(id):
		Props.set_param(node, "gloom", w * float(r["wear_gloom"]))
	var n := 0
	for k in (r["wear_rubble"] as Array):
		if w >= float(k) - 0.0001:
			n += 1
	var rub: Node3D = node.get_node_or_null("rubble")
	if rub != null and int(rub.get_meta("n", -1)) == n:
		return
	if rub != null:
		rub.queue_free()
		rub.name = "rubble_old"
	if n == 0:
		return
	rub = Node3D.new()
	rub.name = "rubble"
	rub.set_meta("n", n)
	node.add_child(rub)
	var f := foot(id) * 0.85 / maxf(node.scale.x, 0.01)
	for k in n:
		var p := Props.instance("rubble_pile" if Props.has("rubble_pile") else "rock_1")
		var a: float = float([0.55, 2.5, 1.45][k]) - node.rotation.y   # toward the camera's side of the building
		p.position = Vector3(sin(a) * f, 0.0, cos(a) * f)
		p.rotation.y = 0.7 * k + 0.3
		rub.add_child(p)


## What a ruin costs to repair: a share of everything spent on the building (its build and its levels). During the
## missions raid.repair_share of it; after them (Data.raids_open) the endgame price, gloom_raids.repair ruin_share with
## its ruin_min and ruin_cap. The Hearthtree (home) always pays the endgame price (21 Nov 2026), so its repair in a
## mission is never a wall.
func repair_cost(id: String) -> Dictionary:
	var spent := {"leaves": 0.0, "timber": 0.0}
	if id == "home":
		var levels: Array = Data.b["stations"]["camp"]["levels"]
		spent["leaves"] = 100.0
		for k in range(1, mini(Save.camp_level, levels.size())):
			spent["leaves"] += float(levels[k].get("leaves", 0))
			spent["timber"] += float(levels[k].get("timber", 0))
	else:
		var st: Dictionary = Data.b["stations"][id]
		spent["leaves"] = float(st.get("build", {}).get("leaves", 0))
		spent["timber"] = float(st.get("build", {}).get("timber", 0))
		var levels2: Array = st.get("levels", [])
		for k in range(1, mini(int(Save.stations.get(id, 1)), levels2.size())):
			spent["leaves"] += float(levels2[k].get("leaves", 0))
			spent["timber"] += float(levels2[k].get("timber", 0))
	if Data.raids_open() or id == "home":
		# the endgame price: a smaller share, capped, so a ruin after a Gloom Raid (or the Hearthtree's) is never a wall
		var r: Dictionary = Data.gr()["repair"]
		var cap: Dictionary = r["ruin_cap"]
		var c := {"leaves": clampi(int(ceil(spent["leaves"] * float(r["ruin_share"]))), int(r["ruin_min"]), int(cap["leaves"]))}
		if spent["timber"] > 0.0:
			c["timber"] = mini(int(ceil(spent["timber"] * float(r["ruin_share"]))), int(cap["timber"]))
		return c
	var share := float(Data.b["raid"]["repair_share"])
	var cost := {"leaves": maxi(10, int(ceil(spent["leaves"] * share)))}
	if spent["timber"] > 0.0:
		cost["timber"] = int(ceil(spent["timber"] * share))
	return cost


func _ruin_card(id: String, title: String, anchor: Vector3) -> Dictionary:
	var cost := repair_cost(id)
	var what: String = {"home": "Nothing can be bought here", "target": "No training here", "bench": "No bows to buy or upgrade",
		"well": "It can't mend the camp", "cottage": "%s is hiding" % Data.pet_name(),
		"stall": "%s won't come out, and no trading" % Data.mount_name(),
		"saddlery": "No skills or attachments to buy or upgrade",
		"tailor": "No outfits to buy or put on"}.get(id, "")
	var rows: Array = [{"text": "In ruins", "note": "%s until it is repaired" % what, "cost": {}, "label": "", "enabled": false, "action": Callable()}]
	var raid: bool = main.fight.active and main.fight.mode == "raid"
	if main.fight.active and main.fight.in_wave:
		if raid:
			rows.append({"text": "Repair between waves", "note": "Raids leave their damage: repair it after this wave", "cost": {}, "label": "", "enabled": false, "action": Callable()})
		else:
			rows.append({"text": "Repair between waves", "note": "Or win the raid and the camp mends itself", "cost": {}, "label": "", "enabled": false, "action": Callable()})
	else:
		rows.append(_tile("repair", "Repair", "Everything here works again" + (" · free if the raid is won" if main.fight.active and not raid else ""),
			cost, "Repair", true, _repair.bind(id)))
	return {"title": title, "sub": "Knocked down by the Gloom", "rows": rows, "anchor": anchor}


func _repair(id: String) -> void:
	if not Save.ruined.has(id) or (main.fight.active and main.fight.in_wave) or not Data.pay(repair_cost(id)):
		return
	Save.ruined.erase(id)
	Save.wear.erase(id)
	if main.fight.active:
		hp[id] = full_hp(id)                         # standing again (and a target again) for the rest of the fight
	Save.save_game()
	Fx.flower_ring(main, main.world.station_pos(id), 1.4)
	main.hud.banner("Repaired!", Color(1.0, 0.9, 0.5), "%s works again" % _name(id))
	main.on_purchase()


func _name(id: String) -> String:
	return Data.camp_name(true) if id == "home" else String(Data.b["stations"][id]["name"])


## "Patch it up": a building worn by raids (on its own card).
func _wear_row(id: String) -> Array:
	var w := float(Save.wear.get(id, 0.0))
	if w < float(Data.gr()["repair"]["wear_step"]) - 0.0001 or Save.ruined.has(id):
		return []
	var full := full_hp(id)
	var note := "Worn %d%% by raids: %s of %s health" % [int(round(w * 100.0)), _thousands(int(round(full * (1.0 - w)))), _thousands(int(round(full)))]
	return [_tile("repair", "Patch it up", note, patch_cost(id), "Patch", not _locked(), _patch.bind(id), "Worn")]


func _patch(id: String) -> void:
	if _locked() or not Save.wear.has(id) or not Data.pay(patch_cost(id)):
		return
	mend_wear(id)
	if nodes.has(id):
		Fx.boing(nodes[id], 0.25)
	Fx.flower_ring(main, main.world.station_pos(id), 1.4)
	Save.save_game()
	main.hud.banner("Patched up!", Color(1.0, 0.9, 0.5), "%s is whole again" % _name(id))
	main.on_purchase()


## Mending without paying (the caller paid: Mend all / Mend some).
func mend_wear(id: String) -> void:
	Save.wear.erase(id)
	if main.fight.active and hp.has(id):
		hp[id] = full_hp(id)
	_wear_look(id)


func mend_ruin(id: String) -> void:
	Save.ruined.erase(id)
	Save.wear.erase(id)
	if main.fight.active:
		hp[id] = full_hp(id)


# ---------------------------------------------------------------- health in a mission
## A building's full health at its level now.
func full_hp(id: String) -> float:
	return Data.building_hp(id, Save.camp_level if id == "home" else int(Save.stations.get(id, 1)))


## Every standing building at full health (a mission or raid starts), less the wear Gloom Raids left on it.
func reset_hp() -> void:
	hp.clear()
	for id in BUILDINGS:
		if shown(id) and not Save.ruined.has(id):
			hp[id] = full_hp(id) * (1.0 - float(Save.wear.get(id, 0.0)))


## What patching a worn building costs: half the endgame ruin price for the share it has lost (no timber).
func patch_cost(id: String) -> Dictionary:
	var w := float(Save.wear.get(id, 0.0))
	if w <= 0.0:
		return {}
	var r: Dictionary = Data.gr()["repair"]
	var ruin_l := float(repair_cost(id).get("leaves", 0))
	return {"leaves": maxi(int(r["wear_min"]), int(ceil(ruin_l * w * float(r["wear_share"]) - 0.0001)))}


## Gloom Raids: the share of health each standing building has lost is kept as wear (rounded down to wear_step). Only
## raids call this (at every wave held, on pause, at the end). It does not save: the callers do.
func save_wear() -> void:
	if not main.fight.active:
		return
	var step := float(Data.gr()["repair"]["wear_step"])
	for id in hp:
		if Save.ruined.has(id):
			Save.wear.erase(id)
			continue
		var full := full_hp(id)
		if full <= 0.0:
			continue
		var lost := clampf(1.0 - float(hp[id]) / full, 0.0, 0.95)
		var w := floorf(lost / step + 0.0001) * step
		if w >= step - 0.0001:
			Save.wear[id] = snappedf(w, 0.01)
		else:
			Save.wear.erase(id)


## What enemies can attack: [id, position, footprint radius] for each standing building.
func building_targets() -> Array:
	var out: Array = []
	for id in hp:
		if float(hp[id]) > 0.0 and nodes.has(id):
			out.append([id, main.world.station_pos(id), foot(id)])
	return out


func hurt_building(id: String, amount: float) -> void:
	if not hp.has(id) or float(hp[id]) <= 0.0:
		return
	main.fight.busy()
	if main.fight.mode == "raid":
		main.raids.on_building_hit(id)
	hp[id] = float(hp[id]) - amount
	var at: Vector3 = main.world.station_pos(id)
	Fx.hit(main, at + Vector3(0, 0.8, 0), Color(0.75, 0.55, 0.35))
	Fx.number(main, at + Vector3(0, 2.0, 0), amount, Color(1.0, 0.55, 0.4))
	if nodes.has(id):
		Fx.boing(nodes[id], 0.08)
	if float(hp[id]) <= 0.0:
		ruin(id)


func ruin(id: String) -> void:
	if main.fight.active and main.fight.mode == "raid" and not Save.ruined.has(id):
		main.fight.raid_losses += 1                  # a building lost in this raid: no perfect defence
	if not Save.ruined.has(id):
		Save.ruined.append(id)
	Save.wear.erase(id)                              # the ruin replaces its wear
	hp[id] = 0.0
	var at: Vector3 = main.world.station_pos(id)
	Fx.kill(main, at + Vector3(0, 1.0, 0), Color(0.55, 0.42, 0.3))
	Fx.smoke(main, at)
	main.shake(0.25)
	main.hud.toast("%s was knocked down!" % _name(id))
	if id == "stall":
		main.set_riding(false)
	Save.save_game()
	refresh()
	main.refresh_companions()


## A won mission: the camp mends itself. With `before` (a replay once raids are open), only the ruins made in that
## replay are mended: ruins a Gloom Raid left stay until they are repaired.
func repair_all_free(before = null) -> void:
	if Save.ruined.is_empty():
		return
	if before == null:
		Save.ruined.clear()
	else:
		var keep: Array = []
		for id in Save.ruined:
			if (before as Array).has(id):
				keep.append(id)
		if keep.size() == Save.ruined.size():
			return
		Save.ruined = keep
	Save.save_game()
	refresh("all")
	main.refresh_companions()


## A building given by a mission (balance.json missions[].gift: the garden, the Fishing Spot; Phase G2: the Market
## and the Mushroom Cottage are bought at Hearthtree level 2 now, but a gift of them still works). Its banner comes
## a moment after the "mission won" banner, so both can be read.
func gift(id: String) -> void:
	if int(Save.stations.get(id, 0)) > 0:
		return
	Save.stations[id] = 1
	_gift_extras(id)
	Save.save_game()
	refresh(id)
	main.refresh_companions()
	match id:
		"stall":
			main.hud.banner_later(3.4, "%s arrives!" % Data.mount_name(), Color(1.0, 0.9, 0.55), "A Market for the camp, and a friend to ride: tap Ride")
		"cottage":
			main.hud.banner_later(3.4, "%s moves in!" % Data.pet_name(), Color(0.6, 1.0, 0.45), "A Mushroom Cottage, and a little friend who fights beside you")
		"garden":
			main.hud.banner_later(3.4, "A garden!", Color(0.6, 1.0, 0.45), "Rich soil south of the camp · and a cooking pot by the fire")
			if not Save.flag("told_garden"):
				Save.set_flag("told_garden")
				main.hud.tip_after("Plant seeds, water them, pick them when ripe. They grow a step for every wave you hold.", rings.get("garden"))
		"fishing":
			main.hud.banner_later(3.4, "Gone fishing!", Color(0.6, 0.85, 1.0), "Bramble left you a rod by the lake")
			if not Save.flag("told_fish"):
				Save.set_flag("told_fish")
				main.hud.tip_after("Tap the Fishing Spot to cast a line between waves. Tap again when the float dips!", rings.get("fishing"))


## What comes with a gift besides the building (the garden brings a few berries, so the pantry is never empty).
func _gift_extras(id: String) -> void:
	if id == "garden":
		Save.pantry["berries"] = int(Save.pantry.get("berries", 0)) + 4


## An older save that won a mission before its gift existed (or missed one) gets it now. Called once at the end of
## main._ready, after the HUD and the companions exist.
func catch_up_gifts() -> void:
	_tell_saddlery_moves()                         # G4: an old save's Thump and Burrows gear, now the Saddlery's
	var got: Array = []
	for i in Data.mission_count():
		var m := Data.mission(i)
		var g := String(m.get("gift", ""))
		if g != "" and Save.missions_done.has(String(m["id"])) and int(Save.stations.get(g, 0)) == 0:
			Save.stations[g] = 1
			_gift_extras(g)
			got.append(_name(g))
	if got.is_empty():
		return
	Save.save_game()
	refresh("all")
	main.refresh_companions()
	main.hud.tip("New in your camp: %s" % ", ".join(got), null)


## The cat freed the Moss Warden (Phase E calls this, in the first Burrow, once every mission is won). Guardians are
## found, never bought: no mission gives the stone and no row sells or wakes one. The stone and its ring show from now.
func free_guardian() -> void:
	Save.stations["stone"] = maxi(1, int(Save.stations.get("stone", 0)))
	Save.save_game()
	refresh("stone")
	main.refresh_companions()                      # spawns it (asleep, the first time) at its stone
	Save.set_flag("warden_awake")
	Save.save_game()
	if main.guardian != null:
		main.guardian.wake()
		main.guardian.refresh_stats()
	main.hud.banner("The %s is free!" % Data.guardian_name(), Color(0.65, 0.95, 0.5), "It will guard the camp while you are away.")
	main.on_purchase()


# ---------------------------------------------------------------- the Wishing Well mends the camp (Phase G2)
## The standing Well mends the campfire, buildings, defences and the Moss Warden up to full.
## It uses well.passive rates from balance.json and skips ruins, broken pieces, ashes and a downed Warden.
## Mending runs on live camp time with a clamped frame step.
func _physics_process(delta: float) -> void:
	if main == null or main.frozen or main.fight == null or main.get("area") != null:
		return
	well_tick(minf(delta, 0.1))


## One step of the Well's mending, dt seconds of play (the tests call it too).
func well_tick(dt: float) -> void:
	var lv := well_level()
	if lv <= 0 or dt <= 0.0:
		return
	var f = main.fight
	var wave: bool = f.active and f.in_wave
	var rate := well_regen(lv) if wave else well_between(lv)
	var cap := 1.0                                  # 22 Nov 2026: always up to full, in a wave or not
	if rate <= 0.0:
		return
	if f.active and not f.last_stand and not Save.fire_ruined and f.gate_hp > 0.0 and f.gate_max > 0.0:
		f.gate_hp = _mended(f.gate_hp, f.gate_max, rate * dt, cap)
	if f.active:
		for id in hp:
			if Save.ruined.has(id) or float(hp[id]) <= 0.0:
				continue
			hp[id] = _mended(float(hp[id]), full_hp(id), rate * dt, cap)
	if main.defences != null and main.defences.has_method("well_mend"):
		main.defences.well_mend(dt, rate, cap)
	if main.guardian != null:
		main.guardian.well_mend(rate * dt)


## `now` raised by `step` (a share) of `full`, never past `cap` of it, and never lowered (above the cap it stays).
func _mended(now: float, full: float, step: float, cap: float) -> float:
	var top := full * minf(cap, 1.0)
	if full <= 0.0 or now >= top:
		return now
	return minf(top, now + full * step)


## The Well's level while it can work: built and not in ruins (0 otherwise).
func well_level() -> int:
	if Save.ruined.has("well"):
		return 0
	return int(Save.stations.get("well", 0))


func _well_pick(key: String, lv: int) -> float:
	var t: Array = (Data.b.get("well", {}) as Dictionary).get("passive", {}).get(key, [])
	if t.is_empty():
		return 0.0
	return float(t[clampi(lv, 0, t.size() - 1)])


## In a wave: the share of its max health everything mends every second (well.passive.regen_by_level).
func well_regen(lv: int) -> float:
	return _well_pick("regen_by_level", lv)


## Between waves: the share of its max health everything mends every second, up to full (well.passive.between_by_level).
func well_between(lv: int) -> float:
	return _well_pick("between_by_level", lv)


## True while a wave is on: the camp's stations only work between waves (every new action checks it itself).
func _locked() -> bool:
	return main.fight.active and main.fight.in_wave



# ---------------------------------------------------------------- the Guardian Stone and the Moss Warden (Phase C)
func _card_stone() -> Dictionary:
	var anchor := _anchor("stone", 2.0)
	var lv := int(Save.stations.get("stone", 0))
	var sub := "Level %d · the Warden grows with %s too (x%.2f)" % [lv, Data.camp_name(), Data.guardian_power()]
	var g = main.guardian
	if g == null:
		return {"title": "Guardian Stone", "sub": sub, "rows": [{"text": "The stone is quiet", "note": "", "cost": {}, "label": "", "enabled": false, "action": Callable()}], "anchor": anchor}
	if not Save.flag("warden_awake"):
		return {"title": "Guardian Stone", "sub": sub, "rows": [
			{"text": "The %s is asleep" % Data.guardian_name(), "note": "An old guardian of mossy stone. Wake it and it guards your camp",
				"cost": {}, "label": "Wake", "enabled": true, "pulse": true, "action": _wake_warden}], "anchor": anchor}
	var rows: Array = []
	rows.append({"text": "%s · level %d" % [Data.guardian_name(), lv], "note": "%s health · fists %d · ground slam %d" % [
		_thousands(int(round(Data.guardian_max_hp()))), int(round(Data.guardian_fist())), int(round(Data.guardian_slam()))],
		"cost": {}, "label": "", "enabled": false, "action": Callable()})
	rows.append({"text": "How it fights", "note": "Goes for whatever attacks your buildings, barricades or campfire · too slow for fliers and thieves · stand by it to help it up",
		"cost": {}, "label": "", "enabled": false, "action": Callable()})
	rows.append({"text": "Post: %s" % g.post_text(Save.guardian_post), "note": _post_note(), "cost": {}, "label": "Change", "enabled": true, "action": _next_post})
	var looks: Array = []
	if (Data.b["looks"]["guardian"] as Array).size() > 1:
		looks = _look_tiles("guardian", "guardian", "Your guardian now", "Same strength, a new look")
	looks.append(_skin_row("guardian"))
	_add_section(rows, "Looks", looks)
	_add_section(rows, "Upgrade", [_station_upgrade_row("stone")])
	return {"title": "Guardian Stone", "sub": sub, "rows": rows, "anchor": anchor}


## 1035 -> "1,035".
func _thousands(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


## The lanes of the mission that comes next (the running one, the saved run's, else the next not won; all four after
## the last mission), as ints.
func _post_lanes() -> Array:
	if (main.fight.active and main.fight.mode == "raid") or bool(Save.raids.get("pending", false)):
		var kl: Array = main.raids.known_lanes()      # a Gloom Raid's trails (none while a sneak raid hides)
		return kl if not kl.is_empty() else [0, 1, 2, 3]
	var mi := -1
	if main.fight.active:
		mi = main.fight.mission
	elif Save.mission_run.has("mission"):
		mi = int(Save.mission_run["mission"])
	else:
		mi = Data.next_mission()
	var out: Array = []
	if mi >= 0 and mi < Data.mission_count():
		for ln in Data.mission(mi)["lanes"]:
			out.append(int(ln))
	else:
		out = [0, 1, 2, 3]
	return out


func _post_note() -> String:
	var lanes := _post_lanes()
	var names: Array = lanes.map(func(ln): return String(Data.patch(int(ln))["name"]))
	var p := Save.guardian_post
	var note := "Goes where the fight is, all round the camp" if p < 0 else "Stays at that trail's mouth; the rest of the camp is yours"
	note += " · next raid: %s" % ", ".join(names)
	if p >= 0 and not lanes.has(p):
		note += " (not that trail: it guards the camp then)"
	return note


func _wake_warden() -> void:
	if _locked() or Save.flag("warden_awake") or main.guardian == null:
		return
	Save.set_flag("warden_awake")
	main.guardian.wake()
	main.hud.banner("The %s wakes!" % Data.guardian_name(), Color(0.65, 0.95, 0.5), "A big, slow friend: it goes for whatever attacks your camp")
	Save.save_game()
	main.on_purchase()


## "Change" on the post row: guard the camp, then each trail of the coming mission, then round again.
func _next_post() -> void:
	if _locked():
		return
	var order: Array = [-1]
	order.append_array(_post_lanes())
	var i := order.find(Save.guardian_post)
	Save.guardian_post = int(order[(i + 1) % order.size()]) if i >= 0 else -1
	Save.save_game()
	if main.fight.active and main.guardian != null:
		main.guardian.post = main.guardian._post_spot()
	main.hud.refresh_card()

# ---------------------------------------------------------------- the garden (Phase C, mission 1's gift)
func _card_garden() -> Dictionary:
	var anchor := _anchor("garden", 1.2)
	var lv := Data.garden_level()
	var g = main.garden
	var sub := "Level %d · %d plots · a step for every wave the camp holds" % [lv, Data.garden_plots()]
	if g == null:
		return {"title": "Garden", "sub": sub, "rows": [], "anchor": anchor}
	var rows: Array = []
	var cnt: Dictionary = g.counts()
	rows.append({"kind": "pantry"})
	if int(cnt["ripe"]) > 0:
		var pv: Dictionary = g.pick_preview()
		var bits: Array = []
		var add: Dictionary = pv["add"]
		for k in add:
			bits.append("+%d %s → %d/%d" % [int(add[k]), Data.item_name(String(k), int(add[k])),
				int(Save.pantry.get(k, 0)) + int(add[k]), int(Data.b["cooking"]["pantry_cap"])])
		var note := ", ".join(bits)
		for k in pv["full"]:
			note += (" · " if note != "" else "") + "pantry full of %s" % Data.item_name(String(k), 2)
		rows.append({"text": "Pick what is ripe", "note": note, "cost": {}, "label": "Pick", "enabled": not add.is_empty(), "pulse": true, "action": _garden_pick})
	else:
		rows.append({"text": "Nothing ripe yet", "note": g.summary(), "cost": {}, "label": "", "enabled": false, "action": Callable()})
	if int(cnt["growing"]) > 0:
		var w: int = g.wet_waves()
		var least := w
		for i in g.plots():
			if g._growing(i):
				least = mini(least, int(g.plot(i)["wet"]))
		if least < w:
			rows.append({"text": "Water the garden", "note": "Watered plants grow twice as fast for %d waves" % w, "cost": {}, "label": "Water",
				"enabled": true, "pulse": int(cnt["dry"]) > 0, "action": _garden_water})
		else:
			rows.append({"text": "Watered", "note": "%d more waves of water" % least, "cost": {}, "label": "", "enabled": false, "action": Callable()})
	var empty := int(cnt["empty"])
	var extra := int(Data.pick("garden", "extra_by_level", lv))
	var wet := int(Data.b["garden"]["grow_wet"])
	var dry := int(Data.b["garden"]["grow_dry"])
	var seeds: Array = []
	for c in Data.b["garden"]["crops"]:
		var grow := int(c["grow"])
		var note2 := "Ripe in %d waves with water, %d without · gives %d" % [int(ceil(float(grow) / wet)), int(ceil(float(grow) / dry)),
			int(c["yield"]) + extra] if empty > 0 else "No empty plot"
		seeds.append(_tile(String(c.get("gives", "garden")), "Plant %s" % String(c["name"]), note2, c["seed"], "Plant", empty > 0,
			_garden_plant.bind(String(c["id"])), "%d empty" % empty if empty > 0 else "Full"))
	_add_section(rows, "Plant", seeds)
	_add_section(rows, "Upgrade", [_station_upgrade_row("garden")])
	return {"title": "Garden", "sub": sub, "rows": rows, "anchor": anchor}


func _garden_plant(crop_id: String) -> void:
	if _locked() or main.garden == null:
		return
	var c := Data.crop(crop_id)
	if c.is_empty() or main.garden.first_empty() < 0 or not Data.can_afford(c["seed"]):
		return
	var i: int = main.garden.first_empty()
	Data.pay(c["seed"])
	main.garden.plant(crop_id)
	var at: Vector3 = main.garden.plot_pos(i)
	Fx.dust(main, at, 6, 0.7)
	main.garden.pop()
	Sfx.play("pop", -6.0)
	Save.save_game()
	main.on_purchase()


func _garden_water() -> void:
	if _locked() or main.garden == null:
		return
	if main.garden.water() <= 0:
		return
	Fx.puff(main, main.world.station_pos("garden") + Vector3(0, 0.6, 0), Color(0.55, 0.8, 1.0), 12)
	Sfx.play("water", -6.0)
	Save.save_game()
	main.on_purchase()


func _garden_pick() -> void:
	if _locked() or main.garden == null:
		return
	var got: Dictionary = main.garden.pick()
	if got.is_empty():
		return
	var at: Vector3 = main.world.station_pos("garden")
	var k := 0
	for g in got:
		Fx.text(main, at + Vector3(0, 1.0 + 0.4 * k, 0), "+%d %s" % [int(got[g]), Data.item_name(String(g), int(got[g]))], Color(0.75, 1.0, 0.5))
		k += 1
	Fx.flower_ring(main, at, 1.0)
	Sfx.play("pluck", -4.0)
	main.raids.add_gloom("harvest")
	Save.save_game()
	main.on_purchase()
	main.hud.toast(Data.food_receipt(got))
	if not Save.flag("told_cook"):
		Save.set_flag("told_cook")
		main.hud.tip("Cook what you pick at the pot by the campfire. A dish is eaten when the next chapter starts.", rings.get("pot"))


# ---------------------------------------------------------------- the cooking pot (comes with the garden)
func _card_pot() -> Dictionary:
	var anchor: Vector3 = main.world.station_pos("pot") + Vector3(0, 1.4, 0)
	var ck = main.cooking
	if ck == null:
		return {"title": "Cooking Pot", "sub": "", "rows": [], "anchor": anchor}
	var subs: Array = []
	if Save.meal_on != "":
		var ron := Data.recipe(Save.meal_on)
		subs.append("Active dish · %s · %s" % [String(ron.get("name", "")), String(ron.get("says", ""))])
	if Save.meal_ready != "":
		var waiting_dish := Data.recipe(Save.meal_ready)
		subs.append("Waiting dish · %s · %s · next chapter or dungeon run" % [String(waiting_dish.get("name", "")), String(waiting_dish.get("says", ""))])
	var sub := "\n".join(subs) if not subs.is_empty() else "One waiting dish · activates next chapter or dungeon run"
	var rows: Array = []
	rows.append({"kind": "section", "text": "Your food"})
	rows.append({"kind": "pantry"})
	var known: Array = ck.known()
	var ready: Array = known.filter(func(r): return ck.can_cook(r))
	var not_yet: Array = known.filter(func(r): return not ck.can_cook(r))
	var order: Array = ready + not_yet                 # what can be cooked now comes first
	var waiting := String(Data.recipe(Save.meal_ready).get("name", "")) if Save.meal_ready != "" else ""
	for r in order:
		var ok: bool = ck.can_cook(r)
		var note := "%s\n%s · next chapter or dungeon run" % [ck.needs_text(r), String(r.get("says", ""))]
		if not ok:
			note = "%s · %s" % [ck.why_not(r), note]
		elif waiting != "":
			note += "\nReplaces %s and uses these ingredients" % waiting
		rows.append({"text": "Cook %s" % String(r["name"]), "note": note, "cost": {}, "label": "Replace" if waiting != "" else "Cook", "enabled": ok,
			"pulse": ok and Save.meal_ready == "", "action": _cook_dish.bind(String(r["id"]))})
	return {"title": "Cooking Pot", "sub": sub, "rows": rows, "anchor": anchor}


## Cook a dish: it waits in the pot and is eaten when the next chapter starts. Between waves only, never on the ashes.
func _cook_dish(id: String) -> void:
	if _locked() or _out or Save.fire_ruined or main.cooking == null:
		return
	main.cooking.cook(id)


# ---------------------------------------------------------------- the Fishing Spot (Phase C, mission 6's gift)
func _card_fishing() -> Dictionary:
	var anchor := _anchor("fishing", 1.6)
	var fsh = main.fishing
	var sub := "Calm water · fish for the cooking pot · %d fish in the pantry" % int(Save.pantry.get("fish", 0))
	if fsh == null:
		return {"title": "Fishing Spot", "sub": sub, "rows": [], "anchor": anchor}
	var rows: Array = []
	var riding: bool = main.player.riding
	rows.append({"text": "Cast a line", "note": ("Get off %s to fish" % Data.mount_name()) if riding else "Tap anywhere when the float dips · drag to stop",
		"cost": {}, "label": "Cast", "enabled": fsh.can_fish(), "action": _cast})
	var cfg: Dictionary = Data.b["fishing"]
	var bits: Array = []
	for e in cfg["catches"]:
		var n := int(Save.fish_log.get(String(e["id"]), 0))
		bits.append("%s %d" % [String(e["name"]), n] if n > 0 else "?")
	rows.append({"text": "Fish log · %d of %d found" % [fsh.log_found(), (cfg["catches"] as Array).size()], "note": " · ".join(bits),
		"cost": {}, "label": "", "enabled": false, "action": Callable()})
	var found := 0
	var tb: Array = []
	for tr in cfg["treasures"]:
		if Save.flag(String(tr["id"])):
			found += 1
			tb.append("%s: %s" % [String(tr["name"]), String(tr["says"])])
		else:
			tb.append("?")
	rows.append({"text": "Lake treasures · %d of %d" % [found, (cfg["treasures"] as Array).size()], "note": " · ".join(tb),
		"cost": {}, "label": "", "enabled": false, "action": Callable()})
	return {"title": "Fishing Spot", "sub": sub, "rows": rows, "anchor": anchor}


func _cast() -> void:
	if _locked() or main.fishing == null:
		return
	main.fishing.cast(rings["fishing"])


# ---------------------------------------------------------------- the campfire's ring (after the camp fell)
func _card_fire() -> Dictionary:
	var cost := _fire_cost()
	var free := cost.is_empty()
	return {"title": "The campfire", "sub": "Only ashes are left", "rows": [
		_cost_row("Rebuild the campfire: Free" if free else "Rebuild the campfire",
			"Free: you have too few leaves to pay" if free else "Light the camp again, then fight on", cost, "Rebuild", true, _rebuild_fire)],
		"anchor": Vector3(0, 1.6, 0)}


## Relighting the ashes costs leaves only; with fewer than that, it is free (so the camp can never get stuck).
func _fire_cost() -> Dictionary:
	var cost: Dictionary = Data.b["raid"].get("fire_rebuild", {"leaves": 40})
	if Save.leaves < int(cost.get("leaves", 40)):
		return {}
	return {"leaves": int(cost.get("leaves", 40))}


func _rebuild_fire() -> void:
	if not Save.fire_ruined or not Data.pay(_fire_cost()):
		return
	Save.fire_ruined = false
	Save.save_game()
	main.world.set_fire_out(false)
	set_fire_out(false)
	Fx.flower_ring(main, Vector3.ZERO, 2.0)
	main.hud.banner("The campfire burns again!", Color(1.0, 0.85, 0.45), "The camp is safe")
	main.on_purchase()


## The home's windows and lantern glow warm.
func _glow(home: Node3D) -> void:
	var g := Props.find_part(home, "glow")
	if g == null:
		return
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1.6, 1.3, 0.9)
	_flame_material(g, m)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.75, 0.42)
	light.light_energy = 0.8
	light.omni_range = 2.4
	light.position = Vector3(0, 1.5, 1.2)
	light.add_to_group("lamp")
	light.visible = Quality.lamps()
	home.add_child(light)
	if Save.camp_level >= 4:                        # the big homes have rooms and lanterns up high too
		var up := light.duplicate() as OmniLight3D
		up.position = Vector3(0, 3.4 + (mini(Save.camp_level, 6) - 4) * 0.5, 1.0)
		up.omni_range = 3.2
		up.add_to_group("lamp")
		home.add_child(up)


func _update_pulses() -> void:
	# a ring pulses when something there is new or affordable (the Hearthtree's: growing it, once every goal is met and
	# the price is affordable, is one of those rows; a "quiet" row never counts: the Market's everyday trades); the
	# signpost between waves, unless the next mission waits for a bigger Hearthtree
	for id in rings:
		var ring = rings[id]
		if not ring.visible:
			ring.pulse = false
			continue
		var spec: Dictionary = ring.builder.call()
		var any := false
		for row in spec.get("rows", []):
			if row.get("enabled", false) and not row.get("quiet", false) and (row.get("pulse", false) or not (row.get("cost", {}) as Dictionary).is_empty()):
				any = true
		ring.pulse = any or (id == "sign" and not (main.fight.active and main.fight.in_wave) and not _next_locked())


## The next mission waits for a bigger Hearthtree (no fight on, no saved run, the missions not over).
func _next_locked() -> bool:
	if main.fight.active or Save.mission_run.has("mission") or Data.raids_open():
		return false
	return not Data.mission_unlocked(Data.next_mission())


func flame() -> Node3D:
	return Props.find_part(nodes["campfire"], "flame") if nodes.has("campfire") else null


var _fire_light: OmniLight3D
var _fire_fx: Node3D
var _fire_for: Node3D
var _embers_p: CPUParticles3D
var _out := false


## Last Stand: the flame, its light and the embers go; only the smoke is left.
func set_fire_out(on: bool) -> void:
	_out = on
	var f := flame()
	if f:
		f.visible = not on
	if _fire_light and is_instance_valid(_fire_light):
		_fire_light.visible = not on
	if _embers_p and is_instance_valid(_embers_p):
		_embers_p.emitting = not on
	if on and nodes.has("campfire"):
		Fx.smoke(main, nodes["campfire"].global_position)
	if rings.has("pot"):
		rings["pot"].visible = ring_shown("pot")       # no cooking on the ashes (the Last Stand)


## The campfire comes alive: the flame licks and glows (flame.gdshader), a warm light flickers over the camp, embers
## float up and a thin smoke rises.
func _light_fire() -> void:
	var fire: Node3D = nodes.get("campfire")
	if fire == null or fire == _fire_for:
		return
	_fire_for = fire
	var f := flame()
	var base := 0.0                                 # where the flame starts and how tall it is, for the light,
	var tall := 0.6                                 # the embers and the smoke (the brazier's sits up in its bowl)
	if f:
		base = (f.global_position - fire.global_position).y
		if f is MeshInstance3D and (f as MeshInstance3D).mesh:
			tall = maxf(0.6, (f as MeshInstance3D).mesh.get_aabb().end.y)
		var fm := ShaderMaterial.new()
		fm.shader = preload("res://shaders/flame.gdshader")
		fm.set_shader_parameter("tint", _fire_tint())
		_flame_mat = fm
		fm.set_shader_parameter("height", tall)
		fm.set_shader_parameter("sway", clampf(tall / 0.6, 1.0, 1.8))
		_flame_material(f, fm)
	if _fire_fx and is_instance_valid(_fire_fx):
		_fire_fx.queue_free()
	_fire_fx = Node3D.new()
	fire.add_child(_fire_fx)
	_fire_light = OmniLight3D.new()
	_fire_light.light_color = Color(1.0, 0.62, 0.28)
	_fire_light.light_energy = 2.2
	_fire_light.omni_range = 4.5
	_fire_light.omni_attenuation = 1.4
	_fire_light.position = Vector3(0, base + 0.6, 0)
	_fire_fx.add_child(_fire_light)
	_embers_p = _embers()
	_embers_p.position = Vector3(0, base + 0.25, 0)
	_fire_fx.add_child(_embers_p)
	var sm := _smoke()
	sm.position = Vector3(0, base + tall * 0.85, 0)
	_fire_fx.add_child(sm)
	set_fire_out(_out)


func _flame_material(n: Node, m: Material) -> void:
	if n is MeshInstance3D:
		(n as MeshInstance3D).material_override = m
		(n as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_flame_material(c, m)


func _embers() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.035, 0.035)
	p.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	p.material_override = m
	p.amount = 18
	p.lifetime = 1.6
	p.position = Vector3(0, 0.35, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.18
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 1.2
	p.gravity = Vector3(0, 0.4, 0)
	p.tangential_accel_min = -0.6
	p.tangential_accel_max = 0.6
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([Color(1.0, 0.85, 0.4, 1.0), Color(1.0, 0.45, 0.15, 1.0), Color(0.6, 0.1, 0.05, 0.0)])
	p.color_ramp = g
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


func _smoke() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var s := SphereMesh.new()
	s.radius = 0.12
	s.height = 0.2
	s.radial_segments = 6
	s.rings = 3
	p.mesh = s
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	p.material_override = m
	p.amount = 7
	p.lifetime = 2.6
	p.position = Vector3(0, 0.8, 0)
	p.direction = Vector3.UP
	p.spread = 12.0
	p.initial_velocity_min = 0.35
	p.initial_velocity_max = 0.55
	p.gravity = Vector3(0.15, 0.05, -0.05)
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.1
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.5))
	sc.add_point(Vector2(1.0, 1.0))
	p.scale_amount_curve = sc
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	g.colors = PackedColorArray([Color(0.9, 0.85, 0.8, 0.0), Color(0.85, 0.82, 0.8, 0.28), Color(0.8, 0.8, 0.82, 0.0)])
	p.color_ramp = g
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


## The campfire's look (Phase D: Shardfire burns blue-violet): the flame's tint and its light's colour.
var _flame_mat: ShaderMaterial
var _light_col := Color(1.0, 0.62, 0.28)


func _fire_look() -> Dictionary:
	for fl in Data.gr()["fire_looks"]:
		if String(fl["id"]) == Save.fire_look:
			return fl
	return Data.gr()["fire_looks"][0]


func _fire_tint() -> Vector3:
	var t: Array = _fire_look().get("tint", [1, 1, 1])
	var l: Array = _fire_look().get("light", [1.0, 0.62, 0.28])
	_light_col = Color(float(l[0]), float(l[1]), float(l[2]))
	return Vector3(float(t[0]), float(t[1]), float(t[2]))


func apply_fire_look() -> void:
	var tint := _fire_tint()
	if _flame_mat != null:
		_flame_mat.set_shader_parameter("tint", tint)
	var fire: Node3D = nodes.get("campfire")
	if fire:
		Fx.boing(fire, 0.3)
		Fx.flower_ring(main, Vector3.ZERO, 1.4)


func _process(_delta: float) -> void:
	_light_fire()
	if _fire_light and is_instance_valid(_fire_light):
		var t := Time.get_ticks_msec() * 0.001
		var n := 0.55 * sin(t * 13.0) * sin(t * 5.7) + 0.3 * sin(t * 23.0 + 1.3)
		_fire_light.light_energy = 2.2 + n * 0.6
		_fire_light.light_color = Color(_light_col.r, _light_col.g + n * 0.05, _light_col.b)


# ---------------------------------------------------------------- cards
func _cost_row(text: String, note: String, cost: Dictionary, label: String, ok: bool, action: Callable) -> Dictionary:
	return {"text": text, "note": note, "cost": cost, "label": label, "enabled": ok and Data.can_afford(cost), "action": action}


## Phase G2: a shop tile (hud.gd lays consecutive ones out as a grid): an icon, a name, one short line, optional stat
## bars ([["Damage", 0..1], ...]) and a badge ("Level 3/5", "Owned", "Equipped", "New", "Max", "Locked"), the price and
## one button. With no label (or no action) it has no working button: an owned look in use, a stat at its top.
func _tile(icon: String, title: String, text: String, cost: Dictionary, label: String, ok: bool, action: Callable,
		badge := "", stats: Array = []) -> Dictionary:
	var t := {"kind": "item", "icon": icon, "title": title, "text": text, "cost": cost, "label": label,
		"enabled": ok and label != "" and action.is_valid() and Data.can_afford(cost), "action": action}
	if badge != "":
		t["badge"] = badge
	if not stats.is_empty():
		t["stats"] = stats
	return t


## The Hearthtree's name without "the", for a tile's title ("Hearthtree level 3").
func _camp_word() -> String:
	return Data.camp_name(true).trim_prefix("The ")


## A small shelf heading over the tiles that follow it.
func _section(text: String) -> Dictionary:
	return {"kind": "section", "text": text}


## A shelf: its heading, then its rows (nothing at all when it has none).
func _add_section(rows: Array, heading: String, items: Array) -> void:
	if items.is_empty():
		return
	rows.append(_section(heading))
	rows.append_array(items)


func _anchor(id: String, h: float) -> Vector3:
	return main.world.station_pos(id) + Vector3(0, h, 0)


## The Hearthtree's card (ring "shop"): its goal list first (compact lines), then shop tiles in sections: Grow, The
## cat, Buildings, Defences, and Settings (the graphics row stays a plain row).
func _card_shop() -> Dictionary:
	var title := Data.camp_name(true)
	if Save.ruined.has("home"):
		return _ruin_card("home", title, _anchor("home", 3.2))
	var lv := Save.camp_level
	var rows: Array = []
	if Data.raids_open():
		var cc: Dictionary = main.raids.camp_check()
		if not (cc["items"] as Array).is_empty():
			rows.append(main.raids.camp_row(cc))          # anything broken after a raid: Mend all at the very top
	rows.append_array(_grow_rows())                    # Phase F: its goals, then (G2) the Grow section and its tile
	rows.append_array(_wear_row("home"))
	if not Save.flag("shop_open"):
		rows.append({"text": "Nothing for sale yet", "note": "Defend the camp first: enemies drop golden leaves", "cost": {}, "label": "", "enabled": false, "action": Callable()})
	# the cat
	if Save.flag("home"):
		_add_section(rows, "The cat", _stat_rows(["health", "speed", "magnet"]))
	_add_section(rows, "Buildings", _building_tiles())
	_add_section(rows, "Defences", _defence_tiles())
	# graphics: Auto, Low, Medium, High (kept apart from the save; see quality.gd)
	rows.append(_section("Settings"))
	rows.append(_cost_row("Graphics: %s" % Quality.label(), "Lower it if the game stutters · Auto picks for this phone",
		{}, "Change", true, Quality.cycle))
	var names: Array = Data.b["home_names"]
	var sub := "Level %d: %s" % [lv, String(names[clampi(lv - 1, 0, names.size() - 1)])]
	if _grow_shown():
		var goals := Data.home_goals(lv + 1)
		var met := goals.filter(func(g): return bool(g["done"])).size()
		sub += " · level %d: %d of %d goals" % [lv + 1, met, goals.size()]
	return {"title": title, "sub": sub, "rows": rows, "anchor": _anchor("home", 3.2)}


## The Buildings shelf: the Training Target and the Bow Shop (once the first mission shows them), then the Wishing
## Well (Hearthtree 3), the Mushroom Cottage and the Market (Hearthtree 2), the Saddlery (8 missions and
## Hearthtree 2). Once the first mission is won, a building that is not open yet shows as a locked tile with what it
## needs.
func _building_tiles() -> Array:
	var out: Array = []
	for sid in ["target", "bench"]:
		if Save.flag("shop_" + sid) and int(Save.stations[sid]) == 0:
			var info: Dictionary = Data.b["stations"][sid]
			out.append(_tile(_station_icon(sid), String(info["name"]), _village_note(sid), info["build"], "Build", true,
				_build_station.bind(sid), "New"))
	if not Save.flag("shop_open"):
		return out
	# G4: the Saddlery once mission 8 is won (and Hearthtree 2); 23 Nov 2026: the Tailor's Nook at Hearthtree 3
	for sid in ["well", "cottage", "stall", "saddlery", "tailor"]:
		if int(Save.stations.get(sid, 0)) > 0:
			continue
		var vi: Dictionary = Data.b["stations"][sid]
		if Data.station_open(sid):
			out.append(_tile(_station_icon(sid), String(vi["name"]), _village_note(sid), vi["build"], "Build", true,
				_build_station.bind(sid), "New"))
		elif Data.progress() >= 1:
			out.append(_tile(_station_icon(sid), String(vi["name"]), _station_needs(sid), vi["build"], "Build", false, Callable(), "Locked"))
	return out


## What a building still waits for: "Needs the Hearthtree at level 2", "Win 4 missions first".
func _station_needs(sid: String) -> String:
	var vi: Dictionary = Data.b["stations"][sid]
	var bits: Array = []
	if Save.camp_level < int(vi.get("needs_home", 1)):
		bits.append("Needs %s at level %d" % [Data.camp_name(), int(vi.get("needs_home", 1))])
	var need := int(vi.get("needs_missions", 0))
	if Data.progress() < need:
		bits.append("Finish %d Raid Missions first" % need)
	return " · ".join(bits)


## The Defences shelf: mending what a raid or a camp fall left broken, then for each kind its pieces (towers and spikes:
## barricade rows are built at the road spots now, defences.gd) and its next level (the barricade level raises every
## row's health).
func _defence_tiles() -> Array:
	var out: Array = []
	var lv := Save.camp_level
	# defences kept damaged after a Gloom Raid or a camp fall
	var wrecked: int = main.defences.wrecked_count()
	if wrecked > 0:
		out.append(_tile("repair", "Mend the defences", "%d defence piece%s broken or damaged" % [wrecked, "s" if wrecked > 1 else ""],
			{"leaves": main.defences.repair_cost()}, "Mend", true, _mend_raid))
	for type in ["barricade", "tower", "spikes"]:
		var di := Data.defence_info(type)
		if not main.defences.unlocked(type):
			continue
		if type != "barricade":
			var have := int(Save.items.get(type, 0))
			var note := "You have %d to place · tap the build button" % have if have > 0 else _def_note(type)
			var room: bool = main.defences.room_for(type)
			if not room:
				note = main.defences.room_note(type)
			out.append(_tile(type, String(di["name"]), note, {"leaves": int(di["piece"])}, "Buy", room, _buy_piece.bind(type),
				("%d to place" % have) if have > 0 else ""))
		var dl: int = main.defences.level(type)
		var dlevels: Array = di["levels"]
		var shown_top := _def_shown_top(type)
		# level 4 (Shardstone) once raids are open; level 5 (Phase E: Heartwood, Amber) once the Burrows are open
		if dl < shown_top:
			var ok := dl + 1 <= lv
			var lnote := _def_level_note(type, dl + 1) if ok else "Needs %s at level %d" % [Data.camp_name(), dl + 1]
			var dcost := _def_cost(type, dl + 1)
			if ok and dl + 1 == 4:
				lnote += " · set with Gloom shards"
			elif ok and dl + 1 >= 5:
				lnote += Data.mats_line(dcost)
			out.append(_tile(type, _def_level_title(type, dl + 1), lnote, dcost, "Upgrade", ok, _upgrade_defence.bind(type),
				"Level %d/%d" % [dl, dlevels.size()], [["Level", float(dl) / float(maxi(dlevels.size(), 1))]]))
	return out


## The highest defence level on offer now: 3, then 4 (Shardstone) once raids are open, 5 once the Burrows are open.
func _def_shown_top(type: String) -> int:
	var n := (Data.defence_info(type)["levels"] as Array).size()
	if not Data.raids_open():
		n = mini(n, 3)
	elif not Data.burrows_open():
		n = mini(n, 4)
	return n


## "Barricades level 2", "Towers level 3", "Thorn Spikes: Shardstone" (levels 4 and 5 have names).
func _def_level_title(type: String, lv: int) -> String:
	var dlevels: Array = Data.defence_info(type)["levels"]
	var kind := Data.def_kind_name(type)
	if lv >= 4 and lv <= dlevels.size() and dlevels[lv - 1].has("name"):
		return "%s: %s" % [kind, String(dlevels[lv - 1]["name"])]
	return "%s level %d" % [kind, lv]


func _mend_raid() -> void:
	var cost := {"leaves": main.defences.repair_cost()}
	if main.defences.wrecked_count() == 0 or not Data.pay(cost):
		return
	main.defences.repair_raid()
	main.hud.banner("Defences mended!", Color(1.0, 0.9, 0.45))
	main.on_purchase()


func _village_note(sid: String) -> String:
	match sid:
		"target": return "Train here to hit harder, shoot faster, reach further"
		"bench": return "Buy new bows, upgrade and equip them"
		"well": return "Mends the camp by itself, a little at a time"
		"cottage": return "%s moves in and fights beside you" % String(Data.look("pet", Save.pet_look)["name"])
		"stall": return "Bramble's shop, and %s comes free" % String(Data.look("mount", Save.mount_look)["name"])
		"saddlery": return "Skills and attachments for %s" % Data.mount_name()
		"tailor": return "New outfits for the cat · looks only"
	return ""


## The icon id of a building's tiles (hud.gd draws them; an unknown id is a plain round icon).
func _station_icon(sid: String) -> String:
	match sid:
		"home": return "home"
		"target": return "target"
		"bench": return "bow"
		"well": return "well"
		"cottage": return "pet"
		"stall": return "market"
		"saddlery": return "saddlery"
		"tailor": return "tailor"
		"garden": return "garden"
		"stone": return "guardian"
		"fishing": return "fishing"
		"pot": return "pot"
	return sid


func _def_note(type: String) -> String:
	match type:
		"barricade": return "Blocks a road at one of its glowing spots: enemies must break it"
		"tower": return "Shoots acorns at enemies near it"
		"spikes": return "Hurts and slows enemies that walk over it"
	return ""


func _def_level_note(type: String, lv: int) -> String:
	var l: Dictionary = Data.defence_info(type)["levels"][lv - 1]
	match type:
		"barricade": return "%d health each" % int(l["hp"])
		"tower": return "360° · %d damage · %.1fm\nEvery %.2fs · %d health" % [int(l["damage"]), float(l["range"]), float(l["every"]), int(l.get("hp", 0))]
		"spikes": return "%d damage a second, slows more" % int(l["dps"])
	return ""


## Builds a station bought on the Hearthtree's card, once it is open (Data.station_open: needs_missions, needs_home).
## Phase G2: the Market brings Thistle with it (the mount comes with the stall's level, main.refresh_companions), as the
## old gift of mission 2 did.
func _build_station(sid: String) -> void:
	if int(Save.stations[sid]) > 0 or not Data.station_open(sid) or not Data.pay(Data.b["stations"][sid]["build"]):
		return
	Save.stations[sid] = 1
	if main.fight.active and BUILDINGS.has(sid):
		hp[sid] = full_hp(sid)
	Save.save_game()
	refresh(sid)
	main.on_purchase()
	match sid:
		"cottage":
			main.hud.banner("%s moves in!" % Data.pet_name(), Color(0.6, 1.0, 0.45), "A little friend now fights beside the cat")
		"stall":
			main.hud.banner("The %s is open!" % _name("stall"), Color(1.0, 0.9, 0.55), "Bramble trades here, and %s comes free: tap Ride to hop on" % Data.mount_name())
		"well":
			main.hud.banner("Wishing Well built!", Color(0.6, 0.85, 1.0), "It keeps the camp mended by itself")
		"saddlery":
			main.hud.banner("Saddlery built!", Color(1.0, 0.85, 0.55), "Teach %s skills and make it attachments here" % Data.mount_name())
		"tailor":
			main.hud.banner("%s built!" % _name("tailor"), Color(0.82, 0.68, 1.0), "New outfits for the cat: looks only")
		_:
			main.hud.banner("%s built!" % Data.b["stations"][sid]["name"], Color(1.0, 0.9, 0.45))


func _buy_piece(type: String) -> void:
	if not Data.pay({"leaves": int(Data.defence_info(type)["piece"])}):
		return
	Save.items[type] = int(Save.items.get(type, 0)) + 1
	Save.save_game()
	main.on_purchase()
	main.hud.refresh_build()


## What a defence level costs: leaves, and Gloom shards for level 4 (H1: level 5 is leaves only, after the Burrows open).
func _def_cost(type: String, lv: int) -> Dictionary:
	var l: Dictionary = Data.defence_info(type)["levels"][lv - 1]
	var c := {"leaves": int(l["upgrade"])}
	for k in Data.CURRENCIES:
		if k != "leaves" and int(l.get(k, 0)) > 0:
			c[k] = int(l[k])
	return c


func _upgrade_defence(type: String) -> void:
	var dl: int = main.defences.level(type)
	var levels: Array = Data.defence_info(type)["levels"]
	if dl >= levels.size() or dl + 1 > Save.camp_level or (dl + 1 >= 4 and not Data.raids_open()) or (dl + 1 >= 5 and not Data.burrows_open()):
		return
	if not Data.pay(_def_cost(type, dl + 1)):
		return
	Save.def_levels[type] = dl + 1
	Save.save_game()
	main.defences.relevel(type)
	main.on_purchase()


## Grows the home a level: every goal on the next level's list met (Data.home_goals_met, which keeps the older
## needs_burrows / needs_depth gates of levels 6-8) and its price paid.
func _grow_camp() -> void:
	var levels: Array = Data.b["stations"]["camp"]["levels"]
	if Save.camp_level >= levels.size():
		return
	var next: Dictionary = levels[Save.camp_level]
	if not Data.home_goals_met(Save.camp_level + 1):
		return
	if not Data.pay(_level_cost(next)):
		return
	Save.camp_level += 1
	Save.save_game()
	main.on_camp_grown()


# ---------------------------------------------------------------- Phase F: growing the Hearthtree (its goals)
## The Hearthtree's card shows the next level's goals once the first mission is won (the first mission's shop stays
## simple).
func _grow_shown() -> bool:
	var levels: Array = Data.b["stations"]["camp"]["levels"]
	return Save.camp_level < levels.size() and (Data.progress() >= 1 or Save.camp_level > 1)


## The top of the Hearthtree's card: each goal of its next level on one line (a tick when met, else its progress and a
## button to where it is bought), then (G2) the Grow section with its tile: the price and Grow (on only when every goal
## is met and the price affordable: then the Hearthtree's badge shows its "!"). The tile is the last row.
func _grow_rows() -> Array:
	var rows: Array = []
	if not _grow_shown():
		return rows
	var lv := Save.camp_level
	var levels: Array = Data.b["stations"]["camp"]["levels"]
	var goals := Data.home_goals(lv + 1)
	for g in goals:
		rows.append(_goal_row(g))
	var next: Dictionary = levels[lv]
	var cost := _level_cost(next)
	var met := Data.home_goals_met(lv + 1)
	var fires: Array = Data.b["fire_hp_by_camp_level"]
	var fire_hp := int(fires[mini(lv + 1, fires.size() - 1)])
	var towers: Array = Data.defence_info("tower")["max_by_camp_level"]
	var names: Array = Data.b["home_names"]
	var gives := "%s · campfire %d · %d towers" % [String(names[mini(lv, names.size() - 1)]), fire_hp,
		int(towers[mini(lv + 1, towers.size() - 1)])]
	if lv + 1 <= 5:                                     # the Training Target and the Bow Shop stop at 5
		gives += " · buildings lv %d" % (lv + 1)
	var left := goals.filter(func(g): return not bool(g["done"])).size()
	var note := gives + Data.mats_line(cost)
	if not met:
		if left > 0:
			note = gives                                # the tile's Goals bar shows how many are met
		elif bool(next.get("needs_burrows", false)) and not Data.burrows_open():
			note = "After the raids: the Gloomwood must open first"
		else:
			note = "Beat level %d of %s first" % [int(next.get("needs_depth", 0)), String(Data.burrow_list()[0]["name"])]
	rows.append(_section("Grow"))
	var row := _tile("grow", "%s level %d" % [_camp_word(), lv + 1], note, cost, "Grow", met, _grow_camp,
		"Level %d/%d" % [lv, levels.size()], [["Goals", float(goals.size() - left) / float(maxi(goals.size(), 1)),
		"%d/%d" % [goals.size() - left, goals.size()]]])
	row["pulse"] = bool(row["enabled"])
	rows.append(row)
	return rows


## One goal on the Hearthtree's card: "Damage 4" with a tick when met, else "Damage 3/4" and Go (the cat walks to the
## card that sells it) or Show (it is sold further down this card). `small`/`done` make it a compact line (hud.gd).
func _goal_row(g: Dictionary) -> Dictionary:
	var done := bool(g["done"])
	var row := {"text": String(g["text"]) if done else String(g["progress"]), "note": "", "cost": {}, "label": "",
		"enabled": false, "action": Callable(), "small": true, "done": done, "goal": g}
	if not done:
		var r = goal_ring(String(g["station"]))
		if r != null:
			row["label"] = "Show" if r == rings["shop"] else "Go"
			row["enabled"] = true
			row["action"] = _goal_go.bind(g)
	return row


## The marker whose card sells a goal (Data.home_goals' `station`): the Hearthtree's ("home"), a station's, the signpost's
## ("sign") or the Old Hollow's ("hollow"). null when there is none to go to now (not built, or hidden).
func goal_ring(sid: String):
	var r = null
	match sid:
		"home", "camp", "shop": r = rings.get("shop")
		"hollow": r = main.burrows.ring() if main.get("burrows") != null else null
		_: r = rings.get(sid)
	if r == null or not is_instance_valid(r) or not r.visible:
		return null
	return r


## A tap on a goal: its card opens, and the cat walks there first if it is out of reach (as a tap on its marker does).
## A goal sold on the card already open (the Hearthtree's own stats, buildings, towers, defences) scrolls the card to
## its tile.
func _goal_go(g: Dictionary) -> void:
	var r = goal_ring(String(g.get("station", "")))
	if r == null:
		return
	if r == main.hud.card_ring():
		main.hud.scroll_card_to(_goal_find(g))
		return
	main.hud.hide_card()
	if main.interact != null:
		main.interact.use(r)
	else:
		main.open_ring(r)


## The title of the tile on the Hearthtree's card that sells a goal (hud.scroll_card_to finds the first row or tile
## holding these words).
func _goal_find(g: Dictionary) -> String:
	var id := String(g.get("id", ""))
	match String(g.get("type", "")):
		"stat", "all_stats":
			return String(Data.stat_info(id)["name"]) if Data.b["stats"].has(id) else ""
		"towers":
			var tl: int = main.defences.level("tower")
			if tl < int(g.get("level", 1)):
				return _def_level_title("tower", tl + 1)
			return String(Data.defence_info("tower")["name"])
		"defence":
			if not Data.b["defences"].has(id):
				return ""
			return _def_level_title(id, main.defences.level(id) + 1)
		"station":
			return String(Data.b["stations"].get(id, {}).get("name", id))
	return ""


## A level's price (every currency it names; other keys such as needs_* are not money).
func _level_cost(next: Dictionary) -> Dictionary:
	var c := {}
	for k in Data.CURRENCIES:
		if int(next.get(k, 0)) > 0:
			c[k] = int(next[k])
	return c


## What each stat does, in one short line, and its tile's icon (hud.gd draws the icons).
const STAT_SAYS := {"damage": "Arrows hit harder", "draw": "Shoots faster", "range": "Shoots from further away",
	"health": "More health for the cat", "speed": "The cat runs faster", "magnet": "Leaves fly in from further"}
const STAT_ICONS := {"damage": "damage", "draw": "draw", "range": "range", "health": "heart", "speed": "speed", "magnet": "magnet"}


## The stat tiles (the Training Target's Damage, Draw speed and Range; the Hearthtree's Health, Move speed and Leaf
## magnet): a bar for the level out of what the station allows now, "Level 3/6", and Buy.
func _stat_rows(ids: Array) -> Array:
	var rows: Array = []
	for sid in ids:
		var info := Data.stat_info(sid)
		var lv := int(Save.stats[sid])
		var cap := Data.stat_cap(sid)
		var costs: Array = info["cost"]
		var top := Data.stat_top(sid)
		var unit := String(info["unit"])
		var per := float(info["per_level"])
		var now := ""
		match unit:
			"x": now = "+%d%%" % int(round(per * lv * 100.0))
			"m": now = "+%.1fm" % (per * lv)
			"hp": now = "+%d" % int(per * lv)
		var nm := String(info["name"])
		var icon := String(STAT_ICONS.get(sid, sid))
		var says := String(STAT_SAYS.get(sid, ""))
		var bar := [["Level", float(lv) / float(maxi(maxi(cap, lv), 1))]]
		var at_home := String(info["station"]) == "home" or String(info["station"]) == "camp"
		if cap == 0:
			rows.append(_tile(icon, nm, "Upgrade the %s to unlock" % _name(String(info["station"])) if not at_home else "Grow %s to unlock" % Data.camp_name(),
				{}, "", false, Callable(), "Locked"))
		elif lv >= top:
			rows.append(_tile(icon, nm, "%s · now %s" % [says, now], {}, "", false, Callable(), "Max", [["Level", 1.0]]))
		elif lv >= cap:
			var more := ("Grow %s for more" % Data.camp_name()) if at_home else ("Upgrade the %s for more" % _name(String(info["station"])))
			rows.append(_tile(icon, nm, "Now %s · %s" % [now, more], {}, "", false, Callable(), "Level %d/%d" % [lv, maxi(cap, lv)], bar))
		elif lv >= costs.size():
			var mc := Data.stat_cost(sid, lv)          # Phase E: mastery, past level 10
			rows.append(_tile(icon, nm, "Mastery: now %s%s" % [now, Data.mats_line(mc)], mc, "Buy", true, _buy_stat.bind(sid),
				"Mastery %d/%d" % [lv - costs.size() + 1, top - costs.size()], bar))
		else:
			rows.append(_tile(icon, nm, ("%s · now %s" % [says, now]) if lv > 0 else says, Data.stat_cost(sid, lv), "Buy", true,
				_buy_stat.bind(sid), "Level %d/%d" % [lv, cap], bar))
	return rows


func _buy_stat(sid: String) -> void:
	var lv := int(Save.stats[sid])
	if lv >= Data.stat_cap(sid) or lv >= Data.stat_top(sid):
		return
	if not Data.pay(Data.stat_cost(sid, lv)):
		return
	Save.stats[sid] = lv + 1
	Save.save_game()
	main.on_purchase()
	var st := String(Data.stat_info(sid)["station"])
	Fx.flower_ring(main, main.world.station_pos(st), 1.0)
	if sid == "health":
		main.player.hp = Data.cat_max_hp()
		main.hud.refresh_hp()


## A station's own upgrade tile: "Training Target level 2" with what the level gives, "Level 1/5", and Upgrade (never
## above the Hearthtree's level). At its top: the station's name and Max, no button.
func _station_upgrade_row(id: String) -> Dictionary:
	var lv := int(Save.stations[id])
	var levels: Array = Data.b["stations"][id]["levels"]
	var nm := String(Data.b["stations"][id]["name"])
	var icon := _station_icon(id)
	if lv >= levels.size() or (bool(levels[lv].get("needs_burrows", false)) and not Data.burrows_open()):
		return _tile(icon, nm, "At max level for now" if lv < levels.size() else "At max level", {}, "", false, Callable(), "Max", [["Level", 1.0]])
	var next: Dictionary = levels[lv]
	var cost := _level_cost(next)
	var ok := lv + 1 <= Save.camp_level
	var gives := ""
	if id == "target":
		gives = "Stats up to level %d%s" % [int(Data.b["stat_cap_by_station_level"][lv + 1]), ", unlocks Range" if lv + 1 == 2 else ""]
	elif id == "well":
		gives = _well_line(lv + 1)
	elif id == "cottage":
		gives = "%s: %d damage every %.1fs" % [Data.pet_name(), int(Data.pick("pet", "damage_by_level", lv + 1)), Data.pick("pet", "every_by_level", lv + 1)]
	elif id == "stall":
		gives = "%s runs faster and has %d health" % [Data.mount_name(), roundi(Data.pick("mount", "hp_by_level", lv + 1) * Data.mount_hp_mult())]
	elif id == "saddlery":
		gives = "Skills and attachments up to level %d" % (lv + 1)
	elif id == "stone":
		var pw := Data.guardian_power()                 # the next stone level at today's Hearthtree level
		gives = "%s: %s health, fists %d, slam %d" % [Data.guardian_name(), _thousands(int(round(Data.pick("guardian", "hp_by_level", lv + 1) * pw))),
			int(round(Data.pick("guardian", "fist_damage_by_level", lv + 1) * pw)), int(round(Data.pick("guardian", "slam_damage_by_level", lv + 1) * pw))]
	elif id == "garden":
		gives = "%d plots, water lasts %d waves" % [int(Data.pick("garden", "plots_by_level", lv + 1)), int(Data.pick("garden", "wet_waves_by_level", lv + 1))]
		if int(Data.pick("garden", "extra_by_level", lv + 1)) > 0:
			gives += ", +%d on every harvest" % int(Data.pick("garden", "extra_by_level", lv + 1))
	else:
		gives = "Bows up to level %d" % int(Data.b["bow_cap_by_bench_level"][lv + 1])
		var sells: Array = []
		for bid in Data.b["bows"]:
			var bi := Data.bow_info(bid)
			if int(bi["bench_level"]) == lv + 1 and not Data.bow_hidden(String(bid)) and not (bool(bi.get("needs_burrows", false)) and not Data.burrows_open()):
				sells.append("the " + String(bi["name"]))
		if not sells.is_empty():
			gives += ", sells %s" % " and ".join(sells)
	var text := gives if ok else ("Needs %s at level %d" % [Data.camp_name(), lv + 1])
	return _tile(icon, "%s level %d" % [nm, lv + 1], text, cost, "Upgrade", ok, _upgrade_station.bind(id),
		"Level %d/%d" % [lv, levels.size()], [["Level", float(lv) / float(maxi(levels.size(), 1))]])


func _upgrade_station(id: String) -> void:
	var lv := int(Save.stations[id])
	var levels: Array = Data.b["stations"][id]["levels"]
	if lv >= levels.size():
		return
	var next: Dictionary = levels[lv]
	if lv + 1 > Save.camp_level or (bool(next.get("needs_burrows", false)) and not Data.burrows_open()) or not Data.pay(_level_cost(next)):
		return
	Save.stations[id] = lv + 1
	Save.save_game()
	refresh(id)
	main.on_purchase()


func _card_target() -> Dictionary:
	if Save.ruined.has("target"):
		return _ruin_card("target", "Training Target", _anchor("target", 1.5))
	var rows := _wear_row("target")
	_add_section(rows, "Train", _stat_rows(["damage", "draw", "range"]))
	_add_section(rows, "Upgrade", [_station_upgrade_row("target")])
	return {"title": "Training Target", "sub": "Level %d · the cat practises while you stand here" % Save.stations["target"], "rows": rows, "anchor": _anchor("target", 1.5)}


## G3: the Bow Shop (station id "bench", the Bow Bench before G3): one tile per bow, in balance.json's order (Twig,
## Sunwood, Ember, Frost; since 22 Nov 2026 Thorn Volley and Foxfire are "hidden": no tile unless the save owns one, then
## it shows Owned / Equipped as below so it can still be used), each with one button:
##   the bow in the cat's paw   "Upgrade" (its level, mastery past 10 once the Burrows are open; never above the
##                              shop's cap, Data.bow_cap(): at the cap the button is off and the note says to upgrade
##                              the Bow Shop); badge "Equipped"
##   owned, not in the paw      "Equip" (free); off while a mission or raid wave is on, the note then "Between waves";
##                              badge "Owned"
##   not owned                  "Buy" (balance.json craft); off below the shop level it needs ("Needs Bow Shop level
##                              N", badge "Locked"), else badge "New". A bow bought between waves goes in the paw; one
##                              bought mid-wave waits on the shelf (equip it after the wave)
## The Foxfire Bow is left out until the Burrows open (unless the save owns it). Each bow keeps its own level. A tile
## shows res://assets/ui/bows/bow_<id>.png (row key "picture", hud.gd) when that picture exists, else the "bow" icon.
func _card_bench() -> Dictionary:
	if Save.ruined.has("bench"):
		return _ruin_card("bench", _name("bench"), _anchor("bench", 1.6))
	var rows: Array = _wear_row("bench")
	var bows: Array = []
	for bid in Data.b["bows"]:
		var t := _bow_tile(String(bid))
		if not t.is_empty():
			bows.append(t)
	_add_section(rows, "Bows", bows)
	_add_section(rows, "Upgrade", [_station_upgrade_row("bench")])
	return {"title": _name("bench"), "sub": "Level %d · buy, upgrade and equip bows" % Save.stations["bench"], "rows": rows,
		"anchor": _anchor("bench", 1.6)}


## The path of a bow's shop picture (G3: rendered from its model); the tile uses it only when the file exists.
static func bow_picture_path(bid: String) -> String:
	return "res://assets/ui/bows/bow_%s.png" % bid


## One bow's tile on the Bow Shop (see _card_bench); {} for a bow not shown: a hidden bow the save does not own (Thorn
## Volley and Foxfire, 22 Nov 2026), or one that waits for the Burrows.
func _bow_tile(bid: String) -> Dictionary:
	var bi := Data.bow_info(bid)
	var nm := String(bi["name"])
	var owned := Save.bows.has(bid)
	if not owned and Data.bow_hidden(bid):
		return {}                                           # kept out of the shop for now (owned ones still show)
	if not owned and bool(bi.get("needs_burrows", false)) and not Data.burrows_open():
		return {}                                           # a bow that waits for the Burrows
	var says := _bow_note(bid)
	var cap := Data.bow_cap()
	var t: Dictionary
	if owned:
		var lv := int(Save.bows[bid])
		var top := Data.bow_top(bid)
		var shown_cap := maxi(mini(cap, top), lv)
		var bar := [["Level", float(lv) / float(maxi(shown_cap, 1)), "%d/%d" % [lv, shown_cap]]]
		if bid == Save.bow:
			var curve: Dictionary = Data.b["bow_upgrade_curve"]
			if lv + 1 >= int(curve["late_from_level"]) and lv + 1 <= int(curve["late_to_level"]) and lv < cap and lv < top:
				var gain := (Data.bow_level_mult(bid, lv + 1) / Data.bow_level_mult(bid, lv) - 1.0) * 100.0
				says = "Next: +%s%% damage\n%s" % [_short_num(gain), says]
			var costs: Array = bi["cost"]
			if lv >= top:
				t = _tile("bow", nm, "At max level · " + says, {}, "", false, Callable(), "Equipped", [["Level", 1.0, "Max"]])
			elif lv >= cap:
				t = _tile("bow", nm, "Upgrade the %s for more" % _name("bench"), {}, "Upgrade", false, Callable(), "Equipped", bar)
			elif lv >= costs.size():
				var bc := Data.bow_cost(bid, lv)            # Phase E: bow mastery, past level 10
				t = _tile("bow", nm, "Mastery %d/%d%s" % [lv - costs.size() + 1, top - costs.size(), Data.mats_line(bc)], bc,
					"Upgrade", true, _upgrade_bow, "Equipped", bar)
			else:
				t = _tile("bow", nm, says, Data.bow_cost(bid, lv), "Upgrade", true, _upgrade_bow, "Equipped", bar)
		else:
			var mid := _locked()                            # a wave is on: bows are swapped between waves
			t = _tile("bow", nm, "Between waves" if mid else says, {}, "Equip", not mid, _equip.bind(bid), "Owned", bar)
	else:
		var need := int(bi["bench_level"])
		var ok := int(Save.stations["bench"]) >= need
		var cc := Data.craft_cost(bid)
		t = _tile("bow", nm, (says + Data.mats_line(cc)) if ok else "Needs %s level %d" % [_name("bench"), need], cc, "Buy", ok,
			_craft.bind(bid), "New" if ok else "Locked")
	var pic := bow_picture_path(bid)
	if ResourceLoader.exists(pic):
		t["picture"] = pic
	return t


## What a bow does, in plain words, from its balance.json numbers: "A normal bow", "Goes through the first enemy, +1.5 m
## range", "Fire arrows: the hit enemy burns for 3 s", "Ice arrows: slow, and the 3rd hit freezes", "3 arrows in a fan",
## "Goes through two enemies, +1 m range".
func _bow_note(bid: String) -> String:
	var bi := Data.bow_info(bid)
	var bits: Array = []
	var n := int(bi["arrows"])
	if n > 1:
		bits.append("%d arrows in a fan" % n)
	var p := int(bi["pierce"])
	if p == 1:
		bits.append("goes through the first enemy")
	elif p > 1:
		bits.append("goes through %s enemies" % _count_word(p))
	var fire := Data.bow_burn(bid)
	if not fire.is_empty():
		bits.append("fire arrows: the hit enemy burns for %s s" % _short_num(float(fire.get("seconds", 0.0))))
	var ice := Data.bow_frost(bid)
	if not ice.is_empty():
		bits.append("ice arrows: slow, and the %s hit freezes" % _ordinal(int(ice.get("hits_to_freeze", 3))))
	var rb := float(bi["range_bonus"])
	if rb > 0.0:
		bits.append("+%s m range" % _short_num(rb))
	var dm := Data.bow_draw_mult(bid)
	var cons: Array = []                                 # the bow's downsides, after a "·"
	if rb < 0.0:
		cons.append("%s m shorter range" % _short_num(-rb))
	if dm > 1.0:
		var pct := roundi((dm - 1.0) * 100.0)
		cons.append("draws %d%% slower" % pct if pct < 20 else "slowest draw")   # a big slowdown reads as "slowest draw"
	if bits.is_empty() and cons.is_empty():
		return "Fastest draw" if dm <= 1.0 else "A normal bow"
	var s := ", ".join(bits)
	if s != "":
		s = s.substr(0, 1).to_upper() + s.substr(1)
	if not cons.is_empty():
		s = (s + " · " if s != "" else "") + " · ".join(cons)
	return s


const _COUNT_WORDS := ["no", "one", "two", "three", "four", "five"]


## "two", "three" (a number as a word in a line; the figure itself past five).
func _count_word(n: int) -> String:
	return String(_COUNT_WORDS[n]) if n >= 0 and n < _COUNT_WORDS.size() else str(n)


## 1 -> "1st", 2 -> "2nd", 3 -> "3rd", 4 -> "4th", 11 -> "11th", 22 -> "22nd".
func _ordinal(n: int) -> String:
	var suf := "th"
	if n % 100 < 11 or n % 100 > 13:
		match n % 10:
			1: suf = "st"
			2: suf = "nd"
			3: suf = "rd"
	return "%d%s" % [n, suf]


## 1.5 -> "1.5", 1.0 -> "1", 3.0 -> "3".
func _short_num(x: float) -> String:
	return ("%.1f" % x).trim_suffix(".0")


## Levels up the bow in the cat's paw (any time, mid-wave too), up to the Bow Shop's cap.
func _upgrade_bow() -> void:
	var lv := int(Save.bows[Save.bow])
	if lv >= Data.bow_cap() or lv >= Data.bow_top(Save.bow) or not Data.pay(Data.bow_cost(Save.bow, lv)):
		return
	Save.bows[Save.bow] = lv + 1
	Save.save_game()
	Fx.flower_ring(main, main.world.station_pos("bench"), 1.0)
	main.on_purchase()


## Buys bow bid on the Bow Shop (its balance.json craft price: leaves and timber), once the shop is big enough.
## Between waves it goes straight into the cat's paw; bought while a wave is on it waits (Equip after the wave). A hidden
## bow (22 Nov 2026) is not sold.
func _craft(bid: String) -> void:
	if Save.bows.has(bid) or Data.bow_hidden(bid) or int(Save.stations["bench"]) < int(Data.bow_info(bid)["bench_level"]) \
			or (bool(Data.bow_info(bid).get("needs_burrows", false)) and not Data.burrows_open()) or not Data.pay(Data.craft_cost(bid)):
		return
	Save.bows[bid] = 1
	var swap := not _locked()
	if swap:
		Save.bow = bid
	Save.save_game()
	Fx.flower_ring(main, main.world.station_pos("bench"), 1.4)
	main.player.apply_bow()
	main.on_purchase()
	main.hud.banner("%s bought!" % Data.bow_info(bid)["name"], Color(1.0, 0.9, 0.45),
		"In the cat's paw now" if swap else "Equip it between waves")


## Puts an owned bow in the cat's paw (free), only between waves.
func _equip(bid: String) -> void:
	if not Save.bows.has(bid) or Save.bow == bid or _locked():
		return
	Save.bow = bid
	Save.save_game()
	main.player.apply_bow()
	Fx.sparkle(main, main.player.global_position + Vector3(0, 1.0, 0))
	main.on_purchase()


# ---------------------------------------------------------------- G4: the Saddlery (the mount's skills and attachments)
## G4: the Saddlery's card: two shelves of tiles, "Skills" (Stomp, Ram, Pounce, Bellow: balance.json mount_skills) and
## "Attachments" (Fire-spitter, Mossweave Saddle, Saddlebags: mount_attachments), in balance.json's order, then its own
## upgrade ("Upgrade"). Each tile has one button:
##   not learned yet     "Buy" (its level-1 price, leaves and timber); badge "New"
##   learned             "Upgrade" (the next level's price; levels 4-5 only once the Burrows are open); off at the Saddlery's
##                       level (the line "Upgrade the Saddlery for more") or while the next level needs the Burrows
##                       ("Level 4 opens after the Raid Missions"); badge "Level 2/5" and a level bar
##   at its top          no button; badge "Max"
## Its line says what it does at its level (level 1 before it is learned): _saddle_note. Learning and upgrading work
## any time (mid-wave too, like the bows' levels). Never real money. Every skill learned works (mount.gd).
## 22 Nov 2026 (the owner's rule): the mount wears ONE attachment at a time (Save.saddlery.worn), and only that one acts
## and shows. The Attachments tiles work like the Bow Shop's, one button each:
##   the worn one        "Upgrade" as above (or no button at its top); badge "Worn"
##   owned, not worn     "Wear" (free); off while a mission or raid wave is on, the line then "Between waves"; badge
##                       "Owned"
##   not owned           "Buy"; badge "New". Bought when nothing is worn, it is worn at once.
func _card_saddlery() -> Dictionary:
	var title := _name("saddlery")
	if Save.ruined.has("saddlery"):
		return _ruin_card("saddlery", title, _anchor("saddlery", 1.6))
	var rows: Array = _wear_row("saddlery")
	var skills: Array = []
	for id in Data.saddle_items("skills"):
		skills.append(_saddle_tile("skills", String(id)))
	var gear: Array = []
	for id in Data.saddle_items("attach"):
		gear.append(_saddle_tile("attach", String(id)))
	_add_section(rows, "Skills", skills)
	_add_section(rows, "Attachments", gear)
	_add_section(rows, "Upgrade", [_station_upgrade_row("saddlery")])
	return {"title": title, "sub": "Level %d · %s uses its skills and wears one attachment while you ride" % [Data.saddlery_level(), Data.mount_name()],
		"rows": rows, "anchor": _anchor("saddlery", 1.6)}


## One skill's or attachment's tile on the Saddlery (part "skills" or "attach"; see _card_saddlery).
func _saddle_tile(part: String, id: String) -> Dictionary:
	var info := Data.saddle_info(part, id)
	var nm := String(info.get("name", id))
	var icon := String(info.get("icon", "saddlery"))
	var lv := Data.saddle_level(part, id)
	var top := Data.saddle_top(part, id)
	var says := _saddle_note(part, id, maxi(lv, 1))
	var block := Data.saddle_block(part, id)
	if lv <= 0:
		var c := Data.saddle_price(part, id, 1)
		return _tile(icon, nm, says, c, "Buy", block == "", _saddle_buy.bind(part, id), "New")
	var badge := "Level %d/%d" % [lv, top]
	var bar := [["Level", float(lv) / float(maxi(top, 1)), "%d/%d" % [lv, top]]]
	if part == "attach":
		if Data.worn_attach() != id:                    # owned, not worn: Wear it (free, between waves)
			var mid := _locked()
			return _tile(icon, nm, "Between waves" if mid else says, {}, "Wear", not mid, _saddle_wear.bind(id), "Owned", bar)
		badge = "Worn"
	match block:
		"max":
			return _tile(icon, nm, says, {}, "", false, Callable(), "Worn" if part == "attach" else "Max", [["Level", 1.0, "Max"]])
		"cap":
			return _tile(icon, nm, "Upgrade the %s for more" % _name("saddlery"), {}, "Upgrade", false, Callable(), badge, bar)
		"burrows":
			return _tile(icon, nm, "Level %d opens after the Raid Missions" % (lv + 1), {}, "Upgrade", false, Callable(), badge, bar)
	var nc := Data.saddle_price(part, id, lv + 1)
	return _tile(icon, nm, says + Data.mats_line(nc), nc, "Upgrade", block == "", _saddle_buy.bind(part, id), badge, bar)


## What a skill or attachment does at level lv, in one short line, from its balance.json numbers ("Shockwave every 4 s:
## 28 damage", "Kills drop +10% leaves").
func _saddle_note(part: String, id: String, lv: int) -> String:
	var info := Data.saddle_info(part, id)
	var every := _short_num(float(info.get("every_s", 0.0)))
	match id:
		"stomp":
			return "Shockwave every %s s: %d damage" % [every, roundi(Data.skill_damage(id, lv))]
		"ram":
			return "Charges ahead every %s s: %d damage" % [every, roundi(Data.skill_damage(id, lv))]
		"pounce":
			return "Leaps on a group every %s s: %d damage, %s s stun" % [every, roundi(Data.skill_damage(id, lv)), _short_num(Data.skill_stun(id, lv))]
		"bellow":
			return "%d+ enemies near: %s s stun, +%d%% damage taken" % [int(info.get("min_foes", 4)), _short_num(Data.skill_stun(id, lv)),
				roundi(Data.skill_taken(id, lv) * 100.0)]
		"fire_spitter":
			return "Cat's firing pace: %s splash damage in %s m, +%s burn/s for %s s" % [_short_num(Data.fire_damage(lv)), _short_num(float(info["blast_m"])), _short_num(Data.fire_burn_per_s(lv)), _short_num(float(info["burn_s"]))]
		"saddle":
			return "When worn: %s has +%d%% health" % [Data.mount_name(), roundi(float(info.get("hp_per_level", 0.0)) * lv * 100.0)]
		"saddlebags":
			return "When worn: kills drop +%d%% leaves" % roundi(float(info.get("leaves_per_level", 0.0)) * lv * 100.0)
	return String(info.get("text", ""))


## Learns (level 1) or upgrades skill or attachment id at the Saddlery: built and standing, never past its level, the
## Burrows open for levels marked needs_burrows, and the price paid. 22 Nov 2026: an attachment is upgraded only
## while it is worn; one bought while nothing is worn is worn at once.
func _saddle_buy(part: String, id: String) -> void:
	var info := Data.saddle_info(part, id)
	if info.is_empty() or Data.saddle_block(part, id) != "":
		return
	var lv := Data.saddle_level(part, id)
	if part == "attach" and lv > 0 and Data.worn_attach() != id:
		return                                          # owned and not worn: its button is Wear
	if not Data.pay(Data.saddle_price(part, id, lv + 1)):
		return
	var shelf: Dictionary = Save.saddlery[part]
	shelf[id] = lv + 1
	if part == "attach" and Data.worn_attach() == "":
		Save.saddlery["worn"] = id
	Save.save_game()
	if part == "attach" and id == "saddle" and Data.worn_attach() == "saddle" and main.mount != null and main.mount.resting <= 0.0:
		main.mount.hp = main.mount.max_hp()            # the new saddle's health comes at once
	if part == "attach" and main.mount != null and main.mount.has_method("refresh_gear"):
		main.mount.refresh_gear()                       # 22 Nov 2026: its model on the mount, when the file exists
	Fx.flower_ring(main, main.world.station_pos("saddlery"), 1.4 if lv == 0 else 1.0)
	if main.mount != null:
		Fx.sparkle(main, main.mount.global_position + Vector3(0, 1.0, 0))
	main.on_purchase()
	if lv == 0:
		var nm := String(info.get("name", id))
		if part == "attach" and Data.worn_attach() != id:
			main.hud.banner("%s bought!" % nm, Color(1.0, 0.9, 0.55), "Wear it here to use it (between waves)")
		else:
			main.hud.banner(("%s learned!" if part == "skills" else "%s ready!") % nm, Color(1.0, 0.9, 0.55), _saddle_note(part, id, 1))


## 22 Nov 2026: puts on attachment id (owned, not the one worn), free, only between waves; the one worn before comes
## off. Its model swaps on the mount; the Mossweave Saddle's health comes or goes with it (never more than the new top).
func _saddle_wear(id: String) -> void:
	if Data.attach_level(id) < 1 or Data.worn_attach() == id or _locked() or Save.ruined.has("saddlery"):
		return
	var m = main.mount
	var before: int = m.max_hp() if m != null else 0
	Save.saddlery["worn"] = id
	Save.save_game()
	if m != null:
		if m.resting <= 0.0:
			m.hp = clampi(m.hp + maxi(0, m.max_hp() - before), 0, m.max_hp())
		if m.has_method("refresh_gear"):
			m.refresh_gear()
		Fx.sparkle(main, m.global_position + Vector3(0, 1.0, 0))
	main.on_purchase()


## G4: an old save brought over (Save.migrate_saddlery) hears once what became of its mount's moves and attachments.
func _tell_saddlery_moves() -> void:
	var bits: Array = []
	if Save.flag("g4_free_stomp") and not Save.flag("told_g4_stomp"):
		Save.set_flag("told_g4_stomp")
		bits.append("%s's Thump is now Stomp, a Saddlery skill: it keeps it at level %d." % [Data.mount_name(), maxi(1, Data.skill_level("stomp"))])
	if Save.flag("g4_old_attach") and not Save.flag("told_g4_attach"):
		Save.set_flag("told_g4_attach")
		var names: Array = []
		var old: Dictionary = Data.saddlery_cfg().get("old_attachments", {})
		for oid in old:
			var to: Array = old[oid]
			if not to.is_empty() and (Save.attach.get("owned", []) as Array).has(String(oid)):
				names.append(String(Data.saddle_info("attach", String(to[0])).get("name", to[0])))
		if names.size() == 1:
			bits.append("Your %s is a Saddlery attachment now: it works everywhere." % names[0])
		elif names.size() > 1:
			var worn := String(Data.saddle_info("attach", Data.worn_attach()).get("name", ""))
			bits.append("Your %s are Saddlery attachments now. %s wears one at a time%s; swap at the Saddlery." % [" and ".join(names),
				Data.mount_name(), (": the %s now" % worn) if worn != "" else ""])
	if bits.is_empty():
		return
	Save.save_game()
	main.hud.tip_after(" ".join(bits), rings.get("saddlery") if shown("saddlery") else null)


# ---------------------------------------------------------------- 23 Nov 2026: the Tailor's Nook (the cat's outfits)
## The Tailor's Nook's card: one tile per outfit (balance.json cat_skins, in its order: the original first), in the
## shop-tile style, one button each. Outfits are looks only: they change no number.
##   the one she wears      "Wearing" (no working button); badge "Wearing"
##   owned, not worn        "Wear" (free); off while a mission or raid wave is on, the line then "Between waves"; badge
##                          "Owned"
##   not owned              "Buy" and its price (balance.json price in its currency, today leaves); the line "Needs
##                          <price>" when she cannot pay it. A missing model or a currency the game cannot take yet
##                          leaves Buy off ("Coming later"). She puts it on at once between waves. A mid-wave purchase waits for Wear.
## A tile shows res://assets/ui/cat_skins/<id>.png (row key "picture") when that picture exists, else the outfit icon.
## One level: no upgrade shelf.
func _card_tailor() -> Dictionary:
	var title := _name("tailor")
	if Save.ruined.has("tailor"):
		return _ruin_card("tailor", title, _anchor("tailor", 2.0))
	var rows: Array = _wear_row("tailor")
	var tiles: Array = []
	for id in Data.cat_skin_ids():
		tiles.append(_skin_tile(String(id)))
	_add_section(rows, "Outfits", tiles)
	return {"title": title, "sub": "Outfits for the cat · looks only, no strength", "rows": rows, "anchor": _anchor("tailor", 2.0)}


## One outfit's tile on the Tailor's Nook (see _card_tailor).
func _skin_tile(id: String) -> Dictionary:
	var info := Data.cat_skin(id)
	var nm := Data.cat_skin_name(id)
	var says := String(info.get("short", ""))
	var t: Dictionary
	if Save.cat_skin == id:
		t = _tile("outfit", nm, says, {}, "Wearing", false, Callable(), "Wearing")
	elif Data.cat_skin_owned(id):
		var mid := _locked()                                 # a wave is on: outfits are changed between waves
		t = _tile("outfit", nm, "Between waves" if mid else says, {}, "Wear", not mid, _wear_skin.bind(id), "Owned")
	else:
		var cost := Data.cat_skin_cost(id)
		var buyable := Data.cat_skin_buyable(id)
		var note := says
		if not buyable:
			note = "Coming later"
		elif not Data.can_afford(cost):
			note = "Needs %s" % _price_words(cost)
		t = _tile("outfit", nm, note, cost, "Buy", buyable, _buy_skin.bind(id), "New")
	var pic := Data.cat_skin_picture(id)
	if ResourceLoader.exists(pic):
		t["picture"] = pic
	return t


## "3,000 leaves", "1,500 leaves and 40 timber": a price in words. gloom: shards read "Gloom shard(s)" (what Bramble
## pays) instead of the plain currency id.
func _price_words(cost: Dictionary, gloom := false) -> String:
	var bits: Array = []
	for k in cost:
		var n := int(cost[k])
		if n > 0:
			var word := Data.mat_name(String(k)) if String(k) in Data.MATS else String(k)
			if gloom and String(k) == "shards":
				word = "Gloom shard" if n == 1 else "Gloom shards"
			bits.append("%s %s" % [_thousands(n), word])
	if bits.size() <= 1:
		return "".join(bits)
	return ", ".join(bits.slice(0, bits.size() - 1)) + " and " + String(bits[bits.size() - 1])


## Buys outfit id at the Tailor's Nook (built and standing; its price in its currency). Between waves she puts it on at
## once (as a bow bought at the Bow Shop goes into her paw); bought while a wave is on, it waits for Wear.
func _buy_skin(id: String) -> void:
	if Data.cat_skin(id).is_empty() or Data.cat_skin_owned(id) or int(Save.stations.get("tailor", 0)) < 1 \
			or Save.ruined.has("tailor") or not Data.cat_skin_buyable(id) or not Data.pay(Data.cat_skin_cost(id)):
		return
	Save.cat_skins_owned.append(id)
	var swap := not _locked()
	if swap:
		Save.cat_skin = id
	Save.save_game()
	if swap:
		main.player.apply_skin()
		Fx.sparkle(main, main.player.global_position + Vector3(0, 1.0, 0))
	Fx.flower_ring(main, main.world.station_pos("tailor"), 1.4)
	main.on_purchase()
	main.hud.banner("%s bought!" % Data.cat_skin_name(id), Color(0.82, 0.68, 1.0), "She wears it now" if swap else "Wear it between waves")


## Puts on an owned outfit (free), only between waves; the cat's model swaps in place (player.apply_skin).
func _wear_skin(id: String) -> void:
	if not Data.cat_skin_owned(id) or Save.cat_skin == id or _locked() or Save.ruined.has("tailor"):
		return
	Save.cat_skin = id
	Save.save_game()
	main.player.apply_skin()
	Fx.sparkle(main, main.player.global_position + Vector3(0, 1.0, 0))
	main.on_purchase()


## The standing Well's only row is its upgrade.
func _card_well() -> Dictionary:
	if Save.ruined.has("well"):
		return _ruin_card("well", "Wishing Well", _anchor("well", 1.9))
	var lv := int(Save.stations["well"])
	return {"title": "Wishing Well", "sub": "Level %d · %s" % [lv, _well_line(lv)],
		"rows": [_station_upgrade_row("well")], "anchor": _anchor("well", 1.9)}


## The Well's mending rates at level lv.
func _well_line(lv: int) -> String:
	return "Mends to full · %s/s between waves, %s/s in waves" % [_pct(well_between(lv)), _pct(well_regen(lv))]


## 0.75 -> "75%", 0.005 -> "0.5%", 0.0025 -> "0.25%".
func _pct(x: float) -> String:
	var p := snappedf(x * 100.0, 0.01)
	return ("%d%%" % int(roundf(p))) if is_equal_approx(p, roundf(p)) else ("%s%%" % String.num(p, 2))


func _card_cottage() -> Dictionary:
	if Save.ruined.has("cottage"):
		return _ruin_card("cottage", "Mushroom Cottage", _anchor("cottage", 2.6))
	var lv := int(Save.stations["cottage"])
	var rows: Array = _wear_row("cottage")
	rows.append({"text": "%s · level %d" % [Data.pet_name(), lv], "note": "Flicks sparks: %d damage every %.1fs" % [int(Data.pick("pet", "damage_by_level", lv)), Data.pick("pet", "every_by_level", lv)],
		"cost": {}, "label": "", "enabled": false, "action": Callable()})
	# the Nest: every look fights exactly the same
	var nest := _look_tiles("pet", "pet", "Your pet now", "Same damage and speed, a different friend")
	nest.append(_skin_row("pet"))
	nest.append_array(_gloomlit_row("pet"))
	nest.append_array(_attach_rows("pet"))
	_add_section(rows, "The Nest", nest)
	_add_section(rows, "Upgrade", [_station_upgrade_row("cottage")])
	return {"title": "Mushroom Cottage", "sub": "Level %d · %s lives here" % [lv, String(Data.look("pet", Save.pet_look)["name"])], "rows": rows, "anchor": _anchor("cottage", 2.6)}


## The looks of a companion slot as tiles: the one in use ("Equipped", no button), the others free to Use (every look
## has the same numbers).
func _look_tiles(slot: String, icon: String, use_text: String, other_text: String) -> Array:
	var out: Array = []
	for lk in Data.b["looks"][slot]:
		var id := String(lk["id"])
		var use: bool = _look_id(slot) == id
		var txt := use_text if use else other_text
		if slot == "mount" and not use:
			txt = "Same speed and skills, a new look"         # G4: looks have no move of their own
		out.append(_tile(icon, String(lk["name"]), txt, {}, "" if use else "Use", not use, _use_look.bind(slot, id), "Equipped" if use else ""))
	return out


## Phase G2: the Market (the old Market Stall's card): riding Thistle at the top, then Bramble's shop in tiles (what he
## sells, what he buys), the Stable (mount looks, colours, attachments) and the Market's own upgrade.
func _card_stall() -> Dictionary:
	var title := _name("stall")
	if Save.ruined.has("stall"):
		return _ruin_card("stall", title, _anchor("stall", 2.4))
	var lv := int(Save.stations["stall"])
	var rows: Array = _wear_row("stall")
	var riding: bool = main.player.riding
	var mn := Data.mount_name()
	# G4: the mount has no move of its own: it carries the cat faster and takes the hits; it fights with the Saddlery's skills
	var learned := 0
	for sk in Data.saddle_items("skills"):
		if Data.skill_level(String(sk)) > 0:
			learned += 1
	var ride_note := "%s%% faster, takes the hits for you" % _short_num((Data.pick("mount", "speed_by_level", lv) - 1.0) * 100.0)
	if learned > 0:
		ride_note += " · %d skill%s" % [learned, "s" if learned > 1 else ""]
	rows.append({"text": ("Get off %s" if riding else "Ride %s") % mn, "note": "%s goes back to the %s" % [mn, title] if riding else ride_note,
		"cost": {}, "label": "Walk" if riding else "Ride", "enabled": main.mount != null, "action": main.toggle_ride})
	_add_section(rows, "Bramble sells", _market_sells())
	_add_section(rows, "Bramble buys", _market_buys())
	# the Stable: every look rides exactly the same, with the same Saddlery skills (G4: the saddle and the bags are
	# Saddlery attachments now; the Thunder Shoes stay here)
	var stable := _look_tiles("mount", "mount", "Your mount now", "")
	stable.append(_skin_row("mount"))
	stable.append_array(_gloomlit_row("mount"))
	stable.append_array(_attach_rows("mount"))
	_add_section(rows, "Stable", stable)
	_add_section(rows, "Upgrade", [_station_upgrade_row("stall")])
	return {"title": title, "sub": "Level %d · Bramble's trades, and %s" % [lv, mn], "rows": rows, "anchor": _anchor("stall", 2.4)}


## What Bramble sells: timber (balance.json trade.buy), then each market.sells entry (food goes to the pantry, up to its
## cap; an expedition material, if one is ever listed, to the materials. H1: he sells no amber).
func _market_sells() -> Array:
	var out: Array = []
	var tb: Dictionary = Data.b["trade"].get("buy", {"timber": 5, "leaves": 50})
	out.append(_quiet(_tile("timber", "%d timber" % int(tb.get("timber", 5)), "For building and growing · you have %d" % Save.timber,
		{"leaves": int(tb.get("leaves", 50))}, "Buy", true, _trade.bind(true))))
	var list: Array = Data.b.get("market", {}).get("sells", [])
	var cap := int(Data.b["cooking"].get("pantry_cap", 20))
	for i in list.size():
		var e: Dictionary = list[i]
		if not _market_open(e):
			continue
		var id := String(e["id"])
		var n := int(e.get("amount", 1))
		var mat := Data.MATS.has(id)
		var title := "%d %s" % [n, Data.mat_name(id) if mat else Data.item_name(id, n)]
		var room := mat or int(Save.pantry.get(id, 0)) + n <= cap
		var text := ""
		if mat:
			text = "An expedition material · you have %d" % Data.have(id)
		elif room:
			text = "Food for cooking and dungeon healing · %d/%d owned" % [int(Save.pantry.get(id, 0)), cap]
		else:
			text = "Pantry full · %d/%d owned" % [int(Save.pantry.get(id, 0)), cap]
		out.append(_quiet(_tile(id, title, text, {"leaves": int(e.get("leaves", 0))}, "Buy", room, _market_buy.bind(i))))
	return out


## What Bramble buys: timber (trade.sell), Gloom shards once there are enough (as before), and each market.buys entry
## (H1: amber, once every mission is won), for what the entry pays (_market_pay: leaves, and shards).
func _market_buys() -> Array:
	var out: Array = []
	var ts: Dictionary = Data.b["trade"].get("sell", {"timber": 5, "leaves": 30})
	out.append(_quiet(_tile("timber", "Sell %d timber" % int(ts.get("timber", 5)), "Bramble pays %d leaves" % int(ts.get("leaves", 30)),
		{"timber": int(ts.get("timber", 5))}, "Sell", true, _trade.bind(false))))
	var st: Dictionary = Data.gr()["shard_trade"]
	if Save.shards >= int(st["shards"]):
		out.append(_tile("shard", "Sell %d Gloom shards" % int(st["shards"]), "Bramble pays %d leaves" % int(st["leaves"]),
			{"shards": int(st["shards"])}, "Sell", true, main.raids.trade_shards))
	var list: Array = Data.b.get("market", {}).get("buys", [])
	for i in list.size():
		var e: Dictionary = list[i]
		if not _market_open(e):
			continue
		var id := String(e["id"])
		var n := int(e.get("amount", 1))
		var nm := Data.mat_name(id) if Data.MATS.has(id) else Data.item_name(id, n)
		out.append(_quiet(_tile(id, "Sell %d %s" % [n, nm], "Bramble pays %s · you have %d" % [_price_words(_market_pay(e), true), _stock(id)],
			{id: n} if Data.CURRENCIES.has(id) else {}, "Sell", _stock(id) >= n, _market_sell.bind(i))))
	return out


## H1: what Bramble pays for a market.buys entry: every currency the entry names (Data.CURRENCIES, above 0), e.g.
## {"leaves": 1000, "shards": 1} for amber.
func _market_pay(e: Dictionary) -> Dictionary:
	var pay := {}
	for k in Data.CURRENCIES:
		if int(e.get(k, 0)) > 0:
			pay[k] = int(e[k])
	return pay


## An everyday trade: always there, so it never lights the Market's "!" (the shard trade still does, as before).
func _quiet(tile: Dictionary) -> Dictionary:
	tile["quiet"] = true
	return tile


## A market entry is on offer now (after_missions: only once every mission is won).
func _market_open(e: Dictionary) -> bool:
	return not bool(e.get("after_missions", false)) or Data.raids_open()


## How many of a market item the player has: a currency or material (Data.have), else the pantry.
func _stock(id: String) -> int:
	return Data.have(id) if Data.CURRENCIES.has(id) else int(Save.pantry.get(id, 0))


## Buys market.sells[i] from Bramble: the leaves are paid, the item goes to the pantry or the materials.
func _market_buy(i: int) -> void:
	var list: Array = Data.b.get("market", {}).get("sells", [])
	if i < 0 or i >= list.size() or Save.ruined.has("stall") or int(Save.stations.get("stall", 0)) <= 0:
		return
	var e: Dictionary = list[i]
	var id := String(e["id"])
	var n := int(e.get("amount", 1))
	if not _market_open(e) or n <= 0:
		return
	var mat := Data.MATS.has(id)
	if not mat and int(Save.pantry.get(id, 0)) + n > int(Data.b["cooking"].get("pantry_cap", 20)):
		return
	if not Data.pay({"leaves": int(e.get("leaves", 0))}):
		return
	if mat:
		Data.give(id, n)
	else:
		Data.add_items({id: n})
	Save.save_game()
	Fx.sparkle(main, main.world.station_pos("stall") + Vector3(0, 1.2, 0))
	main.on_purchase()
	if mat:
		main.hud.toast("+%d %s · now %d · leaves %d" % [n, Data.mat_name(id), Data.have(id), Save.leaves])
	else:
		main.hud.toast("%s · leaves %d" % [Data.food_receipt({id: n}), Save.leaves])


## Sells market.buys[i] to Bramble: the item is taken, he pays what the entry names (H1: leaves, and shards).
func _market_sell(i: int) -> void:
	var list: Array = Data.b.get("market", {}).get("buys", [])
	if i < 0 or i >= list.size() or Save.ruined.has("stall") or int(Save.stations.get("stall", 0)) <= 0:
		return
	var e: Dictionary = list[i]
	var id := String(e["id"])
	var n := int(e.get("amount", 1))
	if not _market_open(e) or n <= 0 or _stock(id) < n:
		return
	if Data.CURRENCIES.has(id):
		if not Data.pay({id: n}):
			return
	else:
		Data.take_items({id: n})
	var pay := _market_pay(e)
	for k in pay:
		Data.give(String(k), int(pay[k]))
	Save.save_game()
	Fx.sparkle(main, main.world.station_pos("stall") + Vector3(0, 1.2, 0))
	main.on_purchase()
	var now: Array = []
	for k in pay:
		now.append("%s %d" % [k, Data.have(String(k))])
	main.hud.toast("Sold %d %s · now %d · %s" % [n, Data.mat_name(id) if Data.MATS.has(id) else Data.item_name(id, n), _stock(id), " · ".join(now)])


## Phase E: attachments for the mount or the pet (balance.json attachments): Burrows-only help, bought with the price
## balance.json names (leaves today), one worn at a time. Shown once the Burrows are open. Card-only for now (no model on the companion).
func _attach_rows(slot: String) -> Array:
	var rows: Array = []
	if not Data.burrows_open():
		return rows
	var items: Dictionary = Data.b.get("attachments", {}).get("items", {})
	var owned: Array = Save.attach.get("owned", [])
	for id in items:
		var it: Dictionary = items[id]
		if String(it["slot"]) != slot:
			continue
		var worn: bool = String(Save.attach.get(slot, "")) == id
		if worn:
			rows.append(_tile(slot, String(it["name"]), String(it["note"]), {}, "Take off", true, _wear.bind(slot, ""), "Equipped"))
		elif owned.has(id):
			rows.append(_tile(slot, String(it["name"]), String(it["note"]), {}, "Wear", true, _wear.bind(slot, String(id)), "Owned"))
		else:
			var c: Dictionary = it["cost"]
			rows.append(_tile(slot, String(it["name"]), String(it["note"]) + Data.mats_line(c), c, "Buy", true, _buy_attach.bind(String(id)), "New"))
	return rows


func _buy_attach(id: String) -> void:
	var it: Dictionary = Data.b["attachments"]["items"].get(id, {})
	if it.is_empty() or (Save.attach["owned"] as Array).has(id) or not Data.pay(it["cost"]):
		return
	(Save.attach["owned"] as Array).append(id)
	Save.attach[String(it["slot"])] = id                   # worn at once
	Save.save_game()
	var who = _companion(String(it["slot"]))
	if who != null:
		Fx.sparkle(main, who.global_position + Vector3(0, 1.0, 0))
	main.hud.banner(String(it["name"]), Color(1.0, 0.9, 0.55), String(it["note"]))
	main.on_purchase()


func _wear(slot: String, id: String) -> void:
	if id != "" and not (Save.attach["owned"] as Array).has(id):
		return
	Save.attach[slot] = id
	Save.save_game()
	main.on_purchase()


## The three companion slots (mount, pet, guardian): which look and skin fill each, and who wears them.
func _look_id(slot: String) -> String:
	match slot:
		"mount": return Save.mount_look
		"guardian": return Save.guardian_look
	return Save.pet_look


func _skin_id(slot: String) -> String:
	match slot:
		"mount": return Save.mount_skin
		"guardian": return Save.guardian_skin
	return Save.pet_skin


func _set_skin_id(slot: String, id: String) -> void:
	match slot:
		"mount": Save.mount_skin = id
		"guardian": Save.guardian_skin = id
		_: Save.pet_skin = id


func _set_look_id(slot: String, id: String) -> void:
	match slot:
		"mount": Save.mount_look = id
		"guardian": Save.guardian_look = id
		_: Save.pet_look = id


func _companion(slot: String):
	match slot:
		"mount": return main.mount
		"guardian": return main.guardian
	return main.pet


## The skins of the look in a slot that can be worn now (one with "needs_flag" waits until that flag is set; one priced
## in Gloom shards, Gloomlit, until it is unlocked).
func _skins(slot: String) -> Array:
	var out: Array = []
	for s in Data.look(slot, _look_id(slot)).get("skins", []):
		if String(s.get("needs_flag", "")) != "" and not Save.flag(String(s["needs_flag"])):
			continue
		if int(s.get("shards", 0)) > 0 and not Save.unlocks.has(_skin_unlock(slot, String(s["id"]))):
			continue
		out.append(s)
	return out


func _skin_unlock(slot: String, skin_id: String) -> String:
	return "skin:%s:%s:%s" % [slot, _look_id(slot), skin_id]


## Gloomlit colours for the look in a slot: earned with Gloom shards, never sold (shown until it is unlocked).
func _gloomlit_row(slot: String) -> Array:
	for s in Data.look(slot, _look_id(slot)).get("skins", []):
		if int(s.get("shards", 0)) > 0 and not Save.unlocks.has(_skin_unlock(slot, String(s["id"]))):
			return [_tile("shard", "%s colours" % String(s["name"]), "Earned with Gloom shards, never sold", {"shards": int(s["shards"])}, "Unlock",
				true, _unlock_skin.bind(slot, String(s["id"])), "New")]
	return []


func _unlock_skin(slot: String, skin_id: String) -> void:
	var sk := Data.skin(slot, _look_id(slot), skin_id)
	if String(sk.get("id", "")) != skin_id or Save.unlocks.has(_skin_unlock(slot, skin_id)) or not Data.pay({"shards": int(sk.get("shards", 0))}):
		return
	Save.unlocks.append(_skin_unlock(slot, skin_id))
	_set_skin_id(slot, skin_id)
	var who = _companion(slot)
	if who != null:
		who.set_look()
		Fx.sparkle(main, who.global_position + Vector3(0, 1.0, 0))
	Save.save_game()
	main.hud.banner("%s colours!" % String(sk["name"]), Color(0.8, 0.6, 1.0), "Earned with Gloom shards")
	main.on_purchase()


## The skin row: the colours of the look in use; "Next" goes round them (all free while testing, sold later).
func _skin_row(slot: String) -> Dictionary:
	var skins := _skins(slot)
	var cur := Data.skin(slot, _look_id(slot), _skin_id(slot))
	var names: Array = skins.map(func(s): return String(s["name"]))
	return {"text": "Colours: %s" % String(cur.get("name", "Natural")), "note": " · ".join(names),
		"cost": {}, "label": "Next", "enabled": skins.size() > 1, "action": _next_skin.bind(slot)}


func _next_skin(slot: String) -> void:
	var skins := _skins(slot)
	if skins.size() < 2:
		return
	var cur := _skin_id(slot)
	var i := 0
	for k in skins.size():
		if String(skins[k]["id"]) == cur:
			i = k
	_set_skin_id(slot, String(skins[(i + 1) % skins.size()]["id"]))
	var who = _companion(slot)
	if who != null:
		who.set_look()
	Save.save_game()
	main.on_purchase()


func _use_look(slot: String, id: String) -> void:
	_set_look_id(slot, id)
	var who = _companion(slot)
	if who != null:
		who.set_look()
	Save.save_game()
	main.hud.banner(String(Data.look(slot, id)["name"]), Color(1.0, 0.9, 0.55), "Same power, a new look")
	main.on_purchase()


## Bramble's timber trade (balance.json trade): buying 5 for 50 leaves, or selling 5 for 30.
func _trade(buying: bool) -> void:
	if Save.ruined.has("stall"):
		return
	var timber_before := Save.timber
	if buying:
		var tb: Dictionary = Data.b["trade"].get("buy", {"timber": 5, "leaves": 50})
		if not Data.pay({"leaves": int(tb.get("leaves", 50))}):
			return
		Save.timber += int(tb.get("timber", 5))
	else:
		var ts: Dictionary = Data.b["trade"].get("sell", {"timber": 5, "leaves": 30})
		if not Data.pay({"timber": int(ts.get("timber", 5))}):
			return
		Save.add_leaves(int(ts.get("leaves", 30)))
	Save.save_game()
	Fx.sparkle(main, main.world.station_pos("stall") + Vector3(0, 1.2, 0))
	main.on_purchase()
	main.hud.toast("%+d timber · now %d · leaves %d" % [Save.timber - timber_before, Save.timber, Save.leaves])


func _card_sign() -> Dictionary:
	var f = main.fight
	var anchor: Vector3 = main.world.station_pos("sign") + Vector3(0, 2.0, 0)
	if f.active and f.mode == "raid":
		return _sign_navigation(main.raids.card_raid(anchor), "raids", true)
	if f.active and f.in_wave:
		return _sign_navigation({"title": f.title(), "sub": "Raid mission · wave %d of %d is on. Protect the camp!" % [f.wave, f.waves()], "rows": [], "anchor": anchor}, "missions", true)
	if f.active:
		return _sign_navigation({"title": f.title(), "sub": f.status_text(), "rows": [
			{"text": "Wave %d of %d" % [f.wave + 1, f.waves()], "note": "Saved · rest, shop and repair for as long as you need", "cost": {}, "label": "Start wave", "enabled": true, "action": f.next_phase_now}],
			"anchor": anchor}, "missions", true)
	var selected := sign_tab if sign_tab != "" else ("raids" if Data.raids_open() else "missions")
	if selected == "raids" and Data.raids_open():
		var watch: Dictionary = main.raids.card_watch(anchor)
		watch["title"] = "Random Raids"
		return _sign_navigation(watch, "raids")
	return _sign_navigation(_mission_catalog(anchor), "missions")


func _sign_navigation(spec: Dictionary, selected: String, busy := false) -> Dictionary:
	spec["view_id"] = "signpost_%s_%s" % [selected, ("wave" if main.fight.in_wave else "ready") if busy else "catalog"]
	spec["spacious"] = true
	spec["tabs"] = [
		{"text": "Raid Missions", "selected": selected == "missions", "enabled": not busy, "action": _set_sign_tab.bind("missions")},
		{"text": "Random Raids", "selected": selected == "raids", "enabled": not busy and Data.raids_open(), "action": _set_sign_tab.bind("raids")}
	]
	return spec


func _set_sign_tab(tab: String) -> void:
	if main.fight.active or (tab == "raids" and not Data.raids_open()) or tab not in ["missions", "raids"]:
		return
	sign_tab = tab
	if main.hud._card_scroll != null:
		main.hud._card_scroll.scroll_vertical = 0
	main.hud.refresh_card()


func _mission_catalog(anchor: Vector3) -> Dictionary:
	var rows: Array = []
	var blocked := ""
	if Save.fire_ruined:
		blocked = "Rebuild the campfire first"
	elif bool(Save.raids.get("pending", false)):
		blocked = "A random raid is waiting · meet it first"
	if blocked != "":
		rows.append({"text": blocked, "note": "Your completed raid missions remain saved", "cost": {}, "label": "", "enabled": false, "action": Callable()})
	if not Save.mission_run.is_empty():
		rows.append({"kind": "section", "text": "In progress"})
		rows.append_array(_run_rows(blocked))
	var todo: Array = []
	var done: Array = []
	for i in range(Data.mission_count() - 1, -1, -1):
		var won := Save.missions_done.has(String(Data.mission(i)["id"]))
		var entry := _mission_entry(i, won, blocked)
		if won:
			done.append(entry)
		else:
			todo.append(entry)
	if not todo.is_empty():
		rows.append({"kind": "section", "text": "To finish · %d" % todo.size()})
		rows.append_array(todo)
	if not done.is_empty():
		rows.append({"kind": "section", "text": "Completed · %d" % done.size()})
		rows.append_array(done)
	var sub := "%d / %d finished" % [done.size(), Data.mission_count()]
	if not Data.raids_open():
		sub += " · Random Raids unlock at %d" % Data.mission_count()
	return {"title": "The Signpost", "sub": sub, "rows": rows, "anchor": anchor}


func _mission_entry(i: int, won: bool, blocked: String) -> Dictionary:
	var m := Data.mission(i)
	var label := "Replay" if won else "Start"
	var note := "Finished · %d waves" % int(m["waves"]) if won else "%d waves" % int(m["waves"])
	var enabled := blocked == "" and Data.mission_unlocked(i)
	if blocked != "":
		note = blocked
	elif Save.mission_run.has("mission"):
		enabled = false
		label = "Current" if int(Save.mission_run["mission"]) == i else label
		note = "Use Resume above" if int(Save.mission_run["mission"]) == i else "Resume or give up the current raid mission first"
	elif not Data.mission_unlocked(i):
		label = "Locked"
		note = "Finish #%d first · %d waves" % [i, int(m["waves"])] if i > Data.next_mission() else "Needs %s at level %d" % [Data.camp_name(), Data.mission_needs_home(i)]
	return {"kind": "mission", "mission_index": i, "mission_name": String(m["name"]), "completed": won, "text": "Raid Mission %d · %s" % [i + 1, m["name"]],
		"note": note, "cost": {}, "label": label, "enabled": enabled, "action": main.start_stage.bind(i)}


## The next mission while it needs a bigger Hearthtree (Phase F: missions 3, 7, 11 and 14 start an act): "Needs the
## Hearthtree at level 3", a button to its card, and what is still missing on its goal list (only the next level's
## list counts).
func _locked_rows(nxt: int) -> Array:
	var m := Data.mission(nxt)
	var need := Data.mission_needs_home(nxt)
	var home = goal_ring("home")
	var rows: Array = []
	rows.append({"text": "%d. %s" % [nxt + 1, m["name"]], "note": "Needs %s at level %d (now %d) · grow it there" % [Data.camp_name(), need, Save.camp_level],
		"cost": {}, "label": "Go" if home != null else "", "enabled": home != null, "action": _goal_go.bind({"station": "home"})})
	var lv := Save.camp_level + 1
	var missing: Array = []
	for g in Data.home_goals(lv):
		if not bool(g["done"]):
			missing.append(String(g["progress"]))
	if not missing.is_empty():
		rows.append({"text": "Goals left for %s level %d" % [Data.camp_name(true).trim_prefix("The "), lv], "note": " · ".join(missing), "cost": {}, "label": "", "enabled": false, "action": Callable()})
	elif Data.home_goals_met(lv):
		var price := Data.home_price(lv)
		var bits: Array = []
		for k in Data.CURRENCIES:
			if int(price.get(k, 0)) > 0:
				bits.append("%s %s" % [_thousands(int(price[k])), "leaves" if k == "leaves" else (Data.mat_name(k) if Data.MATS.has(k) else k)])
		rows.append({"text": "Every goal is met", "note": "Grow %s for %s" % [Data.camp_name(), ", ".join(bits)], "cost": {}, "label": "", "enabled": false, "action": Callable()})
	return rows


## A mission under way, saved at a chapter break: go on from there, or give it up ([] when there is none). `blocked`:
## why it cannot start now (a raid at the gate).
func _run_rows(blocked := "") -> Array:
	var rows: Array = []
	var run: Dictionary = Save.mission_run
	if not (run.has("mission") and int(run["mission"]) >= 0 and int(run["mission"]) < Data.mission_count()):
		return rows
	var mi := int(run["mission"])
	var m0 := Data.mission(mi)
	var c0 := int(run.get("chapter", 0))
	var per := int(Data.b["mission"]["chapter_waves"])
	var next_wave := clampi(int(run.get("wave_done", c0 * per)) + 1, 1, int(m0["waves"]))
	rows.append({"text": "Resume Raid Mission %d · %s" % [mi + 1, m0["name"]], "note": blocked if blocked != "" else "Resume at wave %d of %d · cleared waves stay cleared" % [next_wave, int(m0["waves"])],
		"cost": {}, "label": "Start wave", "enabled": blocked == "", "action": main.start_stage.bind(mi)})
	rows.append({"text": "Give up this raid mission", "note": "Next time it starts from wave 1 · what you earned stays",
		"cost": {}, "label": "Give up", "enabled": true, "action": _give_up_run})
	return rows


func _mission_enemies(i: int) -> String:
	var seen: Array = []
	var m := Data.mission(i)
	var pairs: Array = []
	for ch in m["chapters"]:
		pairs += ch["pool"]
	pairs += m["elite"] + m["boss"]
	for pair in pairs:
		var nm := String(Data.enemy(String(pair[0]))["name"])
		if not seen.has(nm):
			seen.append(nm)
	return ", ".join(seen)


func _give_up_run() -> void:
	main.fight.give_up_run()
	main.hud.toast("Raid mission given up: it starts from wave 1 next time")
	main.hud.refresh_card()
