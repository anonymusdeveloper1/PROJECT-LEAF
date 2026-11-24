extends Node
## Supplies through the normal Bag, garden, pot, Market and dungeon paths. Uses the test save only.

var t
var main


func run() -> void:
	var hud = main.hud
	main.player.invincible = true
	await t._tap_at(hud.bag_button.get_global_rect().get_center())
	await t._wait(0.3)
	t._expect("Bag opens through the HUD button", hud.card_ring() == hud.inventory)
	t._expect("opening Bag keeps gameplay live", not main.frozen and not get_tree().paused and Engine.time_scale == 1.0)
	t._expect("fresh food counts and dungeon-use reason are visible", _words().contains("0/20") and _words().contains("Eat in a dungeon"))
	t._expect("Bag has one supplies view", not _words().contains("Resources") and not _words().contains("Use Auto\nFood"))
	t._expect("Bag shows the current cat on foot", hud.inventory.preview.cat_copy != null and hud.inventory.preview.mount_copy == null)
	await t._tap_outside()
	t._expect("outside tap closes Bag", not hud.card_open())
	hud.open_inventory()
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	hud._unhandled_key_input(escape)
	t._expect("Escape closes Bag", not hud.card_open())
	hud.open_inventory()
	hud._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	t._expect("Android Back closes Bag", not hud.card_open())
	hud.open_inventory()
	await t._at_ring(main.stations.rings["shop"])
	t._expect("a building replaces the Bag dialog", hud.card_ring() == main.stations.rings["shop"])
	hud.open_inventory()
	t._expect("Bag replaces the building dialog", hud.card_ring() == hud.inventory)
	hud.hide_card()
	await _camp()
	await _dungeon()
	_old_save()
	await t._wait(0.2)
	t._expect("Bag button fits the safe area", hud.bag_button.get_global_rect().end.y <= hud.get_viewport().get_visible_rect().size.y - hud._safe.y)
	t._expect("Bag and action buttons have separate space", hud.bag_button.get_global_rect().end.x <= hud._build_bar.position.x)


func _words() -> String:
	return _text_in(main.hud._card)


func _text_in(node: Node) -> String:
	if node == null or (node is Control and not node.visible):
		return ""
	var text := ""
	if node is Label or node is Button:
		text = node.text + "\n"
	for child in node.get_children():
		text += _text_in(child)
	return text


