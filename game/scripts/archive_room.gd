extends "res://scripts/view.gd"
const EvidenceInspect = preload("res://scripts/evidence_inspect_layer.gd")

const ANCHORS := ["比赛报名表", "医学院宣传册", "旧吉他拨片"]
const ANCHOR_NOTES := [
	"报名费是林澈自己攒的。参赛是他真实投入过的事。",
	"父亲带回宣传册，希望儿子少承担一点风险。",
	"拨片属于父亲。他也曾把喜欢的事收进箱子。"
]
const PHOTO_ORDER := ["父亲参加乐队", "父亲收起吉他", "林澈参加游戏比赛", "林澈填写医学志愿"]
const PHOTO_SHUFFLED := ["林澈填写医学志愿", "父亲收起吉他", "父亲参加乐队", "林澈参加游戏比赛"]
const CAUSAL_ORDER := ["放弃梦想", "恐惧风险", "保护与限制", "推迟选择", "无法确认意愿"]
const CAUSAL_SHUFFLED := ["保护与限制", "无法确认意愿", "放弃梦想", "推迟选择", "恐惧风险"]
const STATIONS := ["物证柜", "照片时间线", "对话修复台", "因果链", "封存终端"]
const STATION_X := [165.0, 450.0, 880.0, 680.0, 1100.0]

var player := Vector2(100, 492)
var player_target := Vector2.ZERO
var walking_to := false
var facing_left := false
var walk_clock := 0.0
var near_station := -1
var flags: Dictionary = {}
var anchors: Array = []
var hint: Label
var narration: Label
var progress: Label
var station_buttons: Array[Button] = []
var modal: Control
var modal_content: Control
var background: Texture2D
var modal_feedback := ""
var modal_choice_count := 0
var evidence_layer

func _ready() -> void:
	var stored: Variant = GameState.get("case_flags")
	if stored is Dictionary:
		flags = stored
	var saved_anchors: Variant = flags.get("scene02_anchor_ids", [])
	if saved_anchors is Array:
		anchors = saved_anchors
	for asset in ["res://assets/scenes/archive_room_bg.png", "res://assets/scenes/scene02/bg_back.png"]:
		if ResourceLoader.exists(asset):
			background = load(asset)
			break
	setup("02 / 成长档案室", "按时间还原事件，区分父亲的影响与林澈自己的决定。")
	for i in range(STATIONS.size()):
		var b := button_at(STATIONS[i], Vector2(STATION_X[i] - 96, 293), Vector2(192, 48), _click_station.bind(i))
		b.add_theme_font_size_override("font_size", 18)
		b.focus_mode = Control.FOCUS_NONE
		station_buttons.append(b)
	progress = label_at("", Vector2(48, 132), Vector2(1180, 35), 20, CYAN)
	narration = label_at("Ghost：时间顺序能说明发生过什么，不能单独说明谁替谁决定。", Vector2(64, 571), Vector2(1148, 68), 21, PAPER)
	comic_dialogue.show_line("Ghost", "时间顺序能说明发生过什么，不能单独说明谁替谁决定。")
	hint = label_at("WASD / 方向键移动，靠近后按 E / Enter；也可点击场景中的设施。", Vector2(64, 651), Vector2(1150, 39), 18, CYAN)
	_create_modal()
	_create_evidence_layer()
	_refresh()

func _create_evidence_layer() -> void:
	evidence_layer = EvidenceInspect.new()
	evidence_layer.name = "EvidenceInspectLayer"
	ui.add_child(evidence_layer)
	evidence_layer.confirmed.connect(_archive_evidence_confirmed)

func _archive_texture(index: int) -> Texture2D:
	var source := load("res://assets/props/white_corridor/evidence_atlas.png") as Texture2D
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = Rect2(543 * (index % 4), 0, 543, 724)
	return atlas

