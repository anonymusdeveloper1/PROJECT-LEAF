extends "res://ui/windows/building_window.gd"
## H5 (Stage 2, 27 Nov 2026; the H5 map parts 1 and 3.4, the owner's answers Q2 and Q3): the Saddlery's window (building
## and marker "saddlery": the mount's skills and attachments, G4). Two tabs at the bottom (card.gd "tabs_at": "bottom"),
## each with its icon and its word, Attachments first; a fresh visit always opens on Attachments.
##   Attachments   "Patch it up" when raids wore it, then the Saddlery's attachments (the Fire-spitter, the Mossweave
##                 Saddle, the Saddlebags: content/attachments with "shop": "saddlery", in the index's order) as big
##                 pictures (ui/kit/icon_grid.gd): the price under one not owned yet, else "Worn · Level 2/5" or
##                 "Owned · Level 1/5". A tap on one opens its detail in this window (ui/windows/attachment_inspect.gd):
##                 the attachment turning, fitted to the mount out now, what it does, and one button: Buy (not owned),
##                 Wear (owned and not worn; between waves), Upgrade (the worn one, while the Saddlery's level and the
##                 Burrows allow), else a grey Worn with the reason. The mount wears one at a time (the owner, 22 Nov 2026).
##   Skills        the three skill circles joined in a triangle (ui/kit/skill_triangle.gd) over the round skill icons,
##                 and the Saddlery's own Upgrade pinned at the bottom (ui/windows/saddlery_skills.gd draws the tab and a
##                 skill's detail). A learned skill is dragged into a circle to use it; a tap on a filled circle empties
##                 it; every mount shares the circles; 0 to 3 skills are used, never 4 (Q3), and a fourth learned one
##                 stays in the grid with its level. A tap on a skill's icon opens its detail: Learn or Upgrade.
## The Saddlery's Upgrade asks first in the confirm window: the skill and attachment cap it gives and the mount's speed
## and health at that level (Data.mount_level_at_saddlery, mount_speed_at, mount_base_hp_at: the very tables riding and
## the mount's health read), and, when an old Market's tier still decides, that the building is catching up (Q2).
## Confirm and Cancel come back to the Skills tab. A player short of leaves can still open it (the price is red there).
## Buy, Learn, an item's Upgrade and Wear are one tap, no confirm. Every button that pays checks again when it is
## pressed that the level it showed is still the next one (commands/buy.gd expected_level), so a stale tap never buys
## a second level, then runs the rule in stations.gd (_saddle_buy, _saddle_wear: the receipts, the gear model on the
## mount and the saddle's health stay there). Knocked down: only the ruin card. A wave blanks the card (card.gd).
## The window API (the map, part 3.4): select(tab), tab_ids(), entries(tab), entry(part, id), inspect(id), back(),
## open_on(tab), gives(level), pulse(), and act(part, id, expected) for a button. It is also the window row of the
## Attachments tab's grid (content, tick, opened, closed).
## Used by: ui/windows/window_list.gd (hud.windows["saddlery"]), stations.gd (the marker's builder and its "!"),
##          attachment_inspect.gd and saddlery_skills.gd (entry, act, back, shown_id), the tests.
## Uses: Data (saddle_items, saddle_info, saddle_top, saddle_block, saddle_price, skill_level, attach_level,
##       worn_attach, skill_is_slotted, shop_picture, saddlery_level, mount_level_at_saddlery, mount_speed_at,
##       mount_base_hp_at, mount_hp_mult, mount_name, level_price, word), Save, commands/buy.gd (can_run: the one check
##       a purchase passes), the rules in stations.gd (_saddle_buy, _saddle_wear, _upgrade_station, _locked, _name,
##       _short_num), ui/kit/icon_grid.gd, the confirm window (hud.confirm), the card's scroll (hud._card_scroll).

const Buy := preload("res://commands/buy.gd")
const IconGrid := preload("res://ui/kit/icon_grid.gd")
const AttachmentInspect := preload("res://ui/windows/attachment_inspect.gd")
const SaddlerySkills := preload("res://ui/windows/saddlery_skills.gd")

const TABS := ["attachments", "skills"]                      # in their order along the bottom
const TAB_ICONS := {"attachments": "saddlebags", "skills": "stomp"}   # each tab's picture (ui_icons.gd ids)
const SKILLS_VIEW := "saddlery_skills"   # the Skills tab's view_id: a leaf pickup or a save never redraws it under a drag
## H5 words: not in balance.json "windows" yet. Data.word(key) is used when it has the key; this is only the fallback.
const H5_WORDS := {
	"saddlery_sub": "Level %d · %s uses its skills and wears one attachment while you ride",
}

