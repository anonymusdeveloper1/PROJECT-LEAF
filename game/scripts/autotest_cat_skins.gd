extends Node
## 23 Nov 2026: the cat's outfits and the Tailor's Nook (`-- --autotest --fresh --tailor`), run from autotest.gd. Each
## check logs "EXPECT PASS <what>" or "EXPECT FAIL <what>" through autotest.gd's _expect. Light on purpose: every
## number comes from balance.json; a wave being on is faked by hand (fight.active, in_wave and on_break).
##   (a) the building: Locked below Hearthtree 3 ("Needs the Hearthtree at level 3"), then Build pays its price; its
##       model (the owner's, or the stand-in), its ring and badge, its health; ruined and repaired like the others
##   (b) its card: one tile per outfit, in order, with the right labels (Wearing, Buy with the price, "Needs <price>")
##   (c) buying takes the leaves (and puts it on between waves); without enough it is refused
##   (d) wearing swaps Save.cat_skin and the hero model; with no outfit file she keeps the original, with no error;
##       an outfit "file" (the other hero model, CatRanger2 or CatRanger, standing in) is swapped in place, and back
##   (e) Wear is off in a wave ("Between waves")
##   (f) after a swap the bow (the equipped bow's model in SK_CatBow), the nocked arrow (bone `arrow`), shooting and
##       riding (and a swap while riding) still work
##   (g) an old save without the outfit keys loads with the original look; a worn outfit the game no longer sells
##       falls back to the original
## (h) the real outfit files: each swaps the hero to its file; bow, nocked arrow and cloth work; close-ups standing, running, shooting
## Screenshots in --shots: tailor_nook.png (the building in the camp), tailor_card.png, tailor_swapped.png, skin_<id>_stand/run1/run2/shoot.png.

var t                     # autotest.gd (its helpers: _wait, _expect, _until, _log, _shot)
var main

const ArrowScript := preload("res://scripts/arrow.gd")
const BASE := Vector3(-1.5, 0, 12.0)                # open ground south of the camp
const IDS := ["original", "dusk_ranger", "nightfall_ranger"]
const CLOAK_BONES := ["cloak.L.1", "cloak.L.2", "cloak.R.1", "cloak.R.2"]


func run() -> bool:
	main.player.invincible = true
	_start_fresh(2)
	await t._wait(0.3)
	await _building()
	_card()
	_buy()
	await _card_shot()
	await _wear()
	_wave()
	await _after_swap()
	await _real_looks()
	_old_save()
	_fight(false)
	main.set_riding(false, false)
	main.hud.hide_card()
	_clear()
	Save.cat_skin = "original"
	Save.cat_skins_owned = ["original"]
	main.player.apply_skin()
	t._log("tailor done", {"model": main.player.model_path(), "swaps": main.player.skin_swaps})
	return true


func _x(what: String, ok: bool, extra := {}) -> bool:
	return t._expect(what, ok, extra)


func _st():
	return main.stations


## A camp with 8 missions won at Hearthtree level `home`: the Bow Shop and the Market built, no Nook, only the original
## outfit, no leaves.
func _start_fresh(home: int) -> void:
	Save.missions_done = []
	for i in 8:
		Save.missions_done.append(String(Data.mission(i)["id"]))
	Save.mission_run = {}
	Save.camp_level = home
	for k in Save.stations:
		Save.stations[k] = 0
	Save.stations["bench"] = 1
	Save.stations["stall"] = 1
	Save.ruined = []
	Save.wear = {}
	Save.fire_ruined = false
	Save.leaves = 0
	Save.timber = 0
	Save.cat_skin = "original"
	Save.cat_skins_owned = ["original"]
	for k in ["shop_open", "shop_target", "shop_bench", "home", "first_stage_done"]:
		Save.set_flag(k)
	_st().refresh()
	main.refresh_companions()


func _item(card: Dictionary, title: String) -> Dictionary:
	for r in card["rows"]:
		if String(r.get("kind", "")) == "item" and String(r.get("title", "")) == title:
			return r
	return {}


