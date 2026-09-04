extends Node
## Slice 13b: holds the current match's reconnect token (server-issued
## via net/player_spawner.gd's _issue_reconnect_token(), held only in
## this client's own memory -- lost on a full quit, never IP-matched,
## see memory/plan.md's Slice 13b block) and drives the client-side
## auto-reconnect attempt when the connection drops mid-match.
##
## An autoload specifically so it survives NetworkManager.close()/
## join() re-pointing multiplayer.multiplayer_peer out from under
## whatever scene happens to be active. Deliberately does NOT reload
## TestArena.tscn on a successful reconnect -- that was tried first and
## found live to corrupt MultiplayerSpawner's own replication caches on
## both ends (cascading "Node not found"/"Invalid packet received"
## engine errors, see memory/gotchas.md): the client's local TestArena
## is left exactly as the disconnect froze it (no despawn ever ran
## against it -- see net/player_spawner.gd's own grace-period design),
## so PlayerSpawner._rpc_reassign_controller() on the existing, still-
## present character node is all that's needed to resume it; no reload
## required, and none of that node's already-established replication
## state gets invalidated.
##
## Also the fix for a real bug found via /waza:hunt during play-testing
## (2026-09-03, see memory/gotchas.md): a dropped connection used to
## leave the player staring at a frozen TestArena forever, with
## ui/hud/network_stats_overlay.gd spamming "No multiplayer peer is
## assigned" every frame. That overlay now shows this manager's own
## status text instead while reconnecting, and returns to MainMenu
## only once this manager gives up.

signal reconnect_status_changed

const GRACE_PERIOD_SECONDS := 30.0
const RETRY_INTERVAL_SECONDS := 1.0

var _token: String = ""
var _last_join_address: String = ""
var _last_join_port: int = 0
var _attempting: bool = false
var _gave_up: bool = false
var _time_remaining: float = 0.0
var _status_text: String = ""


func _ready() -> void:
	multiplayer.server_disconnected.connect(_on_disconnected)
	multiplayer.connection_failed.connect(_on_disconnected)


## Called by ui/host_join/host_join.gd right before/after every real
## NetworkManager.join() attempt, so a later auto-reconnect knows where
## to dial back to. Not needed for host() -- the host doesn't reconnect
## to itself if its own process is what went down.
func remember_join_target(address: String, port: int) -> void:
	_last_join_address = address
	_last_join_port = port


## Called by net/player_spawner.gd's own _rpc_receive_token, server ->
## this specific peer, right after spawn. A fresh token also resets any
## earlier give-up state, so a brand new match's own disconnects start
## clean.
@rpc("authority", "reliable")
func _rpc_receive_token(token: String) -> void:
	_token = token
	_gave_up = false


func status_text() -> String:
	return _status_text


func has_given_up() -> bool:
	return _gave_up


func is_attempting() -> bool:
	return _attempting


## Never fires for the server's own listen-peer -- multiplayer.
## server_disconnected/.connection_failed are both client-side-only
## signals in Godot, so this is already scoped to "I am a client who
## lost the server" without an extra NetworkManager.is_server() guard.
func _on_disconnected() -> void:
	if _token.is_empty() or _attempting:
		return
	_attempting = true
	_gave_up = false
	_time_remaining = GRACE_PERIOD_SECONDS
	_status_text = "Connection lost -- reconnecting..."
	reconnect_status_changed.emit()
	_try_reconnect()


func _try_reconnect() -> void:
	if not _attempting:
		return
	NetworkManager.close()
	if not multiplayer.connected_to_server.is_connected(_on_connected_for_reconnect):
		multiplayer.connected_to_server.connect(_on_connected_for_reconnect, CONNECT_ONE_SHOT)
	NetworkManager.join(_last_join_address, _last_join_port)
	get_tree().create_timer(RETRY_INTERVAL_SECONDS).timeout.connect(_on_retry_tick)


func _on_retry_tick() -> void:
	if not _attempting:
		return
	_time_remaining -= RETRY_INTERVAL_SECONDS
	if _time_remaining <= 0.0:
		_give_up()
		return
	_status_text = "Connection lost -- reconnecting... (%ds)" % int(ceil(_time_remaining))
	reconnect_status_changed.emit()
	if not multiplayer.has_multiplayer_peer():
		_try_reconnect()


func _on_connected_for_reconnect() -> void:
	_rpc_attempt_reconnect.rpc_id(1, _token)


## any_peer, but the actual authority check lives in
## PlayerSpawner.try_reclaim(), which is only ever handed
## multiplayer.get_remote_sender_id() here, never a client-supplied id
## -- a peer can only ever reclaim whichever character its own token
## maps to server-side.
@rpc("any_peer", "reliable")
func _rpc_attempt_reconnect(token: String) -> void:
	if not NetworkManager.is_server():
		return
	var spawner := get_tree().get_first_node_in_group(&"player_spawner") as PlayerSpawner
	var success: bool = (
		spawner.try_reclaim(token, multiplayer.get_remote_sender_id()) if spawner else false
	)
	_rpc_receive_reconnect_result.rpc_id(multiplayer.get_remote_sender_id(), success)


@rpc("authority", "reliable")
func _rpc_receive_reconnect_result(success: bool) -> void:
	if not success:
		_give_up()
		return
	_attempting = false
	_status_text = ""


func _give_up() -> void:
	_attempting = false
	_gave_up = true
	_status_text = "Connection lost."
	reconnect_status_changed.emit()
