class_name Soldier
extends CharacterBody3D
## One combatant, human or bot. The node persists across deaths and is only hidden,
## so `sid` is a stable identity for scores and network messages.

enum Driver {
	BOT,           ## Server simulated, driven by BotBrain.
	LOCAL,         ## This machine's player, simulated here.
	PROXY_VIEW,    ## Client's view of someone else: interpolated from snapshots.
	PROXY_SERVER,  ## Server's view of a remote human: positions come from their client.
}

const HISTORY_SECONDS := 0.6
const HISTORY_RATE := 1.0 / 30.0
## Limbs update every frame this close to the camera, in metres as seen through its zoom.
const POSE_FULL_RANGE := 30.0
const POSE_MID_RANGE := 80.0
const OFF_SCREEN_POSE := 0.1
const FELL_THROUGH := -2.0

var world: World
var sid := 0
var peer := 0
var team := 0
var class_id := 0
var pname := ""
var token := ""
var level := 1
## Round trip to the server in ms, as the server last measured it. -1 until it has.
var ping := -1
## Test switches from the admin panel. The server decides them and tells every machine.
var god := false
var noclip := false
var inf_ammo := false
## Ran out of stamina: no sprint until enough of it is back.
var exhausted := false
## What the soldier carried on foot, kept while they sit in a vehicle.
var _foot_ammo := {}
## Weapons, attachments and perks chosen for this life. Empty for bots.
var kit := {}
var slot_stats: Array[Dictionary] = []
## The same weapons seen through their second sight; empty where a weapon has only one.
var magnified_stats: Array[Dictionary] = []
## Which sight the player looks through on a weapon that has two: 0 the dot, 1 the magnifier.
## Only the owner's client uses it, and it is kept from one life to the next.
var sight := 0
var control: int = Driver.BOT

var alive := false
var hp := 100.0
var max_hp := 100.0
var yaw := 0.0
var pitch := 0.0
var crouching := false
var prone := false
var sprinting := false
var aiming := false
var blocking := false
var protected_t := 0.0

var kills := 0
var deaths := 0
var score := 0

# Loadout
var slot := 0
var loadout: Array = []
var mags := [0, 0, 0]
var reserves := [0, 0, 0]
## Carried grenades by kind, indexed by C.NADE_FRAG and the rest. On a mech, frags are its rockets.
var nades: Array = [0, 0, 0]
var nade_kind := C.NADE_FRAG
var grenades: int:
	get:
		return nades[C.NADE_FRAG]
	set(value):
		nades[C.NADE_FRAG] = value
var reload_t := 0.0
var fire_cd := 0.0
var swing_t := 0.0
var switch_t := 0.0
var stamina := C.STAMINA_MAX
var stamina_max := C.STAMINA_MAX
var grenade_cd := 0.0

# Coins and super classes
var coins := 0
var base_class := 0
var super_t := 0.0
var jet_fuel := C.JET_FUEL
var jetting := false
var cloak_block_t := 0.0
var net_cloaked := false
var net_reloading := false

# Vehicles. A driver is a Soldier with the tank class, so damage, networking, bots and the
# HUD all work unchanged; only the movement and the model differ.
var hull_yaw := 0.0
var tank_speed := 0.0
var drive := Vector2.ZERO
var reverse_t := 0.0
var vehicle_id := -1
## -1 infantry, 0 driver/main gun, 1 independent roof gun.
var vehicle_seat := -1
## The carrier this soldier sits in as a passenger, or -1.
var riding := -1
var _body_layer := 0
var infantry_hp := 100.0


# Input for the shared movement step.
var wish := Vector3.ZERO
var want_sprint := false
var want_crouch := false
var want_prone := false
var _unseen_t := 0.0
var want_jump := false
var want_fly := false
var lunge_t := 0.0
var lunge_dir := Vector3.ZERO

# Server bookkeeping
var last_damage_time := -100.0
var death_time := -100.0
var damagers := {}
var last_state_time := 0.0
var last_valid_pos := Vector3.ZERO
var was_teleported := false

var model: SoldierModel = null
var shape: CapsuleShape3D
var _shape_node: CollisionShape3D

var _history: Array[Vector4] = []
var _history_t := 0.0
var _snaps: Array = []
var _prev_pos := Vector3.ZERO
var _cur_pos := Vector3.ZERO
var _step_acc := 0.0


