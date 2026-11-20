# Phase C spec: the Moss Warden, the garden, cooking and fishing

17 November 2026. The build spec for GAME_PLAN.md section 0 (Draft 7), build step C. Nothing here is built yet.

**Where this comes from.** Three designs were written and judged. All three judges picked the "lean and safe" design
as the base. This spec is that design, with every rule problem the judges found removed, and the best ideas of the
other two grafted in:
- from "gameplay first": the Warden's post (guard the camp or hold a trail), charge blocking, a range check when a hit
  lands on the Warden, the `stagger()` helper, summed damage numbers, the cat helping the Warden pull itself
  together, meals picked for the next chapter's threat, +1 growth dry and +2 watered, one merged mesh for all garden
  plants, a "cook before the boss" tip;
- from "player delight": the player wakes the Warden with a card row, the dish is eaten by itself when the next chapter
  starts, tap-anywhere fishing with a white, blue or gold "!", a fish log, `banner_later`, the lake fireflies tied to
  Quality, and the GAME_PLAN offline-meter line flagged for removal.

**Status of the numbers.** Godot was not run for this spec and no game file was changed. Every balance number is a
first guess to tune by play (`--guardianab` gives the Warden's value). Positions from `world.gd` (station spots, rings,
trails, lake shore, footprints) are exact. Hide-spot and reed positions come from the Python replica of the camp in
the scratchpad (`campmap.py`); they still have to be checked in the game (`--camplife`).

## The user's rules, and how this spec keeps them

| Rule | How it is kept |
|---|---|
| One cat protecting its campfire camp; no villagers, residents, workers, expeditions or production timers | The Warden is a companion like Sprig and Thistle. The cat plants, waters, picks, cooks and fishes itself. Nothing produces anything on its own; the Warden gives no items. |
| Nothing works while the game is closed | No timestamps anywhere in the save. Plants grow only when a wave is held. A meal lasts one chapter. The Warden's regrow timer counts in-mission game time and stops on `main.frozen`. |
| No menus: rings and cards | Every new thing is a ring and a card built in `stations.gd`. Fishing has no screen of its own: it draws a small ring and a "!" over the float and listens for taps. |
| Stations only work between waves | `hud._spec` already blanks the cards in a wave; the leak in `hud._on_save_changed` is fixed (C0), and every new action checks `_locked()` itself. |
| One gameplay guardian; other looks change looks only | `looks.guardian` holds models and colours only. Every number is in `balance.guardian`. |
| Low-end phones | The Warden thinks 4 times a second with one group fetch. The garden and cooking have no per-frame code. Fishing runs code only while a line is out. Decorative extras follow Quality. |
| Characters from the user's Meshy, props from Claude in Blender | The Warden gets one concept image (Codex CLI) and a Meshy model from the user; Claude cleans it up, colours, rigs and animates it. Every prop is modelled by Claude in Blender (section 11). |
| Economy: leaves and timber, about 35,000 leaves over the 15 missions | New costs are about 4,600 leaves and 15 timber over a full run (section 6.8). No new currency appears on a cost button. |

## Fixes for what the judges flagged

| Flagged in | Problem | What this spec does |
|---|---|---|
| Delight | The Warden handed the cat a Glowbell every chapter break (a helper producing goods) | Dropped. The "flower for the cat" moment is cosmetic only, gives no item, and is an optional polish step (C7). |
| Gameplay | A full-screen fishing overlay with a "Done" button | No overlay screen. The fishing UI is a HUD drawing with `mouse_filter = IGNORE`; the player stops by walking away. |
| Gameplay | "Hold a trail" sent the Warden onto the trail outside the firelight | A held trail's post is the trail mouth on the firelight's edge (`world.edge_point`), with a 5.5 m leash. "Guard the camp" is the default. The choice lives on the stone card only. |
| Gameplay | Held enemies ignored the cat; the Vigil emptied the Last Stand | No "hold" mechanic. Enemies try the cat first, exactly as now, and only fight the Warden when it is in their way. In the Last Stand no enemy fights the Warden: it only swats what comes near the cat or the ashes. |
| Gameplay | Bosses "never dazed" against charges that daze the Thornstag | A charge into the Warden ends through the existing `enemy._end_charge()`, which is what a charge into a building already does (a short daze, for every charger). The slam's `stagger()` never dazes a boss. |
| Gameplay | Drum-buff formula said to double hits | Checked: `enemy.gd` L982 and L985 already use `(1.0 + buff if buff_t > 0.0 else 1.0)`; `buff` is an added share. The Warden's hits use the same expression, so nothing doubles. |
| Gameplay, Delight | `_act_target != main.player` while `_act_target` can be the String `"gate"` (a Godot 4 String-vs-Object comparison) | New public helpers in `enemy.gd` (`wrecking()`, `hitting_cat()`) test `is String` first, as `enemy.gd` L953 and L978 do. |
| Gameplay | A meal cooked in a breather boosted the current chapter | The dish waits in the pot and is eaten when the next chapter starts. |
| Lean | A meal lasted 5 waves held, spilling across chapters | Replaced by the chapter meal above. |
| Lean | The rod stayed in a holder; the cat never held it | The cat holds the rod on its bow-hand bone (`weapon.L`, from `CatRanger_clips.json` `bones.bow_hand`); the bow is hidden while it fishes. |
| Lean | Unwatered plots did not grow at all | Dry plots grow 1 step per wave held, watered plots 2. Water is a bonus, never a chore. |
| Lean | `hp = max_hp()` every frame outside missions | `guardian.refresh_stats()` runs only when something changes (purchase, camp growth, meal). |
| Delight | Mission gift turned into an Array (`["fish","pot"]`) | Gifts stay one String per mission. The pot comes with the garden. |
| Delight | Pot ring in the cat's main walking lane south of the fire; revive spot moved | The pot ring is north-east of the fire at (1.0, -1.0). The revive spot is unchanged. |
| Delight, Gameplay | 110-160 new timber on a tight timber budget | 15 new timber in total. Fishing gives a little timber (driftwood, chests). |
| All | GAME_PLAN section 0 says the Gloom meter "can fill offline" | Conflicts with the no-offline rule. Phase D must drop that line (open question 1). |
| Judge 3 | Fishing arrives late, so most recipes were teasers | Four recipes need only the garden. Fish recipes are not shown until fishing exists. |

---------------------------------------------------------------------------------------------------------------------

## 0. Decisions at a glance

| System | Unlock | Where (Godot metres, fire at 0,0) | Ring | Moves on | Per-frame code |
|---|---|---|---|---|---|
| Garden (`garden`) and Cooking Pot (`pot`) | Gift for the first win of mission 4, Stumps at Dusk (`stumps`, index 3) | Bed (0.5, 8.4), rotated PI. Pot on the fire's north-east rim: NE x (fire foot + 0.18) | Garden (0.5, 7.2); pot (1.0, -1.0) at every level | Garden: +1 step per wave held (+2 watered). Meal: one chapter | none (events only) |
| Moss Warden and Guardian Stone (`stone`) | Gift for the first win of mission 5, Bandit Night (`bandits`, index 4). The player wakes it with a card row. First fight: mission 6, Mossback Wakes | Stone (8.0, 0.75). The Warden rests at (6.9, 0.75) | (8.0, 1.85) | In-mission game time (regrow 30 s) and breathers | `guardian.gd`, thinks every 0.25 s |
| Fishing Spot (`fishing`) | Gift for the first win of mission 6, Mossback Wakes (`mossback`, index 5) | Prop (-7.2, 5.3), the lake's south shore | (-6.48, 5.28) | Active play only | `fishing.gd`, only while a line is out |

Why gifts and not shop rows: the shop card already scrolls past 6 rows, `_card_shop` hard-codes `sid == "well"`, and
`--village` presses "Build" 5 times. `stations.gift()` and `missions[i].gift` are a proven path, and the shop stays
untouched.

Why none of the new ids goes into `world.VILLAGE` or `stations.BUILDINGS`: `world.gd:380` and `grass.gd:55` index
dicts by every `VILLAGE` id and crash on a new one; `BUILDINGS` brings hp, ruins, repair costs and enemy sieges. The
stone, garden, pot and fishing spot cannot be wrecked. The Warden itself takes the hits.

Placement check (replica, home levels 1-6, everything built; worst clearance to anything):

