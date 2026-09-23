class_name ComicDialogueLayer
extends Control

## Fixed-screen comic dialogue frame shared by all story rooms.  It deliberately
## lives above the world, so portrait composition never affects world Y sorting.
signal advance_requested

var portrait: TextureRect
var speaker_label: Label
var body_label: Label
var prompt_label: Label
var panel: Panel

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 4095
	var speed_lines := ColorRect.new()
	speed_lines.name = "ComicSpeedLines"
	speed_lines.position = Vector2(24, 438)
	speed_lines.size = Vector2(1232, 10)
	speed_lines.color = Color("67e6e0", 0.42)
	add_child(speed_lines)
	panel = Panel.new()
	panel.name = "ComicDialoguePanel"
	panel.position = Vector2(42, 485)
	panel.size = Vector2(1196, 184)
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("09141f", 0.96)
	frame.border_color = Color("67e6e0")
	frame.set_border_width_all(3)
	frame.corner_radius_top_left = 20
	frame.corner_radius_bottom_right = 20
	panel.add_theme_stylebox_override("panel", frame)
	add_child(panel)
	portrait = TextureRect.new()
	portrait.name = "ComicPortrait"
	# A deliberately cropped chest-up panel overlaps the speech-box edge.  The
	# source figures are full-body PNGs; COVERED crops them without new artwork.
	portrait.position = Vector2(906, 338)
	portrait.size = Vector2(278, 220)
	portrait.clip_contents = true
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(portrait)
	speaker_label = Label.new()
	speaker_label.name = "ComicSpeaker"
	speaker_label.position = Vector2(76, 502)
	speaker_label.size = Vector2(650, 38)
	speaker_label.add_theme_font_size_override("font_size", 25)
	speaker_label.add_theme_color_override("font_color", Color("67e6e0"))
	add_child(speaker_label)
	body_label = Label.new()
	body_label.name = "ComicDialogueText"
	body_label.position = Vector2(76, 544)
	body_label.size = Vector2(840, 88)
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.add_theme_font_size_override("font_size", 23)
	body_label.add_theme_color_override("font_color", Color("e5e2ce"))
	add_child(body_label)
	prompt_label = Label.new()
	prompt_label.name = "ComicContinuePrompt"
	prompt_label.position = Vector2(960, 638)
	prompt_label.size = Vector2(240, 24)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	prompt_label.add_theme_font_size_override("font_size", 15)
	prompt_label.add_theme_color_override("font_color", Color("a1b5bf"))
	add_child(prompt_label)
	var click := Button.new()
	click.name = "ComicDialogueClickAdvance"
	click.flat = true
	click.position = panel.position
	click.size = panel.size
	click.modulate.a = 0.0
	click.tooltip_text = "点击继续"
	click.pressed.connect(func(): advance_requested.emit())
	add_child(click)
	visible = false

func show_line(speaker: String, text: String, show_prompt := false) -> void:
	visible = true
	speaker_label.text = speaker
	body_label.text = text
	prompt_label.text = "E / Enter / Space / 点击继续" if show_prompt else ""
	var path := "res://assets/characters/%s.png" % speaker
	if not ResourceLoader.exists(path):
		path = "res://assets/characters/Ghost.png"
	var source := load(path) as Texture2D
	# Crop the authored full-height figure at the upper torso before it reaches
	# TextureRect, keeping a recognisable head-and-shoulders comic close-up.
	var close_up := AtlasTexture.new()
	close_up.atlas = source
	close_up.region = Rect2(0, 0, source.get_width(), source.get_height() * 0.56)
	portrait.texture = close_up
	portrait.modulate = Color.WHITE if speaker != "系统" else Color(0.55, 0.9, 1.0, 0.7)

func hide_dialogue() -> void:
	visible = false
