extends Node3D

@onready var area_3d: Area3D = $Area3D        # зона исчезновения (ближняя)
@onready var area_3d_2: Area3D = $Area3D2     # зона преследования (дальняя)

const SPEED = 3.0
var expe  = 100

var player: Node3D = null
var is_chasing: bool = false
var is_hidden: bool = false

func _process(delta: float) -> void:
	if is_chasing and player and not is_hidden:
		var direction = (player.global_position - global_position).normalized()
		global_position += direction * SPEED * delta
		# Поворот к игроку
		look_at(player.global_position, Vector3.UP)

# Игрок вошёл в ближнюю зону — исчезаем
func _on_area_3d_body_entered(body: Node3D) -> void:
	if body is Plaeyr:
		player.add_exp(expe)
		is_hidden = true
		visible = false

# Игрок вышел из ближней зоны — появляемся
func _on_area_3d_body_exited(body: Node3D) -> void:
	if body is CharacterBody3D:
		is_hidden = false
		visible = true

# Игрок вошёл в дальнюю зону — начинаем преследование
func _on_area_3d_2_body_entered(body: Node3D) -> void:
	if body is Plaeyr:
		player = body
		is_chasing = true

# Игрок вышел из дальней зоны — останавливаемся
func _on_area_3d_2_body_exited(body: Node3D) -> void:
	if body is Plaeyr:
		player = null
		is_chasing = false
