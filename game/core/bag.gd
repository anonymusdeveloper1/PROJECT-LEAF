class_name Bag
extends RefCounted
## The Bag (H3, 26 Nov 2026; docs/ARCHITECTURE.md part 4 Type Object, part 10 the save): what the cat carries in the
## camp, as counts and stacks. Static functions only (like Fx and Props); it keeps no state of its own.
## Used by: Data's has_items / take_items / add_items wrappers (fishing uses them), the Market, the garden and the pot,
## the Bag window (inventory.gd), placing from the Bag (defences.gd), the potion command and buttons, the tests.
## Uses: Save (the counts), Data (balance.json "bag", "ingredients", "defences"; content/recipes; Data.MATS) and Events
## (item_gained, bag_changed).
## Rules:
##   - Where the counts live (H3, the smallest change; ARCHITECTURE's owned[kind][id] comes later): food, fish and
##     potions in Save.bag ({id: count}); towers and spikes in Save.items; amber in Save.mats. Only this file writes
##     them; every other file goes through Bag (or the Data.*_items wrappers).
##   - The kinds come from data, never from name lists here: "food" is a key of balance.json ingredients; "potion" an
##     entry of content/recipes (Cooked Fish too); "material" one of Data.MATS; "build" a balance.json defences entry
##     with "from_bag": true. Anything else is unknown: kept in the save, never shown, never counted, never added.
##   - The Bag order: food (ingredients order), potions (content index order), materials, build items (defences order).
##   - Stacks: a potion is one stack of at most its entry's "limit"; everything else stacks to bag.stack (20) and uses
##     more slots when there are more. The Bag has bag.slots (24) slots. A count above its stack size (an old or forced
##     count) simply shows as more stacks.
##   - add() puts in only what fits now (room_for). force = a thing already paid for: it always goes in, whatever the
##     room (pieces moved off reserved ground at load, an upgraded old save, amber coming home from a run, the garden
##     gift), even past 24 slots.
##   - add sends Events.item_gained(kind, id, added) and then Events.bag_changed(); take sends bag_changed(); both mark
##     the save dirty. Amber goes through Save.add_mat, which already does both.


# ---------------------------------------------------------------- what an id is
## "food", "potion", "material", "build", or "" for an id the Bag does not know.
static func kind_of(id: String) -> String:
	if id == "":
		return ""
	if (Data.b.get("ingredients", {}) as Dictionary).has(id):
		return "food"
	if not Data.item("recipes", id).is_empty():
		return "potion"
	if Data.MATS.has(id):
		return "material"
	if Data.defence_ids().has(id) and Data.defence_info(id).get("from_bag", false) == true:
		return "build"
	return ""


## Every id the Bag can hold, in the Bag order.
static func ids() -> Array[String]:
	var out: Array[String] = []
	for id: Variant in Data.b.get("ingredients", {}):
		out.append(String(id))
	for e: Variant in Data.catalog("recipes"):
		if e is Dictionary and String((e as Dictionary).get("id", "")) != "":
			out.append(String((e as Dictionary)["id"]))
	for id: Variant in Data.MATS:
		out.append(String(id))
	for id: String in Data.defence_ids():
		if Data.defence_info(id).get("from_bag", false) == true:
			out.append(id)
	return out


# ---------------------------------------------------------------- counts and room
## The camp's count (Save.bag, Save.mats or Save.items); 0 for an unknown id.
static func count(id: String) -> int:
	match kind_of(id):
		"food", "potion":
			return maxi(0, int(Save.bag.get(id, 0)))
		"material":
			return maxi(0, int(Save.mats.get(id, 0)))
		"build":
			return maxi(0, int(Save.items.get(id, 0)))
	return 0


## How many go in one slot: a potion's limit; everything else bag.stack.
static func stack_size(id: String) -> int:
	if kind_of(id) == "potion":
		return maxi(1, limit(id))
	return maxi(1, int(_cfg().get("stack", 20)))


## A potion's limit (its entry's "limit"); -1 for everything else (no limit but the room).
static func limit(id: String) -> int:
	if kind_of(id) != "potion":
		return -1
	return maxi(1, int(Data.item("recipes", id).get("limit", 1)))


static func slots() -> int:
	return maxi(0, int(_cfg().get("slots", 24)))


## How many slots the known things take now (every stack of every id).
static func used_slots() -> int:
	var n := 0
	for id in ids():
		n += _stacks_of(count(id), stack_size(id))
	return n


static func free_slots() -> int:
	return maxi(0, slots() - used_slots())


