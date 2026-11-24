extends Node
var t
var main


func _x(what: String, ok: bool, extra := {}) -> void:
	t._expect(what, ok, extra)


func _catalog() -> Dictionary:
	main.stations.sign_tab = "missions"
	return main.stations._card_sign()


func _missions(spec: Dictionary) -> Array:
	return (spec["rows"] as Array).filter(func(r): return r.has("mission_index"))


func _entry(index: int) -> Dictionary:
	for row in _missions(_catalog()):
		if int(row["mission_index"]) == index:
			return row
	return {}


func _won(count: int) -> void:
	Save.missions_done = []
	for i in count:
		Save.missions_done.append(String(Data.mission(i)["id"]))


func _descending(entries: Array) -> bool:
	var indices: Array = entries.map(func(r): return int(r["mission_index"]))
	return indices == range(Data.mission_count() - 1, -1, -1)


## Feed actual finger events through Input, including the viewport's phone/window transform.
func _swipe(from: Vector2, to: Vector2) -> void:
	var xf: Transform2D = get_viewport().get_final_transform()
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.position = xf * from
	down.pressed = true
	Input.parse_input_event(down)
	for i in 8:
		await t._wait(0.03)
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = xf * from.lerp(to, float(i + 1) / 8.0)
		drag.relative = xf.basis_xform((to - from) / 8.0)
		Input.parse_input_event(drag)
	await t._wait(0.15)                           # settle before lifting, so each check starts without inertia
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.position = xf * to
	Input.parse_input_event(up)
	await t._wait(0.06)


func _middle_card() -> Control:
	var viewport_rect: Rect2 = main.hud._card_scroll.get_global_rect()
	for child in main.hud._card_list.get_children():
		if child.has_meta("mission_index"):
			var rect: Rect2 = child.get_global_rect()
			if rect.position.y > viewport_rect.get_center().y and rect.end.y < viewport_rect.end.y:
				return child
	return null


func _scroll_gestures() -> void:
	var scroll: ScrollContainer = main.hud._card_scroll
	_x("the mission list hides its scrollbar while retaining scrollable content", not scroll.get_v_scroll_bar().is_visible() and scroll.get_v_scroll_bar().max_value > scroll.get_v_scroll_bar().page)
	# Start each swipe on a different part of a real, visible locked mission card.
	for part in ["title", "badge", "button", "background"]:
		scroll.scroll_vertical = 0
		await t._wait(0.05)
		var card := _middle_card()
		var line: Control = card.get_child(0)
		var target: Control = line.get_child(1).get_child(0)
		if part == "badge":
			target = line.get_child(0)
		elif part == "button":
			target = line.get_child(2)
		var start := target.get_global_rect().get_center()
		if part == "background":
			start = card.get_global_rect().position + Vector2(6, 60)
		await _swipe(start, start - Vector2(0, 210))
		_x("finger swipes over mission %s scroll the list" % part, scroll.scroll_vertical > 100, {"scroll": scroll.scroll_vertical})
	var before := scroll.scroll_vertical
	var middle: Vector2 = scroll.get_global_rect().get_center()
	await _swipe(middle, middle + Vector2(0, 180))
	_x("finger swipes scroll back toward mission 15", scroll.scroll_vertical < before - 80)
	scroll.scroll_vertical = 100000
	await t._wait(0.05)
	var start_button: Button
	for button in main.hud.card_buttons():
		if String(button.get_meta("label", "")) == "Start":
			start_button = button
	before = scroll.scroll_vertical
	var start := start_button.get_global_rect().get_center()
	await _swipe(start, start + Vector2(0, 210))
	_x("dragging from the enabled Start button scrolls without starting combat", scroll.scroll_vertical < before - 100 and not main.fight.active)
	_x("scroll gestures never move the cat or close the menu", main.joystick.vector == Vector2.ZERO and main.hud._card != null)
	scroll.scroll_vertical = 100000
	await t._wait(0.05)
	await t._shot("signpost_touch_scrolled_to_mission_1")
	# A stationary tap still works after the same button has participated in a drag.
	await t._tap_at(start_button.get_global_rect().get_center())
	_x("a deliberate Start tap still begins mission 1 after scrolling", main.fight.active and main.fight.mission == 0)
	t._reset_fight()
	main.fight.give_up_run()


