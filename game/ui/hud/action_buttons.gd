extends RefCounted
## The bottom buttons: the Bag, Ride / Feed / Snack, the defences to place, Place and Done. A part of the HUD (hud.gd).


var hud                                 # the HUD node (untyped on purpose: hud._stage_l and the rest are read at run time)


func _init(h) -> void:
	hud = h


func build() -> void:
	# building: a button per kind of piece the cat has bought; while placing, Place and Done
	hud._build_bar = HBoxContainer.new()
	hud._build_bar.add_theme_constant_override("separation", 10)
	hud._build_bar.alignment = BoxContainer.ALIGNMENT_END
	hud.add_child(hud._build_bar)
	hud._place_bar = HBoxContainer.new()
	hud._place_bar.add_theme_constant_override("separation", 14)
	hud._place_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	hud.add_child(hud._place_bar)
	hud.bag_button = _big_button("Bag", Color(0.56, 0.35, 0.17), open_inventory)
	hud.bag_button.custom_minimum_size = Vector2(116, 84)
	hud.bag_button.add_theme_font_size_override("font_size", 25)
	hud.bag_button.icon = hud.icon("saddlebags")
	hud.bag_button.expand_icon = true
	hud.bag_button.add_theme_constant_override("icon_max_width", 30)
	hud.add_child(hud.bag_button)


func refresh_build() -> void:
	hud._snack_button = null
	for c in hud._build_bar.get_children():
		(c as Control).visible = false
		c.queue_free()
	for c in hud._place_bar.get_children():
		c.queue_free()
	var d = hud.main.defences
	if d == null:
		return
	if d.placing != "":
		hud._place_bar.add_child(_big_button("Place", Color(0.36, 0.66, 0.24), d.place_here))
		hud._place_bar.add_child(_big_button("Done", Color(0.55, 0.5, 0.45), d.stop_placing))
		hud._place_bar.visible = true
		hud._build_bar.visible = false
		return
	hud._place_bar.visible = false
	hud._build_bar.visible = true
	hud._feed_ok = hud.main.can_feed()
	if hud.main.get("area") != null:
		_area_buttons()                              # below ground: the mount's Ride / Feed, and a snack; no building
		return
	if hud.main.mount != null and hud.main.mount.resting > 0.0:
		# knocked out: the Ride button becomes Feed (food from the pantry brings it back), greyed when there is none
		var ok: bool = hud._feed_ok
		var txt: String = ("Feed %s\n%s" % [Data.mount_name(), hud.main.feed_text()]) if ok else ("No food\n%s" % hud.main.feed_text())
		hud._build_bar.add_child(_big_button(txt, Color(0.9, 0.5, 0.55) if ok else Color(0.62, 0.6, 0.55), hud.main.feed_mount, ok))
	elif hud.main.mount != null and not Save.ruined.has("stall"):
		var on: bool = hud.main.player.riding
		hud._build_bar.add_child(_big_button("Walk" if on else "Ride", Color(0.42, 0.6, 0.86) if not on else Color(0.55, 0.5, 0.45), hud.main.toggle_ride))
	for type in ["barricade", "tower", "spikes"]:
		var n := int(Save.items.get(type, 0))
		if n <= 0:
			continue
		var names := {"barricade": "Barricade", "tower": "Tower", "spikes": "Spikes"}
		hud._build_bar.add_child(_big_button("%s ×%d" % [names[type], n], Color(0.85, 0.62, 0.22), d.start_placing.bind(type)))


## The buttons below ground: Ride / Walk or Feed the mount (as in missions), and a snack from the pantry that heals.
func _area_buttons() -> void:
	if hud.main.mount != null and hud.main.mount.resting > 0.0:
		var ok: bool = hud._feed_ok
		var txt := ("Feed %s
%s" % [Data.mount_name(), hud.main.feed_text()]) if ok else ("No food
%s" % hud.main.feed_text())
		hud._build_bar.add_child(_big_button(txt, Color(0.9, 0.5, 0.55) if ok else Color(0.62, 0.6, 0.55), hud.main.feed_mount, ok))
	elif hud.main.mount != null and not Save.ruined.has("stall"):
		var on: bool = hud.main.player.riding
		hud._build_bar.add_child(_big_button("Walk" if on else "Ride", Color(0.42, 0.6, 0.86) if not on else Color(0.55, 0.5, 0.45), hud.main.toggle_ride))
	hud._snack_button = _big_button("", Color(0.55, 0.75, 0.35), _quick_snack)
	hud._snack_button.add_theme_font_size_override("font_size", 25)
	hud._build_bar.add_child(hud._snack_button)
	_refresh_snack()


func _refresh_snack() -> void:
	if hud._snack_button == null or not is_instance_valid(hud._snack_button):
		return
	var sn: Dictionary = hud.main.snack_pick()
	if sn.is_empty():
		var name := "No food" if Save.snack_choice == "auto" else "%s ×0" % Data.item_name(Save.snack_choice, 2).capitalize()
		hud._snack_button.text = "%s\nChoose food" % name
		hud._snack_button.disabled = hud.main.frozen or hud.main.player.hp <= 0
		return
	var item := String(sn["item"])
	var reason: String = hud.main.snack_reason()
	hud._snack_button.text = "%s ×%d\n%s" % [Data.item_name(item, 2).capitalize(), int(Save.pantry.get(item, 0)), "Heal %d" % int(sn["heal"]) if reason == "" else reason]
	hud._snack_button.disabled = reason != ""


func _quick_snack() -> void:
	if hud.main.snack_pick().is_empty():
		open_inventory()
	else:
		hud.main.eat_snack()


func open_inventory() -> void:
	if hud.main.frozen or hud.main.player.hp <= 0 or (hud.main.fishing != null and hud.main.fishing.busy()):
		return
	if hud._card_ring == hud.inventory:
		hud.hide_card()
		return
	hud.main.interact.stop_walk()
	hud.show_card(hud.inventory)


func _big_button(text: String, col: Color, action: Callable, enabled := true) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.custom_minimum_size = Vector2(170, 84)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 30)
	b.add_theme_color_override("font_color", Color(1, 1, 1))
	b.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.05, 0.8))
	b.add_theme_constant_override("outline_size", 6)
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(22)
	sb.border_color = col.darkened(0.35)
	sb.border_width_bottom = 6
	for st in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	var pr := sb.duplicate() as StyleBoxFlat
	pr.bg_color = col.darkened(0.15)
	pr.border_width_bottom = 2
	b.add_theme_stylebox_override("pressed", pr)
	b.add_theme_stylebox_override("disabled", sb)
	b.add_theme_color_override("font_disabled_color", Color(0.95, 0.93, 0.9))
	b.add_to_group("ui_block")
	b.set_meta("label", text)
	b.pressed.connect(func(): action.call())
	return b


func build_buttons() -> Array:
	# for the automated test
	var out: Array = []
	hud.p_card._collect_buttons(hud._build_bar, out)
	hud.p_card._collect_buttons(hud._place_bar, out)
	return out
