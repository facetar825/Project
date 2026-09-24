extends Control
## Independent finger ownership allows movement, looking and actions together.
signal look_changed(delta: Vector2)
signal pause_requested

var movement := Vector2.ZERO
var dash_requested := false
var jump_requested := false
var active := false
var move_finger := -1
var look_finger := -1
var stick_offset := Vector2.ZERO
var dash_cooldown := 0.0
var margin := Vector2(40, 28)
const RADIUS := 86.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(func():
		update_safe_area()
		reset_input())
	update_safe_area()
	reset_input()

func update_safe_area() -> void:
	if not OS.has_feature("android"):
		return
	var screen := Vector2(DisplayServer.screen_get_size())
	var safe := DisplayServer.get_display_safe_area()
	if screen.x <= 0 or screen.y <= 0 or safe.size.x <= 0:
		return
	var scale_factor := size / screen
	margin.x = maxf(40.0, maxf(safe.position.x, screen.x - safe.end.x) * scale_factor.x + 16.0)
	margin.y = maxf(28.0, maxf(safe.position.y, screen.y - safe.end.y) * scale_factor.y + 16.0)

func stick_center() -> Vector2:
	return Vector2(margin.x + 105, size.y - margin.y - 105)

func dash_rect() -> Rect2:
	return Rect2(Vector2(size.x - margin.x - 156, size.y - margin.y - 118), Vector2(156, 104))

func jump_rect() -> Rect2:
	return Rect2(Vector2(size.x - margin.x - 332, size.y - margin.y - 118), Vector2(156, 104))

func pause_rect() -> Rect2:
	return Rect2(Vector2(size.x - margin.x - 156, margin.y), Vector2(156, 64))

func set_active(value: bool) -> void:
	active = value
	visible = value
	reset_input()

func reset_input() -> void:
	movement = Vector2.ZERO
	stick_offset = Vector2.ZERO
	move_finger = -1
	look_finger = -1
	dash_requested = false
	jump_requested = false
	queue_redraw()

func consume_dash() -> bool:
	var value := dash_requested
	dash_requested = false
	return value

func consume_jump() -> bool:
	var value := jump_requested
	jump_requested = false
	return value

func _input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventScreenTouch:
		if not event.pressed or event.canceled:
			if event.index == move_finger:
				move_finger = -1
				movement = Vector2.ZERO
				stick_offset = Vector2.ZERO
			if event.index == look_finger:
				look_finger = -1
		elif pause_rect().has_point(event.position):
			pause_requested.emit()
		elif dash_rect().has_point(event.position):
			dash_requested = true
		elif jump_rect().has_point(event.position):
			jump_requested = true
		elif event.position.x < size.x * 0.45 and event.position.y > size.y * 0.4 and move_finger == -1:
			move_finger = event.index
			update_stick(event.position)
		elif event.position.x >= size.x * 0.45 and look_finger == -1:
			look_finger = event.index
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if event.index == move_finger:
			update_stick(event.position)
		elif event.index == look_finger:
			look_changed.emit(event.relative * 0.004)
		get_viewport().set_input_as_handled()

func update_stick(point: Vector2) -> void:
	stick_offset = (point - stick_center()).limit_length(RADIUS)
	var raw := stick_offset / RADIUS
	movement = Vector2.ZERO if raw.length() < 0.15 else raw.normalized() * ((raw.length() - 0.15) / 0.85)
	queue_redraw()

func _process(_delta: float) -> void:
	if active:
		queue_redraw()

func draw_button(rect: Rect2, text: String) -> void:
	draw_rect(rect, Color(0.06, 0.13, 0.16, 0.78))
	draw_rect(rect, Color(0.47, 0.86, 0.8, 0.8), false, 2)
	var font := ThemeDB.fallback_font
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24)
	draw_string(font, rect.get_center() + Vector2(-text_size.x / 2, 9), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("e0e2db"))

func _draw() -> void:
	if not active:
		return
	draw_circle(stick_center(), RADIUS, Color(0.06, 0.13, 0.16, 0.65))
	draw_arc(stick_center(), RADIUS, 0, TAU, 64, Color(0.47, 0.86, 0.8, 0.75), 2, true)
	draw_circle(stick_center() + stick_offset, 33, Color(0.47, 0.86, 0.8, 0.7))
	draw_button(jump_rect(), "ПРЫЖОК")
	draw_button(dash_rect(), "РЫВОК" if dash_cooldown <= 0 else "%.1f с" % dash_cooldown)
	draw_button(pause_rect(), "ПАУЗА")
