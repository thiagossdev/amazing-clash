extends Control
## Room Config: mode select (Team/FFA), friendly-fire toggle, per-player
## SELF-SERVICE team assignment (Team mode only -- a "Switch Team"
## button on a peer's own row only, never another peer's; corrected
## mid-Phase-9, was host-controlled-for-everyone, a real authority bug
## the human owner caught, not a design choice), a self-service perk
## pick (Phase 9, visible on every row, changeable only on a peer's
## own -- same authority shape as team), and a Leave Room button (Phase
## 14, returns to Main Menu). LAN discovery (Phase 10) is not this
## screen's job, see memory/plan.md's "Slices 7-10".
##
## Phase 14: ready is now symmetric (a toggle Button per row, including
## the host's own) rather than a checkbox for every peer EXCEPT the
## host plus a separate host-only Start button -- LobbyState itself
## decides WHEN to actually start (a server-side countdown once
## everyone's ready, see LobbyState._recompute_countdown()), this
## screen just reflects that countdown's broadcast value. There is no
## more Start button to press.
##
## Mode/friendly-fire controls are host-only: NetworkManager.is_server()
## gates both interactivity (disabled for clients) and which peer's own
## script instance is allowed to actually call
## LobbyState.set_room_match_mode()/set_room_friendly_fire() -- both are
## called directly (no RPC), since the host IS the server locally.
## Team and perk, unlike those two, are per-player choices, not
## match-wide settings -- LobbyState.set_local_team()/set_local_perk()
## are self-service (any peer, own row only), same shape as
## set_local_ready().

const MODE_LABELS: Array[String] = ["Team", "Free For All"]

var _is_host: bool = false

@onready var _mode_option: OptionButton = $ModeOptionButton
@onready var _friendly_fire_check: CheckBox = $FriendlyFireCheckBox
@onready var _player_list_container: VBoxContainer = $PlayerListContainer
@onready var _status_label: Label = $StatusLabel
@onready var _leave_button: Button = $LeaveButton


func _ready() -> void:
	_is_host = NetworkManager.is_server()

	for label in MODE_LABELS:
		_mode_option.add_item(label)
	_mode_option.disabled = not _is_host
	_friendly_fire_check.disabled = not _is_host
	if _is_host:
		_mode_option.item_selected.connect(_on_mode_selected)
		_friendly_fire_check.toggled.connect(_on_friendly_fire_toggled)
	_leave_button.pressed.connect(_on_leave_pressed)

	LobbyState.room_state_changed.connect(_refresh_room_ui)
	LobbyState.countdown_changed.connect(_refresh_status_label)
	EventBus.match_state_changed.connect(_on_match_state_changed)
	_refresh_room_ui()
	_maybe_dev_hooks()


func _on_mode_selected(index: int) -> void:
	LobbyState.set_room_match_mode(index as MatchState.MatchMode)


func _on_friendly_fire_toggled(value: bool) -> void:
	LobbyState.set_room_friendly_fire(value)


func _on_leave_pressed() -> void:
	LanDiscovery.stop_advertising()
	NetworkManager.close()
	get_tree().change_scene_to_file("res://ui/main_menu/MainMenu.tscn")


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

	_refresh_status_label()


## LobbyState.countdown_seconds_remaining is -1.0 whenever nothing is
## counting down (not everyone ready yet, or still inside the silent
## pre-delay window) -- blank status in that case, same as this screen
## showed nothing extra before the Start button existed.
func _refresh_status_label() -> void:
	var remaining := LobbyState.countdown_seconds_remaining
	_status_label.text = "Starting in %d..." % int(ceil(remaining)) if remaining >= 0.0 else ""