## How many more of id fit now: a potion its limit minus what is held (0 when none is held and no slot is free);
## anything else the space left in its last stack plus a whole stack per free slot. 0 for an unknown id.
static func room_for(id: String) -> int:
	var kind := kind_of(id)
	if kind == "":
		return 0
	var have := count(id)
	if kind == "potion":
		if have <= 0 and free_slots() <= 0:
			return 0
		return maxi(0, limit(id) - have)
	var size := stack_size(id)
	var in_last := (size - have % size) % size
	return in_last + free_slots() * size


# ---------------------------------------------------------------- changes
## Puts n of id in: what fits now, or all of it with force (a thing already paid for). Returns how many went in. Sends
## item_gained and bag_changed when anything went in.
static func add(id: String, n: int, force: bool = false) -> int:
	var kind := kind_of(id)
	if n <= 0:
		return 0
	if kind == "":
		push_warning("Bag.add: \"%s\" is not a thing the Bag holds" % id)
		return 0
	var put := n if force else mini(n, room_for(id))
	if put <= 0:
		return 0
	if kind == "material":
		Save.add_mat(id, put)                              # marks dirty, sends item_gained and bag_changed itself
		return put
	_set_count(id, kind, count(id) + put)
	Save.mark_dirty()
	Events.item_gained.emit(kind, id, put)
	Events.bag_changed.emit()
	return put


## Takes n of id out, all or nothing: false (and nothing taken) when there are fewer.
static func take(id: String, n: int) -> bool:
	if n <= 0:
		return true
	if count(id) < n:
		return false
	_take_raw(id, n)
	if kind_of(id) != "material":
		Save.mark_dirty()
		Events.bag_changed.emit()
	return true


## There are at least needs[id] of every id.
static func has_all(needs: Dictionary) -> bool:
	for k: Variant in needs:
		if count(String(k)) < int(needs[k]):
			return false
	return true


## Takes every needs[id] out, all or nothing. One bag_changed (amber sends its own).
static func take_all(needs: Dictionary) -> bool:
	if not has_all(needs):
		return false
	var changed := false
	for k: Variant in needs:
		var id := String(k)
		var n := int(needs[k])
		if n <= 0:
			continue
		_take_raw(id, n)
		changed = changed or kind_of(id) != "material"
	if changed:
		Save.mark_dirty()
		Events.bag_changed.emit()
	return true


## Puts each items[id] in (in the dictionary's order, each taking room from the next). Returns what did not fit,
## {id: n} ({} when everything went in).
static func add_all(items: Dictionary, force: bool = false) -> Dictionary:
	var left: Dictionary = {}
	for k: Variant in items:
		var id := String(k)
		var n := int(items[k])
		if n <= 0:
			continue
		var put := add(id, n, force)
		if n - put > 0:
			left[id] = n - put
	return left


# ---------------------------------------------------------------- carried defences (H6)
## What the next take_defence(kind) would hand out: {} when there is no stock; the first carried record; else
## {"level": credit} when an old paid level waits for the first piece; else fresh stock {"level": 1}.
static func peek_defence(kind: String) -> Dictionary:
	if kind_of(kind) != "build" or count(kind) <= 0:
		return {}
	_sync_reserves(kind)
	var list: Array = _reserves(kind)
	if not list.is_empty():
		return (list[0] as Dictionary).duplicate()
	var credit := int(Save.defence_legacy_credit.get(kind, 0))
	if credit > 0:
		return {"level": credit}
	return {"level": 1}


## Takes one piece out and returns its record ({} = no stock). A carried record leaves first; else the credit is used
## up ({"level": L, "credit": true}); else fresh stock {"level": 1}. Always marks the save dirty; bag_changed only
## when notify.
static func take_defence(kind: String, notify: bool = true) -> Dictionary:
	if kind_of(kind) != "build" or count(kind) <= 0:
		return {}
	_sync_reserves(kind)
	var record: Dictionary = {"level": 1}
	var list: Array = _reserves(kind)
	var credit := int(Save.defence_legacy_credit.get(kind, 0))
	_set_count(kind, "build", count(kind) - 1)
	if not list.is_empty():
		record = list.pop_front()
	elif credit > 0:
		Save.defence_legacy_credit.erase(kind)
		record = {"level": credit, "credit": true}
	Save.mark_dirty()
	if notify:
		Events.bag_changed.emit()
	return record


## Puts a piece back (always forced: it was paid for). Keeps the record only when it is not plain stock (a level
## other than 1, or a wreck); never makes a credit again. With notify: item_gained, then bag_changed, like add().
static func return_defence(kind: String, record: Dictionary, notify: bool = true) -> void:
	if kind_of(kind) != "build":
		return
	_sync_reserves(kind)
	_set_count(kind, "build", count(kind) + 1)
	if int(record.get("level", 1)) != 1 or record.has("wreck"):
		var keep: Dictionary = {"level": int(record.get("level", 1))}
		if record.has("wreck"):
			keep["wreck"] = float(record["wreck"])
		_reserves(kind).append(keep)
	Save.mark_dirty()
	if notify:
		Events.item_gained.emit("build", kind, 1)
		Events.bag_changed.emit()


