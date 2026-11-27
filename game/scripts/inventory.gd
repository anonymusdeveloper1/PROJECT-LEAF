extends RefCounted
## The Bag window (H3, 26 Nov 2026; the H3 build map, part 3.9): what the cat carries, opened by the Bag button as a
## card ({"kind": "inventory"} row, card.gd) while the game goes on. At the top the health bars (the cat's, and the
## mount's while riding) with the three currencies; then the 3D view of the cat (and its mount) beside the selected
## thing's details; then the grid.
## The grid: Bag.slots() square slots (24: 4 rows of 6), filled from Bag.stacks() in the Bag's order (food, potions,
## amber, towers and spikes); an empty slot is an empty frame, and more stacks than slots (only things already paid
## for, Bag.add with force) add whole rows. A slot is keyed "<id>#<stack index>" (slots, slot_of). A potion's slot shows
## "2/3" (held / its limit), any other its stack's count. Only things the cat has show: amber only when held (below
## ground the run's satchel, with "At camp N · This run N" in the details, as before).
## The details: the name, the count, what it is for (Bag.desc: a recipe's desc, else balance.json bag.desc) and one
## button: Use when it has effects (Bag.effects: potions and fish; it sends the Use-potion command, closes the Bag when
## it works and shows the reason under the button when not), Place for a tower or spikes (it closes the Bag and starts
## the same placing as the row-2 buttons; below ground "Place it in the camp"). Food and amber have no button.
## It rebuilds on Events.bag_changed and on a selection; every 0.15 s it checks the 3D view's state (riding, the model,
## the bow ...) and the satchel, and updates the bars and the currencies.
## Called by: hud.gd (refresh, tick), card.gd (spec, content), action_buttons.gd (open_inventory shows it), the tests.
## Uses: Bag (every count, name, desc, icon and effect), the Use-potion command (commands/use_potion.gd), defences.gd
## (start_placing), the HUD's helpers (icons, tile buttons).

const PreviewScript := preload("res://scripts/inventory_preview.gd")
const HealthBar := preload("res://ui/hud/health_bars.gd")
const MountScript := preload("res://scripts/mount.gd")
const USE_POTION := "res://commands/use_potion.gd"      # the Use-potion command (H3, loaded when it is used)
const COLUMNS := 6
const GAP := 8

var hud
var main
var key := "inventory"
var selected := ""              # the selected slot's key ("<id>#<index>"; a bare id means its first stack)
var preview
var slots := {}                 # slot key -> its Button (only the slots that hold something)
var _stacks: Array = []         # what the grid shows: Bag.stacks() (below ground, amber as the run's satchel)
var _labels := {}
var _buttons := {}
var _bars := {}
var _state := ""
var _refresh_t := 0.0
var _reason := ""               # why the last Use or Place was refused (under the button until the selection changes,
                                # a Use reason stops being true, or a bag_changed rebuild)
var _rebuild_due := false       # a bag_changed came: one rebuild at the end of the frame


func _init(owner_hud) -> void:
	hud = owner_hud
	main = hud.main
	Events.bag_changed.connect(_on_bag_changed)


func spec() -> Dictionary:
	_stacks = _grid_stacks()
	_fix_selection()                                    # before the snapshot, so the next refresh sees it unchanged
	_state = _snapshot()
	return {"title": "Bag", "sub": "Gameplay continues", "rows": [{"kind": "inventory"}]}


func tick(delta: float) -> void:
	if hud.card_ring() != self:
		_reason = ""
		return
	_refresh_t -= delta
	if _refresh_t <= 0.0:
		_refresh_t = 0.15
		refresh()


## The Bag is open: rebuilt when what it shows changed (the stacks, the selection, the 3D view's state), else only its
## live parts (the bars, the currencies).
func refresh() -> void:
	if hud.card_ring() != self:
		return
	if _reason_gone():
		_reason = ""                                         # the refusal is no longer true: redraw without it
		hud.refresh_card()
		return
	if _state != _snapshot():
		hud.refresh_card()
	else:
		_update_live()


