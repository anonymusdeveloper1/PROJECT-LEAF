extends RefCounted
## Per-piece levels, quotes and upgrades for the camp's defences (H6 Stage 2, 27 Nov 2026; docs/ARCHITECTURE.md part 4).
## Every tower, patch and barricade row carries its own `level` (1 to 5), in the live piece and in its Save.placed record.
## defences.gd is the facade and forwards here (piece_cap, level_stats, new_row_level, upgrade_quote, upgrade_placed,
## repair_quote, pad_reason, refresh_specialisation); this file holds the rules and reads no marker or card.
## Used by: defences.gd (the only caller), through its forwards.
## Uses: Data (defence tiers, specialisations, prices, Workshop level), Save (placed records, ruined), DefencePersistence
## (the barricade credit), Bag (best_held_level), the defences node `d` (pieces, rows, _spawn names).
## Rules:
##   - Data.defence_level_info returns {} outside 1..top, it does not clamp: every level here is clamped first.
##   - defences.build runs before stations.build, so piece_cap reads the Workshop from Save (level and ruin), never from
##     main.stations. Only upgrade_quote asks the Workshop's own refusal (stations.workshop_reason), later, at play time.
##   - Money is never a reason: a quote that only lacks money is eligible; Data.pay refuses in upgrade_placed.
##   - A stale or missing target spends nothing.

const DefencePersistence := preload("res://scripts/defence_persistence.gd")

var d: Node3D                           # the defences node (defences.gd)


func setup(defences: Node3D) -> void:
	d = defences


# ---------------------------------------------------------------- levels
## The top tier of a kind (5 for all three today).
func top(kind: String) -> int:
	return maxi(1, (Data.defence_info(kind).get("levels", []) as Array).size())


func clamp_level(kind: String, lv: int) -> int:
	return clampi(lv, 1, top(kind))


## The level a live piece or a saved record holds (1 when it has none: an older test's piece).
func piece_level(p: Dictionary) -> int:
	return clamp_level(String(p.get("type", "tower")), int(p.get("level", 1)))


func row_level(row: Dictionary) -> int:
	return clamp_level("barricade", int(row.get("level", 1)))


## The best level of a kind: placed pieces (a row counts once), what the Bag holds, and at least 1.
func best_level(kind: String) -> int:
	var best := 1
	if kind == "barricade":
		for row: Dictionary in d.rows:
			best = maxi(best, row_level(row))
	else:
		for p: Dictionary in d.pieces:
			if String(p["type"]) == kind:
				best = maxi(best, piece_level(p))
	return maxi(best, Bag.best_held_level(kind))


## The level a row built now starts at: the barricade credit of an old save, else 1.
func new_row_level() -> int:
	return clamp_level("barricade", maxi(1, DefencePersistence.peek_credit("barricade")))


# ---------------------------------------------------------------- specialisations
func _tuning(id: String) -> Dictionary:
	var info: Dictionary = Data.specialisation_info(id)
	var t: Variant = info.get("tuning", {})
	if t is Dictionary and not (t as Dictionary).is_empty():
		return t as Dictionary
	var all: Variant = Data.b.get("specialisations", {})
	return (all as Dictionary).get(id, {}) if all is Dictionary else {}


## A tuning list entry at a learned level (0.0 when it is not learned or the list is short).
func _by_level(id: String, key: String) -> float:
	var lv: int = Data.specialisation_level(id)
	var list: Variant = _tuning(id).get(key, [])
	if lv < 1 or not (list is Array) or (list as Array).is_empty():
		return 0.0
	return float((list as Array)[clampi(lv, 1, (list as Array).size()) - 1])


## Reinforced barricades: the extra share of health every row section has (0 when not learned).
func hp_bonus() -> float:
	return _by_level("reinforced_barricades", "hp_bonus")


## The crack threshold now: Reinforced barricades' own once learned, else the entry's (`base`).
func crack_at(base: float) -> float:
	if int(Data.specialisation_level("reinforced_barricades")) > 0:
		return float(_tuning("reinforced_barricades").get("crack_at", base))
	return base


## Deep thorns: what every patch's slow is multiplied by (1.0 when not learned).
func slow_mult() -> float:
	var m := _by_level("deep_thorns", "slow_mult")
	return m if m > 0.0 else 1.0


## A piece's full health at a level (a patch has no combat wear: 1.0). Reinforced barricades add its share.
func max_hp(kind: String, lv: int) -> float:
	if kind == "spikes":
		return 1.0
	var hp := float(Data.defence_level_info(kind, clamp_level(kind, lv)).get("hp", 1))
	if kind == "barricade":
		hp *= 1.0 + hp_bonus()
	return hp


## What a tier costs to reach: its `price` (leaves, timber), only real money.
func tier_price(kind: String, lv: int) -> Dictionary:
	var info: Dictionary = Data.defence_level_info(kind, lv)
	var src: Variant = info.get("price", {})
	var out: Dictionary = {}
	if src is Dictionary and not (src as Dictionary).is_empty():
		for k: String in Data.CURRENCIES:
			if int((src as Dictionary).get(k, 0)) > 0:
				out[k] = int((src as Dictionary)[k])
	elif int(info.get("upgrade", 0)) > 0:
		out["leaves"] = int(info["upgrade"])      # an entry that has no price block yet
	return out


