extends RefCounted
## One supplies grid in the shared live dialog, with the current cat and mount beside the selected item.

const PreviewScript := preload("res://scripts/inventory_preview.gd")
const COLUMNS := 6
const GAP := 8

var hud
var main
var key := "inventory"
var selected := "berries"
var preview
var slots := {}
var _entries := {}
var _labels := {}
var _buttons := {}
var _state := ""
var _refresh_t := 0.0


func _init(owner_hud) -> void:
	hud = owner_hud
	main = hud.main


func spec() -> Dictionary:
	_state = _snapshot()
	return {"title": "Bag", "sub": "Gameplay continues", "rows": [{"kind": "inventory"}]}


func tick(delta: float) -> void:
	if hud.card_ring() != self:
		return
	_refresh_t -= delta
	if _refresh_t <= 0.0:
		_refresh_t = 0.15
		refresh()


func refresh() -> void:
	if hud.card_ring() != self:
		return
	if _state != _snapshot():
		hud.refresh_card()
	else:
		_update_live()


func _snapshot() -> String:
	var ids: Array = []
	for entry in _items():
		ids.append(entry["id"])
	return JSON.stringify([selected, ids, main.area != null, Save.meal_ready, Save.meal_on,
		main.player.riding, main.player.model.get_instance_id(), Save.mount_look, Save.mount_skin,
		Save.bow, Data.worn_attach()])


func _items() -> Array:
	var items: Array = []
	for id in Data.b["ingredients"]:
		if Data.food_known(String(id)):
			items.append({"id": id, "kind": "food", "icon": id, "name": Data.item_name(String(id), 2).capitalize()})
	if Data.raids_open() or Save.burrow_keys > 0:
		items.append({"id": "keys", "kind": "resource", "icon": "keys", "name": "Hollow keys"})
	var sat: Dictionary = main.area.satchel() if main.area != null else {}
	for id in Data.MATS:
		if Data.raids_open() or Data.have(id) > 0 or int(sat.get(id, 0)) > 0:
			items.append({"id": id, "kind": "material", "icon": id, "name": Data.mat_name(id).capitalize()})
	for id in ["tower", "spikes"]:
		if int(Save.items.get(id, 0)) > 0:
			items.append({"id": id, "kind": "build", "icon": id, "name": "Acorn towers" if id == "tower" else "Thorn spikes"})
	for id in ["meal_ready", "meal_on"]:
		if String(Save.get(id)) != "":
			items.append({"id": id, "kind": "dish", "icon": "pot", "name": String(Data.recipe(String(Save.get(id))).get("name", "Dish"))})
	return items


func content() -> Control:
	_entries.clear()
	_labels.clear()
	_buttons.clear()
	slots.clear()
	for entry in _items():
		_entries[String(entry["id"])] = entry
	if not _entries.has(selected):
		selected = String(_entries.keys()[0])
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	var wallet := HBoxContainer.new()
	wallet.add_theme_constant_override("separation", 20)
	box.add_child(wallet)
	for id in ["leaves", "timber", "shards"]:
		var pair := HBoxContainer.new()
		pair.add_theme_constant_override("separation", 6)
		pair.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wallet.add_child(pair)
		var picture: TextureRect = hud._btn_icon(hud.icon(id))
		picture.custom_minimum_size = Vector2(30, 30)
		pair.add_child(picture)
		_labels["wallet_" + id] = _text("", 25)
		_labels["wallet_" + id].autowrap_mode = TextServer.AUTOWRAP_OFF
		_labels["wallet_" + id].size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pair.add_child(_labels["wallet_" + id])
	var upper := HBoxContainer.new()
	upper.add_theme_constant_override("separation", 14)
	box.add_child(upper)
	var portrait := PanelContainer.new()
	portrait.add_theme_stylebox_override("panel", _slot_style(false))
	portrait.custom_minimum_size = Vector2(210, 256)
	upper.add_child(portrait)
	preview = SubViewportContainer.new()
	preview.set_script(PreviewScript)
	preview.setup(main)
	portrait.add_child(preview)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 6)
	upper.add_child(details)
	for id in ["name", "amount", "health", "description"]:
		_labels[id] = _text("", 24 if id == "name" else 19)
		details.add_child(_labels[id])
	if _entries[selected]["kind"] == "food":
		var actions := HBoxContainer.new()
		actions.add_theme_constant_override("separation", 8)
		details.add_child(actions)
		_buttons["eat"] = _button("Eat", _eat)
		_buttons["select"] = _button("Quick heal", _choose.bind(selected))
		actions.add_child(_buttons["eat"])
		actions.add_child(_buttons["select"])
		_buttons["auto"] = _button("Use Auto", _choose.bind("auto"))
		details.add_child(_buttons["auto"])
		_labels["reason"] = _text("", 18)
		details.add_child(_labels["reason"])
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", GAP)
	grid.add_theme_constant_override("v_separation", GAP)
	box.add_child(grid)
	var side := floorf((hud._list_w() - GAP * (COLUMNS - 1)) / COLUMNS)
	for entry in _entries.values():
		var slot := _slot(entry, side)
		grid.add_child(_square(slot, side))
		slots[entry["id"]] = slot
	var total := maxi(COLUMNS * 2, int(ceil(float(_entries.size()) / COLUMNS)) * COLUMNS)
	for i in total - _entries.size():
		var empty := Panel.new()
		empty.custom_minimum_size = Vector2(side, side)
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty.add_theme_stylebox_override("panel", _slot_style(false))
		grid.add_child(_square(empty, side))
	_labels["quick"] = _text("", 19)
	box.add_child(_labels["quick"])
	_update_live()
	return box


