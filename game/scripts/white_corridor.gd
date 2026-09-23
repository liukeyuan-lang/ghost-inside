extends "res://scripts/view.gd"

## World objects sort at their feet/base.  Tall artwork is drawn above the base,
## so it never uses a sprite centre to decide who covers whom.
const AGE_NAMES := ["7 岁", "15 岁", "18 岁", "22 岁"]
const BASES := [Vector2(170, 510), Vector2(342, 470), Vector2(514, 405), Vector2(686, 495), Vector2(858, 370), Vector2(1018, 462), Vector2(1140, 528)]
const INTERACT_RADIUS := 78.0
const PLAY_BOUNDS := Rect2(82, 332, 1118, 214)

class DepthObject extends Node2D:
	var kind := "station"
	var caption := ""
	var accent := Color.WHITE
	var done := false
	var sprite: Texture2D
	func _draw() -> void:
		if kind == "player":
			draw_flat_ellipse(Vector2(0, 4), Vector2(25, 8), Color(0.01, 0.04, 0.07, 0.45))
			if sprite:
				var ratio := float(sprite.get_width()) / maxf(float(sprite.get_height()), 1.0)
				draw_texture_rect(sprite, Rect2(-62.0 * ratio, -124, 124.0 * ratio, 124), false)
			return
		if kind == "terminal":
			draw_flat_ellipse(Vector2(0, 3), Vector2(48, 10), Color(0.02, 0.08, 0.12, 0.45))
			draw_rect(Rect2(-48, -22, 36, 22), Color("526c73"))
			draw_rect(Rect2(-41, -70, 26, 48), Color("829ca0"))
			draw_rect(Rect2(12, -103, 38, 101), Color("172e38"))
			draw_rect(Rect2(17, -96, 28, 43), accent.darkened(0.35))
			draw_rect(Rect2(17, -96, 28, 43), accent, false, 2)
		elif kind == "door":
			draw_rect(Rect2(-45, -166, 90, 166), Color("60777d"))
			draw_rect(Rect2(-39, -158, 78, 156), Color("112530"))
			draw_rect(Rect2(-39, -158, 78, 156), accent, false, 3)
		elif kind == "exit":
			draw_rect(Rect2(-48, -142, 96, 142), accent.darkened(0.5))
			draw_rect(Rect2(-42, -134, 84, 134), Color("cdf7ef", 0.75))
		else:
			draw_flat_ellipse(Vector2(0, 3), Vector2(41, 9), Color(0.01, 0.05, 0.08, 0.38))
			draw_rect(Rect2(-8, -21, 16, 22), accent.darkened(0.5))
			draw_rect(Rect2(-54, -118, 108, 80), Color("0d2530", 0.88))
			draw_rect(Rect2(-54, -118, 108, 80), accent, false, 3)
			draw_string(ThemeDB.fallback_font, Vector2(-42, -84), caption, HORIZONTAL_ALIGNMENT_LEFT, 84, 22, accent)
			draw_string(ThemeDB.fallback_font, Vector2(-42, -57), "已恢复" if done else "待观测", HORIZONTAL_ALIGNMENT_LEFT, 84, 15, Color("e7f3ef"))
	func draw_flat_ellipse(at: Vector2, radii: Vector2, color: Color) -> void:
		draw_set_transform(at, 0.0, Vector2(1.0, radii.y / radii.x))
		draw_circle(Vector2.ZERO, radii.x, color)
		draw_set_transform(Vector2.ZERO)

var player := Vector2(170, 530)
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
var world: Node2D
var player_actor: DepthObject
var objects: Array[DepthObject] = []

func _ready() -> void:
	setup("01 / 白色走廊", "在真正的走廊纵深中恢复人生节点；不替林澈填写志愿。")
	ui.z_index = 4096 # UI is fixed and is never part of feet sorting.
	if ResourceLoader.exists("res://assets/scenes/white_corridor_bg.png"):
		background = load("res://assets/scenes/white_corridor_bg.png")
	_build_world()
	objective = label_at("", Vector2(54, 132), Vector2(780, 40), 25, CYAN)
	status = label_at("", Vector2(54, 173), Vector2(1040, 46), 20, PAPER)
	view_state = label_at("", Vector2(1005, 135), Vector2(240, 38), 19, CYAN)
	ghost = label_at("Ghost：你不是来替林澈判断答案，而是把被覆盖的选择重新放回可见处。", Vector2(70, 573), Vector2(1130, 67), 23, PAPER)
	hint = label_at("", Vector2(70, 654), Vector2(1130, 37), 18, CYAN)
	refresh()

