extends RefCounted
## H5 (the window kit; the H5 map part 3.4): the small detail a tap on a trade's picture opens inside its own window
## (the Market's Sells and Buys, H5 Stage 2). Top to bottom:
##   - the picture again, bigger (DETAIL_PIC), then the name (bold) and what the thing does
##   - the amount, with - and + beside it: whole bundles, from 1 (2 bundles of Sunberries are 4 Sunberries)
##   - what you pay and what you get for that amount: the price in red where the cat has too few (amount_line with the
##     check on), the payout always in ink (amber's 2,000 leaves and two shards are never red)
##   - why it can't be done now, when it can't ("Bag full", "You have 1", "After the Raid Missions"): the quote stays
##     on show, so a trade that stops being affordable while the popup is open still shows its numbers
##   - Back and the one action (Buy or Sell), one tap each
## It is drawn inside the window's own card: the owner window's content() returns this popup's content() while it is
## open, so the card's X, a tap outside and the phone's Back close the whole card, as for any window.
## It holds no rules and does no sums. The owner opens it with open_item(spec):
##   spec = {"id", "title", "desc", "picture" (a res:// image, used when the file exists), "icon" (an icon id, else),
##           "label" (the action's word: Data.word("buy") or Data.word("sell")), "tone" (a shop_tiles.BTN name;
##           green by default),
##           "quote": Callable(bundles: int) -> Dictionary   what that many bundles would be now, in the shape of
##                    scripts/market_trade.gd quote(): "units", "price", "payout", "max_bundles", "reason" ("" = it can
##                    be done now)
##           "act": Callable(bundles: int) -> Variant         does it (the Buy command, MarketTrade.sell); true (or
##                    nothing) when it went through, false when it was refused
##           "back": Callable() -> void                       optional: the owner's own Back, after the popup closed}
## API:
##   open_item(spec)   shows spec's item at 1 bundle; the card's scroll is kept and the popup starts at the top (the
##                     owner then rebuilds the card, hud.refresh_card(), as the build menu's _open_detail does)
##   close()           shows nothing again (the owner's grid comes back on its next content())
##   is_open(), item_id(), amount()   what it shows (the owner and the tests read them)
##   content()         the whole popup, safe to call on every rebuild of the card: it keeps its item and amount
##   set_amount(n)     n bundles (at least 1); redraws the numbers in place, never the whole card, so nothing jumps
##   tick(delta)       the owner's tick passes it on (the HUD ticks only the card's window): every TICK_S it asks the
##                     quote again and redraws the numbers when the stock or the money changed
##   opened(), closed()   the owner passes on its visit hooks; closed() ends the popup (a new visit starts on the grid)
## Back closes the popup, runs the owner's back, rebuilds the card and scrolls the list back to where it was (two frames
## later, as the Bow Shop's Back does). The action runs act(amount), then rebuilds the card (the owner shows the
## receipt or the refusal); after a trade that went through, the amount drops to what can still be traded (at least 1).
## Used by: ui/windows/market_window.gd (H5 Stage 2), the tests. Uses: ui/kit/icon_grid.gd (amount_line), card_parts.gd
## (the buttons), the HUD's tiles, icons and pictures, Data (the words). No class_name: preload it.

const IconGrid := preload("res://ui/kit/icon_grid.gd")
const CardParts := preload("res://ui/kit/card_parts.gd")
const ShopTiles := preload("res://ui/hud/shop_tiles.gd")   # the type of the HUD's tiles (hud.p_tiles)

const DETAIL_PIC := 200.0               # the picture (the build menu's detail picture)
const DETAIL_PAD := 8.0                 # the soft square behind it is this much bigger on each side
const NAME_FS := 32
const DESC_FS := 22
const AMOUNT_FS := 28
const LEAD_FS := 21                     # "You pay", "You get"
const REASON_FS := 21
const REASON_INK := Color(0.7, 0.28, 0.2)   # why it can't be done (the build menu's "needs" colour)
const SOFT_INK := Color(0.45, 0.36, 0.26)
const BTN := Vector2(220, 64)           # Back and the action (the build menu's detail buttons)
const STEP_BTN := Vector2(72, 64)       # - and +: a thumb wide and tall
const STEP_FS := 34                     # their signs, bigger than a word
const STEP_MINUS := "-"                 # the signs on them (symbols, not words; plain ASCII so every font has them)
const STEP_PLUS := "+"
const AMOUNT_ROOM := 888                # the amount label keeps room for a number this wide, so - and + never jump
const TICK_S := 0.25                    # how often an open popup asks its quote again

