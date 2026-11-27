extends "res://ui/windows/building_window.gd"
## The Defence Workshop sells stock and specialisations and sets the limit for piece upgrades.

const Buy := preload("res://commands/buy.gd")
const TABS := ["defences", "specialisations"]

var tab: String = TABS[0]
var _next_tab: String = TABS[0]


func _init(owner_hud: CanvasLayer) -> void:
	super(owner_hud, "workshop", "workshop")


func spec() -> Dictionary:
	return tab_spec(tab)


func tab_ids() -> Array:
	return TABS.duplicate()


func select(tab_id: String) -> void:
	if not TABS.has(tab_id):
		return
	tab = tab_id
	if ring() != null and hud.card_ring() == ring():
		hud._card_scroll.scroll_vertical = 0
		hud.refresh_card()


## Ask for a tab on the next visit, or switch to it if the Workshop is already open.
func open_on(tab_id: String) -> void:
	if not TABS.has(tab_id):
		return
	if ring() != null and hud.card_ring() == ring():
		select(tab_id)
	else:
		_next_tab = tab_id


func card_opened() -> void:
	tab = _next_tab
	_next_tab = TABS[0]


func tab_spec(tab_id: String) -> Dictionary:
	var title := String(Data.building(id)["name"])
	var anchor: Vector3 = main.world.station_pos(id)
	if Save.ruined.has(id):
		var ruin := _ruin_card(id, title, anchor)
		ruin["rows"][0]["note"] = st.workshop_reason()
		return ruin
	var showing: String = tab_id if TABS.has(tab_id) else TABS[0]
	var tabs: Array[Dictionary] = []
	var rows: Array = []
	for tid: String in TABS:
		var tab_rows := _rows(tid)
		if tid == showing:
			rows = tab_rows
		var name := _w("tab_" + tid)
		tabs.append({"id": tid, "text": name, "name": name, "selected": tid == showing,
			"enabled": true, "action": select.bind(tid), "dot": _has_purchase(tab_rows)})
	return {"title": title, "sub": _w("home_defences") % _piece_cap(Data.station_level(id)),
		"anchor": anchor, "rows": rows, "tabs": tabs, "footer": upgrade_footer()}


func pulse() -> bool:
	if Save.ruined.has(id):
		return super.pulse()
	for tid: String in TABS:
		if _has_purchase(_rows(tid)):
			return true
	return bool(upgrade_footer().get("pulse", false))


func _has_purchase(rows: Array) -> bool:
	for row: Dictionary in rows:
		if _lights(row):
			return true
	return false


func _rows(tab_id: String) -> Array:
	if tab_id == "specialisations":
		return _specialisations()
	var rows := as_list(_wear_row(id))
	var d: Node3D = main.defences
	for kind: String in Data.defence_ids():
		var entry := Data.defence_info(kind)
		if bool(entry.get("from_bag", false)):
			rows.append(_stock_row(kind, entry))
		elif kind == "barricade":
			var counts := _w("workshop_count_rows") % [int(d.rows_built()), int(d.pads_open_count())]
			rows.append(list_row(String(entry["icon"]), String(entry["name"]),
				counts + "\n" + _w("workshop_build_row"), {}, "", false, Callable(), "", kind))
	return rows


func _stock_row(kind: String, entry: Dictionary) -> Dictionary:
	var d: Node3D = main.defences
	var buy := Buy.new("defences", kind)
	var why := buy.can_run(main)
	var held := Bag.count(kind)
	var placed: int = d.placed_count(kind)
	var note: String
	if kind == "tower":
		note = _w("workshop_count_tower") % [held, placed, held + placed, int(d.tower_cap())]
	else:
		note = _w("workshop_count_spikes") % [held, placed, Bag.room_for(kind)]
	var unlocked: bool = d.unlocked(kind)
	if why != "":
		note += "\n" + why
	return list_row(String(entry["icon"]), String(entry["name"]), note, buy.price() if unlocked else {},
		_w("buy") if unlocked else "", why == "", st._buy_piece.bind(kind), "", kind)


func _specialisations() -> Array:
	var rows: Array = []
	for entry: Dictionary in Data.shop_entries("specialisations"):
		if not Data.unlock_missing(entry.get("unlock", {})).is_empty():
			continue
		var sid := String(entry["id"])
		var lv := Data.specialisation_level(sid)
		var prices: Array = entry.get("upgrades", [])
		var top := 1 + prices.size()
		var badge := _w("level_badge") % [lv, top] if lv > 0 else ""
		var note := String(entry["desc"])
		if lv >= top:
			rows.append(list_row(String(entry["icon"]), String(entry["name"]), note + "\n" + _w("max"),
				{}, "", false, Callable(), badge, sid))
			continue
		var buy := Buy.new("specialisations", sid, 1, lv + 1)
		var price := buy.price()
		var why := buy.can_run(main)
		note += "\n" + (_w("defence_next_level") % buy.next_level())
		if why != "" and Data.can_afford(price):
			note += " · " + why
		rows.append(list_row(String(entry["icon"]), String(entry["name"]), note, price,
			_w("learn" if lv == 0 else "upgrade"), why == "", st.buy_specialisation.bind(sid, lv + 1), badge, sid))
	return rows


func _piece_cap(workshop_level: int) -> int:
	var cap := 0
	for kind: String in Data.defence_ids():
		cap = maxi(cap, int(main.defences.piece_cap(kind, workshop_level)))
	return cap


func gives(level: int) -> Array:
	return [_w("workshop_health") % int(Data.building_hp(id, level)), _w("home_defences") % _piece_cap(level)]


func upgrade_footer() -> Dictionary:
	var lv := Data.station_level(id)
	var top := Data.building_levels(id).size()
	var text := _w("level_of") % [lv, top]
	var why := _upgrade_reason()
	if lv <= 0 or lv >= top:
		return {"text": text, "note": why, "cost": {}, "buttons": [], "pulse": false}
	var note := _w("home_defences") % _piece_cap(lv + 1)
	if why != "":
		note += "\n" + why
	var cost := Data.level_price(id, lv + 1)
	return {"text": text, "note": note, "cost": cost, "pulse": why == "" and Data.can_afford(cost),
		"buttons": [{"label": _w("upgrade"), "tone": "green", "enabled": why == "", "action": ask_upgrade}]}


func _upgrade_reason() -> String:
	return st.workshop_upgrade_reason(Data.station_level(id))


func ask_upgrade() -> void:
	var lv := Data.station_level(id)
	if st.workshop_upgrade_reason(lv) != "":
		return
	var title := _w("upgrade_title") % [String(Data.building(id)["name"]), lv + 1]
	hud.confirm.ask({"title": title, "lines": gives(lv + 1), "cost": Data.level_price(id, lv + 1),
		"on_confirm": st.upgrade_workshop.bind(lv), "back": _reopen_tab.bind(tab),
		"reason": st.workshop_upgrade_reason.bind(lv)})


func _reopen_tab(origin: String) -> void:
	open_on(origin)
	reopen()
