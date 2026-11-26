extends Node
## H4 (Stage 2): the --bowshop window checks, run from autotest_g3_bow.gd (it keeps the G3 shooting checks and the
## helpers both use). The windows are reached only through main.hud.windows["bench"] and ["target"]; the Bow Shop and
## the Training Target are lists with the Upgrade pinned at the bottom (the owner, 26 Nov 2026: Q2 a, Q9, Q10 a, Q11).
##   (a) the window: title, a list with its Upgrade in the footer, the four bow rows in order (Twig, Sunwood, Ember,
##       Frost; Thorn Volley and Foxfire hidden unless owned, then Owned / Equipped), labels, badges and lines (Q10 a:
##       Locked has no button); each bow's desc is its line; a hidden bow is not sold nor named on the shop's next level
##   (b) Buy: Ember at Shop level 3 takes exactly its leaves and its timber, owns it at level 1, puts it in the paw;
##       without the timber nothing is bought
##   (c) Upgrade: raises only the bow in the paw, stops at the Shop's cap (then a grey "Equipped" button)
##   (d) Equip: back to Twig between waves; with a wave on Equip is off ("Between waves") and does nothing; the Frost
##       Bow bought mid-wave (exactly its price) is owned but not equipped, and equipped after the wave
##   (n) "Level N of M · Next: +X% damage" over the bow's own line at every level the bow in the paw can reach, then
##       "Max level"; mastery past 10 once the Burrows are open
##   (r) the bow in the paw's drawn row shows every line (its level line and its own line can each take two) at the
##       Shop's cap and on a mastery level, in the list and in the inspect view (Q10 a: it keeps its _bow_note line)
##   (u) the pinned Upgrade: "Level 1 of 5", the price, on even with 0 leaves (Q2 a) but no "!"; it opens the confirm,
##       whose lines name the bows the next level sells (never a hidden one); Cancel goes back, Confirm levels the shop
##       and comes back
##   (v) the inspect view (Q11): a real tap on a bow's picture opens it in the same window (the bow's name, a turning
##       3D view of the bow and its arrow, its lines, its own button, Back, no footer); its arrow's real damage with the
##       cat's Damage stat and a potion; a save keeps the turn; Back frees the 3D view; a locked bow can be looked at
##   (p) all six bows owned, at 540x960 and 480x1040: the dialog fits and the footer's Upgrade stays inside the dialog
##       and the screen at the list's top and end
##   (z) with 0 leaves no row is on and the marker shows no "!"; with the price it does (also while a bow is looked at)
##   (t) the Training Target: three stat rows with "Next:" and Buy, Range Locked below Target 2, no row on with 0
##       leaves; its footer opens the confirm and Confirm makes it level 2 (Range opens)
## Moved out of autotest_g3_bow.gd on 26 Nov 2026 (house rule 1: one job a file, under about 800 lines); the checks
## (a) to (t) did not change, (r) is new.
## Screenshots: bowshop_confirm, bowshop_inspect_twig, bowshop_inspect_frost, bowshop_list_540, bowshop_list_480,
## bowshop_row_cap, bowshop_row_mastery, bowshop_row_inspect, bowshop_target, bowshop_target_confirm.

var t                     # autotest.gd (its helpers: _wait, _expect, _until, _log, _shot, _press, _tap_at, _tap_close)
var main
var g                     # autotest_g3_bow.gd: the helpers both halves use (_x, _start_fresh, _row and the rest)
var _lay                  # autotest_layout.gd, for its _card_fits (the dialog fits the phone and its safe area)

const Bow := preload("res://scripts/autotest_g3_bow.gd")        # its ORDER (the G3 checks use it too)
const BowInspect := preload("res://ui/windows/bow_inspect.gd")   # its words (ARROW_HIT, ARROW_HIT_POTION)
const ORDER: Array = Bow.ORDER
const HIDDEN := ["volley", "foxfire"]
const T_STATS := ["damage", "draw", "range"]          # (t) what the Training Target trains, in its order
const BOW_NOTES := {
	"twig": "Fastest draw",
	"sunwood": "Goes through the first enemy, +1.5 m range · draws 10% slower",
	"ember": "Fire arrows: the hit enemy burns for 3 s · 0.8 m shorter range",
	"frost": "Ice arrows: slow, and the 3rd hit freezes · slowest draw",
	"volley": "3 arrows in a fan",
	"foxfire": "Goes through two enemies, +1 m range",
}


## The checks, in the order they always ran; autotest_g3_bow.gd starts them on a fresh camp and frees this node after.
func run() -> void:
	_card()
	_buy()
	_upgrade()
	_equip()
	_next_lines()
	await _row_lines()
	await _footer()
	await _inspect_view()
	await _phones()
	_pulse()
	await _target()


# ---------------------------------------------------------------- helpers kept in autotest_g3_bow.gd (its G3 checks use them)
func _x(what: String, ok: bool, extra := {}) -> bool:
	return g._x(what, ok, extra)


func _st():
	return g._st()


func _win():
	return g._win()


func _w(key: String) -> String:
	return g._w(key)


func _start_fresh() -> void:
	g._start_fresh()


func _bname(bid: String) -> String:
	return g._bname(bid)


func _rows() -> Array:
	return g._rows()


func _row(bid: String) -> Dictionary:
	return g._row(bid)


# ---------------------------------------------------------------- the window checks' own helpers
## The Training Target's window (ui/windows/target_window.gd).
func _twin():
	return main.hud.windows["target"]


## "Next: +10% damage" for bow bid going from level lv to lv + 1.
func _next_words(bid: String, lv: int) -> String:
	var gain := (Data.bow_level_mult(bid, lv + 1) / Data.bow_level_mult(bid, lv) - 1.0) * 100.0
	return _w("bow_next") % _st()._short_num(gain)


func _need(bid: String) -> Dictionary:
	return Data.craft_cost(bid)


func _set_wave(on: bool) -> Dictionary:
	var f = main.fight
	var keep := {"active": f.active, "in_wave": f.in_wave}
	f.active = on
	f.in_wave = on
	return keep


