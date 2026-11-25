extends Node
## Phase G3: the Bow Shop and its bows (`-- --autotest --fresh --bowshop`), run from autotest.gd. Each check logs
## "EXPECT PASS <what>" or "EXPECT FAIL <what>" through autotest.gd's _expect. Light on purpose: every number comes from
## balance.json, no wave is played (a wave being on is faked by hand for the few lines that need it, with no frame
## passing while it is on); the foes are stood still where a check needs them still.
##   (a) the card: title, the four tiles in order (Twig, Sunwood, Ember, Frost; since 22 Nov 2026 Thorn Volley and
##       Foxfire are hidden unless owned, then they show Owned / Equipped), labels, badges and notes; a hidden bow is
##       not sold and not named on the Shop's upgrade
##   (b) Buy: Ember at Shop level 3 takes exactly its leaves and its timber, owns it at level 1, puts it in the paw;
##       without the timber nothing is bought
##   (c) Upgrade: raises only the bow in the paw, stops at the Shop's cap
##   (d) Equip: back to Twig between waves; with a wave on Equip is off ("Between waves") and does nothing; the Frost
##       Bow bought mid-wave (exactly its price) is owned but not equipped, and equipped after the wave
##   (e) pierce: Sunwood's arrow goes through the first foe, Twig's stops at it
##   (f) fan: Thorn Volley (for a save that owns it) shoots 3 arrows at once, each at its share of the damage
##   (g) burn: an Ember hit sets the foe burning for seconds x share_per_s x the hit's damage, then it stops; a frozen
##       game does not burn
##   (i) ice (22 Nov 2026): Frost arrows chill (hits counted), a chilled foe's clock runs at half speed (steps, attack
##       timer), a new hit restarts the chill, the 3rd hit freezes it (no step, no clock) for freeze_s, bosses
##       boss_freeze_s; hits while frozen do not count; nothing runs down while the game is frozen; each bow's arrow
##       carries its trail and its length from its model; screenshots of the trails and the ice
##   (h) fallback: with no bow files the cat's own bow stays (tinted); close-ups of the bows that have files

var t                     # autotest.gd (its helpers: _wait, _expect, _until, _log)
var main

const ArrowScript := preload("res://scripts/arrow.gd")
const ORDER := ["twig", "sunwood", "ember", "frost"]
const HIDDEN := ["volley", "foxfire"]
const BOW_NOTES := {
	"twig": "Fastest draw",
	"sunwood": "Goes through the first enemy, +1.5 m range · draws 10% slower",
	"ember": "Fire arrows: the hit enemy burns for 3 s · 0.8 m shorter range",
	"frost": "Ice arrows: slow, and the 3rd hit freezes · slowest draw",
	"volley": "3 arrows in a fan",
	"foxfire": "Goes through two enemies, +1 m range",
}


func run() -> bool:
	main.player.invincible = true
	_start_fresh()
	await t._wait(0.3)
	_card()
	_buy()
	_upgrade()
	_equip()
	await _late_upgrades()
	await _pierce()
	await _fan()
	await _burn()
	await _frost()
	await _trails()
	await _fallback()
	_clear()
	main.hud.hide_card()
	_start_fresh()
	t._log("bowshop done")
	return true


func _x(what: String, ok: bool, extra := {}) -> bool:
	return t._expect(what, ok, extra)


func _st():
	return main.stations


## A camp with mission 1 won, the Bow Shop at level 1 and only the Twig Bow, no leaves, no Burrows.
func _start_fresh() -> void:
	Save.missions_done = [String(Data.mission(0)["id"])]
	Save.mission_run = {}
	Save.camp_level = 5
	for k in Save.stations:
		Save.stations[k] = 0
	Save.stations["bench"] = 1
	Save.bows = {"twig": 1}
	Save.bow = "twig"
	Save.ruined = []
	Save.wear = {}
	Save.fire_ruined = false
	Save.leaves = 0
	Save.timber = 0
	Save.flags.erase("hollow_open")
	for k in ["shop_open", "shop_target", "shop_bench", "home", "first_stage_done"]:
		Save.set_flag(k)
	main.player.apply_bow()
	_st().refresh()


func _bname(bid: String) -> String:
	return String(Data.bow_info(bid)["name"])


## The bow tiles of the Bow Shop's card (not its own upgrade tile), in card order (any bow, hidden ones too).
func _tiles() -> Array:
	var out: Array = []
	var names: Array = []
	for bid in Data.b["bows"]:
		names.append(_bname(String(bid)))
	for r in _st()._card_bench()["rows"]:
		if String(r.get("kind", "")) == "item" and names.has(String(r.get("title", ""))):
			out.append(r)
	return out


func _tile(bid: String) -> Dictionary:
	for r in _tiles():
		if String(r["title"]) == _bname(bid):
			return r
	return {}


## The Bow Shop's own upgrade tile ("Bow Shop level N").
func _shop_upgrade() -> Dictionary:
	for r in _st()._card_bench()["rows"]:
		if String(r.get("kind", "")) == "item" and String(r.get("title", "")).begins_with(String(Data.b["stations"]["bench"]["name"]) + " level"):
			return r
	return {}


func _need(bid: String) -> Dictionary:
	return Data.craft_cost(bid)


func _set_wave(on: bool) -> Dictionary:
	var f = main.fight
	var keep := {"active": f.active, "in_wave": f.in_wave}
	f.active = on
	f.in_wave = on
	return keep


func _restore_wave(keep: Dictionary) -> void:
	main.fight.active = keep["active"]
	main.fight.in_wave = keep["in_wave"]


