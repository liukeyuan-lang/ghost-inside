extends "res://scripts/view.gd"
var player := Vector2(640, 490)
var targets := [Vector2(370, 420), Vector2(640, 390), Vector2(890, 425)]
var elapsed := 0.0
var integrity := 100.0
var immunity := 2.0
var pulse_age := 10.0
var spawn_timer := 2.2
var projectiles: Array[Dictionary] = []
var shot_index := 0
var status: Label
var dialogue: Label
var target_label: Label
var evidence_label: Label
var notice := ""
var notice_time := 0.0
var leaving := false
var walk_phase := 0.0
var facing_left := false
var star_0: Texture2D = preload("res://assets/ui/starfield/background_0.png")
var star_1: Texture2D = preload("res://assets/ui/starfield/background_1.png")
var star_2: Texture2D = preload("res://assets/ui/starfield/background_2.png")
func _ready() -> void:
	setup("02 / 因果回忆", "三段投影不会被改写。闪避情绪冲击，靠近金色标记，按 Space 固定被忽略的事实。")
	status = label_at("", Vector2(65, 125), Vector2(1150, 42), 22, CYAN)
	dialogue = label_at("", Vector2(105, 177), Vector2(1080, 68), 28)
	target_label = label_at("", Vector2(60, 565), Vector2(1145, 42), 22, GOLD)
	evidence_label = label_at("", Vector2(60, 610), Vector2(920, 90), 20, MUTED)
	button_at("共鸣 Space", Vector2(1030, 627), Vector2(200, 60), pulse)
	update_labels()
func segment_data() -> Dictionary:
	return GameState.data.memory.segments[GameState.segment]
func duration() -> float:
	return float(segment_data().to - segment_data().from)
func _physics_process(delta: float) -> void:
	if leaving:
		return
	elapsed += delta
	immunity = maxf(0.0, immunity - delta)
	pulse_age += delta
	notice_time -= delta
	var movement := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if movement.x != 0:
		facing_left = movement.x < 0
	if movement != Vector2.ZERO:
		walk_phase += delta * 10.0
	player += movement * 295 * delta
	player = player.clamp(Vector2(100, 285), Vector2(1180, 538))
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_timer = 2.6
		if GameState.segment != 1:
			var lane: float = [340.0, 440.0, 515.0][shot_index % 3]
			projectiles.append({"position": Vector2(70, lane), "line": ["必须先保证正确", "成功才能证明选择", "失败就说明不该开始"][shot_index % 3]})
			shot_index += 1
	for shot in projectiles:
		shot.position.x += 230 * delta
		if Rect2(shot.position - Vector2(8, 19), Vector2(170, 42)).has_point(player):
			hit()
	projectiles = projectiles.filter(func(shot): return shot.position.x < 1250)
	if GameState.segment > 0 and not safe_area().has_point(player):
		hit()
	if elapsed >= duration() and GameState.evidence.get(segment_data().evidence_id, false):
		if GameState.segment == 2:
			leaving = true
			goto_scene("seed_lab")
		else:
			GameState.segment += 1
			elapsed = 0
			projectiles.clear()
			immunity = 2.0
			spawn_timer = 2.5
	update_labels()
	queue_redraw()
func safe_area() -> Rect2:
	var margin := minf(elapsed / duration(), 1.0) * 115.0
	return Rect2(100 + margin, 280, 1080 - margin * 2, 265)
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pulse"):
		pulse()
func pulse() -> void:
	if leaving or pulse_age < 1.0:
		return
	pulse_age = 0
	get_parent().sound("pulse")
	if elapsed < 4.0:
		notice = "先听见这段话。金色标记将在对话停顿时亮起。"
		notice_time = 3.0
		return
	if player.distance_to(targets[GameState.segment]) > 130:
		notice = "靠近金色标记，再释放共鸣。"
		notice_time = 3.0
		return
	var bundles := [["F02", "F03", "E02"], ["F01", "E01", "B02"], ["E03", "B01", "B03"]]
	for id in bundles[GameState.segment]:
		GameState.unlock_evidence(id)
	get_parent().sound("evidence")
	integrity = minf(100.0, integrity + 15)
	notice = "证据已激活：" + segment_data().evidence_id + "  ·  " + segment_data().resonance_target
	notice_time = 5.0
	update_labels()
func hit() -> void:
	if immunity > 0 or leaving:
		return
	integrity -= 25
	get_parent().sound("impact")
	immunity = 1.7
	if integrity <= 0:
		interrupt_sync()
func interrupt_sync() -> void:
	GameState.sync_nodes -= 1
	GameState.interruptions += 1
	if GameState.sync_nodes <= 0:
		GameState.blur_evidence()
		leaving = true
		goto_scene("mind_map")
		return
	elapsed = 0
	integrity = 100
	immunity = 3
	projectiles.clear()
	player = Vector2(640, 490)
	notice = "同步中断：从当前片段恢复。观察横向冲击，留在明亮区域。"
	notice_time = 6
