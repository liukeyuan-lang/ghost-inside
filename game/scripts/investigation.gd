extends "res://scripts/view.gd"

const BANDS := ["fact", "emotion", "expectation"]
const BAND_NAMES := {"fact": "事实", "emotion": "情绪", "expectation": "期待"}
const BAND_COLORS := {
	"fact": Color("79d7e8"),
	"emotion": Color("e47886"),
	"expectation": Color("e9b86b"),
}
const STAGE := Rect2(40, 122, 1200, 438)
const OFFICE_CARPET: Texture2D = preload("res://assets/map/office_carpet.png")
const STUDIO_BG: Texture2D = preload("res://assets/scenes/scene03/bg_generated.png")

var spec: Dictionary = {}
var scene_id := ""
var player := Vector2.ZERO
var speed := 255.0
var selected_item := ""
var message_label: Label
var prompt_label: Label
var inventory_box: HBoxContainer
var dossier_panel: Panel
var dossier_label: Label
var choice_panel: Panel
var map_buttons: Array[Control] = []
var nearby: Dictionary = {}
var first_inspection_order: Array[String] = []
var completion_announced := false
var ending_ready := false

func _ready() -> void:
	scene_id = GameState.current_scene_id
	var path := "res://data/scenes/%s.json" % scene_id
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		GameState.load_error = "场景数据无法读取：" + scene_id
		get_parent().call_deferred("go", "start")
		return
	spec = parsed
	GameState.stage = scene_id
	var spawn: Array = spec.get("spawn", {}).get("pos", [180, 470])
	player = Vector2(float(spawn[0]), float(spawn[1]))
	setup(str(spec.get("title", "意识空间")), "三频段调查 / 物证吸附 / 意愿档案持续写入")
	build_interface()
	initialize_groups()
	refresh_all()
	check_completion(false)
	ending_ready = scene_id == "scene01_white_corridor" and GameState.has_flag("scene06_complete")
	if ending_ready:
		show_message("白色走廊停止延伸。医院白光与小星球微光之间，出现一片尚未形成的区域。", "结案")
	queue_redraw()

func build_interface() -> void:
	for index in range(BANDS.size()):
		var band: String = BANDS[index]
		var button := button_at("%d  %s" % [index + 1, BAND_NAMES[band]], Vector2(470 + index * 150, 23), Vector2(138, 50), func(): set_band(band))
		button.add_theme_font_size_override("font_size", 18)
	var dossier_button := button_at("意愿档案", Vector2(912, 23), Vector2(178, 50), toggle_dossier)
	dossier_button.add_theme_font_size_override("font_size", 18)
	message_label = label_at("", Vector2(62, 579), Vector2(790, 84), 19, PAPER)
	prompt_label = label_at("", Vector2(62, 665), Vector2(780, 30), 16, MUTED)
	inventory_box = HBoxContainer.new()
	inventory_box.position = Vector2(855, 578)
	inventory_box.size = Vector2(380, 118)
	inventory_box.add_theme_constant_override("separation", 5)
	ui.add_child(inventory_box)

	dossier_panel = Panel.new()
	dossier_panel.position = Vector2(840, 96)
	dossier_panel.size = Vector2(400, 462)
	dossier_panel.visible = false
	ui.add_child(dossier_panel)
	var dossier_title := Label.new()
	dossier_title.text = "意愿档案 / WILL DOSSIER"
	dossier_title.position = Vector2(20, 16)
	dossier_title.size = Vector2(350, 35)
	dossier_title.add_theme_font_size_override("font_size", 23)
	dossier_title.add_theme_color_override("font_color", CYAN)
	dossier_panel.add_child(dossier_title)
	dossier_label = Label.new()
	dossier_label.position = Vector2(20, 58)
	dossier_label.size = Vector2(360, 330)
	dossier_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dossier_label.add_theme_font_size_override("font_size", 18)
	dossier_panel.add_child(dossier_label)
	var close := Button.new()
	close.text = "关闭"
	close.position = Vector2(250, 398)
	close.size = Vector2(120, 44)
	close.pressed.connect(toggle_dossier)
	dossier_panel.add_child(close)

	choice_panel = Panel.new()
	choice_panel.position = Vector2(330, 185)
	choice_panel.size = Vector2(620, 330)
	choice_panel.visible = false
	ui.add_child(choice_panel)