func _build_player_row(peer_id: int, local_id: int, team_mode: bool) -> HBoxContainer:
	var row := HBoxContainer.new()

	var label := Label.new()
	var class_id: String = LobbyState.player_class_ids[peer_id]
	var team_suffix := (
		" [%s]" % LobbyState.team_label(LobbyState.get_team_id(peer_id)) if team_mode else ""
	)
	var perk_id := LobbyState.get_perk_id(peer_id, LobbyState.PERK_IDS[0])
	var perk_suffix := " (%s)" % perk_id.capitalize()
	var role_suffix := " (Host)" if peer_id == _host_peer_id() else ""
	label.text = "Peer %s: %s%s%s%s" % [peer_id, class_id, team_suffix, perk_suffix, role_suffix]
	row.add_child(label)

	var controls := VBoxContainer.new()
	var is_ready_now := LobbyState.is_ready(peer_id)
	var ready_button := Button.new()
	ready_button.toggle_mode = true
	ready_button.button_pressed = is_ready_now
	ready_button.text = "Not Ready" if is_ready_now else "Ready"
	ready_button.disabled = peer_id != local_id
	if peer_id == local_id:
		ready_button.toggled.connect(LobbyState.set_local_ready)
	controls.add_child(ready_button)

	if peer_id == local_id and team_mode:
		var switch_button := Button.new()
		switch_button.text = "Switch Team"
		switch_button.pressed.connect(
			func(): LobbyState.set_local_team(1 - LobbyState.get_team_id(local_id))
		)
		controls.add_child(switch_button)

	row.add_child(controls)

	if peer_id == local_id:
		row.add_child(_build_perk_option())

	return row


## Only ever built for the local peer's own row -- a perk is
## self-service (LobbyState.set_local_perk()), same authority shape as
## team. Every other peer's row shows their pick as read-only text
## (perk_suffix above), same as class.
func _build_perk_option() -> OptionButton:
	var option := OptionButton.new()
	for perk_id in LobbyState.PERK_IDS:
		option.add_item(perk_id.capitalize())
	option.selected = LobbyState.PERK_IDS.find(
		LobbyState.get_perk_id(multiplayer.get_unique_id(), LobbyState.PERK_IDS[0])
	)
	option.item_selected.connect(
		func(index: int): LobbyState.set_local_perk(LobbyState.PERK_IDS[index])
	)
	return option


func _host_peer_id() -> int:
	return 1


## Headless dev testing hooks -- there is no mouse/keyboard to click
## real controls in this environment. Same pattern as
## CharacterSelect's/HostJoin's own --dev-* flags; see
## memory/verify.md's Phase 8 section for how these are used in the
## live multi-process test. Host-only flags do nothing on a client, and
## vice versa, matching each control's own real interactivity gating.
## --dev-ready, --dev-switch-team, and --dev-perk=<id> are available to
## EITHER role -- Phase 14 made ready symmetric (team and perk were
## already self-service, per-player choices, not host-only). There is
## no more --dev-autostart: the countdown itself is what starts the
## match now, once every peer (including the host) has readied up --
## see LobbyState._recompute_countdown().
func _maybe_dev_hooks() -> void:
	var args := OS.get_cmdline_user_args()
	if _is_host:
		if "--dev-room-mode=ffa" in args:
			_on_mode_selected(MatchState.MatchMode.FREE_FOR_ALL)
		if "--dev-room-friendly-fire" in args:
			_on_friendly_fire_toggled(true)
	if "--dev-ready" in args:
		_await_and_set_local_ready(true)
	if "--dev-switch-team" in args:
		_await_and_switch_local_team()
	for arg in args:
		if arg.begins_with("--dev-perk="):
			LobbyState.set_local_perk(arg.trim_prefix("--dev-perk="))


## Waits for the LOCAL peer's own registration to land in LobbyState
## before setting ready -- synchronous on the host (register_local_
## player() applies directly), but a client's own registration only
## lands after its _rpc_register round-trip completes, so a poll (not a
## fixed delay -- proved unreliable across independent OS processes in
## Phase 7's own live testing) is needed here too, same bounded-wait
## reasoning as _await_and_switch_local_team() below.
func _await_and_set_local_ready(ready: bool) -> void:
	var local_id := multiplayer.get_unique_id()
	var max_wait_ticks := 40
	for _i in max_wait_ticks:
		if LobbyState.player_class_ids.has(local_id):
			LobbyState.set_local_ready(ready)
			return
		await get_tree().create_timer(0.5).timeout


func _await_and_switch_local_team() -> void:
	var local_id := multiplayer.get_unique_id()
	var max_wait_ticks := 40
	for _i in max_wait_ticks:
		if LobbyState.player_team_ids.has(local_id):
			LobbyState.set_local_team(1 - LobbyState.get_team_id(local_id))
			return
		await get_tree().create_timer(0.5).timeout
