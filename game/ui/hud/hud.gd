extends CanvasLayer
## Everything drawn on top of the game. There are no menus. The screen (H2, 26 Nov 2026: the owner's sketch and answers;
## docs/PHASE_H_PLAN.md H2; ui/hud/hud_layout.gd has every place):
##   the top      top-left the three currencies, small, no strip behind them (the satchel after them below ground), the
##                endgame-save label under them and (H3, Q22) the running Damage and Speed Potions ("Damage +25% · 24 s",
##                the old dish line); top-right the Settings gear;
##                top-centre the raid bar (no words, no numbers), the campfire's thin bar under it in a fight, and the
##                words line (the next wave's
##                roads, the wave, the Gloom, the Gloomwood's level). Under them the boss bar, then the banners (a
##                compact strip), the toast and the status or hiding line, never into the middle third.
##   the bottom   row 1: the Bag and the build icon (the build menu) at the left, the Health Potion (while
##                the cat is hurt and the Bag holds one) at the right; row 2: the defences to place at the left, Ride /
##                Walk (or, while the mount is knocked out, the Mount Health Potion) at the right; Place and Done while
##                placing. The buttons slide and fade in and out (slide.gd). The tip and the hint just above them.
##   the middle   nothing but the health bars over the cat (lifebar.gd) and the pointer arrow: the cat stands there.
##   a card       (19 Nov 2026, the user's call) the card of a thing the player tapped (marker.gd, interact.gd) opens as
##                a dialog in the middle of the screen over a soft dim of the game: a header with its name and a round
##                close button, its rows below (scrolling inside when long). The X, a tap on the dim, Android's back
##                button or Escape close it. Inside (20 Nov 2026, the user: "like a whole shop store"; Phase G2) the
##                things to buy are shop tiles in a grid (rows {"kind": "item"}, 2 a row on a phone) under small shelf
##                headings ({"kind": "section"}); the plain rows ({text, note, cost, label, ...}) draw as before. H3: a
##                row {"kind": "window", "window": w} holds a window (the garden's, the pot's: ui/windows/) that builds
##                its own contents, ticks while it shows and hears when a visit opens and closes (card.gd). H4: each
##                building's card is its own window (ui/windows/, made here: hud.windows, plugged into the markers by
##                stations.use_windows); the confirm window (hud.confirm, ui/kit/confirm_window.gd) asks before a
##                building's Upgrade.
## The phone's safe area (status bar, camera hole, gesture bar) is kept clear (--safe-top= / --safe-bottom= try it on a
## PC, in HUD pixels).
## (H2, part 1: the code is split into the parts in ui/hud/; this node keeps the shared nodes and the calls other scripts make.)

const LifebarScript := preload("res://ui/hud/lifebar.gd")
const ArrowsScript := preload("res://ui/hud/threat_arrows.gd")
const InventoryScript := preload("res://scripts/inventory.gd")
const SettingsWindowScript := preload("res://ui/hud/settings_window.gd")
const GardenWindowScript := preload("res://ui/windows/garden_window.gd")
const CookingWindowScript := preload("res://ui/windows/cooking_window.gd")
const ConfirmWindowScript := preload("res://ui/kit/confirm_window.gd")
const WindowList := preload("res://ui/windows/window_list.gd")
const ROW_H := 72.0                     # the top bar's height with only the gear (hud_layout.gd GEAR_H)
const DIALOG_W := 0.9
const TILE_INK := Color(0.25, 0.16, 0.08)
const LayoutScript := preload("res://ui/hud/hud_layout.gd")
const TopBarScript := preload("res://ui/hud/top_bar.gd")
const FightBarScript := preload("res://ui/hud/fight_bar.gd")
const MessagesScript := preload("res://ui/hud/messages.gd")
const ActionButtonsScript := preload("res://ui/hud/action_buttons.gd")
const CardScript := preload("res://ui/hud/card.gd")
const CardSignpostScript := preload("res://ui/hud/card_signpost.gd")
const ShopTilesScript := preload("res://ui/hud/shop_tiles.gd")
const HudIconsScript := preload("res://ui/hud/hud_icons.gd")

