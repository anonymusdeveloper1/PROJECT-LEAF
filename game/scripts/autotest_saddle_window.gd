extends Node
## H5 Stage 2 (27 Nov 2026): the Saddlery's window through real taps and a real drag, for `--saddlery` (run by
## autotest_g4_saddle.gd _window, which hands over t, main and itself). Each check logs "EXPECT PASS <what>" or
## "EXPECT FAIL <what>" through autotest.gd's _expect. The window is reached only through main.hud.windows["saddlery"]
## and the card on the screen. Screenshots (t._shot, at the size the mode runs): saddlery_attachments,
## saddlery_attachment_detail, saddlery_attachment_worn, saddlery_skills, saddlery_skill_detail,
## saddlery_skills_circles, saddlery_upgrade_confirm, saddlery_upgrade_confirm_short.
##   (1) a tap on the marker opens it on Attachments: two bottom tabs (icon and word), the three pictures, no footer
##   (2) an attachment's detail: it turns, fitted to the mount out now (the other mount: its own file); Buy wears the
##       first one; a stale tap buys nothing; the cap's reason; Back; a second one shows Wear, Wear swaps (the saddle's
##       health goes); the worn one upgrades once the Saddlery allows
##   (3) Skills: the pinned Upgrade, the triangle (three circles) over the four round icons (three or more across); a
##       skill's detail: Learn (into the grid, not a circle), Back
##   (4) the circles: refusals (wrong payload, unknown, unlearned, a bad circle, a wave on), a real drag, replace,
##       move, a duplicate refused, a real tap clears; never four; every learned level kept
##   (5) the confirm: the next cap and the mount's speed and health; red and grey when short; Cancel and Confirm come
##       back to Skills; the building catching up (the owner's Q2)
##   (6) visits: a fresh visit opens on Attachments, open_on("skills") opens the next one on Skills; the "!" follows
##       what can be paid; in ruins only the ruin card

const SkillTriangle := preload("res://ui/kit/skill_triangle.gd")

var t                     # autotest.gd (its helpers: _wait, _expect, _shot, _tap_at, _at_ring, _press, _tap_close)
var main
var g4                    # autotest_g4_saddle.gd (its fixtures: _start_fresh, _gear, _slots, _fight)
var _last_view            # the attachment detail's 3D view just before Back (it must be freed then)


func run() -> bool:
	_setup()
	await _attachments()
	await _skills()
	await _circles()
	await _confirm()
	await _visits()
	main.hud.hide_card()
	await t._wait(0.2)
	return true


func _x(what: String, ok: bool, extra := {}) -> bool:
	return t._expect(what, ok, extra)


func _w():
	return main.hud.windows["saddlery"]


func _ring():
	return main.stations.rings.get("saddlery")


## A camp with 8 missions won, the Market (Thistle) and the Saddlery at level 1, nothing learned or owned, plenty to pay.
func _setup() -> void:
	g4._start_fresh(8)
	Save.stations["saddlery"] = 1
	Save.leaves = 200000
	Save.timber = 5000
	main.stations.refresh()
	main.refresh_companions()


## The open card's nodes with meta `key` (equal to `value` when one is given), only those showing (an old content
## being freed is hidden first).
func _find(key: String, value: Variant = null) -> Array:
	var out: Array = []
	var c = main.hud._card
	if c == null or not is_instance_valid(c):
		return out
	for n in (c as Node).find_children("*", "", true, false):
		if n.has_meta(key) and (value == null or n.get_meta(key) == value) and n is CanvasItem and (n as CanvasItem).is_visible_in_tree():
			out.append(n)
	return out


func _first(key: String, value: Variant = null):
	var a := _find(key, value)
	return a[0] if not a.is_empty() else null


## Every word under n, joined (a cell's, a detail's).
func _text_in(n: Node) -> String:
	var bits: Array = []
	for l in n.find_children("*", "Label", true, false):
		bits.append(String((l as Label).text))
	return " | ".join(bits)


func _centre(n) -> Vector2:
	return (n as Control).get_global_rect().get_center()


## The button on the open card with meta "tab_id" = tab.
func _tab_button(tab: String) -> Button:
	for b in main.hud.card_buttons():
		if String(b.get_meta("tab_id", "")) == tab:
			return b as Button
	return null


