extends GutTest
## Pure logic coverage for LobbyState.resolve_class_id() -- the
## Node-based registry (RPC broadcast, peer bookkeeping) is verified
## tactilely instead, matching this project's own convention for
## WinCondition/CombatResolver/PlayerSpawner.

const LobbyStateScript := preload("res://net/lobby_state.gd")


func test_valid_class_id_passes_through() -> void:
	assert_eq(LobbyState.resolve_class_id("warden"), "warden")


func test_unknown_class_id_falls_back_to_first_canonical_id() -> void:
	assert_eq(LobbyState.resolve_class_id("not_a_class"), LobbyState.CLASS_IDS[0])


func test_empty_class_id_falls_back_to_first_canonical_id() -> void:
	assert_eq(LobbyState.resolve_class_id(""), LobbyState.CLASS_IDS[0])


func test_get_class_id_returns_fallback_for_unregistered_peer() -> void:
	var lobby := LobbyStateScript.new()
	assert_eq(lobby.get_class_id(42, "vanguard"), "vanguard")
	lobby.free()


func test_get_class_id_returns_registered_choice() -> void:
	var lobby := LobbyStateScript.new()
	lobby.player_class_ids[42] = "warden"
	assert_eq(lobby.get_class_id(42, "vanguard"), "warden")
	lobby.free()


func test_get_team_id_returns_fallback_for_unregistered_peer() -> void:
	var lobby := LobbyStateScript.new()
	assert_eq(lobby.get_team_id(42, 1), 1)
	lobby.free()


func test_get_team_id_returns_registered_team() -> void:
	var lobby := LobbyStateScript.new()
	lobby.player_team_ids[42] = 1
	assert_eq(lobby.get_team_id(42, 0), 1)
	lobby.free()


func test_is_ready_defaults_false_for_unregistered_peer() -> void:
	var lobby := LobbyStateScript.new()
	assert_false(lobby.is_ready(42))
	lobby.free()


func test_is_ready_reflects_registered_flag() -> void:
	var lobby := LobbyStateScript.new()
	lobby.player_ready[42] = true
	assert_true(lobby.is_ready(42))
	lobby.free()


func test_all_non_host_ready_true_when_no_other_peers() -> void:
	var lobby := LobbyStateScript.new()
	lobby.player_class_ids[1] = "vanguard"
	assert_true(lobby.all_non_host_ready(1))
	lobby.free()


func test_all_non_host_ready_false_when_a_peer_has_not_reported() -> void:
	var lobby := LobbyStateScript.new()
	lobby.player_class_ids[1] = "vanguard"
	lobby.player_class_ids[2] = "warden"
	assert_false(lobby.all_non_host_ready(1))
	lobby.free()


func test_all_non_host_ready_ignores_the_host_own_flag() -> void:
	var lobby := LobbyStateScript.new()
	lobby.player_class_ids[1] = "vanguard"
	lobby.player_class_ids[2] = "warden"
	lobby.player_ready[2] = true
	assert_true(lobby.all_non_host_ready(1))
	lobby.free()


func test_all_non_host_ready_true_once_every_non_host_peer_reports() -> void:
	var lobby := LobbyStateScript.new()
	lobby.player_class_ids[1] = "vanguard"
	lobby.player_class_ids[2] = "warden"
	lobby.player_class_ids[3] = "ranged_mage"
	lobby.player_ready[2] = true
	lobby.player_ready[3] = true
	assert_true(lobby.all_non_host_ready(1))
	lobby.free()