func _camp() -> void:
	Save._endgame_seed()
	Save.fish_log["carp"] = 1
	Save.stations["stone"] = 1
	main.raids.manual = true
	main.on_camp_grown()
	main.player.hp = Data.cat_max_hp()
	await t._wait(0.4)
	Save.pantry = {"berries": 5, "herbs": 4, "honey": 3, "fish": 2, "goldfish": 1}
	var crop: Dictionary = Data.b["garden"]["crops"][0]
	Save.garden[0] = {"crop": String(crop["id"]), "grow": int(crop["grow"]), "wet": 0}
	var gain := int(crop["yield"]) + int(Data.pick("garden", "extra_by_level", Data.garden_level()))
	var expected := int(Save.pantry["berries"]) + gain
	main.stations._garden_pick()
	t._expect("harvest adds the expected food and reports the total", int(Save.pantry["berries"]) == expected and main.hud._toast.text.contains("now %d/20" % expected))
	Save.pantry["berries"] = int(Data.b["cooking"]["pantry_cap"])
	Save.garden[0] = {"crop": String(crop["id"]), "grow": int(crop["grow"]), "wet": 0}
	main.garden.pick()
	t._expect("full pantry leaves the crop ripe", main.garden.is_ripe(0) and int(Save.pantry["berries"]) == 20)
	await t._at_ring(main.stations.rings["garden"])
	t._expect("garden shows owned food and a capacity reason", _words().contains("Sunberries 20/20") and _words().contains("pantry full"))
	await t._wait(0.3)
	await t._shot("inventory_garden")
	await t._at_ring(main.stations.rings["pot"])
	t._expect("pot shows Have and Need beside current stock", _words().contains("Sunberries 20/20") and _words().contains("Have 20, Need 3"))
	t._expect("every unlocked recipe has an actionable row", main.hud.card_buttons().size() == main.cooking.known().size())
	main.stations._cook_dish("berry_tart")
	t._expect("cooking spends ingredients once and reports the new total", Save.meal_ready == "berry_tart" and int(Save.pantry["berries"]) == 17 and main.hud._toast.text.contains("now 17/20"))
	t._expect("prepared dish effect and replacement are explicit", _words().contains("Waiting dish") and _words().contains("shoots 15% faster") and _words().contains("Replace"))
	await t._wait(0.3)
	await t._shot("inventory_cooking")
	Save.meal_on = "fish_skewers"
	hud_open()
	t._expect("waiting and active dishes have individual slots", main.hud.inventory.slots.has("meal_ready") and main.hud.inventory.slots.has("meal_on"))
	main.hud.inventory._select("meal_ready")
	t._expect("selecting a prepared dish explains its effect", _words().contains("Waiting dish") and _words().contains("shoots 15% faster"))
	Save.meal_on = ""
	Save.meal_ready = ""
	main.hud.hide_card()
	Save.pantry["fish"] = 19
	main.fishing.catch = {"id": "trout", "name": "Silver Trout", "gives": {"fish": 2}}
	main.fishing._give()
	t._expect("partial fishing catch reports accepted food and full stock", int(Save.pantry["fish"]) == 20 and main.hud._toast.text.contains("+1 fish") and main.hud._toast.text.contains("now 20/20"))
	Save.pantry["berries"] = 5
	var l0 := Save.leaves
	var offer: Dictionary = Data.b["market"]["sells"][0]
	main.stations._market_buy(0)
	t._expect("Market purchase updates food, money and receipt", int(Save.pantry["berries"]) == 5 + int(offer["amount"]) and Save.leaves == l0 - int(offer["leaves"]) and main.hud._toast.text.contains("now"))
	main.hud.inventory.selected = "berries"
	hud_open()
	t._expect("food counts in Bag match the Market result", _words().contains("%d/20" % int(Save.pantry["berries"])))
	await t._wait(0.3)
	await t._shot("inventory_food_camp")
	var slot: Button = main.hud.inventory.slots["berries"]
	t._expect("supplies use square slots", absf(slot.size.x - slot.size.y) < 1.0, {"size": str(slot.size)})
	var currency: Label = main.hud.inventory._labels["wallet_leaves"]
	t._expect("currency count fits on one line", currency.get_line_count() == 1 and currency.size.x >= currency.get_minimum_size().x)
	t._expect("food, keys, materials and build supplies share the grid", main.hud.inventory.slots.has("fish") and main.hud.inventory.slots.has("keys") and main.hud.inventory.slots.has("amber") and main.hud.inventory.slots.has("tower"))
	main.set_riding(true, false)
	await t._wait(0.5)
	t._expect("mounted Bag preview shows both cat and current mount", main.hud.inventory.preview.cat_copy != null and main.hud.inventory.preview.mount_copy != null)
	await t._shot("inventory_mounted")
	main.set_riding(false, false)
	await t._wait(0.4)
	t._expect("dismounting returns preview to the cat alone", main.hud.inventory.preview.mount_copy == null)
	main.hud.inventory._select("keys")
	await t._wait(0.2)
	t._expect("currency strip and key details show current amounts", main.hud.inventory._labels["wallet_leaves"].text == str(Save.leaves) and _words().contains("Hollow keys"))
	await t._shot("inventory_resources_camp")
	main.hud.hide_card()


func hud_open() -> void:
	if main.hud.card_ring() != main.hud.inventory:
		main.hud.open_inventory()
	else:
		main.hud.refresh_card()


