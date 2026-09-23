extends SceneTree

class Host:
	extends Control
	func sound(_cue: String) -> void:
		pass
	func restart() -> void:
		pass
	func go(_scene: String) -> void:
		pass

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var host := Host.new()
	root.add_child(host)
	var room: Control = load("res://scenes/archive_room.tscn").instantiate()
	host.add_child(room)
	await process_frame
	if not is_instance_valid(room):
		push_error("Archive room failed to instantiate")
		quit(1)
		return
	if room.comic_dialogue == null or not room.comic_dialogue.visible or room.comic_dialogue.speaker_label.text != "Ghost":
		push_error("Archive opening Ghost explanation did not use ComicDialogueLayer")
		quit(7)
		return
	room.call("_choose_photo", "林澈填写医学志愿")
	if room.flags.get("scene02_photo_count", 0) != 0:
		push_error("Wrong photo order advanced progress")
		quit(2)
		return
	for name in ["父亲参加乐队", "父亲收起吉他", "林澈参加游戏比赛", "林澈填写医学志愿"]:
		room.call("_choose_photo", name)
	room.call("inspect_archive_evidence", "photo")
	if not room.evidence_layer.visible:
		push_error("Archive photo did not open in EvidenceInspectLayer")
		quit(9)
		return
	room.evidence_layer._advance()
	room.evidence_layer._confirm()
	for name in ["比赛报名表", "医学院宣传册", "旧吉他拨片"]:
		room.call("inspect_archive_evidence", name)
		room.evidence_layer._advance()
		room.evidence_layer._confirm()
	room.call("_choose_dialogue", false)
	if room.flags.get("scene02_dialogue_part", 0) != 0:
		push_error("False dialogue advanced progress")
		quit(3)
		return
	room.call("_choose_dialogue", true)
	if room.comic_dialogue.speaker_label.text != "林澈":
		push_error("Archive formal Linche line did not use ComicDialogueLayer")
		quit(8)
		return
	room.call("_choose_dialogue", true)
	room.call("_choose_cause", "无法确认意愿")
	if room.flags.get("scene02_causal_count", 0) != 0:
		push_error("Wrong causal card advanced progress")
		quit(4)
		return
	for name in ["放弃梦想", "恐惧风险", "保护与限制", "推迟选择", "无法确认意愿"]:
		room.call("_choose_cause", name)
	room.call("_choose_judgment", false)
	if room.flags.get("scene02_permission", false):
		push_error("Wrong judgment granted permission")
		quit(5)
		return
	room.call("_choose_judgment", true)
	room.call("_seal_false_conclusion")
	if not room.flags.get("scene02_complete", false):
		push_error("Scene 02 did not complete")
		quit(6)
		return
	print("ARCHIVE_ROOM_SMOKE_PASS")
	quit()
