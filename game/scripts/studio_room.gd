extends "res://scripts/view.gd"

# Shared stage and controls for the four later investigation rooms. Each room
# owns its puzzle rules; this script only draws the space and handles controls.
var room_kind := "studio"
var room_title := ""
var frequency := 0
var player := Vector2(850, 494)
var face_left := false
var walk_phase := 0.0
var response: Label
var progress: Label
var band_label: Label
var actions: Array[Button] = []
var active_action := 0

func _ready() -> void:
	room_kind = "studio"
	open_room("03 / 废弃游戏工作室", "谁封存了 Dream_Project？按 WORLD → CHARACTER → ENDING 恢复项目。")
	if not has_flag("scene02_complete"):
		say("成长档案室的结论尚未写入意愿档案。请先完成上一间房。")
		make_action("返回成长档案室", 0, 0, func(): goto_scene("archive_room"))
		return
	make_action("查看小星球设计稿", 0, 0, inspect_sketch)
	make_action("插入 WORLD 模块", 0, 1, func(): insert_module(0))
	make_action("插入 CHARACTER 模块", 0, 2, func(): insert_module(1))
	make_action("插入 ENDING 模块", 0, 3, func(): insert_module(2))
	make_action("撤销 Medical_Application 覆盖", 0, 4, undo_override)
	make_action("查看最后项目日志", 0, 5, read_log)
	make_action("前往未来验证中心  →", 1, 5, finish_room)
	say("父亲的影响已确认，但没有证据表明他替林澈封存了项目。先恢复模块依赖。")
	update_progress()

func open_room(title: String, subtitle: String) -> void:
	room_title = title
	setup(title, subtitle)
	for i in range(3):
		var band_button := button_at(["1 事实", "2 情绪", "3 期待"][i], Vector2(48 + i * 148, 133), Vector2(138, 38), set_frequency.bind(i))
		band_button.add_theme_font_size_override("font_size", 17)
		band_button.focus_mode = Control.FOCUS_NONE
	band_label = label_at("", Vector2(510, 133), Vector2(700, 37), 17, CYAN)
	progress = label_at("", Vector2(60, 551), Vector2(1150, 32), 18, GOLD)
	response = label_at("", Vector2(60, 590), Vector2(1150, 76), 21, PAPER)
	label_at("WASD / 方向键移动 · 点击选项，或 Tab 选中后按 E / Enter · 1/2/3 切频段 · F2 重开", Vector2(60, 677), Vector2(1160, 28), 16, MUTED)
	set_frequency(0)
	queue_redraw()

func make_action(caption: String, column: int, row: int, callback: Callable) -> Button:
	var pos := Vector2(58 + column * 300, 188 + row * 57)
	var button := button_at(caption, pos, Vector2(282, 49), callback)
	button.add_theme_font_size_override("font_size", 16)
	button.focus_entered.connect(func(): active_action = actions.find(button))
	actions.append(button)
	if actions.size() == 1:
		button.grab_focus()
	return button

func say(message: String) -> void:
	if is_instance_valid(response):
		response.text = message
	if get_parent().has_method("sound"):
		get_parent().sound("interact")
	queue_redraw()

func set_frequency(index: int) -> void:
	frequency = clampi(index, 0, 2)
	if is_instance_valid(band_label):
		band_label.text = ["事实层：时间、文件与实际动作", "情绪层：停顿、声音与未说出口的话", "期待层：社会标签与正确人生投影"][frequency]
	queue_redraw()

func has_flag(flag: String) -> bool:
	return bool(GameState.case_flags.get(flag, false))

func write_flag(flag: String) -> void:
	GameState.case_flags[flag] = true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_1, KEY_2, KEY_3]:
			set_frequency(int(event.keycode - KEY_1))
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("interact") and not actions.is_empty():
			var focus: Control = get_viewport().gui_get_focus_owner()
			if focus is Button and actions.has(focus):
				focus.pressed.emit()
			else:
				actions[clampi(active_action, 0, actions.size() - 1)].pressed.emit()
			get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if direction != Vector2.ZERO:
		player += direction * 220.0 * delta
		player = player.clamp(Vector2(695, 386), Vector2(1168, 528))
		if direction.x != 0:
			face_left = direction.x < 0
		walk_phase += delta * 12.0
		queue_redraw()

