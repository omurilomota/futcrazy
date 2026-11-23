class_name Player
extends RigidBody3D

## Jogador de física livre (estilo Gang Beasts simplificado):
## o corpo é um RigidBody3D controlado por velocidade + torque, então
## empurrões, tombos e cambaleios saem de graça da simulação.
##
## Modificadores de evento entram por add_modifier(id, {...}) e são
## multiplicativos — assim dois eventos ao mesmo tempo não brigam.

const BASE_RADIUS := 0.42
const BASE_TORSO_H := 1.0
const BASE_LEG_LEN := 0.5
const BASE_MASS := 10.0

const BASE_SPEED := 7.2
const JUMP_SPEED := 9.6
const KICK_CD := 0.30
const KICK_RANGE := 1.55
const KICK_POWER := 9.0
const KICK_LIFT := 0.5
const TACKLE_CD := 0.85
const TACKLE_SPEED := 13.0
const TACKLE_WINDOW := 0.28
const SHOVE_IMPULSE := 70.0

const UPRIGHT_K := 120.0
const UPRIGHT_C := 14.0

var game: Node
var team := 0
var is_human := false
var brain: BotBrain

var color_body := Color("#3b82f6")
var goal_dir := 1.0
var facing := 1.0

## Papel no time: "field" (linha) ou "gk" (goleiro, só no campo todo).
var role := "field"
var home_x := 0.0
var marker: MeshInstance3D
var cap: MeshInstance3D
var _marker_y := 1.0

## Teclas deste jogador: mapas ação -> lista de Key. Trocado pelo game.gd conforme o modo.
var keys: Dictionary = {
	"left": [KEY_A, KEY_LEFT],
	"right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_W, KEY_UP],
	"kick": [KEY_SPACE],
	"tackle": [KEY_SHIFT, KEY_J],
}

var modifiers: Dictionary = {}

# comandos (escritos pelo teclado ou pelo BotBrain)
var input_move := 0.0
var want_jump := false
var want_kick := false
var want_tackle := false

# estado de ação
var grounded := false
var stun_left := 0.0
var kick_cd_left := 0.0
var tackle_cd_left := 0.0
var tackle_window := 0.0
var kick_anim := 0.0
var brawl_punch := false

var _built := false
var _cur_h := 0.0
var _cur_r := BASE_RADIUS
var _prev_vy := 0.0
var _jump_latch := false
var _squash := 0.0
var _run_phase := 0.0
var _tilt_time := 0.0
var _flail_t := 0.0

var rig: Node3D
var torso_mesh: MeshInstance3D
var shorts_mesh: MeshInstance3D
var head_root: Node3D
var leg_l: Node3D
var leg_r: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_mesh_l: MeshInstance3D
var leg_mesh_r: MeshInstance3D
var foot_l: MeshInstance3D
var foot_r: MeshInstance3D
var arm_mesh_l: MeshInstance3D
var arm_mesh_r: MeshInstance3D

var body_shape: CollisionShape3D
var body_box: BoxShape3D
var head_shape: CollisionShape3D
var head_sphere: SphereShape3D


func setup(g: Node, team_id: int, human: bool, role_name := "field") -> void:
	game = g
	team = team_id
	is_human = human
	role = role_name
	color_body = Cfg.TEAM_A_COLOR if team_id == 0 else Cfg.TEAM_B_COLOR
	goal_dir = 1.0 if team_id == 0 else -1.0
	facing = goal_dir

	mass = BASE_MASS
	gravity_scale = 1.0
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 4
	axis_lock_linear_z = true
	axis_lock_angular_x = true
	axis_lock_angular_y = true
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.05
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp = 1.2
	collision_layer = 2
	collision_mask = 1 | 2 | 4

	_build_nodes()
	_build_visuals()
	_build_marker()
	_rebuild()
	_built = true

	if not is_human:
		brain = BotBrain.new(role, home_x)


# ---------------------------------------------------------------- construção

