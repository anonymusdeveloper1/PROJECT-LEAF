extends RefCounted
## H4: the shared base of every building's window (ui/windows/, one file per building; docs/ARCHITECTURE.md part 2).
## A window builds the words and rows of its building's card and nothing else. Everything that pays, changes the save,
## moves something in the camp or plays an effect stays in stations.gd (main.stations, `st` here) under its old name,
## and a window calls it as st.<name> (for example st._upgrade_station.bind(id)). A window may read Save and Data.
## How it plugs in: ui/windows/window_list.gd makes one window per building (hud.windows, keyed by its marker's id);
## stations.use_windows sets each marker's builder to its window's spec(), so the card (ui/kit/card.gd) draws spec(),
## and the marker's "!" comes from pulse(). The card also tells a window when a visit starts and ends (card_opened,
## card_closed: the builder's object hears them).
## H4 Stage 1: every window still returns today's rows (shop tiles under shelf headings), so every card looks exactly
## as before. upgrade_footer (the pinned Upgrade), ask_upgrade (the confirm window), list_row and as_list are ready for
## Stage 2's windows.
## Used by: every window in ui/windows/ (they extend this file), defences_tab.gd and stat_list.gd (their rows),
##          stations.gd (spec, pulse, and the old card names the tests still call in Stage 1), the tests.
## Uses: Data (the building entries and the words, Data.word), Save, the card's row kinds (plain rows, "item" tiles,
##       "section" headings; "list" rows and the footer from H4: ui/kit/card.gd, ui/kit/list_row.gd), the confirm window
##       (hud.confirm, ui/kit/confirm_window.gd), and the rules in stations.gd.

const CompanionShop := preload("res://scripts/companion_shop.gd")   # H5: its SLOT_KINDS (which content kind a slot's looks are)

var hud                         # the HUD node (untyped on purpose, as in the HUD's parts)
var main                        # hud.main
var st                          # main.stations: the rules (pay, level up, build) live there
var id := ""                    # the building id, the save's: "home", "target", "bench", "well", ...
var ring_id := ""               # its marker in st.rings: "shop" for the Hearthtree, else the same as id


func _init(owner_hud, building: String, marker_id: String) -> void:
	hud = owner_hud
	main = hud.main if hud != null else null
	st = main.stations if main != null else null
	id = building
	ring_id = marker_id


## The card now: {"title", "sub", "rows", "anchor"} (Stage 2 adds "footer" and "tabs"). Each window gives its own.
func spec() -> Dictionary:
	return {"title": "", "rows": []}


## The marker's "!": a row of spec() that is on, not quiet, and new or priced (the same rule as stations._update_pulses
## for a marker without a window), or the footer's pulse. A window with tabs checks every tab.
func pulse() -> bool:
	var s := spec()
	for row in s.get("rows", []):
		if _lights(row):
			return true
	return bool((s.get("footer", {}) as Dictionary).get("pulse", false))


## One row lights the "!": on, not quiet (the Market's everyday trades), and marked pulse or priced.
static func _lights(row: Variant) -> bool:
	if not (row is Dictionary):
		return false
	var r: Dictionary = row
	return bool(r.get("enabled", false)) and not bool(r.get("quiet", false)) \
		and (bool(r.get("pulse", false)) or not (r.get("cost", {}) as Dictionary).is_empty())


## What reaching `level` gives, one short line each, in today's words (the parts today's upgrade line joins with ", ").
## [] when the building has nothing to say.
func gives(_level: int) -> Array:
	return []


## A {"kind": "list"} row (ui/kit/list_row.gd draws it). Its `enabled` already includes the price, as _tile's does,
## because the marker's "!" reads `enabled` (a row on with too few leaves would light it). row_id is the row's own id.
func list_row(icon: String, title: String, text: String, cost: Dictionary, label: String, ok: bool,
		action: Callable, badge := "", row_id := "") -> Dictionary:
	var r := {"kind": "list", "id": row_id, "icon": icon, "title": title, "text": text, "cost": cost, "label": label,
		"enabled": ok and label != "" and action.is_valid() and Data.can_afford(cost), "action": action}
	if badge != "":
		r["badge"] = badge
	return r


