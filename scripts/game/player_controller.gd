class_name PlayerController
extends Node3D
## The local player's input, camera and first-person presentation.

enum State { WAITING, DEPLOY, ALIVE, DEAD, ENDED }

const STATE_RATE := 1.0 / 30.0
## Seconds on the body before the view moves over to a living team mate.

## How far a tank's crosshair reaches, and how close a soldier must be to the line to catch it.
const AIM_REACH := 240.0
const AIM_ASSIST_RADIUS := 1.4

var world: World
var soldier: Soldier
var camera := Camera3D.new()
var vm := ViewModel.new()
var state: int = State.WAITING
var input_blocked := false
## The leader is looking through binoculars, picking where artillery lands.
var designating := false
var picker_open := false
var build_kind := -1

var bloom := 0.0
var scoped := false
var thermal := false
var _spin := 0.0
## The sprint key was still held when stamina ran out.
var _sprint_spent := false
## Looking through a sight with the rocket launcher's frame round it, with or without thermal.
var sighted := false
var launcher_heat := true
var tank_heat := false

var _state_t := 0.0
var _eye := C.STAND_EYE
var _recoil_pitch := 0.0
var _last_shot := -9.0
var _hum_yaw := 0.0
var _hum_swing := 0.0
var _shot_i := 0
var _shake := 0.0
var _step_acc := 0.0
var _was_on_floor := true
var _fall_speed := 0.0
var _land_dip := 0.0
var _death_t := 0.0
var _killer: Soldier = null
var _pending_swing := -1.0
var _pending_throw := -1.0
var _throw_kind := C.NADE_FRAG
var _orbit := 0.0
var _spawned_this_life := false
## F on a gun: the slot to go back to once the quick cut is over, and how long until then.
var _melee_back := -1
var _melee_back_t := 0.0
var _vm_ready := false


func _ready() -> void:
	camera.top_level = true
	camera.near = 0.06
	camera.far = 2600.0
	camera.fov = Settings.fov
	add_child(camera)
	camera.current = true
	camera.add_child(vm)
	vm.visible = false


func attach(s: Soldier) -> void:
	soldier = s
	vm.setup(s.team)
	# Compiles the first-person materials now, not in the moment the player deploys.
	vm.set_weapon(C.cls(s.team, 0)["weapons"][0])
	_vm_ready = true
	state = State.DEPLOY
	world.hud.show_deploy(0.0)


func on_spawned() -> void:
	build_kind = -1
	_melee_back = -1
	state = State.ALIVE
	_death_t = 0.0
	_eye = C.STAND_EYE
	_recoil_pitch = 0.0
	bloom = 0.0
	scoped = false
	vm.ads = 0.0
	vm.visible = true
	vm.weapon_id = -1
	vm.set_weapon(soldier.weapon_id(), soldier.weapon_parts())
	world.hud.hide_deploy()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Sfx.play("spawn", -6.0)


## The class changed in the field, into or out of a super class.
func on_transformed(vehicle_change: bool) -> void:
	picker_open = false
	_melee_back = -1
	bloom = 0.0
	scoped = false
	vm.ads = 0.0
	vm.cancel_reload()
	vm.weapon_id = -1
	vm.set_weapon(soldier.weapon_id(), soldier.weapon_parts())
	if vehicle_change:
		return
	if soldier.is_super():
		world.hud.banner(String(soldier.class_data()["name"]).to_upper(), T.t("Masz %d sekund") % int(soldier.super_t), UiKit.BRASS)
	else:
		world.hud.big_message("SUPERKLASA WYGASŁA", UiKit.MUTED)


func on_died(killer: Soldier, weapon_id: int) -> void:
	state = State.DEAD
	picker_open = false
	_killer = killer
	_death_t = 0.0
	vm.visible = false
	scoped = false
	soldier.aiming = false
	world.hud.on_local_death(killer, weapon_id)


func on_round_end() -> void:
	state = State.ENDED
	vm.visible = false
	scoped = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func on_round_start() -> void:
	vm.visible = false
	if soldier:
		state = State.DEPLOY
		world.hud.show_deploy(0.0)


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		world.hud.toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if state != State.ALIVE or input_blocked:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		var sens := Settings.sensitivity * 0.0022
		if soldier.aiming:
			sens *= Settings.ads_sensitivity * (camera.fov / Settings.fov)
		soldier.yaw -= motion.relative.x * sens
		var y := motion.relative.y * sens
		soldier.pitch = clampf(soldier.pitch + (y if Settings.invert_y else -y), -1.5, 1.5)
		if soldier.on_roof_gun():
			soldier.pitch = clampf(soldier.pitch, C.TANK_GUNNER_PITCH_MIN, C.TANK_GUNNER_PITCH_MAX)
		vm.add_sway(motion.relative)