func inspect_archive_evidence(kind: String) -> void:
	var data := {
		"photo": [0, "照片时间线", "相片放大后可见人物年龄、父亲的婚戒与吉他上的积灰。", "【照片观察】\n父亲乐队照：年轻、未戴婚戒，吉他无灰。\n父亲收起吉他：婚戒出现，琴盒积灰。\n林澈比赛照：少年身高，报名表折角可见。\n医学志愿照：成年笔迹。\n这些线索帮助排序，不替任何人确认意愿。", "年龄 / 婚戒 / 积灰是排序线索"],
		"比赛报名表": [1, "比赛报名表", "报名表折在通知书下面。先移开上层纸张。", "【游戏创作比赛报名表】\n报名人：林澈\n项目：青少年游戏创作比赛\n手写：\"如果这次能进决赛，\n我就认真考虑做游戏。\"\n\n报名费由林澈自己攒下。\n它证明投入，不替他填职业答案。", "通知书压住 → 移开 → 报名表展开"],
		"医学院宣传册": [2, "医学院宣传册", "宣传册夹着父亲带回来的便签。展开阅读外部来源。", "【医学院宣传册】\n父亲便签：\"这条路稳一点，你不用像我那样冒险。\"\n\n来源：父亲。\n它说明保护和期待同时存在；没有林澈自己的原始意愿声明。", "宣传册展开后可见来源与缺失项"],
		"旧吉他拨片": [3, "旧吉他拨片", "拨片放大后可以翻到背面。", "【旧吉他拨片 / 背面】\n刻字：L.C. 乐队 2001\n边缘磨损，琴盒内积灰。\n\n它属于父亲，记录他曾把喜欢的事收进箱子；不能据此替林澈作决定。", "近景 + 背面刻字"],
	}
	if not data.has(kind):
		return
	var item: Array = data[kind]
	var texture := load("res://assets/props/archive_room/old_guitar_pick.png") as Texture2D if kind == "旧吉他拨片" else _archive_texture(int(item[0]))
	evidence_layer.inspect("archive_" + kind, texture, str(item[1]), str(item[2]), str(item[3]), str(item[4]), true)

func _archive_evidence_confirmed(id: String) -> void:
	if id.begins_with("archive_"):
		var kind := id.trim_prefix("archive_")
		if kind in ANCHORS:
			_take_anchor(ANCHORS.find(kind), true)
	_refresh()

func _create_modal() -> void:
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(modal)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.05, 0.08, 0.88)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(shade)
	var panel := Panel.new()
	panel.position = Vector2(220, 144)
	panel.size = Vector2(840, 448)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("142b3a")
	style.border_color = CYAN
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	modal.add_child(panel)
	modal_content = Control.new()
	modal_content.position = Vector2(236, 159)
	modal_content.size = Vector2(808, 418)
	modal.add_child(modal_content)
	modal.visible = false

func _say_comic(line: String, speaker := "Ghost") -> void:
	narration.text = speaker + "：" + line
	comic_dialogue.show_line(speaker, line)

func _clear_modal() -> void:
	for child in modal_content.get_children():
		child.queue_free()

func _modal_title(title: String, body: String) -> void:
	modal.visible = true
	_clear_modal()
	modal_choice_count = 0
	_modal_label(title, Vector2(22, 15), Vector2(720, 45), 29, CYAN)
	_modal_label(body, Vector2(22, 67), Vector2(750, 69), 19, PAPER)
	if not modal_feedback.is_empty():
		_modal_label("⚠ " + modal_feedback, Vector2(22, 138), Vector2(750, 25), 16, RED)
	_modal_button("关闭", Vector2(666, 360), Vector2(118, 43), _close_modal)

func _modal_label(value: String, pos: Vector2, dimensions: Vector2, size: int = 21, color: Color = PAPER) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = dimensions
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_content.add_child(label)
	return label

func _modal_button(caption: String, pos: Vector2, dimensions: Vector2, callback: Callable) -> Button:
	var b := button_at(caption, pos, dimensions, callback)
	b.reparent(modal_content, false)
	b.position = pos
	b.add_theme_font_size_override("font_size", 18)
	if caption == "关闭":
		b.call_deferred("grab_focus")
	else:
		if modal_choice_count == 0:
			b.call_deferred("grab_focus")
		modal_choice_count += 1
	return b

