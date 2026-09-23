extends "res://scripts/view.gd"
var reality := false
var reveal := 0.0
var speech: Label

func _ready() -> void:
	get_parent().sound("change")
	setup("04 / 意愿档案重分类", "没有删除父亲、游戏或医学。保护机制仍然存在，但不再把未知强制写成错误。")
	var kind: String = GameState.result.get("result", "hold")
	var exit_name: String = {"accept": "开始对话", "revise": "带着矛盾前进", "hold": "暂时退出"}[kind]
	label_at(exit_name, Vector2(430, 150), Vector2(720, 72), 46, CYAN if kind == "accept" else GOLD)
	label_at({"accept": "价值清算者拆成纸页，胸口的秤停止向亏欠倾斜。", "revise": "价值清算者放下账本，仍保留提醒风险的裂纹。", "hold": "价值清算者停止封路，允许这份未知暂时存在。"}[kind], Vector2(430, 238), Vector2(740, 78), 24)
	label_at("SELF_INTENT  ERROR  →  UNCONFIRMED", Vector2(430, 324), Vector2(740, 36), 22, RED if kind == "revise" else CYAN)
	label_at("被采用的种子" if kind != "hold" else "暂时保留的种子", Vector2(430, 368), Vector2(740, 38), 21, CYAN)
	label_at(GameState.result.get("response", ""), Vector2(430, 408), Vector2(740, 110), 23)
	label_at("仍未解决：医学、游戏、家庭期待，以及父亲是否理解。", Vector2(430, 530), Vector2(740, 58), 21, MUTED)
	button_at("回到现实  →", Vector2(430, 624), Vector2(500, 60), show_reality).grab_focus()
	queue_redraw()

func show_reality() -> void:
	reality = true
	for child in ui.get_children():
		child.queue_free()
	label_at("现实 / 第一次承认不知道", Vector2(85, 65), Vector2(1100, 80), 36, GOLD)
	portrait_at("lin_che", Vector2(20, 145), Vector2(330, 460), Color(0.75, 0.85, 0.92, 0.34), true)
	portrait_at("lin_father", Vector2(930, 145), Vector2(330, 460), Color(0.72, 0.68, 0.64, 0.30), true)
	label_at(GameState.data.ending.action, Vector2(255, 200), Vector2(770, 90), 25, MUTED)
	speech = label_at("“%s”" % GameState.data.ending.line, Vector2(255, 325), Vector2(780, 165), 32)
	speech.visible_characters = 0
	label_at("父亲抬起手，碰到衣服里的旧拨片。画面在他回应前结束。", Vector2(255, 525), Vector2(800, 62), 21, MUTED)
	button_at("重新体验 / F2", Vector2(440, 620), Vector2(400, 60), func(): get_parent().restart())
	queue_redraw()

func _process(delta: float) -> void:
	if reality and is_instance_valid(speech):
		reveal += delta * 15
		speech.visible_characters = int(reveal)

func _draw() -> void:
	if reality:
		draw_rect(Rect2(0, 0, 1280, 720), Color("11171e"))
		draw_line(Vector2(82, 178), Vector2(1190, 178), GOLD, 2)
		draw_line(Vector2(250, 306), Vector2(1030, 306), Color("355161"), 1)
	else:
		plate(Rect2(42, 135, 335, 540))
		var kind: String = GameState.result.get("result", "hold")
		var tint: Color = {"accept": Color(0.48, 0.92, 0.88, 0.82), "revise": Color(0.94, 0.68, 0.39, 0.86), "hold": Color(0.60, 0.66, 0.72, 0.78)}[kind]
		var monster_height: float = {"accept": 360.0, "revise": 430.0, "hold": 395.0}[kind]
		draw_actor("defense_construct", Vector2(212, 620), monster_height, tint)
		if kind == "accept":
			for y in [300, 360, 420, 480]:
				draw_line(Vector2(95, y), Vector2(330, y + 25), PAPER.darkened(0.25), 2)
