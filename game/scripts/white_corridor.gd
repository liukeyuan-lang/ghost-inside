extends "res://scripts/view.gd"
const EvidenceInspect = preload("res://scripts/evidence_inspect_layer.gd")

## World objects sort at their feet/base.  Tall artwork is drawn above the base,
## so it never uses a sprite centre to decide who covers whom.
const AGE_NAMES := ["7 岁", "15 岁", "18 岁", "22 岁"]
const BASES := [Vector2(170, 510), Vector2(342, 470), Vector2(514, 405), Vector2(686, 495), Vector2(858, 370), Vector2(1018, 462), Vector2(1140, 528)]
const INTERACT_RADIUS := 78.0
const PLAY_BOUNDS := Rect2(82, 332, 1118, 214)
const LYING_THERAPIST_PATH := "res://assets/props/white_corridor/lying_therapist.png"
enum IntroState { BLACKOUT, DIALOGUE, RISING, EXPLORE }
const INTRO_PAGES := [
	{"speaker": "Ghost", "text": "能听见吗？先别动，意识接入还没稳定。"},
	{"speaker": "心灵调理师", "text": "这里是什么地方？我为什么会躺在这里？"},
	{"speaker": "Ghost", "text": "这里不是医院，是林澈意识空间的入口。这张椅子让你接入他的记忆。"},
	{"speaker": "心灵调理师", "text": "我要做什么？"},
	{"speaker": "Ghost", "text": "恢复四个人生节点，确认哪些声音属于他；不要替他选择。"},
	{"speaker": "Ghost", "text": "如果找不到答案，就保留空白。错误答案比未知更危险。"},
	{"speaker": "Ghost", "text": "接入完成。靠近终端启动意识观测器，然后从七岁节点开始。"},
]

class DepthObject extends Node2D:
	var kind := "station"
	var caption := ""
	var accent := Color.WHITE
	var done := false
	var sprite: Texture2D
	var visual: Sprite2D
	var evidence: Sprite2D
	func _draw() -> void:
		# All core artwork is a transparent PNG child.  The Node2D itself remains
		# exactly at its feet/base so sorting and collision never use tall art bounds.
		pass

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
var ghost_actor: DepthObject
var objects: Array[DepthObject] = []
var lying_actor: Sprite2D
var intro_state := IntroState.BLACKOUT
var intro_index := 0
var intro_input_armed := false
var intro_overlay: ColorRect
var evidence_layer
var evidence_seen: Dictionary = {}

const PROP_ROOT := "res://assets/props/white_corridor/"
const PROP_PATHS := {
	"terminal": PROP_ROOT + "landing_terminal.png",
	"stations": PROP_ROOT + "age_stations_atlas.png",
	"doors": PROP_ROOT + "doors_atlas.png",
	"evidence": PROP_ROOT + "evidence_atlas.png",
	"actors": PROP_ROOT + "map_actors_atlas.png",
}

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
	_create_evidence_layer()
	_begin_intro()

func _create_evidence_layer() -> void:
	evidence_layer = EvidenceInspect.new()
	evidence_layer.name = "EvidenceInspectLayer"
	ui.add_child(evidence_layer)
	evidence_layer.confirmed.connect(_on_evidence_confirmed)
	evidence_layer.choice_made.connect(_on_evidence_choice)

func _open_evidence(id: String, station: int, title: String, preview: String, body: String, note: String) -> void:
	# The existing transparent atlas remains the visual source; text is intentionally
	# typeset here so it stays readable rather than being baked into a tiny icon.
	evidence_layer.inspect(id, _atlas(PROP_PATHS.evidence, Rect2(543 * station, 0, 543, 724)), title, preview, body, note, true)

func _on_evidence_confirmed(id: String) -> void:
	evidence_seen[id] = true
	match id:
		"age07":
			complete_node("7 岁：蓝色碎片被放大保存；它只记录‘我想把它做完’。")
		"age15":
			complete_node("15 岁：报名表与持续投入构成未命名的意愿片段。")
		"age18":
			ghost.text = "Ghost：来源都在这里了。它们来自谁？能替代林澈自己的意愿吗？"
			_show_eighteen_choice()
		"age22":
			ghost.text = "Ghost：这句话是谁说的？你找到原始记录了吗？"
			_show_twentytwo_choice()
	refresh()