func _close_modal() -> void:
	modal.visible = false
	_refresh()

func _click_station(index: int) -> void:
	player_target = Vector2(STATION_X[index], 492)
	walking_to = true
	_open_station(index)

func _physics_process(delta: float) -> void:
	if modal.visible:
		return
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if direction != Vector2.ZERO:
		walking_to = false
	elif walking_to:
		direction = player.direction_to(player_target)
		if player.distance_to(player_target) < 6:
			walking_to = false
			direction = Vector2.ZERO
	if direction.x != 0:
		facing_left = direction.x < 0
	if direction != Vector2.ZERO:
		walk_clock += delta * 10
	player += direction * 270 * delta
	player = player.clamp(Vector2(72, 455), Vector2(1208, 523))
	near_station = -1
	var best := 115.0
	for i in range(STATION_X.size()):
		var distance := absf(player.x - STATION_X[i])
		if distance < best:
			best = distance
			near_station = i
	if near_station >= 0:
		hint.text = "E / Enter · %s     ｜     点击设施也可调查" % STATIONS[near_station]
	else:
		hint.text = "WASD / 方向键移动，靠近后按 E / Enter；也可点击场景中的设施。"
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if evidence_layer and evidence_layer.visible:
		return
	if event.is_action_pressed("interact"):
		if modal.visible:
			var focused := get_viewport().gui_get_focus_owner()
			if focused is Button:
				focused.pressed.emit()
				get_viewport().set_input_as_handled()
		elif near_station >= 0:
			_open_station(near_station)
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and modal.visible:
		_close_modal()
		get_viewport().set_input_as_handled()

func _open_station(index: int) -> void:
	get_parent().sound("interact")
	modal_feedback = ""
	match index:
		0: _show_anchors()
		1: _show_timeline()
		2: _show_dialogue()
		3: _show_causal()
		4: _show_terminal()

func _show_timeline() -> void:
	if flags.get("scene02_timeline", false):
		_modal_title("照片时间线 · 已确认", "父亲参加乐队 → 父亲收起吉他 → 林澈参加游戏比赛 → 林澈填写医学志愿。\n顺序证明先后，不证明谁替谁决定。")
		return
	var count := int(flags.get("scene02_photo_count", 0))
	_modal_title("照片时间线 · %d / 4" % count, "按事件发生的先后选择照片。观察父亲的鬓角、吉他的积灰与林澈的身高。")
	for i in range(PHOTO_SHUFFLED.size()):
		var value: String = PHOTO_SHUFFLED[i]
		_modal_button(value, Vector2(22 + (i % 2) * 389, 166 + (i / 2) * 79), Vector2(366, 62), _choose_photo.bind(value))
	_modal_button("查看照片物证特写", Vector2(430, 332), Vector2(330, 42), func(): inspect_archive_evidence("photo"))

func _choose_photo(value: String) -> void:
	var count := int(flags.get("scene02_photo_count", 0))
	if value != PHOTO_ORDER[count]:
		var clue := "照片出现矛盾：吉他先积灰后崭新，或林澈的身高忽然倒退。检查这张照片属于哪个时期。"
		if value == "林澈填写医学志愿" and count == 0:
			clue = "志愿表上的笔迹属于成年的林澈。此时父亲的吉他早已收起。"
		_say_comic(clue)
		modal_feedback = "日期或场景不符；观察吉他的灰尘与人物年龄。"
		_show_timeline()
		return
	count += 1
	modal_feedback = ""
	flags["scene02_photo_count"] = count
	get_parent().sound("evidence")
	if count >= PHOTO_ORDER.size():
		flags["scene02_timeline"] = true
		_say_comic("时间顺序已经成立。它记录了父亲和林澈各自经历过什么。")
	_show_timeline()
	_refresh()

