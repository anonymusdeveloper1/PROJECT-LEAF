extends Node
## The Bag (H3, 26 Nov 2026; `-- --autotest --fresh --bag`, also `--inventory`, the H2 name; the H3 build map, part 5.3,
## P2b): the Bag window (it opens and closes as in H2, 24 slots, stacks, only owned things, the empty Bag, a full Bag,
## a forced add past 24, Use and Place, a refused Use's reason clearing once it is no longer true), placing from the
## Bag (the drop-in, below ground refused, the ghost uses the start-up check's rule: the owner's Q25), pieces sent back
## into a full Bag, a tower refused with a full Bag, and Bramble buying a Golden Carp. At its end it runs the potions'
## checks (autotest_potions.gd, P2a) when that file is there. Uses the test save only: it seeds the endgame camp (as the
## old --inventory did) and puts the Bag, the pieces and amber back to the seed's at the end. It never touches the
## Timers clock.

const POTIONS_TEST := "res://scripts/autotest_potions.gd"
const USE_POTION := "res://commands/use_potion.gd"
const DefencesTab := preload("res://ui/windows/defences_tab.gd")   # H4: the Defences shelf's rows (the Hearthtree's tab)
const COLUMNS := 6                                   # the Bag window's columns (inventory.gd)

var t                     # autotest.gd (its helpers: _wait, _shot, _expect, _tap_at, _tap_outside, _at_ring ...)
var main
var _seed := {}           # the Bag, the pieces and amber right after the endgame seed (put back at the end)


func run() -> void:
	var hud = main.hud
	var was_invincible: bool = main.player.invincible
	main.player.invincible = true
	await _opens_and_closes()
	await _camp()
	await _empty_bag()
	await _stacks()
	await _full_bag()
	await _buttons()
	await _use()
	await _place()
	await _ghost_rule()
	_market_carp()
	await _views()
	await _dungeon()
	await t._wait(0.2)
	_x("the Bag button fits the safe area", hud.bag_button.get_global_rect().end.y <= hud.get_viewport().get_visible_rect().size.y - hud._safe.y)
	_x("the Bag and the action buttons have separate space", hud.bag_button.get_global_rect().end.x <= hud._build_bar.position.x)
	_restore()
	main.player.invincible = was_invincible
	await _potions()


# ---------------------------------------------------------------- helpers
func _x(what: String, ok: bool, extra := {}) -> bool:
	return t._expect(what, ok, extra)


func _inv() -> Variant:
	return main.hud.inventory


## The words the open card shows (visible labels and buttons).
func _words() -> String:
	return _text_in(main.hud._card)


func _text_in(node: Node) -> String:
	if node == null or (node is Control and not (node as Control).visible) or node.is_queued_for_deletion():
		return ""
	var text := ""
	if node is Label:
		text = (node as Label).text + "\n"
	elif node is Button:
		text = (node as Button).text + "\n"
	for child in node.get_children():
		text += _text_in(child)
	return text


## The labels of the open card's buttons (the slots' names, Use, Place ...).
func _labels_of_buttons() -> Array:
	var out: Array = []
	for b in main.hud.card_buttons():
		if is_instance_valid(b) and not (b as Node).is_queued_for_deletion() and (b as Control).is_visible_in_tree():
			out.append(String((b as Button).get_meta("label", (b as Button).text)))
	return out


## The Bag opens (or rebuilds when it is open), laid out.
func _open() -> void:
	if main.hud.card_ring() != _inv():
		main.hud.open_inventory()
	else:
		main.hud.refresh_card()
	await t._wait(0.35)


## The Bag window's grid (the open one, not one being freed).
func _grid() -> GridContainer:
	if main.hud._card == null:
		return null
	for g in main.hud._card.find_children("*", "GridContainer", true, false):
		if (g as Control).is_visible_in_tree() and not (g as Node).is_queued_for_deletion():
			return g as GridContainer
	return null


func _frames() -> int:
	var g := _grid()
	return g.get_child_count() if g != null else -1


## The count a slot shows ("" when there is no such slot).
func _count_text(slot_key: String) -> String:
	var l = _inv()._labels.get("stock_" + slot_key)
	return String(l.text) if l != null and is_instance_valid(l) else ""