# ---------------------------------------------------------------- (1) and (2) Attachments
func _attachments() -> void:
	var w = _w()
	if main.mount == null or _ring() == null:
		_x("the mount is out and the Saddlery's marker is there (the Market and the Saddlery built)", false,
			{"mount": main.mount != null, "ring": _ring() != null})
		return
	await t._at_ring(_ring())
	await t._wait(0.5)
	var s: Dictionary = w.spec()
	var tabs: Array = s.get("tabs", [])
	var tab_ok := tabs.size() == 2 and String(tabs[0].get("id", "")) == "attachments" and String(tabs[1].get("id", "")) == "skills"
	for tb in tabs:
		tab_ok = tab_ok and String(tb.get("icon", "")) != "" and String(tb.get("text", "")) == Data.word("tab_" + String(tb["id"]))
	_x("a tap on the marker opens the Saddlery on Attachments: two tabs at the bottom (Attachments, Skills; icon and word), no footer",
		main.hud.card_ring() == _ring() and String(w.tab) == "attachments" and String(s.get("tabs_at", "")) == "bottom" and tab_ok
		and (s.get("footer", {}) as Dictionary).is_empty(), {"tab": w.tab, "tabs": tabs.map(func(x): return x.get("id"))})
	var skills_btn := _tab_button("skills")
	var body_end: float = main.hud._card_scroll.get_global_rect().end.y if main.hud._card_scroll != null else 0.0
	_x("the tabs sit under the card's rows", skills_btn != null and skills_btn.get_global_rect().position.y >= body_end - 1.0,
		{"tab_y": skills_btn.get_global_rect().position.y if skills_btn != null else -1.0, "body_end": body_end})
	var ids: Array = _find("cell").map(func(n): return String(n.get_meta("cell")))
	var pics := true
	for n in _find("cell"):
		pics = pics and _first_child_meta(n, "cell_pic")
	var fresh := true
	for ae: Dictionary in w.entries("attachments"):
		fresh = fresh and String(ae["state"]) == "new" and ae["price"] == Data.saddle_price("attach", String(ae["id"]), 1)
	_x("three pictures in order: Fire-spitter, Mossweave Saddle, Saddlebags, each new with its price",
		ids == ["fire_spitter", "saddle", "saddlebags"] and pics and fresh, {"cells": ids})
	await t._shot("saddlery_attachments")
	# a real tap on the Mossweave Saddle: its detail, turning, fitted to the mount out now
	var cell = _first("cell", "saddle")
	if cell != null:
		await t._tap_at(_centre(cell))
	await t._wait(0.7)
	var look := Save.mount_look
	var want := Data.gear_model("saddle", look)
	var view = _first("model_view")
	_x("a tap on its picture opens the Mossweave Saddle's detail", String(w.shown_id) == "saddle" and _first("attachment_inspect", "saddle") != null,
		{"shown": w.shown_id})
	_x("it turns, the file fitted to %s (%s)" % [look, want.get_file()], want == "" or (view != null and view.shown() != null
		and String(view.get_meta("model_path", "")) == want and float(view.turned()) > 0.05),
		{"path": view.get_meta("model_path", "") if view != null else "", "turned": view.turned() if view != null else 0.0})
	var other := "bramblewool" if look != "bramblewool" else "thistle"
	Save.mount_look = other
	main.mount.set_look()
	main.hud.refresh_card()
	await t._wait(0.4)
	var view2 = _first("model_view")
	var want2 := Data.gear_model("saddle", other)
	_x("with %s out the detail shows %s's own fitted file" % [other, other], want2 == "" or (view2 != null
		and String(view2.get_meta("model_path", "")) == want2), {"path": view2.get_meta("model_path", "") if view2 != null else ""})
	Save.mount_look = look
	main.mount.set_look()
	main.hud.refresh_card()
	await t._wait(0.4)
	await t._shot("saddlery_attachment_detail")
	# Buy: paid once, worn at once (the first one), its model on the mount
	var p1 := Data.saddle_price("attach", "saddle", 1)
	var l0 := Save.leaves
	var t0 := Save.timber
	var bought: bool = t._press(Data.word("buy"))
	await t._wait(0.4)
	_x("Buy: the Mossweave Saddle is owned at level 1, exactly its price paid, and worn at once (the first one)",
		bought and Data.attach_level("saddle") == 1 and Data.worn_attach() == "saddle" and Save.leaves == l0 - int(p1.get("leaves", 0))
		and Save.timber == t0 - int(p1.get("timber", 0)), {"level": Data.attach_level("saddle"), "worn": Data.worn_attach(), "leaves": l0 - Save.leaves})
	_x("its model is on the mount when its file is there", main.mount.gear.has("saddle") == (Data.gear_model("saddle", Save.mount_look) != ""),
		{"gear": main.mount.gear.keys()})
	var why = _first("why")
	var e: Dictionary = w.entry("attach", "saddle")
	_x("at Saddlery level 1 the worn saddle shows a grey Worn and 'Upgrade the Saddlery for more'",
		String(e["label"]) == Data.word("worn") and not bool(e["can"]) and why != null and String(why.text) == String(Data.word("saddle_cap_hint")) % main.stations._name("saddlery")
		and not t._press(Data.word("worn")), {"why": why.text if why != null else ""})
	await t._shot("saddlery_attachment_worn")
	t._press(Data.word("back"))
	await t._wait(0.4)
	var cell2 = _first("cell", "saddle")
	_x("Back: the pictures again, the saddle's says Worn · Level 1/5", String(w.shown_id) == "" and cell2 != null
		and _text_in(cell2).contains("%s · %s" % [Data.word("worn"), Data.word("level_badge") % [1, 5]]), {"cell": _text_in(cell2) if cell2 != null else ""})
	# a second one: Wear swaps (one worn at a time), the saddle's health goes with it
	w.inspect("saddlebags")
	await t._wait(0.3)
	t._press(Data.word("buy"))
	await t._wait(0.3)
	e = w.entry("attach", "saddlebags")
	_x("the Saddlebags bought while the saddle is worn: owned, not worn, its button Wear", Data.attach_level("saddlebags") == 1
		and Data.worn_attach() == "saddle" and String(e["action"]) == "wear" and bool(e["can"]), e)
	var hp_worn: int = main.mount.max_hp()
	var worn_ok: bool = t._press(Data.word("wear"))
	await t._wait(0.3)
	_x("Wear: the Saddlebags are worn, the saddle comes off and its health with it", worn_ok and Data.worn_attach() == "saddlebags"
		and main.mount.max_hp() == roundi(float(Data.mount_base_hp_at(Data.mount_level()))) and hp_worn > main.mount.max_hp(),
		{"worn": Data.worn_attach(), "hp": [hp_worn, main.mount.max_hp()]})
	Save.stations["saddlery"] = 2
	main.hud.refresh_card()
	await t._wait(0.3)
	var p2 := Data.saddle_price("attach", "saddlebags", 2)
	l0 = Save.leaves
	var up: bool = t._press(Data.word("upgrade"))
	await t._wait(0.3)
	_x("at Saddlery level 2 the worn Saddlebags upgrade to level 2 for exactly that price", up and Data.attach_level("saddlebags") == 2
		and Save.leaves == l0 - int(p2.get("leaves", 0)), {"level": Data.attach_level("saddlebags")})
	Save.stations["saddlery"] = 5                       # level 3 open now: a button drawn for level 2 is stale
	l0 = Save.leaves
	w.act("attach", "saddlebags", 2)
	_x("a stale Upgrade (drawn for level 2, pressed again) buys nothing, even with level 3 open", Data.attach_level("saddlebags") == 2
		and Save.leaves == l0, {"level": Data.attach_level("saddlebags")})
	Save.stations["saddlery"] = 2
	main.hud.refresh_card()
	await t._wait(0.3)
	_last_view = _first("model_view")
	t._press(Data.word("back"))
	await t._wait(0.3)


