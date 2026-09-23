extends "res://scripts/view.gd"

const AGE_NAMES := ["7 岁", "15 岁", "18 岁", "22 岁"]
const STATIONS := [170.0, 340.0, 510.0, 680.0, 850.0, 1005.0, 1140.0]
var player := Vector2(170, 510)
var walk_target := -1
var observer := false
var vision := false
var completed := 0
var phase := 0
var stride := 0.0
var face_left := false
var background: Texture2D
var objective: Label
var status: Label
var ghost: Label
var hint: Label
var view_state: Label
var station_buttons: Array[Button] = []

func _ready() -> void:
	setup("01 / 白色走廊", "恢复被正确答案覆盖的人生节点；不替林澈填写志愿。")
	if ResourceLoader.exists("res://assets/scenes/white_corridor_bg.png"):
		background = load("res://assets/scenes/white_corridor_bg.png")
	objective = label_at("", Vector2(54, 132), Vector2(780, 40), 25, CYAN)
	status = label_at("", Vector2(54, 173), Vector2(1040, 46), 20, PAPER)
	view_state = label_at("", Vector2(1005, 135), Vector2(240, 38), 19, CYAN)
	for i in range(STATIONS.size()):
		var names := ["登陆终端", "7 岁节点", "15 岁节点", "18 岁节点", "22 岁节点", "侧门", "档案室出口"]
		var b := button_at(names[i], Vector2(STATIONS[i] - 65, 366), Vector2(130, 43), click_station.bind(i))
		b.add_theme_font_size_override("font_size", 17)
		b.focus_mode = Control.FOCUS_NONE
		station_buttons.append(b)
	ghost = label_at("Ghost：你不是来替林澈判断答案，而是把被覆盖的选择重新放回可见处。", Vector2(70, 573), Vector2(1130, 67), 23, PAPER)
	hint = label_at("", Vector2(70, 654), Vector2(1130, 37), 18, CYAN)
	refresh()

