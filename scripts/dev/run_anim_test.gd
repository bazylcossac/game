extends Node
## `--test=run-anim`, headless: the first-person sprint. A gun is lowered and turned in, and sways
## across, bobs and rolls with every stride; a blade is pulled in close to the body at a slant and
## pumps with the arm. Neither moves like that standing or walking, and both settle back once the
## sprint ends.
const DT := 1.0 / 60.0
const WALK := 4.5
const SPRINT := 8.0

var passed := 0
var failed := 0
var vm: ViewModel


func _ready() -> void:
	vm = ViewModel.new()
	add_child(vm)
	vm.setup(C.Team.RESISTANCE)
	await get_tree().process_frame
	for id: int in [C.W.CARBINE, C.W.PISTOL, C.W.MINIGUN]:
		_gun(id)
	for id: int in [C.W.SWORD, C.W.LIGHTSABER, C.W.GREATSWORD]:
		_blade(id)
	print("[run-anim] PASS %d, FAIL %d" % [passed, failed])
	get_tree().quit(0 if failed == 0 else 1)


func _gun(id: int) -> void:
	var name := "gun %d" % id
	vm.set_weapon(id)
	_run(1.0, false, 0.0)
	var still := _run(1.0, false, 0.0)
	var walk := _run(1.5, false, WALK)
	_run(0.5, true, SPRINT)
	var sprint := _run(1.5, true, SPRINT)
	_check("%s: standing, the gun barely moves (%.3f)" % [name, still["pos_span"].x], still["pos_span"].x < 0.01)
	_check("%s: walking sways a little (%.3f)" % [name, walk["pos_span"].x], walk["pos_span"].x < 0.03)
	_check("%s: sprinting swings it side to side (%.3f)" % [name, sprint["pos_span"].x], sprint["pos_span"].x > 0.05)
	_check("%s: and up and down (%.3f)" % [name, sprint["pos_span"].y], sprint["pos_span"].y > 0.035)
	_check("%s: and rolls it (%.2f rad)" % [name, sprint["rot_span"].z], sprint["rot_span"].z > 0.25)
	_check("%s: the muzzle dips with each step (%.2f rad)" % [name, sprint["rot_span"].x], sprint["rot_span"].x > 0.08)
	_check("%s: sprinting holds it low and turned in (%.2f rad, %.3f m lower)" % [name, sprint["rot_mean"].y, still["pos_mean"].y - sprint["pos_mean"].y], sprint["rot_mean"].y > 0.6 and sprint["pos_mean"].y < still["pos_mean"].y - 0.04)
	_run(0.5, false, 0.0)
	var after := _run(1.0, false, 0.0)
	_check("%s: back at the hip after the sprint (%.3f rad, %.3f m)" % [name, after["rot_mean"].distance_to(still["rot_mean"]), after["pos_mean"].distance_to(still["pos_mean"])], after["rot_mean"].distance_to(still["rot_mean"]) < 0.03 and after["pos_mean"].distance_to(still["pos_mean"]) < 0.01)