func _items(card: Dictionary) -> Array:
	return (card["rows"] as Array).filter(func(r): return String(r.get("kind", "")) == "item")


func _sections(card: Dictionary) -> Array:
	var out: Array = []
	for r in card["rows"]:
		if String(r.get("kind", "")) == "section":
			out.append(String(r["text"]))
	return out


func _tile(id: String) -> Dictionary:
	return _item(_st()._card_tailor(), Data.cat_skin_name(id))


func _fight(on: bool) -> void:
	var f = main.fight
	f.active = on
	f.in_wave = on
	f.on_break = on


func _foe(at: Vector3) -> Node3D:
	var e = main.fight.spawn("thornling", at, 0)
	e.hp = 1e6
	e.max_hp = 1e6
	e.set_physics_process(false)
	return e


func _clear() -> void:
	for e in get_tree().get_nodes_in_group("foes"):
		e.dead = true
		e.remove_from_group("foes")
		e.remove_from_group("enemies")
		e.queue_free()
	for a in main.get_children().filter(func(n): return n.get_script() == ArrowScript):
		a.queue_free()


# ---------------------------------------------------------------- (a) the building
func _building() -> void:
	var st = _st()
	var name := String(Data.b["stations"]["tailor"]["name"])
	var nh := int(Data.b["stations"]["tailor"].get("needs_home", 1))
	var build: Dictionary = Data.b["stations"]["tailor"]["build"]
	var need_txt := "Needs %s at level %d" % [Data.camp_name(), nh]
	var tl := _item(st._card_shop(), name)
	_x("at Hearthtree 2 the Hearthtree shows a Locked %s tile ('%s')" % [name, need_txt], nh == 3 and String(tl.get("badge", "")) == "Locked"
		and String(tl.get("text", "")) == need_txt and not bool(tl.get("enabled", true)), {"tile": tl.get("text", ""), "badge": tl.get("badge", "")})
	Save.leaves = 100000
	Save.timber = 1000
	st._build_station("tailor")
	_x("below Hearthtree 3 it cannot be built", int(Save.stations["tailor"]) == 0 and Save.leaves == 100000)
	Save.camp_level = nh
	Save.leaves = int(build["leaves"]) + 123
	Save.timber = int(build["timber"]) + 7
	tl = _item(st._card_shop(), name)
	_x("at Hearthtree 3 the tile is a Build button with its price (%d leaves, %d timber)" % [int(build["leaves"]), int(build["timber"])],
		String(tl.get("label", "")) == "Build" and String(tl.get("badge", "")) == "New" and bool(tl.get("enabled", false))
		and int((tl.get("cost", {}) as Dictionary).get("leaves", 0)) == int(build["leaves"]) and int((tl.get("cost", {}) as Dictionary).get("timber", 0)) == int(build["timber"]),
		{"badge": tl.get("badge", ""), "label": tl.get("label", ""), "cost": tl.get("cost", {})})
	st._build_station("tailor")
	_x("Build pays exactly its price and the Nook is level 1", int(Save.stations["tailor"]) == 1 and Save.leaves == 123 and Save.timber == 7,
		{"leaves": Save.leaves, "timber": Save.timber})
	var node: Node3D = st.nodes.get("tailor")
	var own := Props.has("tailors_nook")
	var want := "tailors_nook" if own else String(Data.b["stations"]["tailor"]["stand_in"]["model"])
	_x("its model stands at its spot: %s" % ("the owner's tailors_nook" if own else "the stand-in %s, tinted" % want), node != null
		and String(node.get_meta("model", "")) == want and node.global_position.distance_to(main.world.station_pos("tailor")) < 0.01,
		{"model": node.get_meta("model", "") if node else "", "at": node.global_position if node else Vector3.ZERO})
	var ring = st.rings.get("tailor")
	_x("its marker shows, with the needle badge, on the camera's side", ring != null and ring.visible and ring.icon == "needle"
		and ring.global_position.z > main.world.station_pos("tailor").z, {"icon": ring.icon if ring else ""})
	var hp_want: float = Data.building_hp("tailor", 1)
	st.reset_hp()
	_x("it has building health (%d at level 1)" % int(hp_want), hp_want > 0.0 and is_equal_approx(float(st.hp.get("tailor", 0.0)), hp_want)
		and st.building_targets().any(func(b): return String(b[0]) == "tailor"), {"hp": st.hp.get("tailor", 0.0)})
	# the building in the camp (the cat a little south-west of its ring)
	main.player.global_position = st.rings["tailor"].global_position + Vector3(-1.6, 0, 1.4)
	main.snap_camera()
	await t._wait(1.2)
	await t._shot("tailor_nook")
	# ruined and repaired like the others
	st.hurt_building("tailor", hp_want + 1.0)
	var rc: Dictionary = st._card_tailor()
	_x("knocked down it is a ruin: its card shows only In ruins and Repair", Save.ruined.has("tailor") and String((rc["rows"] as Array)[0].get("text", "")) == "In ruins"
		and _item(rc, "Repair").get("label", "") == "Repair", {"rows": (rc["rows"] as Array).size()})
	var cost: Dictionary = st.repair_cost("tailor")
	Save.leaves = int(cost.get("leaves", 0)) + 11
	Save.timber = int(cost.get("timber", 0)) + 2
	st._repair("tailor")
	_x("Repair pays its price and it stands again", not Save.ruined.has("tailor") and Save.leaves == 11 and Save.timber == 2, {"cost": cost})
	st.hp.clear()


