extends Node
## Timers (autoload "Timers"; docs/ARCHITECTURE.md part 3): real-time jobs that keep running while the game is closed.
## In H3 these are the garden's crops and the cooking pot; a later long job is one new kind in balance.json timers.jobs
## and one small handler.
## Used by: garden.gd and cooking.gd (they start, water, collect and remove jobs, and listen to Events.timer_finished),
## the garden and pot windows (time left, progress), core/save_upgrades.gd (the 3 -> 4 step reads `clock`) and the tests.
## Uses: Save (the jobs live in Save.timers, so they get Save's one file, its atomic write, its version and its dirty
## flag), Data (balance.json "timers": the job kinds, how often to check) and Events (timer_finished).
## Rules:
##   - Save.timers is {"seen": the highest clock reading so far, "jobs": {id: {"start", "len", "data", "told"}}}. start
##     and seen are Unix seconds (UTC); len is the job's length in seconds (watering lowers it); told is true once
##     timer_finished was sent for it. Timers keeps no state of its own.
##   - A job id is "<kind>:<key>" ("crop:0" .. "crop:5" for the plots, "cook:pot"); its kind must be listed in
##     balance.json timers.jobs, or start() refuses it.
##   - The clock rule: now() never goes below seen. When the phone's clock is set back, now() stays at seen until the
##     clock passes it again, so jobs never run backwards: they wait. A job started then starts at seen and waits too.
##     The clock is UTC, so a change of time zone does nothing. (Setting the clock forward finishes jobs early: that
##     cannot be stopped without a server.)
##   - start, shorten, remove and set_job_data mark the save dirty. Raising seen alone never does (that would write the
##     file every 10 s for ever); seen is written whenever the save is written anyway.
##   - check() runs every timers.check_every_s seconds of real time, on resume and focus, and once 1 s after a save
##     loads (so the garden and the pot exist and hear about jobs that ended while the game was closed). Each job that
##     has ended and was not told yet: told = true, the save is marked dirty, then Events.timer_finished(id).
##   - Timers never changes the game itself: no Bag, no Gloom meter, no leaves. The handlers (garden.gd, cooking.gd)
##     refresh looks and toast; what changes the game (pick, collect, the Gloom bumps) happens on the player's taps. A
##     handler also catches up from Timers' state on its own setup, since an event can be missed.
##   - `clock` is the Service Locator for time (ARCHITECTURE part 4): the real clock, or a pretend one for tests. A test
##     sets it to a method of its own node (real now + an offset; a lambda would copy its locals and not see the test
##     move its clock) and calls use_real_clock() when it ends. Timers never looks at main or main.frozen.

const REAL_CLOCK_METHOD := &"get_unix_time_from_system"

## Unix seconds (UTC) now: the real clock, or a test's pretend one.
var clock: Callable = Callable(Time, REAL_CLOCK_METHOD)

var _next_check_ms := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Events.save_loaded.connect(_on_save_loaded)


func _process(_delta: float) -> void:
	var ms := Time.get_ticks_msec()
	if ms < _next_check_ms:
		return
	_next_check_ms = ms + int(maxf(0.1, _check_every_s()) * 1000.0)
	check()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		check()


## max(clock, seen): Unix seconds that never go back. Raises seen in memory (never marks the save dirty).
func now() -> float:
	if not clock.is_valid():
		clock = Callable(Time, REAL_CLOCK_METHOD)     # a test's node is gone: back to the real clock
	var t := float(clock.call())
	var seen := float(Save.timers.get("seen", 0.0))
	if t > seen:
		Save.timers["seen"] = t
		return t
	return seen


## Starts job `id` (it replaces a job with the same id): it ends `seconds` from now. data is the handler's own (a copy
## is kept). false, and nothing starts, when the id's kind is not in balance.json timers.jobs.
func start(id: String, seconds: float, data: Dictionary = {}) -> bool:
	if not _kind_known(_kind(id)):
		push_warning("Timers.start: \"%s\" is not a kind listed in balance.json timers.jobs" % id)
		return false
	_jobs()[id] = {"start": now(), "len": maxf(0.0, seconds), "data": data.duplicate(true), "told": false}
	Save.mark_dirty()
	return true


func has(id: String) -> bool:
	return _jobs().get(id) is Dictionary