func _show_eighteen_choice() -> void:
	evidence_layer.offer_choices("age18_choice", "18 岁 · 来源归属", [
		{"id": "self", "text": "属于林澈自我意愿"},
		{"id": "external", "text": "属于外部期待，无法替代自我意愿"},
		{"id": "insufficient", "text": "证据不足"},
	])

func _show_twentytwo_choice() -> void:
	evidence_layer.offer_choices("age22_choice", "22 岁 · 摘要处理", [
		{"id": "keep", "text": "保留为林澈意愿"},
		{"id": "remove", "text": "标记为系统摘要并移除"},
		{"id": "hold", "text": "暂不处理"},
	])

func _on_evidence_choice(id: String, choice: String) -> void:
	if id == "age18_choice":
		if choice != "external":
			evidence_layer.show_feedback("奖状、父亲、老师和亲友的话都是外部来源；没有林澈自己的意愿记录。")
			return
		evidence_layer.visible = false
		complete_node("18 岁：玩家确认这是外部期待，不能替代自我意愿。")
		return
	if id == "age22_choice":
		if choice != "remove":
			evidence_layer.show_feedback("该句只有系统生成摘要，缺少原始语音与记忆纹理；保留或搁置都会让节点无法继续核验。")
			return
		evidence_layer.visible = false
		complete_node("22 岁：玩家将无原始记录的系统摘要移除；意愿仍保留为空白。")

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
		_attach_prop_visual(item, i)
		world.add_child(item)
		objects.append(item)
	# The lying PNG is its own authored actor layer, positioned on the chair rather
	# than being a rotated standing sprite.  It is placed behind the chair control
	# panel but above the chair base, so the base still occludes its lower edge.
	var chair := objects[0]
	lying_actor = Sprite2D.new()
	lying_actor.name = "LyingTherapist_IntroArt"
	lying_actor.texture = _safe_texture(LYING_THERAPIST_PATH)
	lying_actor.scale = Vector2.ONE * 0.118
	lying_actor.position = Vector2(-8, -80)
	lying_actor.z_index = 1
	chair.add_child(lying_actor)
	player_actor = DepthObject.new()
	player_actor.name = "Player_FeetSort"
	player_actor.kind = "player"
	player_actor.position = player
	player_actor.z_index = int(player.y)
	_attach_actor_visual(player_actor, 0, "Player_MapActor", 0.25)
	player_actor.modulate.a = 0.0
	world.add_child(player_actor)
	ghost_actor = DepthObject.new()
	ghost_actor.name = "Ghost_MapActor"
	ghost_actor.kind = "ghost"
	ghost_actor.position = Vector2(260, 438)
	ghost_actor.z_index = int(ghost_actor.position.y)
	_attach_actor_visual(ghost_actor, 4, "Ghost_ActualMapRender", 0.18)
	world.add_child(ghost_actor)

func _atlas(path: String, region: Rect2) -> AtlasTexture:
	var source := _safe_texture(path)
	if source == null:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = region
	return atlas

func _safe_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

func _attach_sprite(host: DepthObject, texture: Texture2D, node_name: String, scale_amount: float, visual_height: float) -> Sprite2D:
	if texture == null:
		# A compact text marker keeps a damaged build navigable without pretending a
		# procedural rectangle is finished art. Normal builds always use the PNG path.
		var missing := Label.new()
		missing.name = node_name + "_MissingArtFallback"
		missing.text = "[素材缺失]"
		missing.position = Vector2(-42, -36)
		missing.add_theme_color_override("font_color", Color("ffb8a8"))
		host.add_child(missing)
		return null
	var sprite := Sprite2D.new()
	sprite.name = node_name
	sprite.texture = texture
	sprite.scale = Vector2.ONE * scale_amount
	# Sprite is centered, hence its lower edge sits on the base at y=0.
	sprite.position = Vector2(0, -visual_height * 0.5)
	host.add_child(sprite)
	host.visual = sprite
	return sprite