# ---------------------------------------------------------------- (b) the card
func _card() -> void:
	var card: Dictionary = _st()._card_tailor()
	var titles: Array = _items(card).map(func(r): return String(r["title"]))
	var want: Array = IDS.map(func(id): return Data.cat_skin_name(id))
	_x("the card: title Tailor's Nook, one Outfits shelf, three tiles in order: %s" % ", ".join(want), String(card["title"]) == "Tailor's Nook"
		and _sections(card) == ["Outfits"] and titles == want and want == ["Original Ranger", "Dusk Ranger", "Ember Ranger"],
		{"title": card["title"], "sections": _sections(card), "titles": titles})
	var o := _tile("original")
	_x("the original (worn): Wearing, no working button", String(o.get("label", "")) == "Wearing" and String(o.get("badge", "")) == "Wearing"
		and not bool(o.get("enabled", true)), {"label": o.get("label", ""), "badge": o.get("badge", "")})
	var ok := true
	var seen := {}
	for id in ["dusk_ranger", "nightfall_ranger"]:
		var r := _tile(id)
		var price := int(Data.cat_skin(id)["price"])
		var words := "Needs %s leaves" % _thousands(price)
		seen[id] = [r.get("label", ""), r.get("text", ""), r.get("cost", {}), r.get("enabled", false)]
		ok = (ok and String(r.get("label", "")) == "Buy" and int((r.get("cost", {}) as Dictionary).get("leaves", 0)) == price
			and String(r.get("text", "")) == words and not bool(r.get("enabled", true)) and String(Data.cat_skin(id)["currency"]) == "leaves")
	_x("with no leaves: Buy with the price in leaves (3,000 and 6,000), off, the line 'Needs <price>'", ok
		and int(Data.cat_skin("dusk_ranger")["price"]) == 3000 and int(Data.cat_skin("nightfall_ranger")["price"]) == 6000, seen)
	var pics := {}
	for id in IDS:
		var pic := Data.cat_skin_picture(id)
		pics[id] = String(_tile(id).get("picture", "")) == pic if ResourceLoader.exists(pic) else not _tile(id).has("picture")
	_x("each tile has its picture when res://assets/ui/cat_skins/<id>.png exists, else the outfit icon", pics.values().all(func(v): return v), pics)
	# a currency the game cannot take yet (a premium one, later): never free, the button stays off
	var info: Dictionary = Data.b["cat_skins"]["nightfall_ranger"]
	var keep := String(info["currency"])
	info["currency"] = "gems"
	Save.leaves = 100000
	var r2 := _tile("nightfall_ranger")
	_st()._buy_skin("nightfall_ranger")
	_x("a currency the game cannot take yet: Buy is off ('Coming later') and buying does nothing", not bool(r2.get("enabled", true))
		and String(r2.get("text", "")) == "Coming later" and not Data.cat_skin_owned("nightfall_ranger") and Save.leaves == 100000,
		{"text": r2.get("text", "")})
	info["currency"] = keep
	var keep_model := String(info["model"])
	info["model"] = "res://assets/cat/skins/missing_for_test.glb"
	var missing := _tile("nightfall_ranger")
	_st()._buy_skin("nightfall_ranger")
	_x("a missing outfit model shows 'Coming later' and buying takes no leaves", not bool(missing.get("enabled", true))
		and String(missing.get("text", "")) == "Coming later" and not Data.cat_skin_owned("nightfall_ranger") and Save.leaves == 100000,
		{"text": missing.get("text", ""), "leaves": Save.leaves})
	info["model"] = keep_model
	Save.leaves = 0


