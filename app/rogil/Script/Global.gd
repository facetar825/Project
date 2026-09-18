extends Node

var arry_room = ["res://Scene/comtwo.tscn", "res://Scene/roomtree.tscn", "res://Scene/room_4.tscn"]

func get_room() -> PackedScene:
	var random_index = randi() % arry_room.size()
	return load(arry_room[random_index]) as PackedScene