func setup(w: World, new_sid: int, new_peer: int, new_team: int, new_name: String, mode: int) -> void:
	world = w
	sid = new_sid
	peer = new_peer
	team = new_team
	pname = new_name
	control = mode
	name = "Soldier%d" % sid
	collision_layer = 0
	collision_mask = C.LAYER_WORLD | C.LAYER_VEHICLE | C.LAYER_FORT
	# Hull updates must not launch a character with inherited platform velocity.
	platform_floor_layers = C.LAYER_WORLD
	platform_wall_layers = 0
	floor_max_angle = deg_to_rad(52.0)
	floor_snap_length = 0.45
	shape = CapsuleShape3D.new()
	shape.radius = C.BODY_RADIUS
	shape.height = C.STAND_HEIGHT
	_shape_node = CollisionShape3D.new()
	_shape_node.shape = shape
	_shape_node.position.y = C.STAND_HEIGHT * 0.5
	add_child(_shape_node)
	_sync_model()
	if model:
		model.visible = false
	visible = true


## The energy shield, for classes that have one. `shield` is its charge, 0 to C.SHIELD_HP. A broken
## shield is not ready again until it has charged all the way back.
var shield := 0.0
var shield_ready := true
## -1 leaning left, 1 right, 0 upright: what the player asks for. `lean_amount` follows it smoothly.
var lean := 0
var lean_amount := 0.0


func has_shield() -> bool:
	return class_data().get("shield", false)


## Holding the shield up in front.
func shield_held() -> bool:
	return alive and weapon_id() == C.W.ENERGY_SHIELD and shield_ready and shield > 0.0


func can_lean() -> bool:
	return alive and riding < 0 and not prone and not sprinting and not is_vehicle() and not is_mech()


## Where leaning puts the head, stopped short of any wall beside it so nobody looks through one.
func lean_offset() -> Vector3:
	if is_zero_approx(lean_amount):
		return Vector3.ZERO
	var side := Basis(Vector3.UP, yaw) * Vector3.RIGHT * signf(lean_amount)
	var reach := absf(lean_amount) * C.LEAN_DIST
	var eye := global_position + Vector3.UP * eye_height()
	if is_inside_tree():
		var q := PhysicsRayQueryParameters3D.create(eye, eye + side * (reach + 0.18), C.LAYER_WORLD)
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			reach = maxf(minf(reach, eye.distance_to(hit["position"]) - 0.18), 0.0)
	return side * reach + Vector3.DOWN * absf(lean_amount) * 0.05


func weapon_id() -> int:
	return loadout[slot] if slot < loadout.size() else C.W.PISTOL


## The weapon in hand, with its attachments and perks already applied.
func weapon() -> Dictionary:
	if slot >= slot_stats.size():
		return C.WEAPONS[weapon_id()]
	if sight == 1 and slot < magnified_stats.size() and not magnified_stats[slot].is_empty():
		return magnified_stats[slot]
	return slot_stats[slot]


## Whether the weapon in hand carries a second sight to flip to.
func has_two_sights() -> bool:
	return slot < magnified_stats.size() and not magnified_stats[slot].is_empty()


func weapon_parts() -> Array:
	if kit.is_empty() or class_id >= C.NORMAL_CLASSES:
		return []
	if slot == 0:
		return kit.get("parts_p", [])
	return kit.get("parts_s", []) if slot == 1 else []


func has_perk(id: String) -> bool:
	return class_id < C.NORMAL_CLASSES and kit.get("perks", []).has(id)


func is_melee() -> bool:
	return weapon()["melee"]


func class_data() -> Dictionary:
	return C.cls(team, class_id)


func is_super() -> bool:
	return class_id >= C.NORMAL_CLASSES


func is_mech() -> bool:
	return class_data().get("mech", false)


## Behind the roof gun, either as the gunner or as a driver alone in the tank.
func on_roof_gun() -> bool:
	return is_gunner() or (is_vehicle() and weapon_id() == C.W.TANK_MG)


func is_vehicle() -> bool:
	return class_data().get("vehicle", false)