## The counts of an id's stacks, in order (Bag.stacks()).
func _stacks_of(id: String) -> Array:
	var out: Array = []
	for s in Bag.stacks():
		if String(s["id"]) == id:
			out.append(int(s["n"]))
	return out


## The Bag holds exactly this: food and potions (Save.bag), towers, spikes and amber.
func _set_bag(bag: Dictionary, towers: int, spikes: int, amber: int) -> void:
	Save.bag = bag.duplicate()
	Save.items["tower"] = towers
	Save.items["spikes"] = spikes
	Save.mats["amber"] = amber
	Events.bag_changed.emit()


func _tap(c: Control) -> void:
	if c == null or not is_instance_valid(c):
		return
	await t._tap_at(c.get_global_rect().get_center())
	await t._wait(0.3)


# ---------------------------------------------------------------- it opens and closes as in H2
func _opens_and_closes() -> void:
	var hud = main.hud
	await t._tap_at(hud.bag_button.get_global_rect().get_center())
	await t._wait(0.35)
	_x("the Bag opens through the HUD button (a real tap)", hud.card_ring() == hud.inventory)
	_x("opening the Bag keeps gameplay live", not main.frozen and not get_tree().paused and Engine.time_scale == 1.0)
	_x("the Bag keeps its title and line", hud.card_title() == "Bag" and _words().contains("Gameplay continues"))
	_x("the Bag shows the current cat on foot", hud.inventory.preview != null and hud.inventory.preview.cat_copy != null
		and hud.inventory.preview.mount_copy == null)
	_x("the Bag shows health as bars, no Health text", hud.inventory._bars.get("cat") != null and not hud.inventory._labels.has("health"))
	var labels := _labels_of_buttons()
	_x("no Eat, Quick heal or Use Auto and no x/20 any more (H3)", not labels.has("Eat") and not labels.has("Quick heal")
		and not labels.has("Use Auto") and not _words().contains("/20") and not _words().contains("Quick heal"), {"buttons": labels})
	await t._tap_outside()
	_x("a tap outside closes the Bag", not hud.card_open())
	hud.open_inventory()
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	hud._unhandled_key_input(escape)
	_x("Escape closes the Bag", not hud.card_open())
	hud.open_inventory()
	hud._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	_x("Android Back closes the Bag", not hud.card_open())
	hud.open_inventory()
	await t._at_ring(main.stations.rings["shop"])
	_x("a building replaces the Bag", hud.card_ring() == main.stations.rings["shop"])
	hud.open_inventory()
	_x("the Bag replaces a building's card", hud.card_ring() == hud.inventory)
	hud.hide_card()
	await t._wait(0.2)


# ---------------------------------------------------------------- the endgame camp (towers unlocked, the Market built)
func _camp() -> void:
	Save._endgame_seed()
	Save.stations["stone"] = 1
	main.raids.manual = true
	main.on_camp_grown()
	main.defences.load_saved()
	main.player.hp = Data.cat_max_hp()
	await t._wait(0.4)
	_seed = {"bag": Save.bag.duplicate(true), "items": Save.items.duplicate(true), "placed": Save.placed.duplicate(true),
		"mats": Save.mats.duplicate(true), "leaves": Save.leaves}


# ---------------------------------------------------------------- the empty Bag
func _empty_bag() -> void:
	var inv = _inv()
	_set_bag({}, 0, 0, 0)
	await _open()
	_x("an empty Bag shows 'The Bag is empty' with no details and no button", main.hud.card_ring() == inv
		and _words().contains("The Bag is empty") and inv.slots.is_empty() and not inv._labels.has("description")
		and inv._buttons.is_empty(), {"words": _words()})
	_x("an empty Bag still draws its %d empty slots" % Bag.slots(), _frames() == Bag.slots(), {"frames": _frames()})
	await t._shot("bag_empty")
	main.hud.hide_card()


