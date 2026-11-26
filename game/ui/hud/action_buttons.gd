extends RefCounted
## The bottom buttons (H2, the owner's sketch): row 1 the Bag and the build icon at the left and the potion slot at the
## right (the snack below ground; H3's potions take it), row 2 the defences to place at the left (smaller buttons, the
## owner's answer 3) and Ride / Walk at the right (Feed in its place while the mount is knocked out); Place and Done in
## the middle while placing (the Bag, the build icon and the defences slide out). Every button is made once and kept:
## refresh_build() slides each in or out (slide.gd) and updates its words; hud_layout.gd places them. A part of the
## HUD (hud.gd).

const RideCommand := preload("res://commands/ride.gd")
const Slide := preload("res://ui/hud/slide.gd")
const DEFENCES := ["barricade", "tower", "spikes"]     # the pieces placed from the HUD (until H3 places them from the Bag)
const DEF_NAMES := {"barricade": "Barricade", "tower": "Tower", "spikes": "Spikes"}
const BLUE := Color(0.42, 0.6, 0.86)
const STONE := Color(0.55, 0.5, 0.45)
const PINK := Color(0.9, 0.5, 0.55)
const GREY := Color(0.62, 0.6, 0.55)
const GREEN := Color(0.55, 0.75, 0.35)
const AMBER := Color(0.85, 0.62, 0.22)
const WOOD := Color(0.56, 0.35, 0.17)
const ROW2_FROM := Vector2(0, 12)       # row 2 slides only as far as the gap to row 1 (so it never covers row 1)

var hud                                 # the HUD node (untyped on purpose: hud._stage_l and the rest are read at run time)
var ride_button: Button                 # row 2, right: Ride / Walk
var feed_button: Button                 # ... the same place while the mount is knocked out: Feed <mount> / No food
var def_buttons := {}                   # row 2, left: "barricade", "tower", "spikes" -> its button
var place_button: Button
var done_button: Button


func _init(h) -> void:
	hud = h


func build() -> void:
	# the holders (plain Controls the layout places; they take no touches themselves)
	hud._defence_bar = _holder()
	hud._build_bar = _holder()                           # the right-hand column: Ride / Feed over the potion slot
	hud._place_bar = _holder()
	ride_button = _big_button("Ride", BLUE, _ride_toggle)
	hud._build_bar.add_child(ride_button)
	feed_button = _big_button("Feed", PINK, _feed)
	hud._build_bar.add_child(feed_button)
	hud._snack_button = _big_button("", GREEN, _quick_snack)
	hud._snack_button.add_theme_font_size_override("font_size", 25)
	hud._build_bar.add_child(hud._snack_button)
	for type in DEFENCES:
		var b := _big_button(String(DEF_NAMES[type]), AMBER, _place.bind(type))
		b.custom_minimum_size = Vector2(124, 84)         # hud_layout.gd's DEF (a literal: hud_layout preloads this file)
		b.add_theme_font_size_override("font_size", 23)
		b.add_theme_constant_override("outline_size", 5)
		def_buttons[type] = b
		hud._defence_bar.add_child(b)
	place_button = _big_button("Place", Color(0.36, 0.66, 0.24), _place_here)
	hud._place_bar.add_child(place_button)
	done_button = _big_button("Done", STONE, _stop_placing)
	hud._place_bar.add_child(done_button)
	hud.bag_button = _big_button("Bag", WOOD, open_inventory)
	hud.bag_button.custom_minimum_size = Vector2(116, 84)
	hud.bag_button.add_theme_font_size_override("font_size", 25)
	hud.bag_button.icon = hud.icon("saddlebags")
	hud.bag_button.expand_icon = true
	hud.bag_button.add_theme_constant_override("icon_max_width", 30)
	hud.add_child(hud.bag_button)
	hud._build_icon = _icon_button(hud.p_icons._make_build(), WOOD, open_build, "Build")
	hud.add_child(hud._build_icon)
	for b in _all():
		b.add_to_group("hud_edge")
		Slide.show(b, b == hud.bag_button or b == hud._build_icon, Slide.FROM, true)


## A plain holder the layout places: it never takes a touch (the buttons in it do).
func _holder() -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(c)
	return c


## Every bottom button (shown or not).
func _all() -> Array:
	var out: Array = [ride_button, feed_button, hud._snack_button]
	for type in DEFENCES:
		out.append(def_buttons[type])
	out.append_array([place_button, done_button, hud.bag_button, hud._build_icon])
	return out