func initialize_groups() -> void:
	for raw_group in spec.get("slot_groups", []):
		var group: Dictionary = raw_group
		for raw_item in group.get("accepts", []):
			var item_id := str(raw_item)
			if GameState.evidence.get(item_id, false) and not item_id in GameState.inventory:
				GameState.inventory.append(item_id)
		if str(group.get("type", "")) == "exclusion":
			var key := GameState.placement_key(scene_id, str(group.id))
			if not GameState.placements.has(key):
				GameState.placements[key] = Array(group.get("initial_items", group.get("must_remove", []))).duplicate()

func _process(delta: float) -> void:
	if choice_panel.visible or dossier_panel.visible:
		return
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if direction.length_squared() > 0.01:
		player += direction.normalized() * speed * delta
		player = clamp_to_walkable(player)
	update_nearby()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("band_fact"):
		set_band("fact")
	elif event.is_action_pressed("band_emotion"):
		set_band("emotion")
	elif event.is_action_pressed("band_expectation"):
		set_band("expectation")
	elif event.is_action_pressed("interact") and not choice_panel.visible and not dossier_panel.visible:
		activate_nearby()
	elif event.is_action_pressed("pulse"):
		show_hint()

func clamp_to_walkable(point: Vector2) -> Vector2:
	var best := point
	var best_distance := INF
	for raw in spec.get("walkable", []):
		var values: Array = raw.get("rect", [100, 350, 1080, 170])
		var rect := Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3]))
		var candidate := Vector2(clampf(point.x, rect.position.x, rect.end.x), clampf(point.y, rect.position.y, rect.end.y))
		var distance := candidate.distance_squared_to(point)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best

func set_band(band: String) -> void:
	if not band in BANDS:
		return
	GameState.current_band = band
	get_parent().sound("change")
	show_message("频段切换：%s。场景几何保持不变，隐藏信息正在重新显影。" % BAND_NAMES[band], "频段")
	refresh_all()

func update_nearby() -> void:
	var candidate: Dictionary = {}
	var best := INF
	for raw_object in spec.get("objects", []):
		var object: Dictionary = raw_object
		if not object_visible(object):
			continue
		var pos := vec2(object.get("pos", [0, 0]))
		var distance := player.distance_to(pos)
		var radius := maxf(float(object.get("interact_radius", 80)), 155.0)
		if distance <= radius and distance < best:
			best = distance
			candidate = {"kind": "object", "data": object}
	for raw_group in spec.get("slot_groups", []):
		var group: Dictionary = raw_group
		var distance := player.distance_to(vec2(group.get("pos", [0, 0])))
		if distance <= 185.0 and distance < best:
			best = distance
			candidate = {"kind": "group", "data": group}
	for raw_npc in normalize_array(spec.get("npcs", [])):
		var npc: Dictionary = raw_npc
		var distance := player.distance_to(vec2(npc.get("pos", [0, 0])))
		if distance <= 175.0 and distance < best:
			best = distance
			candidate = {"kind": "npc", "data": npc}
	nearby = candidate
	if nearby.is_empty():
		prompt_label.text = "WASD / 方向键移动   1/2/3 切频段   E/Enter 调查   Space 提示   F2 重开"
	else:
		var data: Dictionary = nearby.data
		prompt_label.text = "E / Enter：" + str(data.get("name", data.get("id", "互动")))

func activate_nearby() -> void:
	if nearby.is_empty():
		show_message("附近没有可交互目标。按 Space 查看当前谜题提示。", "Ghost")
		return
	var kind: String = nearby.kind
	var data: Dictionary = nearby.data
	if kind == "object":
		interact_object_by_id(str(data.id))
	elif kind == "group":
		activate_group(str(data.id))
	elif kind == "npc":
		interact_npc(data)

