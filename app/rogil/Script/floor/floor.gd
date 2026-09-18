extends Node3D
## Один законченный забег: три печати, страж, выход.
const Visuals = preload("res://Script/floor/visuals.gd")
const Hero = preload("res://Script/floor/hero.gd")
const Foe = preload("res://Script/floor/foe.gd")
const AMBER := Color("edc17b")
const TEAL := Color("78dbcb")
const UPGRADES := [
	["ТЯЖЁЛЫЙ УДАР", "+8 к урону каждого удара", "damage"],
	["БЫСТРЫЕ РУКИ", "Атака на 15% чаще", "haste"],
	["ВТОРОЕ ДЫХАНИЕ", "+25 к здоровью и лечение на 40", "health"],
	["ДЛИННОЕ ЛЕЗВИЕ", "+0,6 м к радиусу атаки", "range"],
	["ЛЁГКИЙ ШАГ", "+0,7 к скорости движения", "speed"],
]
var hero: CharacterBody3D
var mode := "menu"
var stage := 0
var kills := 0
var elapsed := 0.0
var spawn_clock := 0.0
var remaining := 0
var intermission := 0.0
var gems: Array[Node3D] = []
var seals: Array[MeshInstance3D] = []
var portal: Node3D
var boss: CharacterBody3D
var hud: MarginContainer
var stats: Label
var objective: Label
var hp_bar: ProgressBar
var xp_bar: ProgressBar
var boss_bar: ProgressBar
var overlay: ColorRect
var modal: VBoxContainer
var message: Label
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	build_world()
	hero = Hero.new()
	hero.game = self
	add_child(hero)
	hero.position = Vector3(0, 0.2, 9)
	build_ui()
	show_menu()

func build_world() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("111d26")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("a9c4d0")
	settings.ambient_light_energy = 0.65
	environment.environment = settings
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	sun.light_color = Color("ffe3b5")
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)
	Visuals.box(self, Vector3(0, -0.6, 0), Vector3(49, 1, 49), Color("313f45"), true)
	for x in range(-6, 6):
		for z in range(-6, 6):
			var shade := rng.randf_range(0.0, 0.035)
			Visuals.box(self, Vector3(x * 4 + 2, -0.08, z * 4 + 2), Vector3(3.94, 0.16, 3.94), Color(0.22 + shade, 0.29 + shade, 0.30 + shade))
	for side in [-1, 1]:
		Visuals.box(self, Vector3(side * 24, 1.3, 0), Vector3(1, 2.8, 49), Color("273640"), true)
		Visuals.box(self, Vector3(0, 1.3, side * 24), Vector3(49, 2.8, 1), Color("273640"), true)
		for offset in [-18, -9, 0, 9, 18]:
			for point in [Vector3(side * 23, 0, offset), Vector3(offset, 0, side * 23)]:
				Visuals.box(self, point + Vector3.UP * 2.4, Vector3(1.4, 4.8, 1.4), Color("40525a"))
				Visuals.box(self, point + Vector3.UP * 4.9, Vector3(1.7, 0.3, 1.7), AMBER)
				var light := OmniLight3D.new()
				light.position = point + Vector3.UP * 3
				light.light_color = AMBER
				light.light_energy = 1.8
				light.omni_range = 6
				add_child(light)
	for index in range(3):
		var seal := Visuals.ring(self, Vector3((index - 1) * 6, 0.12, -12), 1.7, Color("5b6c76"))
		seals.append(seal)
		Visuals.caption(self, str(index + 1), Vector3((index - 1) * 6, 0.7, -12), AMBER)
	Visuals.ring(self, Vector3(0, 0.08, 0), 5.5, Color("537d80"))
	portal = Node3D.new()
	add_child(portal)
	portal.position = Vector3(0, 0, -19)
	for side in [-1, 1]:
		Visuals.box(portal, Vector3(side * 2, 2, 0), Vector3(0.9, 4, 1), Color("607879"))
	Visuals.box(portal, Vector3(0, 4.1, 0), Vector3(5, 0.6, 1.2), AMBER)
	var gate := Visuals.ring(portal, Vector3(0, 2.1, 0), 1.7, TEAL)
	gate.rotation.x = PI / 2
	Visuals.caption(portal, "ВЫХОД", Vector3(0, 5.2, 0), TEAL)
	portal.hide()

