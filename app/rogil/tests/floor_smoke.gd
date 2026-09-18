extends SceneTree
## Запуск: godot --headless --path app/rogil --script res://tests/floor_smoke.gd
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		failures += 1
	else:
		print("PASS: ", description)

func run() -> void:
	var packed = load("res://Scene/Floor.tscn")
	if not packed:
		quit(1)
		return
	var game = packed.instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	check(game.mode == "menu", "Start menu")
	game.start_run()
	check(game.stage == 1 and game.remaining == 10, "First wave starts")
	await physics_frame
	var starting_position: Vector3 = game.hero.position
	Input.action_press("up")
	await create_timer(0.15).timeout
	Input.action_release("up")
	check(game.hero.position.distance_to(starting_position) > 0.5, "Movement and walk animation")
	Input.action_press("sprint")
	await physics_frame
	await physics_frame
	Input.action_release("sprint")
	check(game.hero.dash_cooldown > 0 and game.hero.invulnerability > 0, "Dash and invulnerability")
	game.hero.dash_time = 0
	game.hero.invulnerability = 0
	var pause_event := InputEventKey.new()
	pause_event.keycode = KEY_ESCAPE
	pause_event.pressed = true
	game._unhandled_input(pause_event)
	var paused_clock: float = game.elapsed
	await create_timer(0.1).timeout
	check(game.mode == "pause" and game.elapsed == paused_clock, "Escape pauses simulation")
	game._unhandled_input(pause_event)
	check(game.mode == "playing", "Escape resumes simulation")
	game.hero.take_damage(20)
	check(game.hero.hp == 80, "Contact damage")
	game.hero.take_damage(20)
	check(game.hero.hp == 80, "Invulnerability prevents stacked damage")
	game.hero.collect(12)
	check(game.mode == "upgrade" and game.hero.level == 2, "Experience opens upgrade choice")
	var clock: float = game.elapsed
	var pos: Vector3 = game.hero.position
	await create_timer(0.1).timeout
	check(game.elapsed == clock and game.hero.position == pos, "Upgrade freezes gameplay")
	game.apply_upgrade("health")
	check(game.hero.max_hp == 125 and game.hero.hp == 120, "Health upgrade and healing")
	for id in ["damage", "haste", "range", "speed"]:
		game.mode = "upgrade"
		game.apply_upgrade(id)
	check(game.hero.damage == 32 and game.hero.attack_interval < 0.7 and game.hero.attack_range > 4.3 and game.hero.speed > 7, "All upgrades apply")
	# Проверяем настоящий удар игрока и выпадение опыта.
	game.spawn_enemy(0, game.hero.position + Vector3(1.5, 0, 0))
	var target = get_first_node_in_group("floor_enemies")
	game.hero.cooldown = 0
	await physics_frame
	await physics_frame
	check(target.hp < target.max_hp, "Automatic area attack")
	target.take_damage(999)
	check(game.gems.size() == 1 and game.kills == 1, "Enemy drops one experience shard")
	await process_frame
	# Все три волны должны закончиться и перевести игрока к боссу.
	for expected_stage in range(1, 4):
		check(game.stage == expected_stage, "Wave order %d" % expected_stage)
		game.remaining = 0
		for enemy in get_nodes_in_group("floor_enemies"):
			enemy.take_damage(9999)
		await process_frame
		game.mode = "playing"
		game._process(0.01)
		check(game.intermission > 0, "Cleared wave starts rest")
		game.intermission = 0.01
		game._process(0.02)
	check(game.stage == 4 and is_instance_valid(game.boss), "Boss spawns after third seal")
	game.mode = "playing"
	game.boss.slam_clock = 0
	game.boss._physics_process(0.01)
	check(game.boss.warning_time > 0 and is_instance_valid(game.boss.warning), "Boss telegraphs slam")
	game.hero.position = game.boss.position + Vector3(10, 0, 0)
	var hp: float = game.hero.hp
	game.boss._physics_process(2)
	check(game.hero.hp == hp, "Leaving slam radius avoids damage")
	game.boss.take_damage(9999)
	check(game.portal.visible, "Boss death unlocks exit")
	game.hero.position = game.portal.position
	game.mode = "playing"
	game._process(0.01)
	check(game.mode == "victory", "Entering portal completes floor")
	game.restart()
	await process_frame
	await process_frame
	game = current_scene
	check(game.mode == "playing" and game.kills == 0 and game.hero.level == 1 and game.stage == 1, "Restart resets run")
	game.hero.invulnerability = 0
	game.hero.take_damage(9999)
	check(game.mode == "defeat", "Death opens result screen")
	print("FLOOR TEST FAILURES: ", failures)
	quit(0 if failures == 0 else 1)
