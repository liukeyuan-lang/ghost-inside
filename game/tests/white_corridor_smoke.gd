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
	room.set_player_for_test(room.BASES[1])
	room.interact(1)
	if room.phase != 0:
		fail_test("Seven-year fragment found without Q")
		return
	room.vision = true
	for n in range(3):
		room.interact(1)
	if room.completed != 1:
		fail_test("Seven-year node did not complete")
		return
	for station in [2, 3, 4]:
		room.set_player_for_test(room.BASES[station])
		for n in range(3):
			room.interact(station)
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
