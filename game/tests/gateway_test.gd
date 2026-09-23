extends SceneTree

const Gateway = preload("res://scripts/ai_gateway.gd")
var gateway: Node
var checks := 0
var failures := 0
var unlocked: Array[String] = ["F01", "F02", "F03", "E01", "E02", "E03", "B01", "B02", "B03"]
var selected := {"facts": "F02", "feelings": "E03", "boundaries": "B02"}

class MockServer extends Node:
	var server := TCPServer.new()
	var peers: Array[StreamPeerTCP] = []
	var replies: Array[String] = []
	var requests := 0
	var hang := false
	func _process(_delta: float) -> void:
		while server.is_connection_available():
			peers.append(server.take_connection())
		for peer in peers.duplicate():
			peer.poll()
			if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
				peers.erase(peer)
				continue
			if peer.get_available_bytes() == 0:
				continue
			peer.get_data(peer.get_available_bytes())
			requests += 1
			if hang:
				continue
			var body: String = replies.pop_front() if not replies.is_empty() else "{}"
			var bytes := str(body).to_utf8_buffer()
			peer.put_data(("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % bytes.size()).to_utf8_buffer())
			peer.put_data(bytes)
			peers.erase(peer)
	func close() -> void:
		for peer in peers:
			peer.disconnect_from_host()
		peers.clear()
		server.stop()

func _initialize() -> void:
	call_deferred("run")

func expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)

func canonical() -> Dictionary:
	return {"result": "accept", "evidence_ids": ["F02", "E03", "B02"], "response": "医学可以是我的一部分，选择仍由我自己确认。", "world_state": "dialogue_exit", "trace": ["核对已激活证据", "保留自主选择"], "memory_write": "职业不是全部身份"}

func envelope(value: Variant) -> String:
	return JSON.stringify({"choices": [{"message": {"content": JSON.stringify(value)}}]})

func run() -> void:
	gateway = Gateway.new()
	root.add_child(gateway)
	var examples := [
		["感谢家人的付出，不等于把以后所有选择都交出去。", "accept"],
		["医学可以是你喜欢的一部分，不必成为证明价值的唯一方式。", "accept"],
		["你父亲毁了你的人生，离开他就好了。", "revise"],
		["家人的期待全是控制，你什么都不欠他们。", "revise"],
		["真正的你只想做游戏，医学都是假的。", "revise"],
		["马上拒绝工作，选择画画，你才会自由。", "hold"]
	]
	for example in examples:
		var result: Dictionary = await gateway.evaluate(selected, example[0], unlocked, false)
		expect(result.result == example[1], "case input: " + example[0])
		expect(result.source == "local" and result.attempts == 0, "offline never calls network")
		expect(result.ghost_trace.size() == 6, "six public audit stages")
		var raw := result.duplicate(true)
		for key in ["source", "reason", "attempts", "ghost_trace", "blocked"]:
			raw.erase(key)
		expect(gateway.validate_result(raw, unlocked).ok, "fallback contract")
	var revise_cards := {"facts": "F03", "feelings": "E01", "boundaries": "B01"}
	var hold_cards := {"facts": "F01", "feelings": "E02", "boundaries": "B03"}
	expect(gateway.local_result(selected, "", unlocked).result == "accept", "accept cards without prose")
	expect(gateway.local_result(revise_cards, "", unlocked).result == "revise", "revise cards without prose")
	expect(gateway.local_result(hold_cards, "", unlocked).result == "hold", "hold cards without prose")
	expect(gateway.validate_result(canonical(), unlocked).ok, "valid online contract")
	var bad: Array = [null, [], "accept", 42]
	for change in [
		{"result": "kill"}, {"result": 1}, {"world_state": "temporary_exit"},
		{"evidence_ids": []}, {"evidence_ids": ["F99"]}, {"evidence_ids": ["F02", "F02"]},
		{"evidence_ids": [2]}, {"evidence_ids": ["E03"]}, {"response": 1},
		{"response": ""}, {"response": "字".repeat(81)}, {"memory_write": []},
		{"memory_write": ""}, {"memory_write": "字".repeat(81)}, {"trace": "reason"},
		{"trace": []}, {"trace": [1]}, {"trace": ["字".repeat(81)]},
		{"response": "你必须辞职。"}, {"source": "online"}
	]:
		var value := canonical()
		value.merge(change, true)
		bad.append(value)
	var missing := canonical()
	missing.erase("trace")
	bad.append(missing)
	for value in bad:
		expect(not gateway.validate_result(value, unlocked).ok, "reject malformed result " + str(value))
	var grey: Array[String] = ["F01", "E03", "B02"]
	expect(not gateway.validate_result(canonical(), grey).ok, "grey F02 cannot be cited")
	var blocked: Dictionary = await gateway.evaluate(selected, "", grey, false)
	expect(blocked.result == "hold" and blocked.blocked and not blocked.evidence_ids.has("F02"), "grey fact cannot be submitted")
	expect(not gateway.selection_valid({"facts": "E03", "feelings": "F02", "boundaries": "B02"}, unlocked), "card categories cannot be swapped")

	# Real local HTTP transport; no external endpoint or real credential is used.
	var saved := {}
	for key in ["GHOST_AI_URL", "GHOST_AI_KEY", "GHOST_AI_MODEL"]:
		saved[key] = OS.get_environment(key)
	OS.set_environment("GHOST_AI_KEY", "")
	var no_key: Dictionary = await gateway.evaluate(selected, "", unlocked, true)
	expect(no_key.source == "local" and no_key.attempts == 0, "missing key never calls network")
	var mock := MockServer.new()
	root.add_child(mock)
	var port := 18879
	while mock.server.listen(port, "127.0.0.1") != OK and port < 18889:
		port += 1
	expect(mock.server.is_listening(), "mock HTTP server ready")
	if mock.server.is_listening():
		OS.set_environment("GHOST_AI_URL", "http://127.0.0.1:%d/v1/chat/completions" % port)
		OS.set_environment("GHOST_AI_KEY", "local-test-key")
		OS.set_environment("GHOST_AI_MODEL", "mock")
		mock.replies = [envelope(canonical())]
		var valid: Dictionary = await gateway.evaluate(selected, "", unlocked, true)
		expect(valid.source == "online" and valid.attempts == 1, "valid HTTP reply accepted")
		mock.replies = ["not json", envelope(canonical())]
		var retry: Dictionary = await gateway.evaluate(selected, "", unlocked, true)
		expect(retry.source == "online" and retry.attempts == 2, "invalid response retried exactly once")
		mock.replies = [envelope({"result": "destroy"}), envelope({"result": "destroy"})]
		var invalid: Dictionary = await gateway.evaluate(selected, "", unlocked, true)
		expect(invalid.source == "local" and invalid.attempts == 2 and invalid.reason.begins_with("invalid_twice"), "second invalid reply uses case fallback")
		mock.hang = true
		var started := Time.get_ticks_msec()
		var timeout: Dictionary = await gateway.evaluate(selected, "", unlocked, true)
		var elapsed := Time.get_ticks_msec() - started
		expect(timeout.source == "local" and timeout.reason == "timeout" and timeout.attempts == 1, "timeout uses fallback without retry")
		expect(elapsed < 8200, "timeout bounded near eight seconds: %d ms" % elapsed)
		print("HTTP_TIMEOUT_MS=", elapsed)
		mock.close()
		var disconnected: Dictionary = await gateway.evaluate(selected, "", unlocked, true)
		expect(disconnected.source == "local" and disconnected.reason in ["connection_failed", "timeout"] and disconnected.attempts == 1, "offline socket uses fallback")
	for key in saved:
		if saved[key].is_empty():
			OS.unset_environment(key)
		else:
			OS.set_environment(key, saved[key])
	mock.queue_free()
	gateway.queue_free()
	print("GATEWAY_TEST checks=", checks, " failures=", failures)
	await process_frame
	await process_frame
	quit(0 if failures == 0 else 1)
