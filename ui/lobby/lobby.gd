extends Control
## Room Config: mode select (Team/FFA), friendly-fire toggle, per-player
## SELF-SERVICE team assignment (Team mode only -- a "Switch Team"
## button on a peer's own row only, never another peer's; corrected
## mid-Phase-9, was host-controlled-for-everyone, a real authority bug
## the human owner caught, not a design choice), a self-service perk
## pick (Phase 9), self-service weapon/boot picks (Phase 16, a shared
## pool of 3 each, class-independent), all visible on every row and
## changeable only on a peer's own -- same authority shape as team --
## and a Leave Room button (Phase 14, returns to Main Menu). LAN
## discovery (Phase 10) is not this screen's job, see memory/plan.md's
## "Slices 7-10".
##
## Phase 14: ready is now symmetric (a toggle Button, including the
## host's own) rather than a checkbox for every peer EXCEPT the host
## plus a separate host-only Start button -- LobbyState itself decides
## WHEN to actually start (a server-side countdown once everyone's
## ready, see LobbyState._recompute_countdown()), this screen just
## reflects that countdown's broadcast value. There is no more Start
## button to press.
##
## 2026-09-04 (human owner's own request): Ready and Switch Team are no
## longer built per-row inside _build_player_row() -- they're the 2
## most important actions on this whole screen, so they're now fixed,
## large (2x a normal Button's default size/font), bottom-center-
## anchored controls in Lobby.tscn (ReadyButton/SwitchTeamButton)
## always controlling the LOCAL peer, never rebuilt on every room-state
## refresh. Every peer's row still shows their own ready state, just as
## read-only text now (a " [Ready]" suffix), the same way team/perk/
## weapon/boot picks already were.
##
## Mode/friendly-fire controls are host-only: NetworkManager.is_server()
## gates both interactivity (disabled for clients) and which peer's own
## script instance is allowed to actually call
## LobbyState.set_room_match_mode()/set_room_friendly_fire() -- both are
## called directly (no RPC), since the host IS the server locally.
## Team, perk, weapon, and boot, unlike those two, are per-player
## choices, not match-wide settings -- LobbyState.set_local_team()/
## set_local_perk()/set_local_weapon()/set_local_boot() are all
## self-service (any peer, own row only), same shape as
## set_local_ready().

const MODE_LABELS: Array[String] = ["Team", "Free For All"]

var _is_host: bool = false

@onready var _mode_option: OptionButton = $ModeOptionButton
@onready var _friendly_fire_check: CheckBox = $FriendlyFireCheckBox
@onready var _player_list_container: VBoxContainer = $PlayerListContainer
@onready var _status_label: Label = $StatusLabel
@onready var _leave_button: Button = $LeaveButton
@onready var _ready_button: Button = $ReadyButton
@onready var _switch_team_button: Button = $SwitchTeamButton


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
	_ready_button.toggled.connect(LobbyState.set_local_ready)
	_switch_team_button.pressed.connect(_on_switch_team_pressed)

	LobbyState.room_state_changed.connect(_refresh_room_ui)
	LobbyState.countdown_changed.connect(_refresh_status_label)
	EventBus.match_state_changed.connect(_on_match_state_changed)
	_refresh_room_ui()
	_maybe_dev_hooks()