func _restore_wave(keep: Dictionary) -> void:
	main.fight.active = keep["active"]
	main.fight.in_wave = keep["in_wave"]


# ---------------------------------------------------------------- what an open window shows
## Every live Label's words under n (not the old rows a rebuild is freeing).
func _texts(n: Node) -> Array:
	var out: Array = []
	if n == null or not is_instance_valid(n):
		return out
	for l in n.find_children("*", "Label", true, false):
		if (l as Control).is_visible_in_tree() and not _going(l):
			out.append(String((l as Label).text))
	return out


## A node or one of its parents is being freed (a card's rebuild hides and frees the old rows).
func _going(n: Node) -> bool:
	var q: Node = n
	while q != null:
		if q.is_queued_for_deletion():
			return true
		q = q.get_parent()
	return false


## The open dialog's live button with this label (not the X), or null.
func _button(label: String) -> Button:
	for b in main.hud.card_buttons():
		if String(b.get_meta("label", "")) == label and (b as Control).is_visible_in_tree() and not _going(b):
			return b
	return null


## The open dialog's live list rows (ui/kit/list_row.gd panels), in order.
func _list_rows() -> Array:
	var out: Array = []
	var list = main.hud._card_list
	if main.hud._card == null or list == null or not is_instance_valid(list):
		return out
	for c in list.find_children("*", "", true, false):
		if c.has_meta("list_row") and (c as Control).is_visible_in_tree() and not _going(c):
			out.append(c)
	return out


## The picture of the open list row with this id, or null.
func _row_picture(id: String) -> Control:
	for r in _list_rows():
		if String(r.get_meta("id", "")) == id:
			for c in (r as Node).find_children("*", "", true, false):
				if c.has_meta("list_pic"):
					return c as Control
	return null


## The inspect view's turning 3D view in the open dialog (ui/kit/model_view.gd), or null.
func _model_view():
	var list = main.hud._card_list
	if main.hud._card == null or list == null or not is_instance_valid(list):
		return null
	for c in list.find_children("*", "", true, false):
		if c.has_meta("model_view") and not _going(c):
			return c
	return null


## A control shows inside the dialog and inside the screen between the phone's bars.
func _on_card_and_screen(c: Control) -> bool:
	var hud = main.hud
	if c == null or hud._card == null:
		return false
	var v: Vector2 = hud.get_viewport().get_visible_rect().size
	var r := c.get_global_rect()
	var top: float = hud._safe.x
	var bottom: float = v.y - hud._safe.y
	var screen := Rect2(0.0, top, v.x, bottom - top)
	return c.is_visible_in_tree() and (hud._card as Control).get_global_rect().grow(0.5).encloses(r) and screen.grow(0.5).encloses(r)


## The confirm window's lines as it lists them (each line's first letter a capital).
func _capitalised(lines: Array) -> Array:
	return lines.map(func(s): return String(s).substr(0, 1).to_upper() + String(s).substr(1))


func _confirm_lines() -> Array:
	var out: Array = []
	for r in main.hud.confirm.spec()["rows"]:
		if bool(r.get("small", false)):
			out.append(String(r.get("text", "")))
	return out


