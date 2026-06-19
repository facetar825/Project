extends Node3D
@onready var pointgena: Node3D = $pointgena


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func startgen(n):
	for point in pointgena.get_children():
		
		var room = Global.get_room().instantiate()

		get_tree().current_scene.add_child(room)

		room.global_transform = point.global_transform
		if n > 1:
			room.startgen(n - 1)
		