func _build_world() -> void:
	world = Node2D.new()
	world.name = "World_YSortedByBase"
	add_child(world)
	move_child(world, 0)
	for i in range(BASES.size()):
		var kind: String = ["terminal", "station", "station", "station", "station", "door", "exit"][i]
		var text: String = ["", "07", "15", "18", "22", "", ""][i]
		var tint := CYAN if i == 0 else MUTED
		var item := DepthObject.new()
		item.name = ["LandingChairTerminal_Base", "Age07_Base", "Age15_Base", "Age18_Base", "Age22_Base", "MemoryDeletedDoor_Base", "ArchiveExit_Base"][i]
		item.kind = kind
		item.caption = text
		item.accent = tint
		item.position = BASES[i]
		item.z_index = int(item.position.y)
		item.visible = i < 5
		world.add_child(item)
		objects.append(item)
	player_actor = DepthObject.new()
	player_actor.name = "Player_FeetSort"
	player_actor.kind = "player"
	player_actor.sprite = load("res://assets/characters/心灵调理师.png")
	player_actor.position = player
	player_actor.z_index = int(player.y)
	world.add_child(player_actor)

func _physics_process(delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if direction != Vector2.ZERO:
		walk_target = -1
		face_left = direction.x < 0 if direction.x != 0 else face_left
		stride += delta * 11
	if walk_target >= 0:
		var target: Vector2 = BASES[walk_target] + Vector2(0, 54)
		if player.distance_to(target) <= 8:
			walk_target = -1
		else:
			direction = player.direction_to(target)
	_move_player(direction * delta * 280)
	hint.text = "WASD / 方向键在走廊前后移动 · E / Enter 调查「%s」· 按住 Q 意识视野" % nearby_name()
	queue_redraw()

func _move_player(delta: Vector2) -> void:
	if delta == Vector2.ZERO:
		return
	var candidate := player + delta
	candidate.x = clampf(candidate.x, PLAY_BOUNDS.position.x, PLAY_BOUNDS.end.x)
	candidate.y = clampf(candidate.y, PLAY_BOUNDS.position.y, PLAY_BOUNDS.end.y)
	# Every prop blocks only a narrow base, never its tall artwork.  Comparing the
	# current and candidate distances also lets a player spawned near a base move
	# out of it instead of becoming trapped inside the collision radius.
	for index in range(objects.size()):
		if not objects[index].visible:
			continue
		var radius := 43.0 if index in [0, 5, 6] else 34.0
		var current_distance := player.distance_to(objects[index].position)
		var next_distance := candidate.distance_to(objects[index].position)
		if next_distance < radius and next_distance < current_distance:
			return
	player = candidate
	player_actor.position = player
	player_actor.z_index = int(player.y)

func set_player_for_test(at: Vector2) -> void:
	player = at
	player_actor.position = player
	player_actor.z_index = int(player.y)

func move_player_for_test(delta: Vector2) -> void:
	_move_player(delta)

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
		else:
			ghost.text = "Ghost：先走近当前目标。每一次确认都要在对应记忆的位置发生。"
		get_viewport().set_input_as_handled()

func nearest_station() -> int:
	var best := -1
	var distance := INTERACT_RADIUS
	for i in range(BASES.size()):
		if not objects[i].visible: continue
		var d := player.distance_to(BASES[i])
		if d < distance:
			best = i
			distance = d
	return best

func nearby_name() -> String:
	var near := nearest_station()
	return ["登陆终端", "7 岁节点", "15 岁节点", "18 岁节点", "22 岁节点", "MEMORY DELETED", "成长档案室出口"][near] if near >= 0 else "无（请走近目标）"

func click_station(index: int) -> void:
	# Kept as a callable for accessibility integrations; it moves, never remote-interacts.
	walk_target = index

func interact(index: int) -> void:
	# Direct callers (tests/accessibility) get the same proximity gate as E.
	if index < 0 or index >= BASES.size() or not objects[index].visible or player.distance_to(BASES[index]) > INTERACT_RADIUS:
		ghost.text = "Ghost：先走近当前目标。每一次确认都要在对应记忆的位置发生。"
		refresh()
		return
	get_parent().sound("interact")
	if index == 0:
		if not observer:
			observer = true
			GameState.case_flags["observer"] = true
			ghost.text = "Ghost：意识观测器已接入。按住 Q，寻找 7 岁节点中被成绩遮住的蓝色碎片。"
	elif not observer:
		ghost.text = "系统：请先在登陆椅旁启动意识观测器。"
	elif index == 5:
		ghost.text = "MEMORY DELETED：权限不足，无法进入。这里的缺口仍被保留。"
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
	if phase == 0 and not vision:
		ghost.text = "Ghost：普通视野只看得见成绩。按住 Q，再调查 7 岁节点。"
		return
	if phase == 0: ghost.text = "Ghost：蓝色碎片出现了。它记录的是‘我想把它做完’，不是一个职业名称。"
	elif phase == 1: ghost.text = "Ghost：碎片已收取。再次调查，把它插入 7 岁节点。"
	else:
		complete_node("7 岁：蓝色意愿碎片已保存，尚不为它命名。")
		return
	phase += 1

func do_fifteen() -> void:
	_progress_text(["Ghost：录取通知书下面还压着一张纸。先移开这份‘更正确的故事’。", "Ghost：发现游戏比赛报名表。它和持续的投入可以拼合，但不能直接等同于职业志愿。"], "15 岁：报名表与投入感构成未命名的意愿片段。")
func do_eighteen() -> void:
	_progress_text(["系统：外部期待写入失败。失败不能跳过。请追踪这块碎片的来源。", "Ghost：来源是奖状、亲友的安心和掌声。它们会影响林澈，却不能替他确认意愿。"], "18 岁：已确认意愿 → 无法确认意愿。MEMORY DELETED 侧门显现，但权限不足。")
func do_twentytwo() -> void:
	_progress_text(["Ghost：‘成为优秀医生’这句话没有记忆纹理，是系统伪造的总结。", "Ghost：伪造碎片已拔除。现在不要填入另一个好听的答案。"], "22 岁：已确认意愿 → 无法确认意愿。伪造结论不再冒充当事人的声音。")
func _progress_text(lines: Array, finished: String) -> void:
	if phase < 2:
		ghost.text = lines[phase]
		phase += 1
	else:
		complete_node(finished)

func complete_node(message: String) -> void:
	GameState.case_flags["scene01_age_%d" % [7, 15, 18, 22][completed]] = true
	objects[completed + 1].done = true
	objects[completed + 1].accent = CYAN
	objects[completed + 1].queue_redraw()
	completed += 1
	phase = 0
	ghost.text = "Ghost：" + message
	get_parent().sound("evidence")
	if completed == 3: objects[5].visible = true
	if completed == 4:
		objects[6].visible = true
		ghost.text += "\n四段节点已恢复。成长档案室出口开放；选择理由仍然空白。"

func current_name() -> String:
	return AGE_NAMES[mini(completed, 3)]
func phase_description() -> String:
	if not observer: return "走近登陆椅旁的终端，取得意识观测器"
	if completed == 4: return "走近成长档案室出口"
	return ["按住 Q 寻找蓝色碎片", "移开录取通知书", "尝试写入外部期待", "识别伪造职业结论"][completed]
func refresh() -> void:
	objective.text = "恢复人生节点  %d / 4" % completed
	status.text = "当前目标：" + phase_description()
	view_state.text = "◈ 意识视野 / Q" if vision else "普通视野 · 按住 Q"
	view_state.add_theme_color_override("font_color", CYAN if vision else MUTED)
	queue_redraw()
func _draw() -> void:
	if background: draw_texture_rect(background, Rect2(0, 0, 1280, 720), false)
	else: draw_rect(Rect2(0, 220, 1280, 350), Color("b8d0cf"))
	draw_rect(Rect2(0, 0, 1280, 225), Color("07121d", 0.88))
	if vision:
		draw_rect(Rect2(40, 220, 1200, 340), Color(0.2, 0.72, 0.9, 0.12))
		draw_circle(Vector2(BASES[1].x, BASES[1].y - 130), 13, Color("3d9dff"))
	draw_rect(Rect2(40, 561, 1200, 86), Color("0d1a27", 0.96))
