extends SceneTree
## Trusted, standalone ENet query. Does not join a match or load game scripts.
var api := SceneMultiplayer.new()
var peer := ENetMultiplayerPeer.new()
var elapsed := 0.0
var expected := ""

func _initialize() -> void:
	var port := 7777
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--port="):
			port = int(arg.trim_prefix("--port="))
		if arg.begins_with("--version="):
			expected = arg.trim_prefix("--version=")
	api.auth_callback = _reply
	api.auth_timeout = 8.0
	api.peer_authenticating.connect(func(_id: int) -> void: api.send_auth(1, PackedByteArray([2])))
	if peer.create_client("127.0.0.1", port) != OK:
		quit(1)
	api.multiplayer_peer = peer

func _process(delta: float) -> bool:
	api.poll()
	elapsed += delta
	if elapsed > 6.0:
		peer.close()
		quit(1)
	return false

func _reply(_id: int, data: PackedByteArray) -> void:
	var info: Variant = JSON.parse_string(data.get_string_from_utf8())
	if info is Dictionary and not String(info.get("version", "")).is_empty():
		if expected.is_empty() or info.get("version") == expected:
			print("PANEL_HEALTH=" + JSON.stringify(info))
			peer.close()
			quit(0)
			return
	peer.close()
	quit(1)
