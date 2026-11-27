# Game content

Each kind groups entries by ID under `<kind>/<id>/`. An entry lives in
`entry.json` beside its model, icon, and any other assets for that entry.
Keep folder IDs lowercase with underscores and stable after release.

`index.json` lists the IDs for each kind. Data reads the index at startup,
including in Android exports.

See [Architecture, part 5](../../docs/ARCHITECTURE.md#5-content-one-folder-per-thing)
for the entry format and index workflow.

## The shop kinds (H5)

`mounts`, `pets`, `outfits` and `attachments` hold what the Market, the
Saddlery and the Tailor's Nook sell. `scripts/shop_data.gd` reads them, and
callers ask `Data` (`Data.shop_entries`, `Data.owned_level`, ...).

Every entry has the shared fields `id`, `name`, `desc`, `icon`, `price` and
`unlock`, and may have `hidden: true`.

- `price` is a currency dictionary, such as `{"leaves": 160}` or
  `{"leaves": 900, "timber": 30}`. `{}` means free, or included once its
  `unlock` rule holds (Thistle and Bramblewool come with the Market, the
  original outfit is always owned). A missing price, or one in a currency the
  shops cannot take (amber, or one the game does not know yet), is never sold.
- `icon` is a picture ID drawn in `scripts/ui_icons.gd`. It stands in when the
  optional `picture` file (a `res://` path, such as
  `res://content/mounts/thistle/icon.png`) is missing.
- `model` is a `res://` path. The shipped models stay where they are in
  `assets/`.

What each kind adds:

| Kind | Its own fields |
|---|---|
| `mounts` | `short` (the short name), `shop` (`stall`), `fur` and `skins` (the colours). Every mount has the same speed, health and skills. |
| `pets` | `short`, `shop` (`stall`), `flies`, `spark`, `fur`, `skins`. `looks_only: true` (Lumi) buys only the look, and only once the pet is owned. All pet looks share one pet level. |
| `outfits` | `picture` (the Tailor's card), `model` (a whole hero model; `""` for the original look, which uses the hero model). |
| `attachments` | `shop` (`saddlery` or `stall`), `slot` (`mount` or `pet`), `scope` (`all`: works everywhere; `expedition`: the Burrows only). A Saddlery attachment has `price` for level 1 and `upgrades` for levels 2 to 5 (`needs_burrows: true` is a gate, never a payment), its effect numbers, and `model` with `{mount}` standing for the mount look's ID. Expedition gear has one price and its `mods`. |

What the player owns is in the save (version 5): `owned[kind][id] = {"level": n}`
(1 for a look or an outfit, the bought level for a Saddlery attachment), read
through `Data.owned_level`. The pet has one shared level (`Save.pet_level`), and
an old save's Mushroom Cottage and Market became the pet, the mount looks and the
mount's carried tier (`core/save_upgrade_v5.gd`). The Cottage's building entry is
gone; its picture and model stay in `assets/`.

To add one: copy an entry of the same kind, give it a new folder ID, list the
ID in `index.json`, keep it `hidden` until the owner says it goes in, and run
`--content`.

## H6 rebuild

- An enemy entry holds its existing model ID in `assets/enemies/`, role and
  part data. `parts.health.max` is the base HP used for wave planning.
  `Data.enemy` presents the combat fields alongside the parts. The Gloom Totem
  still uses its procedural prop look. The H5 entries use zero armour.
- A squad entry lists its members in spawn order. Each member has a `kind`
  and an inclusive `n` range. `from_mission` and `elite` keep their H5 meaning.
  Add new enemies and squads to the index and run the encounter checks.
- A defence has one `levels` row per tier, starting at level 1. Each row names
  its prop and stats. H5 upgrade leaves and shards come from `upgrade` and
  `shards`. `price` is for buying a piece or building a road row.
  `from_bag` marks the pieces the Bag carries. The old fence refund stays in
  balance data. Add new entries to the index and run the Bag and row checks.
- Building `model` names a prop. `layout` holds position, collision footprint,
  ring offset, path and grass clearance where used. Points and offsets are
  XYZ arrays in metres. `path` gives the original points, smoothing steps
  and multiplier on the camp path half-width. The Well also has a stamp peak.
  The Hearthtree's marker on the model has its own fallback offset.
  Stand-ins and level variants use the same layout records.
- Specialisation entries are staged and hidden. `price` is the cost to learn
  and `upgrades` gives the next two prices. `effect` names the tuning under
  balance data's `specialisations`. Use `Data.specialisation_info` to read
  the tuning during the foundation test.
