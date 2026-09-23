extends Control

@onready var resolution_option = $Panel/ResolutionOption
@onready var shadow_option = $Panel/ShadowOption
@onready var light_option = $Panel/LightOption
@onready var volume_slider = $Panel/VolumeSlider
@onready var display_mode_option = $Panel/DisplayModeOption
@onready var sensitivity_slider = $Panel/SensitivitySlider    # HSlider для чувствительности
@onready var sensitivity_label = $Panel/SensitivityValue      # Label для отображения значения

var resolution_map = {
	"1920x1080": 0,
	"1600x900": 1,
	"1366x768": 2,
	"1280x720": 3
}

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

	# Настройка слайдера громкости
	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = 0.01

	# Настройка слайдера чувствительности
	sensitivity_slider.min_value = 0.1
	sensitivity_slider.max_value = 3.0
	sensitivity_slider.step = 0.05

	# Загружаем текущие настройки в виджеты
	_update_widgets()

	# Подключаем сигналы
	resolution_option.item_selected.connect(_on_resolution_changed)
	shadow_option.item_selected.connect(_on_shadow_changed)
	light_option.item_selected.connect(_on_light_changed)
	volume_slider.value_changed.connect(_on_volume_changed)
	display_mode_option.item_selected.connect(_on_display_mode_changed)
	sensitivity_slider.value_changed.connect(_on_sensitivity_changed)

func _update_widgets() -> void:
	# Разрешение
	var res_str = str(SettingsManager.resolution.x) + "x" + str(SettingsManager.resolution.y)
	if resolution_map.has(res_str):
		resolution_option.select(resolution_map[res_str])
	else:
		resolution_option.select(0)

	# Качество теней
	shadow_option.select(SettingsManager.shadow_quality)

	# Качество освещения
	light_option.select(SettingsManager.light_quality)

	# Громкость
	volume_slider.value = SettingsManager.master_volume

	# Режим экрана
	display_mode_option.select(SettingsManager.display_mode)

	# Чувствительность мыши
	sensitivity_slider.value = SettingsManager.mouse_sensitivity
	_update_sensitivity_label()

func _update_sensitivity_label() -> void:
	if sensitivity_label:
		var percent = sensitivity_slider.value / 3.0 * 100
		sensitivity_label.text = str(round(percent)) + "%"

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

func _on_sensitivity_changed(value: float) -> void:
	SettingsManager.set_mouse_sensitivity(value)
	_update_sensitivity_label()
