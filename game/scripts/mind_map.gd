extends "res://scripts/view.gd"
var player := Vector2(190, 460)
var points := [Vector2(285, 330), Vector2(565, 330), Vector2(845, 330), Vector2(1110, 452)]
var hint: Label
var story: Label
var frequency_label: Label
var dossier: Label
var buttons: Array[Button] = []
var near := -1
var travel_target := Vector2.ZERO
var travelling := false
var frequency := 0
var facing_left := false
var walk_phase := 0.0
var city_back: Texture2D = preload("res://assets/map/city_back.png")
var city_buildings: Texture2D = preload("res://assets/map/city_buildings.png")
var city_front: Texture2D = preload("res://assets/map/city_front.png")
var carpet: Texture2D = preload("res://assets/map/office_carpet.webp")
func _ready() -> void:
	setup("01 / 白色走廊", "切换事实、情绪、期待频段，调查三件物品；关闭循环掌声，开放意愿档案。")
	var frequency_names := ["1 事实频段", "2 情绪频段", "3 期待频段"]
	for i in range(3):
		var frequency_button := button_at(frequency_names[i], Vector2(48 + i * 176, 132), Vector2(160, 38), set_frequency.bind(i))
		frequency_button.add_theme_font_size_override("font_size", 17)
	for i in range(4):
		var caption: String = ["家庭合照 / 履历", "成绩单 / 录取档案", "掌声 / 意愿终端", "回忆入口"][i]
		buttons.append(button_at(caption, points[i] + Vector2(-98, -91), Vector2(196, 52), walk_to.bind(i)))
		buttons[-1].add_theme_font_size_override("font_size", 17)
		buttons[-1].focus_mode = Control.FOCUS_NONE
	frequency_label = label_at("", Vector2(590, 133), Vector2(620, 36), 17, CYAN)
	dossier = label_at("意愿档案：SELF_INTENT / ERROR", Vector2(915, 178), Vector2(300, 30), 17, RED)
	story = label_at("林澈：这里保存了我所有正确答案，却没有保存我为什么选它。", Vector2(70, 579), Vector2(1130, 66), 23)
	if GameState.interruptions >= 3:
		story.text = "同步中断，回忆从头开始。已发现证据变为灰色轮廓；再次共鸣才能恢复。"
	hint = label_at("WASD / 方向键移动；靠近物品后按 E / Enter。数字 1 / 2 / 3 切换记忆频段。", Vector2(70, 655), Vector2(1150, 42), 19, CYAN)
	set_frequency(0)
	refresh()
func entrance_open() -> bool:
	return GameState.applause_off and "O01" in GameState.inspected and "O02" in GameState.inspected
func walk_to(index: int) -> void:
	travel_target = points[index] + Vector2(0, 52)
	travelling = true
func _physics_process(delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if direction != Vector2.ZERO:
		travelling = false
	if travelling:
		direction = player.direction_to(travel_target)
		if player.distance_to(travel_target) < 6:
			travelling = false
			direction = Vector2.ZERO
	if direction.x != 0:
		facing_left = direction.x < 0
	if direction != Vector2.ZERO:
		walk_phase += delta * 10.0
	player += direction * 270 * delta
	player = player.clamp(Vector2(100, 340), Vector2(1180, 523))
	near = -1
	for i in range(4):
		if player.distance_to(points[i]) < 112:
			near = i
	if near >= 0:
		hint.text = "E / Enter  ·  " + ["调查家庭合照", "调查成绩单", "关闭掌声" if not GameState.applause_off else "听见呼吸", "进入家庭饭桌" if entrance_open() else "入口尚未开放：调查三件物品并关闭掌声"][near]
	else:
		hint.text = "WASD / 方向键移动  ·  E / Enter 互动  ·  点击物品名称可自动走近"
	queue_redraw()
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and near >= 0:
		interact(near)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_1, KEY_2, KEY_3]:
			set_frequency(int(event.keycode - KEY_1))

func set_frequency(index: int) -> void:
	frequency = clampi(index, 0, 2)
	var descriptions := [
		"事实：记录谁做了什么，边缘清晰，暂不解释动机。",
		"情绪：暖色裂纹显示爱、恐惧、感谢与窒息可以并存。",
		"期待：白色标签覆盖人物，正确答案把轮廓拉直。"
	]
	if is_instance_valid(frequency_label):
		frequency_label.text = descriptions[frequency]
	queue_redraw()
