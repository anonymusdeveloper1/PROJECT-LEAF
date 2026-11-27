extends "res://ui/windows/building_window.gd"
## H4: the Bow Shop's window (building and marker "bench": the Bow Bench before G3, the same save keys). The plan: "the
## Bow Shop is the same list for the bows". One list row per bow (ui/kit/list_row.gd) in the bows' content order (Twig,
## Sunwood, Ember, Frost; Thorn Volley and the Foxfire Bow are "hidden" since 22 Nov 2026: no row unless the save owns
## one, and the Foxfire Bow also waits for the Gloomwood), each with its picture, its name, a badge, its lines and one
## button (the owner's answer, 26 Nov 2026, Q10 a):
##   the bow in the cat's paw   badge "Equipped"; "Level 4 of 8 · Next: +10% damage" (" · Mastery 1/2" past level 10)
##                              with the bow's own line under it; Upgrade with its price while it can level (any time,
##                              mid-wave too), else a grey "Equipped" button and "Upgrade the Bow Shop for more" (at the
##                              shop's cap, Data.bow_cap()) or "Max level" (at the bow's top)
##   owned, not in the paw      badge "Owned"; "Level 2 of 6 · <its line>" ("Between waves" while a wave is on); Equip
##   not owned                  badge "New": its line and its price, Buy (a bow bought between waves goes in the paw,
##                              one bought mid-wave waits on the shelf); badge "Locked": "Needs Bow Shop level N" and
##                              its price, no button
## A tap on a bow's picture opens its inspect view in this window (Q11 a and b; ui/windows/bow_inspect.gd): the bow big
## and turning with its arrow beside it, its numbers, its one button and Back. A locked or unbought bow can be looked
## at too. Over the list, "Patch it up" when raids wore the shop (Q9); the shop's own Upgrade is pinned at the bottom
## (the base's upgrade_footer: it asks first in the confirm window, which lists gives()) and hides while a bow is looked
## at. Knocked down: only the ruin card. Buy, Equip and a bow's Upgrade are one tap, no confirm (Q4 a).
## Moved from stations.gd (_card_bench, _bow_tile, _bow_note and their helpers, and the shop's part of the upgrade line)
## in H4 Stage 1; list rows, the pinned Upgrade and the inspect view since Stage 2 (P2b).
## Used by: ui/windows/window_list.gd (hud.windows["bench"]), stations.gd (the marker's builder and its "!"),
##          ui/windows/bow_inspect.gd (inspect, bow_row, _bow_note, shown_cap, back), the tests.
## Uses: Data (bows, bow_info, bow_shop_level, bow_waits, bow_hidden, bow_cap, bow_top, bow_cost, craft_cost,
##       bow_level_mult, bow_picture, bow_burn, bow_frost, bow_draw_mult, mats_line, word), Save.bows / Save.bow, the
##       rules in stations.gd (_upgrade_bow, _craft, _equip, _locked, _name), the card's scroll (hud._card_scroll) and
##       the end of a window row's visit (hud.p_card._close_window, for Back).

const BowInspect := preload("res://ui/windows/bow_inspect.gd")

var inspect := ""                       # the bow whose inspect view shows ("" = the list); every visit starts on the list
var _inspect: BowInspect                # the inspect view: the card's window row while a bow is looked at
var _list_scroll := 0                   # how far the list was scrolled when a bow's picture was tapped (Back goes there)


func _init(owner_hud) -> void:
	super(owner_hud, "bench", "bench")
	_inspect = BowInspect.new(self)


## The card now: the ruin card, a bow's inspect view, or the list with the pinned Upgrade.
func spec() -> Dictionary:
	if Save.ruined.has(id):
		return _ruin_card(id, st._name(id), _anchor(id, 1.6))
	if inspect != "":
		return {"title": String(Data.bow_info(inspect).get("name", inspect)), "sub": "",
			"rows": [{"kind": "window", "window": _inspect, "enabled": true}], "anchor": _anchor(id, 1.6)}
	return _list_spec()


## The list: Patch it up (when worn), the bows' rows, and the shop's own Upgrade pinned at the bottom.
func _list_spec() -> Dictionary:
	var rows: Array = as_list(_wear_row(id))
	for e: Dictionary in Data.bows():
		var r := bow_row(String(e["id"]))
		if not r.is_empty():
			rows.append(r)
	return {"title": st._name(id), "sub": "Level %d · buy, upgrade and equip bows" % Data.station_level(id), "rows": rows,
		"footer": upgrade_footer(), "anchor": _anchor(id, 1.6)}


