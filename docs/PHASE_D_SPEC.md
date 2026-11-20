# Phase D: after the missions. Gloom Raids and keeping the camp up

**The user's decisions of 18 November 2026 (override anything below):** the Burrows (Phase E) are free and unlimited
to enter, so the burrow keys a raid pays are a small bonus, never a ticket. The Moss Warden stays home and guards the
camp (in raids too). Food matters from the start (Phase C: the garden is mission 1's gift; food brings a knocked-out
mount back). The user tests on the phone: build it complete and playable, with light testing.

Final spec for Project LEAF, Draft 7, Phase D. Written 17 November 2026 for building in `game/` (Godot 4.7.2).

Where it comes from: three designs were judged (gameplay first, lean and safe first, player delight first). This spec
is built on the **player delight** design. It keeps the lean design's `fight.gd` skeleton, its wreck fix, the 95% bump
cap and the no-clock grep guard. It takes the gameplay design's ready bonus, seeded raids, quiet saves and replay
snapshot, with its Moth Lantern and Bramble Snare as an optional late step. Every violation the judges found is
removed:
- every warning is 30-60 s
- the damage a raid does is saved at every wave and when the app pauses, so a quit cannot erase it
- a lost raid never leaves ashes and never takes anything
- no raccoons in raids
- no "village" wording
- the in-world meter is a model swap of the existing signpost, so Phase D adds no new world spot

Choices that are Claude's and still open are marked *(proposal)*. Section 25 lists the questions for the user.
`docs/PHASE_C_SPEC.md` did not exist when this was written (checked 17 November 2026). Phase C is reached only through
the named hooks in section 22.

---

## 0. The user's rules, and how Phase D keeps each one