## Passengers are out of the world until they get out: no body, no model, no collisions.
func set_riding(vehicle: int) -> void:
	if vehicle >= 0 and riding < 0:
		_body_layer = collision_layer
		collision_layer = 0
	elif vehicle < 0 and riding >= 0:
		collision_layer = _body_layer
	riding = vehicle
	if model:
		model.visible = vehicle < 0 and control != Driver.LOCAL


func is_gunner() -> bool:
	return is_vehicle() and vehicle_seat == 1


func melee_slot() -> int:
	for i in range(loadout.size() - 1, -1, -1):
		if C.WEAPONS[loadout[i]]["melee"]:
			return i
	return -1


func melee_weapon() -> Dictionary:
	return slot_stats[maxi(melee_slot(), 0)]


func body_radius() -> float:
	return class_data().get("radius", C.BODY_RADIUS)


func stance_height() -> float:
	if prone:
		return C.PRONE_HEIGHT
	return C.CROUCH_HEIGHT if crouching else float(class_data().get("height", C.STAND_HEIGHT))


func eye_height() -> float:
	if is_gunner():
		return C.TANK_GUNNER_EYE
	if prone:
		return C.PRONE_EYE
	return C.CROUCH_EYE if crouching else float(class_data().get("eye", C.STAND_EYE))


func is_cloaked() -> bool:
	if control == Driver.PROXY_VIEW:
		return net_cloaked
	return alive and class_data().get("cloak", false) and cloak_block_t <= 0.0


func eye_position() -> Vector3:
	return global_position + Vector3.UP * eye_height() + lean_offset()


func aim_direction() -> Vector3:
	return Basis.from_euler(Vector3(pitch, yaw, 0.0), EULER_ORDER_YXZ) * Vector3.FORWARD


func state_flags() -> int:
	var f := 0
	if alive: f |= C.F_ALIVE
	if crouching: f |= C.F_CROUCH
	if prone: f |= C.F_PRONE
	if sprinting: f |= C.F_SPRINT
	if aiming: f |= C.F_ADS
	if blocking: f |= C.F_BLOCK
	if reload_t > 0.0: f |= C.F_RELOAD
	if protected_t > 0.0: f |= C.F_PROTECTED
	if is_cloaked(): f |= C.F_CLOAK
	if lean < 0: f |= C.F_LEAN_L
	if lean > 0: f |= C.F_LEAN_R
	return f


func apply_flags(f: int) -> void:
	crouching = f & C.F_CROUCH != 0
	prone = f & C.F_PRONE != 0
	sprinting = f & C.F_SPRINT != 0
	aiming = f & C.F_ADS != 0
	blocking = f & C.F_BLOCK != 0
	net_cloaked = f & C.F_CLOAK != 0
	net_reloading = f & C.F_RELOAD != 0
	lean = -1 if f & C.F_LEAN_L != 0 else (1 if f & C.F_LEAN_R != 0 else 0)


# ---------------------------------------------------------------- life cycle

func respawn(pos: Vector3, new_yaw: float, new_class: int, new_kit: Dictionary = {}) -> void:
	kit = new_kit
	base_class = new_class
	super_t = 0.0
	vehicle_id = -1
	vehicle_seat = -1
	if riding >= 0:
		set_riding(-1)
	alive = true
	_foot_ammo = {}
	_apply_class(new_class)
	protected_t = C.SPAWN_PROTECTION
	damagers.clear()
	velocity = Vector3.ZERO
	wish = Vector3.ZERO
	yaw = new_yaw
	pitch = 0.0
	teleport(pos)
	_snaps.clear()
	_history.clear()


## Switches to a super class on the spot, or back to `base_class` when it runs out.
func become(new_class: int, duration: float, new_hp := -1.0) -> void:
	if new_class == C.SUPER_MECH or new_class == C.SUPER_SPECIAL:
		coins = 0
	var was_vehicle := is_vehicle()
	var to_vehicle: bool = C.cls(team, new_class).get("vehicle", false)
	# Climbing in and out is no way to a fresh set of magazines and grenades.
	if to_vehicle and not was_vehicle:
		_foot_ammo = ammo_state()
	_apply_class(new_class)
	if was_vehicle and not to_vehicle and not _foot_ammo.is_empty():
		set_ammo(_foot_ammo)
		_foot_ammo = {}
	super_t = duration
	if new_hp >= 0.0:
		hp = new_hp
	elif new_class < C.NORMAL_CLASSES:
		hp = max_hp * C.SUPER_END_HP_FRACTION


