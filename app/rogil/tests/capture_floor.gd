extends SceneTree
## Снимки реального рендера для проверки интерфейса (запуск без --headless).
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://Scene/Floor.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://floor-menu.png")
	game.start_run()
	game.spawn_enemy(0, Vector3(-3, 0.2, 2))
	game.spawn_enemy(1, Vector3(3, 0.2, -1))
	game.spawn_enemy(2, Vector3(-5, 0.2, -4))
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://floor-game.png")
	game.hero.collect(12)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://floor-upgrade.png")
	game.apply_upgrade("damage")
	game.stage = 3
	game.begin_stage()
	game.boss.slam_clock = 0
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://floor-boss.png")
	print("Screenshots: ", ProjectSettings.globalize_path("user://"))
	quit()
