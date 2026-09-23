extends "res://scripts/studio_room.gd"

const MIRROR_ORDER := ["奖状", "兄弟合照", "医学院宣传册", "毕业照"]
var saw_diary := false
var saw_card := false
var lamp_views := 0
var writer_known := false
var mirror_items: Array[String] = []
var mirror_complete := false
var removed_voices: Array[String] = []
var silence_known := false

func _ready() -> void:
	room_kind = "brother"
	open_room("05 / 林远的房间", "还原谁填写意向表、林远为何选择，以及林澈回答了什么。")
	if not has_flag("scene04_complete"):
		say("未来模型尚未证明结果的局限。先完成未来验证中心。")
		make_action("返回未来验证中心", 0, 0, func(): goto_scene("validation_center"))
		return
	make_action("查看林远的日记", 0, 0, inspect_diary)
	make_action("对照林澈的生日卡", 0, 1, inspect_card)
	make_action("调节台灯：15° / 45° / 75°", 0, 2, turn_lamp)
	make_action("放入镜中：优秀学生奖状", 0, 3, func(): place_mirror("奖状"))
	make_action("放入镜中：兄弟合照", 0, 4, func(): place_mirror("兄弟合照"))
	make_action("放入镜中：医学院宣传册", 0, 5, func(): place_mirror("医学院宣传册"))
	make_action("放入镜中：优秀毕业照", 1, 0, func(): place_mirror("毕业照"))
	make_action("移出声音：医学挺好的", 1, 1, func(): remove_voice("医学挺好的"))
	make_action("移出声音：选自己喜欢的", 1, 2, func(): remove_voice("你应该选自己喜欢的"))
	make_action("移出声音：不要学我", 1, 3, func(): remove_voice("不要学我"))
	make_action("确认林澈的真实回应", 1, 4, confirm_silence)
	make_action("前往自我手术室  →", 1, 5, finish_room)
	say("表格上的医学是真实的，但填写者与理由被噪点遮住。上关已证明公开结果不能解释意愿。")
	update_progress()

func inspect_diary() -> void:
	saw_diary = true
	say("林远日记：哥哥从来没有选错过。夹页写有三个光影角度：15°、45°、75°。")
	update_progress()

func inspect_card() -> void:
	saw_card = true
	say("林澈生日卡的笔画工整，还画了小星球。它可以与意向表上的字迹直接对照。")
	update_progress()

func turn_lamp() -> void:
	if not saw_diary or not saw_card:
		say("先查看日记的三个角度，再取得林澈的生日卡作笔迹对照。")
		return
	if lamp_views >= 3:
		say("三个角度都已检查。意向表签名是林远，不是林澈。")
		return
	lamp_views += 1
	if lamp_views == 1:
		say("15°：意向表有反复描摹的压力痕。")
	elif lamp_views == 2:
		say("45°：表格笔画与林澈的生日卡不同。")
	else:
		writer_known = true
		say("75°：被遮住的签名显影——林远。林澈没有代填志愿。")
	update_progress()

func place_mirror(item: String) -> void:
	if not writer_known:
		say("先确认填写者。否则镜中的脚印可能被误认成哥哥的命令。")
		return
	if mirror_complete:
		say("镜中轨迹已经复原。林远主动踩着哥哥的脚印，并没有人推他。")
		return
	var next := mirror_items.size()
	if item != MIRROR_ORDER[next]:
		mirror_items.clear()
		say("镜中脚印错位，出现可见的时序噪点：请从最早的奖状开始，按人生阶段排列。")
	else:
		mirror_items.append(item)
		if mirror_items.size() == 4:
			mirror_complete = true
			say("镜中轨迹完整：林远自己走进医学脚印。理由显影：因为哥哥没有选错过。那只是公开结果，不是哥哥的选择理由。")
		else:
			say("轨迹第 %d/4 步吻合：%s。" % [mirror_items.size(), item])
	update_progress()
	queue_redraw()

func remove_voice(voice: String) -> void:
	if not mirror_complete:
		say("先还原林远为什么选择，记忆才会播放到林澈回应的位置。")
		return
	if frequency != 1:
		say("这几句听上去都合理。切到情绪层，检查当晚是否真的有人说话。")
		return
	if removed_voices.has(voice):
		say("这句未经证实的补写台词已移出回应槽。")
		return
	removed_voices.append(voice)
	say("“%s”没有当晚的声纹证据，已从回应槽移出。还剩 %d 句候选。" % [voice, 3 - removed_voices.size()])
	update_progress()

func confirm_silence() -> void:
	if removed_voices.size() < 3 or frequency != 1:
		say("情绪层仍有未经验证的补写声音。逐一移出三句，听完时钟。")
		return
	silence_known = true
	write_flag("scene05_complete")
	GameState.will_dossier["填写者"] = "林远"
	GameState.will_dossier["选择理由_林远"] = "因为哥哥没有选错过"
	GameState.will_dossier["首次直接询问"] = "无法回答"
	GameState.will_dossier["异常触发"] = "自我意愿识别失败"
	say("时钟经过 7.4 秒，林澈心跳加快，林远仍在等待——没有语言。林远问：你当时怎么知道想当医生？林澈：因为……。芯片报错。")
	update_progress()

func finish_room() -> void:
	if not silence_known:
		say("尚未确认 7.4 秒沉默。林澈没有逼弟弟学医；直接触发异常的是弟弟的提问。")
		return
	goto_scene("surgery_room")

func update_progress() -> void:
	if is_instance_valid(progress):
		progress.text = "意愿档案 · 结果不能反推意愿  /  填写者：%s  /  镜中轨迹：%d/4  /  候选声音已移出：%d/3" % ["林远" if writer_known else "待确认", mirror_items.size(), removed_voices.size()]
