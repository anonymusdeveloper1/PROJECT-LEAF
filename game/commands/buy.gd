extends "res://commands/command.gd"
## Buy one thing (H5, 27 Nov 2026; docs/ARCHITECTURE.md part 4, Command; the H5 map part 3.3). Every shop's Buy, Learn,
## item Upgrade, Train and Unlock sends this one command: Buy.new(kind, id, amount, expected_level, look_id), with
## Buy = preload("res://commands/buy.gd"). can_run(main) gives "" or the reason (a player word from balance.json
## windows); run(main) does the whole purchase or nothing. A building's own Upgrade is not a Buy: it stays
## ask_upgrade() and stations._upgrade_station(), and Wear, Equip, Build and Repair keep their own rules.
## Kinds (id is the exact content or balance id; an unknown, hidden or malformed one is never bought, and never falls
## back to Sprig or Thistle):
##   market_goods   one of Bramble's "sells" offers (scripts/market_trade.gd), amount = whole bundles (two bundles of
##                  Sunberries = 4 for 60 leaves). Selling to him is MarketTrade.sell, not this
##   mounts         a mount look (content/mounts). Thistle and Bramblewool come with the Market (price {}): they are
##                  owned once it is built and are never bought; a later paid mount is bought here
##   pets           a pet look (content/pets). Sprig (a full pet) gives the pet at level 1 (Save.pet_level); Lumi
##                  ("looks_only", the owner's Q1 B) needs the pet first and buys only her look
##   pet_training   the next level of the one shared pet level (id is not used); never above the Hearthtree's level
##   skills         learns (level 1) or upgrades a mount skill (balance.json mount_skills). A new skill goes into the
##                  grid, not a circle: the player drags it in (scripts/companion_shop.gd assign_skill)
##   attachments    a Saddlery attachment's next level, or one piece of expedition gear (content/attachments)
##   outfits        an outfit (content/outfits)
##   colour_unlock  a priced colour (Gloomlit) of one exact look: id = the colour's id, look_id = the look's id (its
##                  slot, mount, pet or guardian, comes from where that look is listed)
##   bows           a bow at the Bow Shop (the rule of stations._craft: the same gates, worn at once between waves)
##   defences       one tower or spikes piece into the Bag (the rule of stations._buy_piece)
## amount is 1 for every kind but market_goods. expected_level is the level the button showed this purchase reaching
## (Learn = 1, an Upgrade to level 3 = 3; next_level() gives it when the button is drawn); -1 skips the check. A stale
## button (the level moved on since it was drawn) buys nothing, so one tap never buys two levels.
## Rules:
##   - can_run checks everything again when it runs: the kind and the exact id, that the price is well formed (an
##     unknown currency or amber fails closed), the building that sells it standing (built, not in ruins), its unlock
##     rule, ownership, the level cap and the Burrows gate, the room, then the money last. A free thing ({}) still
##     needs its entitlement.
##   - The paid currency buys only looks (CLAUDE.md): a price for power (a full pet, its training, a skill, gear, a
##     bow, a piece, Bramble's goods) that names shards is refused, never paid. Outfits, colours, looks-only pets and
##     mount looks may.
##   - run pays, writes the save's fields, marks the save dirty and sends Events.item_gained(kind, id, 1) once for a
##     new thing (a level-1 skill or attachment, a look, an outfit, a colour with id "skin:<slot>:<look>:<colour>", a
##     bow). A higher level or the pet's training is not a new thing. Bag items (market goods, pieces) send the Bag's
##     own item_gained instead, so one purchase is one gain. It never saves, opens no window and never calls the HUD:
##     the caller saves (as the old rules did), refreshes the live model once, gives the receipt and redraws.
##   - What the purchase itself sets (as the H4 rules did): a first Saddlery attachment is worn when none is; expedition
##     gear is worn at once in its slot; an outfit or a bow is put on at once between waves (during a wave it waits
##     for Wear or Equip); a colour of the look in its slot now is put on.
##   - Where it writes (the v5 save, H5 Stage 2): Save.owned[kind][id] = {"level": n} for mounts, pets, outfits and
##     attachments (a record's other fields are kept), Save.pet_level, Save.saddlery.skills / worn, Save.attach,
##     Save.cat_skin, Save.unlocks and the look's skin, Save.bows / bow, and the Bag. Until the v5 save is live
##     (v5_ready), the kinds that need it (mounts, pets, pet_training, attachments, outfits, mount and pet colours) are
##     refused with "Coming later": the running H4 game never writes two kinds of ownership.
## Used by: the shop windows (H5 Stage 2), the thin rule callers in stations.gd, scripts/companion_shop.gd, the tests.
## Uses: Data (the catalogue and its prices, levels, unlock rules, words, the money), Save, Bag, Events,
##       scripts/market_trade.gd (Bramble's offers and the shared words and checks), main.fight (a wave is on) and
##       main.defences (the tower cap).

