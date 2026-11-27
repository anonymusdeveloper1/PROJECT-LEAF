extends RefCounted
## H5 (26 Nov 2026; docs/ARCHITECTURE.md parts 5 and 10): the shops' catalogue. It answers "what is on sale, what does
## it cost, what does the player own" for the four content kinds H5 moved out of balance.json: mounts, pets, outfits and
## attachments (content/<kind>/<id>/entry.json, listed in content/index.json). Static functions only; it keeps no state.
## Callers never use this file directly: scripts/data.gd is the front door (Data.shop_entries, Data.owned_level, ...),
## and the older names there (Data.look, cat_skin_*, saddle_*, attachments_on) read their entries through it.
## No class_name: data.gd preloads it.
## Rules:
##   - Index order everywhere. A hidden entry ("hidden": true) or a malformed one (no id) is never shown or sold, but a
##     save that owns it keeps it (its record and level still count).
##   - Prices: a currency dictionary, {"leaves": 160} or {"leaves": 900, "timber": 30}. An explicit {} is free, or
##     included under the entry's unlock rule (Thistle and Bramblewool with the Market, the original outfit). A price
##     that is missing, not a dictionary, or names a currency the shops cannot take (amber, or one the game does not
##     know yet) fails closed: never free, never sold.
##   - A levelled entry (a Saddlery attachment) has "price" for level 1 and "upgrades" for levels 2, 3, ... in order.
##     A level's "needs_burrows": true is a gate (the Burrows open), never a payment.
##   - Ownership (the v5 save, live since H5 Stage 2): Save.owned[kind][id] = {"level": n} for every kind here (the
##     Saddlery's attachments by their bought level, expedition gear and looks at 1); the pet's one level is
##     Save.pet_level. An entry with an explicit free price ({}) whose unlock rule holds is owned without a record.
## Used by: scripts/data.gd. Uses: Data (the catalogue, balance.json, the unlock rules, the currencies), Save.

## A companion slot and the content kind that holds its looks. The guardian's looks stay in balance.json looks.
const SLOT_KINDS := {"mount": "mounts", "pet": "pets"}
## The building whose shop sells the Saddlery's attachments (its entries' "shop"); also the building whose level caps them.
const SADDLERY := "saddlery"