# ---------------------------------------------------------------- (a) the window
func _card() -> void:
	var st = _st()
	var win = _win()
	var card: Dictionary = win.spec()
	_x("the window's title is the Bow Shop", String(card["title"]) == "Bow Shop" and String(Data.building("bench")["name"]) == "Bow Shop",
		{"title": card["title"]})
	var all_list: bool = (card["rows"] as Array).all(func(r): return String(r.get("kind", "")) == "list")
	var foot: Dictionary = card.get("footer", {})
	_x("H4: the Bow Shop is a list (every row a list row) with its own Upgrade pinned in the footer, not in the rows",
		all_list and not foot.is_empty() and not (card["rows"] as Array).any(func(r): return String(r.get("title", "")).begins_with("Bow Shop level")),
		{"kinds": (card["rows"] as Array).map(func(r): return r.get("kind", "")), "footer": foot.get("text", "")})
	var keys: Array = Data.bow_ids()
	_x("content/bows: the Frost Bow comes right after Ember; Thorn Volley and Foxfire are kept, marked hidden",
		keys.find("frost") == keys.find("ember") + 1 and HIDDEN.all(func(b): return keys.has(b) and Data.bow_hidden(b))
		and not ORDER.any(func(b): return Data.bow_hidden(b)), {"bows": keys})
	var no_mats := true
	for bid in keys:
		var prices: Array = (Data.bow_info(bid).get("mastery", []) as Array).duplicate()
		prices.append(Data.craft_cost(bid))
		for c in prices:
			if c is Dictionary:
				for m in ["amber", "glowstone", "heartwood"]:
					no_mats = no_mats and not (c as Dictionary).has(m)
	_x("H1: every bow's mastery and craft price is leaves (and timber) only; Foxfire crafts for 5,120 leaves", no_mats
		and Data.craft_cost("foxfire") == {"leaves": 5120} and Data.bow_cost("twig", (Data.bow_info("twig")["cost"] as Array).size()).keys() == ["leaves"]
		and int(Data.bow_cost("twig", (Data.bow_info("twig")["cost"] as Array).size())["leaves"]) == 1200, {"foxfire": Data.craft_cost("foxfire")})
	# each bow's desc (its content entry) is the line the shop builds from its numbers: words and numbers cannot drift
	var desc_ok := true
	var descs := {}
	for bid in keys:
		var d := String(Data.bow_info(bid).get("desc", ""))
		var note := String(win._bow_note(bid))
		descs[bid] = [d, note]
		desc_ok = desc_ok and d == note and note == String(BOW_NOTES.get(bid, ""))
	_x("each bow's desc (content/bows) is its line from its numbers (pierce, arrows, fire, ice, range, draw)", desc_ok, descs)
	var titles: Array = _rows().map(func(r): return r["title"])
	_x("four bow rows in order twig, sunwood, ember, frost (Volley and Foxfire hidden)", titles == ORDER.map(func(b): return _bname(b)), {"rows": titles})
	var tw := _row("twig")
	var want_tw := "%s · %s\n%s" % [_w("bow_level") % [1, Data.bow_cap()], _next_words("twig", 1), BOW_NOTES["twig"]]
	_x("Twig (fresh save, in the paw): Equipped, Upgrade with its price, 'Level 1 of 4 · Next: +10% damage' over 'Fastest draw', its picture",
		String(tw.get("badge", "")) == _w("equipped") and String(tw.get("label", "")) == _w("upgrade") and String(tw.get("text", "")) == want_tw
		and tw.get("cost", {}) == Data.bow_cost("twig", 1) and String(tw.get("picture", "")) == Data.bow_picture("twig") and Data.bow_picture("twig") != ""
		and (tw.get("on_picture", Callable()) as Callable).is_valid(), {"text": tw.get("text", ""), "want": want_tw, "label": tw.get("label", "")})
	var locked_ok := true
	var info := {}
	for bid in ["sunwood", "ember", "frost"]:
		var tl := _row(bid)
		var need := Data.bow_shop_level(bid)
		var shop_ok: bool = int(Save.stations["bench"]) >= need
		var good: bool
		if shop_ok:
			good = String(tl.get("badge", "")) == "New" and String(tl.get("label", "")) == "Buy"
		else:
			good = String(tl.get("badge", "")) == "Locked" and String(tl.get("label", "")) == "" and not bool(tl.get("enabled", true)) \
				and String(tl.get("text", "")) == "Needs Bow Shop level %d" % need and tl.get("cost", {}) == Data.craft_cost(bid)
		locked_ok = locked_ok and good
		info[bid] = "%s/%s/%s" % [tl.get("label", ""), tl.get("badge", ""), tl.get("text", "")]
	_x("Q10 a: the other bows are Locked below their Shop level with 'Needs Bow Shop level N', their price and no button", locked_ok, info)
	# the shop's next level names the bows it will sell, never a hidden one (what the confirm lists, gives)
	var up3 := ", ".join(win.gives(Data.bow_shop_level("ember")))
	var up5 := ", ".join(win.gives(Data.bow_shop_level("frost")))
	var up4 := ", ".join(win.gives(4))
	_x("the Shop's level for Ember sells the Ember Bow; for Frost the Frost Bow; level 4 names no hidden bow",
		up3.contains(_bname("ember")) and up5.contains(_bname("frost")) and not up4.contains(_bname("volley")) and not up4.contains(_bname("foxfire"))
		and up4 == "Bows up to level %d" % int((Data.b["bow_cap_by_bench_level"] as Array)[4]),
		{"to_ember": up3, "to_frost": up5, "to_4": up4})
	# at the Shop's level each bow's own line shows (leaves are still missing, so Buy is off but the badge is New)
	Save.stations["bench"] = Data.bow_shop_level("frost")
	var notes_ok := true
	var seen := {}
	for bid in ["sunwood", "ember", "frost"]:
		var tl := _row(bid)
		seen[bid] = tl.get("text", "")
		notes_ok = notes_ok and String(tl.get("badge", "")) == "New" and String(tl.get("label", "")) == "Buy" and not bool(tl.get("enabled", true)) \
			and String(tl.get("text", "")).begins_with(String(BOW_NOTES[bid]))
	_x("at the Frost Bow's Shop level the three bows are New with Buy (off: no leaves) and state their pro and con (Frost: '%s')" % BOW_NOTES["frost"], notes_ok, seen)
	Save.stations["bench"] = 5
	Save.set_flag("hollow_open")
	var t5: Array = _rows().map(func(r): return r["title"])
	_x("Shop level 5 and the Burrows open: still the four rows (no Volley, no Foxfire)", t5 == ORDER.map(func(b): return _bname(b)), {"rows": t5})
	# a save that owns them still sees them, after the four, and can use them
	Save.bows["volley"] = 1
	Save.bows["foxfire"] = 1
	var t6: Array = _rows().map(func(r): return r["title"])
	var vo := _row("volley")
	_x("a save that owns Volley and Foxfire sees them after the four, Owned with Equip", t6 == (ORDER + HIDDEN).map(func(b): return _bname(b))
		and String(vo.get("badge", "")) == "Owned" and String(vo.get("label", "")) == "Equip" and bool(vo.get("enabled", false))
		and String(_row("foxfire").get("badge", "")) == "Owned", {"rows": t6, "volley": "%s/%s" % [vo.get("badge", ""), vo.get("label", "")]})
	Save.bow = "volley"
	vo = _row("volley")
	_x("an owned hidden bow in the paw shows Equipped with Upgrade", String(vo.get("badge", "")) == _w("equipped") and String(vo.get("label", "")) == _w("upgrade"),
		{"volley": "%s/%s" % [vo.get("badge", ""), vo.get("label", "")]})
	Save.bow = "twig"
	Save.bows.erase("volley")
	Save.bows.erase("foxfire")
	Save.leaves = 100000
	Save.timber = 1000
	st._craft("volley")
	st._craft("foxfire")
	_x("a hidden bow cannot be bought", not Save.bows.has("volley") and not Save.bows.has("foxfire") and Save.leaves == 100000 and Save.timber == 1000,
		{"bows": Save.bows})
	Save.leaves = 0
	Save.timber = 0
	Save.flags.erase("hollow_open")
	Save.stations["bench"] = 1


