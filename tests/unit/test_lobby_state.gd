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


## Phase 14: ready is now symmetric -- the host's own flag counts too
## (replaces the old all_non_host_ready(), which deliberately skipped
## peer 1). See net/lobby_state.gd's own doc comment.
func test_all_ready_false_when_no_one_is_registered() -> void:
	var lobby := LobbyStateScript.new()
	assert_false(lobby.all_ready())
	lobby.free()


func test_all_ready_true_for_a_solo_host_who_has_readied_up() -> void:
	var lobby := LobbyStateScript.new()
	lobby.player_class_ids[1] = "vanguard"
	lobby.player_ready[1] = true
	assert_true(lobby.all_ready())
	lobby.free()


func test_all_ready_false_when_the_host_has_not_readied_up() -> void:
	var lobby := LobbyStateScript.new()
	lobby.player_class_ids[1] = "vanguard"
	lobby.player_class_ids[2] = "warden"
	lobby.player_ready[2] = true
	assert_false(lobby.all_ready())
	lobby.free()


func test_all_ready_false_when_a_non_host_peer_has_not_reported() -> void:
	var lobby := LobbyStateScript.new()
	lobby.player_class_ids[1] = "vanguard"
	lobby.player_class_ids[2] = "warden"
	lobby.player_ready[1] = true
	assert_false(lobby.all_ready())
	lobby.free()


func test_all_ready_true_once_every_registered_peer_including_host_reports() -> void:
	var lobby := LobbyStateScript.new()
	lobby.player_class_ids[1] = "vanguard"
	lobby.player_class_ids[2] = "warden"
	lobby.player_class_ids[3] = "ranged_mage"
	lobby.player_ready[1] = true
	lobby.player_ready[2] = true
	lobby.player_ready[3] = true
	assert_true(lobby.all_ready())
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


func test_team_label_maps_ids_to_red_and_blue() -> void:
	assert_eq(LobbyState.team_label(0), "Red")
	assert_eq(LobbyState.team_label(1), "Blue")


## Found by /check (Phase 14): LobbyState is an autoload, so its
## registries used to survive across a Leave Room -> re-host cycle --
## a stale player_ready[1] = true from a PREVIOUS room could let the
## new room's countdown auto-start with no Ready press ever happening
## in it. reset_room() is called at the top of register_local_player(),
## the one function every fresh room entry (Host or Join) already goes
## through.
func test_reset_room_clears_every_previous_rooms_state() -> void:
	var lobby := LobbyStateScript.new()
	lobby.player_class_ids[1] = "vanguard"
	lobby.player_team_ids[1] = 0
	lobby.player_perk_ids[1] = "swift"
	lobby.player_weapon_ids[1] = "warhammer"
	lobby.player_boot_ids[1] = "tumbling_boots"
	lobby.player_ready[1] = true
	lobby.room_match_mode = MatchState.MatchMode.FREE_FOR_ALL
	lobby.room_friendly_fire = true
	lobby.reset_room()
	assert_true(lobby.player_class_ids.is_empty())
	assert_true(lobby.player_team_ids.is_empty())
	assert_true(lobby.player_perk_ids.is_empty())
	assert_true(lobby.player_weapon_ids.is_empty())
	assert_true(lobby.player_boot_ids.is_empty())
	assert_true(lobby.player_ready.is_empty())
	assert_eq(lobby.room_match_mode, MatchState.MatchMode.TEAM)
	assert_false(lobby.room_friendly_fire)
	lobby.free()


## Found by /check (Phase 14): a peer disconnecting or a new peer
## direct-IP-joining mid-match still runs LobbyState's own registry
## mutations (_on_peer_disconnected/_apply_registration), which could
## make is_room_ready_to_start() resolve true again off leftover Room
## Config state and re-trigger the countdown mid-match. The countdown
## is only ever a Room Config (Phase.LOBBY) concern. Phase saved/
## restored per this file's own established isolation convention (see
## test_player_spawner.gd's _spawner_and_characters()).
func test_countdown_still_valid_false_once_the_match_has_left_lobby() -> void:
	var lobby := LobbyStateScript.new()
	lobby.player_class_ids[1] = "vanguard"
	lobby.player_ready[1] = true
	lobby._countdown_generation = 1
	var original_phase := MatchState.current_phase
	MatchState.current_phase = MatchState.Phase.IN_PROGRESS
	assert_false(lobby._countdown_still_valid(1))
	MatchState.current_phase = original_phase
	lobby.free()


func test_countdown_still_valid_true_while_still_in_the_lobby() -> void:
	var lobby := LobbyStateScript.new()
	lobby.player_class_ids[1] = "vanguard"
	lobby.player_ready[1] = true
	lobby._countdown_generation = 1
	var original_phase := MatchState.current_phase
	MatchState.current_phase = MatchState.Phase.LOBBY
	assert_true(lobby._countdown_still_valid(1))
	MatchState.current_phase = original_phase
	lobby.free()


## Phase 14: is_room_ready_to_start() is the pure predicate the
## server-only countdown coroutine gates on -- everyone ready, AND (FFA,
## which has no team-split concept, OR a valid team split). The
## countdown/RPC broadcast itself is verified live, same convention as
## the rest of this file's own registry logic.
func test_is_room_ready_to_start_false_when_not_everyone_is_ready() -> void:
	var lobby := LobbyStateScript.new()
	lobby.player_class_ids[1] = "vanguard"
	assert_false(lobby.is_room_ready_to_start())
	lobby.free()