# ---------------------------------------------------------------- (a) the card
func _card() -> void:
	var st = _st()
	var card: Dictionary = st._card_bench()
	_x("the card's title is the Bow Shop", String(card["title"]) == "Bow Shop" and String(Data.b["stations"]["bench"]["name"]) == "Bow Shop",
		{"title": card["title"]})
	var keys: Array = (Data.b["bows"] as Dictionary).keys()
	_x("balance.json: the Frost Bow comes right after Ember; Thorn Volley and Foxfire are kept, marked hidden",
		keys.find("frost") == keys.find("ember") + 1 and HIDDEN.all(func(b): return keys.has(b) and Data.bow_hidden(b))
		and not ORDER.any(func(b): return Data.bow_hidden(b)), {"bows": keys})
	var no_mats := true
	for bid in keys:
		var prices: Array = (Data.b["bows"][bid].get("mastery", []) as Array).duplicate()
		prices.append(Data.b["bows"][bid].get("craft", {}))
		for c in prices:
			if c is Dictionary:
				for m in ["amber", "glowstone", "heartwood"]:
					no_mats = no_mats and not (c as Dictionary).has(m)
	_x("H1: every bow's mastery and craft price is leaves (and timber) only; Foxfire crafts for 5,120 leaves", no_mats
		and Data.craft_cost("foxfire") == {"leaves": 5120} and Data.bow_cost("twig", (Data.b["bows"]["twig"]["cost"] as Array).size()).keys() == ["leaves"]
		and int(Data.bow_cost("twig", (Data.b["bows"]["twig"]["cost"] as Array).size())["leaves"]) == 1200, {"foxfire": Data.craft_cost("foxfire")})
	var tiles := _tiles()
	var titles: Array = tiles.map(func(r): return r["title"])
	_x("four bow tiles in order twig, sunwood, ember, frost (Volley and Foxfire hidden)", titles == ORDER.map(func(b): return _bname(b)), {"tiles": titles})
	var tw := _tile("twig")
	_x("Twig (fresh save): Equipped, button Upgrade, note 'Fastest draw'", String(tw.get("badge", "")) == "Equipped" and String(tw.get("label", "")) == "Upgrade"
		and String(tw.get("text", "")) == BOW_NOTES["twig"], {"tile": tw.get("text", ""), "label": tw.get("label", "")})
	var locked_ok := true
	var info := {}
	for bid in ["sunwood", "ember", "frost"]:
		var tl := _tile(bid)
		var need := int(Data.bow_info(bid)["bench_level"])
		var shop_ok: bool = int(Save.stations["bench"]) >= need
		var good := String(tl.get("label", "")) == "Buy"
		if shop_ok:
			good = good and String(tl.get("badge", "")) == "New"
		else:
			good = good and String(tl.get("badge", "")) == "Locked" and not bool(tl.get("enabled", true)) \
				and String(tl.get("text", "")) == "Needs Bow Shop level %d" % need
		locked_ok = locked_ok and good
		info[bid] = "%s/%s/%s" % [tl.get("label", ""), tl.get("badge", ""), tl.get("text", "")]
	_x("the other bows: Buy, Locked below their Shop level with 'Needs Bow Shop level N'", locked_ok, info)
	# the Shop's own upgrade names the bows it will sell, never a hidden one
	Save.stations["bench"] = int(Data.bow_info("ember")["bench_level"]) - 1
	var up3 := String(_shop_upgrade().get("text", ""))
	Save.stations["bench"] = int(Data.bow_info("frost")["bench_level"]) - 1
	var up5 := String(_shop_upgrade().get("text", ""))
	Save.stations["bench"] = 3
	var up4 := String(_shop_upgrade().get("text", ""))
	_x("the Shop's upgrade to Ember's level sells the Ember Bow; to Frost's level the Frost Bow; to level 4 it names no hidden bow",
		up3.contains(_bname("ember")) and up5.contains(_bname("frost")) and not up4.contains(_bname("volley")) and not up4.contains(_bname("foxfire")),
		{"to_ember": up3, "to_frost": up5, "to_4": up4})
	# at the Shop's level each bow's own note shows (leaves are still missing, so Buy is off but the badge is New)
	Save.stations["bench"] = int(Data.bow_info("frost")["bench_level"])
	var notes_ok := true
	var seen := {}
	for bid in ["sunwood", "ember", "frost"]:
		var tl := _tile(bid)
		seen[bid] = tl.get("text", "")
		notes_ok = notes_ok and String(tl.get("badge", "")) == "New" and String(tl.get("text", "")).begins_with(String(BOW_NOTES[bid]))
	_x("at the Frost Bow's Shop level the three bows are New and state their pro and con (Frost: '%s')" % BOW_NOTES["frost"], notes_ok, seen)
	Save.stations["bench"] = 5
	Save.set_flag("hollow_open")
	var t5: Array = _tiles().map(func(r): return r["title"])
	_x("Shop level 5 and the Burrows open: still the four tiles (no Volley, no Foxfire)", t5 == ORDER.map(func(b): return _bname(b)), {"tiles": t5})
	# a save that owns them still sees them, after the four, and can use them
	Save.bows["volley"] = 1
	Save.bows["foxfire"] = 1
	var t6: Array = _tiles().map(func(r): return r["title"])
	var vo := _tile("volley")
	_x("a save that owns Volley and Foxfire sees them after the four, Owned with Equip", t6 == (ORDER + HIDDEN).map(func(b): return _bname(b))
		and String(vo.get("badge", "")) == "Owned" and String(vo.get("label", "")) == "Equip" and bool(vo.get("enabled", false))
		and String(_tile("foxfire").get("badge", "")) == "Owned", {"tiles": t6, "volley": "%s/%s" % [vo.get("badge", ""), vo.get("label", "")]})
	Save.bow = "volley"
	vo = _tile("volley")
	_x("an owned hidden bow in the paw shows Equipped with Upgrade", String(vo.get("badge", "")) == "Equipped" and String(vo.get("label", "")) == "Upgrade",
		{"volley": "%s/%s" % [vo.get("badge", ""), vo.get("label", "")]})
	Save.bow = "twig"
	Save.bows.erase("volley")
	Save.bows.erase("foxfire")
	Save.leaves = 100000
	Save.timber = 1000
	st._craft("volley")
	st._craft("foxfire")
	_x("a hidden bow cannot be bought", not Save.bows.has("volley") and not Save.bows.has("foxfire") and Save.leaves == 100000 and Save.timber == 1000,
		{"bows": Save.bows})
	Save.leaves = 0
	Save.timber = 0
	Save.flags.erase("hollow_open")
	Save.stations["bench"] = 1


