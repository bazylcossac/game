class_name TankCollider
extends AnimatableBody3D
## A physical hull, separate from the rendered model and the driver's movement capsule.
## Exists on headless servers too. Combat still uses its existing lag-compensated hit boxes.

const CENTER := Vector3(0, 1.3, 0)

var hull_shape := BoxShape3D.new()
var _driver: Soldier


func setup(team: int, class_id := C.VEHICLE_CLASS) -> void:
	collision_layer = 0
	collision_mask = 0
	sync_to_physics = false
	hull_shape.size = C.cls(team, class_id)["hit_box"] * 2.0
	var cs := CollisionShape3D.new()
	cs.shape = hull_shape
	cs.position = CENTER
	add_child(cs)


func update_hull(pos: Vector3, yaw: float, intact: bool, driver: Soldier) -> void:
	if _driver != driver:
		if is_instance_valid(_driver):
			_driver.remove_collision_exception_with(self)
		_driver = driver
		if is_instance_valid(_driver):
			_driver.add_collision_exception_with(self)
	global_transform = Transform3D(Basis(Vector3.UP, yaw), pos)
	collision_layer = C.LAYER_VEHICLE if intact else 0


## The movement capsule is shorter than a hull: sweep the full hull against other tanks
## before driving, while the capsule continues handling slopes and world geometry.
func travel_fraction(motion: Vector3) -> float:
	if motion.length_squared() < 0.000001:
		return 1.0
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = hull_shape
	q.transform = global_transform.translated_local(CENTER)
	q.motion = motion
	q.collision_mask = C.LAYER_VEHICLE | C.LAYER_FORT
	q.exclude = [get_rid()]
	q.margin = 0.04
	var result := get_world_3d().direct_space_state.cast_motion(q)
	if result[0] < 1.0 and is_instance_valid(_driver) and _driver.world.forts and Net.is_server():
		q.transform.origin += motion * minf(result[0] + .02, 1.0)
		for hit: Dictionary in get_world_3d().direct_space_state.intersect_shape(q, 2):
			var id := int(hit["collider"].get_meta("fort_id", 0))
			if id > 0:
				_driver.world.forts.damage(id, motion.length() * 80.0, _driver, true)
	return result[0]


func can_face(pos: Vector3, yaw: float) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = hull_shape
	q.transform = Transform3D(Basis(Vector3.UP, yaw), pos + CENTER)
	q.collision_mask = C.LAYER_VEHICLE | C.LAYER_FORT
	q.exclude = [get_rid()]
	q.margin = 0.005
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()
