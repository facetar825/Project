extends Node3D

@onready var com_one: Node3D = $comOne


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	startgen()
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
func startgen():
	await get_tree().create_timer(1).timeout
	com_one.startgen(2)
	pass
