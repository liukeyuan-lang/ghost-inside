extends Control

const INK := Color("0a1523")
const PANEL := Color("122434")
const CYAN := Color("67e6e0")
const PAPER := Color("e5e2ce")
const MUTED := Color("a1b5bf")
const GOLD := Color("efbc76")
const RED := Color("ee7e89")
const AMBER := Color("e9a85f")
var ui: Control
var comic_dialogue: ComicDialogueLayer
var _character_cache: Dictionary = {}

func setup(title: String, subtitle: String) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	comic_dialogue = ComicDialogueLayer.new()
	comic_dialogue.name = "ComicDialogueLayer"
	ui.add_child(comic_dialogue)
	label_at(title, Vector2(40, 26), Vector2(950, 44), 32, PAPER)
	label_at(subtitle, Vector2(42, 76), Vector2(1130, 38), 18, MUTED)
	button_at("重开 F2", Vector2(1110, 20), Vector2(130, 56), func(): get_parent().restart())

func label_at(text: String, pos: Vector2, dimensions: Vector2, font_size: int = 24, color: Color = PAPER) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = dimensions
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(label)
	return label

func button_at(text: String, pos: Vector2, dimensions: Vector2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = pos
	button.size = dimensions
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", PAPER)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = PANEL if state != "hover" else Color("254553")
		box.border_color = CYAN if state in ["focus", "pressed", "hover"] else Color("42616d")
		if state == "disabled":
			box.bg_color = Color("16202a")
		box.set_border_width_all(2)
		box.content_margin_left = 12
		box.content_margin_right = 12
		button.add_theme_stylebox_override(state, box)
	button.pressed.connect(callback)
	ui.add_child(button)
	return button

func portrait_at(character: String, pos: Vector2, dimensions: Vector2, tint: Color = Color.WHITE, behind := false) -> TextureRect:
	var portrait := TextureRect.new()
	portrait.texture = character_texture(character)
	portrait.position = pos
	portrait.size = dimensions
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.modulate = tint
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(portrait)
	if behind:
		ui.move_child(portrait, 0)
	return portrait

func character_texture(character: String) -> Texture2D:
	if not _character_cache.has(character):
		_character_cache[character] = load("res://assets/characters/%s.png" % character)
	return _character_cache[character]

func draw_actor(character: String, feet: Vector2, height: float, tint: Color = Color.WHITE, flip := false, bob := 0.0) -> void:
	var texture := character_texture(character)
	if texture == null:
		return
	var ratio := float(texture.get_width()) / maxf(float(texture.get_height()), 1.0)
	var width := height * ratio
	if flip:
		draw_set_transform(feet, 0.0, Vector2(-1, 1))
		draw_texture_rect(texture, Rect2(-width * 0.5, -height + bob, width, height), false, tint)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_texture_rect(texture, Rect2(feet.x - width * 0.5, feet.y - height + bob, width, height), false, tint)

func chapter_chip(number: String, title: String, pos: Vector2, active := false) -> void:
	var fill := Color("183848") if active else Color("101e2b")
	draw_rect(Rect2(pos, Vector2(177, 42)), fill)
	draw_rect(Rect2(pos, Vector2(177, 42)), AMBER if active else Color("355161"), false, 2)
	draw_string(get_theme_default_font(), pos + Vector2(10, 27), number + "  " + title, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, PAPER if active else MUTED)

func plate(rect: Rect2, color: Color = PANEL) -> void:
	draw_rect(rect, color)
	draw_rect(rect, Color("355161"), false, 2)

func person(at: Vector2, color: Color, scale_factor: float = 1.0) -> void:
	draw_rect(Rect2(at + Vector2(-10, -38) * scale_factor, Vector2(20, 20) * scale_factor), color)
	draw_rect(Rect2(at + Vector2(-16, -16) * scale_factor, Vector2(32, 34) * scale_factor), color)
	draw_rect(Rect2(at + Vector2(-14, 18) * scale_factor, Vector2(10, 20) * scale_factor), color)
	draw_rect(Rect2(at + Vector2(4, 18) * scale_factor, Vector2(10, 20) * scale_factor), color)

func guardian(at: Vector2, kind: String = "locked", s: float = 1.0) -> void:
	var color: Color = {"locked": RED, "accept": CYAN, "revise": GOLD, "hold": MUTED}.get(kind, RED)
	for i in range(5):
		var offset := Vector2((i % 2) * 18 - 32, i * 22 - 55) * s
		draw_rect(Rect2(at + offset, Vector2(52, 30) * s), color.darkened(i * 0.09))
		draw_line(at + offset + Vector2(8, 10) * s, at + offset + Vector2(40, 10) * s, INK, 3 * s)
	draw_rect(Rect2(at + Vector2(-23, -90) * s, Vector2(46, 32) * s), color)
	draw_rect(Rect2(at + Vector2(-12, -80) * s, Vector2(24, 5) * s), INK)
	if kind != "accept":
		draw_line(at + Vector2(-10, 0) * s, at + Vector2(-75, 25) * s, color, 5 * s)
		draw_line(at + Vector2(-95, 10) * s, at + Vector2(-50, 10) * s, color, 3 * s)
	else:
		draw_arc(at, 80 * s, 0.3, 2.8, 20, color, 3)
	if kind == "locked":
		draw_rect(Rect2(at + Vector2(45, 12) * s, Vector2(38, 48) * s), color)
	elif kind == "revise":
		draw_rect(Rect2(at + Vector2(45, 76) * s, Vector2(48, 20) * s), color)
		draw_polyline(PackedVector2Array([at + Vector2(5, -45) * s, at + Vector2(-8, -10) * s, at + Vector2(8, 16) * s, at + Vector2(-2, 42) * s]), INK, 3 * s)

func goto_scene(next: String) -> void:
	get_parent().call_deferred("go", next)