var hud                                 # the HUD node (untyped on purpose, as in the kit's other parts)
var _item: Dictionary = {}              # the spec of the item it shows; {} when closed
var _amount := 1                        # bundles
var _list_scroll := 0                   # the card's scroll when the popup opened (Back goes back there)
var _ring: Variant = null               # the card that was open then (the scroll is put back only on that card)
var _t := 0.0
var _sig := ""                          # the quote last drawn (tick redraws when it changes)
# the parts the numbers are drawn in (made by content(); null when it is not showing)
var _amount_l: Label
var _minus_b: Button
var _plus_b: Button
var _pay_box: HBoxContainer
var _get_box: HBoxContainer
var _reason_l: Label
var _act_b: Button


func _init(owner_hud) -> void:
	hud = owner_hud


## Shows spec's item (see the top) at 1 bundle. The card's scroll is kept for Back and the popup starts at the top.
func open_item(spec: Dictionary) -> void:
	if _item.is_empty() and hud != null and hud.card_open() and hud._card_scroll != null and is_instance_valid(hud._card_scroll):
		_list_scroll = int(hud._card_scroll.scroll_vertical)
		_ring = hud.card_ring()
		hud._card_scroll.scroll_vertical = 0
	_item = spec.duplicate()
	_amount = 1
	_sig = ""


## Shows nothing again; the owner's grid comes back on its next content().
func close() -> void:
	_item = {}
	_amount = 1
	_sig = ""
	_forget_parts()


func is_open() -> bool:
	return not _item.is_empty()


func item_id() -> String:
	return String(_item.get("id", ""))


func amount() -> int:
	return _amount


## n bundles (at least 1; more than can be traded now is allowed, and then the reason shows). The numbers are redrawn
## in place.
func set_amount(bundles: int) -> void:
	_amount = maxi(1, bundles)
	_redraw_numbers()


# ---------------------------------------------------------------- the window API (passed on by the owner window)
## The whole popup (an empty box when closed). Safe on every rebuild: the item and the amount stay.
func content() -> Control:
	var box := VBoxContainer.new()
	box.set_meta("item_popup", item_id())
	box.add_theme_constant_override("separation", 10)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.mouse_filter = Control.MOUSE_FILTER_PASS        # a drag still scrolls the dialog
	_forget_parts()
	if _item.is_empty():
		return box
	var tiles: ShopTiles = hud.p_tiles
	var title := String(_item.get("title", ""))
	box.add_child(_picture(title))
	box.add_child(_text(title, NAME_FS, hud.TILE_INK, true))
	var desc := String(_item.get("desc", ""))
	if desc != "":
		var d := _text(desc, DESC_FS, SOFT_INK, false)
		d.set_meta("desc", true)
		box.add_child(d)
	# the amount, with - and + beside it
	var steps := HBoxContainer.new()
	steps.alignment = BoxContainer.ALIGNMENT_CENTER
	steps.add_theme_constant_override("separation", 16)
	steps.mouse_filter = Control.MOUSE_FILTER_PASS
	_minus_b = _button(STEP_MINUS, "blue", STEP_BTN, _step.bind(-1))
	_minus_b.set_meta("step", -1)
	steps.add_child(_minus_b)
	_amount_l = _text("", AMOUNT_FS, hud.TILE_INK, true)
	_amount_l.set_meta("amount", true)
	_amount_l.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_amount_l.autowrap_mode = TextServer.AUTOWRAP_OFF
	_amount_l.custom_minimum_size = Vector2(tiles._bold().get_string_size(_amount_text(AMOUNT_ROOM), HORIZONTAL_ALIGNMENT_LEFT, -1, AMOUNT_FS).x + 8.0, 0)
	steps.add_child(_amount_l)
	_plus_b = _button(STEP_PLUS, "blue", STEP_BTN, _step.bind(1))
	_plus_b.set_meta("step", 1)
	steps.add_child(_plus_b)
	box.add_child(steps)
	# what you pay and what you get for it
	_pay_box = _lead_row("you_pay", "pay")
	box.add_child(_pay_box)
	_get_box = _lead_row("you_get", "get")
	box.add_child(_get_box)
	_reason_l = _text("", REASON_FS, REASON_INK, false)
	_reason_l.set_meta("reason", true)
	box.add_child(_reason_l)
	# Back and the one action
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	buttons.mouse_filter = Control.MOUSE_FILTER_PASS
	var back_b := _button(Data.word("back"), "grey", BTN, _on_back)
	back_b.disabled = false
	buttons.add_child(back_b)
	var label := String(_item.get("label", Data.word("buy")))
	_act_b = _button(label, String(_item.get("tone", "green")), BTN, _on_act)
	_act_b.set_meta("action", true)
	buttons.add_child(_act_b)
	box.add_child(buttons)
	_sig = ""
	_redraw_numbers()
	return box


