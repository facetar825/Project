extends Node3D
## Один законченный забег: три печати, страж, выход.
const Visuals = preload("res://Script/floor/visuals.gd")
const TouchControls = preload("res://Script/floor/touch_controls.gd")
const Hero = preload("res://Script/floor/hero.gd")
const Foe = preload("res://Script/floor/foe.gd")
const Dungeon = preload("res://Script/floor/dungeon.gd")
const DungeonScene = preload("res://Scene/PresetDungeon.tscn")
const Art = preload("res://Script/floor/art.gd")
const AMBER := Color("edc17b")
const TEAL := Color("78dbcb")
const UPGRADES := [
	["ТЯЖЁЛЫЙ УДАР", "+8 к урону каждого удара", "damage"],
	["БЫСТРЫЕ РУКИ", "Атака на 15% чаще", "haste"],
	["ВТОРОЕ ДЫХАНИЕ", "+25 к здоровью и лечение на 40", "health"],
	["ДЛИННОЕ ЛЕЗВИЕ", "+0,6 м к радиусу атаки", "range"],
	["ЛЁГКИЙ ШАГ", "+0,7 к скорости движения", "speed"],
]
var mobile_controls := OS.has_feature("mobile") or "--mobile-controls" in OS.get_cmdline_user_args()
var touch_controls: Control
var hero: CharacterBody3D
var mode := "menu"
var stage := 0
var kills := 0
var elapsed := 0.0
var spawn_clock := 0.0
var remaining := 0
var intermission := 0.0
var dungeon: Node3D
var waiting_for_entry := true
var room_cleared := false
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
	get_tree().auto_accept_quit = not OS.has_feature("android")
	if mobile_controls:
		get_tree().quit_on_go_back = false
		get_tree().root.go_back_requested.connect(toggle_pause)
	rng.randomize()
	build_world()
	hero = Hero.new()
	hero.game = self
	add_child(hero)
	hero.position = dungeon.start_position
	build_ui()
	show_menu()

func build_world() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("111d26")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("92aabd")
	settings.ambient_light_energy = 0.5
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = settings
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	sun.light_color = Color("b9d4e0")
	sun.light_energy = 0.65
	sun.shadow_enabled = not mobile_controls
	add_child(sun)
	dungeon = DungeonScene.instantiate()
	add_child(dungeon)
	var art := Art.new()
	add_child(art)
	art.decorate(dungeon)
	for index in range(3):
		var point: Vector3 = dungeon.exits[index] + Vector3.UP * 0.2
		var seal := Visuals.ring(self, point, 1.7, Color("5b6c76"))
		seals.append(seal)
		Visuals.caption(self, "ПЕЧАТЬ %d" % (index + 1), point + Vector3.UP * 4, AMBER)
	portal = Node3D.new()
	add_child(portal)
	portal.position = dungeon.end_position
	portal.rotation.y = PI / 2
	var frame = preload("res://Scene/Doors.tscn").instantiate()
	portal.add_child(frame)
	dungeon.adapt_thresholds(portal)
	for part in frame.find_children("*", "CSGMesh3D", true, false):
		part.material_override = Visuals.material(Color("827151"))
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
	normal.bg_color = Color("1c2b31")
	normal.border_color = Color("76694f")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(3)
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
	if mobile_controls:
		theme.default_font_size = 24
	var heading := VBoxContainer.new()
	heading.position = Vector2(30, 24)
	heading.add_theme_constant_override("separation", 8)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(heading)
	heading.add_child(label("R O G I L     /     ЭТАЖ I", 17, AMBER))
	objective = label("", 19, Color("e0e2db"))
	if mobile_controls:
		heading.position.x = 60
		objective.custom_minimum_size.x = 880
		objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.add_child(objective)
	boss_bar = progress(AMBER, 7)
	boss_bar.custom_minimum_size.x = 500
	boss_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	heading.add_child(boss_bar)
	boss_bar.hide()
	hud = MarginContainer.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hud.offset_left = 30
	hud.offset_top = -127
	hud.offset_right = 620
	hud.offset_bottom = -46
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	if mobile_controls:
		hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		hud.position = Vector2(60, 115)
		hud.size = Vector2(850, 80)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	hud.add_child(column)
	stats = label("", 15, Color("c5d3d5"))
	column.add_child(stats)
	if mobile_controls:
		stats.add_theme_font_size_override("font_size", 22)
	hp_bar = progress(Color("bd6f61"), 13)
	hp_bar.custom_minimum_size.x = 350
	hp_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(hp_bar)
	xp_bar = progress(TEAL, 4)
	xp_bar.custom_minimum_size.x = 350
	xp_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(xp_bar)
	message = label("WASD  Движение     SHIFT  Рывок     SPACE  Прыжок     ESC  Пауза", 13, Color("a5b7bd"))
	message.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	message.offset_top = -28
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(message)
	if mobile_controls:
		message.hide()
		touch_controls = TouchControls.new()
		root.add_child(touch_controls)
		touch_controls.look_changed.connect(hero.rotate_camera)
		touch_controls.pause_requested.connect(toggle_pause)
		touch_controls.set_active(false)
	overlay = ColorRect.new()
	overlay.color = Color(0.015, 0.025, 0.035, 0.74)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	modal = VBoxContainer.new()
	modal.custom_minimum_size.x = 610
	modal.add_theme_constant_override("separation", 18)
	var panel := PanelContainer.new()
	var card := StyleBoxFlat.new()
	card.bg_color = Color(0.045, 0.07, 0.085, 0.97)
	card.border_color = Color("8b7958")
	card.border_width_top = 3
	card.border_width_bottom = 1
	card.content_margin_left = 38
	card.content_margin_right = 38
	card.content_margin_top = 28
	card.content_margin_bottom = 28
	card.shadow_color = Color(0, 0, 0, 0.4)
	card.shadow_size = 20
	panel.add_theme_stylebox_override("panel", card)
	center.add_child(panel)
	panel.add_child(modal)

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
	if is_instance_valid(touch_controls):
		touch_controls.set_active(false)
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
	clear_modal("ДАНЖ ТРЁХ ПЕЧАТЕЙ", "Галерея → каменный зал → лабиринт → страж.\n\nЗачищай комнаты, чтобы открывать проход дальше.\nСобирай опыт и выбирай улучшения. После босса\nвойди в портал. Атака работает автоматически.")
	if mobile_controls:
		modal.add_child(label("Слева — джойстик. Справа — поворот камеры.\nПрыжок и рывок — кнопки на экране.", 18, TEAL))
	button("НАЧАТЬ ЗАБЕГ", start_run)
	button("ВЫЙТИ", func(): get_tree().quit())