var main
var boss = null
var _leaf_tex: ImageTexture
var _log_tex: ImageTexture
var _leaves_l: Label
var _timber_l: Label
var _timber_box: HBoxContainer
var _shard_tex: ImageTexture            # Phase D: Gloom shards
var _shard_l: Label
var _shard_box: HBoxContainer
var _shown_shards := 0
var shards_held := 0                    # shards banked but still flying to the cat (the shower): not counted up yet
var _held_t := 0.0
var _meal_l: Label                     # the old dish line (Phase C); H3 (Q22): the running potions, hidden when none
var _eg_l: Label                       # "Endgame test save" (the debug endgame start)
var _res: HBoxContainer                # the top bar's left: leaves, timber, shards, the satchel below ground
var _line2: HBoxContainer              # ... its second line: the endgame label, the running potions
var _top: Panel                        # H2: no strip behind the top bar any more (null; the name stays for the tests)
var _gear: Button                      # H2: the Settings gear at the top-right
var _fire_bar: Control                 # H2: the campfire's thin bar under the raid bar (in a fight)
var _lifebar: Control                  # the health bars over the cat (and its mount)
var _stage_l: Label
var _gate_bar: Control
var _boss_bar: Control
var _banner: PanelContainer
var _banner_t: Label
var _banner_s: Label
var _banner_tw: Tween
var _toast: Label
var _toast_tw: Tween
var _tip: Label
var _hint: Label
var _overlay: Control
var _card: PanelContainer              # the open dialog (null when none)
var _card_key := ""
var _card_anchor := Vector3.ZERO
var _card_ring = null
var _card_in := 0.0                    # the dialog popping in: 0 = small and clear, 1 = open
var _dim: ColorRect                    # the soft dark see-through cover over the game behind a dialog
var _dim_down := false                 # a touch went down on the dim (a tap on it closes the dialog)
var _dim_from := Vector2.ZERO
var _card_head: Control                # the dialog's header strip (its name, its line, the X)
var _card_scroll: ScrollContainer      # the dialog's rows, scrolling inside when long
var _card_list: VBoxContainer
var _card_title: Label
var _card_sub: Label
var _card_body: Control
var _card_tabs: HBoxContainer
var _card_nav: MarginContainer
var _card_view_id := ""
var _card_render_signature := ""
var _close_btn: Button                 # the round X
var _quit_back := true                 # what Android's back button did before the dialog took it
var _tip_ring = null
var _tip_time := 0.0
var _shown_leaves := 0
var _gate_flash := 0.0
var _build_bar: Control                # the bottom-right column: Ride / Walk or the mount's potion over the cat's
var _defence_bar: Control              # H2: the defences to place, bottom-left above the Bag
var _build_icon: Button                # H2: the build icon next to the Bag (H4: the build menu)
var _bottom_h := 100.0                 # how tall the bottom rows that show are, up from the gesture bar (the edge arrows)
var inventory
var settings                           # H2: the Settings window (the gear), opened through the card
var garden_window                      # H3: the garden's window (ui/windows/garden_window.gd), a {"kind": "window"} row
var cooking_window                     # H3: the cooking pot's window (ui/windows/cooking_window.gd)
## H4: the building windows (ui/windows/window_list.gd): marker id -> its window, plus the build menu under "build";
## stations.use_windows plugs them into the markers.
var windows: Dictionary = {}
var confirm                            # H4: the confirm window (ui/kit/confirm_window.gd), opened through the card
var _card_window = null                # H3: the window in the open card's rows (its tick runs every frame); null when none
var _card_window_open = null           # H3: the window whose opened() ran in this card's visit (card.gd); null when none
var bag_button: Button
var _hide_l: Label
var _place_bar: Control                # Place and Done while placing
var status := ""                        # a line under the top bar (rebuilding the campfire...)
var _point_pos := Vector3.ZERO          # point_at: an arrow to a spot in the world (a raid's trail), for _point_t s
var _point_t := 0.0
var _raid_attacking := false
var _progress_wave := -1                # the fight's wave number at the last fight_progress (a new number = a new attack)
var _bar_key := ""                      # what the raid bar last drew (it redraws only when this changes)
var _fade: ColorRect                    # Phase E: the full-screen fade between the camp and the Burrows (its own layer)
var _satchel_box: HBoxContainer         # Phase E: the satchel below ground, in the top bar after the leaves
var _safe := Vector2.ZERO               # the phone's safe insets in HUD pixels: top, bottom
var _top_h := ROW_H                     # how tall the top bar is now (with its second line or without)
var _zone_end := 0.0                    # the bottom of everything at the top (the bar, the boss bar, a banner, ...)
# the parts that hold the HUD's code (each has a back-reference to this node)
var p_layout: LayoutScript
var p_top: TopBarScript
var p_fight: FightBarScript
var p_msgs: MessagesScript
var p_actions: ActionButtonsScript
var p_card: CardScript
var p_sign: CardSignpostScript
var p_tiles: ShopTilesScript
var p_icons: HudIconsScript