## Select an item by its id, using the same first stack as the Bag grid.
func select_item(id: String) -> void:
	for stack: Dictionary in _grid_stacks():
		if String(stack["id"]) == id:
			_select(_key_of(stack))
			return


## The first stack's slot of an id (null when the Bag holds none or is closed). For the tests.
func slot_of(id: String) -> Control:
	return slots.get("%s#0" % id)


## A refused Use's reason shows only while the command would still refuse for that reason (cheap: it asks only while
## a reason is showing).
func _reason_gone() -> bool:
	if _reason == "":
		return false
	var id := String(_selected_stack().get("id", ""))
	if id == "" or Bag.effects(id).is_empty():
		return false                                         # a Place reason stays until the selection changes
	var cmd: Variant = _use_command(id)
	return cmd != null and String(cmd.can_run(main)) != _reason


func _on_bag_changed() -> void:
	if _rebuild_due:
		return
	_rebuild_due = true
	_rebuild_now.call_deferred()                         # several changes in one frame: one rebuild


func _rebuild_now() -> void:
	_rebuild_due = false
	_reason = ""
	if is_instance_valid(hud) and hud.card_ring() == self:
		hud.refresh_card()


func _snapshot() -> String:
	var shown: Array = []
	for s in _grid_stacks():
		shown.append([s["id"], s["n"]])
	var camp_mats: Array = []
	for id in Data.MATS:
		camp_mats.append(Bag.count(String(id)))
	return JSON.stringify([selected, shown, camp_mats, main.area != null, main.player.riding,
		main.player.model.get_instance_id(), Save.mount_look, Save.mount_skin, Save.bow, Data.worn_attach()])


## The stacks the grid shows: Bag.stacks(), but below ground the materials as the run's satchel (shown while the camp
## or the satchel holds some), in their place in the Bag's order.
func _grid_stacks() -> Array:
	var base: Array = Bag.stacks()
	if main.area == null:
		return base
	var out: Array = []
	var mats_in := false
	for s in base:
		if String(s["kind"]) == "material":
			continue
		if String(s["kind"]) == "build" and not mats_in:
			out.append_array(_run_mats())
			mats_in = true
		out.append(s)
	if not mats_in:
		out.append_array(_run_mats())
	return out


func _run_mats() -> Array:
	var out: Array = []
	var sat: Dictionary = main.area.satchel()
	for m in Data.MATS:
		var id := String(m)
		var have := int(sat.get(id, 0))
		if have <= 0 and Bag.count(id) <= 0:
			continue
		var size := Bag.stack_size(id)
		var index := 0
		while true:
			out.append({"id": id, "kind": "material", "n": mini(have, size), "index": index})
			have -= size
			index += 1
			if have <= 0:
				break
	return out


static func _key_of(s: Dictionary) -> String:
	return "%s#%d" % [String(s["id"]), int(s["index"])]


## The selection stays on its slot; when that stack is gone, on the same thing's first stack; else on the first slot.
func _fix_selection() -> void:
	var first := ""
	var same := ""
	var id := selected.get_slice("#", 0)
	for s in _stacks:
		var k := _key_of(s)
		if k == selected:
			return
		if first == "":
			first = k
		if same == "" and String(s["id"]) == id:
			same = k
	selected = same if same != "" else first


func _selected_stack() -> Dictionary:
	for s in _stacks:
		if _key_of(s) == selected:
			return s
	return {}


