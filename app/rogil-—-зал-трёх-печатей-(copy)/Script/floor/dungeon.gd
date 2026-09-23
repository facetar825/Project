extends Node3D
## Этаж из авторских PackedScene. Стены, полы и их материалы берутся из пресетов.
const Visuals = preload("res://Script/floor/visuals.gd")
const PRESETS = [preload("res://Scene/room_4.tscn"), preload("res://Scene/roomtree.tscn"), preload("res://Scene/comtwo.tscn"), preload("res://Scene/roomtree.tscn")]
const WALL = preload("res://Scene/Wall.tscn")
const DOOR = preload("res://Scene/Doors.tscn")
const NAMES := ["ДЛИННАЯ ГАЛЕРЕЯ", "КАМЕННЫЙ ЗАЛ", "ЛАБИРИНТ", "ЗАЛ СТРАЖА"]
const CELL := 1.25
var rooms: Array[Node3D] = []
var entrances: Array[Vector3] = []
var exits: Array[Vector3] = []
var gates: Array[Node3D] = []
var grid := AStarGrid2D.new()
var ready_for_play := false
var spawn_cells: Array = [[], [], [], []]
var start_position := Vector3(0, 0.3, 5)
var end_position := Vector3.ZERO

func _ready() -> void:
	var start: Node3D = $Entrance
	adapt_thresholds(start)
	var socket: Node3D = start.get_node("pointgena/point_spawn_com")
	var anchor := socket.global_position
	anchor.y = 0
	for index in range(PRESETS.size()):
		var room: Node3D = get_node(["Gallery", "Hall", "Maze", "GuardianHall"][index])
		room.position = anchor
		# У бокового выхода comtwo исходный маркер повёрнут внутрь комнаты.
		# Последний зал разворачиваем наружу, чтобы комнаты не пересекались.
		room.rotation.y = PI / 2 if index == 3 else 0.0
		rooms.append(room)
		entrances.append(anchor)
		adapt_thresholds(room)
		add_gate(anchor, room.rotation.y)
		bridge(anchor, room.rotation.y)
		var exit_socket: Node3D = room.get_node("pointgena/point_spawn_com")
		anchor = exit_socket.global_position
		anchor.y = 0
		exits.append(anchor)
		var title_pos := room.to_global(Vector3(0, 4.8, -3))
		Visuals.caption(self, "%02d  /  %s" % [index + 1, NAMES[index]], title_pos, Color("edc17b"))
		for lamp_point in [Vector3(1.6, 3, -4), room.to_local(anchor) + Vector3(1.6, 3, 3)]:
			var lamp := OmniLight3D.new()
			lamp.position = room.to_global(lamp_point)
			lamp.light_color = Color("ffd39b")
			lamp.light_energy = 2.5
			lamp.omni_range = 12
			add_child(lamp)
	end_position = rooms[3].to_global(Vector3(0, 0, -48))
	cap(start.to_global(Vector3(0, 3, 10.4)), 0, 11)
	cap(exits[3] + Vector3.UP * 3, PI / 2, 5.8)
	set_gate(0, false)
	prepare_navigation.call_deferred()

func adapt_thresholds(room: Node3D) -> void:
	# В исходной дверной раме порог возвышается над полом. Опускаем только порог,
	# сохраняя саму раму, чтобы входить можно было без обязательного прыжка.
	for node in room.find_children("CSGMesh3D3", "CSGMesh3D", true, false):
		node.position.y -= 0.4
		node.use_collision = false

func bridge(point: Vector3, angle: float) -> void:
	var tile := WALL.instantiate() as CSGBox3D
	tile.size = Vector3(3.6, 0.2, 2.4)
	tile.position = point + Vector3(0, -0.12, 0)
	tile.rotation.y = angle
	tile.use_collision = true
	add_child(tile)

func cap(point: Vector3, angle: float, width: float) -> void:
	var wall := WALL.instantiate() as CSGBox3D
	wall.size = Vector3(width, 8, 0.8)
	wall.position = point
	wall.rotation.y = angle
	wall.use_collision = true
	add_child(wall)

