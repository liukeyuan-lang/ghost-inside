extends "res://scripts/studio_room.gd"

const EVIDENCE_NAMES := [
	"A 父亲的影响复杂且有价值",
	"B 林澈亲自封存游戏项目",
	"C 人生结果无法证明意愿",
	"D 林澈无法向弟弟说明选择"
]
var active_simulation := -1
var observed_simulations: Array[int] = []
var evidence_loaded: Array[int] = []
var self_loop_seen := false
var ring_rotated := false

func _ready() -> void:
	room_kind = "surgery"
	open_room("06 / 自我手术室", "暂时切断影响、运行反例。所有线路可以恢复；不能以删除人物或记忆结案。")
	if not has_flag("scene05_complete"):
		say("林远的直接提问还未还原。先完成他的房间。")
		make_action("返回林远的房间", 0, 0, func(): goto_scene("brother_room"))
		return
	make_action("模拟：暂切父亲线路 / 恢复", 0, 0, func(): run_simulation(0))
	make_action("模拟：强化游戏线路 / 恢复", 0, 1, func(): run_simulation(1))
	make_action("模拟：无限时间金钱 / 恢复", 0, 2, func(): run_simulation(2))
	make_action("证据 A：父亲双重影响", 0, 3, func(): load_evidence(0))
	make_action("证据 B：林澈亲自封存", 0, 4, func(): load_evidence(1))
	make_action("证据 C：结果不等于意愿", 0, 5, func(): load_evidence(2))
	make_action("证据 D：弟弟提问触发", 1, 0, func(): load_evidence(3))
	make_action("情绪层：检查透明回路", 1, 1, inspect_loop)
	make_action("保持：必须确认正确答案", 1, 2, keep_diagnosis)
	make_action("旋转：允许意愿暂未确定", 1, 3, rotate_ring)
	make_action("查看意识报告  →", 1, 5, finish_room)
	say("Ghost：请选择要删除的错误影响。先运行可撤回的模拟；看异常是否消失。")
	update_progress()

func run_simulation(index: int) -> void:
	if active_simulation >= 0 and active_simulation != index:
		say("仍有一条模拟线路被暂切。再次点击同一模拟，恢复后才能检查另一条。")
		return
	if active_simulation == index:
		active_simulation = -1
		if not observed_simulations.has(index):
			observed_simulations.append(index)
		say("模拟结束，线路已恢复。影响没有被删除；反例已写入意愿档案。")
	else:
		active_simulation = index
		match index:
			0:
				say("暂切父亲线路：林澈仍要求系统判断医学或游戏哪条更不会后悔。异常继续。父亲影响不是全部原因。再次点击恢复。")
			1:
				say("强化游戏线路：第一次项目失败后，林澈再次要求系统决定是否继续。异常继续。恢复梦想不等于恢复选择能力。再次点击恢复。")
			2:
				say("提供无限时间与金钱：可以同时尝试，但他仍要求系统选出最终正确人生。异常继续。再次点击恢复。")
	update_progress()
	queue_redraw()

func load_evidence(index: int) -> void:
	if observed_simulations.size() < 3 or active_simulation >= 0:
		say("先完成三次模拟，并恢复暂切线路；不能在被改写的状态下做最终诊断。")
		return
	var valid := false
	match index:
		0:
			valid = not str(GameState.will_dossier.get("外部影响", "")).is_empty()
		1:
			valid = str(GameState.will_dossier.get("执行人", "")) == "林澈"
		2:
			valid = has_flag("scene04_complete")
		3:
			valid = str(GameState.will_dossier.get("异常触发", "")) == "自我意愿识别失败"
	if not valid:
		say("这条核心证据还没有在前一场景被核实，不能凭空放入手术台。")
		return
	if evidence_loaded.has(index):
		say("这条证据已归位。")
		return
	evidence_loaded.append(index)
	say("已放入 %s。%s" % [EVIDENCE_NAMES[index], "四份证据都已归位；情绪层出现一条连回林澈自己的透明线路。" if evidence_loaded.size() == 4 else "继续放入其余已核实的证据。"])
	if evidence_loaded.size() == 4:
		write_flag("surgery_evidence")
	update_progress()
	queue_redraw()

func inspect_loop() -> void:
	if evidence_loaded.size() < 4:
		say("透明线路仍被遮住。需要四份来自不同场景的核心证据。")
		return
	if frequency != 1:
		say("这条线路不是文件记录；切到情绪层看回路。")
		return
	self_loop_seen = true
	say("如果不能保证正确 → 不确认选择属于自己 → 寻找外部证明 → 仍不能保证正确。这条回路没有可以删除的主人。")
	update_progress()

func keep_diagnosis() -> void:
	if not self_loop_seen:
		say("先在情绪层看见透明回路，再检查诊断条件。")
	else:
		say("保持“必须确认正确答案”会继续把不确定判为 ERROR；这与三次模拟和四份证据冲突。")

func rotate_ring() -> void:
	if not self_loop_seen or active_simulation >= 0:
		say("还不能旋转。恢复模拟线路，放入四份证据并看清透明回路。")
		return
	ring_rotated = true
	write_flag("scene06_complete")
	GameState.will_dossier["修正诊断"] = "将正确作为确认意愿的前置条件"
	GameState.will_dossier["处理结果"] = "未删除人格影响；解除必须保证正确的诊断条件"
	GameState.will_dossier["意愿归属"] = "UNCONFIRMED"
	say("诊断环旋转：自我意愿 ERROR → UNCONFIRMED。Ghost：没有需要删除的单一影响。治疗不能替代选择。")
	update_progress()
	queue_redraw()

func finish_room() -> void:
	if not ring_rotated:
		say("手术尚未完成。不要替林澈选择职业，也不要删除父亲或被放弃的可能。")
		return
	goto_scene("finale")

func update_progress() -> void:
	if is_instance_valid(progress):
		progress.text = "意愿档案 · 反例：%d/3  /  核心证据：%d/4  /  自我回路：%s  /  诊断：%s" % [observed_simulations.size(), evidence_loaded.size(), "已见" if self_loop_seen else "未见", "UNCONFIRMED" if ring_rotated else "ERROR"]
