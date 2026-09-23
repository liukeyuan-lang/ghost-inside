extends "res://scripts/view.gd"

var reveal := false
var speech: Label

func _ready() -> void:
	setup("CASE 001 / 最终意识报告", "白色走廊停止自动延伸 · 自我意愿 ERROR → UNCONFIRMED")
	label_at("原始诊断", Vector2(70, 145), Vector2(210, 38), 20, MUTED)
	label_at("外部影响导致自我意愿异常", Vector2(70, 183), Vector2(500, 42), 25)
	label_at("修正诊断", Vector2(70, 252), Vector2(210, 38), 20, MUTED)
	label_at("把‘正确’作为确认意愿的前置条件", Vector2(70, 290), Vector2(610, 50), 27, CYAN)
	label_at("处理结果", Vector2(70, 365), Vector2(210, 38), 20, MUTED)
	label_at("未删除任何人格影响\n允许意愿暂未确定，并保留后续修正能力", Vector2(70, 403), Vector2(610, 82), 23)
	var report := report_copy(GameState.report_type)
	label_at(report, Vector2(760, 170), Vector2(430, 220), 22, GOLD)
	speech = label_at("Ghost：请选择目标人物的正确道路。\n\n（两个选择按钮逐渐消失。）", Vector2(90, 525), Vector2(900, 110), 22, PAPER)
	button_at("让林澈回答  →", Vector2(900, 568), Vector2(290, 58), reveal_reality)
	queue_redraw()

func reveal_reality() -> void:
	if reveal:
		get_parent().restart()
		return
	reveal = true
	speech.text = "林澈：我不知道。\n林澈：但这次，我想先弄清楚自己为什么选择。\n\n（他取下写着自己名字的身份牌。画面在任何人替他回答之前结束。）"
	var button: Button = ui.get_children().filter(func(node): return node is Button and node.text == "让林澈回答  →")[0]
	button.text = "重新接入案例  F2"
	get_parent().sound("change")
	queue_redraw()

func report_copy(kind: String) -> String:
	match kind:
		"responsibility":
			return "责任型理解\n\n你从关系和责任理解选择。\n外部影响具有价值，但不能代替选择归属。"
		"exploration":
			return "探索型理解\n\n你寻找被封存的自我。\n可能性值得恢复，但可能性本身不是答案。"
		_:
			return "融合型理解\n\n稳定、自由、责任与喜欢可以同时存在。\n不再要求矛盾提前给出正确答案。"

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), INK)
	draw_colored_polygon(PackedVector2Array([Vector2(0,720),Vector2(0,100),Vector2(560,350),Vector2(560,720)]),Color("e7eeee"))
	draw_colored_polygon(PackedVector2Array([Vector2(1280,720),Vector2(1280,100),Vector2(720,350),Vector2(720,720)]),Color("273348"))
	draw_rect(Rect2(560, 100, 160, 620), Color("0a1523"))
	draw_circle(Vector2(620, 420), 70, Color(0.4,0.85,0.82,0.12))
	draw_circle(Vector2(660, 420), 70, Color(0.91,0.69,0.35,0.1))
	draw_rect(Rect2(40, 120, 1200, 390), Color(0.03,0.07,0.1,0.9))
	draw_rect(Rect2(40, 510, 1200, 155), Color(0.03,0.07,0.1,0.95))
	if reveal:
		draw_actor("林澈", Vector2(640, 680), 235, Color.WHITE)