# ---------------------------------------------------------------- (c) buying
func _buy() -> void:
	var st = _st()
	var price := int(Data.cat_skin("dusk_ranger")["price"])
	Save.leaves = price - 1
	st._buy_skin("dusk_ranger")
	_x("one leaf short: buying is refused (nothing taken, not owned)", Save.leaves == price - 1 and not Data.cat_skin_owned("dusk_ranger"))
	Save.leaves = price + 55
	st._buy_skin("dusk_ranger")
	_x("Buy Dusk Ranger: exactly its price taken, owned, and (between waves) she wears it", Save.leaves == 55 and Data.cat_skin_owned("dusk_ranger")
		and Save.cat_skin == "dusk_ranger" and Save.cat_skins_owned.has("original"), {"leaves": Save.leaves, "owned": Save.cat_skins_owned, "worn": Save.cat_skin})
	var d := _tile("dusk_ranger")
	var o := _tile("original")
	var n := _tile("nightfall_ranger")
	_x("now: Dusk Ranger Wearing, the original Wear (on), Nightfall Buy (off, 'Needs 6,000 leaves')", String(d.get("label", "")) == "Wearing"
		and String(o.get("label", "")) == "Wear" and bool(o.get("enabled", false)) and String(o.get("badge", "")) == "Owned"
		and String(n.get("label", "")) == "Buy" and not bool(n.get("enabled", true)) and String(n.get("text", "")) == "Needs 6,000 leaves",
		{"dusk": d.get("label", ""), "original": [o.get("label", ""), o.get("enabled", false)], "nightfall": [n.get("label", ""), n.get("text", "")]})
	st._buy_skin("dusk_ranger")
	_x("buying it again does nothing", Save.leaves == 55 and Save.cat_skins_owned.count("dusk_ranger") == 1)
	Save.cat_skin = "original"                           # (d) starts from the original look
	main.player.apply_skin()


## The card as the player sees it (the original worn, Dusk Ranger owned, Nightfall Ranger not): tailor_card.png.
func _card_shot() -> void:
	var ring = _st().rings["tailor"]
	main.player.global_position = ring.global_position
	main.snap_camera()
	await t._wait(0.4)
	main.open_ring(ring)
	await t._wait(0.8)
	_x("the card opens from the Nook's marker", main.hud.card_ring() == ring)
	await t._shot("tailor_card")
	main.hud.hide_card()
	await t._wait(0.3)


