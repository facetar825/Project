extends Node
var room_1 : PackedScene = preload("res://Scene/comtwo.tscn")
var room_2 : PackedScene = preload("res://Scene/roomtree.tscn")
var room_3 : PackedScene = preload("res://Scene/room_4.tscn")
var arry_rooms = [room_1, room_2, room_3 ]
func get_room():
	var random_room = arry_rooms[randi() % arry_rooms.size()]
	return random_room
