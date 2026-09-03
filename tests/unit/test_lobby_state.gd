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