var tab := "attachments"                # the tab showing: "attachments" or "skills"
var shown_id := ""                      # the attachment or skill whose detail shows ("" = the tab's overview)
var _next_tab := ""                     # the tab the next visit opens on (open_on, the confirm's way back); "" = Attachments
var _list_scroll := 0                   # how far the overview was scrolled when a detail opened (Back goes there)
var _attach_view: AttachmentInspect     # the attachment detail: the card's window row while one is looked at
var _skills: SaddlerySkills             # the Skills tab and a skill's detail: its window row


func _init(owner_hud) -> void:
	super(owner_hud, "saddlery", "saddlery")
	_attach_view = AttachmentInspect.new(self)
	_skills = SaddlerySkills.new(self)


## The card now: the ruin card, or the tab showing (its overview or the detail looked at) with the two tabs.
func spec() -> Dictionary:
	if Save.ruined.has(id):
		return _ruin_card(id, st._name(id), _anchor(id, 1.6))
	var showing := tab if TABS.has(tab) else "attachments"
	var s := {"title": st._name(id), "sub": _sub(), "anchor": _anchor(id, 1.6), "tabs": _tabs(showing), "tabs_at": "bottom"}
	var looked := part_of(shown_id)
	if showing == "skills":
		s["rows"] = [{"kind": "window", "window": _skills, "enabled": true}]
		if looked != "skills":                          # the overview: the triangle, the grid and the pinned Upgrade
			s["footer"] = upgrade_footer()
			s["view_id"] = SKILLS_VIEW + ":" + _levels()   # a new learned level redraws it; a circle's change is drawn in place
		return s
	if looked == "attach":
		s["rows"] = [{"kind": "window", "window": _attach_view, "enabled": true}]
		return s
	var rows: Array = as_list(_wear_row(id))
	rows.append({"kind": "window", "window": self, "enabled": true})
	s["rows"] = rows
	return s


func tab_ids() -> Array:
	return TABS.duplicate()


## A tap on a tab: that tab's overview, from its top.
func select(t: String) -> void:
	if not TABS.has(t):
		return
	tab = t
	shown_id = ""
	if _open():
		if hud._card_scroll != null and is_instance_valid(hud._card_scroll):
			hud._card_scroll.scroll_vertical = 0
		hud.refresh_card()


## The next visit opens on tab t (a goal's Go, the confirm's way back); when this window is open now, t shows at once.
## It does not open the card or walk the cat: the caller does that (a tap on the marker, main.open_ring, reopen()).
func open_on(t: String) -> void:
	if not TABS.has(t):
		return
	if _open():
		select(t)
	else:
		_next_tab = t


## A visit starts: on Attachments, or on the tab asked for once (open_on, the confirm's way back).
func card_opened() -> void:
	tab = _next_tab if TABS.has(_next_tab) else "attachments"
	_next_tab = ""
	shown_id = ""


func card_closed() -> void:
	shown_id = ""


## The bottom tabs: the icon and the word of each, the one showing selected, and the small "!" on a tab where
## something can be bought now.
func _tabs(showing: String) -> Array:
	var out: Array = []
	for t: String in TABS:
		out.append({"id": t, "text": _w("tab_" + t), "icon": String(TAB_ICONS[t]), "selected": t == showing,
			"enabled": true, "action": select.bind(t), "dot": _tab_dot(t)})
	return out


func _sub() -> String:
	return _word("saddlery_sub") % [Data.saddlery_level(), Data.mount_name()]


## The skills' learned levels in their order ("1,0,2,0"): part of the Skills tab's view_id, so its grid redraws when a
## level changes, while a drop on a circle (saddlery_skills.gd draws that in place) never redraws the card.
func _levels() -> String:
	var bits := PackedStringArray()
	for sid in Data.saddle_items("skills"):
		bits.append(str(Data.skill_level(String(sid))))
	return ",".join(bits)


# ---------------------------------------------------------------- what each attachment and skill can do now
## The tab's attachments ("attachments") or skills ("skills"), in their order, each as entry() gives it.
func entries(t: String) -> Array:
	var part := "skills" if t == "skills" else "attach"
	var out: Array = []
	for sid in Data.saddle_items(part):
		out.append(entry(part, String(sid)))
	return out


