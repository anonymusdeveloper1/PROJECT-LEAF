extends RefCounted
## H4: the list of the building windows (ui/windows/): one window object per building, keyed by its marker's id in
## stations.rings ("shop" is the Hearthtree's), plus the build menu and the two defence card builders.
## hud.gd makes them once. stations.use_windows plugs the building windows into their markers.
## A known list of names in code (docs/ARCHITECTURE.md house rule 3): it is the one place that names the windows until
## the building entries (content/buildings/) say which window each one has.
## H5 (27 Nov 2026): the Mushroom Cottage's window is gone with the Cottage (its pet is sold and trained at the Market's
## Pets tab).
## Used by: ui/hud/hud.gd build().
## Uses: every window file below.

const WINDOWS := {
	"shop": preload("res://ui/windows/hearthtree_window.gd"),
	"target": preload("res://ui/windows/target_window.gd"),
	"bench": preload("res://ui/windows/bow_shop_window.gd"),
	"well": preload("res://ui/windows/well_window.gd"),
	"stone": preload("res://ui/windows/stone_window.gd"),
	"garden": preload("res://ui/windows/garden_card.gd"),
	"stall": preload("res://ui/windows/market_window.gd"),
	"saddlery": preload("res://ui/windows/saddlery_window.gd"),
	"tailor": preload("res://ui/windows/tailor_window.gd"),
	"workshop": preload("res://ui/windows/workshop_window.gd"),
	"fishing": preload("res://ui/windows/fishing_window.gd"),
	"build": preload("res://ui/windows/build_menu_window.gd"),
	"defence_piece": preload("res://ui/windows/defence_piece_window.gd"),
	"defence_pad": preload("res://ui/windows/defence_pad_window.gd"),
}


## Every window, keyed by id for the HUD.
static func make_all(hud) -> Dictionary:
	var out: Dictionary = {}
	for rid in WINDOWS:
		out[rid] = (WINDOWS[rid] as GDScript).new(hud)
	return out
