extends Node

var data: Dictionary = {}
var load_error := ""
var stage := "start"
var inspected: Array[String] = []
var applause_off := false
var evidence: Dictionary = {}
var sync_nodes := 3
var segment := 0
var selected: Dictionary = {}
var free_text := ""
var submissions := 0
var result: Dictionary = {}
var offline := true
var demo_mode := false
var online_mode := false
var interruptions := 0
var trace: Array[String] = []

# Six-room investigation state.  The legacy fields above stay available so old
# resources can still be imported, but the main route only uses this contract.
var current_scene_id := "scene01_white_corridor"
var current_band := "fact"
var flags: Dictionary = {}
var dossier: Dictionary = {}
var tendency: Dictionary = {}
var inventory: Array[String] = []
var placements: Dictionary = {}
var device_seen: Dictionary = {}
var completed_once: Dictionary = {}
var hint_levels: Dictionary = {}
var report_type := "balance"
var first_tendency := ""

func _ready() -> void:
	var raw = JSON.parse_string(FileAccess.get_file_as_string("res://data/cases/white_corridor.json"))
	if raw is Dictionary and raw.has("cards") and raw.has("fallbacks"):
		data = raw
	else:
		load_error = "案例文件缺失或格式错误，无法建立连接。"
	reset_case()
	var keys := {"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT], "move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN], "interact": [KEY_E, KEY_ENTER], "pulse": [KEY_SPACE], "restart": [KEY_F2], "band_fact": [KEY_1], "band_emotion": [KEY_2], "band_expectation": [KEY_3]}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for code in keys[action]:
			var event := InputEventKey.new()
			event.physical_keycode = code
			InputMap.action_add_event(action, event)
			var logical := InputEventKey.new()
			logical.keycode = code
			InputMap.action_add_event(action, logical)

func reset_case() -> void:
	stage = "start"
	inspected.clear()
	applause_off = false
	evidence.clear()
	sync_nodes = 3
	segment = 0
	selected.clear()
	free_text = ""
	submissions = 0
	result.clear()
	offline = true
	interruptions = 0
	trace.clear()
	current_scene_id = "scene01_white_corridor"
	current_band = "fact"
	flags.clear()
	dossier = {
		"选择结果": "医学",
		"执行人": "待确认",
		"外部影响": "待确认",
		"被放弃可能": "待确认",
		"选择理由": "空白",
		"意愿归属": "无法确认",
	}
	tendency = {"responsibility": 0, "exploration": 0, "balance": 0}
	inventory.clear()
	placements.clear()
	device_seen.clear()
	completed_once.clear()
	hint_levels.clear()
	report_type = "balance"
	first_tendency = ""

func unlock_evidence(id: String) -> void:
	evidence[id] = true

func active_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in evidence:
		if evidence[id]:
			ids.append(id)
	return ids

func blur_evidence() -> void:
	for id in evidence:
		evidence[id] = false
	segment = 0
	sync_nodes = 3

func set_agent_result(value: Dictionary) -> void:
	result = value.duplicate(true)

func has_flag(id: String) -> bool:
	return bool(flags.get(id, false))

func write_flag(id: String) -> void:
	if not id.is_empty():
		flags[id] = true

func placement_key(scene_id: String, group_id: String) -> String:
	return scene_id + "/" + group_id

func placement(scene_id: String, group_id: String) -> Array:
	var key := placement_key(scene_id, group_id)
	if not placements.has(key):
		placements[key] = []
	return placements[key]

func record_tendency(kind: String) -> void:
	if tendency.has(kind):
		if first_tendency.is_empty():
			first_tendency = kind
		tendency[kind] = int(tendency[kind]) + 1

func choose_report_type() -> String:
	if first_tendency in ["responsibility", "exploration", "balance"]:
		report_type = first_tendency
		return report_type
	var responsibility := int(tendency.get("responsibility", 0))
	var exploration := int(tendency.get("exploration", 0))
	if responsibility >= exploration + 3:
		report_type = "responsibility"
	elif exploration >= responsibility + 3:
		report_type = "exploration"
	else:
		report_type = "balance"
	return report_type

func local_result(kind: String) -> Dictionary:
	var value: Dictionary = data.fallbacks[kind].duplicate(true)
	value.result = kind
	value.evidence_ids = value.evidence_ids.filter(func(id): return evidence.get(id, false))
	return value
