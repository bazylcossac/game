extends Node
## Transport layer. The match always runs "on a server": offline play is simply a
## server with no remote peers, so a dedicated VPS build needs no separate game logic.

signal world_requested(cfg: Dictionary)
## The server let this client in and is waiting for it to pick a side. `counts` is players per side.
signal side_requested(cfg: Dictionary, counts: Array)
signal connect_failed(reason: String)
signal session_ended(reason: String)

enum Mode { NONE, OFFLINE, HOST, CLIENT, DEDICATED }

const INTERP_DELAY := 0.1
## First byte a connecting machine sends: a player coming in, or a server list asking for details.
const AUTH_JOIN := 1
const AUTH_INFO := 2

var mode: int = Mode.NONE
var world: World = null
var my_name := ""
## What the server list shows for this server. Empty leaves the name the list already has.
var server_name := ""

## The side this client plays, and the match it is holding back until the player picks one.
var _side := 0
var _picks_side := false
var _welcome_cfg := {}

var _clock_offset := 0.0
var _clock_synced := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(_on_server_lost)
	# Everyone passes through here first, so a server list can ask about a server on the game's
	# own port without becoming a player or receiving the match.
	var api := multiplayer as SceneMultiplayer
	api.auth_callback = _on_auth
	api.peer_authenticating.connect(_on_authenticating)


func is_server() -> bool:
	return mode == Mode.OFFLINE or mode == Mode.HOST or mode == Mode.DEDICATED


func is_networked() -> bool:
	return mode == Mode.HOST or mode == Mode.CLIENT or mode == Mode.DEDICATED


## True when this process renders the game and has a local player.
func has_view() -> bool:
	return mode == Mode.OFFLINE or mode == Mode.HOST or mode == Mode.CLIENT


func local_time() -> float:
	return Time.get_ticks_usec() / 1000000.0


func server_time() -> float:
	return local_time() + (0.0 if is_server() else _clock_offset)


func sync_clock(remote_time: float) -> void:
	var offset := remote_time - local_time()
	if not _clock_synced:
		_clock_offset = offset
		_clock_synced = true
	else:
		_clock_offset = lerpf(_clock_offset, offset, 0.05)


# ---------------------------------------------------------------- session control

func start_offline(cfg: Dictionary) -> void:
	_reset()
	mode = Mode.OFFLINE
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	world_requested.emit(cfg)


func start_host(cfg: Dictionary, port: int) -> Error:
	_reset()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, C.MAX_PLAYERS + C.QUERY_SLOTS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	mode = Mode.HOST
	world_requested.emit(cfg)
	return OK


func start_dedicated(cfg: Dictionary, port: int) -> Error:
	_reset()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, C.MAX_PLAYERS + C.QUERY_SLOTS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	mode = Mode.DEDICATED
	world_requested.emit(cfg)
	return OK


## With `pick_side` the match waits for `choose_side`. Without it this client plays `Settings.side`.
func start_client(address: String, port: int, player_name: String, pick_side := false) -> Error:
	_reset()
	my_name = player_name
	_side = Settings.side
	_picks_side = pick_side
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	mode = Mode.CLIENT
	return OK


func leave() -> void:
	_reset()


## The player picked a side after joining: now the map can load.
func choose_side(team: int) -> void:
	if _welcome_cfg.is_empty():
		return
	_side = clampi(team, 0, 1)
	var cfg := _welcome_cfg
	_welcome_cfg = {}
	world_requested.emit(cfg)


## Round-trip time to a connected player in ms, or -1 when there is none to measure.
func ping_of(peer: int) -> int:
	if peer == multiplayer.get_unique_id():
		return 0
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	var link := enet.get_peer(peer) if enet else null
	return int(link.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)) if link else -1


func _reset() -> void:
	mode = Mode.NONE
	_picks_side = false
	_welcome_cfg = {}
	_clock_synced = false
	_clock_offset = 0.0
	world = null
	if multiplayer.multiplayer_peer != null and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


## A client introduces itself to the server as soon as the link is up.
func _on_authenticating(id: int) -> void:
	if mode == Mode.CLIENT and id == 1:
		var api := multiplayer as SceneMultiplayer
		api.send_auth(1, PackedByteArray([AUTH_JOIN]))
		api.complete_auth(1)


## On the server: lets a player in, or answers a server list and leaves it waiting at the door.
func _on_auth(id: int, data: PackedByteArray) -> void:
	if not is_server() or data.is_empty():
		return
	var api := multiplayer as SceneMultiplayer
	if data[0] == AUTH_JOIN:
		api.complete_auth(id)
	elif data[0] == AUTH_INFO:
		api.send_auth(id, JSON.stringify(_server_info()).to_utf8_buffer())


func _server_info() -> Dictionary:
	var info := {"name": server_name, "version": C.VERSION}
	if _server():
		var counts := _server().team_counts()
		info["mode"] = String(world.cfg["mode"])
		info["map"] = String(world.cfg["map"])
		info["players"] = int(counts[0]) + int(counts[1])
		info["max"] = _server().player_limit()
	return info


func _on_peer_connected(_id: int) -> void:
	pass


