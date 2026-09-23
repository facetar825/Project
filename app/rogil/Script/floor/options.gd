extends Node
## Настройки этажа. Отдельный файл сохраняет совместимость со старым прототипом.
signal option_changed(key: StringName, value: Variant)

const DEFAULTS := {
	"master_volume": 0.85, "music_volume": 0.55, "sfx_volume": 0.85,
	"sensitivity": 1.0, "fullscreen": false, "shadows": true,
	"particles": true, "blood": true, "camera_shake": true,
	"brightness": 1.0, "fov": 70.0,
}
const RANGES := {
	"master_volume": Vector2(0.0, 1.0), "music_volume": Vector2(0.0, 1.0),
	"sfx_volume": Vector2(0.0, 1.0), "sensitivity": Vector2(0.2, 2.5),
	"brightness": Vector2(0.65, 1.5), "fov": Vector2(55.0, 95.0),
}
const ACCENT := Color("e74a62")
const WHITE := Color("f2e9e9")
const MUTED := Color("a396a3")

var settings_path := "user://rogil_options.cfg"
var master_volume := 0.85
var music_volume := 0.55
var sfx_volume := 0.85
var sensitivity := 1.0
var fullscreen := false
var shadows := true
var particles := true
var blood := true
var camera_shake := true
var brightness := 1.0
var fov := 70.0
var _widgets: Dictionary = {}
var _save_timer: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_options()
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.2
	_save_timer.timeout.connect(save_options)
	add_child(_save_timer)
	get_tree().node_added.connect(_on_node_added)
	apply_all()


func _exit_tree() -> void:
	# Быстрое закрытие окна не должно потерять последнее движение ползунка.
	if _save_timer != null and not _save_timer.is_stopped():
		save_options()


func load_options() -> void:
	var config := ConfigFile.new()
	if config.load(settings_path) != OK:
		return
	for key: String in DEFAULTS:
		var value: Variant = config.get_value("options", key, DEFAULTS[key])
		set(key, _validated_value(key, value))


func save_options() -> void:
	var config := ConfigFile.new()
	for key: String in DEFAULTS:
		config.set_value("options", key, get(key))
	var error := config.save(settings_path)
	if error != OK:
		push_warning("Не удалось сохранить настройки: %s" % error_string(error))


func _validated_value(key: String, value: Variant) -> Variant:
	if RANGES.has(key):
		if typeof(value) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(value)):
			return DEFAULTS[key]
		var limits: Vector2 = RANGES[key]
		return clampf(float(value), limits.x, limits.y)
	return value if typeof(value) == TYPE_BOOL else DEFAULTS[key]


func set_option(key: String, value: Variant) -> void:
	if not DEFAULTS.has(key):
		return
	var validated: Variant = _validated_value(key, value)
	set(key, validated)
	if key in ["master_volume", "music_volume", "sfx_volume"]:
		_apply_audio()
	elif key == "fullscreen":
		_apply_display()
	elif key in ["shadows", "brightness", "fov"]:
		_apply_visuals()
	option_changed.emit(StringName(key), validated)
	_sync_widgets()
	if is_instance_valid(_save_timer):
		_save_timer.start()
	else:
		save_options()


func restore_defaults() -> void:
	for key: String in DEFAULTS:
		set(key, DEFAULTS[key])
	apply_all()
	_sync_widgets()
	for key: String in DEFAULTS:
		option_changed.emit(StringName(key), get(key))
	save_options()


func apply_all() -> void:
	_apply_audio()
	_apply_display()
	_apply_visuals()


func _apply_audio() -> void:
	# Шины создаются и при открытии настроек до запуска звукового контроллера.
	for bus_name: String in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, "Master")
	for bus_name: String in ["Master", "Music", "SFX"]:
		var key: String = {"Master": "master_volume", "Music": "music_volume", "SFX": "sfx_volume"}[bus_name]
		var volume: float = get(key)
		var index := AudioServer.get_bus_index(bus_name)
		AudioServer.set_bus_mute(index, volume <= 0.0001)
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.0001)))


func _apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var target := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != target:
		DisplayServer.window_set_mode(target)


func _apply_visuals() -> void:
	if not is_inside_tree():
		return
	for node: Node in get_tree().root.find_children("*", "", true, false):
		_apply_visual_node(node)


func _on_node_added(node: Node) -> void:
	if node is Camera3D or node is DirectionalLight3D or node is WorldEnvironment:
		# Свойства новых объектов обычно заполняются после add_child().
		call_deferred("_apply_visual_node", node)


func _apply_visual_node(node: Node) -> void:
	if not is_instance_valid(node):
		return
	if node is Camera3D:
		node.fov = fov
	elif node is DirectionalLight3D:
		node.shadow_enabled = shadows
	elif node is WorldEnvironment and node.environment != null:
		var environment: Environment = node.environment
		if not environment.has_meta("rogil_base_exposure"):
			environment.set_meta("rogil_base_exposure", environment.tonemap_exposure)
		environment.tonemap_exposure = float(environment.get_meta("rogil_base_exposure")) * brightness