# ---------------------------------------------------------------- (b) Buy
func _buy() -> void:
	var st = _st()
	var need := _need("ember")
	Save.stations["bench"] = int(Data.bow_info("ember")["bench_level"])
	Save.leaves = int(need["leaves"]) + 77
	Save.timber = int(need["timber"]) - 1
	var tl := _tile("ember")
	st._craft("ember")
	_x("Buy without the timber: nothing is bought, nothing taken (button off)", not Save.bows.has("ember") and Save.leaves == int(need["leaves"]) + 77
		and Save.timber == int(need["timber"]) - 1 and not bool(tl.get("enabled", true)), {"enabled": tl.get("enabled")})
	Save.timber = int(need["timber"])
	tl = _tile("ember")
	var can: bool = bool(tl.get("enabled", false))
	st._craft("ember")
	_x("Buy Ember: owned at level 1, in the paw, exactly its leaves and timber taken", can and int(Save.bows.get("ember", 0)) == 1 and Save.bow == "ember"
		and Save.leaves == 77 and Save.timber == 0, {"bows": Save.bows, "bow": Save.bow, "leaves": Save.leaves, "timber": Save.timber})
	var e := _tile("ember")
	_x("the Ember tile is now Equipped with a button Upgrade; Twig is Owned with Equip", String(e.get("badge", "")) == "Equipped" and String(e.get("label", "")) == "Upgrade"
		and String(_tile("twig").get("badge", "")) == "Owned" and String(_tile("twig").get("label", "")) == "Equip")


# ---------------------------------------------------------------- (c) Upgrade
func _upgrade() -> void:
	var st = _st()
	Save.leaves = 1000000
	Save.stations["bench"] = 3
	var lv0 := int(Save.bows["ember"])
	var twig0 := int(Save.bows["twig"])
	st._upgrade_bow()
	_x("Upgrade raises only the equipped bow's level", int(Save.bows["ember"]) == lv0 + 1 and int(Save.bows["twig"]) == twig0, {"bows": Save.bows})
	Save.stations["bench"] = 1
	var cap := Data.bow_cap()
	for i in cap + 3:
		st._upgrade_bow()
	var tl := _tile("ember")
	_x("Upgrade stops at the Shop's cap (%d), the button off with its note" % cap, int(Save.bows["ember"]) == cap and not bool(tl.get("enabled", true))
		and String(tl.get("text", "")) == "Upgrade the Bow Shop for more" and int(Save.bows["twig"]) == twig0, {"bows": Save.bows, "text": tl.get("text", "")})
	Save.stations["bench"] = 3


# ---------------------------------------------------------------- (d) Equip
func _equip() -> void:
	var st = _st()
	st._equip("twig")
	_x("Equip Twig between waves puts it back in the paw; Ember keeps its level", Save.bow == "twig" and int(Save.bows["ember"]) > 1, {"bow": Save.bow})
	var keep := _set_wave(true)
	var tl := _tile("ember")
	st._equip("ember")
	_x("with a wave on: Equip is off, says 'Between waves', and _equip does nothing", String(tl.get("label", "")) == "Equip" and not bool(tl.get("enabled", true))
		and String(tl.get("text", "")) == "Between waves" and Save.bow == "twig", {"tile": tl.get("text", ""), "bow": Save.bow})
	var need := _need("frost")
	Save.stations["bench"] = int(Data.bow_info("frost")["bench_level"])
	Save.leaves = int(need["leaves"])
	Save.timber = int(need["timber"])
	st._craft("frost")
	_x("buying the Frost Bow mid-wave takes exactly its price, owns it at level 1, leaves the paw alone", int(Save.bows.get("frost", 0)) == 1 and Save.bow == "twig"
		and Save.leaves == 0 and Save.timber == 0 and int(need.get("leaves", 0)) > 0 and int(need.get("timber", 0)) > 0,
		{"bows": Save.bows, "bow": Save.bow, "price": need})
	_restore_wave(keep)
	st._equip("frost")
	_x("after the wave the Frost Bow can be equipped", Save.bow == "frost" and String(_tile("frost").get("badge", "")) == "Equipped")
	st._equip("twig")


