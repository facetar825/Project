extends CharacterBody3D
const Visuals = preload("res://Script/floor/visuals.gd")
const Creatures = preload("res://Script/floor/creature_models.gd")

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
var camera: Camera3D
var visual_time := 0.0
var attack_pose := 0.0
var step_clock := 0.0

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
	model = Creatures.build_hero(self)
	Visuals.ring(self, Vector3(0, 0.06, 0), 0.52, Color('a94262'))
	pivot = Node3D.new()
	pivot.position.y = 1.5
	add_child(pivot)
	pivot.rotation.x = pitch
	var arm := SpringArm3D.new()
	arm.spring_length = 10.0
	arm.collision_mask = 1 | 8
	arm.margin = 0.3
	pivot.add_child(arm)
	camera = Camera3D.new()
	camera.fov = game.options.fov
	arm.add_child(camera)
	camera.current = true

func _unhandled_input(event: InputEvent) -> void:
	if game.mode != "playing" or not game.dungeon.ready_for_play:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		pivot.rotation.y -= event.relative.x * 0.003 * game.options.sensitivity
		pitch = clampf(pitch - event.relative.y * 0.003 * game.options.sensitivity, -1.15, -0.12)
		pivot.rotation.x = pitch

func _physics_process(delta: float) -> void:
	if game.mode != "playing" or not game.dungeon.ready_for_play:
		return
	cooldown -= delta
	invulnerability -= delta
	dash_cooldown = maxf(0, dash_cooldown - delta)
	dash_time -= delta
	attack_pose = maxf(0, attack_pose - delta * 4)
	visual_time += delta
	step_clock -= delta
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
		game.sound.play("dash", global_position)
		game.fx.dash(global_position)
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
		if step_clock <= 0 and is_on_floor():
			step_clock = 0.34
			game.sound.play("step", global_position)
	Creatures.animate(model, visual_time, minf(1, direction.length()), attack_pose)
	if cooldown <= 0:
		var targets: Array = []
		for enemy in get_tree().get_nodes_in_group("floor_enemies"):
			if not enemy.dead and position.distance_to(enemy.position) < attack_range and game.dungeon.clear_sight(position, enemy.position):
				targets.append(enemy)
		if not targets.is_empty():
			cooldown = attack_interval
			attack_pose = 1.0
			game.sound.play("slash", global_position)
			game.fx.slash(position, attack_range, model.rotation.y)
			for enemy in targets:
				enemy.take_damage(damage)

func take_damage(amount: float) -> void:
	if invulnerability > 0 or game.mode != "playing":
		return
	hp = maxf(0, hp - amount)
	invulnerability = 0.7
	game.sound.play("hurt", global_position)
	game.fx.hurt()
	game.floating_text(position, "−%d" % amount, Color("ff877a"))
	if hp <= 0:
		game.finish(false)

func collect(amount: int) -> void:
	xp += amount
	game.sound.play("pickup", global_position)
	game.check_level()