# ---------------------------------------------------------------- stacks, slots, only owned things
func _stacks() -> void:
	var inv = _inv()
	var size := Bag.stack_size("berries")
	_set_bag({}, 0, 0, 0)
	var put := Bag.add("berries", 2 * size + 5)
	_x("%d berries take 3 stacks (%d, %d, 5)" % [2 * size + 5, size, size], put == 2 * size + 5
		and _stacks_of("berries") == [size, size, 5] and Bag.used_slots() == 3, {"stacks": _stacks_of("berries")})
	await _open()
	_x("the window shows the 3 berry slots with their counts", inv.slots.has("berries#0") and inv.slots.has("berries#1")
		and inv.slots.has("berries#2") and not inv.slots.has("berries#3") and _count_text("berries#0") == str(size)
		and _count_text("berries#1") == str(size) and _count_text("berries#2") == "5", {"slots": inv.slots.keys()})
	_x("the grid has %d slots and only the berries fill any (only owned things show)" % Bag.slots(),
		_frames() == Bag.slots() and inv.slots.keys() == ["berries#0", "berries#1", "berries#2"], {"frames": _frames(), "slots": inv.slots.keys()})
	_x("slot_of gives an id's first stack", inv.slot_of("berries") == inv.slots["berries#0"] and inv.slot_of("herbs") == null)
	var lim := Bag.limit("health_potion")
	var got := Bag.add("health_potion", lim + 2)
	_x("a potion is one stack of at most its limit (%d), and refuses more" % lim, got == lim and _stacks_of("health_potion") == [lim]
		and Bag.add("health_potion", 1) == 0 and Bag.room_for("health_potion") == 0, {"got": got, "stacks": _stacks_of("health_potion")})
	await get_tree().process_frame
	await get_tree().process_frame
	_x("the window rebuilds on bag_changed: the potion's slot is there at once", inv.slot_of("health_potion") != null)
	await t._wait(0.3)
	_x("a potion's slot shows held/limit, in the Bag's order after the food", _count_text("health_potion#0") == "%d/%d" % [lim, lim]
		and not inv.slots.has("health_potion#1") and inv.slots.keys() == ["berries#0", "berries#1", "berries#2", "health_potion#0"],
		{"count": _count_text("health_potion#0"), "slots": inv.slots.keys()})
	var slot: Control = inv.slot_of("berries")
	_x("the slots are square", slot != null and absf(slot.size.x - slot.size.y) < 1.0, {"size": str(slot.size) if slot != null else ""})
	await _tap(inv.slots["berries#1"])
	_x("a real tap on a slot selects it and shows the berries", inv.selected == "berries#1" and _words().contains("Owned %d" % (2 * size + 5))
		and _words().contains(Bag.desc("berries")), {"selected": inv.selected})
	await t._shot("bag_stacks")
	main.hud.hide_card()


# ---------------------------------------------------------------- a full Bag
func _full_bag() -> void:
	var inv = _inv()
	_set_bag({}, 0, 0, 0)
	Bag.add("berries", Bag.room_for("berries"))
	_x("%d stacks fill the Bag: no room for herbs, a tower or a potion it holds none of" % Bag.slots(),
		Bag.used_slots() == Bag.slots() and Bag.free_slots() == 0 and Bag.room_for("herbs") == 0 and Bag.add("herbs", 1) == 0
		and Bag.room_for("tower") == 0 and Bag.room_for("mount_potion") == 0, {"used": Bag.used_slots()})
	var price := int(Data.defence_info("tower")["piece"])
	var leaves0 := Save.leaves
	main.stations._buy_piece("tower")
	_x("buying a tower with a full Bag is refused, before paying", Save.leaves == leaves0 and Bag.count("tower") == 0)
	var tile := _tower_tile()
	_x("the Hearthtree's tower tile says Bag full and is off", not tile.is_empty() and String(tile.get("text", "")) == "Bag full"
		and not bool(tile.get("enabled", true)), {"tile": str(tile.get("text", ""))})
	# a piece already paid for goes back even into the full Bag (the start-up check)
	var home: Vector3 = main.world.HOME_SPOT
	Save.placed.append({"type": "tower", "x": home.x, "z": home.z, "rot": 0.0})
	main.defences.load_saved()
	var still := 0
	for sp in Save.placed:
		if String(sp.get("type", "")) == "tower":
			still += 1
	_x("a tower standing on the home's ground goes back into the Bag at load, even when the Bag is full",
		Bag.count("tower") == 1 and still == 0 and Bag.used_slots() == Bag.slots() + 1, {"towers": Bag.count("tower"), "placed": still})
	var forced := Bag.add("herbs", 1, true)
	_x("a forced add goes past the Bag's slots", forced == 1 and Bag.used_slots() == Bag.slots() + 2, {"used": Bag.used_slots()})
	await _open()
	var want := ceili(float(Bag.slots() + 2) / COLUMNS) * COLUMNS
	_x("the window shows every stack past the slots and adds whole rows", inv.slots.size() == Bag.slots() + 2 and _frames() == want,
		{"slots": inv.slots.size(), "frames": _frames(), "want": want})
	await t._shot("bag_full")
	main.hud.hide_card()
	# with room again, the same purchase works (so the refusal above was the full Bag)
	_set_bag({}, 0, 0, 0)
	var leaves1 := Save.leaves
	main.stations._buy_piece("tower")
	_x("with room, a tower is bought into the Bag", Bag.count("tower") == 1 and Save.leaves == leaves1 - price)