func tick(delta: float) -> void:
	if _item.is_empty() or _amount_l == null or not is_instance_valid(_amount_l) or not _amount_l.is_inside_tree():
		return
	_t += delta
	if _t < TICK_S:
		return
	_t = 0.0
	if _signature(_quote()) != _sig:
		_redraw_numbers()


func opened() -> void:
	pass


## The visit ends (the X, a tap outside, another card): the next visit starts on the owner's grid.
func closed() -> void:
	close()


# ---------------------------------------------------------------- the numbers
## What `_amount` bundles would be now (the owner's quote; {} when it has none).
func _quote() -> Dictionary:
	var q: Variant = _item.get("quote", Callable())
	if q is Callable and (q as Callable).is_valid():
		var out: Variant = (q as Callable).call(_amount)
		if out is Dictionary:
			return out
	return {}


## The quote and what the cat has of each thing it asks for: a change in either redraws.
func _signature(q: Dictionary) -> String:
	var s := "%d|%s" % [_amount, str(q)]
	var price := _dict(q.get("price", {}))
	for k: Variant in price:
		s += "|%s=%d" % [String(k), IconGrid.held(String(k))]
	return s


## Puts the quote's numbers in the parts content() made: the amount, the two lines, the reason, which buttons work.
func _redraw_numbers() -> void:
	if _amount_l == null or not is_instance_valid(_amount_l):
		return
	var q := _quote()
	_sig = _signature(q)
	var units := int(q.get("units", 0))                 # the things themselves: 2 bundles of Sunberries are 4
	_amount_l.text = _amount_text(units if units > 0 else _amount)
	var room: float = hud.p_tiles._list_w() * 0.7
	_fill_line(_pay_box, _dict(q.get("price", {})), room, true)
	_fill_line(_get_box, _dict(q.get("payout", {})), room, false)
	var reason := String(q.get("reason", "")) if not q.is_empty() else Data.word("coming_later")
	_reason_l.text = reason
	_reason_l.visible = reason != ""
	var most := int(q.get("max_bundles", 0))
	_minus_b.disabled = _amount <= 1
	_plus_b.disabled = q.is_empty() or _amount >= most
	_act_b.disabled = not _can_act(q)


## The trade can be done now as shown: a quote with no reason, for no more than can be traded.
func _can_act(q: Dictionary) -> bool:
	if q.is_empty() or String(q.get("reason", "")) != "":
		return false
	return _amount <= int(q.get("max_bundles", 0))


## One "You pay" / "You get" row's line, drawn again (its word stays).
func _fill_line(row: HBoxContainer, amounts: Dictionary, room: float, check: bool) -> void:
	if row == null or not is_instance_valid(row):
		return
	var old: Node = row.get_node_or_null("Line")
	if old != null:
		row.remove_child(old)
		old.queue_free()
	var line: HBoxContainer = IconGrid.amount_line(hud, amounts, room, check)
	line.name = "Line"
	line.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_child(line)
	row.visible = IconGrid.amount_kinds(amounts) > 0


