extends Node3D
## Empirical winding probe: renders one face of each Kit quad winding from the
## side its normal points to. A face that is drawn correctly shows as a coloured
## square; a back-facing one is culled (invisible). Run via tools/winding_probe.sh.

var _frame := 0


func _ready() -> void:
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.0, -6.0)
	cam.rotation_degrees = Vector3(0, 180, 0)   # look toward +Z
	add_child(cam)
	cam.current = true
	# a "nz" face at z=0 (normal -Z, facing the camera) from box_quads, red
	_show(Kit.box_quads(Vector3(-2.5, 1, 0), Vector3(2, 2, 0.01), 1.0, ["nz"]), Color.RED)
	# the same face with reversed winding, green
	var q: Array = Kit.box_quads(Vector3(0, 1, 0), Vector3(2, 2, 0.01), 1.0, ["nz"])[0]
	_show([[q[0], q[3], q[2], q[1], q[4], q[7], q[6], q[5], q[8]]], Color.GREEN)
	# a "py" (top) face seen from above-ish: camera is at y=1 so tilt it: place at y=0.2, blue
	_show(Kit.box_quads(Vector3(2.5, 0.2, 0), Vector3(2, 0.01, 2), 1.0, ["py"]), Color.BLUE)
	var l := DirectionalLight3D.new()
	add_child(l)


func _show(quads: Array, col: Color) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = Kit.mesh_from_quads(quads)
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m
	add_child(mi)


func _process(_d: float) -> void:
	_frame += 1
	if _frame == 12:
		get_viewport().get_texture().get_image().save_png("res://screenshots/winding_probe.png")
		print("[probe] saved")
		get_tree().quit()
