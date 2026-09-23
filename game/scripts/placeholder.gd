extends Control
@export var phase := "start"
var stages := ["start", "mind_map", "memory_dinner", "seed_lab", "ending"]
func _ready() -> void:
	var label := Label.new()
	label.position = Vector2(90, 140)
	label.text = "GHOST INSIDE / 白色走廊\n" + phase
	add_child(label)
	var button := Button.new()
	button.position = Vector2(90, 360)
	button.size = Vector2(600, 80)
	button.text = "建立连接" if phase == "start" else "继续"
	button.pressed.connect(advance)
	add_child(button)
func advance() -> void:
	if phase == "start" and not GameState.load_error.is_empty():
		return
	if phase == "memory_dinner":
		for group in GameState.data.cards.values():
			for card in group:
				GameState.unlock_evidence(card.id)
	if phase == "seed_lab":
		GameState.set_agent_result(GameState.local_result("accept"))
	if phase == "ending":
		get_parent().restart()
	else:
		get_parent().go(stages[stages.find(phase) + 1])
