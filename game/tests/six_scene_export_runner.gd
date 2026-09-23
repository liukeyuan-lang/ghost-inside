extends Node

func start(game: Node) -> void:
	call_deferred("run_all", game)

func run_all(game: Node) -> void:
	var state: Node = get_tree().root.get_node("GameState")
	for run_index in range(5):
		if run_index > 0:
			game.call("restart")
		if state.get("stage") != "start" or not state.get("case_flags").is_empty() or not state.get("will_dossier").is_empty():
			fail_test("Case did not reset before run %d" % run_index)
			return
		var room: Node = game.get("current")
		room.call("begin_case")
		await get_tree().process_frame
		room = game.get("current")
		if state.get("stage") != "white_corridor":
			fail_test("Start did not enter corridor")
			return
		if room.get("background") == null:
			fail_test("Corridor map art missing in export")
			return
		room.call("set_player_for_test", room.get("BASES")[0])
		room.call("interact", 0)
		room.call("set_player_for_test", room.get("BASES")[1])
		room.call("interact", 1)
		if room.get("phase") != 0:
			fail_test("Q gate failed")
			return
		room.set("vision", true)
		for station in [1, 2, 3, 4]:
			room.call("set_player_for_test", room.get("BASES")[station])
			for phase_index in range(3):
				room.call("interact", station)
		room.call("set_player_for_test", room.get("BASES")[6])
		room.call("interact", 6)
		await get_tree().process_frame
		room = game.get("current")
		if state.get("stage") != "archive_room":
			fail_test("Corridor did not enter archive")
			return
		if room.get("background") == null:
			fail_test("Archive map art missing in export")
			return
		room.call("_choose_photo", "林澈填写医学志愿")
		if state.get("case_flags").get("scene02_photo_count", 0) != 0:
			fail_test("Wrong photo order advanced")
			return
		for name in ["父亲参加乐队", "父亲收起吉他", "林澈参加游戏比赛", "林澈填写医学志愿"]:
			room.call("_choose_photo", name)
		for index in range(3):
			room.call("_take_anchor", index)
		room.call("_choose_dialogue", true)
		room.call("_choose_dialogue", true)
		for name in ["放弃梦想", "恐惧风险", "保护与限制", "推迟选择", "无法确认意愿"]:
			room.call("_choose_cause", name)
		room.call("_choose_judgment", false)
		if state.get("case_flags").get("scene02_permission", false):
			fail_test("Wrong judgment granted permission")
			return
		room.call("_choose_judgment", true)
		room.call("_seal_false_conclusion")
		room.call("_show_terminal")
		if not press_button(room.get("modal_content"), "进入废弃游戏工作室"):
			fail_test("Archive onward button missing")
			return
		await get_tree().process_frame
		room = game.get("current")
		if state.get("stage") != "studio_room":
			fail_test("Archive did not enter studio")
			return
		room.call("inspect_sketch")
		for index in range(3):
			room.call("insert_module", index)
		room.call("undo_override")
		room.call("read_log")
		room.call("finish_room")
		await get_tree().process_frame
		room = game.get("current")
		if state.get("stage") != "validation_center":
			fail_test("Studio did not enter validation")
			return
		room.call("inspect_linyu_public")
		room.call("set_frequency", 1)
		room.call("find_drawer")
		room.call("inspect_linyu_hidden")
		room.call("inspect_chenmo_public")
		room.call("set_frequency", 0)
		room.call("inspect_chenmo_back")
		room.call("inspect_chenmo_hidden")
		room.call("stamp", "reverse")
		room.call("finish_room")
		await get_tree().process_frame
		room = game.get("current")
		if state.get("stage") != "brother_room":
			fail_test("Validation did not enter brother room")
			return
		room.call("inspect_diary")
		room.call("inspect_card")
		for index in range(3):
			room.call("turn_lamp")
		for name in ["奖状", "兄弟合照", "医学院宣传册", "毕业照"]:
			room.call("place_mirror", name)
		room.call("set_frequency", 1)
		for name in ["医学挺好的", "你应该选自己喜欢的", "不要学我"]:
			room.call("remove_voice", name)
		room.call("confirm_silence")
		room.call("finish_room")
		await get_tree().process_frame
		room = game.get("current")
		if state.get("stage") != "surgery_room":
			fail_test("Brother room did not enter surgery")
			return
		for index in range(3):
			room.call("run_simulation", index)
			room.call("run_simulation", index)
		for index in range(4):
			room.call("load_evidence", index)
		room.call("set_frequency", 1)
		room.call("inspect_loop")
		room.call("rotate_ring")
		room.call("finish_room")
		await get_tree().process_frame
		room = game.get("current")
		if state.get("stage") != "finale" or state.get("will_dossier").get("意愿归属", "") != "UNCONFIRMED":
			fail_test("Surgery did not enter honest finale")
			return
		room.call("advance")
		room.call("advance")
		if room.get("page") != 2:
			fail_test("Final dialogue did not reach cut before father reply")
			return
		print("SIX_SCENE_RUN_PASS %d" % (run_index + 1))
	game.call("stop_audio_for_test")
	game.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("SIX_SCENE_FIVE_RUNS_PASS")
	get_tree().quit()

func press_button(node: Node, caption: String) -> bool:
	for child in node.get_children():
		if child is Button and child.text == caption:
			child.pressed.emit()
			return true
	return false

func fail_test(reason: String) -> void:
	push_error(reason)
	get_tree().quit(1)