## The marker's "!": the list's rows and the pinned Upgrade (the base's rule), also while a bow is looked at.
func pulse() -> bool:
	if inspect == "" or Save.ruined.has(id):
		return super()
	var s := _list_spec()
	for row in s.get("rows", []):
		if _lights(row):
			return true
	return bool((s.get("footer", {}) as Dictionary).get("pulse", false))


## What Bow Shop level `level` gives: the bow level cap it allows, and the bows it starts selling (never a hidden one,
## nor one that waits for the Gloomwood): "Bows up to level 6", "sells the Sunwood Longbow".
func gives(level: int) -> Array:
	var caps: Array = Data.b["bow_cap_by_bench_level"]
	var out: Array = ["Bows up to level %d" % int(caps[clampi(level, 0, caps.size() - 1)])]
	var sells: Array = []
	for bid in Data.bow_ids():
		var bi := Data.bow_info(String(bid))
		if Data.bow_shop_level(String(bid)) == level and not Data.bow_hidden(String(bid)) and not Data.bow_waits(String(bid)):
			sells.append("the " + String(bi["name"]))
	if not sells.is_empty():
		out.append("sells %s" % " and ".join(sells))
	return out


## A visit always starts on the list (and ends there: the inspect view's closed() frees its 3D view).
func card_opened() -> void:
	inspect = ""


func card_closed() -> void:
	inspect = ""


# ---------------------------------------------------------------- the bows' rows
## One bow's list row (see the top of this file), with its picture (Data.bow_picture) whose tap opens its inspect view;
## {} for a bow not shown: a hidden bow the save does not own, or one that waits for the Gloomwood.
func bow_row(bid: String) -> Dictionary:
	var bi := Data.bow_info(bid)
	var nm := String(bi.get("name", bid))
	var owned := Save.bows.has(bid)
	if not owned and (Data.bow_hidden(bid) or Data.bow_waits(bid)):
		return {}                                           # kept out of the shop for now (owned ones still show)
	var note := _bow_note(bid)
	var r: Dictionary
	if owned:
		var lv := int(Save.bows[bid])
		var level := _w("bow_level") % [lv, shown_cap(bid)]
		if bid == Save.bow:
			var top := Data.bow_top(bid)
			if lv < Data.bow_cap() and lv < top:
				var gain := (Data.bow_level_mult(bid, lv + 1) / Data.bow_level_mult(bid, lv) - 1.0) * 100.0
				var line := level + " · " + _w("bow_next") % _short_num(gain)
				var costs: Array = bi["cost"]
				if lv >= costs.size():                      # Phase E: bow mastery, past level 10
					line += " · Mastery %d/%d" % [lv - costs.size() + 1, top - costs.size()]
				r = list_row("bow", nm, line + "\n" + note, Data.bow_cost(bid, lv), _w("upgrade"), true, st._upgrade_bow,
					_w("equipped"), bid)
			else:
				var why: String = _w("max") if lv >= top else ("Upgrade the %s for more" % st._name(id))
				r = list_row("bow", nm, level + " · " + why + "\n" + note, {}, _w("equipped"), false, Callable(),
					_w("equipped"), bid)
		else:
			var mid: bool = st._locked()                    # a wave is on: bows are swapped between waves
			r = list_row("bow", nm, level + " · " + ("Between waves" if mid else note), {}, "Equip", not mid,
				st._equip.bind(bid), "Owned", bid)
	else:
		var need := Data.bow_shop_level(bid)
		var cc := Data.craft_cost(bid)
		if Data.station_level(id) >= need:
			r = list_row("bow", nm, note + Data.mats_line(cc), cc, "Buy", true, st._craft.bind(bid), "New", bid)
		else:
			r = list_row("bow", nm, "Needs %s level %d" % [st._name(id), need], cc, "", false, Callable(), "Locked", bid)
	var pic := Data.bow_picture(bid)
	if pic != "":
		r["picture"] = pic
	r["on_picture"] = show_bow.bind(bid)
	return r