func _physics_process(delta: float) -> void:
	if state != State.ALIVE or soldier == null or not soldier.alive:
		return
	var s := soldier
	if input_blocked:
		s.wish = Vector3.ZERO
		s.want_sprint = false
		s.aiming = false
		_send_state(delta)
		return
	if s.riding >= 0:
		if Input.is_action_just_pressed("use"):
			Net.send_use()
		if Input.is_action_just_pressed("seat"):
			Net.send_switch_seat()
		s.aiming = false
		_send_state(delta)
		return

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var yaw_basis := Basis(Vector3.UP, s.yaw)
	s.wish = (yaw_basis * Vector3(input.x, 0.0, input.y))
	s.drive = Vector2(input.x, -input.y)
	if s.class_data().get("builder", false):
		if Input.is_action_just_pressed("build_menu"):
			build_kind = build_kind + 1 if build_kind < Fortifications.DEFS.size() - 1 else -1
		if build_kind >= 0 and Input.is_action_just_pressed("build"):
			Net.send_build(build_kind, world.forts.candidate(s), s.yaw)
	else:
		build_kind = -1
	_tick_command(s)
	if Input.is_action_just_pressed("use"):
		Net.send_use()
	if Input.is_action_just_pressed("seat") and s.is_vehicle():
		Net.send_switch_seat()
	if Input.is_action_just_pressed("thermal"):
		_toggle_thermal(s)
	if s.wish.length_squared() > 1.0:
		s.wish = s.wish.normalized()
	var firing := Input.is_action_pressed("fire")
	# Run dry and the sprint key does nothing more until it is let go: holding it on does not
	# keep trying to run, so the legs walk steadily instead of lurching every time a little comes back.
	if s.exhausted and Input.is_action_pressed("sprint"):
		_sprint_spent = true
	elif not Input.is_action_pressed("sprint"):
		_sprint_spent = false
	s.want_sprint = Input.is_action_pressed("sprint") and input.y < -0.1 and not firing and not _sprint_spent
	s.want_crouch = Input.is_action_pressed("crouch")
	if Input.is_action_just_pressed("prone"):
		s.want_prone = not s.want_prone
	# Getting up: any of these beats lying still.
	if s.want_prone and (s.want_crouch or Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("sprint")):
		s.want_prone = false
		s.want_jump = false
	if Input.is_action_just_pressed("jump") and not s.prone:
		s.want_jump = true
	s.want_fly = Input.is_action_pressed("jump")

	if Input.is_action_just_pressed("super") and s.coins > 0 and not s.is_super():
		picker_open = not picker_open
	if picker_open and (s.coins <= 0 or s.is_super()):
		picker_open = false
	for i in 4:
		if Input.is_action_just_pressed("slot%d" % (i + 1)):
			if not picker_open:
				_melee_back = -1
				_switch(i)
			elif i < 2:
				picker_open = false
				Net.send_transform(C.SUPER_MECH + i)

	var aim_held := Input.is_action_pressed("aim")
	if s.is_melee():
		s.aiming = false
		s.blocking = aim_held and s.stamina > 0.3
	else:
		s.blocking = false
		s.aiming = aim_held and s.reload_t <= 0.0 and not s.sprinting and s.switch_t <= 0.0 and not designating

	if Input.is_action_just_pressed("melee"):
		if s.melee_slot() >= 0:
			if not s.is_melee():
				_melee_back = s.slot
				_switch(s.melee_slot())
			s.switch_t = 0.0
			_swing()
			# One cut and the gun comes back, unless the sword is what the player was holding.
			if _melee_back >= 0:
				_melee_back_t = float(s.weapon()["rate"]) + 0.12
	elif Input.is_action_just_pressed("reload") and s.can_reload() and _pending_throw < 0.0:
		_reload()
	elif Input.is_action_just_pressed("grenade"):
		_throw_grenade()
	elif Input.is_action_just_pressed("grenade_next"):
		s.pick_next_nade()
		Sfx.play("ui_click", -8.0)
	elif not designating:
		_try_attack()

	if _pending_throw >= 0.0:
		_pending_throw -= delta
		if _pending_throw < 0.0:
			_release_grenade()
	if _pending_swing >= 0.0:
		_pending_swing -= delta
		if _pending_swing < 0.0:
			Net.send_swing(s.aim_direction(), _view_time())
	if _melee_back >= 0:
		_melee_back_t -= delta
		if _melee_back_t <= 0.0 and _pending_swing < 0.0:
			if s.is_melee():
				_switch(_melee_back)
			_melee_back = -1

	bloom = move_toward(bloom, 0.0, delta * 4.5)
	# After a burst the muzzle settles back, though never quite to where it began.
	var since_shot := Time.get_ticks_msec() / 1000.0 - _last_shot
	if since_shot > 0.13 and _recoil_pitch > 0.0:
		var settle := minf(_recoil_pitch, delta * 0.55)
		_recoil_pitch -= settle
		s.pitch = clampf(s.pitch - settle * 0.7, -1.5, 1.5)
	_send_state(delta)
	_track_footsteps(delta)