func interact_object_by_id(object_id: String) -> void:
	var object := find_object(object_id)
	if object.is_empty() or not object_visible(object):
		return
	get_parent().sound("interact")
	if not object_id in GameState.inspected:
		GameState.inspected.append(object_id)
		first_inspection_order.append(object_id)
		GameState.record_tendency(str(object.get("tendency", "balance")))
	var text := str(object.get("inspect_text", "没有更多记录。"))
	var frequency: Array = object.get("frequency_text", [])
	var band_index := BANDS.find(GameState.current_band)
	if band_index >= 0 and frequency.size() > band_index:
		text += "\n[%s] %s" % [BAND_NAMES[GameState.current_band], str(frequency[band_index])]
	var hidden: Dictionary = object.get("hidden", {})
	if str(hidden.get("band", "")) == GameState.current_band:
		text += "\n显影：" + str(hidden.get("reveal", ""))
	if bool(object.get("takeable", false)) and not object_id in GameState.inventory and not is_item_placed(object_id):
		GameState.inventory.append(object_id)
		selected_item = object_id
		text += "\n已取得物证；当前手持：" + str(object.get("name", object_id))
		run_trace("调用工具", "拾取 " + object_id)
	var conditional: Dictionary = object.get("conditional_interact", {})
	if not conditional.is_empty() and not GameState.has_flag(str(conditional.get("writes_flag", ""))):
		if requirements_met(conditional.get("requires_flags", [])) and (str(conditional.get("requires_band", "")) in ["", GameState.current_band]):
			GameState.write_flag(str(conditional.get("writes_flag", "")))
			text += "\n" + str(conditional.get("text", "隐藏记录已恢复。"))
			get_parent().sound("evidence")
			run_trace("引用证据", str(conditional.get("writes_flag", "")))
			check_completion()
		elif requirements_met(conditional.get("requires_flags", [])) and not str(conditional.get("requires_band", "")).is_empty():
			text += "\n需要切换到%s频段。" % BAND_NAMES.get(str(conditional.requires_band), str(conditional.requires_band))
	show_message(text, str(object.get("name", object_id)))
	refresh_all()

func interact_npc(npc: Dictionary) -> void:
	var lines: Array = npc.get("lines", [])
	var text := "记忆投影保持冻结。"
	if not lines.is_empty():
		text = "\n".join(lines.map(func(line): return str(line)))
	show_message(text, str(npc.get("character", "投影")))

func activate_group(group_id: String) -> void:
	var group := find_group(group_id)
	if group.is_empty():
		return
	if group_complete(group):
		show_message("该推理已经成立：" + completion_story(group), str(group_id))
		return
	if not requirements_met(group.get("requires_flags", [])):
		show_message("前置证据不足。先完成上一层验证。", "Ghost")
		return
	match str(group.get("type", "")):
		"sequence", "set", "single":
			place_selected(group)
		"device":
			advance_device(group)
		"choice":
			show_choice(group)
		"exclusion":
			remove_exclusion(group)

func place_selected(group: Dictionary) -> void:
	if selected_item.is_empty() or not selected_item in GameState.inventory:
		show_message("请先调查并选择一件可移动物证。", "吸附槽")
		return
	var accepts: Array = group.get("accepts", [])
	if not selected_item in accepts:
		show_message(str(group.get("wrong_feedback", "这件物证不属于该槽位。")), "冲突")
		get_parent().sound("impact")
		return
	var placed: Array = GameState.placement(scene_id, str(group.id))
	if selected_item in placed:
		show_message("这件物证已经放入当前装置。", "吸附槽")
		return
	placed.append(selected_item)
	GameState.placements[GameState.placement_key(scene_id, str(group.id))] = placed
	var placed_name := str(find_object(selected_item).get("name", selected_item))
	show_message("已放入：%s（%d/%d）" % [placed_name, placed.size(), int(group.get("slots", accepts.size()))], str(group.id))
	get_parent().sound("evidence")
	if placed.size() >= int(group.get("slots", accepts.size())):
		var correct := true
		if str(group.get("type", "")) == "sequence":
			correct = placed == Array(group.get("correct_order", []))
		else:
			for item in accepts:
				if not item in placed:
					correct = false
		if correct:
			complete_group(group)
		else:
			GameState.placements[GameState.placement_key(scene_id, str(group.id))] = []
			show_message(str(group.get("wrong_feedback", "顺序或组合不成立；物证已退回。")), "发现冲突")
			get_parent().sound("impact")
	refresh_all()

func advance_device(group: Dictionary) -> void:
	var key := GameState.placement_key(scene_id, str(group.id))
	var seen: Array = GameState.device_seen.get(key, [])
	var states: Array = group.get("states", [])
	var reveals: Array = group.get("state_reveals", [])
	if states.is_empty():
		return
	var index := seen.size() % states.size()
	if not index in seen:
		seen.append(index)
	GameState.device_seen[key] = seen
	var text := str(states[index])
	if reveals.size() > index:
		text += "\n" + str(reveals[index])
	show_message(text, str(group.id))
	get_parent().sound("change")
	if seen.size() >= states.size():
		complete_group(group)
	refresh_all()