# ---------------------------------------------------------------- (d) wearing
func _wear() -> void:
	var st = _st()
	var pl = main.player
	var orig: String = pl.original_base() + ".glb"
	var has_file := Data.cat_skin_model("dusk_ranger") != ""
	_x("before: the original model is on", pl.model_path() == orig and pl.skin_current(), {"model": pl.model_path()})
	var swaps0: int = pl.skin_swaps
	st._wear_skin("dusk_ranger")
	await t._wait(0.3)
	if has_file:
		_x("Wear Dusk Ranger: Save.cat_skin and the hero model swap to its file", Save.cat_skin == "dusk_ranger"
			and pl.model_path() == Data.cat_skin_model("dusk_ranger") and pl.skin_swaps == swaps0 + 1, {"model": pl.model_path()})
	else:
		_x("Wear Dusk Ranger with no file yet: Save.cat_skin swaps, the original model stays (nothing rebuilt, no error)",
			Save.cat_skin == "dusk_ranger" and pl.model_path() == orig and pl.skin_swaps == swaps0 and pl.skin_current()
			and is_instance_valid(pl.model) and pl.tree.active, {"model": pl.model_path(), "file": Data.cat_skin(String("dusk_ranger"))["model"]})
	st._wear_skin("original")
	await t._wait(0.3)
	_x("Wear the original: back to the original model", Save.cat_skin == "original" and pl.model_path() == orig and pl.skin_current(),
		{"model": pl.model_path()})
	# an outfit file standing in: the other hero model (same skeleton and clips) as Dusk Ranger's file, so the swap in
	# place is tried for real
	var other := Data.cat_skin_model("dusk_ranger")           # the real Dusk Ranger file
	var info: Dictionary = Data.b["cat_skins"]["dusk_ranger"]
	var keep := String(info["model"])
	info["model"] = other
	var old_model: Node3D = pl.model
	var old_skel: Skeleton3D = pl.skeleton
	var old_tree = pl.tree
	swaps0 = pl.skin_swaps
	st._wear_skin("dusk_ranger")
	_x("with a file: Wear swaps the hero model in place (old model out of the scene at once)", Save.cat_skin == "dusk_ranger"
		and pl.model_path() == other and pl.skin_swaps == swaps0 + 1 and pl.model != old_model and not old_model.is_inside_tree()
		and pl.model.get_parent() == pl, {"model": pl.model_path()})
	await t._wait(0.5)
	var sk: Skeleton3D = pl.skeleton
	var mods: Array = [pl.ride_pose, pl.twist, pl.ride_motion, pl.bow_face]
	_x("the new model is set up: its own AnimationTree (active), skeleton and the 4 skeleton modifiers on it", not is_instance_valid(old_model)
		and not is_instance_valid(old_skel) and not is_instance_valid(old_tree) and sk != null and sk.is_inside_tree() and pl.tree.active
		and pl.tree.get_parent() == pl.model and mods.all(func(m): return m != null and m.get_parent() == sk))
	_x("the cloth is set up again on the new skeleton", pl.cloth != null and is_instance_valid(pl.cloth) and pl.cloth.skeleton == sk
		and pl.cloth.sim != null and pl.cloth.sim.get_parent() == sk, {"cloth": pl.cloth != null})
	await t._wait(0.5)
	_x("the clips play on the new tree (its AnimationPlayer is the new model's, Idle while she stands)", pl.tree.active
		and pl.tree.get_node(pl.tree.anim_player) == pl.anim and pl.model.is_ancestor_of(pl.anim) and String(pl.loco_clip) == "Idle",
		{"clip": pl.loco_clip})
	main.player.global_position = BASE
	main.snap_camera()
	main.closeup_at = pl
	main.closeup = Vector3(1.6, 1.4, 2.6)
	await t._wait(0.8)
	await t._shot("tailor_swapped")
	main.closeup = Vector3.ZERO
	main.closeup_at = null
	info["model"] = keep
	_keep_other = other


var _keep_other := ""                       # the stand-in outfit file used in (d), again in (f)


# ---------------------------------------------------------------- (e) Wear in a wave
func _wave() -> void:
	var st = _st()
	var pl = main.player
	Save.cat_skin = "original"
	pl.apply_skin()
	_fight(true)
	var d := _tile("dusk_ranger")
	_x("in a wave: Wear is off and the line says 'Between waves'", String(d.get("label", "")) == "Wear" and not bool(d.get("enabled", true))
		and String(d.get("text", "")) == "Between waves", {"label": d.get("label", ""), "text": d.get("text", "")})
	st._wear_skin("dusk_ranger")
	_x("and Wear does nothing in a wave", Save.cat_skin == "original")
	_fight(false)
	var d2 := _tile("dusk_ranger")
	_x("between waves Wear is on again", String(d2.get("label", "")) == "Wear" and bool(d2.get("enabled", false)))


