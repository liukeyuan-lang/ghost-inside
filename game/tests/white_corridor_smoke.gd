extends SceneTree

class Host:
	extends Control
	var target := ""
	func sound(_cue: String) -> void:
		pass
	func restart() -> void:
		pass
	func go(next: String) -> void:
		target = next

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var state: Node = root.get_node("GameState")
	state.call("reset_case")
	var host := Host.new()
	root.add_child(host)
	var room: Control = load("res://scenes/white_corridor.tscn").instantiate()
	host.add_child(room)
	await create_timer(0.7).timeout
	# Formal transparent-art assets must load and be used by real map render nodes.
	for path in room.PROP_PATHS.values():
		if not ResourceLoader.exists(path) or load(path) == null:
			fail_test("Missing formal White Corridor art: %s" % path)
			return
	if not ResourceLoader.exists(room.LYING_THERAPIST_PATH) or room.lying_actor == null or room.lying_actor.texture == null:
		fail_test("Intro lying therapist art was not loaded")
		return
	if room.intro_state == room.IntroState.EXPLORE or room.player_actor.modulate.a > 0.01:
		fail_test("Intro did not begin with player controls locked and standing actor hidden")
		return
	if not room.comic_dialogue.visible:
		fail_test("Comic Ghost dialogue panel is missing from intro")
		return
	var first_page: int = room.intro_index
	room.advance_intro()
	if room.intro_index != first_page + 1:
		fail_test("Intro dialogue did not advance page by page")
		return
	room.complete_intro_for_test()
	if room.intro_state != room.IntroState.EXPLORE or room.lying_actor.visible or room.player_actor.modulate.a < 0.99:
		fail_test("Intro did not transition from lying pose to controllable standing player")
		return
	if room.get_node_or_null("World_YSortedByBase/Ghost_MapActor/Ghost_ActualMapRender") == null:
		fail_test("Ghost does not have an actual map render node")
		return
	if room.player_actor.visual == null or room.player_actor.visual.texture == null:
		fail_test("Player does not use a map actor texture")
		return
	for index in range(room.objects.size()):
		if room.objects[index].visual == null or room.objects[index].visual.texture == null:
			fail_test("World object %d fell back to procedural block art" % index)
			return
	# The initial position is close to the login base, but must never be trapped
	# inside its narrow collision radius.
	var spawn_position: Vector2 = room.player
	room.move_player_for_test(Vector2(0, 12))
	if room.player.y <= spawn_position.y:
		fail_test("Player could not move away from the landing base")
		return
	# Interaction is spatial: a remote call must never start or advance the chain.
	room.set_player_for_test(Vector2(700, 340))
	room.interact(1)
	if room.observer:
		fail_test("Observer activated outside terminal")
		return
	room.set_player_for_test(room.BASES[0])
	room.interact(0)
	if room.objects[1].evidence.visible:
		fail_test("Unresolved evidence was visible without Q consciousness view")
		return
	room.set_player_for_test(room.BASES[1])
	room.interact(1)
	if room.phase != 0:
		fail_test("Seven-year fragment found without Q")
		return
	room.vision = true
	room.refresh()
	if not room.objects[1].evidence.visible:
		fail_test("Q consciousness view did not reveal the blue evidence layer")
		return
	room.interact(1)
	if room.evidence_layer == null or not room.evidence_layer.visible:
		fail_test("Seven-year evidence did not open as a fixed close-up")
		return
	room.evidence_layer._advance()
	room.evidence_layer._confirm()
	if room.completed != 1:
		fail_test("Seven-year node did not complete after reading evidence")
		return
	room.set_player_for_test(room.BASES[2])
	room.interact(2)
	if room.evidence_layer.expanded:
		fail_test("15-year document began already expanded")
		return
	room.evidence_layer._advance()
	if not room.evidence_layer.expanded:
		fail_test("15-year document did not require paper expansion")
		return
	room.evidence_layer._confirm()
	room.set_player_for_test(room.BASES[3])
	room.interact(3)
	room.evidence_layer._advance()
	room.evidence_layer._confirm()
	room._on_evidence_choice("age18_choice", "self")
	if room.completed != 2:
		fail_test("Wrong 18-year judgment advanced progress")
		return
	room._on_evidence_choice("age18_choice", "external")
	room.set_player_for_test(room.BASES[4])
	room.interact(4)
	room.evidence_layer._advance()
	room.evidence_layer._confirm()
	room._on_evidence_choice("age22_choice", "hold")
	if room.completed != 3:
		fail_test("Wrong 22-year judgment advanced progress")
		return
	room._on_evidence_choice("age22_choice", "remove")
	if room.completed != 4 or not state.get("case_flags").get("scene01_age_22", false):
		fail_test("Four nodes did not complete")
		return
	# Moving up/down changes the feet sort relative to the tall 15-year station.
	room.set_player_for_test(Vector2(room.BASES[2].x, room.BASES[2].y - 70))
	var behind_z: int = room.player_actor.z_index
	room.set_player_for_test(Vector2(room.BASES[2].x, room.BASES[2].y + 70))
	if behind_z >= room.objects[2].z_index or room.player_actor.z_index <= room.objects[2].z_index:
		fail_test("Feet Y sorting did not change front/back order")
		return
	room.set_player_for_test(room.BASES[6])
	room.interact(6)
	await process_frame
	if host.target != "archive_room" or state.get("will_dossier").get("选择理由", "") != "空白":
		fail_test("Archive room was not opened with honest dossier")
		return
	print("WHITE_CORRIDOR_SMOKE_PASS")
	quit()

func fail_test(reason: String) -> void:
	push_error(reason)
	quit(1)