# ---------------------------------------------------------------- (b) Buy
func _buy() -> void:
	var st = _st()
	var need := _need("ember")
	Save.stations["bench"] = Data.bow_shop_level("ember")
	Save.leaves = int(need["leaves"]) + 77
	Save.timber = int(need["timber"]) - 1
	var tl := _row("ember")
	st._craft("ember")
	_x("Buy without the timber: nothing is bought, nothing taken (button off)", not Save.bows.has("ember") and Save.leaves == int(need["leaves"]) + 77
		and Save.timber == int(need["timber"]) - 1 and not bool(tl.get("enabled", true)) and String(tl.get("label", "")) == "Buy",
		{"enabled": tl.get("enabled"), "label": tl.get("label")})
	Save.timber = int(need["timber"])
	tl = _row("ember")
	var can: bool = bool(tl.get("enabled", false))
	st._craft("ember")
	_x("Buy Ember: owned at level 1, in the paw, exactly its leaves and timber taken", can and int(Save.bows.get("ember", 0)) == 1 and Save.bow == "ember"
		and Save.leaves == 77 and Save.timber == 0, {"bows": Save.bows, "bow": Save.bow, "leaves": Save.leaves, "timber": Save.timber})
	var e := _row("ember")
	var tw := _row("twig")
	_x("Q10 a: the Ember row is now Equipped with Upgrade; Twig is Owned with Equip and 'Level 1 of N · Fastest draw'",
		String(e.get("badge", "")) == _w("equipped") and String(e.get("label", "")) == _w("upgrade")
		and String(tw.get("badge", "")) == "Owned" and String(tw.get("label", "")) == "Equip"
		and String(tw.get("text", "")) == "%s · %s" % [_w("bow_level") % [1, _win().shown_cap("twig")], BOW_NOTES["twig"]],
		{"twig": tw.get("text", "")})


# ---------------------------------------------------------------- (c) Upgrade
func _upgrade() -> void:
	var st = _st()
	Save.leaves = 1000000
	Save.stations["bench"] = 3
	var lv0 := int(Save.bows["ember"])
	var twig0 := int(Save.bows["twig"])
	st._upgrade_bow()
	_x("Upgrade raises only the equipped bow's level", int(Save.bows["ember"]) == lv0 + 1 and int(Save.bows["twig"]) == twig0, {"bows": Save.bows})
	Save.stations["bench"] = 1
	var cap := Data.bow_cap()
	for i in cap + 3:
		st._upgrade_bow()
	var tl := _row("ember")
	var want := "%s · Upgrade the Bow Shop for more\n%s" % [_w("bow_level") % [cap, cap], BOW_NOTES["ember"]]
	_x("Q10 a: Upgrade stops at the Shop's cap (%d): a grey 'Equipped' button, 'Level %d of %d · Upgrade the Bow Shop for more' over its line" % [cap, cap, cap],
		int(Save.bows["ember"]) == cap and not bool(tl.get("enabled", true)) and String(tl.get("label", "")) == _w("equipped")
		and String(tl.get("badge", "")) == _w("equipped") and String(tl.get("text", "")) == want and int(Save.bows["twig"]) == twig0,
		{"bows": Save.bows, "text": tl.get("text", ""), "label": tl.get("label", "")})
	Save.stations["bench"] = 3


# ---------------------------------------------------------------- (d) Equip
func _equip() -> void:
	var st = _st()
	st._equip("twig")
	_x("Equip Twig between waves puts it back in the paw; Ember keeps its level", Save.bow == "twig" and int(Save.bows["ember"]) > 1, {"bow": Save.bow})
	var keep := _set_wave(true)
	var tl := _row("ember")
	st._equip("ember")
	_x("with a wave on: Equip is off, says 'Between waves', and _equip does nothing", String(tl.get("label", "")) == "Equip" and not bool(tl.get("enabled", true))
		and String(tl.get("text", "")).ends_with("Between waves") and Save.bow == "twig", {"row": tl.get("text", ""), "bow": Save.bow})
	var need := _need("frost")
	Save.stations["bench"] = Data.bow_shop_level("frost")
	Save.leaves = int(need["leaves"])
	Save.timber = int(need["timber"])
	st._craft("frost")
	_x("buying the Frost Bow mid-wave takes exactly its price, owns it at level 1, leaves the paw alone", int(Save.bows.get("frost", 0)) == 1 and Save.bow == "twig"
		and Save.leaves == 0 and Save.timber == 0 and int(need.get("leaves", 0)) > 0 and int(need.get("timber", 0)) > 0,
		{"bows": Save.bows, "bow": Save.bow, "price": need})
	_restore_wave(keep)
	st._equip("frost")
	_x("after the wave the Frost Bow can be equipped", Save.bow == "frost" and String(_row("frost").get("badge", "")) == _w("equipped"))
	st._equip("twig")


# ---------------------------------------------------------------- (n) "Next:" on every level of the bow in the paw
func _next_lines() -> void:
	var keep_bows: Dictionary = Save.bows.duplicate(true)
	var keep_bow: String = Save.bow
	var keep_bench := int(Save.stations["bench"])
	Save.stations["bench"] = 5
	Save.bows["ember"] = 1
	Save.bow = "ember"
	var cap := Data.bow_cap()
	var ok := true
	var bad := {}
	for lv in range(1, cap):
		Save.bows["ember"] = lv
		var r := _row("ember")
		var want := "%s · %s\n%s" % [_w("bow_level") % [lv, cap], _next_words("ember", lv), BOW_NOTES["ember"]]
		var good: bool = String(r.get("text", "")) == want and String(r.get("label", "")) == _w("upgrade") \
			and String(r.get("badge", "")) == _w("equipped") and r.get("cost", {}) == Data.bow_cost("ember", lv)
		if not good:
			bad[lv] = r.get("text", "")
		ok = ok and good
	_x("the bow in the paw: 'Level N of %d · Next: +X%% damage' over its own line, with Upgrade and its price, at every level 1 to %d" % [cap, cap - 1],
		ok and cap == 10, bad)
	Save.bows["ember"] = cap
	var top := _row("ember")
	_x("at its top (no Burrows): 'Level 10 of 10 · Max level' over its line, the grey Equipped button, no Next",
		String(top.get("text", "")) == "%s · %s\n%s" % [_w("bow_level") % [cap, cap], _w("max"), BOW_NOTES["ember"]]
		and String(top.get("label", "")) == _w("equipped") and not bool(top.get("enabled", true)), {"text": top.get("text", "")})
	Save.set_flag("hollow_open")
	var mcap := Data.bow_cap()
	var costs: Array = Data.bow_info("ember")["cost"]
	var m := _row("ember")
	var want_m := "%s · %s · Mastery 1/%d\n%s" % [_w("bow_level") % [cap, mcap], _next_words("ember", cap), mcap - costs.size(), BOW_NOTES["ember"]]
	_x("the Burrows open: mastery past level 10 ('... · Next: +X% damage · Mastery 1/2'), Upgrade with the mastery price",
		String(m.get("text", "")) == want_m and String(m.get("label", "")) == _w("upgrade") and m.get("cost", {}) == Data.bow_cost("ember", cap),
		{"text": m.get("text", ""), "want": want_m})
	Save.bows["ember"] = mcap
	var mt := _row("ember")
	_x("at its mastery top: 'Level 12 of 12 · Max level', the grey Equipped button",
		String(mt.get("text", "")).begins_with("%s · %s\n" % [_w("bow_level") % [mcap, mcap], _w("max")]) and String(mt.get("label", "")) == _w("equipped")
		and not bool(mt.get("enabled", true)), {"text": mt.get("text", "")})
	Save.flags.erase("hollow_open")
	Save.bows = keep_bows
	Save.bow = keep_bow
	Save.stations["bench"] = keep_bench