func build(m) -> void:
	p_layout = LayoutScript.new(self)
	p_top = TopBarScript.new(self)
	p_fight = FightBarScript.new(self)
	p_msgs = MessagesScript.new(self)
	p_actions = ActionButtonsScript.new(self)
	p_card = CardScript.new(self)
	p_sign = CardSignpostScript.new(self)
	p_tiles = ShopTilesScript.new(self)
	p_icons = HudIconsScript.new(self)
	main = m
	inventory = InventoryScript.new(self)
	settings = SettingsWindowScript.new(self)
	garden_window = GardenWindowScript.new(self)
	cooking_window = CookingWindowScript.new(self)
	confirm = ConfirmWindowScript.new(self)
	windows = WindowList.make_all(self)
	_leaf_tex = p_icons._make_leaf()
	_log_tex = p_icons._make_log()
	_shard_tex = p_icons._make_shard()
	p_msgs.build_overlay()
	p_top.build()
	_lifebar = Control.new()
	_lifebar.set_script(LifebarScript)
	_lifebar.main = main
	add_child(_lifebar)
	move_child(_lifebar, 0)                         # under the cards and banners
	var arrows := Control.new()                     # where an attack comes from: arrows at the screen's edge
	arrows.set_script(ArrowsScript)
	arrows.main = main
	add_child(arrows)
	p_fight.build()
	p_msgs.build()
	p_actions.build()
	p_msgs.build_fade()
	get_viewport().size_changed.connect(p_layout._layout)
	Save.changed.connect(_on_save_changed)
	Events.currency_changed.connect(p_top._on_currency_changed)
	Events.save_loaded.connect(_on_save_loaded)
	Events.bag_changed.connect(p_actions._on_bag_changed)
	Events.wave_started.connect(_on_wave_started)
	Events.wave_ended.connect(_on_wave_ended, CONNECT_DEFERRED)
	Events.raid_started.connect(_on_raid_started)
	Events.raid_ended.connect(_on_raid_ended, CONNECT_DEFERRED)
	Events.mission_won.connect(refresh.unbind(1))
	Events.riding_changed.connect(_on_riding_changed)
	Events.mount_down_changed.connect(refresh_build.unbind(1))
	Events.placing_changed.connect(refresh_build.unbind(1))
	Events.area_changed.connect(_on_area_changed)
	Events.boss_changed.connect(_on_boss_changed)
	Events.campfire_hit.connect(gate_hit)
	Events.fight_progress.connect(_on_fight_progress)
	p_layout._layout()
	refresh()
	main.stations.use_windows(windows)              # H4: each building's marker opens its window (and asks it for its "!")


func refresh() -> void:
	var below: bool = main.get("area") != null
	p_top.refresh(below)
	refresh_hp()
	p_fight.refresh(below)
	p_top._refresh_satchel(below)
	p_fight.refresh_bar()


## The bars over the cat follow its health by themselves (lifebar.gd); kept for the callers.
func refresh_hp() -> void:
	if _lifebar:
		_lifebar.queue_redraw()


func _on_save_changed() -> void:
	refresh()
	if _card != null and _card_ring != null:
		if _card_ring == inventory:
			inventory.refresh()
		else:
			p_card._fill_card(_spec(_card_ring))              # through _spec: a card stays blank while a wave is on


func _on_save_loaded() -> void:
	_on_save_changed()
	refresh_build()


func _on_wave_started(_n: int) -> void:
	refresh()
	refresh_card()


func _on_wave_ended(_n: int, held: bool) -> void:
	# The next wave's roads are planned after wave_ended is sent.
	if held and not main.fight.in_wave:
		p_fight.progress_done = p_fight.progress_total
	refresh()
	refresh_card()


func _on_raid_started(_spec: Dictionary) -> void:
	_raid_attacking = false
	_progress_wave = -1
	p_fight.progress_done = 0
	p_fight.progress_total = 0
	refresh()
	refresh_card()


func _on_raid_ended(_won: bool, _perfect: bool) -> void:
	# The raid announces its result before the fight returns to camp.
	_raid_attacking = false
	_progress_wave = -1
	p_fight.progress_done = 0
	p_fight.progress_total = 0
	refresh()
	refresh_card()


func _on_riding_changed(_on: bool) -> void:
	refresh_build()
	refresh_card()


func _on_area_changed(_inside: bool) -> void:
	refresh()
	refresh_build()


func _on_boss_changed(new_boss: Node) -> void:
	boss = new_boss