func _on_peer_disconnected(id: int) -> void:
	if is_server() and world and world.server:
		world.server.remove_human(id)


func _on_connected() -> void:
	c_hello.rpc_id(1, my_name, C.VERSION, Settings.token)


func _on_failed() -> void:
	_reset()
	connect_failed.emit("Nie udało się połączyć z serwerem.")


func _on_server_lost() -> void:
	_reset()
	session_ended.emit("Utracono połączenie z serwerem.")


# ---------------------------------------------------------------- server -> client

## Runs an `on_<event>` handler on this machine and on every connected client.
func broadcast(event: StringName, args: Array, reliable := true) -> void:
	if world:
		world.handle_event(event, args)
	if mode == Mode.HOST or mode == Mode.DEDICATED:
		if reliable:
			s_event.rpc(event, args)
		else:
			s_event_fast.rpc(event, args)


## Like broadcast, but for clients only. Use when the server already applied the change.
func broadcast_remote(event: StringName, args: Array, reliable := true) -> void:
	if mode == Mode.HOST or mode == Mode.DEDICATED:
		if reliable:
			s_event.rpc(event, args)
		else:
			s_event_fast.rpc(event, args)


## Sends an event to the machine that owns a soldier. Bots are silently skipped.
func send_to_owner(s: Soldier, event: StringName, args: Array) -> void:
	if s.peer == 0:
		return
	if s.peer == multiplayer.get_unique_id():
		if world:
			world.handle_event(event, args)
	elif mode == Mode.HOST or mode == Mode.DEDICATED:
		s_event.rpc_id(s.peer, event, args)


func send_snapshot(data: PackedByteArray) -> void:
	if mode == Mode.HOST or mode == Mode.DEDICATED:
		s_snapshot.rpc(data)


@rpc("authority", "call_remote", "reliable", 1)
func s_welcome(cfg: Dictionary, counts: Array) -> void:
	if _picks_side and not Modes.mode_of(Modes.normalize(cfg)).get("ffa", false):
		_welcome_cfg = cfg
		side_requested.emit(cfg, counts)
	else:
		world_requested.emit(cfg)


@rpc("authority", "call_remote", "reliable", 1)
func s_rejected(reason: String) -> void:
	_reset()
	connect_failed.emit(reason)


@rpc("authority", "call_remote", "reliable", 1)
func s_event(event: StringName, args: Array) -> void:
	if world:
		world.handle_event(event, args)


@rpc("authority", "call_remote", "unreliable_ordered", 2)
func s_event_fast(event: StringName, args: Array) -> void:
	if world:
		world.handle_event(event, args)


@rpc("authority", "call_remote", "unreliable_ordered", 3)
func s_snapshot(data: PackedByteArray) -> void:
	if world:
		world.apply_snapshot(data)


# ---------------------------------------------------------------- client -> server
# Each send_* helper short-circuits on the server, so offline and host players take the
# same code path as remote players without a network hop.

func _sender() -> int:
	return multiplayer.get_remote_sender_id()


func _server() -> MatchServer:
	return world.server if world else null


@rpc("any_peer", "call_remote", "reliable", 1)
func c_hello(player_name: String, version: String, token: String) -> void:
	if not is_server():
		return
	var peer := _sender()
	if version != C.VERSION:
		s_rejected.rpc_id(peer, T.pack("Niezgodna wersja gry (serwer: %s).", [C.VERSION]))
		return
	if _server() and _server().is_full():
		_reject_full(peer)
		return
	if _server():
		_server().pending_names[peer] = player_name.strip_edges().left(20)
		_server().pending_tokens[peer] = token.left(64)
		s_welcome.rpc_id(peer, world.cfg, _server().team_counts())


func _reject_full(peer: int) -> void:
	s_rejected.rpc_id(peer, T.pack("Serwer jest pełny: ten tryb ma %d miejsc dla graczy.", [_server().player_limit()]))


## The client finished building the map and is ready to receive game events.
func send_ready() -> void:
	if is_server():
		_server().add_human(multiplayer.get_unique_id(), Settings.player_name, Settings.token, Settings.side)
	else:
		c_ready.rpc_id(1, _side)


@rpc("any_peer", "call_remote", "reliable", 1)
func c_ready(side: int) -> void:
	if not is_server() or not _server():
		return
	var peer := _sender()
	# Someone else may have taken the last place while this player was picking a side.
	if _server().is_full():
		_reject_full(peer)
		return
	_server().add_human(peer, String(_server().pending_names.get(peer, "Gracz")), String(_server().pending_tokens.get(peer, "")), side)


func send_deploy(class_id: int, spawn_flag: int, kit: Dictionary = {}) -> void:
	if is_server():
		_server().sv_deploy(multiplayer.get_unique_id(), class_id, spawn_flag, kit)
	else:
		c_deploy.rpc_id(1, class_id, spawn_flag, kit)


@rpc("any_peer", "call_remote", "reliable", 1)
func c_deploy(class_id: int, spawn_flag: int, kit: Dictionary) -> void:
	if is_server() and _server():
		_server().sv_deploy(_sender(), class_id, spawn_flag, kit)


