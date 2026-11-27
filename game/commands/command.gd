extends RefCounted
## An action that can be checked before it runs.


func can_run(_main: Node3D) -> String:
	return ""


func run(_main: Node3D) -> bool:
	return false