# ---------------------------------------------------------------- (r) the bow in the paw's drawn row shows every line
## Its level line and its own line can each take two drawn lines ("Level 8 of 8 · Upgrade the Bow Shop for more" over
## Ember's "Fire arrows: ... · 0.8 m shorter range"). At the Shop's cap, on mastery 1/2 and in the inspect view the
## drawn Label shows every line, so the bow's downside at the end is on screen (Q10 a: the row keeps its _bow_note
## line). The checks above compare the spec's words; this one reads the drawn row.
func _row_lines() -> void:
	_start_fresh()
	var win = _win()
	var hud = main.hud
	Save.stations["bench"] = Data.bow_shop_level("ember")
	Save.bows["ember"] = Data.bow_cap()
	Save.bow = "ember"
	hud.show_card(win.ring())
	await t._wait(0.5)
	await _all_lines("at the Shop's cap", "Upgrade the %s for more" % _st()._name("bench"), "bowshop_row_cap")
	hud.hide_card()
	await t._wait(0.3)
	Save.stations["bench"] = 5
	Save.set_flag("hollow_open")
	Save.bows["ember"] = (Data.bow_info("ember")["cost"] as Array).size()      # level 10: next is mastery 1/2
	hud.show_card(win.ring())
	await t._wait(0.5)
	await _all_lines("on mastery 1/2", "Mastery 1/", "bowshop_row_mastery")
	win.show_bow("ember")
	await t._wait(0.6)
	await _all_lines("in its inspect view (mastery 1/2)", "Mastery 1/", "bowshop_row_inspect")
	hud.hide_card()
	await t._wait(0.3)
	_start_fresh()


## The open dialog draws Ember's row words whole (they hold `must`), scrolled into view for the screenshot `shot`.
func _all_lines(what: String, must: String, shot: String) -> void:
	var words := String(_win().bow_row("ember").get("text", ""))
	var l := _label_showing(words)
	var n: int = l.get_line_count() if l != null else -1
	var shown: int = l.get_visible_line_count() if l != null else -1
	var most: int = l.max_lines_visible if l != null else -1
	_x("Q10 a: %s the Ember row shows all %d of its lines, down to the end of its own line ('%s')" % [what, n, String(BOW_NOTES["ember"]).get_slice(" · ", 1)],
		l != null and words.contains(must) and words.ends_with(String(BOW_NOTES["ember"])) and (most < 0 or n <= most) and shown == n,
		{"lines": n, "shown": shown, "max": most, "text": words})
	if l != null and main.hud._card_scroll != null and is_instance_valid(main.hud._card_scroll):
		(main.hud._card_scroll as ScrollContainer).ensure_control_visible(l)
		await get_tree().process_frame
		await get_tree().process_frame
	await t._shot(shot)


## The open dialog's live Label showing exactly these words, or null.
func _label_showing(words: String) -> Label:
	var list = main.hud._card_list
	if main.hud._card == null or list == null or not is_instance_valid(list) or words == "":
		return null
	for l in (list as Node).find_children("*", "Label", true, false):
		if String((l as Label).text) == words and (l as Control).is_visible_in_tree() and not _going(l):
			return l as Label
	return null


# ---------------------------------------------------------------- (u) the pinned Upgrade and the confirm
func _footer() -> void:
	_start_fresh()
	var win = _win()
	var hud = main.hud
	var n: int = Data.building_levels("bench").size()
	var f: Dictionary = win.spec()["footer"]
	var btns: Array = f.get("buttons", [])
	_x("the footer: 'Level 1 of %d', the next level's price, Upgrade on even with 0 leaves (Q2 a), no '!'" % n,
		String(f.get("text", "")) == _w("level_of") % [1, n] and f.get("cost", {}) == Data.level_price("bench", 2) and btns.size() == 1
		and String(btns[0].get("label", "")) == _w("upgrade") and bool(btns[0].get("enabled", false)) and not bool(f.get("pulse", true))
		and not win.pulse(), {"footer": f.get("text", ""), "cost": f.get("cost", {})})
	var price: Dictionary = Data.level_price("bench", 2)
	Save.leaves = int(price.get("leaves", 0))
	Save.timber = int(price.get("timber", 0))
	hud.show_card(win.ring())
	await t._wait(0.5)
	var fb: Button = hud.p_card.footer_button(_w("upgrade"))
	_x("the open Bow Shop has its Upgrade in the footer, outside the scrolling list, inside the dialog and the screen",
		fb != null and bool(fb.get_meta("footer", false)) and not hud._card_scroll.is_ancestor_of(fb) and _on_card_and_screen(fb))
	if fb == null:
		hud.hide_card()
		return
	fb.pressed.emit()
	await t._wait(0.4)
	var cs: Dictionary = hud.confirm.spec()
	var want_lines := _capitalised(win.gives(2))
	_x("Upgrade asks first: the confirm 'Bow Shop level 2' lists what level 2 gives (it sells the Sunwood Longbow) and its price",
		hud.card_ring() == hud.confirm and String(cs.get("title", "")) == "Bow Shop level 2" and _confirm_lines() == want_lines
		and String(", ".join(want_lines)).contains(_bname("sunwood")) and (cs["footer"] as Dictionary).get("cost", {}) == price,
		{"title": cs.get("title", ""), "lines": _confirm_lines()})
	await t._shot("bowshop_confirm")
	var cancel: Button = hud.p_card.footer_button(_w("cancel"))
	if cancel != null:
		cancel.pressed.emit()
	await t._wait(0.4)
	_x("Cancel goes back to the Bow Shop and changes nothing", hud.card_ring() == win.ring() and int(Save.stations["bench"]) == 1
		and Save.leaves == int(price.get("leaves", 0)), {"bench": Save.stations["bench"], "leaves": Save.leaves})
	fb = hud.p_card.footer_button(_w("upgrade"))
	if fb != null:
		fb.pressed.emit()
	await t._wait(0.4)
	var ok_b: Button = hud.p_card.footer_button(_w("confirm"))
	if ok_b != null:
		ok_b.pressed.emit()
	await t._wait(0.4)
	var f2: Dictionary = win.spec()["footer"]
	_x("Confirm pays exactly the price: the Bow Shop is level 2 and its window is back, 'Level 2 of %d'" % n,
		int(Save.stations["bench"]) == 2 and Save.leaves == 0 and Save.timber == 0 and hud.card_ring() == win.ring()
		and String(f2.get("text", "")) == _w("level_of") % [2, n], {"bench": Save.stations["bench"], "leaves": Save.leaves})
	hud.hide_card()
	await t._wait(0.3)