func content() -> Control:
	_labels.clear()
	_buttons.clear()
	_bars.clear()
	slots.clear()
	_stacks = _grid_stacks()
	_fix_selection()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	# The health bars (the cat's, and the mount's while riding) with the three currencies packed right under them
	var top := VBoxContainer.new()
	top.add_theme_constant_override("separation", 2)
	box.add_child(top)
	_bars["cat"] = HealthBar.new()
	_bars["cat"].custom_minimum_size = Vector2(0, 22)
	top.add_child(_bars["cat"])
	_bars["mount"] = HealthBar.new()
	_bars["mount"].set_colour(HealthBar.MOUNT)
	_bars["mount"].custom_minimum_size = Vector2(0, 14)
	top.add_child(_bars["mount"])
	var wallet := HBoxContainer.new()
	wallet.add_theme_constant_override("separation", 14)
	top.add_child(wallet)
	for id in ["leaves", "timber", "shards"]:
		var pair := HBoxContainer.new()
		pair.add_theme_constant_override("separation", 6)
		wallet.add_child(pair)
		var picture: TextureRect = hud._btn_icon(hud.icon(id))
		picture.custom_minimum_size = Vector2(30, 30)
		pair.add_child(picture)
		_labels["wallet_" + id] = _text("", 25)
		_labels["wallet_" + id].autowrap_mode = TextServer.AUTOWRAP_OFF
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
	_details(details)
	var grid := GridContainer.new()                     # nested in the box: hud_layout.gd resets a list's own grids
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", GAP)
	grid.add_theme_constant_override("v_separation", GAP)
	box.add_child(grid)
	var side := floorf((hud._list_w() - GAP * (COLUMNS - 1)) / COLUMNS)
	for s in _stacks:
		var slot := _slot(s, side)
		grid.add_child(_square(slot, side))
		slots[_key_of(s)] = slot
	var room := Bag.slots()
	var total := room
	if _stacks.size() > room:                           # more stacks than slots (things already paid for): whole rows
		total = ceili(float(_stacks.size()) / COLUMNS) * COLUMNS
	for i in range(_stacks.size(), total):
		var empty := Panel.new()
		empty.custom_minimum_size = Vector2(side, side)
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty.add_theme_stylebox_override("panel", _slot_style(false))
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if i >= room:
			empty.modulate.a = 0.45                     # past the Bag's slots: no room there
		grid.add_child(_square(empty, side))
	_update_live()
	return box


## The selected thing's name, count, what it is for and its one button ("The Bag is empty" when it holds nothing).
func _details(details: VBoxContainer) -> void:
	var s := _selected_stack()
	if s.is_empty():
		_labels["name"] = _text("The Bag is empty", 24)
		details.add_child(_labels["name"])
		return
	var id := String(s["id"])
	var kind := String(s["kind"])
	var have := Bag.count(id)
	var amount := "Owned %d" % have
	if kind == "potion":
		amount = "Owned %d/%d" % [have, Bag.limit(id)]
	var description := Bag.desc(id)
	if kind == "material" and main.area != null:
		var run_n := int(main.area.satchel().get(id, 0))
		amount = "At camp %d · This run %d" % [have, run_n]
		var kept: Dictionary = main.area._banked_preview(float(Data.burrow_cfg()["knockout_keep"]))
		description += "\nRoot lift keeps all. After a knock-out, keep %d." % int(kept.get(id, 0))
	_labels["name"] = _text(Bag.name_of(id, maxi(1, have)).capitalize(), 24)
	_labels["amount"] = _text(amount, 19)
	_labels["description"] = _text(description, 19)
	for k in ["name", "amount", "description"]:
		details.add_child(_labels[k])
	var why := _reason
	if not Bag.effects(id).is_empty():
		_buttons["use"] = _button("Use", _use, true)
		details.add_child(_buttons["use"])
	elif kind == "build":
		var below: bool = main.area != null
		_buttons["place"] = _button("Place", _place, not below)
		details.add_child(_buttons["place"])
		if below:
			why = "Place it in the camp"
	else:
		return
	_labels["reason"] = _text(why, 18)
	details.add_child(_labels["reason"])


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


