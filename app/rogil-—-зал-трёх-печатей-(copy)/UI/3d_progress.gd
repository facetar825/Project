extends Node3D
@onready var progress_bar: ProgressBar = $SubViewport/ProgressBar

func set_value(n):
	progress_bar.value = n

func set_max_value(n):
	progress_bar.max_value = n