## Copies of tile rows as list rows (the keys are shared), so a tile helper's rows (Patch it up, _wear_row) sit in a
## list window looking like the list rows.
func as_list(rows: Array) -> Array:
	var out: Array = []
	for r in rows:
		if r is Dictionary:
			var c: Dictionary = (r as Dictionary).duplicate()
			c["kind"] = "list"
			out.append(c)
	return out


## The building's own upgrade tile (stations._station_upgrade_row before H4): "Training Target level 2" with what the
## level gives (gives(), joined into one line), "Level 1/5", and Upgrade (never above the Hearthtree's level). At its
## top: the building's name and Max, no button.
func upgrade_tile() -> Dictionary:
	var lv := int(Save.stations[id])
	var levels: Array = Data.building_levels(id)
	var nm := String(Data.building(id)["name"])
	var icon := _station_icon(id)
	if lv >= levels.size() or (bool(levels[lv].get("needs_burrows", false)) and not Data.burrows_open()):
		return _tile(icon, nm, "At max level for now" if lv < levels.size() else "At max level", {}, "", false, Callable(), "Max", [["Level", 1.0]])
	var next: Dictionary = levels[lv]
	var cost: Dictionary = st._level_cost(next)
	var ok := lv + 1 <= Save.camp_level
	var says := ", ".join(gives(lv + 1))
	var text := says if ok else ("Needs %s at level %d" % [Data.camp_name(), lv + 1])
	return _tile(icon, "%s level %d" % [nm, lv + 1], text, cost, "Upgrade", ok, st._upgrade_station.bind(id),
		"Level %d/%d" % [lv, levels.size()], [["Level", float(lv) / float(maxi(levels.size(), 1))]])


## H4 (docs/PHASE_H_PLAN.md: "Buildings with levels have an Upgrade button fixed at the bottom"): the pinned Upgrade,
## a card's "footer" (ui/kit/card.gd). "Level 2 of 5" and the next level's price. The owner's answer (26 Nov 2026, Q2
## (a)): Upgrade always opens the confirm window, even when the price can't be paid yet (the price shows red there and
## Confirm stays grey); only the Hearthtree's level turns it off. The marker's "!" (pulse) shows only when it can be
## paid. At the top: "Max level" (or "Max level for now" while the next level waits for the Gloomwood), no button.
## Built in Stage 1, used by the windows from Stage 2.
func upgrade_footer() -> Dictionary:
	var lv := Data.station_level(id)
	var n: int = Data.building_levels(id).size()
	var text := _w("level_of") % [lv, n]
	var why := _upgrade_reason()
	if lv >= n or _waits_gloomwood(lv):
		return {"text": text, "note": why, "cost": {}, "buttons": [], "pulse": false}
	var cost: Dictionary = Data.level_price(id, lv + 1)
	var ok := why == ""
	return {"text": text, "note": why, "cost": cost,
		"buttons": [{"label": _w("upgrade"), "tone": "green", "enabled": ok, "action": ask_upgrade}],
		"pulse": ok and Data.can_afford(cost)}


## Why stations._upgrade_station would refuse now, leaving the price aside (the confirm checks that itself): "" when it
## may run, else the footer's note (at the top, waiting for the Gloomwood, or the Hearthtree too small).
func _upgrade_reason() -> String:
	var lv := Data.station_level(id)
	var n: int = Data.building_levels(id).size()
	if lv >= n:
		return _w("max")
	if _waits_gloomwood(lv):
		return _w("max_for_now")
	if lv + 1 > Save.camp_level:
		return _w("needs_home") % [Data.camp_name(), lv + 1]
	return ""