func remove_exclusion(group: Dictionary) -> void:
	var key := GameState.placement_key(scene_id, str(group.id))
	var contents: Array = GameState.placements.get(key, []).duplicate()
	if contents.is_empty():
		complete_group(group)
		return
	var removed: String = str(contents.pop_front())
	GameState.placements[key] = contents
	show_message("移出候选声音：%s。剩余 %d 段。" % [str(find_object(removed).get("name", removed)), contents.size()], "记忆验证")
	get_parent().sound("change")
	if contents.is_empty():
		complete_group(group)
	refresh_all()

func show_choice(group: Dictionary) -> void:
	for child in choice_panel.get_children():
		child.queue_free()
	choice_panel.visible = true
	var heading := Label.new()
	heading.text = "选择验证方式"
	heading.position = Vector2(28, 22)
	heading.size = Vector2(560, 40)
	heading.add_theme_font_size_override("font_size", 26)
	choice_panel.add_child(heading)
	var options: Array = group.get("options", [])
	for index in range(options.size()):
		var option := str(options[index])
		var button := Button.new()
		button.text = option
		button.position = Vector2(45, 80 + index * 62)
		button.size = Vector2(530, 50)
		button.add_theme_font_size_override("font_size", 19)
		button.pressed.connect(func(): resolve_choice(group, option))
		choice_panel.add_child(button)

func resolve_choice(group: Dictionary, option: String) -> void:
	choice_panel.visible = false
	if option == str(group.get("correct", "")):
		complete_group(group)
	else:
		show_message(str(group.get("wrong_feedback", "证据与这个判断冲突。")), "发现冲突")
		get_parent().sound("impact")

func complete_group(group: Dictionary) -> void:
	var flag := str(group.get("on_correct", group.get("observe_all_writes", "")))
	GameState.write_flag(flag)
	var text := completion_story(group)
	show_message(text, "推理成立")
	get_parent().sound("evidence")
	run_trace("最终结果", flag)
	check_completion()
	refresh_all()

func completion_story(group: Dictionary) -> String:
	return str(group.get("on_correct_story", group.get("on_complete_story", "推理成立。")))

func group_complete(group: Dictionary) -> bool:
	var flag := str(group.get("on_correct", group.get("observe_all_writes", "")))
	return not flag.is_empty() and GameState.has_flag(flag)

func check_completion(announce := true) -> void:
	var completion: Dictionary = spec.get("completion", {})
	if completion.is_empty() or not requirements_met(completion.get("all_of", [])):
		return
	var first_time := not bool(GameState.completed_once.get(scene_id, false))
	for flag in completion.get("writes", []):
		GameState.write_flag(str(flag))
	if first_time:
		GameState.completed_once[scene_id] = true
		for key in spec.get("dossier_update", {}):
			GameState.dossier[key] = spec.dossier_update[key]
		for evidence_id in spec.get("evidence_writes", []):
			GameState.evidence[str(evidence_id)] = true
		run_trace("记忆写入", scene_id)
	if announce and first_time:
		show_message(str(completion.get("on_complete_story", "意愿档案已更新。")), "意愿档案已更新")
		get_parent().sound("change")
	refresh_dossier()

func open_exit(exit_id: String) -> void:
	var found: Dictionary = {}
	for raw_exit in spec.get("exits", []):
		if str(raw_exit.get("id", "")) == exit_id:
			found = raw_exit
			break
	if found.is_empty():
		return
	if not condition_met(str(found.get("condition", "always"))):
		show_message("出口尚未开放。完成当前房间或前一房间的推理。", "门锁")
		return
	var target := str(found.get("target", "scene01_white_corridor"))
	GameState.inventory.clear()
	selected_item = ""
	GameState.current_scene_id = target
	get_parent().call_deferred("go", target)

func trigger_ending() -> void:
	if not ending_ready:
		return
	GameState.choose_report_type()
	get_parent().call_deferred("go", "final_report")

func show_hint() -> void:
	var pending := ""
	for raw_group in spec.get("slot_groups", []):
		var group: Dictionary = raw_group
		if not group_complete(group):
			pending = str(group.id)
			break
	if pending.is_empty():
		show_message("本场推理已经完成。返回走廊，进入下一扇已开放的门。", "Ghost 提示")
		return
	var key := scene_id + "/" + pending
	var level := mini(int(GameState.hint_levels.get(key, 0)) + 1, 3)
	GameState.hint_levels[key] = level
	var hints := {
		1: "检查尚未成立的装置，注意它需要的是顺序、集合、状态或排除。",
		2: "切换 1/2/3 频段，对照当前物证的事实、情绪与期待记录。",
		3: "先调查所有发光物件；选中物证后点击对应吸附槽。装置与印章可直接点击。",
	}
	show_message(str(hints[level]), "Ghost 提示 %d/3" % level)