## The Hearthtree's Buy tile for towers ({} when there is none).
func _tower_tile() -> Dictionary:
	for tile in DefencesTab.rows(main.hud.windows["shop"]):
		if String(tile.get("icon", "")) == "tower" and String(tile.get("label", "")) == "Buy":
			return tile
	return {}


# ---------------------------------------------------------------- which things get a button
func _buttons() -> void:
	var inv = _inv()
	_set_bag({"berries": 3, "fish": 2, "health_potion": 1}, 1, 0, 2)
	await _open()
	inv._select("berries#0")
	await t._wait(0.2)
	_x("food has no button; its details say what it is for", not inv._buttons.has("use") and not inv._buttons.has("place")
		and _words().contains(Bag.desc("berries")))
	inv._select("amber#0")
	await t._wait(0.2)
	_x("amber has no button; Bramble buys it", inv._buttons.is_empty() and _words().contains("Bramble buys it")
		and _words().contains("Owned 2"))
	inv._select("fish#0")
	await t._wait(0.2)
	_x("fish has Use (it mends the mount)", inv._buttons.has("use") and not inv._buttons.has("place"))
	inv._select("health_potion#0")
	await t._wait(0.2)
	_x("a potion has Use, its name, Owned n/limit and what it does", inv._buttons.has("use")
		and _words().contains(Bag.name_of("health_potion", 1)) and _words().contains("Owned 1/%d" % Bag.limit("health_potion"))
		and _words().contains(Bag.desc("health_potion")))
	inv._select("tower#0")
	await t._wait(0.2)
	_x("a tower has Place and its name from the defences data", inv._buttons.has("place") and not inv._buttons.has("use")
		and _words().contains(Bag.name_of("tower", 1)))
	main.hud.hide_card()


# ---------------------------------------------------------------- Use (the Use-potion command)
func _use() -> void:
	var inv = _inv()
	var hud = main.hud
	_set_bag({"health_potion": 1}, 0, 0, 0)
	main.player.hp = Data.cat_max_hp()
	await _open()
	inv._select("health_potion#0")
	await t._wait(0.3)
	if not inv._buttons.has("use"):
		_x("the Health Potion has a Use button", false)
		hud.hide_card()
		return
	await _tap(inv._buttons["use"])
	var why := String(inv._labels["reason"].text) if inv._labels.has("reason") else ""
	if not ResourceLoader.exists(USE_POTION):
		print("NOTE commands/use_potion.gd is not there yet (P2a): Use says Can't be used")
		_x("without the potion command Use says Can't be used and nothing is used", why == "Can't be used"
			and hud.card_ring() == inv and Bag.count("health_potion") == 1, {"reason": why})
		hud.hide_card()
		return
	_x("Use at full health is refused: the reason shows under the button, the Bag stays open, nothing is used",
		why != "" and hud.card_ring() == inv and Bag.count("health_potion") == 1, {"reason": why})
	await t._shot("bag_use_refused")
	main.player.hp = maxi(1, Data.cat_max_hp() - 3)    # the cat gets hurt while the Bag stays open
	await t._wait(0.3)                                 # the Bag's 0.15 s tick asks the command again
	_x("the reason clears once it is no longer true (the cat got hurt, the Bag stayed open)", hud.card_ring() == inv
		and (not inv._labels.has("reason") or String(inv._labels["reason"].text) == ""),
		{"reason": String(inv._labels["reason"].text) if inv._labels.has("reason") else ""})
	main.player.hp = Data.cat_max_hp()
	if inv._buttons.has("use"):
		await _tap(inv._buttons["use"])                # refused again, so the selection check below has a reason to clear
	inv._select("health_potion#0")                     # a new selection clears the reason
	await t._wait(0.2)
	_x("the reason clears when the selection changes", not inv._labels.has("reason") or String(inv._labels["reason"].text) == "")
	main.player.hp = maxi(1, Data.cat_max_hp() - 3)
	await _tap(inv._buttons["use"])
	_x("Use on a hurt cat drinks the potion and closes the Bag", not hud.card_open() and Bag.count("health_potion") == 0,
		{"left": Bag.count("health_potion"), "open": hud.card_open()})
	await t._wait(0.3)
	main.player.hp = Data.cat_max_hp()