## One attachment's (part "attach") or skill's (part "skills") state now, for its picture, its detail and the tests:
##   {"id", "part", "name", "icon", "picture", "level", "top", "block" (Data.saddle_block), "state", "action", "label",
##    "price", "next", "can", "why"}
##   state    an attachment "new", "owned" or "worn"; a skill "new", "learned" or "slotted" (in a circle)
##   action   "buy", "learn", "upgrade", "wear", or "" when nothing can be done now (label is then the grey button's word)
##   price    what the action costs ({} for Wear and for none); next: the level it reaches (Buy's expected_level)
##   can      the action can run now, its price included (commands/buy.gd can_run; Wear: between waves)
##   why      why it can't go further, money aside: "Upgrade the Saddlery for more", "Level 4 opens after the Raid
##            Missions", "Max level", "Between waves" ("" when it can, or when only leaves or timber are short: the
##            price shows them red)
func entry(part: String, sid: String) -> Dictionary:
	var skills := part == "skills"
	var info := Data.saddle_info(part, sid)
	var lv: int = Data.skill_level(sid) if skills else Data.attach_level(sid)
	var block := Data.saddle_block(part, sid)
	var worn := not skills and lv >= 1 and Data.worn_attach() == sid
	var e := {"id": sid, "part": part, "name": String(info.get("name", sid)), "icon": String(info.get("icon", "saddlery")),
		"picture": "" if skills else Data.shop_picture("attachments", sid), "level": lv, "top": Data.saddle_top(part, sid),
		"block": block, "action": "", "label": "", "price": {}, "next": lv + 1, "can": false, "why": ""}
	if skills:
		e["state"] = "new" if lv <= 0 else ("slotted" if Data.skill_is_slotted(sid) else "learned")
	else:
		e["state"] = "new" if lv <= 0 else ("worn" if worn else "owned")
	if not skills and lv >= 1 and not worn:            # owned, not worn: Wear it (free, between waves)
		var mid: bool = st._locked()
		e["action"] = "wear"
		e["label"] = _w("wear")
		e["can"] = not mid and not Save.ruined.has(id)
		e["why"] = _w("between_waves") if mid else ""
		return e
	if block == "":
		e["action"] = ("learn" if skills else "buy") if lv <= 0 else "upgrade"
		e["label"] = _w(String(e["action"]))
		e["price"] = Data.saddle_price(part, sid, lv + 1)
		var why: String = Buy.new("skills" if skills else "attachments", sid, 1, lv + 1).can_run(main)
		e["can"] = why == ""
		if why != "" and Data.can_afford(e["price"] as Dictionary):
			e["why"] = why                              # not the money (the red price says that): Buy's own reason
		return e
	e["label"] = _w("worn") if worn else (_w("max") if block == "max" else _w("upgrade" if lv >= 1 else ("learn" if skills else "buy")))
	match block:
		"cap":
			e["why"] = _w("saddle_cap_hint") % st._name(id)
		"burrows":
			e["why"] = _w("opens_after_missions") % (lv + 1)
		"max":
			e["why"] = _w("max")
		_:
			e["why"] = _w("coming_later")                 # no Saddlery standing (the card shows its ruin card then)
	return e


## The part an id belongs to: "skills" (a mount skill), "attach" (a Saddlery attachment shown here), else "".
func part_of(sid: String) -> String:
	if sid == "":
		return ""
	if not Data.saddle_info("skills", sid).is_empty():
		return "skills"
	return "attach" if Data.saddle_items("attach").has(sid) else ""


## A detail's one button (or a grid's): runs its action once. `expected` is the level the button showed it reaching: when
## the level moved on since it was drawn, nothing is bought (commands/buy.gd). The rules in stations.gd pay and do the
## rest (the receipt, the gear model and the saddle's health on the mount); the card redraws after the press.
func act(part: String, sid: String, expected: int) -> void:
	var e := entry(part, sid)
	match String(e["action"]):
		"wear":
			if bool(e["can"]):
				st._saddle_wear(sid)
		"buy", "learn", "upgrade":
			if Buy.new("skills" if part == "skills" else "attachments", sid, 1, expected).can_run(main) == "":
				st._saddle_buy(part, sid, expected)


# ---------------------------------------------------------------- the marker's "!" and the tabs' dots
## The marker's "!": something on either tab can be bought now (a Buy, Learn or Upgrade whose price can be paid;
## "Patch it up"), or the Saddlery's own Upgrade can be paid. In ruins: the ruin card's Repair, as on every building.
func pulse() -> bool:
	if Save.ruined.has(id):
		return super.pulse()
	return _tab_dot("attachments") or _tab_dot("skills")


func _tab_dot(t: String) -> bool:
	if t == "attachments":
		for r in _wear_row(id):
			if _lights(r):
				return true
	for e: Dictionary in entries(t):
		if bool(e["can"]) and String(e["action"]) != "wear":   # Wear is free: it never lights the "!"
			return true
	return t == "skills" and bool(upgrade_footer().get("pulse", false))


