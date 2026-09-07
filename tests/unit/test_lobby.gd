extends GutTest
## ui/lobby/lobby.gd's fixed, bottom-center Ready/Switch Team buttons
## (2026-09-04, human owner's own request -- pulled out of the
## per-player row `_build_player_row()` used to build them in, see that
## file's own doc comment). Matches this project's established
## convention for `LobbyState` (`tests/unit/test_lobby_state.gd`'s own
## doc comment): pure logic gets a unit test here (signal wiring, and
## `_refresh_room_ui()`'s read-and-reflect-into-UI logic, both testable
## without touching the real RPC/broadcast pipeline); the actual
## register/broadcast round-trip stays live-verified only.

const LOBBY_SCENE := preload("res://ui/lobby/Lobby.tscn")


func after_each() -> void:
	LobbyState.reset_room()


func _spawn_lobby() -> Control:
	return add_child_autofree(LOBBY_SCENE.instantiate())


func test_ready_button_is_wired_to_set_local_ready() -> void:
	var lobby := _spawn_lobby()
	var ready_button: Button = lobby.get_node("ReadyButton")
	var connections := ready_button.toggled.get_connections()
	assert_eq(connections.size(), 1)
	assert_eq(connections[0]["callable"], Callable(LobbyState, "set_local_ready"))


func test_switch_team_button_is_wired() -> void:
	var lobby := _spawn_lobby()
	var switch_button: Button = lobby.get_node("SwitchTeamButton")
	assert_eq(switch_button.pressed.get_connections().size(), 1)


func test_ready_button_reflects_the_local_peers_own_ready_state() -> void:
	var lobby := _spawn_lobby()
	var ready_button: Button = lobby.get_node("ReadyButton")
	assert_false(ready_button.button_pressed, "not ready by default")
	assert_eq(ready_button.text, "Ready")

	LobbyState.player_ready[multiplayer.get_unique_id()] = true
	LobbyState.room_state_changed.emit()

	assert_true(ready_button.button_pressed)
	assert_eq(ready_button.text, "Not Ready")


func test_switch_team_button_only_visible_in_team_mode() -> void:
	var lobby := _spawn_lobby()
	var switch_button: Button = lobby.get_node("SwitchTeamButton")
	LobbyState.room_match_mode = MatchState.MatchMode.TEAM
	LobbyState.room_state_changed.emit()
	assert_true(switch_button.visible)

	LobbyState.room_match_mode = MatchState.MatchMode.FREE_FOR_ALL
	LobbyState.room_state_changed.emit()
	assert_false(switch_button.visible)


## Human owner's own explicit ask: 2x the default Button size/font.
## Godot's own default Button theme font size is 16 -- this project's
## own convention elsewhere (Slice 14/16's own labels) doesn't
## hardcode a "default" to compare against, so this just locks in the
## chosen 32 (2x16) directly, the same way any other deliberate design
## constant would be tested.
func test_ready_and_switch_team_buttons_use_doubled_font_size() -> void:
	var lobby := _spawn_lobby()
	var ready_button: Button = lobby.get_node("ReadyButton")
	var switch_button: Button = lobby.get_node("SwitchTeamButton")
	assert_eq(ready_button.get_theme_font_size(&"font_size"), 32)
	assert_eq(switch_button.get_theme_font_size(&"font_size"), 32)


## Human owner's own 2026-09-04 follow-up ask: "bloquear qualquer
## mudança depois de ready, somente pode apertar not ready" -- Switch
## Team must lock the instant the local peer readies up. ReadyButton
## itself is deliberately NOT covered by this lock (un-readying must
## always stay possible) -- see test_ready_button_reflects_the_local_
## peers_own_ready_state() above, which already exercises toggling it
## with no disabled check.
func test_switch_team_button_disabled_once_ready() -> void:
	var lobby := _spawn_lobby()
	var switch_button: Button = lobby.get_node("SwitchTeamButton")
	LobbyState.room_match_mode = MatchState.MatchMode.TEAM
	LobbyState.room_state_changed.emit()
	assert_false(switch_button.disabled, "test setup: not ready yet")

	LobbyState.player_ready[multiplayer.get_unique_id()] = true
	LobbyState.room_state_changed.emit()
	assert_true(switch_button.disabled)


## Same lock, for the 3 self-service options built per-row
## (_build_player_row() only ever builds these for the LOCAL peer's own
## row -- see that function's own doc comment). Uses 2 separate lobby
## instances (not one instance re-emitted twice) since rebuilding the
## row list calls queue_free() on the old row, which doesn't remove it
## from the tree until the next idle frame -- a 2nd emit in the same
## test would risk reading the stale, not-yet-freed row back.
func test_loadout_options_are_disabled_once_ready() -> void:
	var lobby := _spawn_lobby()
	var local_id := multiplayer.get_unique_id()
	LobbyState.player_class_ids[local_id] = "vanguard"
	LobbyState.player_ready[local_id] = true
	LobbyState.room_state_changed.emit()
	var row: HBoxContainer = lobby.get_node("PlayerListContainer").get_child(0)
	assert_true((row.get_child(1) as OptionButton).disabled, "perk option")
	assert_true((row.get_child(2) as OptionButton).disabled, "weapon option")
	assert_true((row.get_child(3) as OptionButton).disabled, "boot option")


func test_loadout_options_stay_enabled_while_not_ready() -> void:
	var lobby := _spawn_lobby()
	var local_id := multiplayer.get_unique_id()
	LobbyState.player_class_ids[local_id] = "vanguard"
	LobbyState.room_state_changed.emit()
	var row: HBoxContainer = lobby.get_node("PlayerListContainer").get_child(0)
	assert_false((row.get_child(1) as OptionButton).disabled, "perk option")
	assert_false((row.get_child(2) as OptionButton).disabled, "weapon option")
	assert_false((row.get_child(3) as OptionButton).disabled, "boot option")
