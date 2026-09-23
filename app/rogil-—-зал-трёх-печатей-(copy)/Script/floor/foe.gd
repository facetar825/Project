extends CharacterBody3D
const Visuals = preload("res://Script/floor/visuals.gd")
var game: Node3D
var kind := 0 # 0 — обычный, 1 — быстрый, 2 — тяжёлый, 3 — босс
var hp := 40.0
var max_hp := 40.0
var speed := 2.8
var damage := 10.0
var dead := false
var attack_clock := 0.0
var slam_clock := 5.0
var warning_time := 0.0
var warning: MeshInstance3D
var bar: Label3D
var skin: Node3D
var route := PackedVector3Array()
var path_clock := 0.0
var legs: Array[MeshInstance3D] = []
var stride := 0.0

func _ready() -> void:
	add_to_group("floor_enemies")
	collision_layer = 4
	collision_mask = 1 | 8
	var sizes := [1.0, 0.7, 1.4, 2.5]
	var size: float = sizes[kind]
	hp = [40.0, 26.0, 95.0, 850.0][kind]
	max_hp = hp
	speed = [2.8, 4.4, 1.9, 2.1][kind]
	damage = [10.0, 8.0, 18.0, 24.0][kind]
	var collider := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = size * 0.4
	shape.height = size * 1.7
	collider.shape = shape
	collider.position.y = size * 0.85
	add_child(collider)
	skin = Node3D.new()
	add_child(skin)
	var color: Color = [Color("68716d"), Color("5c7771"), Color("686379"), Color("a5905e")][kind]
	Visuals.box(skin, Vector3(0, size * 0.8, 0), Vector3(0.85, 1.25, 0.65) * size, color)
	Visuals.box(skin, Vector3(0, size * 1.65, 0), Vector3(0.7, 0.55, 0.65) * size, color.lightened(0.12))
	Visuals.box(skin, Vector3(0, 1.68, 0.337) * size, Vector3(0.65, 0.19, 0.05) * size, Color("202932"))
	Visuals.box(skin, Vector3(0, 1.10, 0.36) * size, Vector3(0.56, 0.38, 0.16) * size, color.lightened(0.2))
	var emblem := Visuals.box(skin, Vector3(0, 1.12, 0.46) * size, Vector3(0.16, 0.16, 0.035) * size, Color("d7a578"))
	emblem.rotation.z = PI / 4
	for side in [-1, 1]:
		var eye := Visuals.box(skin, Vector3(side * 0.2, 1.7, 0.375) * size, Vector3(0.12, 0.09, 0.04) * size, Color("ffb968"))
		var eye_mat := Visuals.material(Color("ffb968"), true)
		eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		eye.material_override = eye_mat
		Visuals.box(skin, Vector3(side * 0.62, 0.85, 0) * size, Vector3(0.3, 0.9, 0.4) * size, color.darkened(0.18))
		Visuals.box(skin, Vector3(side * 0.62, 1.35, 0) * size, Vector3(0.52, 0.35, 0.62) * size, color.lightened(0.13))
		var leg := Visuals.box(skin, Vector3(side * 0.25, 0.2, 0.04) * size, Vector3(0.32, 0.5, 0.53) * size, color.darkened(0.2))
		legs.append(leg)
		if kind == 3:
			var horn := Visuals.box(skin, Vector3(side * 0.4, 2.03, 0) * size, Vector3(0.12, 0.45, 0.14) * size, Color("dec18a"))
			horn.rotation.z = side * -0.25
	bar = Visuals.caption(self, "", Vector3(0, size * 2.2, 0), Color("ffe3b1"))
	update_bar()

func _physics_process(delta: float) -> void:
	if dead or game.mode != "playing":
		return
	attack_clock -= delta
	slam_clock -= delta
	var direction: Vector3 = game.hero.position - position
	direction.y = 0
	var distance := direction.length()
	skin.rotation.y = atan2(direction.x, direction.z)
	stride += delta * speed * 3
	for index in range(legs.size()):
		legs[index].rotation.x = sin(stride + index * PI) * 0.3 if distance > 2 else 0.0
	var visible_target: bool = game.dungeon.clear_sight(position, game.hero.position)
	if kind == 3:
		if warning_time > 0:
			warning_time -= delta
			if warning_time <= 0:
				warning.queue_free()
				game.pulse(position, 7, Color("ff775b"))
				if distance < 7 and visible_target:
					game.hero.take_damage(32)
				slam_clock = 5
			return
		if slam_clock <= 0:
			warning_time = 1.5
			warning = Visuals.ring(game, Vector3(position.x, 0.12, position.z), 7, Color("ff654d"))
			var danger := Visuals.material(Color("ff654d"), true)
			danger.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			warning.material_override = danger
			game.floating_text(position + Vector3.UP * 3, "УДАР ПО ЗЕМЛЕ!", Color("ffad78"))
			return
	path_clock -= delta
	if distance > 3 or not visible_target:
		if path_clock <= 0:
			path_clock = 0.6
			route = game.dungeon.route(position, game.hero.position)
		while not route.is_empty() and Vector2(route[0].x - position.x, route[0].z - position.z).length() < 0.6:
			route.remove_at(0)
		if not route.is_empty():
			direction = route[0] - position
			direction.y = 0
		else:
			direction = Vector3.ZERO
	direction = direction.normalized()
	# Небольшое разделение не даёт противникам собраться в одной точке.
	var separation := Vector3.ZERO
	for other in get_tree().get_nodes_in_group("floor_enemies"):
		if other == self or other.dead:
			continue
		var offset: Vector3 = position - other.position
		offset.y = 0
		if offset.length_squared() < 2.0 and offset.length_squared() > 0.01:
			separation += offset.normalized() * 0.65
	var movement := (direction + separation).normalized() * speed
	velocity.x = movement.x if distance > 1.2 else 0.0
	velocity.z = movement.z if distance > 1.2 else 0.0
	velocity.y -= 24 * delta
	move_and_slide()
	skin.rotation.y = atan2(direction.x, direction.z)
	if distance < (2.7 if kind == 3 else 1.65) and attack_clock <= 0 and visible_target:
		attack_clock = 1.0
		game.hero.take_damage(damage)

func take_damage(amount: float) -> void:
	if dead:
		return
	hp -= amount
	game.floating_text(position + Vector3.UP * 1.5, str(int(amount)), Color("fff0cb"))
	update_bar()
	if hp <= 0:
		dead = true
		if is_instance_valid(warning):
			warning.queue_free()
		game.enemy_killed(self)
		queue_free()

func update_bar() -> void:
	bar.text = ("СТРАЖ ПЕЧАТИ\n" if kind == 3 else "") + "%d / %d" % [maxf(0, hp), max_hp]
