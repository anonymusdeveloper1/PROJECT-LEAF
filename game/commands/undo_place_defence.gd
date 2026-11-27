extends "res://commands/command.gd"
## Take back the last tower or patch of spikes placed in this placing visit (H6, Stage 1; docs/ARCHITECTURE.md part 4,
## Command): UndoPlaceDefence.new(id).can_run(main) / .run(main). The piece goes back to the Bag at the record it was
## paid with, once, even into a full Bag. Rules:
##   - can_run is defences.undo_reason(id): "" or the refusal in words (nothing to undo, the piece is no longer the
##     last one placed, a wave began, or the cat is below ground).
##   - run checks can_run, then defences.revert_placement(id).
##   - It never saves and never calls the HUD: the caller saves.

var id: int


func _init(piece_id: int) -> void:
	id = piece_id


func can_run(main: Node3D) -> String:
	return main.defences.undo_reason(id)


func run(main: Node3D) -> bool:
	if can_run(main) != "":
		return false
	return main.defences.revert_placement(id)
