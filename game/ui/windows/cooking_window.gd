extends RefCounted
## H3: the cooking pot's window, shown inside the pot's card as a row {"kind": "window", "window": hud.cooking_window}
## (stations._card_pot; card.gd draws it and calls the visit hooks; hud.gd ticks it while it shows).
## STUB (H3 Stage 1, so the game parses): Stage 2 (P4b) fills it in as the build map's part 3.8 says: the pot's slots
## to drag ingredients into (ui/kit/drag_source.gd, drop_slot.gd), Cook when they make a recipe, the bar while it
## cooks, and Collect. It holds no game rules: every rule is in cooking.gd (main.cooking).
##
## The window API (the same for every window in a card):
##   content()  builds the whole window from Save, Timers and the slots; it runs on every rebuild of the card, so it
##              must be safe to call again at any time
##   tick(d)    every frame while the window shows
##   opened()   once per visit, just before that visit's first content()
##   closed()   once, when the card closes or another card replaces it (never on a rebuild or a wave blank): the slots
##              empty here

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


func opened() -> void:
	pass


func closed() -> void:
	pass