## n has a child (at any depth) with meta key.
func _first_child_meta(n: Node, key: String) -> bool:
	for c in n.find_children("*", "", true, false):
		if c.has_meta(key):
			return true
	return false


# ---------------------------------------------------------------- (3) Skills
func _skills() -> void:
	var w = _w()
	var btn := _tab_button("skills")
	if btn != null:
		await t._tap_at(_centre(btn))
	await t._wait(0.7)
	var tri = _first("skill_triangle")
	var cells: Array = _find("skill_cell")
	_x("a tap on the Skills tab: the triangle of three circles over the four skill icons, the Saddlery's Upgrade pinned",
		String(w.tab) == "skills" and tri != null and _find("skill_slot").size() == 3 and cells.size() == 4
		and main.hud.p_card.footer_button(Data.word("upgrade")) != null, {"tab": w.tab, "cells": cells.size()})
	var across := 0
	if not cells.is_empty():
		var y0: float = (cells[0] as Control).get_global_rect().position.y
		for c in cells:
			if absf((c as Control).get_global_rect().position.y - y0) < 1.0:
				across += 1
	_x("at least three skill icons a row", across >= 3, {"across": across})
	_x("the attachment's 3D view was freed when its detail closed", _find("model_view").is_empty()
		and not is_instance_valid(_last_view))
	await t._shot("saddlery_skills")
	var stomp = _first("skill_cell", "stomp")
	if stomp != null:
		await t._tap_at(_centre(stomp))
	await t._wait(0.5)
	_x("a tap on Stomp's icon opens its detail", String(w.shown_id) == "stomp" and _first("skill_detail", "stomp") != null)
	var p1 := Data.saddle_price("skills", "stomp", 1)
	var l0 := Save.leaves
	var learned: bool = t._press(Data.word("learn"))
	await t._wait(0.4)
	_x("Learn: Stomp level 1 for exactly its price; it goes into the grid, not a circle", learned and Data.skill_level("stomp") == 1
		and Save.leaves == l0 - int(p1.get("leaves", 0)) and not Data.skill_is_slotted("stomp"), {"slots": Data.skill_slots()})
	var e: Dictionary = w.entry("skills", "stomp")
	_x("its detail now offers Upgrade to level 2 (the Saddlery is level 2)", String(e["action"]) == "upgrade" and int(e["next"]) == 2
		and _first("skill_detail", "stomp") != null, e)
	await t._shot("saddlery_skill_detail")
	t._press(Data.word("back"))
	await t._wait(0.6)
	_x("Back: the Skills tab's circles and icons again", String(w.shown_id) == "" and String(w.tab) == "skills" and _first("skill_triangle") != null)


