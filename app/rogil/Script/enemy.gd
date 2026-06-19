extends Entity
class_name Enemy
@onready var _3d_progress: Node3D = $"3dProgress"

@onready var skin: Node3D = $Skin
@onready var animation_player: AnimationPlayer = $Skin/AnimationPlayer
@onready var collision_shape_3d: CollisionShape3D = $CollisionShape3D
@onready var area_dmg: Area3D = $Area_dmg
@onready var collision_shape_dmg: CollisionShape3D = $Area_dmg/CollisionShapeDMG

const ROTATION_SPEED = 5.0

var player: Entity = null
var player_in_range: bool = false


func take_damage(amount: int) -> void:
	super.take_damage(amount)
	_3d_progress.set_value
	(current_hp)

func _ready() -> void:
	super._ready()
	add_to_group("enemy")
	player = get_tree().get_first_node_in_group("player")
	area_dmg.body_entered.connect(_on_area_dmg_body_entered)
	area_dmg.body_exited.connect(_on_area_dmg_body_exited)
	_3d_progress.set_max_value(max_hp)

func _physics_process(delta: float) -> void:
	if player_in_range:
		print("Враг атакует, can_attack = ", can_attack)   # добавить
		try_attack(player)
	if not is_on_floor():
		velocity += get_gravity() * delta

	if player:
		_chase_player(delta)
		if player_in_range:
			try_attack(player)
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()
	_update_animation()

func _chase_player(delta: float) -> void:
	var direction := (player.global_position - global_position)
	direction.y = 0
	direction = direction.normalized()

	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

	if direction.length() > 0.1:
		var target_angle := atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_angle, delta * ROTATION_SPEED)

func _update_animation() -> void:
	var moving := Vector2(velocity.x, velocity.z).length() > 0.1
	if moving:
		if animation_player.current_animation != "Walking/mixamo_com":
			animation_player.play("Walking/mixamo_com")
	else:
		if animation_player.current_animation != "Idle":
			animation_player.play("Idle")

func _on_area_dmg_body_entered(body: Node3D) -> void:
	if body is Entity and body.is_in_group("player"):
		player_in_range = true



func _on_area_dmg_body_exited(body: Node3D) -> void:
	if body is Entity and body.is_in_group("player"):
		player_in_range = false# Replace with function body.
