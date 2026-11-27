extends Node
## An Effects holder (H3, 26 Nov 2026; docs/ARCHITECTURE.md part 4, Component): the effects running on one thing. A
## child named "Effects" of the cat (player.gd) and of the mount (mount.gd), made in their setup; no class_name
## (preload it).
## Used by: core/effects.gd (add, has_source), the HUD's potion line (top_bar.gd, active), the tests (step, left, mult).
## Uses: its owner's Callables (max_hp, heal, stats_changed) and main.frozen.
## Rules:
##   - Two kinds run here. heal_over_time: the total, maxi(1, roundi(max * share)) points, handed out evenly over
##     `seconds` through heal (the owner caps at its max health), so a 14-hp cat gets 6 points over 5 s. stat_mult:
##     stat -> mult for `seconds`.
##   - One effect per source (the item id): Effects refuses a second one while one runs ("Already active"); if add() is
##     called anyway, the new one replaces the old.
##   - On every start or end of a stat_mult, and on clear(), stats_changed gets the FULL map of every stat with a
##     running stat_mult ({"damage": 0.25, "speed": 0.25}, or {}), never only the stat that changed: Data's
##     set_effect_mults replaces its whole map, so the Damage Potion ending never ends a running Speed Potion (Dirty
##     Flag: the cat's stats change only then).
##   - It ticks in _process on frame time (clamped to 0.1 s) and stops while main.frozen, so effects pause with the
##     game; it sleeps (no _process) while nothing runs. Effects are not saved (they last 5-30 s). The owner calls
##     clear() when it is knocked out.
##   - step(dt) moves every running effect on by dt seconds (_process calls it; a test calls it with main.frozen on, so
##     nothing else moves meanwhile).

signal changed                            # an effect started or ended, or clear() ran

var main                                  # main.gd (main.frozen pauses the effects); set by the owner
var max_hp: Callable                      # the owner's max health: () -> int
var heal: Callable                        # the owner's heal: (points: int) -> void
var stats_changed: Callable               # the cat: Data.set_effect_mults (the full map); the mount: none
var _running: Array = []                  # {"source", "type", "stat", "mult", "seconds", "t", "total", "given"}


func _ready() -> void:
	set_process(not _running.is_empty())


func _process(delta: float) -> void:
	if main != null and bool(main.frozen):
		return
	step(minf(delta, 0.1))


## Starts effect e (a heal_over_time or a stat_mult) from source. Effects.reason has checked that it may.
func add(e: Dictionary, source: String) -> void:
	var type := String(e.get("type", ""))
	if type != "heal_over_time" and type != "stat_mult":
		push_warning("Effects holder: a \"%s\" effect does not run over time" % type)
		return
	var replaced_stat := _drop(source)
	var run := {"source": source, "type": type, "stat": String(e.get("stat", "")), "mult": float(e.get("mult", 0.0)),
		"seconds": maxf(0.0, float(e.get("seconds", 0.0))), "t": 0.0, "total": 0, "given": 0}
	if type == "heal_over_time":
		var top := int(max_hp.call()) if max_hp.is_valid() else 0
		run["total"] = maxi(1, roundi(float(top) * float(e.get("share", 0.0))))
	_running.append(run)
	if type == "stat_mult" or replaced_stat:
		_send_stats()
	set_process(true)
	changed.emit()
	if float(run["seconds"]) <= 0.0:
		step(0.0)                                       # no time at all: it all happens (and ends) at once


## Moves every running effect on by dt seconds: heals hand out what is due by now, and what has run its time ends.
func step(dt: float) -> void:
	if _running.is_empty():
		set_process(false)
		return
	var ended := false
	var stats_ended := false
	for run: Dictionary in _running.duplicate():
		run["t"] = float(run["t"]) + maxf(0.0, dt)
		var secs := float(run["seconds"])
		var k := 1.0 if secs <= 0.0 else clampf(float(run["t"]) / secs, 0.0, 1.0)
		if String(run["type"]) == "heal_over_time":
			var total := int(run["total"])
			var due := mini(total, floori(float(total) * k + 0.0001))
			if due > int(run["given"]):
				var pts := due - int(run["given"])
				run["given"] = due
				if heal.is_valid():
					heal.call(pts)
		if k >= 1.0:
			_running.erase(run)
			ended = true
			stats_ended = stats_ended or String(run["type"]) == "stat_mult"
	if stats_ended:
		_send_stats()
	if ended:
		changed.emit()
	if _running.is_empty():
		set_process(false)


## Something from source is running.
func has_source(source: String) -> bool:
	for run: Dictionary in _running:
		if String(run["source"]) == source:
			return true
	return false


## Seconds left of what source runs (0 when nothing does).
func left(source: String) -> float:
	var out := 0.0
	for run: Dictionary in _running:
		if String(run["source"]) == source:
			out = maxf(out, float(run["seconds"]) - float(run["t"]))
	return out


## The running stat_mult share for stat (the stat is x (1 + this)); 0.0 when none runs. The same number Data's
## effect_mult gives for the cat.
func mult(stat: String) -> float:
	var out := 0.0
	for run: Dictionary in _running:
		if String(run["type"]) == "stat_mult" and String(run["stat"]) == stat:
			out += float(run["mult"])
	return out


## What runs now, in the order it started: [{"source", "type", "stat", "mult", "left"}].
func active() -> Array:
	var out: Array = []
	for run: Dictionary in _running:
		out.append({"source": run["source"], "type": run["type"], "stat": run["stat"], "mult": run["mult"],
			"left": maxf(0.0, float(run["seconds"]) - float(run["t"]))})
	return out


## Everything stops (the owner was knocked out). The cat's stats go back at once: stats_changed gets {}.
func clear() -> void:
	var had := not _running.is_empty()
	_running.clear()
	if stats_changed.is_valid():
		stats_changed.call({})
	set_process(false)
	if had:
		changed.emit()


# ---------------------------------------------------------------- inside
## Takes away what source runs; true when one of them was a stat_mult (the map must be sent again).
func _drop(source: String) -> bool:
	var stat := false
	for run: Dictionary in _running.duplicate():
		if String(run["source"]) == source:
			_running.erase(run)
			stat = stat or String(run["type"]) == "stat_mult"
	return stat


## Hands the owner the full map of every stat with a running stat_mult (Dirty Flag).
func _send_stats() -> void:
	if not stats_changed.is_valid():
		return
	var map := {}
	for run: Dictionary in _running:
		if String(run["type"]) == "stat_mult":
			var s := String(run["stat"])
			map[s] = float(map.get(s, 0.0)) + float(run["mult"])
	stats_changed.call(map)