func run() -> bool:
	var f = main.fight
	var st = main.stations
	main.player.invincible = true
	main.player.set_process(false)
	f.set_physics_process(false)
	t._reset_fight()
	Save.mission_run = {}
	Save.fire_ruined = false
	Save.raids["pending"] = false
	Save.raids["meter"] = 0.0
	Save.leaves = 0
	Save.timber = 0
	_won(0)
	main.raids.refresh_open()
	var spec := _catalog()
	var entries := _missions(spec)
	_x("a fresh signpost lists all 15 raid missions", entries.size() == Data.mission_count() and entries.size() == 15)
	_x("fresh Raid Missions appear from 15 down to 1", _descending(entries))
	_x("Raid Missions and Random Raids have separate navigation", String(spec["tabs"][0]["text"]) == "Raid Missions" and String(spec["tabs"][1]["text"]) == "Random Raids")
	_x("Random Raids stay locked before the story missions are finished", not bool(spec["tabs"][1]["enabled"]))
	_x("only the next unfinished raid mission can start", entries.filter(func(r): return bool(r["enabled"])).size() == 1 and bool(_entry(0)["enabled"]) and not bool(_entry(1)["enabled"]))
	st._set_sign_tab("raids")
	_x("calling navigation directly cannot bypass the random raid unlock", st.sign_tab == "missions")
	main.hud.show_card(st.rings["sign"])
	await t._wait(0.6)
	_x("both navigation buttons render in the signpost", main.hud._card_tabs.get_child_count() == 2 and main.hud._card_tabs.get_child(1).disabled)
	var first_card: Control = main.hud._card_list.get_child(1)
	main.hud.refresh_card()
	await t._wait(0.1)
	_x("unchanged live refreshes preserve the mission cards and their reveal", is_instance_valid(first_card) and main.hud._card_list.get_child(1) == first_card and is_equal_approx(first_card.modulate.a, 1.0))
	await t._shot("signpost_fresh_missions")
	await _scroll_gestures()
	main.hud.hide_card()
	_won(3)
	spec = _catalog()
	entries = _missions(spec)
	var completed: Array = entries.filter(func(r): return bool(r["completed"]))
	var unfinished: Array = entries.filter(func(r): return not bool(r["completed"]))
	_x("unfinished and completed groups retain descending mission order", _descending(entries))
	_x("completed and unfinished missions remain listed separately", completed.size() == 3 and unfinished.size() == 12 and (spec["rows"] as Array).any(func(r): return String(r.get("text", "")) == "Completed · 3"))
	_x("finished missions are marked Finished and offer Replay", completed.all(func(r): return String(r["note"]).contains("Finished") and String(r["label"]) == "Replay" and bool(r["enabled"])))
	_x("unfinished missions retain the sequential unlock", bool(_entry(3)["enabled"]) and not bool(_entry(4)["enabled"]) and Data.next_mission() == 3)
	main.hud.show_card(st.rings["sign"])
	await t._wait(0.6)
	await t._shot("signpost_unfinished_missions")
	main.hud._card_scroll.scroll_vertical = 100000
	await t._wait(0.1)
	await t._shot("signpost_completed_replays")
	main.hud.hide_card()
	var garden_before: int = Save.stations["garden"]
	var progress_before := Data.progress()
	(_entry(0)["action"] as Callable).call()
	_x("Replay starts a completed raid mission from wave 1", f.active and f.in_wave and f.mission == 0 and f.wave == 1)
	f._clear_foes()
	var leaves_before: int = Save.leaves
	var timber_before: int = Save.timber
	f._win()
	var reward: Dictionary = Data.mission(0)["reward"]
	var share: float = Data.b["mission"]["replay_reward"]
	_x("repeat completion pays the configured replay reward", Save.leaves - leaves_before == roundi(float(reward["leaves"]) * share) and Save.timber - timber_before == roundi(float(reward["timber"]) * share))
	_x("replays never duplicate story progress or first-clear gifts", Data.progress() == progress_before and Data.next_mission() == 3 and Save.stations["garden"] == garden_before and f.barricade_gift == 0)
	_x("replaying early missions cannot unlock Random Raids", not Data.raids_open() and not bool(_catalog()["tabs"][1]["enabled"]))
	Save.mission_run = {"mission": 3, "chapter": 0, "wave_done": 2, "gain": 0}
	_x("a saved mission blocks launching a different replay", not bool(_entry(0)["enabled"]))
	f.start_mission(0)
	_x("the combat API preserves another mission's saved progress", not f.active and int(Save.mission_run["mission"]) == 3 and int(Save.mission_run["wave_done"]) == 2)
	f.start_mission(3)
	_x("the saved raid mission resumes its next uncleared wave", f.active and f.wave == 3 and f.mission == 3)
	t._reset_fight()
	f.give_up_run()
	_x("explicit Give up releases the mission slot", Save.mission_run.is_empty() and bool(_entry(0)["enabled"]))
	Save.fire_ruined = true
	_x("a ruined campfire blocks both replays and new missions", not bool(_entry(0)["enabled"]) and not bool(_entry(3)["enabled"]))
	Save.fire_ruined = false
	_won(Data.mission_count() - 1)
	_x("the Random Raids view is still locked with one mission left", not bool(_catalog()["tabs"][1]["enabled"]))
	f.start_mission(Data.mission_count() - 1)
	f._clear_foes()
	f._win()
	_x("finishing the final unique mission unlocks Random Raids", Data.raids_open() and bool(_catalog()["tabs"][1]["enabled"]))
	st._set_sign_tab("raids")
	spec = st._card_sign()
	_x("the unlocked Random Raids view retains the Watch controls", String(spec["title"]) == "Random Raids" and bool(spec["tabs"][1]["selected"]) and String(spec["sub"]).contains("Gloom") and (spec["rows"] as Array).any(func(r): return String(r.get("text", "")).begins_with("Raids held")))
	main.hud.show_card(st.rings["sign"])
	await t._wait(0.6)
	await t._shot("signpost_random_raids_unlocked")
	t._press("Raid Missions")
	await t._wait(0.6)
	_x("the Raid Missions button still opens the catalogue after endgame unlock", st.sign_tab == "missions" and _missions(st._card_sign()).size() == 15)
	_x("every completed raid mission remains replayable after Random Raids unlock", _missions(_catalog()).all(func(r): return bool(r["completed"]) and String(r["label"]) == "Replay" and bool(r["enabled"])))
	_x("the fully completed catalogue also runs from 15 down to 1", _descending(_missions(_catalog())))
	await t._shot("signpost_all_missions_completed")
	main.hud.hide_card()
	Save.raids["pending"] = true
	_x("a pending random raid prevents mission replays from dodging it", not bool(_entry(0)["enabled"]))
	f.start_mission(0)
	_x("pending raid priority is enforced in combat too", not f.active)
	Save.raids["pending"] = false
	Save.save_game()
	Save.load_game()
	main.defences.relink_saved()
	_x("saved completion records keep replays and the raid unlock after reload", Data.progress() == 15 and Data.mission_unlocked(0) and Data.raids_open())
	main.player.set_process(true)
	f.set_physics_process(true)
	t._log("raid mission menu done")
	return true
