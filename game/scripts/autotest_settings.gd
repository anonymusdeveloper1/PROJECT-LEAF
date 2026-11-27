extends Node
## H2: the Settings window (`-- --autotest --fresh --settings`), run from autotest.gd. Each check logs "EXPECT PASS <what>"
## or "EXPECT FAIL <what>" through autotest.gd's _expect.
## Uses: settings_window.gd (spec, the rows' actions), Quality (set_level, set_auto), Sfx (set_sound, sound_on), the
## Master bus, core/settings_file.gd. Nothing may be written to user://settings.json during the run (a test never
## writes it); the quality level, auto, and the bus are put back at the end.

const WindowScript := preload("res://ui/hud/settings_window.gd")
const SettingsFile := preload("res://core/settings_file.gd")

var t: Variant                           # autotest.gd (its helpers: _expect, _log)
var main: Variant


func run() -> void:
	var before_text := _file_text()
	var was_level: int = Quality.level
	var was_auto: bool = Quality.auto
	var was_fps30: bool = Quality.fps30
	var was_sound: bool = Sfx.sound_on()
	var window = WindowScript.new(main.hud)
	var ok := _rows(window)
	ok = _graphics(window, before_text) and ok
	ok = _sound(window, before_text) and ok
	ok = await _card(before_text) and ok
	# put everything back through the real calls, then check that nothing was written and the game follows
	if was_auto:
		Quality.set_auto()
	else:
		Quality.set_level(was_level)
	Quality.fps30 = was_fps30
	Quality.apply_viewport()
	Sfx.set_sound(was_sound)
	var bus := AudioServer.get_bus_index("Master")
	ok = t._expect("nothing was written to user://settings.json during the test", _file_text() == before_text) and ok
	ok = t._expect("the sound, the bus and the graphics are back as they were",
		Sfx.sound_on() == was_sound and AudioServer.is_bus_mute(bus) == (not was_sound)
		and Quality.level == was_level and Quality.auto == was_auto and Quality.fps30 == was_fps30
		and main.world.sun.shadow_enabled == Quality.shadows()
		and main.world.env.glow_enabled == Quality.glow()) and ok
	t._log("settings done", {"ok": ok})


## The settings file's text ("" when it is missing).
func _file_text() -> String:
	return FileAccess.get_file_as_string(SettingsFile.PATH) if FileAccess.file_exists(SettingsFile.PATH) else ""


func _find(spec: Dictionary, id: String) -> Dictionary:
	for row in spec["rows"]:
		if String((row as Dictionary).get("id", "")) == id:
			return row
	return {}


func _rows(window) -> bool:
	var spec: Dictionary = window.spec()
	var graphics: Dictionary = Data.item("settings", "graphics")
	var sound: Dictionary = Data.item("settings", "sound")
	var ok: bool = t._expect("the settings content has the graphics and sound entries", not graphics.is_empty() and not sound.is_empty())
	var options: Array = graphics.get("options", [])
	ok = t._expect("the graphics entry lists Auto, Low, Medium, High", options.size() == 4) and ok
	for option in options:
		var row := _find(spec, "graphics_" + String(option["id"]))
		ok = t._expect("the window has a graphics row for %s with its words from the entry" % option["id"],
			not row.is_empty() and row["text"] == option["name"] and row["note"] == option["desc"]) and ok
	var srow := _find(spec, "sound")
	ok = t._expect("the window has a sound row", not srow.is_empty() and srow["text"] == sound["name"]) and ok
	ok = t._expect("the window has a title and no row is missing its action",
		spec["title"] == String(graphics.get("window_title", "")) and spec["title"] != "" and (spec["rows"] as Array).all(func(r): return r.get("kind", "") == "section" or (r["action"] as Callable).is_valid())) and ok
	return ok