## The squad leader's two orders: Z raises the binoculars, T drops the beacon.
func _tick_command(s: Soldier) -> void:
	var commanding: bool = s.class_data().get("command", false) and world.squads.leads(s) and not s.is_vehicle()
	if not commanding:
		designating = false
		return
	if Input.is_action_just_pressed("build"):
		Net.send_beacon()
	if Input.is_action_just_pressed("artillery"):
		designating = not designating
		Sfx.play("ui_click", -6.0)
	if not designating:
		return
	if Input.is_action_just_pressed("aim"):
		designating = false
	elif Input.is_action_just_pressed("fire"):
		var point := strike_point()
		var problem := world.squads.strike_problem(s, point)
		if problem == "":
			designating = false
			Net.send_strike(point)
		else:
			world.on_squad_notice(problem)


## Where the binoculars are looking, on the first solid thing along the line.
func strike_point() -> Vector3:
	var from := camera.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from - camera.global_transform.basis.z * (C.STRIKE_RANGE + 60.0), C.LAYER_WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return Vector3.INF if hit.is_empty() else hit["position"]


func _view_time() -> float:
	return Net.server_time() - (0.0 if Net.is_server() else Net.INTERP_DELAY)


func _send_state(delta: float) -> void:
	_state_t += delta
	if _state_t >= STATE_RATE:
		_state_t = 0.0
		Net.send_state(soldier.global_position, soldier.yaw, soldier.pitch, soldier.state_flags(), soldier.slot, soldier.hull_yaw)


func _switch(slot: int) -> void:
	var before := soldier.slot
	var before_weapon := soldier.weapon_id()
	soldier.switch_to(slot)
	if soldier.slot == before:
		return
	vm.cancel_reload()
	vm.set_weapon(soldier.weapon_id(), soldier.weapon_parts())
	if soldier.is_melee():
		Sfx.play("sword_on", -5.0)
	elif C.is_blade(before_weapon):
		Sfx.play("sword_off", -7.0)
	else:
		Sfx.play("reload_out", -10.0, 1.3)


func _try_attack() -> void:
	var s := soldier
	var w := s.weapon()
	if s.is_melee():
		if Input.is_action_pressed("fire") and s.can_swing():
			_swing()
		return
	var wants := Input.is_action_pressed("fire") if w["auto"] else Input.is_action_just_pressed("fire")
	# A minigun has to spin up first. While the trigger is held it stays up to speed.
	var spin: float = w.get("spin", 0.0)
	if spin > 0.0:
		# Bracing it with the right button spins the barrels up too, ready to fire at once.
		_spin = move_toward(_spin, 1.0 if wants or s.aiming else 0.0, get_physics_process_delta_time() / spin)
		vm.barrel_speed = _spin
		if _spin < 1.0:
			return
	else:
		_spin = 0.0
	if not wants:
		return
	if s.can_fire():
		_shoot()
	elif s.mags[s.slot] <= 0 and Input.is_action_just_pressed("fire"):
		if s.can_reload():
			_reload()
		else:
			Sfx.play("empty_click", -6.0)