func _draw() -> void:
	var tint: Color = [Color("244454"), Color("583647"), Color("52616c")][frequency]
	plate(Rect2(40, 122, 1200, 422), Color("0a1824"))
	# Receding planes keep the scene readable while the scene art is being built.
	draw_rect(Rect2(680, 178, 535, 210), tint)
	draw_colored_polygon(PackedVector2Array([Vector2(680, 388), Vector2(1215, 388), Vector2(1240, 544), Vector2(625, 544)]), Color("162a36"))
	for i in range(4):
		var x := 710 + i * 160
		draw_line(Vector2(x, 388), Vector2(640 + i * 190, 544), Color("44616b"), 2)
	draw_line(Vector2(680, 388), Vector2(1215, 388), CYAN.darkened(0.2), 3)
	match room_kind:
		"studio":
			draw_studio()
		"validation":
			draw_validation()
		"brother":
			draw_brother()
		"surgery":
			draw_surgery()
	var bob := sin(walk_phase) * 2.0 if Input.get_vector("move_left", "move_right", "move_up", "move_down") != Vector2.ZERO else 0.0
	draw_actor("心灵调理师", player, 86, Color("c5f5f4"), face_left, bob)
	draw_arc(player + Vector2(0, 2), 29, 0, TAU, 24, CYAN, 2)
	plate(Rect2(40, 546, 1200, 165), Color("101e2b"))

func draw_studio() -> void:
	draw_rect(Rect2(752, 245, 150, 112), Color("0d1825"))
	draw_rect(Rect2(765, 255, 124, 77), Color("183e50"))
	draw_string(get_theme_default_font(), Vector2(773, 288), "Dream_Project", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, CYAN)
	draw_string(get_theme_default_font(), Vector2(780, 312), "WORLD > ? > ?", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, GOLD)
	draw_rect(Rect2(724, 360, 290, 19), Color("423b38"))
	for i in range(3):
		var done := module_index > i
		draw_rect(Rect2(960 + i * 71, 267, 59, 45), CYAN.darkened(0.55) if done else PANEL)
		draw_rect(Rect2(960 + i * 71, 267, 59, 45), CYAN if done else MUTED, false, 2)
		draw_string(get_theme_default_font(), Vector2(968 + i * 71, 296), ["W", "C", "E"][i], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, PAPER)
	draw_actor("沈舟", Vector2(1112, 423), 143, Color(0.56, 0.84, 1.0, 0.54))

func draw_validation() -> void:
	for i in range(2):
		var x := 710 + i * 245
		draw_rect(Rect2(x, 220, 205, 158), Color("172c39") if i == 0 else Color("382c33"))
		draw_rect(Rect2(x, 220, 205, 158), CYAN if i == 0 else GOLD, false, 3)
		draw_string(get_theme_default_font(), Vector2(x + 18, 252), "林宇 / 98" if i == 0 else "陈默 / 12", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, PAPER)
		draw_string(get_theme_default_font(), Vector2(x + 18, 295), "稳定成功" if i == 0 else "自由失败", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, MUTED)
		draw_actor("林宇" if i == 0 else "陈默", Vector2(x + 128, 401), 96, Color(0.8, 0.95, 1.0, 0.64))
	draw_rect(Rect2(884, 433, 105, 32), Color("153f4e"))
	draw_string(get_theme_default_font(), Vector2(897, 456), "结果≠意愿", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, CYAN)