func add_gate(point: Vector3, angle: float) -> void:
	var gate := Node3D.new()
	add_child(gate)
	gate.position = point
	gate.rotation.y = angle
	var frame := DOOR.instantiate()
	gate.add_child(frame)
	adapt_thresholds(gate)
	var barrier := Visuals.box(gate, Vector3(0, 3, 0), Vector3(4.3, 6, 0.4), Color("437d79"), true)
	barrier.name = "Barrier"
	# Двери не участвуют в статической сетке, но блокируют тела и удары.
	barrier.get_child(0).collision_layer = 8
	var mat := Visuals.material(Color(0.22, 0.64, 0.57, 0.45), true)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	barrier.material_override = mat
	gates.append(gate)

func set_gate(index: int, closed: bool) -> void:
	var barrier: MeshInstance3D = gates[index].get_node("Barrier")
	barrier.visible = closed
	barrier.get_child(0).collision_layer = 8 if closed else 0

func entered_room(index: int, point: Vector3) -> bool:
	var local := rooms[index].to_local(point)
	return local.z < -3.3 and local.z > -8 and absf(local.x) < 2.0

func checkpoint(index: int) -> Vector3:
	return rooms[index].to_global(Vector3(0, 0.35, -5))

func contains_point(index: int, point: Vector3, margin: float = 0) -> bool:
	var room := rooms[index]
	var floor_box: CSGBox3D = room.get_node("CSGCombiner3D/CSGBox3D")
	var local := floor_box.to_local(point)
	return absf(local.x) < floor_box.size.x / 2 - margin and absf(local.z) < floor_box.size.z / 2 - margin

func prepare_navigation() -> void:
	# CSG обновляет коллизии после входа в дерево, поэтому ждём физические кадры.
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	grid.region = Rect2i(-40, -135, 110, 147)
	grid.cell_size = Vector2.ONE * CELL
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	var space := get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = 0.85
	var clearance := PhysicsShapeQueryParameters3D.new()
	clearance.shape = shape
	clearance.collision_mask = 1
	for x in range(grid.region.position.x, grid.region.end.x):
		for z in range(grid.region.position.y, grid.region.end.y):
			var cell := Vector2i(x, z)
			var point := Vector3(x * CELL, 0, z * CELL)
			var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 2, point - Vector3.UP * 2, 1)
			var hit := space.intersect_ray(ray)
			clearance.transform.origin = point + Vector3.UP * 1.25
			var solid := hit.is_empty() or not space.intersect_shape(clearance, 1).is_empty()
			grid.set_point_solid(cell, solid)
			if not solid:
				for index in range(4):
					if contains_point(index, point, 4):
						spawn_cells[index].append(point + Vector3.UP * 0.3)
	ready_for_play = true

func nearest_cell(point: Vector3) -> Vector2i:
	var cell := Vector2i(roundi(point.x / CELL), roundi(point.z / CELL))
	for radius in range(5):
		for x in range(-radius, radius + 1):
			for z in range(-radius, radius + 1):
				var candidate := cell + Vector2i(x, z)
				if grid.is_in_boundsv(candidate) and not grid.is_point_solid(candidate):
					return candidate
	return Vector2i(-9999, -9999)

func route(from: Vector3, to: Vector3) -> PackedVector3Array:
	if not ready_for_play:
		return PackedVector3Array()
	var first := nearest_cell(from)
	var last := nearest_cell(to)
	if not grid.is_in_boundsv(first) or not grid.is_in_boundsv(last):
		return PackedVector3Array()
	var result := PackedVector3Array()
	for cell in grid.get_id_path(first, last):
		result.append(Vector3(cell.x * CELL, 0.3, cell.y * CELL))
	return result

func spawn_point(index: int, player: Vector3, rng: RandomNumberGenerator) -> Vector3:
	var candidates: Array = spawn_cells[index]
	if candidates.is_empty():
		return checkpoint(index)
	for attempt in range(40):
		var point: Vector3 = candidates[rng.randi_range(0, candidates.size() - 1)]
		if point.distance_to(player) > 9 and not route(point, player).is_empty():
			return point
	return checkpoint(index) + Vector3(0, 0, -3)

func clear_sight(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from + Vector3.UP, to + Vector3.UP, 1 | 8)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()
