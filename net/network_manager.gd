extends Node
## Wraps ENetMultiplayerPeer: transport, connection, local direct-connect.
## Server-authoritative model -- see
## docs/blueprint/03-networking-and-match-modes.md. Pattern inherited from
## amazing-nauts' net/network_manager.gd. Matchmaking/dedicated-server
## infrastructure is out of scope for Phase 1 (direct connect only).

const DEFAULT_PORT := 7777
const MAX_CLIENTS := 8

var peer: ENetMultiplayerPeer

## Dev-only artificial network latency (milliseconds, one-way), for local
## testing without OS-level tools. Delays the *application* of outgoing
## input / incoming snapshot effects, not the real transport packets
## themselves (instant on loopback regardless).
var artificial_latency_ms: int = 0

var _delayed_calls: Array[Dictionary] = []
var _elapsed_time: float = 0.0


func _ready() -> void:
	multiplayer.server_disconnected.connect(close)
	multiplayer.connection_failed.connect(close)


func host(port: int = DEFAULT_PORT, max_clients: int = MAX_CLIENTS) -> Error:
	var new_peer := ENetMultiplayerPeer.new()
	var err := new_peer.create_server(port, max_clients)
	if err != OK:
		return err
	peer = new_peer
	multiplayer.multiplayer_peer = peer
	return OK


func join(address: String = "127.0.0.1", port: int = DEFAULT_PORT) -> Error:
	var new_peer := ENetMultiplayerPeer.new()
	var err := new_peer.create_client(address, port)
	if err != OK:
		return err
	peer = new_peer
	multiplayer.multiplayer_peer = peer
	return OK


func is_server() -> bool:
	return multiplayer.has_multiplayer_peer() and multiplayer.is_server()


## RTT (ms) for one connected peer, or 0 if `peer_id` isn't currently
## connected. ENetMultiplayerPeer.get_peer() logs an engine ERROR for any
## id outside multiplayer.get_peers(), so membership is checked first.
func get_peer_rtt_ms(peer_id: int) -> int:
	if not peer or not multiplayer.get_peers().has(peer_id):
		return 0
	return int(peer.get_peer(peer_id).get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))


func close() -> void:
	if peer:
		peer.close()
		peer = null
	multiplayer.multiplayer_peer = null


## Runs callable now if no artificial latency is configured, otherwise
## queues it to run artificial_latency_ms later. Fire-and-forget: callers
## don't get the callable's return value back.
func with_artificial_latency(callable: Callable) -> void:
	if artificial_latency_ms <= 0:
		callable.call()
		return
	_delayed_calls.append(
		{"release_time": _elapsed_time + artificial_latency_ms / 1000.0, "callable": callable}
	)


## Delay is measured against _elapsed_time (this node's own accumulated
## process delta), not a wall-clock read -- headless/batch test runs can
## process many simulated frames faster than real time elapses, so a
## wall-clock-based release_time could sit unreached indefinitely even
## after "enough" frames have passed.
func _process(delta: float) -> void:
	_elapsed_time += delta
	if _delayed_calls.is_empty():
		return
	var still_pending: Array[Dictionary] = []
	for entry in _delayed_calls:
		if entry["release_time"] > _elapsed_time:
			still_pending.append(entry)
		elif is_instance_valid(entry["callable"].get_object()):
			# The callable's bound object can be freed before its delayed
			# effect was due to fire -- despawn, scene teardown, test
			# cleanup. Drop it rather than error.
			entry["callable"].call()
	_delayed_calls = still_pending
