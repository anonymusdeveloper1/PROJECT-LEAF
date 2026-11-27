extends Node
## An enemy's Loot (H6 Stage 1, 27 Nov 2026; docs/ARCHITECTURE.md part 4, Component): what it pays when it dies. In a
## Burrow the run pays and counts the fight (area.on_enemy_died); in the camp it drops leaves (a wave's pay is
## multiplied, the leaves it stole come back unmultiplied). A child named "Loot" of the enemy; no class_name.
## Used by: connected to the enemy's Health `died` signal (enemy.setup). enemy._die emits it right after
## fight.on_enemy_died and right before Events.enemy_died, so the order of events is H5's.

var e: EnemyNode                           # the enemy (enemy.gd) this part belongs to; set once by bind_enemy


func bind_enemy(enemy: Node3D) -> void:
	e = enemy as EnemyNode


func on_died() -> void:
	if e._in_area():
		e.main.area.on_enemy_died(e)                # in a Burrow: the run pays (leaves, amber, dew) and counts the fight
	else:
		var value := Data.saddlebag_leaves(int(e.info["leaves"]))
		if e.main.fight.active:
			value = roundi(value * float(Data.b["mission"]["enemy_leaf_mult"]))
			# Apply the bonus to fresh leaves after the existing camp drop is worked out.
			value = roundi(value * float(Data.b["kill_leaf_bonus"]))
		value += e.carried                           # returned stolen leaves are never multiplied
		e.main.drop_leaves(e.global_position, value)