const MarketTrade := preload("res://scripts/market_trade.gd")
const SADDLERY := "saddlery"            # the Saddlery's building id: it teaches the skills and caps their levels
const SLOT_OF_KIND := {"mounts": "mount", "pets": "pet"}   # a companion kind -> its slot (Save.<slot>_look)

var kind: String
var id: String
var amount: int
var expected_level: int
var look_id: String


func _init(buy_kind: String, buy_id: String, how_many: int = 1, expected: int = -1, look: String = "") -> void:
	kind = buy_kind
	id = buy_id
	amount = how_many
	expected_level = expected
	look_id = look


# ---------------------------------------------------------------- the command
func can_run(main: Node3D) -> String:
	if kind == "market_goods":
		return String(MarketTrade.quote(MarketTrade.SELLS, id, amount)["reason"])
	if amount != 1:
		return MarketTrade.say("amount", [amount])
	var why: String = ""
	match kind:
		"mounts", "pets", "outfits":
			why = _why_look()
		"pet_training":
			why = _why_training()
		"skills":
			why = _why_skill()
		"attachments":
			why = _why_attachment()
		"colour_unlock":
			why = _why_colour()
		"bows":
			why = _why_bow()
		"defences":
			why = _why_piece(main)
		_:
			why = MarketTrade.say("coming_later")
	if why != "":
		return why
	var next: int = next_level()
	if expected_level >= 0 and expected_level != next:
		return MarketTrade.say("already_owned" if expected_level < next else "coming_later")
	var cost: Dictionary = price()
	if not Data.can_afford(cost):
		return MarketTrade.short_of(cost)
	return ""


func run(main: Node3D) -> bool:
	if can_run(main) != "":
		return false
	if kind == "market_goods":
		return MarketTrade.trade(MarketTrade.SELLS, id, amount)
	var next: int = next_level()
	if not Data.pay(price()):
		return false
	match kind:
		"mounts":
			_set_owned("mounts", id, 1)
			_gained(id)
		"pets":
			_set_owned("pets", id, 1)
			if not _looks_only(Data.shop_entry("pets", id)):
				Save.set("pet_level", maxi(Data.pet_level(), 1))   # the pet comes, at level 1
			_gained(id)
		"pet_training":
			Save.set("pet_level", next)
		"skills":
			if not Save.saddlery.get("skills") is Dictionary:
				Save.saddlery["skills"] = {}
			(Save.saddlery["skills"] as Dictionary)[id] = next
			if next == 1:
				_gained(id)
		"attachments":
			_set_owned("attachments", id, next)
			if next == 1:
				_wear_first(Data.shop_entry("attachments", id))
				_gained(id)
		"outfits":
			_set_owned("outfits", id, 1)
			if not wave_on(main):
				Save.cat_skin = id                          # she puts it on at once between waves
			_gained(id)
		"colour_unlock":
			var slot: String = _look_slot(look_id)
			var key: String = _unlock_key(slot)
			Save.unlocks.append(key)
			if _look_in(slot) == look_id:
				_set_skin(slot, id)                         # the look out now wears it at once
			_gained(key)
		"bows":
			Save.bows[id] = 1
			if not wave_on(main):
				Save.bow = id                               # into the cat's paw at once between waves
			_gained(id)
		"defences":
			Bag.add(id, 1, true)                            # paid for: it always goes in (the room was checked)
	Save.mark_dirty()
	return true


