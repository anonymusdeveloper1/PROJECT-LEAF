extends "res://commands/command.gd"
## Mount, dismount or toggle the cat's ride.

const MOUNT_UNAVAILABLE := "The mount is unavailable"

var want: int
var quiet: bool


func _init(request: int = -1, silent: bool = false) -> void:
	want = request
	quiet = silent


func _wants_ride(main: Node3D) -> bool:
	return want == 1 or (want == -1 and not main.player.riding)


func can_run(main: Node3D) -> String:
	if not _wants_ride(main):
		return ""
	if main.mount == null or Save.ruined.has("stall"):
		return MOUNT_UNAVAILABLE
	if main.mount.resting > 0.0:
		if main.fight.active or main.area != null:            # H3: the Mount Health Potion replaces Feed
			return "%s is knocked out: use a %s" % [Data.mount_name(), Data.item_name(Effects.hud_potion("mount"), 1)]
		return "%s is resting: %d s" % [Data.mount_name(), int(ceil(main.mount.resting))]
	return ""


func run(main: Node3D) -> bool:
	var reason := can_run(main)
	if not quiet and reason != "" and reason != MOUNT_UNAVAILABLE:
		main.hud.toast(reason)
	# A refused ride still puts the cat on foot if it was already riding.
	var on := _wants_ride(main) and reason == ""
	if on == main.player.riding:
		return false
	main.player.riding = on
	Save.riding = on
	Save.save_game()
	if on:
		main.mount.come_to(main.player.global_position)
		if not quiet and not Save.flag("told_ride"):
			Save.set_flag("told_ride")
			main.hud.tip("Riding %s: faster, and it takes the hits for you. Drag to steer. The cat shoots around you; turn for enemies directly behind." % Data.mount_name(), null)
	else:
		Fx.dust(main, main.player.global_position, 6, 1.0)
	Events.riding_changed.emit(on)
	return true