func _attach_prop_visual(item: DepthObject, index: int) -> void:
	match index:
		0:
			_attach_sprite(item, _safe_texture(PROP_PATHS.terminal), "LandingChairTerminal_Art", 0.135, 171.0)
		1, 2, 3, 4:
			var age_index := index - 1
			var station_sprite := _attach_sprite(item, _atlas(PROP_PATHS.stations, Rect2(418 * age_index, 0, 418, 941)), "Age%02d_StationArt" % [7, 15, 18, 22][age_index], 0.18, 169.0)
			var evidence_sprite := _attach_sprite(item, _atlas(PROP_PATHS.evidence, Rect2(543 * age_index, 0, 543, 724)), "Age%02d_EvidenceLayer" % [7, 15, 18, 22][age_index], 0.105, 76.0)
			if evidence_sprite:
				evidence_sprite.position = Vector2(0, -132)
				evidence_sprite.visible = false
				item.evidence = evidence_sprite
			item.visual = station_sprite
		5:
			_attach_sprite(item, _atlas(PROP_PATHS.doors, Rect2(0, 0, 836, 941)), "MemoryDeletedDoor_Art", 0.18, 169.0)
		6:
			_attach_sprite(item, _atlas(PROP_PATHS.doors, Rect2(836, 0, 836, 941)), "ArchiveExit_Art", 0.18, 169.0)

func _attach_actor_visual(item: DepthObject, actor_region_index: int, node_name: String, scale_amount: float) -> void:
	var column := actor_region_index % 4
	var row := actor_region_index / 4
	_attach_sprite(item, _atlas(PROP_PATHS.actors, Rect2(column * 384, row * 512, 384, 512)), node_name, scale_amount, 512.0 * scale_amount)

func _physics_process(delta: float) -> void:
	if intro_state != IntroState.EXPLORE:
		return
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
	if evidence_layer and evidence_layer.visible:
		return
	if intro_state == IntroState.DIALOGUE:
		if _is_intro_advance(event):
			advance_intro()
			get_viewport().set_input_as_handled()
		return
	if intro_state != IntroState.EXPLORE:
		return
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

func _is_intro_advance(event: InputEvent) -> bool:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		return true
	return event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")

func _begin_intro() -> void:
	intro_state = IntroState.BLACKOUT
	intro_overlay = ColorRect.new()
	intro_overlay.name = "IntroBlackoutFade"
	intro_overlay.color = Color(0.0, 0.02, 0.05, 1.0)
	intro_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	intro_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_overlay.z_index = 4094
	ui.add_child(intro_overlay)
	ghost.visible = false
	objective.visible = false
	status.visible = false
	view_state.visible = false
	hint.visible = false
	if comic_dialogue:
		comic_dialogue.advance_requested.connect(advance_intro)
		comic_dialogue.hide_dialogue()
	var tween := create_tween()
	tween.tween_property(intro_overlay, "color:a", 0.18, 0.55)
	tween.tween_callback(_show_intro_page)

func _show_intro_page() -> void:
	intro_state = IntroState.DIALOGUE
	if intro_overlay:
		intro_overlay.color.a = 0.18
	var page: Dictionary = INTRO_PAGES[intro_index]
	comic_dialogue.show_line(str(page.speaker), str(page.text), true)

func advance_intro() -> void:
	if intro_state != IntroState.DIALOGUE:
		return
	intro_index += 1
	if intro_index < INTRO_PAGES.size():
		_show_intro_page()
		return
	_finish_intro()

func _finish_intro() -> void:
	intro_state = IntroState.RISING
	comic_dialogue.hide_dialogue()
	if intro_overlay:
		intro_overlay.color.a = 0.0
	var tween := create_tween()
	if lying_actor:
		tween.tween_property(lying_actor, "modulate:a", 0.0, 0.24)
	tween.tween_property(player_actor, "modulate:a", 1.0, 0.2)
	tween.tween_callback(_enable_exploration)

func _enable_exploration() -> void:
	if lying_actor:
		lying_actor.visible = false
	player_actor.modulate.a = 1.0
	player = BASES[0] + Vector2(52, 20)
	set_player_for_test(player)
	ghost.visible = true
	objective.visible = true
	status.visible = true
	view_state.visible = true
	hint.visible = true
	ghost.text = "Ghost：接入稳定。靠近登陆椅终端，按 E 启动意识观测器。"
	intro_state = IntroState.EXPLORE
	# The state change occurs after the input event is consumed; a deferred frame
	# prevents the closing Enter/E from immediately activating the terminal.
	await get_tree().process_frame