# ---------------------------------------------------------------- 22 Nov 2026: price, damage, unlock, draw and range of the four bows
func _balance_steps() -> void:
	var price_ok := true
	var dmg_ok := true
	var prices := []
	for i in ORDER.size():
		var bid: String = ORDER[i]
		var p := int(Data.craft_cost(bid).get("leaves", 0))
		prices.append(p)
		if i > 0:
			var prev: String = ORDER[i - 1]
			price_ok = price_ok and p > int(Data.craft_cost(prev).get("leaves", 0)) and int(Data.craft_cost(bid).get("timber", 0)) > int(Data.craft_cost(prev).get("timber", 0))
			dmg_ok = dmg_ok and float(Data.bow_info(bid)["damage"]) > float(Data.bow_info(prev)["damage"])
	_x("the four shop bows cost more (leaves and timber) and hit harder, one after the other", price_ok and dmg_ok, {"leaves": prices})
	var cap_top := (Data.b["bow_cap_by_bench_level"] as Array).size() - 1
	var frost_need := int(Data.bow_info("frost")["bench_level"])
	var keep_bench := int(Save.stations["bench"])
	var keep_leaves := Save.leaves
	var keep_timber := Save.timber
	var keep_has := Save.bows.has("frost")
	Save.bows.erase("frost")
	Save.stations["bench"] = frost_need - 1
	Save.leaves = 1000000
	Save.timber = 100000
	var locked := _tile("frost")
	_st()._craft("frost")
	var not_bought := not Save.bows.has("frost")
	Save.stations["bench"] = frost_need
	var open := _tile("frost")
	_x("the Frost Bow is locked until the Bow Shop's top level (%d of %d) and cannot be bought before" % [frost_need, cap_top],
		frost_need == cap_top and String(locked.get("badge", "")) == "Locked" and not_bought and String(open.get("badge", "")) == "New"
		and bool(open.get("enabled", false)), {"locked": locked.get("badge", ""), "open": open.get("badge", "")})
	Save.stations["bench"] = keep_bench
	Save.leaves = keep_leaves
	Save.timber = keep_timber
	if keep_has:
		Save.bows["frost"] = 1
	# draw: interval = SHOOT_LENGTH / (draw speed / the bow's draw_mult)
	var keep_bow := Save.bow
	Save.bow = "twig"
	var iv_twig: float = 0.8333 / (Data.cat_draw() / Data.bow_draw_mult(Save.bow))
	Save.bow = "frost"
	var iv_frost: float = 0.8333 / (Data.cat_draw() / Data.bow_draw_mult(Save.bow))
	var want := float(Data.bow_info("frost")["draw_mult"])
	_x("Frost draws slower than Twig (interval %.3f s vs %.3f s, about x%s)" % [iv_frost, iv_twig, want],
		iv_frost > iv_twig and absf(iv_frost / iv_twig - want) < 0.01 and absf(iv_frost / iv_twig - 1.25) < 0.01,
		{"twig": iv_twig, "frost": iv_frost})
	# range: Ember's is shorter than Twig's by its range_bonus, and never under the floor
	Save.bow = "twig"
	var r_twig := Data.cat_range()
	Save.bow = "ember"
	var r_ember := Data.cat_range()
	Save.bow = "sunwood"
	var r_sun := Data.cat_range()
	Save.bow = keep_bow
	_x("Ember's range is 0.8 m shorter than Twig's, Sunwood's 1.5 m longer", absf((r_twig - r_ember) - 0.8) < 0.001 and absf((r_sun - r_twig) - 1.5) < 0.001,
		{"twig": r_twig, "ember": r_ember, "sunwood": r_sun})
	var keep_rb = Data.b["bows"]["ember"]["range_bonus"]
	Data.b["bows"]["ember"]["range_bonus"] = -100.0
	Save.bow = "ember"
	var floor_r := Data.cat_range()
	Data.b["bows"]["ember"]["range_bonus"] = keep_rb
	Save.bow = keep_bow
	_x("a huge negative range bonus stops at the floor (cat.min_range_m)", absf(floor_r - float(Data.b["cat"]["min_range_m"])) < 0.001, {"range": floor_r})


# ---------------------------------------------------------------- foes and arrows
func _foe(at: Vector3, still := true) -> Node3D:
	var e = main.fight.spawn("thornling", at, 0)
	e.hp = 1e6
	e.max_hp = 1e6
	if still:
		e.set_physics_process(false)
	return e


func _clear() -> void:
	for e in get_tree().get_nodes_in_group("foes"):
		e.dead = true
		e.remove_from_group("foes")
		e.remove_from_group("enemies")
		e.queue_free()
	for a in _arrows():
		a.queue_free()
	main.frozen = false


func _arrows() -> Array:
	return main.get_children().filter(func(n): return n.get_script() == ArrowScript)


## One arrow of bow bid, as the cat shoots it (its pierce, burn and ice from balance.json), along +Z at a foe's chest
## height.
func _shoot(bid: String, from: Vector3, dmg: float) -> Node3D:
	var bow := Data.bow_info(bid)
	var a := Node3D.new()
	a.set_script(ArrowScript)
	main.add_child(a)
	a.launch(from, Vector3(0, 0, 1), main, dmg, int(bow["pierce"]), Data.bow_burn(bid), bid, Data.bow_frost(bid))
	return a