func build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root)
	var theme := Theme.new()
	theme.default_font_size = 18
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("20383f")
	normal.border_color = Color("567975")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(6)
	normal.content_margin_left = 24
	normal.content_margin_right = 24
	normal.content_margin_top = 16
	normal.content_margin_bottom = 16
	theme.set_stylebox("normal", "Button", normal)
	var hover := normal.duplicate()
	hover.bg_color = Color("355955")
	hover.border_color = AMBER
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("focus", "Button", hover)
	theme.set_stylebox("pressed", "Button", hover)
	root.theme = theme
	var shade := ColorRect.new()
	shade.color = Color(0.035, 0.075, 0.095, 0.85)
	shade.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	shade.offset_bottom = 178
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	hud = MarginContainer.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hud.add_theme_constant_override("margin_left", 30)
	hud.add_theme_constant_override("margin_right", 30)
	hud.add_theme_constant_override("margin_top", 24)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	hud.add_child(column)
	var title := label("ROGIL    /    ЗАЛ ТРЁХ ПЕЧАТЕЙ", 22, AMBER)
	column.add_child(title)
	objective = label("", 22, Color.WHITE)
	column.add_child(objective)
	stats = label("", 16, Color("b7cbd0"))
	column.add_child(stats)
	hp_bar = progress(Color("d87668"), 20)
	column.add_child(hp_bar)
	xp_bar = progress(TEAL, 8)
	column.add_child(xp_bar)
	boss_bar = progress(AMBER, 14)
	column.add_child(boss_bar)
	boss_bar.hide()
	message = label("WASD — движение    Мышь — камера    Shift — рывок    Пробел — прыжок    Esc — пауза", 16, Color("d4dfdf"))
	message.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	message.offset_top = -42
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(message)
	overlay = ColorRect.new()
	overlay.color = Color(0.025, 0.055, 0.075, 0.92)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	modal = VBoxContainer.new()
	modal.custom_minimum_size.x = 640
	modal.add_theme_constant_override("separation", 16)
	center.add_child(modal)

func label(text: String, size: int, color: Color) -> Label:
	var item := Label.new()
	item.text = text
	item.add_theme_font_size_override("font_size", size)
	item.add_theme_color_override("font_color", color)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return item

func progress(color: Color, height: float) -> ProgressBar:
	var item := ProgressBar.new()
	item.custom_minimum_size.y = height
	item.show_percentage = false
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := StyleBoxFlat.new()
	background.bg_color = Color("17242d")
	background.set_corner_radius_all(4)
	item.add_theme_stylebox_override("background", background)
	var fill := background.duplicate()
	fill.bg_color = color
	item.add_theme_stylebox_override("fill", fill)
	return item

func clear_modal(heading: String, subtitle: String) -> void:
	for child in modal.get_children():
		modal.remove_child(child)
		child.queue_free()
	overlay.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	modal.add_child(label("ЭТАЖ 01    /    ЗАБЫТОЕ СВЯТИЛИЩЕ", 16, TEAL))
	modal.add_child(label(heading, 42, AMBER))
	modal.add_child(label(subtitle, 18, Color("c1d0d5")))

func button(text: String, callback: Callable) -> void:
	var item := Button.new()
	item.text = text
	item.pressed.connect(callback)
	modal.add_child(item)
	if modal.get_child_count() == 4:
		item.grab_focus()

