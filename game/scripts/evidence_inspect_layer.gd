class_name EvidenceInspectLayer
extends Control

## Fixed comic evidence close-up.  It is intentionally not a dialogue balloon:
## the evidence has its own darkened stage, paper panel, and readable metadata.
signal confirmed(evidence_id: String)
signal choice_made(evidence_id: String, choice_id: String)

var evidence_id := ""
var expanded := false
var require_expand := true
var shade: ColorRect
var frame: Panel
var image: TextureRect
var title_label: Label
var body_label: Label
var note_label: Label
var action: Button
var close_button: Button
var choices: VBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 4096
	shade = ColorRect.new()
	shade.color = Color(0.01, 0.03, 0.06, 0.9)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	frame = Panel.new()
	frame.position = Vector2(105, 72)
	frame.size = Vector2(1070, 578)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("102534")
	style.border_color = Color("efbc76")
	style.set_border_width_all(4)
	style.set_corner_radius_all(10)
	frame.add_theme_stylebox_override("panel", style)
	add_child(frame)
	image = TextureRect.new()
	image.position = Vector2(46, 75)
	image.size = Vector2(405, 405)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.modulate = Color(1, 1, 1, 0.96)
	frame.add_child(image)
	title_label = _label(Vector2(480, 32), Vector2(540, 44), 29, Color("efbc76"))
	body_label = _label(Vector2(480, 93), Vector2(530, 380), 20, Color("e5e2ce"))
	note_label = _label(Vector2(480, 365), Vector2(530, 72), 17, Color("a1b5bf"))
	choices = VBoxContainer.new()
	choices.position = Vector2(480, 440)
	choices.size = Vector2(530, 120)
	frame.add_child(choices)
	action = _button("移开并展开", Vector2(46, 500), Vector2(405, 48), _advance)
	close_button = _button("确认阅读", Vector2(835, 500), Vector2(175, 48), _confirm)
	visible = false

func _label(pos: Vector2, dimensions: Vector2, font_size: int, color: Color) -> Label:
	var value := Label.new()
	value.position = pos
	value.size = dimensions
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value.add_theme_font_size_override("font_size", font_size)
	value.add_theme_color_override("font_color", color)
	frame.add_child(value)
	return value

func _button(caption: String, pos: Vector2, dimensions: Vector2, callback: Callable) -> Button:
	var value := Button.new()
	value.text = caption
	value.position = pos
	value.size = dimensions
	value.add_theme_font_size_override("font_size", 19)
	value.pressed.connect(callback)
	frame.add_child(value)
	return value

func inspect(id: String, texture: Texture2D, title: String, preview: String, readable_body: String, note: String = "", must_expand := true) -> void:
	evidence_id = id
	expanded = false
	require_expand = must_expand
	image.texture = texture
	title_label.text = "物证特写 / " + title
	body_label.text = preview
	note_label.text = "漫画物证记录：" + note
	note_label.visible = true
	_clear_choices()
	action.visible = must_expand
	action.text = "移开并展开" if must_expand else "放大查看"
	close_button.visible = not must_expand
	close_button.text = "确认阅读"
	set_meta("expanded_body", readable_body)
	visible = true
	call_deferred("_focus_action")

func _focus_action() -> void:
	(action if action.visible else close_button).grab_focus()

func _advance() -> void:
	if not visible:
		return
	expanded = true
	body_label.text = str(get_meta("expanded_body"))
	note_label.visible = false
	action.visible = false
	close_button.visible = true
	close_button.grab_focus()

func offer_choices(id: String, prompt: String, option_data: Array) -> void:
	evidence_id = id
	expanded = true
	title_label.text = "证据判断 / " + prompt
	body_label.text = "请根据刚才查看的来源记录判断。Ghost 只能指出矛盾，不能替你选择。"
	note_label.text = "选择错误不会推进，并会回到这组可复查的证据。"
	note_label.visible = true
	action.visible = false
	close_button.visible = false
	_clear_choices()
	for item in option_data:
		var b := Button.new()
		b.text = str(item.text)
		b.custom_minimum_size = Vector2(530, 34)
		b.add_theme_font_size_override("font_size", 17)
		b.pressed.connect(func(): choice_made.emit(id, str(item.id)))
		choices.add_child(b)
	visible = true
	if choices.get_child_count() > 0:
		choices.get_child(0).call_deferred("grab_focus")

func show_feedback(message: String) -> void:
	note_label.text = "证据冲突：" + message + " 请重新选择。"

func _clear_choices() -> void:
	for child in choices.get_children():
		child.queue_free()

func _confirm() -> void:
	if require_expand and not expanded:
		return
	visible = false
	confirmed.emit(evidence_id)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and (event.keycode == KEY_E or event.keycode == KEY_ENTER or event.keycode == KEY_SPACE):
		if action.visible:
			_advance()
		elif close_button.visible:
			_confirm()
		get_viewport().set_input_as_handled()
