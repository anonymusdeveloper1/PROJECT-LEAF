extends RefCounted
## H4: the confirm window (the window kit): a small card that asks before a rule runs. A building's Upgrade opens it
## (building_window.gd, ask_upgrade); H6's per-piece window can reuse it, since it takes any title, lines and price. It
## opens through the card system like the Settings window (it has a key and a builder), so it keeps the dialog's width,
## its X and its dim. The HUD makes one (hud.confirm).
##   ask(a)   a: {"title": String,
##                "lines": Array (what it gives, one short line each; the first letter is made a capital here),
##                "cost": Dictionary (its price; {} for none),
##                "ok_label": String (the Confirm button's word; the word "confirm" when missing),
##                "on_confirm": Callable (runs the rule),
##                "back": Callable (reopens the window it came from; may be an empty Callable),
##                "reason": Callable giving a String ("" when the rule may run now, else why not; may be empty)}
## The lines are small rows, the reason (when there is one) a plain row under them. The footer holds the price (red
## when it is short) and two buttons: Cancel in the live grey and Confirm in green (grey and off while the price is
## short or there is a reason).
## Confirm runs the rule, then goes back to the window it came from, at its new level; Cancel only goes back (the
## owner's answer, 26 Nov 2026, Q3 a). Without a back both just close. The X, a tap outside, Android's back button and
## Escape close everything, as on every dialog. A wave blanks it, as it blanks every station card (its key is not
## exempt): no footer, so no Confirm.
## Its words come from data (balance.json "windows", Data.word). Called by: the building windows (ui/windows/), the
## tests. Uses: the HUD's card (show_card, hide_card, refresh_card, card_ring), Data.

var hud
var key := "confirm"
var builder: Callable = spec                          # a ring in the card system has a builder (this has no marker)
var _ask: Dictionary = {}                             # what the open question is (see above)


func _init(owner_hud = null) -> void:
	hud = owner_hud


## Asks: keeps `a`, then shows the window (or redraws it, when it already shows).
func ask(a: Dictionary) -> void:
	_ask = a.duplicate()
	if hud == null:
		return
	if hud.card_ring() == self:
		hud.refresh_card()                            # show_card does nothing for the card that already shows
	else:
		hud.show_card(self)


func spec() -> Dictionary:
	var rows: Array = []
	var lines: Variant = _ask.get("lines", [])
	if lines is Array:
		for line in lines:
			var s := String(line)
			if s != "":
				rows.append({"text": s.substr(0, 1).to_upper() + s.substr(1), "small": true})
	var why := _reason()
	if why != "":
		rows.append({"text": why})
	var cost := _cost()
	var ok_label := String(_ask.get("ok_label", ""))
	if ok_label == "":
		ok_label = Data.word("confirm")
	return {"title": String(_ask.get("title", "")), "sub": "", "rows": rows,
		"footer": {"text": "", "note": "", "cost": cost, "buttons": [
			{"label": Data.word("cancel"), "tone": "grey", "enabled": true, "action": _cancel},
			{"label": ok_label, "tone": "green", "enabled": why == "" and Data.can_afford(cost), "action": _confirm}]}}


## Confirm: the rule runs, then back to the window it came from (or the dialog closes). When it stopped being possible
## since the window was drawn (the price, a reason), nothing runs and the window shows why.
func _confirm() -> void:
	if _reason() != "" or not Data.can_afford(_cost()):
		if hud != null:
			hud.refresh_card()
		return
	var run := _callable("on_confirm")
	if run.is_valid():
		run.call()
	_go_back()


## Cancel: back to the window it came from (or the dialog closes); nothing runs.
func _cancel() -> void:
	_go_back()


func _go_back() -> void:
	var back := _callable("back")
	if back.is_valid():
		back.call()
	elif hud != null:
		hud.hide_card()


## Why the rule may not run now ("" when it may).
func _reason() -> String:
	var r := _callable("reason")
	return String(r.call()) if r.is_valid() else ""


func _cost() -> Dictionary:
	var c: Variant = _ask.get("cost", {})
	return c if c is Dictionary else {}


func _callable(k: String) -> Callable:
	var c: Variant = _ask.get(k, Callable())
	return c if c is Callable else Callable()