# ---------------------------------------------------------------- (4) the circles
func _circles() -> void:
	var w = _w()
	var tri = _first("skill_triangle")
	if tri == null:
		_x("the circles are on the Skills tab", false)
		return
	var refused: bool = not tri.can_take(0, SkillTriangle.payload("ram")) and not tri.can_take(0, {"kind": "seed", "id": "sunberry"}) \
		and not tri.can_take(0, SkillTriangle.payload("nope")) and not tri.can_take(3, SkillTriangle.payload("stomp")) \
		and not tri.can_take(-1, SkillTriangle.payload("stomp"))
	g4._fight(true)
	var mid_wave: bool = tri.can_take(0, SkillTriangle.payload("stomp"))
	g4._fight(false)
	_x("refused: an unlearned skill, a seed, an unknown id, a circle that is not there, and any drop while a wave is on",
		refused and not mid_wave and Data.skill_slots() == _three([]))
	# a real drag of Stomp into the first circle
	var src = _first("skill_cell", "stomp")
	var res := {}
	if src != null:
		res = await _drag(_centre(src), _centre(tri.slot_node(0)), 0.45)
	await t._wait(0.4)
	tri = _first("skill_triangle")
	_x("a real drag of Stomp into the first circle puts it there (the mount now fights with it)", bool(res.get("dragging", false))
		and Data.skill_slots() == _three(["stomp"]) and tri != null and tri.slot_ids() == _three(["stomp"]) and Data.active_skill_level("stomp") == 1,
		{"res": res, "slots": Data.skill_slots()})
	var cell = _first("skill_cell", "stomp")
	_x("its icon in the grid now has the green rim of a skill in use", cell != null and bool(cell.get_meta("slotted", false)))
	# learn the other three (the rule, as their details' Learn does), then fill and change the circles
	for sid in ["ram", "pounce", "bellow"]:
		w.act("skills", sid, 1)
	main.hud.refresh_card()                             # their new levels redraw the grid (the Skills tab's view_id holds them)
	await t._wait(0.5)
	tri = _first("skill_triangle")
	var all_learned := ["stomp", "ram", "pounce", "bellow"].all(func(s): return Data.skill_level(s) == 1)
	_drop(1, "ram")
	_drop(2, "pounce")
	_x("Ram and Pounce dropped on circles 2 and 3: three in use, Bellow learned but in no circle", all_learned
		and Data.skill_slots() == _three(["stomp", "ram", "pounce"]) and Data.active_skill_level("bellow") == 0 and Data.skill_level("bellow") == 1,
		{"slots": Data.skill_slots()})
	_drop(0, "bellow")
	_x("Bellow dropped on Stomp's circle replaces it; Stomp stays learned in the grid", Data.skill_slots() == _three(["bellow", "ram", "pounce"])
		and Data.skill_level("stomp") == 1 and not Data.skill_is_slotted("stomp"), {"slots": Data.skill_slots()})
	_drop(0, "ram")
	_x("Ram dropped on the first circle moves there: its old circle empties", Data.skill_slots() == _three(["ram", "", "pounce"]),
		{"slots": Data.skill_slots()})
	tri = _first("skill_triangle")
	var dup: bool = tri.can_take(0, SkillTriangle.payload("ram"))
	_drop(0, "ram")
	_drop(1, "seed")
	_x("Ram again on its own circle and a wrong payload are refused: nothing changes", not dup and Data.skill_slots() == _three(["ram", "", "pounce"]))
	await t._wait(0.3)
	tri = _first("skill_triangle")
	if tri != null:
		await t._tap_at(_centre(tri.slot_node(2)))
	await t._wait(0.3)
	tri = _first("skill_triangle")
	_x("a real tap on the filled third circle empties it", Data.skill_slots() == _three(["ram"]) and tri != null and tri.slot_ids() == _three(["ram"]),
		{"slots": Data.skill_slots()})
	_drop(1, "stomp")
	_drop(2, "pounce")
	var slots: Array = Data.skill_slots()
	_x("never four: three circles, every learned level kept", slots.size() == 3 and _find("skill_slot").size() == 3
		and ["stomp", "ram", "pounce", "bellow"].all(func(s): return Data.skill_level(s) == 1) and not slots.has("bellow"), {"slots": slots})
	await t._wait(0.4)
	await t._shot("saddlery_skills_circles")


