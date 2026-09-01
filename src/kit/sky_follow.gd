extends MeshInstance3D
## Keeps the sky dome centred on the active camera so it never gets closer.

func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		global_position = cam.global_position
