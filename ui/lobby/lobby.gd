extends Control
## Room Config: mode select (Team/FFA), friendly-fire toggle, per-player
## SELF-SERVICE team assignment (Team mode only -- a "Switch Team"
## button on a peer's own row only, never another peer's; corrected
## mid-Phase-9, was host-controlled-for-everyone, a real authority bug
## the human owner caught, not a design choice), a ready checkbox per
## non-host player, and a host-only Start button. Perks (Phase 9) and
## LAN discovery (Phase 10) are not this screen's job yet, see
## memory/plan.md's "Slices 7-10".
##
## Mode/friendly-fire controls are host-only: NetworkManager.is_server()
## gates both interactivity (disabled for clients) and which peer's own
## script instance is allowed to actually call
## LobbyState.set_room_match_mode()/set_room_friendly_fire() -- both are
## called directly (no RPC), since the host IS the server locally.
## Team, unlike those two, is a per-player choice, not a match-wide
## setting -- LobbyState.set_local_team() is self-service (any peer,
## own row only), same shape as set_local_ready().

const MODE_LABELS: Array[String] = ["Team", "Free For All"]

var _is_host: bool = false

@onready var _mode_option: OptionButton = $ModeOptionButton
@onready var _friendly_fire_check: CheckBox = $FriendlyFireCheckBox
@onready var _player_list_container: VBoxContainer = $PlayerListContainer
@onready var _start_button: Button = $StartButton
@onready var _waiting_label: Label = $WaitingLabel


func _ready() -> void:
	_is_host = NetworkManager.is_server()
	_start_button.visible = _is_host
	_waiting_label.visible = not _is_host

	for label in MODE_LABELS:
		_mode_option.add_item(label)
	_mode_option.disabled = not _is_host
	_friendly_fire_check.disabled = not _is_host
	if _is_host:
		_mode_option.item_selected.connect(_on_mode_selected)
		_friendly_fire_check.toggled.connect(_on_friendly_fire_toggled)
	_start_button.pressed.connect(_on_start_pressed)

	LobbyState.room_state_changed.connect(_refresh_room_ui)
	EventBus.match_state_changed.connect(_on_match_state_changed)
	_refresh_room_ui()
	_maybe_dev_hooks()


func _on_mode_selected(index: int) -> void:
	LobbyState.set_room_match_mode(index as MatchState.MatchMode)


func _on_friendly_fire_toggled(value: bool) -> void:
	LobbyState.set_room_friendly_fire(value)


func _on_start_pressed() -> void:
	MatchState.friendly_fire_enabled = LobbyState.room_friendly_fire
	MatchState.enter_loading(LobbyState.room_match_mode as MatchState.MatchMode)


## LOADING (not IN_PROGRESS) is the scene-change trigger -- every peer
## switches to TestArena.tscn here, then net/loading_reporter.gd
## reports back once that peer's own tree is actually ready. The
## server only calls enter_in_progress() once everyone has reported,
## by which point every peer is already inside TestArena -- no further
## scene change needed for that transition. See core/match_state.gd's
## Phase 7 doc comment.
func _on_match_state_changed(_new_phase: int) -> void:
	if MatchState.current_phase == MatchState.Phase.LOADING:
		get_tree().change_scene_to_file("res://maps/test_arena/TestArena.tscn")


func _refresh_room_ui() -> void:
	_mode_option.selected = LobbyState.room_match_mode
	_friendly_fire_check.button_pressed = LobbyState.room_friendly_fire

	for child in _player_list_container.get_children():
		child.queue_free()

	var local_id := multiplayer.get_unique_id()
	var team_mode := LobbyState.room_match_mode == MatchState.MatchMode.TEAM
	for peer_id in LobbyState.player_class_ids:
		_player_list_container.add_child(_build_player_row(peer_id, local_id, team_mode))

	var team_split_ok := (not team_mode) or LobbyState.has_valid_team_split()
	_start_button.disabled = (
		not LobbyState.all_non_host_ready(_host_peer_id()) or not team_split_ok
	)