func update_labels() -> void:
	var chapter_names := ["成长档案 / 父亲的旧拨片", "封存工作室 / Dream_Project", "林远房间 / 7.4 秒沉默"]
	status.text = "同步节点 %s  ·  完整度 %d%%  ·  %s  ·  %02d / %02d 秒" % ["●".repeat(GameState.sync_nodes) + "○".repeat(3 - GameState.sync_nodes), integrity, chapter_names[GameState.segment], mini(int(elapsed), int(duration())), duration()]
	dialogue.text = "“%s”" % segment_data().line
	target_label.text = notice if notice_time > 0 else ("共鸣目标：" + segment_data().resonance_target + ("  ·  靠近并按 Space" if elapsed >= 4 else "  ·  等待停顿"))
	var evidence_text := ""
	for id in ["F02", "F03", "F01"]:
		evidence_text += "%s %s    " % [id, "已激活" if GameState.evidence.get(id, false) else ("灰色轮廓 · 待共鸣" if GameState.evidence.has(id) else "未发现")]
	evidence_label.text = evidence_text + "\nWASD / 方向键移动  ·  共鸣不会伤害任何人"
func _draw() -> void:
	var backgrounds := [star_0, star_1, star_2]
	draw_texture_rect(backgrounds[GameState.segment], Rect2(40, 120, 1200, 434), true, Color(0.52, 0.64, 0.72, 0.55))
	draw_rect(Rect2(40, 120, 1200, 434), [Color(0.05, 0.10, 0.16, 0.72), Color(0.11, 0.07, 0.13, 0.72), Color(0.08, 0.09, 0.14, 0.70)][GameState.segment])
	for x in [250, 640, 1030]:
		draw_rect(Rect2(x - 122, 230, 244, 298), Color(0.05, 0.09, 0.13, 0.68))
		draw_rect(Rect2(x - 122, 230, 244, 298), Color("496576"), false, 2)
	if GameState.segment == 0:
		draw_actor("林父", Vector2(420, 510), 285, Color(0.83, 0.86, 0.90))
		draw_actor("林澈", Vector2(820, 510), 275, Color(0.70, 0.80, 0.88))
		draw_circle(Vector2(455, 305), 15, AMBER)
		draw_string(get_theme_default_font(), Vector2(475, 312), "旧拨片 / 乐队邀请", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, AMBER)
	elif GameState.segment == 1:
		draw_actor("沈舟", Vector2(390, 510), 270, Color(0.78, 0.90, 0.86))
		draw_actor("林澈", Vector2(820, 510), 280, Color(0.64, 0.72, 0.80))
		draw_rect(Rect2(515, 290, 250, 118), Color("101821"))
		draw_rect(Rect2(515, 290, 250, 118), AMBER, false, 2)
		draw_string(get_theme_default_font(), Vector2(535, 340), "DREAM_PROJECT", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, AMBER)
		draw_string(get_theme_default_font(), Vector2(535, 375), "ARCHIVED BY LIN CHE", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, MUTED)
	else:
		draw_actor("林澈", Vector2(430, 510), 278, Color(0.68, 0.78, 0.86))
		draw_actor("林远", Vector2(830, 510), 250, Color(0.86, 0.89, 0.94))
		draw_string(get_theme_default_font(), Vector2(512, 305), "7.4 SEC / NO SELF VOICE", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, RED)
		draw_string(get_theme_default_font(), Vector2(490, 345), "“你当时怎么知道自己想当医生？”", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, PAPER)
	if GameState.segment > 0:
		var safe := safe_area()
		draw_rect(Rect2(70, 278, safe.position.x - 70, 270), Color(0.8, 0.25, 0.3, 0.4))
		draw_rect(Rect2(safe.end.x, 278, 1210 - safe.end.x, 270), Color(0.8, 0.25, 0.3, 0.4))
		draw_rect(safe, GOLD, false, 3)
	var target: Vector2 = targets[GameState.segment]
	draw_arc(target, 28, 0, TAU, 16, GOLD if elapsed >= 4 else MUTED, 4)
	draw_rect(Rect2(target - Vector2(7, 7), Vector2(14, 14)), GOLD)
	for shot in projectiles:
		if GameState.demo_mode:
			draw_rect(Rect2(shot.position, Vector2(350, 35)), Color(0.9, 0.3, 0.4, 0.16))
		draw_rect(Rect2(shot.position - Vector2(8, 19), Vector2(170, 42)), Color("872f4c"))
		draw_string(get_theme_default_font(), shot.position + Vector2(0, 5), shot.line, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, PAPER)
	var bob := sin(walk_phase) * 3.0 if Input.get_vector("move_left", "move_right", "move_up", "move_down") != Vector2.ZERO else 0.0
	draw_actor("心灵调理师", player + Vector2(0, 22), 92, CYAN if immunity <= 0 else Color("c2ffff"), facing_left, bob)
	draw_arc(player, 27, 0, TAU, 20, CYAN, 2)
	if pulse_age < 0.6:
		draw_arc(player, pulse_age * 215, 0, TAU, 32, CYAN, 4)
