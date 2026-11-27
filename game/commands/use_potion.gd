extends "res://commands/command.gd"
## Use one potion (or a fish) from the Bag (H3, 26 Nov 2026; docs/ARCHITECTURE.md part 4, Command). The HUD's potion
## buttons (ui/hud/action_buttons.gd), the Bag's Use button (inventory.gd) and the tests all send this same command:
## UsePotion.new(id).can_run(main) / .run(main), with UsePotion = preload("res://commands/use_potion.gd").
## Uses: Bag (the count, the effects, take), Effects (reason, apply), main (frozen, the cat, the mount), Fx and Sfx.
## Rules:
##   - can_run checks, in this order: "None in the Bag"; "Can't be used" (no effects); "Wait a moment" (the game or the
##     cat is frozen); "The cat is down"; then, when every effect has a reason from Effects.reason, the first one
##     ("Full health", "Only for a knocked-out mount", "The mount is not here", "Knocked out: use a Mount Health
##     Potion", "Already active", "The mount is at full health"). "" means it can run.
##   - run takes one from the Bag and does every effect that can act now (the item id is the effects' source), with
##     hearts or a sparkle and the "pluck" sound. It never calls main.hud and never saves: Bag.take marks the save
##     dirty, and the caller shows a refusal.

var id: String


func _init(item_id: String) -> void:
	id = item_id


func can_run(main: Node3D) -> String:
	if Bag.count(id) <= 0:
		return "None in the Bag"
	var effs := Bag.effects(id)
	if effs.is_empty():
		return "Can't be used"
	if bool(main.frozen) or bool(main.player.frozen):
		return "Wait a moment"
	if int(main.player.hp) <= 0:
		return "The cat is down"
	var first := ""
	for e: Variant in effs:
		var why := Effects.reason(e as Dictionary, main, id) if e is Dictionary else "Can't be used"
		if why == "":
			return ""
		if first == "":
			first = why
	return first


func run(main: Node3D) -> bool:
	if can_run(main) != "":
		return false
	var acting: Array = []
	for e: Variant in Bag.effects(id):
		if e is Dictionary and Effects.reason(e as Dictionary, main, id) == "":
			acting.append(e)
	if acting.is_empty() or not Bag.take(id, 1):
		return false
	for e: Variant in acting:
		Effects.apply(e as Dictionary, main, id)
		_show(e as Dictionary, main)
	Sfx.play("pluck", -4.0)
	return true


## Hearts over the one it mends or brings back, a sparkle on the cat for the rest.
func _show(e: Dictionary, main: Node3D) -> void:
	var type := String(e.get("type", ""))
	if String(e.get("target", "cat")) == "mount" and main.get("mount") != null:
		Fx.hearts(main, main.mount.global_position + Vector3(0, 1.0, 0))
		if type == "revive":
			Fx.sparkle(main, main.player.global_position + Vector3(0, 1.0, 0))
	elif type == "stat_mult":
		Fx.sparkle(main, main.player.global_position + Vector3(0, 1.0, 0))
	else:
		Fx.hearts(main, main.player.global_position + Vector3(0, 1.2, 0))
