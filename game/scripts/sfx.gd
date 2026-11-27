class_name Sfx
extends RefCounted
## Placeholder sounds (made by tools/make_sfx.py). A small pool of players hung on the main node; a sound that
## repeats very fast (many arrows hitting at once) is thinned out so it never turns into noise.

const SettingsFile := preload("res://core/settings_file.gd")

static var _players: Array = []
static var _streams := {}
static var _last := {}
static var _next := 0
static var _on := true                  # the sound switch (Settings window); off mutes the Master bus


static func init(host: Node) -> void:
	_players.clear()
	for i in 10:
		var p := AudioStreamPlayer.new()
		host.add_child(p)
		_players.append(p)
	_on = bool(SettingsFile.read().get("sound", true))      # an old file without "sound" means on
	_apply_sound()


## The Settings window's sound switch: mutes or unmutes the Master bus (every game sound) and remembers it.
static func set_sound(on: bool) -> void:
	_on = on
	_apply_sound()
	SettingsFile.write("sound", on)


static func sound_on() -> bool:
	return _on


static func _apply_sound() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), not _on)


static func play(name: String, volume_db := 0.0, min_gap := 0.04) -> void:
	if _players.is_empty():
		return
	var now := Time.get_ticks_msec() * 0.001
	if now - float(_last.get(name, -1.0)) < min_gap:
		return
	_last[name] = now
	if not _streams.has(name):
		var path := "res://assets/sfx/%s.wav" % name
		_streams[name] = load(path) if ResourceLoader.exists(path) else null
	if _streams[name] == null:
		return
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	if not is_instance_valid(p):
		return
	p.stream = _streams[name]
	p.volume_db = volume_db
	p.pitch_scale = randf_range(0.92, 1.08)
	p.play()
