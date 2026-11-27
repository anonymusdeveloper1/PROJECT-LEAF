extends RefCounted
## H5 (Stage 2): the Market's Mounts and Pets tabs (ui/windows/market_window.gd; the H5 map parts 1 and 3.4, the
## owner's answers Q1 B and Q2 A). Every mount rides alike and every pet fights alike: a look changes only how it looks.
##   Mounts  the Ride/Walk row (the mount's speed, and how many skills sit in its circles), a grid of the mounts' whole
##           pictures, then the colours of the mount out now (Next), its Gloomlit colours (earned with Gloom shards) and
##           the expedition gear for the mount (Thunder Shoes, once the Gloomwood is open)
##   Pets    once the pet is owned: its training row (its level, its sparks now and next, Train with the old Mushroom
##           Cottage's price, never above the Hearthtree's level); the grid of the pets' whole pictures; then, once the
##           pet is owned, its colours, Gloomlit colours and expedition gear
## A grid cell: the look's whole picture, its name, then "Equipped" (out now), "Included" or "Owned" with Use (one tap),
## or its price with Buy (one tap). A look not owned is grey. Sprig costs 160 leaves and brings the pet; Lumi (looks
## only, 400 leaves) says "Buy Sprig first" until the pet is owned. A tap on a picture opens its detail view in this
## window: the picture bigger, its name and what it is, what it does now, its price or state, Back and the same action.
## It is the card's window row on those two tabs ({"kind": "window"}, card.gd: content, tick, opened, closed); the rows
## around it are list rows (ui/kit/list_row.gd) made with the Market window's list_row.
## The rules stay in stations.gd (the window only says which, and checks the Buy command's can_run to draw a button on
## or off): Use is stations._use_look (CompanionShop.choose), Buy is stations._buy_companion (CompanionShop.buy: the Buy
## command, then the first pet joins the cat), Train is stations._train_pet (the Buy command "pet_training"), Next is
## stations._next_skin, a Gloomlit colour stations._unlock_skin, and expedition gear stations._buy_attach and _wear.
## Each of them saves, gives the receipt and refreshes the camp (main.on_purchase).
## Used by: ui/windows/market_window.gd (companions), the tests (entries, look_state, detail_lines, sparks, inspect).
## Uses: commands/buy.gd (can_run, price, next level), scripts/market_trade.gd (short_of, MARKET), ui/kit/icon_grid.gd,
##       ui/kit/card_parts.gd, market_words.gd, Data, Save, main (mount, player, toggle_ride), stations.gd (_use_look,
##       _buy_companion, _train_pet, _skins, _skin_id, _skin_unlock, _next_skin, _unlock_skin, _buy_attach, _wear,
##       _name).

const IconGrid := preload("res://ui/kit/icon_grid.gd")
const CardParts := preload("res://ui/kit/card_parts.gd")
const ShopTiles := preload("res://ui/hud/shop_tiles.gd")   # the type of the HUD's tiles (hud.p_tiles)
const Buy := preload("res://commands/buy.gd")
const MarketTrade := preload("res://scripts/market_trade.gd")
const Words := preload("res://ui/windows/market_words.gd")

const KINDS := {"mount": "mounts", "pet": "pets"}        # a companion slot -> its content kind
const TAB_SLOT := {"mounts": "mount", "pets": "pet"}      # a Market tab -> the slot it shows
const DETAIL_PIC := 200.0               # the detail view's picture (the build menu's)
const DETAIL_PAD := 8.0                 # the soft square behind it is this much bigger on each side
const BTN := Vector2(220, 64)           # the detail view's Back and action
const SOFT_INK := Color(0.45, 0.36, 0.26)

var hud                                 # the HUD node (untyped on purpose, as in the HUD's parts)
var main
var st                                  # main.stations: the old rules (colours, gear) live there
var _market: WeakRef                    # the Market's window (weak: it holds this tab)
var detail := ""                        # the look whose detail view shows ("" = the grid)
var detail_slot := ""                   # ... and its slot


func _init(market) -> void:
	_market = weakref(market)
	hud = market.hud
	main = market.main
	st = market.st