## The level this purchase reaches now: the level owned + 1 (1 for something not owned yet). A button passes it as
## expected_level when it is drawn. Market goods and pieces are always 1.
func next_level() -> int:
	return _level_now() + 1


## What this purchase costs now, its currencies only ({} when it is free or unknown): the same price run pays and the
## confirm or the button shows.
func price() -> Dictionary:
	match kind:
		"market_goods":
			return MarketTrade.quote(MarketTrade.SELLS, id, amount)["price"]
		"mounts", "pets", "outfits":
			return Data.entry_price(kind, id, 1)
		"pet_training":
			return Data.pet_level_price(Data.pet_level() + 1)
		"skills":
			return Data.saddle_price("skills", id, Data.skill_level(id) + 1)
		"attachments":
			return Data.entry_price("attachments", id, Data.owned_level("attachments", id) + 1)
		"colour_unlock":
			var slot: String = _look_slot(look_id)
			return _colour_price(Data.skin(slot, look_id, id)) if slot != "" else {}
		"bows":
			return Data.craft_cost(id)
		"defences":
			return _piece_price()
	return {}


# ---------------------------------------------------------------- shared by the shops
## The v5 save is live (H5 Stage 2): Save has the owned dictionary and the shared pet level. Until then the purchases
## that write them are refused, and the H4 rules in stations.gd stay the only writers.
static func v5_ready() -> bool:
	return Save.get("owned") is Dictionary and Save.get("pet_level") is int


## A wave is on (main.fight: active and in a wave), when the camp's stations wait (stations._locked).
static func wave_on(main: Node3D) -> bool:
	var f: Variant = main.get("fight") if main != null else null
	return f is Object and (f as Object).get("active") == true and (f as Object).get("in_wave") == true


## The building whose shop sells entry e: its "shop" ("stall", "saddlery"), else the building its unlock rule names
## (the Tailor's Nook for an outfit); "" when neither says.
static func shop_of(e: Dictionary) -> String:
	var shop: Variant = e.get("shop")
	if shop is String and shop != "":
		return shop
	var rule: Variant = e.get("unlock")
	if rule is Dictionary:
		var part: Variant = (rule as Dictionary).get("building")
		if part is Array and (part as Array).size() == 2 and (part as Array)[0] is String:
			return String((part as Array)[0])
	return ""


# ---------------------------------------------------------------- why not, kind by kind (money and staleness aside)
## mounts, pets and outfits: one look or outfit, bought once.
func _why_look() -> String:
	if not v5_ready():
		return MarketTrade.say("coming_later")
	var e: Dictionary = Data.shop_entry(kind, id)
	if e.is_empty():
		return MarketTrade.say("coming_later")
	if Data.owned_level(kind, id) >= 1:
		return MarketTrade.say("already_owned")
	var why: String = _entry_reason(e)
	if why != "":
		return why
	if kind == "pets" and _looks_only(e) and Data.pet_level() < 1:
		return MarketTrade.say("pet_first", [_first_pet_name()])
	var looks: bool = kind != "pets" or _looks_only(e)
	var model_ok: bool = Data.cat_skin_buyable(id) if kind == "outfits" \
		else Data.companion_model(String(SLOT_OF_KIND.get(kind, "")), id) != ""
	if not model_ok or not Data.entry_price_ok(kind, id, 1) or not MarketTrade.price_ok(Data.entry_price(kind, id, 1), looks):
		return MarketTrade.say("coming_later")
	return ""


## pet_training: the pet owned, the pet's shop standing, a level left under the top and the Hearthtree, a price.
func _why_training() -> String:
	if not v5_ready():
		return MarketTrade.say("coming_later")
	if Data.pet_level() < 1:
		return MarketTrade.say("pet_first", [_first_pet_name()])
	var why: String = MarketTrade.building_reason(_pet_shop())
	if why != "":
		return why
	var next: int = Data.pet_level() + 1
	if next > Data.pet_top():
		return MarketTrade.say("max")
	if next > Data.pet_level_cap():
		return MarketTrade.say("needs_home", [Data.camp_name(true), next])
	var cost: Dictionary = Data.pet_level_price(next)
	if cost.is_empty() or not MarketTrade.price_ok(cost, false):
		return MarketTrade.say("coming_later")
	return ""