func _blade(id: int) -> void:
	var name := "blade %d" % id
	vm.set_weapon(id)
	_run(1.0, false, 0.0)
	var still := _run(1.0, false, 0.0)
	# The same cut from standing, to compare the cut out of a sprint with.
	vm.play_swing()
	var base_cut := _run(1.0, false, 0.0)
	_run(0.5, true, SPRINT)
	var sprint := _run(1.5, true, SPRINT)
	var rest_pos: Vector3 = still["pos_mean"]
	var run_pos: Vector3 = sprint["pos_mean"]
	_check("%s: sprinting pulls it in to the body (%.2f -> %.2f m)" % [name, rest_pos.length(), run_pos.length()], run_pos.z > rest_pos.z + 0.12 and run_pos.length() < rest_pos.length() - 0.08)
	var slant: Vector3 = sprint["rot_mean"] - still["rot_mean"]
	_check("%s: at a slant (%.2f, %.2f rad)" % [name, slant.x, slant.z], slant.x > 0.4 and slant.z < -0.4)
	_check("%s: the arm pumps with the stride (%.3f m, %.2f rad)" % [name, sprint["pos_span"].z, sprint["rot_span"].x], sprint["pos_span"].z > 0.06 and sprint["rot_span"].x > 0.2)
	_check("%s: the tip stays in front of the eyes (%.2f)" % [name, sprint["tip_max_z"]], sprint["tip_max_z"] < -0.05)
	# On a 16:9 screen, the edges at +-1: the hand at the bottom edge, the blade up to the right.
	var hand: Vector2 = sprint["hand_low"]
	var tip: Vector2 = sprint["tip_far"]
	_check("%s: the hand stays at the bottom of the screen (%.2f, %.2f)" % [name, hand.x, hand.y], hand.y > -1.05 and hand.x > 0.1)
	_check("%s: the tip stays on screen, right of the crosshair (%.2f, %.2f)" % [name, tip.x, tip.y], tip.x < 0.97 and sprint["tip_left"] > 0.15)
	# A cut ends the sprint: it comes out of the carry and back to rest without a jump.
	vm.play_swing()
	var cut := _run(1.0, false, 0.0)
	_check("%s: a cut out of the sprint moves as smoothly as one from standing (largest step %.3f m, %.3f m)" % [name, cut["max_step"], base_cut["max_step"]], cut["max_step"] < base_cut["max_step"] * 1.15 + 0.01)
	_check("%s: back at rest after the cut (%.3f m)" % [name, cut["last_pos"].distance_to(rest_pos)], cut["last_pos"].distance_to(rest_pos) < 0.01)


## Runs the view model for `seconds` and measures the weapon holder: means and spans of its
## position and rotation, the largest jump between frames and how near the blade tip comes.
func _run(seconds: float, sprinting: bool, speed: float) -> Dictionary:
	var lo_p := Vector3.INF
	var hi_p := -Vector3.INF
	var lo_r := Vector3.INF
	var hi_r := -Vector3.INF
	var sum_p := Vector3.ZERO
	var sum_r := Vector3.ZERO
	var max_step := 0.0
	var tip_max_z := -INF
	var hand_low := Vector2(0.0, INF)
	var tip_far := Vector2(-INF, 0.0)
	var tip_left := INF
	var last := vm.holder.position
	var frames := int(seconds / DT)
	for i in frames:
		vm.animate(DT, false, false, sprinting, speed, true)
		var p := vm.holder.position
		var r := vm.holder.rotation
		lo_p = lo_p.min(p)
		hi_p = hi_p.max(p)
		lo_r = lo_r.min(r)
		hi_r = hi_r.max(r)
		sum_p += p
		sum_r += r
		max_step = maxf(max_step, p.distance_to(last))
		last = p
		var tip := vm.gun.get_node_or_null("Muzzle") as Node3D if vm.gun else null
		if tip:
			var at := vm.to_local(tip.global_position)
			tip_max_z = maxf(tip_max_z, at.z)
			var on_tip := _screen(at)
			if on_tip.x > tip_far.x:
				tip_far = on_tip
			tip_left = minf(tip_left, on_tip.x)
			var on_hand := _screen(p)
			if on_hand.y < hand_low.y:
				hand_low = on_hand
	return {
		"pos_span": hi_p - lo_p, "rot_span": hi_r - lo_r, "pos_mean": sum_p / frames,
		"rot_mean": sum_r / frames, "max_step": max_step, "tip_max_z": tip_max_z, "last_pos": last,
		"hand_low": hand_low, "tip_far": tip_far, "tip_left": tip_left,
	}


## Where a point in view space lands on a 16:9 screen, -1..1 across, drawn with the first-person
## field of view.
func _screen(at: Vector3) -> Vector2:
	var t := tan(deg_to_rad(Mats.VIEWMODEL_FOV * 0.5))
	return Vector2(at.x / (-at.z * t * 16.0 / 9.0), at.y / (-at.z * t))


func _check(label: String, ok: bool) -> void:
	passed += 1 if ok else 0
	failed += 0 if ok else 1
	print("[run-anim] %s %s" % ["PASS" if ok else "FAIL", label])
