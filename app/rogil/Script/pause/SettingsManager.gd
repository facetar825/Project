extends Node

# ---------- Настройки (значения по умолчанию) ----------
var resolution: Vector2i = Vector2i(1920, 1080)
var shadow_quality: int = 2          # 0=Off, 1=Low, 2=Medium, 3=High
var light_quality: int = 2           # 0=Low, 1=Medium, 2=High
var master_volume: float = 0.8       # 0.0 .. 1.0
var display_mode: int = 0            # 0=Windowed, 1=Fullscreen, 2=Borderless

const SETTINGS_PATH = "user://settings.ini"

# Кеш для источников света (обновляем при изменении сцены)
var _cached_lights: Array = []

# ---------- Загрузка / сохранение ----------
func _ready() -> void:
	load_settings()
	apply_all_settings()
	# Обновляем кеш при смене сцены
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

func save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("Video", "resolution", str(resolution.x) + "x" + str(resolution.y))
	config.set_value("Video", "shadow_quality", shadow_quality)
	config.set_value("Video", "light_quality", light_quality)
	config.set_value("Audio", "master_volume", master_volume)
	config.set_value("Video", "display_mode", display_mode)
	config.save(SETTINGS_PATH)

# ---------- Применение всех настроек ----------
func apply_all_settings() -> void:
	apply_display_settings()
	apply_shadow_settings()
	apply_light_settings()
	apply_audio_settings()

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
	_cached_lights = _find_all_lights(get_tree().root)
	
	for light in _cached_lights:
		if not is_instance_valid(light):
			continue
			
		light.shadow_enabled = (shadow_quality > 0)
		
		if shadow_quality > 0:
			# Просто регулируем bias в зависимости от качества
			match shadow_quality:
				1: light.shadow_bias = 0.2   # Низкое качество
				2: light.shadow_bias = 0.1   # Среднее
				3: light.shadow_bias = 0.05  # Высокое

func apply_light_settings() -> void:
	var env_node = get_tree().root.get_node_or_null("WorldEnvironment")
	if env_node and env_node.environment:
		var env = env_node.environment
		match light_quality:
			0:
				env.ambient_light_energy = 0.4
			1:
				env.ambient_light_energy = 0.7
			2:
				env.ambient_light_energy = 1.0

func apply_audio_settings() -> void:
	var master = AudioServer.get_bus_index("Master")
	if master != -1:
		var volume_db = linear_to_db(master_volume)
		AudioServer.set_bus_volume_db(master, volume_db)

# ---------- Поиск всех источников света (исправленная версия) ----------
func _find_all_lights(node: Node) -> Array:
	var result = []
	for child in node.get_children():
		# Проверяем, является ли child Light3D или его наследником
		if child is Light3D:
			result.append(child)
		# Рекурсивно обходим всех детей
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