## The level of the best piece of kind in the Bag: 0 when none is held; else the highest carried record's level, or 1
## when fresh stock is held too (more pieces than records). A credit is not a piece yet and does not count.
static func best_held_level(kind: String) -> int:
	if kind_of(kind) != "build" or count(kind) <= 0:
		return 0
	_sync_reserves(kind)
	var list: Array = _reserves(kind)
	var best := 1 if count(kind) > list.size() else 0
	for r: Variant in list:
		best = maxi(best, int((r as Dictionary).get("level", 1)))
	return maxi(1, best)


## The count of kind changed by something else (a command wrote it): marks the save dirty, tells the HUD.
static func defence_changed(kind: String, amount: int) -> void:
	Save.mark_dirty()
	if amount > 0:
		Events.item_gained.emit("build", kind, amount)
	Events.bag_changed.emit()


# ---------------------------------------------------------------- what the Bag shows
## One entry per stack, in the Bag order: {"id", "kind", "n" (in this stack), "index" (0 = the id's first stack)}.
static func stacks() -> Array:
	var out: Array = []
	for id in ids():
		var have := count(id)
		if have <= 0:
			continue
		var kind := kind_of(id)
		var size := stack_size(id)
		var index := 0
		while have > 0:
			out.append({"id": id, "kind": kind, "n": mini(have, size), "index": index})
			have -= size
			index += 1
	return out


## The name the player sees for n of id: food and potions from Data.item_name (balance.json ingredients, the recipe's
## name / plural), amber from Data.mat_name, towers and spikes from their defences entry.
static func name_of(id: String, n: int) -> String:
	match kind_of(id):
		"food", "potion":
			return Data.item_name(id, n)
		"material":
			return Data.mat_name(id)
		"build":
			return String(Data.defence_info(id).get("name", id))
	return id


## What it is for: a recipe's "desc", else balance.json bag.desc[id], else "".
static func desc(id: String) -> String:
	var r := Data.item("recipes", id)
	if r.has("desc"):
		return String(r["desc"])
	return String((_cfg().get("desc", {}) as Dictionary).get(id, ""))


## Its picture's id (ui_icons.gd / hud.icon): a recipe's "icon", else the id itself.
static func icon(id: String) -> String:
	var r := Data.item("recipes", id)
	if r.has("icon"):
		return String(r["icon"])
	return id


## What Use does: a recipe's "effects", else balance.json bag.use[id].effects; [] means it has no Use.
static func effects(id: String) -> Array:
	var r := Data.item("recipes", id)
	if r.get("effects") is Array:
		return r["effects"]
	var use: Variant = (_cfg().get("use", {}) as Dictionary).get(id)
	if use is Dictionary and (use as Dictionary).get("effects") is Array:
		return (use as Dictionary)["effects"]
	return []


# ---------------------------------------------------------------- inside
static func _cfg() -> Dictionary:
	var c: Variant = Data.b.get("bag", {})
	return c if c is Dictionary else {}


static func _stacks_of(n: int, size: int) -> int:
	if n <= 0:
		return 0
	return ceili(float(n) / float(maxi(1, size)))


## Writes a count (never below 0) for a food, potion or build id. Food and potions at 0 leave Save.bag.
static func _set_count(id: String, kind: String, n: int) -> void:
	if kind == "build":
		Save.items[id] = maxi(0, n)
	elif n > 0:
		Save.bag[id] = n
	else:
		Save.bag.erase(id)


## Takes n out without events (the callers send them). Amber goes through Save.add_mat (which sends its own).
static func _take_raw(id: String, n: int) -> void:
	var kind := kind_of(id)
	if kind == "material":
		Save.add_mat(id, -n)
	else:
		if kind == "build":
			_sync_reserves(id)
			var list: Array = _reserves(id)
			for i in mini(n, list.size()):
				list.pop_front()                            # the oldest carried records leave first
		_set_count(id, kind, count(id) - n)


## The carried records of kind (the array itself, made when missing).
static func _reserves(kind: String) -> Array:
	var v: Variant = Save.defence_reserves.get(kind)
	if not v is Array:
		v = []
		Save.defence_reserves[kind] = v
	return v


## Keeps the rule reserves.size() <= count: old callers write Save.items directly, so extra records go from the back.
static func _sync_reserves(kind: String) -> void:
	if not Save.defence_reserves.has(kind):
		return
	var list: Array = _reserves(kind)
	var have := maxi(0, int(Save.items.get(kind, 0)))
	while list.size() > have:
		list.pop_back()