## The numbers of a kind at a level, specialisations applied: {hp, damage, every, range, dps, slow, price}. A number the
## kind does not have is 0.0. The card's "next" gains come from here.
func level_stats(kind: String, lv: int) -> Dictionary:
	var at := clamp_level(kind, lv)
	var info: Dictionary = Data.defence_level_info(kind, at)
	return {"hp": max_hp(kind, at) if kind != "spikes" else 0.0, "damage": float(info.get("damage", 0)),
		"every": float(info.get("every", 0)), "range": float(info.get("range", 0)), "dps": float(info.get("dps", 0)),
		"slow": float(info.get("slow", 0)) * (slow_mult() if kind == "spikes" else 1.0), "price": tier_price(kind, at)}


# ---------------------------------------------------------------- the caps
## The highest level a piece of `kind` may be upgraded to: the Workshop's level, at most 5, 3 until every mission is won,
## 4 until the Burrows are open. workshop_level -1: the standing Workshop now (none or ruined: 0).
func piece_cap(kind: String, workshop_level := -1) -> int:
	var wl := workshop_level
	if wl < 0:
		wl = 0 if Save.ruined.has("workshop") else Data.station_level("workshop")
	var cap := mini(mini(wl, 5), top(kind))
	if not Data.raids_open():
		cap = mini(cap, 3)
	elif not Data.burrows_open():
		cap = mini(cap, 4)
	return maxi(cap, 0)


static func _w(key: String, fallback: String) -> String:
	var s := Data.word(key)
	return fallback if s == key else s


## The refusal for a gate of the next level: the Workshop's level, then the raids, then the Burrows ("" when none).
func _cap_reason(kind: String, next: int) -> String:
	var wl: int = 0 if Save.ruined.has("workshop") else Data.station_level("workshop")
	if wl < next:
		return _w("upgrade_cap", "Needs Workshop level %d") % next
	if next >= 4 and not Data.raids_open():
		return _w("needs_raids", "Opens after the Raid Missions")
	if next >= 5 and not Data.burrows_open():
		return _w("needs_burrows", "Opens with the Burrows")
	return "" if next <= piece_cap(kind) else _w("upgrade_cap", "Needs Workshop level %d") % next


# ---------------------------------------------------------------- finding the target
## {"row": row} or {"piece": piece} for a kind, an id and a slot ({} when there is none, or the kind does not match).
func _target(kind: String, id: int, slot: Vector2i) -> Dictionary:
	if kind == "barricade":
		var row: Dictionary = d.row_at(slot.x, slot.y)
		return {} if row.is_empty() else {"row": row}
	var p: Dictionary = d.piece_at(id)
	if p.is_empty() or String(p["type"]) != kind:
		return {}
	return {"piece": p}


func _target_level(t: Dictionary) -> int:
	return row_level(t["row"]) if t.has("row") else piece_level(t["piece"])


# ---------------------------------------------------------------- upgrades
## What upgrading one placed piece or row would take: {"next_level": int (0: none), "price": Dictionary, "reason": ""}.
## The checks run in this order: the target, the level shown (stale), the top, the Workshop, the cap, a wave or being
## below ground. Money is never a reason.
func quote(kind: String, id: int, slot: Vector2i, expected_level: int) -> Dictionary:
	var out := {"next_level": 0, "price": {}, "reason": ""}
	var t := _target(kind, id, slot)
	if t.is_empty():
		out["reason"] = _w("upgrade_gone", "That is gone")
		return out
	var cur := _target_level(t)
	if expected_level != cur:
		out["reason"] = _w("upgrade_stale", "It changed: look again")
		return out
	var next := cur + 1
	if next > top(kind):
		out["reason"] = _w("upgrade_max", "At its top level")
		return out
	out["next_level"] = next
	out["price"] = tier_price(kind, next)
	var st: Variant = d.main.stations if d.main != null else null
	if st != null and st.has_method("workshop_reason"):
		var why := String(st.call("workshop_reason"))
		if why != "":
			out["reason"] = why
			return out
	var cap := _cap_reason(kind, next)
	if cap != "":
		out["reason"] = cap
	elif d._wave_on():
		out["reason"] = _w("workshop_wave", "Between waves")
	elif d.main.area != null:
		out["reason"] = _w("workshop_below", "Not below ground")
	return out