## The slot the Market's window shows now: "mount" on the Mounts tab, "pet" on the Pets tab.
func current_slot() -> String:
	var m = _market.get_ref()
	return String(TAB_SLOT.get(String(m.tab) if m != null else "", "mount"))


## A tab's rows: the detail view alone while a look is looked at; else the rows over the grid, the grid (this window),
## and the rows under it.
func rows(slot: String) -> Array:
	var me := {"kind": "window", "window": self, "enabled": true}
	if detail != "" and detail_slot == slot:
		return [me]
	var out: Array = _rows_over(slot)
	out.append(me)
	out.append_array(_rows_under(slot))
	return out


## Something on the tab can be bought now (the tab's "!" dot and the marker's): a Buy in the grid, Train, a Gloomlit
## colour or a piece of gear, each with its price affordable. Use, Ride and Next are free and quiet.
func lights(slot: String) -> bool:
	for c: Dictionary in entries(slot):
		if String(c.get("label", "")) != "" and bool(c.get("enabled", false)) and not (c.get("cost", {}) as Dictionary).is_empty():
			return true
	var m = _market.get_ref()
	if m == null:
		return false
	for r: Variant in _rows_over(slot) + _rows_under(slot):
		if m._lights(r):
			return true
	return false


## The slot's companion is owned: a mount (with the Market or a carried tier), the pet (bought, or an old Cottage's).
func has_slot(slot: String) -> bool:
	return Data.pet_level() > 0 if slot == "pet" else Data.mount_level() > 0


func _rows_over(slot: String) -> Array:
	if slot == "mount":
		return [ride_row()]
	return [training_row()] if has_slot("pet") else []


func _rows_under(slot: String) -> Array:
	if not has_slot(slot):
		return []
	var out: Array = [colour_row(slot)]
	out.append_array(gloomlit_rows(slot))
	out.append_array(gear_rows(slot))
	return out


# ---------------------------------------------------------------- the grid of looks
## The grid's cells of a slot, in the catalogue's order: {"id", "title" (its short name), "picture", "icon", "cost",
## "note", "label", "enabled" (with the price), "action", "grey" (not owned), "out" (the look out now)}.
func entries(slot: String) -> Array:
	var out: Array = []
	var kind := String(KINDS.get(slot, ""))
	for e: Dictionary in Data.shop_entries(kind):
		var lid := String(e["id"])
		var s := look_state(slot, lid)
		out.append({"id": lid, "title": _short(e), "picture": Data.shop_picture(kind, lid), "icon": String(e.get("icon", slot)),
			"cost": s["cost"], "note": s["note"], "label": s["label"], "enabled": s["enabled"], "action": s["action"],
			"grey": not bool(s["owned"]), "out": bool(s["out"]), "badge": s["badge"]})
	return out


## What a look shows and does now (the cell and the detail view share it): {"owned", "out", "badge", "note", "cost",
## "label", "enabled" (with the price), "action"}.
##   out now                  "Equipped", no button
##   owned                    "Included" (comes with the Market) or "Owned", and Use
##   for sale                 its price and Buy (on when it can be paid)
##   not for sale now         why not ("Buy Sprig first", "Coming later"), no button
func look_state(slot: String, lid: String) -> Dictionary:
	var kind := String(KINDS.get(slot, ""))
	var s := {"owned": false, "out": false, "badge": "", "note": "", "cost": {}, "label": "", "enabled": false,
		"action": Callable()}
	var e := Data.shop_entry(kind, lid)
	if e.is_empty():
		return s
	var owned := Data.owned_level(kind, lid) >= 1
	var pet_ok := slot != "pet" or Data.pet_level() >= 1
	s["owned"] = owned
	if owned and pet_ok and _look_in(slot) == lid:
		s["out"] = true
		s["note"] = Words.say("equipped")
		s["badge"] = s["note"]
		return s
	if owned:
		var free: bool = e.get("price") is Dictionary and (e["price"] as Dictionary).is_empty()
		s["note"] = Words.say("included" if free else "owned")
		s["badge"] = s["note"]
		s["label"] = Words.say("use")
		s["enabled"] = pet_ok
		s["action"] = st._use_look.bind(slot, lid)
		return s
	var b := Buy.new(kind, lid, 1, 1)
	var price: Dictionary = b.price()
	var why: String = b.can_run(main)
	if why == "" or (not price.is_empty() and why == MarketTrade.short_of(price)):
		s["cost"] = price
		s["badge"] = Words.say("new")
		s["label"] = Words.say("buy")
		s["enabled"] = Data.can_afford(price)
		s["action"] = st._buy_companion.bind(slot, lid, b.next_level())
	else:
		s["note"] = why
	return s