## Late damage must reach real arrows; purchases must remain affordable and reject an insufficient wallet.
func _late_upgrades() -> void:
	var keep_bow: String = Save.bow
	var keep_bows: Dictionary = Save.bows.duplicate(true)
	var keep_stats: Dictionary = Save.stats.duplicate(true)
	var keep_leaves: int = Save.leaves
	var keep_bench: int = Save.stations["bench"]
	var processing: bool = main.player.is_processing()
	main.player.set_process(false)
	Save.stats["damage"] = 9
	var expected := {1: 1.0, 5: 1.4, 6: 1.6, 9: 2.2, 10: 2.4, 11: 2.5, 12: 2.6}
	var affordable := {"twig": 810, "sunwood": 1100, "ember": 1480, "frost": 1930}
	for bid in ORDER:
		var curve_ok := true
		for level in expected:
			Save.bow = bid
			Save.bows[bid] = int(level)
			var want: float = 20.8 * float(Data.bow_info(bid)["damage"]) * float(expected[level])
			curve_ok = curve_ok and absf(Data.arrow_damage() - want) < 0.0001
		_x("%s keeps early damage, gains stronger levels 6-10 and retains mastery increments" % bid, curve_ok)
		var total := 0
		for level in range(5, 9):
			total += int(Data.bow_cost(bid, level)["leaves"])
		_x("%s level 5 to 9 costs the reduced leaf total" % bid, total == int(affordable[bid]), {"leaves": total})
	Save.bow = "ember"
	Save.bows["ember"] = 9
	Save.leaves = 0
	var power := Data.arrow_damage()
	_x("an already-owned level-9 Ember gains damage even with no leaves", absf(power - 59.488) < 0.0001 and Save.leaves == 0 and int(Save.bows["ember"]) == 9, {"damage": power})
	_clear()
	var base := Vector3(-1.5, 0, 12)
	var foe := _foe(base + Vector3(0, 0, 2.0))
	_shoot("ember", base + Vector3(0, foe.aim_height, 0), power)
	await t._wait(0.3)
	_x("the stronger level-9 arrow really hits and scales its Ember burn", absf(1e6 - float(foe.hp) - 59.488) < 0.001 and absf(float(foe.burn_per_s) - 14.872) < 0.001, {"hit": 1e6 - float(foe.hp), "burn_per_s": foe.burn_per_s})
	_clear()
	Save.bows["ember"] = 5
	Save.stations["bench"] = 2                       # level 6 power is available before the expensive late shop tier
	var price := int(Data.bow_cost("ember", 5)["leaves"])
	Save.leaves = price - 1
	_st()._upgrade_bow()
	_x("one leaf short refuses a late upgrade without charging or changing its level", int(Save.bows["ember"]) == 5 and Save.leaves == price - 1)
	var tile := _tile("ember")
	_x("the shop shows the affordable price and next damage gain", int((tile.get("cost", {}) as Dictionary).get("leaves", 0)) == price and String(tile.get("text", "")).begins_with("Next: +14.3% damage\n"), {"tile": tile.get("text", ""), "cost": tile.get("cost", {})})
	main.hud.show_card(_st().rings["bench"])
	await t._wait(0.4)                              # let the card's opening animation and layout settle
	await t._shot("late_bow_price_damage")
	main.hud.hide_card()
	Save.leaves = price
	_st()._upgrade_bow()
	_x("exactly the reduced price buys level 6 and leaves the wallet at zero", price == 225 and int(Save.bows["ember"]) == 6 and Save.leaves == 0)
	Save.bows["ember"] = 5
	Save.stations["bench"] = 4
	Save.leaves = int(affordable["ember"])
	for step in 4:
		_st()._upgrade_bow()
	_x("a saved 1480-leaf budget buys all four Ember upgrades from 5 to 9", int(Save.bows["ember"]) == 9 and Save.leaves == 0)
	var guaranteed := _guaranteed_mission_leaves(12) + _guaranteed_mission_leaves(13)
	var shop_cost: int = (Data.b["stations"]["bench"]["levels"][3] as Dictionary)["leaves"]
	var owned_package: int = shop_cost + int(affordable["ember"])
	var new_package := shop_cost + int(Data.craft_cost("ember")["leaves"])
	for level in range(1, 9):
		new_package += int(Data.bow_cost("ember", level)["leaves"])
	_x("raids 13 and 14 guaranteed leaves cover shop 4 plus Ember 5-to-9 with repair room", guaranteed >= owned_package + 2000, {"guaranteed_floor": guaranteed, "package": owned_package, "remaining": guaranteed - owned_package})
	_x("even a newly bought Ember to level 9 fits that budget without kill or performance rewards", guaranteed > new_package, {"guaranteed_floor": guaranteed, "package": new_package, "remaining": guaranteed - new_package})
	t._log("late bow affordability", {"guaranteed_floor": guaranteed, "owned_package": owned_package, "new_package": new_package})
	Save.bow = keep_bow
	Save.bows = keep_bows
	Save.stats = keep_stats
	Save.leaves = keep_leaves
	Save.stations["bench"] = keep_bench
	main.player.set_process(processing)


## Conservative first-clear income: floor each guaranteed wave/chapter payment, excluding kills and all bonuses.
func _guaranteed_mission_leaves(index: int) -> int:
	var mission: Dictionary = Data.mission(index)
	var cfg: Dictionary = Data.b["mission"]
	var scale: float = 1.0 + float(cfg["pay_per_mission"]) * index
	var leaves := int((mission["reward"] as Dictionary)["leaves"])
	for wave in range(1, int(mission["waves"]) + 1):
		leaves += floori((float(cfg["wave_bonus"]) + float(cfg["wave_bonus_step"]) * wave) * scale)
	var chapters := ceili(float(mission["waves"]) / float(cfg["chapter_waves"]))
	var chests: Array = cfg["chest_leaves"]
	for chapter in chapters:
		leaves += floori(float(chests[mini(chapter, chests.size() - 1)]) * scale)
	return leaves


# ---------------------------------------------------------------- (e) pierce
func _pierce() -> void:
	await t._wait(2.0)                                  # the first frames after loading are slow: a slow frame would skip the arrow past a foe
	_clear()
	var base := Vector3(-1.5, 0, 12.0)                  # open ground south of the camp
	main.player.global_position = base + Vector3(8, 0, 0)
	for bid in ["sunwood", "twig"]:
		var foes: Array = []
		for i in 3:
			foes.append(_foe(base + Vector3(0, 0, 4.0 + 2.0 * i)))
		await t._wait(0.2)
		var h0: Array = foes.map(func(f): return f.hp)
		var from: Vector3 = base + Vector3(0, float(foes[0].aim_height), 0)
		_shoot(bid, from, 10.0)
		await t._wait(0.9)
		var hit: Array = []
		for i in 3:
			hit.append(float(h0[i]) - float(foes[i].hp) > 0.5)
		var pierce := int(Data.bow_info(bid)["pierce"])
		var want: Array = []
		for i in 3:
			want.append(i <= pierce)
		_x("%s arrow (pierce %d) hits %d foe(s) in a line, the first first" % [_bname(bid), pierce, pierce + 1], hit == want, {"hit": hit, "want": want})
		_clear()
		await t._wait(0.1)