func _apply_class(new_class: int) -> void:
	class_id = new_class
	var cd := class_data()
	max_hp = float(cd["hp"]) + (15.0 if has_perk("tough") else 0.0)
	hp = max_hp
	loadout = cd["weapons"]
	if is_gunner():
		loadout = [C.W.TANK_MG]
	var parts: Array = [[], [], [], []]
	var perks: Array = []
	if not kit.is_empty() and new_class < C.NORMAL_CLASSES:
		var primary: int = kit["primary"]
		if (cd["weapons"] as Array).size() < 3:
			# Weapons built into the body: no blade to carry, and no other gun to swap in.
			loadout = [primary, kit["sidearm"]]
		else:
			var melee: int = primary if C.WEAPONS[primary]["melee"] else int(cd["weapons"][2])
			loadout = [primary, kit["sidearm"], melee]
		parts = [kit["parts_p"], kit["parts_s"], [], []]
		perks = kit["perks"]
	if new_class == 0 and kit.get("ordnance", "grenades") == "rockets":
		loadout = loadout.duplicate()
		loadout.append(C.W.AT_ROCKET)
	if cd.get("shield", false):
		loadout = loadout.duplicate()
		loadout.append(C.W.ENERGY_SHIELD)
	mags.resize(loadout.size())
	reserves.resize(loadout.size())
	slot_stats.clear()
	magnified_stats.clear()
	for i in loadout.size():
		var w := Gear.stats(loadout[i], parts[i], perks)
		if loadout[i] == C.W.AT_ROCKET:
			w["mag"] = 1
			w["reserve"] = 2
		slot_stats.append(w)
		magnified_stats.append(Gear.magnified(w))
		mags[i] = w["mag"]
		reserves[i] = w["reserve"]
	nades = [int(cd["grenades"]) + (1 if has_perk("grenadier") else 0), int(cd.get("smoke", 0)), int(cd.get("fire", 0))]
	if new_class == 0 and kit.get("ordnance", "grenades") == "rockets":
		grenades = 0
	nade_kind = C.NADE_FRAG
	if nades[nade_kind] <= 0:
		pick_next_nade()
	stamina_max = C.STAMINA_MAX * (1.5 if has_perk("runner") else 1.0)
	shield = C.SHIELD_HP if has_shield() else 0.0
	shield_ready = true
	lean = 0
	lean_amount = 0.0
	slot = 0
	reload_t = 0.0
	fire_cd = 0.0
	swing_t = 0.0
	switch_t = 0.0
	stamina = stamina_max
	exhausted = false
	jet_fuel = C.JET_FUEL
	jetting = false
	want_fly = false
	cloak_block_t = 0.0
	crouching = false
	prone = false
	want_prone = false
	sprinting = false
	aiming = false
	blocking = false
	shape.radius = body_radius()
	shape.height = stance_height()
	_shape_node.position.y = stance_height() * 0.5
	_sync_model()
	if model:
		model.visible = control != Driver.LOCAL or is_vehicle() or is_mech()
		model.set_loadout(weapon_id(), class_id, weapon_parts())
		model.reset_pose()


## Soldiers and mechs are different scenes, so the model is swapped when the class needs it.
func _sync_model() -> void:
	if is_gunner():
		if model:
			model.queue_free()
			model = null
		return
	if not Net.has_view():
		return
	var want: Script = SoldierModel
	if is_vehicle():
		want = ApcModel if class_data().get("apc", false) else TankModel
	elif is_mech():
		want = MechModel
	if model != null and model.get_script() == want:
		return
	if model != null:
		model.queue_free()
	model = want.new()
	model.setup(team)
	add_child(model)
	model.top_level = true


func teleport(pos: Vector3) -> void:
	global_position = pos
	last_valid_pos = pos
	_prev_pos = pos
	_cur_pos = pos


func die() -> void:
	alive = false
	super_t = 0.0
	coins = 0
	jetting = false
	wish = Vector3.ZERO
	blocking = false
	aiming = false
	reload_t = 0.0
	if model:
		model.visible = true
		model.play_death()


# ---------------------------------------------------------------- simulation