func _graphics(window, before_text: String) -> bool:
	var ok := true
	for i in ["low", "medium", "high"].size():
		var id: String = ["low", "medium", "high"][i]
		(_find(window.spec(), "graphics_" + id)["action"] as Callable).call()
		ok = t._expect("pressing %s sets Quality.level to %d and auto off" % [id, i], Quality.level == i and not Quality.auto) and ok
		ok = t._expect("pressing %s writes nothing to the settings file" % id, _file_text() == before_text) and ok
		var row := _find(window.spec(), "graphics_" + id)
		ok = t._expect("%s now reads In use and cannot be pressed" % id, not row["enabled"] and row["label"] == "In use") and ok
		var auto_row := _find(window.spec(), "graphics_auto")
		ok = t._expect("Auto reads Use while %s is picked" % id, auto_row["enabled"] and auto_row["label"] == "Use") and ok
	(_find(window.spec(), "graphics_auto")["action"] as Callable).call()
	ok = t._expect("pressing Auto sets auto on, at the detected level", Quality.auto and Quality.level == Quality.detect()) and ok
	ok = t._expect("pressing Auto writes nothing to the settings file", _file_text() == before_text) and ok
	ok = t._expect("Auto reads In use", not _find(window.spec(), "graphics_auto")["enabled"]) and ok
	return ok


func _sound(window, before_text: String) -> bool:
	var bus := AudioServer.get_bus_index("Master")
	Sfx.set_sound(true)
	var ok: bool = t._expect("the sound is on and the Master bus is not muted", Sfx.sound_on() and not AudioServer.is_bus_mute(bus))
	ok = t._expect("turning the sound on writes nothing to the settings file", _file_text() == before_text) and ok
	var row := _find(window.spec(), "sound")
	ok = t._expect("with sound on the button reads Turn off", row["label"] == "Turn off") and ok
	(row["action"] as Callable).call()
	ok = t._expect("pressing it mutes the Master bus and Sfx.sound_on() is false", AudioServer.is_bus_mute(bus) and not Sfx.sound_on()) and ok
	ok = t._expect("turning the sound off writes nothing to the settings file", _file_text() == before_text) and ok
	row = _find(window.spec(), "sound")
	ok = t._expect("with sound off the button reads Turn on", row["label"] == "Turn on") and ok
	(row["action"] as Callable).call()
	ok = t._expect("pressing it again unmutes the bus and Sfx.sound_on() is true", not AudioServer.is_bus_mute(bus) and Sfx.sound_on()) and ok
	ok = t._expect("turning the sound on again writes nothing to the settings file", _file_text() == before_text) and ok
	return ok


## The window through the HUD: open it with hud.open_settings(), read the card's real buttons, press a graphics row's own
## button, close it.
func _card(before_text: String) -> bool:
	var hud = main.hud
	hud.open_settings()
	await t._wait(0.3)
	var ok: bool = t._expect("hud.open_settings() opens the Settings card", hud.card_ring() == hud.settings)
	var buttons: Array = hud.card_buttons()
	ok = t._expect("the card shows a button for Auto, Low, Medium, High and the sound row", buttons.size() == 5) and ok
	var labels: Array = buttons.map(func(b): return String(b.get_meta("label", b.text)))
	ok = t._expect("the sound row's button reads Turn on or Turn off", labels.size() == 5 and (labels[4] == "Turn off" or labels[4] == "Turn on")) and ok
	if buttons.size() == 5:
		var pick := 3 if not (not Quality.auto and Quality.level == 2) else 1     # High, or Low when High is in use
		var button: Button = buttons[pick]
		ok = t._expect("the graphics button to press is enabled", not button.disabled) and ok
		button.pressed.emit()
		await t._wait(0.2)
		ok = t._expect("pressing its real button sets that level and auto off", Quality.level == pick - 1 and not Quality.auto) and ok
		ok = t._expect("pressing it writes nothing to the settings file", _file_text() == before_text) and ok
	hud.hide_card()
	await t._wait(0.2)
	ok = t._expect("the Settings card closes", hud.card_ring() != hud.settings) and ok
	return ok
