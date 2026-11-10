extends Node
## Pooled sound playback. All audio calls become no-ops on a headless server.

const POOL_3D := 48
const POOL_2D := 16
## Fast guns overlap their own tails, so they get voices that cannot cut off the interface.
const POOL_OWN := 12
## The close-up take of a shot, heard only by the one firing. Others get the muffled plain name.
const OWN_PREFIX := "own_"
## Sounds with several takes. Playing "name" picks one of "name_1" to "name_N".
const VARIANTS := {
	"laser_pistol": 3, "laser_rifle": 3, "laser_assault": 3, "laser_smg": 3, "laser_marksman": 3,
	"laser_revolver": 3, "laser_heavy": 3, "laser_plasma": 3, "laser_minigun": 3, "mech_launcher": 3, "thunder_near": 2, "thunder_far": 2, "laser_scatter": 3, "laser_sniper": 3, "laser_rail": 3,
	"laser_suppressed": 3, "mech_cannon": 3, "tank_fire": 2, "sword_swing": 3, "sword_clash": 2,
	"sword_hit": 2, "deflect": 2, "shield_hit": 3, "impact_wall": 3, "impact_body": 3, "explosion": 2,
	"death": 5, "hurt": 4, "droid_death": 3, "droid_hurt": 3,
}
## The same sound again within this many milliseconds adds noise, not impact.
const REPEAT_GAP_MS := 28

var enabled := true
var _streams := {}
var _pool3d: Array[AudioStreamPlayer3D] = []
var _pool2d: Array[AudioStreamPlayer] = []
var _i3 := 0
var _i2 := 0
var _pool_own: Array[AudioStreamPlayer] = []
var _i_own := 0
var _music: AudioStreamPlayer
var _ambient: AudioStreamPlayer
var _hum: AudioStreamPlayer
var _hum_level := 0.0
var _hum_target := 0.0
var _hum_pitch := 1.0
var _last_played := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	enabled = DisplayServer.get_name() != "headless"
	if not enabled:
		return
	for bus_name: String in ["SFX", "Music", "World"]:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "SFX" if bus_name == "World" else "Master")
	# A little space around everything in the world, and a limiter so a battle cannot clip.
	var verb := AudioEffectReverb.new()
	verb.room_size = 0.55
	verb.damping = 0.6
	verb.wet = 0.1
	verb.dry = 1.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index("World"), verb)
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = -1.0
	AudioServer.add_bus_effect(0, limiter)
	for i in POOL_3D:
		var p := AudioStreamPlayer3D.new()
		p.bus = "World"
		p.unit_size = 17.0
		p.max_distance = 360.0
		p.attenuation_filter_cutoff_hz = 7000.0
		p.attenuation_filter_db = -8.0
		add_child(p)
		_pool3d.append(p)
	for i in POOL_2D:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool2d.append(p)
	for i in POOL_OWN:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool_own.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	_music.finished.connect(_music.play)  # Imported WAVs are not loop-flagged, so loop by hand.
	_ambient = AudioStreamPlayer.new()
	_ambient.bus = "SFX"
	add_child(_ambient)
	_ambient.finished.connect(_ambient.play)
	_hum = AudioStreamPlayer.new()
	_hum.bus = "SFX"
	_hum.volume_db = -60.0
	add_child(_hum)
	Settings.apply_audio()


func _process(delta: float) -> void:
	if not enabled or _hum == null:
		return
	_hum_level = move_toward(_hum_level, _hum_target, delta * 5.0)
	if _hum_level <= 0.001:
		if _hum.playing:
			_hum.stop()
		return
	if not _hum.playing:
		_hum.stream = _looping("sword_hum")
		_hum.play()
	_hum.volume_db = linear_to_db(_hum_level) - 14.0
	_hum.pitch_scale = lerpf(_hum.pitch_scale, _hum_pitch, minf(delta * 12.0, 1.0))


## The blade's steady hum. `swing` from 0 to 1 bends it up as the blade moves fast.
func blade_hum(on: bool, swing := 0.0) -> void:
	_hum_target = (0.7 + clampf(swing, 0.0, 1.0) * 0.6) if on else 0.0
	_hum_pitch = 1.0 + clampf(swing, 0.0, 1.0) * 0.4


func _looping(sound: String) -> AudioStream:
	var s := _stream(sound).duplicate() as AudioStreamWAV
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = int(s.get_length() * s.mix_rate)
	return s


func _take(sound: String) -> String:
	var takes: int = VARIANTS.get(sound.trim_prefix(OWN_PREFIX), 0)
	return sound if takes == 0 else "%s_%d" % [sound, randi_range(1, takes)]


func _too_soon(sound: String) -> bool:
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(sound, -9999)) < REPEAT_GAP_MS:
		return true
	_last_played[sound] = now
	return false


func _stream(sound: String) -> AudioStream:
	if not _streams.has(sound):
		_streams[sound] = load("res://assets/audio/%s.wav" % sound)
	return _streams[sound]


## Reads every sound in advance, so nothing touches the disk in the middle of a firefight.
func preload_all() -> void:
	if not enabled:
		return
	for file: String in DirAccess.get_files_at("res://assets/audio"):
		if file.get_extension() == "import":
			_stream(file.get_basename().get_basename())


func play(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	if not enabled:
		return
	if _too_soon(sound):
		return
	var p := _pool2d[_i2]
	_i2 = (_i2 + 1) % POOL_2D
	p.stream = _stream(_take(sound))
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


## A shot from the local player's own gun, close-up and in stereo.
func play_own(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	if not enabled:
		return
	var own := OWN_PREFIX + sound
	if _too_soon(own):
		return
	var p := _pool_own[_i_own]
	_i_own = (_i_own + 1) % POOL_OWN
	p.stream = _stream(_take(own))
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


func play_at(sound: String, pos: Vector3, volume_db := 0.0, pitch := 1.0) -> void:
	if not enabled:
		return
	if _too_soon(sound):
		return
	var p := _pool3d[_i3]
	_i3 = (_i3 + 1) % POOL_3D
	p.stream = _stream(_take(sound))
	p.global_position = pos
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


func play_music(sound: String) -> void:
	if not enabled:
		return
	_music.stream = _stream(sound)
	_music.volume_db = 0.0
	_music.play()


func stop_music(fade := 1.0) -> void:
	if not enabled or not _music.playing:
		return
	var tw := create_tween()
	tw.tween_property(_music, "volume_db", -50.0, fade)
	tw.tween_callback(func() -> void:
		_music.stream = null
		_music.stop())


func play_ambient(sound: String, volume_db := -6.0) -> void:
	if not enabled:
		return
	_ambient.stream = _stream(sound)
	_ambient.volume_db = volume_db
	_ambient.play()


func stop_ambient() -> void:
	if enabled:
		_ambient.stream = null
		_ambient.stop()
