extends Node
## LAN room discovery via UDP broadcast, entirely separate from
## net/network_manager.gd's ENet gameplay connection (DEFAULT_PORT
## 7777) -- this only ever exchanges a tiny "a room exists" beacon,
## never gameplay data, on its own fixed port. See memory/plan.md's
## Slice 10.
##
## Real, documented risk (not resolved here, not this project's to
## solve): UDP broadcast doesn't reliably cross every real-world LAN
## setup (Wi-Fi AP isolation, some WSL2-to-Windows-host network
## configurations). ui/host_join/'s manual IP field stays available at
## all times as the guaranteed fallback if a room never shows up here.
##
## Confirmed mechanism (2026-09-03, `/waza:hunt`, real Linux+WSL2 host
## / Windows client play-test -- `wslinfo --networking-mode` reads
## "nat" in this dev environment): WSL2 NAT mode puts the Linux side on
## its own private virtual subnet behind a Hyper-V virtual switch, not
## the real LAN. Inbound broadcast from the real LAN into that isolated
## subnet is blocked by the NAT boundary by default -- standard NAT
## behavior, nothing to configure here -- which is exactly why a
## Windows-hosted room never appeared to the Linux/WSL2 client.
## Outbound broadcast from WSL2 can inconsistently leak onto the real
## LAN (a Linux-hosted room *did* appear to the Windows client), but
## `PacketPeerUDP.get_packet_ip()`'s reported source address for that
## leaked packet is the WSL2-internal NAT address, not the address a
## real LAN peer can actually route back to -- so joining a discovered
## room this way hung forever (no success, no clean failure) even
## though the identical IP typed manually into the Join field connects
## instantly. The actual fix, if ever wanted, is a WSL2 networking-mode
## change (`[wsl2] networkingMode=mirrored` in `.wslconfig`, Windows
## 11 22H2+), not a code change here.

## Fired whenever discovered_rooms changes (a new/updated room, or one
## expiring) -- ui/host_join/host_join.gd listens to redraw its list.
signal rooms_updated

const DISCOVERY_PORT := 7778
const ANNOUNCE_INTERVAL_SEC := 1.0
const ROOM_TTL_MSEC := 3000

## Keyed by the announcing peer's IP (String, from PacketPeerUDP.
## get_packet_ip() -- never trusted from the payload itself). Each
## entry: {player_count: int, max_players: int, last_seen_msec: int}.
var discovered_rooms: Dictionary = {}

var _advertise_socket: PacketPeerUDP
var _advertise_elapsed: float = ANNOUNCE_INTERVAL_SEC
var _listen_socket: PacketPeerUDP


func _process(delta: float) -> void:
	if _advertise_socket:
		_advertise_elapsed += delta
		if _advertise_elapsed >= ANNOUNCE_INTERVAL_SEC:
			_advertise_elapsed = 0.0
			_send_announcement()
	if _listen_socket:
		_poll_listen_socket()
		_apply_pruning()


## Host-only: starts broadcasting a "this room exists" beacon every
## ANNOUNCE_INTERVAL_SEC. Call once NetworkManager.host() has already
## succeeded. A no-op if already advertising.
func start_advertising() -> void:
	if _advertise_socket:
		return
	var socket := PacketPeerUDP.new()
	socket.set_broadcast_enabled(true)
	socket.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	_advertise_socket = socket
	_advertise_elapsed = ANNOUNCE_INTERVAL_SEC


## Host-only: stops the beacon. Called once the room stops accepting
## new joiners (Room Config's Start button, see ui/lobby/lobby.gd) --
## advertising a room nobody can actually join anymore is pointless.
func stop_advertising() -> void:
	if _advertise_socket:
		_advertise_socket.close()
	_advertise_socket = null


## Client-only: starts listening for other peers' beacons. Call when
## entering the Host/Join screen. A no-op if already listening.
func start_listening() -> void:
	if _listen_socket:
		return
	var socket := PacketPeerUDP.new()
	var err := socket.bind(DISCOVERY_PORT)
	if err != OK:
		push_warning("LanDiscovery: bind failed (%s) -- LAN list disabled, use manual IP." % err)
		return
	_listen_socket = socket
	discovered_rooms.clear()


## Stops listening and clears the discovered list -- called once the
## player has committed to hosting or joining (ui/host_join/host_join.gd's
## _enter_lobby()), since browsing rooms no longer applies.
func stop_listening() -> void:
	if _listen_socket:
		_listen_socket.close()
	_listen_socket = null
	discovered_rooms.clear()


func _send_announcement() -> void:
	var payload := {
		"player_count": multiplayer.get_peers().size() + 1,
		"max_players": NetworkManager.MAX_CLIENTS
	}
	_advertise_socket.put_packet(var_to_bytes(payload))


func _poll_listen_socket() -> void:
	var updated := false
	while _listen_socket.get_available_packet_count() > 0:
		var bytes := _listen_socket.get_packet()
		var ip := _listen_socket.get_packet_ip()
		var parsed := parse_announcement(bytes)
		if parsed.is_empty():
			continue
		discovered_rooms[ip] = {
			"player_count": parsed["player_count"],
			"max_players": parsed["max_players"],
			"last_seen_msec": Time.get_ticks_msec(),
		}
		updated = true
	if updated:
		rooms_updated.emit()


## Pure: validates an arbitrary received payload before trusting it --
## this is untrusted network input (any process, ours or not, could be
## broadcasting on this port), not just a malformed edge case. Returns
## {} for anything that doesn't decode to the exact expected shape.
func parse_announcement(bytes: PackedByteArray) -> Dictionary:
	var decoded: Variant = bytes_to_var(bytes)
	if not (decoded is Dictionary):
		return {}
	if not (decoded.has("player_count") and decoded.has("max_players")):
		return {}
	if not (decoded["player_count"] is int and decoded["max_players"] is int):
		return {}
	return decoded


## Pure: drops any room whose last_seen_msec is older than ttl_msec.
## Extracted as its own function so it's unit-testable without a real
## socket or Time singleton, matching this project's WinCondition-style
## "pure logic gets a GUT test" convention.
func prune_stale_rooms(
	rooms: Dictionary, now_msec: int, ttl_msec: int = ROOM_TTL_MSEC
) -> Dictionary:
	var kept := {}
	for ip in rooms:
		if now_msec - rooms[ip]["last_seen_msec"] <= ttl_msec:
			kept[ip] = rooms[ip]
	return kept


func _apply_pruning() -> void:
	var pruned := prune_stale_rooms(discovered_rooms, Time.get_ticks_msec())
	if pruned.size() != discovered_rooms.size():
		discovered_rooms = pruned
		rooms_updated.emit()