| Rule (non-negotiable) | How Phase D keeps it |
|---|---|
| One cat protecting its campfire camp. Not Clash of Clans: no villagers, residents, workers, expeditions or production timers | Raids come to the camp. The cat, its pet, its mount and (later) the guardian defend it. Nothing is produced over time. The Gloom meter is a threat, not a producer. |
| **Nothing happens while the game is closed**: no offline fights, losses or progress | The meter fills only from live, non-idle play (each frame's delta clamped to 0.1 s) and from things the cat does. No script reads the wall clock. Nothing saved is a time. A raid that was coming or under way comes back **at its warning** (section 13). |
| When every mission is won, random attacks keep coming and the camp must be kept in good condition | Raids repeat for as long as the player plays. The kind, trails and leader are random. Ruins, wrecked defences and building wear carry over between raids until the player fixes them (section 11). |
| Draft 7 raids: meter, horn, warning of 30-60 s, scaled to the camp | Section 4 (meter), section 5 (warning: 45 s, 60 s for the first raid and elite raids, never under 30 or over 60), section 7 (scaling). |
| Raid types: siege, sneak, sky, rare elite | Section 6. |
| Repelling pays Gloom shards; a perfect defence pays a bonus; a lost raid leaves ruins to repair, **never more** | Section 9 (pay) and section 10 (loss). A loss takes no leaves, timber, shards, levels, items or pieces, and does not leave the campfire as ashes. |
| Raids damage buildings, barricades and towers and knock the guardian down; bigger camps draw bigger raids | Section 11 (damage that stays), section 7 (camp score), section 22 (guardian hook). |
| Burrows open after the last mission; keys must not refill while the game is closed | Phase E. Phase D gives it keys earned only by holding raids (section 9), never from a timer. |
| Looks-only monetisation, never pay-to-win | Shards are earned only and are never sold. Nothing priced in shards is ever sold for money. There is no paid warning skip, repair, revive or raid (section 12). |
| Runs on low-end phones | Live enemies capped by Quality level, no new lights, rout and shard pickups capped (section 20). |
| No menus: the cat walks onto rings and cards pop up | Everything is on the signpost card ("The Watch"), the shop, the building cards and the Stable and Nest cards, plus a small meter at the HUD's top right. |
| Characters from the user's Meshy, props from Claude in Blender | One new character, the Gloom Herald (section 18), with a placeholder until it comes. Props in section 19. |

---

## 1. Design pillars

1. **Readable.** Before a raid arrives, the game says what it is, where it comes from, how strong it is and how long
   the player has. It says this three ways:
   - a banner
   - the world: the Gloom mist and glowing eyes roll back onto the trail, and the signpost's horn crystal glows
   - the HUD: a countdown plus an arrow to the trail

   The sneak raid hides its trail, but it says that it is hiding, and it shows the trail with 15 s left.
2. **Fair.** A raid never starts while the player is idle, never as the game opens, and never during another fight.
   The cat's own upgrades never make raids harder: only the camp grows the raids, and slower than the camp's power
   grows. Losing makes the next raid gentler.
3. **Short, with a climax.** A raid is 3 waves, about 3-4 minutes. The last wave is led by the Gloom Herald, or by a
   boss in an elite raid. Beat the leader and the raid breaks: the rest flee and drop their leaves.
4. **Satisfying wins.** Petals burst off the raid's trail, shards stream to the cat while the counter ticks up, and a
   perfect defence gets a gold banner, a streak and ribbons on the signpost.
5. **Never punishing.** A loss leaves only damage to repair. Repairs are capped in price and one tap away. There is no
   leaves tax, nothing is stolen and the fire does not turn to ashes.
6. **Upkeep is a moment, not a chore.** "Mend all" fixes everything the player can afford in one tap, and each fixed
   thing springs back with a flower ring, one after another across the camp.

---

## 2. A raid's life (what the player sees)

1. **Calm.** After the last mission is won, the signpost grows a horn and a crystal cage (the Watch). A banner and a
   tip explain it. The crystal fills slowly while the player plays. The HUD top right shows `Gloom 62%`.
2. **Stir (75%).** Toast: "The Gloom stirs in the woods...". The next raid is planned now: kind, trails, level and
   leader. With the Tracker upgrade, the Watch card and the HUD already name it.
3. **Horn (100%).** The signpost's horn blows itself (a bounce, a violet shockwave, the horn sound). Banner: "A Gloom
   Raid is coming!", with a sub such as "Siege raid · level 8 · from Fernwood · 45 s to get ready". Mist and eyes roll
   back onto the raid's trail(s) (`world.gloom_returns`). A gold arrow points at the trail for 6 s.
4. **Warning (45 s; 60 s for the first raid and elite raids).** The camp is still safe and every card works. The
   signpost card offers "Meet them now", the camp check with "Mend all", and "What's coming". The countdown stops while
   the player has been idle for 20 s or more, so the Gloom waits for the player. At 10 s left: a toast "10 seconds!"
   and the arrow again.
5. **Waves 1-3.** These run like mission waves, with a 10 s breather between them. The camp is unsafe during a wave,
   as today.
6. **The leader.** In wave 3 the Gloom Herald (or the elite raid's boss) walks in mid-wave, with the boss bar. The
   Herald drums to speed up and toughen the raiders near it.
7. **Rout.** When the leader falls, every raider still on the field flees, drops its leaves and leaves petals behind.
   Banner: "The raid breaks!"
8. **Pay.** Banner: "Raid repelled!" or "Perfect defence!", for example "+27 shards · +220 leaves · +5 timber · perfect
   streak 3". Petals lift off the trail and shards fly to the cat.
9. **Upkeep.** If anything was damaged, a tip arrow points at the signpost: "Mend the camp before the next raid." The
   meter starts again from 0.

A **lost raid** (the camp falls) ends at step 5 or 6. Banner, in a soft violet and not red: "The Gloom broke through",
with the sub "2 buildings in ruins · 3 defences wrecked · nothing else was lost". The fire relights at once. The next
raid is a little gentler.

---

## 3. Words used in this spec

- **Raids open**: every mission has been won (`Data.raids_open()`, true when `Data.next_mission() >=
  Data.mission_count()`).
- **The plan**: the next raid as chosen at 75% (`Save.raids.plan`).
- **Pending**: the meter is full and the raid is announced but not over. It stays pending through the warning, the
  waves and any app restart, until the raid ends.
- **The run**: the progress of the raid now pending (`Save.raids.run`): waves held, buildings lost, the fire's state.
- **Wear**: the share of a standing building's health that raids took and that is not patched yet (`Save.wear`).
- **Wreck**: a defence piece kept damaged (`Save.placed[i].wreck`, as today).
- The balance key `raid` keeps meaning the **mission camp-falls** numbers. Everything new lives under `gloom_raids`.

---

## 4. The Gloom meter

- **Range** 0-100 (`gloom_raids.meter.full`), saved in `Save.raids.meter`. It exists only once raids are open.
- **Passive fill**: `per_minute` = 10 points a minute of live play, so about 10 minutes from empty to full. It fills
  only when **all** of these hold:
  - no fight is on (`not fight.active`; a mission replay and a raid both count as fights)
  - no raid is pending
  - the campfire is not ashes (`not Save.fire_ruined`)
  - the player is not idle: a touch in the last `idle_after` = 45 s (`raids.idle_t`)
  - the cat is up (`player.hp > 0`)
  - `main.frozen` is off
  - the cat is not in the Burrows (Phase E: `main.get("area") == null`)
- **Clamped delta**: each frame adds at most `max_delta` = 0.1 s. A resume from the Android background, or a stall,
  can never add time.
- **Action points** (things the cat does in play): a replay chapter held 6, a replay won 12; from Phase C a harvest 2,
  a dish 3, a fish 2; from Phase E a Burrows run 15. Each feature calls `main.raids.add_gloom("<action>")`. Action
  points **never fill the meter past `bump_cap` = 95**, so the horn always sounds while the player is there playing.
  Because of the cap, a raid can never become pending during a mission replay.
- **Stir** at `stir_at` = 75: the plan is made (section 6) and saved. Toast "The Gloom stirs in the woods...". With
  Tracker, the plan's trail flickers its mist eyes for 2 s (`world.gloom_returns` then `world.settle_gloom` after 2 s).
- **Full** (100): the raid becomes pending, with `warn_left` = the warning's length (section 5). The warning starts as
  soon as it is allowed. It is not allowed while: a fight is on, the fire is ashes, the cat is down, the cat is in the
  Burrows, or a Phase C mini-game is running (`main.get("busy_minigame") == true`). Until then the meter stays full,
  and the HUD and the card say why.
- **Sound the horn** *(proposal)*: from `call_from` = 50, the Watch card offers "Sound the horn". The meter jumps to
  full, the plan is made if it was not yet, and the warning is 30 s (45 with Lookout). A player who enjoys raids can
  have one about every 5 minutes; a player who doesn't is never rushed.
- **After a raid** (won or lost) the meter is set to 0, which gives about 10 minutes of calm by itself.
- **The first raid**: when the last mission is won for the first time, and when an old save with every mission won is
  loaded, the meter is set to `first_fill` = 70. The first raid therefore comes about 3 minutes later (or at once with
  "Sound the horn"). It is always a siege, 2 levels below the camp's raid level, with a 60 s warning and tips.
- **Saving the meter**: quietly (`Save.save_game(true)`: no `changed` signal, so the open card is not rebuilt) each
  time it crosses a multiple of 10, at stir, at full, when the app pauses or loses focus (`main._notification`), and at
  every raid start and end. A quit can lose up to 10 points of the meter. It can never gain anything.

---

## 5. The warning (always 30-60 s)

| Setting | Seconds |
|---|---|
| Normal | 45 |
| First raid ever | 60 |
| Elite raid | 60 |
| Called early ("Sound the horn") | 30 |
| Lookout upgrade | +15, **capped at 60** (normal 60, called 45, first and elite stay 60) |
| After a restart | the saved seconds left, clamped to 30-60 |
| Sneak trail shown | at 15 s left (from the start with Tracker) |
| Idle hold | the countdown stops while the player has been idle for 20 s or more |
| "10 seconds!" toast and arrow | at 10 s left |

- The warning is the existing breather: `fight.start_raid(spec, warn_s)` sets `active = true`, `in_wave = false` and
  `_breather = warn_s`. When it runs out, `_physics_process` calls `_start_wave(wave + 1)` as it does today. During the
  warning the camp is safe (`inside_camp` is true while `in_wave` is false), every card works, and the Wishing Well
  works.
- "Meet them now" on the signpost is the existing `fight.next_phase_now()` (sets `_breather = 0.01`).
- The idle hold does not add warning time: it stops the clock while nobody is playing. It also applies to the 10 s
  breathers between waves.
- When the warning starts (`raids.present_warning()`):
  - `Sfx.play("raid_horn")` (placeholder until the file exists: `horn` at +4 dB, played twice 0.6 s apart)
  - the signpost horn's blow: `Fx.boing` on the part `horn`, plus `Fx.shockwave` at the signpost, violet, 2 m
  - `hud.banner` (section 14.6)
  - `world.gloom_returns(ln)` for each raid trail (a hidden sneak raid skips this until it is revealed)
  - `hud.point_at(trail point, 6 s)`, where the point is `world.trail_point(ln, 0.55 * world.trail_length(ln))`
  - the camera pulls in to fight distance by itself (it already does while `fight.active`)
- The sneak reveal: toast "There! They're coming down Bandit Thicket!", gloom on the trail, and the arrow. If the
  player taps "Meet them now" before the reveal, the reveal happens as wave 1 starts.

---

## 6. Raid kinds

All kinds use enemies already in the game. The only new character is the Herald (section 18), and it has a working
placeholder.

| Kind | Weight | From raid # | Trails | Leader | Pool (weight) | Spawn every (s), wave 1 to 3 | Shards x | What the player is told |
|---|---|---|---|---|---|---|---|---|
| **Siege** | 4 | 1 | 1 (2 from raid level 12) | Gloom Herald | stump 3, brute 3, boar 2, beetle 2, thornling 4 | 1.7 to 1.1 | 1.0 | "Bruisers are coming for your buildings" |
| **Sky** | 3 | 2 | 2 | Gloom Herald | moth 7, pitcher 2, crow 1, thornling 2 | 1.5 to 1.0 | 1.15 | "Moths fly over barricades: towers and your bow matter" |
| **Sneak** | 3 | 3 | 1: the **least-guarded** trail, hidden until 15 s left | Gloom Herald | thornling 5, mole 3, puffball 3, pitcher 1 | 1.4 to 0.9 | 1.15 | "They're hiding their trail. Watch the woods!" |
| **Elite** (rare) | 1 | 5, and at least 4 raids since the last elite | 2 | Mossback, then the Owl Witch, then the Elder Thornstag, in turn | stump 2, beetle 2, frog 1, crow 1, snail 1, thornling 3 | 1.7 to 1.1 | 2.0 | "A great foe leads this raid" |

- **Raccoons are never in raids.** They steal pickups, and a raid must never feel like a theft.
- **Choosing the kind** (at stir, `raids._plan()`): a weighted pick among the kinds whose "from raid #" has been
  reached. The raid number is raids held + raids lost + 1. A kind never comes 3 times in a row (`max_same_in_a_row`
  = 2). Elite also needs `since_elite >= gap` (4). The very first raid is always a siege.
- **The elite leader** is `leaders[elite_turn % 3]`. `elite_turn` goes up only when an elite raid is **held**, so a
  lost elite raid brings back the same boss next time.
- **Choosing the trails**:
  - siege and sky: random trails, avoiding the last raid's trails when another choice exists
  - sneak: the trail with the lowest `defences.lane_guard(ln)` (ties at random). Guard = the health of the standing
    barricades on that trail, plus 150 for each standing tower whose range (+1 m) reaches the trail's midpoint
    `world.trail_point(ln, 0.5 * world.trail_length(ln))`.

  Sneak raids stay on the 4 existing trails. A new southern trail is out of scope (section 25, question 6): it would
  need world.gd's hard-coded `for i in 4` loops, the shader's `vec4` patch parameters and new barricade spots, and the
  south is where the Burrows hollow should go.
- **Waves**: 3, with a 10 s breather between them.
  - Wave w has `count` = lerp(12, 20) across the 3 waves, plus `floor(level / 5)`.
  - The last wave is cut to 60%, as in missions ("the leader brings fewer friends"), and the leader goes in the queue
    at index `leader_at` = 5 (mid-wave, after a few escorts).
  - At most `max_alive_by_quality` [18, 24, 28] alive at once (Quality Low, Medium, High).
- **The leader and the rout**: the leader has the boss bar and its own banner ("The Gloom Herald!", "Topple it and the
  raid breaks"). When it dies:
  - the rest of the queue is cleared, and every other foe still on the field flees with petals and drops its leaves
    (section 8)
  - banner: "The raid breaks!", "N raiders fled and dropped their leaves"
  - the wave then ends, and the raid is won

  Summons (the bear's thornlings, the owl's moths, the stag's stumps) are routed too. Leaders have `boss: true`, so
  they never flee as stragglers and never take knockback.
- **The Last Stand in a raid**: the same as in a mission. The fire can be rebuilt once per raid (10 timber, 4 s on the
  ashes). If the fire falls a second time, or the cat falls during the Last Stand, the raid is lost (section 10).
  Holding the rest of the raid without a fire still wins it, but not as a perfect defence.

---

## 7. Scaling: bigger camps draw bigger raids

```
camp score = 2 x (home level - 1)
           + sum of station levels (target, bench, well, cottage, stall; 0 when not built)
           + acorn towers placed
           + sum of (defence level - 1) over barricade, tower, spikes
           + guardian level                      (Phase C; Data.guardian_level() is 0 until then)

raid level = clamp(1 + floor(max(0, camp score - 20) / 2) + floor(renown / 2), 1, 30)
             first raid ever: raid level - 2 (at least 1)
renown     = +1 per raid held, -2 per raid lost (never below 0), at most 20

strength   = 2.2 + 0.07 x raid level            (the enemy.setup multiplier, as for missions)
wave w     = strength x (1 + 0.08 x (w - 1))
leader     = x 1.0 for the Herald, x 0.8 for an elite boss
```

- The cat's stats and bow are **not** in the camp score. Upgrading the cat always makes raids easier. Each camp
  upgrade adds about +0.035 strength, far less than what it gives (defence level 4 adds 3 points, +0.105 strength,
  against about +55% defence power).
- Worked examples:
  - **Just finished mission 15**: home 5, stations 3/3/2/3/3, 6 towers, defences 3/3/2, guardian 2. Camp score 35,
    raid level 8 (the first raid is level 6). Strength 2.76 to 3.20 across the 3 waves. Waves of 13 / 17 / 13, plus the
    leader. Mission 15 runs 2.12 to 4.13 with up to 26 enemies, so the first raids feel a step below its finale.
  - **Late**: home 6, stations 15, 7 towers, defences 4/4/4, guardian 3. Camp score 44, level 13, plus renown 20
    (+10): level 23. Strength 3.81 to 4.42. Waves of 16 / 20 / 14, plus the leader.
- **Mercy**: a loss takes 2 renown, which lowers the raid level by 1. The Watch card says "The next raid will be a
  little gentler".
- The **raid level is shown** on the Watch card ("Raid level 8") and in the warning banner, so the player can see that
  bigger camps draw bigger raids.
- The level is fixed when the plan is made at 75% and saved in the plan. Buying things afterwards does not raise it:
  what was announced is what comes.

---

## 8. The raid in code: a mode inside fight.gd

There is no second fight engine. `fight.gd` gets `mode := "mission"` or `"raid"`, and a raid is a mission-shaped
Dictionary built by `raids.spec_for(plan)`. So `_start_wave`, `_pick_lane`, `_pick_kind`, the spawn loop, `spawn()`,
the straggler flee, `damage_fire`, the Last Stand and `rebuild_fire` all work unchanged.

A raid **never**:
- uses `mission = -1` (`Data.mission(-1)` would silently return the Thornstag's data)
- reaches `_win()` or `_chapter_done()`
- writes `Save.mission_run`, `missions_done`, `stages_won` or `stages_lost`
- takes the camp-falls 30% of leaves or sets `Save.fire_ruined`

The raid spec (`raids.spec_for(plan)`):

```gdscript
{
	"id": "raid_siege", "name": "Siege raid", "type": "siege", "level": 8, "seed": 1234567,
	"waves": 3, "count": [13, 21], "lanes": [0],
	"chapters": [{"name": "Siege raid", "pool": [["stump", 3], ["brute", 3], ["boar", 2], ["beetle", 2], ["thornling", 4]], "every": [1.7, 1.1]}],
	"elite": [], "boss": [["herald", 1]], "leader": "herald", "leader_at": 5, "leader_mult": 1.0,
	"strength": 2.76, "wave_ramp": 0.08, "breather": 10.0, "max_alive": 24, "hidden": false
}
```

- `boss` holds the leader only. When the leader's kind is missing from `balance.json` `enemies` (before step D6),
  `boss` is `[]`, there is no rout, and the raid ends when the last wave is cleared.
- Pool kinds missing from `enemies` are dropped when the spec is built.
- **Seeded**: in raid mode `fight` uses its own `RandomNumberGenerator`, seeded from `spec.seed` and the wave number,
  for `_pick_kind` and `_pick_lane`. A raid that comes back after a restart is the same raid.

---

## 9. Winning: pay, the perfect defence, the ready bonus, the shard shower

On a raid held (`raids.finish(true, ...)`, called from `fight._raid_over(true)`):

| Pay | Formula | Level 8 siege | Level 23 elite |
|---|---|---|---|
| Shards | round((10 + 1.0 x level) x kind x (1 + 0.5 if perfect + 0.2 if ready)) | 18 (27 perfect, 31 perfect and ready) | 66 (99 perfect, 112 perfect and ready) |
| Leaves | 100 + 15 x level | 220 | 445 |
| Timber | 3 + floor(level / 4) | 5 | 8 |
| Kill drops | as today (`enemy._die`), plus the rout drops | about 300 | about 350, plus the boss's 300-500 |
| Burrows keys | +1, +1 more for an elite raid; at most 3 held | +1 | +2 |

- **Perfect defence**: no building fell during this raid (`fight.raid_losses == 0`, counted in `stations.ruin`), and
  the campfire never went out (`fight.fire_went_out` is false). Barricades and towers breaking does not spoil it,
  because that is their job. Old ruins left unrepaired do not spoil it either. The guardian being knocked down does not
  spoil it.
- **Ready bonus** (from the gameplay design): the camp was whole when wave 1 began. That means the camp check
  (section 11.4) had nothing to fix: no ruins, no wrecks, no wear. +20% shards. It rewards mending without punishing
  anyone.
- **Streak**: `Save.raids.streak` counts perfect defences in a row, and `best_streak` keeps the best. At streaks 3, 5
  and 10 the signpost shows ribbons 1, 2 and 3 (hidden parts of its model). They stay until the streak breaks. The
  best-ever streak shows on the Watch card.
- **Renown** +1 (at most 20). `held` +1. `since_elite` +1, or back to 0 after an elite raid. `elite_turn` +1 after an
  elite raid.
- **Shards are banked at once** (`Save.shards += n` and save), so a crash can never lose them. The shower is only for
  show: `mini(Quality.particles(8), n / 3)` display-only shard pickups (`pickup.gd` with `kind = "shard"` and value 0)
  burst from where the leader fell, or from the campfire when there was no leader, and are called home after 0.8 s. The
  HUD shard counter counts up to the new total as they land, with a `shard` chime for each.
- **The world celebrates**: `world.lift_gloom(ln)` for each raid trail (the existing petal burst; the trails are
  claimed, so they settle back to 0) and `Fx.flower_ring` at the campfire.
- **Banner**: "Raid repelled!" (gold) or "Perfect defence!" (bright gold), with "+27 shards · +220 leaves · +5 timber",
  plus a second line "Perfect streak 3" when the streak is 2 or more, or "The camp was ready: +20% shards".
- No wave-bonus leaves are paid in raids. The leaves come from the kills, the rout and the end pay.

---

## 10. Losing: what a lost raid costs (only damage)

A raid is lost when `fight.camp_falls()` runs in raid mode: the cat falls in the Last Stand, or the fire falls a second
time.

- **Kept, to repair:**
  - ruined buildings (saved the moment they fall, as today)
  - damaged or broken defences, which become wrecks through `defences.keep_damage()`
  - building wear (section 11.2)
- **Never taken**: leaves (the leaves the cat picked up in the raid stay too), timber, shards, levels, items, placed
  pieces, looks, keys, mission progress.
- **The fire does not become ashes.** `Save.fire_ruined` stays false, and `_end()` relights the fire because
  `last_stand` is on and the fire is not ruined. The meter can fill again at once.
- **Consolation** *(proposal)*: 2 shards per wave fully held (0-4), so a brave loss is never worth nothing.
- Renown -2 (mercy), `lost` +1, streak 0, meter 0, `world.settle_gloom()` (the mist quietly leaves the trails). The
  remaining raiders go back into the woods (`fight._clear_foes()`).
- **Banner** (soft violet, `Color(0.8, 0.6, 1.0)`): "The Gloom broke through", with "<n> buildings in ruins · <m>
  defences wrecked · nothing else was lost". 3.5 s later a tip with an arrow to the signpost: "Repair and mend from the
  signpost. The next raid will be a little gentler."
- **Closing the app mid-raid is not a loss** (section 13).
- The mission rule is unchanged: if the camp falls during a **mission replay**, today's camp-falls rules still apply
  (30% of unspent leaves, ashes, the chapter starts over). "Never more" is about raids.

---

## 11. Keeping the camp up

Three kinds of damage carry over between raids. All three can be fixed from the Watch card in one tap. The damage a
raid does is **saved at every wave the player holds and whenever the app pauses or loses focus**, not only at the end,
so closing the game cannot erase it.

### 11.1 Ruins (buildings at 0 health)
- Kept exactly as now: `Save.ruined`, the `_ruin_look` crust, `_ruin_card` / `_repair` at each building's ring. A ruin
  cannot be repaired while a wave is on, so it is repaired in the warning, in the breathers or after the raid.
- **Endgame repair price** (once raids are open): 10% of what was spent on the building (build plus levels; the home
  counts 100 plus its home levels), at least 20 leaves, **at most 900 leaves and 30 timber**. Before the endgame,
  today's camp-falls price (`raid.repair_share` 0.3, no cap) stays as it is.

  | Building | Endgame repair |
  |---|---|
  | Training Target level 3 | 76 leaves + 2 timber |
  | Bow Bench level 3 | 94 + 3 |
  | Wishing Well level 3 | 103 + 3 |
  | Mushroom Cottage level 3 | 141 + 3 |
  | Market Stall level 3 | 171 + 5 |
  | Home level 4 | 460 + 20 |
  | Home level 5 or 6 | 900 + 30 (capped) |
- **A won mission replay**, once raids are open, mends only the ruins made in that replay
  (`stations.repair_all_free(before)`, where `before` is `Save.ruined` when the replay started). It never mends raid
  ruins, or an easy replay would be a free repair button. The check is whether raids were open **when the mission
  started** (`fight._endgame_run`), so missions before the endgame, including the first win of mission 15, keep
  today's free mend exactly.

### 11.2 Building wear *(proposal)*
- `Save.wear = {id: 0..1}`: the share of a standing building's health lost in raids, rounded **down** to steps of
  0.05. Below 0.05 it is not stored.
- Written from `stations.hp` by `stations.save_wear()`. This runs at every raid wave held, in `raids.persist()` (pause,
  focus out, close) while a raid is on, and at the raid's end. Only raids write wear. Mission replays read it but never
  write it.
- A ruin clears its wear (the ruin replaces it). Repairing a ruin clears it too.
- `stations.reset_hp()` starts each building at `full_hp(id) x (1 - wear)`, in raids and replays alike, so a worn camp
  is weaker until it is patched.
- **Look**: `Props.set_param(node, "gloom", wear x 0.35)`, plus 1, 2 or 3 `rubble_pile` props at the building's foot at
  wear 0.2, 0.45 and 0.7 (child node `rubble`, rebuilt on `refresh`).
- **Patch** row on the building's own card: `max(5, ceil(endgame ruin price x wear x 0.5))` leaves, no timber.
  Examples: a home level 6 worn 20% is 90 leaves; a Market Stall worn 40% is 35. The row is disabled during a wave.
- The campfire has no wear. It starts every raid at full health. *(The gameplay design's slowly healing campfire was
  dropped: a time-based regen reads too close to a timer.)*

### 11.3 Wrecked defences
- At every raid wave held, in `raids.persist()` during a raid, and at the raid's end (won or lost),
  `defences.keep_damage()` turns every damaged barricade or tower into a saved wreck, as a camp fall does today. A wreck
  keeps its health and keeps working while it has health. Spikes are never hurt.
- **Mend price per piece** (once raids are open): piece price x (1 + 0.5 x (level - 1)) x 0.3 x the missing share,
  rounded up. A fully broken level 3 barricade is 18 leaves, a level 3 tower 54, a level 4 barricade 23 and a level 4
  tower 68. Before the endgame the price stays as now.
- The shop row "Mend the raid damage" is renamed "Mend the defences". It is also covered by "Mend all".

### 11.4 The camp check, camp condition and "Mend all"
- `raids.camp_check()` returns
  `{ruins: [ids], wrecks: [pieces], wear: {id: share}, cost: {leaves, timber}, items: [...], condition: 0..1}`.
- The items are in priority order: the home's ruin; other ruins, cheapest first; wrecked defences, most broken first;
  wear, highest first. Each item is `{kind, id_or_piece, cost}`.
- **Camp condition** (a %, shown on the Watch card's sub): a weighted mean. The home weighs 2, each other built
  building 1 (a ruin counts 0, a worn building `1 - wear`). Each barricade and tower weighs 0.5 (its health share).
- The Watch card row reads "Mend the camp", with a note such as "1 ruin · 3 defences wrecked · home worn 20%", the summed
  cost, and the button **Mend all**.
- If the player cannot afford everything, the button reads **Mend some**: it mends items in priority order while the
  leaves and timber last, and the note says what will be left.
- Mend all is blocked during a wave. It works in the warning, in the breathers and in calm.
- **Feel**: each fixed thing does `Fx.boing` plus `Fx.flower_ring` at its position, 0.15 s apart, and then the banner
  "The camp is mended!".
- **Typical upkeep**: a held raid costs about 60-150 leaves (15-30% of its leaves). A lost raid costs about 300-500,
  roughly one raid's pay, or up to about 1,300 if the home itself fell.

### 11.5 The guardian (Phase C)
Its knock-down and recovery belong to Phase C. Phase D only calls the hooks in section 22. If Phase C makes the
guardian stone a building in `stations.BUILDINGS` with a `building_hp` entry, raids ruin, wear and mend it like any
building, and the camp check lists it, with no raid code change.

---

## 12. Gloom shards (the new currency)

**Earned only by play**: raids (section 9), and later the Burrows and tasks. **Never sold.** Nothing priced in shards
can be bought with money, and paid looks never cost shards. There is no paid warning skip, repair, revive or raid. This
keeps "looks-only, never pay-to-win", even though shards buy some power.

| What shards buy | Where | Cost | Kind |
|---|---|---|---|
| **Lookout**: +15 s on every raid warning (never past 60) | Watch card | 25 shards | Gameplay (time to prepare) |
| **Tracker**: see the next raid's kind and trail at 75%; sneak raids cannot hide | Watch card | 40 shards | Gameplay (information) |
| **Barricades level 4**, Shardstone (1,400 health) | Shop | 1,500 leaves + 60 shards | Gameplay (needs home level 4) |
| **Acorn towers level 4** (36 damage every 0.7 s, 6.5 m range, 800 health) | Shop | 2,400 leaves + 90 shards | Gameplay (needs home level 4) |
| **Thorn spikes level 4** (34 damage a second, slows 0.5) | Shop | 1,200 leaves + 50 shards | Gameplay (needs home level 4) |
| **Gloomlit** colours for each mount and pet look (violet with bright accents; a palette swap) | Stable and Nest cards | 60 shards each | Looks, earned only |
| **Shardfire**: the campfire burns blue-violet (a flame tint) | Watch card | 100 shards | Looks, earned only |
| Sell shards to Bramble | Market Stall card | 5 shards for 100 leaves | A floor, so shards are never useless |
| *(optional, step D12)* Moth Lantern, Bramble Snare | Shop | section 21 | Gameplay |

- Level 5 of each defence is left to Phase E (Burrows rare materials), as GAME_PLAN says: "the strongest defences need
  rare materials".
- **Pace**: about 18-31 shards per raid early on, about 90-130 shards an hour. The Phase D goods total about 605 shards
  plus 5,100 leaves, roughly 25 raids or 5-6 hours of play, before the Burrows add more.
- Phase C may price the guardian's top upgrade in shards (`Data.pay` handles them).

---

## 13. Nothing happens while the game is closed

Rules (the build checks them: section 23, `--meter` and `--raidsave`):

1. **No wall clock.** Phase D adds no `Time.get_unix_time*`, `Time.get_datetime*`, `Time.get_date*`,
   `Time.get_time_dict*` or `Time.get_time_string*`, and no day-based caps. `Time.get_ticks_msec` stays allowed only for
   visual pulses (as `hud._draw_gate` does today); it never feeds game state. The audit step runs
   `grep -rnE "get_unix_time|get_datetime|get_date_|get_time_dict|get_time_string" game/scripts` and must find matches
   only in `autotest.gd`.
2. **The meter is fed only by clamped in-session delta and by actions.** Each frame adds at most 0.1 s. Idle play (no
   touch for 45 s) adds nothing.
3. **The warning only counts down while the player is there.** It stops after 20 s idle, and it runs on physics
   frames, which do not run while Android has the app paused.
4. **What is saved**: the meter value, the plan, `pending`, `warn_left` and `run` (waves held, buildings lost, the
   fire's state). **Never a timestamp.**
5. **On load** (`raids.restore_on_load()`, deferred at the end of `main._ready`):
   - If `pending`: the same plan comes back at its warning, with `warn_left` clamped to 30-60. Waves already held stay
     held (`run.wave_done`), so the raid goes on with the wave that was not finished. Banner after 1 s: "A Gloom Raid
     is waiting!", with "It comes in 30 s · nothing happened while you were away".
   - Ruins, wear and wrecks from before the quit stay. They were saved at the last wave held or when the app paused.
   - If the Last Stand was on at the quit, the fire comes back at 30% and counts as the raid's one rebuild (no timber
     is charged), and the raid is no longer perfect. A quit can never relight the fire for free a second time.
   - Otherwise the meter is exactly where it was.
6. **A quit is never a loss and never a win.** The raid simply comes back. A pending raid blocks starting a mission
   replay, so it cannot be dodged.
7. **Persist points**:
   - `main._notification(what)`: on `NOTIFICATION_APPLICATION_PAUSED`, `NOTIFICATION_APPLICATION_FOCUS_OUT` and
     `NOTIFICATION_WM_CLOSE_REQUEST` it calls `raids.persist()`. During a raid that saves wear
     (`stations.save_wear`), wrecks (`defences.keep_damage`), the fire's state and `warn_left = fight._breather`; then
     `Save.save_game(true)`.
   - At every 10-point meter step, at stir, at full, at raid start, at every wave held and at raid end.
8. On `NOTIFICATION_APPLICATION_PAUSED` (mobile only) `main.frozen = true`; on `NOTIFICATION_APPLICATION_RESUMED`
   `main.frozen = false`. Focus out on the PC does not freeze the game (the autotests run there).

The only gap left is a crash or a force-kill in the middle of a wave, with no pause notice. Then that one wave's damage
to standing buildings and defences is lost. Ruins are still kept, because they save the moment they happen.

---

## 14. HUD and cards

### 14.1 HUD top right (empty outside fights today)
`_stage_l` (the label) and `_gate_bar` (the bar). They show when `fight.active` **or** `raids.meter_shown()`, which is
true once raids are open.

| State | Label (`_stage_l`, 25 pt, right-aligned) | Bar (`_gate_bar`, 276 x 34) |
|---|---|---|
| Meter filling | `Gloom 62%` | violet fill `Color(0.62, 0.4, 0.95)` on dark; text "Raid at 100%" |
| Idle | `Gloom 62% · waits for you` (dimmed) | the same at 60% opacity |
| Tracker, past 75% | `Next: Sky raid · Fernwood` | the meter |
| Pending but blocked | `Raid waiting · rebuild the fire` (or "· get up", "· back to camp") | full, pulsing |
| Warning | `Siege raid · Fernwood · 0:38` (sneak: `Sneak raid · trail unknown · 0:38`) | countdown from gold to red, text `0:38`; while held: `waiting for you` |
| Raid wave | `Siege raid · wave 2 of 3 · 9 left` (`fight.status_text`) | the existing campfire bar |
| Raid breather | `Siege raid · wave 3 of 3 in 6 s` | the campfire bar |

`hud._draw_gate()` gets a branch: when `not fight.active`, or the raid is in its warning (`fight.mode == "raid" and
fight.warning`), it calls `_draw_raid_bar()`; otherwise it draws the campfire bar as now. The bar redraws only when the
shown value changes by at least 0.5 (meter points) or 1 s (countdown), and every frame only while it pulses.

### 14.2 Resources (top left)
- A third `_icon_row` under leaves and timber: a **shard** icon drawn in code (`_make_shard()`, a 64 x 64 faceted
  violet crystal with a lighter left facet and a pale core, drawn like `_make_leaf`) and its count. Visible once
  `Save.shards > 0 or Data.raids_open()`.
- The count ticks up through `_shown_shards`, like leaves.
- `hud._cost_button` draws the shard icon for a `"shards"` cost key, red when it cannot be afforded, like the others.

### 14.3 Pointing at a trail
`hud.point_at(world_pos: Vector3, secs: float)` generalises the tip arrow (`_draw_overlay`) to a world point with no
ring. It shows the bobbing arrow when the point is on screen and the edge arrow when it is off screen. `_draw_overlay`
uses `_point_pos` while `_point_t > 0` and there is no `_tip_ring`.

### 14.4 The signpost card becomes "The Watch" (once raids are open)
New order in `stations._card_sign()`:
1. Raid on (`f.active and f.mode == "raid"`): `main.raids.card_raid(anchor)`
2. Mission replay on: the existing branches
3. Raids open: `main.raids.card_watch(anchor)`
4. Otherwise: the existing card

Extract `_run_rows()` (the "Go on" / "Give up" rows) and `_replay_rows()` (the "Won · replay for half the reward"
rows) from today's function, so `card_watch` can append them. The old row "Every mission is won! · Gloom Raids are
coming soon." goes away.

**Watch, calm** (title "The Watch", sub "Gloom 62% · raid level 8 · camp 86%"):

| Row | Note | Button |
|---|---|---|
| "The Gloom is gathering" (below 50%) | "It fills while you play, never while the game is closed · 62%" | (disabled) |
| "Sound the horn" (50% or more) | "Call the raid now: 30 s to get ready" (with Tracker past 75%: "Next: Sky raid from Fernwood") | **Sound** |
| "A raid is waiting" (pending, blocked) | "Rebuild the campfire first: the Gloom waits" | (disabled) |
| "The camp is in good shape" / "Mend the camp" | "1 ruin · 3 defences wrecked · home worn 20%" | **Mend all** / **Mend some** (cost) |
| "Lookout" (until owned) | "+15 s to get ready before every raid" | **Buy** (25 shards) |
| "Tracker" (until owned) | "See the next raid at 75% · sneak raids can't hide" | **Buy** (40 shards) |
| "Campfire look: Campfire" | "Shardfire burns blue-violet" | **Unlock** (100 shards), then **Change** |
| "Raids held 12 · perfect 5" | "Perfect streak 2 · best 4" (after a loss: "The next raid will be a little gentler") | (disabled) |
| then `_run_rows()` or `_replay_rows()` | while a raid is pending, the replay rows are disabled: "A raid is at the gate: meet it first" | **Fight** |

**Warning** (title "Siege raid!", sub "From Fernwood · 0:38 to get ready"; sneak: "Trail unknown · 0:38"):
1. "Meet them now" / "Start the raid" / **Go** -> `fight.next_phase_now`
2. the camp check row (Mend all / Mend some)
3. "What's coming" / "Stump Golems, Toadstool Brutes, Bramble Boars · led by the Gloom Herald · level 8" (disabled)

**Wave**: title "Siege raid", sub "Wave 2 of 3 · topple the Gloom Herald to break it", no rows (as for missions now).
**Breather**: title, sub `status_text()`, rows "Next wave now" (**Go**) and the camp check row.

The calm Watch card has 3-6 rows before the replays. Cards with more than 6 rows already scroll (`hud.gd` 486-493).

### 14.5 Other cards
- **Every building card** (`_card_shop` for the home, `_card_target`, `_card_bench`, `_card_well`, `_card_cottage`,
  `_card_stall`) gets `_wear_row(id)` when wear is 0.05 or more: "Patch it up" / "Worn 20% by raids: 2,080 of 2,600
  health" / cost / **Patch**.
- **Shop**:
  - top, when anything is broken: the camp check row (Mend all / Mend some)
  - "Mend the raid damage" becomes **"Mend the defences"**, note "%d defence piece(s) broken or damaged"
  - the defence upgrade rows go to level 4 when `dl < levels.size()` and raids are open. The text for level 4 is
    "Every %s to Shardstone"; the note is `_def_level_note(type, 4)` + " · set with Gloom shards", or "Needs a bigger
    home (level 4)". The cost shows leaves and shards.
- **Market Stall**: "Sell 5 Gloom shards" / "Bramble pays 100 leaves" / cost `{shards: 5}` / **Sell**. Shown once
  shards are 5 or more.
- **Stable and Nest** (`_skin_row`, `_next_skin`): "Next" skips skins that cost shards and are not in `Save.unlocks`. An
  extra row "Gloomlit colours" / "Earned with Gloom shards, never sold" / 60 shards / **Unlock** shows until owned.
- **Ruin cards** in raid mode: in a wave, "Repair between waves" / "Raids leave their damage: repair it after this
  wave". The "or free when the mission is won" note never shows in raids.

### 14.6 Messages (exact text)
| When | Kind | Text |
|---|---|---|
| Last mission won (first time) | banner (gold), 3.5 s after the win banner | "Every mission is won!" / "But the Gloom will be back. The Watch by the signpost shows it gathering." Then a tip with an arrow to the sign ring: "When the horn's crystal is full, a raid comes. You'll always get time to prepare." |
| 75% | toast | "The Gloom stirs in the woods..." |
| 75% with Tracker | toast | "The Watch hears a Siege raid on Fernwood" |
| Horn | banner (violet `0.8, 0.55, 1.0`) | "A Gloom Raid is coming!" / "Siege raid · level 8 · from Fernwood · 45 s to get ready" |
| First raid | tip with an arrow to the sign | "Repair and mend, then tap Meet them now at the signpost. Or wait for the horn." |
| Sneak reveal | toast | "There! They're coming down Bandit Thicket!" |
| 10 s left | toast | "10 seconds!" |
| Wave 1 | banner | "They're here!" / the kind's tell |
| Last wave | banner | "Final push!" / "The Gloom Herald leads it" (elite: "Mossback leads it") |
| Leader spawns | banner (replaces the generic boss banner in raids) | "The Gloom Herald!" / "Topple it and the raid breaks" |
| Rout | banner (gold) | "The raid breaks!" / "9 raiders fled and dropped their leaves" |
| Held | banner | "Raid repelled!" or "Perfect defence!" / "+27 shards · +220 leaves · +5 timber" (+ "Perfect streak 3" or "The camp was ready: +20% shards") |
| Lost | banner (soft violet) | "The Gloom broke through" / "2 buildings in ruins · 3 defences wrecked · nothing else was lost" |
| Building hit in a raid (once per building every 10 s) | toast | "The Mushroom Cottage is under attack!" |
| After a raid, if damaged | tip with an arrow to the sign | "Mend the camp before the next raid." |
| Mend all | banner | "The camp is mended!" |
| First shards | tip with an arrow to the shop | "Gloom shards! Spend them on Shardstone defences in the shop, or on the Watch's Lookout and Tracker." |
| Load with a raid pending | banner | "A Gloom Raid is waiting!" / "It comes in 30 s · nothing happened while you were away" |

---

## 15. balance.json

### 15.1 New top-level key `gloom_raids`
The existing key `raid` keeps meaning the mission camp-falls numbers (`fight.camp_falls`, `stations.repair_cost`,
`_card_fire` and `defences.repair_cost` read it).

```json
"gloom_raids": {
  "_note": "Gloom Raids after every mission is won (Phase D, docs/PHASE_D_SPEC.md); not `raid` (the mission camp-falls numbers). The meter fills ONLY while the game runs: `meter.per_minute` points a minute while no fight is on, no raid is pending, the fire burns, the cat is up and the player touched the screen in the last `meter.idle_after` s (frame delta clamped to `meter.max_delta`), plus `meter.actions`, which never fill it past `meter.bump_cap`. Nothing reads the clock. At `meter.stir_at` the next raid is planned (its kind, trails, level and leader are fixed then); at `meter.full` it is pending and its warning (`warning`, always `warning.min`..`warning.max` s) starts when allowed. A raid is `waves` waves of lerp(count) (+1 per `count_per_level` raid levels) from its kind's pool; the last wave is cut to 60% and led by its leader (queue index `leader_at`); beating the leader routs the rest. Raid level = 1 + floor(max(0, camp score - level.camp_free) / level.camp_step) + floor(renown / level.renown_step), at most level.max (the first raid: - level.first_raid_minus). Renown +level.won_renown per raid held, -level.loss_renown per raid lost, 0..level.renown_cap. Strength = strength.base + strength.per_level x level, x (1 + strength.wave_ramp x (wave - 1)), the leader x leader_mult. Pay: shards round((pay.shards + pay.shards_per_level x level) x kind shards x (1 + pay.perfect if perfect + pay.ready if ready)); leaves pay.leaves + pay.leaves_per_level x level; timber pay.timber + floor(level / pay.timber_per_levels); keys pay.keys. A lost raid pays pay.lost_per_wave_held shards per wave held and takes nothing.",
  "meter": {
    "full": 100, "per_minute": 10, "idle_after": 45, "max_delta": 0.1, "bump_cap": 95,
    "first_fill": 70, "call_from": 50, "stir_at": 75, "save_step": 10,
    "actions": {"replay_chapter": 6, "replay_won": 12, "harvest": 2, "dish": 3, "fish": 2, "burrow_run": 15}
  },
  "warning": {"normal": 45, "first": 60, "elite": 60, "called": 30, "lookout_bonus": 15, "min": 30, "max": 60,
              "sneak_reveal": 15, "idle_hold": 20, "ten_left": 10, "point_s": 6},
  "waves": 3,
  "breather": 10,
  "count": [12, 20],
  "count_per_level": 5,
  "leader_at": 5,
  "max_alive_by_quality": [18, 24, 28],
  "strength": {"base": 2.2, "per_level": 0.07, "wave_ramp": 0.08, "herald_mult": 1.0, "boss_mult": 0.8},
  "level": {"camp_free": 20, "camp_step": 2, "renown_step": 2, "renown_cap": 20, "won_renown": 1, "loss_renown": 2,
            "max": 30, "first_raid_minus": 2},
  "camp_score": {"per_home_level": 2, "per_station_level": 1, "per_tower": 1, "per_defence_level": 1, "per_guardian_level": 1},
  "first_raid": "siege",
  "max_same_in_a_row": 2,
  "types": {
    "siege": {"name": "Siege raid", "weight": 4, "from_raid": 1, "lanes": 1, "lanes_more_from_level": 12, "leader": "herald", "shards": 1.0,
      "pool": [["stump", 3], ["brute", 3], ["boar", 2], ["beetle", 2], ["thornling", 4]], "every": [1.7, 1.1],
      "tell": "Bruisers are coming for your buildings"},
    "sky": {"name": "Sky raid", "weight": 3, "from_raid": 2, "lanes": 2, "leader": "herald", "shards": 1.15,
      "pool": [["moth", 7], ["pitcher", 2], ["crow", 1], ["thornling", 2]], "every": [1.5, 1.0],
      "tell": "Moths fly over barricades: towers and your bow matter"},
    "sneak": {"name": "Sneak raid", "weight": 3, "from_raid": 3, "lanes": 1, "pick": "weakest", "hidden": true, "leader": "herald", "shards": 1.15,
      "pool": [["thornling", 5], ["mole", 3], ["puffball", 3], ["pitcher", 1]], "every": [1.4, 0.9],
      "tell": "They're hiding their trail. Watch the woods!"},
    "elite": {"name": "Elite raid", "weight": 1, "from_raid": 5, "gap": 4, "lanes": 2, "leaders": ["bear", "owl", "stag"], "shards": 2.0, "warning": "elite",
      "pool": [["stump", 2], ["beetle", 2], ["frog", 1], ["crow", 1], ["snail", 1], ["thornling", 3]], "every": [1.7, 1.1],
      "tell": "A great foe leads this raid"}
  },
  "pay": {"shards": 10, "shards_per_level": 1.0, "perfect": 0.5, "ready": 0.2, "lost_per_wave_held": 2,
          "leaves": 100, "leaves_per_level": 15, "timber": 3, "timber_per_levels": 4,
          "keys": {"held": 1, "elite_extra": 1, "max": 3}},
  "streak_ribbons": [3, 5, 10],
  "rout": {"max_pickups": 12, "max_petals_low": 8},
  "lane_guard": {"tower": 150, "tower_reach_bonus": 1.0},
  "repair": {"ruin_share": 0.1, "ruin_min": 20, "ruin_cap": {"leaves": 900, "timber": 30},
             "wear_share": 0.5, "wear_min": 5, "wear_step": 0.05, "wear_gloom": 0.35, "wear_rubble": [0.2, 0.45, 0.7],
             "mend_share": 0.3, "mend_per_level": 0.5, "mend_stagger_s": 0.15},
  "watch": {
    "lookout": {"name": "Lookout", "shards": 25, "note": "+15 s to get ready before every raid"},
    "tracker": {"name": "Tracker", "shards": 40, "note": "See the next raid at 75% · sneak raids can't hide"}
  },
  "fire_looks": [
    {"id": "", "name": "Campfire", "tint": [1.0, 1.0, 1.0]},
    {"id": "shardfire", "name": "Shardfire", "shards": 100, "tint": [0.6, 0.65, 1.25]}
  ],
  "shard_trade": {"shards": 5, "leaves": 100},
  "alert_every_s": 10
}
```

### 15.2 New enemy (in `enemies`, step D6)
```json
"herald": {
  "name": "Gloom Herald", "hp": 450, "speed": 0.6, "damage": 2, "gate_damage": 10, "leaves": 40,
  "aggro": 3.0, "reach": 0.7, "attack_every": 1.6, "height": 1.6, "radius": 0.55, "color": "#4A3566",
  "boss": true, "ai": "crow", "model": "crow", "scale": 1.25,
  "drum_every": 7.0, "drum_range": 5.0, "drum_buff": 0.25, "drum_time": 4.0
}
```
- `"model": "crow"` is the placeholder (the Crow Drummer at 1.25x) until the Meshy Herald arrives. Then set
  `"model": "herald"` and remove `scale`.
- `"ai": "crow"` makes it drum (section 17, enemy.gd). The crow's drum action already plays a `Drum` clip with a `beat`
  event when the model has one, or falls back to `Attack`.
- At raid level 8, wave 3 (strength 3.20) it has about 1,440 health: roughly 15-20 s of focused fire with towers and the
  pet.

### 15.3 Defence level 4 (appended to each `defences.<type>.levels`)
```json
"barricade": {"hp": 1400, "upgrade": 1500, "shards": 60, "model": "barricade_shard", "name": "Shardstone"},
"tower":     {"damage": 36, "every": 0.7, "range": 6.5, "upgrade": 2400, "shards": 90, "hp": 800},
"spikes":    {"dps": 34, "slow": 0.5, "upgrade": 1200, "shards": 50}
```
Level 4 needs raids open, and home level 4 or more (the existing check `dl + 1 <= Save.camp_level`).

### 15.4 Gloomlit skins (step D8)
Appended to `skins` of thistle, bramblewool, sprig and lumi:
```json
{"id": "gloomlit", "name": "Gloomlit", "to": [0.76, 0.75, 0.9], "shards": 60}
```

### 15.5 `raid` (the mission camp-falls block)
Unchanged. Update only its `_note`: "the camp falls in a MISSION (not the Gloom Raids: see gloom_raids): ...".

---

## 16. Save fields and old saves

New vars in `save.gd`. Each one is added in **three places**: the `var`, `load_game` (with `d.get(key, default)` and
casts) and the `save_game` dict.

```gdscript
var shards := 0                       # Gloom shards: earned in play only, never sold
var raids := {}                       # Gloom Raids state; filled from RAIDS_DEFAULT
var wear := {}                        # building id -> share of health lost in raids (0..1, steps of 0.05)
var unlocks: Array = []               # bought with shards: "watch:lookout", "watch:tracker",
                                      # "skin:mount:thistle:gloomlit", "fire:shardfire", ...
var fire_look := ""                   # "" or "shardfire"
var burrow_keys := 0                  # Phase E reads it; written by raids held (at most 3); never refilled by time
var save_v := 2                       # save format version (1 = before Phase D)

const RAIDS_DEFAULT := {
	"meter": 0.0,          # 0..100; fills only while the game runs
	"plan": {},            # the next raid, made at stir: {type, lanes, level, leader, first, seed}
	"pending": false,      # the meter is full: the raid is announced and not over (warning, waves, restarts)
	"warn_left": 0.0,      # warning seconds left (on load clamped to warning.min..max)
	"run": {},             # the pending raid's progress: {wave_done, losses, fire, fire_went_out, rebuilt, ready, revealed}
	"renown": 0, "held": 0, "lost": 0, "perfect": 0, "streak": 0, "best_streak": 0,
	"since_elite": 0, "elite_turn": 0, "last_types": [], "last_lanes": [],
	"first_done": false,   # the first raid has been fought
}
```

- `load_game`:
  - `raids = RAIDS_DEFAULT.duplicate(true)`, then merge the saved keys over it with casts: floats for `meter` and
    `warn_left`, ints for the counters, `bool` for `pending` and `first_done`, plan lanes cast to `int`, `run` values
    cast (`wave_done` and `losses` int, `fire` float, the rest bool).
  - A plan whose `type` is not in `gloom_raids.types` is dropped, together with `pending` and `run`.
  - `wear` values cast to float and clamped to 0..0.95. `shards` int, at least 0. `unlocks` strings. `fire_look`
    string. `burrow_keys` int, 0..3.
  - `save_v = int(d.get("save_v", 1))`.
- `save_game(quiet := false)`: when `quiet` is true it writes the file but does **not** emit `changed`. It is used for
  meter steps and pause persistence, so the open card is not rebuilt. Existing callers are unchanged.
- **Migration** (in `raids.restore_on_load()`, which needs Data and the missions):
  - If `save_v < 2` and `Data.raids_open()` (an old save with every mission won): `raids.meter = first_fill`, and the
    one-time intro plays (flag `told_raids`).
  - Then `save_v = 2`.
- Nothing else is needed for old saves. Old ruins and wrecks keep working. `def_levels` stay at 3 or below until level
  4 is bought. The `placed[].wreck` format does not change. `best_night` and `spots` stay legacy fields: never reuse
  those names.
- Tip flags: `told_raids`, `told_raid_warn`, `told_raid_after`, `told_shards`.

---

## 17. Files and functions

### 17.1 New: `game/scripts/raids.gd` (a Node, `main.raids`)
Built in `main._ready` right after `fight` (`raids = Node.new()`, `set_script(RaidsScript)`, `raids.main = self`,
`add_child(raids)`). It owns the meter, the plan, the warning's presentation, pay, the camp check and the Watch card.
`fight.gd` runs the raid.

```gdscript
extends Node
## Gloom Raids (Phase D): after every mission is won, the Gloom keeps coming.
##   meter    Save.raids.meter 0..100. It fills only while the game is open and the player is playing (no fight, no
##            raid pending, the fire burns, the cat is up, a touch within idle_after). Never fed from the clock.
##   plan     made at stir_at: kind, trails, level, leader, seed. What was announced is what comes.
##   pending  full: the raid is announced and fight.gd runs it (start_raid): the warning, then 3 waves. It stays
##            pending across restarts and comes back at its warning. Nothing is ever worked out while closed.
##   end      held: shards, leaves, timber, keys. Lost: a few shards. The damage stays either way, nothing is taken.

signal raid_started(spec: Dictionary)      # Phase C (dish boosts, the guardian) and Phase E listen
signal raid_ended(won: bool, perfect: bool)

var main
var idle_t := 0.0
var open := false                           # cache of Data.raids_open(), refreshed by refresh_open()
var _alerts := {}                           # building id -> seconds until the next "under attack" toast

func cfg() -> Dictionary                    # Data.b["gloom_raids"]
func refresh_open() -> void
func tick(delta: float) -> void             # main._process: clamp delta, idle_t, alerts, the pending path, or fill
func touch() -> void                        # main._input: idle_t = 0
func can_fill() -> bool                     # section 4
func holding() -> bool                      # idle_t >= warning.idle_hold (the countdown waits)
func add_gloom(action: String) -> void      # action points, never past bump_cap, never while pending
func _add(points: float, cap: float) -> void   # stir -> plan; full -> _go_pending; quiet save on 10-point steps
func camp_score() -> int
func raid_level(first := false) -> int
func strength_for(level: int) -> float
func _plan() -> Dictionary                  # kind (weights, from_raid, gap, no 3 in a row), lanes, level, leader, seed
func _pick_lanes(t: Dictionary) -> Array    # "weakest" via defences.lane_guard; else random, avoiding last_lanes
func spec_for(plan: Dictionary) -> Dictionary   # section 8; drops kinds missing from `enemies`
func warn_seconds(plan: Dictionary, called: bool) -> float   # section 5, clamped to min..max
func call_now() -> void                     # "Sound the horn" (meter >= call_from)
func _go_pending(called: bool) -> void      # plan if missing, pending, warn_left, meter = full, quiet save, try_warning
func blocked_reason() -> String             # "", "fire", "down", "away", "busy", "fight"
func try_warning() -> void                  # fight.start_raid(spec_for(plan), warn_left) when allowed, then present_warning
func present_warning() -> void              # horn, banner, gloom_returns, point_at, tips
func warning_tick(left: float) -> void      # fight calls it during the warning: warn_left, sneak reveal, 10 s toast
func on_wave_begins(w: int) -> void         # w == 1: run.ready = camp_check().items.is_empty(); reveal a hidden sneak
func on_leader(e) -> void                   # banner, hud.boss = e
func on_building_hit(id: String) -> void    # the "under attack" toast, at most once per building every alert_every_s
func on_wave_held(w: int) -> void           # run.wave_done = w, save_wear, keep_damage, fire state, save
func finish(won: bool, perfect: bool, held: int) -> void   # section 9 / 10: pay, counters, banners, keys, clear, emit
func persist() -> void                      # meter; during a raid: wear, wrecks, fire state, warn_left; quiet save
func restore_on_load() -> void              # migration, the pending raid back at its warning, the banner
func on_all_missions_won() -> void          # meter = first_fill, the signpost swap, intro banner and tip
func camp_check() -> Dictionary             # section 11.4
func mend_all() -> void                     # priority order; Mend some when short; staggered fx
func card_watch(anchor: Vector3) -> Dictionary
func card_raid(anchor: Vector3) -> Dictionary
func meter_shown() -> bool
func hud_text() -> String
func hud_frac() -> float
func hud_state() -> String                  # "meter", "idle", "blocked", "warning", ""
func buy_watch(id: String) -> void          # "lookout" / "tracker"
func set_fire_look(id: String) -> void
func trade_shards() -> void
func _update_watch_model() -> void          # the signpost's fill, flag, bell and ribbons
```

Core bodies (the rest follows the sections above):

```gdscript
func tick(delta: float) -> void:
	if not open or main.frozen:
		return
	var d := minf(delta, float(cfg()["meter"]["max_delta"]))   # a resume or a stall never adds time
	idle_t += d
	for id in _alerts.keys():
		_alerts[id] = float(_alerts[id]) - d
	if main.fight.active:
		return
	if bool(Save.raids["pending"]):
		try_warning()
		return
	if can_fill():
		var m: Dictionary = cfg()["meter"]
		_add(float(m["per_minute"]) / 60.0 * d, float(m["full"]))


func can_fill() -> bool:
	return open and not main.fight.active and not bool(Save.raids["pending"]) and not Save.fire_ruined \
		and idle_t < float(cfg()["meter"]["idle_after"]) and main.player.hp > 0 and not main.frozen \
		and main.get("area") == null


func add_gloom(action: String) -> void:
	if not open or bool(Save.raids["pending"]):
		return
	var m: Dictionary = cfg()["meter"]
	_add(float(m["actions"].get(action, 0.0)), float(m["bump_cap"]))


func _add(points: float, cap: float) -> void:
	var m: Dictionary = cfg()["meter"]
	var r: Dictionary = Save.raids
	var before := float(r["meter"])
	var after := minf(maxf(before, minf(before + points, cap)), float(m["full"]))
	if after <= before:
		return
	r["meter"] = after
	if before < float(m["stir_at"]) and after >= float(m["stir_at"]) and (r["plan"] as Dictionary).is_empty():
		r["plan"] = _plan()
		_stir_message()
		Save.save_game(true)
	if after >= float(m["full"]):
		_go_pending(false)
	elif int(before / float(m["save_step"])) != int(after / float(m["save_step"])):
		Save.save_game(true)
	_update_watch_model()
```

```gdscript
func try_warning() -> void:
	if blocked_reason() != "":
		return
	var r: Dictionary = Save.raids
	if not main.fight.start_raid(spec_for(r["plan"]), float(r["warn_left"])):
		return
	present_warning()
	raid_started.emit(main.fight.raid)
	var g = main.get("guardian")
	if g != null and g.has_method("on_raid_start"):
		g.on_raid_start()
```

`finish()` order:
1. `main.stations.save_wear()` and `main.defences.keep_damage()`.
2. Pay (section 9) or the consolation (section 10). `Save.shards += n` at once.
3. Counters: `held`/`lost`, `perfect`, `streak`, `best_streak`, `renown`, `since_elite`, `elite_turn`, `last_types`
   (the last 2), `last_lanes`, `first_done`. Keys: `Save.burrow_keys = mini(max, keys + n)`.
4. Clear: `plan = {}`, `pending = false`, `warn_left = 0`, `run = {}`, `meter = 0`.
5. World: `lift_gloom(ln)` for each raid trail on a win, `settle_gloom()` on a loss.
6. The banner (section 14.6), the shard shower (`main.drop_shards_fx`), the guardian hook (`on_raid_end(won)` if it
   exists), `raid_ended.emit(won, perfect)`.
7. `Save.save_game()`; `Sfx.play("win" if won else "lose", -4.0)`.
8. The tips: `told_raid_after` (an arrow to the sign, when anything is damaged) and `told_shards`.

### 17.2 `fight.gd`: a raid mode
New state, next to the existing vars:
```gdscript
var mode := "mission"            # "mission", or "raid" (a Gloom Raid: raids.gd builds the spec)
var raid: Dictionary = {}        # the raid's mission-shaped spec while mode == "raid"
var warning := false             # a raid's warning is running (the breather before its next wave)
var raid_losses := 0             # buildings knocked down in this raid (stations.ruin)
var fire_went_out := false       # the campfire went out in this raid: no perfect defence
var _rng := RandomNumberGenerator.new()   # raids: seeded, so a raid that comes back is the same raid
var _ruined_at_start: Array = [] # a replay after the endgame mends only the ruins it made
var _endgame_run := false        # raids were open when this mission started
```

| Function | Change (the mission path is unchanged in every function) |
|---|---|
| `info()` | `return raid if mode == "raid" else Data.mission(mission)` |
| `_pay_scale()` | `if mode == "raid": return 1.0` first |
| `strength(w)` | raid: `float(raid["strength"]) * (1.0 + float(raid["wave_ramp"]) * (maxi(ww, 1) - 1))` |
| new `_max_alive()` | `int(raid["max_alive"]) if mode == "raid" else int(_cfg()["max_alive"])`; used in `_physics_process` |
| new `_rand()` | `return _rng.randf() if mode == "raid" else randf()`; `_pick_kind` uses it instead of `randf()`, `_pick_lane` uses `lanes[mini(int(_rand() * lanes.size()), lanes.size() - 1)]` |
| `title()` | raid: `String(raid.get("name", "Gloom Raid"))` |
| `status_text()` | raid branches first: warning `"%s · %s · %s"` (name, trail or "trail unknown", m:ss) plus " · waiting for you" while `main.raids.holding()`; breather `"%s · wave %d of %d in %ds"`; wave `"%s · wave %d of %d · %d left"` |
| `start_mission(i)` | also refuse when `bool(Save.raids.get("pending", false))`. Set `mode = "mission"`, `raid = {}`, `_endgame_run = Data.raids_open()`, `_ruined_at_start = Save.ruined.duplicate()` |
| `_start_wave(w)` | raid: `_rng.seed = hash([int(raid["seed"]), w])` first; `warning = false`; leader index `mini(_queue.size(), int(info().get("leader_at", 2)))` (missions keep 2 because they have no key). `main.on_wave_start` then calls `main.raids.on_wave_begins(w)` |
| `_physics_process` | the `_breather > 0.0` block: raid and `main.raids.holding()` -> return; `_breather -= delta`; while `warning`, `main.raids.warning_tick(_breather)`. Spawn cap `_max_alive()`. Raid spawn pace: `into = float(wave - 1) / float(maxi(1, waves() - 1))` |
| `spawn()` | raid: the leader (`kind == raid.get("leader")`) gets `s *= float(raid["leader_mult"])`, `e.set_meta("leader", true)` and `main.raids.on_leader(e)`, and skips the generic boss banner |
| `on_enemy_died(e)` | add: `if mode == "raid" and is_instance_valid(e) and e.has_meta("leader"): _rout(e)` |
| `_start_last_stand()` | add `fire_went_out = true` |
| `_wave_cleared()` | right after `in_wave = false`: `if mode == "raid": _raid_wave_cleared(); return`. A raid can never reach `_win` or `_chapter_done` |
| `camp_falls()` | after `if not active: return`: `if mode == "raid": _raid_over(false); return`. This skips the 30% leaves, `fire_ruined`, `stages_lost` and `mission_run` |
| `_chapter_done()` | add `main.raids.add_gloom("replay_chapter")` (it does nothing before the endgame) |
| `_win()` | for a replay (`not first_win`): `main.raids.add_gloom("replay_won")`. At the very end: `if first_win and Data.raids_open(): main.raids.on_all_missions_won()` |

```gdscript
## A Gloom Raid: the warning first (the breather before its next wave), then its waves. raids.gd calls this.
func start_raid(spec: Dictionary, warn_s: float) -> bool:
	if active or Save.fire_ruined:
		return false
	var run: Dictionary = Save.raids.get("run", {})
	mode = "raid"
	raid = spec
	active = true
	in_wave = false
	on_break = false
	wished = false
	last_stand = false
	warning = true
	rebuilt = bool(run.get("rebuilt", false))            # one rebuild per raid, kept across a restart
	fire_went_out = bool(run.get("fire_went_out", false))
	raid_losses = int(run.get("losses", 0))
	total_t = 0.0
	_first = false
	_queue.clear()
	gate_max = float(Data.fire_hp())
	gate_hp = gate_max * clampf(float(run.get("fire", 1.0)), 0.3, 1.0)
	wave = int(run.get("wave_done", 0))                  # waves already held stay held
	_breather = warn_s
	main.stations.reset_hp()                             # hp{} is stale outside fights; wear applies here
	main.on_raid_start(spec)
	return true


func _raid_wave_cleared() -> void:
	main.raids.on_wave_held(wave)                        # wear, wrecks and the fire saved now, not only at the end
	if wave >= waves():
		_raid_over(true)
		return
	_breather = float(raid["breather"])
	main.hud.toast("Wave %d of %d held!" % [wave, waves()])
	main.on_wave_cleared()


## A Gloom Raid ends: held, or the Gloom got through. Either way the damage stays; nothing else is lost.
func _raid_over(won: bool) -> void:
	var perfect := won and raid_losses == 0 and not fire_went_out
	var held := wave if won else maxi(0, wave - 1)
	if not won:
		main.set_riding(false)
	_clear_foes()
	main.raids.finish(won, perfect, held)
	_end(won)                 # relights the fire if the Last Stand was on (a raid never sets fire_ruined)
	mode = "mission"          # after _end: main.on_stage_end still sees mode == "raid"
	raid = {}
	warning = false


## The leader fell: the rest of the raid flees and drops its leaves.
func _rout(leader) -> void:
	_queue.clear()
	var at: Vector3 = leader.global_position
	var fled := 0
	var pay := 0
	var petals := Quality.particles(int(main.raids.cfg()["rout"]["max_petals_low"]) * 2)
	for f in get_tree().get_nodes_in_group("foes"):
		if f == leader or f.dead:
			continue
		pay += int(f.info.get("leaves", 0)) + int(f.get("carried") if f.get("carried") != null else 0)
		f.dead = true
		f.remove_from_group("foes")
		f.remove_from_group("enemies")
		if fled < petals:
			Fx.petals(main, f.global_position + Vector3(0, 0.4, 0))
		f.queue_free()
		fled += 1
	# drop_leaves makes at most 6 pickups a call: at most max_pickups pickups in all, round the leader
	var calls := maxi(1, int(main.raids.cfg()["rout"]["max_pickups"]) / 6)
	for k in calls:
		var part := pay / calls + (pay % calls if k == 0 else 0)
		if part > 0:
			main.drop_leaves(at + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)), part)
	main.hud.banner("The raid breaks!", Color(1.0, 0.85, 0.4), "%d raiders fled and dropped their leaves" % fled)
```
The spawn loop then sees an empty queue and no foes, and calls `_wave_cleared()` itself.

The public API the autotest uses is unchanged: `start_stage`, `spawn(kind, pos, patch)`, `damage_fire`,
`set_physics_process`, `gate_hp`/`gate_max`, `last_stand`, `rebuilt`, `left_in_wave`, `status_text`.

### 17.3 `main.gd`
```gdscript
const RaidsScript := preload("res://scripts/raids.gd")
var raids
```
- `_ready`: build `raids` right after `fight`. At the end, before the autotest block: `raids.refresh_open()` and
  `raids.call_deferred("restore_on_load")`.
- `_process`, after `if frozen: return`: `raids.tick(delta)`.
- New `_input(event)`: an `InputEventScreenTouch` or `InputEventMouseButton` press, an `InputEventScreenDrag`, or an
  `InputEventKey` press calls `raids.touch()`. Nothing is consumed.
- New `_notification(what)`:
  - `NOTIFICATION_APPLICATION_PAUSED`, `NOTIFICATION_APPLICATION_FOCUS_OUT`, `NOTIFICATION_WM_CLOSE_REQUEST`:
    `raids.persist()`. PAUSED also sets `frozen = true` (mobile).
  - `NOTIFICATION_APPLICATION_RESUMED`: `frozen = false`.
- New `on_raid_start(spec)`: `player.hp = Data.cat_max_hp()`, `hud.refresh_hp()`, `hud.refresh()`,
  `stations.refresh()`, `hud.refresh_card()`.
- `on_wave_start(n, elite, last)`: after the refresh lines, a raid branch: wave 1 "They're here!", the last wave "Final
  push!", other waves a toast "Raid wave %d of %d". Then `raids.on_wave_begins(n)` and return.
- `on_stage_end(won)`:
  - sweep the pickups as now
  - **if `fight.mode == "raid"`**: `stations.refresh()`, `hud.refresh()`, `hud.refresh_build()`, `Save.save_game()`,
    return. **No free mending.**
  - else (missions): on a win, `defences.repair_all()` as now; then `stations.repair_all_free(fight._ruined_at_start)`
    if `fight._endgame_run`, else `stations.repair_all_free()` (today's behaviour)
- New `drop_shards_fx(n: int, at: Vector3)`: display-only shard pickups that are called home after 0.8 s.
- `on_player_down`: no change. In a raid's Last Stand it calls `fight.cat_fell()`, which calls `camp_falls()`, which
  calls `_raid_over(false)`. Otherwise the cat respawns at the camp after 5 s as usual.

### 17.4 `stations.gd`
- New `full_hp(id) -> float`: `Data.building_hp(id, level)` (the same level choice as `reset_hp` today).
- `reset_hp()`: `hp[id] = full_hp(id) * (1.0 - float(Save.wear.get(id, 0.0)))`.
- New `save_wear()`: for each id in `hp` (only when a fight is active): ruined -> erase; else
  `lost = 1 - hp/full`, `w = floor(lost / step) * step`; store `w` when it is at least `step`, else erase. It does not
  save; callers save.
- `ruin(id)`: at the top, `if main.fight.active and main.fight.mode == "raid": main.fight.raid_losses += 1`. Also
  `Save.wear.erase(id)`.
- `hurt_building(id, amt)`: add `main.raids.on_building_hit(id)` when `main.fight.mode == "raid"`.
- `repair_cost(id)`: when `Data.raids_open()`, use `gloom_raids.repair` (`ruin_share`, `ruin_min`, `ruin_cap`);
  otherwise as now.
- `_repair(id)`: also `Save.wear.erase(id)`; if `main.fight.active`, `hp[id] = full_hp(id)` (this also fixes a
  repaired building staying at hp 0, and so untargetable, for the rest of a fight).
- `repair_all_free(before := [])`: with no argument, clear everything (today). With a list, clear only the ids in
  `Save.ruined` that are not in `before`.
- New `patch_cost(id) -> Dictionary`, `_patch(id)` (blocked during a wave; pay; erase wear; `hp[id] = full_hp(id)` if
  a fight is active; `Fx.boing` and `Fx.flower_ring`; refresh) and `_wear_row(id)`, added to every building card.
- New `_wear_look(id)` inside `refresh()`: the gloom param and the `rubble` child with 0-3 `rubble_pile` props.
- `_ruin_card`: the raid wording of section 14.5.
- `_card_sign()`: the new order of section 14.4; `_run_rows()` and `_replay_rows()` extracted.
- `_card_shop()`: the camp check row at the top when needed; "Mend the defences"; defence rows up to
  `levels.size()` (level 4 only when raids are open) with `_def_cost(type, lv)`.
  ```gdscript
  func _def_cost(type: String, lv: int) -> Dictionary:
  	var l: Dictionary = Data.defence_info(type)["levels"][lv - 1]
  	var c := {"leaves": int(l["upgrade"])}
  	if int(l.get("shards", 0)) > 0:
  		c["shards"] = int(l["shards"])
  	return c
  ```
- `_upgrade_defence(type)`: the guard becomes `dl >= levels.size() or dl + 1 > Save.camp_level or (dl + 1 >= 4 and
  not Data.raids_open())`; pay `_def_cost(type, dl + 1)`.
- `_card_stall()`: the shard trade row (`main.raids.trade_shards`).
- `_skin_row` / `_next_skin`: skip skins with `"shards"` that are not in `Save.unlocks`; new `_gloomlit_row(slot)` and
  `_unlock_skin(slot)`.
- `_light_fire()` / `_flame_material()`: set the flame's `tint` from `Save.fire_look` (`gloom_raids.fire_looks`), and
  tint the fire's OmniLight `light_color` by the same colour.

### 17.5 `defences.gd`
- **Wrecks saved by reference** (fixes the index drift, which raids would hit at every wave):
  - in `build()`, after `var p := _spawn_saved(sp)` and the empty check: `p["src"] = sp`
  - in `place_here()`: build the dict first (`var sp := {...}`), then `Save.placed.append(sp)`, then
    `p = _spawn(...)`, then `p["src"] = sp`
  - `_save_wrecks()`:
    ```gdscript
    for p in pieces:
    	var sp = p.get("src")
    	if sp == null:
    		continue
    	if p["wrecked"]:
    		sp["wreck"] = float(p["hp"]) / float(p["max_hp"])
    	else:
    		sp.erase("wreck")
    Save.save_game()
    ```
  The save format does not change.
- `level(type)`: clamp to `(Data.defence_info(type)["levels"] as Array).size()` instead of 3.
- `model(type, lv)`: tower `acorn_tower_%d` and spikes `thorn_spikes_%d` with level 4. If the level 4 prop does not
  exist yet (`not Props.has(...)`), use the level 3 model plus a `gloom_shard` crystal child (or a small scaled
  `gloom_crystal` until `gloom_shard` exists) at `CAP_AT[type]`: barricade (0, 0.95, 0), tower (0, 2.35, 0), spikes
  (0, 0.12, 0). These are first guesses; check them in the `--shards` close-ups.
- `repair_cost()`: when raids are open, per piece `piece * (1 + mend_per_level * (lv - 1)) * mend_share * missing`.
- New `piece_mend_cost(p) -> int` and `mend_piece(p)` (for Mend some), next to `repair_raid()`.
- New `lane_guard(ln: int) -> float` (section 6).
- Comments: "raid damage" becomes "damage kept after a Gloom Raid or a camp fall".

### 17.6 `enemy.gd`
- One line: `match id:` in `_think` (line 468) becomes `match String(info.get("ai", id)):`, so the Herald reuses the
  crow's drumming. Nothing else is keyed on the Herald's id.
- Nothing else. Raids use the mission behaviour: trails, `_siege` (towers, then buildings, then the fire), fliers and
  the Last Stand hunt. The rout is in `fight.gd`.

### 17.7 `world.gd`
- New `swap_sign()`: replaces the signpost node built in `rebuild_camp()` with `signpost_watch` when
  `Data.raids_open()` (or the placeholder below), at the same `station_pos("sign")` and with the same 0.2 m collision
  circle. `rebuild_camp()` uses the same choice. Keep the node in `var sign_node`.
- Placeholder until `signpost_watch.glb` exists: the old `signpost` with a `gloom_crystal` child named `fill` at
  (0, 1.55, 0), scale 0.35.
- `gloom_returns`, `settle_gloom` and `lift_gloom` are used as they are. In the endgame every patch is claimed, so
  `settle_gloom` settles to 0. *(Known quirk: `_apply_gloom` shrinks the gloom-crystal scatter once a patch is clear, so
  `gloom_returns` brings back the ground tint, the mist and the eyes only. That is enough.)*
- Phase D adds **no new world spot**. Nothing goes south of the campfire (that is the Burrows hollow's place).

### 17.8 `hud.gd`
- The shard row (`_shard_box`, `_shard_l`, `_shard_tex = _make_shard()`, `_shown_shards`).
- `_cost_button`: after timber, `if int(cost.get("shards", 0)) > 0:` add `_btn_icon(_shard_tex)` and
  `_btn_label(str(n), 26, Save.shards >= n)`.
- `refresh()` and `_process`: show `_stage_l` and `_gate_bar` when `f.active or main.raids.meter_shown()`. The text is
  `f.status_text()` while active, else `main.raids.hud_text()`.
- `_draw_gate()` -> `_draw_raid_bar()` branch (section 14.1).
- `point_at(pos, secs)` with `_point_pos` / `_point_t`, used by `_draw_overlay` (section 14.3).
- `hud.status` is not used, because `main._update_rebuild` clears it every frame.

### 17.9 `data.gd`
```gdscript
func can_afford(cost: Dictionary) -> bool:
	return Save.leaves >= int(cost.get("leaves", 0)) and Save.timber >= int(cost.get("timber", 0)) \
		and Save.shards >= int(cost.get("shards", 0))

func pay(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	Save.leaves -= int(cost.get("leaves", 0))
	Save.timber -= int(cost.get("timber", 0))
	Save.shards -= int(cost.get("shards", 0))
	return true

func gr() -> Dictionary:
	return b["gloom_raids"]

func raids_open() -> bool:
	return next_mission() >= mission_count()

## Phase C replaces this body with the guardian's real level. If Phase C was built first, keep its version.
func guardian_level() -> int:
	return 0
```

### 17.10 `pickup.gd`
- `var kind := "leaf"`. `setup(m, v, at, k := "leaf")`: a shard uses the `gloom_shard` model (placeholder: a small
  scaled `gloom_crystal`).
- `_collect()`: a shard plays the `shard` sound and `Fx.sparkle`, and never touches Save (its value is already banked).
  `steal()` ignores shards.

### 17.11 `flame.gdshader`, sounds
- `flame.gdshader`: `uniform vec3 tint = vec3(1.0);`, multiplied into the flame's colour (Shardfire).
- Sounds in `game/assets/sfx/`: `raid_horn.wav` (a long low horn, about 2.5 s), `shard.wav` (a glassy chime),
  `rout.wav` (a whoosh). Until they exist: `horn` at +4 dB twice, `pickup`, `win`. `Sfx.play` already plays nothing
  for a missing file.

---

## 18. New character for the user's Meshy: the Gloom Herald

The only new character in Phase D. Until it exists, the placeholder is the Crow Drummer model at scale 1.25 (section
15.2), which already works with the drum AI.

**Concept image prompt.** Make it with Codex CLI `image_gen`: one single image, with the Cat Ranger sheet as the style
reference. Save the prompt as `concepts/enemies4/prompts/01_gloom_herald.txt` and the image as
`concepts/enemies4/01_gloom_herald.png`.

```
SUBJECT: A Gloom Herald, the raid leader who blows the Gloom's war horn: a hunched, hooded forest creature of dark bark and thorny roots, about one and a half times the height of a cat, standing upright on short stubby root legs, with long thin arms. A deep violet hood with a drooping pointed tip hides its face; two glowing violet eyes shine in the shadow of the hood. Mossy shoulders with a few small solid violet crystal growths. It holds a big curled cream-coloured bone horn bound with wooden bands in both hands, raised a little as if about to blow it. On its back a tall crooked pole carries a tattered violet banner with a pale crystal at the top. Mischievous and pompous rather than scary, never gory. No other weapons.

STYLE: Stylized LOW-POLY 3D game model render in the same art style as the attached reference image: few, large faceted flat-shaded polygons with visible facets, simple chunky cute shapes, no fine detail, clean matte saturated colours with simple painted patches, soft even studio lighting. A bright, friendly fantasy mobile-game look.

CAMERA AND POSE: front view turned about 20 degrees to the side, camera at chest height. Neutral standing pose, the horn held a little away from the body at chest height, the banner pole clearly behind one shoulder.

FOR A 3D MODEL GENERATOR: Exactly one subject, alone. The whole body visible from top to bottom with empty margin on every side, centred, nothing cropped. No ground, no base, no props lying around. Plain flat light-grey background with no gradient, no floor and no cast shadow. No particles, smoke, sparkles or floating effects. Limbs held a little away from the body so they read clearly.
ONE SINGLE IMAGE: not a character sheet, no multiple views, no turnaround, no close-up insets, no colour swatches, no text, no labels, no watermark, no border.
REFERENCE: use the attached image only as an art-style reference (the low-poly faceted 3D look, shading and colour saturation). Do not draw the cat and do not copy its sheet layout.
```

**Model and rig** (`docs/ASSET_RULES.md` and `docs/AGENT_BRIEF_MESHY.md`):
- Budget **5,000 triangles** (the Crow Drummer's class).
- `RIG_herald`, `SK_herald`, root bone `root`.
- Spring chains, only when `Quality.springs()`: the banner `jig.banner.1-3` (stiffness about 1.5, drag 0.5) and the
  hood tip `jig.hood.1-2`.
- Clips, all in place at 30 fps:
  - `Idle`
  - `Walk`
  - `Attack` (swings the horn like a club; event `hit`)
  - `Hit`
  - `Die` (ends collapsed; the banner falls)
  - `Drum` (raises the horn and blows, about 1.2 s; event `beat`). The name `Drum` lets the crow's code drive it.
- `aim_height_m` about 0.9.
- Output `game/assets/enemies/herald/herald.glb` and `herald.json`. Add `herald` to the ASSET_RULES id list and clip
  table ("herald: + `Drum` = blows the horn"), and the budget row.
- Once it is in: `"model": "herald"`, and drop `scale`.

---

## 19. Blender props (Claude models them; ASSET_RULES apply)

All props follow ASSET_RULES:
- per-face vertex colours on the one `M_VertexColor` material, a flat faceted look, colours from `art/palette.json`
  (`crystal_violet`, `crystal_light`, `gloom_violet`, `gloom_dark`, `gold`, `cream`, `wood_*`, `moss`, `stone_*`; no
  new palette entries are needed)
- front faces Blender -Y, origin on the ground at the footprint centre, transforms applied
- parts the game moves are separate objects with set names and their origin at the pivot
- the `blender-asset-qa` gate before export
- each prop goes into a new group file `game/assets/props/raids.json` (group "raids", the same schema as
  `barricades.json`); working file `art/blender/props/raids.blend`; scripts in `art/scripts/props/raids/`; previews in
  `art/previews/props/raids/`
- run Blender with `TEMP` and `TMP` set to `D:\DevCache\tmp`

| Name | Size (m, W x H x D) | Budget (tris) | What it is | Named parts |
|---|---|---|---|---|
| `signpost_watch` | 0.9 x 2.0 x 0.4 | 1,500 | The existing `signpost.glb` (0.9 x 1.53 x 0.28, three arrow signs, readable side facing -Y), with a small wooden cradle on top holding a big curled cream horn with wooden bands, its bell pointing north (+Y, away from the camera). Under the cradle, a small twig cage holds a tall violet crystal column. Three hooks for ribbons. Same origin, facing and 0.2 m collision circle, so it swaps in place. | `fill` (the crystal column, origin at its base, about 0.5 m tall; the game scales it in Y from 0.06 to 1.0), `horn` (origin at the cradle, for the blow bounce), `lookout_flag` (a small green pennant on a stick; hidden until Lookout is owned), `tracker_bell` (a small bronze bell on a hook; hidden until Tracker is owned), `ribbon_1`, `ribbon_2`, `ribbon_3` (gold, green and white streamers; hidden until streaks 3, 5, 10) |
| `gloom_shard` | 0.12 x 0.18 x 0.12 | 100 | One faceted violet crystal with a pale lilac core and a thin gold glint. Used for the shard shower pickups and as the placeholder crystal on level 4 defences. | none |
| `rubble_pile` | 0.6 x 0.25 x 0.5 | 300 | Broken planks, two stones and three small violet crystal chips. Placed by code at worn buildings. | none |
| `barricade_shard` | 3.0 x 0.95 x 0.7 | 1,200 | Level 4 road barricade (Shardstone): the thorn gate rebuilt on a low stone footing, with violet-white shard crystals set in its posts and tips. 3.0 m along X like the others; front -Y faces the woods. Collision box 3.0 x 0.6. | none |
| `acorn_tower_4` | as `acorn_tower_3`, about 1.0 x 2.6 x 1.0 | 1,500 | Level 4 acorn tower: the level 3 tower with a crown of pale shard crystals and a crystal lens over its acorn launcher, bound with pale vines. | `turret` (origin on its turning axis), marker `marker_shoot`, as `acorn_tower_3` |
| `thorn_spikes_4` | as `thorn_spikes_3` | 1,500 | Level 4 spikes: the thorn bed with violet crystal thorns among the wooden ones. | none |

Optional, only for step D12: `moth_lantern` and `bramble_snare` (section 21).

---

## 20. Quality and performance (low-end phones)

- **Live enemies** in raids are capped by graphics level: Low 18, Medium 24, High 28 (`max_alive_by_quality`, read once
  into the spec). Queues can be longer; they wait. Missions keep 28. Wave sizes (12-24 plus the leader) never exceed
  what missions already do, so the O(n²) separation in `main._physics_process` stays within today's numbers. Measured
  today: 17-18 enemies at about 114 fps on the S24 at every level.
- **No new lights.** The signpost's crystal and the shards glow through bright vertex colours plus the existing glow
  (High only). Shardfire reuses the fire's existing OmniLight and only changes its colour.
- **Pickups**: the shard shower is `mini(Quality.particles(8), n / 3)` pickups (4 on Low). The rout drops at most 12
  leaf pickups in all, and plays at most 8 petal bursts on Low (`Quality.particles(16)`).
- **Rubble**: at most 3 per building, so at most 18 x 300 = 5,400 triangles.
- **Mist on Low**: check that `gloom_returns` reads on Low (`ground_lite`). The mist and eye meshes should still show.
  If they do not, the HUD arrow carries the direction.
- **Per-frame cost**: `raids.tick` is O(1). The HUD bar redraws only on change (and while pulsing). `lane_guard` and
  `camp_check` run only at stir, at the horn, at wave 1 and when the Watch card is built, never every frame.
- **Saves**: the meter saves quietly about once a minute, never every frame. The Watch card is rebuilt only on
  `Save.changed` or `refresh_card`; the countdown updates through the HUD label, not the card.
- **Measure** with `--raidperf` (section 23) on Low, Medium and High, and add the numbers to `docs/PERFORMANCE.md`.
  Target: no worse than the 17-18 enemy mission fight, and Low at a steady 30 fps on the low-end test phone with a level
  23 siege raid (stump golems are 5,000-triangle models).

---

## 21. Optional later: counters bought with shards (step D12)

From the gameplay design. Build these **only after the core raids have been played and the user says yes** (section
25, question 7). They give sky and siege raids a counter the player can buy. The Watch Bell from that design is folded
into the signpost's Lookout and Tracker.

### Moth Lantern (answers the sky raid)
- A free-placed piece like a tower (`defences._valid`). At most 2. Health 400 (one level). Collision circle 0.5.
- **Lure**: a flier within 7 m of a standing lantern goes for the lantern before any building. `enemy._siege(true)`
  checks `main.defences.lure_targets()` first. These have the same shape as `tower_targets()`:
  `[handle with hurt(), pos, 0.5]`. Ground foes ignore lanterns.
- **Zap**: every 0.5 s, fliers within 2.5 m take 7 damage, with an `Fx` spark line. Moths circling the lantern burn
  down while the buildings are left alone, until the lantern breaks.
- Price: 300 leaves + 30 shards each. Shop row "Moth Lantern" / "Lures moths away from your buildings and zaps them ·
  %d of 2".
- Prop `moth_lantern` (0.6 x 2.3 x 0.6 m, 1,500 tris): a crooked dark-wood post with a crossbar and a big round lantern
  of warm amber-white glass (bright faces, no light) in a twig cage, with two pale lilac cloth streamers like moth
  wings. Footprint radius 0.45. It may start from `lantern_post.glb`.

### Bramble Snare (answers the siege)
- It goes on a **barricade road spot** (`world.barricade_slots()`), so each spot holds either a barricade (it blocks)
  or a snare (it roots). At most 4. It does not block, has no health, and enemies never target it.
- When a ground foe comes within 1.0 m and the snare is ready, it **roots** that foe for 2.5 s (bosses 1.2 s), deals
  30 damage and cancels a charge or windup. Then it rests for 8 s. Its bud snaps shut, then opens again.
- New `enemy.root(t)`: while it lasts, no `_walk`; the charge, windup or dash is cancelled (check the state names at
  enemy.gd 1072-1113 for charges and 1177-1196 for the bear's dash); it plays `Hit`, then `Idle`.
- Price: 120 leaves + 15 shards each. Saved as `{type: "snare", slot: [lane, i]}`. `keep_damage` skips snares.
  `lane_guard` counts each snare as 100.
- Prop `bramble_snare` (1.6 x 0.3 x 1.0 m, 1,000 tris): a flat ring of thorny bramble loops across a road, with a
  closed green bud in the middle as the child object `bud` (pivot at its base), front -Y facing the woods.

Balance, in `defences` (`unlock_missions: 15`, so `defences.unlocked()` needs no change):
```json
"lantern": {"name": "Moth Lantern", "piece": 300, "piece_shards": 30, "unlock_missions": 15, "max": 2,
            "lure_r": 7.0, "zap_r": 2.5, "zap_damage": 7, "zap_every": 0.5, "levels": [{"hp": 400, "upgrade": 0}]},
"snare":   {"name": "Bramble Snare", "piece": 120, "piece_shards": 15, "unlock_missions": 15, "max": 4,
            "trigger_r": 1.0, "root_s": 2.5, "boss_root_s": 1.2, "damage": 30, "every": 8.0, "levels": [{"upgrade": 0}]}
```
The lantern and snare loops run only while `fight.active` (at most 2 lanterns and 4 snares against the foes).

---

## 22. Hooks for Phase C and Phase E

**Phase C (guardian, garden, cooking, fishing).** None of these are needed for Phase D to work, and Phase D works
whichever phase is built first.
- **The guardian**: `main.get("guardian")` may be null. If it exists, Phase D calls `on_raid_start()` (in
  `raids.try_warning`) and `on_raid_end(won)` (in `raids.finish`) when it has those methods, and shows its
  `status_text()` on the Watch card when it has one.
  - The camp score uses `Data.guardian_level()`, which Phase C implements.
  - Raid enemies attack the guardian through Phase C's own target list in `enemy._siege`, added beside
    `defences.tower_targets()`. Phase D adds no guardian targeting.
  - Knocking the guardian down never spoils a perfect defence, and raids charge no repair cost for it: it is a
    companion, not a structure. Its recovery can key off `main.on_wave_cleared` (the breathers) and
    `raids.raid_ended`.
- **Meter actions**: a harvest calls `main.raids.add_gloom("harvest")`, a dish cooked `add_gloom("dish")`, a fish caught
  `add_gloom("fish")`. Action points never fill the meter past 95%.
- **Mini-games**: while Phase C sets `main.busy_minigame = true` (fishing, cooking), a full meter waits and no warning
  starts. Phase C must end or pause a mini-game when `fight.in_wave` turns on.
- **Raids never target** the garden, the fishing dock or anything Phase C adds for calm play, unless Phase C adds it to
  `stations.BUILDINGS` on purpose.
- **Dish boosts** "for the next chapter or raid": listen to `raids.raid_started(spec)` and end on
  `raids.raid_ended`.
- **Shards**: `Data.pay` and `_cost_button` understand `"shards"`, so the guardian stone's upgrades can use them.

**Phase E (the Burrows).**
- The meter does not fill, and a pending warning does not start, while `main.get("area") != null`.
- A finished Burrows run calls `main.raids.add_gloom("burrow_run")`.
- **Keys**: Phase D writes `Save.burrow_keys`: +1 per raid held, +1 more for an elite raid, at most 3 held. There is no
  daily refill and no clock, so "a few keys a day" follows from play alone. Phase E reads and spends them.
- Level 5 of each defence and the guardian's top level cost Burrows materials. `Data.pay` gets a material key, as it
  gets `shards` here.
- The hollow is due south (world research). Phase D adds nothing south of the campfire.

---

## 23. Autotest modes (`game/scripts/autotest.gd`)

They use the test save as now and the existing helpers (`_veteran(15)`, `_log`, `_shot`, `_wait`, `_go_to`,
`_measure`). Each check logs `PASS` or `FAIL <what>`. The test loops call `main.raids.touch()` every frame so the idle
guard does not stop the meter, except where idle is tested.

Debug args, read through `Data.args()`:
- `--raid-meter=N` sets the meter
- `--raid-type=siege|sneak|sky|elite` forces the next plan
- `--raid-small` uses count [2, 3], 2 waves and a 1 s breather
- `--raid-warn=S` sets the warning length (clamped to 30-60)

| Mode | What it does and checks |
|---|---|
| `--raid` | Veteran 15, `--raid-small`, meter 99, tick: `pending`, the warning starts. Check `fight.active`, `mode == "raid"`, `warning`, `in_wave == false`, `world.inside_camp(Vector3(0, 0, 1))` true, the HUD shows the warning text. `next_phase_now()` -> wave 1. Kill the foes (`e.hit`), reach the last wave, spawn and kill the herald: every other foe fled and leaves were dropped. Raid held: shards gained = the formula x1.5 (perfect, no ruins), plus x0.2 if the camp was whole; `held + 1`; renown +1; meter 0; `mode == "mission"`; `burrow_keys == 1`. `Save.mission_run`, `missions_done`, `claimed`, `stages_won` and `stages_lost` unchanged. `world.gloom[ln]` back to 0. |
| `--raidloss` | Start a raid; ruin a building (`stations.hurt_building(id, 99999)`), damage a barricade; `damage_fire` to 0 (Last Stand), `rebuild_fire`, `damage_fire` to 0 again: lost. Check: leaves and timber unchanged except for pickups and the rebuild's 10 timber; `fire_ruined == false` and the fire is lit; `mission_run == {}`; the ruin kept; the barricade wrecked in **its own** `Save.placed` entry; renown -2 (not below 0); `lost + 1`; shards += 2 x waves held; `pending == false`. Then a mission replay won does **not** clear that ruin. |
| `--raidsave` | During the warning (`warn_left` 40): `raids.persist()`, `Save.load_game()`, a test reset of the fight, `raids.restore_on_load()`: `pending`, `warn_left` 40, the same plan and seed. Hold wave 1; in wave 2 ruin the well and damage the home; `persist()`; reload: `run.wave_done == 1`, warning at 30 s or more, the well still ruined, `wear.home > 0`, the wrecks kept, and wave 2's queue is the same as before. Quit during a Last Stand: on reload the fire is at 30%, `rebuilt == true`, no timber charged. The save file has no time values. The no-clock grep (section 13) finds nothing outside autotest.gd. |
| `--raidresume=1` / `--raidresume=2` | Two runs. Run 1 (`--fresh`): veteran 15, fill the meter, start wave 1, ruin the target, quit. Run 2 (no `--fresh`): load. Check `mode == "raid"`, back at the warning, the target still ruined, shards unchanged. Also: run 1 saves meter 40 with no raid, run 2 reads exactly 40. |
| `--meter` | 600 ticks of 0.1 s: the meter rises 10 (±0.1). One tick of 30 s: at most +0.0167 (0.1 s worth). `idle_t = 46`: no fill. `fight.active`: no fill. `fire_ruined`: no fill. `pending`: no fill. `add_gloom("replay_chapter")`: +6. Action points from 90 stop at 95. Crossing 75: a plan exists. `main._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)` saves quietly and nothing moves. `call_now()` below 50 does nothing; at 50 or more the warning is 30 s (45 with Lookout). |
| `--raidtypes` | For each kind: `Save.raids.plan = raids._plan()` with `--raid-type`, `_go_pending`, Go, wait 8 s, shot, log the kinds and `patch` of each foe, then `_clear_foes` and end. Barricades on trails 0, 1 and 2 only. Check: sky has moths; sneak spawns only on trail 3 and no `gloom_returns` was called before the reveal; elite's wave 3 sets `hud.boss` to the boss; siege has stumps, brutes and boars; no raccoon in any raid; no kind 3 times in a row from 20 rolls; every warning is 30-60 s with and without Lookout. |
| `--wear` | A raid where the home loses 30% and the stall 0: wear `{home: 0.3}`. The next `reset_hp`: the home at 70%. The patch cost follows the formula. `mend_all` with plenty of leaves clears ruins, wrecks and wear; with few leaves "Mend some" mends in priority order. The camp condition is 100% after a full mend. |
| `--shards` | `Data.can_afford` and `pay` with shards. Buy Lookout: the next normal warning is 60 s (not 75). Level 4 defences: hidden before every mission is won, blocked below home level 4, then bought (leaves and shards taken), `level()` returns 4, the barricade's max_hp is 1,400, the placeholder cap shows (close-up shots). Unlock Gloomlit: `_next_skin` includes it. The shard trade gives 100 leaves for 5. The Shardfire tint is set. |
| `--raidperf` | A level 23 siege raid at High, Medium and Low (`--quality=`), 60 s each: fps, triangles and draw calls via `_measure`, plus a shot of the warning (the mist on the trail) and the Watch card. Add the numbers to PERFORMANCE.md. |
| `--raidshots` | Close-ups (`main.closeup`) of the signpost Watch at fill 0, 0.5 and 1, with the flag, the bell and the ribbons; the HUD meter, warning and wave states; the "Perfect defence!" banner. For the lead's review. |

`--laststand` and every existing mode (`--resume`, `--village`, `--siege`, `--smoke`, `--levels`, `--skins`, `--bars`)
must still pass unchanged. The mission paths are untouched, except `repair_all_free(before)`, which applies only to
missions started after the endgame.

---

## 24. Build order (small steps; each ends green on its autotests with nothing broken)

**Progress (18 Nov 2026):** D1 to D9 are built and tested. D10 waits for the user's Meshy model: the placeholder (the
Crow Drummer at 1.25x) is in. D11 is done on the PC (`--raidperf`, the docs); the balance pass on the phone is left.
D12 is not built (optional). Build notes, test results and what Phase E needs: docs/PHASE_A_PROGRESS.md, "Phase D".

1. **D1 Plumbing.** **[built]**
   - Save fields, `RAIDS_DEFAULT`, migration, `save_game(quiet)`.
   - `Data.can_afford` / `pay` with shards, `raids_open`, `gr`, `guardian_level`.
   - The HUD shard row, icon and cost icon.
   - The `gloom_raids` balance block (without the herald).
   - Test: `--shards` (afford and pay only); an old save loads; a save written and read back keeps the new fields;
     `--smoke`.
2. **D2 Defence and repair fixes.** **[built]**
   - Wrecks saved by reference (`p["src"]`).
   - The `level()` clamp, the endgame mend price, `piece_mend_cost` / `mend_piece`.
   - The endgame ruin price and cap, `full_hp`, `reset_hp` with wear, `save_wear`, `_repair` fixes,
     `repair_all_free(before)` with `_endgame_run`.
   - `lane_guard(ln)`.
   - Test: `--laststand`, `--siege`, `--resume` still pass.
3. **D3 Raid mode in fight.gd.** **[built]**
   - `mode`, `raid`, `warning`, `info`, `strength`, `_max_alive`, `_rand`, `title`, `status_text`, `start_raid`,
     `_raid_wave_cleared`, `camp_falls` -> `_raid_over`, `_rout`, the `start_mission` refusal.
   - `main.on_raid_start`, the `on_stage_end` raid branch, the `on_wave_start` raid branch.
   - Start raids only from the autotest with a hand-made spec and a stub `raids.gd` (`finish`, `on_wave_held`).
   - Test: `--raid` (no meter), `--raidloss`, `--laststand`.
4. **D4 raids.gd core.** **[built]**
   - Meter (clamp, idle, actions, bump cap, quiet saves), `_input`, `_notification`, `persist`, `restore_on_load`.
   - Plan (kinds, lanes, level, leader, seed), `spec_for`, warnings (lengths, hold, reveal), pay, perfect, ready,
     renown, keys, loss.
   - The replay bumps and the intro on the last mission's win.
   - Test: `--meter`, `--raid`, `--raidloss`, `--raidsave`, `--raidresume=1/2`, and the no-clock grep.
5. **D5 Presentation.** **[built]**
   - The HUD top right (`_draw_raid_bar`), `point_at`, the Watch card in all states, the raid card, banners, toasts,
     tips.
   - `gloom_returns`, `lift_gloom` and `settle_gloom` on raid trails.
   - The signpost swap with the placeholder fill.
   - Test: `--raidshots`.
6. **D6 The Herald and the rout.** **[built, with the crow placeholder]**
   - The `ai` key in enemy.gd, the `herald` balance entry (crow placeholder), the leader meta, the boss bar, `_rout`,
     the elite rotation.
   - Test: `--raid` (rout), `--raidtypes`.
7. **D7 Keeping up.** **[built]**
   - Wear: the look (placeholder rubble: `rock` props or small `gloom_crystal`s), the Patch rows.
   - `camp_check`, camp condition, Mend all / Mend some with staggered effects, the shop's camp check row, the
     "under attack" toasts.
   - Test: `--wear`.
8. **D8 Shard goods.** **[built]**
   - Level 4 defences (placeholder look), Lookout and Tracker, Gloomlit skins, Shardfire (flame tint), the shard trade,
     the `told_shards` tip.
   - Test: `--shards` (full).
9. **D9 Blender props.** **[built: the six GLBs were made before the code, and the code uses them]**
   - `signpost_watch`, `gloom_shard`, `rubble_pile`, `barricade_shard`, `acorn_tower_4`, `thorn_spikes_4`, with the
     QA gate and `raids.json`. Then swap out the placeholders.
   - Test: `--raidshots`, `--shards` close-ups.
10. **D10 The Gloom Herald.** **[not built: waits for the user's Meshy model; the placeholder is in]**
    - The concept image (Codex CLI, one image), then the user's Meshy model, then colour, rig and clips in Blender per
      `docs/AGENT_BRIEF_MESHY.md`. Drop it in and set `"model": "herald"`.
11. **D11 Balance, performance and docs.** **[done on the PC: `--raidperf` and the docs; the phone balance pass is
    left]**
    - `--raidperf` on Low, Medium and High, and play on the phone. Tune `count`, `strength`, `pay` and `per_minute`.
    - Update GAME_PLAN.md (section 26), `game/README.md`, the `raid` note and PERFORMANCE.md.
12. **D12 (optional, only with the user's yes)** Moth Lantern and Bramble Snare (section 21), with their props.
    **[not built]**

---

## 25. Questions for the user (the *(proposal)* choices)

The build uses the first answer until the user says otherwise.
1. **Calling a raid early** from 50% ("Sound the horn", a 30 s warning): yes, or should raids come only when the meter
   is full?
2. **Building wear** between raids (a worn building is weaker until patched): yes, or only ruins (all or nothing)?
3. **The Gloom Herald and the rout** (beat the leader and the rest flee): yes? It needs one new Meshy model.
4. **A few shards on a loss** (2 per wave held): yes, or nothing at all?
5. **Defence level 4 for shards** (with level 5 for Burrows materials): yes, or should all top defences wait for the
   Burrows?
6. **A truly new raid direction** (a southern or lake trail for sneak raids) needs world and shader work for a 5th
   trail, and the south is the Burrows' side. Keep sneak raids to "the least-guarded of the 4 trails" for now?
7. **Moth Lantern and Bramble Snare** (counters bought with shards): add them after the core raids have been played?
8. **Selling shards to Bramble** (5 for 100 leaves), so shards are never useless: yes?
9. **Pace**: about 10 minutes of play per raid, or about 5 when the player calls them early. Start there and tune by
   play?

---

## 26. GAME_PLAN.md changes (step D11)

**Section 0, "After the missions", replace the Gloom Raids and Keeping the camp up bullets (lines 119-126) with:**

> - **Gloom Raids** (Phase D, see docs/PHASE_D_SPEC.md). A Gloom meter (the Watch: a horn and a crystal on the
>   signpost) fills only while the game is being played: time in the camp with no fight on (not while idle), plus
>   things the cat does (replays, garden, cooking, fishing, Burrows runs). **Nothing happens while the game is closed**:
>   the meter does not fill, no raid is fought, nothing is lost. A raid that was coming, or being fought, when the game
>   closed comes back at its warning (at least 30 s) when the player returns. When the meter is full the horn sounds
>   and a raid arrives after a warning (45 s; 60 s for the first raid and for elite raids; never more than 60), and the
>   player can meet it early from the signpost. Kinds: siege (bruisers for buildings), sneak (the least-guarded trail,
>   hidden until 15 s before), sky (moths over the barricades), and a rare elite raid led by a boss. A raid is 3 waves;
>   its last wave is led by the Gloom Herald (or the boss): topple the leader and the raid breaks. Repelling pays Gloom
>   shards, leaves and timber; a perfect defence (no building lost, the fire never out) pays 50% more shards, and a
>   camp that was whole when the raid began pays 20% more. A lost raid leaves only damage to repair, nothing else, and
>   the next raid is a little gentler. The raid level grows with the camp (home, stations, towers, defence levels,
>   guardian) and with raids won, never with the cat's own upgrades.
> - **Keeping the camp up.** Ruins, wrecked defences and building wear carry over between raids and are saved as they
>   happen. Repair at each building, mend defences in the shop, or tap "Mend all" at the signpost. Endgame repairs are
>   capped in price. Raids knock the guardian down; it gets up again by itself.
> - **Gloom shards** are earned only by playing and are never sold. They buy defence level 4 (Shardstone), the Watch's
>   Lookout and Tracker, earned-only looks (Gloomlit colours, Shardfire), or leaves from Bramble.

**The Burrows bullet:** "*(proposal)* A few keys a day so they never replace the camp." becomes "Keys are earned by
holding raids (1, or 2 for an elite raid, at most 3 held), never refilled by a timer, so they never replace the camp."

**"Built so far", line 24:** "If the cat falls then, the Gloom Raid takes 30% of the unspent leaves" becomes "If the cat
falls then, the camp falls: the Gloom takes 30% of the unspent leaves", so the mission penalty is not confused with the
new Gloom Raids.

**Build order:** mark D as built when step D11 is done.

---

## Props as built (18 November 2026, notes for the code)

All six section-19 GLBs are in `game/assets/props/` with `raids.json` (group "raids", `size_m` as [x, y, z] like
`barricades.json`). Contact sheet: `art/previews/props/raids/raids_contact_sheet.png`.
- `signpost_watch.glb` (1,364 tris): parts `fill`, `horn`, `lookout_flag`, `tracker_bell`, `ribbon_1..3`, all children
  of the root and all VISIBLE in the GLB: the code must hide `lookout_flag`, `tracker_bell` and `ribbon_1..3` at load.
  `fill`'s origin is at its base, Godot (-0.255, 1.232, 0.005) from the root, 0.476 m tall: scale its local Y from 0.06
  to 1.0. The crystal cage hangs under the cradle's left arm (-X), so the placeholder's (0, 1.55, 0) does not apply.
  `horn`'s origin is at the cradle, Godot (-0.04, 1.825, 0.005) (ready for `Fx.boing`). The root keeps the old
  signpost's origin, so it swaps in place.
- `gloom_shard.glb` (72): origin at its lower tip on the ground; its centre is 0.09 m up (lift it that much to spin it
  about its centre).
- `rubble_pile.glb` (223), `barricade_shard.glb` (1,168; collision box 3.0 x 0.6), `thorn_spikes_4.glb` (989).
- `acorn_tower_4.glb` (1,496): `turret` at Godot (0, 2.54, 0), `marker_shoot` a child of `turret`, `banner` a part,
  the same pivots as level 3; 3.15 m tall. Hidden faces under 12 degrees were removed (fine from the game camera).
- With the level-4 GLBs present, `Props.has()` picks them up; the cap-crystal placeholders are no longer needed.
