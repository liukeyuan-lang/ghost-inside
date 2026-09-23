extends "res://scripts/view.gd"
var card_buttons: Dictionary = {}
var input: LineEdit
var submit: Button
var feedback: Label
var counter: Label
var trace_label: Label
var responding := false
var busy := false
var edit_mode := ""
var previous: Dictionary = {}
var previous_text := ""
var gateway: Node

func _ready() -> void:
	gateway = preload("res://scripts/ai_gateway.gd").new()
	add_child(gateway)
	setup("03 / 自我手术 · 认知种子", "事实、感受、边界各选一张。目标不是替他选职业，而是把“错误”改为“尚未确认”。")
	build_cards()

func build_cards() -> void:
	var titles := ["事实 / 发生了什么", "感受 / 他如何经历", "边界 / 他保留什么"]
	var groups := ["facts", "feelings", "boundaries"]
	for column in range(3):
		var group: String = groups[column]
		label_at(titles[column], Vector2(42 + column * 290, 130), Vector2(278, 38), 22, CYAN)
		for i in range(3):
			var card: Dictionary = GameState.data.cards[group][i]
			var pos := Vector2(42 + column * 290, 177 + i * 119)
			var button := button_at("", pos, Vector2(275, 106), choose.bind(group, str(card.id)))
			button.disabled = not GameState.evidence.get(card.id, false)
			card_buttons[card.id] = button
			button.set_meta("normal_style", button.get_theme_stylebox("normal").duplicate())
			label_at(card.id + "  " + card.title, pos + Vector2(12, 10), Vector2(252, 30), 20)
			label_at(card.text if not button.disabled else "灰色证据需要重新共鸣。", pos + Vector2(12, 42), Vector2(252, 60), 18, MUTED)
	label_at("GHOST / 调试轨迹", Vector2(937, 134), Vector2(294, 40), 22, CYAN)
	portrait_at("Ghost", Vector2(965, 165), Vector2(220, 350), Color(0.45, 0.75, 0.82, 0.16), true)
	trace_label = label_at("目标 → 检查选择权\n\n调用工具 → 等待种子\n\n引用证据 → 等待选择\n\n发现冲突 → 尚未评估\n\n最终结果 → 由林澈回应\n\n记忆写入 → 尚未发生", Vector2(940, 190), Vector2(280, 340), 20, MUTED)
	input = LineEdit.new()
	input.position = Vector2(42, 553)
	input.size = Vector2(855, 58)
	input.max_length = 60
	input.placeholder_text = "可选：写一句话（最多 60 字），也可以直接提交三张卡"
	input.text = GameState.free_text
	input.add_theme_font_size_override("font_size", 20)
	ui.add_child(input)
	counter = label_at("%d / 60" % input.text.length(), Vector2(804, 617), Vector2(100, 30), 18, MUTED)
	input.text_changed.connect(func(value): counter.text = "%d / 60" % value.length())
	input.text_submitted.connect(func(_value): submit_seed())
	submit = button_at("交给林澈", Vector2(940, 553), Vector2(288, 58), submit_seed)
	feedback = label_at("每类必须选一张。所有卡片都来自刚才的回忆。", Vector2(42, 659), Vector2(1190, 42), 20, GOLD)
	refresh_selection()
	queue_redraw()

func choose(group: String, id: String) -> void:
	if busy or not GameState.evidence.get(id, false):
		return
	if GameState.submissions == 1:
		if edit_mode != "card":
			return
		var changes := 0
		var candidate := GameState.selected.duplicate()
		candidate[group] = id
		for key in candidate:
			if candidate[key] != previous.get(key):
				changes += 1
		if changes > 1:
			feedback.text = "这次只能更换一张卡。可先恢复原卡，再修改另一类。"
			return
	GameState.selected[group] = id
	refresh_selection()

func refresh_selection() -> void:
	for id in card_buttons:
		var box: StyleBoxFlat = card_buttons[id].get_meta("normal_style").duplicate()
		if id in GameState.selected.values():
			box.border_color = CYAN
			box.bg_color = Color("16454c")
		card_buttons[id].add_theme_stylebox_override("normal", box)
	if is_instance_valid(feedback) and not GameState.selected.is_empty():
		feedback.text = "已选：%s / %s / %s" % [GameState.selected.get("facts", "事实待选"), GameState.selected.get("feelings", "感受待选"), GameState.selected.get("boundaries", "边界待选")]
	if is_instance_valid(submit):
		submit.disabled = GameState.selected.size() != 3 or busy