func _on_fight_progress(done: int, total: int) -> void:
	p_fight.progress_done = done
	p_fight.progress_total = total
	_gate_bar.queue_redraw()                    # the raid bar fills as enemies are beaten
	if main.fight.wave != _progress_wave:
		_progress_wave = main.fight.wave
		_raid_attacking = false                 # a new attack: the first message refreshes the bar again
	# Random Raids start the attack without sending wave_started.
	if main.fight.mode == "raid" and not _raid_attacking:
		_raid_attacking = true
		refresh()
		refresh_card()


func _process(delta: float) -> void:
	inventory.tick(delta)
	if _card_window != null:
		_card_window.tick(delta)                    # H3: the open card's window (the garden's times, the pot's bar)
	p_actions.tick_potions()                        # H3: the potion buttons follow the cat's health and the Bag
	if _card_ring == inventory and main.player.hp <= 0:
		hide_card()
	p_top.tick(delta)
	_gate_flash = maxf(0.0, _gate_flash - delta)
	_point_t = maxf(0.0, _point_t - delta)
	p_fight.tick_stage()
	p_msgs.tick_status()
	p_msgs.tick_toast()
	p_fight.tick_bar()
	p_msgs.tick_tip(delta)
	p_layout._place_all()
	if _card != null:
		p_card._place_card()
	_overlay.queue_redraw()


## Android's back button closes an open dialog (quit_on_go_back is off while one is open).
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and _card != null:
		hide_card()


## Escape (on a PC; or a back key sent as a key) closes an open dialog.
func _unhandled_key_input(event: InputEvent) -> void:
	if _card != null and event is InputEventKey and event.pressed and not event.echo \
			and ((event as InputEventKey).keycode == KEY_ESCAPE or (event as InputEventKey).keycode == KEY_BACK):
		hide_card()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- forwarders: what other scripts and the tests call

func line_y() -> float:
	return p_layout.line_y()


func hide_hint() -> void:
	p_msgs.hide_hint()


func banner(title: String, color := Color(1, 1, 1), sub := "", big := false) -> void:
	p_msgs.banner(title, color, sub, big)


func fade(alpha: float, secs: float) -> void:
	await p_msgs.fade(alpha, secs)


func banner_busy() -> bool:
	return p_msgs.banner_busy()


func banner_later(delay: float, title: String, color := Color(1, 1, 1), sub := "", big := false) -> void:
	p_msgs.banner_later(delay, title, color, sub, big)


func toast(text: String) -> void:
	p_msgs.toast(text)


func tip_after_delay(delay: float, text: String, ring) -> void:
	p_msgs.tip_after_delay(delay, text, ring)


func tip_after(text: String, ring) -> void:
	p_msgs.tip_after(text, ring)


func tip(text: String, ring) -> void:
	p_msgs.tip(text, ring)


func gate_hit() -> void:
	p_fight.gate_hit()


func point_at(world_pos: Vector3, secs: float) -> void:
	p_msgs.point_at(world_pos, secs)


func refresh_build() -> void:
	p_actions.refresh_build()


func open_settings() -> void:
	settings.toggle()


func open_inventory() -> void:
	p_actions.open_inventory()


func build_buttons() -> Array:
	return p_actions.build_buttons()


func show_card(ring) -> void:
	p_card.show_card(ring)


func hide_card() -> void:
	p_card.hide_card()


func drop_tip_ring() -> void:
	p_msgs.drop_tip_ring()


func card_open() -> bool:
	return p_card.card_open()


func card_ring():
	return p_card.card_ring()


func tip_ring():
	return p_msgs.tip_ring()


func refresh_card() -> void:
	p_card.refresh_card()


func card_title() -> String:
	return p_card.card_title()


func scroll_card_to(needle: String) -> void:
	await p_card.scroll_card_to(needle)


func _spec(ring) -> Dictionary:
	return p_card._spec(ring)


func card_buttons() -> Array:
	return p_card.card_buttons()


func close_button() -> Button:
	return p_card.close_button()


func _btn_icon(tex: Texture2D) -> TextureRect:
	return p_card._btn_icon(tex)


func _list_w() -> float:
	return p_tiles._list_w()


func _grid_cols() -> int:
	return p_tiles._grid_cols()


func _tile_button(it: Dictionary, cost: Dictionary) -> Button:
	return p_tiles._tile_button(it, cost)


func _ui_style(k: String) -> StyleBoxFlat:
	return p_tiles._ui_style(k)


func icon(k) -> Texture2D:
	return p_icons.icon(k)


func _icon_known(k) -> bool:
	return p_icons._icon_known(k)
