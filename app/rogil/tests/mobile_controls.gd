extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	print("PASS: " if ok else "FAIL: ", description)
	if not ok:
		failures += 1

func touch(index: int, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	root.push_input(event, true)

func drag(index: int, point: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = point
	event.relative = relative
	root.push_input(event, true)

func run() -> void:
	var game = load("res://Scene/Floor.tscn").instantiate()
	game.mobile_controls = true
	root.add_child(game)
	current_scene = game
	root.size = Vector2i(1280, 720)
	while not game.dungeon.ready_for_play:
		await physics_frame
	var controls = game.touch_controls
	check(not controls.active, "Touch controls inactive over menu")
	await process_frame
	var start_button = game.modal.get_child(4)
	var start_point: Vector2 = root.get_final_transform() * start_button.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.position = start_point
		event.index = 0
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await process_frame
	check(game.mode == "playing", "Real touch dispatch activates menu button")
	game.hero.position = game.dungeon.checkpoint(0)
	game.hero.invulnerability = 100
	await create_timer(0.15).timeout
	var origin: Vector3 = game.hero.position
	var stick: Vector2 = controls.stick_center()
	touch(0, stick + Vector2(0, -80), true)
	await create_timer(0.2).timeout
	check(game.hero.position.distance_to(origin) > 0.5, "Joystick moves hero")
	var yaw: float = game.hero.pivot.rotation.y
	touch(1, Vector2(900, 320), true)
	drag(1, Vector2(940, 330), Vector2(40, 10))
	check(absf(game.hero.pivot.rotation.y - yaw) > 0.1 and controls.movement.y < -0.5, "Second finger rotates camera without stopping movement")
	touch(2, controls.dash_rect().get_center(), true)
	await physics_frame
	await physics_frame
	check(game.hero.dash_cooldown > 2.0, "Third finger triggers dash")
	touch(2, controls.dash_rect().get_center(), false)
	touch(0, stick, false)
	touch(1, Vector2(940, 330), false)
	check(controls.movement == Vector2.ZERO and controls.look_finger == -1, "Release resets movement and camera fingers")
	await create_timer(0.5).timeout
	touch(3, controls.jump_rect().get_center(), true)
	await physics_frame
	await physics_frame
	check(game.hero.velocity.y > 0, "Touch jump lifts hero")
	touch(3, controls.jump_rect().get_center(), false)
	touch(0, stick + Vector2(0, -80), true)
	touch(4, controls.pause_rect().get_center(), true)
	check(game.mode == "pause" and controls.movement == Vector2.ZERO and not controls.active, "Pause clears held touches")
	game.resume()
	check(controls.active and controls.move_finger == -1, "Resume does not reuse old fingers")
	game.hero.xp = game.hero.next_xp
	game.check_level()
	check(game.mode == "upgrade" and not controls.active, "Upgrade menu disables touch layer")
	game.apply_upgrade("damage")
	check(game.mode == "playing" and controls.active, "Upgrade choice restores controls")
	game.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(game.mode == "pause" and not controls.active, "Backgrounding pauses game")
	game.resume()
	root.go_back_requested.emit()
	check(game.mode == "pause" and not quit_on_go_back, "Android Back opens pause without quitting")
	check(game.stage == 1 and game.living_enemies() > 0, "Enemies still spawn with mobile controls")
	print("MOBILE TEST FAILURES: ", failures)
	quit(0 if failures == 0 else 1)
