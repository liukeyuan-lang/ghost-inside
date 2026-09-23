extends "res://scripts/studio_room.gd"

var linyu_public := false
var drawer_open := false
var linyu_hidden := false
var chenmo_public := false
var chenmo_back := false
var chenmo_hidden := false
var stamped := false

func _ready() -> void:
	room_kind = "validation"
	open_room("04 / 未来验证中心", "将两个人生参考模型送入模拟器。结果能反推林澈当初的意愿吗？")
	if not has_flag("scene03_complete"):
		say("项目封存的执行人尚未确认。先完成废弃游戏工作室。")
		make_action("返回游戏工作室", 0, 0, func(): goto_scene("studio_room"))
		return
	make_action("林宇：放入公开履历", 0, 0, inspect_linyu_public)
	make_action("林宇：寻找隐藏抽屉", 0, 1, find_drawer)
	make_action("林宇：放入摄影作品", 0, 2, inspect_linyu_hidden)
	make_action("陈默：放入失败资料", 0, 3, inspect_chenmo_public)
	make_action("陈默：检查关闭通知背面", 0, 4, inspect_chenmo_back)
	make_action("陈默：放入录音与后续", 0, 5, inspect_chenmo_hidden)
	make_action("盖章：稳定人生正确", 1, 0, func(): stamp("stable"))
	make_action("盖章：自由人生正确", 1, 1, func(): stamp("free"))
	make_action("翻转印章：无法由结果反推意愿", 1, 2, func(): stamp("reverse"))
	make_action("前往林远的房间  →", 1, 5, finish_room)
	say("意愿档案已写明：项目由林澈亲自封存。这里的模型只是参照，不是林澈确定的未来。")
	update_progress()

func inspect_linyu_public() -> void:
	linyu_public = true
	say("晋升、家庭合照、收入记录均属实。稳定 95，评价 92，安全 90；系统仍给出 98，缺了某种变量。")
	update_progress()

func find_drawer() -> void:
	if not linyu_public:
		say("先将林宇的公开资料放入模拟器，才能检查缺失变量。")
		return
	if frequency != 1:
		say("公开资料看不到抽屉。情绪层的相机快门声指出它的位置。")
		return
	drawer_open = true
	say("相机快门声来自桌内。抽屉里有林宇多年未公开的摄影作品。")
	update_progress()

func inspect_linyu_hidden() -> void:
	if not drawer_open:
		say("摄影作品还藏在抽屉里。")
		return
	linyu_hidden = true
	say("照片背面：如果那年没有回来，我现在会在哪里。林宇：偶尔遗憾，但遗憾不能证明我选错。正确率变成无法计算。")
	update_progress()

func inspect_chenmo_public() -> void:
	chenmo_public = true
	say("投资终止、工作室关闭、项目未完成；系统判定人生正确率 12。它仍提示有遗漏变量。")
	update_progress()

func inspect_chenmo_back() -> void:
	if not chenmo_public:
		say("先放入陈默的公开失败资料。")
		return
	if frequency != 0:
		say("关闭通知背面的文件是实际记录，请切到事实层。")
		return
	chenmo_back = true
	say("关闭通知背面是新公司入职邀请。旧项目的经验也进入了下一版本。失败不是人生终止。")
	update_progress()

func inspect_chenmo_hidden() -> void:
	if not chenmo_back:
		say("先确认关闭通知背面，找出失败之后发生了什么。")
		return
	chenmo_hidden = true
	say("陈默：我不后悔做过。但再来一次，我不会用同样方法。自由不是让失败值得，而是继续处理结果。")
	update_progress()

func stamp(choice: String) -> void:
	if not linyu_hidden or not chenmo_hidden:
		say("两个模型都有未检查的隐藏变量，不能先给林澈盖章。")
		return
	if choice == "stable":
		if not GameState.case_flags.has("report_focus"):
			GameState.case_flags["report_focus"] = "responsibility"
		say("反例：林宇有稳定成果，也有未完成感。良好结果不能证明初始意愿。")
		return
	if choice == "free":
		if not GameState.case_flags.has("report_focus"):
			GameState.case_flags["report_focus"] = "exploration"
		say("反例：陈默的项目失败，却继续生活。被放弃的可能也不能自动成为林澈的真实意愿。")
		return
	if not GameState.case_flags.has("report_focus"):
		GameState.case_flags["report_focus"] = "fusion"
	stamped = true
	write_flag("scene04_complete")
	GameState.will_dossier["稳定结果"] = "不能证明正确"
	GameState.will_dossier["失败结果"] = "不能证明错误"
	GameState.will_dossier["选择理由"] = "仍空白"
	say("印章背面：无法由结果反推意愿。两个模型都不能替林澈回答当时为什么选择。")
	update_progress()

func finish_room() -> void:
	if not stamped:
		say("仍需检查两个模型的隐藏变量，并翻转结果印章。")
		return
	goto_scene("brother_room")

func update_progress() -> void:
	if is_instance_valid(progress):
		progress.text = "意愿档案 · 执行人：%s  /  林宇隐藏变量：%s  /  陈默隐藏变量：%s  /  结论：%s" % [str(GameState.will_dossier.get("执行人", "?")), "已见" if linyu_hidden else "未见", "已见" if chenmo_hidden else "未见", "结果≠意愿" if stamped else "待判断"]