func show_menu() -> void:
	mode = "menu"
	hud.hide()
	clear_modal("ЗАЛ ТРЁХ ПЕЧАТЕЙ", "Один этаж. Три испытания. Один страж.\n\nПобеждай волны врагов, собирай осколки опыта\nи выбирай улучшения. Открой портал и покинь зал.\nАтака срабатывает автоматически рядом с врагами.")
	button("НАЧАТЬ ЗАБЕГ", start_run)
	button("ВЫЙТИ", func(): get_tree().quit())

func start_run() -> void:
	mode = "playing"
	overlay.hide()
	hud.show()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	begin_stage()

func begin_stage() -> void:
	stage += 1
	spawn_clock = 0.5
	if stage <= 3:
		remaining = [10, 16, 22][stage - 1]
		objective.text = "ПЕЧАТЬ %d / 3   ·   Победи всех врагов" % stage
	else:
		remaining = 0
		spawn_enemy(3, Vector3(0, 0.2, -10))
		objective.text = "СТРАЖ ПЕЧАТИ   ·   Уходи из красного круга!"
		boss_bar.show()

func _process(delta: float) -> void:
	if mode != "playing":
		return
	elapsed += delta
	spawn_clock -= delta
	if remaining > 0 and spawn_clock <= 0:
		spawn_clock = 1.1 if stage == 3 else 1.4
		remaining -= 1
		var angle := rng.randf_range(0, TAU)
		var point := Vector3(cos(angle) * 19, 0.2, sin(angle) * 19)
		if point.distance_to(hero.position) < 9:
			point = -point
			point.y = 0.2
		var kind := 0
		if stage >= 2 and remaining % 3 == 0:
			kind = 1
		if stage == 3 and remaining % 5 == 0:
			kind = 2
		spawn_enemy(kind, point)
	if stage <= 3 and remaining == 0 and living_enemies() == 0 and intermission <= 0:
		seals[stage - 1].material_override = Visuals.material(TEAL, true)
		hero.hp = minf(hero.max_hp, hero.hp + 25)
		intermission = 5.0
	if intermission > 0:
		intermission -= delta
		objective.text = "ПЕЧАТЬ СНЯТА   ·   +25 HP   ·   Следующее испытание через %d" % ceili(intermission)
		if intermission <= 0:
			begin_stage()
	for index in range(gems.size() - 1, -1, -1):
		var gem := gems[index]
		gem.rotate_y(delta * 2)
		var target := hero.position + Vector3.UP * 0.8
		if gem.position.distance_to(target) < 7 or intermission > 0 or portal.visible:
			gem.position = gem.position.move_toward(target, delta * 13)
		if gem.position.distance_to(target) < 1.2:
			gems.remove_at(index)
			gem.queue_free()
			hero.collect(4)
			if mode != "playing":
				break
	if portal.visible and hero.position.distance_to(portal.position) < 2.5 and mode == "playing":
		finish(true)
	update_hud()

func living_enemies() -> int:
	var count := 0
	for enemy in get_tree().get_nodes_in_group("floor_enemies"):
		if not enemy.dead:
			count += 1
	return count

func spawn_enemy(kind: int, point: Vector3) -> void:
	var enemy := Foe.new()
	enemy.game = self
	enemy.kind = kind
	add_child(enemy)
	enemy.position = point
	if kind == 3:
		boss = enemy

func enemy_killed(enemy: CharacterBody3D) -> void:
	kills += 1
	if enemy.kind == 3:
		portal.show()
		boss_bar.hide()
		objective.text = "СТРАЖ ПОВЕРЖЕН   ·   Войди в бирюзовый портал"
		return
	var gem := Visuals.box(self, enemy.position + Vector3.UP * 0.65, Vector3(0.35, 0.55, 0.35), TEAL)
	gem.material_override = Visuals.material(TEAL, true)
	gem.rotation.z = PI / 4
	gems.append(gem)