func _build_player_row(peer_id: int, local_id: int, team_mode: bool) -> HBoxContainer:
	var row := HBoxContainer.new()

	var label := Label.new()
	var class_id: String = LobbyState.player_class_ids[peer_id]
	var team_suffix := " [Team %d]" % LobbyState.get_team_id(peer_id) if team_mode else ""
	var role_suffix := " (Host)" if peer_id == _host_peer_id() else ""
	label.text = "Peer %s: %s%s%s" % [peer_id, class_id, team_suffix, role_suffix]
	row.add_child(label)

	if peer_id != _host_peer_id():
		var ready_check := CheckBox.new()
		ready_check.text = "Ready"
		ready_check.button_pressed = LobbyState.is_ready(peer_id)
		ready_check.disabled = peer_id != local_id
		if peer_id == local_id:
			ready_check.toggled.connect(LobbyState.set_local_ready)
		row.add_child(ready_check)

	if peer_id == local_id and team_mode:
		var switch_button := Button.new()
		switch_button.text = "Switch Team"
		switch_button.pressed.connect(
			func(): LobbyState.set_local_team(1 - LobbyState.get_team_id(local_id))
		)
		row.add_child(switch_button)

	return row


func _host_peer_id() -> int:
	return 1


## Headless dev testing hooks -- there is no mouse/keyboard to click
## real controls in this environment. Same pattern as
## CharacterSelect's/HostJoin's own --dev-* flags; see
## memory/verify.md's Phase 8 section for how these are used in the
## live multi-process test. Host-only flags do nothing on a client, and
## vice versa, matching each control's own real interactivity gating.
## --dev-switch-team is available to EITHER role -- team is a
## self-service, per-player choice, not host-only (corrected mid-Phase-9).
func _maybe_dev_hooks() -> void:
	var args := OS.get_cmdline_user_args()
	if _is_host:
		if "--dev-room-mode=ffa" in args:
			_on_mode_selected(MatchState.MatchMode.FREE_FOR_ALL)
		if "--dev-room-friendly-fire" in args:
			_on_friendly_fire_toggled(true)
	else:
		if "--dev-ready" in args:
			LobbyState.set_local_ready(true)
	if "--dev-switch-team" in args:
		_await_and_switch_local_team()
	if _is_host and "--dev-autostart" in args:
		_await_and_autostart()


## Waits for the LOCAL peer's own registration to land in LobbyState
## before switching -- synchronous on the host (register_local_player()
## applies directly), but a client's own registration only lands after
## its _rpc_register round-trip completes, so a poll (not a fixed
## delay -- proved unreliable across independent OS processes in Phase
## 7's own live testing) is needed here too, same bounded-wait
## reasoning as _await_and_autostart().
func _await_and_switch_local_team() -> void:
	var local_id := multiplayer.get_unique_id()
	var max_wait_ticks := 40
	for _i in max_wait_ticks:
		if LobbyState.player_team_ids.has(local_id):
			LobbyState.set_local_team(1 - LobbyState.get_team_id(local_id))
			return
		await get_tree().create_timer(0.5).timeout


## Polls (rather than a fixed delay, which proved unreliable in Phase
## 7's own live testing: 2 independent OS processes have no shared
## clock) for every non-host peer to be both registered AND ready
## before auto-starting, up to a bounded wait so a genuinely solo run
## doesn't hang forever either.
func _await_and_autostart() -> void:
	var min_peers := 2
	var max_wait_ticks := 40
	for _i in max_wait_ticks:
		if (
			LobbyState.player_class_ids.size() >= min_peers
			and LobbyState.all_non_host_ready(_host_peer_id())
		):
			break
		await get_tree().create_timer(0.5).timeout
	_on_start_pressed()
