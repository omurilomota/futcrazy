@tool
class_name Ball
extends RigidBody3D

## Bola de futebol com física 2.5D (Z travado, rotação só no plano da tela).
## Eventos alteram a bola via add_modifier()/remove_modifier().

const MIN_RADIUS := 0.32
const MAX_SPEED := 36.0

var game: Node
var modifiers: Dictionary = {}

var mesh_root: Node3D
var sphere: MeshInstance3D
var trail: CPUParticles3D

var _squash := 0.0
var _sfx_cd := 0.0
var _base_material: StandardMaterial3D


func setup(g: Node) -> void:
	game = g
	mass = 0.45
	gravity_scale = 1.0
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 6
	axis_lock_linear_z = true
	axis_lock_angular_x = true
	axis_lock_angular_y = true
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.06
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp = 0.45
	collision_layer = 4
	collision_mask = 1 | 2 | 4

	physics_material_override = PhysicsMaterial.new()
	physics_material_override.bounce = 0.62
	physics_material_override.friction = 0.75

	var shape := SphereShape3D.new()
	shape.radius = MIN_RADIUS
	var collider := CollisionShape3D.new()
	collider.shape = shape
	add_child(collider)

	_build_visuals()
	_refresh()
	body_entered.connect(_on_body_entered)


func _build_visuals() -> void:
	mesh_root = Node3D.new()
	add_child(mesh_root)

	sphere = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = MIN_RADIUS
	sm.height = MIN_RADIUS * 2.0
	sm.radial_segments = 18
	sm.rings = 10
	sphere.mesh = sm
	_base_material = StandardMaterial3D.new()
	_base_material.albedo_color = Color("#f8fafc")
	_base_material.roughness = 0.55
	sphere.material_override = _base_material
	mesh_root.add_child(sphere)

	# manchas escuras nas laterais: dá leitura de rotação quando a bola rola
	var spot_mat := StandardMaterial3D.new()
	spot_mat.albedo_color = Color("#111827")
	spot_mat.roughness = 0.7
	var dirs := [
		Vector3(0.0, 0.0, 1.0),
		Vector3(0.62, 0.35, 0.7),
		Vector3(-0.62, 0.35, 0.7),
		Vector3(0.55, -0.5, 0.66),
		Vector3(-0.55, -0.5, 0.66),
		Vector3(0.0, 0.95, 0.3),
		Vector3(0.0, -0.95, 0.3),
		Vector3(0.9, 0.1, 0.42),
		Vector3(-0.9, 0.1, 0.42),
	]
	for i in dirs.size():
		var d: Vector3 = (dirs[i] as Vector3).normalized()
		var patch := MeshInstance3D.new()
		var pm := SphereMesh.new()
		pm.radius = 0.085
		pm.height = 0.17
		pm.radial_segments = 8
		pm.rings = 4
		patch.mesh = pm
		patch.material_override = spot_mat
		patch.position = d * (MIN_RADIUS * 0.9)
		mesh_root.add_child(patch)

	# rastro: só aparece quando a bola voa rápido
	trail = Fx.trail(self, Color("#f8fafc"), 26)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	# campo de trampolim: a bola ganha energia a cada toque no chão
	if game != null and game.trampoline and linear_velocity.y <= 0.1:
		if global_position.y < MIN_RADIUS + 0.35:
			var v := linear_velocity
			v.y = clampf(absf(v.y) * 1.15 + 6.0, 9.0, 22.0)
			linear_velocity = v
			squash(0.22)

	# limita a velocidade para nenhuma física explodir
	var lv := linear_velocity
	var sp := lv.length()
	if sp > MAX_SPEED:
		linear_velocity = lv / sp * MAX_SPEED

	_squash = move_toward(_squash, 0.0, delta * 1.8)
	var s := clampf(_squash, -0.4, 0.4)
	mesh_root.scale = Vector3(1.0 + s, 1.0 - s, 1.0 + s)

	_sfx_cd = maxf(0.0, _sfx_cd - delta)
	if trail != null:
		trail.emitting = linear_velocity.length() > 13.0


func _on_body_entered(body: Node) -> void:
	var sp := linear_velocity.length()
	if sp > 5.0:
		squash(clampf(sp / 45.0, 0.05, 0.25))
	if sp > 7.0 and _sfx_cd <= 0.0 and game != null and game.has_method("sfx_play"):
		_sfx_cd = 0.09
		var vol := lerpf(-18.0, -4.0, clampf(sp / 28.0, 0.0, 1.0))
		game.sfx_play("bounce", vol, clampf(1.6 - sp * 0.02, 0.7, 1.45))
		if global_position.y < 1.2 and body is StaticBody3D:
			game.spawn_dust(global_position - Vector3(0.0, MIN_RADIUS * 0.7, 0.0), Color("#dbe7cf"), 5.0, 0.7)


func squash(amount: float) -> void:
	_squash = maxf(_squash, amount)


func add_modifier(id: String, mod: Dictionary) -> void:
	modifiers[id] = mod
	_refresh()


func remove_modifier(id: String) -> void:
	modifiers.erase(id)
	_refresh()


func has_modifier(id: String) -> bool:
	return modifiers.has(id)


func _refresh() -> void:
	var bounce := 0.62
	var friction := 0.75
	var mass_mult := 1.0
	var gravity := 1.0
	var tint := Color("#f8fafc")
	for id in modifiers:
		var m: Dictionary = modifiers[id]
		bounce = maxf(bounce, float(m.get("bounce", 0.0)))
		friction = minf(friction, float(m.get("friction", 1.0)))
		mass_mult *= float(m.get("mass", 1.0))
		gravity *= float(m.get("gravity", 1.0))
		if m.has("tint"):
			tint = m["tint"]
	mass = clampf(0.45 * mass_mult, 0.12, 2.0)
	gravity_scale = clampf(gravity, 0.0, 3.0)
	physics_material_override.bounce = bounce
	physics_material_override.friction = friction
	if _base_material != null:
		_base_material.albedo_color = tint
