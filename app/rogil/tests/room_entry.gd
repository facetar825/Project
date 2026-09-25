extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	print("PASS: " if ok else "FAIL: ", description)
	if not ok:
		failures += 1

func run() -> void:
	var game = load("res://Scene/Floor.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.dungeon.ready_for_play:
		await physics_frame
	var dungeon = game.dungeon
	for index in range(4):
		check(not dungeon.entered_room(index, dungeon.entrances[index] + dungeon.rooms[index].basis.z), "Outside room does not start wave %d" % index)
		check(dungeon.entered_room(index, dungeon.checkpoint(index)), "Center of entrance starts wave %d" % index)
		var inside: Vector3 = dungeon.rooms[index].to_global(Vector3(2.1, 0.35, -5))
		check(dungeon.entered_room(index, inside), "Off-center entry starts wave %d" % index)
		var past_trigger: Vector3 = dungeon.rooms[index].to_global(Vector3(0, 0.35, -10))
		check(dungeon.entered_room(index, past_trigger), "Crossing entry between frames starts wave %d" % index)
	game.start_run()
	game.hero.position = dungeon.rooms[0].to_global(Vector3(9, 0.35, -10))
	game.hero.invulnerability = 100
	game._process(0.01)
	check(game.stage == 1, "Wave starts with hero inside gallery")
	await create_timer(0.8).timeout
	check(game.living_enemies() > 0, "First enemy actually spawned")
	print("ROOM ENTRY TEST FAILURES: ", failures)
	quit(0 if failures == 0 else 1)