func _button(text: String, action: Callable, enabled: bool) -> Button:
	var button: Button = hud._tile_button({"label": text, "enabled": enabled, "action": action}, {})
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


## One stack's slot: its picture (the letter of its name on the plain disc when it has none yet), its count ("2/3" for
## a potion), the chosen frame when selected.
func _slot(s: Dictionary, side: float) -> Button:
	var id := String(s["id"])
	var key_s := _key_of(s)
	var n := int(s["n"])
	var name := Bag.name_of(id, maxi(1, n)).capitalize()
	var button := Button.new()
	button.custom_minimum_size = Vector2(side, side)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = name
	button.set_meta("label", name)
	button.add_theme_stylebox_override("normal", _slot_style(key_s == selected))
	button.add_theme_stylebox_override("hover", _slot_style(true))
	button.add_theme_stylebox_override("pressed", _slot_style(true))
	button.pressed.connect(_select.bind(key_s))
	var icon_id := Bag.icon(id)
	var picture: TextureRect = hud._btn_icon(hud.icon(icon_id))
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picture.offset_left = 15
	picture.offset_right = -15
	picture.offset_top = 10
	picture.offset_bottom = -24
	button.add_child(picture)
	if not hud._icon_known(icon_id):
		var letter := _text(name.substr(0, 1).to_upper(), 30)
		letter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		letter.offset_bottom = -14
		letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		letter.add_theme_color_override("font_color", Color(1.0, 0.97, 0.9))
		letter.add_theme_color_override("font_outline_color", Color(0.36, 0.2, 0.09, 0.9))
		letter.add_theme_constant_override("outline_size", 6)
		button.add_child(letter)
	var count := _text("%d/%d" % [n, Bag.limit(id)] if String(s["kind"]) == "potion" else str(n), 23)
	count.autowrap_mode = TextServer.AUTOWRAP_OFF
	count.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	count.offset_left = 5
	count.offset_right = -7
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	button.add_child(count)
	_labels["stock_" + key_s] = count
	return button


func _select(key_s: String) -> void:
	selected = key_s
	_reason = ""
	if hud.card_ring() == self:
		hud.refresh_card()


## Use: the Use-potion command (the same one the HUD potion buttons send). It closes the Bag when it worked; else the
## reason shows under the button (the card rebuilds after the press and keeps it).
func _use() -> void:
	var id := String(_selected_stack().get("id", ""))
	var cmd: Variant = _use_command(id)
	var why := "Can't be used"
	if cmd != null:
		why = String(cmd.can_run(main))
		if why == "" and bool(cmd.run(main)):
			_reason = ""
			hud.hide_card()
			return
		if why == "":
			why = "Can't be used"
	_reason = why
	if _labels.has("reason"):
		_labels["reason"].text = _reason


## The Use-potion command for id (null while commands/use_potion.gd is not there: Use then says "Can't be used").
func _use_command(id: String) -> Variant:
	if id == "" or not ResourceLoader.exists(USE_POTION):
		return null
	var script := load(USE_POTION) as GDScript
	return script.new(id) if script != null else null


## Place: the Bag closes and the same placing as the row-2 buttons starts (never below ground).
func _place() -> void:
	var id := String(_selected_stack().get("id", ""))
	if main.area != null:
		_reason = "Place it in the camp"
		return
	if id == "" or main.defences == null:
		return
	_reason = ""
	hud.hide_card()
	main.defences.start_placing(id)


func _update_live() -> void:
	if _labels.is_empty():
		return
	for id in ["leaves", "timber", "shards"]:
		_labels["wallet_" + id].text = str(Data.have(id))
	_bars["cat"].set_share(float(main.player.hp) / float(maxi(1, Data.cat_max_hp())))
	var mount: MountScript = main.mount
	var riding: bool = main.player.riding and mount != null and mount.max_hp() > 0
	_bars["mount"].visible = riding
	if riding:
		_bars["mount"].set_share(float(mount.hp) / float(mount.max_hp()))
