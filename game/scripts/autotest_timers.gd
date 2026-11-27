## Timers checks for autotest.gd (`-- --autotest --fresh --timers`; core/timers.gd, H3 26 Nov 2026).
## A pretend clock (a method of this node: a lambda would copy its locals and not see the test move the clock) stands in
## for the real one: base + offset, held still between moves, with base a whole second just past the real now and the
## save's seen. The jobs use the kind "cook" with ids no handler acts on ("cook:autotest_*"; the pot's job is
## "cook:pot"). At the end every test job is removed and use_real_clock() puts the real clock and seen back, so no
## future seen stays in the test save.
## Checks: start, progress, left, shorten, remove, job data, ids, an unknown kind; a job that ends "while the game is
## closed" (save, load, move the clock) is told once and stays told after a reload; jobs wait when the clock is set back;
## resume and focus run a check; the periodic check; seen alone never marks the save dirty; Unix seconds round-trip.
extends Node

const AutotestScript := preload("res://scripts/autotest.gd")
const MainScript := preload("res://scripts/main.gd")

const A := "cook:autotest_a"
const B := "cook:autotest_b"
const C := "cook:autotest_c"
const D := "cook:autotest_d"
const E := "cook:autotest_e"
const F := "cook:autotest_f"
const ALL := [A, B, C, D, E, F]

var t: AutotestScript
var main: MainScript

var _base := 0.0
var _offset := 0.0
var _told: Array = []


## The pretend clock (Timers.clock while this test runs).
func _clock() -> float:
	return _base + _offset


func _on_finished(id: String) -> void:
	_told.append(id)


## Two Unix times are the same (to a millisecond). is_equal_approx is relative (1e-5 of the value), which at 1.8e9 s
## lets about 5 hours through, so it must never compare clock readings or starts.
static func _same_time(a: float, b: float) -> bool:
	return absf(a - b) < 0.001


func run() -> bool:
	var real := Time.get_unix_time_from_system()
	_base = ceilf(maxf(real, float(Save.timers.get("seen", 0.0)))) + 1.0
	_offset = 0.0
	Timers.clock = _clock
	Events.timer_finished.connect(_on_finished)
	var ok := t._expect("the pretend clock is in use (now() = base + offset)", _same_time(Timers.now(), _base), {"now": Timers.now(), "base": _base})
	ok = _check_jobs() and ok
	ok = await _check_closed() and ok
	ok = _check_clock_back() and ok
	ok = _check_notifications() and ok
	ok = await _check_periodic() and ok
	ok = _check_dirty() and ok
	ok = await _check_round_trip() and ok
	# put everything back: no test job, the real clock, and seen at the real now
	for id: String in ALL:
		Timers.remove(id)
	Events.timer_finished.disconnect(_on_finished)
	Timers.use_real_clock()
	Save.save_game(true)
	var now_real := Time.get_unix_time_from_system()
	ok = t._expect("at the end the real clock is back, seen is not in the future and no test job is left",
		float(Save.timers["seen"]) <= now_real + 0.001 and absf(Timers.now() - now_real) < 2.0 and Timers.ids("cook").is_empty(),
		{"seen": Save.timers["seen"], "real": now_real}) and ok
	return ok