func _show_anchors() -> void:
	if not flags.get("scene02_timeline", false):
		_modal_title("物证柜 · 尚未稳定", "先排列照片，建立事件先后；物证才能准确放回对应的记忆。")
		return
	_modal_title("记忆锚点 · %d / 3" % anchors.size(), "将比赛报名表、医学院宣传册、旧吉他拨片放入对应记忆。三件必须齐全。")
	for i in range(ANCHORS.size()):
		var name: String = ANCHORS[i]
		_modal_button(("✓ " if name in anchors else "＋ ") + name, Vector2(22, 165 + i * 64), Vector2(340, 52), func(): inspect_archive_evidence(name))
		_modal_label(ANCHOR_NOTES[i], Vector2(380, 167 + i * 64), Vector2(395, 53), 16, MUTED)

func _take_anchor(index: int, inspected := false) -> void:
	if not inspected:
		inspect_archive_evidence(ANCHORS[index])
		return
	var name: String = ANCHORS[index]
	if name not in anchors:
		anchors.append(name)
		flags["scene02_anchor_ids"] = anchors
		GameState.unlock_evidence(["F01", "F02", "F03"][index])
		get_parent().sound("evidence")
		_say_comic("%s。它是记忆锚点，不是替林澈填写的答案。" % name)
	_show_anchors()
	_refresh()

func _show_dialogue() -> void:
	if anchors.size() < 3:
		_modal_title("对话修复台 · 缺少锚点", "三件物证全部放入后，才能稳定播放父子对话。当前 %d / 3。" % anchors.size())
		return
	if flags.get("scene02_dialogue", false):
		_modal_title("父子对话 · 已修复", "已说出口：父亲谈到人生的风险；林澈说“我知道”。\n推测 / 待确认：父亲也许怕儿子承担自己曾经历的失落；林澈也许不敢说仍想继续游戏。")
		comic_dialogue.show_line("Ghost", "已说出口的话被恢复了；没有说出口的部分仍然只能保留为可能。")
		return
	var part := int(flags.get("scene02_dialogue_part", 0))
	if part == 0:
		_modal_title("父亲的停顿 · 第 1 / 2 句", "已说出口：父亲说“喜欢可以……但是人生……”\n请从物证推测他没说完的话。推测不能写成事实。")
		comic_dialogue.show_line("林父", "喜欢可以……但是人生……")
		_modal_button("也许他怕儿子承担自己经历过的风险（推测）", Vector2(22, 185), Vector2(750, 65), _choose_dialogue.bind(true))
		_modal_button("他明确说过：游戏一文不值（当作事实）", Vector2(22, 270), Vector2(750, 65), _choose_dialogue.bind(false))
	else:
		_modal_title("林澈的沉默 · 第 2 / 2 句", "已说出口：林澈说“我知道”。报名表折角仍在。\n未说出口的部分只能保留为可能性。")
		comic_dialogue.show_line("林澈", "我知道。")
		_modal_button("他也许仍想继续做游戏，却暂时不敢表达（推测）", Vector2(22, 185), Vector2(750, 65), _choose_dialogue.bind(true))
		_modal_button("他已经决定放弃游戏，并完全认同父亲（当作事实）", Vector2(22, 270), Vector2(750, 65), _choose_dialogue.bind(false))

func _choose_dialogue(valid: bool) -> void:
	if not valid:
		_say_comic("物证没有记录这句话。未说出口的内容是可能性，不能伪装成事实。")
		modal_feedback = "没有物证支持这句断言；请保留为推测。"
		_show_dialogue()
		return
	modal_feedback = ""
	var part := int(flags.get("scene02_dialogue_part", 0)) + 1
	flags["scene02_dialogue_part"] = part
	get_parent().sound("evidence")
	if part >= 2:
		flags["scene02_dialogue"] = true
		_say_comic("父亲的保护与限制可能并存。林澈的沉默仍须由林澈自己解释。")
	_show_dialogue()
	_refresh()

