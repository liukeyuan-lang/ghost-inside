extends "res://scripts/view.gd"

var page := 0
var next_button: Button
var narrative: Label
var report: Label
var therapist: Texture2D = preload("res://assets/characters/心灵调理师.png")

func _ready() -> void:
	setup("案例 001 / 意识报告", "白色走廊不再自动延伸。两条路都没有被命名，第三片区域尚未形成。")
	if not bool(GameState.case_flags.get("scene06_complete", false)):
		label_at("自我手术室尚未完成。", Vector2(86, 215), Vector2(1000, 50), 31, RED)
		button_at("返回自我手术室", Vector2(86, 558), Vector2(360, 60), func(): goto_scene("surgery_room"))
		return
	report = label_at("", Vector2(86, 168), Vector2(560, 312), 23, PAPER)
	narrative = label_at("", Vector2(698, 419), Vector2(495, 170), 22, PAPER)
	next_button = button_at("查看走廊  →", Vector2(86, 570), Vector2(390, 64), advance)
	next_button.grab_focus()
	label_at("E / Enter 继续  ·  F2 在 15 秒内重开", Vector2(88, 663), Vector2(1120, 30), 18, CYAN)
	show_page()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and page < 2:
		advance()
		get_viewport().set_input_as_handled()

func advance() -> void:
	if page < 2:
		page += 1
		show_page()
		queue_redraw()

func show_page() -> void:
	match page:
		0:
			report.text = "原始诊断\n外部影响导致自我意愿异常\n\n修正诊断\n林澈将“保证正确”当作确认意愿的前提\n\n处理结果\n未删除父亲、记忆或任何人格影响\n自我意愿：ERROR → UNCONFIRMED"
			match str(GameState.case_flags.get("report_focus", "fusion")):
				"responsibility":
					narrative.text = "责任视角：外部影响有价值，却不能代替选择归属。\n\nGhost：治疗不能替代选择。"
				"exploration":
					narrative.text = "探索视角：被封存的可能值得恢复，但也不是现成答案。\n\nGhost：治疗不能替代选择。"
				_:
					narrative.text = "融合视角：稳定、自由、责任和喜欢可以同时存在。\n\nGhost：治疗不能替代选择。"
			next_button.text = "查看走廊  →"
		1:
			report.text = "两个出口没有名称。\n左侧有医院的白光。\n右侧有小星球的微光。\n中间还有未形成的空间。"
			narrative.text = "Ghost：请选择目标人物的正确道路。\n\n两个选择按钮逐渐消失。\n\n林澈：我不知道。\n系统没有报错。"
			next_button.text = "听林澈说话  →"
		2:
			report.text = "林澈取下写着自己名字的身份牌。\n\n林澈：但这次，我想先弄清楚自己为什么选择。\n\n他拨通父亲的电话。"
			narrative.text = "林澈：爸，我以前总觉得，只有证明这条路是对的，才能说它是我自己选的。\n\n现在我还不确定。但我想和你认真谈谈。"
			next_button.text = "画面结束 · F2 重开"
			next_button.disabled = true

func _draw() -> void:
	plate(Rect2(40, 122, 1200, 505), Color("0b1822"))
	# The corridor stops at two unlabelled doors. The center remains open.
	draw_rect(Rect2(655, 145, 557, 257), Color("1a3441"))
	for i in range(4):
		draw_line(Vector2(655 + i * 140, 145), Vector2(655 + i * 140, 404), Color("4d6e76"), 2)
	draw_colored_polygon(PackedVector2Array([Vector2(655, 402), Vector2(1212, 402), Vector2(1238, 626), Vector2(592, 626)]), Color("182934"))
	if page >= 1:
		draw_rect(Rect2(714, 236, 121, 167), Color("d7e9ec"))
		draw_rect(Rect2(714, 236, 121, 167), CYAN, false, 4)
		draw_rect(Rect2(1023, 236, 121, 167), Color("24364a"))
		draw_rect(Rect2(1023, 236, 121, 167), GOLD, false, 4)
		draw_circle(Vector2(1081, 323), 24, Color("77b9c0"))
		draw_circle(Vector2(1081, 323), 7, GOLD)
		draw_rect(Rect2(849, 275, 154, 128), Color("51636d") if page == 2 else Color("243944"))
		for x in range(868, 992, 22):
			draw_line(Vector2(x, 401), Vector2(x + 14, 349), Color("678d91"), 2)
	if page == 2:
		draw_actor("林澈", Vector2(917, 480), 166, Color("d6e4ec"))
		draw_rect(Rect2(910, 332, 22, 11), PAPER)
	else:
		draw_texture_rect(therapist, Rect2(891, 381, 59, 98), false, Color("a0d9df"))
	draw_line(Vector2(655, 404), Vector2(1212, 404), CYAN, 2)