# ---------------------------------------------------------------- Place from the Bag, the drop-in
func _place() -> void:
	var inv = _inv()
	var hud = main.hud
	var d = main.defences
	_set_bag({}, 2, 1, 0)
	await _open()
	_x("towers and spikes have their slots", inv.slot_of("tower") != null and inv.slot_of("spikes") != null)
	await _tap(inv.slot_of("tower"))
	_x("a tap on the tower's slot shows Place", inv.selected == "tower#0" and inv._buttons.has("place"))
	await t._shot("bag_tower")
	if inv._buttons.has("place"):
		await _tap(inv._buttons["place"])
	_x("Place closes the Bag and starts placing a tower", not hud.card_open() and d.placing == "tower" and d.ghost != null,
		{"placing": d.placing})
	var spot: Vector3 = await _green_spot()
	_x("the ghost is green on open ground", d.ghost_ok, {"spot": str(spot)})
	var n0 := Bag.count("tower")
	var placed0: int = Save.placed.size()
	var pieces0: int = d.pieces.size()
	d.place_here()
	var ok: bool = d.pieces.size() == pieces0 + 1
	_x("place_here takes one tower from the Bag and places it", ok and Bag.count("tower") == n0 - 1 and Save.placed.size() == placed0 + 1,
		{"bag": Bag.count("tower"), "placed": Save.placed.size()})
	if ok:
		var p: Dictionary = d.pieces.back()
		var node: Node3D = p["node"]
		_x("the piece starts above its spot (it drops in)", node.position.y > 0.3, {"y": node.position.y})
		await t._wait(0.5)
		_x("the drop-in ends at the spawn position", node.position.distance_to(p["pos"]) < 0.01,
			{"node": str(node.position), "pos": str(p["pos"])})
		await t._shot("bag_placed")
	_x("with a tower left, placing goes on", d.placing == "tower" and Bag.count("tower") == 1)
	d.stop_placing()
	_x("a barricade is never placed from the Bag", _refused_kind("barricade"))
	main.player.frozen = false
	await t._wait(0.2)


func _refused_kind(type: String) -> bool:
	main.defences.start_placing(type)
	var ok: bool = main.defences.placing == ""
	main.defences.stop_placing()
	return ok


## Stands the cat (frozen, so it keeps still) where its ghost falls on open ground; returns that spot.
func _green_spot() -> Vector3:
	var d = main.defences
	main.player.frozen = true
	for r in [6.0, 8.0, 10.0, 12.0, 5.0, 14.0]:
		for k in 16:
			var a := TAU * float(k) / 16.0
			var s := Vector3(sin(a) * float(r), 0.0, cos(a) * float(r))
			if not d._valid(s):
				continue
			main.player.global_position = s - Vector3(sin(a), 0.0, cos(a)) * float(d.AHEAD)
			main.player.facing = a
			await get_tree().process_frame
			await get_tree().process_frame
			if d.ghost_ok:
				return s
	return Vector3.ZERO