func test_is_room_ready_to_start_false_in_team_mode_with_an_invalid_split() -> void:
	var lobby := LobbyStateScript.new()
	lobby.player_class_ids[1] = "vanguard"
	lobby.player_class_ids[2] = "warden"
	lobby.player_ready[1] = true
	lobby.player_ready[2] = true
	lobby.player_team_ids[1] = 0
	lobby.player_team_ids[2] = 0
	lobby.room_match_mode = MatchState.MatchMode.TEAM
	assert_false(lobby.is_room_ready_to_start())
	lobby.free()


func test_is_room_ready_to_start_true_in_team_mode_with_a_valid_split() -> void:
	var lobby := LobbyStateScript.new()
	lobby.player_class_ids[1] = "vanguard"
	lobby.player_class_ids[2] = "warden"
	lobby.player_ready[1] = true
	lobby.player_ready[2] = true
	lobby.player_team_ids[1] = 0
	lobby.player_team_ids[2] = 1
	lobby.room_match_mode = MatchState.MatchMode.TEAM
	assert_true(lobby.is_room_ready_to_start())
	lobby.free()


func test_is_room_ready_to_start_true_in_ffa_regardless_of_team_split() -> void:
	var lobby := LobbyStateScript.new()
	lobby.player_class_ids[1] = "vanguard"
	lobby.player_class_ids[2] = "warden"
	lobby.player_ready[1] = true
	lobby.player_ready[2] = true
	lobby.player_team_ids[1] = 0
	lobby.player_team_ids[2] = 0
	lobby.room_match_mode = MatchState.MatchMode.FREE_FOR_ALL
	assert_true(lobby.is_room_ready_to_start())
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


## Phase 16: weapon and boot are a 2nd/3rd fully independent loadout
## axis alongside perk (confirmed 2026-09-03: not a replacement for
## it) -- same resolve/get/default-on-registration shape as perk above.
func test_valid_weapon_id_passes_through() -> void:
	assert_eq(LobbyState.resolve_weapon_id("warhammer"), "warhammer")


func test_unknown_weapon_id_falls_back_to_first_canonical_weapon() -> void:
	assert_eq(LobbyState.resolve_weapon_id("not_a_weapon"), LobbyState.WEAPON_IDS[0])


func test_empty_weapon_id_falls_back_to_first_canonical_weapon() -> void:
	assert_eq(LobbyState.resolve_weapon_id(""), LobbyState.WEAPON_IDS[0])


func test_get_weapon_id_returns_fallback_for_unregistered_peer() -> void:
	var lobby := LobbyStateScript.new()
	assert_eq(lobby.get_weapon_id(42, "iron_sword"), "iron_sword")
	lobby.free()


func test_get_weapon_id_returns_registered_choice() -> void:
	var lobby := LobbyStateScript.new()
	lobby.player_weapon_ids[42] = "warhammer"
	assert_eq(lobby.get_weapon_id(42, "iron_sword"), "warhammer")
	lobby.free()


func test_registering_a_class_defaults_weapon_to_first_canonical_weapon() -> void:
	var lobby := LobbyStateScript.new()
	lobby._apply_registration(42, "warden")
	assert_eq(lobby.player_weapon_ids[42], LobbyState.WEAPON_IDS[0])
	lobby.free()


func test_registering_again_does_not_reset_an_already_chosen_weapon() -> void:
	var lobby := LobbyStateScript.new()
	lobby._apply_registration(42, "warden")
	lobby.player_weapon_ids[42] = "warhammer"
	lobby._apply_registration(42, "warden")
	assert_eq(lobby.player_weapon_ids[42], "warhammer")
	lobby.free()


func test_valid_boot_id_passes_through() -> void:
	assert_eq(LobbyState.resolve_boot_id("tumbling_boots"), "tumbling_boots")


func test_unknown_boot_id_falls_back_to_first_canonical_boot() -> void:
	assert_eq(LobbyState.resolve_boot_id("not_a_boot"), LobbyState.BOOT_IDS[0])


func test_empty_boot_id_falls_back_to_first_canonical_boot() -> void:
	assert_eq(LobbyState.resolve_boot_id(""), LobbyState.BOOT_IDS[0])


func test_get_boot_id_returns_fallback_for_unregistered_peer() -> void:
	var lobby := LobbyStateScript.new()
	assert_eq(lobby.get_boot_id(42, "swift_boots"), "swift_boots")
	lobby.free()


func test_get_boot_id_returns_registered_choice() -> void:
	var lobby := LobbyStateScript.new()
	lobby.player_boot_ids[42] = "tumbling_boots"
	assert_eq(lobby.get_boot_id(42, "swift_boots"), "tumbling_boots")
	lobby.free()


func test_registering_a_class_defaults_boot_to_first_canonical_boot() -> void:
	var lobby := LobbyStateScript.new()
	lobby._apply_registration(42, "warden")
	assert_eq(lobby.player_boot_ids[42], LobbyState.BOOT_IDS[0])
	lobby.free()


func test_registering_again_does_not_reset_an_already_chosen_boot() -> void:
	var lobby := LobbyStateScript.new()
	lobby._apply_registration(42, "warden")
	lobby.player_boot_ids[42] = "tumbling_boots"
	lobby._apply_registration(42, "warden")
	assert_eq(lobby.player_boot_ids[42], "tumbling_boots")
	lobby.free()