## skills: a known skill, the Saddlery standing, its next level under the top, the Saddlery's level and the Burrows gate.
func _why_skill() -> String:
	if Data.saddle_info("skills", id).is_empty():
		return MarketTrade.say("coming_later")
	var why: String = MarketTrade.building_reason(SADDLERY)
	if why != "":
		return why
	var next: int = Data.skill_level(id) + 1
	match Data.saddle_block("skills", id):
		"max":
			return MarketTrade.say("max")
		"cap":
			return MarketTrade.say("max_for_now")
		"burrows":
			return MarketTrade.say("opens_after_missions", [next])
		"built":
			return MarketTrade.say("coming_later")          # (not reached: building_reason above said why)
	var cost: Dictionary = Data.saddle_price("skills", id, next)
	if cost.is_empty() or not MarketTrade.price_ok(cost, false):
		return MarketTrade.say("coming_later")
	return ""


## attachments: a shown entry, its shop standing, a level left, only the one worn is upgraded, never above its shop's
## level (the Saddlery's; the Market's 1 for gear bought once), the Burrows gate, a well-formed price.
func _why_attachment() -> String:
	if not v5_ready():
		return MarketTrade.say("coming_later")
	var e: Dictionary = Data.shop_entry("attachments", id)
	if e.is_empty():
		return MarketTrade.say("coming_later")
	var why: String = _entry_reason(e)
	if why != "":
		return why
	var lv: int = Data.owned_level("attachments", id)
	var top: int = _top(e)
	if lv >= top:
		return MarketTrade.say("already_owned" if top <= 1 else "max")
	if lv >= 1 and not _wearing(e):
		return MarketTrade.say("receipt_wear_here")      # owned and not worn: its button is Wear
	var next: int = lv + 1
	if next > Data.station_level(shop_of(e)):
		return MarketTrade.say("max_for_now")
	if _needs_burrows(e, next) and not Data.burrows_open():
		return MarketTrade.say("opens_after_missions", [next])
	if not Data.entry_price_ok("attachments", id, next) \
			or not MarketTrade.price_ok(Data.entry_price("attachments", id, next), false):
		return MarketTrade.say("coming_later")
	return ""


## colour_unlock: a known look and an owned one (the guardian: awake), its colour by exact id with a price, not yet
## unlocked, its flag set when it waits for one, and the look's shop standing.
func _why_colour() -> String:
	var slot: String = _look_slot(look_id)
	if slot == "":
		return MarketTrade.say("coming_later")
	if SLOT_OF_KIND.values().has(slot):
		if not v5_ready():
			return MarketTrade.say("coming_later")
		var e: Dictionary = Data.shop_entry(_kind_of_slot(slot), look_id)
		if Data.owned_level(_kind_of_slot(slot), look_id) < 1:
			return MarketTrade.say("pet_first", [String(e.get("short", e.get("name", look_id)))])
		var why: String = MarketTrade.building_reason(shop_of(e))
		if why != "":
			return why
	elif not Data.guardian_awake():
		return MarketTrade.say("coming_later")
	var sk: Dictionary = Data.skin(slot, look_id, id)
	if String(sk.get("id", "")) != id:
		return MarketTrade.say("coming_later")
	if String(sk.get("needs_flag", "")) != "" and not Save.flag(String(sk["needs_flag"])):
		return MarketTrade.say("coming_later")
	if _colour_price(sk).is_empty() or Save.unlocks.has(_unlock_key(slot)):
		return MarketTrade.say("already_owned")          # a free colour needs no unlock
	if not MarketTrade.price_ok(sk, true):
		return MarketTrade.say("coming_later")
	return ""


## bows: H4's _craft gates exactly (a known bow, not hidden, not owned, its unlock rule: the Bow Shop's level and a
## flag such as "hollow_open"), and a price in leaves and timber.
func _why_bow() -> String:
	if not Data.has_bow(id) or Data.bow_hidden(id):
		return MarketTrade.say("coming_later")
	if Save.bows.has(id):
		return MarketTrade.say("already_owned")
	var rule: Variant = Data.bow_info(id).get("unlock", {})
	if not rule is Dictionary:
		return MarketTrade.say("coming_later")
	var missing: Array = Data.unlock_missing(rule)
	if not missing.is_empty():
		return _missing_words(missing[0])
	if not MarketTrade.price_ok(Data.bow_info(id).get("price", {}), false):
		return MarketTrade.say("coming_later")
	return ""