func draw_brother() -> void:
	draw_rect(Rect2(730, 220, 225, 190), Color("122d3b"))
	draw_rect(Rect2(730, 220, 225, 190), CYAN, false, 3)
	for i in range(4):
		draw_rect(Rect2(752 + i * 47, 260, 31, 64), Color("4a7a8b").darkened(i * 0.15))
		draw_line(Vector2(770 + i * 47, 340), Vector2(810 + i * 47, 374), MUTED, 3)
	draw_actor("林澈", Vector2(1004, 401), 133, Color(0.76, 0.87, 1.0, 0.75))
	draw_actor("林远", Vector2(1120, 401), 128, Color(0.88, 0.93, 1.0, 0.78))
	draw_rect(Rect2(1070, 398, 128, 24), Color("42403a"))
	draw_string(get_theme_default_font(), Vector2(788, 246), "记忆镜", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, CYAN)

func draw_surgery() -> void:
	draw_rect(Rect2(843, 324, 230, 66), Color("46616b"))
	draw_rect(Rect2(843, 324, 230, 66), CYAN, false, 3)
	draw_actor("林澈", Vector2(947, 341), 86, Color(0.76, 0.9, 1.0, 0.75))
	for i in range(5):
		var start := Vector2(744 + i * 101, 243)
		draw_line(start, Vector2(958, 330), [CYAN, GOLD, MUTED, Color("dc8ca7"), Color("9b9eee")][i], 3)
		draw_circle(start, 7, [CYAN, GOLD, MUTED, Color("dc8ca7"), Color("9b9eee")][i])
	if frequency == 1 and has_flag("surgery_evidence"):
		draw_arc(Vector2(960, 335), 100, 0, TAU, 32, CYAN, 3)
		draw_string(get_theme_default_font(), Vector2(886, 229), "无法保证正确 → 继续寻找证明", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, PAPER)

var module_index := 0
var saw_sketch := false
var override_removed := false
var log_read := false

func inspect_sketch() -> void:
	saw_sketch = true
	say("设计稿写着模块依赖：WORLD → CHARACTER → ENDING。沈舟：喜欢做游戏，不等于已决定成为游戏制作人。")
	update_progress()

func insert_module(index: int) -> void:
	if not saw_sketch:
		say("先查看设计稿，确认模块依赖。")
		return
	if index != module_index:
		say("模块依赖不满足。设计稿提示：WORLD → CHARACTER → ENDING。已插入的模块没有丢失。")
		return
	module_index += 1
	if module_index == 3:
		say("三枚模块归位，但 ENDING 校验失败。事实层显示它被 Medical_Application 覆盖。")
	else:
		say(["WORLD 已插入。下一枚应依赖这个世界。", "CHARACTER 已插入。最后才是 ENDING。"][index])
	update_progress()
	queue_redraw()

func undo_override() -> void:
	if module_index < 3:
		say("ENDING 尚未装入，不能检查覆盖记录。")
		return
	if frequency != 0:
		say("覆盖动作属于实际文件记录。切到事实层再检查。")
		return
	override_removed = true
	say("已临时撤销覆盖。最后的日志不是父亲强迫执行的：确认键由 Lin Che 按下。")
	update_progress()

func read_log() -> void:
	if not override_removed:
		say("最后日志仍被覆盖。先在事实层撤销 Medical_Application 覆盖。")
		return
	log_read = true
	write_flag("scene03_complete")
	GameState.will_dossier["执行人"] = "林澈"
	GameState.will_dossier["被放弃可能"] = "游戏创作"
	GameState.will_dossier["执行理由"] = "更好的未来"
	say("存储空间不足。林澈输入 Need a better future，亲自确认封存。受他人影响与亲手执行可以同时为真。")
	update_progress()

func finish_room() -> void:
	if not log_read:
		say("还没有确认是谁封存项目。请完成依赖、撤销覆盖并查看最后日志。")
		return
	goto_scene("validation_center")

func update_progress() -> void:
	if is_instance_valid(progress):
		progress.text = "意愿档案 · 外部影响：%s  /  模块：%d/3  /  执行人：%s" % [str(GameState.will_dossier.get("外部影响", "已记录")), module_index, str(GameState.will_dossier.get("执行人", "待确认"))]