# ---------------------------------------------------------------- (f) fan
func _fan() -> void:
	_clear()
	var base := Vector3(-1.5, 0, 12.0)
	main.player.global_position = base
	var foe := _foe(base + Vector3(0, 0, 5.0))
	main.player.target = foe
	Save.bow = "volley"
	Save.bows["volley"] = 1
	var n0 := _arrows().size()
	main.player._fire()
	var made := _arrows()
	var one := Data.arrow_damage()
	var share := float(Data.bow_info("volley")["damage"])
	var dirs: Array = made.map(func(a): return a.dir)
	var fan_ok := made.size() - n0 == int(Data.bow_info("volley")["arrows"]) and made.size() == 3
	if fan_ok:
		fan_ok = not (dirs[0] as Vector3).is_equal_approx(dirs[1]) and not (dirs[1] as Vector3).is_equal_approx(dirs[2])
	var dmg_ok := made.all(func(a): return absf(float(a.damage) - one) < 0.001)
	Save.bow = "twig"
	var twig_dmg := Data.arrow_damage()                  # same bow level (1), so the ratio is the bow's own share
	Save.bow = "volley"
	_x("Thorn Volley (owned): one shot makes 3 arrows in a fan", fan_ok, {"arrows": made.size() - n0})
	_x("each fan arrow does %d%% of a plain arrow's damage" % int(round(share * 100.0)), dmg_ok and absf(one / twig_dmg - share) < 0.001,
		{"arrow": one, "twig": twig_dmg})
	_clear()
	Save.bow = "twig"
	Save.bows.erase("volley")
	main.player.target = null


# ---------------------------------------------------------------- (g) burn
func _burn() -> void:
	_clear()
	var fire := Data.bow_burn("ember")
	var secs := float(fire.get("seconds", 0.0))
	var share := float(fire.get("share_per_s", 0.0))
	var base := Vector3(-1.5, 0, 12.0)
	main.player.global_position = base + Vector3(8, 0, 0)
	var foe := _foe(base + Vector3(0, 0, 5.0), false)
	foe.set_physics_process(true)
	await t._wait(0.2)
	var h0: float = foe.hp
	_shoot("ember", base + Vector3(0, float(foe.aim_height), 0), 12.0)
	var lit: bool = await t._until(func(): return foe.burn_t > 0.0, 1.5)
	var hit_dmg := float(foe.last_dealt)
	_x("an Ember hit sets the foe burning", lit and hit_dmg > 0.0 and foe.burn_t <= secs + 0.001, {"burn_t": foe.burn_t, "hit": hit_dmg})
	await t._wait(secs + 0.5)
	var want := secs * share * hit_dmg
	_x("the burn deals about %s x %s x the hit's damage in all, then stops" % [secs, share], foe.burn_t == 0.0 and absf(float(foe.burn_dealt) - want) <= 0.05 * want + 0.05,
		{"dealt": foe.burn_dealt, "want": want, "burn_t": foe.burn_t})
	var after: float = foe.burn_dealt
	await t._wait(1.2)
	_x("a burnt-out foe takes no more fire damage", is_equal_approx(float(foe.burn_dealt), after), {"dealt": foe.burn_dealt})
	_clear()
	# a frozen game does not burn
	var foe2 := _foe(base + Vector3(0, 0, 5.0), false)
	foe2.set_physics_process(true)
	await t._wait(0.2)
	_shoot("ember", base + Vector3(0, float(foe2.aim_height), 0), 12.0)
	await t._until(func(): return foe2.burn_t > 0.0, 1.5)
	main.frozen = true
	var bt: float = foe2.burn_t
	await t._wait(1.5)
	_x("while the game is frozen the burn neither ticks nor runs down", bt > 0.0 and float(foe2.burn_dealt) == 0.0 and is_equal_approx(float(foe2.burn_t), bt),
		{"burn_t": foe2.burn_t, "dealt": foe2.burn_dealt})
	main.frozen = false
	_clear()