func _physics_process(delta: float) -> void:
	lean_amount = move_toward(lean_amount, float(lean) if can_lean() else 0.0, delta * C.LEAN_SPEED)
	# Anyone squeezed through the terrain is put back on top of it, not left to fall for ever.
	if alive and not noclip and global_position.y < FELL_THROUGH and control != Driver.PROXY_VIEW:
		var ground := world.map.ground_height(global_position.x, global_position.z)
		if global_position.y < ground - 2.5:
			global_position.y = ground + 0.5
			velocity = Vector3.ZERO
	if riding >= 0:
		global_position = world.ride_position(self)
		velocity = Vector3.ZERO
		_prev_pos = global_position
		_cur_pos = global_position
		return
	if control == Driver.PROXY_VIEW:
		return
	if control == Driver.PROXY_SERVER:
		if alive:
			tick_weapons(delta)
			_record_history(delta)
		return
	if not alive:
		return
	var u0 := Time.get_ticks_usec()
	tick_weapons(delta)
	_prev_pos = _cur_pos
	simulate_move(delta)
	_cur_pos = global_position
	if Time.get_ticks_usec() - u0 > 4000:
		print("[spike] soldier move ", sid, " ", (Time.get_ticks_usec() - u0) / 1000.0, " cls=", class_id, " pos=", global_position)
	if control == Driver.BOT or Net.is_server():
		_record_history(delta)


func _process(delta: float) -> void:
	if control == Driver.PROXY_VIEW:
		_interpolate()
	if model == null or not model.visible:
		return
	var pos := global_position
	if control == Driver.BOT or (control == Driver.LOCAL and is_vehicle()):
		# Smooth 60 Hz physics steps for high refresh rate displays.
		pos = _prev_pos.lerp(_cur_pos, Engine.get_physics_interpolation_fraction())
	var speed := Vector2(velocity.x, velocity.z).length()
	var local_vel := Basis(Vector3.UP, -yaw) * velocity
	var grounded := absf(velocity.y) < 2.5 if control == Driver.PROXY_VIEW else is_on_floor()
	var reloading := net_reloading if control == Driver.PROXY_VIEW else reload_t > 0.0
	model.pose_interval = _pose_interval(pos)
	# Out of sight a body only has to keep up now and then. Its shadow is the one thing that shows.
	_unseen_t += delta
	if model.pose_interval < OFF_SCREEN_POSE or _unseen_t >= OFF_SCREEN_POSE:
		var pose_delta := _unseen_t
		_unseen_t = 0.0
		model.set_motion(Vector2(local_vel.x, -local_vel.z), grounded, reloading, sprinting)
		if model is SoldierModel:
			(model as SoldierModel).prone = prone
			(model as SoldierModel).lean = lean_amount
		model.update_pose(pose_delta, pos, yaw, pitch, speed, crouching, aiming, blocking, alive)
		model.set_hull(hull_yaw)
		model.set_health(hp / max_hp)
		model.set_jet(alive and class_data().get("jetpack", false) and velocity.y > 0.8)
		model.set_cloak(1.0 if alive and is_cloaked() else 0.0, speed)
	if alive and is_vehicle():
		_step_acc += delta
		if _step_acc > 0.95 and control != Driver.LOCAL and is_near_listener():
			_step_acc = 0.0
			Sfx.play_at("tank_hum", pos, 0.0, randf_range(0.96, 1.04))
	elif alive and control != Driver.LOCAL and speed > 1.0 and is_near_listener():
		_step_acc += speed * delta
		if is_mech():
			if _step_acc > 3.2:
				_step_acc = 0.0
				Sfx.play_at("mech_step", pos, 2.0, randf_range(0.9, 1.1))
		elif _step_acc > 2.6:
			_step_acc = 0.0
			var loud := -12.0 if crouching else -6.0
			Sfx.play_at("step%d" % randi_range(1, 3), pos, loud - (14.0 if has_perk("quiet") else 0.0), randf_range(0.9, 1.1))


## Nobody can tell a walk at 15 updates a second from one at 200 across the square, and a
## scope brings the far side close again, so distance counts as seen through the zoom.
func _pose_interval(pos: Vector3) -> float:
	var cam := world.controller.camera
	var range_seen := cam.global_position.distance_to(pos) * cam.fov / Settings.fov
	if range_seen < POSE_FULL_RANGE:
		return 0.0
	if not cam.is_position_in_frustum(pos):
		return 0.1
	return 1.0 / 30.0 if range_seen < POSE_MID_RANGE else 1.0 / 15.0