## The level a bow's "Level 4 of 8" counts to: what the shop allows now (Data.bow_cap), never above the bow's top,
## never below the level it has.
func shown_cap(bid: String) -> int:
	return maxi(mini(Data.bow_cap(), Data.bow_top(bid)), int(Save.bows.get(bid, 0)))


# ---------------------------------------------------------------- the inspect view (bow_inspect.gd draws it)
## A tap on a bow's picture: its inspect view in this window, from the top. The list's scroll is kept for Back.
func show_bow(bid: String) -> void:
	if inspect == "" and hud.card_ring() == ring() and hud._card_scroll != null and is_instance_valid(hud._card_scroll):
		_list_scroll = int(hud._card_scroll.scroll_vertical)
		hud._card_scroll.scroll_vertical = 0
	inspect = bid
	hud.refresh_card()


## The inspect view's Back: first its visit ends (the card ends a window row's visit only when the card closes or
## another window row comes, so without this the view's closed() would never run and its 3D view would never be
## freed), then the list shows again, scrolled back to where it was.
func back() -> void:
	hud.p_card._close_window()
	inspect = ""
	hud.refresh_card()
	_scroll_back(_list_scroll)


## Scrolls the list back to y once its rows are laid out (two frames, as card.gd's scroll_card_to waits).
func _scroll_back(y: int) -> void:
	if y <= 0:
		return
	await hud.get_tree().process_frame
	await hud.get_tree().process_frame
	if inspect == "" and hud.card_ring() == ring() and hud._card_scroll != null and is_instance_valid(hud._card_scroll):
		hud._card_scroll.scroll_vertical = y


# ---------------------------------------------------------------- a bow's own line
## What a bow does, in plain words, from its numbers: "A normal bow", "Goes through the first enemy, +1.5 m range",
## "Fire arrows: the hit enemy burns for 3 s", "Ice arrows: slow, and the 3rd hit freezes", "3 arrows in a fan",
## "Goes through two enemies, +1 m range". (Each bow's entry "desc" holds the same words; --bowshop checks they agree.)
func _bow_note(bid: String) -> String:
	var bi := Data.bow_info(bid)
	var bits: Array = []
	var n := int(bi["arrows"])
	if n > 1:
		bits.append("%d arrows in a fan" % n)
	var p := int(bi["pierce"])
	if p == 1:
		bits.append("goes through the first enemy")
	elif p > 1:
		bits.append("goes through %s enemies" % _count_word(p))
	var fire := Data.bow_burn(bid)
	if not fire.is_empty():
		bits.append("fire arrows: the hit enemy burns for %s s" % _short_num(float(fire.get("seconds", 0.0))))
	var ice := Data.bow_frost(bid)
	if not ice.is_empty():
		bits.append("ice arrows: slow, and the %s hit freezes" % _ordinal(int(ice.get("hits_to_freeze", 3))))
	var rb := float(bi["range_bonus"])
	if rb > 0.0:
		bits.append("+%s m range" % _short_num(rb))
	var dm := Data.bow_draw_mult(bid)
	var cons: Array = []                                 # the bow's downsides, after a "·"
	if rb < 0.0:
		cons.append("%s m shorter range" % _short_num(-rb))
	if dm > 1.0:
		var pct := roundi((dm - 1.0) * 100.0)
		cons.append("draws %d%% slower" % pct if pct < 20 else "slowest draw")   # a big slowdown reads as "slowest draw"
	if bits.is_empty() and cons.is_empty():
		return "Fastest draw" if dm <= 1.0 else "A normal bow"
	var s := ", ".join(bits)
	if s != "":
		s = s.substr(0, 1).to_upper() + s.substr(1)
	if not cons.is_empty():
		s = (s + " · " if s != "" else "") + " · ".join(cons)
	return s


const _COUNT_WORDS := ["no", "one", "two", "three", "four", "five"]


## "two", "three" (a number as a word in a line; the figure itself past five).
func _count_word(n: int) -> String:
	return String(_COUNT_WORDS[n]) if n >= 0 and n < _COUNT_WORDS.size() else str(n)


## 1 -> "1st", 2 -> "2nd", 3 -> "3rd", 4 -> "4th", 11 -> "11th", 22 -> "22nd".
func _ordinal(n: int) -> String:
	var suf := "th"
	if n % 100 < 11 or n % 100 > 13:
		match n % 10:
			1: suf = "st"
			2: suf = "nd"
			3: suf = "rd"
	return "%d%s" % [n, suf]