func interact(index: int) -> void:
	get_parent().sound("interact")
	if index == 3:
		if entrance_open():
			goto_scene("memory_dinner")
		return
	var obj: Dictionary = GameState.data.map_objects[index]
	if obj.id not in GameState.inspected:
		GameState.inspected.append(obj.id)
	if index == 2:
		GameState.applause_off = true
	var raw_layer_texts: Variant = obj.get("frequency_text", [])
	var layer_texts: Array = raw_layer_texts if raw_layer_texts is Array else []
	var layer_text: String = str(layer_texts[frequency]) if layer_texts.size() > frequency else str(obj.get("inspect_text", ""))
	story.text = obj.name + "：" + layer_text
	if entrance_open():
		story.text += "\n掌声停止。意愿档案仍报错，回忆入口已经开放。保护机制退到一旁。"
	refresh()
func refresh() -> void:
	for i in range(3):
		buttons[i].text = ("✓ " if "O0%d" % (i + 1) in GameState.inspected else "") + ["家庭合照 / 履历", "成绩单 / 录取", "掌声已关闭" if GameState.applause_off else "掌声 / 意愿"][i]
	buttons[3].text = "进入回忆" if entrance_open() else "未开放"
	if is_instance_valid(dossier):
		dossier.text = "意愿档案：SELF_INTENT / " + ("UNREAD" if not entrance_open() else "ERROR")
	queue_redraw()
func _draw() -> void:
	var frequency_tints := [Color(0.66, 0.82, 0.86, 0.82), Color(0.55, 0.28, 0.30, 0.82), Color(0.78, 0.83, 0.88, 0.86)]
	plate(Rect2(40, 122, 1200, 437), Color("0c1b27"))
	# The supplied city layers become the distant world behind the diagnostic glass.
	draw_texture_rect(city_back, Rect2(42, 123, 1196, 136), true, Color(0.35, 0.60, 0.76, 0.48))
	draw_texture_rect(city_buildings, Rect2(42, 123, 1196, 136), true, Color(0.43, 0.78, 0.86, 0.40))
	draw_texture_rect(city_front, Rect2(42, 123, 1196, 136), true, Color(0.22, 0.38, 0.48, 0.62))
	draw_rect(Rect2(56, 174, 1168, 174), Color("d9e2df").lerp(frequency_tints[frequency], 0.3))
	for x in [75, 250, 425, 600, 775, 950]:
		draw_rect(Rect2(x, 184, 132, 148), Color("142a37"))
		draw_rect(Rect2(x, 184, 132, 148), CYAN.darkened(0.35), false, 2)
	# Office pack texture is used as the corridor floor surface.
	draw_texture_rect(carpet, Rect2(56, 350, 1168, 194), true, Color(0.24, 0.48, 0.56, 0.68))
	for y in range(366, 545, 44):
		draw_line(Vector2(56, y), Vector2(1224, y), Color(0.25, 0.55, 0.60, 0.27), 1)
	draw_line(Vector2(56, 350), Vector2(1224, 350), CYAN, 3)
	chapter_chip("A", "成长档案", Vector2(61, 181), frequency == 2)
	chapter_chip("B", "封存工作室", Vector2(238, 181), frequency == 0)
	chapter_chip("C", "未来验证", Vector2(415, 181), false)
	chapter_chip("D", "林远房间", Vector2(592, 181), frequency == 1)
	chapter_chip("E", "自我手术", Vector2(769, 181), entrance_open())
	for i in range(3):
		plate(Rect2(points[i] - Vector2(63, 18), Vector2(126, 56)), PAPER.darkened(0.25))
		if i == 0:
			for x in [-30, 0, 30]:
				person(points[i] + Vector2(x, 12), INK, 0.4)
		elif i == 1:
			for y in [0, 12, 24]:
				draw_line(points[i] + Vector2(-45, y), points[i] + Vector2(45, y), INK, 5)
		else:
			draw_rect(Rect2(points[i] - Vector2(48, 7), Vector2(96, 32)), INK)
			draw_circle(points[i] + Vector2(25, 10), 9, CYAN if GameState.applause_off else RED)
	draw_rect(Rect2(1050, 380, 100, 150), CYAN.darkened(0.7) if entrance_open() else INK)
	draw_rect(Rect2(1050, 380, 100, 150), CYAN if entrance_open() else MUTED, false, 3)
	draw_actor("defense_construct", Vector2(995, 366), 142, Color(0.55, 0.72, 0.78, 0.72) if GameState.applause_off else Color(0.95, 0.55, 0.60, 0.82))
	var bob := sin(walk_phase) * 3.0 if travelling or Input.get_vector("move_left", "move_right", "move_up", "move_down") != Vector2.ZERO else 0.0
	draw_actor("therapist", player + Vector2(0, 24), 94, Color(0.82, 0.96, 1.0), facing_left, bob)
	draw_arc(player, 28, 0, TAU, 20, CYAN, 2)
	plate(Rect2(40, 566, 1200, 78))