# ---------------------------------------------------------------- (v) the inspect view (Q11 a and b)
func _inspect_view() -> void:
	_start_fresh()
	var win = _win()
	var hud = main.hud
	var keep_stats: Dictionary = Save.stats.duplicate(true)
	Save.stats["damage"] = 3                            # the cat's Damage stat shows in the arrow's line
	Save.leaves = 100000
	hud.show_card(win.ring())
	await t._wait(0.5)
	var pic := _row_picture("twig")
	if not _x("the Twig's row shows its picture, which takes taps", pic != null and (_row("twig").get("on_picture", Callable()) as Callable).is_valid()):
		hud.hide_card()
		Save.stats = keep_stats
		return
	await t._tap_at(pic.get_global_rect().get_center())
	await t._wait(0.6)
	var mv = _model_view()
	var shown: Node3D = mv.shown() if mv != null else null
	var meshes: int = shown.find_children("*", "MeshInstance3D", true, false).size() if shown != null else 0
	_x("Q11 a: a real tap on the Twig's picture opens its inspect view in the same window: its name, a 3D view with the bow and its arrow, no footer",
		win.inspect == "twig" and hud.card_ring() == win.ring() and hud.card_title() == _bname("twig") and mv != null and meshes >= 2
		and not hud.p_card.foot.visible and hud.p_card.footer_button(_w("upgrade")) == null,
		{"inspect": win.inspect, "title": hud.card_title(), "meshes": meshes})
	var texts := _texts(hud._card_list)
	var want: Array = win._inspect.lines("twig")
	var dmg_pct := roundi(float(Data.bow_info("twig")["damage"]) * Data.bow_level_mult("twig", 1) * 100.0)
	_x("it shows the bow's damage at its level ('Damage %d%%'), its own line, its level, and its own row and Back" % dmg_pct,
		want.size() >= 3 and String(want[0]) == _w("bow_damage") % dmg_pct and String(want[1]) == BOW_NOTES["twig"]
		and String(want[2]) == _w("bow_level") % [1, Data.bow_cap()] and want.all(func(s): return texts.has(s))
		and _button(_w("back")) != null and _button(_w("upgrade")) != null, {"lines": want, "texts": texts})
	_lay._card_fits("bow inspect")
	# Q11 b: what each arrow of a bow really hits for (the number a shot uses), with the cat's Damage stat; any bow, the
	# one in the paw (Data.arrow_damage()) and one not owned (Data.arrow_damage("sunwood"), at level 1)
	var stat_now := "+%d%%" % roundi(float(Data.stat_info("damage")["per_level"]) * 3.0 * 100.0)
	var hit: String = win._inspect.arrow_hit("twig")
	var want_hit := BowInspect.ARROW_HIT % [_st()._short_num(Data.arrow_damage()), stat_now]
	var sun_hit: String = win._inspect.arrow_hit("sunwood")
	var want_sun := BowInspect.ARROW_HIT % [_st()._short_num(Data.arrow_damage("sunwood")), stat_now]
	_x("Q11 b: each arrow's real damage, Data.arrow_damage() (%s), with the cat's Damage %s; a bow not owned shows its own (%s)" % [_st()._short_num(Data.arrow_damage()), stat_now, _st()._short_num(Data.arrow_damage("sunwood"))],
		hit == want_hit and texts.has(hit) and sun_hit == want_sun and Data.arrow_damage("sunwood") > Data.arrow_damage() and Data.arrow_damage(Save.bow) == Data.arrow_damage(),
		{"line": hit, "want": want_hit, "sunwood": sun_hit, "want_sun": want_sun})
	var base := Data.arrow_damage()
	main.player.effects.add({"type": "stat_mult", "target": "cat", "stat": "damage", "mult": 0.25, "seconds": 30.0}, "bowshop_test")
	hud.refresh_card()
	await t._wait(0.2)
	var hit_p: String = win._inspect.arrow_hit("twig")
	var want_p := BowInspect.ARROW_HIT_POTION % [_st()._short_num(Data.arrow_damage()), stat_now, "+25%"]
	_x("... and with a Damage Potion running the line grows with it (x1.25) and says so",
		absf(Data.arrow_damage() - base * 1.25) < 0.001 and hit_p == want_p and _texts(hud._card_list).has(hit_p), {"line": hit_p, "want": want_p})
	main.player.effects.clear()
	hud.refresh_card()
	await t._wait(0.3)
	await t._shot("bowshop_inspect_twig")
	# a save rebuilds the window: the same 3D view, its turn going on from where it was
	await t._wait(0.5)
	var r0: float = mv.turned() if mv != null and is_instance_valid(mv) else 0.0
	Save.changed.emit()
	var same: bool = _model_view() == mv
	var r1: float = mv.turned() if mv != null and is_instance_valid(mv) else 0.0
	await t._wait(0.4)
	var r2: float = mv.turned() if mv != null and is_instance_valid(mv) else 0.0
	_x("a save (Save.changed) rebuilds the window but keeps the same 3D view, turning on from where it was",
		same and mv != null and is_instance_valid(mv) and mv.is_inside_tree() and r0 > 0.05 and is_equal_approx(r1, r0) and wrapf(r2 - r1, 0.0, TAU) > 0.05,
		{"same": same, "r0": r0, "r1": r1, "r2": r2})
	# its own button works in the view (the bow's Upgrade): the view stays
	var lv0 := int(Save.bows["twig"])
	t._press(_w("upgrade"))
	await t._wait(0.3)
	_x("the bow's own Upgrade works in the view, which stays (the same 3D view)", int(Save.bows["twig"]) == lv0 + 1 and win.inspect == "twig"
		and _model_view() == mv, {"twig": Save.bows["twig"]})
	# Back: the list again, the view's visit over and its 3D view freed
	var back := _button(_w("back"))
	var had_back := back != null                        # read now: the pressed button is freed with the view
	if had_back:
		back.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	await t._wait(0.2)
	_x("Back returns to the list (its footer back) and ends the view's visit: closed() ran and the 3D view is freed",
		had_back and win.inspect == "" and hud.card_title() == "Bow Shop" and hud.p_card.foot.visible
		and hud.p_card.footer_button(_w("upgrade")) != null and win._inspect._view == null and not is_instance_valid(mv)
		and hud._card_window_open == null and _list_rows().size() == _rows().size(),
		{"title": hud.card_title(), "back": had_back, "inspect": win.inspect, "foot": hud.p_card.foot != null and hud.p_card.foot.visible,
		"up": hud.p_card.footer_button(_w("upgrade")) != null, "view": win._inspect._view == null, "freed": not is_instance_valid(mv),
		"open": hud._card_window_open == null, "drawn": _list_rows().size(), "rows": _rows().size()})
	# a locked bow can be looked at too
	(_row("frost")["on_picture"] as Callable).call()
	await t._wait(0.5)
	var fl: Array = win._inspect.lines("frost")
	var labels: Array = hud.card_buttons().filter(func(b): return (b as Control).is_visible_in_tree() and not _going(b)).map(func(b): return String(b.get_meta("label", "")))
	var frost_pct := roundi(float(Data.bow_info("frost")["damage"]) * Data.bow_level_mult("frost", 1) * 100.0)
	var frost_hit := BowInspect.ARROW_HIT % [_st()._short_num(Data.arrow_damage("frost")), stat_now]
	_x("a locked bow can be looked at: its damage at level 1 (%d%%), its line and its arrow's hit, no level; its row Locked with no button, then Back" % frost_pct,
		win.inspect == "frost" and hud.card_title() == _bname("frost") and fl == [_w("bow_damage") % frost_pct, BOW_NOTES["frost"], frost_hit]
		and _model_view() != null and labels == [_w("back")]
		and _list_rows().any(func(r): return String(r.get_meta("id", "")) == "frost"), {"lines": fl, "buttons": labels})
	await t._shot("bowshop_inspect_frost")
	var fmv = _model_view()
	await t._tap_close()
	await get_tree().process_frame
	_x("the X closes it all: the next visit starts on the list, the 3D view is freed", hud._card == null and win.inspect == ""
		and win._inspect._view == null and not is_instance_valid(fmv))
	Save.stats = keep_stats


