extends RefCounted
## H4: the build menu (the build icon next to the Bag; in hud.windows under "build", not a marker). It opens through
## the card like the Settings window: it has a `key` and a `builder`, and its one row is a {"kind": "window"} row (this
## object), so the card draws content() and calls tick, opened and closed.
## H4 Stage 1: a stub with the build menu's API (docs: the H4 map, 3.15), not used yet (the build icon still opens the
## Hearthtree's Buildings shelf). Stage 2 (P2d) fills it: the grid of building pictures (ui/kit/icon_grid.gd), the
## detail view with Build, entries() and pulse().
## Used by: ui/windows/window_list.gd (made with the building windows); from Stage 2 the build icon
##          (ui/hud/action_buttons.gd), the Hearthtree's goals (open_at) and the tests.
## Uses: Data (the menu buildings and the words, Data.word).

var hud                                 # the HUD node (untyped on purpose, as in the HUD's parts)
var main
var key := "build"                      # not exempt from the wave blank: a wave blanks it, as every station card
var builder: Callable = spec            # a ring in the card system has a builder (this has no marker)
var _detail := ""                       # the building whose detail view shows ("" = the grid)


func _init(owner_hud) -> void:
	hud = owner_hud
	main = hud.main if hud != null else null


## The card: the menu's title and its one window row; while the Hearthtree is in ruins only "Repair the Hearthtree
## first" (nothing can be built then, as today).
func spec() -> Dictionary:
	if Save.ruined.has("home"):
		return {"title": String(Data.word("build_title")), "sub": "", "anchor": Vector3.ZERO,
			"rows": [{"text": String(Data.word("build_ruined")) % Data.camp_name()}]}
	return {"title": String(Data.word("build_title")), "sub": "", "anchor": Vector3.ZERO,
		"rows": [{"kind": "window", "window": self, "enabled": true}]}


func open() -> void:
	if hud != null:
		hud.show_card(self)


## The build icon's tap: close the menu when it is open, else open it.
func toggle() -> void:
	if hud == null:
		return
	if hud.card_ring() == self:
		hud.hide_card()
	else:
		open()


## Opens the menu at building `id`'s detail view (a goal's Show). The card does not reopen the card already open
## (card.gd show_card), so an open menu only redraws.
func open_at(id: String) -> void:
	_detail = id
	if hud != null and hud.card_ring() == self:
		hud.refresh_card()
	else:
		open()


## What the grid shows now: [{"id", "name", "state": "open" | "locked", "needs", "price"}]. Stage 1: nothing yet.
func entries() -> Array:
	return []


## The build icon's "!": an open entry whose price can be paid. Stage 1: never.
func pulse() -> bool:
	return false


## The window row's contents (the card calls it on every rebuild). Stage 1: the empty menu's one line.
func content() -> Control:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l := Label.new()
	l.text = String(Data.word("build_empty"))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(l)
	return box


func tick(_delta: float) -> void:
	pass


## A visit starts (the card, just before its first content()).
func opened() -> void:
	pass


## The visit ends: the next visit starts on the grid.
func closed() -> void:
	_detail = ""