## The detail view's lines under its name and what it is: a mount's speed and health now (every mount the same), a
## pet's sparks at its level (level 1 before it is owned), then that a look changes only how it looks.
func detail_lines(slot: String) -> Array:
	var m = _market.get_ref()
	if slot == "mount":
		var lv := maxi(Data.mount_level(), 1)
		var pct: String = m._short_num((Data.mount_speed_at(lv) - 1.0) * 100.0) if m != null else ""
		return [Words.say("mount_speed_hp") % [Data.mount_name(), pct, roundi(Data.mount_base_hp_at(lv) * Data.mount_hp_mult())],
			Words.say("mount_same")]
	return [sparks(maxi(Data.pet_level(), 1)), Words.say("pet_same")]


# ---------------------------------------------------------------- the rows over and under the grid
## Ride / Get off: the mount's speed and its skills in use, or that it goes back to the Market.
func ride_row() -> Dictionary:
	var m = _market.get_ref()
	var riding: bool = main.player.riding
	var mn := Data.mount_name()
	var note := ""
	if riding:
		note = Words.say("ride_back") % [mn, st._name(MarketTrade.MARKET)]
	else:
		note = Words.say("ride_note") % m._short_num((Data.mount_speed_at(maxi(Data.mount_level(), 1)) - 1.0) * 100.0)
		var slotted := 0
		for sid: String in Data.skill_slots():
			if sid != "":
				slotted += 1
		if slotted > 0:
			note += " · " + Words.say("ride_skills") % slotted
	var r: Dictionary = m.list_row("mount", Words.say("get_off" if riding else "ride_mount") % mn, note, {},
		Words.say("walk" if riding else "ride"), main.mount != null, main.toggle_ride, "", "ride")
	r["picture"] = Data.shop_picture("mounts", Save.mount_look)
	r["quiet"] = true
	return r


## The pet's training: "Sprig · level 2", its sparks now and next, Train with the next level's price (on while it can
## be trained: never above the Hearthtree's level), or "Max level" at its top.
func training_row() -> Dictionary:
	var m = _market.get_ref()
	var lv := Data.pet_level()
	var top := Data.pet_top()
	var title := Words.say("pet_level") % [Data.pet_name(), lv]
	var badge := Words.say("level_badge") % [lv, top]
	var r: Dictionary
	if lv >= top:
		r = m.list_row("pet", title, sparks(lv) + "\n" + Words.say("max"), {}, "", false, Callable(), badge, "pet_training")
	else:
		var b := Buy.new("pet_training", "", 1, lv + 1)
		var cost: Dictionary = b.price()
		var why: String = b.can_run(main)
		var ok := why == "" or (not cost.is_empty() and why == MarketTrade.short_of(cost))
		var text := sparks(lv) + "\n" + Words.say("pet_next") % [_damage(lv + 1), _every(lv + 1)]
		if not ok:
			text += "\n" + why
		r = m.list_row("pet", title, text, cost, Words.say("train"), ok, st._train_pet.bind(lv + 1), badge, "pet_training")
	r["picture"] = Data.shop_picture("pets", Save.pet_look)
	return r


## The colours of the look out now: "Colours: Snow", their names, and Next (free: stations._next_skin).
func colour_row(slot: String) -> Dictionary:
	var m = _market.get_ref()
	var skins: Array = st._skins(slot)
	var look := _look_in(slot)
	var cur := Data.skin(slot, look, st._skin_id(slot))
	var names := PackedStringArray()
	for sk: Variant in skins:
		if sk is Dictionary:
			names.append(String((sk as Dictionary).get("name", "")))
	var r: Dictionary = m.list_row(slot, Words.say("colours") % String(cur.get("name", "")), " · ".join(names), {},
		Words.say("next"), skins.size() > 1, st._next_skin.bind(slot), "", "colours")
	r["picture"] = Data.shop_picture(String(KINDS.get(slot, "")), look)
	r["quiet"] = true
	return r


