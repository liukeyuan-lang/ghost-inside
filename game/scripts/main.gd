extends Control
var current: Control
var music: AudioStreamPlayer
var sounds: Dictionary = {}

func _ready() -> void:
	var style := Theme.new()
	style.default_font = load("res://assets/fonts/ark-pixel-12px-proportional-zh_cn.ttf")
	style.default_font_size = 24
	theme = style
	music = AudioStreamPlayer.new()
	var track: AudioStreamOggVorbis = load("res://assets/audio/ambience.ogg")
	track.loop = true
	music.stream = track
	music.volume_db = -24
	add_child(music)
	music.play()
	for cue in ["interact", "pulse", "evidence", "impact", "change"]:
		var audio := AudioStreamPlayer.new()
		audio.stream = load("res://assets/audio/%s.wav" % cue)
		audio.volume_db = -15
		add_child(audio)
		sounds[cue] = audio
	go("start")
	if "--self-test" in OS.get_cmdline_user_args():
		call_deferred("self_test")

func go(next: String) -> void:
	if is_instance_valid(current):
		remove_child(current)
		current.queue_free()
	GameState.stage = next
	current = load("res://scenes/%s.tscn" % next).instantiate()
	add_child(current)
	if is_instance_valid(music):
		music.volume_db = -30 if next in ["memory_dinner", "ending"] else -24

func sound(cue: String) -> void:
	if sounds.has(cue):
		sounds[cue].play()

func stop_audio_for_test() -> void:
	if is_instance_valid(music):
		music.stop()
		music.stream = null
	for audio in sounds.values():
		if is_instance_valid(audio):
			audio.stop()
			audio.stream = null
	sounds.clear()

func restart() -> void:
	GameState.reset_case()
	go("start")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		restart()
		get_viewport().set_input_as_handled()

func self_test() -> void:
	var runner: Node = load("res://tests/playthrough.gd").new()
	add_child(runner)
	runner.run(self)
