extends "res://ui/windows/building_window.gd"
## H5: the Tailor's Nook's window (building and marker "tailor": the cat's outfits, 23 Nov 2026; rebuilt in H5 to the
## owner's picture 1). Outfits are looks only: they change no number. The card is one window row (ui/windows/
## outfit_preview.gd draws it): the cat big on a low stand, turning slowly, dressed in the outfit TRIED ON; under her the
## name, the state or price and ONE button; the outfit cards in a grid; Back.
##   A tap on any card (also a grey one, an outfit not owned yet) tries it on: only the picture changes. Nothing is
##   written to the save and the live cat keeps her model, her stats and her money. A visit opens on the outfit she wears.
##   the one she wears      "Wearing" (grey, no working button)
##   owned, not worn        "Wear" (free); off while a mission or raid wave is on, the line then "Between waves"
##   not owned              "Buy" and its price (the line turns red when she cannot pay); a missing model or a currency
##                          the game cannot take yet leaves Buy off ("Coming later"). Buy runs the rule in stations.gd
##                          (_buy_skin), which puts it on at once between waves; a mid-wave purchase waits for Wear.
## One level: no upgrade shelf. "Patch it up" over the picture when raids wore it. Knocked down: only the ruin card.
## Names the tests and other parts call: entries(), try_on(id), selected_id(), state(id), back(), pulse().
## Used by: ui/windows/window_list.gd (hud.windows["tailor"]), stations.gd (the marker's builder and its "!"), the tests.
## Uses: ui/windows/outfit_preview.gd, Data (cat_skin_ids, cat_skin, cat_skin_name, cat_skin_owned, cat_skin_cost,
##       cat_skin_buyable, cat_skin_picture), Save.cat_skin, the rules in stations.gd (_buy_skin, _wear_skin, _locked),
##       the base's helpers.

const OutfitPreview := preload("res://ui/windows/outfit_preview.gd")

var _sel := ""                          # the outfit tried on ("" = the one she wears); every visit starts on hers
var _preview: OutfitPreview             # the picture and the layout: the card's window row


func _init(owner_hud) -> void:
	super(owner_hud, "tailor", "tailor")
	_preview = OutfitPreview.new(self)


## The card now: the ruin card, or the Nook's one window row (with "Patch it up" over it when raids wore it).
func spec() -> Dictionary:
	var title: String = st._name("tailor")
	if Save.ruined.has("tailor"):
		return _ruin_card("tailor", title, _anchor("tailor", 2.0))
	var rows: Array = as_list(_wear_row("tailor"))
	rows.append({"kind": "window", "window": _preview, "enabled": true})
	return {"title": title, "sub": "Outfits for the cat · looks only, no strength", "rows": rows, "anchor": _anchor("tailor", 2.0)}


## The marker's "!": an outfit she can buy now (not owned, sold, the price in hand), or "Patch it up".
func pulse() -> bool:
	if Save.ruined.has(id):
		return super()
	for sk in Data.cat_skin_ids():
		var s := state(String(sk))
		if String(s["kind"]) == "new" and bool(s["enabled"]):
			return true
	return super()


## A visit always starts on the outfit she wears (the picture's closed() frees its 3D view).
func card_opened() -> void:
	_sel = ""


func card_closed() -> void:
	_sel = ""


# ---------------------------------------------------------------- the outfit tried on
## The outfit the picture shows: the one tried on, else (also when it is gone from the game) the one she wears.
func selected_id() -> String:
	if _sel != "" and Data.cat_skin_ids().has(_sel):
		return _sel
	return Save.cat_skin if Data.cat_skin_ids().has(Save.cat_skin) else String(Data.cat_skin_ids()[0])


## Tries outfit id on: the picture dresses in it (even one not owned). The save and the live cat do not change.
func try_on(outfit_id: String) -> void:
	if not Data.cat_skin_ids().has(outfit_id):
		return
	_sel = outfit_id
	hud.refresh_card()


## Back: the Nook closes (the camp shows again; the picture's visit ends and its 3D view goes).
func back() -> void:
	hud.hide_card()


## The picture's view of its 3D world and what it shows (the tests read them).
func preview() -> OutfitPreview:
	return _preview


# ---------------------------------------------------------------- the grid and the one button
## The outfit cards, in the content order (the original first): {"id", "title", "icon", "picture" (when its file is
## there), "cost" ({} once owned), "note" ("Wearing", "Owned", "Coming later"), "grey" (not owned), "locked": false,
## "selected" (the one tried on)}. Every card can be tapped (try_on).
func entries() -> Array:
	var out: Array = []
	var sel := selected_id()
	for sk in Data.cat_skin_ids():
		var oid := String(sk)
		var s := state(oid)
		var cell := {"id": oid, "title": String(s["name"]), "icon": "outfit", "cost": s["cost"], "note": s["note"],
			"grey": String(s["kind"]) == "new", "locked": false, "selected": oid == sel}
		if String(s["kind"]) == "worn":
			cell["note"] = _w("wearing")
		elif String(s["kind"]) == "owned":
			cell["note"] = _w("owned") if not st._locked() else _w("between_waves")
		var pic := Data.cat_skin_picture(oid)
		if ResourceLoader.exists(pic):
			cell["picture"] = pic
		out.append(cell)
	return out


## What the Nook says and offers for outfit id, whatever she wears: {"id", "name", "short", "kind" ("worn", "owned",
## "new"), "cost", "label" (the one button: Wearing, Wear, Buy), "enabled", "note" (the line under the name when there is
## no price to show), "action"}.
func state(outfit_id: String) -> Dictionary:
	var info := Data.cat_skin(outfit_id)
	var s := {"id": outfit_id, "name": Data.cat_skin_name(outfit_id), "short": String(info.get("short", "")), "kind": "new",
		"cost": {}, "label": "", "enabled": false, "note": "", "buyable": false, "action": Callable()}
	if Save.cat_skin == outfit_id:
		s["kind"] = "worn"
		s["label"] = _w("wearing")
		s["note"] = _w("wearing")
	elif Data.cat_skin_owned(outfit_id):
		var mid: bool = st._locked()                         # a wave is on: outfits are changed between waves
		s["kind"] = "owned"
		s["label"] = _w("wear")
		s["enabled"] = not mid and not Save.ruined.has("tailor")
		s["note"] = _w("between_waves") if mid else _w("owned")
		s["action"] = st._wear_skin.bind(outfit_id)
	else:
		var cost := Data.cat_skin_cost(outfit_id)
		var buyable := Data.cat_skin_buyable(outfit_id)
		s["cost"] = cost
		s["buyable"] = buyable
		s["label"] = _w("buy")
		s["enabled"] = buyable and Data.can_afford(cost) and not Save.ruined.has("tailor")
		s["note"] = _w("coming_later") if not buyable else (_w("needs") % _price_words(cost) if not Data.can_afford(cost) else String(s["short"]))
		s["action"] = st._buy_skin.bind(outfit_id)
	return s