# ---------------------------------------------------------------- (f) the bow, the nocked arrow and riding after a swap
func _after_swap() -> void:
	var pl = main.player
	var info: Dictionary = Data.b["cat_skins"]["dusk_ranger"]
	var keep := String(info["model"])
	info["model"] = _keep_other
	# a bow with its own model in the paw, if one exists (else the cat's own bow, tinted)
	var bid := "twig"
	for b in Data.b["bows"]:
		if ResourceLoader.exists(pl.bow_path(String(b))) and not Data.bow_hidden(String(b)):
			bid = String(b)
			break
	Save.bows[bid] = maxi(int(Save.bows.get(bid, 1)), 1)
	Save.bow = bid
	pl.apply_bow()
	Save.cat_skin = "dusk_ranger"
	var swapped: bool = pl.apply_skin()
	await t._wait(0.4)
	var bm := pl.model.find_child("SK_CatBow", true, false) as MeshInstance3D
	var parts: Dictionary = pl._bow_parts(bid)
	var bow_ok: bool = bm != null and bm.visible and (bm.mesh == parts["mesh"] and bm.skin == parts["skin"] if not parts.is_empty()
		else bm.mesh == bm.get_meta("orig_mesh", bm.mesh))
	_x("after a swap the %s is in the new model's paw (%s)" % [Data.bow_info(bid)["name"], "its own model" if not parts.is_empty() else "the cat's own bow"],
		swapped and bow_ok, {"bow": bid, "model": pl.model_path()})
	var nock: Node = pl.nocked.get_child(0) if pl.nocked.get_child_count() > 0 else null
	var hold := pl.nocked.get_parent() as BoneAttachment3D
	var own_arrow: bool = ResourceLoader.exists(ArrowScript.arrow_path(bid))
	_x("the nocked arrow rides bone `arrow` of the new skeleton (%s)" % ("the bow's own arrow" if own_arrow else "the plain arrow"), nock != null
		and hold != null and hold.bone_name == "arrow" and hold.get_parent() == pl.skeleton
		and (not own_arrow or String(nock.scene_file_path) == ArrowScript.arrow_path(bid)), {"nock": nock.scene_file_path if nock else ""})
	# she shoots with it
	pl.global_position = BASE
	_foe(BASE + Vector3(0, 0, -2.6))
	var shots0: int = pl.shots_fired
	var shot: bool = await t._until(func(): return pl.shots_fired > shots0, 4.0)
	_x("she aims and shoots after the swap (an arrow leaves the nock)", shot and pl.state.contains("shoot"), {"shots": pl.shots_fired - shots0, "state": pl.state})
	_clear()
	await t._wait(0.5)
	# riding: on the mount, then a swap while riding
	main.mount.resting = 0.0
	main.set_riding(true, false)
	var seated: bool = await t._until(func(): return pl.riding and pl.ride_pose.amount > 0.99, 3.0)
	await t._wait(0.5)
	var y0: float = pl.model.position.y
	_x("she rides in the new outfit: seated on the saddle, the ride's motion on", seated and pl.ride_motion.amount > 0.99 and y0 > 0.05,
		{"amount": pl.ride_pose.amount, "y": y0})
	Save.cat_skin = "original"
	var sw2: bool = pl.apply_skin()
	await t._wait(0.6)
	_x("a swap while riding: still riding, seated again on the saddle, the ride's motion back on", sw2 and pl.riding and pl.ride_pose.amount > 0.99
		and pl.ride_motion.amount > 0.99 and absf(pl.model.position.y - y0) < 0.15 and pl.ride_pose.get_parent() == pl.skeleton,
		{"amount": pl.ride_pose.amount, "y": pl.model.position.y, "y_before": y0})
	pl.ride_jolt("stomp")
	await t._wait(0.3)
	_x("a skill's jolt still moves her in the saddle", pl.jolts > 0 and pl.riding)
	main.set_riding(false, false)
	await t._wait(0.4)
	_x("off the mount: standing again", not pl.riding and pl.ride_pose.amount < 0.01 and pl.model.position.y < 0.05,
		{"amount": pl.ride_pose.amount, "y": pl.model.position.y})
	info["model"] = keep
	Save.bow = "twig"
	pl.apply_bow()