func _dungeon() -> void:
	Save.snack_choice = "auto"
	Save.pantry = {"berries": 6, "herbs": 3, "honey": 3, "fish": 3, "goldfish": 1}
	await main.burrows.enter("old_hollow", 1)
	await t._wait(0.3)
	var area = main.area
	t._expect("the real dungeon entry succeeded", area != null)
	if area == null:
		return
	area.run["satchel"] = {"amber": 5, "glowstone": 3, "heartwood": 1}
	Save.mats = {"amber": 10, "glowstone": 6, "heartwood": 2}
	hud_open()
	main.hud.inventory._select("amber")
	await t._wait(0.2)
	t._expect("stored and run materials are distinct", _words().contains("At camp 10 · This run 5"))
	t._expect("knock-out preview uses the run settlement calculation", _words().contains("keep %d" % int(area._banked_preview(float(Data.burrow_cfg()["knockout_keep"])).get("amber", 0))))
	await t._shot("inventory_resources_dungeon")
	main.hud.inventory._select("honey")
	var foe = area.spawn("snail", main.player.global_position + Vector3(3, 0, -2))
	if foe != null:
		foe.hp = 99999
		foe.wake()
		var before: Vector3 = foe.global_position
		await t._wait(0.4)
		t._expect("enemy movement continues with Bag open", foe.global_position.distance_to(before) > 0.01 and not main.frozen)
	main.hud.inventory._choose("honey")
	main.player.hp = Data.cat_max_hp() - 1
	main._snack_t = -1
	var food0 := int(Save.pantry["honey"])
	t._expect("selected food overrides Auto", String(main.snack_pick()["item"]) == "honey")
	t._expect("selected food heals only missing health", main.eat_snack() and main.player.hp == Data.cat_max_hp() and int(Save.pantry["honey"]) == food0 - 1)
	t._expect("healing feedback reports actual health restored", main.hud._toast.text.begins_with("Healed 1"))
	main.player.hp -= 2
	t._expect("Bag and quick heal share one cooldown", not main.eat_snack("fish") and int(Save.pantry["fish"]) == 3)
	main.hud.hide_card()
	hud_open()
	t._expect("reopening Bag retains cooldown", main.snack_left() > 0 and main.snack_reason("fish").begins_with("Ready in"))
	main._snack_t = -1
	main.player.hp = Data.cat_max_hp()
	t._expect("full health spends no food", not main.eat_snack("fish") and int(Save.pantry["fish"]) == 3)
	Save.pantry["honey"] = 0
	t._expect("empty chosen food does not consume another ingredient", main.snack_pick().is_empty() and not main.eat_snack() and int(Save.pantry["goldfish"]) == 1)
	main.hud.refresh_build()
	t._expect("empty selection offers Choose food", main.hud._snack_button.text.contains("Choose food"))
	main.hud.inventory._choose("auto")
	t._expect("Auto retains the original configured priority", String(main.snack_pick()["item"]) == "fish")
	main.hud.inventory._choose("fish")
	main.hud.inventory._select("fish")
	var eat_button: Button = main.hud.inventory._buttons["eat"]
	main.player.hp -= 4
	main._snack_t = -1
	await t._wait(0.2)
	t._expect("live health updates keep the same action buttons", main.hud.inventory._buttons["eat"] == eat_button)
	main.hud.inventory.selected = "fish"
	main.hud.refresh_card()
	await t._wait(0.2)
	await t._shot("inventory_food_dungeon")
	var stock := int(Save.pantry["fish"])
	await t._tap_at(main.hud.inventory._buttons["eat"].get_global_rect().get_center())
	t._expect("Bag Eat closes its dialog and consumes once", not main.hud.card_open() and int(Save.pantry["fish"]) == stock - 1)
	main.player.hp -= 2
	main._snack_t = -1
	await t._wait(0.2)
	await t._tap_at(main.hud._snack_button.get_global_rect().get_center())
	t._expect("the quick-heal HUD button consumes once through real input", int(Save.pantry["fish"]) == stock - 2 and main.player.hp == Data.cat_max_hp())
	var saved = JSON.parse_string(FileAccess.get_file_as_string(Save.path))
	t._expect("food, healing and choice are saved together", int(saved["pantry"]["fish"]) == stock - 2 and int(saved["burrow_run"]["hp"]) == main.player.hp and String(saved["snack_choice"]) == "fish")
	main.player.hp = 0
	main._snack_t = -1
	t._expect("defeated cat cannot eat", not main.eat_snack("fish"))
	main.player.hp = Data.cat_max_hp()
	await area._leave("back")
	_write_save(saved)
	Save.load_game()
	await main.burrows.resume_run()
	t._expect("resuming restores consumed food and healed health", main.area != null and int(Save.pantry["fish"]) == stock - 2 and main.player.hp == int(saved["burrow_run"]["hp"]))
	await area._leave("down")
	t._expect("material settlement agrees with Bag preview", int(Save.mats["amber"]) == 12 and int(Save.mats["glowstone"]) == 7)
	t._expect("camp food action explains dungeon use", main.snack_reason("fish") == "Eat in a dungeon")


func _old_save() -> void:
	Save.save_game()
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Save.path))
	saved.erase("snack_choice")
	_write_save(saved)
	Save.snack_choice = "honey"
	Save.load_game()
	t._expect("older saves default quick heal to Auto", Save.snack_choice == "auto")
	saved["snack_choice"] = "unknown_food"
	_write_save(saved)
	Save.load_game()
	t._expect("invalid saved choice falls back to Auto", Save.snack_choice == "auto")
	Save.save_game()


func _write_save(value: Dictionary) -> void:
	var file := FileAccess.open(Save.path, FileAccess.WRITE)
	file.store_string(JSON.stringify(value))
