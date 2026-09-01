class_name Puzzle
extends Node
## Metadata for a puzzle so the route verifier can reason about it, plus a
## tiny helper to mark it solved. Areas declare one per puzzle:
##
##   Puzzle.declare(self, "forest_braziers", "braziers_solved", [], "light the braziers in the order of the stones")
##
## `requires` entries look like "keepsake:lantern", "item:coin" or "flag:x".

signal solved

@export var id := ""
@export var sets_flag := ""
@export var requires: Array = []
@export var hint := ""
## Things the solution hands over (trades, riddles): item ids / keepsake ids.
@export var grants_item := ""
@export var grants_keepsake := ""


func is_solved() -> bool:
	return sets_flag != "" and Game.has_flag(sets_flag)


func solve(message: String = "") -> void:
	if is_solved():
		return
	if sets_flag != "":
		Game.set_flag(sets_flag, true)
	Audio.sfx("riddle_correct", null, -4.0)
	if message != "":
		Game.toast.emit(message)
	Game.note("puzzle_" + id, "Solved: " + id.replace("_", " "), hint if hint != "" else "You worked something out.")
	solved.emit()


static func declare(parent: Node, id_: String, sets_flag_: String, requires_: Array = [], hint_: String = "", grants: Dictionary = {}) -> Puzzle:
	var p := Puzzle.new()
	p.id = id_
	p.sets_flag = sets_flag_
	p.requires = requires_
	p.hint = hint_
	p.grants_item = String(grants.get("item", ""))
	p.grants_keepsake = String(grants.get("keepsake", ""))
	p.name = "Puzzle_" + id_
	parent.add_child(p)
	return p
