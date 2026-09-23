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
	if stage == "white_corridor" and variant == "intro_comic":
		await create_timer(0.7).timeout
	elif stage == "white_corridor" and variant == "post_intro":
		room.call("complete_intro_for_test")
		await create_timer(0.5).timeout
	if variant == "vision" and stage == "white_corridor":
		room.call("complete_intro_for_test")
		room.call("interact", 0)
		room.set("vision", true)
		room.call("refresh")
	elif variant == "puzzle" and stage == "archive_room":
		room.call("_open_station", 1)
	elif variant == "evidence15" and stage == "white_corridor":
		room.call("complete_intro_for_test")
		room.call("set_player_for_test", room.get("BASES")[0]); room.call("interact", 0)
		room.call("set_player_for_test", room.get("BASES")[1]); room.set("vision", true); room.call("interact", 1)
		room.evidence_layer._advance(); room.evidence_layer._confirm()
		room.call("set_player_for_test", room.get("BASES")[2]); room.call("interact", 2)
		room.evidence_layer._advance()
	elif variant == "evidence22_choice" and stage == "white_corridor":
		room.call("complete_intro_for_test")
		room.call("set_player_for_test", room.get("BASES")[0]); room.call("interact", 0)
		room.set("vision", true)
		for station in [1, 2]:
			room.call("set_player_for_test", room.get("BASES")[station]); room.call("interact", station)
			room.evidence_layer._advance(); room.evidence_layer._confirm()
		room.call("set_player_for_test", room.get("BASES")[3]); room.call("interact", 3)
		room.evidence_layer._advance(); room.evidence_layer._confirm(); room.call("_on_evidence_choice", "age18_choice", "external")
		room.call("set_player_for_test", room.get("BASES")[4]); room.call("interact", 4)
		room.evidence_layer._advance(); room.evidence_layer._confirm()
	elif variant == "evidence_pick" and stage == "archive_room":
		room.call("inspect_archive_evidence", "旧吉他拨片")
		room.evidence_layer._advance()
	for i in range(15):
		await process_frame
	var file := ProjectSettings.globalize_path("res://../artifacts/qa_%s_%s.png" % [stage, variant])
	var code := root.get_texture().get_image().save_png(file)
	print("CAPTURE %s %d" % [file, code])
	quit(0 if code == OK else 1)
