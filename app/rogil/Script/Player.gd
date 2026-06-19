extends Entity
class_name Player
@onready var _3d_progress: Node3D = $"3dProgress"

@onready var animation_player: AnimationPlayer = $Idle/AnimationPlayer
@onready var camerapoint: Node3D = $camerapoint
@onready var camera_3d: Camera3D = $camerapoint/Camera3D
@onready var idle: Node3D = $Idle
@onready var area_dmg: Area3D = $Area_dmg
@onready var collision_shape_dmg: CollisionShape3D = $Area_dmg/CollisionShapeDMG

@onready var control: Control = $Control
@onready var panel: Panel = $Control/Panel
@onready var v_box_container: VBoxContainer = $Control/Panel/VBoxContainer
@onready var hp_bar: ProgressBar = $Control/ProgressBar

@onready var lable_max_hp: Label = $Control/Panel/VBoxContainer/HBoxContainer/lable_max_hp
@onready var lable_dmg: Label = $Control/Panel/VBoxContainer/HBoxContainer2/lable_dmg
@onready var lable_crit_chanc: Label = $Control/Panel/VBoxContainer/HBoxContainer3/lable_crit_chanc
@onready var lable_crit: Label = $Control/Panel/VBoxContainer/HBoxContainer4/lable_crit
@onready var lable_regen_hp: Label = $Control/Panel/VBoxContainer/HBoxContainer5/lable_regen_hp
@onready var lable_speed: Label = $Control/Panel/VBoxContainer/HBoxContainer6/lable_speed
@onready var lable_speed_attakc: Label = $Control/Panel/VBoxContainer/HBoxContainer7/lable_speed_attakc



@onready var label_hp: Label = $Control/Label



const WALK_SPEED = 20.0   # нормальная скорость (подберите на глаз)
const ACCELERATION = 10.0
const FRICTION = 20.0
const MOUSE_SENSITIVITY = 0.003
const CAMERA_MIN_PITCH = -60.0
const CAMERA_MAX_PITCH = 75.0
const MODEL_ROTATION_SPEED = 10.0
const ATTACK_RANGE = 2.5

var camera_pitch: float = 0.0
var enemies_in_range: Array[Entity] = []

# Player.gd (дописать в _ready)
func _ready() -> void:
	
	super._ready()
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	animation_player.play("Idle")
	add_to_group("player")
	area_dmg.body_entered.connect(_on_attack_area_entered)
	area_dmg.body_exited.connect(_on_attack_area_exited)
	update_hp_bar()
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
			camera_pitch = clamp(
				camera_pitch + event.relative.y * MOUSE_SENSITIVITY,
				deg_to_rad(CAMERA_MIN_PITCH),
				deg_to_rad(CAMERA_MAX_PITCH)
			)
			camerapoint.rotation.x = camera_pitch
		return

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			var mode := Input.MOUSE_MODE_VISIBLE \
				if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED \
				else Input.MOUSE_MODE_CAPTURED
			Input.set_mouse_mode(mode)
			match mode:
				Input.MOUSE_MODE_CAPTURED:
					hide_options()
				Input.MOUSE_MODE_VISIBLE:
					show_options()
	#if event is InputEventMouseButton and event.pressed:
		#if event.button_index == MOUSE_BUTTON_LEFT:
			#_attack_nearest_enemy()

func hide_options():
	$Control/PauseMenu.hide()

func show_options():
	$Control/PauseMenu.show()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	_handle_movement(delta)
	_update_animation()
	move_and_slide()
	
	# Атака ПОСЛЕ движения
	if enemies_in_range.size() > 0:
		print("Врагов в зоне: ", enemies_in_range.size())   # строка A
		var nearest = _get_nearest_enemy()
		if nearest:
			print("Атакую ", nearest.name)      
			print("попытка атаки")            # строка B
			try_attack(nearest)
	
func _get_nearest_enemy() -> Entity:
	if enemies_in_range.size() == 0:
		return null
	return enemies_in_range[0]  
func _handle_movement(delta: float) -> void:
	var input_dir := Input.get_vector("left", "right", "up", "down")
	var cam_basis := camera_3d.global_transform.basis
	var forward := -cam_basis.z
	var right := cam_basis.x
	forward.y = 0
	right.y = 0
	forward = forward.normalized()
	right = right.normalized()
	var direction := (forward * -input_dir.y + right * input_dir.x).normalized()

	if direction.length() > 0.1:
		# Мгновенная скорость без инерции
		velocity.x = direction.x * get_speed()
		velocity.z = direction.z * get_speed()
		
		var local_dir := global_transform.basis.inverse() * direction
		var target_angle := atan2(local_dir.x, local_dir.z)
		idle.rotation.y = lerp_angle(idle.rotation.y, target_angle, delta * MODEL_ROTATION_SPEED)
	else:
		# Мгновенная остановка
		velocity.x = 0.0
		velocity.z = 0.0