func requirements_met(requirements: Array) -> bool:
	for raw in requirements:
		if not GameState.has_flag(str(raw)):
			return false
	return true

func condition_met(condition: String) -> bool:
	if condition in ["", "always"]:
		return true
	if condition.begins_with("flag:"):
		return GameState.has_flag(condition.trim_prefix("flag:"))
	return false

func object_visible(object: Dictionary) -> bool:
	var visible: Dictionary = object.get("visible_requires", {})
	if visible.is_empty():
		return true
	var band := str(visible.get("band", ""))
	if not band.is_empty() and band != GameState.current_band:
		return false
	return requirements_met(visible.get("flags", []))

func is_item_placed(item_id: String) -> bool:
	for raw in GameState.placements.values():
		if raw is Array and item_id in raw:
			return true
	return false

func find_object(object_id: String) -> Dictionary:
	for raw in spec.get("objects", []):
		if str(raw.get("id", "")) == object_id:
			return raw
	return {}

func find_group(group_id: String) -> Dictionary:
	for raw in spec.get("slot_groups", []):
		if str(raw.get("id", "")) == group_id:
			return raw
	return {}

func vec2(raw: Array) -> Vector2:
	return Vector2(float(raw[0]), float(raw[1]))

func normalize_array(value: Variant) -> Array:
	if value is Array:
		return value
	if value is Dictionary and not value.is_empty():
		return [value]
	return []

func show_message(text: String, source := "Ghost") -> void:
	message_label.text = source + "｜" + text

func run_trace(step: String, detail: String) -> void:
	GameState.trace.append(step + " → " + detail)
	if GameState.trace.size() > 12:
		GameState.trace.pop_front()

func toggle_dossier() -> void:
	dossier_panel.visible = not dossier_panel.visible
	if dossier_panel.visible:
		refresh_dossier()

func refresh_dossier() -> void:
	if dossier_label == null:
		return
	var lines: Array[String] = []
	for key in GameState.dossier:
		lines.append("%s：%s" % [str(key), str(GameState.dossier[key])])
	lines.append("\n核心证据：" + ("、".join(GameState.active_ids()) if not GameState.active_ids().is_empty() else "未确认"))
	lines.append("\nGhost 调试轨迹：")
	for entry in GameState.trace.slice(maxi(0, GameState.trace.size() - 6)):
		lines.append(str(entry))
	dossier_label.text = "\n".join(lines)

func refresh_all() -> void:
	refresh_map_buttons()
	refresh_inventory()
	refresh_dossier()
	update_nearby()
	queue_redraw()

func refresh_map_buttons() -> void:
	for control in map_buttons:
		if is_instance_valid(control):
			control.queue_free()
	map_buttons.clear()
	for raw_object in spec.get("objects", []):
		var object: Dictionary = raw_object
		if not object_visible(object):
			continue
		var position := vec2(object.get("pos", [0, 0]))
		var button := Button.new()
		button.text = str(object.get("id", "?")) + "\n" + shorten(str(object.get("name", "物件")), 4)
		button.position = position + Vector2(-44, -22)
		button.size = Vector2(88, 38)
		button.add_theme_font_size_override("font_size", 11)
		button.tooltip_text = str(object.get("name", "物件")) + "\n点击等同于靠近后按 E"
		var object_id := str(object.get("id", ""))
		button.pressed.connect(func(): interact_object_by_id(object_id))
		ui.add_child(button)
		map_buttons.append(button)
	for raw_group in spec.get("slot_groups", []):
		var group: Dictionary = raw_group
		var position := vec2(group.get("pos", [0, 0]))
		var button := Button.new()
		var complete_mark := "✓" if group_complete(group) else "◇"
		button.text = "%s %s" % [complete_mark, shorten(str(group.get("id", "装置")), 11)]
		button.position = position + Vector2(-62, 32)
		button.size = Vector2(124, 34)
		button.add_theme_font_size_override("font_size", 11)
		var group_id := str(group.get("id", ""))
		button.pressed.connect(func(): activate_group(group_id))
		ui.add_child(button)
		map_buttons.append(button)
	for raw_exit in spec.get("exits", []):
		var exit: Dictionary = raw_exit
		var values: Array = exit.get("rect", [50, 390, 100, 80])
		var button := Button.new()
		var unlocked := condition_met(str(exit.get("condition", "always")))
		button.text = ("→ " if unlocked else "× ") + str(exit.get("name", "出口"))
		button.position = Vector2(float(values[0]), float(values[1]))
		button.size = Vector2(maxf(float(values[2]), 100), maxf(minf(float(values[3]), 52), 38))
		button.disabled = not unlocked
		button.add_theme_font_size_override("font_size", 14)
		var exit_id := str(exit.get("id", ""))
		button.pressed.connect(func(): open_exit(exit_id))
		ui.add_child(button)
		map_buttons.append(button)
	if ending_ready:
		var ending := Button.new()
		ending.text = "走向未命名区域  →"
		ending.position = Vector2(500, 470)
		ending.size = Vector2(300, 58)
		ending.add_theme_font_size_override("font_size", 20)
		ending.pressed.connect(trigger_ending)
		ui.add_child(ending)
		map_buttons.append(ending)