func start_run() -> void:
	mode = "playing"
	overlay.hide()
	hud.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if mobile_controls else Input.MOUSE_MODE_CAPTURED
	if is_instance_valid(touch_controls):
		touch_controls.set_active(true)
	waiting_for_entry = true
	objective.text = "ВОЙДИ В ГАЛЕРЕЮ   ·   Первая дверь впереди"

func begin_stage() -> void:
	stage += 1
	waiting_for_entry = false
	room_cleared = false
	dungeon.set_gate(stage - 1, true)
	spawn_clock = 0.5
	if stage <= 3:
		remaining = [10, 16, 22][stage - 1]
		objective.text = "%s   ·   Печать %d / 3   ·   Победи всех врагов" % [Dungeon.NAMES[stage - 1], stage]
	else:
		remaining = 0
		spawn_enemy(3, dungeon.rooms[3].to_global(Vector3(0, 0.3, -27)))
		objective.text = "СТРАЖ ПЕЧАТИ   ·   Уходи из красного круга!"
		boss_bar.show()

func _process(delta: float) -> void:
	if mode != "playing":
		return
	if not dungeon.ready_for_play:
		objective.text = "ПОДГОТОВКА ДАНЖА…"
		return
	if waiting_for_entry and stage < 4:
		objective.text = "ПРОЙДИ В %s   ·   Следуй к открытой двери" % Dungeon.NAMES[stage]
		if dungeon.entered_room(stage, hero.position):
			begin_stage()
	elapsed += delta
	spawn_clock -= delta
	if remaining > 0 and spawn_clock <= 0:
		spawn_clock = 1.1 if stage == 3 else 1.4
		remaining -= 1
		var point: Vector3 = dungeon.spawn_point(stage - 1, hero.position, rng)
		var kind := 0
		if stage >= 2 and remaining % 3 == 0:
			kind = 1
		if stage == 3 and remaining % 5 == 0:
			kind = 2
		spawn_enemy(kind, point)
	if stage > 0 and stage <= 3 and not room_cleared and remaining == 0 and living_enemies() == 0:
		room_cleared = true
		seals[stage - 1].material_override = Visuals.material(TEAL, true)
		hero.hp = minf(hero.max_hp, hero.hp + 25)
		intermission = 5.0
	if intermission > 0:
		intermission -= delta
		objective.text = "КОМНАТА ЗАЧИЩЕНА   ·   +25 HP   ·   Проход откроется через %d" % ceili(intermission)
		if intermission <= 0:
			dungeon.set_gate(stage, false)
			waiting_for_entry = true
	for index in range(gems.size() - 1, -1, -1):
		var gem := gems[index]
		gem.rotate_y(delta * 2)
		var target := hero.position + Vector3.UP * 0.8
		if gem.position.distance_to(target) < 7 or room_cleared or portal.visible:
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
	if is_instance_valid(touch_controls):
		touch_controls.dash_cooldown = hero.dash_cooldown
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
		toggle_pause()

func toggle_pause() -> void:
	if mode == "playing":
		mode = "pause"
		clear_modal("ПАУЗА", "Передохни. Испытание подождёт.")
		button("ПРОДОЛЖИТЬ", resume)
		button("НАЧАТЬ ЗАНОВО", restart)
		button("В ГЛАВНОЕ МЕНЮ", func(): get_tree().reload_current_scene())
	elif mode == "pause":
		resume()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or (mobile_controls and what == NOTIFICATION_APPLICATION_FOCUS_OUT):
		if is_instance_valid(touch_controls):
			touch_controls.reset_input()
		if mode == "playing":
			toggle_pause()

func resume() -> void:
	mode = "playing"
	overlay.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if mobile_controls else Input.MOUSE_MODE_CAPTURED
	if is_instance_valid(touch_controls):
		touch_controls.set_active(true)

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

func checkpoint() -> Vector3:
	return dungeon.start_position if stage == 0 else dungeon.checkpoint(stage - 1)

func floating_text(point: Vector3, text: String, color: Color) -> void:
	var item := Visuals.caption(self, text, point + Vector3.UP, color)
	var tween := create_tween()
	tween.tween_property(item, "position:y", item.position.y + 1.4, 0.6)
	tween.tween_callback(item.queue_free)
