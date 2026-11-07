class_name ServerProbe
extends Node
## Asks one server what it is playing and how far away it is. It uses the game's own port and
## stops at the door (see `Net._on_auth`), so it needs no extra firewall rule and never joins.

## `info` holds what the server said, with "ping" in ms. "reached" is true when the server was
## there at all: one that is there and says nothing runs a version without a server list.
signal answered(info: Dictionary)

const TIMEOUT := 3.0
## The best of a few answers, so one late frame on either side does not read as lag.
const SAMPLES := 3

var _api := SceneMultiplayer.new()
var _link := ENetMultiplayerPeer.new()
var _left := TIMEOUT
var _sent_at := 0
var _samples := 0
var _info := {"reached": false, "ping": -1}
var _done := false


func ask(address: String, port: int) -> void:
	_api.auth_callback = _on_reply
	_api.auth_timeout = TIMEOUT + 1.0
	_api.peer_authenticating.connect(_on_reached)
	_api.connection_failed.connect(_stop)
	if _link.create_client(address, port) != OK:
		_stop()
		return
	_api.multiplayer_peer = _link


func _process(delta: float) -> void:
	if _api.multiplayer_peer != null:
		_api.poll()
	_left -= delta
	if _done or _left <= 0.0:
		set_process(false)
		_link.close()
		answered.emit(_info)
		queue_free()


func _exit_tree() -> void:
	_link.close()


func _stop() -> void:
	_done = true


func _on_reached(_id: int) -> void:
	_info["reached"] = true
	_ask_again()


func _ask_again() -> void:
	_sent_at = Time.get_ticks_usec()
	_api.send_auth(1, PackedByteArray([Net.AUTH_INFO]))


func _on_reply(_id: int, data: PackedByteArray) -> void:
	var ms := int((Time.get_ticks_usec() - _sent_at) / 1000.0)
	_info["ping"] = ms if _samples == 0 else mini(int(_info["ping"]), ms)
	_samples += 1
	var said: Variant = JSON.parse_string(data.get_string_from_utf8())
	if said is Dictionary:
		_info.merge(said, true)
	if _samples >= SAMPLES:
		_stop()
	else:
		_ask_again()