## Upgrades one placed piece or row: quotes again, pays, applies the level, fills the health (all three sections of a
## row), clears the saved wrecks and saves. False (nothing spent) when the quote has a reason or the money is short.
func upgrade(kind: String, id: int, slot: Vector2i, expected_level: int) -> bool:
	var q := quote(kind, id, slot, expected_level)
	if String(q["reason"]) != "" or int(q["next_level"]) <= 0:
		return false
	var t := _target(kind, id, slot)
	if t.is_empty() or not Data.pay(q["price"]):
		return false
	var next := int(q["next_level"])
	apply_level(t.get("row", t.get("piece", {})), next)
	var list: Array = (t["row"]["pieces"] as Array) if t.has("row") else [t["piece"]]
	for p: Dictionary in list:
		restat(p)
	for src: Variant in _records(t):
		(src as Dictionary).erase("wreck")
		(src as Dictionary).erase("wrecks")
	Save.save_game()
	d._refresh_marks()
	var at: Vector3 = (t["row"]["root"] as Node3D).position if t.has("row") else t["piece"]["pos"]
	for p: Dictionary in list:
		if is_instance_valid(p["node"]):
			Fx.boing(p["node"], 0.35)
	Fx.flower_ring(d.main, at, 1.5 if t.has("row") else 1.2)
	if d.main.hud != null:
		d.main.on_purchase()
	return true


## The Save.placed records of a target (a row's own, or its sections' when an older test only set those; a piece's own).
func _records(t: Dictionary) -> Array:
	var out: Array = []
	var list: Array = (t["row"]["pieces"] as Array) if t.has("row") else [t["piece"]]
	var first: Variant = t["row"].get("src") if t.has("row") else null
	if first is Dictionary:
		out.append(first)
	for p: Dictionary in list:
		var sp: Variant = p.get("src")
		if sp is Dictionary and not out.has(sp):
			out.append(sp)
	return out


## Writes a level on a row (and every section, and its record) or on one piece (and its record). Health and looks
## follow with restat.
func apply_level(target: Dictionary, lv: int) -> void:
	target["level"] = lv
	if target.has("pieces"):
		for p: Dictionary in target["pieces"]:
			p["level"] = lv
	for src: Variant in _records({"row": target} if target.has("pieces") else {"piece": target}):
		(src as Dictionary)["level"] = lv


## One piece at its (new) level: full health, standing, not wrecked, its new model, looks, collision and marker.
func restat(p: Dictionary) -> void:
	var kind := String(p["type"])
	var lv := piece_level(p)
	p["max_hp"] = max_hp(kind, lv)
	p["hp"] = p["max_hp"]
	p["wrecked"] = false
	p["broken"] = false
	d._swap_model(p, lv)
	d._show(p)
	d._collide(p)
	d._markers.reattach_piece(int(p["id"]))


## A specialisation was learned or raised: Reinforced barricades rebuilds every section's health (each keeps its
## share; a broken one stays at 0) and its look; the others read their numbers live.
func refresh_specialisation(id: String) -> void:
	if id == "reinforced_barricades":
		for p: Dictionary in d.pieces:
			if String(p["type"]) != "barricade":
				continue
			var share := clampf(float(p["hp"]) / maxf(float(p["max_hp"]), 1.0), 0.0, 1.0)
			p["max_hp"] = max_hp("barricade", piece_level(p))
			p["hp"] = float(p["max_hp"]) * share
			p["broken"] = float(p["hp"]) <= 0.0
			d._show(p)
			d._collide(p)
	d._refresh_marks()


# ---------------------------------------------------------------- repair and pads
## Does the row have a section that is broken (down)?
func row_broken(row: Dictionary) -> bool:
	for p: Dictionary in row.get("pieces", []):
		if float(p["hp"]) <= 0.0 or bool(p["broken"]):
			return true
	return false


## The Repair button of a placed piece: {"show", "price", "reason"}. Shown for a downed tower or a row with a broken
## section; a patch never shows it. A tower waits for the break between waves; a row may be repaired in a wave.
func repair_quote(kind: String, id: int, slot: Vector2i) -> Dictionary:
	var out := {"show": false, "price": {}, "reason": ""}
	if kind == "barricade":
		var row: Dictionary = d.row_at(slot.x, slot.y)
		if row.is_empty() or not row_broken(row):
			return out
		out["show"] = true
		out["price"] = d.repair_row_cost(row)
		return out
	if kind != "tower":
		return out
	var p: Dictionary = d.piece_at(id)
	if p.is_empty() or String(p["type"]) != "tower" or float(p["hp"]) > 0.0:
		return out
	out["show"] = true
	out["price"] = d.tower_repair_cost(p)
	if d._wave_on():
		out["reason"] = _w("between_waves", "Between waves")
	return out


func repair_placed(kind: String, id: int, slot: Vector2i) -> bool:
	if kind == "barricade":
		return d.repair_row_at(slot.x, slot.y)
	if kind == "tower":
		return d.repair_tower_id(id)
	return false


## Can a row be built at this road pad? "" when it can (money aside), else a word: barricades come later, the pad opens
## later, a row already stands, a wave is on, or the cat is below ground.
func pad_reason(lane: int, pad: int) -> String:
	if not d.unlocked("barricade"):
		return _w("pad_barricades_later", "Barricades open later")
	if not d.pad_open(lane, pad):
		return _w("pad_opens_later", "This pad opens as the %s grows") % Data.camp_name().trim_prefix("the ")
	if not d.row_at(lane, pad).is_empty():
		return _w("pad_built", "A row stands here")
	if d._wave_on():
		return _w("workshop_wave", "Between waves")
	if d.main.area != null:
		return _w("workshop_below", "Not below ground")
	return ""