func update_hud() -> void:
	hp_bar.max_value = hero.max_hp
	hp_bar.value = hero.hp
	xp_bar.max_value = hero.next_xp
	xp_bar.value = hero.xp
	stats.text = "HP %d / %d     Уровень %d · опыт %d / %d     Убийств %d     %02d:%02d     Рывок: %s" % [hero.hp, hero.max_hp, hero.level, hero.xp, hero.next_xp, kills, int(elapsed) / 60, int(elapsed) % 60, "готов" if hero.dash_cooldown <= 0 else "%.1f с" % hero.dash_cooldown]
	if is_instance_valid(boss) and not boss.dead:
		boss_bar.max_value = boss.max_hp
		boss_bar.value = boss.hp

func check_level() -> void:
	if hero.xp < hero.next_xp or mode != "playing":
		return
	hero.xp -= hero.next_xp
	hero.level += 1
	hero.next_xp += 8
	mode = "upgrade"
	clear_modal("НОВЫЙ УРОВЕНЬ", "Уровень %d. Выбери одно улучшение — бой приостановлен." % hero.level)
	var choices: Array = range(UPGRADES.size())
	choices.shuffle()
	for index in choices.slice(0, 3):
		var upgrade: Array = UPGRADES[index]
		button(upgrade[0] + "\n" + upgrade[1], apply_upgrade.bind(upgrade[2]))

func apply_upgrade(id: String) -> void:
	if mode != "upgrade":
		return
	match id:
		"damage": hero.damage += 8
		"haste": hero.attack_interval = maxf(0.2, hero.attack_interval * 0.85)
		"health":
			hero.max_hp += 25
			hero.hp = minf(hero.max_hp, hero.hp + 40)
		"range": hero.attack_range += 0.6
		"speed": hero.speed += 0.7
	resume()
	check_level()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if mode == "playing":
			mode = "pause"
			clear_modal("ПАУЗА", "Передохни. Испытание подождёт.")
			button("ПРОДОЛЖИТЬ", resume)
			button("НАЧАТЬ ЗАНОВО", restart)
			button("В ГЛАВНОЕ МЕНЮ", func(): get_tree().reload_current_scene())
		elif mode == "pause":
			resume()

func resume() -> void:
	mode = "playing"
	overlay.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func finish(won: bool) -> void:
	mode = "victory" if won else "defeat"
	clear_modal("ЭТАЖ ПРОЙДЕН" if won else "ЗАБЕГ ОКОНЧЕН", ("Три печати разрушены. Путь свободен." if won else "Стражи зала оказались сильнее. Попробуй ещё раз.") + "\n\nВремя: %02d:%02d   ·   Убийств: %d   ·   Уровень: %d" % [int(elapsed) / 60, int(elapsed) % 60, kills, hero.level])
	button("ЕЩЁ ОДИН ЗАБЕГ", restart)
	button("В ГЛАВНОЕ МЕНЮ", func(): get_tree().reload_current_scene())
	button("ВЫЙТИ", func(): get_tree().quit())

func restart() -> void:
	# Перезагрузка сбрасывает врагов, опыт и все таймеры.
	get_tree().set_meta("floor_autostart", true)
	get_tree().reload_current_scene()

func _enter_tree() -> void:
	if get_tree().has_meta("floor_autostart"):
		get_tree().remove_meta("floor_autostart")
		ready.connect(start_run, CONNECT_DEFERRED | CONNECT_ONE_SHOT)

func pulse(point: Vector3, radius: float, color: Color) -> void:
	var effect := Visuals.ring(self, Vector3(point.x, 0.15, point.z), radius, color)
	effect.scale = Vector3.ONE * 0.15
	var tween := create_tween()
	tween.tween_property(effect, "scale", Vector3.ONE, 0.25)
	tween.tween_callback(effect.queue_free)

func floating_text(point: Vector3, text: String, color: Color) -> void:
	var item := Visuals.caption(self, text, point + Vector3.UP, color)
	var tween := create_tween()
	tween.tween_property(item, "position:y", item.position.y + 1.4, 0.6)
	tween.tween_callback(item.queue_free)
