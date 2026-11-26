extends RefCounted
## H3: the garden's window, shown inside the garden's card as a row {"kind": "window", "window": hud.garden_window}
## (stations._card_garden; card.gd draws it and calls the visit hooks; hud.gd ticks it while it shows).
## STUB (H3 Stage 1, so the game parses): Stage 2 (P3b) fills it in as the build map's part 3.7 says: the 6 plots as on
## the bed (plot 3 2 1 over 6 5 4), the seeds to drag onto an empty plot (ui/kit/drag_source.gd, drop_slot.gd), Water,
## and a tap on a ripe plot to pick it. It holds no game rules: every rule is in garden.gd (main.garden).
##
## The window API (the same for every window in a card):
##   content()  builds the whole window from Save and Timers; it runs on every rebuild of the card, so it must be safe
##              to call again at any time
##   tick(d)    every frame while the window shows
##   opened()   once per visit, just before that visit's first content()
##   closed()   once, when the card closes or another card replaces it (never on a rebuild or a wave blank)

var hud                                 # the HUD node (untyped on purpose, as in the HUD's parts)
var main


func _init(owner_hud) -> void:
	hud = owner_hud
	main = hud.main


func content() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return box


func tick(_delta: float) -> void:
	pass


## A new visit to the garden: garden.gd counts the Gloom bump once per visit that picks something (map 3.7).
func opened() -> void:
	if main != null and main.garden != null and main.garden.has_method("window_opened"):
		main.garden.window_opened()


func closed() -> void:
	pass
