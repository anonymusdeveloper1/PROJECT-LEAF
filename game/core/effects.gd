class_name Effects
extends RefCounted
## The effects list (H3, 26 Nov 2026; docs/ARCHITECTURE.md part 5): what a potion (and later an upgrade, an attachment or
## a boon) does, written in data as entries {"type", "target", ...} (content/recipes effects, balance.json bag.use).
## Static functions only, one small piece per type; it keeps no state (a running effect lives in its target's Effects
## holder, parts/effects_holder.gd).
## Used by: the Use-potion command (commands/use_potion.gd), the Ride command and the mount (hud_potion, for their
## words), the HUD's potion buttons (hud_potion), the tests.
## Uses: main (main.player and main.mount, and their Effects holders), Data (the cat's max health, balance.json
## potions.hud, the names).
## Types (H3):
##   heal            at once, maxi(1, roundi(max * share)) points. The target must be standing and hurt.
##   heal_over_time  the same total, handed out evenly over `seconds` by the target's holder. The target must be standing
##                   and hurt, and nothing from the same source may be running there ("Already active").
##   stat_mult       the target's `stat` becomes x (1 + mult) for `seconds` (the cat's holder hands Data its map:
##                   Data.effect_mult). Refused while the same source is running.
##   revive          a knocked-out mount (resting > 0) gets up with `share` of its health (mount.revive).
## Fields: type; target "cat" (main.player, max health Data.cat_max_hp()) or "mount" (main.mount, its max_hp()); share
## (of the target's max health); stat and mult; seconds. The mount is missing only when main.mount is null: a ruined
## stall stops nothing (a revive then brings the mount to the cat instead of being ridden).
## reason() is "" when the effect can act now, else one of: "Full health", "The mount is at full health", "Knocked out:
## use a <Mount Health Potion>", "Only for a knocked-out mount", "The mount is not here", "Already active", "The cat is
## down", "Can't be used" (a type or target this list does not know).

const TYPES := ["heal", "heal_over_time", "stat_mult", "revive"]   # the types built here (one piece each, below)


## This list knows the type (the content test checks every entry's effects with it, in --bag).
static func known(type: String) -> bool:
	return TYPES.has(type)


## Why effect e cannot act now ("" when it can). source: what it comes from (the item id): the holder runs one
## effect per source.
static func reason(e: Dictionary, main: Node3D, source: String) -> String:
	var type := String(e.get("type", ""))
	var target := String(e.get("target", "cat"))
	if not known(type) or not (target == "cat" or target == "mount"):
		return "Can't be used"
	if target == "mount" and main.get("mount") == null:
		return "The mount is not here"
	match type:
		"revive":
			if target != "mount":
				return "Can't be used"                          # H3: only a mount gets back up this way
			return "" if main.mount.resting > 0.0 else "Only for a knocked-out mount"
		"heal", "heal_over_time":
			var why := _not_hurt(target, main)
			if why != "":
				return why
			if type == "heal_over_time" and _holder(target, main) == null:
				return "Can't be used"
			if type == "heal_over_time" and _holder(target, main).has_source(source):
				return "Already active"
			return ""
		"stat_mult":
			var down := _down(target, main)
			if down != "":
				return down
			if _holder(target, main) == null:
				return "Can't be used"
			if _holder(target, main).has_source(source):
				return "Already active"
			return ""
	return "Can't be used"


## Does effect e (when it can act now: reason() is "").
static func apply(e: Dictionary, main: Node3D, source: String) -> void:
	if reason(e, main, source) != "":
		return
	var target := String(e.get("target", "cat"))
	match String(e.get("type", "")):
		"heal":
			var pts := maxi(1, roundi(float(_max_hp(target, main)) * float(e.get("share", 0.0))))
			if target == "cat":
				main.player.heal(pts)
			else:
				main.mount.heal(pts)
		"heal_over_time", "stat_mult":
			_holder(target, main).add(e, source)
		"revive":
			main.mount.revive(float(e.get("share", 0.0)))


## The potion a HUD potion button uses (balance.json potions.hud): slot "cat" (the Health Potion) or "mount" (the Mount
## Health Potion). "" when data names none.
static func hud_potion(slot: String) -> String:
	var p: Variant = Data.b.get("potions", {})
	if not p is Dictionary:
		return ""
	var h: Variant = (p as Dictionary).get("hud", {})
	return String((h as Dictionary).get(slot, "")) if h is Dictionary else ""


# ---------------------------------------------------------------- inside
static func _holder(target: String, main: Node3D) -> Node:
	var who: Variant = main.player if target == "cat" else main.get("mount")
	if who == null:
		return null
	return who.get("effects") as Node


static func _max_hp(target: String, main: Node3D) -> int:
	return Data.cat_max_hp() if target == "cat" else int(main.mount.max_hp())


## The target is down: the cat at 0 health, or the mount knocked out. "" when it stands.
static func _down(target: String, main: Node3D) -> String:
	if target == "cat":
		return "The cat is down" if int(main.player.hp) <= 0 else ""
	if float(main.mount.resting) > 0.0 or int(main.mount.hp) <= 0:
		var potion := hud_potion("mount")
		return ("Knocked out: use a %s" % Data.item_name(potion, 1)) if potion != "" else "Knocked out"
	return ""


## A heal needs the target standing and hurt: "" when it is, else why not.
static func _not_hurt(target: String, main: Node3D) -> String:
	var down := _down(target, main)
	if down != "":
		return down
	if target == "cat":
		return "Full health" if int(main.player.hp) >= Data.cat_max_hp() else ""
	return "The mount is at full health" if int(main.mount.hp) >= int(main.mount.max_hp()) else ""