# ---------------------------------------------------------------- Q25: the ghost uses the start-up check's rule
func _ghost_rule() -> void:
	var d = main.defences
	var w = main.world
	_set_bag({}, 1, 0, 0)
	d.start_placing("tower")
	_x("placing a tower starts", d.placing == "tower")
	var pts: Array = []
	var centres: Array = [w.LAKE_C, w.HOME_SPOT]
	for c: Vector3 in centres:
		for i in 33:
			for j in 33:
				pts.append(Vector3(c.x - 4.0 + i * 0.25, 0.0, c.z - 4.0 + j * 0.25))
	var missed := 0                       # spots the old ghost let through: only the home or the lake rule catches them
	var bad: Array = []
	var shore := Vector3.INF
	for p in pts:
		var old_rule: bool = w.in_reserved(p, 0.6) or w.in_village(p, 0.6) or w.in_hollow_clear(p) or w.near_hollow(p, d._hollow_keep())
		var lake: float = w.lake_dist(p)
		if (w.near_home(p, 0.6) or lake < 0.6) and not old_rule:
			missed += 1
			if shore == Vector3.INF and lake > 0.1 and lake < 0.5 and not w.near_home(p, 0.6):
				shore = p
		if d.off_limits(p) and d._valid(p):
			bad.append([snappedf(p.x, 0.01), snappedf(p.z, 0.01)])
	_x("there are spots by the lake and the home only the start-up check kept clear before (%d)" % missed, missed > 0)
	_x("the ghost is red wherever the start-up check would send a piece back to the Bag (Q25)", bad.is_empty(),
		{"bad": bad.slice(0, 10), "n": bad.size()})
	# the real ghost on the lake's shore: red, and Place does nothing
	if shore != Vector3.INF:
		var out: Vector3 = (shore - w.LAKE_C)
		out.y = 0.0
		out = out.normalized()
		main.player.frozen = true
		main.player.global_position = shore + out * float(d.AHEAD)
		main.player.facing = atan2(-out.x, -out.z)
		await get_tree().process_frame
		await get_tree().process_frame
		var n0 := Bag.count("tower")
		var placed0: int = Save.placed.size()
		var gp: Vector3 = d._ghost_pos
		d.place_here()
		_x("on the lake's shore the ghost is red and Place does nothing", gp.distance_to(shore) < 0.35
			and not d.ghost_ok and Bag.count("tower") == n0 and Save.placed.size() == placed0,
			{"ghost": str(d._ghost_pos), "shore": str(shore), "ok": d.ghost_ok})
		if d.ghost != null and is_instance_valid(d.ghost):
			main.closeup_at = d.ghost                   # look down at the red ghost (buildings by the shore hide it otherwise)
			main.closeup = Vector3(0.0, 8.0, 6.5)
		await t._wait(0.3)
		await t._shot("bag_ghost_lake")
		main.closeup = Vector3.ZERO
		main.closeup_at = null
		main.player.frozen = false
	else:
		_x("a lake-shore spot to try the ghost on", false)
	d.stop_placing()
	await t._wait(0.2)


# ---------------------------------------------------------------- Bramble buys a Golden Carp
func _market_carp() -> void:
	var buys: Array = Data.b.get("market", {}).get("buys", [])
	var i := -1
	for k in buys.size():
		if String((buys[k] as Dictionary).get("id", "")) == "goldfish":
			i = k
	if not _x("the Market buys the Golden Carp (balance.json market.buys)", i >= 0):
		return
	_set_bag({"goldfish": 1}, 0, 0, 0)
	var pay := int((buys[i] as Dictionary).get("leaves", 0))
	var leaves0 := Save.leaves
	# H5: the Market's Buys tab (a picture and what Bramble pays), its popup, then one Sell through the trade
	var mw = main.hud.windows["stall"]
	mw.select("buys")
	var sell := {}
	for cell: Dictionary in mw.entries("buys"):
		if String(cell.get("id", "")) == "goldfish":
			sell = cell
	_x("Bramble's Buys tab offers to buy the carp", not sell.is_empty() and mw.inspect("goldfish") and mw.trade.is_open()
		and mw.trade.popup.item_id() == "goldfish")
	mw.back()
	main.stations.market_trade("buys", "goldfish", 1)
	_x("Bramble buys a Golden Carp for %d leaves" % pay, pay > 0 and Save.leaves == leaves0 + pay and Bag.count("goldfish") == 0,
		{"pay": pay, "leaves": [leaves0, Save.leaves]})


