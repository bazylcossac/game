class_name MachineModel
extends SoldierModel
## What walkers and tanks have in common: Forge parts, a paint scheme per side, and armour
## that scorches as it takes damage and burns out when destroyed.

const WRECK_TIME := 11.0
## Hot embers fade from this down to plain char.
const WRECK_HEAT := 1.7

var _skin: Array[MeshInstance3D] = []
var _health := 1.0
var _heat := 0.0
var _power := 1.0
var _painted_burn := -1.0
var _painted_power := -1.0


## Builds every mesh ahead of time, so the first walker of a match does not stall the game.
static func warm() -> void:
	for team in 2:
		for script: GDScript in [MechModel, TankModel]:
			var m: MachineModel = script.new()
			m.setup(team)
			m.free()


## Mesh of one rigid part, shared by every machine of this side.
func part(parent: Node3D, key: String, build: Callable, pos := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = Forge.mesh("%s/%d/%s" % [get_script().get_global_name(), team, key], build)
	mi.material_override = Forge.skin(team)
	mi.position = pos
	parent.add_child(mi)
	_skin.append(mi)
	return mi


func set_health(fraction: float) -> void:
	if not is_equal_approx(fraction, _health):
		_health = fraction
		_refresh_paint()


func _start_wreck() -> void:
	_heat = WRECK_HEAT
	_power = 0.0
	_refresh_paint()


func _end_wreck() -> void:
	_heat = 0.0
	_power = 1.0
	_health = 1.0
	_refresh_paint()


func _cool(delta: float) -> void:
	if _heat > 1.0:
		_heat = maxf(_heat - delta * 0.12, 1.0)
		_refresh_paint()


## Writes only on change: instance parameters are not free to set every frame.
func _refresh_paint() -> void:
	# Scorching starts once half the armour is gone and never quite chars a live machine.
	var burn := _heat if _heat > 0.0 else clampf((0.6 - _health) * 0.9, 0.0, 0.42)
	if absf(burn - _painted_burn) < 0.01 and is_equal_approx(_power, _painted_power):
		return
	_painted_burn = burn
	_painted_power = _power
	for mi in _skin:
		mi.set_instance_shader_parameter("burn", burn)
		mi.set_instance_shader_parameter("power", _power)