func evaluate_local() -> Dictionary:
	var kind := "accept"
	if GameState.selected.get("facts") == "F03":
		kind = "revise"
	if GameState.selected.get("facts") == "F01" and GameState.selected.get("boundaries") == "B03":
		kind = "hold"
	for word in ["毁了", "全是控制", "医学都是假的"]:
		if word in GameState.free_text:
			kind = "revise"
	for word in ["马上", "辞职", "断绝关系", "原谅一切"]:
		if word in GameState.free_text:
			kind = "hold"
	return GameState.local_result(kind)

func submit_seed() -> void:
	if busy or responding or GameState.selected.size() != 3 or GameState.submissions >= 2:
		return
	for id in GameState.selected.values():
		if not GameState.evidence.get(id, false):
			return
	busy = true
	GameState.free_text = input.text.left(60)
	previous = GameState.selected.duplicate()
	previous_text = GameState.free_text
	GameState.submissions += 1
	refresh_selection()
	feedback.text = "Ghost 正在检查证据；网络不可用时会自动使用案例回应。"
	trace_label.text = "目标 → 保留林澈的选择权\n\n调用工具 → evaluate_seed\n\n引用证据 → " + "、".join(GameState.active_ids()) + "\n\n发现冲突 → 检查中\n\n最终结果 → 等待回应\n\n记忆写入 → 尚未发生"
	input.editable = false
	var value: Dictionary = await gateway.evaluate(GameState.selected, GameState.free_text, GameState.active_ids(), GameState.online_mode)
	if GameState.submissions == 2 and value.result != "accept":
		value = GameState.local_result("hold")
		value.source = "local"
		value.reason = "submission_limit"
	GameState.offline = value.get("source", "local") != "online"
	GameState.set_agent_result(value)
	busy = false
	show_response()

func show_response() -> void:
	responding = true
	for child in ui.get_children():
		child.queue_free()
	card_buttons.clear()
	var kind: String = GameState.result.result
	label_at("林澈的回应 / " + {"accept": "接受", "revise": "修改", "hold": "暂时保留"}[kind], Vector2(50, 35), Vector2(950, 60), 36)
	label_at("“%s”" % GameState.result.response, Vector2(65, 170), Vector2(770, 165), 30)
	label_at("引用证据：" + ", ".join(GameState.result.evidence_ids), Vector2(65, 355), Vector2(800, 50), 22, CYAN)
	label_at("SELF_INTENT  ERROR  →  UNCONFIRMED / 尚未确认\n职业与父亲的回应仍然未知；不知道也可以被保留。", Vector2(65, 426), Vector2(800, 96), 22, MUTED)
	GameState.trace.assign(["目标 → 保留当事人的决定权", "调用工具 → evaluate_seed", "引用证据 → " + ", ".join(GameState.result.evidence_ids), "发现冲突 → " + ("理解仍不完整" if kind != "accept" else "兴趣与受困感可以并存"), "最终结果 → " + kind, "记忆写入 → " + GameState.result.memory_write])
	if GameState.result.has("ghost_trace"):
		GameState.trace.assign(GameState.result.ghost_trace)
	label_at("GHOST / " + ("本地回应" if GameState.offline else "在线评估"), Vector2(925, 135), Vector2(300, 45), 22, CYAN)
	portrait_at("Ghost", Vector2(968, 170), Vector2(214, 330), Color(0.45, 0.80, 0.88, 0.18), true)
	label_at("\n\n".join(GameState.trace), Vector2(925, 192), Vector2(292, 420), 20, MUTED)
	if kind == "revise" and GameState.submissions == 1:
		button_at("更换一张卡", Vector2(65, 560), Vector2(235, 64), reopen.bind("card"))
		button_at("修改短句", Vector2(320, 560), Vector2(235, 64), reopen.bind("text"))
		button_at("保留林澈的改写", Vector2(575, 560), Vector2(290, 64), finish)
		label_at("最多再提交一次；再次未被接受，将暂时保留。", Vector2(65, 652), Vector2(800, 40), 20, GOLD)
	else:
		button_at("查看改变  →", Vector2(65, 560), Vector2(460, 64), finish).grab_focus()
	button_at("重开 F2", Vector2(1110, 20), Vector2(130, 56), func(): get_parent().restart())
	queue_redraw()

func reopen(mode: String) -> void:
	for child in ui.get_children():
		child.queue_free()
	responding = false
	edit_mode = mode
	build_cards()
	input.editable = mode == "text"
	for button in card_buttons.values():
		button.disabled = mode != "card"
	feedback.text = "仅修改短句，卡片保持原样。" if mode == "text" else "仅更换一张卡，短句保持原样。"

func finish() -> void:
	goto_scene("ending")

func _draw() -> void:
	plate(Rect2(922, 121, 318, 517))
	if responding:
		plate(Rect2(42, 121, 850, 517))