# ---------------------------------------------------------------- start, progress, left, shorten, remove, data
func _check_jobs() -> bool:
	var ok := t._expect("an unknown kind is refused", not Timers.start("nope:1", 10.0) and not Timers.has("nope:1")
		and not Timers.start("", 10.0))
	ok = t._expect("start: a known kind starts at now, not done", Timers.start(A, 60.0, {"recipe": "health_potion"}) and Timers.has(A)
		and not Timers.done(A) and is_equal_approx(Timers.left(A), 60.0) and is_zero_approx(Timers.progress(A))
		and _same_time(float(Save.timers["jobs"][A]["start"]), _base) and Save.timers["jobs"][A]["told"] == false) and ok
	_offset = 15.0
	ok = t._expect("progress and left follow the clock", is_equal_approx(Timers.left(A), 45.0) and is_equal_approx(Timers.progress(A), 0.25),
		{"left": Timers.left(A), "progress": Timers.progress(A)}) and ok
	Timers.shorten(A, 20.0)
	ok = t._expect("shorten: the job ends sooner", is_equal_approx(Timers.left(A), 25.0) and is_equal_approx(Timers.progress(A), 15.0 / 40.0),
		{"left": Timers.left(A)}) and ok
	Timers.shorten(A, 1000.0)
	ok = t._expect("shorten never goes below the time already run (it is done now)", Timers.done(A) and is_zero_approx(Timers.left(A))
		and is_equal_approx(Timers.progress(A), 1.0) and is_equal_approx(float(Save.timers["jobs"][A]["len"]), 15.0)) and ok
	Timers.shorten(A, 5.0)
	ok = t._expect("shortening a done job changes nothing", is_equal_approx(float(Save.timers["jobs"][A]["len"]), 15.0)) and ok
	var data := Timers.job_data(A)
	data["recipe"] = "changed"
	ok = t._expect("job_data is a copy of the job's data", String(Timers.job_data(A).get("recipe", "")) == "health_potion") and ok
	Timers.set_job_data(A, "wet_until", 123.0)
	ok = t._expect("set_job_data changes the job's data", is_equal_approx(float(Timers.job_data(A).get("wet_until", 0.0)), 123.0)
		and String(Timers.job_data(A).get("recipe", "")) == "health_potion") and ok
	Timers.start(B, 30.0)
	var cook_ids := Timers.ids("cook")
	ok = t._expect("ids(kind) lists that kind's jobs, sorted", cook_ids.has(A) and cook_ids.has(B) and cook_ids.find(A) < cook_ids.find(B)
		and not Timers.ids("crop").has(A), {"cook": cook_ids}) and ok
	var told_before := _told.size()
	Timers.remove(A)
	ok = t._expect("remove: the job is gone and nothing is sent", not Timers.has(A) and not Timers.done(A) and is_zero_approx(Timers.left(A))
		and is_zero_approx(Timers.progress(A)) and Timers.job_data(A).is_empty() and _told.size() == told_before) and ok
	Timers.start(B, 90.0)
	ok = t._expect("start replaces a job with the same id", is_equal_approx(Timers.left(B), 90.0)) and ok
	Timers.remove(B)
	var was: Callable = Timers.clock
	Timers.clock = Callable()
	var t_real := Timers.now()
	var fell_back := Timers.clock.is_valid() and t_real >= Time.get_unix_time_from_system() - 1.0
	Timers.clock = was
	ok = t._expect("a clock that is gone falls back to the real one", fell_back) and ok
	return ok


# ---------------------------------------------------------------- a job that ends while the game is closed
func _check_closed() -> bool:
	_offset = 100.0
	Timers.start(C, 30.0, {"recipe": "cooked_fish"})
	Save.save_game(true)
	Save.load_game()
	await get_tree().process_frame
	var ok := t._expect("the job is still there after a save and a reload", Timers.has(C) and not Timers.done(C)
		and is_equal_approx(Timers.left(C), 30.0) and String(Timers.job_data(C).get("recipe", "")) == "cooked_fish", {"left": Timers.left(C)})
	_told.clear()
	_offset = 200.0                                    # the game was "closed" past the job's end
	Timers.check()
	ok = t._expect("check() tells the job once with its id", _told == [C] and Timers.done(C) and Save.timers["jobs"][C]["told"] == true,
		{"told": _told}) and ok
	Timers.check()
	ok = t._expect("a second check() sends nothing", _told == [C], {"told": _told}) and ok
	Save.save_game(true)
	Save.load_game()
	await get_tree().process_frame
	Timers.check()
	ok = t._expect("after a save and a reload the job is still told (nothing is sent again)", Timers.has(C)
		and Save.timers["jobs"][C]["told"] == true and _told == [C], {"told": _told}) and ok
	Timers.remove(C)
	return ok


