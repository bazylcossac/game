class_name MenuBackdrop
extends Node3D
## A slow drift down the wet boulevard of Corp City at night, under Korpo's adverts, with laser fire
## crossing the street far ahead.

var _camera := Camera3D.new()
var _fx: Fx
var _t := 0.0
var _shot_t := 1.0


func _ready() -> void:
	var map := NeonMap.new("menu")
	map.build(self, Modes.DEFAULT_SEED, false)
	Atmos.setup(self, "neonowa_dzielnica")
	_fx = Fx.new()
	add_child(_fx)
	_camera.fov = 58.0
	_camera.far = 900.0
	add_child(_camera)
	_camera.current = true


func _process(delta: float) -> void:
	_t += delta * 0.03
	var from := Vector3(-17.0 + sin(_t) * 5.0, 6.5 + sin(_t * 0.7) * 1.8, 150.0 - sin(_t * 0.5) * 40.0)
	_camera.global_position = from
	_camera.look_at(Vector3(sin(_t * 0.6) * 14.0, 9.0, 20.0), Vector3.UP)
	_shot_t -= delta
	if _shot_t <= 0.0:
		_shot_t = randf_range(0.15, 1.2)
		var team := randi_range(0, 1)
		var z := randf_range(30.0, 90.0)
		var x := randf_range(-28.0, 28.0)
		var a := Vector3(x, randf_range(1.0, 5.0), z + (18.0 if team == 0 else -18.0))
		var b := Vector3(x + randf_range(-16.0, 16.0), randf_range(1.0, 5.0), z + (-18.0 if team == 0 else 18.0))
		_fx.spawn_shot(C.W.CARBINE, team, a, b, 0)
