extends "res://commands/command.gd"
## Place one tower or patch of spikes from the Bag (H6, Stage 1; docs/ARCHITECTURE.md part 4, Command). The Place button
## (through scripts/defence_placement.gd) and the tests send this same command:
## PlaceDefence.new(kind, at, yaw).can_run(main) / .run(main), with PlaceDefence = preload("res://commands/place_defence.gd").
## Rules:
##   - can_run is defences.placement_reason(kind, at): "" or the refusal in words.
##   - run checks can_run, then defences.commit_placement(kind, at, yaw); placed_id is the new piece's id after a
##     successful run (-1 before, and after a refusal).
##   - It never saves and never calls the HUD: the caller saves and shows a refusal.

var kind: String
var at: Vector3
var yaw: float
var placed_id := -1


func _init(piece_kind: String, spot: Vector3, rotation_y: float) -> void:
	kind = piece_kind
	at = spot
	yaw = rotation_y


func can_run(main: Node3D) -> String:
	return main.defences.placement_reason(kind, at)


func run(main: Node3D) -> bool:
	placed_id = -1
	if can_run(main) != "":
		return false
	placed_id = main.defences.commit_placement(kind, at, yaw)
	return placed_id >= 0