func is_near_listener() -> bool:
	return world.camera_position().distance_squared_to(global_position) < 3600.0


func simulate_move(delta: float) -> void:
	if is_gunner():
		world.sync_gunner(self)
		return
	var cd := class_data()
	if cd.get("vehicle", false):
		_simulate_tank(delta)
		return
	if noclip:
		_simulate_noclip(delta)
		return
	var speed: float = C.WALK_SPEED * float(cd["speed"]) * float(weapon()["move_mult"])
	# Without the lock the legs would stop and start on every scrap of stamina that came back.
	# The lock is the only limit: a second, higher floor would leave a band where sprint
	# switched off and on every tick, which is what made a tired soldier stutter.
	if stamina <= 0.0:
		exhausted = true
	elif exhausted and stamina >= stamina_max * C.STAMINA_RECOVER:
		exhausted = false
	sprinting = want_sprint and not exhausted and not cd.get("no_sprint", false) and wish.length_squared() > 0.1 and not aiming and not blocking and not crouching and reload_t <= 0.0
	if sprinting:
		speed = C.SPRINT_SPEED * float(cd["speed"]) * float(weapon()["move_mult"])
		stamina = maxf(stamina - delta, 0.0)
		if stamina <= 0.0:
			exhausted = true
	else:
		stamina = minf(stamina + delta * 0.8, stamina_max)
	if cd.get("no_crouch", false):
		want_crouch = false
		want_prone = false
	_update_crouch()
	if prone:
		sprinting = false
		speed = C.PRONE_SPEED
	elif crouching:
		speed = C.CROUCH_SPEED
	if aiming or blocking:
		speed *= C.ADS_SPEED_MULT

	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var target := wish * speed
	var accel := C.GROUND_ACCEL if is_on_floor() else C.AIR_ACCEL
	if jetting:
		accel = C.AIR_ACCEL * 2.6
	horizontal = horizontal.move_toward(target, accel * delta)
	if lunge_t > 0.0:
		lunge_t -= delta
		horizontal = lunge_dir * 13.0
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if is_on_floor():
		if want_jump and not cd.get("no_jump", false) and not prone:
			velocity.y = C.JUMP_VELOCITY
			floor_snap_length = 0.0
		else:
			floor_snap_length = 0.45
	else:
		velocity.y -= C.GRAVITY * delta
	want_jump = false
	if cd.get("jetpack", false):
		_tick_jetpack(delta)
	move_and_slide()


## Flying through everything: forward goes where the eyes look, Space up, Ctrl down, Shift fast.
func _simulate_noclip(delta: float) -> void:
	sprinting = false
	var right := Basis(Vector3.UP, yaw) * Vector3.RIGHT
	var dir := aim_direction() * drive.y + right * drive.x
	if want_fly:
		dir += Vector3.UP
	if want_crouch:
		dir += Vector3.DOWN
	if dir.length_squared() > 1.0:
		dir = dir.normalized()
	velocity = dir * (40.0 if want_sprint else 14.0)
	global_position += velocity * delta
	want_jump = false


## Players steer the hull with `drive`; bots hand in a `wish` direction and it steers for them.
func _simulate_tank(delta: float) -> void:
	var steer := drive.x
	var throttle := drive.y
	if control != Driver.LOCAL:
		steer = 0.0
		throttle = 0.0
		if wish.length_squared() > 0.01:
			var diff := angle_difference(hull_yaw, atan2(-wish.x, -wish.z))
			steer = -clampf(diff * 2.0, -1.0, 1.0)
			throttle = clampf(1.0 - absf(diff) / 1.2, 0.0, 1.0)
		if reverse_t > 0.0:
			reverse_t -= delta
			throttle = -1.0
			steer = 0.0
	var hull := world.collider_for_driver(sid)
	var next_hull_yaw := hull_yaw - steer * C.TANK_TURN_RATE * delta
	if hull == null or is_zero_approx(steer) or hull.can_face(global_position, next_hull_yaw):
		hull_yaw = next_hull_yaw
	var top: float = C.TANK_SPEED * (1.0 if throttle >= 0.0 else C.TANK_REVERSE_MULT)
	tank_speed = move_toward(tank_speed, throttle * top, C.TANK_ACCEL * delta)
	var forward := Basis(Vector3.UP, hull_yaw) * Vector3.FORWARD
	velocity.x = forward.x * tank_speed
	velocity.z = forward.z * tank_speed
	if not is_on_floor():
		velocity.y -= C.GRAVITY * delta
	if hull:
		# Query from the current pose, including turns made this tick.
		hull.update_hull(global_position, hull_yaw, alive, self)
		var fraction := hull.travel_fraction(Vector3(velocity.x, 0, velocity.z) * delta)
		velocity.x *= fraction
		velocity.z *= fraction
	move_and_slide()
	if hull:
		hull.update_hull(global_position, hull_yaw, alive, self)
	if is_on_wall():
		tank_speed *= 0.9


