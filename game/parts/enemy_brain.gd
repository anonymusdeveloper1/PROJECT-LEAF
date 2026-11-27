extends Node
## An enemy's Brain (H6 Stage 1, 27 Nov 2026; docs/ARCHITECTURE.md part 4, State): it picks the small state script for
## the enemy's current `state` word and runs it each frame. A child named "Brain" of the enemy; no class_name.
## Used by: enemy._physics_process (step, sleep_step), enemy.hit and enemy._burn_hurt (check_enrage) and _die (enter_down).
## Rules:
##   - The Brain only READS `enemy.state` (the word the tests and hit() assign directly). change_state(name) sets it.
##     "down" is the Brain's own and is never written into `state`.
##   - Name to state: one ActionState for the 15 action names; blink, dig, pounce, dash_windup, dash, emerge, windup,
##     charge, daze and flee each their own; every other name is the Roam state. States are made the first time they
##     are needed, per enemy.
##   - step() runs one state and returns the walking speed of the frame (the squad formation can change it).
##   - The Burrow boss's enrage check keeps its H5 condition and is called from hit and _burn_hurt only.

const StateBase := preload("res://states/enemy/enemy_state.gd")
const ActionState := preload("res://states/enemy/action_state.gd")
const BlinkState := preload("res://states/enemy/blink_state.gd")
const DigState := preload("res://states/enemy/dig_state.gd")
const PounceState := preload("res://states/enemy/pounce_state.gd")
const DashWindupState := preload("res://states/enemy/dash_windup_state.gd")
const DashState := preload("res://states/enemy/dash_state.gd")
const EmergeState := preload("res://states/enemy/emerge_state.gd")
const WindupState := preload("res://states/enemy/windup_state.gd")
const ChargeState := preload("res://states/enemy/charge_state.gd")
const DazeState := preload("res://states/enemy/daze_state.gd")
const FleeState := preload("res://states/enemy/flee_state.gd")
const SleepState := preload("res://states/enemy/sleep_state.gd")
const DownState := preload("res://states/enemy/down_state.gd")
const RoamState := preload("res://states/enemy/roam_state.gd")

## The state words that all run the one ActionState (a moment of impact inside each).
const ACTION_NAMES: Array[String] = ["attack", "slam", "roar", "grab", "spores", "heal", "cast", "orbs", "hex", "summon",
	"spit", "burst", "drum", "lob", "bite"]
## The state words that each have their own state script.
const OWN_NAMES: Array[String] = ["blink", "dig", "pounce", "dash_windup", "dash", "emerge", "windup", "charge", "daze",
	"flee"]

var e: EnemyNode                           # the enemy (enemy.gd) this part belongs to; set once by bind_enemy
var spd := 0.0                            # this frame's walking speed (the Roam state's squad steering may change it)
var _states: Dictionary = {}              # state key -> state object, made lazily
var _cur: StateBase                      # the state running now
var _down := false                        # the enemy has died


func bind_enemy(enemy: Node3D) -> void:
	e = enemy as EnemyNode


## Sets the enemy's state word (the H5 code still assigns `state` directly in many places; both ways work).
func change_state(state_name: String) -> void:
	e.state = state_name


func is_down() -> bool:
	return _down


## The enemy died: the Brain goes to Down (internally only; `enemy.state` is left as it is).
func enter_down() -> void:
	_down = true
	_switch(_state_by_key("down"))


## One frame of the awake enemy: runs the state its `state` word names and returns the walking speed to use.
func step(delta: float, speed: float) -> float:
	spd = speed
	var st: StateBase = _state_for(String(e.state))
	_switch(st)
	var next: String = st.update(delta)
	if next != "":
		change_state(next)
	return spd


## One frame of a sleeping enemy (the Sleep state), at the place in the frame where H5 ran its sleep tick.
func sleep_step(delta: float) -> void:
	var st: StateBase = _state_by_key("sleep")
	_switch(st)
	st.update(delta)


## A Burrow boss at low health (mods.enrage_at) enrages: the exact H5 condition, called from hit and _burn_hurt.
func check_enrage() -> void:
	if not e.enraged and e.mods.has("enrage_at") and e.hp > 0.0 and e.hp <= e.max_hp * float(e.mods["enrage_at"]):
		e._enrage()


func _switch(st: StateBase) -> void:
	if st == _cur:
		return
	if _cur != null:
		_cur.exit()
	_cur = st
	_cur.enter()


func _state_for(state_name: String) -> StateBase:
	return _state_by_key(_key_of(state_name))


func _state_by_key(key: String) -> StateBase:
	if not _states.has(key):
		var st: StateBase = _make(key)
		st.bind(e, self)
		_states[key] = st
	return _states[key] as StateBase


## The key of the state object a state word runs (the action words share one; unknown words are the road walk).
func _key_of(state_name: String) -> String:
	if state_name in ACTION_NAMES:
		return "action"
	if state_name in OWN_NAMES:
		return state_name
	return "roam"


func _make(key: String) -> StateBase:
	match key:
		"action":
			return ActionState.new()
		"blink":
			return BlinkState.new()
		"dig":
			return DigState.new()
		"pounce":
			return PounceState.new()
		"dash_windup":
			return DashWindupState.new()
		"dash":
			return DashState.new()
		"emerge":
			return EmergeState.new()
		"windup":
			return WindupState.new()
		"charge":
			return ChargeState.new()
		"daze":
			return DazeState.new()
		"flee":
			return FleeState.new()
		"sleep":
			return SleepState.new()
		"down":
			return DownState.new()
	return RoamState.new()