func _square(control: Control, side: float) -> AspectRatioContainer:
	var square := AspectRatioContainer.new()
	square.ratio = 1.0
	square.stretch_mode = AspectRatioContainer.STRETCH_FIT
	square.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	square.custom_minimum_size = Vector2(side, side)
	square.add_child(control)
	return square


func _text(text: String, size := 21) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", hud.TILE_INK)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _button(text: String, action: Callable) -> Button:
	var button: Button = hud._tile_button({"label": text, "enabled": true, "action": action}, {})
	button.add_theme_font_size_override("font_size", 20)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return button


func _slot_style(chosen: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.96, 0.88, 0.7) if chosen else Color(0.91, 0.83, 0.66)
	style.border_color = Color(0.38, 0.56, 0.18) if chosen else Color(0.7, 0.55, 0.35)
	style.set_border_width_all(4 if chosen else 2)
	style.set_corner_radius_all(6)
	return style


func _slot(entry: Dictionary, side: float) -> Button:
	var id := String(entry["id"])
	var button := Button.new()
	button.custom_minimum_size = Vector2(side, side)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = String(entry["name"])
	button.add_theme_stylebox_override("normal", _slot_style(id == selected))
	button.add_theme_stylebox_override("hover", _slot_style(true))
	button.add_theme_stylebox_override("pressed", _slot_style(true))
	button.pressed.connect(_select.bind(id))
	var picture: TextureRect = hud._btn_icon(hud.icon(entry["icon"]))
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picture.offset_left = 15
	picture.offset_right = -15
	picture.offset_top = 10
	picture.offset_bottom = -24
	button.add_child(picture)
	var count := _text("", 23)
	count.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	count.offset_left = 5
	count.offset_right = -7
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	button.add_child(count)
	_labels["stock_" + id] = count
	if entry["kind"] == "dish":
		var status := _text("Ready" if id == "meal_ready" else "Active", 14)
		status.position = Vector2(5, 3)
		button.add_child(status)
	return button


func _select(id: String) -> void:
	selected = id
	hud.refresh_card()


func _choose(id: String) -> void:
	if id != "auto" and Data.snack(id).is_empty():
		return
	Save.snack_choice = id
	Save.save_game()
	hud.refresh_build()
	hud.refresh_card()


func _eat() -> void:
	if main.eat_snack(selected):
		hud.hide_card()


func _count(entry: Dictionary) -> int:
	var id := String(entry["id"])
	match String(entry["kind"]):
		"food": return int(Save.pantry.get(id, 0))
		"build": return int(Save.items.get(id, 0))
		"dish": return 1
		"material":
			if main.area != null:
				return int(main.area.satchel().get(id, 0))
	return Data.have(id)


func _update_live() -> void:
	if _labels.is_empty():
		return
	for id in ["leaves", "timber", "shards"]:
		_labels["wallet_" + id].text = str(Data.have(id))
	for id in _entries:
		_labels["stock_" + id].text = str(_count(_entries[id]))
	var entry: Dictionary = _entries[selected]
	var kind := String(entry["kind"])
	_labels["name"].text = String(entry["name"])
	_labels["amount"].text = "Owned %d" % _count(entry)
	_labels["health"].text = "Health %d/%d" % [main.player.hp, Data.cat_max_hp()]
	var choice := "Auto" if Save.snack_choice == "auto" else Data.item_name(Save.snack_choice, 2).capitalize()
	_labels["quick"].text = "Quick heal · %s" % choice
	var description := ""
	match kind:
		"food":
			_labels["amount"].text = "%d/%d" % [_count(entry), int(Data.b["cooking"]["pantry_cap"])]
			description = "Heals up to %d in a dungeon.\nUsed for cooking at the pot." % int(Data.snack(selected).get("heal", 0))
			var feed: Dictionary = Data.b["mount"].get("revive_food", {})
			if feed.has(selected):
				description += "\nFeed %d to revive the mount." % int(feed[selected])
			var reason: String = main.snack_reason(selected)
			_buttons["eat"].disabled = reason != ""
			_buttons["select"].disabled = Save.snack_choice == selected
			_buttons["select"].text = "Selected" if Save.snack_choice == selected else "Quick heal"
			_buttons["auto"].disabled = Save.snack_choice == "auto"
			_labels["reason"].text = reason
		"material":
			description = "For mastery, defences and camp upgrades."
			if main.area != null:
				_labels["amount"].text = "At camp %d · This run %d" % [Data.have(selected), _count(entry)]
				var kept: Dictionary = main.area._banked_preview(float(Data.burrow_cfg()["knockout_keep"]))
				description += "\nRoot lift keeps all. After a knock-out, keep %d." % int(kept.get(selected, 0))
		"resource":
			_labels["amount"].text = "%d/%d" % [Save.burrow_keys, int(Data.burrow_cfg()["keys"]["cap"])]
			description = "A bonus boon when you enter a dungeon."
		"build": description = "Ready to place with the camp build controls."
		"dish":
			var dish := Data.recipe(String(Save.get(selected)))
			_labels["amount"].text = "Waiting dish" if selected == "meal_ready" else "Active dish"
			description = String(dish.get("says", "")) + "\n"
			description += "Next chapter or dungeon run." if selected == "meal_ready" else ("This dungeon run." if main.area != null else "This chapter.")
	_labels["description"].text = description