func _show_causal() -> void:
	if not flags.get("scene02_dialogue", false):
		_modal_title("因果链 · 对话未修复", "先取得三件锚点，再把父子已说出口的话与可能的沉默区分开。")
		return
	if flags.get("scene02_causal_count", 0) >= CAUSAL_ORDER.size():
		_modal_title("因果链 · 已确认", "放弃梦想 → 恐惧风险 → 保护与限制 → 推迟选择 → 无法确认意愿。\n这是可解释的影响链，不是替林澈确认职业的判决。")
		return
	var count := int(flags.get("scene02_causal_count", 0))
	_modal_title("因果链 · %d / 5" % count, "按原因逐步排列。点错只退回冲突卡，已经确认的前段会保留。")
	for i in range(CAUSAL_SHUFFLED.size()):
		var value: String = CAUSAL_SHUFFLED[i]
		_modal_button(value, Vector2(22 + (i % 2) * 389, 160 + (i / 2) * 72), Vector2(366, 61), _choose_cause.bind(value))

func _choose_cause(value: String) -> void:
	var count := int(flags.get("scene02_causal_count", 0))
	if value != CAUSAL_ORDER[count]:
		_say_comic("因果不能从结果倒推。前 %d 段已经确认，只撤回这张冲突卡。" % count)
		modal_feedback = "因果不能从结果倒推；已确认的前段保留。"
		_show_causal()
		return
	modal_feedback = ""
	flags["scene02_causal_count"] = count + 1
	get_parent().sound("evidence")
	if count + 1 >= CAUSAL_ORDER.size():
		_say_comic("影响链成立。但父亲影响了林澈，不代表父亲替他作出了全部决定。")
	_show_causal()
	_refresh()

func _show_terminal() -> void:
	if int(flags.get("scene02_causal_count", 0)) < CAUSAL_ORDER.size():
		_modal_title("封存终端 · 权限锁定", "时间线、三件锚点、对话和因果链必须全部修复。现在还不能封存任何结论。")
		return
	if not flags.get("scene02_judgment", false):
		_modal_title("判断校验", "父亲的影响是否决定了林澈的人生？")
		_modal_button("影响不等于决定", Vector2(22, 177), Vector2(750, 66), _choose_judgment.bind(true))
		_modal_button("父亲决定了林澈的一切", Vector2(22, 263), Vector2(750, 66), _choose_judgment.bind(false))
		return
	if not flags.get("scene02_complete", false):
		_modal_title("封存权限 · 已获得", "封存不是遗忘；它是停止让无原始记录的系统摘要冒充当事人的声音。\n可封存：系统摘要及强制写入。不可删除：父亲、恐惧、医学可能性或林澈的记忆。")
		_modal_button("仅封存无原始记录摘要", Vector2(22, 260), Vector2(750, 72), _seal_false_conclusion)
		return
	_modal_title("系统摘要 · 已封存", "父亲的影响已确认；林澈的真实意愿仍待他自己表达。\n下一处：废弃游戏工作室。")
	_modal_button("进入废弃游戏工作室", Vector2(22, 264), Vector2(750, 70), func(): goto_scene("studio_room"))

func _choose_judgment(valid: bool) -> void:
	if not valid:
		_say_comic("你找到了影响，但还没有证明决定。保护和限制可以同时为真，却不能替代林澈的意愿记录。")
		modal_feedback = "影响、保护和限制可同时为真，却不足以替林澈决定。"
		_show_terminal()
		return
	modal_feedback = ""
	flags["scene02_judgment"] = true
	flags["scene02_permission"] = true
	get_parent().sound("change")
	var dossier: Variant = GameState.get("will_dossier")
	if dossier is Dictionary:
		dossier["外部影响"] = "父亲希望降低风险，同时限制了表达"
		dossier["封存范围"] = "仅伪造结论与强制写入"
		_say_comic("权限已取得。接下来只处理无原始记录的系统摘要；哪些话属于林澈仍须由记录回答。")
	_show_terminal()
	_refresh()

func _seal_false_conclusion() -> void:
	flags["scene02_complete"] = true
	var dossier: Variant = GameState.get("will_dossier")
	if dossier is Dictionary:
		dossier["强制行为"] = "未发现"
	get_parent().sound("change")
	_say_comic("无原始记录的系统摘要已封存。职业、父亲的回应与梦想状态仍未被替答。")
	_show_terminal()
	_refresh()

