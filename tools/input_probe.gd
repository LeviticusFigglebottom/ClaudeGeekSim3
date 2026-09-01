extends Node
## Diagnostic: do synthetic input events reach _input/_unhandled_input? Run:
##   godot --headless --path . res://tools/input_probe.tscn
var f := 0
func _ready() -> void:
	print("[probe] ready input=", is_processing_input(), " unhandled=", is_processing_unhandled_input(), " display=", DisplayServer.get_name())
func _input(e: InputEvent) -> void:
	print("[probe] _input ", e.get_class())
func _unhandled_input(e: InputEvent) -> void:
	print("[probe] _unhandled_input ", e.get_class())
func _process(_d: float) -> void:
	f += 1
	if f == 3:
		var m := InputEventMouseMotion.new()
		m.relative = Vector2(10, 0)
		m.position = Vector2(100, 100)
		get_viewport().push_input(m)
		var a := InputEventAction.new()
		a.action = "interact"
		a.pressed = true
		get_viewport().push_input(a)
		print("[probe] pushed via viewport")
	if f == 5:
		var k := InputEventKey.new()
		k.keycode = KEY_E
		k.pressed = true
		Input.parse_input_event(k)
		print("[probe] parsed key")
	if f == 8:
		get_tree().quit()