# ---------------------------------------------------------------- the buttons
func _step(by: int) -> void:
	set_amount(_amount + by)


## The action: act(amount), then the card is rebuilt (the owner shows the receipt or the refusal). After a trade that
## went through, the amount drops to what can still be traded (at least 1).
func _on_act() -> void:
	if _item.is_empty() or not _can_act(_quote()):
		return
	var act: Variant = _item.get("act", Callable())
	if not (act is Callable) or not (act as Callable).is_valid():
		return
	var done: Variant = (act as Callable).call(_amount)
	if not (done is bool) or bool(done):
		_amount = clampi(_amount, 1, maxi(1, int(_quote().get("max_bundles", 1))))
	hud.refresh_card()


## Back: the popup closes, the owner's own back runs, the card is rebuilt and scrolled back to where the list was.
func _on_back() -> void:
	var back: Variant = _item.get("back", Callable())
	var y := _list_scroll
	var ring: Variant = _ring
	close()
	_list_scroll = 0
	_ring = null
	if back is Callable and (back as Callable).is_valid():
		(back as Callable).call()
	hud.refresh_card()
	_scroll_back(y, ring)


## Scrolls the list back to y once its rows are laid out (two frames, as card.gd's scroll_card_to waits), only when the
## same card is still open and the popup still closed.
func _scroll_back(y: int, ring: Variant) -> void:
	if y <= 0 or hud == null:
		return
	await hud.get_tree().process_frame
	await hud.get_tree().process_frame
	if _item.is_empty() and hud.card_ring() == ring and hud._card_scroll != null and is_instance_valid(hud._card_scroll):
		hud._card_scroll.scroll_vertical = y


## One of the popup's buttons: the footer's look (card_parts.gd), but its press is the popup's own, and it is turned
## on and off in place (a redraw never replaces it under the finger). It does not rebuild the card by itself.
func _button(label: String, tone: String, least: Vector2, action: Callable) -> Button:
	var b: Button = CardParts.foot_button(hud, {"label": label, "tone": tone, "enabled": false})
	b.remove_meta("footer")                             # a button of the popup, not of the card's footer
	b.custom_minimum_size = least
	if least == STEP_BTN:
		b.add_theme_font_size_override("font_size", STEP_FS)
	b.pressed.connect(func() -> void:
		if not b.disabled:
			action.call())
	return b


# ---------------------------------------------------------------- the parts
## The picture in the tiles' soft square: the item's own picture when its file is there, else its icon; an unknown
## icon shows the name's first letter on a plain disc, as a tile does. It takes no taps.
func _picture(title: String) -> Control:
	var tiles: ShopTiles = hud.p_tiles
	var sq := Panel.new()
	sq.set_meta("popup_pic", true)
	var side := DETAIL_PIC + DETAIL_PAD * 2.0
	sq.custom_minimum_size = Vector2(side, side)
	sq.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sq.add_theme_stylebox_override("panel", tiles._ui_style("pic"))
	sq.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var raw: Variant = _item.get("icon", "")
	var own: Texture2D = hud.p_icons._picture(String(_item.get("picture", "")))
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
		sq.add_child(tiles._letter(title))
	return sq


## A "You pay" / "You get" row: its word on the left (the window word without its "%s"), the line after it.
func _lead_row(key: String, meta: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.set_meta("popup_" + meta, true)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := _text(Data.word(key).replace("%s", "").strip_edges(), LEAD_FS, SOFT_INK, false)
	l.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(l)
	return row


## A centred line of words: bold ones in ink (the name, the amount), the others soft and wrapped.
func _text(t: String, fs: int, ink: Color, bold: bool) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", ink)
	if bold:
		l.add_theme_font_override("font", hud.p_tiles._bold())
	return l


func _forget_parts() -> void:
	_amount_l = null
	_minus_b = null
	_plus_b = null
	_pay_box = null
	_get_box = null
	_reason_l = null
	_act_b = null


## "Amount: 4" (the window word "amount" with n in it; the word alone if it has no number in it).
static func _amount_text(n: int) -> String:
	var word := Data.word("amount")
	return word % n if word.contains("%d") else word


static func _dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}