# ---------------------------------------------------------------- the details and Back
## Opens the detail of attachment or skill sid (its tab shows; the overview's scroll is kept for Back).
func inspect(sid: String) -> void:
	var part := part_of(sid)
	if part == "":
		return
	if shown_id == "" and _open() and hud._card_scroll != null and is_instance_valid(hud._card_scroll):
		_list_scroll = int(hud._card_scroll.scroll_vertical)
		hud._card_scroll.scroll_vertical = 0
	tab = "skills" if part == "skills" else "attachments"
	shown_id = sid
	if _open():
		hud.refresh_card()


## A detail's Back: its tab's overview again, scrolled back to where it was (the detail's window row ends its visit
## when the overview's row takes its place, so the turning attachment's 3D view is freed then).
func back() -> void:
	if shown_id == "":
		return
	shown_id = ""
	if _open():
		hud.refresh_card()
		_scroll_back(_list_scroll)


## Scrolls the overview back to y once its rows are laid out (two frames, as the Bow Shop does).
func _scroll_back(y: int) -> void:
	if y <= 0:
		return
	await hud.get_tree().process_frame
	await hud.get_tree().process_frame
	if shown_id == "" and _open() and hud._card_scroll != null and is_instance_valid(hud._card_scroll):
		hud._card_scroll.scroll_vertical = y


## This window's card is the one open now.
func _open() -> bool:
	return hud != null and ring() != null and hud.card_ring() == ring()


# ---------------------------------------------------------------- the Attachments tab's grid (a window row: this object)
## The attachments as big pictures (Data.shop_picture, else the entry's icon): the price under one not owned yet, else
## its state and level. A tap on a picture opens its detail. No button in the grid: the detail has the one action.
func content() -> Control:
	var cells: Array = []
	for e: Dictionary in entries("attachments"):
		var fresh := String(e["state"]) == "new"
		cells.append({"id": String(e["id"]), "title": String(e["name"]), "picture": String(e["picture"]),
			"icon": String(e["icon"]), "cost": e["price"] if fresh else {}, "note": "" if fresh else state_line(e)})
	return IconGrid.make(hud, cells, inspect)


func tick(_delta: float) -> void:
	pass


func opened() -> void:
	pass


func closed() -> void:
	pass


## An owned attachment's or learned skill's short state: "Worn · Level 2/5", "Owned · Level 1/5", "Level 3/5".
func state_line(e: Dictionary) -> String:
	var lv := _w("level_badge") % [int(e["level"]), int(e["top"])]
	match String(e["state"]):
		"worn":
			return _w("worn") + " · " + lv
		"owned":
			return _w("owned") + " · " + lv
		"new":
			return _w("new")
	return lv


# ---------------------------------------------------------------- the Saddlery's own Upgrade (on the Skills tab)
## What Saddlery level `level` gives, one line each: how far skills and attachments can go, the mount's speed and health
## at that level (the very numbers riding and its health use; with the Mossweave Saddle when it is worn), and, while an
## old Market's tier is still higher (the owner's Q2 A), that the mount keeps that tier until the Saddlery passes it.
func gives(level: int) -> Array:
	var out: Array = [_w("saddle_level_cap") % level]
	var ml := Data.mount_level_at_saddlery(level)
	if ml > 0:
		var faster: String = _short_num((Data.mount_speed_at(ml) - 1.0) * 100.0)
		out.append(_w("mount_speed_hp") % [Data.mount_name(), faster, roundi(float(Data.mount_base_hp_at(ml)) * Data.mount_hp_mult())])
		var credit := _credit()
		if credit >= level:
			out.append(_w("saddle_catching_up") % [Data.mount_name(), ml, st._name(id), credit])
	return out


## The pinned Upgrade's tap: the confirm window (what the next level gives and its price; Confirm stays grey while the
## price is short). Confirm runs stations._upgrade_station; Confirm and Cancel come back to the Skills tab.
func ask_upgrade() -> void:
	var lv := Data.station_level(id)
	hud.confirm.ask({"title": "%s level %d" % [String(Data.building(id).get("name", id)), lv + 1], "lines": gives(lv + 1),
		"cost": Data.level_price(id, lv + 1), "on_confirm": st._upgrade_station.bind(id), "back": _back_to_skills,
		"reason": _upgrade_reason})


## The confirm's way back: this window again, on the Skills tab (a fresh visit would open on Attachments).
func _back_to_skills() -> void:
	_next_tab = "skills"
	reopen()
	if not _open():
		_next_tab = ""                                  # it could not open now: the next visit starts on Attachments


## The mount tier an old save already paid for at the Market (Save.saddlery "mount_credit"; 0 for a new camp).
func _credit() -> int:
	var c: Variant = Save.saddlery.get("mount_credit", 0)
	return int(c) if c is int or c is float else 0


## A window word: balance.json "windows" when it has it, else this file's H5_WORDS.
func _word(key: String) -> String:
	var w := Data.word(key)
	return String(H5_WORDS.get(key, key)) if w == key else w