| Spot | Worst clearance |
|---|---|
| Stone body, r 0.7 | 2.11 m (trail 2 at level 1) |
| Stone ring | 2.14 m |
| Warden rest spot, r 0.6 | 1.89 m (after the reserved-ground filter removes three level-1 bushes) |
| Garden bed, r 1.1 | 1.30 m (the stall's lane) |
| Garden ring | 0.51 m (the end of the village lane; the new garden branch continues from it) |
| Fishing prop, r 0.45 | sits on the shore, 0.33 m from the water |
| Fishing ring | 0.80 m from the water |

Ring spacing (main._update_rings takes the first ring that contains the cat, so centres must be 1.5 m apart or more):
stone 4.75 m or more from any ring, garden 2.39 m (stall), fishing 4.38 m (cottage), pot 1.64 m (bench and sign rings at
level 1). The pot ring keeps 1.05 m or more from the cat's start `(0, camp_r x 0.42)` and from the revive spot
(0.6, 1.4), and 0.75 m or more from the sign path. The level-1 camp has no other free ground for the pot.

---------------------------------------------------------------------------------------------------------------------

## 1. Groundwork (C0): no new gameplay yet

### 1.1 Safety fixes the new cards rely on

1. **Wave-lock leak**, `hud.gd` `_on_save_changed()` (L192-195). Every leaf pickup emits `Save.changed`, which refills
   an open card from `builder.call()` and brings back its live buttons in a wave. Replace with:
   ```gdscript
   func _on_save_changed() -> void:
   	refresh()
   	if _card != null and _card_ring != null:
   		_fill_card(_spec(_card_ring))
   ```
2. **Self-guard** in `stations.gd`, used by every new action:
   ```gdscript
   func _locked() -> bool:
   	return main.fight.active and main.fight.in_wave
   ```
3. **Pulse without a cost.** `stations._update_pulses()` (L347-359): a row may carry `"pulse": true`. The test becomes
   ```gdscript
   if row.get("enabled", false) and (row.get("pulse", false) or not (row.get("cost", {}) as Dictionary).is_empty()):
   ```
   `hud._fill_card` ignores the unknown key.
4. **`hud.banner_later(delay, title, color, sub)`**: `get_tree().create_timer(delay).timeout.connect(banner.bind(title,
   color, sub))`. Gift banners use it with 3.4 s, so the "mission won" banner stays readable. Use it for the existing
   stall and cottage banners too.
5. **`main.reopen_ring()`**: `_ring_on = null`, so the next `_update_rings` shows the card of the ring the cat stands on
   again (fishing uses it after a catch).
6. **`Fx.puff(parent, pos, color, amount := 10)`** in `fx.gd`, a public wrapper for water drops and steam:
   ```gdscript
   static func puff(parent: Node, pos: Vector3, color: Color, amount := 10) -> void:
   	_burst(parent, pos, _grad([color.lightened(0.3), color]), amount, 2.0, 0.6, 0.6, -4.0, 50.0)
   ```
   Its particle count goes through `Quality.particles` inside `_burst`.

### 1.2 Every registry a new id must join

New ids: `stone`, `garden`, `pot`, `fishing`. Ring id = building id for all four.

| Where | What to add | Why it matters |
|---|---|---|
| `stations.gd` `FOOT` (L27) | `"stone": 0.7, "garden": 1.1, "pot": 0.25, "fishing": 0.45` | `foot()` crashes on a missing key |
| `stations.build()` ring list (L33) | append the id when its system lands (C1, C2, C3, C4) | a ring id `X` needs a `_card_X()` builder |
| `stations.model_name()` | `stone` -> `guardian_stone`, `garden` -> `garden_bed`, `pot` -> `cook_pot`, `fishing` -> `fishing_spot` | |
| `stations.shown()` | `stone`, `garden`, `fishing`: `int(Save.stations.get(id, 0)) >= 1`; `pot`: `int(Save.stations.get("garden", 0)) >= 1` | the pot has no level of its own |
| `stations.ring_shown()` | `stone`, `garden`, `fishing`: `shown(id)`; `pot`: `shown("pot") and not _out and not Save.fire_ruined` | no cooking on the ashes |
| `stations.set_fire_out()` | at the end: `if rings.has("pot"): rings["pot"].visible = ring_shown("pot")` | the Last Stand hides the pot ring at once |
| `stations.refresh()` model list (L101) | append the ids; `if id == "garden": have.rotation.y = PI`; after `_ruin_look`, `if main.garden: main.garden.attach(nodes.get("garden"))` | the bed's work side faces the camp |
| `stations.refresh()` ring match (L132-142) | `"stone": station_pos + (0,0,1.1)`, `"garden": station_pos + (0,0,-1.2)`, `"pot": Vector3(1.0,0,-1.0)`, `"fishing": world.FISH_RING` | |
| `stations._station_upgrade_row()` (L726-738) | `elif id == "stone"` and `elif id == "garden"` before the bow-bench `else` | otherwise the row says "Bows up to level N" |
| `stations.gift()` (L287-298) | banners for `garden`, `stone`, `fishing` (1.5) | |
| `world.station_pos()` (L250-264) | see 1.3 | a missing id returns ZERO, which is the campfire |
| `world.rebuild_paths()` key (L351-352) | stone, garden and fishing levels | a new gift restamps the paths and the grass |
| `grass.gd` keep-out (L50-55) | a separate 3-key dict (1.3) | never the `VILLAGE` dict |
| **Not** touched | `BUILDINGS`, `VILLAGE`, `_ruin_card`'s dict, `_card_shop`, `_village_note`, `_build_station` | |

Card builders run inside `stations.build()` (through `_update_pulses`) before `main.hud` and the companions exist, and
again on every `refresh()` and every leaf pickup while the cat stands on a ring. Every new builder is cheap, has no
side effects, and null-guards `main.guardian`, `main.garden`, `main.cooking` and `main.fishing`. `main._ready` creates
`garden`, `cooking` and `fishing` before `stations.build`, so only `main.guardian` can be null there.

### 1.3 Positions and reserved ground (`world.gd`, `grass.gd`, `defences.gd`, `lake.gd`)

**`world.station_pos()`** gets:
```gdscript
"stone": return Vector3(8.0, 0, 0.75)       # east, just past the biggest firelight, south of the Bandit Thicket road
"garden": return Vector3(0.5, 0, 8.4)       # south, behind the end of the village lane
"fishing": return Vector3(-7.2, 0, 5.3)     # the lake's south shore
"pot": return Vector3(0.7071, 0, -0.7071) * float(POT_R[clampi(Save.camp_level, 1, 6) - 1])
```
with `const POT_R := [0.78, 0.98, 0.98, 0.98, 1.13, 1.08]` (the campfire foot by level + 0.18) and
`const FISH_RING := Vector3(-6.48, 0, 5.28)`.

**Reserved ground**, so random hide spots and placed defences stay off it, whether the station is built or not:
```gdscript
## Ground kept for the guardian stone, the garden and the fishing spot, built yet or not (Phase C).
const RESERVED := [[Vector3(8.0, 0, 1.0), 1.7], [Vector3(0.5, 0, 7.9), 2.0], [Vector3(-6.7, 0, 5.35), 1.3]]

func in_reserved(p: Vector3, margin: float) -> bool:
	for z in RESERVED:
		if Vector2(p.x - z[0].x, p.z - z[0].z).length() < float(z[1]) + margin:
			return true
	return false
```

- **Hide spots**: a post-filter at the very end of `_hideouts()`. The generation loop stays as it is, so the seed-909
  random sequence is unchanged and only spots inside reserved ground disappear:
  ```gdscript
  for i in range(hide_spots.size() - 1, -1, -1):
  	var h: Array = hide_spots[i]
  	if in_reserved(h[0], float(h[1])):
  		if h[3] != null and is_instance_valid(h[3]):
  			h[3].queue_free()
  		hide_spots.remove_at(i)
  ```
  The replica says this drops: level 1 grass (2.85, 9.43) and bushes (6.29, 0.23), (6.66, 0.57), (6.73, -0.71);
  level 2 grass (3.07, 10.17) and bushes (7.49, -0.83), (-8.42, 5.81); level 5 four bushes; nothing at levels 3, 4
  and 6. The trail tall grass (step 1, which `--grasswalk` uses) is untouched. Note: once the garden's path is drawn
  (1.4), the path test inside the loop can reject a different candidate, so the random meadow spots outside the
  reserved ground may shift once when the garden is built. The trail grass does not.
- **Grass**: after the `VILLAGE` loop in `grass.build`:
  ```gdscript
  for id in ["stone", "garden", "fishing"]:
  	if int(Save.stations.get(id, 0)) > 0:
  		keep_out.append([world.station_pos(id), {"stone": 1.0, "garden": 1.5, "fishing": 0.8}[id]])
  ```
  This dict is only ever indexed with its own three keys.
- **Defences**: `defences._valid()` adds `if main.world.in_reserved(pos, 0.6): return false`. `defences.build()`, after
  the fence-refund block: every tower or spikes entry in `Save.placed` (entries with `x`/`z`) inside
  `in_reserved(Vector3(x, 0, z), 0.6)` goes back to `Save.items[type]`; then
  `main.hud_note = "%d defence piece%s stood where the camp needs room: place it again"` and `Save.save_game()`. Old
  saves could place towers there, because `_valid` allowed anywhere off the roads.
- **Lake shore** (`lake.gd` `_shore()`): build each rock and reed `Transform3D` exactly as now (all random numbers are
  still drawn), but only append it if `Vector2(xf.origin.x - FISH_RING.x, xf.origin.z - FISH_RING.z).length() >= 1.1`.
  That removes the rocks at 91 and 108 degrees and the reed cluster at 78 degrees in front of the fishing ring; every
  other rock and reed stays where it is. Also make `_splash(at)` public as `splash(at)` (keep `_splash` calling it),
  and set the fireflies' `amount = Quality.particles(16)`.

### 1.4 Paths (`world.rebuild_paths`)

- Key: append `|%d|%d|%d` for `stone`, `garden`, `fishing`.
- Draw the village lane when `any_village or int(Save.stations.get("garden", 0)) > 0`.
- Garden built: one more line,
  `lines.append([_smooth(PackedVector3Array([Vector3(0.3,0,5.4), Vector3(0.45,0,6.3), Vector3(0.5,0,7.0)]), 5), CAMP_PATH_HALF * 0.85])`.
- No paths to the stone or the fishing spot: the meadow stays wild there.

### 1.5 Gifts and old saves

- `balance.json` missions, edited by id (line numbers move): `stumps.gift = "garden"`, `bandits.gift = "stone"`,
  `mossback.gift = "fishing"`. `fight._win` already calls `stations.gift(String(m["gift"]))` on a first win.
- `stations.gift()` banners (all with `hud.banner_later(3.4, ...)`):
  - `garden`: "A garden!", `Color(0.6, 1.0, 0.45)`, sub "The stumps left rich soil south of the camp · and a cooking pot
    by the fire". Then `main.hud.tip("Plant seeds, water them, pick them when ripe. They grow a step for every wave you
    hold.", rings["garden"])` and flag `told_garden`.
  - `stone`: "Something stirs at the old stone", `Color(0.65, 0.95, 0.5)`, sub "East of the camp: go and see". Then
    `tip("Wake the Moss Warden at its stone.", rings["stone"])`. The Warden spawns asleep (section 2.1).
  - `fishing`: "Gone fishing!", `Color(0.6, 0.85, 1.0)`, sub "Bramble left you a rod by the lake". Then
    `tip("Cast a line at the lake between waves. Tap when the float dips!", rings["fishing"])` and flag `told_fish`.
- **Catch-up for old saves**, `stations.catch_up_gifts()`, called once at the end of `main._ready` (after the HUD and
  `refresh_companions()` exist):
  ```gdscript
  func catch_up_gifts() -> void:
  	var got: Array = []
  	for i in Data.mission_count():
  		var m := Data.mission(i)
  		var g := String(m.get("gift", ""))
  		if g != "" and Save.missions_done.has(String(m["id"])) and int(Save.stations.get(g, 0)) == 0:
  			Save.stations[g] = 1
  			got.append(_name(g))
  	if got.is_empty():
  		return
  	Save.save_game()
  	refresh("all")
  	main.refresh_companions()
  	main.hud.tip("New in your camp: %s" % ", ".join(got), null)
  ```
  This also repairs any old save that missed the stall or the cottage.

### 1.6 Placeholders (`props.gd` `_placeholder_mesh`)

Faceted placeholder cases until the Blender GLBs land, so nothing ever shows as a magenta box: `guardian_stone` (grey
cylinder and a moss-green cap ball), `garden_bed` (brown box, 6 dark mounds), `cook_pot` (dark ball on 3 thin
cylinders), `fishing_spot` (stump cylinder and a basket box), `fishing_rod` (thin brown box, 1.1 m), `plant_sprout`,
`plot_weeds`, `soil_wet`, `<crop>_growing` and `<crop>_ripe` for the 3 crops (green balls; ripe ones add coloured fruit
balls), and the catch items `fish_minnow`, `fish_perch`, `fish_trout`, `fish_carp`, `driftwood`, `sunken_chest`.
`_placeholder` adds the empties `marker_plot_1..6` for `garden_bed`, `marker_tip` for `fishing_rod`, and a `rod` part
for `fishing_spot`. Any code that reads a marker falls back to a fixed offset when `find_part` returns null.

New `Props.merge(list)` for the garden's single plant mesh:
```gdscript
static func merge(list: Array) -> ArrayMesh:      # [[Mesh, Transform3D], ...] -> one mesh, one draw call
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	for it in list:
		var m: Mesh = it[0]
		for s in m.get_surface_count():
			st.append_from(m, s, it[1])
			any = true
	return st.commit() if any else ArrayMesh.new()
```

### 1.7 Looks and skins for three slots (`stations.gd` L913-956)

Add helpers `_look_id(slot)`, `_skin_id(slot)`, `_set_skin_id(slot, id)`, `_set_look_id(slot, id)` and
`_companion(slot)` (returns `main.mount`, `main.pet` or `main.guardian`), and rewrite `_skin_row`, `_next_skin` and
`_use_look` on top of them with a `match slot`. Skins with `"needs_flag"` are skipped (in the row's names and in
`_next_skin`) until `Save.flag(needs_flag)` is set. Behaviour for the mount and the pet stays exactly the same
(`--skins` checks it).

---------------------------------------------------------------------------------------------------------------------

## 2. The camp guardian: the Moss Warden

### 2.1 Unlock and waking it

1. The first win of mission 5, Bandit Night, gifts `stone` (1.5). `stations.gift("stone")` sets level 1, refreshes the
   stone (flower ring, boing) and calls `main.refresh_companions()`, which spawns the Warden at its rest spot in state
   `sleep`: a mossy heap of stones (the `Crumble` clip held on its last frame; the placeholder squashed to 0.3 height).
2. The stone card's first row reads "The Moss Warden is asleep" with a free, pulsing **Wake** button. Pressing it
   (`stations._wake_warden`):
   - checks `_locked()` and `not Save.flag("warden_awake")`, then `Save.set_flag("warden_awake")`;
   - `main.guardian.wake()`: the `Reform` clip, `main.shake(0.25)`, `Fx.dust` 16, `Fx.flower_ring` 1.6 m, `Sfx "rumble"`;
   - banner "The Moss Warden wakes!", sub "A big, slow friend: it goes for whatever attacks your camp";
   - `Save.save_game()` and `main.on_purchase()`.
3. If a mission starts while it still sleeps, it wakes by itself in `on_mission_start()` with the same banner, so the
   player never loses it.

Mission 5's raccoons are thieves that ignore structures, so the Warden would have little to show there. Its first
fight is mission 6, Mossback Wakes, where a mossy bear boss smashes buildings. This fits "woken around mission 5".

### 2.2 The Guardian Stone (station `stone`)

- An old standing stone with a glowing leaf rune, east of the camp at (8.0, 0.75); ring (8.0, 1.85); card anchor
  `_anchor("stone", 2.0)`. The Warden rests at stone + (-1.1, 0, 0) = (6.9, 0.75), facing +Z, and turns to face the
  cat when the cat is within 3 m.
- It **cannot be attacked**. It is not in `BUILDINGS`, so enemies on trail 2 never leave the road to siege a stone 8 m
  out, and the only way the guardian fails is "the Warden crumbles and comes back".
- Levels: 1 is the gift. Level 2 costs 500 leaves (needs home level 2). Level 3 costs 1,200 leaves + 15 timber (needs
  home level 3). The home-level cap comes from `_station_upgrade_row`. On top of the stone level, every number is
  multiplied by `power_by_camp_level[home level]`, so it also grows with the home.
- The stone prop's rune parts `rune_1`, `rune_2`, `rune_3` are shown up to the stone level (set in `refresh()`), and
  the Warden's model scale is `scale_by_level` (1.0 / 1.06 / 1.12): the player sees each upgrade.

### 2.3 What it does, by situation

`main.guardian` is a `Node3D` running `guardian.gd`. It is **never** in the groups `foes` or `enemies`: a wave ends only
when `foes` is empty, and arrows, bolts, towers, Sprig and Thistle all target those groups.

| Situation | What it does |
|---|---|
| Not woken yet | `sleep`: a heap at its rest spot. Does nothing. |
| No mission running | `rest`: walks home and plays `Sit` beside the stone. Faces the cat when it is within 3 m. |
| Mission starts (`on_stage_start`) | Wakes if asleep, full health, walks to its post (2.4). It has about 12 s before the first enemies arrive. |
| A wave is on | Thinks every 0.25 s, moves, punches and slams (2.5, 2.6). |
| Breather or chapter break | `refill()`: back up at once if it was down, full health. Stays at its post (`Idle`, facing out), so it never walks 8 m each way. |
| Last Stand | Stands beside the ashes on the cat's side and swats what comes near the cat or the ashes (2.9). |
| Mission ends (won, or the camp falls) | `on_mission_end()`: back up, full health, walks home and sits. |

### 2.4 Where it stands: its post

`Save.guardian_post` is -1 ("Guard the camp", the default) or 0 to 3 ("Hold the <trail name> trail"). A held trail is
used only if that lane is in the running mission's `lanes`; otherwise the Warden guards the camp for that mission and
the saved value stays. Lane ids in the mission JSON parse as floats, so compare with `int(ln) == p` in a loop, never
`Array.has`.

| Post | Idle spot (no target) | Leash (where its targets may be) |
|---|---|---|
| Guard the camp, one-lane mission | `patch_dir(lane) * camp_r * 0.7`: the inner mouth of that trail | `|foe| < camp_r + leash_extra_m` (5.0), from the campfire: 9 m at home level 1, 12.5 m at level 6. That reaches the innermost barricade slot on each road. |
| Guard the camp, several lanes | `normalize(sum of patch_dir(lanes)) * camp_r * 0.5`; if the sum is shorter than 0.3, `(0, 0, -camp_r * 0.5)` | same |
| Hold a trail | `world.edge_point(lane)`: the trail mouth on the firelight's edge | `foe within hold_leash_m (5.5) of the post`. The rest of the camp is left to the cat. |
| Last Stand | `cat_xz.normalized() * (stations.foot("campfire") + 0.9)` | foes within `last_stand_reach` (2.5 m) of the cat or of the ashes |

The idle spot is passed once through `world.constrain(spot, 0.6, false)` and nudged so it stays 1.6 m or more from every
visible ring centre (so it never stands on the sign ring at level 1). It is computed in `on_mission_start()` and
`on_wave_start()`, not per frame. At home levels 5-6 lane 3's mouth lies under the big home's canopy, as the enemies'
path already does.

The post is changed on the stone card ("Change" row, 9.1), between waves only. The decision it adds: in two-lane
missions, hold one trail with the Warden and take the other with the cat.

### 2.5 Choosing a target (`guardian._think`, every `think_s` = 0.25 s, only in a wave)

1. One `get_tree().get_nodes_in_group("foes")` per think and one pass over it.
2. Skip foes that are `dead` or `flyer` ("fliers get past it"), and foes outside the leash.
3. In the same pass, fill `_near` with the non-flier foes within 3 m (used every frame for the body push and here for
   the slam check).
4. Score each candidate (lower is better), starting from its flat distance to the Warden:
   - minus 6.0 if `e.wrecking()` (attacking a building, a barricade, a tower or the campfire);
   - minus 2.5 if `e.hitting_cat()` and it is within 4 m of the Warden (the bodyguard reflex);
   - minus 2.0 if it is inside the firelight + 1 m;
   - minus 1.5 if it is the current target (so it does not flip between two foes).
   In the Last Stand only foes within 2.5 m of the cat or the ashes count, and the score is plain distance.
5. Slam if `_slam_cd <= 0`, the Warden is idle or walking, and either 2 or more (`slam_min_foes`) non-flier foes are
   within `slam_range + e.radius`, or a boss is within that range.

Every physics frame, drop the target if `not is_instance_valid(target) or target.dead`: `fight._stragglers_flee` and
`_clear_foes` free enemies without `_die`.

New public helpers in `enemy.gd` (they test `is String` before any Object comparison):
```gdscript
## Hitting a building, a barricade, a tower or the campfire (what the Moss Warden goes for first).
func wrecking() -> bool:
	if not (state in ["attack", "burst", "spit"]):
		return false
	var t = _act_target
	if t is String:
		return t == "gate"
	return t is Object and is_instance_valid(t) and t != main.player and t != main.guardian


func hitting_cat() -> bool:
	return state == "attack" and _act_target is Object and _act_target == main.player
```

### 2.6 Attacks

Timing comes from the model's JSON events (enemy-style `_event(clip, ev, fallback)`, copied from enemy.gd L337-341),
not the mount's instant thump.

- **Punch** (`fist_every` 1.6 s): starts when the target is within `touch = radius + e.radius + fist_reach`
  (0.6 + r + 0.55) and `_punch_cd <= 0`. Clip `Punch`, impact at `events.Punch.hit` (fallback 0.45 s). At impact, if the
  target is still valid, not dead and within `touch + 0.4`: `target.hit(dir, Data.guardian_fist())`. That one call
  handles beetle shields, knockback, the rigged daze, damage numbers and death. Count `kills` when `target.dead` turns
  true. Then `Fx.dust(main, at, 5, 1.0)`, `main.shake(0.06)`, `Sfx.play("thud", -6.0)`. Otherwise it is a whiff (dust
  only). A Beetle Knight blocks most fists from the front, so the slam is what opens a beetle.
- **Ground slam** (`slam_every` 7.0 s, first one ready 3 s into a mission): clip `Slam`, and at its start
  `Fx.telegraph_ring(main, pos, slam_range, _act_event, Color(0.55, 0.9, 0.4, 0.35))`. At `events.Slam.impact`
  (fallback 0.95 s): fetch `foes` once, and for every non-flier within `slam_range + e.radius` call
  `e.hit(dir, Data.guardian_slam())`; small foes (`e.radius <= daze_radius`, 0.45) also get `e.stagger(slam_daze_s)`.
  Then `Fx.shockwave(main, pos, slam_range + 0.3, Color(0.6, 0.9, 0.45))` (one torus every 7 s at most),
  `Fx.dust(main, pos, 14, 1.8)`, `Fx.text(main, head, look.shout "Rumble!", ...)`, `main.shake(0.2)`, `Sfx "thud"`.
  Afterwards `_punch_cd = maxf(_punch_cd, 0.6)`; count `slams`.
- **Charge block**: a Bramble Boar or the Elder Thornstag that charges into the awake Warden stops there (2.7).

New `enemy.gd` helper (a whitelist of plain states, so a pouncer never floats and a digger never shows):
```gdscript
## The Moss Warden's slam: a short stun for small foes. Ends the way any daze ends (state "daze" until _act_t > 0.8).
func stagger(daze_s: float) -> void:
	if dead or boss or flyer or not (state in ["walk", "chase", "attack"]):
		return
	state = "daze"
	_act_t = 0.8 - daze_s
	_act_target = null
	if anim and anim.has_animation("Hit"):
		_play("Hit", 0.05)
```

### 2.7 Enemies fighting it (`enemy.gd`, all changes)

1. **Taunt**, in `_think()` right after `state = "walk"` (L664) and **before** the `last_stand` and `_siege` lines.
   Every kind still tries the cat first in its own branch above this line, so cat-first behaviour does not change:
   ```gdscript
   var g = main.guardian
   if g != null and gate_damage > 0 and not flyer and not main.fight.last_stand and g.taunts(self):
   	_fight_guardian(g)
   	return
   ```
   ```gdscript
   ## The camp guardian is in the way: hit it (structure-scale hits; _impact range-checks them).
   func _fight_guardian(g) -> void:
   	var c := Vector3(g.global_position.x, 0, g.global_position.z)
   	var me := Vector3(global_position.x, 0, global_position.z)
   	var away := me - c
   	var dist := away.length()
   	var touch: float = float(g.radius) + radius + float(info["reach"]) + 0.35
   	if dist < touch:
   		_goal = global_position
   		_face(-away / maxf(dist, 0.01), get_physics_process_delta_time(), 10.0)
   		if _cd <= 0.0:
   			_start_action("burst" if id == "puffball" else "attack", g)
   	else:
   		_goal = c + away / maxf(dist, 0.01) * (float(g.radius) + radius + 0.15)
   ```
   `guardian.taunts(e)` = `up() and main.fight.in_wave and flat distance < radius + e.radius + taunt_m (1.6)`.
   Kinds whose own branch returns early never reach this: pitchers spitting at structures, moles digging, raccoons
   (`gate_damage` 0) and fliers. The Warden walks over to a spitting pitcher (it is "wrecking") and punches it.
2. **`_impact` "attack"**, a new branch after `elif tgt == main.player:` and before the generic `has_method("hurt")`
   branch (so the guardian never gets the stump's siege x2 and the hit is range-checked when it lands):
   ```gdscript
   elif tgt is Object and tgt == main.guardian:
   	if main.guardian.reachable_from(global_position, float(info["reach"]) + radius):
   		main.guardian.hurt(int(maxi(gate_damage, 4) * (1.0 + buff if buff_t > 0.0 else 1.0)))
   ```
3. **`_impact` "slam"** (bear, stag), after the defences loop: `if main.guardian != null:
   main.guardian.blast(global_position, float(info["slam_range"]), gate_damage)`.
4. **`_burst()`** (puffball), after the defences loop: `if main.guardian != null: main.guardian.blast(me, r, gate_damage)`.
5. **`_do_charge()`**, before the fence check:
   ```gdscript
   var g = main.guardian
   if g != null and g.up() and global_position.distance_to(g.global_position) < radius + float(g.radius) + 0.2:
   	g.hurt(gate_damage)
   	g.blocked(global_position)          # Fx.shockwave, Fx.text "Blocked!", main.shake(0.25)
   	_end_charge()
   	return
   ```
   `_end_charge()` dazes the charger for 0.8 s, which is what a charge into a building does already, boss or not.
6. Helpers `wrecking()`, `hitting_cat()` (2.5) and `stagger()` (2.6).

Not changed: `_ranged_target` (pitchers never target the Warden), the per-kind branches, the boss specials.

### 2.8 Health, crumbling, pulling itself together

- **Max health** `Data.guardian_max_hp()` = `hp_by_level[stone] x power_by_camp_level[home] x (1 + meal guardian_hp)`.
  `guardian.refresh_stats()` recomputes `_max` and the model scale; it keeps the share of health in a mission and sets
  full health outside one. It is called from `main.refresh_companions()` (so every purchase and camp growth), and from
  `cooking.eat()` and `cooking.finish()`. Never per frame.
- **`hurt(amount: int)`** (one argument, the same contract as `enemy.Target.hurt` and `defences.PieceHandle.hurt`):
  ignored unless `up()`. Otherwise `main.fight.busy()` (so stragglers do not flee mid-fight), `hp -= amount`, add to
  `_dmg_acc`, flash (2.11), and play `Hit` only if one hit is 15% of max health or more and it is idle or walking. At
  `hp <= 0` it crumbles.
- **Damage numbers** are summed and shown at most every 0.4 s: `Fx.number(main, head, _dmg_acc,
  Color(0.85, 0.82, 0.65))`, stone beige, apart from the cat's red, the mount's orange and the buildings' coral.
- **`blast(at, r, amount)`**: `if up() and flat distance < r + radius: hurt(amount)`.
- **`reachable_from(p, reach)`**: `up() and flat distance < radius + reach + 0.6`.
- **Crumble** (`_crumble`): state `down`, `target = null`, clip `Crumble`, 4 `rock_1` instances at scale 0.5 as rubble
  around it (freed when it rises), `Fx.kill(main, at, Color(0.6, 0.65, 0.7))`, `Fx.dust` 16, `main.shake(0.3)`, toast
  "The Moss Warden crumbles!". The first time: tip "It pulls itself together in 30 s. Stand next to it to help."
  (flag `told_warden_down`). Taunted foes lose interest at once, because `up()` is false. Count `downs`.
- **Regrow**: `_down_t = Data.guardian_revive_s()` (30 s, or 15 with the Warden's Root Stew). It counts down only while
  `fight.active` and not `main.frozen`: in-game time, never wall-clock time. While the cat is alive within
  `help_range` (1.6 m) of the heap it counts at `help_rate` (x2), with `Fx.sparkle` from the cat every 0.4 s. At 0:
  `_rise(revive_hp)`: clip `Reform`, rubble freed, `Fx.flower_ring` 1.4 m, health 60%. It cannot be targeted while
  rising.
- **Breather or chapter break**: `refill()` (from `main.on_wave_cleared`, which `on_chapter_done` also calls) brings it
  up whole at once.
- **The mission ends**: `on_mission_end()` (from `main.on_stage_end`, which also runs after `camp_falls`, a path that
  skips `on_wave_cleared`) brings it up whole and sends it home. A down Warden never carries over.

### 2.9 Last Stand, the camp falling, raids later

- **Last Stand**: the Warden moves beside the ashes on the cat's side and only punches or slams foes within 2.5 m of the
  cat or the ashes. No enemy fights it (the taunt check skips the Last Stand), so "every enemy hunts the cat" stays
  true and the cat is still alone in the dark; the Warden only swats what comes for the cat while it rebuilds the
  fire. Only puffball bursts, boss slams and charges can hurt it then.
- **The camp falls**: it comes back up and goes home. Nothing is lost.
- **Raids (Phase D)** run through `fight.gd`, so every hook here applies unchanged. The raid's lanes give its post, so
  posting it on a "sneak" raid's trail is real preparation. A lost raid leaves it down only until the raid ends. Its
  being knocked down does not spoil a "perfect defence", which counts buildings.
- `Data.power()` adds `2 * Data.guardian_level()` once the Warden is awake, so the mission strength hint stays honest.

### 2.10 Numbers (`balance.guardian`, section 6.2)

| When | Home / stone | Health | Fist (per second) | Slam |
|---|---|---|---|---|
| Mission 6, first fight | 2 / 1 | 690 | 29 (18) | 46 |
| Mission 6-8, stone level 2 | 2 / 2 | 1,035 | 44 (27) | 69 |
| Missions 9-10 | 3 / 3 | 1,690 | 72 (45) | 117 |
| Mission 15 | 6 / 3 | 2,275 | 96 (60) | 158 |

Checks (enemy strength = (1 + 0.08 x mission index) x (1 + 0.05 x (wave - 1))):
- Mission 6, wave 10 (strength about 2.0): a thornling has about 36 health, so one punch kills it and a slam clears a
  pack. A brute has about 244: 6 punches, about 9 s. Five thornlings hit it for about 8 a second each, so they take 690
  health in about 17 s.
- The Mossback bear at wave 20 hits it for about 123 every 1.8 s and knocks it down in 10-15 s: 6-9 hits that did not
  land on buildings.
- Missions 9-10: a stump has about 548 health and hits the Warden for about 75 (no siege x2). One on one the Warden
  wins in about 12 s.

It roughly matches the cat's single-target damage at the same point in the game, is slower, adds area slams, and
cannot touch fliers or thieves. Tuning target: the Warden deals 25-35% of a wave's damage (`--guardianab` logs it).

### 2.11 `game/scripts/guardian.gd` (new, about 380 lines, `extends Node3D`)

Fields: `main, model, anim, meta, _body, _arms: Array, home, post, hp, _max, radius, state, target, _near: Array,
_think_t, _act_t, _act_len, _act_event, _act_done, _punch_cd, _slam_cd, _down_t, _help_fx_t, _flash_t, _dmg_acc,
_dmg_t, _rubble: Array`, and the test counters `kills, slams, downs, dealt`.

Public API:

| Function | What it does |
|---|---|
| `setup(m, at)` | `home = at; post = at; radius = balance.guardian.radius`, `_load_model()`, `refresh_stats()`, `Fx.blob(self, 0.75)` (shown only on Low), state `sleep` or `rest` by `Save.flag("warden_awake")` |
| `_load_model()` | `res://assets/companions/<Save.guardian_look>/<id>.glb` and `.json`; `Props.apply_vc`; `Props.set_skin(model, Data.look("guardian", id), Data.skin("guardian", id, Save.guardian_skin))`; loop `Idle`, `Walk`, `Sit`; spring bones **only if `Quality.springs()`** (copy `enemy._springs`, L164-184). No GLB: the placeholder (2.13). |
| `set_look()` | frees the model and reloads, as `mount.gd` does |
| `refresh_stats()` | `_max`, scale by stone level, health (2.8) |
| `up() -> bool` | `main.fight.active and state in ["idle", "walk", "punch", "slam", "hit"]` |
| `taunts(e)`, `reachable_from(p, reach)`, `hurt(amount: int)`, `blast(at, r, amount)`, `blocked(at)` | sections 2.7 and 2.8 |
| `push_out(p: Vector3, r: float) -> Vector3` | moves `p` out of the Warden's circle (radius x 0.8 while down); used by `player.gd` |
| `wake()` | `Reform` at home, then `rest` |
| `refill()` | back up whole now (breathers and chapter breaks) |
| `on_mission_start()`, `on_wave_start()`, `on_mission_end()` | sections 2.3 and 2.4 |
| `post_lane() -> int`, `post_name() -> String` | the post in use and its card text |

Private: `_think()`, `_score(e)`, `_in_leash(e)`, `_post_spot()`, `_start(kind)`, `_act(delta)`, `_impact()`,
`_slam_hits()`, `_crumble()`, `_rise(share)`, `_regrow(delta)`, `_move(goal, delta)`, `_push_near()`,
`_flush_numbers(delta)`, `_flash(on)`, `_play(clip, blend)`, `_event(clip, ev, fallback)`.

`_physics_process(delta)` in order:
1. Return if `main.frozen` or state is `sleep`.
2. Count down `_punch_cd`, `_slam_cd`, `_flash_t`; `_flush_numbers(delta)`.
3. `down`: `_regrow(delta)`, return. `rise`, `punch`, `slam`, `hit`: `_act(delta)` (impact at the event, back to `idle`
   at the clip's end), `_push_near()`, return.
4. Not `fight.active`: walk home, then `rest` and `Sit`; face the cat if it is within 3 m. Return.
5. In a wave: `_think` every `think_s`; drop an invalid or dead target; goal = the target's edge
   (`e.pos - dir x touch x 0.9`) or the post; `_move(goal, delta)` at `speed` (x `hurry` 1.3 when the target is
   wrecking); punch when in touch and ready; `_push_near()`.
6. Breather or chapter break: goal = post; `Idle`, facing out.

`_move`: `position += dir * spd * delta`, then `position = main.world.constrain(position, radius, false)` (buildings and
the lake block it, barricades do not, and it slides round circles), turn rate 5, `Walk` with
`anim.speed_scale = spd / meta.ground_speed_m_per_s.Walk`, else `Idle`.

`_push_near`: for each foe in `_near` that is valid, not dead, not a flier and not in `charge`, `dash`, `pounce`, `dig`
or `blink`, push it out of `radius + e.radius` (only the foe moves). O(k), k is about 10. It is **not** added to the
O(n squared) pair loop in `main._physics_process` and never adds a moving circle to `world.circles`.

`_flash(on)`: `Props.set_param(model, "flash", 1.0)` once on a hit, and back to 0.0 once after 0.12 s. Never per frame.

### 2.12 Hooks in other scripts

**`main.gd`**
- `const GuardianScript := preload("res://scripts/guardian.gd")`, `var guardian: Node3D`.
- `refresh_companions()`: `if guardian == null and Data.guardian_level() > 0:` create it, `add_child`,
  `guardian.setup(self, world.station_pos("stone") + Vector3(-1.1, 0, 0))`. Idempotent, because
  `refresh_companions` runs on every purchase. At the end: `if guardian: guardian.refresh_stats()`.
- `on_stage_start()`: `if guardian: guardian.on_mission_start()`.
- `on_wave_start()`: `if guardian: guardian.on_wave_start()`.
- `on_wave_cleared()`: `if guardian: guardian.refill()`, next to `mount.refill()`.
- `on_stage_end()`: `if guardian: guardian.on_mission_end()`.
- `_update_grass()`: after the cat's entries, `if guardian and guardian.visible: list.append(Vector4(g.x, 1.0, g.z,
  0.9))` (one pusher inside the 24-slot cap).

**`player.gd`**: right after `position = main.world.constrain(position, 0.3, false)`:
`if main.guardian != null: position = main.guardian.push_out(position, 0.3)`. The cat never walks through a 2 m golem,
and the golem never pushes the cat around.

**`lifebar.gd`**
- `_bars["warden"] = [1.0, 1.0, 0.0]`. In `_process`, step it with `g.hp / g._max` when `main.guardian` exists. Replace
  `visible = p.hp > 0` with `visible = true`, and skip only the cat's bars in `_draw` while the cat is down.
- In `_draw`, while `main.fight.active` and (`g.hp < g._max` or a hit in the last 2 s) and the Warden is on screen: a
  moss-green bar `Color(0.55, 0.8, 0.35, 0.85)`, 120 x 7 px, at `g.global_position + (0, height_m + 0.25, 0)`, with
  the same grey trail and drain as the cat's.
- While it is down: a 26 px arc over the heap that fills as `_down_t` runs out, the seconds left in 20 px, and "x2"
  while the cat helps.

**`stations.gd`**: the stone ring and `_card_stone()` (9.1), `_wake_warden()`, `_next_post()`, the `stone` upgrade
"gives" line (`"Moss Warden: %d health, fists %d, slam %d"` for the next level at today's home level), the gift banner.

**`autotest.gd`**: `_perf_diag_camp` adds `main.guardian` to both companion lists (L1008, L1022).

### 2.13 Looks, placeholder and model

**Looks only.** `balance.looks.guardian` has one look now, `moss_warden`, with 6 colour skins that recolour the moss
hue family through the shared `skin` shader (Natural, Autumn, Frost, Golden, Midnight, and Lakeweed, which needs the
flag `lake_charm` from a lake treasure, so it is earned in play). Later looks (a crystal golem, a bark giant) are new
entries plus one Meshy model each. They must have **the same clips and events**, and every number comes from
`balance.guardian`. The look rows ("Same strength, a new look") appear on the stone card only once there is more than
one look.

**Placeholder** until the Meshy model exists, built in `guardian.gd` with `Props.build`: a grey-blue body box
0.9 x 1.0 x 0.7, a head ball 0.28, a flattened green moss cape box, two long arm boxes with ball fists 0.22 as
separate MeshInstances (`_arms`), stump-cylinder legs, a small green cone sapling, two amber eye balls. Punch and slam
become arm tweens plus `Fx.boing`; crumble squashes it to 0.3 height over 0.5 s; reform tweens back.

**Concept image prompt.** File `concepts/companions/prompts/03_moss_warden.txt`. Generate one image with
`tools/gen_concepts.ps1 -Folder "D:\Projects\Project LEAF\concepts\companions" -Refs
"D:\3D Modeling Test\CatRanger\reference\concept_sheet.png" -Only 03_moss_warden`, which writes
`concepts/companions/03_moss_warden.png`. Do this first in C1: the user's Meshy model is the long pole.

```
SUBJECT: The Moss Warden, a big gentle guardian that protects a small cat hero's forest camp: a friendly golem about one and three-quarter times the height of a small cat and much broader, built from rounded grey-blue river stones held together by thick bright-green moss and old twisting brown tree roots. A broad barrel-shaped boulder chest with a carved leaf-shaped rune in its middle that glows warm golden yellow. A small round boulder head sunk between huge rounded mossy shoulders, two calm round eyes glowing the same warm golden yellow under a heavy mossy brow, a kind, sleepy, gentle face with no mouth. A small sapling with two bright leaves grows from the top of its head. Thick moss caps the head and shoulders and hangs down the back in short tufts, dotted with a few tiny white and yellow flowers. Very long heavy arms of stacked stones, with brown roots wrapped round the forearms like bracers and a few short vines hanging from them, ending in huge rounded blocky stone fists held half open, the knuckles reaching almost to the knees. Short sturdy stump-like legs with roots spreading over the feet. Warm grey stone in lighter and darker flat patches, bright moss green, brown roots. Strong but never scary, like a big friendly dog. No violet, no crystals, no bark armour, no weapons.

STYLE: Stylized LOW-POLY 3D game model render in the same art style as the attached reference image: few, large faceted flat-shaded polygons with visible facets, simple chunky cute shapes, no fine detail, clean matte saturated colours with simple painted patches, soft even studio lighting. A bright, friendly fantasy mobile-game look.

CAMERA AND POSE: front view turned about 20 degrees to the side, camera at chest height. Standing straight in a calm neutral pose, legs a little apart, both long arms held out and down about 30 degrees away from the body with the fists half open and clear of the legs.

FOR A 3D MODEL GENERATOR: Exactly one subject, alone. The whole body visible from top to bottom with empty margin on every side, centred, nothing cropped. No ground, no base, no props lying around. Plain flat light-grey background with no gradient, no floor and no cast shadow. No particles, smoke, sparkles or floating effects. Limbs held a little away from the body so they read clearly.
ONE SINGLE IMAGE: not a character sheet, no multiple views, no turnaround, no close-up insets, no colour swatches, no text, no labels, no watermark, no border.
REFERENCE: use the attached image only as an art-style reference (the low-poly faceted 3D look, shading and colour saturation). Do not draw the cat and do not copy its sheet layout.
```

Design notes: grey **stone**, not bark, and **golden** eyes and rune, not violet, so it never reads as the Stump Golem
or the Gloom. The moss is the only big green area, so a colour skin (`fur` hue 0.25, width 0.07) recolours just the
moss.

**Size and budget.** 2.1 m tall (the cat is 1.235 m), `radius_m` 0.6, `aim_height_m` 1.0. **6,000 triangles at most**
(the mount class; the Stump Golem has 5,000). One skinned mesh `SK_moss_warden`, the shared `M_VertexColor` material,
colour per face, front facing Blender -Y, origin on the ground, transforms applied. Add the row
"Moss Warden (guardian) | 6,000" to the `docs/ASSET_RULES.md` table.

**Rig.** Armature `RIG_moss_warden`, root bone `root`; deform bones hips, spine, chest, neck, head, and per side
shoulder, upper_arm, forearm, hand, thigh, shin, foot. Spring chains (simulated only when `Quality.springs()` is on):
`jig.sprout.1-2` (the sapling), `jig.moss_l.1-3` and `jig.moss_r.1-3` (the moss tufts on the shoulders and back),
`jig.vine_l.1-2` and `jig.vine_r.1-2` (the vines hanging from the forearms).

**Clips** (30 fps, in place, rotation and location keys only):

| Clip | Seconds | Loop | Event | Notes |
|---|---|---|---|---|
| `Idle` | 3.0 | yes | | slow breathing, looks around, the sapling sways |
| `Walk` | 1.3 | yes | | heavy plodding steps; `ground_speed_m_per_s.Walk` = 1.15 |
| `Punch` | 1.1 | no | `hit` 0.45 | shoulder wind-up, then a big overhand fist in front |
| `Slam` | 1.6 | no | `impact` 0.95 | both fists overhead (0.6 s of build-up), then they pound the ground |
| `Hit` | 0.45 | no | | a small stagger |
| `Crumble` | 1.6 | no | `down` 1.2 | knees buckle, folds forward into a low heap of stones, head tucked, moss on top; ends still. Its last frame is also the sleeping heap |
| `Reform` | 2.0 | no | `up` 1.7 | the heap rumbles, rises, stretches, a little happy shake. Also used for waking |
| `Sit` | 4.0 | yes | | sits leaning on its stone, slow breathing |

**Files.** Meshy source (downloaded by the user): `art/source/meshy/moss_warden.glb`. Working file:
`art/blender/companions/moss_warden.blend`. Scripts: `art/scripts/companions/moss_warden/`. Previews:
`art/previews/companions/moss_warden/`. Output: `game/assets/companions/moss_warden/moss_warden.glb` and
`moss_warden.json` in the ASSET_RULES character format (`id`, `fps` 30, `height_m` 2.1, `radius_m` 0.6,
`aim_height_m` 1.0, `clips`, `ground_speed_m_per_s`, `events`, `spring_chains`, `tris`). Run `blender-asset-qa`
before export, and check the GLB's JSON chunk after.

---------------------------------------------------------------------------------------------------------------------

## 3. The garden

### 3.1 Where and what

- Bed `garden_bed` at (0.5, 8.4), south behind the village lane, rotated PI so its work side faces the camp. It is
  12.6 m or more from every trail end, so it is the safest ground there is, and it is not an enemy target.
- Ring at (0.5, 7.2) on the bed's camp side. The cat stands there facing +Z, toward the camera, so its face shows while
  it gardens. Card anchor `_anchor("garden", 1.2)`.
- 6 plots in 2 rows of 3 (markers `marker_plot_1..6`, 1-3 the row nearest the ring). Open plots by garden level:
  3 / 5 / 6. Locked plots show `plot_weeds`.

### 3.2 Growth: one step per wave held, never real time

When a wave is held (`main.on_wave_held()`, called from `fight._wave_cleared` right after `in_wave = false`, so it
covers breathers, chapter ends and the last wave), every planted plot that is not ripe gains `grow_wet` (2) if its
`wet` counter is above 0, else `grow_dry` (1); a wet plot's `wet` then drops by 1. Ripe is `grow >= crop.grow`. Ripe
plants never rot.

Why per wave held:
1. It cannot be idled: leaving the phone on in the camp grows nothing, so it is no production timer.
2. No clock and no timestamps: nothing can progress while the game is closed, and the save stays simple (ints).
3. It fits the chapter loop: plant at a chapter break, pick at the next one, cook for the chapter after.
4. No per-frame code: the plant mesh changes at most once per wave or card action.
5. Replays grow it too, so grinding a mission also fills the pantry. Raids (Phase D) count their waves the same way.

Watering is free and covers every planted, unripe plot in one tap; it sets `wet` to `wet_waves_by_level` (3 / 4 / 5).
It is a bonus, never a punishment: dry plants still grow.

### 3.3 Crops (`balance.garden.crops`)

| Crop | Gives | Yield | Growth points | Waves to ripe (watered / dry) | Seed |
|---|---|---|---|---|---|
| Sunberries (`sunberry`) | `berries` | 3 | 4 | 2 / 4 | 10 leaves |
| Fernmint (`fernmint`) | `herbs` | 2 | 5 | 3 / 5 | 12 leaves |
| Honeybells (`honeybell`) | `honey` | 2 | 6 | 3 / 6 | 15 leaves |

Seeds are "Bramble's seed packets": the leaf cost is paid by the Plant row itself, so there is no seed inventory and no
trip to the stall. Garden level 3 adds +1 to every harvest.

### 3.4 Actions (`stations.gd`; each starts with `if _locked(): return`, then saves and calls `main.on_purchase()`)

- `_garden_plant(crop_id)`: the first empty open plot; `Data.pay(seed)`; `Save.garden[i] = {"crop": id, "grow": 0,
  "wet": 0}`. `Fx.dust` (brown), the sprout pops in with `Fx.boing`, `Sfx "pop"`. One plot per tap, so crops can be
  mixed.
- `_garden_water()`: every planted, unripe plot gets `wet = wet_waves`. `Fx.puff(main, bed + (0, 0.6, 0),
  Color(0.55, 0.8, 1.0), 12)`, `Sfx "water"`.
- `_garden_pick()`: every ripe plot whose yield fits under `pantry_cap` (20 of each) goes to `Save.pantry[gives]` and is
  emptied; plots that do not fit stay ripe (nothing is lost). `Fx.text` "+3 Sunberries" per crop, `Fx.flower_ring(bed,
  1.0)`, `Sfx "pluck"`. The first time: `tip("Cook what you pick at the pot by the campfire. A dish is eaten when the
  next chapter starts.", rings["pot"])` (flag `told_cook`).

### 3.5 `game/scripts/garden.gd` (new, about 200 lines, `extends Node3D`, no `_process`)

`setup(m)`, `plots() -> int`, `plot(i) -> Dictionary`, `is_ripe(i) -> bool`, `counts() -> Dictionary` (`ripe`,
`empty`, `growing`, `dry`), `summary() -> String`, `pick_preview() -> Dictionary`, `plant(crop) -> bool`,
`water() -> int`, `pick() -> Dictionary`, `grow_wave() -> int` (returns how many plots turned ripe; toast
"Sunberries are ripe!" once per crop), `attach(bed: Node3D)`, `refresh_look()`.

**Visuals.** One `MeshInstance3D` `_plants`, a child of the bed, whose mesh is `Props.merge(list)` of
`[Props.mesh(name), marker transform]` per plot: `plot_weeds` on locked plots; `plant_sprout` while `grow * 2 <
crop.grow`; `<crop>_growing` while unripe; `<crop>_ripe` when ripe; plus `soil_wet` (a dark soil slab) under every
watered plot. `material_override = Props.vc()`. Marker transforms are taken as `bed.global_transform.affine_inverse() *
marker.global_transform`; the fallback is a 3 x 2 grid with 0.6 m steps. It is rebuilt only when a plot changes (card
action, wave held, new bed model). Ripe glint: one `CPUParticles3D` on the bed with `amount = Quality.particles(6)`,
emitting only while a plot is ripe. Cost: two draw calls (bed and plants) plus the glint, all culled when off screen.

---------------------------------------------------------------------------------------------------------------------

## 4. Cooking at the campfire

### 4.1 The pot

- `cook_pot`, a squat iron pot on 3 hearth stones on the campfire's north-east rim: `station_pos("pot")` =
  NE x (fire foot + 0.18), so (0.55, -0.55) at home level 1 and (0.80, -0.80) at level 5. Collision 0.25.
- Ring at (1.0, -1.0) at every level; like the well's, its disc overlaps the prop's base. Card anchor
  `station_pos("pot") + (0, 1.4, 0)`.
- It comes with the garden (mission 4). The ring hides while the fire is out (`_out`: the Last Stand) or ruined (the
  camp fell), so a blocked card never pops up on the ashes.

### 4.2 The meal rule

- **One dish in the pot, one being eaten, never stacked.** `Save.meal_ready` is the dish waiting in the pot,
  `Save.meal_on` the dish eaten this chapter (both a recipe id or `""`).
- **Cook** takes the ingredients and puts the dish in the pot. If a dish already waits, the new one replaces it (the
  card warns: "swaps out the Berry Tart in the pot"; the old ingredients are not refunded).
- **Eat**: when a chapter's first wave starts (`main.on_wave_start(n)` with `(n - 1) % fight.chapter_waves() == 0`:
  wave 1 of a mission, a resumed chapter, or "Go" after a chapter break), `cooking.eat()` moves `meal_ready` into
  `meal_on` and applies its boost. Banner "The cat eats the %s", sub "%s this chapter", `Fx.sparkle` on the cat. So a
  dish is always for **the next chapter** (Draft 7): cooked between missions it is eaten at chapter 1; cooked at a
  chapter break, at the next chapter; cooked in a breather, at the next chapter.
- **End**: `cooking.finish(held)`. `held` true when the chapter is held (`fight._chapter_done`, before
  `gate_hp = gate_max`) or the mission is won (`fight._end(true)`): the dish is used up. `held` false when the camp
  falls (`fight._end(false)`): the dish goes back into the pot (if the pot is empty) so the retried chapter gets it
  again for free.
- **Closing the game mid-chapter**: the run restarts at the chapter's start, so `Save.load_game()` turns an eaten dish
  back into a waiting one (`if meal_on != "": if meal_ready == "": meal_ready = meal_on; meal_on = ""`). Nothing is
  lost and nothing ticks offline.
- **Applying the boost** (`eat`): `Data.set_meal(id)` caches the boost dict; `player.hp = mini(player.hp + hp,
  Data.cat_max_hp())`; a `fire` boost does `gain = fight.gate_max * fire; gate_max += gain; gate_hp += gain`;
  `guardian.refresh_stats()`; `hud.refresh()`.
- **Removing it** (`finish`): `Data.set_meal("")`; `gate_max = Data.fire_hp()` and `gate_hp = minf(gate_hp, gate_max)`;
  the cat's hp clamped to `Data.cat_max_hp()`; `guardian.refresh_stats()`; `hud.refresh()`.
- **Boss tip** (`fight._chapter_done`, after the banner): if the next chapter is the mission's last, the mission has a
  boss, `Save.meal_ready == ""` and the pot exists: `tip("The boss comes in the last chapter: cook a dish at the pot
  first!", rings["pot"])`.
- **HUD chip**: one 20 px label `_meal_l` in `hud._res` under the timber row, set in `hud.refresh()` from
  `cooking.chip_text()`: "Eating: Berry Tart · shoots 15% faster" while one is active, "In the pot: Berry Tart (next
  chapter)" while one waits, hidden otherwise.

### 4.3 Recipes (`balance.cooking.recipes`), picked for the coming threat

| Recipe | Needs | Boost for one chapter | Good against | Shown when |
|---|---|---|---|---|
| Berry Tart | 3 Sunberries | shoots 15% faster (`draw` 0.15) | moth swarms, many small foes | garden |
| Fernmint Tea | 2 Fernmint | +2 cat health (`hp` 2) | the Last Stand, raccoon raids | garden |
| Honey Cake | 2 honey, 1 Sunberry | Sprig, Thistle and the Warden hit 40% harder (`friends` 0.4) | stumps and brutes near the camp | garden |
| Hearth Stew | 2 Fernmint, 1 honey, 2 Sunberries | campfire +40% health (`fire` 0.4) | puffball bombers, stump golems | garden |
| Fish Skewers | 2 fish, 1 Fernmint | arrows hit 20% harder (`damage` 0.2) | elites, shield walls | fishing |
| Warden's Root Stew | 2 fish, 2 Fernmint, 1 honey | the Warden +50% health and back up in 15 s (`guardian_hp` 0.5, `guardian_revive_s` 15) | sieges | fishing and the stone |
| Golden Carp Feast | 1 Golden Carp, 2 Sunberries, 1 honey | +2 health, arrows +15%, shots +10%, friends +20%, the Warden +20% health | bosses | a Golden Carp was ever caught |

Scale check: one Damage level is +12% and one Draw level +7%, so the Tart is worth about 2 Draw levels for one chapter,
for 10 leaves of seed and a garden visit. +2 health is 2 Health levels on a 5-health cat. These are temporary, one at a
time, and between waves only. Tune by play.

**Where the boosts apply** (all through the cached `Data.meal_boost(k)`, because the stat getters run every frame):
- `Data.cat_max_hp()` + `int(meal_boost("hp"))`; `Data.cat_draw()` x (1 + `meal_boost("draw")`);
  `Data.arrow_damage()` x (1 + `meal_boost("damage")`).
- `pet.gd` `_spit` (L223): damage x (1 + `meal_boost("friends")`). `mount.gd` `_thump` (L265): `dmg` x
  (1 + `meal_boost("friends")`).
- `Data.guardian_fist()` and `guardian_slam()` x (1 + `friends`); `guardian_max_hp()` x (1 + `guardian_hp`);
  `guardian_revive_s()` uses `guardian_revive_s` when set.
- The campfire through `cooking.eat()` and `finish()`.

### 4.4 Cook action (`stations._cook_dish(id)` calls `cooking.cook(id)`)

1. `if _locked() or _out or Save.fire_ruined or not Data.has_items(r.needs): return`.
2. `Data.take_items(r.needs)`; `Save.meal_ready = id`.
3. Ingredients fly from the cat into the pot (3 small tweens of `Props.mesh` items, 0.3 s), `Fx.boing` on the pot,
   `Fx.puff` steam in the dish colour at `marker_steam` (8 particles), `Sfx "sizzle"`.
4. Banner "%s is ready", sub "Eaten when the next chapter starts: %s".
5. `Save.save_game()`, `main.on_purchase()`.

### 4.5 `game/scripts/cooking.gd` (new, about 170 lines, `extends Node`, no `_process`)

`setup(m)`, `known() -> Array` (recipes whose unlock is met), `can_cook(r) -> bool`, `why_not(r) -> String`
("Needs 1 more Sunberry", "The fire is out"), `cook(id)`, `eat()`, `finish(held: bool)`, `eating() -> bool`,
`chip_text() -> String`, `needs_text(r) -> String` ("3 Sunberries (have 5)").

---------------------------------------------------------------------------------------------------------------------

## 5. Fishing at the lake

### 5.1 The spot

- Prop `fishing_spot` at (-7.2, 5.3) on the lake's south shore: a mossy stump seat, a bait tin, a wicker fish basket,
  and a rod rack whose `rod` part is hidden while the cat has the rod. Collision 0.45.
- Ring at (-6.48, 5.28), 0.8 m from the water, 4.38 m from the cottage ring. Card anchor `_anchor("fishing", 1.6)`.
  The cat stands there facing north (`facing = PI`) over the water, back to the camera, so the line goes up the screen.
- The float lands 1.8-2.6 m from the ring toward `LAKE_C`, within +-0.25 rad, and only where `lake_dist < -0.5`
  (about (-6.4, 3.3)): 1.0-2.3 m inside the water.
- The cat never walks on water, so there is no `push_out` exception and the old dock is not used.

### 5.2 When

Whenever the stations work: between missions, in breathers and at chapter breaks (`hud._spec` blanks the card in a
wave). A wave starting, the cat leaving the ring, the cat going down, `main.frozen`, a mission starting or ending all
pull the line in (`fishing.stop("")`; "It got away" only if a fish was hooked). A 15 s breather is about one cast; the
chapter breaks and the time between missions are the fishing time. Not while riding (the card says "Get off %s to
fish").

### 5.3 The game: two taps, calm

1. **Cast**: the card's "Cast" button. `hud.hide_card()` (the cat stays on the ring, so `_update_rings` does not show it
   again), `player.set_fishing(true)` (the bow hidden, the rod in the paw), the rack's `rod` hidden, the cat turned to
   `facing = PI`. The float arcs in `cast_s` (0.55 s) from the rod's `marker_tip` to the landing point, with
   `lake.splash(at)` and `Sfx "plop"`.
2. **Wait** `wait_s` 3-6 s (x 0.75 with the Lucky Lure), with 0-2 **nibbles**: the float twitches 0.15 s with a tiny
   ripple. A tap now is gentle: `Fx.text` "Shh..." and 1 s more wait. Nothing is lost.
3. **Bite**: the catch is rolled now (5.4). The float plunges with a splash and a **"!"** bubble over it: white for
   common, blue for uncommon, **gold for rare**. "Tap!" in 34 px at the bottom of the screen. Tap anywhere within
   `bite_s` (1.0 / 0.85 / 0.7 s by rarity) to hook it. Missed: toast "It got away", the card comes back.
4. **Reel** (only uncommon: 1 pulse, rare: 2 pulses): a ring closes on the float from 110 px to 36 px over `pulse_s`
   (1.1 s); it turns green for the last `pulse_zone` (30%) plus `pulse_grace_s` (0.15 s). A tap while it is green is a
   good pull: the fish tugs sideways with a splash, then the next pulse. An early tap or no tap is a slip: "Easy
   now...", the pulse starts again. `misses_allowed` slips are forgiven (1, or 2 with the Silk Line); one more and "It
   got away!" with a cheeky jump splash.
5. **Land**: the catch mesh arcs from the water to the cat in 0.6 s (like `lake._fish_arc`), `Fx.boing` on the cat
   model, `Fx.sparkle`, `Sfx "pluck"`, toast "+1 Sun Perch (5 fish)". The first catch of a kind: banner "New catch:
   Silver Trout!", sub "4 of 6 in your fish log". Then `player.set_fishing(false)`, the rack's rod shown again, and
   `main.reopen_ring()`, so the card comes back with "Cast": two taps per fish, about 8 s each.

**Input.** `fishing._input(event)`: a pressed `InputEventScreenTouch` (the project emulates touch from the mouse) while a
line is out and `not main.joystick._blocked(event.position)` calls `tap()`. A tap never moves the cat: the floating
joystick starts at the finger and its vector stays inside the dead zone. **Stop** by dragging: if
`main.joystick.vector.length() > 0.5` for 0.15 s, the line comes in and the cat walks.

**The rod in the paw** (`player.gd`): `set_fishing(on)` hides or shows `SK_CatBow` and frees or creates a member
`_rod_hold := BoneAttachment3D` on the bone named in `CatRanger_clips.json` `bones.bow_hand` (`weapon.L`), holding
`Props.instance("fishing_rod")` with an offset `ROD_XF` tuned in the `--fishing` close-up so the rod points forward and
up in the carried pose. If that bone does not exist (another hero model), the rod stays on the rack and the line starts
from the rack's `marker_tip`. If the carried pose reads badly, a short `Cast` clip for the hero is the fix (open
question 3).

