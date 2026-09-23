extends Node3D
## Визуальный слой поверх исходных комнат. Не меняет их коллизии и маршруты.
const V = preload("res://Script/floor/visuals.gd")
const STONE = preload("res://Shader/dungeon_stone.gdshader")
const BRONZE := Color("827151")
const ROCK := Color("47535a")
var flames: Array[MeshInstance3D] = []
var lights: Array[OmniLight3D] = []
var time := 0.0

func decorate(dungeon: Node3D) -> void:
	var material := ShaderMaterial.new()
	material.shader = STONE
	for part in dungeon.find_children("*", "CSGShape3D", true, false):
		if part is CSGBox3D:
			part.material = material
			if part.size.y > 5 and maxf(part.size.x, part.size.z) > 7:
				trim_wall(part)
		elif part is CSGMesh3D:
			part.material_override = V.material(BRONZE.darkened(0.25))
	for index in range(4):
		var room: Node3D = dungeon.rooms[index]
		var floor_box: CSGBox3D = room.get_node("CSGCombiner3D/CSGBox3D")
		var center := floor_box.global_position
		center.y += floor_box.size.y / 2 + 0.025
		if index == 0:
			var rug := V.box(self, center, Vector3(46, 0.025, 4), Color("663e43"))
			rug.rotation.y = room.rotation.y
			for side in [-1, 1]:
				V.box(self, center + Vector3(0, 0.018, side * 1.8), Vector3(45, 0.015, 0.08), BRONZE)
		else:
			var radius := 7.0 if index == 3 else 4.5
			var outer := V.ring(self, center, radius, BRONZE)
			outer.material_override = V.material(BRONZE)
			var inner := V.ring(self, center + Vector3.UP * 0.02, radius - 0.45, Color("466d6c"))
			inner.material_override = V.material(Color("466d6c"))
			for step in range(12):
				var angle := step * TAU / 12
				var mark := V.box(self, center + Vector3(cos(angle), 0.03, sin(angle)) * (radius - 0.8), Vector3(0.12, 0.02, 0.65), BRONZE)
				mark.rotation.y = -angle + PI / 2
		# Бanners отмечают входы и визуально различают комнаты.
		for side in [-1, 1]:
			var pos := room.to_global(Vector3(side * 3.4, 4.1, -2.0))
			var banner := Node3D.new()
			add_child(banner)
			banner.global_position = pos
			banner.rotation.y = room.rotation.y
			V.box(banner, Vector3.ZERO, Vector3(1.1, 2.8, 0.08), Color("386568") if index == 3 else Color("70434a"))
			V.box(banner, Vector3(0, 1.5, 0), Vector3(1.5, 0.12, 0.18), BRONZE)
			var sigil := V.box(banner, Vector3(0, 0.1, 0.06), Vector3(0.4, 0.4, 0.025), Color("d2af70"))
			sigil.rotation.z = PI / 4
			V.box(banner, Vector3(0, -0.9, 0.06), Vector3(0.04, 0.7, 0.02), BRONZE)
		# Светящиеся частицы над печатью, ограниченное число для слабых ПК.
		motes(room.to_global(Vector3(0, 1.5, -5)))

func trim_wall(wall: CSGBox3D) -> void:
	var along_x := wall.size.x > wall.size.z
	var length := wall.size.x if along_x else wall.size.z
	var depth := wall.size.z if along_x else wall.size.x
	var group := Node3D.new()
	add_child(group)
	group.global_transform = wall.global_transform
	var count := maxi(1, int(length / 7))
	for side in [-1, 1]:
		for level in [0.25, 4.8]:
			var pos := Vector3(0, -wall.size.y / 2 + level, side * (depth / 2 + 0.08))
			var size := Vector3(length, 0.18, 0.18)
			if not along_x:
				pos = Vector3(pos.z, pos.y, pos.x)
				size = Vector3(size.z, size.y, size.x)
			V.box(group, pos, size, BRONZE.darkened(0.25))
		for index in range(count):
			var offset := (index + 0.5) * length / count - length / 2
			var pos := Vector3(offset, -wall.size.y / 2, side * (depth / 2 + 0.12))
			if not along_x:
				pos = Vector3(pos.z, pos.y, pos.x)
			V.box(group, pos + Vector3.UP * 2.5, Vector3(0.6, 5, 0.6), ROCK)
			for height in [0.25, 4.8]:
				V.box(group, pos + Vector3.UP * height, Vector3(0.85, 0.3, 0.85), ROCK.lightened(0.10))
			if index % 2 == 0:
				var outward := Vector3(0, 0, side * 0.55) if along_x else Vector3(side * 0.55, 0, 0)
				torch(group, pos + Vector3.UP * 3 + outward)

func torch(parent: Node3D, point: Vector3) -> void:
	V.box(parent, point, Vector3(0.24, 0.65, 0.24), Color("292b30"))
	var flame := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.14
	mesh.height = 0.5
	flame.mesh = mesh
	var mat := V.material(Color("ffc67d"), true)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame.material_override = mat
	parent.add_child(flame)
	flame.position = point + Vector3.UP * 0.5
	flames.append(flame)
	var light := OmniLight3D.new()
	parent.add_child(light)
	light.position = point + Vector3.UP * 0.65
	light.light_color = Color("ffbc78")
	light.light_energy = 2.0
	light.omni_range = 8
	lights.append(light)

func motes(point: Vector3) -> void:
	var particles := CPUParticles3D.new()
	add_child(particles)
	particles.position = point
	particles.amount = 14
	particles.lifetime = 5
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(2, 1, 2)
	particles.direction = Vector3.UP
	particles.gravity = Vector3.ZERO
	particles.initial_velocity_min = 0.1
	particles.initial_velocity_max = 0.35
	particles.scale_amount_min = 0.025
	particles.scale_amount_max = 0.06
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1
	mesh.material = V.material(Color("dec18a"), true)
	particles.mesh = mesh

func _process(delta: float) -> void:
	time += delta
	for index in range(flames.size()):
		var flicker := sin(time * 7 + index * 2.7) * 0.08 + sin(time * 13 + index) * 0.04
		flames[index].scale.y = 1 + flicker
		lights[index].light_energy = 2 + flicker * 2