# ---------------------------------------------------------------- (p) all six bows at both phone shapes
func _phones() -> void:
	_start_fresh()
	var win = _win()
	var hud = main.hud
	var keep_size: Vector2i = get_window().size
	for bid in Data.bow_ids():
		Save.bows[bid] = 1
	Save.stations["bench"] = 3
	for shape: Vector2i in [Vector2i(540, 960), Vector2i(480, 1040)]:
		get_window().size = shape
		await t._wait(0.6)
		hud.show_card(win.ring())
		await t._wait(0.6)
		var where := "%dx%d" % [shape.x, shape.y]
		var drawn: Array = _list_rows().map(func(r): return String(r.get_meta("id", "")))
		_x("all six bows owned: six rows in the shop's order (%s)" % where, drawn == Data.bow_ids(), {"rows": drawn})
		_lay._card_fits("bowshop " + where)
		var fb: Button = hud.p_card.footer_button(_w("upgrade"))
		var sc: ScrollContainer = hud._card_scroll
		var scrolls: bool = hud._card_list.size.y > sc.size.y + 1.0
		var at_top := fb != null and _on_card_and_screen(fb)
		sc.scroll_vertical = int(sc.get_v_scroll_bar().max_value)
		await get_tree().process_frame
		await get_tree().process_frame
		var end_y := sc.scroll_vertical
		var at_end := fb != null and is_instance_valid(fb) and _on_card_and_screen(fb)
		sc.scroll_vertical = 0
		_x("the footer's Upgrade is not in the scrolling list and stays inside the dialog and the screen at the list's top and end (%s)" % where,
			fb != null and not sc.is_ancestor_of(fb) and at_top and at_end, {"scrolls": scrolls, "end": end_y})
		await t._shot("bowshop_list_%d" % shape.x)
		hud.hide_card()
		await t._wait(0.3)
	get_window().size = keep_size
	await t._wait(0.6)
	_start_fresh()


# ---------------------------------------------------------------- (z) the "!" follows "enabled" (with the price in it)
func _pulse() -> void:
	_start_fresh()
	var win = _win()
	var ring = win.ring()
	var on: Array = (win.spec()["rows"] as Array).filter(func(r): return bool(r.get("enabled", false)))
	_x("with 0 leaves no row of the Bow Shop is on and its marker shows no '!' (a row's 'on' includes its price)",
		on.is_empty() and not win.pulse() and not ring.pulse, {"on": on.map(func(r): return r.get("title", "")), "pulse": ring.pulse})
	Save.leaves = int(Data.bow_cost("twig", 1)["leaves"])
	_st().refresh()
	_x("with the Twig's upgrade price its row is on and the marker shows '!'", bool(_row("twig").get("enabled", false)) and win.pulse()
		and ring.visible and ring.pulse, {"visible": ring.visible, "pulse": ring.pulse})
	win.inspect = "twig"
	_x("... also while a bow is looked at (the '!' follows the list)", win.pulse())
	win.inspect = ""
	_start_fresh()


