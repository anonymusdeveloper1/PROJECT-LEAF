extends RefCounted
## The companions' choices (H5, 27 Nov 2026; docs/ARCHITECTURE.md part 4; the H5 map part 3.3): which owned mount or pet
## look comes out (choose), buying a mount or pet look with what follows it (buy), and which learned skills the mount
## uses in its three circles (assign_skill). Static functions only; it keeps no state.
## No class_name: preload it, const CompanionShop := preload("res://scripts/companion_shop.gd").
## Rules:
##   - choose(main, slot, id) puts out an owned look of slot "mount" or "pet" (exact id; Data.owned_level >= 1, the
##     Market's free Thistle and Bramblewool included) and calls that companion's set_look(). The pet slot needs the
##     pet (Data.pet_level() >= 1), so picking Lumi never skips buying Sprig. Like every Market action it needs the
##     Market standing. Free and quiet: no price, no receipt. The look's colour id is kept as it is.
##   - buy(main, slot, id) is the Buy command for a mount or pet look (commands/buy.gd: one way to buy anything), then
##     what must follow it at once: the first pet comes out with main.refresh_companions(), once; and when the look
##     out before is not owned (an empty camp's default), the bought one comes out instead.
##   - assign_skill(main, index, id) puts learned skill id in circle index (0 to 2): a skill already in another circle
##     moves (that circle empties), a skill in a filled circle is replaced (it stays learned in the grid). id "" empties
##     the circle. It needs the Saddlery standing and no wave on. An unknown or unlearned skill, a bad index or no
##     change returns false and changes nothing. Every mount shares the one list (Save.saddlery skill_slots). Learned
##     levels and cooldowns are never touched; the mount reads Data.active_skill_level when it tries a move.
##   - Each change is saved at once (as the H4 rules did), quietly: the caller gives the feedback and redraws its window
##     once (a drag in the Saddlery is never cut short by a redraw from here).
##   - Until the v5 save is live (Buy.v5_ready, H5 Stage 2) all three return false and change nothing.
## Used by: the Market's Mounts and Pets tabs and the Saddlery's Skills tab (H5 Stage 2), the tests.
## Uses: Data (the catalogue, ownership, levels, skill circles), Save, commands/buy.gd, scripts/market_trade.gd (the
##       building check), main (mount, pet, fight, refresh_companions).

const Buy := preload("res://commands/buy.gd")
const MarketTrade := preload("res://scripts/market_trade.gd")
const SLOT_KINDS := {"mount": "mounts", "pet": "pets"}   # a companion slot -> its content kind (main.<slot> is its node)


## Puts out owned look id in slot ("mount" or "pet"). true when it changed; false when it is unknown, not owned, already
## out, the pet is not owned yet, or the Market cannot be used now.
static func choose(main: Node3D, slot: String, id: String) -> bool:
	var kind: String = String(SLOT_KINDS.get(slot, ""))
	if kind == "" or not Buy.v5_ready():
		return false
	var e: Dictionary = Data.shop_entry(kind, id)
	if e.is_empty() or Data.owned_level(kind, id) < 1 or _look_in(slot) == id:
		return false
	if slot == "pet" and Data.pet_level() < 1:
		return false
	if MarketTrade.building_reason(Buy.shop_of(e)) != "":
		return false
	_set_look(slot, id)
	_show_look(main, slot)
	Save.save_game(true)
	return true


## Buys mount or pet look id (the Buy command, kind "mounts" or "pets"; expected_level as Buy's), then the first pet
## comes out and a look that is owned is out. true when it was bought; Buy.new(kind, id).can_run(main) says why not.
static func buy(main: Node3D, slot: String, id: String, expected_level: int = -1) -> bool:
	var kind: String = String(SLOT_KINDS.get(slot, ""))
	if kind == "":
		return false
	var had_pet: bool = Data.pet_level() >= 1
	if not Buy.new(kind, id, 1, expected_level).run(main):
		return false
	var swap: bool = Data.owned_level(kind, _look_in(slot)) < 1
	if swap:
		_set_look(slot, id)                                 # before the pet is made, so it comes out in this look
	if slot == "pet" and not had_pet and Data.pet_level() >= 1 and main.has_method("refresh_companions"):
		main.call("refresh_companions")                    # the pet joins the cat now, once
	if swap:
		_show_look(main, slot)
	Save.save_game(true)
	return true


## Puts learned skill id in the mount's circle index ("" empties it). true when the circles changed.
static func assign_skill(main: Node3D, index: int, id: String) -> bool:
	if not Buy.v5_ready() or Buy.wave_on(main) or MarketTrade.building_reason(Buy.SADDLERY) != "":
		return false
	var slots: Array[String] = Data.skill_slots()
	if index < 0 or index >= slots.size():
		return false
	if id == "":
		if slots[index] == "":
			return false
		slots[index] = ""
	else:
		if Data.saddle_info("skills", id).is_empty() or Data.skill_level(id) < 1 or slots[index] == id:
			return false
		var was: int = slots.find(id)
		if was >= 0:
			slots[was] = ""                                 # it moves: its old circle empties
		slots[index] = id
	var out: Array = []
	out.assign(slots)
	Save.saddlery["skill_slots"] = out
	Save.save_game(true)
	return true


# ---------------------------------------------------------------- inside
## The look out in a slot now (Save.mount_look or Save.pet_look).
static func _look_in(slot: String) -> String:
	return Save.mount_look if slot == "mount" else Save.pet_look


static func _set_look(slot: String, id: String) -> void:
	if slot == "mount":
		Save.mount_look = id
	else:
		Save.pet_look = id


## The companion in the slot (main.mount or main.pet), when it is there, takes its look now.
static func _show_look(main: Node3D, slot: String) -> void:
	var who: Variant = main.get(slot) if main != null else null
	if who is Object and is_instance_valid(who) and (who as Object).has_method("set_look"):
		(who as Object).call("set_look")