func _refresh() -> void:
	if not is_instance_valid(progress):
		return
	var photo := "✓" if flags.get("scene02_timeline", false) else "%d/4" % int(flags.get("scene02_photo_count", 0))
	var dialogue := "✓" if flags.get("scene02_dialogue", false) else "%d/2" % int(flags.get("scene02_dialogue_part", 0))
	var causal := "✓" if int(flags.get("scene02_causal_count", 0)) >= 5 else "%d/5" % int(flags.get("scene02_causal_count", 0))
	progress.text = "照片 %s    锚点 %d/3    对话 %s    因果 %s    封存权限 %s" % [photo, anchors.size(), dialogue, causal, "✓" if flags.get("scene02_permission", false) else "锁定"]
	for i in range(station_buttons.size()):
		station_buttons[i].modulate = CYAN if _station_done(i) else Color.WHITE
	queue_redraw()

func _station_done(index: int) -> bool:
	match index:
		0: return anchors.size() == 3
		1: return flags.get("scene02_timeline", false)
		2: return flags.get("scene02_dialogue", false)
		3: return int(flags.get("scene02_causal_count", 0)) >= 5
		4: return flags.get("scene02_complete", false)
	return false

func _draw() -> void:
	var stage := Rect2(40, 122, 1200, 438)
	plate(stage, Color("101d2a"))
	if background != null:
		draw_texture_rect(background, Rect2(0, 0, 1280, 720), false, Color(0.90, 0.98, 1.0, 0.93))
		draw_rect(Rect2(0, 0, 1280, 185), Color("07121d", 0.86))
		draw_rect(stage, CYAN.darkened(0.6), false, 2)
	else:
		# Perspective shelves and floor form a legible temporary room until scene art arrives.
		draw_rect(Rect2(43, 125, 1194, 220), Color("223848"))
		for x in range(88, 1230, 184):
			draw_rect(Rect2(x, 171, 145, 144), Color("101f2d"))
			draw_rect(Rect2(x, 171, 145, 144), Color("5e8193"), false, 2)
			draw_rect(Rect2(x + 23, 205, 98, 73), Color("d7d8cb"))
		for y in range(348, 558, 34):
			draw_line(Vector2(42, y), Vector2(1237, y), Color(0.34, 0.67, 0.72, 0.2), 1)
		draw_colored_polygon(PackedVector2Array([Vector2(41, 347), Vector2(1238, 347), Vector2(1238, 559), Vector2(41, 559)]), Color("152c38"))
		for x in range(55, 1240, 110):
			draw_line(Vector2(x, 559), Vector2(640 + (x - 640) * 0.23, 347), Color(0.46, 0.76, 0.80, 0.17), 2)
		for y in range(370, 559, 40):
			draw_line(Vector2(41, y), Vector2(1238, y), Color(0.46, 0.76, 0.80, 0.17), 2)
	for i in range(STATION_X.size()):
		var x: float = STATION_X[i]
		var active := _station_done(i)
		var color: Color = CYAN if active else GOLD if i == near_station else MUTED
		draw_rect(Rect2(x - 93, 251, 186, 39), Color("0c1c29"))
		draw_rect(Rect2(x - 93, 251, 186, 39), color, false, 2)
		draw_line(Vector2(x, 344), Vector2(x, 425), color.darkened(0.32), 2)
		draw_arc(Vector2(x, 442), 19, 0, TAU, 24, color, 2)
	draw_actor("心灵调理师", player + Vector2(0, 22), 86, Color(0.86, 0.97, 1.0), facing_left, sin(walk_clock) * 2.5 if walking_to or Input.get_vector("move_left", "move_right", "move_up", "move_down") != Vector2.ZERO else 0.0)
	draw_arc(player + Vector2(0, 13), 25, 0, TAU, 24, CYAN, 2)
	plate(Rect2(40, 565, 1200, 76))
