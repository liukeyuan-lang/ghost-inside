extends Node
## Actual scene integration tests. Run with -- --self-test [--fast].
## Does not write gameplay clocks, positions, evidence, or results.
var app: Control
var failed := false
var started := 0
var observed_results: Dictionary = {}
var capture_dir := ""

func capture(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var picture := get_viewport().get_texture().get_image()
	check(picture.save_png(capture_dir.path_join(name + ".png")) == OK, "screenshot saved " + name)

func check(value: bool, message: String) -> bool:
	if not value:
		failed = true
		push_error("PLAYTHROUGH_FAIL: " + message)
		get_tree().quit(1)
	return value

func run(main: Control) -> void:
	app = main
	started = Time.get_ticks_msec()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			capture_dir = argument.trim_prefix("--capture-dir=")
			DirAccess.make_dir_recursive_absolute(capture_dir)
	if "--fast" in OS.get_cmdline_user_args():
		Engine.time_scale = 4.0
	await get_tree().process_frame
	if not check(GameState.load_error.is_empty(), "case data loads"):
		return
	await capture("00_title")
	for round_index in range(5):
		if not await complete_case(round_index):
			return
	if not check(observed_results.size() == 3, "accept, revise, hold all observed"):
		return
	if not await interruption_checks():
		return
	print("PLAYTHROUGH_PASS: 5 complete scene journeys; accept/revise/hold; one resubmit; 60 characters; F2 reset; 3 interruptions and grey evidence recovery. Real seconds: %.1f" % ((Time.get_ticks_msec() - started) / 1000.0))
	app.stop_audio_for_test()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(0)

func action(name: String) -> void:
	Input.action_press(name)
	var press := InputEventKey.new()
	press.keycode = {"interact": KEY_E, "pulse": KEY_SPACE, "restart": KEY_F2}[name]
	press.pressed = true
	Input.parse_input_event(press)
	await get_tree().physics_frame
	Input.action_release(name)
	var release := InputEventKey.new()
	release.keycode = press.keycode
	release.pressed = false
	Input.parse_input_event(release)
	await get_tree().process_frame

func stop_moving() -> void:
	for name in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(name)

func walk(target: Vector2) -> bool:
	var scene = app.current
	var deadline := Time.get_ticks_msec() + 10000
	while is_instance_valid(scene) and app.current == scene:
		var difference: Vector2 = target - scene.player
		stop_moving()
		if difference.length() < 18:
			return true
		if absf(difference.x) > 12:
			Input.action_press("move_right" if difference.x > 0 else "move_left")
		if absf(difference.y) > 12:
			Input.action_press("move_down" if difference.y > 0 else "move_up")
		await get_tree().physics_frame
		if Time.get_ticks_msec() > deadline:
			stop_moving()
			return check(false, "movement timed out at " + str(scene.player) + " towards " + str(target))
	stop_moving()
	return check(false, "unexpected scene change during movement")

func press_button(caption: String) -> bool:
	for child in app.current.ui.get_children():
		if child is Button and child.text == caption and not child.is_queued_for_deletion():
			if not check(not child.disabled, "button enabled: " + caption):
				return false
			child.pressed.emit()
			await get_tree().process_frame
			return true
	return check(false, "missing button: " + caption)

func open_memory() -> bool:
	if not check(GameState.stage == "start", "title is initial stage"):
		return false
	app.current.begin.pressed.emit()
	await get_tree().process_frame
	if not check(GameState.stage == "mind_map", "authorization opens map"):
		return false
	if not check(not app.current.entrance_open(), "memory initially locked"):
		return false
	# Use movement and interaction events rather than writing player coordinates.
	for index in range(4):
		var target: Vector2 = app.current.points[index] + Vector2(0, 52)
		if not await walk(target):
			return false
		await action("interact")
		if index == 2:
			await capture("01_map")
		if index < 3:
			if not check("O0%d" % (index + 1) in GameState.inspected, "object investigated %d" % index):
				return false
	return check(GameState.stage == "memory_dinner" and GameState.applause_off, "applause off then memory entry")

func finish_memory() -> bool:
	var memory_start := Time.get_ticks_msec()
	for part in range(3):
		if not check(GameState.segment == part and GameState.stage == "memory_dinner", "correct memory segment %d" % part):
			return false
		var scene = app.current
		# At y=390 both text lanes are avoided and every resonance target is in range.
		if not await walk(Vector2(scene.targets[part].x, 390)):
			return false
		while scene.elapsed < 4.1:
			await get_tree().physics_frame
		await action("pulse")
		await capture("02_memory_%d" % part)
		var evidence_id: String = scene.segment_data().evidence_id
		if not check(GameState.evidence.get(evidence_id, false), "Space activates " + evidence_id):
			return false
		while GameState.stage == "memory_dinner" and GameState.segment == part:
			await get_tree().physics_frame
			if Time.get_ticks_msec() - memory_start > 90000:
				return check(false, "memory progression timeout")
	if not check(GameState.stage == "seed_lab" and GameState.active_ids().size() == 9, "55 second memory unlocks all cards"):
		return false
	if Engine.time_scale == 1.0:
		if not check(Time.get_ticks_msec() - memory_start >= 54000, "memory duration not bypassed"):
			return false
	return true

func await_response() -> bool:
	var deadline := Time.get_ticks_msec() + 30000
	while not app.current.responding:
		await get_tree().process_frame
		if Time.get_ticks_msec() > deadline:
			return check(false, "seed response timeout")
	await get_tree().process_frame
	var kind: String = GameState.result.get("result", "")
	if not check(kind in ["accept", "revise", "hold"], "response result whitelist"):
		return false
	for evidence_id in GameState.result.get("evidence_ids", []):
		if not check(GameState.evidence.get(evidence_id, false), "response cites active evidence"):
			return false
	return true

func complete_case(index: int) -> bool:
	if not await open_memory() or not await finish_memory():
		return false
	var lab = app.current
	if not check(lab.submit.disabled, "cannot submit without three categories"):
		return false
	var choices := [
		["F02", "E03", "B02"], ["F03", "E01", "B01"],
		["F01", "E02", "B03"], ["F03", "E01", "B02"],
		["F03", "E01", "B01"]
	]
	for id in choices[index]:
		lab.card_buttons[id].pressed.emit()
	if not check(not lab.submit.disabled and GameState.selected.size() == 3, "three categories enable submit"):
		return false
	await capture("03_seed")
	lab.input.text = ["感谢不等于交出决定权", "我想理解这份恐惧", "我还需要一些时间", "我想自己选择", "我保留矛盾"][index]
	if index == 0:
		lab.input.text = "我".repeat(65)
		if not check(lab.input.text.length() == 60, "input enforces 60 characters"):
			return false
	lab.submit.pressed.emit()
	if not await await_response():
		return false
	await capture("03_response_%d" % index)
	var expected: String = ["accept", "revise", "hold", "revise", "revise"][index]
	if not check(GameState.result.result == expected, "round %d initial response %s" % [index + 1, expected]):
		return false
	if index == 3 or index == 4:
		if not await press_button("更换一张卡" if index == 3 else "修改短句"):
			return false
		if index == 3:
			lab.card_buttons["F02"].pressed.emit()
			lab.card_buttons["B03"].pressed.emit()
			if not check(GameState.selected.boundaries == "B02", "revision cannot change a second card"):
				return false
		else:
			if not check(lab.card_buttons["F01"].disabled, "text revision locks cards"):
				return false
			lab.input.text = "我仍然想理解他的恐惧"
		lab.submit.pressed.emit()
		if not await await_response():
			return false
		expected = "accept" if index == 3 else "hold"
		if not check(GameState.submissions == 2 and GameState.result.result == expected, "single revision resolves to " + expected):
			return false
		lab.submit_seed()
		if not check(GameState.submissions == 2, "third submission prohibited"):
			return false
	observed_results[expected] = GameState.result.world_state
	if not check(GameState.trace.size() == 6, "six Ghost trace stages"):
		return false
	if not await press_button("保留林澈的改写" if expected == "revise" else "查看改变  →"):
		return false
	if not check(GameState.stage == "ending", "ending entered"):
		return false
	await capture("04_world_" + expected)
	var label_text := ""
	for child in app.current.ui.get_children():
		if child is Label:
			label_text += child.text
	if not check({"accept": "开始对话", "revise": "带着矛盾前进", "hold": "暂时退出"}[expected] in label_text, "visible exit changes with response"):
		return false
	if not check(GameState.result.response in label_text, "visible case conclusion matches response"):
		return false
	if not await press_button("回到现实  →"):
		return false
	if not check(app.current.reality and GameState.data.ending.line in app.current.speech.text, "Lin Che speaks before father responds"):
		return false
	await get_tree().create_timer(4.0).timeout
	await capture("05_reality")
	var reset_start := Time.get_ticks_msec()
	await action("restart")
	if not check(Time.get_ticks_msec() - reset_start < 15000, "demo restart within 15 seconds") or not check_reset():
		return false
	print("PLAYTHROUGH_ROUND_%d_PASS: %s" % [index + 1, expected])
	return true

func check_reset() -> bool:
	return check(GameState.stage == "start" and GameState.evidence.is_empty() and GameState.inspected.is_empty() and GameState.selected.is_empty() and GameState.result.is_empty() and GameState.trace.is_empty() and GameState.segment == 0 and GameState.sync_nodes == 3 and GameState.submissions == 0 and GameState.interruptions == 0 and GameState.free_text.is_empty() and not GameState.applause_off, "F2 clears all case progress")

func interruption_checks() -> bool:
	if not await open_memory():
		return false
	var scene = app.current
	if not await walk(Vector2(370, 390)):
		return false
	while scene.elapsed < 4.1:
		await get_tree().physics_frame
	await action("pulse")
	# Exercise the real interruption handler; no state is rewritten by the test.
	while GameState.segment == 0:
		await get_tree().physics_frame
	if not await walk(Vector2(640, 390)):
		return false
	while scene.elapsed < 4.1:
		await get_tree().physics_frame
	await action("pulse")
	if not check(GameState.evidence.get("F03", false), "second fragment evidence obtained before interruption"):
		return false
	for count in range(1, 4):
		scene.interrupt_sync()
		await get_tree().process_frame
		if count < 3:
			if not check(GameState.stage == "memory_dinner" and GameState.segment == 1 and GameState.sync_nodes == 3 - count and scene.elapsed < 1.0, "interruption %d resumes current fragment" % count):
				return false
	if not check(GameState.stage == "mind_map" and GameState.evidence.has("F02") and not GameState.evidence.F02 and GameState.active_ids().is_empty(), "third interruption returns with grey evidence"):
		return false
	if not await walk(app.current.points[3] + Vector2(0, 52)):
		return false
	await action("interact")
	scene = app.current
	if not check(GameState.stage == "memory_dinner" and GameState.sync_nodes == 3, "memory can be reentered after third interruption"):
		return false
	if not await walk(Vector2(370, 390)):
		return false
	while scene.elapsed < 4.1:
		await get_tree().physics_frame
	await action("pulse")
	if not check(GameState.evidence.F02 and GameState.active_ids().size() == 3, "resonance restores grey evidence"):
		return false
	await action("restart")
	return check_reset()