func _physics_process(delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if direction != Vector2.ZERO:
		walk_target = -1
	if walk_target >= 0:
		var target := Vector2(STATIONS[walk_target], 510)
		if player.distance_to(target) <= 8:
			var target_index := walk_target
			walk_target = -1
			player = target
			interact(target_index)
		else:
			direction = player.direction_to(target)
	if direction.x != 0:
		face_left = direction.x < 0
	if direction != Vector2.ZERO:
		stride += delta * 11
	player += direction * delta * 280
	player = player.clamp(Vector2(80, 465), Vector2(1195, 535))
	var near := nearest_station()
	hint.text = "WASD / 方向键移动 · E / Enter 调查「%s」· 按住 Q 意识视野 · 点击物件可走近" % station_buttons[near].text if near >= 0 else "WASD / 方向键移动 · E / Enter 调查 · 按住 Q 意识视野 · 点击物件可走近"
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("vision"):
		vision = true
		refresh()
	elif event.is_action_released("vision"):
		vision = false
		refresh()
	elif event.is_action_pressed("interact"):
		var near := nearest_station()
		if near >= 0:
			interact(near)
			get_viewport().set_input_as_handled()

func nearest_station() -> int:
	var best := -1
	var distance := 82.0
	for i in range(STATIONS.size()):
		var d := absf(player.x - STATIONS[i])
		if d < distance:
			best = i
			distance = d
	return best

func click_station(index: int) -> void:
	if absf(player.x - STATIONS[index]) < 75:
		interact(index)
	else:
		walk_target = index

func interact(index: int) -> void:
	get_parent().sound("interact")
	if index == 0:
		if not observer:
			observer = true
			GameState.case_flags["observer"] = true
			ghost.text = "Ghost：意识观测器已接入。按住 Q，寻找 7 岁节点中被成绩遮住的蓝色碎片。"
		else:
			ghost.text = "Ghost：观测器运行中。当前节点：%s。" % current_name()
	elif not observer:
		ghost.text = "系统：请先在登陆椅旁启动意识观测器。"
	elif index == 5:
		ghost.text = "MEMORY DELETED：权限不足，无法进入。这里的缺口仍被保留。" if completed >= 3 else "侧门尚未显现。"
	elif index == 6:
		if completed == 4:
			GameState.case_flags["scene01_complete"] = true
			GameState.will_dossier["选择结果"] = "医学"
			GameState.will_dossier["选择理由"] = "空白"
			GameState.will_dossier["18岁意愿"] = "无法确认意愿"
			GameState.will_dossier["22岁意愿"] = "无法确认意愿"
			goto_scene("archive_room")
		else:
			ghost.text = "系统：四个节点恢复后，成长档案室才会开放。当前 %d / 4。" % completed
	elif index != completed + 1:
		ghost.text = "Ghost：请先完成 %s；时间顺序本身也是证据。" % current_name() if index > completed + 1 else "Ghost：这个节点已恢复，原始线索仍可追溯。"
	else:
		match completed:
			0: do_seven()
			1: do_fifteen()
			2: do_eighteen()
			3: do_twentytwo()
	refresh()

func do_seven() -> void:
	if phase == 0:
		if not vision:
			ghost.text = "Ghost：普通视野只看得见成绩。按住 Q，再调查 7 岁节点。"
			return
		phase = 1
		ghost.text = "Ghost：蓝色碎片出现了。它记录的是‘我想把它做完’，不是一个职业名称。"
	elif phase == 1:
		phase = 2
		ghost.text = "Ghost：碎片已收取。再次调查，把它插入 7 岁节点。"
	else:
		complete_node("7 岁：蓝色意愿碎片已保存，尚不为它命名。")

func do_fifteen() -> void:
	if phase == 0:
		phase = 1
		ghost.text = "Ghost：录取通知书下面还压着一张纸。先移开这份‘更正确的故事’。"
	elif phase == 1:
		phase = 2
		ghost.text = "Ghost：发现游戏比赛报名表。它和持续的投入可以拼合，但不能直接等同于职业志愿。"
	else:
		complete_node("15 岁：报名表与投入感构成未命名的意愿片段。")

func do_eighteen() -> void:
	if phase == 0:
		phase = 1
		ghost.text = "系统：外部期待写入失败。\nGhost：失败不能跳过。请追踪这块碎片的来源。"
	elif phase == 1:
		phase = 2
		ghost.text = "Ghost：来源是奖状、亲友的安心和掌声。它们会影响林澈，却不能替他确认意愿。"
	else:
		complete_node("18 岁：已确认意愿 → 无法确认意愿。MEMORY DELETED 侧门显现，但权限不足。")

func do_twentytwo() -> void:
	if phase == 0:
		phase = 1
		ghost.text = "Ghost：‘成为优秀医生’这句话没有记忆纹理，是系统伪造的总结。"
	elif phase == 1:
		phase = 2
		ghost.text = "Ghost：伪造碎片已拔除。现在不要填入另一个好听的答案。"
	else:
		complete_node("22 岁：已确认意愿 → 无法确认意愿。伪造结论不再冒充当事人的声音。")

func complete_node(message: String) -> void:
	GameState.case_flags["scene01_age_%d" % [7, 15, 18, 22][completed]] = true
	completed += 1
	phase = 0
	ghost.text = "Ghost：" + message
	get_parent().sound("evidence")
	if completed == 4:
		ghost.text += "\n四段节点已恢复。成长档案室出口开放；选择理由仍然空白。"

func current_name() -> String:
	return AGE_NAMES[mini(completed, 3)]

func phase_description() -> String:
	if not observer:
		return "启动登陆椅旁的终端，取得意识观测器"
	if completed == 4:
		return "前往成长档案室出口"
	match completed:
		0: return ["按住 Q 寻找 7 岁蓝色碎片", "收取蓝色意愿碎片", "插入 7 岁节点"][phase]
		1: return ["移开录取通知书", "发现比赛报名表", "拼合未命名的投入感"][phase]
		2: return ["尝试写入外部期待", "追踪失败碎片的来源", "改为无法确认意愿"][phase]
		3: return ["识别伪造职业结论", "拔除伪造碎片", "改为无法确认意愿"][phase]
	return ""

func refresh() -> void:
	objective.text = "恢复人生节点  %d / 4" % completed
	status.text = "当前目标：" + phase_description()
	view_state.text = "◈ 意识视野 / Q" if vision else "普通视野 · 按住 Q"
	view_state.add_theme_color_override("font_color", CYAN if vision else MUTED)
	for i in range(1, 5):
		station_buttons[i].text = "%s %s" % ["✓" if i <= completed else "◇", AGE_NAMES[i - 1]]
	station_buttons[5].text = "MEMORY DELETED" if completed >= 3 else "侧门"
	station_buttons[6].text = "成长档案室 →" if completed == 4 else "出口锁定"
	queue_redraw()

func _draw() -> void:
	if background:
		draw_texture_rect(background, Rect2(0, 0, 1280, 720), false)
		draw_rect(Rect2(0, 0, 1280, 225), Color("07121d", 0.88))
	else:
		draw_rect(Rect2(40, 122, 1200, 438), Color("b8d0cf"))
		draw_colored_polygon(PackedVector2Array([Vector2(40, 290), Vector2(1240, 290), Vector2(1240, 560), Vector2(40, 560)]), Color("759b9d"))
		for i in range(7):
			draw_rect(Rect2(STATIONS[i] - 63, 245, 126, 115), Color("183945", 0.74))
	for i in range(7):
		var x: float = STATIONS[i]
		var color := CYAN if i > 0 and i <= completed else (GOLD if i == completed + 1 and observer else MUTED)
		if i == 0:
			color = CYAN if observer else GOLD
		elif i == 5:
			color = RED if completed >= 3 else MUTED
		elif i == 6:
			color = CYAN if completed == 4 else MUTED
		draw_rect(Rect2(x - 57, 275, 114, 88), Color("081b25", 0.73))
		draw_rect(Rect2(x - 57, 275, 114, 88), color, false, 2)
		draw_string(get_theme_default_font(), Vector2(x - 45, 313), ["LOGIN", "07", "15", "18", "22", "LOCK", "EXIT"][i], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, color)
		if i == 1 and observer and completed == 0 and vision:
			draw_circle(Vector2(x, 248), 13, Color("3d9dff"))
			draw_arc(Vector2(x, 248), 21, 0, TAU, 24, Color("b3eaff"), 2)
	if vision:
		draw_rect(Rect2(40, 122, 1200, 438), Color(0.2, 0.72, 0.9, 0.12))
	draw_actor("心灵调理师", player, 138, Color.WHITE, face_left, sin(stride) * 3)
	draw_rect(Rect2(40, 561, 1200, 86), Color("0d1a27", 0.96))
	draw_rect(Rect2(40, 561, 1200, 86), CYAN.darkened(0.6), false, 2)
