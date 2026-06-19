extends Node

# ---------- Настройки (значения по умолчанию) ----------
var resolution: Vector2i = Vector2i(1920, 1080)
var shadow_quality: int = 2          # 0=Off, 1=Low, 2=Medium, 3=High
var light_quality: int = 2           # 0=Low, 1=Medium, 2=High
var master_volume: float = 0.8       # 0.0 .. 1.0
var display_mode: int = 0            # 0=Windowed, 1=Fullscreen, 2=Borderless
var mouse_sensitivity: float = 1.0   # 0.1 .. 3.0 (чувствительность мыши)

const SETTINGS_PATH = "user://settings.ini"

# Кеш для источников света
var _cached_lights: Array = []

# ---------- Загрузка / сохранение ----------
func _ready() -> void:
	load_settings()
	apply_all_settings()
	# Обновляем кеш при изменении сцены
	get_tree().node_added.connect(_on_node_added)
	get_tree().node_removed.connect(_on_node_removed)

func load_settings() -> void:
	var config = ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return

	var res_str = config.get_value("Video", "resolution", "1920x1080")
	var parts = res_str.split("x")
	if parts.size() == 2:
		resolution = Vector2i(int(parts[0]), int(parts[1]))

	shadow_quality = config.get_value("Video", "shadow_quality", 2)
	light_quality  = config.get_value("Video", "light_quality", 2)
	master_volume  = config.get_value("Audio", "master_volume", 0.8)
	display_mode   = config.get_value("Video", "display_mode", 0)
	mouse_sensitivity = config.get_value("Controls", "mouse_sensitivity", 1.0)

func save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("Video", "resolution", str(resolution.x) + "x" + str(resolution.y))
	config.set_value("Video", "shadow_quality", shadow_quality)
	config.set_value("Video", "light_quality", light_quality)
	config.set_value("Audio", "master_volume", master_volume)
	config.set_value("Video", "display_mode", display_mode)
	config.set_value("Controls", "mouse_sensitivity", mouse_sensitivity)
	config.save(SETTINGS_PATH)

# ---------- Применение всех настроек ----------
func apply_all_settings() -> void:
	apply_display_settings()
	apply_shadow_settings()
	apply_light_settings()
	apply_audio_settings()
	# Чувствительность мыши применяется в игре, здесь просто сохраняем

# ---------- Отдельные применения ----------
func apply_display_settings() -> void:
	DisplayServer.window_set_size(resolution)

	match display_mode:
		0:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			var screen_size = DisplayServer.screen_get_size()
			DisplayServer.window_set_size(screen_size)

func apply_shadow_settings() -> void:
	# Обновляем кеш
	_cached_lights = _find_all_lights(get_tree().root)
	
	for light in _cached_lights:
		if not is_instance_valid(light):
			continue
			
		# Включаем/выключаем тени
		light.shadow_enabled = (shadow_quality > 0)
		
		if shadow_quality > 0:
			# Настраиваем качество теней
			var shadow_size = 1024
			var shadow_bias = 0.1
			
			match shadow_quality:
				1:  # Low
					shadow_size = 512
					shadow_bias = 0.2
				2:  # Medium
					shadow_size = 1024
					shadow_bias = 0.1
				3:  # High
					shadow_size = 2048
					shadow_bias = 0.05
			
			# Применяем настройки в зависимости от типа света
			if light is DirectionalLight3D:
				light.directional_shadow_max_distance = 100.0
				light.shadow_bias = shadow_bias
				
			elif light is OmniLight3D:
				light.shadow_bias = shadow_bias
				if light.has_method("set_omni_shadow_size"):
					light.set_omni_shadow_size(shadow_size)
				
			elif light is SpotLight3D:
				light.shadow_bias = shadow_bias
				if light.has_method("set_spot_shadow_size"):
					light.set_spot_shadow_size(shadow_size)

func apply_light_settings() -> void:
	var env_node = get_tree().root.get_node_or_null("WorldEnvironment")
	if env_node and env_node.environment:
		var env = env_node.environment
		match light_quality:
			0:  # Low
				env.ambient_light_energy = 0.3
				env.ambient_light_sky_contribution = 0.3
			1:  # Medium
				env.ambient_light_energy = 0.6
				env.ambient_light_sky_contribution = 0.6
			2:  # High
				env.ambient_light_energy = 1.0
				env.ambient_light_sky_contribution = 1.0

func apply_audio_settings() -> void:
	var master = AudioServer.get_bus_index("Master")
	if master != -1:
		var volume_db = linear_to_db(master_volume)
		AudioServer.set_bus_volume_db(master, volume_db)

# ---------- Поиск всех источников света ----------
func _find_all_lights(node: Node) -> Array:
	var result = []
	for child in node.get_children():
		if child is Light3D:
			result.append(child)
		result.append_array(_find_all_lights(child))
	return result

# ---------- Обновление кеша при изменении сцены ----------
func _on_node_added(node: Node) -> void:
	if node is Light3D:
		_cached_lights.append(node)

func _on_node_removed(node: Node) -> void:
	if node is Light3D:
		_cached_lights.erase(node)

# ---------- Методы для привязки к виджетам ----------
func set_resolution(res: Vector2i) -> void:
	resolution = res
	save_settings()
	apply_all_settings()

func set_shadow_quality(value: int) -> void:
	shadow_quality = value
	save_settings()
	apply_all_settings()

func set_light_quality(value: int) -> void:
	light_quality = value
	save_settings()
	apply_all_settings()

func set_master_volume(value: float) -> void:
	master_volume = value
	save_settings()
	apply_all_settings()

func set_display_mode(value: int) -> void:
	display_mode = value
	save_settings()
	apply_all_settings()

func set_mouse_sensitivity(value: float) -> void:
	mouse_sensitivity = value
	save_settings()
	# Применяем сразу, если есть активный игрок
	apply_mouse_sensitivity()

func apply_mouse_sensitivity() -> void:
	# Применяем чувствительность к текущему игроку
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("set_mouse_sensitivity"):
		player.set_mouse_sensitivity(mouse_sensitivity)
	# Или можно применить к камере
	var camera = get_tree().get_first_node_in_group("camera")
	if camera and camera.has_method("set_mouse_sensitivity"):
		camera.set_mouse_sensitivity(mouse_sensitivity)
