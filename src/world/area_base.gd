class_name AreaBase
extends Node3D
## Base class for every area (realm).
##
## An area builds itself in `build()` using the Kit, registers spawn points with
## `add_spawn()`, and reacts to the player through the `on_*` hooks. Areas are
## instantiated fresh on every visit, so anything that should persist goes in
## Game flags. `visit_count` tells the area how many times it has been entered
## (the Nowhere House uses this to become a different house).

@export var area_id := ""
## False for waking-world areas: holding R does nothing there.
@export var can_wake := true

var spawns: Dictionary = {}
var visit_count := 0
## Seeded per area and per run: the same dream, dreamt the same way, until you wake.
var rng := RandomNumberGenerator.new()
var built := false
var _bell_connected := false


func _ready() -> void:
	if area_id == "":
		area_id = _guess_id()
	visit_count = Game.visits_to(area_id)
	rng.seed = hash(area_id) ^ Game.run_seed
	Game.bell_rung.connect(_on_bell)
	Game.umbrella_changed.connect(on_umbrella)
	Game.time_frozen_changed.connect(on_time_frozen)
	Game.lantern_changed.connect(on_lantern)
	Game.mirror_sight_changed.connect(on_mirror_sight)
	build()
	built = true
	if not spawns.has("default") and spawns.size() > 0:
		spawns["default"] = spawns.values()[0]


func _guess_id() -> String:
	var p := scene_file_path
	if p == "":
		return name.to_lower()
	return p.get_file().get_basename()


## Override: construct the area.
func build() -> void:
	pass

## Called by World after the player is placed. `n` is the visit count (1 = first).
func on_enter(spawn_id: String, n: int) -> void:
	visit_count = n

## Called by World just before the area is freed.
func on_exit() -> void:
	pass

func _on_bell(origin: Vector3) -> void:
	on_bell(origin)

## Keepsake hooks — override as needed.
func on_bell(_origin: Vector3) -> void:
	pass

func on_umbrella(_open: bool) -> void:
	pass

func on_time_frozen(_frozen: bool) -> void:
	pass

func on_lantern(_lit: bool) -> void:
	pass

func on_mirror_sight(_active: bool) -> void:
	pass


## Register a spawn point. yaw: 0 faces north (-Z), 90 west (-X), -90 east (+X), 180 south (+Z).
func add_spawn(id: String, pos: Vector3, yaw_deg: float = 0.0) -> void:
	spawns[id] = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), pos)


func player() -> Player:
	return Game.player as Player


## Convenience: the player's position, or origin when running headless without one.
func player_pos() -> Vector3:
	var p := player()
	return p.global_position if p != null else Vector3.ZERO


func info() -> Dictionary:
	return AreaRegistry.info(area_id)
