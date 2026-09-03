## Pure logic coverage for LanDiscovery.parse_announcement()/
## prune_stale_rooms() -- the socket-driven parts (start_advertising(),
## start_listening()) are tactically verified instead, matching this
## project's own convention (see memory/verify.md's Phase 10 section).
extends GutTest


func test_parse_announcement_accepts_well_formed_payload() -> void:
	var payload := var_to_bytes({"player_count": 2, "max_players": 8})
	assert_eq(LanDiscovery.parse_announcement(payload), {"player_count": 2, "max_players": 8})


func test_parse_announcement_rejects_non_dictionary() -> void:
	assert_eq(LanDiscovery.parse_announcement(var_to_bytes("not a dictionary")), {})


func test_parse_announcement_rejects_missing_fields() -> void:
	assert_eq(LanDiscovery.parse_announcement(var_to_bytes({"player_count": 2})), {})


func test_parse_announcement_rejects_wrong_field_types() -> void:
	assert_eq(
		LanDiscovery.parse_announcement(var_to_bytes({"player_count": "two", "max_players": 8})), {}
	)


func test_parse_announcement_rejects_garbage_bytes() -> void:
	var garbage: PackedByteArray = [1, 2, 3, 4, 5, 255, 254, 253]
	assert_eq(LanDiscovery.parse_announcement(garbage), {})


func test_prune_stale_rooms_keeps_recent_entries() -> void:
	var rooms := {"10.0.0.1": {"player_count": 1, "max_players": 8, "last_seen_msec": 1000}}
	var pruned := LanDiscovery.prune_stale_rooms(rooms, 2000, 3000)
	assert_eq(pruned, rooms)


func test_prune_stale_rooms_drops_expired_entries() -> void:
	var rooms := {"10.0.0.1": {"player_count": 1, "max_players": 8, "last_seen_msec": 1000}}
	var pruned := LanDiscovery.prune_stale_rooms(rooms, 5000, 3000)
	assert_eq(pruned, {})


func test_prune_stale_rooms_keeps_one_drops_another() -> void:
	var rooms := {
		"fresh": {"player_count": 1, "max_players": 8, "last_seen_msec": 4000},
		"stale": {"player_count": 1, "max_players": 8, "last_seen_msec": 1000},
	}
	var pruned := LanDiscovery.prune_stale_rooms(rooms, 5000, 3000)
	assert_eq(pruned.keys(), ["fresh"])
