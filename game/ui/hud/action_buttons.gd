extends RefCounted
## The bottom buttons (H2, the owner's sketch): row 1 the Bag and the build icon at the left and the Health Potion button
## at the right, row 2 the defences to place at the left (smaller buttons, the owner's answer 3) and Ride / Walk at the
## right (the Mount Health Potion button in its place while the mount is knocked out); Place and Done in the middle while
## placing (the Bag, the build icon, the defences and the potion buttons slide out). Every button is made once and kept:
## refresh_build() slides each in or out (slide.gd) and updates its words; hud_layout.gd places them. A part of the
## HUD (hud.gd).
## H3 (26 Nov 2026, the owner's Q1 and Q2): Feed and the food snack are gone. The two potion buttons use the potions
## balance.json potions.hud names (Effects.hud_potion): potion_button ("cat") shows while the cat is hurt and the Bag
## holds one; mount_potion_button ("mount") while the mount is knocked out and the Bag holds one; neither while placing
## (Done overlaps row 1's right slot). Each shows the potion's picture and "×N", is greyed when the Use-potion command
## would refuse, and a tap sends that command (a refusal shows as a toast). tick_potions() runs every frame (hud.gd) and
## slides a button only when its wanted state flips.
## H4 (26 Nov 2026): the build icon opens the build menu (hud.windows["build"], ui/windows/build_menu_window.gd), and a
## second tap closes it. A small "!" dot on its top right corner (the owner's Q16 (a): the cue the Hearthtree's marker
## gave before) shows while the menu has a building you can build and pay for now (its pulse()).

const RideCommand := preload("res://commands/ride.gd")
const UsePotion := preload("res://commands/use_potion.gd")
const Slide := preload("res://ui/hud/slide.gd")
const CardParts := preload("res://ui/kit/card_parts.gd")   # H4: the "!" dot (the same as a window tab's and a marker's)
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
var mount_potion_button: Button         # H3: ... the same place while the mount is knocked out: the Mount Health Potion
var potion_button: Button               # H3: row 1, right: the Health Potion while the cat is hurt
var def_buttons := {}                   # row 2, left: "barricade", "tower", "spikes" -> its button
var _cat_id := ""                       # H3: the potion each potion button uses (balance.json potions.hud)
var _mount_id := ""
var _cat_cmd                            # ... and its Use-potion command (made once; it keeps only the id)
var _mount_cmd
var place_button: Button
var done_button: Button
var build_dot: Control                  # H4: the "!" dot on the build icon (meta "build_dot"; refresh_build_dot)


func _init(h) -> void:
	hud = h


func build() -> void:
	# the holders (plain Controls the layout places; they take no touches themselves)
	hud._defence_bar = _holder()
	hud._build_bar = _holder()                           # the right-hand column: Ride / the mount's potion over the cat's
	hud._place_bar = _holder()
	ride_button = _big_button("Ride", BLUE, _ride_toggle)
	hud._build_bar.add_child(ride_button)
	_cat_id = Effects.hud_potion("cat")
	_mount_id = Effects.hud_potion("mount")
	_cat_cmd = UsePotion.new(_cat_id)
	_mount_cmd = UsePotion.new(_mount_id)
	mount_potion_button = _potion_button(_mount_id, PINK)
	hud._build_bar.add_child(mount_potion_button)
	potion_button = _potion_button(_cat_id, GREEN)
	hud._build_bar.add_child(potion_button)
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
	# H4: the build icon's "!" dot, in its top right corner over the picture; it slides with the icon. It follows the
	# build menu's pulse() whenever the leaves, the timber, the save or a building's level change.
	build_dot = CardParts.tab_dot()
	build_dot.remove_meta("tab_dot")                   # not a tab's: the tests find this one by its name or "build_dot"
	build_dot.name = "BuildDot"
	build_dot.set_meta("build_dot", true)
	build_dot.visible = false
	hud._build_icon.add_child(build_dot)
	Save.changed.connect(refresh_build_dot)
	Events.currency_changed.connect(refresh_build_dot.unbind(2))
	Events.building_upgraded.connect(refresh_build_dot.unbind(2))
	for b in _all():
		b.add_to_group("hud_edge")
		Slide.show(b, b == hud.bag_button or b == hud._build_icon, Slide.FROM, true)
	refresh_build_dot()


## A plain holder the layout places: it never takes a touch (the buttons in it do).
func _holder() -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(c)
	return c


## H3: a potion button: the potion's picture and its count ("×2", font 25), never wider than the 170 px slot; a tap
## sends the Use-potion command.
func _potion_button(id: String, col: Color) -> Button:
	var b := _big_button("", col, _use_potion.bind(id))
	b.add_theme_font_size_override("font_size", 25)
	b.set_meta("label", Data.item_name(id, 1) if id != "" else "Potion")
	if id != "":
		b.icon = hud.icon(Bag.icon(id))
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", 52)
	b.add_theme_constant_override("h_separation", 6)
	b.set_meta("potion_key", -1)
	return b