## The level after `lv` waits for the Gloomwood (its level entry says needs_burrows and the Burrows are not open yet).
func _waits_gloomwood(lv: int) -> bool:
	var levels: Array = Data.building_levels(id)
	if lv < 0 or lv >= levels.size():
		return false
	return bool((levels[lv] as Dictionary).get("needs_burrows", false)) and not Data.burrows_open()


## The pinned Upgrade's tap: the confirm window lists what the next level gives and its price; Confirm runs the rule
## (stations._upgrade_station), and Confirm or Cancel come back to this window (Q3 (a)).
func ask_upgrade() -> void:
	var lv := Data.station_level(id)
	hud.confirm.ask({"title": "%s level %d" % [String(Data.building(id).get("name", id)), lv + 1], "lines": gives(lv + 1),
		"cost": Data.level_price(id, lv + 1), "on_confirm": st._upgrade_station.bind(id), "back": reopen,
		"reason": _upgrade_reason})


## Back to this window (after the confirm): through main.open_ring when its marker shows and the cat is in reach (so
## the marker glows and walking away closes it, as a tap does), else straight onto the screen.
func reopen() -> void:
	var r = ring()
	if r == null:
		hud.hide_card()
		return
	if r.visible and main.player != null and r.in_reach(main.player.global_position):
		main.open_ring(r)
	else:
		hud.show_card(r)


## Its marker (marker.gd; null when there is none). Untyped, as stations.goal_ring: the marker's own functions
## (in_reach) are called on it.
func ring():
	return st.rings.get(ring_id) if st != null else null


## The card's visit hooks (ui/kit/card.gd): a visit starts (the card opens on this window) and ends (it closes or
## another card replaces it). Nothing by default.
func card_opened() -> void:
	pass


func card_closed() -> void:
	pass


## A word of balance.json "windows" (Data.word).
static func _w(key: String) -> String:
	return String(Data.word(key))


# ---------------------------------------------------------------- the card helpers (moved from stations.gd in H4)
## A plain row with a price (stations.gd keeps it for the campfire's card; this hands it on, no copy).
func _cost_row(text: String, note: String, cost: Dictionary, label: String, ok: bool, action: Callable) -> Dictionary:
	return st._cost_row(text, note, cost, label, ok, action)


## 1.5 -> "1.5", 1.0 -> "1", 3.0 -> "3" (stations.gd keeps it for the Saddlery's banner line; this hands it on).
func _short_num(x: float) -> String:
	return st._short_num(x)


## Phase G2: a shop tile (hud.gd lays consecutive ones out as a grid): an icon, a name, one short line, optional stat
## bars ([["Damage", 0..1], ...]) and a badge ("Level 3/5", "Owned", "Equipped", "New", "Max", "Locked"), the price and
## one button. With no label (or no action) it has no working button: an owned look in use, a stat at its top.
func _tile(icon: String, title: String, text: String, cost: Dictionary, label: String, ok: bool, action: Callable,
		badge := "", stats: Array = []) -> Dictionary:
	var t := {"kind": "item", "icon": icon, "title": title, "text": text, "cost": cost, "label": label,
		"enabled": ok and label != "" and action.is_valid() and Data.can_afford(cost), "action": action}
	if badge != "":
		t["badge"] = badge
	if not stats.is_empty():
		t["stats"] = stats
	return t


## The Hearthtree's name without "the", for a tile's title ("Hearthtree level 3").
func _camp_word() -> String:
	return Data.camp_name(true).trim_prefix("The ")


## A small shelf heading over the tiles that follow it.
func _section(text: String) -> Dictionary:
	return {"kind": "section", "text": text}


## A shelf: its heading, then its rows (nothing at all when it has none).
func _add_section(rows: Array, heading: String, items: Array) -> void:
	if items.is_empty():
		return
	rows.append(_section(heading))
	rows.append_array(items)


func _anchor(sid: String, h: float) -> Vector3:
	return main.world.station_pos(sid) + Vector3(0, h, 0)