# ---------------------------------------------------------------- the catalogue
## Every entry of a kind that can be shown and sold, in index order (hidden and malformed entries left out).
static func shop_entries(kind: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Variant in Data.catalog(kind):
		if _listed(e):
			out.append(e)
	return out


## One entry that can be shown and sold, by its exact id; {} for an unknown, hidden or malformed one. Check this before
## paying: an unknown id never falls back to Sprig or Thistle here.
static func shop_entry(kind: String, id: String) -> Dictionary:
	var e: Dictionary = Data.item(kind, id)
	return e if _listed(e) and String(e["id"]) == id else {}


## The entry has an id and is not hidden.
static func _listed(e: Variant) -> bool:
	return e is Dictionary and (e as Dictionary).get("id") is String and String(e["id"]) != "" \
		and not bool((e as Dictionary).get("hidden", false))


## The attachments one shop sells for one slot ("mount" or "pet"; "" for both), in index order: the Saddlery's
## ("saddlery") or the Market's expedition gear ("stall").
static func attachment_entries(shop: String, slot: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in shop_entries("attachments"):
		if String(e.get("shop", "")) == shop and (slot == "" or String(e.get("slot", "")) == slot):
			out.append(e)
	return out


## The entry's full-body shop picture (its "picture", a res:// path) when that file exists, else "": the window then
## draws the entry's "icon" instead.
static func shop_picture(kind: String, id: String) -> String:
	var path := String(Data.item(kind, id).get("picture", ""))
	return path if path != "" and ResourceLoader.exists(path) else ""


## A mount's or pet's model (its entry's "model", a res:// .glb) when the file exists, else "" (slot "mount" or "pet").
static func companion_model(slot: String, id: String) -> String:
	var path := String(Data.item(String(SLOT_KINDS.get(slot, "")), id).get("model", ""))
	return path if path != "" and ResourceLoader.exists(path) else ""


## An attachment's model fitted to one mount look (its entry's "model" with {mount} filled in) when the file exists, else "".
static func gear_model(id: String, look_id: String) -> String:
	var path := String(Data.item("attachments", id).get("model", "")).replace("{mount}", look_id)
	return path if path != "" and ResourceLoader.exists(path) else ""


# ---------------------------------------------------------------- prices
## The currencies a shop price may ask for: every currency the game knows except the expedition materials (amber is
## sold to Bramble, never paid with).
static func _payable(key: String) -> bool:
	return Data.CURRENCIES.has(key) and not Data.MATS.has(key)


## The raw price of reaching `level` of an entry (level 1: its "price"; level n: "upgrades"[n - 2]); null past its top.
static func _raw_price(e: Dictionary, level: int) -> Variant:
	if level == 1:
		return e.get("price")
	var ups: Variant = e.get("upgrades", [])
	if ups is Array and level >= 2 and level - 2 < (ups as Array).size():
		return ups[level - 2]
	return null


## A price is well formed: a dictionary whose numbers are all whole amounts above 0 in payable currencies. Its other
## keys (a gate such as needs_burrows: true, a note) are not money. {} is well formed (free).
static func _price_ok(price: Variant) -> bool:
	if not price is Dictionary:
		return false
	for k: Variant in price:
		var v: Variant = price[k]
		var number := v is int or v is float
		if String(k).begins_with("_") or (not number and not Data.CURRENCIES.has(String(k))):
			continue                                    # a gate or a note
		if not number or not _payable(String(k)) or float(v) <= 0.0 or float(v) != floorf(float(v)):
			return false
	return true


## What reaching `level` of entry id costs, its real currencies only (never 0s, never a gate); {} when it is free, past
## its top, or for an unknown id. entry_price_ok says whether it can be paid at all.
static func entry_price(kind: String, id: String, level: int) -> Dictionary:
	var raw: Variant = _raw_price(Data.item(kind, id), level)
	return Data._currency_price(raw) if raw is Dictionary else {}


## Level `level` of entry id can be sold: a shown entry, a level it has, and a well-formed price (fails closed).
static func entry_price_ok(kind: String, id: String, level: int) -> bool:
	var e: Dictionary = shop_entry(kind, id)
	return not e.is_empty() and _price_ok(_raw_price(e, level))


## How many levels an entry has: 1 plus its upgrades (0 for an unknown id or one without a price).
static func entry_top(kind: String, id: String) -> int:
	var e: Dictionary = Data.item(kind, id)
	if not e.has("price"):
		return 0
	var ups: Variant = e.get("upgrades", [])
	return 1 + ((ups as Array).size() if ups is Array else 0)


## Level `level` of entry id waits for the Burrows (its price has needs_burrows: true).
static func entry_needs_burrows(kind: String, id: String, level: int) -> bool:
	var raw: Variant = _raw_price(Data.item(kind, id), level)
	return raw is Dictionary and bool((raw as Dictionary).get("needs_burrows", false))


# ---------------------------------------------------------------- what the player owns
## The level the player owns of entry id: 0 = not owned; for a look or an outfit 1 = owned; for a Saddlery attachment
## its bought level. Read from the v5 save (Save.owned[kind][id] = {"level": n}); an entry with an explicit free price
## ({}) whose unlock rule holds counts as owned at level 1 (included: Thistle and Bramblewool once the Market is built,
## the original outfit). A malformed record counts as 0.
static func owned_level(kind: String, id: String) -> int:
	var lv: int = _record_level(kind, id)
	if lv < 1 and _included(kind, id):
		lv = 1
	return lv


## The level in Save.owned[kind][id] ({"level": n}, or a bare number), 0 when there is none or it is malformed.
static func _record_level(kind: String, id: String) -> int:
	var shelf: Variant = Save.owned.get(kind)
	if not shelf is Dictionary:
		return 0
	var rec: Variant = (shelf as Dictionary).get(id)
	if rec is Dictionary:
		rec = (rec as Dictionary).get("level", 0)
	if rec is int or rec is float:
		return maxi(0, int(rec))
	return 0


## A shown entry whose price is exactly {} and whose unlock rule holds: it comes with what unlocks it, no purchase.
static func _included(kind: String, id: String) -> bool:
	var e: Dictionary = shop_entry(kind, id)
	if e.is_empty() or not e.get("price") is Dictionary or not (e["price"] as Dictionary).is_empty():
		return false
	var rule: Variant = e.get("unlock", {})
	return rule is Dictionary and Data.unlocked(rule)


# ---------------------------------------------------------------- companion looks
## A mount's or pet's look by id (its content entry: name, short, fur, skins; a pet's flies and spark), the first
## shown look of the slot for an unknown id (as before H5), {} when the slot has none.
static func look(slot: String, id: String) -> Dictionary:
	var kind := String(SLOT_KINDS.get(slot, ""))
	var e: Dictionary = Data.item(kind, id)
	if not e.is_empty():
		return e
	var shown: Array[Dictionary] = shop_entries(kind)
	return shown[0] if not shown.is_empty() else {}


# ---------------------------------------------------------------- the pet (one shared level for every pet look)
## The pet's level (Save.pet_level: 0 before the pet is bought, then 1-3), one for every pet look. Data.pet_level()
## gives this (H5 Stage 2; before H5 it was the Mushroom Cottage's level).
static func pet_level() -> int:
	return maxi(0, Save.pet_level)


## What training the pet to `level` costs (balance.json pet.level_prices[level - 1]: levels 2 and 3, the old Cottage's
## prices); {} for level 1 (buying the pet is its entry's price) and past the top.
static func pet_level_price(level: int) -> Dictionary:
	var t: Variant = (Data.b.get("pet", {}) as Dictionary).get("level_prices", [])
	if not t is Array or level < 2 or level > (t as Array).size() or not t[level - 1] is Dictionary:
		return {}
	return Data._currency_price(t[level - 1])


## The pet's top level (the length of pet.level_prices: 3).
static func pet_top() -> int:
	var t: Variant = (Data.b.get("pet", {}) as Dictionary).get("level_prices", [])
	return (t as Array).size() if t is Array else 0


## The highest level the pet can be trained to now: its top, never above the Hearthtree's level (the old Cottage's cap).
static func pet_level_cap() -> int:
	return mini(pet_top(), Save.camp_level)


## The building whose shop sells and trains the pet (the first pet look's "shop": the Market, "stall"); "" if none says.
static func pet_shop() -> String:
	var pets: Array[Dictionary] = shop_entries("pets")
	return String(pets[0].get("shop", "")) if not pets.is_empty() else ""


# ---------------------------------------------------------------- the mount (one shared level for every mount look)
## The mount's walking-speed multiplier at mount level `level` (balance.json mount.speed_by_level; levels 1-5).
static func mount_speed_at(level: int) -> float:
	return Data.pick("mount", "speed_by_level", level)


## The mount's base health at mount level `level` (balance.json mount.hp_by_level), before the Mossweave Saddle and
## expedition help.
static func mount_base_hp_at(level: int) -> int:
	return roundi(Data.pick("mount", "hp_by_level", level))


## The mount's level with the Saddlery at `level` (the v5 rule, the owner's Q2 A): 0 when no mount is owned, else the
## highest of 1, that Saddlery level and the tier an old save already paid for (Save.saddlery["mount_credit"]), never
## past the mount tables' top. With the Saddlery's real level it is the mount's level now; with the next one, what
## the Saddlery's Upgrade gives (the confirm and the mount read the same tables).
static func mount_level_at_saddlery(level: int) -> int:
	if not _mount_owned():
		return 0
	var credit: Variant = Save.saddlery.get("mount_credit", 0)
	var paid := int(credit) if credit is int or credit is float else 0
	var top: int = mini(_table_top("speed_by_level"), _table_top("hp_by_level"))
	return clampi(maxi(1, maxi(level, paid)), 1, maxi(1, top))


## Some mount look is owned (owned_level >= 1, an included one too), hidden ones included.
static func _mount_owned() -> bool:
	for e: Variant in Data.catalog("mounts"):
		if e is Dictionary and owned_level("mounts", String((e as Dictionary).get("id", ""))) >= 1:
			return true
	return false


## The last level a balance.json mount table has (its length - 1).
static func _table_top(key: String) -> int:
	var t: Variant = (Data.b.get("mount", {}) as Dictionary).get(key, [])
	return (t as Array).size() - 1 if t is Array else 0


# ---------------------------------------------------------------- the mount's skill circles (three, shared by every mount)
## How many skill circles there are (balance.json saddlery.skill_slot_count: 3).
static func skill_slot_count() -> int:
	return maxi(0, int(Data.saddlery_cfg().get("skill_slot_count", 3)))


## The skill in each circle, in order (Save.saddlery["skill_slots"]), always skill_slot_count() of them: "" for an
## empty circle, and for anything that is not a known skill or repeats one already in an earlier circle.
static func skill_slots() -> Array[String]:
	var out: Array[String] = []
	var raw: Variant = Save.saddlery.get("skill_slots", [])
	var saved: Array = raw if raw is Array else []
	for i in skill_slot_count():
		var id := String(saved[i]) if i < saved.size() and saved[i] is String else ""
		if id != "" and (Data.saddle_info("skills", id).is_empty() or out.has(id)):
			id = ""
		out.append(id)
	return out


## Skill id sits in one of the circles.
static func skill_is_slotted(id: String) -> bool:
	return id != "" and skill_slots().has(id)


## The level the mount fights with: its learned level (Data.skill_level) while it is in a circle, else 0. A learned
## skill outside the circles keeps its level but is not used.
static func active_skill_level(id: String) -> int:
	return Data.skill_level(id) if skill_is_slotted(id) else 0


# ---------------------------------------------------------------- outfits (the Tailor's Nook)
## The outfit ids that can be shown, in index order, the default first if the index lacks it.
static func outfit_ids(default_id: String) -> Array:
	var out: Array = []
	for e: Dictionary in shop_entries("outfits"):
		out.append(String(e["id"]))
	if not out.has(default_id):
		out.push_front(default_id)
	return out


## Outfit id in the shape the H4 Tailor's Nook reads ({"id", "name", "short", "desc", "price", "currency", "model",
## "picture"}: one price in one currency, 0 when free), built from its content entry; {} for an unknown id. A copy:
## change the shared entry (Data.item("outfits", id)) to change what the game does.
static func outfit_view(id: String) -> Dictionary:
	var e: Dictionary = Data.item("outfits", id)
	if e.is_empty():
		return {}
	var price := 0
	var currency := "leaves"
	var cost: Dictionary = outfit_cost(id)
	for k: String in cost:
		currency = k
		price = int(cost[k])
		break
	return {"id": id, "name": String(e.get("name", id)), "short": String(e.get("desc", "")), "desc": String(e.get("desc", "")),
		"price": price, "currency": currency, "model": String(e.get("model", "")), "picture": String(e.get("picture", ""))}


## What outfit id costs: every amount above 0 its price names, a currency the game cannot take included (so the card
## can still show it); {} when it is free or has no price.
static func outfit_cost(id: String) -> Dictionary:
	var price: Variant = Data.item("outfits", id).get("price", {})
	var out: Dictionary = {}
	if price is Dictionary:
		for k: Variant in price:
			var v: Variant = price[k]
			if (v is int or v is float) and float(v) > 0.0 and not String(k).begins_with("_"):
				out[String(k)] = int(v)
	return out


## Outfit id's price can be paid: a shown entry with a well-formed price (amber or an unknown currency: never).
static func outfit_price_ok(id: String) -> bool:
	return entry_price_ok("outfits", id, 1)


## Outfit id's hero model (its entry's "model", a res:// .glb) when the file exists, else "".
static func outfit_model(id: String) -> String:
	var path := String(Data.item("outfits", id).get("model", ""))
	return path if path != "" and ResourceLoader.exists(path) else ""


# ---------------------------------------------------------------- the Saddlery's attachments (levelled, everywhere)
## The Saddlery's attachments that can be shown, id -> entry, in index order (fire_spitter, saddle, saddlebags).
static func saddle_attachments() -> Dictionary:
	var out: Dictionary = {}
	for e: Dictionary in attachment_entries(SADDLERY, ""):
		out[String(e["id"])] = e
	return out


## A Saddlery attachment's entry by id (a hidden one too, so a save that owns it keeps it); {} for any other id.
static func saddle_attachment(id: String) -> Dictionary:
	var e: Dictionary = Data.item("attachments", id)
	return e if String(e.get("shop", "")) == SADDLERY else {}


## The level of Saddlery attachment id the player bought (the v5 save's owned.attachments; a hidden one too), 0 when
## it is not bought or is not a Saddlery attachment (expedition gear and old receipt ids count 0 here).
static func saddle_attachment_level(id: String) -> int:
	return owned_level("attachments", id) if not saddle_attachment(id).is_empty() else 0


# ---------------------------------------------------------------- expedition gear (the Burrows only)
## The expedition gear worn now (Save.attach "mount" and "pet"), each one owned (owned_level, the v5 save's
## owned.attachments), as their entries (each has its "mods"). Data.attachments_on() gives this.
static func expedition_worn() -> Array:
	var out: Array = []
	for slot: String in SLOT_KINDS:
		var worn: Variant = Save.attach.get(slot, "")
		var id: String = worn if worn is String else ""
		var e: Dictionary = Data.item("attachments", id)
		if id != "" and String(e.get("scope", "")) == "expedition" and String(e.get("slot", "")) == slot \
				and owned_level("attachments", id) >= 1:
			out.append(e)
	return out