# ---------------------------------------------------------------- the clock set back
func _check_clock_back() -> bool:
	var at := 300.0
	_offset = at
	Timers.start(D, 60.0)
	_offset = at + 10.0
	var left0 := Timers.left(D)                         # seen = T + 10
	var ok := t._expect("the job has run 10 s", is_equal_approx(left0, 50.0), {"left": left0})
	_offset = at - 100.0
	ok = t._expect("the clock set back 110 s: left does not change", is_equal_approx(Timers.left(D), left0)
		and _same_time(Timers.now(), _base + at + 10.0), {"left": Timers.left(D)}) and ok
	Timers.start(E, 20.0)
	ok = t._expect("a job started while the clock is set back starts at seen and waits",
		_same_time(float(Save.timers["jobs"][E]["start"]), _base + at + 10.0) and is_equal_approx(Timers.left(E), 20.0)) and ok
	_offset = at + 5.0
	ok = t._expect("the clock back at T + 5 (still before seen): left does not change", is_equal_approx(Timers.left(D), left0)) and ok
	_offset = at + 20.0
	ok = t._expect("the clock past seen again (T + 20): left drops by 10", is_equal_approx(Timers.left(D), left0 - 10.0)
		and is_equal_approx(Timers.left(E), 10.0), {"left": Timers.left(D)}) and ok
	Timers.remove(D)
	Timers.remove(E)
	return ok


# ---------------------------------------------------------------- resume and focus run a check
func _check_notifications() -> bool:
	_offset = 400.0
	Timers.start(D, 5.0)
	_told.clear()
	_offset = 410.0
	Timers.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	var ok := t._expect("NOTIFICATION_APPLICATION_RESUMED runs a check at once", _told == [D], {"told": _told})
	Timers.start(E, 5.0)
	_told.clear()
	_offset = 420.0
	Timers.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	ok = t._expect("NOTIFICATION_APPLICATION_FOCUS_IN runs a check at once", _told == [E], {"told": _told}) and ok
	Timers.remove(D)
	Timers.remove(E)
	return ok


# ---------------------------------------------------------------- the periodic check
func _check_periodic() -> bool:
	# the reloads in _check_closed left a check pending 1 s after save_loaded: let it pass first, so only _process can
	# tell this job
	await get_tree().create_timer(1.2, true, false, true).timeout
	_offset = 500.0
	Timers.start(F, 2.0)
	_told.clear()
	_offset = 503.0
	var waited := 0.0
	var every := float(Data.b["timers"]["check_every_s"])
	while not _told.has(F) and waited < every + 1.5:
		await get_tree().create_timer(0.1, true, false, true).timeout
		waited += 0.1
	var ok := t._expect("the periodic check tells an ended job within check_every_s (%.1f s)" % every, _told == [F],
		{"told": _told, "waited": waited})
	Timers.remove(F)
	return ok


# ---------------------------------------------------------------- the dirty flag
func _check_dirty() -> bool:
	_offset = 600.0
	Save.save_game(true)
	var clean := not Save._dirty
	_offset = 700.0
	Timers.now()
	Timers.check()
	var ok := t._expect("raising seen alone never marks the save dirty", clean and not Save._dirty
		and _same_time(float(Save.timers["seen"]), _base + 700.0), {"dirty": Save._dirty})
	var marks: Array = []
	Timers.start(A, 50.0)
	marks.append(Save._dirty)
	Save.save_game(true)
	Timers.shorten(A, 5.0)
	marks.append(Save._dirty)
	Save.save_game(true)
	Timers.set_job_data(A, "k", 1)
	marks.append(Save._dirty)
	Save.save_game(true)
	Timers.remove(A)
	marks.append(Save._dirty)
	ok = t._expect("start, shorten, set_job_data and remove mark the save dirty", marks == [true, true, true, true], {"marks": marks}) and ok
	return ok


# ---------------------------------------------------------------- Unix seconds through the JSON file (risk 5)
func _check_round_trip() -> bool:
	_offset = 800.123
	Timers.start(B, 77.5)
	var start := float(Save.timers["jobs"][B]["start"])
	Save.save_game(true)
	Save.load_game()
	await get_tree().process_frame
	var back := float(Save.timers["jobs"].get(B, {}).get("start", 0.0))
	var ok := t._expect("a saved start (Unix seconds with decimals) comes back within 0.01 s", absf(back - start) < 0.01
		and is_equal_approx(float(Save.timers["jobs"][B]["len"]), 77.5), {"saved": start, "loaded": back})
	Timers.remove(B)
	return ok
