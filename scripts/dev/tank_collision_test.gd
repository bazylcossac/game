extends Node
## Headless physics regression: real Soldier movement against parked and occupied hulls.
## Run with -- --test=tank-collision. No match, bot AI or player progress is needed.

class TestWorld:
	extends World
	func _ready() -> void:
		process_physics_priority = -20

var w: World
var failed := 0
var passed := 0


func _ready() -> void:
	w = TestWorld.new()
	add_child(w)
	var ground := StaticBody3D.new()
	ground.collision_layer = C.LAYER_WORLD
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(180, 1, 180)
	floor_shape.shape = box
	floor_shape.position.y = -0.5
	ground.add_child(floor_shape)
	w.add_child(ground)
	w.on_vehicle(1, 0, Vector3.ZERO, 0.0, 800.0, 0)
	var s := _soldier(101, Vector3(6, 0.1, 0))
	await _walk(s, Vector3(6, 0.1, 0), Vector3.LEFT, 1.6)
	_check("parked hull stops infantry at its side (x=%.2f)" % s.position.x, s.position.x > 2.1 and s.position.x < 2.8)
	await _walk(s, Vector3(0, 0.1, 8), Vector3.FORWARD, 1.6)
	_check("parked hull stops infantry at its nose (z=%.2f)" % s.position.z, s.position.z > 3.5 and s.position.z < 4.2)
	w.on_vehicle(1, 0, Vector3.ZERO, PI * 0.5, 800.0, 0)
	await _walk(s, Vector3(6, 0.1, 0), Vector3.LEFT, 1.6)
	_check("collision turns with hull (x=%.2f)" % s.position.x, s.position.x > 3.5 and s.position.x < 4.2)

	var driver := _soldier(102, Vector3.ZERO)
	driver.control = Soldier.Driver.PROXY_VIEW
	w.on_vehicle(1, 0, Vector3.ZERO, 0.0, 800.0, driver.sid)
	driver.become(C.VEHICLE_CLASS, 0.0)
	driver.hull_yaw = 0.0
	driver.yaw = PI * 0.5
	await _walk(s, Vector3(6, 0.1, 0), Vector3.LEFT, 1.6)
	_check("occupied hull blocks infantry independently of turret (x=%.2f)" % s.position.x, s.position.x > 2.1 and s.position.x < 2.8)
	driver.teleport(Vector3(14, 0, 0))
	await _wait(0.1)
	await _walk(s, Vector3(6, 0.1, 0), Vector3.LEFT, 1.6)
	_check("moving proxy moves collision away from old position", s.position.x < -2.0)
	await _walk(s, Vector3(20, 0.1, 0), Vector3.LEFT, 1.6)
	_check("remote driven tank blocks at its new position", s.position.x > 16.1 and s.position.x < 16.8)

	s.teleport(Vector3(40, 0.1, 40))
	driver.control = Soldier.Driver.BOT
	driver.teleport(Vector3(0, 0.1, 0))
	driver.velocity = Vector3.ZERO
	driver.wish = Vector3.FORWARD
	await _wait(1.5)
	_check("driver moves without hitting own hull (z=%.2f)" % driver.position.z, driver.position.z < -7.0)
	driver.wish = Vector3.ZERO
	driver.teleport(Vector3(0, 0.1, 0))
	driver.velocity = Vector3.ZERO
	driver.tank_speed = 0.0
	w.on_vehicle(2, 1, Vector3(0, 0, -14), 0.0, 800.0, 0)
	await _wait(0.1)
	driver.wish = Vector3.FORWARD
	await _wait(3.0)
	_check("full driving hull stops before another tank (z=%.2f)" % driver.position.z, driver.position.z > -7.5 and driver.position.z < -6.7)
	driver.wish = Vector3.ZERO
	driver.teleport(Vector3(0, 0.1, 0))
	driver.velocity = Vector3.ZERO
	driver.tank_speed = 0.0
	w.on_vehicle(2, 1, Vector3(4.8, 0, 0), 0.0, 800.0, 0)
	driver.control = Soldier.Driver.LOCAL
	driver.drive = Vector2(-1, 0)
	await _wait(1.2)
	_check("turning hull cannot overlap adjacent tank (yaw=%.2f)" % driver.hull_yaw, driver.hull_yaw > 0.1 and driver.hull_yaw < 0.5)
	driver.drive = Vector2.ZERO
	driver.wish = Vector3.ZERO
	driver.control = Soldier.Driver.PROXY_VIEW
	driver.teleport(Vector3(40, 0.1, 0))
	w.on_vehicle(2, 1, Vector3(0, 0, -14), 0.0, 0.0, 0)
	await _walk(s, Vector3(6, 0.1, -14), Vector3.LEFT, 1.8)
	_check("destroyed tank releases its collision", s.position.x < -2.0)
	w.on_vehicle(2, 1, Vector3(0, 0, -14), 0.0, 800.0, 0)
	await _walk(s, Vector3(6, 0.1, -14), Vector3.LEFT, 1.6)
	_check("respawned tank restores collision", s.position.x > 2.1 and s.position.x < 2.8)
	# Leaving a seat removes its exception, so the former driver cannot walk back inside.
	w.on_vehicle(1, 0, Vector3(40, 0, 0), 0.0, 800.0, 0)
	driver.become(0, 0.0)
	driver.control = Soldier.Driver.BOT
	await _walk(driver, Vector3(46, 0.1, 0), Vector3.LEFT, 1.6)
	_check("ex-driver collides after leaving", driver.position.x > 42.1 and driver.position.x < 42.8)
	print("[tank-collision] PASS %d, FAIL %d" % [passed, failed])
	get_tree().quit(0 if failed == 0 else 1)


func _soldier(id: int, pos: Vector3) -> Soldier:
	var s := Soldier.new()
	s.setup(w, id, 0, 0, "CollisionTester", Soldier.Driver.BOT)
	w.soldiers[id] = s
	w.add_child(s)
	s.respawn(pos, 0.0, 0)
	return s


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _walk(s: Soldier, from: Vector3, direction: Vector3, seconds: float) -> void:
	s.wish = Vector3.ZERO
	s.velocity = Vector3.ZERO
	s.teleport(from)
	await _wait(0.1)
	s.wish = direction
	await _wait(seconds)
	s.wish = Vector3.ZERO


func _check(label: String, ok: bool) -> void:
	passed += 1 if ok else 0
	failed += 0 if ok else 1
	print("[tank-collision] %s %s" % ["PASS" if ok else "FAIL", label])