func create_panel(parent: VBoxContainer, on_back: Callable) -> void:
	_widgets.clear()
	var body := VBoxContainer.new()
	body.name = "OptionsPanel"
	body.add_theme_constant_override("separation", 12)
	parent.add_child(body)
	body.add_child(_label("Н А С Т Р О Й К И", 26, WHITE))
	body.add_child(_label("Твой ритм. Твоя охота. Изменения сохраняются автоматически.", 14, MUTED))
	var tabs := TabContainer.new()
	tabs.name = "OptionsTabs"
	tabs.custom_minimum_size = Vector2(560, 328)
	tabs.add_theme_font_size_override("font_size", 16)
	tabs.add_theme_color_override("font_selected_color", WHITE)
	tabs.add_theme_color_override("font_unselected_color", MUTED)
	tabs.add_theme_stylebox_override("panel", _style(Color("151019"), Color("40303c"), 14))
	tabs.add_theme_stylebox_override("tab_selected", _style(Color("38202d"), ACCENT, 12))
	tabs.add_theme_stylebox_override("tab_unselected", _style(Color("1b141f"), Color("352733"), 12))
	tabs.add_theme_stylebox_override("tab_hovered", _style(Color("482334"), ACCENT, 12))
	body.add_child(tabs)
	var audio := _tab(tabs, "Звук")
	_slider(audio, "master_volume", "Общая громкость", "Все звуки игры", 0.01, "%")
	_slider(audio, "music_volume", "Музыка", "Атмосфера и музыка сражений", 0.01, "%")
	_slider(audio, "sfx_volume", "Эффекты", "Удары, рывок, враги и интерфейс", 0.01, "%")
	var video := _tab(tabs, "Изображение")
	_toggle(video, "fullscreen", "Полный экран")
	_toggle(video, "shadows", "Тени персонажей и окружения")
	_slider(video, "brightness", "Яркость", "Подстрой под свой экран", 0.05, "x")
	_slider(video, "fov", "Угол обзора", "Шире — больше пространства вокруг", 1.0, "°")
	var gameplay := _tab(tabs, "Управление")
	_slider(gameplay, "sensitivity", "Чувствительность мыши", "Скорость поворота камеры", 0.05, "x")
	_toggle(gameplay, "camera_shake", "Тряска камеры при ударах")
	_toggle(gameplay, "particles", "Частицы и искры")
	_toggle(gameplay, "blood", "Кровь и следы попаданий")
	gameplay.add_child(_label("WASD — движение  ·  Shift — рывок  ·  Space — прыжок", 12, MUTED))
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	body.add_child(footer)
	var reset := _button("По умолчанию")
	reset.name = "RestoreDefaults"
	reset.tooltip_text = "Вернуть исходные настройки звука, изображения и управления"
	reset.pressed.connect(restore_defaults)
	footer.add_child(reset)
	var back := _button("НАЗАД")
	back.name = "OptionsBack"
	back.add_theme_stylebox_override("normal", _style(Color("70273b"), Color("c44a63"), 10))
	back.pressed.connect(func() -> void:
		save_options()
		on_back.call()
	)
	footer.add_child(back)
	back.call_deferred("grab_focus")


func _tab(tabs: TabContainer, title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 12)
	scroll.add_child(column)
	return column


func _slider(parent: VBoxContainer, key: String, title: String, hint: String, step: float, suffix: String) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	parent.add_child(row)
	var heading := HBoxContainer.new()
	row.add_child(heading)
	var name_label := _label(title, 16, WHITE)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(name_label)
	var value_label := _label(_value_text(key, suffix), 15, ACCENT)
	value_label.custom_minimum_size.x = 58
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	heading.add_child(value_label)
	var slider := HSlider.new()
	slider.name = key
	var limits: Vector2 = RANGES[key]
	slider.min_value = limits.x
	slider.max_value = limits.y
	slider.step = step
	slider.value = get(key)
	slider.custom_minimum_size.y = 24
	slider.tooltip_text = hint
	slider.add_theme_stylebox_override("slider", _style(Color("3a2b39"), Color("3a2b39"), 2))
	slider.add_theme_stylebox_override("grabber_area", _style(ACCENT, ACCENT, 2))
	slider.add_theme_stylebox_override("grabber_area_highlight", _style(Color("ff7990"), Color("ff7990"), 2))
	slider.value_changed.connect(func(value: float) -> void: set_option(key, value))
	row.add_child(slider)
	row.add_child(_label(hint, 12, MUTED))
	_widgets[key] = {"control": slider, "value_label": value_label, "suffix": suffix}


func _toggle(parent: VBoxContainer, key: String, title: String) -> void:
	var toggle := CheckButton.new()
	toggle.name = key
	toggle.text = title
	toggle.button_pressed = get(key)
	toggle.custom_minimum_size.y = 34
	toggle.add_theme_font_size_override("font_size", 16)
	toggle.add_theme_color_override("font_color", WHITE)
	toggle.toggled.connect(func(value: bool) -> void: set_option(key, value))
	parent.add_child(toggle)
	_widgets[key] = {"control": toggle}


func _sync_widgets() -> void:
	for key: String in _widgets:
		var entry: Dictionary = _widgets[key]
		if not is_instance_valid(entry.control):
			continue
		if entry.control is Range:
			entry.control.set_value_no_signal(get(key))
			entry.value_label.text = _value_text(key, entry.suffix)
		elif entry.control is BaseButton:
			entry.control.set_pressed_no_signal(get(key))


func _value_text(key: String, suffix: String) -> String:
	var value: float = get(key)
	if suffix == "%":
		return "%d%%" % roundi(value * 100)
	if suffix == "°":
		return "%d°" % roundi(value)
	return ("%.2f×" % value).replace(".", ",")


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = 44
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_stylebox_override("normal", _style(Color("231a27"), Color("53404e"), 10))
	button.add_theme_stylebox_override("hover", _style(Color("542334"), ACCENT, 10))
	button.add_theme_stylebox_override("pressed", _style(Color("8b2942"), ACCENT, 10))
	button.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), ACCENT, 0))
	return button


func _label(text: String, font_size: int, color: Color) -> Label:
	var item := Label.new()
	item.text = text
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", color)
	return item


func _style(background: Color, border: Color, padding: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding * 0.6
	style.content_margin_bottom = padding * 0.6
	return style