func complete_intro_for_test() -> void:
	intro_index = INTRO_PAGES.size() - 1
	if intro_state == IntroState.BLACKOUT:
		_show_intro_page()
	_finish_intro()
	_enable_exploration()

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
	if not evidence_seen.get("age07", false):
		_open_evidence("age07", 0, "7 岁 · 蓝色碎片", "成绩单下方有一块蓝色碎片。先把它从成绩评价里分离出来。", "【蓝色碎片 / 7 岁】\n\n可读文字：\n“我想把它做完。”\n\n记录类型：未命名的持续兴趣。\n它不是职业承诺，也不是任何人替他填写的答案。", "成绩单覆盖层 → 移开 → 放大查看")

func do_fifteen() -> void:
	if not evidence_seen.get("age15", false):
		_open_evidence("age15", 1, "15 岁 · 被压住的比赛报名表", "录取通知书压在一张折起的纸上。按“移开并展开”，再阅读被遮住的报名表。", "【录取通知书摘要】\n林澈：你已被录取。\n\n【比赛报名表】\n项目：青少年游戏创作比赛\n报名人：林澈\n\n手写注释：\n“如果这次能进决赛，\n我就认真考虑做游戏。”\n\n这份投入可被确认，\n但它仍不等同于职业结论。", "录取通知书在上 → 移开 → 报名表展开 → 放大阅读")
func do_eighteen() -> void:
	if not evidence_seen.get("age18", false):
		_open_evidence("age18", 2, "18 岁 · 期待来源记录", "奖状、留言和劝说叠在一起。展开后逐条查看是谁写下的。", "【来源记录】\n父亲：\"医学更稳，别走我的弯路。\"\n老师：\"你的分数很适合医学。\"\n亲友：\"当医生大家都安心。\"\n\n缺失项：林澈的原始意愿陈述。\n请比较来源，再作判断。", "外部来源清晰；自我意愿来源缺失")
	elif not evidence_seen.get("age18_choice_shown", false):
		_show_eighteen_choice()
func do_twentytwo() -> void:
	if not evidence_seen.get("age22", false):
		_open_evidence("age22", 3, "22 岁 · 职业结论摘要", "一行结论悬在记录上方。展开后检查它是否连着原始语音或记忆纹理。", "【系统生成摘要】\n“林澈决定成为一名优秀医生。”\n\n来源字段：系统汇总\n原始语音：未找到\n记忆纹理：未找到\n\n这是一条摘要，不提供它是否等于当事人意愿的答案。", "系统摘要存在；原始语音与记忆纹理缺失")
	elif not evidence_seen.get("age22_choice_shown", false):
		_show_twentytwo_choice()

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
	return ["按住 Q 寻找蓝色碎片", "移开录取通知书", "核验期待的来源", "核验职业结论的来源"][completed]
func refresh() -> void:
	objective.text = "恢复人生节点  %d / 4" % completed
	status.text = "当前目标：" + phase_description()
	view_state.text = "◈ 意识视野 / Q" if vision else "普通视野 · 按住 Q"
	view_state.add_theme_color_override("font_color", CYAN if vision else MUTED)
	for index in range(1, 5):
		# Evidence exists as a real transparent layer, not a procedural Q marker.
		# Q reveals unresolved fragments; restored evidence remains inspectable.
		if objects[index].evidence:
			objects[index].evidence.visible = observer and (vision or objects[index].done)
	queue_redraw()
func _draw() -> void:
	if background: draw_texture_rect(background, Rect2(0, 0, 1280, 720), false)
	else: draw_rect(Rect2(0, 220, 1280, 350), Color("b8d0cf"))
	draw_rect(Rect2(0, 0, 1280, 225), Color("07121d", 0.88))
	if vision:
		draw_rect(Rect2(40, 220, 1200, 340), Color(0.2, 0.72, 0.9, 0.12))
	draw_rect(Rect2(40, 561, 1200, 86), Color("0d1a27", 0.96))
