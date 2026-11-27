extends RefCounted
## The signpost card's mission rows and their reveal motion. A part of the HUD (hud.gd).


var hud                                 # the HUD node (untyped on purpose: hud._stage_l and the rest are read at run time)


func _init(h) -> void:
	hud = h


## Only visible values belong in the cache; the actions are newly bound Callables on each refresh. H4: also a row's id,
## title, badge, icon, picture, stats and goal tick, the tabs' id, icon and "!" dot, where the tabs sit, and the
## footer's words, price and buttons, so a card with a view_id (the garden's) redraws when only one of those changes.
## The footer's Upgrade stays on while the price is short (Q2 a), so whether each currency of its price can be paid
## now is recorded too: the price line colours each one red or ink when it is drawn (shop_tiles._price_line).
func _signpost_signature(spec: Dictionary) -> String:
	var content: Array = [spec.get("title", ""), spec.get("sub", ""), spec.get("tabs_at", "top")]
	for tab in spec.get("tabs", []):
		content.append([tab.get("text", ""), tab.get("selected", false), tab.get("enabled", true), tab.get("id", ""),
			tab.get("icon", ""), tab.get("dot", false)])
	for row in spec.get("rows", []):
		var visible_values := {}
		for key in ["kind", "text", "note", "label", "enabled", "cost", "mission_index", "mission_name", "completed",
				"id", "title", "badge", "icon", "picture", "stats", "small", "done"]:
			if row.has(key):
				visible_values[key] = row[key]
		content.append(visible_values)
	var fv: Variant = spec.get("footer", {})
	var foot: Dictionary = fv if fv is Dictionary else {}
	if not foot.is_empty():
		var buttons: Array = []
		for b: Variant in foot.get("buttons", []):
			if b is Dictionary:
				var bd: Dictionary = b
				buttons.append([bd.get("label", ""), bd.get("enabled", false), bd.get("tone", "green")])
		var cv: Variant = foot.get("cost", {})
		var fc: Dictionary = cv if cv is Dictionary else {}
		var paid: Array = []                            # each currency of the price: can it be paid now (red or ink)
		for k: String in Data.CURRENCIES:
			if int(fc.get(k, 0)) > 0:
				paid.append(Data.have(k) >= int(fc[k]))
		content.append([foot.get("text", ""), foot.get("note", ""), fc, buttons, paid])
	return JSON.stringify(content)


func _signpost_panel(ready := false, completed := false) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_PASS    # card backgrounds must pass finger drags up to the scroll container
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.97, 0.87) if ready else Color(0.94, 0.9, 0.8)
	if completed:
		style.bg_color = Color(0.93, 0.96, 0.85)
	style.border_color = Color(0.6, 0.69, 0.35) if ready or completed else Color(0.79, 0.73, 0.61)
	style.set_border_width_all(2)
	style.set_corner_radius_all(20)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	return panel


## A quiet number badge, name and status, with one thumb-sized action at the right.
func _mission_row(row: Dictionary) -> Control:
	var ready := bool(row.get("enabled", false))
	var completed := bool(row.get("completed", false))
	var panel := _signpost_panel(ready, completed)
	panel.custom_minimum_size.y = 120
	panel.set_meta("mission_index", int(row["mission_index"]))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 18)
	panel.add_child(line)
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.custom_minimum_size = Vector2(60, 60)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(0.35, 0.53, 0.27) if completed else (Color(0.71, 0.47, 0.18) if ready else Color(0.8, 0.75, 0.65))
	badge_style.set_corner_radius_all(16)
	badge.add_theme_stylebox_override("panel", badge_style)
	line.add_child(badge)
	var number := Label.new()
	number.text = str(int(row["mission_index"]) + 1)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	number.add_theme_font_override("font", hud.p_tiles._bold())
	number.add_theme_font_size_override("font_size", 28)
	number.add_theme_color_override("font_color", Color(1.0, 0.98, 0.89) if ready or completed else hud.TILE_INK)
	badge.add_child(number)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	words.add_theme_constant_override("separation", 8)
	line.add_child(words)
	var name_label := Label.new()
	name_label.text = String(row.get("mission_name", ""))
	name_label.add_theme_font_override("font", hud.p_tiles._bold())
	name_label.add_theme_font_size_override("font_size", 25)
	name_label.add_theme_color_override("font_color", hud.TILE_INK)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(name_label)
	var status := Label.new()
	status.text = String(row.get("note", ""))
	status.add_theme_font_size_override("font_size", 19)
	status.add_theme_color_override("font_color", Color(0.31, 0.46, 0.22) if completed else Color(0.45, 0.38, 0.29))
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(status)
	var button: Button = hud.p_card._cost_button(row)
	button.custom_minimum_size = Vector2(130, 66)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(button)
	_signpost_button_motion(button)
	return panel


## Fade and settle without animating positions owned by the containers.
func _reveal_signpost_control(control: Control, delay: float) -> void:
	control.modulate.a = 0.0
	control.scale = Vector2.ONE * 0.98
	_start_signpost_reveal.call_deferred(control, delay)


## The control is passed untyped: a card drawn twice in one frame frees the first one's rows before this deferred call
## runs, and a typed argument would fail on the freed object instead of reaching the check below.
func _start_signpost_reveal(target: Variant, delay: float) -> void:
	if not is_instance_valid(target) or not target is Control or (target as Control).is_queued_for_deletion():
		return
	var control := target as Control
	control.pivot_offset = control.size * 0.5
	var tween := control.create_tween().set_parallel()
	tween.tween_property(control, "modulate:a", 1.0, 0.24).set_delay(delay)
	tween.tween_property(control, "scale", Vector2.ONE, 0.28).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _signpost_button_motion(button: Button) -> void:
	button.mouse_filter = Control.MOUSE_FILTER_PASS   # scrolling also starts over Start, Replay and locked buttons
	if String(button.get_meta("label", "")) == "Defend Camp":
		button.custom_minimum_size.x = 190
	button.button_down.connect(_press_signpost_button.bind(button, true))
	button.button_up.connect(_press_signpost_button.bind(button, false))
	button.mouse_exited.connect(_press_signpost_button.bind(button, false))


func _press_signpost_button(button: Button, down: bool) -> void:
	if not is_instance_valid(button) or button.is_queued_for_deletion() or button.disabled:
		return
	if button.has_meta("press_tween"):
		var previous: Tween = button.get_meta("press_tween")
		if previous.is_valid():
			previous.kill()
	button.pivot_offset = button.size * 0.5
	var tween := button.create_tween()
	button.set_meta("press_tween", tween)
	tween.tween_property(button, "scale", Vector2.ONE * (0.965 if down else 1.0), 0.07 if down else 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