func _tick_jetpack(delta: float) -> void:
	jetting = want_fly and jet_fuel > 0.0
	if jetting:
		jet_fuel = maxf(jet_fuel - delta, 0.0)
		velocity.y = move_toward(velocity.y, C.JET_RISE_SPEED, 46.0 * delta)
		floor_snap_length = 0.0
	elif is_on_floor():
		jet_fuel = minf(jet_fuel + delta * 0.9, C.JET_FUEL)


func _update_crouch() -> void:
	var crouch := want_crouch and not want_prone
	if crouch == crouching and want_prone == prone:
		return
	var room := C.PRONE_HEIGHT if want_prone else (C.CROUCH_HEIGHT if crouch else C.STAND_HEIGHT)
	if room > stance_height():
		# Do not stand up into a ceiling.
		var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.3, global_position + Vector3.UP * (room + 0.05), C.LAYER_WORLD)
		if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			return
	crouching = crouch
	prone = want_prone
	var h := stance_height()
	shape.height = h
	_shape_node.position.y = h * 0.5


func tick_weapons(delta: float) -> void:
	fire_cd = maxf(fire_cd - delta, 0.0)
	swing_t = maxf(swing_t - delta, 0.0)
	switch_t = maxf(switch_t - delta, 0.0)
	protected_t = maxf(protected_t - delta, 0.0)
	grenade_cd = maxf(grenade_cd - delta, 0.0)
	cloak_block_t = maxf(cloak_block_t - delta, 0.0)
	super_t = maxf(super_t - delta, 0.0)
	if reload_t > 0.0:
		reload_t -= delta
		if reload_t <= 0.0:
			finish_reload()


## Both hands are on the gun during a reload, so nothing can be thrown until it is finished.
func can_throw() -> bool:
	return alive and grenade_cd <= 0.0 and reload_t <= 0.0 and nades[nade_kind] > 0


## Moves to the next kind this soldier still carries.
func pick_next_nade() -> void:
	for step in range(1, nades.size() + 1):
		var kind := (nade_kind + step) % nades.size()
		if nades[kind] > 0:
			nade_kind = kind
			return


func can_fire() -> bool:
	return alive and fire_cd <= 0.0 and reload_t <= 0.0 and switch_t <= 0.0 and not sprinting and mags[slot] > 0


func consume_shot() -> void:
	if not inf_ammo:
		mags[slot] -= 1
	fire_cd = weapon()["rate"]
	cloak_block_t = C.CLOAK_BREAK_TIME


func can_swing() -> bool:
	return alive and is_melee() and fire_cd <= 0.0 and switch_t <= 0.0 and not blocking


func can_reload() -> bool:
	var w := weapon()
	return alive and not w["melee"] and reload_t <= 0.0 and mags[slot] < int(w["mag"]) and reserves[slot] > 0


func start_reload() -> void:
	reload_t = weapon()["reload"]
	aiming = false


func finish_reload() -> void:
	reload_t = 0.0
	var need: int = int(weapon()["mag"]) - mags[slot]
	var taken: int = mini(need, reserves[slot])
	mags[slot] += taken
	reserves[slot] -= taken


func ammo_state() -> Dictionary:
	return {"mags": mags.duplicate(), "reserves": reserves.duplicate(), "nades": nades.duplicate(), "slot": slot, "nade_kind": nade_kind}


