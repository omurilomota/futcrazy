class_name Stadium
extends Node3D

## Estádio low-poly 100% procedural: gramado listrado, gols, arquibancadas,
## torcida (MultiMesh), placas, torres de luz e um sol direcional com sombra.

const PITCH_W := 34.0
const PITCH_D := 36.0
const PITCH_Z := -2.0

var ground_mat: PhysicsMaterial


func build(_game: Node) -> void:
	_build_ground()
	_build_stands()
	_build_goal(-1.0)
	_build_goal(1.0)
	_build_masts()
	_build_lights()


func _flat(c: Color, rough := 0.95) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


func _mesh_box(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _flat(color)
	mi.position = pos
	add_child(mi)
	return mi


func _solid_box(size: Vector3, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 7
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	body.position = pos
	add_child(body)
	return body


# ------------------------------------------------------------------- gramado

func _build_ground() -> void:
	var body := _solid_box(Vector3(PITCH_W, 1.0, PITCH_D), Vector3(0.0, -0.5, PITCH_Z))
	ground_mat = PhysicsMaterial.new()
	ground_mat.bounce = 0.3
	ground_mat.friction = 1.0
	body.physics_material_override = ground_mat

	# grama: topo exatamente em y = 0
	_mesh_box(Vector3(PITCH_W, 0.4, PITCH_D), Vector3(0.0, -0.2, PITCH_Z), Color("#2c8a53"))

	# listras
	var stripes := 17
	var w := PITCH_W / float(stripes)
	for i in stripes:
		var c := Color("#2c8a53") if i % 2 == 0 else Color("#34975d")
		_mesh_box(Vector3(w, 0.02, PITCH_D), Vector3(-PITCH_W * 0.5 + w * (i + 0.5), -0.008, PITCH_Z), c)

	# linhas
	var line_col := Color("#e8f2e8")
	var line_d := 30.0
	_mesh_box(Vector3(0.14, 0.012, line_d), Vector3(0.0, 0.0, 0.0), line_col)
	_mesh_box(Vector3(0.14, 0.012, line_d), Vector3(-Cfg.FIELD_HALF, 0.0, 0.0), line_col)
	_mesh_box(Vector3(0.14, 0.012, line_d), Vector3(Cfg.FIELD_HALF, 0.0, 0.0), line_col)


# --------------------------------------------------------------------- gols

func _build_goal(side: float) -> void:
	var gx := Cfg.FIELD_HALF * side
	var h := Cfg.GOAL_H
	var post := 0.14
	var white := Color("#f8fafc")

	# traves e travessão (com colisão: bola bate na trave!)
	for z in [-Cfg.GOAL_HALF_W, Cfg.GOAL_HALF_W]:
		_solid_box(Vector3(post, h, post), Vector3(gx, h * 0.5, z))
		_mesh_box(Vector3(post, h, post), Vector3(gx, h * 0.5, z), white)
	_solid_box(Vector3(post, post, Cfg.GOAL_HALF_W * 2.0 + post), Vector3(gx, h, 0.0))
	_mesh_box(Vector3(post, post, Cfg.GOAL_HALF_W * 2.0 + post), Vector3(gx, h, 0.0), white)

	# rede translúcida
	var net_mat := StandardMaterial3D.new()
	net_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.3)
	net_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	net_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	net_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var net_x := gx + side * Cfg.GOAL_DEPTH
	var back := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.04, h, Cfg.GOAL_HALF_W * 2.0)
	back.mesh = bm
	back.material_override = net_mat
	back.position = Vector3(net_x, h * 0.5, 0.0)
	add_child(back)

	var roof := MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(Cfg.GOAL_DEPTH, 0.04, Cfg.GOAL_HALF_W * 2.0)
	roof.mesh = rm
	roof.material_override = net_mat
	roof.position = Vector3(gx + side * Cfg.GOAL_DEPTH * 0.5, h, 0.0)
	add_child(roof)


# -------------------------------------------------------------- arquibancada

func _build_stands() -> void:
	var seat_colors := [Color("#243449"), Color("#2b3d55"), Color("#20304a")]
	for i in 3:
		var z := -13.2 - float(i) * 1.7
		var y := 0.3 + float(i) * 1.3
		_mesh_box(Vector3(PITCH_W, 1.3, 1.7), Vector3(0.0, y, z), seat_colors[i])

	# torcida
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var person := BoxMesh.new()
	person.size = Vector3(0.26, 0.46, 0.26)
	mm.mesh = person

	var rows := 3
	var per_row := 140
	mm.instance_count = rows * per_row

	var palette := [
		Color("#6b7a8f"), Color("#8a94a6"), Color("#9aa5b5"), Color("#8c6262"),
		Color("#64789b"), Color("#a39d78"), Color("#71907f"), Color("#8a7a99"),
	]
	var idx := 0
	for r in rows:
		var z := -13.2 - float(r) * 1.7 + 0.12
		var y := 0.3 + float(r) * 1.3 + 0.9
		for j in per_row:
			var x := randf_range(-PITCH_W * 0.46, PITCH_W * 0.46)
			var sc := Vector3(1.0, randf_range(0.85, 1.2), 1.0)
			mm.set_instance_transform(idx, Transform3D(Basis.IDENTITY.scaled(sc), Vector3(x, y, z)))
			mm.set_instance_color(idx, palette[randi() % palette.size()])
			idx += 1

	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var crowd_mat := StandardMaterial3D.new()
	crowd_mat.vertex_color_use_as_albedo = true
	crowd_mat.roughness = 1.0
	mmi.material_override = crowd_mat
	add_child(mmi)

	# placas de publicidade
	var ads := [
		Color("#1e3a8a"), Color("#92400e"), Color("#115e59"),
		Color("#5b21b6"), Color("#9f1239"),
	]
	var board_w := 3.2
	var x := -PITCH_W * 0.5 + board_w * 0.5
	var k := 0
	while x < PITCH_W * 0.5 - board_w * 0.5:
		_mesh_box(Vector3(board_w - 0.22, 0.75, 0.12), Vector3(x, 0.48, -12.4), ads[k % ads.size()])
		# faixa branca no topo da placa
		_mesh_box(Vector3(board_w - 0.34, 0.14, 0.02), Vector3(x, 0.74, -12.33), Color("#cfd8e3"))
		x += board_w
		k += 1


func _build_masts() -> void:
	for sx in [-1.0, 1.0]:
		var x: float = 14.5 * float(sx)
		_mesh_box(Vector3(0.22, 5.5, 0.22), Vector3(x, 2.75, -17.5), Color("#334155"))
		_mesh_box(Vector3(1.6, 0.3, 0.5), Vector3(x, 5.5, -17.5), Color("#475569"))
		_mesh_box(Vector3(1.3, 0.12, 0.35), Vector3(x, 5.35, -17.5), Color("#fef9c3"))


func _build_lights() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -35.0, 0.0)
	sun.light_energy = 1.1
	sun.light_color = Color("#fff4dc")
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	add_child(sun)