# ---------------------------------------------------------------- (h) the real outfit files
func _real_looks() -> void:
	var pl = main.player
	Save.bow = "twig"
	pl.apply_bow()
	for id in ["dusk_ranger", "nightfall_ranger"]:
		var file: String = Data.cat_skin_model(id)
		_x("%s: its real file exists in the game (%s)" % [id, file], file != "" and ResourceLoader.exists(file) and file.begins_with("res://assets/cat/skins/"), {"file": file})
		if not Save.cat_skins_owned.has(id):
			Save.cat_skins_owned.append(id)
		Save.cat_skin = "original"
		pl.apply_skin()
		await t._wait(0.3)
		var original_sk: Skeleton3D = pl.skeleton
		var original_cloth = pl.cloth
		var settings: int = original_cloth.sim.setting_count if original_cloth != null and original_cloth.sim != null else -1
		_x("%s: the original has no cloak bones and still has 25 cloth settings" % id, original_sk != null
			and not CLOAK_BONES.any(func(n): return original_sk.find_bone(n) >= 0) and settings == 25, {"settings": settings})
		Save.cat_skin = id
		var swapped: bool = pl.apply_skin()
		await t._wait(0.6)
		_x("%s: wearing it uses its model and clips" % id, swapped and pl.model_path() == file and pl.skin_current()
			and pl.hero_clips() == file.get_basename() + "_clips.json", {"model": pl.model_path(), "clips": pl.hero_clips()})
		var sk: Skeleton3D = pl.skeleton
		_x("%s: own tree active, skeleton set, 4 modifiers on it, Idle clip plays" % id, sk != null and pl.tree.active and pl.tree.get_parent() == pl.model
			and [pl.ride_pose, pl.twist, pl.ride_motion, pl.bow_face].all(func(m): return m != null and m.get_parent() == sk) and String(pl.loco_clip) == "Idle", {"clip": pl.loco_clip})
		_x("%s: the cloth is set up on the new skeleton" % id, pl.cloth != null and is_instance_valid(pl.cloth) and pl.cloth.skeleton == sk and pl.cloth.sim != null
			and pl.cloth.sim.get_parent() == sk)
		var cloth = pl.cloth
		var simulated := {}
		if cloth != null and cloth.sim != null:
			for b in cloth.bones:
				if b["name"] in CLOAK_BONES and cloth.sim.get_root_bone_name(b["setting"]) == b["name"]:
					simulated[b["name"]] = b
		_x("%s: all four cloak bones are simulated" % id, sk != null
			and CLOAK_BONES.all(func(n): return sk.find_bone(n) >= 0 and simulated.has(n)), {"bones": simulated.keys()})
		var bm := pl.model.find_child("SK_CatBow", true, false) as MeshInstance3D
		var parts: Dictionary = pl._bow_parts("twig")
		_x("%s: the bow (SK_CatBow) is in her paw and shows" % id, bm != null and bm.visible and (parts.is_empty() or (bm.mesh == parts["mesh"] and bm.skin == parts["skin"])))
		var nock: Node = pl.nocked.get_child(0) if pl.nocked.get_child_count() > 0 else null
		var hold := pl.nocked.get_parent() as BoneAttachment3D
		_x("%s: the nocked arrow rides bone `arrow` of its skeleton" % id, nock != null and hold != null and hold.bone_name == "arrow" and hold.get_parent() == sk)
		# standing close-up
		pl.global_position = BASE
		main.snap_camera()
		main.closeup_at = pl
		main.closeup = Vector3(1.6, 1.4, 2.6)
		await t._wait(1.0)
		await t._shot("skin_%s_stand" % id)
		# running: the joystick pushed east, the cloak should stream
		var swing := {"cloak.L.2": 0.0, "cloak.R.2": 0.0}
		var sample_cloak := func():
			for n in swing:
				if simulated.has(n):
					swing[n] = maxf(swing[n], float(cloth.lift(simulated[n])["off"]))
		if cloth != null:
			cloth.measure = true
			sk.skeleton_updated.connect(sample_cloak)
		var j = main.joystick
		j.force = true
		j.forced = Vector2(1.0, 0.0)
		await t._wait(0.9)
		_x("%s: running plays the Run clip" % id, String(pl.loco_clip) == "Run" or String(pl.loco_clip) == "Walk", {"clip": pl.loco_clip})
		await t._shot("skin_%s_run1" % id)
		await t._wait(0.15)
		await t._shot("skin_%s_run2" % id)
		await t._wait(0.45)
		if cloth != null:
			sk.skeleton_updated.disconnect(sample_cloak)
			cloth.measure = false
		_x("%s: each cloak hem swings at least 8 degrees and stays under 80 during the run" % id,
			swing.values().all(func(angle): return angle >= 8.0 and angle < 80.0), swing)
		j.forced = Vector2.ZERO
		j.force = false
		await t._wait(0.6)
		# shooting
		pl.global_position = BASE
		_foe(BASE + Vector3(0, 0, -2.6))
		var shots0: int = pl.shots_fired
		var shot: bool = await t._until(func(): return pl.shots_fired > shots0, 4.0)
		_x("%s: she aims and shoots" % id, shot, {"state": pl.state})
		await t._shot("skin_%s_shoot" % id)
		_clear()
		await t._wait(0.4)
		main.closeup = Vector3.ZERO
		main.closeup_at = null
	# Load a scene without a hero rig at Dusk Ranger's path, with its clips JSON still in place.
	var path := Data.cat_skin_model("dusk_ranger")
	var outfit := load(path)
	var empty_scene := PackedScene.new()
	var root := Node3D.new()
	empty_scene.pack(root)
	root.free()
	empty_scene.take_over_path(path)
	Save.cat_skin = "dusk_ranger"
	var fell_back: bool = pl.apply_skin()
	outfit.take_over_path(path)
	var original: String = pl.original_base()
	_x("an unusable outfit uses the original model and its clips", fell_back and pl.model_path() == original + ".glb"
		and pl.hero_base() == path.get_basename() and FileAccess.file_exists(path.get_basename() + "_clips.json")
		and pl.hero_clips() == original + "_clips.json",
		{"model": pl.model_path(), "clips": pl.hero_clips()})
	Save.cat_skin = "original"
	pl.apply_skin()
	await t._wait(0.3)