# ---------------------------------------------------------------- (i) the Frost Bow's ice
func _flat_d(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _frost() -> void:
	_clear()
	var cfg := Data.bow_frost("frost")
	var slow := float(cfg.get("slow", 0.0))
	var secs := float(cfg.get("seconds", 0.0))
	var need := int(cfg.get("hits_to_freeze", 0))
	var fs := float(cfg.get("freeze_s", 0.0))
	var bfs := float(cfg.get("boss_freeze_s", 0.0))
	_x("balance.json: the Frost Bow slows 50% for 3 s, the 3rd hit freezes 1.5 s, bosses 0.5 s, and has no burn",
		slow == 0.5 and secs == 3.0 and need == 3 and fs == 1.5 and bfs == 0.5 and Data.bow_burn("frost").is_empty(), cfg)
	_balance_steps()
	var base := Vector3(-1.5, 0, 12.0)
	main.player.global_position = base + Vector3(8, 0, 0)
	# the arrows: each hit counts, the 3rd freezes (the foe stood still: its clock does not run, so the numbers stay put)
	var foe := _foe(base + Vector3(0, 0, 4.0))
	var twig_foe := _foe(base + Vector3(3.0, 0, 4.0))
	await t._wait(0.2)
	_shoot("twig", base + Vector3(3.0, float(twig_foe.aim_height), 0), 5.0)
	var counts: Array = []
	for k in need:
		_shoot("frost", base + Vector3(0, float(foe.aim_height), 0), 5.0)
		await t._wait(0.6)
		counts.append([foe.chill_hits, snappedf(foe.freeze_t, 0.01)])
	_x("a Twig arrow does not chill", twig_foe.chill_t == 0.0 and twig_foe.hp < 1e6, {"chill_t": twig_foe.chill_t})
	_x("Frost arrows: hits 1 and 2 chill (count 1, 2), the 3rd freezes it for %s s and the count starts over" % fs,
		counts.size() == 3 and int(counts[0][0]) == 1 and int(counts[1][0]) == 2 and float(counts[0][1]) == 0.0 and float(counts[1][1]) == 0.0
		and int(counts[2][0]) == 0 and absf(float(counts[2][1]) - fs) < 0.01 and foe.freezes == 1, {"counts": counts})
	_x("chilled at %d%% for %s s, with the frosty look; frozen with its ice shell" % [roundi(slow * 100.0), secs],
		absf(float(foe.chill_slow) - slow) < 0.001 and absf(float(foe.chill_t) - secs) < 0.01 and foe._frost_on == 2 and foe._ice != null and is_instance_valid(foe._ice))
	_clear()
	# slower: a chilled foe's clock (its steps, its attack timer) runs at half speed
	var walker := _foe(base + Vector3(0, 0, 6.0), false)
	await t._wait(0.4)
	var t0: float = walker._t
	var p0: Vector3 = walker.global_position
	walker._cd = 5.0
	await t._wait(1.0)
	var free_t: float = walker._t - t0
	var free_cd: float = 5.0 - float(walker._cd)
	var free_m := _flat_d(walker.global_position, p0)
	walker.chill(cfg)
	t0 = walker._t
	p0 = walker.global_position
	walker._cd = 5.0
	await t._wait(1.0)
	var cold_t: float = walker._t - t0
	var cold_cd: float = 5.0 - float(walker._cd)
	var cold_m := _flat_d(walker.global_position, p0)
	var k_t := cold_t / maxf(free_t, 0.001)
	_x("chilled: its clock runs at %d%% (steps and attack timer)" % roundi((1.0 - slow) * 100.0), absf(k_t - (1.0 - slow)) < 0.08
		and absf(cold_cd / maxf(free_cd, 0.001) - (1.0 - slow)) < 0.08, {"free_t": free_t, "cold_t": cold_t, "free_cd": free_cd, "cold_cd": cold_cd})
	_x("chilled: it walks about half as far in a second", free_m < 0.3 or cold_m < free_m * 0.75, {"free_m": free_m, "cold_m": cold_m})
	var left: float = walker.chill_t
	walker.chill(cfg)
	_x("a new ice hit starts the %s s again" % secs, left < secs - 0.8 and absf(float(walker.chill_t) - secs) < 0.001 and walker.chill_hits == 2,
		{"left": left, "now": walker.chill_t, "hits": walker.chill_hits})
	walker.chill(cfg)
	_x("the 3rd hit in a row freezes it", absf(float(walker.freeze_t) - fs) < 0.05 and walker.chill_hits == 0, {"freeze_t": walker.freeze_t})
	await t._wait(0.1)
	t0 = walker._t
	p0 = walker.global_position
	await t._wait(0.6)
	_x("frozen: it does not move and its clock stands still", is_equal_approx(float(walker._t), t0) and _flat_d(walker.global_position, p0) < 0.001
		and (walker.anim == null or walker.anim.speed_scale == 0.0), {"t": walker._t - t0, "moved": _flat_d(walker.global_position, p0)})
	var ft: float = walker.freeze_t
	for k in need:
		walker.chill(cfg)
	_x("hits while frozen do not count (no new freeze, the freeze not restarted)", walker.freezes == 1 and walker.chill_hits == 0 and walker.freeze_t <= ft + 0.001,
		{"freezes": walker.freezes, "hits": walker.chill_hits, "freeze_t": walker.freeze_t})
	var thawed: bool = await t._until(func(): return walker.freeze_t <= 0.0, fs + 0.5)
	await t._wait(0.2)
	_x("after %s s it thaws (the shell gone), still chilled, and moves on" % fs, thawed and walker._ice == null and walker._frost_on == 1 and walker._t > t0,
		{"freeze_t": walker.freeze_t, "look": walker._frost_on})
	var off: bool = await t._until(func(): return walker.chill_t <= 0.0, secs + 0.5)
	_x("the chill runs out: its own colours back, the count lost", off and walker._frost_on == 0 and walker.chill_hits == 0)
	_clear()
	# a boss freezes for less
	var big := _foe(base + Vector3(0, 0, 5.0))
	big.boss = true
	for k in need:
		big.chill(cfg)
	_x("a boss freezes for %s s" % bfs, absf(float(big.freeze_t) - bfs) < 0.001 and big.is_boss(), {"freeze_t": big.freeze_t})
	_clear()
	# nothing runs down while the game is frozen
	var held := _foe(base + Vector3(0, 0, 5.0), false)
	await t._wait(0.2)
	for k in need:
		held.chill(cfg)
	main.frozen = true
	var f0: float = held.freeze_t
	var c0: float = held.chill_t
	await t._wait(1.0)
	_x("while the game is frozen the ice neither thaws nor runs down", f0 > 0.0 and is_equal_approx(float(held.freeze_t), f0) and is_equal_approx(float(held.chill_t), c0),
		{"freeze_t": held.freeze_t, "chill_t": held.chill_t})
	main.frozen = false
	await t._wait(0.3)
	_x("and runs on once the game goes on", held.freeze_t < f0)
	_clear()


# ---------------------------------------------------------------- (i) each bow's trail, and pictures of the ice
## Every bow's arrow carries its trail (balance.json fx) and takes its length from its model; one screenshot of each shop
## bow's arrow in flight (bowshop_trail_<id>.png) and of a chilled and a frozen foe (bowshop_chilled / _frozen.png).
func _trails() -> void:
	_clear()
	var pl = main.player
	var base := Vector3(-1.5, 0, 12.0)
	pl.global_position = base
	var ok := true
	var info := {}
	for bid in Data.b["bows"]:
		var a := _shoot(String(bid), base + Vector3(-3.0, 0.6, 0), 1.0)
		var n: int = (a._trail as Array).size()
		var want := 1 + (1 if String(Data.bow_fx(bid).get("trail", "")) == "glint" else (2 if String(Data.bow_fx(bid).get("trail", "")) in ["flame", "frost"] else 0))
		var ln: float = a.length
		info[bid] = "trail %d/%d, length %.3f (model %s)" % [n, want, ln, "own" if ResourceLoader.exists(ArrowScript.arrow_path(bid)) else "plain"]
		ok = ok and n == want and ln > 0.1 and ln < 3.0 and is_equal_approx(ln, ArrowScript.length_for(bid))
	_x("every bow's arrow carries its trail and its length from its model", ok, info)
	_clear()
	await t._wait(0.2)
	var look := Node3D.new()                            # what the close-up camera looks at
	main.add_child(look)
	look.global_position = pl.global_position + Vector3(0, 0, 1.8)
	main.closeup_at = look
	main.closeup = Vector3(6.5, 2.5, 0.0)                # from the side: the arrow flies across the picture
	for bid in ORDER:
		var foe := _foe(pl.global_position + Vector3(0, 0, 6.0))
		Save.bows[bid] = maxi(int(Save.bows.get(bid, 1)), 1)
		Save.bow = bid
		pl.apply_bow()
		pl.target = foe
		pl._fire()
		await t._wait(0.1)
		await t._shot("bowshop_trail_%s" % bid)
		await t._wait(0.5)
		_clear()
	pl.target = null
	var cfg := Data.bow_frost("frost")
	look.global_position = pl.global_position + Vector3(0, 0, 2.2)
	main.closeup = Vector3(4.2, 1.8, 0.0)               # from the same side: a chilled foe (left) and a frozen one (right)
	var cold := _foe(look.global_position + Vector3(0, 0, 0.6))
	var ice := _foe(look.global_position + Vector3(0, 0, -0.6))
	cold.chill(cfg)
	for k in int(cfg.get("hits_to_freeze", 3)):
		ice.chill(cfg)
	await t._wait(0.4)
	await t._shot("bowshop_frozen")
	_clear()
	main.closeup = Vector3.ZERO
	main.closeup_at = null
	look.queue_free()
	Save.bow = "twig"
	pl.apply_bow()


# ---------------------------------------------------------------- (h) each bow's own model (or the fallback)
## With a bow file: its mesh is in the cat's SK_CatBow, skinned by bone name to the cat's skeleton, its M_Glow surface
## (if any) keeps its glowing material, and the nocked arrow is its own model; a close-up shot of the cat shooting
## with it (bowshop_<id>.png in --shots). Without a file: the cat's own bow stays (as before G3).
func _fallback() -> void:
	var pl = main.player
	var bm := pl.model.find_child("SK_CatBow", true, false) as MeshInstance3D
	main.closeup = Vector3(2.8, 1.9, -1.2)                  # beside the cat, a little ahead: the bow side
	for bid in Data.b["bows"]:
		Save.bows[bid] = maxi(int(Save.bows.get(bid, 1)), 1)
		Save.bow = bid
		pl.apply_bow()
		var has_file: bool = ResourceLoader.exists(pl.bow_path(bid))
		var parts: Dictionary = pl._bow_parts(bid)
		if not has_file:
			_x("%s: no bow file, the cat's own bow stays" % bid, parts.is_empty() and bm != null and bm.visible
				and bm.mesh == bm.get_meta("orig_mesh", bm.mesh))
			continue
		var glow_ok := true
		var glows := 0
		for i in bm.mesh.get_surface_count():
			var src := bm.mesh.surface_get_material(i)
			if src != null and src.resource_name == "M_Glow":
				glows += 1
				var om := bm.get_surface_override_material(i)
				glow_ok = glow_ok and om == src and (om as BaseMaterial3D).emission_enabled
		_x("%s: its own model is in the cat's paw (named-bind skin, %d glowing surface(s) kept)" % [bid, glows],
			not parts.is_empty() and bm.visible and bm.mesh == parts["mesh"] and bm.skin == parts["skin"]
			and bm.skin.get_bind_count() > 0 and String(bm.skin.get_bind_name(0)) != "" and glow_ok)
		var nock: Node = pl.nocked.get_child(0) if pl.nocked.get_child_count() > 0 else null
		var own_arrow: bool = ResourceLoader.exists(ArrowScript.arrow_path(bid))
		_x("%s: the arrow on the string is %s" % [bid, "its own" if own_arrow else "the plain one"], nock != null
			and (not own_arrow or String(nock.scene_file_path) == ArrowScript.arrow_path(bid)), {"nock": nock.scene_file_path if nock else ""})
		var foe := _foe(pl.global_position + Vector3(0, 0, -4.5))
		await t._wait(1.4)
		await t._shot("bowshop_%s" % bid)
		_clear()
	main.closeup = Vector3.ZERO
	Save.bow = "twig"
	pl.apply_bow()