func refresh_inventory() -> void:
	for child in inventory_box.get_children():
		child.queue_free()
	var title := Label.new()
	title.text = "物证"
	title.custom_minimum_size = Vector2(48, 40)
	title.add_theme_font_size_override("font_size", 16)
	inventory_box.add_child(title)
	for item_id in GameState.inventory:
		var button := Button.new()
		var item := find_object(item_id)
		button.text = shorten(str(item.get("name", item_id)), 5)
		button.custom_minimum_size = Vector2(72, 42)
		button.add_theme_font_size_override("font_size", 12)
		button.button_pressed = item_id == selected_item
		button.disabled = is_item_placed(item_id)
		button.pressed.connect(func(): select_item(item_id))
		inventory_box.add_child(button)

func select_item(item_id: String) -> void:
	selected_item = item_id
	show_message("当前手持：" + str(find_object(item_id).get("name", item_id)), "物证")
	refresh_inventory()

func shorten(text: String, limit: int) -> String:
	return text if text.length() <= limit else text.left(limit) + "…"

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), INK)
	draw_room_environment()
	var tint: Color = BAND_COLORS.get(GameState.current_band, CYAN)
	draw_rect(STAGE, Color(tint.r, tint.g, tint.b, 0.075))
	draw_rect(STAGE, Color("42616d"), false, 2)
	for raw_npc in normalize_array(spec.get("npcs", [])):
		var npc: Dictionary = raw_npc
		var npc_tint := Color(0.72, 0.9, 1.0, 0.65)
		draw_actor(str(npc.get("character", "Ghost")), vec2(npc.get("pos", [0, 0])), float(npc.get("height", 140)), npc_tint)
	for raw_object in spec.get("objects", []):
		var object: Dictionary = raw_object
		if not object_visible(object):
			continue
		var pos := vec2(object.get("pos", [0, 0]))
		var size := vec2(object.get("size", [70, 50]))
		var color := tint.darkened(0.25)
		if str(object.get("id", "")) in GameState.inspected:
			color = tint
		if is_item_placed(str(object.get("id", ""))):
			color = Color(tint.r, tint.g, tint.b, 0.32)
		draw_rect(Rect2(pos - size * 0.5, size), Color(color.r, color.g, color.b, 0.22))
		draw_rect(Rect2(pos - size * 0.5, size), color, false, 2)
	draw_actor("心灵调理师", player, 88, Color.WHITE, false, sin(Time.get_ticks_msec() / 180.0) * 1.5)
	if not nearby.is_empty():
		var target := vec2(nearby.data.get("pos", nearby.data.get("rect", [player.x, player.y, 0, 0])))
		draw_arc(target, 28, 0, TAU, 24, PAPER, 2)
	draw_rect(Rect2(40, 570, 1200, 135), Color("0d1c29"))
	draw_rect(Rect2(40, 570, 1200, 135), Color("355161"), false, 2)
	draw_string(get_theme_default_font(), Vector2(60, 555), "当前频段  %s" % BAND_NAMES.get(GameState.current_band, "事实"), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, tint)

