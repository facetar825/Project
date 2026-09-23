extends Node3D
## Ограниченный пул следов, короткие эффекты и обратная связь удара.
const V = preload("res://Script/floor/visuals.gd")
var game: Node3D
var trauma := 0.0
var screen: ShaderMaterial
var stains: Array[Node3D] = []
var active: Array[CPUParticles3D] = []
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen = ShaderMaterial.new()
	screen.shader = preload("res://Shader/crimson_screen.gdshader")
	overlay.material = screen
	layer.add_child(overlay)

func _process(delta: float) -> void:
	trauma = maxf(0, trauma - delta * 2.8)
	screen.set_shader_parameter("trauma", trauma)
	screen.set_shader_parameter("health", game.hero.hp / game.hero.max_hp if is_instance_valid(game.hero) else 1.0)
	for index in range(active.size() - 1, -1, -1):
		if not is_instance_valid(active[index]):
			active.remove_at(index)
		else:
			active[index].visible = game.options.particles
	for stain in stains:
		stain.visible = game.options.blood
	if is_instance_valid(game.hero) and is_instance_valid(game.hero.camera):
		var amount := trauma * 0.065 if game.options.camera_shake and game.mode == "playing" else 0.0
		game.hero.camera.h_offset = rng.randf_range(-amount, amount)
		game.hero.camera.v_offset = rng.randf_range(-amount, amount)

func impact(point: Vector3, heavy: bool = false) -> void:
	trauma = maxf(trauma, 0.45 if heavy else 0.12)
	if game.options.particles:
		burst(point + Vector3.UP, Color("f8d9cb"), 14 if heavy else 7, 5.0)
		if game.options.blood:
			burst(point + Vector3.UP, Color("ab173f"), 20 if heavy else 10, 3.2)
	if game.options.blood:
		blood_mark(point, 0.75 if heavy else 0.3)

func death(point: Vector3, boss: bool = false) -> void:
	impact(point, true)
	if game.options.particles:
		burst(point + Vector3.UP, Color("2b202b"), 32 if boss else 15, 6.0)
	if game.options.blood:
		blood_mark(point, 2.2 if boss else 1.1)

func hurt() -> void:
	trauma = 1.0

func dash(point: Vector3) -> void:
	if game.options.particles:
		burst(point + Vector3.UP, Color("e3325c"), 14, 1.5)

func slash(point: Vector3, radius: float, direction: float) -> void:
	# Две ленты формируют чёткое белое лезвие и багровый след.
	for layer in range(2):
		var ribbon := MeshInstance3D.new()
		var mesh := ImmediateMesh.new()
		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for step in range(28):
			var a := -2.0 + step * 4.0 / 28
			var b := -2.0 + (step + 1) * 4.0 / 28
			var width := (0.2 if layer == 0 else 0.06) * sin((step + 0.5) * PI / 28)
			var r := radius * (0.86 if layer == 0 else 0.9)
			var p1 := Vector3(sin(a) * r, 0, cos(a) * r)
			var p2 := Vector3(sin(b) * r, 0, cos(b) * r)
			var p3 := Vector3(sin(a) * (r - width * 4), 0, cos(a) * (r - width * 4))
			var p4 := Vector3(sin(b) * (r - width * 4), 0, cos(b) * (r - width * 4))
			for vertex in [p1, p3, p2, p2, p3, p4]:
				mesh.surface_add_vertex(vertex)
		mesh.surface_end()
		ribbon.mesh = mesh
		var mat := V.material(Color("d42252") if layer == 0 else Color("ffe4e4"), true)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ribbon.material_override = mat
		add_child(ribbon)
		ribbon.position = point + Vector3.UP * (1.0 + layer * 0.025)
		ribbon.rotation = Vector3(0.14, direction - 0.6, 0.15)
		var tween := create_tween().set_parallel()
		tween.tween_property(ribbon, "rotation:y", direction + 0.8, 0.22)
		tween.tween_property(mat, "albedo_color:a", 0.0, 0.28)
		tween.chain().tween_callback(ribbon.queue_free)

func burst(point: Vector3, color: Color, amount: int, power: float) -> void:
	if active.size() > 28:
		return
	var particles := CPUParticles3D.new()
	add_child(particles)
	particles.position = point
	particles.amount = amount
	particles.lifetime = 0.55
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.direction = Vector3.UP
	particles.spread = 125
	particles.initial_velocity_min = power * 0.5
	particles.initial_velocity_max = power
	particles.gravity = Vector3(0, -12, 0)
	particles.scale_amount_min = 0.025
	particles.scale_amount_max = 0.1
	var mesh := SphereMesh.new()
	mesh.radial_segments = 5
	mesh.rings = 2
	mesh.material = V.material(color, true)
	particles.mesh = mesh
	active.append(particles)
	get_tree().create_timer(0.9).timeout.connect(particles.queue_free)

func blood_mark(point: Vector3, radius: float) -> void:
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.5, point + Vector3.DOWN * 3, 1))
	if hit.is_empty():
		return
	var mark := MeshInstance3D.new()
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for step in range(14):
		var a := step * TAU / 14
		var b := (step + 1) * TAU / 14
		mesh.surface_add_vertex(Vector3.ZERO)
		mesh.surface_add_vertex(Vector3(sin(b), 0, cos(b)) * radius * rng.randf_range(0.6, 1.1))
		mesh.surface_add_vertex(Vector3(sin(a), 0, cos(a)) * radius * rng.randf_range(0.6, 1.1))
	mesh.surface_end()
	mark.mesh = mesh
	var mat := V.material(Color("5c1029"))
	mat.roughness = 0.25
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mark.material_override = mat
	add_child(mark)
	mark.position = hit.position + Vector3.UP * 0.018
	stains.append(mark)
	if stains.size() > 40:
		stains.pop_front().queue_free()
