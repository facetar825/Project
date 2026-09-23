extends SceneTree
## godot --headless --path app/rogil --script res://tests/audio_test.gd
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	if ok:
		print("PASS: ", description)
	else:
		push_error(description)
		failures += 1

func run() -> void:
	var mixer = load("res://Script/floor/audio.gd").new()
	root.add_child(mixer)
	await process_frame
	check(AudioServer.get_bus_index("Music") >= 0 and AudioServer.get_bus_index("SFX") >= 0, "Music and SFX buses exist")
	check(mixer._voices.size() == 10, "SFX pool is bounded at 10 voices")
	for event in mixer.EVENTS:
		var stream: AudioStream = mixer._streams[event]
		check(stream != null and stream.get_length() > 0.1, "Playable original effect: " + event)
		mixer.play(event)
	check(mixer._ambient.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and mixer._combat.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Score layers loop seamlessly")
	check(is_equal_approx(mixer._ambient.stream.get_length(), mixer._combat.stream.get_length()), "Score layers share the same 24-second loop length")
	mixer.set_state("boss")
	check(mixer._combat_target > 0.3, "Boss state brings in combat music")
	mixer.set_state("pause")
	check(is_zero_approx(mixer._combat_target), "Pause fades out percussion")
	paused = true
	await create_timer(0.08).timeout
	check(mixer._clock > 0.0, "Audio fades continue while game tree is paused")
	paused = false
	for index in range(100):
		mixer.play("hit")
	check(mixer._voices.size() == 10, "Swarms cannot allocate extra voices")
	mixer.queue_free()
	await process_frame
	print("Audio checks complete; failures: ", failures)
	quit(1 if failures else 0)