## A drop on circle i the way Godot ends a drag there (its _drop_data: the kit checks again before anything changes).
## id "seed" drops a seed instead of a skill.
func _drop(i: int, id: String) -> void:
	var tri = _first("skill_triangle")
	if tri == null or tri.slot_node(i) == null:
		return
	var p: Dictionary = {"kind": "seed", "id": "sunberry"} if id == "seed" else SkillTriangle.payload(id)
	tri.slot_node(i)._drop_data(Vector2.ZERO, p)


## Three circles' ids: the given ones, then empty.
func _three(ids: Array) -> Array[String]:
	var out: Array[String] = []
	for i in 3:
		out.append(String(ids[i]) if i < ids.size() else "")
	return out


# ---------------------------------------------------------------- (5) the Saddlery's Upgrade confirm
func _confirm() -> void:
	var w = _w()
	var lv := Data.saddlery_level()
	var next := lv + 1
	var want: Array = w.gives(next)
	var tier := Data.mount_level_at_saddlery(next)
	var stats: String = String(Data.word("mount_speed_hp")) % [Data.mount_name(), main.stations._short_num((Data.mount_speed_at(tier) - 1.0) * 100.0),
		roundi(float(Data.mount_base_hp_at(tier)) * Data.mount_hp_mult())]
	_x("what level %d gives: skills and attachments up to %d, and the mount's speed and health at tier %d" % [next, next, tier],
		want.size() >= 2 and String(want[0]) == String(Data.word("saddle_level_cap")) % next and String(want[1]) == stats, {"gives": want})
	await _ask()
	var rows: Array = main.hud.confirm.spec().get("rows", [])
	var texts: Array = rows.map(func(r): return String(r.get("text", "")))
	_x("the pinned Upgrade opens the confirm with those lines and the next level's price", main.hud.card_ring() == main.hud.confirm
		and texts.has(_cap(String(want[0]))) and texts.has(_cap(String(want[1]))), {"rows": texts})
	await t._shot("saddlery_upgrade_confirm")
	t._press(Data.word("cancel"))
	await t._wait(0.5)
	_x("Cancel comes back to the Saddlery on the Skills tab, nothing bought", main.hud.card_ring() == _ring() and String(w.tab) == "skills"
		and Data.saddlery_level() == lv, {"tab": w.tab})
	var keep := Save.leaves
	Save.leaves = 0
	main.hud.refresh_card()
	await t._wait(0.3)
	await _ask()
	_x("short of leaves the confirm still opens, its Confirm grey", main.hud.card_ring() == main.hud.confirm and not t._press(Data.word("confirm")))
	await t._shot("saddlery_upgrade_confirm_short")
	t._press(Data.word("cancel"))
	await t._wait(0.5)
	Save.leaves = keep
	main.hud.refresh_card()
	await t._wait(0.3)
	var price := Data.level_price("saddlery", next)
	await _ask()
	var l0 := Save.leaves
	t._press(Data.word("confirm"))
	await t._wait(0.6)
	_x("Confirm: the Saddlery is level %d, its price paid, and the card is back on Skills" % next, Data.saddlery_level() == next
		and Save.leaves == l0 - int(price.get("leaves", 0)) and main.hud.card_ring() == _ring() and String(w.tab) == "skills",
		{"level": Data.saddlery_level(), "tab": w.tab})
	# the owner's Q2: an old Market's tier carried over: the building catches up
	Save.saddlery["mount_credit"] = 4
	var g4l: Array = w.gives(4)
	var g5l: Array = w.gives(5)
	var catching: String = String(Data.word("saddle_catching_up")) % [Data.mount_name(), 4, main.stations._name("saddlery"), 4]
	_x("with an old tier 4 carried over: the mount is tier 4 at a level-%d Saddlery, level 4's confirm says it is catching up, level 5's does not" % next,
		Data.mount_level() == 4 and g4l.has(catching) and not g5l.has(catching) and String(g5l[1]).contains(str(Data.mount_base_hp_at(5))),
		{"tier": Data.mount_level(), "gives4": g4l, "gives5": g5l})
	Save.saddlery["mount_credit"] = 0