# ---------------------------------------------------------------- (t) the Training Target
func _trow(rows: Array, sid: String) -> Dictionary:
	for r in rows:
		if String(r.get("id", "")) == sid:
			return r
	return {}


func _target() -> void:
	_start_fresh()
	var keep_stats: Dictionary = Save.stats.duplicate(true)
	for k in Save.stats:
		Save.stats[k] = 0
	Save.stations["target"] = 1
	_st().refresh()
	var tw = _twin()
	var hud = main.hud
	var rows: Array = tw.spec()["rows"]
	var names: Array = T_STATS.map(func(s): return String(Data.stat_info(s)["name"]))
	_x("(t) the Training Target is a list of three stat rows in order (Damage, Draw speed, Range)",
		rows.map(func(r): return r.get("title", "")) == names and rows.all(func(r): return String(r.get("kind", "")) == "list"),
		{"rows": rows.map(func(r): return r.get("title", ""))})
	var cap := Data.stat_cap("damage")
	var next_ok := true
	for sid in ["damage", "draw"]:
		var r := _trow(rows, sid)
		var info := Data.stat_info(sid)
		var want := "%s\n%s" % [String(info["says"]), _w("stat_next_first") % ("+%d%%" % roundi(float(info["per_level"]) * 100.0))]
		next_ok = next_ok and String(r.get("text", "")) == want and String(r.get("label", "")) == "Buy" and String(r.get("badge", "")) == "Level 0/%d" % cap \
			and r.get("cost", {}) == Data.stat_cost(sid, 0)
	_x("(t) Damage and Draw speed: what they do, then 'Next: +12%%' (what the next level gives), 'Level 0/%d' and Buy with the price" % cap, next_ok,
		{"damage": _trow(rows, "damage").get("text", ""), "draw": _trow(rows, "draw").get("text", "")})
	var rg := _trow(rows, "range")
	_x("(t) Range shows Locked below Target level 2, with no button", String(rg.get("badge", "")) == "Locked" and String(rg.get("label", "")) == ""
		and String(rg.get("text", "")).ends_with("Upgrade the Training Target to unlock"), {"range": rg.get("text", "")})
	_x("(t) with 0 leaves no stat row is on and the Target shows no '!'", rows.all(func(r): return not bool(r.get("enabled", false))) and not tw.pulse())
	Save.leaves = 1000
	_x("(t) with leaves Damage's Buy is on", bool(_trow(tw.spec()["rows"], "damage").get("enabled", false)))
	_st()._buy_stat("damage")
	var dm := _trow(tw.spec()["rows"], "damage")
	var per := "+%d%%" % roundi(float(Data.stat_info("damage")["per_level"]) * 100.0)
	_x("(t) after one Damage: 'Next: +12%% · now +12%%', 'Level 1/%d'" % cap,
		String(dm.get("text", "")) == "%s\n%s" % [String(Data.stat_info("damage")["says"]), _w("stat_next") % [per, per]]
		and String(dm.get("badge", "")) == "Level 1/%d" % cap, {"text": dm.get("text", "")})
	var f: Dictionary = tw.spec()["footer"]
	var n: int = Data.building_levels("target").size()
	_x("(t) its footer: 'Level 1 of %d', Upgrade; level 2 gives 'Stats up to level 6' and 'unlocks Range' (the old tile's line unchanged)" % n,
		String(f.get("text", "")) == _w("level_of") % [1, n] and (f.get("buttons", []) as Array).size() == 1
		and tw.gives(2) == ["Stats up to level %d" % int((Data.b["stat_cap_by_station_level"] as Array)[2]), "unlocks " + String(Data.stat_info("range")["name"])]
		and String(tw.upgrade_tile().get("text", "")) == "Stats up to level 6, unlocks Range", {"gives": tw.gives(2)})
	var price: Dictionary = Data.level_price("target", 2)
	Save.leaves = int(price.get("leaves", 0))
	Save.timber = int(price.get("timber", 0))
	hud.show_card(tw.ring())
	await t._wait(0.5)
	_lay._card_fits("target")
	await t._shot("bowshop_target")
	var fb: Button = hud.p_card.footer_button(_w("upgrade"))
	var had_fb := fb != null                            # read now: the pressed button is freed with the Target's card
	if had_fb:
		fb.pressed.emit()
	await t._wait(0.4)
	_x("(t) its Upgrade asks first: 'Training Target level 2' with 'Stats up to level 6' and 'Unlocks Range'", had_fb and hud.card_ring() == hud.confirm
		and String(hud.confirm.spec().get("title", "")) == "Training Target level 2" and _confirm_lines() == _capitalised(tw.gives(2)),
		{"lines": _confirm_lines(), "title": hud.confirm.spec().get("title", ""), "fb": had_fb})
	await t._shot("bowshop_target_confirm")
	var ok_b: Button = hud.p_card.footer_button(_w("confirm"))
	if ok_b != null:
		ok_b.pressed.emit()
	await t._wait(0.4)
	var rg2 := _trow(tw.spec()["rows"], "range")
	_x("(t) Confirm: the Target is level 2 (its price paid), its window is back, and Range opens (Level 0/%d, Buy)" % Data.stat_cap("range"),
		int(Save.stations["target"]) == 2 and Save.leaves == 0 and hud.card_ring() == tw.ring() and String(rg2.get("badge", "")) == "Level 0/%d" % Data.stat_cap("range")
		and String(rg2.get("label", "")) == "Buy", {"range": "%s/%s" % [rg2.get("badge", ""), rg2.get("label", "")]})
	hud.hide_card()
	await t._wait(0.3)
	Save.stats = keep_stats
	_start_fresh()