func current_spread() -> float:
	var s := soldier
	if s == null or not s.alive:
		return 0.0
	var w := s.weapon()
	var base: float = lerpf(float(w["spread_hip"]), float(w["spread_ads"]), vm.ads)
	var speed := Vector2(s.velocity.x, s.velocity.z).length()
	var moving: float = clampf(speed / 5.0, 0.0, 1.5) * float(w["spread_move"]) * (1.0 - vm.ads * 0.75)
	if not s.is_on_floor():
		moving += 2.0
	var stance := 0.5 if s.prone else (0.7 if s.crouching else 1.0)
	return (base + moving + bloom) * stance


func _shoot() -> void:
	var s := soldier
	var w := s.weapon()
	s.consume_shot()
	var cone := deg_to_rad(current_spread())
	var aim := _aim_vector()
	var right := aim.cross(Vector3.UP).normalized()
	var up := right.cross(aim).normalized()
	var origin := s.eye_position()
	var quiet: bool = w["suppressed"]
	var muzzle := _muzzle_position()
	var dir := aim
	for i in int(w.get("pellets", 1)):
		if w.get("rocket", false) or s.weapon_id() == C.W.MECH_LAUNCHER:
			break
		var ang := randf() * TAU
		var off := sqrt(randf()) * cone
		dir = (aim + (right * cos(ang) + up * sin(ang)) * tan(off)).normalized()
		var max_d: float = w["range"]
		var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * max_d, C.LAYER_WORLD)
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		var end: Vector3 = origin + dir * max_d if hit.is_empty() else hit["position"]
		world.fx.spawn_shot(s.weapon_id(), s.team, muzzle, end, 0 if hit.is_empty() else 1, s.is_vehicle(), not s.is_vehicle())
	Sfx.play_own("laser_suppressed" if quiet else w["sound"], 0.5 if quiet else 1.5 + float(C.SHOT_BOOST.get(w["sound"], 0.0)), randf_range(0.97, 1.03))
	if s.is_gunner() and world.gunner_tank(s):
		world.gunner_tank(s).play_gunner_fire()
	Net.send_fire(s.slot, origin, aim if int(w.get("pellets", 1)) > 1 else dir, _view_time())
	_kick_recoil(w)
	if w.has("shake"):
		shake(float(w["shake"]))
	if s.mags[s.slot] <= 0 and s.can_reload():
		_reload()


## Each weapon has its own pattern: how hard it climbs, which way it drifts, how it wobbles.
func _kick_recoil(w: Dictionary) -> void:
	var s := soldier
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_shot > 0.3:
		_shot_i = 0
	_last_shot = now
	_shot_i += 1
	var recoil: float = float(w["recoil"]) * lerpf(1.0, 0.55, vm.ads)
	var climb: float = 1.0 + float(w["recoil_rise"]) * minf(_shot_i, 14.0)
	var kick := deg_to_rad(recoil * 0.42 * climb)
	var side := deg_to_rad((float(w["recoil_bias"]) + sin(_shot_i * 0.85) * float(w["recoil_h"])) * recoil * 0.32)
	s.pitch = clampf(s.pitch + kick, -1.5, 1.5)
	s.yaw -= side
	_recoil_pitch += kick
	bloom = minf(bloom + recoil * 0.3, 4.0)
	vm.kick(clampf(recoil * 0.35, 0.25, 1.2))


