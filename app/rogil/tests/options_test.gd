extends SceneTree
## godot --headless --path app/rogil --script res://tests/options_test.gd
const Options = preload("res://Script/floor/options.gd")
var failures := 0
var checks := 0
var back_calls := 0
var changed_keys: Array[StringName] = []


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		push_error(description)
		failures += 1


func run() -> void:
	# Уникальный файл: реальные предпочтения игрока никогда не трогаем.
	var path := "user://rogil_options_test_%d.cfg" % OS.get_process_id()
	var options := Options.new()
	options.settings_path = path
	root.add_child(options)
	options.option_changed.connect(func(key: StringName, _value: Variant) -> void: changed_keys.append(key))
	check(is_equal_approx(options.music_volume, 0.55), "Missing file loads defaults")
	options.set_option("master_volume", 0.0)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")), "Zero volume mutes Master")
	options.set_option("master_volume", 0.72)
	options.set_option("music_volume", 0.28)
	options.set_option("sfx_volume", 0.63)
	check(not AudioServer.is_bus_mute(0), "Increasing volume unmutes Master")
	check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))), 0.28), "Music bus gets independent volume")
	check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))), 0.63), "SFX bus gets independent volume")
	options.set_option("sensitivity", 999.0)
	options.set_option("fov", -3.0)
	check(options.sensitivity == 2.5 and options.fov == 55.0, "Numeric settings stay in valid ranges")
	options.set_option("blood", false)
	check(&"blood" in changed_keys and not options.blood, "Gameplay setting emits live change")
	await create_timer(0.25).timeout
	check(FileAccess.file_exists(path), "Debounced changes persist automatically")
	var reloaded := Options.new()
	reloaded.settings_path = path
	reloaded.load_options()
	check(is_equal_approx(reloaded.master_volume, 0.72) and not reloaded.blood and reloaded.sensitivity == 2.5, "Options survive reload")
	reloaded.free()
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	var light := DirectionalLight3D.new()
	world.add_child(light)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.tonemap_exposure = 0.8
	world.add_child(environment)
	options.set_option("shadows", false)
	options.set_option("brightness", 1.25)
	options.set_option("fov", 84.0)
	options.apply_all()
	options.apply_all()
	check(not light.shadow_enabled and camera.fov == 84.0, "Visual options apply to the active world")
	check(is_equal_approx(environment.environment.tonemap_exposure, 1.0), "Brightness uses stable base exposure without compounding")
	var late_camera := Camera3D.new()
	world.add_child(late_camera)
	await process_frame
	check(late_camera.fov == 84.0, "New cameras inherit saved FoV")
	var parent := VBoxContainer.new()
	parent.size = Vector2(610, 540)
	root.add_child(parent)
	options.create_panel(parent, func() -> void: back_calls += 1)
	await process_frame
	await process_frame
	var tabs: TabContainer = parent.find_child("OptionsTabs", true, false)
	check(tabs.get_tab_count() == 3, "Settings panel has all three categories")
	var slider: HSlider = parent.find_child("music_volume", true, false)
	slider.value = 0.41
	check(is_equal_approx(options.music_volume, 0.41), "Panel sliders apply changes")
	var toggle: CheckButton = parent.find_child("blood", true, false)
	toggle.button_pressed = true
	check(options.blood, "Panel switches apply changes")
	var reset: Button = parent.find_child("RestoreDefaults", true, false)
	reset.pressed.emit()
	check(options.blood and options.camera_shake and is_equal_approx(options.music_volume, 0.55), "Restore defaults resets all settings")
	check(is_equal_approx(slider.value, 0.55) and toggle.button_pressed, "Reset refreshes visible controls")
	var back: Button = parent.find_child("OptionsBack", true, false)
	back.pressed.emit()
	check(back_calls == 1, "Back returns through supplied callback")
	check(parent.get_combined_minimum_size().x <= 610 and parent.get_combined_minimum_size().y <= 550, "Settings content fits the 1280x720 modal")
	# Испорченный конфиг не должен передать строку или NaN в аудио/камеру.
	var malformed := ConfigFile.new()
	malformed.set_value("options", "master_volume", "broken")
	malformed.set_value("options", "fov", -200)
	malformed.set_value("options", "blood", 1)
	malformed.save(path)
	var validated := Options.new()
	validated.settings_path = path
	validated.load_options()
	check(validated.master_volume == 0.85 and validated.fov == 55.0 and validated.blood, "Malformed file is validated safely")
	validated.free()
	parent.free()
	world.free()
	options.free()
	DirAccess.remove_absolute(path)
	print("Settings: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