## The job is there and its time is up (told or not).
func done(id: String) -> bool:
	return has(id) and now() >= _end(id)


## Seconds left: 0 when it is done or there is no such job.
func left(id: String) -> float:
	if not has(id):
		return 0.0
	return maxf(0.0, _end(id) - now())


## How far along it is, 0..1: 1 when done, 0 when there is no such job.
func progress(id: String) -> float:
	if not has(id):
		return 0.0
	var j := _job(id)
	var length := float(j.get("len", 0.0))
	if length <= 0.0:
		return 1.0
	return clampf((now() - float(j.get("start", 0.0))) / length, 0.0, 1.0)


## A copy of the job's own data ({} when there is no such job). Change it with set_job_data.
func job_data(id: String) -> Dictionary:
	var d: Variant = _job(id).get("data", {})
	return (d as Dictionary).duplicate(true) if d is Dictionary else {}


func set_job_data(id: String, key: String, value: Variant) -> void:
	if not has(id):
		return
	var j := _job(id)
	if not j.get("data") is Dictionary:
		j["data"] = {}
	(j["data"] as Dictionary)[key] = value
	Save.mark_dirty()


## The job ends `seconds` sooner: len goes down, but never below the time it has already run (it is then done now),
## and never up.
func shorten(id: String, seconds: float) -> void:
	if not has(id) or seconds <= 0.0:
		return
	var j := _job(id)
	var length := float(j.get("len", 0.0))
	var ran := maxf(0.0, now() - float(j.get("start", 0.0)))
	j["len"] = maxf(length - seconds, minf(length, ran))
	Save.mark_dirty()


## Takes the job away (collected or cancelled). Sends nothing.
func remove(id: String) -> void:
	if _jobs().erase(id):
		Save.mark_dirty()


## The ids of every job of one kind ("crop" gives "crop:0", "crop:3", ...), sorted.
func ids(kind: String) -> Array[String]:
	var out: Array[String] = []
	for id: Variant in _jobs():
		if _kind(String(id)) == kind:
			out.append(String(id))
	out.sort()
	return out


## Tells every job that has ended and was not told yet: told = true, the save is marked dirty, then
## Events.timer_finished(id). A handler may remove or start jobs while it hears the event.
func check() -> void:
	var t := now()
	var jobs := _jobs()
	for id: Variant in jobs.keys():
		var j: Variant = jobs.get(id)
		if not j is Dictionary or (j as Dictionary).get("told", false) == true:
			continue
		if t >= float((j as Dictionary).get("start", 0.0)) + float((j as Dictionary).get("len", 0.0)):
			(j as Dictionary)["told"] = true
			Save.mark_dirty()
			Events.timer_finished.emit(String(id))


## For the tests, when they end: the real clock again, and seen brought back to the real now, so a pretend clock that
## ran ahead leaves no future seen in the test save (later jobs in the same run would wait). Lowering seen marks the
## save dirty, so the file gets the real value too.
func use_real_clock() -> void:
	clock = Callable(Time, REAL_CLOCK_METHOD)
	var real := Time.get_unix_time_from_system()
	if float(Save.timers.get("seen", 0.0)) > real:
		Save.timers["seen"] = real
		Save.mark_dirty()


func _on_save_loaded() -> void:
	get_tree().create_timer(1.0, true, false, true).timeout.connect(check)


func _jobs() -> Dictionary:
	if not Save.timers.get("jobs") is Dictionary:
		Save.timers["jobs"] = {}
	return Save.timers["jobs"]


func _job(id: String) -> Dictionary:
	var j: Variant = _jobs().get(id)
	return j if j is Dictionary else {}


func _end(id: String) -> float:
	var j := _job(id)
	return float(j.get("start", 0.0)) + float(j.get("len", 0.0))


static func _kind(id: String) -> String:
	return id.get_slice(":", 0)


func _kind_known(kind: String) -> bool:
	var jobs: Variant = (Data.b.get("timers", {}) as Dictionary).get("jobs", {})
	return kind != "" and jobs is Dictionary and (jobs as Dictionary).has(kind)


func _check_every_s() -> float:
	return float((Data.b.get("timers", {}) as Dictionary).get("check_every_s", 1.0))