## Puts back what `ammo_state` saved, as long as it was saved for the same weapons.
func set_ammo(state: Dictionary) -> void:
	var saved_mags: Array = state.get("mags", [])
	if saved_mags.size() != mags.size():
		return
	mags = saved_mags.duplicate()
	reserves = (state["reserves"] as Array).duplicate()
	if (state["nades"] as Array).size() == nades.size():
		nades = (state["nades"] as Array).duplicate()
		nade_kind = int(state["nade_kind"])
	slot = clampi(int(state["slot"]), 0, loadout.size() - 1)
	if model:
		model.set_weapon(weapon_id(), weapon_parts())


## Full health and every magazine, from the admin panel.
func refill() -> void:
	hp = max_hp
	for i in loadout.size():
		mags[i] = slot_stats[i]["mag"]
		reserves[i] = slot_stats[i]["reserve"]
	var cd := class_data()
	nades = [int(cd["grenades"]) + (1 if has_perk("grenadier") else 0), int(cd.get("smoke", 0)), int(cd.get("fire", 0))]
	stamina = stamina_max
	exhausted = false


func switch_to(new_slot: int) -> void:
	if new_slot == slot or new_slot < 0 or new_slot >= loadout.size():
		return
	# A broken shield cannot be taken out again until it has charged back.
	if loadout[new_slot] == C.W.ENERGY_SHIELD and not shield_ready:
		return
	if new_slot == C.TANK_ROOF_SLOT and world.roof_taken(self):
		return
	slot = new_slot
	reload_t = 0.0
	blocking = false
	aiming = false
	switch_t = 0.21 if has_perk("reflex") else 0.35
	if model:
		model.set_weapon(weapon_id(), weapon_parts())


# ---------------------------------------------------------------- lag compensation

func _record_history(delta: float) -> void:
	_history_t += delta
	if _history_t < HISTORY_RATE:
		return
	_history_t = 0.0
	var p := global_position
	_history.append(Vector4(p.x, p.y, p.z, Net.server_time()))
	if _history.size() > int(HISTORY_SECONDS / HISTORY_RATE):
		_history.pop_front()


## Where this soldier stood at server time `t`, for rewinding hit detection.
func position_at(t: float) -> Vector3:
	var n := _history.size()
	if n == 0 or t >= _history[n - 1].w:
		return global_position
	for i in range(n - 1, 0, -1):
		var a: Vector4 = _history[i - 1]
		var c: Vector4 = _history[i]
		if t >= a.w:
			var k := (t - a.w) / maxf(c.w - a.w, 0.0001)
			return Vector3(a.x, a.y, a.z).lerp(Vector3(c.x, c.y, c.z), k)
	var first: Vector4 = _history[0]
	return Vector3(first.x, first.y, first.z)


# ---------------------------------------------------------------- snapshot interpolation

func push_snapshot(t: float, pos: Vector3, snap_yaw: float, snap_pitch: float, snap_hull: float) -> void:
	_snaps.append([t, pos, snap_yaw, snap_pitch, snap_hull])
	if _snaps.size() > 12:
		_snaps.pop_front()


func _interpolate() -> void:
	var n := _snaps.size()
	if n == 0:
		return
	var t := Net.server_time() - Net.INTERP_DELAY
	var a: Array = _snaps[0]
	var c: Array = _snaps[n - 1]
	for i in range(n - 1):
		if _snaps[i][0] <= t and _snaps[i + 1][0] >= t:
			a = _snaps[i]
			c = _snaps[i + 1]
			break
	if t >= c[0]:
		a = c
	var span: float = c[0] - a[0]
	var k := 0.0 if span <= 0.0001 else clampf((t - a[0]) / span, 0.0, 1.0)
	var pa: Vector3 = a[1]
	var pc: Vector3 = c[1]
	var new_pos := pa.lerp(pc, k)
	var dt := maxf(get_process_delta_time(), 0.001)
	velocity = velocity.lerp((new_pos - global_position) / dt, 0.2)
	if velocity.length() > 30.0:
		velocity = Vector3.ZERO
	global_position = new_pos
	yaw = lerp_angle(a[2], c[2], k)
	pitch = lerpf(a[3], c[3], k)
	hull_yaw = lerp_angle(a[4], c[4], k)