func _build_nodes() -> void:
	# caixa em vez de cápsula: base plana = o boneco fica de pé,
	# mas ainda tomba e quica de forma convincente nas pancadas
	body_box = BoxShape3D.new()
	body_box.size = Vector3(BASE_RADIUS * 1.8, BASE_TORSO_H + BASE_LEG_LEN, BASE_RADIUS * 1.25)
	body_shape = CollisionShape3D.new()
	body_shape.shape = body_box
	add_child(body_shape)

	head_sphere = SphereShape3D.new()
	head_sphere.radius = 0.28
	head_shape = CollisionShape3D.new()
	head_shape.shape = head_sphere
	add_child(head_shape)

	rig = Node3D.new()
	add_child(rig)


func _mat(color: Color, rough := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m


func _build_visuals() -> void:
	torso_mesh = MeshInstance3D.new()
	torso_mesh.material_override = _mat(color_body)
	rig.add_child(torso_mesh)

	shorts_mesh = MeshInstance3D.new()
	shorts_mesh.material_override = _mat(color_body.darkened(0.5))
	rig.add_child(shorts_mesh)

	# cabeça (escala aplicada no pai para "cabeção")
	head_root = Node3D.new()
	rig.add_child(head_root)

	var head_mesh := MeshInstance3D.new()
	var hs := SphereMesh.new()
	hs.radius = 0.30
	hs.height = 0.60
	hs.radial_segments = 14
	hs.rings = 8
	head_mesh.mesh = hs
	head_mesh.material_override = _mat(Color("#f6c89f"))
	head_root.add_child(head_mesh)

	var eye_mat := _mat(Color("#171717"), 0.35)
	for sx in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var es := SphereMesh.new()
		es.radius = 0.055
		es.height = 0.11
		es.radial_segments = 8
		es.rings = 4
		eye.mesh = es
		eye.position = Vector3(0.105 * sx, 0.045, 0.245)
		eye.material_override = eye_mat
		head_root.add_child(eye)

	var nose := MeshInstance3D.new()
	var ns := SphereMesh.new()
	ns.radius = 0.055
	ns.height = 0.11
	ns.radial_segments = 8
	ns.rings = 4
	nose.mesh = ns
	nose.position = Vector3(0.0, -0.02, 0.285)
	nose.material_override = _mat(Color("#e0a87e"))
	head_root.add_child(nose)

	# cabelo (tampa baixa e escura)
	var hair := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.305
	hm.height = 0.61
	hm.radial_segments = 14
	hm.rings = 6
	hair.mesh = hm
	hair.position = Vector3(0.0, 0.06, -0.02)
	hair.scale = Vector3(1.02, 0.62, 1.02)
	hair.material_override = _mat(Color("#2b2b33"))
	head_root.add_child(hair)

	# boné do goleiro (aparece só quando role == "gk")
	cap = MeshInstance3D.new()
	var capm := BoxMesh.new()
	capm.size = Vector3(0.42, 0.10, 0.42)
	cap.mesh = capm
	cap.position = Vector3(0.0, 0.25, 0.04)
	cap.material_override = _mat(Color("#facc15"), 0.6)
	cap.visible = false
	head_root.add_child(cap)

	# pernas
	leg_l = Node3D.new()
	leg_r = Node3D.new()
	rig.add_child(leg_l)
	rig.add_child(leg_r)
	leg_mesh_l = MeshInstance3D.new()
	leg_mesh_r = MeshInstance3D.new()
	leg_mesh_l.material_override = _mat(Color("#f6c89f"))
	leg_mesh_r.material_override = _mat(Color("#f6c89f"))
	leg_l.add_child(leg_mesh_l)
	leg_r.add_child(leg_mesh_r)

	foot_l = MeshInstance3D.new()
	foot_r = MeshInstance3D.new()
	foot_l.material_override = _mat(Color("#111827"))
	foot_r.material_override = _mat(Color("#111827"))
	leg_l.add_child(foot_l)
	leg_r.add_child(foot_r)

	# braços
	arm_l = Node3D.new()
	arm_r = Node3D.new()
	rig.add_child(arm_l)
	rig.add_child(arm_r)
	arm_mesh_l = MeshInstance3D.new()
	arm_mesh_r = MeshInstance3D.new()
	arm_mesh_l.material_override = _mat(color_body.darkened(0.12))
	arm_mesh_r.material_override = _mat(color_body.darkened(0.12))
	arm_l.add_child(arm_mesh_l)
	arm_r.add_child(arm_mesh_r)

	var hand_mat := _mat(Color("#f6c89f"))
	for pivot in [arm_l, arm_r]:
		var hand := MeshInstance3D.new()
		var hsm := SphereMesh.new()
		hsm.radius = 0.10
		hsm.height = 0.20
		hsm.radial_segments = 8
		hsm.rings = 4
		hand.mesh = hsm
		hand.material_override = hand_mat
		pivot.add_child(hand)
		hand.name = "Hand"


# ------------------------------------------------------------------ medidas

func get_stat(key: String, default_value := 1.0) -> float:
	var v := default_value
	for id in modifiers:
		var m: Dictionary = modifiers[id]
		if m.has(key):
			v *= float(m[key])
	return v


func add_modifier(id: String, mod: Dictionary) -> void:
	modifiers[id] = mod
	_rebuild()


func remove_modifier(id: String) -> void:
	modifiers.erase(id)
	_rebuild()


func has_modifier(id: String) -> bool:
	return modifiers.has(id)


func body_radius() -> float:
	return _cur_r


func height() -> float:
	return _cur_h


func is_grounded() -> bool:
	return grounded


func _rebuild() -> void:
	if torso_mesh == null:
		return

	var size := get_stat("size")
	var head_s := get_stat("head")
	var leg_mult := get_stat("leg_len")

	var r: float = BASE_RADIUS * size
	var torso_h: float = BASE_TORSO_H * size
	var leg_len: float = BASE_LEG_LEN * size * leg_mult
	var h: float = maxf(torso_h + leg_len, r * 2.0 + 0.1)

	# crescer mantendo os pés no chão (o corpo é centrado na origem)
	if _built and absf(h - _cur_h) > 0.001:
		global_position.y += (h - _cur_h) * 0.5

	_cur_h = h
	_cur_r = r
	body_box.size = Vector3(r * 1.8, h, r * 1.25)
	# centro de massa baixo: fica de pé como um joão-bobo, mas ainda tomba
	center_of_mass = Vector3(0.0, -h * 0.25, 0.0)
	mass = BASE_MASS * size * size
	body_shape.position = Vector3.ZERO

	var half := h * 0.5
	var hip_y := -half + leg_len

	# torso
	var tm := CapsuleMesh.new()
	tm.radius = r * 0.99
	tm.height = maxf(torso_h + r * 0.3, r * 2.0 + 0.02)
	tm.radial_segments = 12
	tm.rings = 4
	torso_mesh.mesh = tm
	torso_mesh.position = Vector3(0.0, hip_y + torso_h * 0.5, 0.0)

	# short
	var sm := CylinderMesh.new()
	sm.top_radius = r * 0.97
	sm.bottom_radius = r * 0.8
	sm.height = 0.26 * size
	sm.radial_segments = 12
	shorts_mesh.mesh = sm
	shorts_mesh.position = Vector3(0.0, hip_y + 0.13 * size, 0.0)

	# cabeça
	var head_r: float = 0.30 * head_s * size
	head_root.scale = Vector3.ONE * (head_s * size)
	head_root.position = Vector3(0.0, half + head_r * 0.5, 0.0)
	head_sphere.radius = maxf(head_r * 0.9, 0.05)
	head_shape.position = head_root.position

	# pernas
	var leg_radius: float = clampf(r * 0.32, 0.05, 0.6)
	var lm := CapsuleMesh.new()
	lm.radius = leg_radius
	lm.height = maxf(leg_len, leg_radius * 2.0 + 0.01)
	lm.radial_segments = 8
	lm.rings = 3
	for mi in [leg_mesh_l, leg_mesh_r]:
		mi.mesh = lm
		mi.position = Vector3(0.0, -leg_len * 0.5, 0.0)
	leg_l.position = Vector3(-r * 0.5, hip_y, 0.0)
	leg_r.position = Vector3(r * 0.5, hip_y, 0.0)

	var foot_size := Vector3(leg_radius * 2.2, 0.1 * size, leg_radius * 3.4)
	var fm := BoxMesh.new()
	fm.size = foot_size
	for foot in [foot_l, foot_r]:
		foot.mesh = fm
		foot.position = Vector3(0.0, -leg_len + foot_size.y * 0.5, leg_radius * 0.8)

	# braços
	var arm_len: float = 0.6 * size
	var arm_radius: float = clampf(r * 0.2, 0.04, 0.4)
	var am := CapsuleMesh.new()
	am.radius = arm_radius
	am.height = maxf(arm_len, arm_radius * 2.0 + 0.01)
	am.radial_segments = 8
	am.rings = 3
	for mi in [arm_mesh_l, arm_mesh_r]:
		mi.mesh = am
		mi.position = Vector3(0.0, -arm_len * 0.5, 0.0)
	arm_l.position = Vector3(-(r * 0.95 + 0.02), half - 0.22 * size, 0.0)
	arm_r.position = Vector3(r * 0.95 + 0.02, half - 0.22 * size, 0.0)
	for pivot in [arm_l, arm_r]:
		var hand := pivot.get_node_or_null("Hand") as Node3D
		if hand != null:
			hand.position = Vector3(0.0, -arm_len, 0.0)
			hand.scale = Vector3.ONE * size * 1.1

	if cap != null:
		cap.visible = role == "gk"
	_marker_y = half + head_r * 2.0 + 0.65
	if marker != null:
		marker.position = Vector3(0.0, _marker_y, 0.0)


# ---------------------------------------------------------------- loop físico

func _physics_process(delta: float) -> void:
	if not _built or freeze:
		return

	kick_cd_left = maxf(0.0, kick_cd_left - delta)
	tackle_cd_left = maxf(0.0, tackle_cd_left - delta)
	tackle_window = maxf(0.0, tackle_window - delta)
	kick_anim = maxf(0.0, kick_anim - delta * 4.5)

	var vy := linear_velocity.y
	var was_grounded := grounded
	_update_grounded()
	_prev_vy = vy

	# aterrissagem: squash + tropeço em queda feia
	if grounded and not was_grounded and _prev_vy < -6.0:
		_squash = 0.2
		if _prev_vy < -13.0:
			stun(0.3)
		if game != null and game.has_method("spawn_dust"):
			game.spawn_dust(global_position + Vector3(0.0, -_cur_h * 0.5 + 0.06, 0.0), Color("#dbe7cf"), clampf(-_prev_vy * 0.9, 5.0, 16.0), clampf(-_prev_vy * 0.06, 0.7, 1.4))

	_read_input(delta)

	if stun_left > 0.0:
		stun_left = maxf(0.0, stun_left - delta)
		_flail(delta)
		_animate(delta)
		if stun_left <= 0.0:
			_stand_up()
		return

	if game != null and game.match_state == "play":
		_move(delta)
		_act()
		_check_hits()
	_balance(delta)
	_bounce_if_trampoline()
	_animate(delta)


func _update_grounded() -> void:
	var space := get_world_3d().direct_space_state
	var from := global_position
	var to := from + Vector3(0.0, -(_cur_h * 0.5 + 0.14), 0.0)
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	grounded = not hit.is_empty()


func _read_input(delta: float) -> void:
	input_move = 0.0
	want_jump = false
	want_kick = false
	want_tackle = false

	if brain != null:
		brain.think(self, game.ball if game != null else null, delta)
		return
	if not is_human:
		return

	if _key_down(keys.get("left", [])):
		input_move -= 1.0
	if _key_down(keys.get("right", [])):
		input_move += 1.0
	want_jump = _key_down(keys.get("jump", []))
	want_kick = _key_down(keys.get("kick", []))
	want_tackle = _key_down(keys.get("tackle", []))


func _key_down(list: Array) -> bool:
	for k in list:
		if Input.is_physical_key_pressed(k):
			return true
	return false


func _move(delta: float) -> void:
	var speed: float = BASE_SPEED * get_stat("speed")
	var steer := get_stat("steer")
	var target := input_move * speed
	var accel := (62.0 if grounded else 18.0) * steer

	var v := linear_velocity
	v.x = move_toward(v.x, target, accel * delta)
	linear_velocity = v

	if absf(input_move) > 0.1:
		facing = signf(input_move)
		if grounded:
			# inclina o corpo na direção da corrida: cambaleio de graça
			apply_torque(Vector3(0.0, 0.0, -input_move * 2.6 * get_stat("wobble")))

	if want_jump and grounded and not _jump_latch:
		v = linear_velocity
		v.y = JUMP_SPEED * get_stat("jump")
		linear_velocity = v
		_jump_latch = true
		_squash = -0.2
	elif not want_jump:
		_jump_latch = false


func _act() -> void:
	if want_kick:
		_kick()
	if want_tackle:
		_tackle()


func _kick() -> void:
	if kick_cd_left > 0.0 or game == null or game.ball == null:
		return
	kick_cd_left = KICK_CD * get_stat("kick_cd")
	kick_anim = 1.0
	_squash = 0.1

	var ball: Ball = game.ball
	var to := ball.global_position - global_position
	var reach: float = KICK_RANGE * get_stat("kick_range") + Cfg.BALL_RADIUS + _cur_r * 0.5
	if to.length() > reach:
		if game.has_method("on_whiff"):
			game.on_whiff(self)
		return

	var dir_x := facing
	if role == "gk":
		dir_x = goal_dir
	elif absf(to.x) > 0.12:
		dir_x = signf(to.x)
	var direction := Vector3(dir_x, 0.0, 0.0)
	var power: float = KICK_POWER * get_stat("kick_power")
	ball.apply_central_impulse(direction * power + Vector3.UP * power * KICK_LIFT)
	ball.squash(0.35)
	# recuo: chutar forte desequilibra quem chutou
	apply_central_impulse(-direction * power * 0.16)
	if game.has_method("on_kick"):
		game.on_kick(self, power)


func _tackle() -> void:
	if tackle_cd_left > 0.0:
		return
	tackle_cd_left = TACKLE_CD
	tackle_window = TACKLE_WINDOW

	if game != null and game.has_method("spawn_dust"):
		game.spawn_dust(global_position + Vector3(-facing * 0.45, -_cur_h * 0.5 + 0.08, 0.0), Color("#dbe7cf"), 7.0, 1.1)

	var v := linear_velocity
	v.x = facing * TACKLE_SPEED * get_stat("speed")
	linear_velocity = v
	apply_torque(Vector3(0.0, 0.0, -facing * 35.0))
	_squash = 0.14
	if game.has_method("on_tackle"):
		game.on_tackle(self)


func _check_hits() -> void:
	if tackle_window <= 0.0 or game == null:
		return
	var in_brawl: bool = game.brawl
	for other in game.players:
		if other == null or other == self:
			continue
		var other_player: Player = other
		if other_player.team == team and not in_brawl:
			continue
		var d := global_position.distance_to(other_player.global_position)
		var reach: float = 1.35 * get_stat("size") + other_player.body_radius()
		if d > reach:
			continue

		var dir := other_player.global_position - global_position
		dir.z = 0.0
		if dir.length() < 0.05:
			dir = Vector3(facing, 0.0, 0.0)
		dir = dir.normalized()
		dir.y = maxf(dir.y, 0.2)

		var power: float = SHOVE_IMPULSE * get_stat("kick_power") * (2.0 if in_brawl else 1.0)
		other_player.apply_central_impulse(dir * power)
		other_player.stun(1.2 if in_brawl else 0.7)
		tackle_window = 0.0
		_squash = 0.18
		if game.has_method("on_hit"):
			game.on_hit(self, other_player, power)
		return


func _balance(delta: float) -> void:
	if not grounded:
		_tilt_time = 0.0
		# no ar o giro é amortecido: quedas engraçadas, mas não impossíveis
		apply_torque(Vector3(0.0, 0.0, -angular_velocity.z * 4.0))
		return
	var up := global_transform.basis.y
	var tilt := atan2(up.x, up.y)
	apply_torque(Vector3(0.0, 0.0, -tilt * UPRIGHT_K - angular_velocity.z * UPRIGHT_C))
	if absf(tilt) > 0.9:
		_tilt_time += delta
		if _tilt_time > 0.5:
			_stand_up()
	else:
		_tilt_time = 0.0


func _flail(delta: float) -> void:
	_flail_t += delta
	if _flail_t > 0.1:
		_flail_t = 0.0
		apply_torque(Vector3(0.0, 0.0, randf_range(-45.0, 45.0)))


func _stand_up() -> void:
	var e := global_rotation
	global_rotation = Vector3(0.0, e.y, 0.0)
	angular_velocity = Vector3.ZERO
	var v := linear_velocity
	v.y = maxf(v.y, 4.2)
	linear_velocity = v
	_squash = -0.18
	_tilt_time = 0.0


func _bounce_if_trampoline() -> void:
	if game == null or not game.trampoline:
		return
	if grounded and linear_velocity.y <= 0.5:
		var v := linear_velocity
		v.y = 12.5
		linear_velocity = v
		_squash = -0.25
		if game.has_method("sfx_play"):
			game.sfx_play("bounce", -12.0, 1.6)


func stun(seconds: float) -> void:
	stun_left = maxf(stun_left, seconds)
	_flail_t = 0.0


func is_gk() -> bool:
	return role == "gk"


## Seta a seta flutuante do jogador controlado (modo campo todo).
func set_marked(v: bool) -> void:
	if marker != null:
		marker.visible = v


func _build_marker() -> void:
	marker = MeshInstance3D.new()
	marker.name = "Marker"
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.17
	cm.height = 0.30
	cm.radial_segments = 4
	marker.mesh = cm
	marker.rotation.z = PI
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("#fde68a")
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker.material_override = m
	marker.visible = false
	add_child(marker)


func _animate(delta: float) -> void:
	if rig == null:
		return

	var spd: float = clampf(absf(linear_velocity.x) / BASE_SPEED, 0.0, 1.8)
	if grounded and spd > 0.05:
		_run_phase += delta * (4.0 + 9.0 * spd)
	var amp := (0.75 * spd) if grounded else 0.22
	var s := sin(_run_phase)

	if stun_left > 0.0:
		s = sin(_run_phase * 4.0)
		amp = 0.95
		# braços pra cima no desespero
		arm_l.rotation.z = 2.2 + s * 0.4
		arm_r.rotation.z = -2.2 - s * 0.4
	else:
		arm_l.rotation.z = 0.3 - s * amp * 0.9
		arm_r.rotation.z = -0.3 + s * amp * 0.9

	var kick := kick_anim * kick_anim
	leg_l.rotation.z = s * amp
	leg_r.rotation.z = -s * amp + facing * kick * 1.4

	var sq := clampf(_squash, -0.35, 0.35)
	rig.scale = Vector3(1.0 + sq, 1.0 - sq * 1.2, 1.0 + sq)
	if absf(_squash) > 0.01:
		_squash = move_toward(_squash, 0.0, delta * 2.6)

	if marker != null and marker.visible:
		marker.rotation.y += delta * 2.2
		marker.position.y = _marker_y + sin(Time.get_ticks_msec() * 0.004) * 0.07