## defences: H4's _buy_piece gates (a piece the Bag holds, room for it, the tower cap) and its price.
func _why_piece(main: Node3D) -> String:
	if Bag.kind_of(id) != "build" or _piece_amount() < 0:
		return MarketTrade.say("coming_later")
	if Bag.room_for(id) <= 0:
		return MarketTrade.say("bag_full")
	var defs: Variant = main.get("defences") if main != null else null
	if not defs is Object or not (defs as Object).has_method("room_for") or (defs as Object).call("room_for", id) != true:
		return MarketTrade.say("max_for_now")
	return ""


# ---------------------------------------------------------------- inside
## The level owned now of what this buys (0 = none): a look, outfit or attachment its owned level, the pet its shared
## level, a skill its learned level, a colour 1 once unlocked, a bow 1 once owned.
func _level_now() -> int:
	match kind:
		"mounts", "pets", "outfits", "attachments":
			return Data.owned_level(kind, id)
		"pet_training":
			return Data.pet_level()
		"skills":
			return Data.skill_level(id)
		"colour_unlock":
			var slot: String = _look_slot(look_id)
			return 1 if slot != "" and Save.unlocks.has(_unlock_key(slot)) else 0
		"bows":
			return 1 if Save.bows.has(id) else 0
	return 0


## Why entry e cannot be sold now: the building that sells it not standing, or the first unmet part of its unlock rule.
func _entry_reason(e: Dictionary) -> String:
	var why: String = MarketTrade.building_reason(shop_of(e))
	if why != "":
		return why
	var rule: Variant = e.get("unlock", {})
	if not rule is Dictionary:
		return MarketTrade.say("coming_later")
	var missing: Array = Data.unlock_missing(rule)
	return "" if missing.is_empty() else _missing_words(missing[0])


## One unmet part of an unlock rule (Data.unlock_missing) in the player's words: a building's level, a number of
## missions won; a flag or an odd part is "Coming later".
func _missing_words(part: Variant) -> String:
	var p: Dictionary = part if part is Dictionary else {}
	match String(p.get("type", "")):
		"building":
			var bid: String = String(p.get("id", ""))
			var nm: String = Data.camp_name(true) if bid == "home" else String(Data.building(bid).get("name", bid))
			return MarketTrade.say("needs_home", [nm, int(p.get("level", 1))])
		"missions_won":
			return MarketTrade.say("needs_missions", [int(p.get("n", 0))])
	return MarketTrade.say("coming_later")


## An entry's levels: 1 plus its "upgrades" (0 without a price).
func _top(e: Dictionary) -> int:
	if not e.has("price"):
		return 0
	var ups: Variant = e.get("upgrades", [])
	return 1 + ((ups as Array).size() if ups is Array else 0)


## Level `level` of entry e waits for the Burrows (its price, or its upgrade, has needs_burrows: true): a gate, never money.
func _needs_burrows(e: Dictionary, level: int) -> bool:
	var raw: Variant = e.get("price") if level == 1 else null
	var ups: Variant = e.get("upgrades", [])
	if level >= 2 and ups is Array and level - 2 < (ups as Array).size():
		raw = (ups as Array)[level - 2]
	return raw is Dictionary and (raw as Dictionary).get("needs_burrows", false) == true


## Attachment e is the one worn in its slot: expedition gear in Save.attach[slot], everything else the Saddlery's one.
func _wearing(e: Dictionary) -> bool:
	if String(e.get("scope", "")) == "expedition":
		return String(Save.attach.get(String(e.get("slot", "")), "")) == id
	return _saddlery_worn() == id


## The Saddlery attachment the mount wears now: Save.saddlery "worn" when that one is a Saddlery attachment it owns, else "".
func _saddlery_worn() -> String:
	var worn: Variant = Save.saddlery.get("worn", "")
	var w: String = worn if worn is String else ""
	if w == "" or Data.saddle_info("attach", w).is_empty() or Data.owned_level("attachments", w) < 1:
		return ""
	return w