## Gives up this life, so the player can deploy again with another class.
func send_respawn() -> void:
	if is_server():
		_server().sv_respawn(multiplayer.get_unique_id())
	else:
		c_respawn.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable", 1)
func c_respawn() -> void:
	if is_server() and _server():
		_server().sv_respawn(_sender())


func send_state(pos: Vector3, yaw: float, pitch: float, flags: int, slot: int, hull: float) -> void:
	if not is_server():
		c_state.rpc_id(1, pos, yaw, pitch, flags, slot, hull)


@rpc("any_peer", "call_remote", "unreliable_ordered", 2)
func c_state(pos: Vector3, yaw: float, pitch: float, flags: int, slot: int, hull: float) -> void:
	if is_server() and _server():
		_server().sv_state(_sender(), pos, yaw, pitch, flags, slot, hull)


func send_fire(slot: int, origin: Vector3, dir: Vector3, view_time: float) -> void:
	if is_server():
		_server().sv_fire(multiplayer.get_unique_id(), slot, origin, dir, view_time)
	else:
		c_fire.rpc_id(1, slot, origin, dir, view_time)


@rpc("any_peer", "call_remote", "reliable", 4)
func c_fire(slot: int, origin: Vector3, dir: Vector3, view_time: float) -> void:
	if is_server() and _server():
		_server().sv_fire(_sender(), slot, origin, dir, view_time)


func send_swing(dir: Vector3, view_time: float) -> void:
	if is_server():
		_server().sv_swing(multiplayer.get_unique_id(), dir, view_time)
	else:
		c_swing.rpc_id(1, dir, view_time)


@rpc("any_peer", "call_remote", "reliable", 4)
func c_swing(dir: Vector3, view_time: float) -> void:
	if is_server() and _server():
		_server().sv_swing(_sender(), dir, view_time)


func send_transform(class_id: int) -> void:
	if is_server():
		_server().sv_transform(multiplayer.get_unique_id(), class_id)
	else:
		c_transform.rpc_id(1, class_id)


@rpc("any_peer", "call_remote", "reliable", 4)
func c_transform(class_id: int) -> void:
	if is_server() and _server():
		_server().sv_transform(_sender(), class_id)


func send_use() -> void:
	if is_server():
		_server().sv_use(multiplayer.get_unique_id())
	else:
		c_use.rpc_id(1)


func send_build(kind: int, pos: Vector3, yaw: float) -> void:
	if is_server():
		_server().sv_build(multiplayer.get_unique_id(), kind, pos, yaw)
	else:
		c_build.rpc_id(1, kind, pos, yaw)


@rpc("any_peer", "call_remote", "reliable", 4)
func c_build(kind: int, pos: Vector3, yaw: float) -> void:
	if is_server() and _server():
		_server().sv_build(_sender(), kind, pos, yaw)


## `action` is 0 to create, 1 to join squad `id`, 2 to leave.
func send_squad(action: int, id: int) -> void:
	if is_server():
		_server().sv_squad(multiplayer.get_unique_id(), action, id)
	else:
		c_squad.rpc_id(1, action, id)


@rpc("any_peer", "call_remote", "reliable", 4)
func c_squad(action: int, id: int) -> void:
	if is_server() and _server():
		_server().sv_squad(_sender(), action, id)


func send_strike(target: Vector3) -> void:
	if is_server():
		_server().sv_strike(multiplayer.get_unique_id(), target)
	else:
		c_strike.rpc_id(1, target)


@rpc("any_peer", "call_remote", "reliable", 4)
func c_strike(target: Vector3) -> void:
	if is_server() and _server():
		_server().sv_strike(_sender(), target)


func send_beacon() -> void:
	if is_server():
		_server().sv_beacon(multiplayer.get_unique_id())
	else:
		c_beacon.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable", 4)
func c_beacon() -> void:
	if is_server() and _server():
		_server().sv_beacon(_sender())


func send_switch_seat() -> void:
	if is_server():
		_server().sv_switch_seat(multiplayer.get_unique_id())
	else:
		c_switch_seat.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable", 4)
func c_switch_seat() -> void:
	if is_server() and _server():
		_server().sv_switch_seat(_sender())


@rpc("any_peer", "call_remote", "reliable", 4)
func c_use() -> void:
	if is_server() and _server():
		_server().sv_use(_sender())


@rpc("any_peer", "call_remote", "reliable", 4)


func send_reload() -> void:
	if not is_server():
		c_reload.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable", 4)
func c_reload() -> void:
	if is_server() and _server():
		_server().sv_reload(_sender())


func send_grenade(origin: Vector3, dir: Vector3, kind: int) -> void:
	if is_server():
		_server().sv_grenade(multiplayer.get_unique_id(), origin, dir, kind)
	else:
		c_grenade.rpc_id(1, origin, dir, kind)


@rpc("any_peer", "call_remote", "reliable", 4)
func c_grenade(origin: Vector3, dir: Vector3, kind: int) -> void:
	if is_server() and _server():
		_server().sv_grenade(_sender(), origin, dir, kind)
