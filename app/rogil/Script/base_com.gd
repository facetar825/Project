extends Node3D
@onready var pointgena: Node3D = $pointgena


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func startgen(n: int) -> void:
	for point in pointgena.get_children():
		var room = Global.get_room().instantiate()   # исправлено instantiate
		# Добавляем комнату как дочернюю к текущей (чтобы сохранить иерархию)
		add_child(room)
		# Устанавливаем позицию в соответствии с точкой
		room.global_transform = point.global_transform
		
		if n > 1:
			room.startgen(n - 1)
		
