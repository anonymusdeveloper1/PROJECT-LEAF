extends Node
## The event board (autoload "Events"; docs/ARCHITECTURE.md part 4, Observer): game-wide news as typed signals. No logic
## and no state live here.
## Used by: the senders (enemy.gd, fight.gd, raids.gd, quality.gd; save.gd and data.gd for the money and the Bag) and
## the listeners (the tests now, the HUD from H2, later Audio, the Hearthtree goal lists, the raid meter, hints).
## Uses: nothing.
## Rules:
##   - an event says what happened; it never asks for an answer, and the sender never depends on who listens
##   - inside one thing, parts talk through that thing's own signals; only game-wide news goes on this board
##   - a new event is added here and to ARCHITECTURE.md part 4 in the same change; one owner edits this file at a time
##   - the senders call these from other scripts, so the "declared but never used" warning is switched off below

@warning_ignore_start("unused_signal")

## An enemy's health reached 0 (enemy.gd _die), once per enemy. kind: its id ("thornling"); at: where it fell.
signal enemy_died(kind: String, at: Vector3)
## An enemy took damage (enemy.gd: an arrow, tower bolt, skill or blast landing, or a burn tick). amount: after armour.
signal damage_dealt(target: Node, amount: float)
## Leaves, timber or shards changed (save.gd); total is the new amount.
signal currency_changed(id: String, total: int)
## Something went into the Bag or was unlocked (data.gd, save.gd); amount is how many were added.
signal item_gained(kind: String, id: String, amount: int)
## The Bag's contents changed (data.gd, save.gd).
signal bag_changed()
## A Raid Mission wave began (fight.gd _start_wave); n counts from 1.
signal wave_started(n: int)
## A Raid Mission wave ended (fight.gd): held when it was beaten, not held when the camp fell during it.
signal wave_ended(n: int, held: bool)
## A Random Raid began, at its warning (raids.gd; the same moment as raids.raid_started). spec: the raid's roster.
signal raid_started(spec: Dictionary)
## A Random Raid ended (raids.gd finish; the same moment as raids.raid_ended).
signal raid_ended(won: bool, perfect: bool)
## A Raid Mission was won, a first win or a replay (fight.gd _win). n: the mission's index (0 = the first).
signal mission_won(n: int)
## A building went up a level. (Not sent yet: it comes with the building windows.)
signal building_upgraded(id: String, level: int)
## A Timers job ended. (Not sent yet: Timers arrives in H3.)
signal timer_finished(job_id: String)
## The graphics level changed (quality.gd, with its own `changed`): 0 Low, 1 Medium, 2 High.
signal quality_changed(level: int)
## A save was loaded or upgraded (save.gd).
signal save_loaded()

## Progress in the current Raid Mission wave or the whole Random Raid attack changed (fight.gd).
signal fight_progress(done: int, total: int)
## The cat mounted or dismounted (commands/ride.gd).
signal riding_changed(on: bool)
## The mount was knocked out or got back up (mount.gd).
signal mount_down_changed(down: bool)
## Defence placement started or ended (defences.gd); kind is empty when done.
signal placing_changed(kind: String)
## The cat entered or left an expedition (burrow_run.gd and main.gd).
signal area_changed(inside: bool)
## A boss appeared or its encounter ended (fight.gd, raids.gd, burrow_run.gd); null clears the bar.
signal boss_changed(boss: Node)
## The campfire took damage (fight.gd damage_fire).
signal campfire_hit()

@warning_ignore_restore("unused_signal")
