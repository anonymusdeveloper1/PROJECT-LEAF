extends "res://ui/windows/building_window.gd"
## H4: the Tailor's Nook's window (building and marker "tailor": the cat's outfits, 23 Nov 2026). Moved from stations.gd
## (_card_tailor, _skin_tile) in H4 Stage 1, looking exactly as before (H5 rebuilds it): one tile per outfit
## (balance.json cat_skins, in its order: the original first), in the shop-tile style, one button each. Outfits are
## looks only: they change no number.
##   the one she wears      "Wearing" (no working button); badge "Wearing"
##   owned, not worn        "Wear" (free); off while a mission or raid wave is on, the line then "Between waves"; badge
##                          "Owned"
##   not owned              "Buy" and its price (balance.json price in its currency, today leaves); the line "Needs
##                          <price>" when she cannot pay it. A missing model or a currency the game cannot take yet
##                          leaves Buy off ("Coming later"). She puts it on at once between waves. A mid-wave purchase
##                          waits for Wear.
## A tile shows res://assets/ui/cat_skins/<id>.png (row key "picture") when that picture exists, else the outfit icon.
## One level: no upgrade shelf. Knocked down: only the ruin card.
## Used by: ui/windows/window_list.gd (hud.windows["tailor"]), stations.gd (the marker's builder; _card_tailor for the
##          tests in Stage 1).
## Uses: Data (cat_skin_ids, cat_skin, cat_skin_name, cat_skin_owned, cat_skin_cost, cat_skin_buyable,
##       cat_skin_picture), the rules in stations.gd (_buy_skin, _wear_skin, _locked), the base's tiles.


func _init(owner_hud) -> void:
	super(owner_hud, "tailor", "tailor")


func spec() -> Dictionary:
	return _card_tailor()


func _card_tailor() -> Dictionary:
	var title: String = st._name("tailor")
	if Save.ruined.has("tailor"):
		return _ruin_card("tailor", title, _anchor("tailor", 2.0))
	var rows: Array = _wear_row("tailor")
	var tiles: Array = []
	for sk in Data.cat_skin_ids():
		tiles.append(_skin_tile(String(sk)))
	_add_section(rows, "Outfits", tiles)
	return {"title": title, "sub": "Outfits for the cat · looks only, no strength", "rows": rows, "anchor": _anchor("tailor", 2.0)}


## One outfit's tile on the Tailor's Nook (see the top of this file).
func _skin_tile(sk: String) -> Dictionary:
	var info := Data.cat_skin(sk)
	var nm := Data.cat_skin_name(sk)
	var says := String(info.get("short", ""))
	var t: Dictionary
	if Save.cat_skin == sk:
		t = _tile("outfit", nm, says, {}, "Wearing", false, Callable(), "Wearing")
	elif Data.cat_skin_owned(sk):
		var mid: bool = st._locked()                         # a wave is on: outfits are changed between waves
		t = _tile("outfit", nm, "Between waves" if mid else says, {}, "Wear", not mid, st._wear_skin.bind(sk), "Owned")
	else:
		var cost := Data.cat_skin_cost(sk)
		var buyable := Data.cat_skin_buyable(sk)
		var note := says
		if not buyable:
			note = "Coming later"
		elif not Data.can_afford(cost):
			note = "Needs %s" % _price_words(cost)
		t = _tile("outfit", nm, note, cost, "Buy", buyable, st._buy_skin.bind(sk), "New")
	var pic := Data.cat_skin_picture(sk)
	if ResourceLoader.exists(pic):
		t["picture"] = pic
	return t