## A first attachment goes on: expedition gear in its own slot at once (as H4's _buy_attach); a Saddlery one when the
## mount wears none (as H4's _saddle_buy).
func _wear_first(e: Dictionary) -> void:
	if String(e.get("scope", "")) == "expedition":
		var slot: String = String(e.get("slot", ""))
		if Save.attach.has(slot):
			Save.attach[slot] = id
	elif _saddlery_worn() == "" or _saddlery_worn() == id:
		Save.saddlery["worn"] = id


## Writes Save.owned[kind_id][item_id] = {"level": level}, keeping the record's other fields (the v5 save).
func _set_owned(kind_id: String, item_id: String, level: int) -> void:
	var owned: Dictionary = Save.get("owned")
	if not owned.get(kind_id) is Dictionary:
		owned[kind_id] = {}
	var shelf: Dictionary = owned[kind_id]
	var rec: Dictionary = shelf[item_id] if shelf.get(item_id) is Dictionary else {}
	rec["level"] = level
	shelf[item_id] = rec


## One new thing came: Events.item_gained(kind, what, 1).
func _gained(what: String) -> void:
	Events.item_gained.emit(kind, what, 1)


func _looks_only(e: Dictionary) -> bool:
	return e.get("looks_only", false) == true


## The short name of the first full pet (a pet entry that is not looks-only): "Sprig".
func _first_pet_name() -> String:
	for e: Dictionary in Data.shop_entries("pets"):
		if not _looks_only(e):
			return String(e.get("short", e.get("name", e["id"])))
	return ""


## The building that sells and trains the pet: the first pet entry's shop (the Market); "" when none says.
func _pet_shop() -> String:
	var pets: Array[Dictionary] = Data.shop_entries("pets")
	return shop_of(pets[0]) if not pets.is_empty() else ""


## The companion slot a look id is listed in: "mount" (content/mounts), "pet" (content/pets) or "guardian"
## (balance.json looks.guardian); "" for an unknown id.
func _look_slot(look: String) -> String:
	if look == "":
		return ""
	for k: String in SLOT_OF_KIND:
		if not Data.shop_entry(k, look).is_empty():
			return String(SLOT_OF_KIND[k])
	return "guardian" if String(Data.look("guardian", look).get("id", "")) == look else ""


func _kind_of_slot(slot: String) -> String:
	for k: String in SLOT_OF_KIND:
		if String(SLOT_OF_KIND[k]) == slot:
			return k
	return ""


## The look out in a slot now (Save.mount_look, pet_look, guardian_look).
func _look_in(slot: String) -> String:
	match slot:
		"mount":
			return Save.mount_look
		"pet":
			return Save.pet_look
		"guardian":
			return Save.guardian_look
	return ""


func _set_skin(slot: String, skin_id: String) -> void:
	match slot:
		"mount":
			Save.mount_skin = skin_id
		"pet":
			Save.pet_skin = skin_id
		"guardian":
			Save.guardian_skin = skin_id


## A colour's unlock id in Save.unlocks for this exact look: "skin:<slot>:<look>:<colour>" (as stations._skin_unlock).
func _unlock_key(slot: String) -> String:
	return "skin:%s:%s:%s" % [slot, look_id, id]


## What a colour costs: every currency its entry names above 0 ({"shards": 60} for Gloomlit); {} for a free colour.
func _colour_price(sk: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: String in Data.CURRENCIES:
		var v: Variant = sk.get(k)
		if (v is int or v is float) and float(v) > 0.0:
			out[k] = int(v)
	return out


## A piece's price in whole leaves (balance.json defences.<id>.piece, as H4's _buy_piece paid it); -1 when it is not a
## whole number of 0 or more.
func _piece_amount() -> int:
	if Bag.kind_of(id) != "build":
		return -1
	var v: Variant = Data.defence_info(id).get("piece")
	if v is int and (v as int) >= 0:
		return v
	if v is float and is_finite(v as float) and (v as float) >= 0.0 and (v as float) == floorf(v as float):
		return int(v as float)
	return -1


func _piece_price() -> Dictionary:
	var n: int = _piece_amount()
	return {"leaves": n} if n > 0 else {}