func _on_switch_team_pressed() -> void:
	var local_id := multiplayer.get_unique_id()
	LobbyState.set_local_team(1 - LobbyState.get_team_id(local_id))


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

	var local_is_ready := LobbyState.is_ready(local_id)
	_ready_button.button_pressed = local_is_ready
	_ready_button.text = "Not Ready" if local_is_ready else "Ready"
	_switch_team_button.visible = team_mode
	# 2026-09-04 (human owner's own request): "bloquear qualquer mudança
	# depois de ready, somente pode apertar not ready" -- Switch Team is
	# the one self-service control built as a fixed node rather than
	# per-row (see this file's own 2026-09-04 doc comment above), so it's
	# disabled here; the per-row perk/weapon/boot options get the same
	# treatment inside _build_perk_option()/_build_weapon_option()/
	# _build_boot_option() below. _ready_button itself is deliberately
	# NEVER disabled -- un-readying is the one action that must still
	# work.
	_switch_team_button.disabled = local_is_ready

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
	var weapon_id := LobbyState.get_weapon_id(peer_id, LobbyState.WEAPON_IDS[0])
	var weapon_name := (
		LobbyState.WEAPON_RESOURCES[LobbyState.WEAPON_IDS.find(weapon_id)].weapon_name
	)
	var boot_id := LobbyState.get_boot_id(peer_id, LobbyState.BOOT_IDS[0])
	var boot_name := LobbyState.BOOT_RESOURCES[LobbyState.BOOT_IDS.find(boot_id)].boot_name
	var loadout_suffix := " [%s / %s]" % [weapon_name, boot_name]
	var role_suffix := " (Host)" if peer_id == _host_peer_id() else ""
	# Ready/Switch Team are no longer built per-row (see this file's own
	# 2026-09-04 doc comment) -- every row still shows ready state, just
	# as read-only text now, the same as team/perk/weapon/boot.
	var ready_suffix := " [Ready]" if LobbyState.is_ready(peer_id) else ""
	label.text = (
		"Peer %s: %s%s%s%s%s%s"
		% [peer_id, class_id, team_suffix, perk_suffix, loadout_suffix, role_suffix, ready_suffix]
	)
	row.add_child(label)

	if peer_id == local_id:
		row.add_child(_build_perk_option())
		row.add_child(_build_weapon_option())
		row.add_child(_build_boot_option())

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
	option.disabled = LobbyState.is_ready(multiplayer.get_unique_id())
	return option


## Phase 16: same self-service authority shape as _build_perk_option()
## above -- class + weapon + boot + perk are 4 fully independent
## choices. Shows each weapon's own display name (WeaponResource.
## weapon_name), not perk's id.capitalize() convention -- a weapon id
## like "iron_sword" would read as "Iron_sword" capitalized.
func _build_weapon_option() -> OptionButton:
	var option := OptionButton.new()
	for weapon in LobbyState.WEAPON_RESOURCES:
		option.add_item(weapon.weapon_name)
	option.selected = LobbyState.WEAPON_IDS.find(
		LobbyState.get_weapon_id(multiplayer.get_unique_id(), LobbyState.WEAPON_IDS[0])
	)
	option.item_selected.connect(
		func(index: int): LobbyState.set_local_weapon(LobbyState.WEAPON_IDS[index])
	)
	option.disabled = LobbyState.is_ready(multiplayer.get_unique_id())
	return option


func _build_boot_option() -> OptionButton:
	var option := OptionButton.new()
	for boot in LobbyState.BOOT_RESOURCES:
		option.add_item(boot.boot_name)
	option.selected = LobbyState.BOOT_IDS.find(
		LobbyState.get_boot_id(multiplayer.get_unique_id(), LobbyState.BOOT_IDS[0])
	)
	option.item_selected.connect(
		func(index: int): LobbyState.set_local_boot(LobbyState.BOOT_IDS[index])
	)
	option.disabled = LobbyState.is_ready(multiplayer.get_unique_id())
	return option


func _host_peer_id() -> int:
	return 1


## Headless dev testing hooks -- there is no mouse/keyboard to click
## real controls in this environment. Same pattern as
## CharacterSelect's/HostJoin's own --dev-* flags; see
## memory/verify.md's Phase 8 section for how these are used in the
## live multi-process test. Host-only flags do nothing on a client, and
## vice versa, matching each control's own real interactivity gating.
## --dev-ready, --dev-switch-team, --dev-perk=<id>, and Phase 16's
## --dev-weapon=<id>/--dev-boot=<id> are available to EITHER role --
## Phase 14 made ready symmetric (team and perk were already
## self-service, per-player choices, not host-only). There is no more
## --dev-autostart: the countdown itself is what starts the match now,
## once every peer (including the host) has readied up -- see
## LobbyState._recompute_countdown().
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
		elif arg.begins_with("--dev-weapon="):
			LobbyState.set_local_weapon(arg.trim_prefix("--dev-weapon="))
		elif arg.begins_with("--dev-boot="):
			LobbyState.set_local_boot(arg.trim_prefix("--dev-boot="))


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
