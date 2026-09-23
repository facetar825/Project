extends CharacterBody3D
const Visuals = preload("res://Script/floor/visuals.gd")

var game: Node3D
var hp := 100.0
var max_hp := 100.0
var damage := 24.0
var attack_interval := 0.7
var attack_range := 4.3
var speed := 7.0
var xp := 0
var level := 1
var next_xp := 12
var cooldown := 0.0
var invulnerability := 0.0
var dash_cooldown := 0.0
var dash_time := 0.0
var dash_direction := Vector3.FORWARD
var pivot: Node3D
var model: Node3D
var animation: AnimationPlayer
var pitch := -0.55

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 8
	var collider := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.42
	shape.height = 1.8
	collider.shape = shape
	collider.position.y = 0.9
	add_child(collider)
	model = Node3D.new()
	add_child(model)
	# Используем модель из исходного проекта, если импорт уже доступен.
	var packed = load("res://anim/Idle.fbx")
	if packed is PackedScene:
		var skin = packed.instantiate()
		model.add_child(skin)
		# Масштабируем родителя: FBX-анимация может менять transform корня модели.
		model.scale = Vector3.ONE * 0.45
		for mesh in skin.find_children("*", "MeshInstance3D", true, false):
			var armor := Visuals.material(Color("9bb5b3"))
			armor.metallic = 0.35
			armor.roughness = 0.55
			armor.vertex_color_use_as_albedo = true
			mesh.material_override = armor
		animation = skin.find_child("AnimationPlayer", true, false)
		if animation and animation.get_animation_list().size() > 0:
			var anim_name: StringName = animation.get_animation_list()[0]
			animation.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
			animation.play(anim_name)
			var walking = load("res://anim/Walking.fbx")
			if walking is AnimationLibrary:
				animation.add_animation_library("walk", walking)
				for walk_name in walking.get_animation_list():
					walking.get_animation(walk_name).loop_mode = Animation.LOOP_LINEAR
	else:
		Visuals.box(model, Vector3(0, 0.9, 0), Vector3(0.7, 1.5, 0.5), Color("83d9dd"))
	Visuals.ring(self, Vector3(0, 0.06, 0), 0.65, Color("74eee1"))
	pivot = Node3D.new()
	pivot.position.y = 1.5
	add_child(pivot)
	pivot.rotation.x = pitch
	var arm := SpringArm3D.new()
	arm.spring_length = 10.0
	arm.collision_mask = 1 | 8
	arm.margin = 0.3
	pivot.add_child(arm)
	var camera := Camera3D.new()
	camera.fov = 65
	arm.add_child(camera)
	camera.current = true

func _unhandled_input(event: InputEvent) -> void:
	if game.mode != "playing" or not game.dungeon.ready_for_play:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		pivot.rotation.y -= event.relative.x * 0.003
		pitch = clampf(pitch - event.relative.y * 0.003, -1.15, -0.12)
		pivot.rotation.x = pitch

func _physics_process(delta: float) -> void:
	if game.mode != "playing" or not game.dungeon.ready_for_play:
		return
	cooldown -= delta
	invulnerability -= delta
	dash_cooldown = maxf(0, dash_cooldown - delta)
	dash_time -= delta
	var input := Input.get_vector("left", "right", "up", "down")
	var direction := pivot.basis * Vector3(input.x, 0, input.y)
	direction.y = 0
	direction = direction.normalized()
	if Input.is_action_just_pressed("sprint") and dash_cooldown <= 0:
		dash_direction = direction if direction.length() > 0.1 else -pivot.basis.z
		dash_direction.y = 0
		dash_direction = dash_direction.normalized()
		dash_time = 0.2
		dash_cooldown = 2.5
		invulnerability = 0.3
	if dash_time > 0:
		direction = dash_direction
	var move_speed := speed * (3.0 if dash_time > 0 else 1.0)
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	velocity.y -= 24 * delta
	if is_on_floor():
		velocity.y = 0
		if Input.is_physical_key_pressed(KEY_SPACE):
			velocity.y = 8
	move_and_slide()
	if position.y < -8:
		position = game.checkpoint()
		take_damage(15)
	if direction.length() > 0.1:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(direction.x, direction.z), delta * 12)
	if animation:
		var desired: StringName = &"walk/mixamo_com" if direction.length() > 0.1 else &"mixamo_com"
		if animation.has_animation(desired) and animation.current_animation != desired:
			animation.play(desired, 0.15)
	model.visible = invulnerability <= 0 or int(invulnerability * 20) % 2 == 0
	if cooldown <= 0:
		var targets: Array = []
		for enemy in get_tree().get_nodes_in_group("floor_enemies"):
			if not enemy.dead and position.distance_to(enemy.position) < attack_range and game.dungeon.clear_sight(position, enemy.position):
				targets.append(enemy)
		if not targets.is_empty():
			cooldown = attack_interval
			game.pulse(position, attack_range, Color("72eee2"))
			for enemy in targets:
				enemy.take_damage(damage)

func take_damage(amount: float) -> void:
	if invulnerability > 0 or game.mode != "playing":
		return
	hp = maxf(0, hp - amount)
	invulnerability = 0.7
	game.floating_text(position, "−%d" % amount, Color("ff877a"))
	if hp <= 0:
		game.finish(false)

func collect(amount: int) -> void:
	xp += amount
	game.check_level()