## 1035 -> "1,035".
func _thousands(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


## 0.75 -> "75%", 0.005 -> "0.5%", 0.0025 -> "0.25%".
func _pct(x: float) -> String:
	var p := snappedf(x * 100.0, 0.01)
	return ("%d%%" % int(roundf(p))) if is_equal_approx(p, roundf(p)) else ("%s%%" % String.num(p, 2))


## "3,000 leaves", "1,500 leaves and 40 timber": a price in words. gloom: shards read "Gloom shard(s)" (what Bramble
## pays) instead of the plain currency id.
func _price_words(cost: Dictionary, gloom := false) -> String:
	var bits: Array = []
	for k in cost:
		var n := int(cost[k])
		if n > 0:
			var word := Data.mat_name(String(k)) if String(k) in Data.MATS else String(k)
			if gloom and String(k) == "shards":
				word = "Gloom shard" if n == 1 else "Gloom shards"
			bits.append("%s %s" % [_thousands(n), word])
	if bits.size() <= 1:
		return "".join(bits)
	return ", ".join(bits.slice(0, bits.size() - 1)) + " and " + String(bits[bits.size() - 1])


## A knocked-down building's whole card: "In ruins" and Repair (stations._repair; between waves only).
func _ruin_card(sid: String, title: String, anchor: Vector3) -> Dictionary:
	var cost: Dictionary = st.repair_cost(sid)
	var what: String = {"home": "Nothing can be bought here", "target": "No training here", "bench": "No bows to buy or upgrade",
		"well": "It can't mend the camp",
		"stall": "%s won't come out, and no trading" % Data.mount_name(),
		"saddlery": "No skills or attachments to buy or upgrade",
		"tailor": "No outfits to buy or put on"}.get(sid, "")
	var rows: Array = [{"text": "In ruins", "note": "%s until it is repaired" % what, "cost": {}, "label": "", "enabled": false, "action": Callable()}]
	var raid: bool = main.fight.active and main.fight.mode == "raid"
	if main.fight.active and main.fight.in_wave:
		if raid:
			rows.append({"text": "Repair between waves", "note": "Raids leave their damage: repair it after this wave", "cost": {}, "label": "", "enabled": false, "action": Callable()})
		else:
			rows.append({"text": "Repair between waves", "note": "Or win the raid and the camp mends itself", "cost": {}, "label": "", "enabled": false, "action": Callable()})
	else:
		rows.append(_tile("repair", "Repair", "Everything here works again" + (" · free if the raid is won" if main.fight.active and not raid else ""),
			cost, "Repair", true, st._repair.bind(sid)))
	return {"title": title, "sub": "Knocked down by the Gloom", "rows": rows, "anchor": anchor}


## "Patch it up": a building worn by raids (on its own card).
func _wear_row(sid: String) -> Array:
	var w := float(Save.wear.get(sid, 0.0))
	if w < float(Data.gr()["repair"]["wear_step"]) - 0.0001 or Save.ruined.has(sid):
		return []
	var full: float = st.full_hp(sid)
	var note := "Worn %d%% by raids: %s of %s health" % [int(round(w * 100.0)), _thousands(int(round(full * (1.0 - w)))), _thousands(int(round(full)))]
	return [_tile("repair", "Patch it up", note, st.patch_cost(sid), "Patch", not st._locked(), st._patch.bind(sid), "Worn")]


## The icon id of a building's tiles (hud.gd draws them; an unknown id is a plain round icon): its entry's "icon"
## (content/buildings/<id>; H4: before, a list here), else the id itself (the cooking pot's "pot").
func _station_icon(sid: String) -> String:
	return String(Data.building(sid).get("icon", sid))


# ---------------------------------------------------------------- the companions' looks (the Market, the Stone)
## The looks of a companion slot as tiles: the one in use ("Equipped", no button), the others free to Use (every look
## has the same numbers). H5: the mount's and the pet's looks are content entries (content/mounts, content/pets) and
## only the owned ones are listed here (Data.owned_level; buying one is the Market's Mounts and Pets tabs'); the
## guardian's stay in balance.json looks.guardian.
func _look_tiles(slot: String, icon: String, use_text: String, other_text: String) -> Array:
	var out: Array = []
	for lk: Dictionary in _slot_looks(slot):
		var lid := String(lk["id"])
		var use: bool = st._look_id(slot) == lid
		var txt := use_text if use else other_text
		if slot == "mount" and not use:
			txt = "Same speed and skills, a new look"         # G4: looks have no move of their own
		out.append(_tile(icon, String(lk["name"]), txt, {}, "" if use else "Use", not use, st._use_look.bind(slot, lid), "Equipped" if use else ""))
	return out


## The looks a slot can put out now, in their order: the owned mount or pet looks (content, H5), or every guardian look.
func _slot_looks(slot: String) -> Array[Dictionary]:
	var kind := String(CompanionShop.SLOT_KINDS.get(slot, ""))
	var out: Array[Dictionary] = []
	if kind == "":
		for lk: Variant in (Data.b.get("looks", {}) as Dictionary).get(slot, []):
			if lk is Dictionary:
				out.append(lk)
		return out
	for e: Dictionary in Data.shop_entries(kind):
		if Data.owned_level(kind, String(e["id"])) >= 1:
			out.append(e)
	return out


## The skin row: the colours of the look in use; "Next" goes round them (all free while testing, sold later).
func _skin_row(slot: String) -> Dictionary:
	var skins: Array = st._skins(slot)
	var cur := Data.skin(slot, st._look_id(slot), st._skin_id(slot))
	var names: Array = skins.map(func(s): return String(s["name"]))
	return {"text": "Colours: %s" % String(cur.get("name", "Natural")), "note": " · ".join(names),
		"cost": {}, "label": "Next", "enabled": skins.size() > 1, "action": st._next_skin.bind(slot)}


## Gloomlit colours for the look in a slot: earned with Gloom shards, never sold (shown until it is unlocked).
func _gloomlit_row(slot: String) -> Array:
	for s in Data.look(slot, st._look_id(slot)).get("skins", []):
		if int(s.get("shards", 0)) > 0 and not Save.unlocks.has(st._skin_unlock(slot, String(s["id"]))):
			return [_tile("shard", "%s colours" % String(s["name"]), "Earned with Gloom shards, never sold", {"shards": int(s["shards"])}, "Unlock",
				true, st._unlock_skin.bind(slot, String(s["id"])), "New")]
	return []


## Phase E: attachments for the mount or the pet: Burrows-only help, bought once for its price (leaves today), one worn
## at a time. Shown once the Burrows are open. Card-only for now (no model on the companion). H5: they are content
## entries (content/attachments, "shop": "stall", "scope": "expedition"; Data.attachment_entries), owned in Save.owned
## (Data.owned_level); Buy is stations._buy_attach (the Buy command), Wear and Take off stations._wear.
func _attach_rows(slot: String) -> Array:
	var rows: Array = []
	if not Data.burrows_open():
		return rows
	for it: Dictionary in Data.attachment_entries(String(st.MARKET), slot):    # the Market sells it (its entries' "shop")
		if String(it.get("scope", "")) != "expedition":
			continue
		var aid := String(it["id"])
		var nm := String(it.get("name", aid))
		var says := String(it.get("desc", ""))
		var worn: bool = String(Save.attach.get(slot, "")) == aid
		if worn:
			rows.append(_tile(slot, nm, says, {}, "Take off", true, st._wear.bind(slot, ""), "Equipped"))
		elif Data.owned_level("attachments", aid) >= 1:
			rows.append(_tile(slot, nm, says, {}, "Wear", true, st._wear.bind(slot, aid), "Owned"))
		else:
			var c: Dictionary = Data.entry_price("attachments", aid, 1)
			rows.append(_tile(slot, nm, says + Data.mats_line(c), c, "Buy", Data.entry_price_ok("attachments", aid, 1),
				st._buy_attach.bind(aid), "New"))
	return rows
