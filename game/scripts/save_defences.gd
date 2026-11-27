extends RefCounted
## The defence part of loading a save (H6, moved here from save.gd in Stage 3; the same checks, no behaviour change).
## Static functions only; it keeps no state. No class_name: preload it,
## const SaveDefences := preload("res://scripts/save_defences.gd"). `save` is the Save node being loaded.
## Used by: Save.load_game. Uses: Data (the caps in balance.json save_upgrades.to_v6) and Save's _whole / _is_num.


## The defence levels after a load (a v6 file never meets the converter, so the loader checks them): every placed
## record's level is a whole number in 1..cap (the same dictionary, since live pieces point at it); the carried records
## and the credits are read through the same rules. `d` is the file's dictionary.
static func load_levels(save, d: Dictionary) -> void:
	var cfg: Dictionary = {}
	var su: Variant = Data.b.get("save_upgrades", {})
	if su is Dictionary and (su as Dictionary).get("to_v6") is Dictionary:
		cfg = (su as Dictionary)["to_v6"]
	var caps: Dictionary = cfg.get("level_cap", {}) if cfg.get("level_cap") is Dictionary else {}
	var bag_kinds: Array = cfg.get("bag_kinds", ["tower", "spikes"]) if cfg.get("bag_kinds") is Array else ["tower", "spikes"]
	for sp: Variant in save.placed:
		var rec: Dictionary = sp
		if caps.has(String(rec.get("type", ""))):
			rec["level"] = clampi(save._whole(rec.get("level", 1)), 1, maxi(1, save._whole(caps.get(String(rec.get("type", "")), 5))))
	save.defence_reserves = {}
	var rv: Variant = d.get("defence_reserves", {})
	if rv is Dictionary:
		for k: Variant in bag_kinds:
			var kind := String(k)
			var src: Variant = (rv as Dictionary).get(kind)
			if not src is Array:
				continue
			var cap := maxi(1, save._whole(caps.get(kind, 5)))
			var list: Array = []
			for r: Variant in src:
				if not r is Dictionary or list.size() >= maxi(0, int(save.items.get(kind, 0))):
					continue
				var one: Dictionary = {"level": clampi(save._whole((r as Dictionary).get("level", 1)), 1, cap)}
				var w: Variant = (r as Dictionary).get("wreck")
				if save._is_num(w) and is_finite(float(w)):
					one["wreck"] = clampf(float(w), 0.0, 1.0)
				list.append(one)
			if not list.is_empty():
				save.defence_reserves[kind] = list
	save.defence_legacy_credit = {}
	var cd: Variant = d.get("defence_legacy_credit", {})
	if cd is Dictionary:
		for kind: String in ["barricade", "tower", "spikes"]:
			var c: int = save._whole((cd as Dictionary).get(kind, 0))
			if c > 0:
				save.defence_legacy_credit[kind] = clampi(c, 1, maxi(1, save._whole(caps.get(kind, 5))))