func draw_room_environment() -> void:
	var base: Color = {
		"scene01_white_corridor": Color("dce5e5"),
		"scene02_archive_room": Color("403329"),
		"scene03_studio_room": Color("202936"),
		"scene04_validation_center": Color("1d3043"),
		"scene05_brother_room": Color("1b2035"),
		"scene06_surgery_room": Color("1b2930"),
	}.get(scene_id, Color("26323b"))
	draw_rect(STAGE, base)
	if scene_id == "scene03_studio_room":
		draw_texture_rect(STUDIO_BG, STAGE, false, Color(0.72, 0.82, 0.9, 0.72))
		return
	# Low-cost 2.5D room shell: fixed vanishing point and reusable geometry.
	var vanishing := Vector2(640, 265)
	draw_colored_polygon(PackedVector2Array([Vector2(40,122), Vector2(1240,122), Vector2(950,350), Vector2(330,350)]), base.lightened(0.06))
	draw_colored_polygon(PackedVector2Array([Vector2(40,560), Vector2(1240,560), Vector2(950,350), Vector2(330,350)]), base.darkened(0.12))
	if scene_id != "scene01_white_corridor":
		draw_texture_rect(OFFICE_CARPET, Rect2(40, 350, 1200, 210), true, Color(0.55, 0.68, 0.75, 0.26))
	draw_colored_polygon(PackedVector2Array([Vector2(40,122), Vector2(330,350), Vector2(330,560), Vector2(40,560)]), base.darkened(0.2))
	draw_colored_polygon(PackedVector2Array([Vector2(1240,122), Vector2(950,350), Vector2(950,560), Vector2(1240,560)]), base.darkened(0.26))
	for x in range(80, 1241, 120):
		draw_line(Vector2(x, 560), vanishing, Color(1,1,1,0.07), 1)
	for y in range(390, 561, 42):
		draw_line(Vector2(40, y), Vector2(1240, y), Color(1,1,1,0.06), 1)
	match scene_id:
		"scene01_white_corridor":
			for x in [150, 390, 630, 870, 1110]:
				draw_rect(Rect2(x - 72, 178, 144, 152), Color("edf3f0"))
				draw_rect(Rect2(x - 72, 178, 144, 152), Color("7ea4a7"), false, 3)
				draw_line(Vector2(x, 205), Vector2(x, 310), Color("b4caca"), 2)
		"scene02_archive_room":
			for x in range(120, 1121, 165):
				draw_rect(Rect2(x, 165, 120, 185), Color("2b211c"))
				for y in range(185, 340, 32):
					draw_line(Vector2(x + 8, y), Vector2(x + 112, y), Color("b78a5e"), 3)
			draw_colored_polygon(PackedVector2Array([Vector2(350,355),Vector2(925,355),Vector2(1010,485),Vector2(270,485)]),Color("5b4030"))
		"scene03_studio_room":
			draw_rect(Rect2(245, 190, 300, 155), Color("09151e"))
			draw_rect(Rect2(270, 215, 250, 105), Color("225369"))
			for x in [670, 760, 850]:
				draw_rect(Rect2(x, 190, 65, 125), Color("28394c"), false, 4)
		"scene04_validation_center":
			draw_rect(Rect2(55, 135, 560, 410), Color(0.12,0.3,0.42,0.35))
			draw_rect(Rect2(665, 135, 560, 410), Color(0.45,0.23,0.15,0.28))
			draw_line(Vector2(640, 140), Vector2(640, 545), CYAN, 4)
			draw_circle(Vector2(640, 330), 82, Color("203a49"))
			draw_arc(Vector2(640,330),82,0,TAU,48,GOLD,4)
		"scene05_brother_room":
			draw_rect(Rect2(610, 160, 250, 175), Color("101522"))
			draw_rect(Rect2(625, 175, 220, 145), Color("516a89"), false, 4)
			draw_colored_polygon(PackedVector2Array([Vector2(450,235),Vector2(520,235),Vector2(620,500),Vector2(330,500)]),Color(0.95,0.77,0.36,0.15))
		"scene06_surgery_room":
			draw_colored_polygon(PackedVector2Array([Vector2(440,305),Vector2(820,305),Vector2(900,450),Vector2(360,450)]),Color("344d52"))
			for target in [Vector2(260,230),Vector2(390,205),Vector2(890,205),Vector2(1030,230),Vector2(640,170)]:
				draw_line(Vector2(640,350), target, Color("61d8d0"), 6)
			draw_arc(Vector2(640,350),115,0,TAU,48,Color("e27887"),4)
