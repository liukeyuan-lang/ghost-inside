extends SceneTree

class Host:
	extends Control
	func sound(_cue: String) -> void:
		pass
	func restart() -> void:
		pass
	func go(_next: String) -> void:
		pass

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var args := OS.get_cmdline_user_args()
	var stage := str(args[0]) if args.size() > 0 else "white_corridor"
	var variant := str(args[1]) if args.size() > 1 else "default"
	var host := Host.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	var room: Control = load("res://scenes/%s.tscn" % stage).instantiate()
	host.add_child(room)
	if variant == "vision" and stage == "white_corridor":
		room.call("interact", 0)
		room.set("vision", true)
		room.call("refresh")
	elif variant == "puzzle" and stage == "archive_room":
		room.call("_open_station", 1)
	for i in range(15):
		await process_frame
	var file := ProjectSettings.globalize_path("res://../artifacts/qa_%s_%s.png" % [stage, variant])
	var code := root.get_texture().get_image().save_png(file)
	print("CAPTURE %s %d" % [file, code])
	quit(0 if code == OK else 1)