# ---------------------------------------------------------------- the 3D view, the bars, the currencies (kept from H2)
func _views() -> void:
	var inv = _inv()
	_set_bag({"berries": 5, "fish": 2}, 1, 0, 3)
	await _open()
	inv._select("berries#0")
	await t._wait(0.3)
	var currency: Label = inv._labels["wallet_leaves"]
	_x("the currency strip shows the leaves on one line", currency.text == str(Save.leaves) and currency.get_line_count() == 1
		and currency.size.x >= currency.get_minimum_size().x)
	_x("food, amber and build things share the grid", inv.slot_of("fish") != null and inv.slot_of("amber") != null and inv.slot_of("tower") != null
		and inv.slot_of("glowstone") == null)
	await t._shot("bag_camp")
	if main.mount != null:
		main.set_riding(true, false)
		await t._wait(0.5)
		_x("riding: the Bag's view shows the cat and the mount", inv.preview.cat_copy != null and inv.preview.mount_copy != null)
		_x("riding: the Bag shows the mount's health bar too", inv._bars.get("mount") != null and inv._bars["mount"].visible)
		await t._shot("bag_mounted")
		main.set_riding(false, false)
		await t._wait(0.4)
		_x("on foot again: the view shows the cat alone", inv.preview.mount_copy == null)
		_x("on foot: the mount's health bar hides", inv._bars.get("mount") != null and not inv._bars["mount"].visible)
	else:
		_x("the endgame camp has its mount (for the riding view)", false)
	main.hud.hide_card()


# ---------------------------------------------------------------- below ground
func _dungeon() -> void:
	var inv = _inv()
	var hud = main.hud
	_set_bag({"health_potion": 1}, 1, 0, 10)
	await main.burrows.enter("old_hollow", 1)
	await t._wait(0.3)
	var area = main.area
	if not _x("the real dungeon entry succeeded", area != null):
		return
	area.run["satchel"] = {"amber": 5}
	await _open()
	inv._select("amber#0")
	await t._wait(0.3)
	var kept := int(area._banked_preview(float(Data.burrow_cfg()["knockout_keep"])).get("amber", 0))
	_x("stored and run materials are distinct", _words().contains("At camp 10 · This run 5"), {"words": _words()})
	_x("the amber slot shows the run's count below ground", _count_text("amber#0") == "5", {"count": _count_text("amber#0")})
	_x("the knock-out preview uses the run settlement calculation", _words().contains("keep %d" % kept))
	await t._shot("bag_dungeon")
	inv._select("tower#0")
	await t._wait(0.3)
	var pb = inv._buttons.get("place")
	_x("below ground the tower's Place is off: Place it in the camp", pb != null and (pb as Button).disabled
		and _words().contains("Place it in the camp"))
	inv._place()
	main.defences.start_placing("tower")
	_x("placing is refused below ground", main.defences.placing == "" and hud.card_ring() == inv and Bag.count("tower") == 1)
	var foe = area.spawn("snail", main.player.global_position + Vector3(3, 0, -2))
	if foe != null:
		foe.hp = 99999
		foe.wake()
		var before: Vector3 = foe.global_position
		await t._wait(0.4)
		_x("enemies keep moving with the Bag open", foe.global_position.distance_to(before) > 0.01 and not main.frozen)
	main.player.hp = Data.cat_max_hp()
	await area._leave("down")
	_x("the material settlement agrees with the Bag's preview", Bag.count("amber") == 10 + kept, {"amber": Bag.count("amber"), "kept": kept})


# ---------------------------------------------------------------- the end
func _restore() -> void:
	main.hud.hide_card()
	if main.defences.placing != "":
		main.defences.stop_placing()
	main.player.frozen = false
	if not _seed.is_empty():
		Save.bag = (_seed["bag"] as Dictionary).duplicate(true)
		Save.items = (_seed["items"] as Dictionary).duplicate(true)
		Save.placed = (_seed["placed"] as Array).duplicate(true)
		Save.mats = (_seed["mats"] as Dictionary).duplicate(true)
		Save.leaves = int(_seed["leaves"])
		main.defences.load_saved()
		Events.bag_changed.emit()
		Save.save_game()


## The potions' checks (P2a's autotest_potions.gd) when that file is there.
func _potions() -> void:
	if not ResourceLoader.exists(POTIONS_TEST):
		print("NOTE %s is not there yet (P2a): the potions' checks did not run" % POTIONS_TEST)
		return
	var e = load(POTIONS_TEST).new()
	e.t = t
	e.main = main
	add_child(e)
	await e.run()
