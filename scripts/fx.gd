class_name Fx
extends RefCounted

## Efeitos visuais baratos em CPUParticles3D: funcionam em qualquer GPU
## e também em modo headless (não quebram o teste automatizado).


static func _quad_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.WHITE
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func _blob_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.WHITE
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func _ramp(color: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, color)
	g.set_color(1, Color(color.r, color.g, color.b, 0.0))
	return g


## Baforada de poeira: pouso, chute, carrinho, gol.
static func dust(parent: Node3D, pos: Vector3, color := Color("#d6c9a8"), amount := 10, power := 1.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.92
	p.amount = clampi(amount, 4, 40)
	p.lifetime = 0.55
	p.local_coords = false
	p.direction = Vector3(1.0, 0.7, 0.0)
	p.spread = 70.0
	p.initial_velocity_min = 1.6 * power
	p.initial_velocity_max = 5.0 * power
	p.gravity = Vector3(0.0, -7.0, 0.0)
	p.damping_min = 2.5
	p.damping_max = 5.0
	p.scale_amount_min = 0.07
	p.scale_amount_max = 0.17
	p.color_ramp = _ramp(color)

	var q := QuadMesh.new()
	q.size = Vector2.ONE
	q.material = _quad_material()
	p.mesh = q

	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)


## Rastro contínuo (usado na bola quando ela voa rápido).
## Esferinhas em vez de quads: de perto o rastro não vira "quadradinhos".
static func trail(parent: Node3D, color := Color("#f8fafc"), amount := 20) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = 0.26
	p.local_coords = false
	p.emitting = false
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.35
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.7
	p.color_ramp = _ramp(color)

	var sm := SphereMesh.new()
	sm.radius = 0.05
	sm.height = 0.10
	sm.radial_segments = 8
	sm.rings = 4
	sm.material = _blob_material()
	p.mesh = sm

	parent.add_child(p)
	return p
