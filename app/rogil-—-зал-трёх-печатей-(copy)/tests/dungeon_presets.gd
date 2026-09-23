extends SceneTree
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	if ok:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)

func run() -> void:
	var game = load("res://Scene/Floor.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.dungeon.ready_for_play:
		await physics_frame
	var dungeon = game.dungeon
	check(dungeon.rooms.size() == 4, "Four rooms instantiated from presets")
	for index in range(4):
		var room = dungeon.rooms[index]
		check(room.scene_file_path == dungeon.PRESETS[index].resource_path, "Original PackedScene %d" % index)
		check(dungeon.spawn_cells[index].size() > 0, "Walkable spawn points %d" % index)
		var entrance: Vector3 = dungeon.checkpoint(index)
		var exit: Vector3 = dungeon.exits[index]
		var path: PackedVector3Array = dungeon.route(entrance, exit)
		check(path.size() > 3, "Navigable room entrance to exit %d" % index)
		if index < 3:
			check(not dungeon.route(entrance, dungeon.checkpoint(index + 1)).is_empty(), "Connected doorway %d" % index)
		for sample in range(8):
			var point: Vector3 = dungeon.spawn_point(index, entrance, game.rng)
			check(dungeon.contains_point(index, point) and not dungeon.route(point, entrance).is_empty(), "Reachable spawn %d:%d" % [index, sample])
	# Пресет comtwo содержит стену от z=0 до z=-18 в локальных координатах.
	var maze: Node3D = dungeon.rooms[2]
	var left := maze.to_global(Vector3(-14, 0.3, -8))
	var right := maze.to_global(Vector3(-8, 0.3, -8))
	check(not dungeon.clear_sight(left, right), "Maze wall blocks attacks")
	var detour: PackedVector3Array = dungeon.route(left, right)
	check(detour.size() > 12, "Enemy route goes around maze partition")
	# Физически проводим героя через каждый стык: пол непрерывен, рамы проходимы.
	game.hero.set_physics_process(false)
	for index in range(4):
		dungeon.set_gate(index, false)
		var forward: Vector3 = -dungeon.rooms[index].basis.z
		game.hero.position = dungeon.entrances[index] - forward * 1.3 + Vector3.UP * 0.4
		game.hero.velocity = Vector3.ZERO
		for frame in range(100):
			await physics_frame
			game.hero.velocity = forward * 3 + Vector3.DOWN * 3
			game.hero.move_and_slide()
		var crossed: float = (game.hero.position - dungeon.entrances[index]).dot(forward)
		check(crossed > 2.5 and game.hero.position.y > -0.5, "Physical doorway traversal %d" % index)
		dungeon.set_gate(index, true)
		game.hero.position = dungeon.entrances[index] - forward * 1.3 + Vector3.UP * 0.4
		for frame in range(35):
			await physics_frame
			game.hero.velocity = forward * 3 + Vector3.DOWN * 3
			game.hero.move_and_slide()
		check((game.hero.position - dungeon.entrances[index]).dot(forward) < 0, "Closed seal blocks doorway %d" % index)
	# Проверяем не только расчёт пути, но и движение настоящего врага вокруг стены.
	game.mode = "playing"
	game.hero.position = right
	game.hero.invulnerability = 1000
	game.spawn_enemy(0, left)
	var enemy = get_first_node_in_group("floor_enemies")
	Engine.time_scale = 8
	for frame in range(1400):
		await physics_frame
		if enemy.position.distance_to(game.hero.position) < 2:
			break
	check(enemy.position.distance_to(game.hero.position) < 2, "Enemy physically follows detour to player")
	Engine.time_scale = 1
	print("DUNGEON TEST FAILURES: ", failures)
	quit(0 if failures == 0 else 1)