## Taps the pinned Upgrade for real and waits for the confirm.
func _ask() -> void:
	var b: Button = main.hud.p_card.footer_button(Data.word("upgrade"))
	if b != null:
		await t._tap_at(_centre(b))
	await t._wait(0.4)


## The confirm shows its lines with a capital first letter.
func _cap(s: String) -> String:
	return s.substr(0, 1).to_upper() + s.substr(1)


# ---------------------------------------------------------------- (6) visits, the "!" and ruins
func _visits() -> void:
	var w = _w()
	await t._tap_close()
	await t._wait(0.3)
	await t._at_ring(_ring())
	await t._wait(0.4)
	_x("after the X a new visit opens on Attachments again", main.hud.card_ring() == _ring() and String(w.tab) == "attachments")
	await t._tap_close()
	w.open_on("skills")
	await t._at_ring(_ring())
	await t._wait(0.4)
	_x("open_on('skills') makes the next visit open on Skills", String(w.tab) == "skills")
	await t._tap_close()
	var keep_l := Save.leaves
	var keep_t := Save.timber
	Save.leaves = 0
	Save.timber = 0
	var off: bool = w.pulse()
	Save.leaves = keep_l
	Save.timber = keep_t
	var on: bool = w.pulse()
	var dots: Array = (w.spec().get("tabs", []) as Array).map(func(tb): return bool(tb.get("dot", false)))
	_x("the marker's \"!\" shows only while something can be paid (off with no leaves, on with plenty), the tabs' dots too",
		not off and on and dots.has(true), {"off": off, "on": on, "dots": dots})
	Save.ruined.append("saddlery")
	var ruin: Dictionary = w.spec()
	Save.ruined.erase("saddlery")
	_x("in ruins: only the ruin card (no tabs)", (ruin.get("tabs", []) as Array).is_empty() and String(ruin.get("sub", "")) == "Knocked down by the Gloom")


# ---------------------------------------------------------------- a real finger drag (as autotest_garden.gd's)
## A real finger drag from `from` to `to` (HUD pixels) through Input, as on the phone. Returns what was true just
## before the finger lifted: {"dragging": a GUI drag is on}.
func _drag(from: Vector2, to: Vector2, secs: float) -> Dictionary:
	var xf: Transform2D = get_viewport().get_final_transform()
	var d := InputEventScreenTouch.new()
	d.index = 0
	d.position = xf * from
	d.pressed = true
	Input.parse_input_event(d)
	var n := maxi(3, int(secs / 0.05))
	for k in n:
		await t._wait(secs / n)
		var m := InputEventScreenDrag.new()
		m.index = 0
		m.position = xf * from.lerp(to, float(k + 1) / n)
		m.relative = xf.basis_xform((to - from) / n)
		Input.parse_input_event(m)
	await get_tree().process_frame
	var out := {"dragging": get_viewport().gui_is_dragging()}
	var u := InputEventScreenTouch.new()
	u.index = 0
	u.position = xf * to
	u.pressed = false
	Input.parse_input_event(u)
	await get_tree().process_frame
	await get_tree().process_frame
	return out
