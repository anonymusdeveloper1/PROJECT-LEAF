## Versioned save upgrades used by Save after backing up an old file.
## Each step takes one save dictionary, keeps unrelated fields and advances the format by one.
class_name SaveUpgrades
extends RefCounted

const CURRENT_VERSION := 2
const FIRST_STEP_VERSION := 2  # Version 1 still goes through the existing raid fix.


static func upgrade(d: Dictionary) -> Dictionary:
	var steps: Dictionary[int, Callable] = {
		# Next step (2 -> 3): add 2: _upgrade_2_to_3 for amber and Hollow keys.
		# When bumping CURRENT_VERSION, carry forward the legacy raid fix for v1 saves.
	}
	var original_version := int(d.get("save_v", 1))
	# The raid fix still owns the v1 version stamp. Start the versioned steps at v2 for those files.
	var version := FIRST_STEP_VERSION if original_version == 1 else original_version
	while version < CURRENT_VERSION and steps.has(version):
		d = steps[version].call(d)
		version += 1
		d["save_v"] = version
	if version != CURRENT_VERSION:
		push_error("Save upgrade stopped at version %d (expected %d)." % [version, CURRENT_VERSION])
	return d
