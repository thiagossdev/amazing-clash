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


func test_resolve_team_id_passes_through_valid_values() -> void:
	assert_eq(LobbyState.resolve_team_id(0), 0)
	assert_eq(LobbyState.resolve_team_id(1), 1)


func test_resolve_team_id_clamps_out_of_range_values() -> void:
	assert_eq(
		LobbyState.resolve_team_id(999),
		1,
		"an untrusted any_peer _rpc_set_team payload must not set an out-of-range team"
	)
	assert_eq(LobbyState.resolve_team_id(-5), 0)


func test_apply_team_clamps_through_resolve_team_id() -> void:
	var lobby := LobbyStateScript.new()
	lobby._apply_team(42, 999)
	assert_eq(lobby.player_team_ids[42], 1)
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


func test_has_valid_team_split_true_with_fewer_than_2_players() -> void:
	var lobby := LobbyStateScript.new()
	lobby.player_team_ids[1] = 0
	assert_true(lobby.has_valid_team_split())
	lobby.free()


func test_has_valid_team_split_false_when_everyone_is_on_one_team() -> void:
	var lobby := LobbyStateScript.new()
	lobby.player_team_ids[1] = 0
	lobby.player_team_ids[2] = 0
	assert_false(lobby.has_valid_team_split())
	lobby.free()


func test_has_valid_team_split_true_when_2_teams_have_members() -> void:
	var lobby := LobbyStateScript.new()
	lobby.player_team_ids[1] = 0
	lobby.player_team_ids[2] = 1
	assert_true(lobby.has_valid_team_split())
	lobby.free()


func test_valid_perk_id_passes_through() -> void:
	assert_eq(LobbyState.resolve_perk_id("adept"), "adept")


func test_unknown_perk_id_falls_back_to_first_canonical_perk() -> void:
	assert_eq(LobbyState.resolve_perk_id("not_a_perk"), LobbyState.PERK_IDS[0])


func test_empty_perk_id_falls_back_to_first_canonical_perk() -> void:
	assert_eq(LobbyState.resolve_perk_id(""), LobbyState.PERK_IDS[0])


func test_get_perk_id_returns_fallback_for_unregistered_peer() -> void:
	var lobby := LobbyStateScript.new()
	assert_eq(lobby.get_perk_id(42, "vitality"), "vitality")
	lobby.free()


func test_get_perk_id_returns_registered_choice() -> void:
	var lobby := LobbyStateScript.new()
	lobby.player_perk_ids[42] = "swift"
	assert_eq(lobby.get_perk_id(42, "vitality"), "swift")
	lobby.free()


func test_registering_a_class_defaults_perk_to_first_canonical_perk() -> void:
	var lobby := LobbyStateScript.new()
	lobby._apply_registration(42, "warden")
	assert_eq(lobby.player_perk_ids[42], LobbyState.PERK_IDS[0])
	lobby.free()


func test_registering_again_does_not_reset_an_already_chosen_perk() -> void:
	var lobby := LobbyStateScript.new()
	lobby._apply_registration(42, "warden")
	lobby.player_perk_ids[42] = "adept"
	lobby._apply_registration(42, "warden")
	assert_eq(lobby.player_perk_ids[42], "adept")
	lobby.free()
