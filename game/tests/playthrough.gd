extends Node
## Six-room integration test. It invokes the same public interaction methods as
## the on-screen buttons; no puzzle flags or dossier fields are written here.

var app: Control
var started := 0
var capture_dir := ""
var observed_reports: Dictionary = {}

func check(value: bool, message: String) -> bool:
	if not value:
		push_error("PLAYTHROUGH_FAIL: " + message)
		get_tree().quit(1)
	return value

func capture(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	check(image.save_png(capture_dir.path_join(name + ".png")) == OK, "capture " + name)

func run(main: Control) -> void:
	app = main
	started = Time.get_ticks_msec()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			capture_dir = argument.trim_prefix("--capture-dir=")
			DirAccess.make_dir_recursive_absolute(capture_dir)
	if not validate_scene_data():
		return
	for round_index in range(5):
		if not await complete_case(round_index):
			return
	if not check(observed_reports.size() == 3, "responsibility, exploration and balance reports"):
		return
	print("PLAYTHROUGH_PASS: six scenes completed 5 times; six puzzle types; three bands; evidence chain; fixed ending; reset. Real seconds: %.2f" % ((Time.get_ticks_msec() - started) / 1000.0))
	app.stop_audio_for_test()
	for count in range(6):
		await get_tree().process_frame
	get_tree().quit(0)

func validate_scene_data() -> bool:
	var types: Dictionary = {}
	var all_objects: Dictionary = {}
	var files: PackedStringArray = DirAccess.get_files_at("res://data/scenes")
	for index in range(1, 7):
		var prefix := "scene0%d_" % index
		var matches: Array[String] = []
		for file in files:
			if file.begins_with(prefix) and file.ends_with(".json"):
				matches.append(file)
		if not check(matches.size() == 1, "one JSON for scene %d" % index):
			return false
		var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/scenes/" + str(matches[0])))
		if not check(data is Dictionary and int(data.get("schema_version", 0)) == 1, "scene %d parses" % index):
			return false
		var rect: Array = data.get("content_rect", [])
		if not check(rect.size() == 4 and int(rect[0]) == 40 and int(rect[1]) == 122 and int(rect[2]) == 1200 and int(rect[3]) == 438, "scene %d fixed viewport" % index):
			return false
		for object in data.get("objects", []):
			var id := str(object.get("id", ""))
			if not check(not all_objects.has(id), "unique object " + id):
				return false
			all_objects[id] = true
		for group in data.get("slot_groups", []):
			types[str(group.get("type", ""))] = true
	return check(types.size() == 6 and types.keys().all(func(kind): return kind in ["sequence", "set", "single", "choice", "device", "exclusion"]), "six puzzle types")

func wait_scene(expected: String) -> bool:
	var deadline := Time.get_ticks_msec() + 5000
	while not is_instance_valid(app.current) or GameState.stage != expected:
		await get_tree().process_frame
		if Time.get_ticks_msec() > deadline:
			return check(false, "scene timeout " + expected)
	await get_tree().process_frame
	return true

func start_case() -> bool:
	if not check(GameState.stage == "start", "title initial"):
		return false
	app.current.begin.pressed.emit()
	return await wait_scene("scene01_white_corridor")

func collect(scene: Control, ids: Array[String]) -> void:
	for id in ids:
		scene.interact_object_by_id(id)

func place(scene: Control, group_id: String, ids: Array[String]) -> void:
	for id in ids:
		scene.select_item(id)
		scene.activate_group(group_id)

func complete_case(round_index: int) -> bool:
	if not await start_case():
		return false
	var scene = app.current
	if round_index % 3 == 0:
		scene.interact_object_by_id("O01")
	elif round_index % 3 == 1:
		scene.interact_object_by_id("O04")
	else:
		scene.interact_object_by_id("O03")
	if round_index == 0:
		await capture("01_white_corridor")
	collect(scene, ["O04", "O05", "O06", "O07"])
	place(scene, "motivation_slots", ["O04", "O05", "O06", "O07"])
	if not check(GameState.has_flag("f01_motivation") and GameState.dossier.get("选择理由") == "空白", "scene 1 motivation"):
		return false
	scene.open_exit("door_A")
	if not await wait_scene("scene02_archive_room"):
		return false
	if round_index == 0:
		await capture("02_archive_room")

	scene = app.current
	collect(scene, ["O21", "O22", "O23", "O24", "O27"])
	place(scene, "timeline", ["O21", "O22", "O23", "O24"])
	place(scene, "projector", ["O27"])
	if not check(GameState.has_flag("scene02_complete") and GameState.evidence.get("F03", false), "scene 2 evidence"):
		return false
	scene.open_exit("exit_corridor")
	if not await wait_scene("scene01_white_corridor"):
		return false
	app.current.open_exit("door_B")
	if not await wait_scene("scene03_studio_room"):
		return false
	if round_index == 0:
		await capture("03_studio_room")

	scene = app.current
	collect(scene, ["O32", "O33", "O34"])
	place(scene, "module_rack", ["O32", "O33", "O34"])
	scene.set_band("fact")
	scene.interact_object_by_id("O34")
	if not check(GameState.has_flag("scene03_complete") and GameState.evidence.get("F01", false), "scene 3 own action"):
		return false
	scene.open_exit("exit_corridor")
	if not await wait_scene("scene01_white_corridor"):
		return false
	app.current.open_exit("door_C")
	if not await wait_scene("scene04_validation_center"):
		return false
	if round_index == 0:
		await capture("04_validation_center")

	scene = app.current
	collect(scene, ["O42", "O43", "O44"])
	place(scene, "sim_linyu", ["O42", "O43", "O44"])
	scene.set_band("emotion")
	scene.interact_object_by_id("O45")
	collect(scene, ["O46"])
	place(scene, "sim_linyu_hidden", ["O46"])
	collect(scene, ["O47", "O49", "O4A", "O48"])
	place(scene, "sim_chenmo", ["O47", "O49", "O4A"])
	scene.set_band("fact")
	scene.interact_object_by_id("O48")
	place(scene, "sim_chenmo_hidden", ["O48"])
	scene.resolve_choice(scene.find_group("stamp"), "翻转印章")
	if not check(GameState.has_flag("scene04_complete") and GameState.evidence.get("B02", false), "scene 4 outcome cannot prove will"):
		return false
	scene.open_exit("exit_corridor")
	if not await wait_scene("scene01_white_corridor"):
		return false
	app.current.open_exit("door_D")
	if not await wait_scene("scene05_brother_room"):
		return false
	if round_index == 0:
		await capture("05_brother_room")

	scene = app.current
	for count in range(3):
		scene.activate_group("desk_lamp")
	collect(scene, ["O56", "O57", "O58", "O59"])
	place(scene, "mirror_track", ["O56", "O57", "O58", "O59"])
	for count in range(3):
		scene.activate_group("response_slots")
	if not check(GameState.has_flag("scene05_complete") and GameState.evidence.get("F02", false), "scene 5 7.4 second silence"):
		return false
	scene.open_exit("exit_corridor")
	if not await wait_scene("scene01_white_corridor"):
		return false
	app.current.open_exit("door_E")
	if not await wait_scene("scene06_surgery_room"):
		return false
	if round_index == 0:
		await capture("06_surgery_room")

	scene = app.current
	for count in range(3):
		scene.activate_group("diagnosis_sim")
	place(scene, "evidence_bed", ["F03", "F01", "B02", "F02"])
	scene.set_band("emotion")
	if not check(scene.object_visible(scene.find_object("O67")), "hidden self-loop visible from prior evidence"):
		return false
	scene.resolve_choice(scene.find_group("diagnostic_ring"), "旋转：允许意愿暂未确定")
	if not check(GameState.has_flag("scene06_complete") and GameState.dossier.get("意愿归属", "").begins_with("UNCONFIRMED"), "scene 6 reclassification"):
		return false
	scene.open_exit("exit_corridor")
	if not await wait_scene("scene01_white_corridor"):
		return false
	if not check(app.current.ending_ready, "changed corridor ending available"):
		return false
	app.current.trigger_ending()
	if not await wait_scene("final_report"):
		return false
	observed_reports[GameState.report_type] = true
	if round_index == 0:
		await capture("07_final_report")
	app.current.reveal_reality()
	if not check(app.current.speech.text.contains("我想先弄清楚自己为什么选择") and not app.current.speech.text.contains("父亲："), "ends before anyone answers for Lin Che"):
		return false
	if not check(GameState.active_ids().size() == 4 and GameState.flags.size() >= 18, "whole-case evidence retained"):
		return false
	print("SIX_SCENE_ROUND_%d_PASS report=%s" % [round_index + 1, GameState.report_type])

	var reset_start := Time.get_ticks_msec()
	app.restart()
	if not await wait_scene("start"):
		return false
	return check(Time.get_ticks_msec() - reset_start < 15000 and GameState.flags.is_empty() and GameState.evidence.is_empty() and GameState.inventory.is_empty() and GameState.placements.is_empty() and GameState.inspected.is_empty(), "reset clears six-room state")
