class_name MenuBackdrop
extends Node3D
## Slow camera move through the real map, with distant laser fire crossing the frame.

var _camera := Camera3D.new()
var _fx: Fx
var _t := 0.0
var _shot_t := 1.0


func _ready() -> void:
	var map := CityMap.new()
	map.build(self, 1943, false)
	Atmos.setup(self)
	_fx = Fx.new()
	add_child(_fx)
	for p: Vector3 in map.fires:
		_fx.add_fire(p)
	for p: Vector3 in map.smokes:
		_fx.add_smoke(p)
	_camera.fov = 58.0
	_camera.far = 2600.0
	add_child(_camera)
	_camera.current = true
	_fx.add_ash(_camera)


func _process(delta: float) -> void:
	_t += delta * 0.022
	var from := Vector3(-14.0 + sin(_t) * 22.0, 7.0 + sin(_t * 0.7) * 1.5, 46.0 + cos(_t) * 8.0)
	_camera.global_position = from
	_camera.look_at(Vector3(sin(_t * 0.6) * 30.0 + 30.0, 7.0, -40.0), Vector3.UP)
	_shot_t -= delta
	if _shot_t <= 0.0:
		_shot_t = randf_range(0.12, 1.1)
		var team := randi_range(0, 1)
		var z := -30.0 + randf_range(-30.0, 10.0)
		var x := randf_range(-60.0, 80.0)
		var a := Vector3(x, randf_range(1.0, 7.0), z + (24.0 if team == 0 else -24.0))
		var b := Vector3(x + randf_range(-20.0, 20.0), randf_range(1.0, 7.0), z + (-24.0 if team == 0 else 24.0))
		_fx.spawn_shot(C.W.CARBINE, team, a, b, 0)