### 5.4 Catches (`balance.fishing`; weights add up to 100)

| Catch | Rarity | Weight | Gives |
|---|---|---|---|
| Minnow | common | 44 | 1 fish |
| Sun Perch | common | 28 | 1 fish |
| Silver Trout | uncommon (1 pulse) | 15 | 2 fish |
| Driftwood | common | 7 | 1 timber |
| Golden Carp | rare (2 pulses) | 4 | 1 Golden Carp (the Feast) |
| Sunken Chest | rare (2 pulses) | 2 | 40 leaves + 3 timber |

- **Lake treasures**, found once each, in order: when a rare is rolled and a treasure is still unfound, half the time
  (`treasure_share` 0.5) it is the next treasure instead. Lucky Lure (bites 25% sooner), Silk Line (one more slip
  forgiven), Lake-moss Charm (the Warden's Lakeweed colours). Stored as the flags `lake_lure`, `lake_line`,
  `lake_charm`. Banner "A lake treasure!" with what it does. Permanent, small, earned only by playing.
- **Pity**: `Save.fish_dry` counts catches since the last rare; at `rare_pity` (20) the roll uses only the rare entries.
- **Pantry cap** 20 of each: a fish over the cap is let go ("The pantry is full: you let it go").
- **Fish log**: `Save.fish_log` counts each catch id; 6 kinds.
- Economy: about 0.8 leaves and 0.13 timber per catch, so fishing is no leaf farm but a small play-only relief for
  timber.

### 5.5 `game/scripts/fishing.gd` (new, about 300 lines, `extends Node3D`) and `fishing_ui.gd` (about 120 lines)

`fishing.gd`, created in `main._ready` before `stations.build`, `set_process(false)` until a cast:
- `var main, rng: RandomNumberGenerator, phase ("" | "cast" | "wait" | "bite" | "reel" | "land"), catch: Dictionary,
  _t, _wait, _nibbles: Array, _pulses, _misses, _ring: Node3D, _at: Vector3, _bobber: MeshInstance3D, _line:
  MeshInstance3D, _ui: Control, _drag_t`, and test overrides `debug_wait := -1.0`, `debug_catch := ""`.
- `setup(m)`: `rng.randomize()`; makes the float (`Props.build` red and white ball, 0.06 m, about 60 tris) and the line
  (an `ImmediateMesh` LINE_STRIP of 6 sagging points, unshaded white), both hidden.
- `build_ui(hud)`: adds `_ui` (fishing_ui.gd) to the HUD.
- `busy() -> bool`, `can_fish() -> bool`, `cast(ring)`, `tap()`, `stop(msg := "")`, `in_zone() -> bool`, `_roll() ->
  Dictionary`, `_land()`, `_update_line()`.
- `_process(delta)`, only while a line is out: the stop checks, the float's bob (a sine), the line rebuilt, the phase
  timers, `_ui.queue_redraw()`.

`fishing_ui.gd` (`extends Control`, full rect, `mouse_filter = MOUSE_FILTER_IGNORE`, never in `ui_block`): `_draw`
only while `fishing.busy()`: the "!" bubble over the projected float in the rarity colour, the closing ring and its
green zone during "reel", "Tap!" or "Wait for the bite..." at the bottom. No buttons, no panel.

---------------------------------------------------------------------------------------------------------------------

## 6. `balance.json` additions (exact)

### 6.1 Stations and mission gifts

Merge into the existing `"stations"` object:
```json
"stone":   {"name": "Guardian Stone", "build": {"leaves": 0}, "levels": [{}, {"leaves": 500}, {"leaves": 1200, "timber": 15}]},
"garden":  {"name": "Garden", "build": {"leaves": 0}, "levels": [{}, {"leaves": 400}, {"leaves": 1000}]},
"fishing": {"name": "Fishing Spot", "build": {"leaves": 0}, "levels": [{}]}
```
The pot has no entry: it has no level and follows the garden. Missions (by id): `stumps.gift = "garden"`,
`bandits.gift = "stone"`, `mossback.gift = "fishing"`. No `building_hp` entries: none of these can be wrecked.

### 6.2 `"guardian"` (new top-level table)

```json
"guardian": {
  "_note": "the Moss Warden, woken at the Guardian Stone (mission 5's gift). Numbers = the stone level's entry x power_by_camp_level[home level] (fists and slam also x a dish's 'friends', health x 'guardian_hp'); every guardian look uses exactly these. In a wave it goes for enemies within its leash, first those hitting a building, a barricade, a tower or the campfire. Enemies within taunt_m of it fight it with structure-scale hits (gate_damage, no siege multiplier, range-checked). Slam when slam_min_foes are within slam_range (or a boss); foes with radius <= daze_radius are dazed slam_daze_s. Knocked down it pulls itself together after revive_s of mission time (x help_rate while the cat stands within help_range) at revive_hp, or whole at the next breather.",
  "hp_by_level": [0, 600, 900, 1300],
  "fist_damage_by_level": [0, 25, 38, 55],
  "slam_damage_by_level": [0, 40, 60, 90],
  "scale_by_level": [1.0, 1.0, 1.06, 1.12],
  "power_by_camp_level": [0, 1.0, 1.15, 1.3, 1.45, 1.6, 1.75],
  "radius": 0.6,
  "speed": 1.15,
  "hurry": 1.3,
  "fist_every": 1.6,
  "fist_reach": 0.55,
  "slam_every": 7.0,
  "slam_first": 3.0,
  "slam_range": 2.2,
  "slam_min_foes": 2,
  "slam_daze_s": 0.6,
  "daze_radius": 0.45,
  "taunt_m": 1.6,
  "leash_extra_m": 5.0,
  "hold_leash_m": 5.5,
  "last_stand_reach": 2.5,
  "think_s": 0.25,
  "revive_s": 30.0,
  "revive_hp": 0.6,
  "help_range": 1.6,
  "help_rate": 2.0,
  "number_every": 0.4,
  "rest_offset": [-1.1, 0, 0]
}
```

### 6.3 `"garden"`

```json
"garden": {
  "_note": "a planted plot grows grow_dry steps for every wave the camp holds, grow_wet while watered (watering lasts wet_waves_by_level waves held); ripe at the crop's grow. Never real time: nothing grows while the game is closed or while the cat waits in the camp.",
  "plots_by_level": [0, 3, 5, 6],
  "wet_waves_by_level": [0, 3, 4, 5],
  "extra_by_level": [0, 0, 0, 1],
  "grow_dry": 1,
  "grow_wet": 2,
  "crops": [
    {"id": "sunberry",  "name": "Sunberries", "gives": "berries", "yield": 3, "grow": 4, "seed": {"leaves": 10}},
    {"id": "fernmint",  "name": "Fernmint",   "gives": "herbs",   "yield": 2, "grow": 5, "seed": {"leaves": 12}},
    {"id": "honeybell", "name": "Honeybells", "gives": "honey",   "yield": 2, "grow": 6, "seed": {"leaves": 15}}
  ]
}
```

### 6.4 `"ingredients"`

```json
"ingredients": {
  "berries":  ["Sunberry", "Sunberries"],
  "herbs":    ["Fernmint", "Fernmint"],
  "honey":    ["honey", "honey"],
  "fish":     ["fish", "fish"],
  "goldfish": ["Golden Carp", "Golden Carp"]
}
```
(Not `"items"`: `Save.items` already means defence pieces.)

### 6.5 `"cooking"`

```json
"cooking": {
  "_note": "one dish waits in the pot (Save.meal_ready); it is eaten when the next chapter (or raid) starts and lasts that chapter (Save.meal_on), then it is used up; if the camp falls it goes back into the pot. Boost keys: hp (added), draw, damage, friends (pet, mount and Warden hits), fire (campfire health), guardian_hp (shares), guardian_revive_s (seconds). unlock: garden | fishing | fishing+stone | goldfish (one was ever caught).",
  "pantry_cap": 20,
  "max_rows": 6,
  "recipes": [
    {"id": "berry_tart",   "name": "Berry Tart",         "needs": {"berries": 3}, "boost": {"draw": 0.15}, "says": "shoots 15% faster", "unlock": "garden", "color": "#e8603c"},
    {"id": "fernmint_tea", "name": "Fernmint Tea",       "needs": {"herbs": 2}, "boost": {"hp": 2}, "says": "+2 health", "unlock": "garden", "color": "#8fd18a"},
    {"id": "honey_cake",   "name": "Honey Cake",         "needs": {"honey": 2, "berries": 1}, "boost": {"friends": 0.4}, "says": "your pet, mount and Warden hit 40% harder", "unlock": "garden", "color": "#ffd36e"},
    {"id": "hearth_stew",  "name": "Hearth Stew",        "needs": {"herbs": 2, "honey": 1, "berries": 2}, "boost": {"fire": 0.4}, "says": "the campfire has 40% more health", "unlock": "garden", "color": "#d98b4a"},
    {"id": "fish_skewers", "name": "Fish Skewers",       "needs": {"fish": 2, "herbs": 1}, "boost": {"damage": 0.2}, "says": "arrows hit 20% harder", "unlock": "fishing", "color": "#f07f6a"},
    {"id": "root_stew",    "name": "Warden's Root Stew", "needs": {"fish": 2, "herbs": 2, "honey": 1}, "boost": {"guardian_hp": 0.5, "guardian_revive_s": 15}, "says": "the Warden: +50% health, back up in 15 s", "unlock": "fishing+stone", "color": "#7fcf6a"},
    {"id": "carp_feast",   "name": "Golden Carp Feast",  "needs": {"goldfish": 1, "berries": 2, "honey": 1}, "boost": {"hp": 2, "damage": 0.15, "draw": 0.1, "friends": 0.2, "guardian_hp": 0.2}, "says": "a little of everything", "unlock": "goldfish", "color": "#ffb43c"}
  ]
}
```

### 6.6 `"fishing"`

```json
"fishing": {
  "_note": "a calm game at the lake (fishing.gd): cast, wait, tap anywhere on the bite; uncommon and rare catches add reel pulses (tap while the closing ring is green). Misses cost nothing. rare_pity: a rare at the latest on this catch. A rolled rare is the next unfound lake treasure treasure_share of the time.",
  "cast_s": 0.55,
  "cast_m": [1.8, 2.6],
  "wait_s": [3.0, 6.0],
  "nibbles": [0, 2],
  "early_tap_s": 1.0,
  "bite_s": {"common": 1.0, "uncommon": 0.85, "rare": 0.7},
  "pulses": {"common": 0, "uncommon": 1, "rare": 2},
  "pulse_s": 1.1,
  "pulse_zone": 0.3,
  "pulse_grace_s": 0.15,
  "misses_allowed": 1,
  "rare_pity": 20,
  "treasure_share": 0.5,
  "cancel_drag": 0.5,
  "catches": [
    {"id": "minnow",    "name": "Minnow",       "rarity": "common",   "weight": 44, "gives": {"fish": 1},  "mesh": "fish_minnow"},
    {"id": "perch",     "name": "Sun Perch",    "rarity": "common",   "weight": 28, "gives": {"fish": 1},  "mesh": "fish_perch"},
    {"id": "trout",     "name": "Silver Trout", "rarity": "uncommon", "weight": 15, "gives": {"fish": 2},  "mesh": "fish_trout"},
    {"id": "driftwood", "name": "Driftwood",    "rarity": "common",   "weight": 7,  "gives": {"timber": 1}, "mesh": "driftwood"},
    {"id": "carp",      "name": "Golden Carp",  "rarity": "rare",     "weight": 4,  "gives": {"goldfish": 1}, "mesh": "fish_carp"},
    {"id": "chest",     "name": "Sunken Chest", "rarity": "rare",     "weight": 2,  "gives": {"leaves": 40, "timber": 3}, "mesh": "sunken_chest"}
  ],
  "treasures": [
    {"id": "lake_lure",  "name": "Lucky Lure",      "says": "Bites come 25% sooner", "wait_mult": 0.75},
    {"id": "lake_line",  "name": "Silk Line",       "says": "One more slip forgiven when you reel", "misses": 1},
    {"id": "lake_charm", "name": "Lake-moss Charm", "says": "New colours for the Warden: Lakeweed"}
  ]
}
```

### 6.7 `"looks"`: add the `"guardian"` slot

```json
"guardian": [
  {"id": "moss_warden", "name": "the Moss Warden", "short": "Moss Warden", "shout": "Rumble!", "fur": [0.25, 0.07],
   "skins": [
     {"id": "natural",  "name": "Natural",  "to": [-1, 1, 1]},
     {"id": "autumn",   "name": "Autumn",   "to": [0.07, 1.1, 0.95]},
     {"id": "frost",    "name": "Frost",    "to": [0.53, 0.55, 1.2]},
     {"id": "golden",   "name": "Golden",   "to": [0.12, 0.85, 1.08]},
     {"id": "midnight", "name": "Midnight", "to": [0.65, 0.6, 0.7]},
     {"id": "lakeweed", "name": "Lakeweed", "to": [0.45, 0.9, 0.95], "needs_flag": "lake_charm"}
   ]}
]
```
Tune `fur` once the model is coloured.

### 6.8 Economy

New leaf sinks over a full run: stone upgrades 1,700, garden upgrades 1,400, seeds about 1,500 (about 120 plantings),
so about 4,600 leaves against about 35,000 earned. New timber cost: 15. Fishing returns a little timber. No change to
`mission.pay_per_mission` is needed; revisit in the balance pass.

---------------------------------------------------------------------------------------------------------------------

## 7. Save fields (`save.gd`)

| Field | Default | `load_game` (typed) | `save_game` |
|---|---|---|---|
| `stations` | add `"stone": 0, "garden": 0, "fishing": 0` to the L11 dict | already merges keys (L55-56) | already saved |
| `guardian_look` | `"moss_warden"` | `String(d.get("guardian_look", "moss_warden"))` | yes |
| `guardian_skin` | `"natural"` | String | yes |
| `guardian_post` | `-1` (-1 guards the camp, 0-3 holds that trail) | `int(d.get("guardian_post", -1))` | yes |
| `garden` | 6 x `{"crop": "", "grow": 0, "wet": 0}` | read up to 6 entries as `{"crop": String, "grow": int, "wet": int}`, pad to 6 | yes |
| `pantry` | `{"berries": 0, "herbs": 0, "honey": 0, "fish": 0, "goldfish": 0}` | merge keys with `int()` | yes |
| `meal_ready` | `""` | String | yes |
| `meal_on` | `""` | String; then the rule in 4.2 turns it back into `meal_ready` | yes |
| `fish_log` | `{}` | catch id -> `int` | yes |
| `fish_dry` | `0` | int | yes |
| `flags` (existing dict) | new keys: `warden_awake`, `told_warden_down`, `told_garden`, `told_cook`, `told_fish`, `lake_lure`, `lake_line`, `lake_charm` | | |

**No timestamps anywhere.** Old saves load with the defaults; missed gifts are caught up (1.5); defence pieces on the
new ground are refunded (1.3).

## 8. Data helpers (`data.gd`)

```gdscript
func guardian_level() -> int: return int(Save.stations.get("stone", 0))
func guardian_awake() -> bool: return guardian_level() > 0 and Save.flag("warden_awake")
func guardian_name() -> String: return String(look("guardian", Save.guardian_look).get("short", "Moss Warden"))
func guardian_power() -> float: return pick("guardian", "power_by_camp_level", Save.camp_level)
func guardian_max_hp() -> float: return pick("guardian", "hp_by_level", guardian_level()) * guardian_power() * (1.0 + meal_boost("guardian_hp"))
func guardian_fist() -> float: return pick("guardian", "fist_damage_by_level", guardian_level()) * guardian_power() * (1.0 + meal_boost("friends"))
func guardian_slam() -> float: return pick("guardian", "slam_damage_by_level", guardian_level()) * guardian_power() * (1.0 + meal_boost("friends"))
func guardian_revive_s() -> float:
	var m := meal_boost("guardian_revive_s")
	return m if m > 0.0 else float(b["guardian"]["revive_s"])
func garden_level() -> int: return int(Save.stations.get("garden", 0))
func garden_plots() -> int: return int(pick("garden", "plots_by_level", garden_level()))
func crop(id: String) -> Dictionary          # b.garden.crops by id; {} if none
func recipe(id: String) -> Dictionary        # b.cooking.recipes by id
func catch_info(id: String) -> Dictionary    # b.fishing.catches by id
func item_name(id: String, n: int) -> String # b.ingredients[id][0 or 1]
func has_items(needs: Dictionary) -> bool    # Save.pantry >= needs
func take_items(needs: Dictionary) -> void
func add_items(d: Dictionary) -> Dictionary  # adds up to cooking.pantry_cap; returns what did not fit
var _boost := {}                             # the eaten dish's boost, cached (the stat getters run every frame)
func set_meal(id: String) -> void: _boost = recipe(id).get("boost", {}) if id != "" else {}
func meal_boost(k: String) -> float: return float(_boost.get(k, 0.0))
```
Changed: `cat_max_hp()` + `int(meal_boost("hp"))`; `cat_draw()` x (1 + `meal_boost("draw")`); `arrow_damage()` x
(1 + `meal_boost("damage")`); `power()` + `2 * guardian_level()` when `guardian_awake()`.

---------------------------------------------------------------------------------------------------------------------

## 9. Cards and rows

Rows use the existing format `{text, note, cost, label, enabled, action}` plus the optional `pulse`. Every card is
blanked in a wave by `hud._spec`, and every action re-checks `_locked()` itself. No card has more than 6 rows.

### 9.1 Guardian Stone (`_card_stone`)

Title "Guardian Stone". Sub `"Level %d · the Warden grows with your home too (x%.2f)"`. Anchor `_anchor("stone", 2.0)`.
The builder returns a one-row "The stone is quiet" card if `main.guardian == null` (it runs before the companions
exist).

While asleep:

| text | note | cost | label | enabled | action |
|---|---|---|---|---|---|
| The Moss Warden is asleep | An old guardian of mossy stone. Wake it and it guards your camp | {} | Wake | true, `pulse` | `_wake_warden` |

While awake:

| text | note | cost | label | enabled | action |
|---|---|---|---|---|---|
| `"%s · level %d"` (name, stone level) | `"%d health · fists %d · ground slam %d"` | {} | "" | false | |
| How it fights | Goes for whatever attacks your buildings, barricades or campfire · too slow for fliers and thieves · stand by it to help it up | {} | "" | false | |
| `"Post: %s"` ("guards the camp" / "holds the Fernwood trail") | Guard: "Goes where the fight is, all round the camp". Hold: "Stays at that trail's mouth; the rest of the camp is yours". Plus " · next mission: Fernwood, Toadstool Dell" | {} | Change | true | `_next_post` |
| (one per look, only when there is more than 1) look name | "Your guardian now" or "Same strength, a new look" | {} | Use / "" | not current | `_use_look.bind("guardian", id)` |
| `_skin_row("guardian")` "Colours: Natural" | the available skin names | {} | Next | skins > 1 | `_next_skin.bind("guardian")` |
| `_station_upgrade_row("stone")` | "Moss Warden: 1,035 health, fists 44, slam 69" or "Needs home level N" | level cost | Upgrade | | `_upgrade_station.bind("stone")` |

`_next_post()`: `if _locked(): return`. Cycles -1, then the lanes of the mission that comes next (`Save.mission_run`'s
mission, else `Data.next_mission()`; all 4 lanes after the last mission), then back to -1. Saves, `main.guardian.post =
main.guardian._post_spot()` if a mission is active, `hud.refresh_card()`.

### 9.2 Garden (`_card_garden`)

Title "Garden". Sub `"Level %d · %d plots · a step for every wave the camp holds"`. Anchor `_anchor("garden", 1.2)`.

| # | text | note | cost | label | enabled / pulse |
|---|---|---|---|---|---|
| 1 | "Pick what is ripe" | "+6 Sunberries, +2 Fernmint" (+ " · pantry full of Sunberries" when some do not fit) | {} | Pick | any ripe that fits; `pulse` |
| 1 (nothing ripe) | "Nothing ripe yet" | `garden.summary()`: "Sunberries 2/4 (watered) · Fernmint 1/5 · empty" | {} | "" | false |
| 2 (when something grows) | "Water the garden" | "Watered plants grow twice as fast for %d waves" | {} | Water | any growing plot with `wet` below the max; `pulse` while any growing plot is dry |
| 2 (all wet) | "Watered" | "%d more waves of water" | {} | "" | false |
| 3-5 | "Plant Sunberries" / "Plant Fernmint" / "Plant Honeybells" | "Ripe in 2 waves with water, 4 without · gives 3 · 2 empty plots", or "No empty plot" | seed `{"leaves": n}` | Plant | an empty plot exists and affordable (`_cost_row`) |
| 6 | `_station_upgrade_row("garden")` | "5 plots, water lasts 4 waves" (level 3: "6 plots, water lasts 5 waves, +1 on every harvest") | level cost | Upgrade | |

### 9.3 Cooking Pot (`_card_pot`)

Title "Cooking Pot". Sub: "Eating: %s · %s this chapter" and/or "In the pot: %s · eaten when the next chapter starts",
or "One dish at a time · eaten when the next chapter starts". Anchor `station_pos("pot") + (0, 1.4, 0)`.

| # | text | note | cost | label | enabled / pulse |
|---|---|---|---|---|---|
| 1 | "Pantry" | "5 Sunberries · 2 Fernmint · 1 honey · 3 fish (· 1 Golden Carp)", or "Empty: plant something in the garden" | {} | "" | false |
| 2-6 | `"Cook %s"` for each known recipe, cookable ones first | `"%s · %s"` (needs with have-counts, what it does), + " · swaps out the %s in the pot"; when not cookable, `why_not` first | {} | Cook | `can_cook`; `pulse` when cookable and the pot is empty |
| last (overflow only) | "More recipes" | "Fish Skewers (2 fish, 1 Fernmint) · Warden's Root Stew (2 fish, 2 Fernmint, 1 honey)" | {} | "" | false |

If more recipes are known than fit in 6 rows, the ones that do not fit go into the last info row.

### 9.4 Fishing Spot (`_card_fishing`)

Title "Fishing Spot". Sub `"Calm water · fish for the cooking pot · %d fish in the pantry"`. Anchor
`_anchor("fishing", 1.6)`.

| text | note | cost | label | enabled | action |
|---|---|---|---|---|---|
| Cast a line | "Tap anywhere when the float dips · drag to stop" (riding: "Get off %s to fish") | {} | Cast | `main.fishing.can_fish()` | `_cast` (`if _locked(): return`, then `main.fishing.cast(rings["fishing"])`) |
| `"Fish log · %d of 6 found"` | "Minnow 12 · Sun Perch 3 · Silver Trout 1 · ? · ? · ?" | {} | "" | false | |
| `"Lake treasures · %d of 3"` | names found, "?" for the rest, and what each does | {} | "" | false | |

### 9.5 Unchanged cards

The shop, the signpost and the village cards are not changed. The Warden's post lives on the stone card only.

---------------------------------------------------------------------------------------------------------------------

## 10. File-by-file change list

All paths under `D:\Projects\Project LEAF\game\` unless shown otherwise.

| File | Changes |
|---|---|
| `scripts/guardian.gd` (new) | section 2.11 |
| `scripts/garden.gd` (new) | section 3.5 |
| `scripts/cooking.gd` (new) | section 4.5 |
| `scripts/fishing.gd`, `scripts/fishing_ui.gd` (new) | section 5.5 |
| `scripts/main.gd` | preload the 4 scripts and `FishingUiScript`; vars `guardian, garden, cooking, fishing`; in `_ready` create `garden` (Node3D), `cooking` (Node) and `fishing` (Node3D) with `setup(self)` **before** `stations.build` (L86); after `hud.build`, `fishing.build_ui(hud)`; after `refresh_companions()`, `stations.catch_up_gifts()`. Hooks: `refresh_companions` (guardian), `on_stage_start` (guardian, `fishing.stop("")`), `on_wave_start` (`if (n - 1) % fight.chapter_waves() == 0: cooking.eat()` first, then guardian, `fishing.stop("")`), new `on_wave_held()` (`garden.grow_wave()`, then `hud.refresh()`), `on_wave_cleared` (`guardian.refill()`), `on_stage_end` (guardian, `fishing.stop("")`), `_update_grass` (guardian pusher), new `reopen_ring()` |
| `scripts/fight.gd` | `_wave_cleared`: `main.on_wave_held()` right after `in_wave = false`. `_chapter_done`: `main.cooking.finish(true)` before `gate_hp = gate_max`; the boss tip after the banner. `_end(won)`: first line `if main.cooking: main.cooking.finish(won)` (no-op if nothing is eaten) |
| `scripts/enemy.gd` | `wrecking()`, `hitting_cat()`, `stagger()`, the taunt check and `_fight_guardian()`, the `_impact` "attack" and "slam" branches, `_burst`, `_do_charge` (2.5-2.7) |
| `scripts/stations.gd` | registries (1.2); `_locked()`; pulse key; `catch_up_gifts()`; gift banners; `_card_stone`, `_card_garden`, `_card_pot`, `_card_fishing`; actions `_wake_warden`, `_next_post`, `_garden_plant`, `_garden_water`, `_garden_pick`, `_cook_dish`, `_cast`; `_station_upgrade_row` elifs; three-slot skins (1.7); rune parts by stone level in `refresh()`; `set_fire_out` pot ring |
| `scripts/hud.gd` | `_on_save_changed` fix; `banner_later`; `_meal_l` chip in `build()` and `refresh()` |
| `scripts/lifebar.gd` | the Warden's bar and regrow arc (2.12) |
| `scripts/player.gd` | `push_out` line after `constrain`; `set_fishing(on)` with `_rod_hold` (5.3) |
| `scripts/pet.gd`, `scripts/mount.gd` | `friends` boost on spark and Thump damage |
| `scripts/data.gd` | section 8 |
| `scripts/save.gd` | section 7 |
| `scripts/world.gd` | `station_pos` cases, `POT_R`, `FISH_RING`, `RESERVED`, `in_reserved`, the hide-spot post-filter, the path key and the garden branch |
| `scripts/grass.gd` | the 3-key keep-out loop |
| `scripts/lake.gd` | shore skip near `FISH_RING`, public `splash(at)`, fireflies `Quality.particles(16)` |
| `scripts/defences.gd` | `_valid` reserved check; the one-time refund in `build()` |
| `scripts/props.gd` | placeholders (1.6), `merge()` |
| `scripts/fx.gd` | `puff()` |
| `scripts/autotest.gd` | new modes (13); `_veteran(n)`: `n >= 4` garden 1, `n >= 5` stone 1 and flag `warden_awake`, `n >= 6` fishing 1, pad `Save.garden`; `_perf_diag_camp` lists add `main.guardian` and `main.fishing` |
| `data/balance.json` | section 6 |
| `D:\Projects\Project LEAF\tools\make_sfx.py` | new placeholder sounds `thud`, `rumble`, `plop`, `splash`, `pluck`, `water`, `sizzle` (made in the step that first plays them) |
| `D:\Projects\Project LEAF\docs\ASSET_RULES.md` | the Warden row (6,000) and its clips; the `camp_life` props group |
| `D:\Projects\Project LEAF\GAME_PLAN.md` section 0 | mark Phase C decisions; record the gift missions |
| `D:\Projects\Project LEAF\docs\PERFORMANCE.md`, `game/README.md` | the new per-frame costs and modes |

---------------------------------------------------------------------------------------------------------------------

## 11. Blender props (Claude models them)

New group **`camp_life`**: working file `art/blender/props/camp_life.blend`; scripts
`art/scripts/props/camp_life/{camp_life_kit, build_camp_life, export_camp_life, render_camp_life, contact_camp_life,
meta}.py` (mirroring `village/`); previews `art/previews/props/camp_life/`; manifest
`game/assets/props/camp_life.json` (size_m, collision radius = FOOT, tris, markers, notes). Rules (ASSET_RULES.md):
low poly, one flat colour per face as vertex colours (`COLOR_0`), the `M_VertexColor` material, no UVs or textures,
origin on the ground at the footprint centre, front facing Blender -Y (Godot +Z), transforms applied,
`blender-asset-qa` before a prop counts as done.

| GLB | Size x / y / z (m) | Collision | Max triangles | Content, named parts and markers |
|---|---|---|---|---|
| `guardian_stone` | 1.0 / 0.9 / 1.6 | circle 0.7 | 1,500 | old rounded standing stone in flat grey patches, a moss cap, two roots coiling round the base, small white flowers and a fern, a ring of flat stones, a mossy hollow where the Warden sits. The carved leaf rune on the front is three separate gold objects `rune_1`, `rune_2`, `rune_3` (shown by stone level). `marker_ring` 1.1 m in front |
| `garden_bed` | 2.2 / 1.4 / 0.45 | circle 1.1 | 2,000 | raised bed of logs and planks, dark soil, 6 low mounds in 2 rows of 3, 0.6 m apart; empties `marker_plot_1..6` on the soil tops (1-3 the front row, -Y); a rain barrel at one end, a small seed crate and a watering can at the other, a tiny leaf sign. `marker_ring` 1.2 m in front |
| `plot_weeds` | 0.5 / 0.5 / 0.15 | none | 150 | weeds and a pebble on a locked plot |
| `soil_wet` | 0.45 / 0.45 / 0.02 | none | 20 | a dark wet-soil slab |
| `plant_sprout` | 0.15 tall | none | 60 | two tiny leaves (first stage of every crop) |
| `sunberry_growing`, `sunberry_ripe` | up to 0.4 tall | none | 150 each | a round green bush; ripe adds 6 orange-red berries |
| `fernmint_growing`, `fernmint_ripe` | up to 0.35 tall | none | 150 each | a mint-fern clump; ripe is fuller, pale blue-green with white tips |
| `honeybell_growing`, `honeybell_ripe` | up to 0.45 tall | none | 150 each | stalks with closed buds; ripe has 3 golden bell flowers |
| `cook_pot` | 0.6 / 0.6 / 0.55 | circle 0.25 | 600 | a squat dark iron pot with two handles on 3 short legs over 3 hearth stones, 2 bright orange ember faces, green soup faces, a wooden ladle. `marker_steam` at the pot's mouth |
| `fishing_spot` | 1.0 / 1.2 / 1.3 | circle 0.45 | 900 | a mossy stump seat, a bait tin, a wicker fish basket, a small rod rack; the rod on the rack is a separate object `rod` (hidden while the cat fishes). The cat stands on its +X side |
| `fishing_rod` | 1.1 long | none | 100 | a bamboo rod with a little reel; origin at the grip, pointing +Y; empty `marker_tip` at the tip |
| `fish_minnow`, `fish_perch`, `fish_trout`, `fish_carp` | 0.15-0.35 long | none | 100 each | for the catch arc; the carp gold |
| `driftwood`, `sunken_chest` | up to 0.4 | none | 100 each | for the catch arc; the chest a small mossy box with a glint |

The float, the fishing line and the Warden placeholder are built in code. The Warden itself is the user's Meshy model
(section 2.13). Add a "camp life" line to `docs/ASSET_RULES.md` "Props and buildings".

---------------------------------------------------------------------------------------------------------------------

## 12. Quality and low-end phones

- **Warden**: one skinned mesh and one material (one draw call, plus a shadow pass on Medium and High; `Fx.blob` on
  Low). Spring bones only when `Quality.springs()` (pet.gd and mount.gd do not check this today; the Warden does). It
  thinks at 4 Hz with one `foes` fetch; per frame it runs movement, `constrain`, an O(k <= 10) push and the cat push.
  No per-frame `Props.set_param` (flash set on change), damage numbers summed every 0.4 s (no Label3D per hit), one
  shockwave torus every 7 s at most, rubble only while it is down.
- **Enemies**: one distance check per 0.2 s think (`taunts`), plus one per charge frame and one per slam or burst.
- **Garden and cooking**: no `_process`. The garden is two draw calls (bed and one merged plant mesh), rebuilt only on
  change. Steam and glints use `Quality.particles(n)` and emit only when relevant.
- **Fishing**: `_process` and `_draw` run only while a line is out; 3 small meshes then; splashes through
  `lake.splash` and `Fx`.
- **Lights**: none new. The rune, the embers and the eyes are bright faces that High's glow picks up. If a light is ever
  added, it goes in group `lamp` with `visible = Quality.lamps()`.
- **Lake**: the 16 fireflies follow `Quality.particles(16)`.
- **Draw calls in view**: pot +1 (near the fire), stone +1, Warden +1 (+1 blob on Low), garden +2, fishing prop +1,
  float and line +2 only while fishing. The stone, garden and fishing spot sit 7-9 m from the fire and are culled in
  most fights. Triangles: about +3k in the camp, +6k with the Warden on screen.
- **Target**: `--perf` with the Warden holding a pack stays within +0.3 ms of the old baseline on the PC at
  `--quality=low`; check on the phone in the Low S24 run.

---------------------------------------------------------------------------------------------------------------------

## 13. Automated tests (`autotest.gd`; the lead runs them in Godot)

Every mode logs `AUTOTEST {json}` lines and writes shots to `--shots`.

1. **`--guardian`** (about 45 s):
   - `_veteran(5)`, clear `warden_awake`. Expect: the Warden exists, `state == "sleep"`, `is_in_group("foes")` and
     `is_in_group("enemies")` both false. Walk to `rings.stone`, press "Wake": `state == "rest"` within 3 s, flag set,
     `hp == Data.guardian_max_hp()` (690 at home level 2). Shots `warden_sleep`, `warden_wake`.
   - `start_stage(5)` with fight physics off, foes cleared, the cat invincible at (0, 0, 17.5): within 10 s the
     Warden is within 1 m of its post. Shot `warden_post`.
   - Spawn 3 thornlings (normal hp), a brute and a stump (hp 1e6) near the post; log every 2 s for 16 s the Warden's
     `{state, target.id, hp}` and each foe's `{id, state, at_warden: _act_target == guardian}`. Expect: a target within
     2 s, `kills >= 3`, `slams >= 1`, at least one foe fighting the Warden, at least one foe in "daze". Shots
     `warden_punch`, `warden_slam` (with `closeup_at = guardian`).
   - Wrecking first: a stump (1e6) attacking the well and an idle thornling 1 m from the Warden: `target.id ==
     "stump"` within 1 s.
   - Charge block: a boar forced into `charge` at the Warden: it ends in "daze" and the Warden's hp dropped by about its
     `gate_damage` x strength. Shot `warden_block`.
   - Knockdown: `hurt(100000)`: `state == "down"`, `taunts(brute) == false`. The cat beside the heap for 3 s: `_down_t`
     drops by about 6. `_down_t = 1.0`: up within 3.5 s at about 0.6 x max. `hurt(100000)` again, then
     `main.on_wave_cleared()`: up and whole. Shot `warden_down`.
   - Last Stand: `fight._start_last_stand()`, the cat at (2, 0, -3): within 6 s the Warden is within 1.5 m of the ash
     spot on the cat's side; 3 thornlings spawned at the cat: none has `_act_target == guardian`, and the Warden punches
     them.
   - Fight physics on, foes killed: `_wave_cleared` fires (the Warden never blocks a wave's end).
   - `fight.camp_falls()`: the Warden is up, whole, and walking home; asleep at home (`rest`) within 20 s.
2. **`--guardianab`** (about 2 x 120 s): `_veteran(5)`, mission index 5 (Mossback) with the cat invincible at
   (0, 0, 17.5) and fight physics on. Run once with the Warden and once with `guardian.process_mode = DISABLED;
   visible = false`. Log campfire hp lost, building hp lost, ruins, waves cleared, and the Warden's
   kills / slams / downs / `dealt`, plus `warden_share` (its damage against everything else's). Expect clearly less
   damage with it, and no stuck wave.
3. **`--garden`**: `_veteran(4)`, 500 leaves. At `rings.garden`: shot `garden_card`; 3 plots at level 1. Press "Plant"
   on Sunberries 3 times: 30 leaves spent. `main.on_wave_held()` twice with no water: every `grow == 2`, not ripe.
   "Water", then `on_wave_held()` once: ripe (2 + 2 = 4). "Pick": `pantry.berries == 9`. Shots `garden_planted`,
   `garden_ripe`. **No real-time growth**: plant again and wait 20 s in the camp: unchanged. Save round trip
   (`save_game`, `load_game`): identical. Home level 2 and "Upgrade": `plots() == 5`. In-wave lock: with
   `fight.active = in_wave = true`, `stations._garden_plant("sunberry")` changes nothing, and after `Save.add_leaves(1)`
   the open card has no buttons (`hud.card_buttons().size() == 0`, proving the hud fix).
4. **`--cook`**: `_veteran(5)`, pantry `{berries 8, herbs 6, honey 4, fish 0, goldfish 0}`. At `rings.pot`: shot; no
   fish recipes shown, no Feast. Cook Berry Tart: `meal_ready == "berry_tart"`. Cook Fernmint Tea: it swaps.
   `start_stage(0)`: at wave 1 `meal_on == "fernmint_tea"`, `meal_ready == ""`, `Data.cat_max_hp()` = base + 2, the
   chip text set. Shot `cook_eaten`. Force `fight._chapter_done(0)`: `meal_on == ""`, max hp back. Cook Hearth Stew in
   a breather, go on: at the next chapter's first wave `gate_max == fire_hp * 1.4`. `camp_falls()`: the stew is back in
   the pot. Reload with `meal_on` set: it turns into `meal_ready`. `_cook_dish("berry_tart")` with `in_wave = true`
   changes nothing. `stations.set_fire_out(true)`: the pot ring hides.
5. **`--fishing`**: `_veteran(6)`, `main.fishing.rng.seed = 7`. At `rings.fishing`: shot `fish_card`. Five casts with
   `debug_wait = 0.8`: press "Cast", wait for "bite" (8 s timeout), `tap()`; in "reel", wait for `in_zone()` and
   `tap()`; log each catch, the pantry and the log. Shots `fish_cast` (close-up of the rod in the paw), `fish_bite`,
   `fish_reel`, `fish_catch`. A tap in "wait" keeps "wait". No tap on a bite: "got away". `debug_catch = "carp"` and
   two early taps: it escapes; with taps in the zone: `pantry.goldfish == 1`, the Feast row appears at the pot. Pity:
   `Save.fish_dry = 19`, cast: a rare, `fish_dry == 0`. Treasures: three forced rares give `lake_lure`, `lake_line`,
   `lake_charm` in order (with `treasure_share` forced to 1). Stop: joystick forced to (0.8, 0) for 0.3 s returns to
   idle and the card; `main.on_wave_start(...)` during a wait returns to idle. Also log the skeleton's bone names once,
   so `ROD_XF` and the bone are checked.
6. **`--camplife`**: `_veteran(14)`, everything built, then home levels 1 to 6 with `on_camp_grown()`. Shots from each
   new ring and an overview per level. Log and expect 0 of each: hide spots with `in_reserved(c, r)`; `Save.placed`
   pieces in reserved ground; pairs of visible rings closer than 1.5 m; new `st_` circles overlapping other `st_`
   circles; the start and revive spots inside a ring. No magenta placeholder boxes.

**Regression set** after every step: `--smoke`, `--village` (shop "Build" x5 unchanged), `--siege`, `--laststand`,
`--bars`, `--skins` (plus a guardian pass: every skin, `set_look`, Lakeweed hidden until `lake_charm`), `--levels`,
`--grasswalk` (trail grass unchanged), `--lake`, `--perf` and `--perfdiag`. `--perf` with `_veteran(6)` now includes
the Warden: record a new baseline. Modes that use `_veteran(4)` (`--siege`, `--laststand`, `--newfoes2`) get the garden
and pot but no Warden, so their numbers stay comparable.

---------------------------------------------------------------------------------------------------------------------

## 14. Build order (small steps; each leaves the game playable)

| Step | What | Verify with |
|---|---|---|
| **C0a** | `hud._on_save_changed` fix, `_locked()`, the `pulse` key, `banner_later`, `reopen_ring`, `Fx.puff` **Built.** | `--smoke`, `--village` |
| **C0b** | Save fields, Data helpers, all `balance.json` tables (section 6) except the mission gifts **Built.** | `--smoke` with an old save |
| **C0c** | `RESERVED`, `in_reserved`, the hide-spot post-filter, the defence `_valid` check and one-time refund, the lake shore skip and fireflies, `station_pos` cases, `POT_R`, `FISH_RING`, the path key **Built.** | `--camplife` (nothing built yet), `--grasswalk`, `--lake` |
| **C0d** | three-slot skins and looks **Built.** | `--skins` |
| **C0e** | `catch_up_gifts()` (it already repairs stall and cottage) **Built** (also gives the garden's 4 Sunberries). | `--smoke` with an old save |
| **C1a** | Concept prompt `03_moss_warden.txt` and one Codex image, sent to the user for Meshy (the long pole, so first) *Not done here (the lead's step).* | the image |
| **C1b** | Stone station: registries, placeholder prop, `_card_stone` with Wake, the `stone` gift on `bandits`, the gift banner **Built**, then changed by the user: no mission gives the stone; `stations.free_guardian()` (Phase E) does. | `--guardian` (sleep and wake part) |
| **C1c** | `guardian.gd` placeholder body, states, movement, home/post, main hooks; no fighting yet **Built** (the Warden walks a grid path round the camp to its post and home). | shots |
| **C1d** | Fighting: think, punch, slam, `stagger`, the enemy.gd hooks, `hurt`, crumble and regrow, the lifebar **Built.** | `--guardian`, `--guardianab`, `--siege`, `--laststand`, `--perf` |
| **C1e** | The post choice on the stone card **Built.** | `--guardian` (post part) |
| **C2a** | Garden station and pot ring registries, `garden.gd` logic, `_card_garden` and its actions, `on_wave_held`, the `garden` gift on `stumps`, the garden path and grass keep-out **Built**; the garden is mission 1's gift now (the user), not mission 4's. | `--garden` |
| **C2b** | The garden's merged plant mesh and glint **Built.** | `--garden` shots |
| **C3** | Cooking: `cooking.gd`, `_card_pot`, the eat and finish hooks, the boost hooks in data.gd, pet.gd and mount.gd, the HUD chip, the boss tip **Built.** | `--cook`, `--bars` |
| **C4a** | Fishing: `fishing.gd` states, `fishing_ui.gd`, `_card_fishing`, the rod in the paw, the `fishing` gift on `mossback` **Built** (together with C4b). | `--fishing` |
| **C4b** | Catches, fish log, pity, lake treasures, the Lakeweed skin, the fish recipes **Built.** | `--fishing`, `--cook`, `--skins` |
| **C5** | The `camp_life` props in Blender and their manifest; swap out the placeholders *Done by the props agent; the GLBs are in use.* | `--camplife` at levels 1, 3 and 6, `--perf` |
| **C6** | The Warden's model from the user's Meshy file: cut to 6,000 tris, colour per face from the concept, rig, the 8 clips with events, jig chains, export, JSON, QA *Done by the model agent; the GLB is in use (checked with `--guardian`, `--skins`).* | `--guardian` close-ups, `--skins` |
| **C7** | Polish: sounds in `make_sfx.py`, tips, first-catch banners; optional cosmetic moments (pats: a "Hrrm!" when the cat stands still beside it outside waves; at a chapter break it may hold out a flower that gives nothing). Docs (section 10). `--perf` on Low and on the S24; a balance pass on the Warden's share, garden pace, meal strength and fishing feel; a debug APK for the user *Partly: the tips, banners and first-catch moments are in; no sounds, no cosmetic pats, no APK.* | everything in the regression set |

C1 can ship with the placeholder body while the user makes the Meshy model.

**Status, 18 November 2026.** Steps C0a to C4b are built and tested (see docs/PHASE_A_PROGRESS.md, "Phase C"). Changes
from the user while it was built: (1) the garden and its cooking pot are the gift of mission 1's first win, with 4
Sunberries; (2) a mount knocked out in a mission stays out until it is fed (balance.json `mount.revive_food`, 2
Sunberries, the HUD's Feed button) or the next chapter break; (3) guardians are found, never bought or given by a
mission: Phase E frees the Moss Warden with `stations.free_guardian()` in the first Burrow.

---------------------------------------------------------------------------------------------------------------------

## 15. Open questions for the user

1. GAME_PLAN.md section 0's Gloom Raid proposal says "the meter can fill offline". That breaks the no-offline-progress
   rule. This spec never progresses anything offline; Phase D should drop that line. Agree?
2. Unlocks: garden and cooking pot at mission 4, the Warden at mission 5 (woken by the player), fishing at mission 6.
   Is that order right?
3. The cat holds the fishing rod in its bow hand in the carried pose. If that reads badly in the close-up, should
   Claude add a short `Cast` clip to the Cat Ranger in Blender?
4. Should the Golden Carp (the boss feast) depend only on fishing luck (with the 20-catch pity), or should Bramble's
   stall also sell one carp per mission?