## The first Gloomlit colour of the look out now that is not unlocked yet: earned with Gloom shards, never sold
## (stations._unlock_skin, the Buy command's colour_unlock underneath). [] when there is none left.
func gloomlit_rows(slot: String) -> Array:
	var m = _market.get_ref()
	var look := _look_in(slot)
	for sk: Variant in Data.look(slot, look).get("skins", []):
		if not sk is Dictionary:
			continue
		var s: Dictionary = sk
		var sid := String(s.get("id", ""))
		if int(s.get("shards", 0)) <= 0 or Save.unlocks.has(st._skin_unlock(slot, sid)):
			continue
		var b := Buy.new("colour_unlock", sid, 1, -1, look)
		var cost: Dictionary = b.price()
		var why: String = b.can_run(main)
		var ok := why == "" or (not cost.is_empty() and why == MarketTrade.short_of(cost))
		return [m.list_row("shard", Words.say("gloomlit_colours") % String(s.get("name", sid)), Words.say("gloomlit_note"),
			cost, Words.say("unlock"), ok, st._unlock_skin.bind(slot, sid), Words.say("new"), "gloomlit")]
	return []


## The Market's expedition gear for the slot (content/attachments, shop "stall"), once the Gloomwood is open: the one
## worn "Equipped" with Take off, an owned one Wear, the rest its price and Buy (stations._buy_attach: worn at once).
func gear_rows(slot: String) -> Array:
	var out: Array = []
	if not Data.burrows_open():
		return out
	var m = _market.get_ref()
	for e: Dictionary in Data.attachment_entries(MarketTrade.MARKET, slot):
		var aid := String(e["id"])
		var nm := String(e.get("name", aid))
		var note := String(e.get("desc", ""))
		var icon := String(e.get("icon", slot))
		if String(Save.attach.get(slot, "")) == aid:
			out.append(m.list_row(icon, nm, note, {}, Words.say("take_off"), true, st._wear.bind(slot, ""), Words.say("equipped"), aid))
		elif Data.owned_level("attachments", aid) >= 1:
			out.append(m.list_row(icon, nm, note, {}, Words.say("wear"), true, st._wear.bind(slot, aid), Words.say("owned"), aid))
		else:
			var b := Buy.new("attachments", aid, 1, 1)
			var cost: Dictionary = b.price()
			var why: String = b.can_run(main)
			var ok := why == "" or (not cost.is_empty() and why == MarketTrade.short_of(cost))
			out.append(m.list_row(icon, nm, note, cost, Words.say("buy"), ok, st._buy_attach.bind(aid), Words.say("new"), aid))
	return out


# ---------------------------------------------------------------- the window API (the card calls these)
## The detail view of the look looked at, else the grid of the slot the window shows.
func content() -> Control:
	var slot := current_slot()
	if detail != "" and detail_slot == slot:
		var e := Data.shop_entry(String(KINDS.get(slot, "")), detail)
		if not e.is_empty():
			return _detail_view(slot, e)
	detail = ""
	var grid := IconGrid.make(hud, entries(slot), open_detail)
	grid.set_meta("companion_grid", slot)
	return grid


func tick(_delta: float) -> void:
	pass


func opened() -> void:
	pass


## The visit ends (or another tab's window takes the card): the next visit starts on the grid.
func closed() -> void:
	detail = ""


## Look lid of slot is looked at (its detail view, on the next rebuild). false for an unknown or hidden look.
func inspect(slot: String, lid: String) -> bool:
	if Data.shop_entry(String(KINDS.get(slot, "")), lid).is_empty():
		return false
	detail = lid
	detail_slot = slot
	return true


## Back to the grid (on the next rebuild).
func reset() -> void:
	detail = ""


## A tap on a cell's picture: its detail view, from the top of the card.
func open_detail(lid: String) -> void:
	if not inspect(current_slot(), lid):
		return
	if hud._card_scroll != null and is_instance_valid(hud._card_scroll):
		hud._card_scroll.scroll_vertical = 0
	hud.refresh_card()


