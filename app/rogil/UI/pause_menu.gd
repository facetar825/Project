extends Control

@onready var resolution_option = $Panel/ResolutionOption    # OptionButton
@onready var shadow_option = $Panel/ShadowOption            # OptionButton
@onready var light_option = $Panel/LightOption              # OptionButton
@onready var volume_slider = $Panel/VolumeSlider            # HSlider (не OptionButton!)
@onready var display_mode_option = $Panel/DisplayModeOption # OptionButton

func _ready() -> void:
	# Заполняем списки
	resolution_option.add_item("1920x1080")
	resolution_option.add_item("1600x900")
	resolution_option.add_item("1366x768")
	resolution_option.add_item("1280x720")

	shadow_option.add_item("Off")
	shadow_option.add_item("Low")
	shadow_option.add_item("Medium")
	shadow_option.add_item("High")

	light_option.add_item("Low")
	light_option.add_item("Medium")
	light_option.add_item("High")

	display_mode_option.add_item("Windowed")
	display_mode_option.add_item("Fullscreen")
	display_mode_option.add_item("Borderless")

	# Загружаем текущие настройки в виджеты
	_update_widgets()

	# Подключаем сигналы
	resolution_option.item_selected.connect(_on_resolution_changed)
	shadow_option.item_selected.connect(_on_shadow_changed)
	light_option.item_selected.connect(_on_light_changed)
	volume_slider.value_changed.connect(_on_volume_changed)
	display_mode_option.item_selected.connect(_on_display_mode_changed)

func _update_widgets() -> void:
	# Разрешение - ищем по тексту
	var res_str = str(SettingsManager.resolution.x) + "x" + str(SettingsManager.resolution.y)
	var res_index = -1
	for i in resolution_option.item_count:
		if resolution_option.get_item_text(i) == res_str:
			res_index = i
			break
	if res_index != -1:
		resolution_option.select(res_index)

	# Качество теней
	shadow_option.select(SettingsManager.shadow_quality)

	# Качество освещения
	light_option.select(SettingsManager.light_quality)

	# Громкость
	volume_slider.value = SettingsManager.master_volume

	# Режим экрана
	display_mode_option.select(SettingsManager.display_mode)
# ---------- Обработчики изменений ----------
func _on_resolution_changed(index: int) -> void:
	var text = resolution_option.get_item_text(index)
	var parts = text.split("x")
	if parts.size() == 2:
		var res = Vector2i(int(parts[0]), int(parts[1]))
		SettingsManager.set_resolution(res)

func _on_shadow_changed(index: int) -> void:
	SettingsManager.set_shadow_quality(index)

func _on_light_changed(index: int) -> void:
	SettingsManager.set_light_quality(index)

func _on_volume_changed(value: float) -> void:
	SettingsManager.set_master_volume(value)

func _on_display_mode_changed(index: int) -> void:
	SettingsManager.set_display_mode(index)