func _update_animation() -> void:
	var moving := Vector2(velocity.x, velocity.z).length() > 0.1
	if moving:
		if animation_player.current_animation != "Walking/mixamo_com":
			animation_player.play("Walking/mixamo_com")
	else:
		if animation_player.current_animation != "Idle":
			animation_player.play("Idle")

func _attack_nearest_enemy() -> void:
	var nearest: Entity = null
	var nearest_dist := ATTACK_RANGE

	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not (enemy is Entity):
			continue
		var dist := global_position.distance_to(enemy.global_position)
		if dist <= nearest_dist:
			nearest_dist = dist
			nearest = enemy

	if nearest:
		_play_aura()
		try_attack(nearest)
	else:
		# Ауру показываем даже при промахе
		_play_aura()




func _on_attack_area_entered(body: Node3D) -> void:
	print("В зону вошло: ", body.name)
	if body is Entity and body.is_in_group("enemy"):
		if body not in enemies_in_range:
			enemies_in_range.append(body)

func _on_attack_area_exited(body: Node3D) -> void:
	print("В зону вышло: ", body.name)   # исправлено сообщение
	if body is Entity and body.is_in_group("enemy"):
		enemies_in_range.erase(body)
		
		
func update_hp_bar():
	
	if hp_bar:
		hp_bar.max_value = get_max_hp()
		hp_bar.value = current_hp
	if label_hp:
		label_hp.text = "HP: %d / %d" % [current_hp, get_max_hp()]
	_3d_progress.set_value(current_hp)
	_3d_progress.set_max_value(max_hp)
func take_damage(amount: int) -> void:
	super.take_damage(amount)
	update_hp_bar()
func _handle_regen(delta: float) -> void:
	super._handle_regen(delta)
	update_hp_bar()
func level_up() -> void:
	super.level_up()
	if point > 0:
		print(point)
		panel.show()
	update_hp_bar()
	

func _on_upgete_1_pressed() -> void:
	bonuse_hp += 20
	lable_max_hp.text = str(get_max_hp())
	point -= 1
	print(point)
	if point == 0:
		panel.hide()
		


func _on_upgete_2_pressed() -> void:
	bonuse_damage += 5
	lable_dmg.text = str(get_damage())
	point -= 1
	print(point)
	if point == 0:
		panel.hide()




func _on_upgete_3_pressed() -> void:
	bonuse_crit_chance += 2
	lable_crit_chanc.text = str(get_crit_chance())
	point -= 1
	print(point)
	if point == 0:
		panel.hide()

	pass # Replace with function body.


func _on_upgete_4_pressed() -> void:
	bonuse_crit_damage += 10
	lable_crit.text = str(get_crit_damage())
	point -= 1
	print(point)
	if point == 0:
		panel.hide()

func _on_upgete_5_pressed() -> void:
	bonuse_regen_hp += 5
	lable_regen_hp.text = str(get_regen_hp())
	point -= 1
	print(point)
	if point == 0:
		panel.hide()




func _on_upgete_6_pressed() -> void:
	bonuse_speed += 2
	lable_speed.text = str(get_speed())
	point -= 1
	print(point)
	if point == 0:
		panel.hide()



func _on_upgete_7_pressed() -> void:
	bonuse_speed_attack += 0.2
	lable_speed_attakc.text = str(get_speed_attack())
	point -= 1
	print(point)
	if point == 0:
		panel.hide()
func _play_aura() -> void:
	# Берём размер из CollisionShape зоны атаки
	var shape := collision_shape_dmg.shape
	var wave_size := 1.0
	
	if shape is SphereShape3D:
		wave_size = shape.radius
	elif shape is BoxShape3D:
		wave_size = max(shape.size.x, shape.size.z) / 2.0
	elif shape is CylinderShape3D:
		wave_size = shape.radius

	var mesh_instance := MeshInstance3D.new()
	add_child(mesh_instance)
	
	# Позиция совпадает с центром Area_dmg
	mesh_instance.position = area_dmg.position
	mesh_instance.position.y = 0.1

	var torus := TorusMesh.new()
	torus.inner_radius = wave_size * 0.6
	torus.outer_radius = wave_size * 0.8
	mesh_instance.mesh = torus

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.6, 1.0, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.6, 1.0)
	mat.emission_energy_multiplier = 4.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_instance.set_surface_override_material(0, mat)

	# Начинаем с нуля и расширяемся до размера зоны
	mesh_instance.scale = Vector3(0.1, 0.1, 0.1)
	
	var tween := create_tween()
	tween.set_parallel(true)
	
	# Расширяется точно до размера зоны
	tween.tween_property(mesh_instance, "scale", Vector3(1.0, 1.0, 1.0), 0.3)
	
	# Затухает
	tween.tween_method(
		func(a: float):
			if is_instance_valid(mesh_instance):
				var m := mesh_instance.get_surface_override_material(0) as StandardMaterial3D
				if m:
					m.albedo_color.a = a
					m.emission_energy_multiplier = a * 4.0,
		0.9, 0.0, 0.3
	)
	
	tween.tween_callback(mesh_instance.queue_free).set_delay(0.35)
