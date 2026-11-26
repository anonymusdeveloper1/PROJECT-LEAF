extends RefCounted
## H2: the Settings window (the gear's dialog). It opens through the card system, like the Bag: spec() returns the card's
## rows in the plain-row format (text, note, cost, label, enabled, action). The words come from data
## (content/settings/<id>/entry.json, read through Data.catalog("settings"); the window title is the graphics entry's "window_title"); a new setting is a new entry and one small
## function here that builds its rows.

var hud
var key := "settings"
var builder: Callable = spec                          # a ring in the card system has a builder (this has no marker)


func _init(owner_hud = null) -> void:
	hud = owner_hud


func spec() -> Dictionary:
	var rows: Array = []
	for entry in Data.catalog("settings"):
		var id := String(entry.get("id", ""))
		rows.append({"kind": "section", "text": String(entry.get("name", id)).to_upper()})
		match id:
			"graphics":
				rows.append_array(_graphics_rows(entry))
			"sound":
				rows.append(_sound_row(entry))
	return {"title": String(Data.item("settings", "graphics").get("window_title", "")), "sub": "", "rows": rows, "view_id": ""}


## Show the window, or close it when it is already showing (the gear's tap).
func toggle() -> void:
	if hud == null:
		return
	if hud.card_ring() == self:
		hud.hide_card()
	else:
		open()


func open() -> void:
	if hud != null:
		hud.show_card(self)


## One row per option (Auto, Low, Medium, High); the one in use shows a grey "In use" button.
func _graphics_rows(entry: Dictionary) -> Array:
	var rows: Array = []
	var options: Array = entry.get("options", [])
	for i in options.size():
		var option: Dictionary = options[i]
		var oid := String(option.get("id", ""))
		var in_use: bool = Quality.auto if oid == "auto" else (not Quality.auto and Quality.level == i - 1)
		var action: Callable = Quality.set_auto if oid == "auto" else Quality.set_level.bind(i - 1)
		rows.append({"text": String(option.get("name", oid)), "note": String(option.get("desc", "")), "cost": {},
			"label": String(entry.get("in_use", "In use")) if in_use else String(entry.get("use", "Use")),
			"enabled": not in_use, "action": action, "id": "graphics_" + oid})
	return rows


func _sound_row(entry: Dictionary) -> Dictionary:
	var on := Sfx.sound_on()
	return {"text": String(entry.get("name", "Sound")),
		"note": String(entry.get("on_note", "")) if on else String(entry.get("off_note", "")), "cost": {},
		"label": String(entry.get("turn_off", "Turn off")) if on else String(entry.get("turn_on", "Turn on")),
		"enabled": true, "action": Sfx.set_sound.bind(not on), "id": "sound"}
