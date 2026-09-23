extends RefCounted
## Авторские процедурные персонажи «Алого обета». +Z — лицо, y=0 — подошвы.
## Геометрия собирается один раз, затем объединяется по материалам внутри суставов.
## Анимация независима от физики и не создаёт меши во время игры.

static var _materials: Dictionary = {}

static func _mat(key: String) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	var colors := {"coat": "171c2a", "edge": "354253", "black": "090c13", "lining": "661529", "flesh": "adb4b8", "bone": "ece3d6", "hair": "ecf3f3", "crimson": "990c32", "red": "f32f55", "steel": "8798a5", "gold": "b89162"}
	m.albedo_color = Color(colors.get(key, "ffffff"))
	m.roughness = 0.76
	if key in ["crimson", "lining"]:
		m.roughness = 0.34
		m.metallic = 0.2
	if key in ["steel", "gold", "edge"]:
		m.metallic = 0.6
		m.roughness = 0.4
	if key == "red":
		m.emission_enabled = true
		m.emission = Color("ff1549")
		m.emission_energy_multiplier = 2.1
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_materials[key] = m
	return m

static func _node(parent: Node3D, pos: Vector3, label: String = "") -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.name = label if not label.is_empty() else "Joint"
	parent.add_child(n)
	return n

static func _mesh(parent: Node3D, mesh: Mesh, key: String, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _mat(key)
	instance.position = pos
	parent.add_child(instance)
	return instance

static func _oval(parent: Node3D, pos: Vector3, size: Vector3, key: String) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 16
	sphere.rings = 8
	var piece := _mesh(parent, sphere, key, pos)
	piece.scale = size
	return piece

static func _tube(parent: Node3D, points: PackedVector3Array, widths: PackedFloat32Array, key: String, sides: int = 8, flatten: float = 1.0) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[PackedVector3Array] = []
	for i in points.size():
		var direction: Vector3 = points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]
		direction = direction.normalized()
		var axis := Vector3.UP if absf(direction.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
		var right := direction.cross(axis).normalized()
		var up := right.cross(direction).normalized()
		var ring := PackedVector3Array()
		for j in sides:
			var angle := float(j) / sides * TAU
			ring.append(points[i] + (right * cos(angle) + up * sin(angle) * flatten) * widths[i])
		rings.append(ring)
	for i in range(rings.size() - 1):
		for j in sides:
			var k := (j + 1) % sides
			for vertex in [rings[i][j], rings[i + 1][j], rings[i + 1][k], rings[i][j], rings[i + 1][k], rings[i][k]]:
				st.add_vertex(vertex)
	# Closing rings keeps cuffs and organic roots solid from every camera angle.
	for j in sides:
		for vertex in [points[0], rings[0][(j + 1) % sides], rings[0][j], points[-1], rings[-1][j], rings[-1][(j + 1) % sides]]:
			st.add_vertex(vertex)
	st.generate_normals()
	return _mesh(parent, st.commit(), key)

static func _line(parent: Node3D, a: Vector3, b: Vector3, radius: float, key: String, end_radius: float = -1.0) -> MeshInstance3D:
	return _tube(parent, PackedVector3Array([a, b]), PackedFloat32Array([radius, radius if end_radius < 0 else end_radius]), key)

static func _cloth(parent: Node3D, side: float, key: String) -> void:
	# A flared coat panel with an uneven pointed hem; true volume, no billboard.
	_tube(parent, PackedVector3Array([Vector3(side * 0.03, 0, 0), Vector3(side * 0.09, -0.23, -0.04), Vector3(side * 0.17, -0.50, -0.12), Vector3(side * 0.20, -0.74, -0.18)]), PackedFloat32Array([0.19, 0.23, 0.27, 0.16]), key, 7, 0.5)
	_line(parent, Vector3(side * 0.18, -0.12, 0.06), Vector3(side * 0.31, -0.66, -0.10), 0.015, "lining", 0.01)

static func _begin(parent: Node3D, label: String) -> Node3D:
	var root := _node(parent, Vector3.ZERO, label)
	root.set_meta("arms", [])
	root.set_meta("legs", [])
	root.set_meta("tails", [])
	root.set_meta("tendrils", [])
	root.set_meta("hero", false)
	root.set_meta("kind", 0)
	return root

static func _remember(root: Node3D, slot: String, joint: Node3D, side: float = 1.0) -> void:
	joint.set_meta("rest_rotation", joint.rotation)
	joint.set_meta("side", side)
	var joints: Array = root.get_meta(slot)
	joints.append(joint)

static func build_hero(parent: Node3D) -> Node3D:
	var root := _begin(parent, "ScarletVowHero")
	root.set_meta("hero", true)
	var body := _node(root, Vector3(0, 1.00, 0), "BreathingBody")
	root.set_meta("body", body)
	_oval(body, Vector3(0, 0.18, 0), Vector3(0.49, 0.65, 0.31), "coat")
	_oval(body, Vector3(0, 0.38, 0.02), Vector3(0.59, 0.27, 0.34), "coat")
	_oval(body, Vector3(0, 0.12, 0.151), Vector3(0.28, 0.41, 0.047), "black")
	_line(body, Vector3(-0.19, 0.38, 0.15), Vector3(0.16, -0.02, 0.155), 0.025, "steel")
	_line(body, Vector3(0.17, 0.35, 0.14), Vector3(0.09, -0.03, 0.16), 0.018, "lining")
	_oval(body, Vector3(0, -0.02, 0), Vector3(0.44, 0.10, 0.34), "black")
	_oval(body, Vector3(0.03, -0.02, 0.185), Vector3(0.08, 0.074, 0.03), "steel")
	for side in [-1.0, 1.0]:
		# High, split collar frames the pale face against the black coat.
		var collar := _oval(body, Vector3(side * 0.15, 0.48, 0), Vector3(0.15, 0.24, 0.27), "coat")
		collar.rotation.z = side * -0.27
		_line(body, Vector3(side * 0.19, 0.52, 0.11), Vector3(side * 0.15, 0.37, 0.18), 0.02, "lining")
		var tail := _node(root, Vector3(side * 0.15, 0.97, -0.06), "CoatTail")
		_cloth(tail, side, "coat")
		_remember(root, "tails", tail, side)
		var leg := _node(root, Vector3(side * 0.135, 0.86, 0), "Leg")
		_line(leg, Vector3.ZERO, Vector3(0, -0.37, 0.015), 0.1, "black", 0.078)
		_oval(leg, Vector3(0, -0.39, 0.02), Vector3(0.17, 0.2, 0.2), "coat")
		_line(leg, Vector3(0, -0.39, 0.005), Vector3(0, -0.70, -0.025), 0.085, "black", 0.07)
		_oval(leg, Vector3(0, -0.75, 0.07), Vector3(0.19, 0.19, 0.34), "black")
		_line(leg, Vector3(-0.07, -0.70, 0.09), Vector3(0.07, -0.70, 0.09), 0.014, "steel")
		_remember(root, "legs", leg, side)
		var arm := _node(body, Vector3(side * 0.29, 0.36, 0), "Arm")
		arm.rotation.z = side * 0.08
		_oval(arm, Vector3(side * 0.025, -0.07, 0), Vector3(0.22, 0.27, 0.24), "coat")
		_line(arm, Vector3.ZERO, Vector3(side * 0.06, -0.32, 0.015), 0.089, "coat", 0.066)
		_line(arm, Vector3(side * 0.06, -0.32, 0.015), Vector3(side * 0.025, -0.58, 0.08), 0.078, "coat", 0.061)
		_line(arm, Vector3(side * 0.02, -0.48, 0.08), Vector3(side * 0.025, -0.53, 0.087), 0.067, "steel")
		_oval(arm, Vector3(side * 0.025, -0.63, 0.09), Vector3(0.14, 0.19, 0.13), "black")
		_remember(root, "arms", arm, side)
	var head := _node(body, Vector3(0, 0.68, 0.015), "MaskedHead")
	root.set_meta("head", head)
	_line(body, Vector3(0, 0.42, 0), Vector3(0, 0.58, 0), 0.075, "flesh")
	_oval(head, Vector3.ZERO, Vector3(0.30, 0.37, 0.29), "flesh")
	_oval(head, Vector3(0, -0.062, 0.125), Vector3(0.282, 0.194, 0.085), "black")
	# Original asymmetrical bone mask and steel staple mouth.
	_oval(head, Vector3(-0.084, 0.005, 0.145), Vector3(0.12, 0.23, 0.055), "bone")
	_line(head, Vector3(-0.13, -0.052, 0.16), Vector3(0.106, -0.087, 0.168), 0.013, "steel")
	for i in 6:
		var x := -0.093 + i * 0.035
		_line(head, Vector3(x, -0.071, 0.171), Vector3(x + 0.007, -0.102, 0.168), 0.006, "bone")
	_oval(head, Vector3(0.075, 0.038, 0.14), Vector3(0.103, 0.057, 0.029), "black")
	_oval(head, Vector3(0.075, 0.038, 0.157), Vector3(0.061, 0.03, 0.014), "red")
	_oval(head, Vector3(0, 0.095, -0.02), Vector3(0.327, 0.25, 0.29), "hair")
	for i in 12:
		var angle := i * 2.399963
		var x := cos(angle) * 0.12
		var z := sin(angle) * 0.085
		_tube(head, PackedVector3Array([Vector3(x, 0.13, z), Vector3(x - 0.045, 0.24, z - 0.04), Vector3(x - 0.135, 0.18, z - 0.095)]), PackedFloat32Array([0.07, 0.05, 0.002]), "hair", 5, 0.68)
	for i in 5:
		var x := -0.13 + i * 0.06
		_tube(head, PackedVector3Array([Vector3(x, 0.17, 0.10), Vector3(x - 0.025, 0.07, 0.163), Vector3(x - 0.07, -0.015 + i * 0.014, 0.17)]), PackedFloat32Array([0.047, 0.033, 0.001]), "hair", 5, 0.40)
	for side in [-1.0, 1.0]:
		_tendril(root, body, Vector3(side * 0.17, 0.22, -0.16), side, false, 0)
		_tendril(root, body, Vector3(side * 0.13, 0.03, -0.16), side, false, 1)
	_batch(root)
	return root

static func _tendril(root: Node3D, body: Node3D, anchor: Vector3, side: float, boss: bool, row: int) -> void:
	var limb := _node(body, anchor, "LivingTendril")
	var upper := row == 0
	var points := PackedVector3Array()
	if upper:
		points = PackedVector3Array([Vector3.ZERO, Vector3(side * 0.22, 0.12, -0.19), Vector3(side * 0.55, 0.36, -0.28), Vector3(side * 0.83, 0.68, -0.23), Vector3(side * 0.87, 0.95, -0.08), Vector3(side * 0.67, 1.14, 0.06)])
	else:
		points = PackedVector3Array([Vector3.ZERO, Vector3(side * 0.3, -0.12, -0.23), Vector3(side * 0.65, -0.19, -0.34), Vector3(side * 0.94, -0.05, -0.30), Vector3(side * 1.12, 0.21, -0.10), Vector3(side * 1.05, 0.46, 0.13)])
	if boss:
		for i in points.size():
			points[i] *= 1.22
		if row == 2:
			limb.rotation.z = side * 0.65
	var widths := PackedFloat32Array([0.09, 0.14, 0.105, 0.075, 0.045, 0.001])
	_tube(limb, points, widths, "crimson", 9, 0.72)
	var vein := PackedVector3Array()
	for i in points.size():
		vein.append(points[i] + Vector3(0, 0, widths[i] * 0.75))
	_tube(limb, vein, PackedFloat32Array([0.018, 0.025, 0.018, 0.012, 0.01, 0.001]), "red", 5)
	for i in range(1, 5):
		var point := points[i]
		_line(limb, point, point + Vector3(side * 0.12, 0.12, -0.03), widths[i] * 0.46, "crimson", 0.001)
	_tube(limb, PackedVector3Array([points[4], points[4].lerp(points[5], 0.6), points[5]]), PackedFloat32Array([0.041, 0.028, 0.001]), "bone" if boss else "red", 6, 0.7)
	_remember(root, "tendrils", limb, side)

static func build_enemy(parent: Node3D, kind: int) -> Node3D:
	var root := _begin(parent, ["HollowMask", "Ravenous", "BoneWarden", "CrownedDevourer"][clampi(kind, 0, 3)])
	root.set_meta("kind", kind)
	root.scale = Vector3.ONE * [1.0, 0.7, 1.4, 2.5][clampi(kind, 0, 3)]
	var heavy := kind >= 2
	var boss := kind == 3
	var runner := kind == 1
	var body := _node(root, Vector3(0, 0.97, 0), "BreathingBody")
	root.set_meta("body", body)
	if runner:
		body.rotation.x = 0.32
	_oval(body, Vector3(0, 0.2, 0), Vector3(0.63 if heavy else 0.46, 0.65, 0.36 if heavy else 0.27), "black" if boss else "coat")
	_oval(body, Vector3(0, 0.32, 0.11), Vector3(0.52 if heavy else 0.39, 0.40, 0.22), "crimson" if boss else "flesh")
	_line(body, Vector3(0, -0.05, 0.16), Vector3(0, 0.50, 0.16), 0.026, "red" if boss else "black")
	for side in [-1.0, 1.0]:
		for rib in range(4 if heavy else 3):
			var y := 0.36 - rib * 0.09
			_tube(body, PackedVector3Array([Vector3(side * 0.04, y, 0.22), Vector3(side * 0.19, y + 0.05, 0.23), Vector3(side * (0.30 if heavy else 0.23), y + 0.025, 0.03)]), PackedFloat32Array([0.024, 0.039 if heavy else 0.022, 0.009]), "bone" if heavy else "coat", 6)
		var leg := _node(root, Vector3(side * 0.15, 0.85, 0), "Leg")
		_line(leg, Vector3.ZERO, Vector3(side * 0.04, -0.36, 0.06), 0.125 if heavy else 0.09, "coat", 0.065)
		_oval(leg, Vector3(side * 0.04, -0.39, 0.06), Vector3(0.17, 0.19, 0.20), "bone" if heavy else "flesh")
		_line(leg, Vector3(side * 0.04, -0.41, 0.04), Vector3(side * 0.015, -0.71, -0.04), 0.08, "black", 0.055)
		_oval(leg, Vector3(side * 0.015, -0.77, 0.06), Vector3(0.18, 0.16, 0.30), "black")
		_remember(root, "legs", leg, side)
		var arm := _node(body, Vector3(side * (0.36 if heavy else 0.25), 0.39, -0.005), "ClawArm")
		arm.rotation.z = side * (0.22 if heavy else 0.13)
		var reach := 1.20 if runner else 1.0
		_oval(arm, Vector3(side * 0.03, -0.07, 0), Vector3(0.32 if heavy else 0.19, 0.30, 0.27), "crimson" if boss else "flesh")
		_line(arm, Vector3(0, -0.04, 0), Vector3(side * 0.065, -0.31, 0.035), 0.11 if heavy else 0.075, "black" if boss else "flesh", 0.055)
		_line(arm, Vector3(side * 0.065, -0.31, 0.035), Vector3(side * 0.04, -0.62 * reach, 0.1), 0.11 if heavy else 0.066, "crimson" if boss else "flesh", 0.047)
		_oval(arm, Vector3(side * 0.04, -0.66 * reach, 0.1), Vector3(0.14, 0.2, 0.12), "black")
		for finger in 3:
			var x := side * 0.04 + (finger - 1) * 0.045
			_tube(arm, PackedVector3Array([Vector3(x, -0.71 * reach, 0.11), Vector3(x * 1.4, -0.85 * reach, 0.20), Vector3(x * 1.45, -0.92 * reach, 0.31)]), PackedFloat32Array([0.026, 0.018, 0.001]), "bone", 5)
		if heavy:
			_oval(arm, Vector3(side * 0.01, 0, -0.015), Vector3(0.4, 0.25, 0.36), "black")
			for spike in 3:
				_tube(arm, PackedVector3Array([Vector3(side * spike * 0.06, 0.08, -0.055), Vector3(side * (0.16 + spike * 0.07), 0.22, -0.07), Vector3(side * (0.22 + spike * 0.09), 0.30 + spike * 0.04, -0.04)]), PackedFloat32Array([0.07, 0.035, 0.001]), "bone" if not boss else "crimson", 6)
		_remember(root, "arms", arm, side)
		var tail := _node(root, Vector3(side * 0.14, 0.93, -0.03), "Shroud")
		_cloth(tail, side, "black")
		tail.scale = Vector3(0.83, 0.65 if runner else 0.85, 0.8)
		_remember(root, "tails", tail, side)
	var head := _node(body, Vector3(0, 0.67, 0.065 if runner else 0), "HollowFace")
	root.set_meta("head", head)
	_line(body, Vector3(0, 0.40, 0), Vector3(0, 0.57, 0), 0.09, "black")
	_oval(head, Vector3(0, 0, -0.01), Vector3(0.31, 0.38, 0.30), "black")
	_oval(head, Vector3(0, -0.015, 0.118), Vector3(0.294, 0.333, 0.11), "bone")
	for side in [-1.0, 1.0]:
		var socket := _oval(head, Vector3(side * 0.074, 0.039, 0.164), Vector3(0.108, 0.084, 0.031), "black")
		socket.rotation.z = side * -0.3
		_oval(head, Vector3(side * 0.074, 0.036, 0.181), Vector3(0.059, 0.026, 0.015), "red")
		_line(head, Vector3(side * 0.072, -0.01, 0.17), Vector3(side * 0.102, -0.132, 0.151), 0.011, "crimson", 0.004)
		_tube(head, PackedVector3Array([Vector3(side * 0.13, -0.08, 0.135), Vector3(side * 0.08, -0.18, 0.13), Vector3(side * 0.035, -0.20, 0.165)]), PackedFloat32Array([0.024, 0.024, 0.001]), "bone", 5)
	_line(head, Vector3(0, 0.015, 0.173), Vector3(0, -0.073, 0.183), 0.014, "black")
	_line(head, Vector3(-0.069, -0.093, 0.165), Vector3(0.069, -0.093, 0.165), 0.013, "black")
	if runner:
		for i in 5:
			_line(body, Vector3(0, 0.12 + i * 0.1, -0.14), Vector3(0, 0.2 + i * 0.1, -0.35), 0.06, "bone", 0.001)
	if boss:
		# A floating broken crown and six living blades make the boss unmistakable.
		for i in 7:
			var angle := float(i) / 7 * TAU
			var base := Vector3(cos(angle) * 0.155, 0.115, sin(angle) * 0.13)
			_tube(head, PackedVector3Array([base, base * Vector3(1.6, 1, 1.6) + Vector3(0, 0.20, 0), base * Vector3(1.25, 1, 1.25) + Vector3(0, 0.4 + (i % 2) * 0.1, 0)]), PackedFloat32Array([0.045, 0.032, 0.001]), "gold", 6)
			_oval(head, base + Vector3(0, 0.065, 0), Vector3.ONE * 0.055, "red")
		for side in [-1.0, 1.0]:
			for row in 3:
				_tendril(root, body, Vector3(side * 0.21, 0.32 - row * 0.18, -0.19), side, true, row)
		_oval(body, Vector3(0, 0.25, 0.26), Vector3(0.09, 0.16, 0.045), "red")
	_batch(root)
	return root

static func _batch(node: Node3D) -> void:
	var groups: Dictionary = {}
	for child in node.get_children():
		if child is MeshInstance3D:
			var key: Material = child.material_override
			if not groups.has(key):
				groups[key] = []
			groups[key].append(child)
		elif child is Node3D:
			_batch(child)
	for key in groups:
		var pieces: Array = groups[key]
		if pieces.size() < 2:
			continue
		var builder := SurfaceTool.new()
		builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		for piece in pieces:
			builder.append_from(piece.mesh, 0, piece.transform)
			piece.free()
		builder.index()
		var merged := MeshInstance3D.new()
		merged.mesh = builder.commit()
		merged.material_override = key
		merged.name = "BatchedSculpt"
		node.add_child(merged)

static func animate(model: Node3D, time: float, moving: float, attack: float = 0.0) -> void:
	if not is_instance_valid(model) or not model.has_meta("body"):
		return
	moving = clampf(moving, 0, 1)
	attack = clampf(attack, 0, 1)
	var hero: bool = model.get_meta("hero", false)
	var kind: int = model.get_meta("kind", 0)
	var rhythm := time * (10.5 if kind == 1 else 8.5)
	var body: Node3D = model.get_meta("body")
	body.position.y = (1.0 if hero else 0.97) + sin(time * 2.6) * 0.012 + absf(sin(rhythm)) * moving * 0.028
	body.rotation.z = sin(rhythm) * moving * 0.028
	body.rotation.x = (0.32 if kind == 1 and not hero else 0.0) + moving * 0.035 + attack * 0.14
	for leg: Node3D in model.get_meta("legs", []):
		var side: float = leg.get_meta("side")
		leg.rotation.x = sin(rhythm) * side * moving * 0.43
	for arm: Node3D in model.get_meta("arms", []):
		var side: float = arm.get_meta("side")
		var rest: Vector3 = arm.get_meta("rest_rotation")
		arm.rotation.x = -sin(rhythm) * side * moving * 0.32 - attack * (1.25 if hero else 1.65)
		arm.rotation.z = rest.z + side * (sin(time * 2) * 0.025 + attack * 0.20)
	for tail: Node3D in model.get_meta("tails", []):
		var side: float = tail.get_meta("side")
		tail.rotation.x = sin(time * 4.0 + side) * 0.05 - moving * 0.18
		tail.rotation.z = sin(time * 3.4 + side) * 0.035
	var index := 0
	for limb: Node3D in model.get_meta("tendrils", []):
		var side: float = limb.get_meta("side")
		var rest: Vector3 = limb.get_meta("rest_rotation")
		limb.rotation.x = sin(time * 2.5 + index * 1.6) * 0.11 + attack * 0.7
		limb.rotation.y = sin(time * 1.7 + index * 1.2) * 0.16 + side * attack * 0.55
		limb.rotation.z = rest.z + sin(time * 2.0 + index * 1.7) * 0.085 - side * attack * 0.20
		index += 1
	var head: Node3D = model.get_meta("head")
	head.rotation.z = sin(time * 1.2) * 0.018
	head.rotation.y = sin(time * 0.7) * 0.045
	head.rotation.x = -attack * 0.1