## Which buttons show, and their words: called when riding, the mount, placing, the area or the bag change.
func refresh_build() -> void:
	var d = hud.main.defences
	var m = hud.main.mount
	var placing: bool = d != null and d.placing != ""
	var below: bool = hud.main.get("area") != null
	var out: bool = m != null and m.resting > 0.0          # knocked out: the Ride button becomes Feed
	var ride: bool = d != null and not placing and m != null and not out and not Save.ruined.has("stall")
	var feed: bool = d != null and not placing and out
	hud._feed_ok = hud.main.can_feed()
	if ride:
		var on: bool = hud.main.player.riding
		_relabel(ride_button, "Walk" if on else "Ride", "Walk" if on else "Ride", STONE if on else BLUE)
	Slide.show(ride_button, ride, ROW2_FROM)
	if feed:
		var ok: bool = hud._feed_ok
		var txt: String = ("Feed %s\n%s" % [Data.mount_name(), hud.main.feed_text()]) if ok else ("No food\n%s" % hud.main.feed_text())
		_relabel(feed_button, txt, txt, PINK if ok else GREY)
		feed_button.disabled = not ok
	Slide.show(feed_button, feed, ROW2_FROM)
	Slide.show(hud._snack_button, d != null and below and not placing)   # below ground: a snack from the pantry that heals
	_refresh_snack()
	for type in DEFENCES:
		var n := int(Save.items.get(type, 0))
		var shown: bool = d != null and not below and not placing and n > 0
		if shown:
			_relabel(def_buttons[type], "%s\n×%d" % [DEF_NAMES[type], n], "%s ×%d" % [DEF_NAMES[type], n], AMBER)
		Slide.show(def_buttons[type], shown, ROW2_FROM)
	Slide.show(place_button, placing)
	Slide.show(done_button, placing)
	Slide.show(hud.bag_button, not placing)
	Slide.show(hud._build_icon, not placing and not below and hud.main.stations != null)


## A kept button's words (`label` is what the tests look it up by) and colour, changed only when they changed.
func _relabel(b: Button, text: String, label: String, col: Color) -> void:
	if b.text != text:
		b.text = text
	b.set_meta("label", label)
	if not b.has_meta("col") or Color(b.get_meta("col")) != col:
		_style(b, col)


func _ride_toggle() -> void:
	if RideCommand.new().run(hud.main):
		hud.main.stations.refresh()


func _feed() -> void:
	if hud._feed_ok:
		hud.main.feed_mount()


func _place(type: String) -> void:
	if hud.main.defences != null:
		hud.main.defences.start_placing(type)


func _place_here() -> void:
	if hud.main.defences != null:
		hud.main.defences.place_here()


func _stop_placing() -> void:
	if hud.main.defences != null:
		hud.main.defences.stop_placing()


func refresh_feed() -> void:
	if hud.main.mount != null and hud.main.mount.resting > 0.0 and hud.main.can_feed() != hud._feed_ok:
		refresh_build()


func _on_bag_changed() -> void:
	refresh_feed()
	_refresh_snack()


func _refresh_snack() -> void:
	if hud._snack_button == null or not is_instance_valid(hud._snack_button) or not Slide.is_on(hud._snack_button):
		return
	var sn: Dictionary = hud.main.snack_pick()
	var text := ""
	if sn.is_empty():
		var name := "No food" if Save.snack_choice == "auto" else "%s ×0" % Data.item_name(Save.snack_choice, 2).capitalize()
		text = "%s\nChoose food" % name
		hud._snack_button.disabled = hud.main.frozen or hud.main.player.hp <= 0
	else:
		var item := String(sn["item"])
		var reason: String = hud.main.snack_reason()
		text = "%s ×%d\n%s" % [Data.item_name(item, 2).capitalize(), int(Save.pantry.get(item, 0)), "Heal %d" % int(sn["heal"]) if reason == "" else reason]
		hud._snack_button.disabled = reason != ""
	if hud._snack_button.text != text:
		hud._snack_button.text = text


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


## The build icon (the owner's answer 4: until H4's build menu): the Hearthtree's card from anywhere in the camp,
## scrolled to its Buildings shelf. A second tap closes it.
func open_build() -> void:
	if hud.main.frozen or hud.main.player.hp <= 0 or (hud.main.fishing != null and hud.main.fishing.busy()):
		return
	var r = hud.main.stations.rings.get("shop") if hud.main.stations != null else null
	if r == null or not is_instance_valid(r):
		return
	if hud._card_ring == r:
		hud.hide_card()
		return
	hud.main.interact.stop_walk()
	hud.show_card(r)
	await hud.p_card.scroll_to_section("Buildings")


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
	_style(b, col)
	b.add_theme_color_override("font_disabled_color", Color(0.95, 0.93, 0.9))
	b.add_to_group("ui_block")
	b.set_meta("label", text)
	b.pressed.connect(func(): action.call())
	return b


## A button's look in `col`: rounded, a darker lip at the bottom that flattens when pressed.
func _style(b: Button, col: Color) -> void:
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
	b.set_meta("col", col)


## A square button with a picture (the build icon).
func _icon_button(tex: Texture2D, col: Color, action: Callable, label: String) -> Button:
	var b := _big_button("", col, action)
	b.custom_minimum_size = Vector2(84, 84)
	b.set_meta("label", label)
	var pic := TextureRect.new()
	pic.texture = tex
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.set_anchors_preset(Control.PRESET_FULL_RECT)
	pic.offset_left = 14
	pic.offset_top = 11
	pic.offset_right = -14
	pic.offset_bottom = -15
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(pic)
	return b


## The bottom buttons that show now (for the automated test; one sliding out is gone already).
func build_buttons() -> Array:
	var out: Array = []
	for bar in [hud._defence_bar, hud._build_bar, hud._place_bar]:
		for c in (bar as Control).get_children():
			if c is Button and Slide.is_on(c as Control):
				out.append(c)
	return out