## The detail view: the picture at 200 px, the name (bold 32), what it is, what it does now, its price or its state,
## then Back and the look's one action (Use or Buy; none when it is out or not for sale now).
func _detail_view(slot: String, e: Dictionary) -> Control:
	var tiles: ShopTiles = hud.p_tiles
	var lid := String(e["id"])
	var s := look_state(slot, lid)
	var box := VBoxContainer.new()
	box.set_meta("companion_detail", lid)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_PASS        # a drag still scrolls the dialog
	box.add_child(_picture(e, Data.shop_picture(String(KINDS.get(slot, "")), lid)))
	box.add_child(_text(String(e.get("name", lid)), 32, hud.TILE_INK, true))
	var desc := String(e.get("desc", ""))
	if desc != "":
		box.add_child(_text(desc, 22, SOFT_INK, false))
	for line: Variant in detail_lines(slot):
		box.add_child(_text(String(line), 20, SOFT_INK, false))
	var cost: Dictionary = s["cost"]
	if tiles._price_kinds(cost) > 0:
		var price: HBoxContainer = tiles._price_line(cost, tiles._list_w())
		price.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_child(price)
	if String(s["note"]) != "":
		var note := _text(String(s["note"]), 21, hud.TILE_INK, true)
		note.set_meta("state", true)
		box.add_child(note)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	buttons.mouse_filter = Control.MOUSE_FILTER_PASS
	buttons.add_child(_button(Words.say("back"), "grey", true, reset))
	var label := String(s["label"])
	if label != "":
		buttons.add_child(_button(label, tiles._btn_tone(label), bool(s["enabled"]), s["action"]))
	box.add_child(buttons)
	return box


## The picture in the tiles' soft square: the look's whole picture when its file is there, else its icon.
func _picture(e: Dictionary, path: String) -> Control:
	var tiles: ShopTiles = hud.p_tiles
	var sq := Panel.new()
	sq.set_meta("detail_pic", true)
	var side := DETAIL_PIC + DETAIL_PAD * 2.0
	sq.custom_minimum_size = Vector2(side, side)
	sq.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sq.add_theme_stylebox_override("panel", tiles._ui_style("pic"))
	sq.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var raw: Variant = String(e.get("icon", ""))
	var own: Texture2D = hud.p_icons._picture(path)
	if own != null:
		raw = own
	var pic := TextureRect.new()
	pic.texture = hud.icon(raw)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.set_anchors_preset(Control.PRESET_FULL_RECT)
	pic.offset_left = DETAIL_PAD
	pic.offset_top = DETAIL_PAD
	pic.offset_right = -DETAIL_PAD
	pic.offset_bottom = -DETAIL_PAD
	sq.add_child(pic)
	if not hud._icon_known(raw):
		sq.add_child(tiles._letter(String(e.get("name", ""))))
	return sq


## A centred line of words: bold ones in ink, the others soft; wrapped.
func _text(t: String, fs: int, ink: Color, bold: bool) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", ink)
	if bold:
		l.add_theme_font_override("font", hud.p_tiles._bold())
	return l


## One of the detail view's buttons: the footer's button (the card kit draws it), but not the card's footer. Its press
## runs the action, then the card refreshes.
func _button(label: String, tone: String, on: bool, action: Callable) -> Button:
	var b: Button = CardParts.foot_button(hud, {"label": label, "tone": tone, "enabled": on, "action": action})
	b.remove_meta("footer")
	b.custom_minimum_size = BTN
	return b


# ---------------------------------------------------------------- small helpers
## The look out in a slot now (Save.mount_look or Save.pet_look).
func _look_in(slot: String) -> String:
	return Save.mount_look if slot == "mount" else Save.pet_look


## An entry's short name ("Thistle", "Lumi").
static func _short(e: Dictionary) -> String:
	return String(e.get("short", e.get("name", e.get("id", ""))))


## "Flicks sparks: 10 damage every 1.1s": the pet's sparks at level lv (the shared pet level; balance.json pet).
static func sparks(lv: int) -> String:
	return Words.say("pet_sparks") % [_damage(lv), _every(lv)]


static func _damage(lv: int) -> int:
	return int(Data.pick("pet", "damage_by_level", lv))


static func _every(lv: int) -> float:
	return Data.pick("pet", "every_by_level", lv)