# ---------------------------------------------------------------- (g) an old save
func _old_save() -> void:
	var keep_path: String = Save.path
	var tmp := "user://leaf_save_skins.json"
	var old := {"leaves": 10, "bows": {"twig": 1}, "camp_level": 3, "missions_done": [], "stations": {"stall": 1}}
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	f.store_string(JSON.stringify(old))
	f.close()
	Save.path = tmp
	Save.cat_skin = "dusk_ranger"
	Save.cat_skins_owned = ["original", "dusk_ranger"]
	Save.load_game()
	_x("an old save without cat_skin / cat_skins_owned loads with the original look, owned and worn", Save.cat_skin == "original"
		and Save.cat_skins_owned == ["original"] and main.player.hero_base() == main.player.original_base(), {"worn": Save.cat_skin, "owned": Save.cat_skins_owned})
	var gone := {"leaves": 10, "bows": {"twig": 1}, "cat_skin": "gone_outfit", "cat_skins_owned": ["gone_outfit", "dusk_ranger"]}
	f = FileAccess.open(tmp, FileAccess.WRITE)
	f.store_string(JSON.stringify(gone))
	f.close()
	Save.load_game()
	_x("a worn outfit the game no longer sells falls back to the original; the others stay owned", Save.cat_skin == "original"
		and Save.cat_skins_owned.has("original") and Save.cat_skins_owned.has("dusk_ranger"), {"worn": Save.cat_skin, "owned": Save.cat_skins_owned})
	Save.cat_skin = "dusk_ranger"
	Save.save_game(true)
	Save.cat_skin = "original"
	Save.load_game()
	_x("saved and loaded: the worn outfit is kept", Save.cat_skin == "dusk_ranger", {"worn": Save.cat_skin})
	Save.path = keep_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
	Save.load_game()


## 3000 -> "3,000".
func _thousands(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out