## A tank's camera sits behind the gun, so aim at whatever the crosshair is on.
func _aim_vector() -> Vector3:
	var s := soldier
	if not s.is_vehicle() and not s.is_mech():
		return s.aim_direction()
	var from := camera.global_position
	var forward := -camera.global_transform.basis.z
	var near := 3.0 if s.on_roof_gun() else (6.0 if s.is_mech() else 5.5)
	var q := PhysicsRayQueryParameters3D.create(from + forward * near, from + forward * AIM_REACH, C.LAYER_WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var reach := AIM_REACH if hit.is_empty() else from.distance_to(hit["position"])
	# Soldiers have no physics bodies for that ray to stop on, so they are checked by hand.
	for o: Soldier in world.soldiers.values():
		if o == s or not o.alive or not world.are_foes(s, o):
			continue
		var body := o.global_position + Vector3.UP * 1.1
		var along := (body - from).dot(forward)
		if along > near and along < reach and (from + forward * along).distance_to(body) < AIM_ASSIST_RADIUS:
			reach = along
	return (from + forward * reach - s.eye_position()).normalized()


func _muzzle_position() -> Vector3:
	if soldier.is_gunner():
		var mount := world.gunner_tank(soldier)
		return mount.gunner_muzzle() if mount else soldier.eye_position() + soldier.aim_direction() * 1.3
	if (soldier.is_vehicle() or soldier.is_mech()) and soldier.model:
		return soldier.model.muzzle_position()
	var tip := vm.gun.get_node_or_null("Muzzle") as Node3D if vm.gun else null
	if tip:
		# The gun is drawn with its own field of view, so the point on screen where the
		# muzzle appears is further out than its true position in the world.
		var at := camera.to_local(tip.global_position)
		var k := tan(deg_to_rad(camera.fov * 0.5)) / tan(deg_to_rad(31.0))
		return camera.to_global(Vector3(at.x * k, at.y * k, at.z))
	var b := camera.global_transform.basis
	var side := lerpf(0.2, 0.0, vm.ads)
	var drop := lerpf(0.16, 0.06, vm.ads)
	return camera.global_position + b * Vector3(side, -drop, -0.75)


func _reload() -> void:
	soldier.start_reload()
	vm.start_reload(float(soldier.weapon()["reload"]))
	Net.send_reload()
	Sfx.play("reload_out", -7.0)
	get_tree().create_timer(float(soldier.weapon()["reload"]) * 0.7, false).timeout.connect(_on_reload_sound)


func _on_reload_sound() -> void:
	if soldier and soldier.alive and soldier.reload_t > 0.0:
		Sfx.play("reload_in", -7.0)


func _swing() -> void:
	var s := soldier
	if not s.can_swing():
		return
	s.fire_cd = s.weapon()["rate"]
	vm.play_swing()
	Sfx.play("sword_swing", -3.0, randf_range(0.95, 1.08))
	# Lunge toward a nearby enemy under the crosshair, which makes the sword usable.
	var aim := s.aim_direction()
	var best := 0.86
	var lunge := false
	for o: Soldier in world.soldiers.values():
		if not o.alive or not world.are_foes(o, s):
			continue
		var to := o.global_position + Vector3.UP - s.eye_position()
		var d := to.length()
		if d > 7.5 or d < 1.2:
			continue
		var c := aim.dot(to / d)
		if c > best:
			best = c
			lunge = true
	if lunge and not s.is_mech():
		s.lunge_t = 0.13
		s.lunge_dir = Vector3(aim.x, 0.0, aim.z).normalized()
	_pending_swing = 0.13


func _throw_grenade() -> void:
	var s := soldier
	if designating or not s.can_throw():
		if s.reload_t > 0.0:
			Sfx.play("empty_click", -8.0)
		return
	s.nades[s.nade_kind] -= 1
	s.grenade_cd = 1.0
	_throw_kind = s.nade_kind
	if s.is_mech():
		_release_grenade()
		return
	# The grenade leaves at the moment the arm comes over, not when the key is pressed.
	vm.play_throw(_throw_kind)
	_pending_throw = ViewModel.THROW_TIME * ViewModel.THROW_RELEASE


func _release_grenade() -> void:
	var s := soldier
	var dir := (s.aim_direction() + Vector3.UP * 0.12).normalized()
	Net.send_grenade(s.eye_position() + s.aim_direction() * 0.5, dir, _throw_kind)
	if s.nades[s.nade_kind] <= 0:
		s.pick_next_nade()


func _track_footsteps(delta: float) -> void:
	var s := soldier
	var speed := Vector2(s.velocity.x, s.velocity.z).length()
	var on_floor := s.is_on_floor()
	if s.is_vehicle():
		_step_acc += delta
		if _step_acc > 0.95:
			_step_acc = 0.0
			Sfx.play("tank_hum", -12.0, 0.92 + clampf(absf(s.tank_speed) / 30.0, 0.0, 0.3))
	elif on_floor and speed > 1.0:
		_step_acc += speed * delta
		if s.is_mech():
			if _step_acc > 3.0:
				_step_acc = 0.0
				Sfx.play("mech_step", -5.0, randf_range(0.92, 1.08))
				shake(0.34)
		elif _step_acc > 2.5:
			_step_acc = 0.0
			Sfx.play("step%d" % randi_range(1, 3), -19.0 if s.crouching or s.prone else -13.0, randf_range(0.92, 1.08))
	if s.jetting and Engine.get_physics_frames() % 18 == 0:
		Sfx.play("jet", -9.0, randf_range(0.95, 1.05))
	if on_floor and not _was_on_floor and _fall_speed < -6.0:
		_land_dip = clampf(-_fall_speed * 0.012, 0.0, 0.14)
		Sfx.play("land", -9.0)
	_was_on_floor = on_floor
	_fall_speed = s.velocity.y


func _process(delta: float) -> void:
	if soldier and world.forts:
		world.forts.update_preview(soldier, build_kind if state == State.ALIVE else -1)
	_update_blade_hum(delta)
	match state:
		State.ALIVE: _camera_alive(delta)
		State.DEAD: _camera_dead(delta)
		_: _camera_overview(delta)
	_shake = move_toward(_shake, 0.0, delta * 2.2)
	if _shake > 0.0:
		var a := _shake * _shake * 0.035
		camera.rotation += Vector3(randf_range(-a, a), randf_range(-a, a), randf_range(-a, a) * 0.6)


## Hum follows how fast the blade is moving: turning the view whips it through the air.
func _update_blade_hum(delta: float) -> void:
	var s := soldier
	var on := state == State.ALIVE and s != null and s.alive and C.is_blade(s.weapon_id())
	if not on:
		Sfx.blade_hum(false)
		return
	var turn := absf(angle_difference(_hum_yaw, s.yaw)) / maxf(delta, 0.001)
	_hum_yaw = s.yaw
	_hum_swing = lerpf(_hum_swing, clampf(turn / 6.0, 0.0, 1.0), minf(delta * 10.0, 1.0))
	Sfx.blade_hum(true, maxf(_hum_swing, 1.0 if s.fire_cd > float(s.weapon()["rate"]) * 0.5 else 0.0))


func _camera_alive(delta: float) -> void:
	var s := soldier
	if s == null:
		return
	_eye = move_toward(_eye, s.eye_height(), delta * 5.0)
	_land_dip = move_toward(_land_dip, 0.0, delta * 0.5)
	var f := Engine.get_physics_interpolation_fraction()
	var pos: Vector3 = s._prev_pos.lerp(s._cur_pos, f)
	var speed := Vector2(s.velocity.x, s.velocity.z).length()
	var on_floor := s.is_on_floor()
	var bob := sin(Time.get_ticks_msec() * 0.001 * (5.0 + speed * 1.1)) * 0.012 * clampf(speed / 6.0, 0.0, 1.0) if on_floor else 0.0
	camera.global_position = pos + Vector3.UP * (_eye + bob * (1.0 - vm.ads) - _land_dip)
	camera.rotation = Vector3(s.pitch, s.yaw, 0.0)
	if s.on_roof_gun():
		_place_gunner_camera(pos)
	elif s.is_mech():
		_place_mech_camera(pos)
	elif _crews_tank(s):
		_place_sight_camera(pos)
	elif s.is_vehicle() or s.riding >= 0:
		_place_chase_camera(pos)

	var w := s.weapon()
	var fov_target: float = Settings.fov * lerpf(1.0, float(w["ads_fov"]), vm.ads)
	if s.sprinting:
		fov_target += 5.0
	if designating:
		fov_target = Settings.fov * 0.34
	camera.fov = lerpf(camera.fov, fov_target, minf(delta * 12.0, 1.0))
	var ads_now := s.aiming
	vm.ads_rate = w["ads_speed"]
	if s.is_vehicle() or s.is_mech() or s.riding >= 0:
		vm.ads = move_toward(vm.ads, 1.0 if ads_now else 0.0, delta * 7.5)
		vm.visible = false
		scoped = false
		var crew := _crews_tank(s)
		sighted = crew and not s.on_roof_gun()
		_set_thermal(crew and tank_heat)
		# The roof gun hangs right over the main sight, so it is left out of this crewman's view.
		var own := s.model as TankModel
		if own:
			own.roof_mount.visible = not sighted
		return
	vm.animate(delta, ads_now, s.blocking, s.sprinting, speed, on_floor, s.velocity.y)
	scoped = w["scope"] and vm.ads > 0.9
	sighted = s.weapon_id() == C.W.AT_ROCKET and vm.ads > 0.85
	_set_thermal(sighted and launcher_heat)
	vm.visible = not scoped and not designating and not sighted


## Over the mech's shoulder, so the pilot sees the whole machine walking.
func _place_mech_camera(pos: Vector3) -> void:
	var s := soldier
	var aim := s.aim_direction()
	var right := aim.cross(Vector3.UP).normalized()
	var pivot := pos + Vector3.UP * 3.1 + right * lerpf(1.2, 1.0, vm.ads)
	camera.global_position = _clear_of_walls(pivot, pivot - aim * lerpf(6.2, 4.6, vm.ads) + Vector3.UP * lerpf(0.9, 0.4, vm.ads))
	camera.rotation = Vector3(s.pitch, s.yaw, 0.0)


## At the wheel or the gun of a tank, as opposed to a carrier or a passenger's seat.
func _crews_tank(s: Soldier) -> bool:
	return s.is_vehicle() and not s.class_data().get("apc", false)


func _toggle_thermal(s: Soldier) -> void:
	if _crews_tank(s):
		tank_heat = not tank_heat
	elif sighted:
		launcher_heat = not launcher_heat
	else:
		return
	Sfx.play("ui_click", -6.0)


## Thermal on or off for whatever is being looked through.
func _set_thermal(on: bool) -> void:
	if on != thermal:
		thermal = on
		world.set_thermal(on)


func _place_chase_camera(pos: Vector3) -> void:
	var s := soldier
	var aim := s.aim_direction()
	var pivot := pos + Vector3.UP * 3.4
	camera.global_position = _clear_of_walls(pivot, pivot - aim * lerpf(10.5, 6.0, vm.ads) + Vector3.UP * lerpf(2.8, 1.4, vm.ads))
	camera.rotation = Vector3(s.pitch - lerpf(0.1, 0.04, vm.ads), s.yaw, 0.0)


## From the top of the turret, so the driver can see which way the hull points.
func _place_sight_camera(pos: Vector3) -> void:
	var s := soldier
	var tank := s.model as TankModel
	var pivot := pos + Vector3.UP * 2.6
	camera.global_position = _clear_of_walls(pivot, tank.sight_position() if tank else pivot)
	camera.rotation = Vector3(s.pitch, s.yaw, 0.0)


## Behind the roof gun, as the man at its grips sees it.
func _place_gunner_camera(pos: Vector3) -> void:
	var s := soldier
	var mount := world.gunner_tank(s)
	var pivot := mount.gunner_pivot() if mount else pos + Vector3.UP * C.TANK_GUNNER_EYE
	camera.global_position = _clear_of_walls(pivot, pivot - s.aim_direction() * 0.16 + Vector3.UP * 0.52)
	camera.rotation = Vector3(s.pitch, s.yaw, 0.0)


## Pulls the camera in rather than letting a wall hide the tank.
func _clear_of_walls(pivot: Vector3, wanted: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(pivot, wanted, C.LAYER_WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return wanted
	var p: Vector3 = hit["position"]
	return p + (pivot - p).normalized() * 0.4


func _camera_dead(delta: float) -> void:
	sighted = false
	_set_thermal(false)
	_death_t += delta
	var s := soldier
	var body := s.global_position
	var height := lerpf(_eye, 2.8, smoothstep(0.0, 1.2, _death_t))
	var back := Vector3(sin(s.yaw), 0.0, cos(s.yaw)) * lerpf(0.0, 3.2, smoothstep(0.0, 1.2, _death_t))
	camera.global_position = body + Vector3.UP * height + back
	var look := body + Vector3.UP * 0.4
	if _killer != null and is_instance_valid(_killer) and _killer.alive:
		look = look.lerp(_killer.global_position + Vector3.UP * 1.2, smoothstep(0.4, 1.6, _death_t))
	if camera.global_position.distance_squared_to(look) > 0.01:
		camera.look_at(look, Vector3.UP)
	camera.fov = lerpf(camera.fov, Settings.fov * 0.8, minf(delta * 2.0, 1.0))
	if _death_t >= C.RESPAWN_DELAY * 0.5 and not world.hud.deploy_visible():
		state = State.DEPLOY
		world.hud.show_deploy(C.RESPAWN_DELAY * 0.5)


func _camera_overview(delta: float) -> void:
	_orbit += delta * 0.05
	var center := Vector3(0, 8, 0)
	var reach := minf(world.map.bound().length() * 0.5, 118.0)
	camera.global_position = center + Vector3(sin(_orbit) * reach, 62.0, cos(_orbit) * reach)
	camera.look_at(center, Vector3.UP)
	camera.fov = 55.0
