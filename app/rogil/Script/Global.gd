extends Node

var room1: PackedScene = preload("res://Scene/comtwo.tscn")
var room2: PackedScene = preload("res://Scene/roomtree.tscn")
var room3: PackedScene = preload("res://Scene/room_4.tscn")
var arry_room = [room1, room2, room3]   # теперь объявлено после

func get_room() -> PackedScene:
	var random_index = randi() % arry_room.size()
	return arry_room[random_index]
