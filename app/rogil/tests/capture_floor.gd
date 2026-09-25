extends SceneTree
## Снимки реального рендера для проверки интерфейса (запуск без --headless).
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://Scene/Floor.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	while not game.dungeon.ready_for_play:
		await physics_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://floor-menu.png")
	game.start_run()
	game.hero.position = game.dungeon.checkpoint(0)
	game._process(0.01)
	game.hero.position = game.dungeon.rooms[0].to_global(Vector3(9, 0.3, -10))
	game.hero.pivot.rotation.y = -PI / 2
	game.spawn_enemy(0, game.hero.position + Vector3(6, 0, 2))
	game.spawn_enemy(1, game.hero.position + Vector3(9, 0, -2))
	game.spawn_enemy(2, game.hero.position + Vector3(14, 0, 3))
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://floor-game.png")
	game.hero.collect(12)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://floor-upgrade.png")
	game.apply_upgrade("damage")
	game.stage = 3
	game.hero.position = game.dungeon.rooms[3].to_global(Vector3(0, 0.3, -12))
	game.hero.pivot.rotation.y = PI / 2
	game.begin_stage()
	game.boss.slam_clock = 0
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://floor-boss.png")
	game.mode = "pause"
	game.hero.position = game.dungeon.rooms[2].to_global(Vector3(4, 0.3, -9))
	game.hero.pivot.rotation.y = 0
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://floor-maze.png")
	var camera := Camera3D.new()
	game.add_child(camera)
	camera.position = Vector3(20, 180, -74)
	camera.rotation.x = -PI / 2
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 195
	camera.far = 400
	camera.current = true
	game.hud.hide()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://floor-layout.png")
	print("Screenshots: ", ProjectSettings.globalize_path("user://"))
	quit()
