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
var case_flags: Dictionary = {}
var will_dossier: Dictionary = {}

func _ready() -> void:
	var raw = JSON.parse_string(FileAccess.get_file_as_string("res://data/cases/white_corridor.json"))
	if raw is Dictionary and raw.has("cards") and raw.has("fallbacks"):
		data = raw
	else:
		load_error = "案例文件缺失或格式错误，无法建立连接。"
	reset_case()
	var keys := {"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT], "move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN], "interact": [KEY_E, KEY_ENTER], "pulse": [KEY_SPACE], "vision": [KEY_Q], "restart": [KEY_F2]}
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
	case_flags.clear()
	will_dossier.clear()

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

func local_result(kind: String) -> Dictionary:
	var value: Dictionary = data.fallbacks[kind].duplicate(true)
	value.result = kind
	value.evidence_ids = value.evidence_ids.filter(func(id): return evidence.get(id, false))
	return value