## Every bottom button (shown or not).
func _all() -> Array:
	var out: Array = [ride_button, mount_potion_button, potion_button]
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
	var out: bool = m != null and m.resting > 0.0          # knocked out: the Mount Health Potion takes Ride's place
	var ride: bool = d != null and not placing and m != null and not out and not Save.ruined.has("stall")
	if ride:
		var on: bool = hud.main.player.riding
		_relabel(ride_button, "Walk" if on else "Ride", "Walk" if on else "Ride", STONE if on else BLUE)
	Slide.show(ride_button, ride, ROW2_FROM)
	tick_potions()
	for type in DEFENCES:
		var n := Bag.count(type)
		var shown: bool = d != null and not below and not placing and n > 0
		if shown:
			_relabel(def_buttons[type], "%s\n×%d" % [DEF_NAMES[type], n], "%s ×%d" % [DEF_NAMES[type], n], AMBER)
		Slide.show(def_buttons[type], shown, ROW2_FROM)
	Slide.show(place_button, placing)
	Slide.show(done_button, placing)
	Slide.show(hud.bag_button, not placing)
	Slide.show(hud._build_icon, not placing and not below and hud.main.stations != null)
	refresh_build_dot()


## H4 (the owner's Q16 (a)): the build icon's "!" dot shows while the build menu has a building you can build and pay
## for now (hud.windows["build"].pulse()). From refresh_build, and on Save.changed, Events.currency_changed (leaves and
## timber also change without a save) and Events.building_upgraded (a built building leaves the menu).
func refresh_build_dot() -> void:
	if build_dot == null:
		return
	var menu: Variant = hud.windows.get("build")         # the build menu (ui/windows/build_menu_window.gd)
	var on: bool = menu != null and bool(menu.pulse())
	if build_dot.visible != on:
		build_dot.visible = on


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


## H3: a potion button's tap: the Use-potion command; a refusal shows as a toast.
func _use_potion(id: String) -> void:
	var cmd = UsePotion.new(id)
	if not cmd.run(hud.main):
		var why: String = cmd.can_run(hud.main)
		if why != "":
			hud.toast(why)
	tick_potions()


func _place(type: String) -> void:
	if hud.main.defences != null:
		hud.main.defences.start_placing(type)


func _place_here() -> void:
	if hud.main.defences != null:
		hud.main.defences.place_here()


func _stop_placing() -> void:
	if hud.main.defences != null:
		hud.main.defences.stop_placing()


## The Bag changed (Events.bag_changed): the potions' counts and the defences' counts follow at once.
func _on_bag_changed() -> void:
	refresh_build()


## H3: the two potion buttons (header): which show, their counts, and whether a tap would work now. Every frame from
## hud.gd, and from refresh_build. Cheap: a button is relabelled only when its count or state changed, and it slides
## only when its wanted state flips.
func tick_potions() -> void:
	if potion_button == null:
		return
	var main = hud.main
	var d = main.defences
	var placing: bool = d != null and d.placing != ""
	var p = main.player
	var m = main.mount
	var cat_n := Bag.count(_cat_id) if _cat_id != "" else 0
	var mount_n := Bag.count(_mount_id) if _mount_id != "" else 0
	var cat_want: bool = not placing and cat_n > 0 and p.hp > 0 and p.hp < Data.cat_max_hp()
	var mount_want: bool = not placing and mount_n > 0 and m != null and m.resting > 0.0
	_potion_state(potion_button, _cat_cmd, _cat_id, cat_n, cat_want, GREEN, Slide.FROM)
	_potion_state(mount_potion_button, _mount_cmd, _mount_id, mount_n, mount_want, PINK, ROW2_FROM)


func _potion_state(b: Button, cmd, id: String, n: int, want: bool, col: Color, from: Vector2) -> void:
	if want:
		var ok: bool = cmd.can_run(hud.main) == ""
		var key := n * 2 + (1 if ok else 0)
		if int(b.get_meta("potion_key", -1)) != key:
			b.set_meta("potion_key", key)
			_relabel(b, "×%d" % n, "%s ×%d" % [Data.item_name(id, 1), n], col if ok else GREY)
			b.disabled = not ok
	if want != Slide.is_on(b):
		Slide.show(b, want, from)


func open_inventory() -> void:
	if hud.main.frozen or hud.main.player.hp <= 0 or (hud.main.fishing != null and hud.main.fishing.busy()):
		return
	if hud._card_ring == hud.inventory:
		hud.hide_card()
		return
	hud.main.interact.stop_walk()
	hud.show_card(hud.inventory)


## The build icon: H4, the build menu (hud.windows["build"]) from anywhere in the camp; a second tap closes it (its
## toggle). Not while the game is frozen, the cat is down or fishing. Opening it stops the cat's walk to a marker. In a
## wave the card shows the wave's blank, and while the Hearthtree is in ruins the menu says so (nothing can be built).
func open_build() -> void:
	if hud.main.frozen or hud.main.player.hp <= 0 or (hud.main.fishing != null and hud.main.fishing.busy()):
		return
	var menu: Variant = hud.windows.get("build")         # the build menu (ui/windows/build_menu_window.gd)
	if menu == null:
		return
	if hud._card_ring != menu:
		hud.main.interact.stop_walk()
	menu.toggle()


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
